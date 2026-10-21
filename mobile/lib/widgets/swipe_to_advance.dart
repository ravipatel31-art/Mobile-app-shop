import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'ui_kit.dart';

/// Flick-to-advance wrapper for list cards, built on Apple's "Designing
/// Fluid Interfaces" model:
///
///  * the card tracks the finger 1:1 (after a 10px axis-lock hysteresis so a
///    vertical scroll is never stolen),
///  * on release the landing is decided by projecting the release velocity
///    (`projected = pos + (v/1000)·d/(1−d)`, d ≈ 0.998 ≈ half a second of
///    momentum) — past half the reveal distance the gesture commits and fires
///    [onCommit], otherwise a spring hands the card back to the origin,
///  * dragging past the reveal extent rubber-bands (asymptotic damping)
///    instead of stopping dead,
///  * a new pointer down interrupts any running settle — input is never
///    locked during a transition.
///
/// The card's regular buttons stay fully functional: this is an addition,
/// not a replacement.
class SwipeToAdvance extends StatefulWidget {
  final Widget child;

  /// Revealed behind the card as it slides right (see [SwipeAdvancePanel]).
  final Widget panel;

  /// Fired when the gesture commits — the caller runs its optimistic advance.
  final VoidCallback onCommit;

  /// Disabled while an advance for this card is already in flight.
  final bool enabled;

  /// Full reveal distance in logical pixels (panel width).
  final double extent;

  const SwipeToAdvance({
    super.key,
    required this.child,
    required this.panel,
    required this.onCommit,
    this.enabled = true,
    this.extent = 110,
  });

  @override
  State<SwipeToAdvance> createState() => _SwipeToAdvanceState();
}

class _SwipeToAdvanceState extends State<SwipeToAdvance>
    with SingleTickerProviderStateMixin {
  /// Drives the settle springs; its `value` is the reveal offset in px.
  /// Built on first use rather than as a `late` field: a `late` one would be
  /// lazily constructed right inside `dispose()` for cards that never
  /// animated, and creating a ticker mid-teardown throws.
  AnimationController? _settleCtrl;
  AnimationController get _settle => _settleCtrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      )..addListener(_onSettleTick);

  double _offset = 0;

  // Drag bookkeeping (raw Listener so we own the axis decision).
  double? _downX;
  double? _downY;
  double _offsetOnDown = 0;

  /// null = axis undecided; true = locked horizontal; false = cancelled.
  bool? _horizontal;

  /// Recent (timeMs, x) samples for the release velocity.
  final List<Offset> _samples = [];

  /// Pixels of drift before the axis is decided — below this a drag is noise.
  static const double _hysteresis = 10;

  /// Momentum decay per ms used for the release projection (Apple's ~0.998).
  static const double _decay = 0.998;

  @override
  void dispose() {
    _settleCtrl?.dispose(); // never via the getter — that would *create* it
    super.dispose();
  }

  void _onSettleTick() {
    if (!mounted) return;
    setState(() => _offset = _settle.value);
  }

  @override
  void didUpdateWidget(covariant SwipeToAdvance old) {
    super.didUpdateWidget(old);
    // Never lock into an animation for a card that can no longer advance —
    // spring home so the UI matches the (disabled) state.
    if (!widget.enabled && old.enabled && _offset != 0) {
      _settle.stop();
      _springBack();
    }
  }

  void _onPointerDown(PointerDownEvent e) {
    if (!widget.enabled) return;
    _settle.stop(); // interruptible: a new touch takes over mid-settle
    _offsetOnDown = _offset;
    _downX = e.position.dx;
    _downY = e.position.dy;
    _horizontal = null;
    _samples
      ..clear()
      ..add(Offset(e.timeStamp.inMilliseconds.toDouble(), e.position.dx));
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_downX == null) return;
    final dx = e.position.dx - _downX!;
    final dy = e.position.dy - _downY!;

    if (_horizontal == null) {
      if (dx.abs() <= _hysteresis && dy.abs() <= _hysteresis) return;
      // Dominant direction wins; vertical hands the drag back to the
      // scrollable so the card never steals a scroll.
      _horizontal = dx.abs() > dy.abs();
      if (!_horizontal!) {
        _springBack();
        return;
      }
    }

    final now = e.timeStamp.inMilliseconds.toDouble();
    _samples.add(Offset(now, e.position.dx));
    // Keep a short trailing window (at least two samples) for the velocity.
    while (_samples.length > 2 && now - _samples.first.dx > 150) {
      _samples.removeAt(0);
    }

    final target = _offsetOnDown + dx;
    setState(() => _offset = _follow(target));
  }

  /// 1:1 inside [0, extent]; beyond either edge the drag rubber-bands
  /// (asymptotic damping saturating one extent past the range).
  double _follow(double target) {
    if (target >= 0 && target <= widget.extent) return target;
    return target < 0
        ? -_saturate(-target)
        : widget.extent + _saturate(target - widget.extent);
  }

  double _saturate(double v) => widget.extent * v / (widget.extent + v);

  void _onPointerUp(PointerUpEvent e) {
    if (_downX == null) return;
    final tracked = _horizontal == true;
    _downX = _downY = null;
    _horizontal = null;
    if (!tracked) return; // never became a horizontal drag — leave the tap

    final v = _releaseVelocity(e.position.dx, e); // px per second
    // Apple's projection: where momentum (~0.5 s of decay) lands the card.
    final projected = _offset + (v / 1000) * _decay / (1 - _decay);
    if (projected >= widget.extent * 0.5) {
      _commit(v);
    } else {
      _springBack(initialVelocity: v);
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (_downX == null) return;
    _downX = _downY = null;
    _horizontal = null;
    _springBack();
  }

  /// Velocity from the trailing samples, in px/s.
  double _releaseVelocity(double x, PointerEvent e) {
    if (_samples.isEmpty) return 0;
    final dt = e.timeStamp.inMilliseconds.toDouble() - _samples.first.dx;
    if (dt <= 1) return 0;
    return (x - _samples.first.dy) / dt * 1000;
  }

  void _commit(double velocity) {
    widget.onCommit(); // optimistic advance fires immediately — no waiting
    // The release momentum carries the card to the full reveal, then it
    // springs home behind the already-repainted optimistic state.
    _settle.animateWith(_springTo(widget.extent, velocity)).whenCompleteOrCancel(
        () {
      if (mounted) _springBack();
    });
  }

  void _springBack({double initialVelocity = 0}) {
    if (_offset == 0 && !_settle.isAnimating) return;
    _animateTo(0, initialVelocity);
  }

  void _animateTo(double target, double velocity) {
    _settle.animateWith(_springTo(target, velocity));
  }

  Simulation _springTo(double target, double velocity) => SpringSimulation(
        SpringDescription.withDampingRatio(
            mass: 1, stiffness: 350, ratio: 1),
        _offset,
        target,
        velocity,
      );

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: widget.extent,
            child: widget.panel,
          ),
          // Stack's hard-edge clip makes the card slide out under the right
          // edge while the panel is revealed behind it; left of the origin
          // the card stays pinned (the rubber-band value still tracks).
          Transform.translate(
            offset: Offset(math.max(_offset, 0), 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// Colored panel revealed behind a [SwipeToAdvance] card: the action's icon
/// and label, so the flick target is legible while the finger is down.
class SwipeAdvancePanel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color foreground;
  final BorderRadius borderRadius;

  const SwipeAdvancePanel({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.foreground,
    this.borderRadius = const BorderRadius.horizontal(
      left: Radius.circular(AppRadius.xl),
      right: Radius.circular(AppRadius.xl),
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: color, borderRadius: borderRadius),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: foreground, size: 24),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: trackFor(11),
            ),
          ),
        ],
      ),
    );
  }
}

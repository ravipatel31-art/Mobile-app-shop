import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// The app's motion system — Apple's spring model ("Designing Fluid
/// Interfaces"), not scripted fixed durations.
///
/// Springs are described by two human-friendly numbers instead of raw
/// stiffness/damping coefficients:
/// - **response** (seconds): how long a nudge takes to roughly settle.
///   Mapped to stiffness as `k = (2π / response)²` (mass 1).
/// - **damping ratio**: 1.0 is critically damped (settles with **no**
///   overshoot — the default for UI); below 1.0 lets the spring bounce,
///   which reads as physical only right after a flick/throw.
///   Mapped to the damping coefficient as `c = 2·√(k·m)·ratio`.
///
/// Springs are also *interruptible*: a retarget mid-flight just starts a new
/// simulation from the current value (and velocity, via [AppMotion.springTo]),
/// so motion hands off instead of restarting.
class AppMotion {
  AppMotion._();

  /// Spring mass — Apple's model uses 1kg; only [response] and [damping]
  /// change the feel.
  static const double _mass = 1;

  /// Maps the Apple parameters (response in seconds + damping ratio) to a
  /// Flutter [SpringDescription]: `k = (2π/response)²`, `c = 2√(k·m)·ratio`.
  static SpringDescription spring({
    required double response,
    required double damping,
  }) {
    final k = math.pow(2 * math.pi / response, 2).toDouble();
    final c = 2 * math.sqrt(k * _mass) * damping;
    return SpringDescription(mass: _mass, stiffness: k, damping: c);
  }

  /// Default settle: critically damped (ratio 1.0, response 0.4s) — no
  /// overshoot. Use for repositions, reveals, and state changes.
  static SpringDescription get settle => spring(response: 0.4, damping: 1.0);

  /// Flick/throw release: slightly under-damped (ratio 0.8, response 0.35s)
  /// — a touch of bounce, only where the gesture just threw the object.
  static SpringDescription get momentum =>
      spring(response: 0.35, damping: 0.8);

  /// Spring-feel curve for Flutter's *implicit* animations
  /// ([AnimatedContainer], [AnimatedSwitcher], …), which only accept curves.
  /// Critically-damped-ish ease-out that mirrors [settle].
  static const Curve curve = Cubic(0.22, 1, 0.36, 1);

  /// Reduced-motion duration used in place of [normalMs]: a fast cross-fade
  /// instead of the full travel time (still visible, just brief).
  static const int _reducedMs = 100;

  /// Whether the OS asks us to reduce motion (a11y "remove animations").
  static bool reducedOf(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// Duration for implicit animations: [normalMs] normally, collapsing to a
  /// fast cross-fade under reduced motion.
  static Duration duration(BuildContext context, int normalMs) =>
      Duration(milliseconds: reducedOf(context) ? _reducedMs : normalMs);

  /// Drives [controller] to [end] with a spring simulation, handing off the
  /// controller's current [velocity] so a mid-flight retarget keeps its
  /// momentum instead of starting cold.
  static TickerFuture springTo(
    AnimationController controller, {
    required double end,
    double? velocity,
    SpringDescription? spring,
  }) {
    return controller.animateWith(SpringSimulation(
      spring ?? settle,
      controller.value,
      end,
      // Ignore a dead controller's velocity (returns 0 when at rest anyway).
      velocity ?? controller.velocity,
    ));
  }
}

// AppHaptics lives in haptics.dart — import that file for haptic calls.

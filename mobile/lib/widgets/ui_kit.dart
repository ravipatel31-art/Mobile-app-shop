import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'motion.dart';

/// Shared visual language for the cafe app: warm coffee palette, gradients,
/// hand-drawn latte-art illustration, and small reusable display widgets.
class CafePalette {
  static const coffee = Color(0xFF6F4E37);
  static const espresso = Color(0xFF4E3626);
  static const caramel = Color(0xFFC8956C);
  static const cream = Color(0xFFF6F4F1);
  static const latte = Color(0xFFEDE4DA);
  static const mint = Color(0xFF5FAB86);
  static const berry = Color(0xFFB3546E);
  static const sunshine = Color(0xFFF2B251);
  static const sky = Color(0xFF5B8DEF);
  static const peach = Color(0xFFE8845C);
  static const mist = Color(0xFFE4E6EB);
  static const charcoal = Color(0xFF333333);
  static const ivory = Color(0xFFFFFFFF);

  // ---- Premium brass family (the "Dark & Premium" accent) ---------------
  /// Polished brass gold — the hero accent. Matches the dark theme's
  /// `primary`; use it for the one element that should catch the eye.
  static const gold = Color(0xFFE6B25A);
  static const champagne = Color(0xFFF3DCA8); // pale gold highlight
  static const bronze = Color(0xFF9C7038); // deeper metal, for gradients
}

/// Semantic status colours, defined **once** for the whole app.
///
/// Order states, table occupancy and success/warning/error feedback used to
/// re-type raw `Colors.red` / `Colors.green.shade700` / `0xFF2F6B51`
/// literals in a dozen screens — colours that only ever read on cream.
/// Resolve the palette for the current appearance at the top of `build`
/// and reference it from there:
///
/// ```dart
/// final status = AppStatus.of(context);
/// ...
/// status.danger,
/// status.tint(status.danger), // soft chip/row wash
/// ```
///
/// Light keeps the deep ink tones that hold contrast on cream (all ≥4.5:1
/// on `#F6F4F1`, white-on-them ≥4.5:1 too, so a filled status button works
/// either way). Dark lifts and softens them into warm pastel-with-body
/// tones that stay legible over espresso without glaring — never the light
/// values, which would punch a hole in a near-black screen.
class AppStatus {
  const AppStatus._();

  /// Light appearance: deep, ink-like status colours.
  static const light = AppStatusPalette(
    success: Color(0xFF2F6B51),
    warning: Color(0xFFB45309),
    danger: Color(0xFFC62828),
    info: Color(0xFF1E5FA8),
    neutral: Color(0xFF546A73),
    occupied: Color(0xFF9A4A2B),
    brightness: Brightness.light,
    onColor: Colors.white,
  );

  /// Dark appearance: same roles, lifted so they don't glare or sink.
  static const dark = AppStatusPalette(
    success: Color(0xFF7FC9A4),
    warning: Color(0xFFE5B168),
    danger: Color(0xFFF08A80),
    info: Color(0xFF8FB8F8),
    neutral: Color(0xFF9AA7AE),
    occupied: Color(0xFFD19A79),
    brightness: Brightness.dark,
    onColor: Color(0xFF17120E),
  );

  /// The palette for the appearance currently in effect.
  static AppStatusPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// One appearance's worth of [AppStatus] colours — see [AppStatus].
class AppStatusPalette {
  const AppStatusPalette({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.neutral,
    required this.occupied,
    required this.brightness,
    this.onColor = Colors.white,
  });

  /// Done / paid / ready / free table.
  final Color success;

  /// Preparing / low stock / awaiting confirmation.
  final Color warning;

  /// Failed / cancelled / urgent.
  final Color danger;

  /// Neutral information (new, pending, queued).
  final Color info;

  /// Idle / unknown — the grey-blue "no strong signal" state.
  final Color neutral;

  /// Occupied table / busy station.
  final Color occupied;

  final Brightness brightness;

  /// What to draw *on top of* one of these colours when it is used as a
  /// fill (button, badge, full-colour chip): white on the deep light-mode
  /// tones, near-black espresso on the lifted dark-mode ones.
  final Color onColor;

  /// The soft wash behind a status chip or highlighted row: the colour
  /// itself at low alpha, so a badge tints its own backdrop instead of
  /// shipping a second `shade50`/`shade100` literal that only reads on
  /// cream. Dark needs roughly twice the alpha to register on espresso.
  Color tint(Color base, {double? alpha}) => base.withValues(
      alpha: alpha ?? (brightness == Brightness.dark ? 0.20 : 0.10));
}

/// [CafePalette] relationships expressed as theme roles, so screens can say
/// `scheme.coffee` / `scheme.cream` instead of re-typing a hex literal that
/// only ever read on a cream page.
///
/// The light values are *exactly* the palette constants (no light-mode
/// drift); the dark values restate the same relationship on the espresso
/// ladder — ink becomes the muted latte primary, pale fills step down
/// toward the page, forward panels step up.
extension CafePaletteRoles on ColorScheme {
  /// Coffee ink: text, icons and accents that used to be
  /// [CafePalette.coffee] (too dark to read on espresso).
  Color get coffee =>
      brightness == Brightness.dark ? primary : CafePalette.coffee;

  /// Espresso ink: the dark text drawn *on* pale fills — [CafePalette.latte]
  /// chips, white pills. In dark those fills become dark surfaces of their
  /// own, so the ink is simply the current on-surface text colour.
  Color get espressoInk =>
      brightness == Brightness.dark ? onSurface : CafePalette.espresso;

  /// Berry accent: the "required / attention" ink used by option badges and
  /// validation hints — lifted in dark so it clears 4.5:1 on espresso.
  Color get berry =>
      brightness == Brightness.dark ? const Color(0xFFE8A5B5) : CafePalette.berry;

  /// Mint accent: price deltas and other "positive" ink.
  Color get mint =>
      brightness == Brightness.dark ? const Color(0xFF8FD0AA) : CafePalette.mint;

  /// Page / soft-card fill that used to be [CafePalette.cream].
  Color get cream => brightness == Brightness.dark
      ? surfaceContainerLow
      : CafePalette.cream;

  /// Pale secondary panel / chip fill that used to be [CafePalette.latte].
  Color get latte => brightness == Brightness.dark
      ? surfaceContainerHigh
      : CafePalette.latte;

  /// Dark contrast block (badge, snackbar-ish panel) that used to be
  /// [CafePalette.espresso] — lightens in dark so it separates from the
  /// page rather than merging with it.
  Color get espresso => brightness == Brightness.dark
      ? surfaceContainerHighest
      : CafePalette.espresso;
}

class CafeGradients {
  /// Deep espresso → warm bronze: the signature header wash. Darker and
  /// richer than a flat brown so gold content on top feels lit from within.
  static const coffee = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3D2A1A), Color(0xFF9C7038)],
  );
  static const espresso = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A1E14), Color(0xFF5E4128)],
  );
  /// Polished-brass shimmer — reserved for the single most important moment
  /// on a screen (a hero total, a success celebration). Used sparingly so it
  /// stays special.
  static const gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF3DCA8), Color(0xFFD8A75A)],
  );
  // The category / status accents are deliberately tuned to a rich,
  // medium-deep value. Every one of these backs *white* content — the icon
  // in a StatCard or QuickActionTile chip, the title on a hero banner, a
  // chosen pill — and the old candy-bright stops put white at 1.7–2.7:1
  // (unreadable). Each end now sits in a luminance band where white clears
  // ~3.6–5.5:1: crisp to read, still fully saturated, and premium rather
  // than pastel. Hue variety is preserved so categories stay tellable apart,
  // and the deep end stays at the top-left (where hero text lives) to match
  // [coffee] and [espresso].
  static const sunrise = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA85A22), Color(0xFFC1741F)],
  );
  static const peach = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB5614A), Color(0xFFC1745C)],
  );
  static const mint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2F8A67), Color(0xFF3F9876)],
  );
  static const berry = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9E3F5B), Color(0xFFB45E74)],
  );
  static const sky = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B6FD0), Color(0xFF5488DF)],
  );

  /// Stable pick from a seed string so the same category/dish always gets
  /// the same color.
  static LinearGradient forSeed(Object seed) {
    const all = [coffee, sunrise, peach, mint, berry, sky];
    return all[seed.toString().hashCode.abs() % all.length];
  }
}

/// The one hairline colour for every soft edge in the app (borders,
/// dividers, scroll edges) so nothing ships three near-identical 5–6% black
/// line colours again.
class AppColors {
  static const hairline = Color(0x0F000000); // black @ 6%
}

/// 4pt spacing scale. Use these instead of raw [EdgeInsets] literals so
/// spacing stays on-grid across screens (Apple-style: everything relates).
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Corner-radius scale. Bigger surfaces read as thicker/rounder; small
/// controls stay tighter. Mirrors the theme (cards 18, inputs 14, dialogs 24).
class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 18;
  static const double xxl = 24;
  static const double pill = 999;
}

/// Three-level elevation scale: **bigger surface = thicker shadow**.
/// Replaces the ~28 ad-hoc `BoxShadow`s scattered through the app.
class AppShadow {
  /// Chips, pills, small controls resting on a surface.
  static const low = [
    BoxShadow(
      color: Color(0x0F000000), // black @ 6%
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Cards and tiles — the default for content surfaces.
  static const medium = [
    BoxShadow(
      color: Color(0x1A000000), // black @ 10%
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Floating/dominant surfaces: banners, docks, sheets.
  static const high = [
    BoxShadow(
      color: Color(0x24000000), // black @ 14%
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];
}

/// Size-specific tracking (WWDC "The Details of UI Typography").
///
/// Letter-spacing must never be one fixed value for all sizes:
/// - display text (≥20px) tightens as it grows (`-0.025em`),
/// - small text (≤13px) gets a slight positive bump for legibility,
/// - body sizes stay neutral.
///
/// Returns the `letterSpacing` to pair with [fontSize].
double trackFor(double fontSize) {
  if (fontSize >= 20) return -(fontSize * 0.025);
  if (fontSize <= 13) return fontSize * 0.02;
  return 0;
}

/// Frosted-glass chrome material — the app's one translucent surface.
///
/// Blurs whatever scrolls underneath (blur 20, the iOS "regular blur"
/// width), sits on a deep espresso semi-transparent tint, and catches the
/// light along its top edge with a faint hairline. The tint is dark (not
/// the old white glass) so the chrome reads as part of the espresso theme:
/// content slides under a subtle dark glass instead of a bright panel
/// cutting across the dark appearance. Use it for app chrome that content
/// scrolls *under* (role-shell app bar, bottom navigation) instead of
/// stacking opaque surfaces on opaque ones.
///
/// NB: iOS pairs the blur with a 180% saturation boost; Flutter's backdrop
/// API only exposes geometric `ImageFilter.matrix` (no colour matrix), so
/// the saturation stage is approximated by the blur + espresso tint.
class TranslucentBar extends StatelessWidget {
  const TranslucentBar({super.key, this.child});

  /// The bar's content. Defaults to expanding so the material fills the
  /// area it is given (e.g. an app bar's `flexibleSpace`).
  final Widget? child;

  /// The frost itself: blur of the backdrop, clipped to the bar.
  static final ui.ImageFilter _frost =
      ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      // Clip so the blur stays inside the bar instead of the whole scene.
      child: BackdropFilter(
        filter: _frost,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xD6100D09), // espresso @ 84% — the dark glass tint
            border: Border(
              top: BorderSide(
                color: Color(0x40FFFFFF), // faint light catching the top edge
                width: 0.5,
              ),
            ),
          ),
          child: child ?? const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// The one bottom-dock surface for every screen bottom: a single
/// [ColorScheme.surface] material with a single hairline edge — no shadow.
/// A dock is anchored to the screen edge, so separation comes from the edge
/// itself, not from stacked depth; floating bars *on* a dock (e.g.
/// [FloatingCartBar]) own their [AppShadow] instead.
class BottomSurface extends StatelessWidget {
  const BottomSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    this.safeArea = true,
  });

  final Widget child;

  /// Padding inside the dock (defaults to the grid: 16 / 12 / 16 / 16).
  final EdgeInsetsGeometry padding;

  /// Whether the dock pads itself around the home-indicator area.
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final dock = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: child,
    );
    return safeArea ? SafeArea(child: dock) : dock;
  }
}

/// Container height sized for 100% text scale but grown proportionally with
/// the OS text size. For fixed-axis containers (horizontal strips, bottom
/// bars) that would otherwise clip their labels at accessibility font sizes.
double scaledMinHeight(BuildContext context, double base) =>
    base * MediaQuery.textScalerOf(context).scale(1);

/// Minimum `NavigationBar` height: the app's 68px footprint at 100% text
/// scale, grown with the OS text size so destination labels are never
/// clipped at accessibility font sizes.
double navBarMinHeight(BuildContext context) =>
    scaledMinHeight(context, 68);

/// Emoji stand-ins for food/drink art — offline-safe "images" for items
/// without photos.
String categoryEmoji(String category) {
  final c = category.toLowerCase().replaceAll('_', ' ');
  if (c.contains('coffee') || c.contains('espresso') || c.contains('latte')) {
    return '☕';
  }
  if (c.contains('tea') || c.contains('chai')) return '🍵';
  if (c.contains('cold') || c.contains('drink') || c.contains('juice')) {
    return '🥤';
  }
  if (c.contains('shake') || c.contains('smoothie')) return '🥛';
  if (c.contains('farsan') || c.contains('snack') || c.contains('namkeen')) {
    return '🥟';
  }
  if (c.contains('sandwich') || c.contains('toast')) return '🥪';
  if (c.contains('pizza')) return '🍕';
  if (c.contains('burger')) return '🍔';
  if (c.contains('fries') || c.contains('chaat')) return '🍟';
  if (c.contains('dessert') || c.contains('sweet') || c.contains('cake')) {
    return '🍰';
  }
  if (c.contains('ice') || c.contains('kulfi')) return '🍨';
  if (c.contains('main') || c.contains('meal') || c.contains('thali')) {
    return '🍛';
  }
  if (c.contains('bread') || c.contains('bun') || c.contains('bakery')) {
    return '🥐';
  }
  return '🍽️';
}

String dishEmoji(String name, {String category = ''}) {
  final n = name.toLowerCase();
  const keywords = <String, String>{
    'coffee': '☕',
    'espresso': '☕',
    'cappuccino': '☕',
    'latte': '☕',
    'mocha': '☕',
    'cold coffee': '🧊',
    'americano': '☕',
    'chai': '🍵',
    'tea': '🍵',
    'green tea': '🍵',
    'masala': '🍵',
    'juice': '🧃',
    'cola': '🥤',
    'soda': '🥤',
    'lime': '🥤',
    'lemon': '🥤',
    'shake': '🥛',
    'lassi': '🥛',
    'milk': '🥛',
    'samosa': '🥟',
    'kachori': '🥟',
    'dhokla': '🟨',
    'khandvi': '🟨',
    'fafda': '🟨',
    'jalebi': '🍥',
    'gathiya': '🥨',
    'sev': '🥨',
    'khakhra': '🍘',
    'thepla': '🫓',
    'puff': '🥐',
    'sandwich': '🥪',
    'grill': '🥪',
    'toast': '🥪',
    'pizza': '🍕',
    'burger': '🍔',
    'fries': '🍟',
    'pasta': '🍝',
    'noodles': '🍜',
    'dosa': '🥞',
    'idli': '🍚',
    'vada': '🍩',
    'pav': '🍔',
    'bhel': '🥗',
    'chaat': '🥗',
    'pani puri': '🥣',
    'dabeli': '🥙',
    'vada pav': '🍔',
    'cake': '🍰',
    'pastry': '🍰',
    'brownie': '🍫',
    'chocolate': '🍫',
    'ice cream': '🍨',
    'kulfi': '🍨',
    'sweet': '🍬',
    'gulab': '🍡',
    'rasgulla': '🍡',
    'thali': '🍛',
    'curry': '🍛',
    'paneer': '🧆',
    'rice': '🍚',
    'roti': '🫓',
  };
  for (final entry in keywords.entries) {
    if (n.contains(entry.key)) return entry.value;
  }
  return categoryEmoji(category);
}

/// Top-down latte-art illustration: saucer, cup, crema, rosetta fern, beans.
///
/// The rosetta replaces an earlier plain heart. Both are drawn with the [art]
/// colour, so call sites that pass a translucent white for a watermark effect
/// keep working unchanged — only the shape inside the crema changed.
class LatteArtPainter extends CustomPainter {
  final Color cup;
  final Color crema;
  final Color art;
  final Color bean;
  final bool withBeans;

  LatteArtPainter({
    this.cup = const Color(0xFFFFF8F0),
    this.crema = const Color(0xFFC8956C),
    this.art = const Color(0xFFFFF8F0),
    this.bean = const Color(0xFF4E3626),
    this.withBeans = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.52);
    final radius = math.min(size.width, size.height) * 0.33;

    final saucer = Paint()..color = cup.withValues(alpha: 0.35);
    canvas.drawCircle(center, radius * 1.42, saucer);

    final cupPaint = Paint()..color = cup;
    canvas.drawCircle(center, radius * 1.18, cupPaint);

    final rim = Paint()
      ..color = cup.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, radius * 0.05);
    canvas.drawCircle(center, radius * 1.18, rim);

    final cremaPaint = Paint()..color = crema;
    canvas.drawCircle(center, radius, cremaPaint);

    final ring = Paint()
      ..color = Color.lerp(crema, const Color(0xFF000000), 0.12)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, radius * 0.06);
    canvas.drawCircle(center, radius * 0.94, ring);

    // The rosetta — the fern a barista free-pours. Drawn as a spine with
    // paired leaves that swell then taper, and a drag-through stem that
    // curls the tip, which is what makes a pour read as a rosetta rather
    // than a leaf. Subtle enough (used at low opacity) to sit behind the
    // hero numbers without competing with them, but with more craft than a
    // plain glyph.
    final ar = radius * 0.62;
    final top = center.dy - ar;
    final artPaint = Paint()..color = art;

    // One leaf: base sits on the spine, tip points outward-and-slightly-down
    // (a free-poured leaf always droops as the milk runs out). The two sides
    // bulge by *different* amounts — the upper/outer edge swells more than
    // the inner one — so each leaf reads as a rounded scallop rather than a
    // straight-sided spike.
    void leaf(Offset base, Offset tip, double bulgeOut, double bulgeIn) {
      final d = tip - base;
      if (d.distance < 0.5) return;
      // Perpendicular to the leaf axis, used to push the side curves out.
      final n = Offset(-d.dy, d.dx) / d.distance;
      final mid = base + d * 0.5;
      final p = Path()
        ..moveTo(base.dx, base.dy)
        // upper/outer side: big soft swell
        ..quadraticBezierTo(mid.dx + n.dx * bulgeOut, mid.dy + n.dy * bulgeOut,
            tip.dx, tip.dy)
        // inner side: shallower swell back to the base, closing the leaf
        ..quadraticBezierTo(mid.dx - n.dx * bulgeIn, mid.dy - n.dy * bulgeIn,
            base.dx, base.dy)
        ..close();
      canvas.drawPath(p, artPaint);
    }

    for (var i = 0; i < 5; i++) {
      final t = i / 4; // 0 = top (narrowest), 1 = base (widest)
      final y = top + ar * (0.16 + 0.70 * t);
      // Leaves grow toward the base and tilt downward as they do.
      final reach = ar * (0.42 + 0.40 * t);
      final droop = ar * (0.02 + 0.10 * t);
      final base = Offset(center.dx, y + ar * 0.05);
      final tipOut = Offset(center.dx - reach, y + droop);
      final bulge = ar * (0.085 + 0.05 * t);
      leaf(base, tipOut, bulge, bulge * 0.72);
      leaf(base, Offset(center.dx + reach, y + droop), bulge, bulge * 0.72);
    }

    // Stem: the drag-through that curls the fern's tip. Thin, round-capped.
    final stem = Paint()
      ..color = art
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, ar * 0.05)
      ..strokeCap = StrokeCap.round;
    final spine = Path()
      ..moveTo(center.dx, top + ar * 0.90)
      ..lineTo(center.dx, top + ar * 0.24)
      ..quadraticBezierTo(
          center.dx, top + ar * 0.04, center.dx + ar * 0.13, top + ar * 0.0);
    canvas.drawPath(spine, stem);

    if (withBeans) {
      void beanAt(Offset o, double r, double angle) {
        canvas.save();
        canvas.translate(o.dx, o.dy);
        canvas.rotate(angle);
        final p = Paint()..color = bean;
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset.zero, width: r * 2, height: r * 1.35),
            p);
        final crease = Paint()
          ..color = cup.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.28
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCenter(center: Offset.zero, width: r * 1.7, height: r * 1.0),
          0.6,
          2.0,
          false,
          crease,
        );
        canvas.restore();
      }

      beanAt(Offset(center.dx - radius * 1.62, center.dy + radius * 0.9),
          radius * 0.22, -0.5);
      beanAt(Offset(center.dx + radius * 1.66, center.dy - radius * 0.7),
          radius * 0.2, 0.7);
    }
  }

  @override
  bool shouldRepaint(covariant LatteArtPainter old) =>
      old.cup != cup ||
      old.crema != crema ||
      old.art != art ||
      old.bean != bean;
}

/// Outline cup-with-steam painter for empty states.
class CupOutlinePainter extends CustomPainter {
  final Color color;

  CupOutlinePainter({this.color = CafePalette.caramel});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, size.width * 0.02)
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    for (var i = 0; i < 3; i++) {
      final x = w * (0.38 + i * 0.12);
      final steam = Path()
        ..moveTo(x, h * 0.30)
        ..cubicTo(x - w * 0.06, h * 0.22, x + w * 0.06, h * 0.16, x, h * 0.08);
      canvas.drawPath(steam, stroke..color = color.withValues(alpha: 0.7));
    }

    final cup = Path()
      ..moveTo(w * 0.25, h * 0.40)
      ..lineTo(w * 0.29, h * 0.72)
      ..arcToPoint(
        Offset(w * 0.61, h * 0.72),
        radius: Radius.circular(w * 0.16),
        clockwise: false,
      )
      ..lineTo(w * 0.65, h * 0.40)
      ..close();
    canvas.drawPath(cup, stroke);

    final handle = Path()
      ..moveTo(w * 0.65, h * 0.46)
      ..arcToPoint(
        Offset(w * 0.78, h * 0.60),
        radius: Radius.circular(w * 0.09),
      )
      ..arcToPoint(
        Offset(w * 0.64, h * 0.66),
        radius: Radius.circular(w * 0.09),
      );
    canvas.drawPath(handle, stroke);

    canvas.drawLine(
        Offset(w * 0.20, h * 0.80), Offset(w * 0.72, h * 0.80), stroke);
  }

  @override
  bool shouldRepaint(covariant CupOutlinePainter old) => old.color != color;
}

/// Gradient hero surface with optional illustration behind content.
class HeroBanner extends StatelessWidget {
  final Gradient gradient;
  final Widget child;
  final Widget? illustration;
  final double? height;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  const HeroBanner({
    super.key,
    required this.gradient,
    required this.child,
    this.illustration,
    this.height,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? BorderRadius.circular(AppRadius.xxl);
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: r,
        boxShadow: AppShadow.high, // banners are the biggest surface → thickest
      ),
      child: Stack(
        children: [
          if (illustration != null)
            Positioned.fill(child: IgnorePointer(child: illustration!)),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Small colored icon chip used in cards and quick actions.
class IconChip extends StatelessWidget {
  final IconData icon;
  final Gradient? gradient;
  final Color? color;
  final double size;
  final double iconSize;

  const IconChip({
    super.key,
    required this.icon,
    this.gradient,
    this.color,
    this.size = 44,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    // Icon contrast must follow its backdrop: white over the saturated
    // gradient, espresso over a light solid (e.g. latte).
    final bg = color ?? CafePalette.latte;
    final onColor =
        bg.computeLuminance() > 0.5 ? CafePalette.espresso : Colors.white;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        color: color ?? CafePalette.latte,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: gradient != null ? AppShadow.medium : null,
      ),
      child: Icon(icon,
          size: iconSize,
          color: gradient != null ? Colors.white : onColor),
    );
  }
}

/// Emoji tile used where a photo is missing — gradient panel + big emoji.
class EmojiArtTile extends StatelessWidget {
  final String emoji;
  final Gradient? gradient;
  final double size;
  final double fontSize;

  /// Screen-reader name for the art ("Latte art"). When null the emoji is
  /// treated as decoration — the card or list tile it sits in already
  /// announces the item's name, so reading a second "coffee" adds noise.
  final String? semanticLabel;

  const EmojiArtTile({
    super.key,
    required this.emoji,
    this.gradient,
    this.size = 84,
    this.fontSize = 38,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      // Decorative by default: skip the emoji glyph in the a11y tree.
      excludeSemantics: semanticLabel == null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: gradient ?? CafeGradients.forSeed(emoji),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(emoji, style: TextStyle(fontSize: fontSize)),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  // w700, not w800: hierarchy from weight + size as a set,
                  // without inflating every section header.
                  style:
                      text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: text.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Apple-style **material** panel — a surface that reads as a physical sheet
/// lit from above rather than flat paint. The fill lifts faintly top-to-bottom
/// (light falling onto the material), the top edge catches a brighter hairline
/// (Apple's "light grazing the surface" cue) while the sides stay soft, and a
/// shadow grounds it. Bigger surfaces should read as *thicker* material, so
/// pass a heavier [shadow] — see [AppShadow]'s low → medium → high scale.
class MaterialPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Gradient? fill;
  final List<BoxShadow>? shadow;

  const MaterialPanel({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppRadius.xl,
    this.fill,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    // Soft hairline all round: definition against the page without boxing the
    // panel in. (Flutter only allows ONE colour on a rounded border, so the
    // lit top edge is painted below as its own clipped strip — same look, and
    // valid in debug/tests as well as release.)
    final hairline = dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.07);
    return Container(
      decoration: BoxDecoration(
        gradient: fill ??
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.surfaceContainerHigh, // lit from above
                scheme.surfaceContainer, // resting base
              ],
            ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: hairline),
        boxShadow: shadow ?? AppShadow.low,
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Light grazing the top edge — the crispest cue that this is a solid
          // sheet of material, easing into the rounded corners and fading out
          // before it reaches them.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(radius)),
              child: SizedBox(
                height: 1.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: dark ? 0.30 : 0.85),
                      Colors.white.withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          if (padding != null)
            Padding(padding: padding!, child: child)
          else
            child,
        ],
      ),
    );
  }
}

/// KPI card with a colored accent — used on dashboards.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Gradient gradient;
  final String? caption;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return MaterialPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconChip(icon: icon, gradient: gradient, size: 42, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (caption != null)
                  Text(caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                          fontSize: 11,
                          letterSpacing: trackFor(11),
                          color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable quick-action tile: gradient icon + label, dressed as a material
/// panel. It answers the pointer **on contact** — the tile dips to 0.97 the
/// instant it's pressed ("highlight on pointer-down, commit on pointer-up"),
/// then eases back as the tap commits. Under reduced motion the scale becomes
/// a plain opacity dip, so the feedback stays without the motion.
class QuickActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback? onTap;
  final String? badge;

  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.gradient,
    this.onTap,
    this.badge,
  });

  @override
  State<QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<QuickActionTile> {
  bool _pressed = false;

  void _press(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reduced = AppMotion.reducedOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed && !reduced ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _pressed && reduced ? 0.78 : 1.0,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: MaterialPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                IconChip(
                    icon: widget.icon,
                    gradient: widget.gradient,
                    size: 40,
                    iconSize: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    // One line always: with a badge present, a second line
                    // would break a short label mid-word ("Billi/ng") on a
                    // phone-width tile.
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style:
                        text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.gradient.colors.last
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(widget.badge!,
                        style: text.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: widget.gradient.colors.last)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Friendly empty/error state with the cup illustration.
class EmptyStateArt extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? action;
  final IconData? icon;

  const EmptyStateArt({
    super.key,
    required this.title,
    this.message,
    this.action,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 110,
              child: CustomPaint(
                painter: CupOutlinePainter(
                  color: scheme.primary.withValues(alpha: 0.55),
                ),
                child: icon == null
                    ? null
                    : Center(
                        child: Icon(icon,
                            size: 22,
                            color: scheme.primary.withValues(alpha: 0.8))),
              ),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!,
                  textAlign: TextAlign.center,
                  style:
                      text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

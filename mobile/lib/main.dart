import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/api_client.dart';
import 'services/notification_service.dart';
import 'state/auth_state.dart';
import 'state/cart_state.dart';
import 'state/tenant_state.dart';
import 'widgets/ui_kit.dart';
import 'screens/auth/login_screen.dart';
import 'screens/ca/ca_shell.dart';
import 'screens/customer/menu_screen.dart';
import 'screens/owner/owner_shell.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/staff/staff_shell.dart';
import 'screens/kitchen/kitchen_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService.init();
  } catch (_) {
    // Notification setup failed — app still works, just no push alerts.
  }
  runApp(const CafeApp());
}

class CafeApp extends StatefulWidget {
  const CafeApp({super.key});

  @override
  State<CafeApp> createState() => _CafeAppState();
}

class _CafeAppState extends State<CafeApp> {
  // One session / one branding holder for the whole app: they must survive
  // rebuilds, so they live here (not recreated inside build()).
  late final ApiClient _api = ApiClient();
  late final AuthState _auth = AuthState(_api);
  late final TenantState _tenant = TenantState(_api)..attach(_auth);

  @override
  void initState() {
    super.initState();
    // Restores the stored session (and, with it, the cafe code); branding
    // then follows via [TenantState.attach]. Best effort: it never blocks
    // or throws, it just leaves the headers unbranded on failure.
    unawaited(_auth.load());
  }

  @override
  void dispose() {
    _tenant.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _api),
        ChangeNotifierProvider(create: (_) => CartState()),
        ChangeNotifierProvider<AuthState>.value(value: _auth),
        ChangeNotifierProvider<TenantState>.value(value: _tenant),
      ],
      child: MaterialApp(
        title: 'Cafe POS',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        // "Dark & Premium": the app owns a deep-espresso, gold-accented
        // appearance instead of following the OS. It reads upscale in a dim
        // cafe and keeps this hero look identical on every device.
        themeMode: ThemeMode.dark,
        home: const RootGate(),
      ),
    );
  }
}

/// Dark appearance — the app's hero look: a deep, warm espresso ladder with
/// a single polished-brass accent.
///
/// Premium here means restraint. The surfaces are warm near-blacks (never
/// pure black, so the steps above them stay visible), depth comes from a
/// clear five-step elevation ladder — cards visibly lift off the page
/// instead of merging into it — and gold is spent only where it earns
/// attention: primary actions, the nav indicator, key accents. Amber-washing
/// every surface would read as garish, not expensive.
ColorScheme _darkColorScheme(ColorScheme base) => base.copyWith(
      // Polished brass gold: the hero accent. Light enough to carry deep
      // espresso ink (onPrimary clears 8.9:1, so a filled CTA reads as
      // gold-on-ink) and rich enough to feel like metal, not neon.
      primary: const Color(0xFFE6B25A),
      onPrimary: const Color(0xFF221A0B),
      // Warm gold-tinted container: the selected nav pill and other
      // "active" wells. The selected icon/label is painted with
      // onSecondaryContainer (champagne) at 7.8:1 over this pill.
      primaryContainer: const Color(0xFF4A3C1E),
      onPrimaryContainer: const Color(0xFFF3DCA8),
      secondaryContainer: const Color(0xFF4A3C1E),
      onSecondaryContainer: const Color(0xFFF3DCA8),
      // Surface ladder (page background is set separately, in the theme).
      // Spaced to read as distinct elevations — the premium cue is that
      // each surface step is perceptibly one level above the one below it.
      surfaceContainerLowest: const Color(0xFF0B0906),
      surfaceContainerLow: const Color(0xFF17130D),
      surface: const Color(0xFF1E1811),
      surfaceContainer: const Color(0xFF1E1811),
      surfaceContainerHigh: const Color(0xFF282117),
      surfaceContainerHighest: const Color(0xFF332A1D),
      // Hairline / soft-edge line: warm white at low alpha, so one token
      // works on the page, on cards and on sheets alike. Slightly more
      // present than before so edges catch light against the deeper page.
      outlineVariant: const Color(0x33FFFFFF),
    );

/// Light appearance — a warm, premium counterpart so the app still reads as
/// considered if the appearance is ever flipped: ivory page, deep-bronze
/// accent. Bronze is dark enough to clear 5:1 on ivory, so links, labels and
/// filled buttons stay legible without going grey.
ColorScheme _lightColorScheme(ColorScheme base) => base.copyWith(
      primary: const Color(0xFF8A5D26),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFEEDFC4),
      onPrimaryContainer: const Color(0xFF3A2A12),
      // Nav selection: a pale-gold pill with deep-bronze content on it, so
      // the active tab reads the same way it does in dark.
      secondaryContainer: const Color(0xFFEEDFC4),
      onSecondaryContainer: const Color(0xFF7A4F1F),
      outlineVariant: const Color(0x1A000000),
    );

/// Builds the app theme for [brightness].
///
/// Both appearances share one structure — typography tracking, radii,
/// button shapes, the quiet ink ripple — and differ only in tone: light is
/// cream-on-espresso ink, dark is a re-tinted hierarchy of warm
/// near-blacks with warm off-white text (never white-on-pure-black).
ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  const seed = CafePalette.coffee; // coffee brown
  final dark = brightness == Brightness.dark;
  final seedScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );
  final scheme = dark ? _darkColorScheme(seedScheme) : _lightColorScheme(seedScheme);
  // Deep espresso page background — near-black, but never pure black, so
  // the surface steps above it stay visible. Light is a warm ivory, never a
  // cool grey, so the coffee warmth survives in both appearances.
  final scaffoldBg = dark ? const Color(0xFF100D09) : const Color(0xFFF7F2E9);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  // One hairline token for every soft edge (borders, dividers) so the app
  // stops shipping three near-identical 5–6% black line colors.
  final hairline =
      dark ? const Color(0x1AFFFFFF) : const Color(0x0F000000); // white 10% / black 6%
  final softBorder = BorderSide(color: hairline);

  // Size-specific tracking on every text role (WWDC typography): display
  // sizes tighten, small labels gain legibility, body stays neutral. Styles
  // derived from `textTheme` (`.copyWith`) inherit this automatically.
  TextStyle? track(TextStyle? s) =>
      s?.fontSize == null ? s : s!.copyWith(letterSpacing: trackFor(s.fontSize!));
  final tt = base.textTheme;
  final ramp = tt.copyWith(
    displayLarge: track(tt.displayLarge),
    displayMedium: track(tt.displayMedium),
    displaySmall: track(tt.displaySmall),
    headlineLarge: track(tt.headlineLarge),
    headlineMedium: track(tt.headlineMedium),
    headlineSmall: track(tt.headlineSmall),
    titleLarge: track(tt.titleLarge),
    titleMedium: track(tt.titleMedium),
    titleSmall: track(tt.titleSmall),
    bodyLarge: track(tt.bodyLarge),
    bodyMedium: track(tt.bodyMedium),
    bodySmall: track(tt.bodySmall),
    labelLarge: track(tt.labelLarge),
    labelMedium: track(tt.labelMedium),
    labelSmall: track(tt.labelSmall),
  );

  return base.copyWith(
    textTheme: ramp,
    scaffoldBackgroundColor: scaffoldBg,
    // Warm coffee hover/focus tint so cards and tiles feel alive on
    // pointer devices instead of the default neutral grey wash. On dark the
    // same brown needs more alpha to register at all — a 6–12% tint of a
    // colour *darker* than the surface is invisible on espresso.
    hoverColor: dark ? const Color(0x2E6F4E37) : const Color(0x146F4E37),
    focusColor: dark ? const Color(0x406F4E37) : const Color(0x1F6F4E37),
    highlightColor: dark ? const Color(0x1F6F4E37) : const Color(0x0F6F4E37),
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldBg,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      // Scroll-edge feedback for every plain AppBar, theme-wide: a soft
      // shadow (same weight as the card-scale [AppShadow.medium]) fades in
      // when content scrolls under the bar. M3 tracks the primary
      // scrollable; the role shells drive their own hairline because their
      // bars are translucent chrome.
      scrolledUnderElevation: 2,
      shadowColor: AppShadow.medium.first.color,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: track(base.textTheme.titleLarge)?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      // Clip once at the theme level: 129 Card sites, only 9 of which
      // remembered to clip — ink/highlight now stays inside rounded corners.
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: softBorder,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      // Fields read as sunken wells on cream; on espresso they must go the
      // other way (lighter than the card) or they vanish into it.
      fillColor:
          dark ? scheme.surfaceContainerHighest : const Color(0xFFFAF9F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      prefixIconColor: scheme.onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: softBorder,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      // No fixed height here: the shells pass a scale-aware minimum
      // (navBarMinHeight) so destination labels grow with the OS text size
      // instead of being clipped inside a 68px box.
      elevation: 0,
      // Frosted chrome: the four role shells wrap their NavigationBar in a
      // [TranslucentBar] (blur + light glass tint + bright top edge), so the
      // bar's own background stays transparent and content slides under a
      // light glass surface instead of hitting an opaque wall.
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      // Selected: a warm gold pill (primaryContainer) with a bright-gold
      // icon/label on it — M3 paints the selected content with
      // onSecondaryContainer, so that role is set to champagne in the scheme.
      // Unselected stays a quiet on-surface grey.
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? scheme.surfaceContainerHigh : scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? scheme.surfaceContainerHigh : scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? scheme.primary : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primaryContainer
            : dark
                ? const Color(0x2EFFFFFF) // white @ 18%
                : Colors.black.withValues(alpha: 0.1),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: hairline,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      iconColor: scheme.onSurfaceVariant,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      // Espresso on cream; a *lifted* espresso on the dark page, so the
      // toast still separates from a background that is already near-black.
      backgroundColor: dark ? const Color(0xFF3A3026) : const Color(0xFF4E3626),
      contentTextStyle: TextStyle(
        color: dark ? const Color(0xFFF5F0EA) : Colors.white,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    // Quiet ink ripple instead of M3 sparkle: Apple-style feedback is a
    // calm highlight, not a burst of particles.
    splashFactory: InkRipple.splashFactory,
  );
}

/// A table-QR deep link parsed from the launch URL.
///
/// Cards encode `{base}/t/<slug>/table/<n>` (tenant-scoped) and the legacy
/// format `{base}/table/<n>` (default tenant); a web host may mount the app
/// under a path prefix, so the pattern is matched off the path's tail.
class QrDeepLink {
  const QrDeepLink({this.tenant, required this.tableNumber});

  /// Cafe code from the URL, or null for a legacy (default-tenant) card.
  final String? tenant;

  /// Table number the card belongs to.
  final String tableNumber;
}

/// Parses `Uri.base` on web: `/t/<slug>/table/<n>` -> scoped cafe code,
/// `/table/<n>` -> legacy default tenant. The route is matched off the
/// path's tail (a web host may mount the app under a prefix) and, when the
/// path has no match, off the fragment, for hash-based hosting.
/// Returns null for every other URL (and on native platforms, where
/// Android/iOS deep links are still a documented gap — no plugin is wired
/// up yet).
QrDeepLink? parseQrDeepLink(Uri uri) {
  try {
    final direct = _parseQrPath(uri.pathSegments);
    if (direct != null) return direct;
    final fragment = uri.fragment;
    if (fragment.isEmpty) return null;
    return _parseQrPath(Uri.parse(fragment).pathSegments);
  } catch (_) {
    return null; // Malformed URL — never let a QR link break startup.
  }
}

QrDeepLink? _parseQrPath(List<String> pathSegments) {
  final segments =
      pathSegments.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  final tableAt = segments.indexOf('table');
  if (tableAt < 0 || tableAt + 1 >= segments.length) return null;
  final tableNumber = segments[tableAt + 1];
  // Keep the match tight: an unrecognised token (a file name, a slug with
  // dots, an over-long path fragment) must never hijack the app.
  if (!RegExp(r'^[0-9A-Za-z_-]{1,16}$').hasMatch(tableNumber)) {
    return null;
  }
  final scoped = tableAt >= 2 && segments[tableAt - 2] == 't';
  return QrDeepLink(
    tenant: scoped ? segments[tableAt - 1] : null,
    tableNumber: tableNumber,
  );
}

/// Evaluated once, lazily: the QR deep link the app was launched with.
/// Native platforms always resolve to null (see [parseQrDeepLink]).
final QrDeepLink? qrLaunchDeepLink = kIsWeb ? parseQrDeepLink(Uri.base) : null;

/// Login-first routing: logged out -> login; owner/staff/kitchen -> their
/// shell; cafe_ca (read-only CA) -> the accounting-bridge shell.
///
/// A table-QR deep link skips all of that: the customer self-order flow is
/// public, so `/t/<slug>/table/<n>` opens straight into the menu for that
/// cafe without asking anyone to sign in.
///
/// Smooth login→shell transition: [AnimatedSwitcher] cross-fades between
/// screens (Apple-style: the outgoing screen fades out while the incoming
/// one fades in, so there is never a blank frame). Every state carries a
/// distinct key so the switcher animates exactly when the visible screen
/// changes — and, crucially, the first screen is shown at full opacity
/// instead of being trapped behind a fade that starts at zero.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  @override
  Widget build(BuildContext context) {
    final qr = qrLaunchDeepLink;
    if (qr != null) {
      // Public self-order flow — no auth gate, straight into the menu.
      return CustomerMenuScreen(tenant: qr.tenant, tableNumber: qr.tableNumber);
    }

    final auth = context.watch<AuthState>();

    final Widget screen;
    if (auth.loading) {
      screen = const Scaffold(
        key: ValueKey('loading'),
        body: Center(child: CircularProgressIndicator()),
      );
    } else if (!auth.isLoggedIn) {
      screen = const LoginScreen(key: ValueKey('login'));
    } else if (auth.isAdmin) {
      screen = const AdminShell(key: ValueKey('admin'));
    } else if (auth.isOwner) {
      screen = const OwnerShell(key: ValueKey('owner'));
    } else if (auth.role == 'cafe_ca') {
      screen = const CaShell(key: ValueKey('ca'));
    } else if (auth.isKitchen) {
      screen = const KitchenShell(key: ValueKey('kitchen'));
    } else {
      screen = const StaffShell(key: ValueKey('staff'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: screen,
    );
  }
}

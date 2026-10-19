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
        // Follow the OS appearance (Apple-style: dark mode is a system
        // decision, never an in-app toggle).
        themeMode: ThemeMode.system,
        home: const RootGate(),
      ),
    );
  }
}

/// Dark-appearance overrides on top of the seed-derived scheme.
///
/// The coffee seed already gives the dark palette its warmth — what it
/// lacks is *hierarchy* and *restraint*:
///  - Material's dark ramp compresses every surface into near-identical
///    near-blacks, so nothing reads as elevated. We widen it into a five
///    step espresso ladder: page < card < sheet < input, each step lighter
///    as it comes forward.
///  - The derived primary is a glare-prone peach; the dark brand brown is a
///    muted latte instead.
///  - Hairlines flip from black-alpha to white-alpha — a black line simply
///    disappears against an espresso surface.
ColorScheme _darkColorScheme(ColorScheme base) => base.copyWith(
      // Muted, softened coffee: light enough to carry dark text and to
      // read as a foreground, desaturated enough not to glare.
      primary: const Color(0xFFD9AE8E),
      // Surface ladder (page background is set separately, in the theme).
      surfaceContainerLowest: const Color(0xFF100D09),
      surfaceContainerLow: const Color(0xFF1C1712),
      surface: const Color(0xFF231D17),
      surfaceContainer: const Color(0xFF231D17),
      surfaceContainerHigh: const Color(0xFF2C251D),
      surfaceContainerHighest: const Color(0xFF352D25),
      // Hairline / soft-edge line: white at low alpha, so one token works
      // on the page, on cards and on sheets alike.
      outlineVariant: const Color(0x2EFFFFFF),
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
  final scheme = dark ? _darkColorScheme(seedScheme) : seedScheme;
  // Deep espresso page background — near-black, but never pure black, so
  // the surface steps above it stay visible.
  final scaffoldBg = dark ? const Color(0xFF17120E) : CafePalette.cream;
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
/// Smooth login→shell transition: when the user logs in, the shell screens
/// fade in from the login screen (Apple-style: a gentle spring fade, not a
/// hard tree swap).
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..value = 0;
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(covariant RootGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Detect login state change and trigger fade-in
    if (oldWidget != widget) {
      final auth = context.read<AuthState>();
      if (!_isLoggedIn && auth.isLoggedIn) {
        _fadeController.forward();
      } else if (_isLoggedIn && !auth.isLoggedIn) {
        _fadeController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qr = qrLaunchDeepLink;
    if (qr != null) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: CustomerMenuScreen(tenant: qr.tenant, tableNumber: qr.tableNumber),
      );
    }
    final auth = context.watch<AuthState>();
    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isLoggedIn) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: const LoginScreen(),
      );
    }
    // Store login state for transition detection
    if (!_isLoggedIn) {
      setState(() => _isLoggedIn = true);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: auth.isAdmin
          ? const AdminShell()
          : auth.isOwner
              ? const OwnerShell()
              : auth.role == 'cafe_ca'
                  ? const CaShell()
                  : auth.isKitchen
                      ? const KitchenShell()
                      : const StaffShell(),
    );
  }
}

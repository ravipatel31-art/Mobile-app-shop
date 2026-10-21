// Generates marketing screenshots (goldens) of the real app UI with real
// fonts loaded. Run with:
//   flutter test test/generate_demo_shots_test.dart --update-goldens
// Output: test/goldens/*.png (full-res source). Publish with:
//   python3 tools/build_screenshots.py   (writes docs/screens/*.webp)
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:cafe_app/main.dart';
import 'package:cafe_app/models/menu_item.dart';
import 'package:cafe_app/screens/admin/dashboard_screen.dart';
import 'package:cafe_app/screens/admin/orders_queue_screen.dart';
import 'package:cafe_app/screens/auth/login_screen.dart';
import 'package:cafe_app/screens/customer/cart_screen.dart';
import 'package:cafe_app/screens/customer/customer_cart.dart';
import 'package:cafe_app/screens/customer/menu_screen.dart';
import 'package:cafe_app/screens/kitchen/kitchen_display_screen.dart';
import 'package:cafe_app/screens/owner/billing_screen.dart';
import 'package:cafe_app/screens/owner/staff_screen.dart';
import 'package:cafe_app/services/api_client.dart';
import 'package:cafe_app/state/auth_state.dart';
import 'package:cafe_app/state/cart_state.dart';
import 'package:cafe_app/state/tenant_state.dart';
import 'package:cafe_app/widgets/shell_app_bar.dart';

const _fontsDir = '/opt/aquaos/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  Future<void> face(String family, String path) async {
    final data = File(path).readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(data.buffer)));
    await loader.load();
  }

  // Roboto family (weights used by the app theme).
  await face('Roboto', '$_fontsDir/Roboto-Regular.ttf');
  await face('Roboto', '$_fontsDir/Roboto-Medium.ttf');
  await face('Roboto', '$_fontsDir/Roboto-Bold.ttf');
  await face('Roboto', '$_fontsDir/Roboto-Black.ttf');
  // Material icons.
  await face('MaterialIcons', '$_fontsDir/MaterialIcons-Regular.otf');
  // DejaVu Sans provides the ₹ glyph (per-glyph fallback).
  await face('DejaVu', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
  // Colour emoji (🧾 ☕ …) exactly as iPhones render them — without this the
  // chips in the dashboard headline fall back to tofu boxes.
  await face(
      'Noto Color Emoji', '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf');
}

/// The shipped app is dark-only (ThemeMode.dark) — match it so the shots show
/// the product as customers actually see it.
///
/// Two test-only font fixes, both invisible on a device (where a null family
/// simply resolves to the system font):
///  • theme text gets an explicit Roboto family + emoji fallback, and
///  • button themes are pinned too — buttons *replace* the ambient
///    DefaultTextStyle with their own `styleFrom(textStyle:)` (null family),
///    and in the test engine that default family is "Ahem" (every glyph a
///    filled box), which is what turned labels into white bars.
ThemeData _shotTheme() {
  const fallback = ['Noto Color Emoji', 'DejaVu'];
  ButtonStyle pinFont(ButtonStyle? style) {
    final base = style ?? const ButtonStyle();
    return base.copyWith(
      textStyle: WidgetStatePropertyAll(
        (base.textStyle?.resolve(const <WidgetState>{}) ?? const TextStyle())
            .copyWith(fontFamily: 'Roboto', fontFamilyFallback: fallback),
      ),
    );
  }

  final theme = buildAppTheme(brightness: Brightness.dark);
  return theme.copyWith(
    textTheme: theme.textTheme.apply(
      fontFamily: 'Roboto',
      fontFamilyFallback: fallback,
    ),
    filledButtonTheme:
        FilledButtonThemeData(style: pinFont(theme.filledButtonTheme.style)),
    elevatedButtonTheme:
        ElevatedButtonThemeData(style: pinFont(theme.elevatedButtonTheme.style)),
    outlinedButtonTheme:
        OutlinedButtonThemeData(style: pinFont(theme.outlinedButtonTheme.style)),
    textButtonTheme:
        TextButtonThemeData(style: pinFont(theme.textButtonTheme.style)),
  );
}

// ---------------------------------------------------------------------------
// Fixtures — realistic café data, dated relative to "today" so nothing on
// screen ever looks stale.
// ---------------------------------------------------------------------------

String _date(int daysAgo) {
  final d = DateTime.now().subtract(Duration(days: daysAgo));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';
}

String _ago(int minutes) =>
    DateTime.now().subtract(Duration(minutes: minutes)).toIso8601String();

/// One order in the exact shape `CafeOrder.fromJson` expects. Prices are in
/// paise (₹180 = 18000). `items` rows: [name, category, qty, unit price].
Map<String, dynamic> _order({
  required String id,
  required String status,
  required int minutesAgo,
  required String customer,
  String? table,
  required List<List<Object>> items,
  bool paid = false,
  String method = 'upi',
  String takenBy = 'priya',
  String pickup = 'counter',
}) {
  final lines = <Map<String, dynamic>>[];
  var sub = 0;
  for (final it in items) {
    final qty = it[2] as int;
    final line = (it[3] as int) * qty;
    sub += line;
    lines.add({
      'name': it[0],
      'category': it[1],
      'qty': qty,
      'unit_price': it[3],
      'line_total': line,
      'selected_options': <dynamic>[],
      'taxable_value': line,
      'cgst': line ~/ 40, // 5% GST, split 2.5 + 2.5
      'sgst': line ~/ 40,
      'gst_rate': 5,
      'hsn_code': '9963',
    });
  }
  final tax = sub ~/ 20; // 5%
  return {
    'id': id,
    'items': lines,
    'total': sub + tax,
    'customer': {'name': customer, 'phone': null},
    'pickup_type': pickup,
    'table_number': table,
    'status': status,
    'created_at': _ago(minutesAgo),
    'notes': '',
    'taken_by': takenBy,
    'payment_method': method,
    'payment_status': paid ? 'paid' : 'unpaid',
    'paid_amount': paid ? sub + tax : 0,
    // A UPI-style reference only for paid UPI bills — cash/card show no ref
    // (matches how the billing screen prints "GPay ref …").
    'payment_token': (paid && method == 'upi') ? '839214750183' : null,
    'sub_total': sub,
    'tax_total': tax,
    'payments': paid
        ? [
            {'method': method, 'amount': sub + tax, 'at': _ago(minutesAgo)}
          ]
        : <Map<String, dynamic>>[],
  };
}

/// Live floor: five orders across received / preparing / ready so the kitchen
/// and queue screens have a busy, believable default view.
List<Map<String, dynamic>> _liveOrders() => [
      _order(
        id: 'o_1041',
        status: 'received',
        minutesAgo: 2,
        customer: 'Asha',
        table: '4',
        items: [
          ['Latte', 'coffee', 2, 18000],
          ['Butter Croissant', 'pastries', 1, 14000],
        ],
      ),
      _order(
        id: 'o_1040',
        status: 'preparing',
        minutesAgo: 7,
        customer: 'Rahul',
        pickup: 'takeaway',
        items: [
          ['Americano', 'coffee', 1, 16000],
          ['Masala Chai', 'tea', 2, 5000],
        ],
      ),
      _order(
        id: 'o_1039',
        status: 'preparing',
        minutesAgo: 14,
        customer: 'Guest',
        table: '7',
        items: [
          ['Cappuccino', 'coffee', 2, 17000],
          ['Avocado Toast', 'food', 1, 22000],
        ],
      ),
      _order(
        id: 'o_1038',
        status: 'ready',
        minutesAgo: 5,
        customer: 'Meera',
        pickup: 'takeaway',
        paid: true,
        method: 'cash',
        items: [
          ['Filter Coffee', 'coffee', 2, 6000],
          ['Samosa', 'food', 2, 4000],
        ],
      ),
      _order(
        id: 'o_1037',
        status: 'received',
        minutesAgo: 1,
        customer: 'Guest',
        table: '2',
        items: [
          ['Cold Brew', 'coffee', 1, 20000],
          ['Chocolate Brownie', 'pastries', 1, 16000],
        ],
      ),
    ];

/// Today's headline — ₹18,450 across 64 orders reads like a real café.
Map<String, dynamic> _daily() => {
      'date': _date(0),
      'order_count': 64,
      'gross_sales': 1845000,
      'by_category': {
        'coffee': 986000,
        'tea': 184000,
        'pastries': 372000,
        'food': 303000,
      },
      'by_payment': {'cash': 680000, 'card': 450000, 'upi': 715000},
      'top_items': [
        {'name': 'Latte', 'qty': 42, 'revenue': 756000},
        {'name': 'Cappuccino', 'qty': 24, 'revenue': 408000},
        {'name': 'Butter Croissant', 'qty': 27, 'revenue': 378000},
        {'name': 'Avocado Toast', 'qty': 13, 'revenue': 286000},
        {'name': 'Masala Chai', 'qty': 31, 'revenue': 155000},
      ],
    };

/// Seven-day range ending today — feeds the trend chart + "peak day" card.
List<Map<String, dynamic>> _range() {
  const gross = [1420000, 1680000, 1510000, 1795000, 1630000, 2040000, 1845000];
  const orders = [48, 57, 51, 61, 55, 70, 64];
  return [
    for (var i = 6; i >= 0; i--)
      {
        'date': _date(i),
        'order_count': orders[6 - i],
        'gross_sales': gross[6 - i],
        'by_category': {
          'coffee': gross[6 - i] ~/ 2,
          'tea': gross[6 - i] ~/ 10,
          'pastries': gross[6 - i] ~/ 5,
          'food': gross[6 - i] ~/ 5,
        },
        // UPI-led split (real cafés collect most on UPI/GPay). The three sum
        // back to gross exactly: upi + card + cash = gross.
        'by_payment': (() {
          final upi = gross[6 - i] * 39 ~/ 100;
          final card = gross[6 - i] ~/ 4;
          return {'upi': upi, 'cash': gross[6 - i] - upi - card, 'card': card};
        })(),
        'top_items': <Map<String, dynamic>>[],
      },
  ];
}

/// Billing: two days, one with dues outstanding so the gold "Mark paid"
/// buttons and the "needs collecting" chip are on screen.
Map<String, dynamic> _billing() => {
      'summary': {
        'order_count': 122,
        'total': 3465000,
        'paid': 3341000,
        'unpaid': 124000,
      },
      'days': [
        {
          'date': _date(0),
          'order_count': 64,
          'total': 1845000,
          'paid': 1721000,
          'unpaid': 124000,
          'by_payment': {'cash': 680000, 'card': 450000, 'upi': 715000},
          'orders': _liveOrders(),
        },
        {
          'date': _date(1),
          'order_count': 58,
          'total': 1620000,
          'paid': 1620000,
          'unpaid': 0,
          'by_payment': {'cash': 540000, 'card': 480000, 'upi': 600000},
          'orders': [
            _order(
              id: 'o_1030',
              status: 'completed',
              minutesAgo: 1500,
              customer: 'Guest',
              table: '3',
              paid: true,
              method: 'cash',
              items: [
                ['Latte', 'coffee', 2, 18000],
                ['Samosa', 'food', 2, 4000],
              ],
            ),
            _order(
              id: 'o_1031',
              status: 'completed',
              minutesAgo: 1450,
              customer: 'Vikram',
              table: '1',
              paid: true,
              method: 'card',
              items: [
                ['Club Sandwich', 'food', 1, 18000],
                ['Cold Brew', 'coffee', 1, 20000],
              ],
            ),
          ],
        },
      ],
    };

Map<String, dynamic> _alert(String item, int qty, int reorder, String unit) => {
      'item': item,
      'qty': qty,
      'reorder_level': reorder,
      'unit': unit,
      'out_of_stock': qty == 0,
    };

/// Customer menu — twelve real café items, `image_url: null` so the test
/// never touches the network for images.
List<Map<String, dynamic>> _menu() {
  Map<String, Object?> item(
          String id, String name, String desc, String cat, int price) =>
      {
        'id': id,
        'name': name,
        'description': desc,
        'category': cat,
        'base_price': price,
        'image_url': null,
        'available': true,
        'options': <dynamic>[],
        'gst_rate': 5,
        'hsn_code': '9963',
      };
  return [
    item('m1', 'Espresso', 'Single origin, thick crema', 'coffee', 9000),
    item('m2', 'Americano', 'Long black over hot water', 'coffee', 16000),
    item('m3', 'Latte', 'Silky milk, double shot', 'coffee', 18000),
    item('m4', 'Cappuccino', 'Classic foam crown', 'coffee', 17000),
    item('m5', 'Cold Brew', 'Steeped 18 hours, over ice', 'coffee', 20000),
    item('m6', 'Masala Chai', 'Cardamom, ginger, jaggery', 'tea', 5000),
    item('m7', 'Green Tea', 'Whole leaf, light steep', 'tea', 6000),
    item('m8', 'Butter Croissant', 'Baked at 6am', 'pastries', 14000),
    item('m9', 'Chocolate Brownie', 'Dark chocolate, walnut', 'pastries', 16000),
    item('m10', 'Avocado Toast', 'Sourdough, chilli flakes', 'food', 22000),
    item('m11', 'Club Sandwich', 'Triple decker, fries on side', 'food', 18000),
    item('m12', 'Samosa', 'Two pieces, tamarind chutney', 'food', 4000),
  ];
}

/// Fake http.Client serving canned JSON for every endpoint the shot screens
/// actually call. Dates are computed at run-time — never stale.
class _FakeHttp extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    late final String body;
    if (path == '/admin/reports/daily') {
      body = jsonEncode(_daily());
    } else if (path == '/admin/reports/range') {
      body = jsonEncode(_range());
    } else if (path == '/admin/staff') {
      body = jsonEncode([
        {
          'username': 'owner',
          'name': 'Owner',
          'role': 'owner',
          'status': 'approved',
          'last_login': '${_date(0)}T08:00:00+00:00'
        },
        {
          'username': 'priya',
          'name': 'Priya Nair',
          'role': 'staff',
          'status': 'approved',
          'last_login': '${_date(0)}T09:15:00+00:00'
        },
        {
          'username': 'sam',
          'name': 'Sam Kulkarni',
          'role': 'kitchen',
          'status': 'approved',
          'last_login': '${_date(1)}T17:40:00+00:00'
        },
      ]);
    } else if (path == '/admin/billing') {
      body = jsonEncode(_billing());
    } else if (path == '/admin/inventory/alerts') {
      body = jsonEncode([
        _alert('Arabica Beans', 2, 5, 'kg'),
        _alert('Butter Croissant', 4, 10, 'piece'),
        _alert('Oat Milk', 1, 4, 'litre'),
      ]);
    } else if (path == '/orders') {
      body = jsonEncode(_liveOrders());
    } else if (path == '/public/menu') {
      body = jsonEncode(_menu());
    } else {
      body = '[]';
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

({ApiClient api, AuthState auth}) _session() {
  final api = ApiClient(client: _FakeHttp())..token = 't';
  final auth = AuthState(api)
    ..name = 'Owner'
    ..username = 'owner'
    ..role = 'owner';
  return (api: api, auth: auth);
}

/// Providers + dark MaterialApp, mirroring main.dart's wiring.
Widget _wrap(({ApiClient api, AuthState auth}) s, Widget home) =>
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: s.api),
        ChangeNotifierProvider<AuthState>.value(value: s.auth),
        ChangeNotifierProvider(create: (_) => CartState()),
        ChangeNotifierProvider<TenantState>.value(
          value: TenantState(s.api)..attach(s.auth),
        ),
      ],
      child: MaterialApp(
        theme: _shotTheme(),
        debugShowCheckedModeBanner: false,
        home: DefaultTextStyle(
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontFamilyFallback: ['Noto Color Emoji', 'DejaVu'],
          ),
          child: home,
        ),
      ),
    );

/// Owner/admin screen inside the standard shell (Scaffold + ShellAppBar).
Widget _shell(({ApiClient api, AuthState auth}) s, String title, Widget body) =>
    _wrap(
      s,
      Scaffold(
        appBar: ShellAppBar(
          title: title,
          userName: s.auth.name ?? 'Owner',
          onLogout: () {},
        ),
        body: body,
      ),
    );

/// Snap the surface to the page's full content height so a capture neither
/// clips mid-widget nor leaves dead space underneath. Re-measures after each
/// resize: a few screens (kitchen) report a short extent on the first pass
/// and settle to their true height only once re-laid out at the new size.
Future<void> _fitContent(WidgetTester tester) async {
  if (find.byType(Scrollable).evaluate().isEmpty) return;
  for (var pass = 0; pass < 3; pass++) {
    final pos =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    final full = pos.viewportDimension + pos.maxScrollExtent;
    if ((full - pos.viewportDimension).abs() < 1) return; // already fits
    await tester.binding.setSurfaceSize(
      Size(400, full.ceilToDouble()),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _shoot(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  setUp(() async {
    await _loadFonts();
  });

  testWidgets('login screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    await tester.pumpWidget(_wrap(_session(), const LoginScreen()));
    await tester.pumpAndSettle();
    await _shoot(tester, 'login');
  });

  // The landing-page hero + storyboard scenes 1 & 6: dashboard switched to
  // the 7-day view so the trend chart and delta pill are on screen.
  testWidgets('owner sales dashboard', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1180));
    final s = _session();
    await tester.pumpWidget(_shell(s, 'Sales', const DashboardScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    await _fitContent(tester);
    await _shoot(tester, 'hero');
  });

  testWidgets('orders queue', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1300));
    final s = _session();
    await tester.pumpWidget(
        _shell(s, 'Orders', const OrdersQueueScreen()));
    await tester.pumpAndSettle();
    await _fitContent(tester);
    await _shoot(tester, 'orders');
  });

  testWidgets('kitchen display', (tester) async {
    // Fixed height (not _fitContent): the kitchen ListView's maxScrollExtent
    // underreports here, so a hand-picked viewport that shows all four
    // tickets complete is more reliable than the auto-fit.
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    final s = _session();
    await tester.pumpWidget(
        _shell(s, 'Kitchen', const KitchenDisplayScreen()));
    await tester.pumpAndSettle();
    await _fitContent(tester);
    await _shoot(tester, 'kitchen');
  });

  testWidgets('billing & payments', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    final s = _session();
    await tester.pumpWidget(_shell(s, 'Billing', const BillingScreen()));
    await tester.pumpAndSettle();
    await _fitContent(tester);
    await _shoot(tester, 'billing');
  });

  testWidgets('customer qr menu', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    final s = _session();
    await tester.pumpWidget(
      _wrap(s, const CustomerMenuScreen(tableNumber: '4')),
    );
    await tester.pumpAndSettle();
    await _fitContent(tester);
    await _shoot(tester, 'menu');
  });

  // Scene 3 — the cart already filled, ready to check out.
  testWidgets('customer cart filled', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    final s = _session();
    final cart = CustomerCart(tableNumber: '4');
    MenuItem item(String id, String name, String cat, int price) => MenuItem(
          id: id,
          name: name,
          description: '',
          category: cat,
          basePrice: price,
          imageUrl: null,
          available: true,
          options: const [],
          gstRate: 5,
          hsnCode: '9963',
        );
    cart.add(item('m3', 'Latte', 'coffee', 18000), const [], 2);
    cart.add(item('m8', 'Butter Croissant', 'pastries', 14000), const [], 1);
    cart.add(item('m5', 'Cold Brew', 'coffee', 20000), const [], 1);
    await tester.pumpWidget(
      _wrap(s, CustomerCartScreen(cart: cart)),
    );
    await tester.pumpAndSettle();
    await _fitContent(tester);
    await _shoot(tester, 'cart');
  });

  testWidgets('owner staff management', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1180));
    final s = _session();
    await tester.pumpWidget(_shell(s, 'Staff', const StaffScreen()));
    await tester.pumpAndSettle();
    await _fitContent(tester);
    await _shoot(tester, 'staff');
  });
}

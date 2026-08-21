# Cafe App (Flutter)

Customer ordering + staff admin in one Flutter app, talking to the Flask/Floci
backend in `../backend`.

## Prerequisites

- Flutter SDK 3.10+ (`flutter --version`)
- The backend running (see `../backend/README.md`): Floci up, seeded, and
  `flask --app run run --debug` serving on port 5000.

## Run

```bash
cd mobile
flutter pub get
flutter run
```

### Pointing the app at your backend

`lib/config.dart` picks the base URL automatically:

- Android emulator → `http://10.0.2.2:5000` (host machine)
- iOS simulator / desktop → `http://localhost:5000`

On a physical phone, use your computer's LAN IP:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:5000
```

## Using the app (point-of-sale)

The app **opens to a login**. Seeded logins: `owner` / `cafe123`,
`priya` / `staff123` (approved staff), `sam` / `staff123` (pending).

**Staff** (two tabs):

- **Tables** — a grid of tables (green = empty, red = occupied). Tap an empty
  table to take an order: browse the menu → choose Size / Milk / Extras (price
  updates live) → review → "Place order for Table N". The table turns occupied.
  Tap an occupied table to view its order, advance its status, or free it.
- **Orders** — the live order queue.

**Owner** (five tabs): **Sales** (today's total, 7-day chart, categories, top
sellers, end-of-day summary), **Orders**, **Tables** (add/remove tables, free
any table), **Staff** (approve pending sign-ups, add/remove staff, see who's
present via last login), **Menu** (add items, toggle sold-out, delete items).

New staff use "Request an account" on the login screen; they can't log in until
the owner approves them under the Staff tab.

## Structure

```
lib/
├── config.dart            # base URL, currency
├── main.dart              # app + RootGate (login / owner / staff)
├── models/                # MenuItem, Cart, Order, SalesSummary, CafeTable, StaffMember
├── services/api_client.dart
├── state/                 # auth (session in secure storage) + cart providers
├── screens/auth/          # login, register (staff request)
├── screens/owner/         # owner shell, staff mgmt, tables mgmt
├── screens/staff/         # staff shell, table grid, take order, order cart
├── screens/admin/         # shared owner tabs: dashboard, orders queue, menu editor
├── screens/customer/      # item_detail (reused); others deprecated/empty
└── widgets/menu_image.dart
```

Money is handled in minor units (paise/cents) end-to-end and formatted for
display; order totals shown at checkout are recomputed and confirmed by the
server.

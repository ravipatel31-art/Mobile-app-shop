import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_state.dart';
import '../../widgets/shell_app_bar.dart';
import '../admin/dashboard_screen.dart';
import '../admin/inventory_screen.dart';
import '../staff/ask_screen.dart';
import '../admin/menu_editor_screen.dart';
import '../admin/orders_queue_screen.dart';
import 'billing_screen.dart';
import 'reports_screen.dart';
import 'staff_screen.dart';
import 'tables_admin_screen.dart';
import 'vendor_message_screen.dart';

/// Owner container: 5 main tabs (Sales, Orders, Tables, Billing, Vendors)
/// plus a "More" menu for less-used screens (Reports, Staff, Menu, Inventory).
class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _index = 0;

  static const _titles = [
    'Sales',
    'Orders',
    'Tables',
    'Billing',
    'Vendors',
  ];

  final _pages = const [
    DashboardScreen(),
    OrdersQueueScreen(),
    TablesAdminScreen(),
    BillingScreen(),
    VendorMessageScreen(),
  ];

  void _openMoreMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'More Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.assessment),
              title: const Text('Reports'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Staff'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaffScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('Menu Editor'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MenuEditorScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Inventory'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventoryScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthState>();
    final name = auth.name ?? auth.username ?? 'Owner';
    return Scaffold(
      appBar: ShellAppBar(
        title: _titles[_index],
        userName: name,
        onLogout: () => context.read<AuthState>().logout(),
        onAsk: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AskScreen())),
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          if (i == 4) {
            // "More" button
            _openMoreMenu();
          } else {
            setState(() => _index = i);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.table_restaurant_outlined),
            selectedIcon: Icon(Icons.table_restaurant),
            label: 'Tables',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Billing',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Vendors',
          ),
        ],
      ),
    );
  }
}

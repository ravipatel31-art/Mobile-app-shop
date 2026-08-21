import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_state.dart';
import '../../widgets/shell_app_bar.dart';
import '../admin/dashboard_screen.dart';
import '../admin/menu_editor_screen.dart';
import '../admin/orders_queue_screen.dart';
import 'billing_screen.dart';
import 'staff_screen.dart';
import 'tables_admin_screen.dart';

/// Owner container: Sales, Billing, Orders, Tables, Staff, Menu.
class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _index = 0;

  static const _titles = [
    'Sales', 'Billing', 'Orders', 'Tables', 'Staff', 'Menu',
  ];
  final _pages = const [
    DashboardScreen(),
    BillingScreen(),
    OrdersQueueScreen(),
    TablesAdminScreen(),
    StaffScreen(),
    MenuEditorScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthState>();
    final name = auth.name ?? auth.username ?? 'Owner';
    return Scaffold(
      appBar: ShellAppBar(
        title: _titles[_index],
        userName: name,
        onLogout: () => context.read<AuthState>().logout(),
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Sales'),
          NavigationDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale),
              label: 'Billing'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.table_restaurant_outlined),
              selectedIcon: Icon(Icons.table_restaurant),
              label: 'Tables'),
          NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Staff'),
          NavigationDestination(
              icon: Icon(Icons.restaurant_menu_outlined),
              selectedIcon: Icon(Icons.restaurant_menu),
              label: 'Menu'),
        ],
      ),
    );
  }
}

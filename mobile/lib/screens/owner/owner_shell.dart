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

/// Owner container with bottom navigation:
/// 5 main tabs + "More" overflow menu for less-used screens.
class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _index = 0;

  static const _titles = [
    'Dashboard',
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
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Text(
                    'More',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _MoreTile(
                    icon: Icons.assessment_outlined,
                    selectedIcon: Icons.assessment,
                    title: 'Reports',
                    subtitle: 'Sales analytics & P&L',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReportsScreen()),
                      );
                    },
                  ),
                  _MoreTile(
                    icon: Icons.people_outline,
                    selectedIcon: Icons.people,
                    title: 'Staff',
                    subtitle: 'Manage team members',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StaffScreen()),
                      );
                    },
                  ),
                  _MoreTile(
                    icon: Icons.restaurant_menu_outlined,
                    selectedIcon: Icons.restaurant_menu,
                    title: 'Menu',
                    subtitle: 'Edit menu items & prices',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MenuEditorScreen()),
                      );
                    },
                  ),
                  _MoreTile(
                    icon: Icons.inventory_outlined,
                    selectedIcon: Icons.inventory,
                    title: 'Inventory',
                    subtitle: 'Stock tracking',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const InventoryScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            tooltip: 'More',
            onPressed: _openMoreMenu,
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
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

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon,
    required this.selectedIcon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(icon, size: 24),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cafe_table.dart';
import '../../models/order.dart';
import '../../services/api_client.dart';
import '../../state/auth_state.dart';
import '../../state/cart_state.dart';
import '../../util/money.dart';
import '../../widgets/collect_order_flow.dart';
import 'customer_info_screen.dart';

/// Staff picks a table. Empty -> take an order. Occupied -> view/advance/free.
class TablesGridScreen extends StatefulWidget {
  const TablesGridScreen({super.key});

  @override
  State<TablesGridScreen> createState() => _TablesGridScreenState();
}

class _TablesGridScreenState extends State<TablesGridScreen> {
  List<CafeTable> _tables = [];
  Map<String, CafeOrder?> _orderCache = {}; // For checking who's serving the table
  bool _loading = true;
  String? _error;
  int _lastTablesTick = 0;
  CartState? _cart;

  @override
  void initState() {
    super.initState();
    _lastTablesTick = context.read<CartState>().tablesTick;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The grid stays alive inside the IndexedStack, so listen for newly placed
    // orders and refresh (the table should flip to occupied right away).
    final cart = context.read<CartState>();
    if (_cart != cart) {
      _cart?.removeListener(_onCartChanged);
      _cart = cart;
      cart.addListener(_onCartChanged);
    }
  }

  @override
  void dispose() {
    _cart?.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    final tick = context.read<CartState>().tablesTick;
    if (tick != _lastTablesTick) {
      _lastTablesTick = tick;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tables = await context.read<ApiClient>().fetchTables();
      _orderCache.clear();

      // Fetch all orders to check staff assignments
      final orders = await context.read<ApiClient>().fetchOrders();
      for (final order in orders) {
        if (order.id.isNotEmpty) {
          _orderCache[order.id] = order;
        }
      }

      if (!mounted) return;
      setState(() {
        _tables = tables;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _openTable(CafeTable t) async {
    if (t.isOccupied) {
      // Check if this table is being served by the current staff member.
      final order = t.orderId != null ? _orderCache[t.orderId] : null;
      final auth = context.read<AuthState>();
      final server = order?.takenBy ?? t.takenBy;
      final isOwner = auth.isOwner;
      final currentUsername = auth.username;
      // Locked = served by another staff member (owners can always manage).
      final locked = !isOwner &&
          server != null &&
          server.isNotEmpty &&
          server != currentUsername;

      await _showOccupied(t, order, locked: locked, server: server);
    } else {
      // Empty table - proceed to customer info
      await Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => CustomerInfoScreen(tableNumber: t.number)));
    }
    _load();
  }

  Future<void> _showOccupied(
    CafeTable t,
    CafeOrder? order, {
    required bool locked,
    String? server,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Table ${t.number}'),
              subtitle: Text(order == null
                  ? 'Order #${t.orderId ?? ''}'
                  : 'Order #${order.id} • ${order.status} • ${formatMoney(order.total)}'),
              trailing: server != null
                  ? Text('Served by $server',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54))
                  : null,
            ),
            if (order != null)
              ...order.items.map((l) => ListTile(
                    dense: true,
                    leading: Text('${l.qty}×'),
                    title: Text(l.name),
                    subtitle:
                        l.options.isEmpty ? null : Text(l.options.join(' · ')),
                    trailing: Text(formatMoney(l.lineTotal)),
                  )),
            const Divider(),
            if (locked) ...[
              const ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Locked'),
                subtitle: Text(
                    'This table is being served by another staff member. '
                    'Use the shared order queue to advance its order.'),
              ),
            ] else ...[
              if (order != null && order.status != 'collected')
                ListTile(
                  leading: const Icon(Icons.skip_next),
                  title: Text(_advanceLabel(order.status)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _advance(order);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Free table'),
                onTap: () async {
                  Navigator.pop(context);
                  await context.read<ApiClient>().freeTable(t.number);
                  _load();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _advanceLabel(String status) {
    switch (status) {
      case 'received':
        return 'Start preparing';
      case 'preparing':
        return 'Mark ready';
      case 'ready':
        return 'Collect & take payment';
      default:
        return 'Advance';
    }
  }

  Future<void> _advance(CafeOrder order) async {
    final idx = CafeOrder.flow.indexOf(order.status);
    if (idx < 0 || idx >= CafeOrder.flow.length - 1) return;
    final next = CafeOrder.flow[idx + 1];
    try {
      if (next == 'collected') {
        // Completing requires payment — the flow also runs Google Pay.
        final updated = await collectOrderAndPay(context, order);
        if (updated == null || !mounted) return; // cancelled or failed
      } else {
        await context.read<ApiClient>().updateOrderStatus(order.id, next);
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final occupiedFill = scheme.errorContainer.withValues(alpha: 0.4);
    final emptyFill = scheme.primaryContainer.withValues(alpha: 0.35);
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.all(12),
        children: _tables
            .map((t) => Card(
                  margin: const EdgeInsets.all(6),
                  color: t.isOccupied ? occupiedFill : emptyFill,
                  child: InkWell(
                    onTap: () => _openTable(t),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              t.isOccupied
                                  ? Icons.table_restaurant
                                  : Icons.table_restaurant_outlined,
                              size: 34,
                              color: t.isOccupied
                                  ? Colors.red.shade400
                                  : Colors.green.shade600,
                            ),
                            const SizedBox(height: 6),
                            Text('Table ${t.number}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                                t.isOccupied ? 'Occupied' : 'Tap to order',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black54)),
                            if (t.isOccupied && t.takenBy != null)
                              Text('Served by ${t.takenBy}',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.black45)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

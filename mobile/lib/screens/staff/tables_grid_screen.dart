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
  Map<String, CafeOrder?> _orderCache = {};
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
      final order = t.orderId != null ? _orderCache[t.orderId] : null;
      final auth = context.read<AuthState>();
      final server = order?.takenBy ?? t.takenBy;
      final isOwner = auth.isOwner;
      final currentUsername = auth.username;
      final locked = !isOwner &&
          server != null &&
          server.isNotEmpty &&
          server != currentUsername;

      await _showOccupied(t, order, locked: locked, server: server);
    } else {
      await Navigator.push(
          context,
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
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
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
            // ── Header ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: t.isOccupied
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.table_restaurant_rounded,
                      color: t.isOccupied
                          ? Colors.red.shade400
                          : Colors.green.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Table ${t.number}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (order != null)
                          Text(
                            'Order #${order.id} • ${order.status} • ${formatMoney(order.total)}',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                  if (server != null)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'by $server',
                        style: TextStyle(
                            fontSize: 11, color: Colors.blue.shade700),
                      ),
                    ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Items ──
            if (order != null)
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 8),
                    for (final l in order.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('${l.qty}×',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.name,
                                      style: const TextStyle(fontSize: 14)),
                                  if (l.options.isNotEmpty)
                                    Text(l.options.join(' • '),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            Text(formatMoney(l.lineTotal),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            // ── Actions ──
            const Divider(height: 1),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: locked
                    ? Row(
                        children: [
                          Icon(Icons.lock_outline,
                              color: Colors.grey.shade500, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Locked by $server',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          if (order != null && order.status != 'collected')
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _advance(order);
                                },
                                icon: Icon(
                                  order.status == 'ready'
                                      ? Icons.shopping_bag
                                      : Icons.skip_next,
                                  size: 18,
                                ),
                                label: Text(_advanceLabel(order.status)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: order.status == 'ready'
                                      ? Colors.green
                                      : null,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          if (order != null &&
                              order.status != 'collected') ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await context
                                      .read<ApiClient>()
                                      .freeTable(t.number);
                                  _load();
                                },
                                icon: const Icon(Icons.check_circle_outline,
                                    size: 18),
                                label: const Text('Free table'),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                          if (order == null || order.status == 'collected')
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await context
                                      .read<ApiClient>()
                                      .freeTable(t.number);
                                  _load();
                                },
                                icon: const Icon(Icons.check_circle_outline,
                                    size: 18),
                                label: const Text('Free table'),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
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
        return 'Pickup & Pay';
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
        final updated = await collectOrderAndPay(context, order);
        if (updated == null || !mounted) return;
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
          const Icon(Icons.error_outline, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }

    final occupied = _tables.where((t) => t.isOccupied).length;
    final empty = _tables.length - occupied;

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          // ── Summary ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.45),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryTile(
                    label: 'Total', value: '${_tables.length}', color: Colors.blueGrey),
                _SummaryTile(
                    label: 'Occupied', value: '$occupied', color: Colors.red),
                _SummaryTile(
                    label: 'Available', value: '$empty', color: Colors.green),
              ],
            ),
          ),

          // ── Grid ──
          Expanded(
            child: _tables.isEmpty
                ? const Center(child: Text('No tables configured'))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 600 ? 4 : 3;
                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        padding: const EdgeInsets.all(12),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        children: _tables.map((t) => _TableCard(
                              table: t,
                              onTap: () => _openTable(t),
                            )).toList(),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Table Card ───

class _TableCard extends StatelessWidget {
  final CafeTable table;
  final VoidCallback onTap;

  const _TableCard({required this.table, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOccupied = table.isOccupied;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: isOccupied
          ? scheme.errorContainer.withValues(alpha: 0.35)
          : scheme.primaryContainer.withValues(alpha: 0.3),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.table_restaurant_rounded,
                size: 36,
                color: isOccupied
                    ? Colors.red.shade400
                    : Colors.green.shade600,
              ),
              const SizedBox(height: 8),
              Text(
                'Table ${table.number}',
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOccupied
                      ? Colors.red.shade100
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOccupied ? 'Occupied' : 'Available',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isOccupied
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                  ),
                ),
              ),
              if (isOccupied && table.takenBy != null) ...[
                const SizedBox(height: 4),
                Text(
                  table.takenBy!,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Summary Tile ───

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

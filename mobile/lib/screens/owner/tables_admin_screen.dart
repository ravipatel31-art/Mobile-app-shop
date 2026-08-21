import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cafe_table.dart';
import '../../models/order.dart';
import '../../services/api_client.dart';
import '../../util/money.dart';

/// Owner view: see table occupancy with staff assignments, add/remove tables, view order details.
class TablesAdminScreen extends StatefulWidget {
  const TablesAdminScreen({super.key});

  @override
  State<TablesAdminScreen> createState() => _TablesAdminScreenState();
}

class _TablesAdminScreenState extends State<TablesAdminScreen> {
  List<CafeTable> _tables = [];
  Map<String, CafeOrder?> _orderCache = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tables = await context.read<ApiClient>().fetchTables();
      _orderCache.clear();

      // Fetch all orders to map to tables
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

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _addTable() async {
    try {
      await context.read<ApiClient>().addTable();
      await _load();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _removeTable(CafeTable t) async {
    try {
      await context.read<ApiClient>().removeTable(t.number);
      await _load();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _freeTable(CafeTable t) async {
    try {
      await context.read<ApiClient>().freeTable(t.number);
      await _load();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _showTableDetails(CafeTable table) async {
    final order = table.orderId != null ? _orderCache[table.orderId] : null;
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Table ${table.number}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Chip(
                      label: Text(table.isOccupied ? 'Occupied' : 'Empty'),
                      backgroundColor: table.isOccupied
                          ? Colors.red.shade100
                          : Colors.green.shade100,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (table.isOccupied && order != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Order #',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                Text(
                                  order.id,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Status',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                Chip(
                                  label: Text(order.status),
                                  backgroundColor: _statusColor(order.status)
                                      .withOpacity(0.3),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Customer',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                Text(
                                  order.customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                Text(
                                  formatMoney(order.total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Items',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...order.items.map((line) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Text(
                              '${line.qty}×',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(line.name),
                                  if (line.options.isNotEmpty)
                                    Text(
                                      line.options.join(' • '),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              formatMoney(line.lineTotal),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 12),
                  const Divider(),
                ] else if (table.isOccupied) ...[
                  const Text('Loading order details...'),
                ] else ...[
                  const Text(
                    'This table is empty.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 16),
                if (table.isOccupied)
                  FilledButton.tonal(
                    onPressed: () {
                      Navigator.pop(context);
                      _freeTable(table);
                    },
                    child: const SizedBox(
                      width: double.infinity,
                      child: Text(
                        'Free this table',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  FilledButton.tonal(
                    onPressed: () {
                      Navigator.pop(context);
                      _removeTable(table);
                    },
                    child: const SizedBox(
                      width: double.infinity,
                      child: Text(
                        'Remove this table',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'received':
        return Colors.blueGrey;
      case 'preparing':
        return Colors.orange;
      case 'ready':
        return Colors.green;
      case 'collected':
        return Colors.grey;
      default:
        return Colors.red;
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

    final occupied = _tables.where((t) => t.isOccupied).length;
    _tables.sort((a, b) => int.parse(a.number).compareTo(int.parse(b.number)));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Tables',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      Text(
                        '${_tables.length}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Occupied',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      Text(
                        '$occupied',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1,
              children: _tables
                  .map((t) => _TableCard(
                        table: t,
                        onTap: () => _showTableDetails(t),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTable,
        icon: const Icon(Icons.add),
        label: const Text('Add table'),
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  final CafeTable table;
  final VoidCallback onTap;
  const _TableCard({required this.table, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final occupied = table.isOccupied;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(6),
      color: occupied
          ? scheme.errorContainer.withValues(alpha: 0.4)
          : scheme.primaryContainer.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  occupied
                      ? Icons.table_restaurant
                      : Icons.table_restaurant_outlined,
                  color: occupied ? Colors.red.shade400 : Colors.green.shade600,
                  size: 34,
                ),
                const SizedBox(height: 6),
                Text(
                  'Table ${table.number}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  occupied ? 'Occupied' : 'Empty',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                if (occupied)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Order #${table.orderId ?? '?'}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black45,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

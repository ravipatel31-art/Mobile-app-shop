import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cart.dart';
import '../../models/order.dart';
import '../../services/api_client.dart';
import '../../state/auth_state.dart';
import '../../state/cart_state.dart';
import '../../util/money.dart';
import '../../util/permissions.dart';
import '../../widgets/collect_order_flow.dart';
import '../../widgets/menu_picker_sheet.dart';
import '../staff/take_order_screen.dart';

class OrdersQueueScreen extends StatefulWidget {
  const OrdersQueueScreen({super.key});

  @override
  State<OrdersQueueScreen> createState() => _OrdersQueueScreenState();
}

class _OrdersQueueScreenState extends State<OrdersQueueScreen> {
  List<CafeOrder> _orders = [];
  bool _loading = true;
  String? _error;
  bool _activeOnly = true;

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
      final orders = await context.read<ApiClient>().fetchOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
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
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  static const _nextLabel = {
    'received': 'Start preparing',
    'preparing': 'Mark ready',
    'ready': 'Collect & take payment',
  };

  /// Reopen a completed order so the customer can add more items. The already
  /// paid amount carries over as credit; only the difference is collected later.
  Future<void> _reopenAndAdd(CafeOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reopen order'),
        content: Text(
            'Order #${order.id} will be reopened and ${order.tableNumber != null ? 'table ${order.tableNumber} ' : ''}'
            'locked again. ${formatMoney(order.paidAmount)} already paid stays '
            'as credit — only the new items will be charged.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reopen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<ApiClient>().reopenOrder(order.id);
      context.read<CartState>().tablesChanged(); // grid: table occupied again
      await _load();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TakeOrderScreen(
            tableNumber: order.tableNumber ?? '',
            existingOrderId: order.id,
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  /// Add items to an existing order straight from the queue: open the menu
  /// popup, then POST the picked items. A collected order is reopened first so
  /// the already-paid amount carries over as credit.
  Future<void> _addItemsToOrder(CafeOrder order) async {
    final cart = context.read<CartState>();
    final api = context.read<ApiClient>();
    final messenger = ScaffoldMessenger.of(context);
    final snapshot = List<CartLine>.from(cart.lines);
    await showMenuPickerSheet(context);
    if (!mounted) return;
    final added = cart.lines.where((l) => !snapshot.contains(l)).toList();
    if (added.isEmpty) return; // nothing picked — leave the cart as-is
    try {
      if (order.status == 'collected') {
        await api.reopenOrder(order.id);
        cart.tablesChanged(); // grid: table occupied again
      }
      final updated = await api.addOrderItems(
          order.id, added.map((l) => l.toOrderItemJson()).toList());
      for (final l in added) {
        cart.removeLine(l);
      }
      await _load();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
          content: Text(
              'Added ${added.length} item(s) to Order #${order.id} • '
              'new total ${formatMoney(updated.total)}')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
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

  int _totalSales(List<CafeOrder> orders) {
    return orders
        .where((o) => o.status == 'collected')
        .fold<int>(0, (sum, o) => sum + o.total);
  }

  int _activeOrdersCount(List<CafeOrder> orders) {
    return orders.where((o) => o.status != 'collected').length;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final visible = _activeOnly
        ? _orders.where((o) => o.status != 'collected').toList()
        : _orders;
    final totalSales = _totalSales(_orders);
    final activeCount = _activeOrdersCount(_orders);

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Container(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.45),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Sales',
                            style: TextStyle(fontSize: 12, color: Colors.black54)),
                        Text(formatMoney(totalSales),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Active Orders',
                            style: TextStyle(fontSize: 12, color: Colors.black54)),
                        Text('$activeCount',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          SwitchListTile(
            value: _activeOnly,
            onChanged: (v) => setState(() => _activeOnly = v),
            title: const Text('Active orders only'),
          ),
          Expanded(
            child: visible.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 120),
                    Center(child: Text('No orders.')),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final o = visible[i];
                      final canAdvance = _nextLabel.containsKey(o.status);
                      final canEdit = canEditOrder(auth, o);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('#${o.id}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  const SizedBox(width: 10),
                                  Chip(
                                    label: Text(o.status,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12)),
                                    backgroundColor: _statusColor(o.status),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  if (o.tableNumber != null) ...[
                                    const SizedBox(width: 8),
                                    Chip(
                                      label: Text('Table ${o.tableNumber}',
                                          style: const TextStyle(fontSize: 12)),
                                      backgroundColor:
                                          Colors.orange.shade100,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                  const Spacer(),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(formatMoney(o.total),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Customer',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.black54)),
                                        Text(o.customerName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  if (o.customerPhone?.isNotEmpty ?? false)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('Phone',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.black54)),
                                          Text(o.customerPhone ?? '',
                                              style:
                                                  const TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              ...o.items.map((line) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Text('${line.qty}×',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(line.name),
                                              if (line.options.isNotEmpty)
                                                Text(line.options.join(' • '),
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.black54)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(formatMoney(line.lineTotal),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  )),
                              if (o.notes.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(4)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.note_outlined,
                                          size: 16, color: Colors.orange),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(o.notes,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontStyle: FontStyle.italic)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.end,
                                  children: [
                                    if (canEdit)
                                      OutlinedButton.icon(
                                        onPressed: () => _addItemsToOrder(o),
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add item'),
                                      ),
                                    if (canAdvance)
                                      FilledButton.tonal(
                                        onPressed: () => _advance(o),
                                        child: Text(_nextLabel[o.status]!),
                                      )
                                    else if (canEdit && o.status == 'collected')
                                      FilledButton.tonal(
                                        onPressed: () => _reopenAndAdd(o),
                                        child: const Text('Reopen & add items'),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

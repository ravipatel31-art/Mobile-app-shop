import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
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
                          if (order != null &&
                              (order.customerPhone?.isNotEmpty ?? false))
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _sendWhatsApp(order);
                                },
                                icon: const Icon(Icons.chat, size: 18),
                                label: const Text('Send Bill'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          if (order != null &&
                              (order.customerPhone?.isNotEmpty ?? false))
                            const SizedBox(width: 10),
                          if (order != null && order.status == 'ready')
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _advance(order);
                                },
                                icon: const Icon(
                                    Icons.shopping_bag,
                                    size: 18),
                                label: const Text('Serve to Customer'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green,
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
      case 'ready':
        return 'Serve to Customer';
      default:
        return 'Advance';
    }
  }

  String _customerPhone(CafeOrder order) {
    final phone = order.customerPhone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (phone.isEmpty) return '';
    if (phone.startsWith('91') && phone.length >= 12) return phone;
    if (phone.length == 10) return '91$phone';
    return phone;
  }

  String _buildBillText(CafeOrder order) {
    final items = order.items.map((item) {
      final opts = item.options.isNotEmpty
          ? '\n   ${item.options.join(" | ")}'
          : '';
      return '  ${item.name} x${item.qty}  ₹${item.lineTotal}$opts';
    }).join('\n');

    final upiLink =
        'upi://pay?pa=${AppConfig.upiId}&pn=${Uri.encodeComponent(AppConfig.merchantName)}&am=${order.total}&cu=INR';

    final buffer = StringBuffer()
      ..writeln('╭─────────────────────────╮')
      ..writeln('│     ${AppConfig.merchantName}     │')
      ..writeln('╰─────────────────────────╯')
      ..writeln()
      ..writeln('📋 Bill #${order.id}')
      ..writeln(
          '📅 ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(order.createdAt) ?? DateTime.now())}')
      ..writeln('👤 ${order.customerName}')
      ..writeln('🪑 Table ${order.tableNumber ?? "N/A"}')
      ..writeln('👨‍🍳 Served by: ${order.takenBy ?? 'N/A'}')
      ..writeln()
      ..writeln('─────────────────────────')
      ..writeln('  ITEM              QTY   AMT')
      ..writeln('─────────────────────────')
      ..writeln(items)
      ..writeln('─────────────────────────')
      ..writeln()
      ..writeln('💰 TOTAL: ₹${order.total}')
      ..writeln('💳 Payment: ${order.paymentMethod.toUpperCase()}')
      ..writeln('✅ Status: ${order.paymentStatus.toUpperCase()}')
      ..writeln();

    if (order.paymentStatus != 'paid') {
      buffer
        ..writeln(' pay using upi')
        ..writeln(upiLink)
        ..writeln();
    }

    buffer
      ..writeln('─────────────────────────')
      ..writeln('  Thank you for visiting!')
      ..writeln('  Visit us again 🙏')
      ..writeln('─────────────────────────');
    return buffer.toString();
  }

  Future<void> _sendWhatsApp(CafeOrder order) async {
    final phone = _customerPhone(order);
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No customer phone number on this order')),
        );
      }
      return;
    }
    final billText = _buildBillText(order);
    final url =
        Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(billText)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
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
        _load();
        final hasPhone =
            updated.customerPhone != null && updated.customerPhone!.isNotEmpty;
        final sendBill = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
            title: const Text('Payment collected'),
            content: Text(
              hasPhone
                  ? 'Send bill to ${updated.customerName} via WhatsApp?'
                  : 'No phone number on this order. Bill not sent.',
            ),
            actions: [
              if (hasPhone)
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Skip'),
                ),
              if (hasPhone)
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('Send Bill'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                ),
              if (!hasPhone)
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
            ],
          ),
        );
        if (sendBill == true && mounted) {
          await _sendWhatsApp(updated);
        }
      } else {
        await context.read<ApiClient>().updateOrderStatus(order.id, next);
        _load();
      }
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
                              order: _orderCache[t.number.toString()],
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
  final CafeOrder? order;
  final VoidCallback onTap;

  const _TableCard({required this.table, this.order, required this.onTap});

  Color _statusColor(String status) {
    switch (status) {
      case 'received':
        return Colors.blue;
      case 'preparing':
        return Colors.orange;
      case 'ready':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'received':
        return 'Order Placed';
      case 'preparing':
        return 'Preparing';
      case 'ready':
        return 'Ready to Serve';
      default:
        return status;
    }
  }

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
              const SizedBox(height: 6),
              Text(
                'Table ${table.number}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              if (isOccupied && order != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(order!.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(order!.status),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(order!.status),
                    ),
                  ),
                ),
              ] else if (isOccupied) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Occupied',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Available',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
              if (isOccupied && table.takenBy != null) ...[
                const SizedBox(height: 3),
                Text(
                  table.takenBy!,
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
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

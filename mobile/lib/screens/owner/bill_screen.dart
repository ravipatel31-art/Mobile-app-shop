import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/order.dart';
import '../../services/api_client.dart';

class BillScreen extends StatelessWidget {
  final CafeOrder order;
  const BillScreen({super.key, required this.order});

  String _formatMoney(int amount) => '₹$amount';

  void _copyBill() {
    final items = order.items.map((item) {
      final opts = item.options.map((o) => '  $o').join('\n');
      return '${item.name} x${item.qty}  ₹${item.lineTotal}'
          '${opts.isNotEmpty ? '\n$opts' : ''}';
    }).join('\n');

    final buffer = StringBuffer()
      ..writeln('═══════════════════════════')
      ..writeln('       CAFE POS BILL')
      ..writeln('═══════════════════════════')
      ..writeln()
      ..writeln('Bill #: ${order.id}')
      ..writeln('Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(order.createdAt) ?? DateTime.now())}')
      ..writeln('Staff: ${order.takenBy ?? 'N/A'}')
      ..writeln()
      ..writeln('─── ITEMS ───────────────')
      ..writeln(items)
      ..writeln()
      ..writeln('─────────────────────────')
      ..writeln('TOTAL: ${_formatMoney(order.total)}')
      ..writeln()
      ..writeln('Payment: ${order.paymentMethod.toUpperCase()}')
      ..writeln('Status: ${order.paymentStatus.toUpperCase()}')
      ..writeln()
      ..writeln('═══════════════════════════')
      ..writeln('  Thank you for your visit!')
      ..writeln('═══════════════════════════');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
  }

  String _buildBillText() {
    final items = order.items.map((item) {
      final opts = item.options.map((o) => '  $o').join('\n');
      return '${item.name} x${item.qty}  ₹${item.lineTotal}'
          '${opts.isNotEmpty ? '\n$opts' : ''}';
    }).join('\n');

    return StringBuffer()
      ..writeln('═══════════════════════════')
      ..writeln('       CAFE POS BILL')
      ..writeln('═══════════════════════════')
      ..writeln()
      ..writeln('Bill #: ${order.id}')
      ..writeln('Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(order.createdAt) ?? DateTime.now())}')
      ..writeln('Staff: ${order.takenBy ?? 'N/A'}')
      ..writeln()
      ..writeln('─── ITEMS ───────────────')
      ..writeln(items)
      ..writeln()
      ..writeln('─────────────────────────')
      ..writeln('TOTAL: ₹${order.total}')
      ..writeln()
      ..writeln('Payment: ${order.paymentMethod.toUpperCase()}')
      ..writeln('Status: ${order.paymentStatus.toUpperCase()}')
      ..writeln()
      ..writeln('═══════════════════════════')
      ..writeln('  Thank you for your visit!')
      ..writeln('═══════════════════════════')
      ..toString();
  }

  static const _ownerWhatsApp = '916351770056';

  Future<void> _sendWhatsApp() async {
    final billText = _buildBillText();
    final url = Uri.parse('https://wa.me/$_ownerWhatsApp?text=${Uri.encodeComponent(billText)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bill #${order.id}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyBill,
          ),
          IconButton(
            icon: const Icon(Icons.whatsapp, color: Colors.green),
            onPressed: _sendWhatsApp,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      Text(
                        'CAFE POS',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bill Receipt',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const Divider(thickness: 2),
                const SizedBox(height: 8),

                // Order info
                _InfoRow(label: 'Bill #', value: order.id),
                _InfoRow(
                  label: 'Date',
                  value: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(order.createdAt) ?? DateTime.now()),
                ),
                if (order.customerName.isNotEmpty)
                  _InfoRow(label: 'Customer', value: order.customerName),
                if (order.tableNumber != null)
                  _InfoRow(label: 'Table', value: order.tableNumber!),
                if (order.takenBy != null)
                  _InfoRow(label: 'Served by', value: order.takenBy!),

                const Divider(thickness: 2),
                const SizedBox(height: 8),

                // Items header
                Row(
                  children: [
                    const Expanded(
                      flex: 4,
                      child: Text('ITEM',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                    const Expanded(
                      flex: 1,
                      child: Text('QTY',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('AMOUNT',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Items
                ...order.items.map((item) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                item.name,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '${item.qty}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _formatMoney(item.lineTotal),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        ...item.options.map((opt) => Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(
                                '  $opt',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            )),
                        const SizedBox(height: 6),
                      ],
                    )),

                const Divider(thickness: 2),
                const SizedBox(height: 8),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    Text(
                      _formatMoney(order.total),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Payment info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: order.paymentStatus == 'paid'
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        order.paymentStatus == 'paid'
                            ? Icons.check_circle
                            : Icons.pending,
                        color: order.paymentStatus == 'paid'
                            ? Colors.green
                            : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment: ${order.paymentMethod.toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Status: ${order.paymentStatus.toUpperCase()}',
                              style: TextStyle(
                                color: order.paymentStatus == 'paid'
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _copyBill,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _sendWhatsApp,
                        icon: const Icon(Icons.whatsapp),
                        label: const Text('WhatsApp'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Center(
                  child: Text(
                    'Thank you for your visit!',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

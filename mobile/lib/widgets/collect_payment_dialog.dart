import 'package:flutter/material.dart';

import '../models/order.dart';
import '../util/money.dart';

const paymentMethods = [
  (value: 'gpay', label: 'GPay', icon: Icons.account_balance_wallet_outlined),
  (value: 'cash', label: 'Cash', icon: Icons.payments_outlined),
  (value: 'card', label: 'Card', icon: Icons.credit_card),
  (value: 'upi', label: 'UPI', icon: Icons.qr_code),
];

/// Asks staff to confirm payment before completing (collecting) an order.
/// Returns the chosen payment method, or null if the staff cancelled.
Future<String?> showCollectPaymentDialog(
    BuildContext context, CafeOrder order) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CollectPaymentDialog(order: order),
  );
}

class _CollectPaymentDialog extends StatefulWidget {
  final CafeOrder order;
  const _CollectPaymentDialog({required this.order});

  @override
  State<_CollectPaymentDialog> createState() => _CollectPaymentDialogState();
}

class _CollectPaymentDialogState extends State<_CollectPaymentDialog> {
  late String _method;

  @override
  void initState() {
    super.initState();
    final m = widget.order.paymentMethod;
    _method = m.isEmpty || m == 'gpay' ? 'cash' : m;
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final remaining = order.total - order.paidAmount;
    return AlertDialog(
      title: const Text('Collect order'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order #${order.id}'),
          const SizedBox(height: 8),
          Text('Amount to collect: ${formatMoney(remaining)}',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          if (order.paidAmount > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Order total ${formatMoney(order.total)} '
              '• ${formatMoney(order.paidAmount)} already paid',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Payment method'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in paymentMethods)
                ChoiceChip(
                  label: Text(m.label),
                  avatar: Icon(m.icon, size: 18),
                  selected: _method == m.value,
                  onSelected: (_) => setState(() => _method = m.value),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _method),
          child: const Text('Confirm & collect'),
        ),
      ],
    );
  }
}

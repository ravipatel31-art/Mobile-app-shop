import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../state/cart_state.dart';
import '../../util/money.dart';
import '../../widgets/collect_payment_dialog.dart' show paymentMethods;
import '../../widgets/menu_picker_sheet.dart';
import '../../widgets/recommendations_strip.dart';

/// Review the current order for a table and send it to the kitchen.
/// When [existingOrderId] is set, this adds items to a reopened order instead
/// of placing a brand-new one.
class OrderCartScreen extends StatefulWidget {
  final String tableNumber;
  final String? existingOrderId;
  const OrderCartScreen({
    super.key,
    required this.tableNumber,
    this.existingOrderId,
  });

  @override
  State<OrderCartScreen> createState() => _OrderCartScreenState();
}

class _OrderCartScreenState extends State<OrderCartScreen> {
  final _notes = TextEditingController();
  bool _submitting = false;
  String _paymentMethod = 'cash';

  bool get _isAddMode => widget.existingOrderId != null;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _place() async {
    final cart = context.read<CartState>();
    if (cart.isEmpty) return;
    setState(() => _submitting = true);
    final api = context.read<ApiClient>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_isAddMode) {
        final order = await api.addOrderItems(
            widget.existingOrderId!, cart.itemsJson);
        cart.clear();
        if (!mounted) return;
        Navigator.of(context).pop(); // back to the take-order/add screen
        messenger.showSnackBar(SnackBar(
            content: Text(
                'Added items to Order #${order.id} • new total ${formatMoney(order.total)}')));
      } else {
        final order = await api.placeOrder(cart.buildOrderPayload(
          tableNumber: widget.tableNumber,
          notes: _notes.text.trim(),
          paymentMethod: _paymentMethod,
        ));
        cart.clear();
        cart.tablesChanged(); // lets the tables grid refresh (table now occupied)
        if (!mounted) return;
        // Back to the table grid.
        Navigator.of(context).popUntil((r) => r.isFirst);
        messenger.showSnackBar(SnackBar(
            content: Text(
                'Order #${order.id} placed for Table ${widget.tableNumber}')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isAddMode
            ? 'Order #${widget.existingOrderId} • Add items'
            : 'Table ${widget.tableNumber} • Review'),
        actions: [
          IconButton(
            tooltip: 'Add more items',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => showMenuPickerSheet(context),
          ),
        ],
      ),
      body: cart.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No items yet.'),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => showMenuPickerSheet(context),
                    child: const Text('Browse menu'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ...List.generate(cart.lines.length, (i) {
                  final line = cart.lines[i];
                  return Card(
                    child: ListTile(
                      title: Text(line.item.name),
                      subtitle: line.optionsSummary.isEmpty
                          ? null
                          : Text(line.optionsSummary),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => cart.setQty(i, line.qty - 1),
                          ),
                          Text('${line.qty}'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => cart.setQty(i, line.qty + 1),
                          ),
                          const SizedBox(width: 6),
                          Text(formatMoney(line.lineTotal),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                const RecommendationsStrip(),
                const SizedBox(height: 8),
                TextField(
                  controller: _notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'e.g. less sugar, extra hot',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                if (!_isAddMode) ...[
                  const SizedBox(height: 16),
                  Text('Payment method',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in paymentMethods)
                        ChoiceChip(
                          label: Text(m.label),
                          avatar: Icon(m.icon, size: 18),
                          selected: _paymentMethod == m.value,
                          onSelected: (_) =>
                              setState(() => _paymentMethod = m.value),
                        ),
                    ],
                  ),
                ],
              ],
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(fontSize: 16)),
                        Text(formatMoney(cart.total),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => showMenuPickerSheet(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add more items'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _submitting ? null : _place,
                      child: _submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_isAddMode
                              ? 'Add items to Order #${widget.existingOrderId}'
                              : 'Place order for Table ${widget.tableNumber}'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

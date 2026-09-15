import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../models/inventory_item.dart';
import '../../services/api_client.dart';

/// Screen to compose and send a stock order message to the vendor via WhatsApp.
class VendorMessageScreen extends StatefulWidget {
  const VendorMessageScreen({super.key});

  @override
  State<VendorMessageScreen> createState() => _VendorMessageScreenState();
}

class _VendorMessageScreenState extends State<VendorMessageScreen> {
  List<InventoryItem> _items = [];
  bool _loading = true;
  String? _error;

  /// Selected item IDs mapped to the quantity to order.
  final Map<String, int> _selected = {};

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
      final items = await context.read<ApiClient>().fetchInventory();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  void _toggleItem(InventoryItem item) {
    setState(() {
      if (_selected.containsKey(item.id)) {
        _selected.remove(item.id);
      } else {
        _selected[item.id] = item.quantity <= 10 ? 10 : item.quantity;
      }
    });
  }

  void _updateQty(String itemId, int qty) {
    setState(() {
      if (qty <= 0) {
        _selected.remove(itemId);
      } else {
        _selected[itemId] = qty;
      }
    });
  }

  String _buildMessage() {
    final buffer = StringBuffer()
      ..writeln('Hi! I need to restock:')
      ..writeln();

    for (final entry in _selected.entries) {
      final item = _items.firstWhere((i) => i.id == entry.key);
      final emoji = _emojiForUnit(item.unit);
      buffer.writeln('$emoji ${item.name} — ${entry.value} ${item.unit}');
    }

    buffer
      ..writeln()
      ..writeln('Please deliver as soon as possible. Thanks!');

    return buffer.toString();
  }

  String _emojiForUnit(String unit) {
    switch (unit.toLowerCase()) {
      case 'kg':
        return '📦';
      case 'litre':
      case 'liter':
        return '🥛';
      case 'piece':
        return '📋';
      case 'g':
        return '🧈';
      case 'ml':
        return '🫗';
      case 'dozen':
        return '🥚';
      case 'pack':
        return '📦';
      default:
        return '📦';
    }
  }

  Future<void> _sendWhatsApp() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item to order')),
      );
      return;
    }

    final message = _buildMessage();
    final url = Uri.parse(
        'https://wa.me/${AppConfig.vendorPhone}?text=${Uri.encodeComponent(message)}');

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

  @override
  Widget build(BuildContext context) {
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

    final lowStock =
        _items.where((i) => i.quantity <= 10).toList();
    final allItems = _items.toList();

    return Column(
      children: [
        // Vendor info card
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.storefront, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Stock Vendor',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(AppConfig.vendorPhone,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              if (lowStock.isNotEmpty)
                Chip(
                  label: Text('${lowStock.length} low stock',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11)),
                  backgroundColor: Colors.orange,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),

        // Selected count + send button
        if (_selected.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_selected.length} item(s) selected for restocking',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _sendWhatsApp,
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('Send'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // Items list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                if (lowStock.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('LOW STOCK',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.orange)),
                  ),
                  ...lowStock.map((item) => _ItemTile(
                        item: item,
                        selected: _selected.containsKey(item.id),
                        quantity: _selected[item.id],
                        onTap: () => _toggleItem(item),
                        onQtyChanged: (qty) => _updateQty(item.id, qty),
                      )),
                  const SizedBox(height: 16),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('ALL ITEMS',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.black54)),
                ),
                ...allItems
                    .where((i) => !_selected.containsKey(i.id))
                    .map((item) => _ItemTile(
                          item: item,
                          selected: false,
                          quantity: null,
                          onTap: () => _toggleItem(item),
                          onQtyChanged: null,
                        )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  final InventoryItem item;
  final bool selected;
  final int? quantity;
  final VoidCallback onTap;
  final ValueChanged<int>? onQtyChanged;

  const _ItemTile({
    required this.item,
    required this.selected,
    required this.quantity,
    required this.onTap,
    this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = item.quantity <= 10;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: selected ? Colors.green.shade50 : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) => onTap(),
                activeColor: Colors.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      'Stock: ${item.quantity} ${item.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isLow ? Colors.orange.shade700 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected && onQtyChanged != null)
                SizedBox(
                  width: 100,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: () => onQtyChanged!(quantity! - 1),
                      ),
                      Expanded(
                        child: Text(
                          '$quantity',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: () => onQtyChanged!(quantity! + 1),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

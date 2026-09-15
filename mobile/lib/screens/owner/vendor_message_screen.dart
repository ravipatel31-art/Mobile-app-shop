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
      ..writeln('📦 Stock Restock Request')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━━')
      ..writeln();

    for (final entry in _selected.entries) {
      final item = _items.firstWhere((i) => i.id == entry.key);
      buffer.writeln('  ${item.name}  →  ${entry.value} ${item.unit}');
    }

    buffer
      ..writeln()
      ..writeln('━━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('Please deliver as soon as possible.')
      ..writeln('Thanks!');

    return buffer.toString();
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
            const Icon(Icons.error_outline, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final lowStock = _items.where((i) => i.quantity <= 10).toList();
    final allItems = _items.toList();

    return Column(
      children: [
        // Vendor info header
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.teal.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Stock Vendor',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(AppConfig.vendorPhone,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
              if (lowStock.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text('${lowStock.length} low',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Selected items bar
        if (_selected.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.shopping_cart,
                      color: Colors.green.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selected.length} item(s) selected',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _selected.entries.map((e) {
                          final item = _items.firstWhere((i) => i.id == e.key);
                          return '${item.name} ×${e.value}';
                        }).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _sendWhatsApp,
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('Send'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // Items list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                if (lowStock.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'LOW STOCK',
                    subtitle: '${lowStock.length} items need attention',
                    color: Colors.orange,
                    icon: Icons.warning_amber_rounded,
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
                _SectionHeader(
                  title: 'ALL ITEMS',
                  subtitle: '${allItems.length} items in inventory',
                  color: Colors.blueGrey,
                  icon: Icons.inventory_2_outlined,
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
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: color,
                  letterSpacing: 0.5)),
          const SizedBox(width: 8),
          Text(subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
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
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: selected ? 2 : 0,
      color: selected ? Colors.green.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? Colors.green.shade300 : Colors.grey.shade200,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox with colored background
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? Colors.green : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
              const SizedBox(width: 12),
              // Item info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isLow
                                ? Colors.orange.shade50
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${item.quantity} ${item.unit}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isLow
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '₹${item.costPrice}/${item.unit}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Quantity controls
              if (selected && onQtyChanged != null)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle,
                            size: 24,
                            color: quantity! > 1
                                ? Colors.green
                                : Colors.grey.shade300),
                        onPressed: quantity! > 1
                            ? () => onQtyChanged!(quantity! - 1)
                            : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                      ),
                      Container(
                        width: 36,
                        alignment: Alignment.center,
                        child: Text(
                          '$quantity',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle,
                            size: 24, color: Colors.green),
                        onPressed: () => onQtyChanged!(quantity! + 1),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
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

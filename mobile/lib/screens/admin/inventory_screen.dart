import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/inventory_item.dart';
import '../../services/api_client.dart';
import '../../util/money.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _fmt = DateFormat('yyyy-MM-dd');
  List<InventoryItem> _inventory = [];
  int _totalSales = 0;
  int _totalCost = 0;
  bool _inProfit = true;
  String? _aiSuggestion;
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
    final api = context.read<ApiClient>();
    try {
      final inventoryResult = await api.fetchInventory();
      final today = _fmt.format(DateTime.now());
      final salesResult = await api.dailyReport(today);
      final profitData = await api.calculateProfitLoss(month: today);

      setState(() {
        _inventory = inventoryResult;
        _totalSales = salesResult.grossSales;
        _totalCost = profitData['total_cost'] as int? ?? 0;
        _inProfit = profitData['in_profit'] as bool? ?? true;
        _aiSuggestion = profitData['suggestion'] as String?;
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

  Future<void> _getAISuggestion() async {
    setState(() {
      _loading = true;
    });
    final api = context.read<ApiClient>();
    try {
      final question =
          'Our shop is running at a loss this month. Total sales: $_totalSales, total inventory cost: $_totalCost. '
          'What specific actions can the admin take to gain profit? Please give 3 concise suggestions.';
      final result = await api.askQuestion(question);
      setState(() {
        _aiSuggestion = result.answer;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _aiSuggestion = 'Could not get AI suggestion. Try again later.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(message: _error!, onRetry: _load);

    final isLoss = !_inProfit;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inventory Management',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _MetricCard(
            title: 'Total Inventory Value',
            value: formatMoney(_totalCost),
            emoji: '📦',
            colors: const [Color(0xFF6366F1), Color(0x818CF8)],
            subtitle: '${_inventory.length} items in stock',
          ),
          const SizedBox(height: 12),
          _MetricCard(
            title: 'Total Sales This Month',
            value: formatMoney(_totalSales),
            emoji: '💰',
            colors: const [Color(0xFF10B981), Color(0xFF059669)],
            subtitle: isLoss ? 'Currently at LOSS' : 'Currently in PROFIT',
          ),
          const SizedBox(height: 12),
          if (isLoss) ...[_LossPill()],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _InventoryList(inventory: _inventory),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _AISuggestionBox(
                suggestion: _aiSuggestion,
                onRequest: _getAISuggestion,
                inLoss: isLoss,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String emoji;
  final List<Color> colors;
  final String subtitle;
  const _MetricCard({
    required this.title,
    required this.value,
    required this.emoji,
    required this.colors,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(emoji,
                    style: const TextStyle(fontSize: 24, height: 0)),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1)),
            ),
            const SizedBox(height: 6),
            Text(subtitle,
                style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _LossPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_down_rounded,
              size: 14, color: scheme.onErrorContainer),
          const SizedBox(width: 6),
          Text(
            'LOSS',
            style: TextStyle(
                color: scheme.onErrorContainer,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InventoryList extends StatelessWidget {
  final List<InventoryItem> inventory;
  const _InventoryList({required this.inventory});

  @override
  Widget build(BuildContext context) {
    if (inventory.isEmpty) {
      return const Center(child: Text('No inventory items found.'));
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: inventory.length,
      separatorBuilder: (_, __) => const Divider(height: 8),
      itemBuilder: (context, i) {
        final item = inventory[i];
        return ListTile(
          leading: CircleAvatar(
            child: Text(item.name.substring(0, 1).toUpperCase()),
          ),
          title: Text(item.name),
          subtitle: Text('Qty: ${item.quantity}'),
          trailing: Text(
            formatMoney(item.totalValue),
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14),
          ),
        );
      },
    );
  }
}

class _AISuggestionBox extends StatelessWidget {
  final String? suggestion;
  final VoidCallback onRequest;
  final bool inLoss;
  const _AISuggestionBox({
    required this.suggestion,
    required this.onRequest,
    required this.inLoss,
  });

  @override
  Widget build(BuildContext context) {
    if (!inLoss) {
      return const Center(child: Text('No loss detected - no suggestions needed.'));
    }
    if (suggestion != null && suggestion!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suggested actions:',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              suggestion!,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRequest,
              child: const Text('Refresh Suggestions'),
            ),
          ],
        ),
      );
    }
    return const Center(child: Text('No suggestions available yet.'));
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
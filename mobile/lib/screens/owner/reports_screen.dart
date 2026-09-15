import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/inventory_item.dart';
import '../../services/api_client.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  DateTime _selectedMonth = DateTime.now();
  String _viewMode = 'monthly'; // 'daily' or 'monthly'

  // Daily data
  DateTime _selectedDay = DateTime.now();
  Map<String, dynamic>? _dailyData;
  bool _loadingDaily = false;

  // Monthly data
  Map<String, dynamic>? _monthlyData;
  List<Map<String, dynamic>> _dailyBreakdown = [];
  bool _loadingMonthly = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadMonthly();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDaily() async {
    setState(() {
      _loadingDaily = true;
      _error = null;
    });
    final api = context.read<ApiClient>();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay);
    try {
      final data = await api.dailyReport(dateStr);
      setState(() {
        _dailyData = {
          'date': dateStr,
          'gross_sales': data.grossSales,
          'order_count': data.orderCount,
          'by_payment': data.byPayment,
          'top_items': data.topItems,
        };
        _loadingDaily = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loadingDaily = false;
      });
    }
  }

  Future<void> _loadMonthly() async {
    setState(() {
      _loadingMonthly = true;
      _error = null;
    });
    final api = context.read<ApiClient>();
    try {
      // Get profit/loss data
      final monthStr = DateFormat('yyyy-MM-dd').format(_selectedMonth);
      final plData = await api.calculateProfitLoss(month: monthStr);

      // Get daily breakdown for the month
      final year = _selectedMonth.year;
      final month = _selectedMonth.month;
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final List<Map<String, dynamic>> dailyData = [];

      for (int d = 1; d <= daysInMonth; d++) {
        final date = DateTime(year, month, d);
        if (date.isAfter(DateTime.now())) break;
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        try {
          final daySummary = await api.dailyReport(dateStr);
          if (daySummary.grossSales > 0) {
            dailyData.add({
              'date': dateStr,
              'sales': daySummary.grossSales,
              'orders': daySummary.orderCount,
            });
          }
        } catch (_) {}
      }

      setState(() {
        _monthlyData = plData;
        _dailyBreakdown = dailyData;
        _loadingMonthly = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loadingMonthly = false;
      });
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedMonth = picked);
      _loadMonthly();
    }
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDay = picked);
      _loadDaily();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Daily Report'),
            Tab(text: 'Monthly P&L'),
          ],
          onTap: (i) {
            if (i == 0 && _dailyData == null) _loadDaily();
            if (i == 1 && _monthlyData == null) _loadMonthly();
          },
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildDailyTab(),
              _buildMonthlyTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyTab() {
    if (_loadingDaily) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorWidget(message: _error!, onRetry: _loadDaily);
    if (_dailyData == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a date to view report'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _pickDay,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: const Text('Pick Date'),
            ),
          ],
        ),
      );
    }

    final data = _dailyData!;
    final grossSales = data['gross_sales'] as int? ?? 0;
    final orderCount = data['order_count'] as int? ?? 0;
    final byPayment = (data['by_payment'] as Map<String, dynamic>?) ?? {};
    final topItems = (data['top_items'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadDaily,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEE, d MMM yyyy').format(_selectedDay),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: _pickDay,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ReportCard(
                  title: 'Sales',
                  value: '₹$grossSales',
                  icon: Icons.trending_up,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ReportCard(
                  title: 'Orders',
                  value: '$orderCount',
                  icon: Icons.receipt_long,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (byPayment.isNotEmpty) ...[
            Text(
              'Payment Methods',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...byPayment.entries.map((e) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.payment, size: 20),
                    title: Text(e.key.toUpperCase()),
                    trailing: Text(
                      '₹${e.value}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                )),
          ],
          if (topItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Top Items',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...topItems.map((item) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('${item['qty']}'),
                    ),
                    title: Text(item['name'] ?? ''),
                    trailing: Text(
                      '₹${item['revenue'] ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthlyTab() {
    if (_loadingMonthly) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _ErrorWidget(message: _error!, onRetry: _loadMonthly);
    }

    return RefreshIndicator(
      onRefresh: _loadMonthly,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: _pickMonth,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: const Text('Change Month'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_monthlyData != null) ...[
            _ProfitLossSummary(data: _monthlyData!),
            const SizedBox(height: 16),
          ],
          if (_dailyBreakdown.isNotEmpty) ...[
            Text(
              'Day-by-Day Breakdown',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._dailyBreakdown.map((day) {
              final date = DateTime.parse(day['date']);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${date.day}'),
                  ),
                  title: Text(DateFormat('EEE, d MMM').format(date)),
                  subtitle: Text('${day['orders']} orders'),
                  trailing: Text(
                    '₹${day['sales']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              );
            }),
          ],
          if (_dailyBreakdown.isEmpty && !_loadingMonthly)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('No sales data for this month.',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _ReportCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfitLossSummary extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ProfitLossSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    final totalSales = data['total_sales'] as int? ?? 0;
    final totalCost = data['total_cost'] as int? ?? 0;
    final netProfit = data['net_profit'] as int? ?? (totalSales - totalCost);
    final inProfit = data['in_profit'] as bool? ?? true;
    final margin = (data['profit_margin'] as num?) ?? 0;
    final totalOrders = data['total_orders'] as int? ?? 0;
    final suggestion = data['suggestion'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  inProfit ? Icons.trending_up : Icons.trending_down,
                  color: inProfit ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Profit & Loss Statement',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const Divider(),
            _PLRow(label: 'Total Sales', value: '₹$totalSales', color: Colors.green),
            const SizedBox(height: 8),
            _PLRow(label: 'Cost of Goods Sold', value: '₹$totalCost', color: Colors.red),
            const SizedBox(height: 4),
            Text(
              '  Based on $totalOrders orders this month',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const Divider(),
            _PLRow(
              label: inProfit ? 'NET PROFIT' : 'NET LOSS',
              value: '₹${netProfit.abs()}',
              color: inProfit ? Colors.green : Colors.red,
              bold: true,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: inProfit ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Margin: ${margin.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: inProfit ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            if (suggestion != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PLRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _PLRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            fontSize: bold ? 16 : 14,
            color: bold ? color : null,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: bold ? 18 : 15,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorWidget({required this.message, required this.onRetry});

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

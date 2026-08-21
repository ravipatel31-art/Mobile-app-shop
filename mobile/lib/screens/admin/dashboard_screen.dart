import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/sales_summary.dart';
import '../../services/api_client.dart';
import '../../state/auth_state.dart';
import '../../util/money.dart';

/// Vibrant & playful sales dashboard: soft cream background with colorful
/// blobs, emoji accents, candy gradients, and an interactive range switcher.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _fmt = DateFormat('yyyy-MM-dd');
  DateTime _selected = DateTime.now();
  String _range = 'today'; // today | 7d | 30d
  SalesSummary? _agg; // headline figures for the selected range
  List<SalesSummary> _series = []; // chart series for the range
  bool _loading = true;
  String? _error;

  bool get _isToday => _range == 'today';

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
      final date = _fmt.format(_selected);
      final days = _range == '7d' ? 7 : _range == '30d' ? 30 : 1;
      final from = _fmt.format(_selected.subtract(Duration(days: days - 1)));
      final results = await Future.wait([
        api.dailyReport(date),
        if (days >= 2) api.rangeReport(from, date),
      ]);
      if (!mounted) return;
      final series = days >= 2
          ? results[1] as List<SalesSummary>
          : <SalesSummary>[results[0] as SalesSummary];
      setState(() {
        _agg = _isToday ? results[0] as SalesSummary : _summarize(series);
        _series = series;
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

  static SalesSummary _summarize(List<SalesSummary> series) {
    var gross = 0;
    var orders = 0;
    final byCat = <String, int>{};
    final byPay = <String, int>{};
    for (final s in series) {
      gross += s.grossSales;
      orders += s.orderCount;
      s.byCategory.forEach((k, v) => byCat[k] = (byCat[k] ?? 0) + v);
      s.byPayment.forEach((k, v) => byPay[k] = (byPay[k] ?? 0) + v);
    }
    return SalesSummary(
      date: '',
      orderCount: orders,
      grossSales: gross,
      byCategory: byCat,
      byPayment: byPay,
      topItems: const [],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selected = picked);
      _load();
    }
  }

  int? _deltaPct() {
    if (_series.length < 2) return null;
    final cur = _series.last.grossSales;
    final prev = _isToday
        ? _series[_series.length - 2].grossSales
        : _series.first.grossSales;
    if (prev <= 0) return null;
    return ((cur - prev) * 100 / prev).round();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _RetryView(message: _error!, onRetry: _load);
    final scheme = Theme.of(context).colorScheme;
    final agg = _agg!;
    final ownerName = context.read<AuthState>().name ?? 'Owner';
    final delta = _deltaPct();
    final avg =
        agg.orderCount == 0 ? 0 : (agg.grossSales / agg.orderCount).round();
    final isLive = _isToday &&
        _fmt.format(_selected) == _fmt.format(DateTime.now());

    return Stack(
      children: [
        // Playful background blobs.
        const Positioned(top: -50, right: -40, child: _Blob(color: Color(0xFFFFB27D), size: 190)),
        const Positioned(top: 170, left: -70, child: _Blob(color: Color(0xFF7CE7D8), size: 170)),
        const Positioned(bottom: 140, right: -60, child: _Blob(color: Color(0xFFF8B5D2), size: 180)),
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('👋 Hey, ${ownerName.split(' ').first}!',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          isLive
                              ? 'Have a great day · ${DateFormat('EEEE, d MMM').format(_selected)}'
                              : DateFormat('EEEE, d MMM').format(_selected),
                          style: TextStyle(
                              fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Change date',
                    onPressed: _pickDate,
                    icon: Icon(Icons.calendar_month_outlined,
                        color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _RangeSelector(
                value: _range,
                onChanged: (r) {
                  setState(() => _range = r);
                  _load();
                },
              ),
              const SizedBox(height: 16),
              _TotalCard(
                total: agg.grossSales,
                orders: agg.orderCount,
                delta: delta,
                isToday: _isToday,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      emoji: '🧾',
                      label: 'Orders',
                      value: '${agg.orderCount}',
                      colors: const [Color(0xFFFF9A62), Color(0xFFF97316)],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      emoji: '💰',
                      label: 'Avg order',
                      value: formatMoney(avg),
                      colors: const [Color(0xFF5EE0CE), Color(0xFF14B8A6)],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      emoji: '⚡',
                      label: 'Peak day',
                      value: _peakDay(),
                      colors: const [Color(0xFFF8A9C8), Color(0xFFEC4899)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Card(
                title: '📈 Sales over time',
                child: SizedBox(
                    height: 180, child: _TrendBars(series: _series)),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final pay = agg.byPayment.isNotEmpty
                      ? _Card(
                          title: '💳 Payments',
                          child: _PaymentDonut(byPayment: agg.byPayment))
                      : null;
                  final best = _isToday && agg.topItems.isNotEmpty
                      ? _Card(
                          title: '🏆 Best sellers',
                          child: Column(
                            children: [
                              for (var i = 0; i < agg.topItems.length; i++)
                                _TopSellerRow(index: i, item: agg.topItems[i]),
                            ],
                          ),
                        )
                      : null;
                  if (pay == null && best == null) {
                    return const SizedBox.shrink();
                  }
                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: [
                        if (pay != null) pay,
                        if (pay != null && best != null)
                          const SizedBox(height: 16),
                        if (best != null) best,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pay != null) Expanded(child: pay),
                      if (pay != null && best != null)
                        const SizedBox(width: 16),
                      if (best != null) Expanded(child: best),
                    ],
                  );
                },
              ),
              if (agg.byCategory.isNotEmpty) ...[
                const SizedBox(height: 16),
                _Card(
                  title: '🍩 By category',
                  child: _CategoryBars(
                      entries: agg.byCategory.entries.toList()),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _peakDay() {
    if (_series.isEmpty) return '—';
    var best = _series.first;
    for (final s in _series) {
      if (s.grossSales > best.grossSales) best = s;
    }
    if (best.grossSales == 0 || best.date.isEmpty) return '—';
    final d = DateTime.tryParse(best.date);
    return d == null ? '—' : DateFormat('E').format(d);
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _RangeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'today', label: Text('Today')),
        ButtonSegment(value: '7d', label: Text('7 days')),
        ButtonSegment(value: '30d', label: Text('30 days')),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        selectedBackgroundColor: const Color(0xFFFF9A62),
        selectedForegroundColor: Colors.white,
        side: BorderSide.none,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final int total;
  final int orders;
  final int? delta;
  final bool isToday;
  const _TotalCard({
    required this.total,
    required this.orders,
    required this.delta,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFA56B), Color(0xFFFFC371)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -6,
            top: -14,
            child: Text('🍩',
                style: TextStyle(
                    fontSize: 76,
                    color: Colors.white.withValues(alpha: 0.3))),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'TODAY\'S SALES' : 'TOTAL SALES',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1),
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: total.toDouble()),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatMoney(v.round()),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (delta != null) ...[
                      _DeltaPill(delta: delta!),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('🧾 $orders orders',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  final int delta;
  const _DeltaPill({required this.delta});

  @override
  Widget build(BuildContext context) {
    final up = delta >= 0;
    final color = up ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
    final bg = up ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 13, color: color),
          const SizedBox(width: 2),
          Text('${up ? '+' : ''}$delta%',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final List<Color> colors;
  const _MetricTile({
    required this.emoji,
    required this.label,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _TrendBars extends StatelessWidget {
  final List<SalesSummary> series;
  const _TrendBars({required this.series});

  static const _colors = [
    Color(0xFFF97316),
    Color(0xFF14B8A6),
    Color(0xFFEC4899),
    Color(0xFFFBBF24),
    Color(0xFF8B5CF6),
  ];

  @override
  Widget build(BuildContext context) {
    final values = series.map((s) => s.grossSales.toDouble()).toList();
    final maxV = values.fold<double>(0, (m, v) => v > m ? v : m);
    final maxY = maxV == 0 ? 100.0 : maxV * 1.2;
    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
              formatMoney(rod.toY.round()),
              const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= series.length) return const SizedBox();
                final date = DateTime.tryParse(series[i].date);
                final label = date == null ? '' : DateFormat('d/M').format(date);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: 18,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _colors[i % _colors.length].withValues(alpha: 0.9),
                      _colors[i % _colors.length].withValues(alpha: 0.35),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String _payEmoji(String m) {
  switch (m) {
    case 'cash':
      return '💵';
    case 'card':
      return '💳';
    case 'upi':
      return '📲';
    case 'gpay':
      return '🔷';
    default:
      return '💰';
  }
}

class _PaymentDonut extends StatelessWidget {
  final Map<String, int> byPayment;
  const _PaymentDonut({required this.byPayment});

  static const _colors = [
    Color(0xFFF97316),
    Color(0xFF14B8A6),
    Color(0xFFEC4899),
    Color(0xFFFBBF24),
    Color(0xFF8B5CF6),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = byPayment.entries.toList();
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 44,
                  startDegreeOffset: -90,
                  sections: [
                    for (var i = 0; i < entries.length; i++)
                      PieChartSectionData(
                        value: entries[i].value.toDouble(),
                        color: _colors[i % _colors.length],
                        radius: 42,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(formatMoney(total),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                  Text('sales',
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(_payEmoji(entries[i].key),
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_pretty(entries[i].key),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(formatMoney(entries[i].value),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopSellerRow extends StatelessWidget {
  final int index;
  final TopItem item;
  const _TopSellerRow({required this.index, required this.item});

  static const _medalColors = [
    Color(0xFFEAB308),
    Color(0xFF94A3B8),
    Color(0xFFD97706),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final medal = index < 3;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: medal
                ? _medalColors[index].withValues(alpha: 0.2)
                : scheme.surfaceContainerHighest,
            child: Text(
              medal ? '🥇🥈🥉'.substring(index * 2, index * 2 + 2) : '${index + 1}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: medal ? _medalColors[index] : scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('${item.qty}× ${item.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ),
          Text(formatMoney(item.revenue),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CategoryBars extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  const _CategoryBars({required this.entries});

  static const _colors = [
    Color(0xFFF97316),
    Color(0xFF14B8A6),
    Color(0xFFEC4899),
    Color(0xFFFBBF24),
    Color(0xFF8B5CF6),
  ];

  @override
  Widget build(BuildContext context) {
    final maxVal = entries.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                    width: 90,
                    child: Text(entries[i].key.replaceAll('_', ' ').trim(),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: maxVal == 0 ? 0 : entries[i].value / maxVal,
                      minHeight: 10,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.7),
                      color: _colors[i % _colors.length],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                    width: 70,
                    child: Text(formatMoney(entries[i].value),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
      ],
    );
  }
}

class _RetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _RetryView({required this.message, required this.onRetry});

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

String _pretty(String s) => s
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

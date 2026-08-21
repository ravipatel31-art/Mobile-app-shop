class TopItem {
  final String name;
  final int qty;
  final int revenue;

  const TopItem({required this.name, required this.qty, required this.revenue});

  factory TopItem.fromJson(Map<String, dynamic> json) => TopItem(
        name: json['name'] as String,
        qty: (json['qty'] ?? 0) as int,
        revenue: (json['revenue'] ?? 0) as int,
      );
}

class SalesSummary {
  final String date;
  final int orderCount;
  final int grossSales;
  final Map<String, int> byCategory;
  final Map<String, int> byPayment;
  final List<TopItem> topItems;

  const SalesSummary({
    required this.date,
    required this.orderCount,
    required this.grossSales,
    required this.byCategory,
    required this.byPayment,
    required this.topItems,
  });

  static Map<String, int> _intMap(dynamic raw) {
    final map = (raw ?? {}) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, (v ?? 0) as int));
  }

  factory SalesSummary.fromJson(Map<String, dynamic> json) => SalesSummary(
        date: (json['date'] ?? '') as String,
        orderCount: (json['order_count'] ?? 0) as int,
        grossSales: (json['gross_sales'] ?? 0) as int,
        byCategory: _intMap(json['by_category']),
        byPayment: _intMap(json['by_payment']),
        topItems: ((json['top_items'] ?? []) as List)
            .map((t) => TopItem.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}

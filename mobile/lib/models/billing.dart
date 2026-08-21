import 'order.dart';

/// A day's worth of collected orders as returned by /admin/billing.
class BillingDay {
  final String date;
  final List<CafeOrder> orders;
  final int orderCount;
  final int total;
  final int paid;
  final int unpaid;
  final Map<String, int> byPayment;

  const BillingDay({
    required this.date,
    required this.orders,
    required this.orderCount,
    required this.total,
    required this.paid,
    required this.unpaid,
    required this.byPayment,
  });

  static Map<String, int> _intMap(dynamic raw) {
    final map = (raw ?? {}) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, (v ?? 0) as int));
  }

  factory BillingDay.fromJson(Map<String, dynamic> json) => BillingDay(
        date: (json['date'] ?? '') as String,
        orders: ((json['orders'] ?? []) as List)
            .map((o) => CafeOrder.fromJson(o as Map<String, dynamic>))
            .toList(),
        orderCount: (json['order_count'] ?? 0) as int,
        total: (json['total'] ?? 0) as int,
        paid: (json['paid'] ?? 0) as int,
        unpaid: (json['unpaid'] ?? 0) as int,
        byPayment: _intMap(json['by_payment']),
      );
}

/// Aggregated billing view for the owner: collected orders grouped by day.
class BillingSummary {
  final List<BillingDay> days;
  final int orderCount;
  final int total;
  final int paid;
  final int unpaid;

  const BillingSummary({
    required this.days,
    required this.orderCount,
    required this.total,
    required this.paid,
    required this.unpaid,
  });

  factory BillingSummary.fromJson(Map<String, dynamic> json) {
    final summary = (json['summary'] ?? {}) as Map<String, dynamic>;
    return BillingSummary(
      days: ((json['days'] ?? []) as List)
          .map((d) => BillingDay.fromJson(d as Map<String, dynamic>))
          .toList(),
      orderCount: (summary['order_count'] ?? 0) as int,
      total: (summary['total'] ?? 0) as int,
      paid: (summary['paid'] ?? 0) as int,
      unpaid: (summary['unpaid'] ?? 0) as int,
    );
  }
}

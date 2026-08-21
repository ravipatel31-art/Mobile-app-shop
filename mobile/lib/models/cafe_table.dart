class CafeTable {
  final String number;
  final String status; // "empty" | "occupied"
  final String? orderId;
  final String? takenBy; // staff member serving this table, if occupied

  const CafeTable({
    required this.number,
    required this.status,
    required this.orderId,
    required this.takenBy,
  });

  bool get isOccupied => status == 'occupied';

  factory CafeTable.fromJson(Map<String, dynamic> json) => CafeTable(
        number: json['number'].toString(),
        status: (json['status'] ?? 'empty') as String,
        orderId: json['order_id'] as String?,
        takenBy: json['taken_by'] as String?,
      );
}

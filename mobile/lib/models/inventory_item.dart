class InventoryItem {
  final String id;
  final String name;
  final int quantity;
  final int costPrice; // in minor units (paise/cents)
  final String? purchaseDate;
  final String? lastRestocked;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.costPrice,
    this.purchaseDate,
    this.lastRestocked,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'] as String,
        name: json['name'] as String,
        quantity: _toInt(json['quantity'] ?? 0),
        costPrice: _toInt(json['cost_price'] ?? 0),
        purchaseDate: json['purchase_date'] as String?,
        lastRestocked: json['last_restocked'] as String?,
      );

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is double) return v.toInt();
    return 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'cost_price': costPrice,
        'purchase_date': purchaseDate,
        'last_restocked': lastRestocked,
      };

  int get totalValue => quantity * costPrice;
}

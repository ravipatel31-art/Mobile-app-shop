class InventoryItem {
  final String id;
  final String name;
  final int quantity;
  final int costPrice; // in minor units (paise/cents)
  final int salePrice; // in minor units (paise/cents)
  final String? lastRestocked;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.costPrice,
    required this.salePrice,
    this.lastRestocked,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'] as String,
        name: json['name'] as String,
        quantity: (json['quantity'] ?? 0) as int,
        costPrice: (json['cost_price'] ?? 0) as int,
        salePrice: (json['sale_price'] ?? 0) as int,
        lastRestocked: json['last_restocked'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'cost_price': costPrice,
        'sale_price': salePrice,
        'last_restocked': lastRestocked,
      };

  int get totalValue => quantity * costPrice;
  int get potentialProfit => quantity * (salePrice - costPrice);
}
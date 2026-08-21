import 'option_group.dart';

class MenuItem {
  final String id;
  final String name;
  final String description;
  final String category;
  final int basePrice; // minor units
  final String? imageUrl;
  final bool available;
  final List<OptionGroup> options;

  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.basePrice,
    required this.imageUrl,
    required this.available,
    required this.options,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'] as String,
        name: json['name'] as String,
        description: (json['description'] ?? '') as String,
        category: (json['category'] ?? 'other') as String,
        basePrice: (json['base_price'] ?? 0) as int,
        imageUrl: json['image_url'] as String?,
        available: (json['available'] ?? true) as bool,
        options: ((json['options'] ?? []) as List)
            .map((o) => OptionGroup.fromJson(o as Map<String, dynamic>))
            .toList(),
      );
}

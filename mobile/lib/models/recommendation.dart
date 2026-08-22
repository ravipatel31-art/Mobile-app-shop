import 'menu_item.dart';
import 'option_group.dart';

/// One AI suggestion from POST /recommend.
///
/// [defaultOptions] carries the first choice of each required single-choice
/// option group so the strip can add the item in one tap; when the item has
/// a required group with no obvious default ([safeToAutopick] is false) the
/// UI opens the detail screen instead.
class Suggestion {
  final MenuItem item;
  final String reason;
  final int unitPrice; // minor units, base price + default option deltas
  final List<SelectedOption> defaultOptions;
  final bool safeToAutopick;

  const Suggestion({
    required this.item,
    required this.reason,
    required this.unitPrice,
    required this.defaultOptions,
    required this.safeToAutopick,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) => Suggestion(
        item: MenuItem.fromJson(json['item'] as Map<String, dynamic>),
        reason: (json['reason'] ?? '') as String,
        unitPrice: (json['unit_price'] ?? 0) as int,
        defaultOptions: ((json['default_options'] ?? []) as List)
            .map((o) => SelectedOption.fromJson(o as Map<String, dynamic>))
            .toList(),
        safeToAutopick: (json['safe_to_autopick'] ?? false) as bool,
      );
}

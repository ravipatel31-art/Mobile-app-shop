class OptionChoice {
  final String label;
  final int priceDelta;

  const OptionChoice({required this.label, required this.priceDelta});

  factory OptionChoice.fromJson(Map<String, dynamic> json) => OptionChoice(
        label: json['label'] as String,
        priceDelta: (json['price_delta'] ?? 0) as int,
      );
}

class OptionGroup {
  final String group;
  final bool required;
  final bool multi;
  final List<OptionChoice> choices;

  const OptionGroup({
    required this.group,
    required this.required,
    required this.multi,
    required this.choices,
  });

  factory OptionGroup.fromJson(Map<String, dynamic> json) => OptionGroup(
        group: json['group'] as String,
        required: (json['required'] ?? false) as bool,
        multi: (json['multi'] ?? false) as bool,
        choices: ((json['choices'] ?? []) as List)
            .map((c) => OptionChoice.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

/// A single chosen option, sent back to the server as {group, label}.
class SelectedOption {
  final String group;
  final String label;

  const SelectedOption({required this.group, required this.label});

  Map<String, dynamic> toJson() => {'group': group, 'label': label};

  factory SelectedOption.fromJson(Map<String, dynamic> json) => SelectedOption(
        group: json['group'] as String,
        label: json['label'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is SelectedOption && other.group == group && other.label == label;

  @override
  int get hashCode => Object.hash(group, label);
}

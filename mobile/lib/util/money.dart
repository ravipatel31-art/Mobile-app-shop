import '../config.dart';

/// Money is stored as integers in minor units (paise/cents). Format for display.
String formatMoney(int minorUnits) {
  final major = minorUnits / 100.0;
  return '${AppConfig.currencySymbol}${major.toStringAsFixed(2)}';
}

/// Space-tight display for badges: whole rupees, thousands-separated —
/// "₹1,240". Paise here would push a quick-action tile's label into a
/// mid-word wrap on a phone-width screen.
String formatMoneyCompact(int minorUnits) {
  final rupees = (minorUnits / 100).round();
  final grouped = rupees.abs().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  final sign = rupees < 0 ? '-' : '';
  return '$sign${AppConfig.currencySymbol}$grouped';
}

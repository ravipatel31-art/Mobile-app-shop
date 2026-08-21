import '../config.dart';

/// Money is stored as integers in minor units (paise/cents). Format for display.
String formatMoney(int minorUnits) {
  final major = minorUnits / 100.0;
  return '${AppConfig.currencySymbol}${major.toStringAsFixed(2)}';
}

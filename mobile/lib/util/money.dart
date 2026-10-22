import '../config.dart';

/// Groups the integer part of a rupee amount with thousands separators:
/// `119200` → `119,200`. Paise are never grouped (they're only two digits).
///
/// `toStringAsFixed` renders the number as a plain string, which for anything
/// past 999 reads as `119200.00` — a raw database value rather than a price a
/// café owner parses at a glance. Every other money surface in the app (POS
/// receipts, banking apps, the invoice this gets printed on) groups them.
String _groupThousands(String plain) {
  final negative = plain.startsWith('-');
  final body = negative ? plain.substring(1) : plain;
  final dot = body.indexOf('.');
  final end = dot == -1 ? body.length : dot;
  final intPart = body.substring(0, end);
  final grouped =
      intPart.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '${negative ? '-' : ''}$grouped${body.substring(end)}';
}

/// Money is stored as integers in minor units (paise/cents). Format for display.
String formatMoney(int minorUnits) {
  final major = minorUnits / 100.0;
  return '${AppConfig.currencySymbol}${_groupThousands(major.toStringAsFixed(2))}';
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

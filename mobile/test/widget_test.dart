import 'package:flutter_test/flutter_test.dart';

import 'package:cafe_app/util/money.dart';

void main() {
  test('formatMoney renders minor units as currency', () {
    expect(formatMoney(0), '₹0.00');
    expect(formatMoney(50), '₹0.50');
    expect(formatMoney(900), '₹9.00');
    expect(formatMoney(123456), '₹1234.56');
  });
}

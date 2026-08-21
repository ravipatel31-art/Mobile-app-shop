import 'package:flutter/foundation.dart';

import '../models/cart.dart';
import '../models/menu_item.dart';
import '../models/option_group.dart';

class CartState extends ChangeNotifier {
  final List<CartLine> _lines = [];
  String? _customerName;
  String? _customerPhone;

  List<CartLine> get lines => List.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;

  /// Just the item payload, for adding items to an existing order.
  List<Map<String, dynamic>> get itemsJson =>
      _lines.map((l) => l.toOrderItemJson()).toList();
  int get count => _lines.fold(0, (sum, l) => sum + l.qty);
  int get total => _lines.fold(0, (sum, l) => sum + l.lineTotal);
  String? get customerName => _customerName;
  String? get customerPhone => _customerPhone;

  // Bumped whenever the set of tables changes in a way the staff tables grid
  // should reflect (a new order placed, or a collected order reopened). The
  // grid subscribes because it stays alive inside the IndexedStack.
  int _tablesTick = 0;
  int get tablesTick => _tablesTick;

  void tablesChanged() {
    _tablesTick++;
    notifyListeners();
  }

  void setCustomerInfo({String? name, String? phone}) {
    _customerName = name;
    _customerPhone = phone;
    notifyListeners();
  }

  void add(MenuItem item, List<SelectedOption> options, int qty) {
    _lines.add(CartLine(item: item, selectedOptions: options, qty: qty));
    notifyListeners();
  }

  void setQty(int index, int qty) {
    if (index < 0 || index >= _lines.length) return;
    if (qty <= 0) {
      _lines.removeAt(index);
    } else {
      _lines[index].qty = qty;
    }
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _lines.length) return;
    _lines.removeAt(index);
    notifyListeners();
  }

  /// Remove a specific line object (used when adding picked items to an
  /// existing order, so an unrelated in-progress cart is left untouched).
  void removeLine(CartLine line) {
    final i = _lines.indexOf(line);
    if (i >= 0) {
      _lines.removeAt(i);
      notifyListeners();
    }
  }

  void clear() {
    _lines.clear();
    _customerName = null;
    _customerPhone = null;
    notifyListeners();
  }

  Map<String, dynamic> buildOrderPayload({
    String? name,
    String? phone,
    String pickupType = 'table',
    String notes = '',
    String? tableNumber,
    String paymentMethod = 'cash',
  }) =>
      {
        'customer': {
          'name': name ??
              _customerName ??
              (tableNumber != null ? 'Table $tableNumber' : 'Guest'),
          if ((phone ?? _customerPhone)?.isNotEmpty ?? false)
            'phone': phone ?? _customerPhone,
        },
        'pickup_type': pickupType,
        if (tableNumber != null) 'table_number': tableNumber,
        'notes': notes,
        'payment_method': paymentMethod,
        'items': _lines.map((l) => l.toOrderItemJson()).toList(),
      };
}

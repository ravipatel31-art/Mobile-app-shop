import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/ask_result.dart';
import '../models/billing.dart';
import '../models/cafe_table.dart';
import '../models/cart.dart';
import '../models/inventory_item.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/recommendation.dart';
import '../models/sales_summary.dart';
import '../models/staff_member.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Thin HTTP wrapper around the Flask backend. Shared via Provider; set [token]
/// after login so authorized calls carry the bearer token.
class ApiClient {
  ApiClient({http.Client? client}) : _http = client ?? http.Client();

  /// Upper bound for any single HTTP request. Without this, a backend that is
  /// unreachable but still accepts the connection can hang the UI forever on a
  /// spinner (reported as the app "sticking" on a tab).
  static const Duration _timeout = Duration(seconds: 5);

  /// AI endpoints call a local LLM on the backend host (~15-25 s per answer),
  /// so they get a much longer ceiling than normal requests.
  static const Duration _aiTimeout = Duration(seconds: 40);

  /// The agentic assistant may make two LLM calls per question (~20-30 s
  /// total on the backend host's CPU).
  static const Duration _askTimeout = Duration(seconds: 75);

  final http.Client _http;
  String? token;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleaned = <String, String>{};
    if (query != null) {
      query.forEach((k, v) {
        if (v != null) cleaned[k] = v.toString();
      });
    }
    return Uri.parse('${AppConfig.baseUrl}$path')
        .replace(queryParameters: cleaned.isEmpty ? null : cleaned);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final msg = (body is Map && body['error'] != null)
        ? body['error'] as String
        : 'Request failed (${res.statusCode})';
    throw ApiException(msg, statusCode: res.statusCode);
  }

  Future<dynamic> _get(String path, [Map<String, dynamic>? query]) async {
    try {
      return _decode(
          await _http.get(_uri(path, query), headers: _headers).timeout(_timeout));
    } on TimeoutException {
      throw ApiException('Cannot reach the server. Is the backend running?');
    } on SocketException {
      throw ApiException('Cannot reach the server. Is the backend running?');
    } on http.ClientException {
      throw ApiException('Cannot reach the server. Is the backend running?');
    }
  }

  Future<dynamic> _send(String method, String path, Object? body,
      {Duration? timeout}) async {
    final t = timeout ?? _timeout;
    try {
      final req = http.Request(method, _uri(path))..headers.addAll(_headers);
      if (body != null) req.body = jsonEncode(body);
      final streamed = await _http.send(req).timeout(t);
      return _decode(await http.Response.fromStream(streamed).timeout(t));
    } on TimeoutException {
      throw ApiException('Cannot reach the server. Is the backend running?');
    } on SocketException {
      throw ApiException('Cannot reach the server. Is the backend running?');
    } on http.ClientException {
      throw ApiException('Cannot reach the server. Is the backend running?');
    }
  }

  // ---- Auth ----
  Future<Map<String, dynamic>> login(String username, String password) async {
    return await _send('POST', '/auth/login',
        {'username': username, 'password': password}) as Map<String, dynamic>;
  }

  Future<void> register(String username, String password, String name) async {
    await _send('POST', '/auth/register',
        {'username': username, 'password': password, 'name': name});
  }

  // ---- Menu (read is open) ----
  Future<List<MenuItem>> fetchMenu({String? category}) async {
    final data = await _get('/menu', {'category': category}) as List;
    return data.map((e) => MenuItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<String>> fetchCategories() async {
    final data = await _get('/categories') as List;
    return data.cast<String>();
  }

  // ---- AI recommendations (staff/owner) ----
  Future<List<Suggestion>> fetchRecommendations(List<CartLine> cart) async {
    final data = await _send('POST', '/recommend', {
      'cart': [
        for (final line in cart)
          {'item_id': line.item.id, 'qty': line.qty},
      ],
    }, timeout: _aiTimeout) as Map<String, dynamic>;
    return ((data['suggestions'] ?? []) as List)
        .map((e) => Suggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- AI assistant (staff/owner) ----
  Future<AskResult> askQuestion(String question) async {
    final data = await _send('POST', '/ask', {'question': question},
            timeout: _askTimeout)
        as Map<String, dynamic>;
    return AskResult.fromJson(data);
  }

  /// Runs a previously-proposed pending action after the user confirmed it.
  Future<Map<String, dynamic>> executeAction(
      String action, Map<String, dynamic> args) async {
    return await _send('POST', '/ask/execute',
            {'action': action, 'args': args}, timeout: _aiTimeout)
        as Map<String, dynamic>;
  }

  // ---- Orders (staff/owner) ----
  Future<CafeOrder> placeOrder(Map<String, dynamic> payload) async {
    final data = await _send('POST', '/orders', payload) as Map<String, dynamic>;
    return CafeOrder.fromJson(data);
  }

  Future<CafeOrder> fetchOrder(String id) async {
    final data = await _get('/orders/$id') as Map<String, dynamic>;
    return CafeOrder.fromJson(data);
  }

  Future<List<CafeOrder>> fetchOrders(
      {String? status, String? date, String? takenBy}) async {
    final data = await _get('/orders',
        {'status': status, 'date': date, 'taken_by': takenBy}) as List;
    return data
        .map((e) => CafeOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CafeOrder> updateOrderStatus(
    String id,
    String status, {
    bool paid = false,
    String? paymentMethod,
    String? paymentToken,
  }) async {
    final data = await _send('PATCH', '/orders/$id/status', {
      'status': status,
      if (paid) 'paid': true,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (paymentToken != null) 'payment_token': paymentToken,
    }) as Map<String, dynamic>;
    return CafeOrder.fromJson(data);
  }

  Future<CafeOrder> reopenOrder(String id) async {
    final data = await _send('POST', '/orders/$id/reopen', {})
        as Map<String, dynamic>;
    return CafeOrder.fromJson(data);
  }

  Future<CafeOrder> addOrderItems(
      String id, List<Map<String, dynamic>> items) async {
    final data = await _send('POST', '/orders/$id/items', {'items': items})
        as Map<String, dynamic>;
    return CafeOrder.fromJson(data);
  }

  // ---- Tables ----
  Future<List<CafeTable>> fetchTables() async {
    final data = await _get('/tables') as List;
    return data.map((e) => CafeTable.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> freeTable(String number) async {
    await _send('POST', '/tables/$number/free', {});
  }

  Future<CafeTable> addTable({int? number}) async {
    final data = await _send('POST', '/admin/tables',
        {if (number != null) 'number': number}) as Map<String, dynamic>;
    return CafeTable.fromJson(data);
  }

  Future<void> removeTable(String number) async {
    await _send('DELETE', '/admin/tables/$number', null);
  }

  // ---- Staff (owner) ----
  Future<List<StaffMember>> fetchStaff() async {
    final data = await _get('/admin/staff') as List;
    return data
        .map((e) => StaffMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> approveStaff(String username) async {
    await _send('POST', '/admin/staff/$username/approve', {});
  }

  Future<void> removeStaff(String username) async {
    await _send('DELETE', '/admin/staff/$username', null);
  }

  Future<void> createStaff(String username, String password, String name) async {
    await _send('POST', '/admin/staff',
        {'username': username, 'password': password, 'name': name});
  }

  // ---- Reports (owner) ----
  Future<SalesSummary> dailyReport(String date) async {
    final data =
        await _get('/admin/reports/daily', {'date': date}) as Map<String, dynamic>;
    return SalesSummary.fromJson(data);
  }

  Future<List<SalesSummary>> rangeReport(String from, String to) async {
    final data =
        await _get('/admin/reports/range', {'from': from, 'to': to}) as List;
    return data
        .map((e) => SalesSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- Billing (owner) ----
  Future<BillingSummary> fetchBilling({String? date}) async {
    final data = await _get('/admin/billing', {'date': date})
        as Map<String, dynamic>;
    return BillingSummary.fromJson(data);
  }

  Future<CafeOrder> markOrderPaid(String id) async {
    final data = await _send('POST', '/admin/billing/$id/paid', {})
        as Map<String, dynamic>;
    return CafeOrder.fromJson(data);
  }

  // ---- Menu management (owner) ----
  Future<MenuItem> createMenuItem(Map<String, dynamic> payload) async {
    final data =
        await _send('POST', '/admin/menu', payload) as Map<String, dynamic>;
    return MenuItem.fromJson(data);
  }

  Future<MenuItem> setAvailability(String id, bool available) async {
    final data = await _send(
            'PATCH', '/admin/menu/$id/availability', {'available': available})
        as Map<String, dynamic>;
    return MenuItem.fromJson(data);
  }

  Future<void> deleteMenuItem(String id) async {
    await _send('DELETE', '/admin/menu/$id', null);
  }

  // ---- Inventory (owner) ----
  Future<List<InventoryItem>> fetchInventory() async {
    final data =
        await _get('/admin/inventory') as List;
    return data
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> fetchInventorySummary() async {
    final data = await _get('/admin/inventory/summary') as Map<String, dynamic>;
    return data;
  }

  Future<InventoryItem> createInventoryItem(Map<String, dynamic> payload) async {
    final data = await _send('POST', '/admin/inventory', payload) as Map<String, dynamic>;
    return InventoryItem.fromJson(data);
  }

  Future<InventoryItem> updateInventoryItem(String id, Map<String, dynamic> payload) async {
    final data = await _send('PUT', '/admin/inventory/$id', payload) as Map<String, dynamic>;
    return InventoryItem.fromJson(data);
  }

  Future<InventoryItem> restockItem(String id, int quantity) async {
    final data = await _send('POST', '/admin/inventory/$id/restock', {'quantity': quantity}) as Map<String, dynamic>;
    return InventoryItem.fromJson(data);
  }

  Future<void> deleteInventoryItem(String id) async {
    await _send('DELETE', '/admin/inventory/$id', null);
  }

  Future<Map<String, dynamic>> calculateProfitLoss({String? month}) async {
    final date = month ?? DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: DateTime.now().day - 1)));
    final data = await _get('/admin/reports/profit-loss', {'month': date}) as Map<String, dynamic>;
    return data;
  }
}

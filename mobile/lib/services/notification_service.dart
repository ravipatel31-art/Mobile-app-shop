import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Simple local notification service for order-ready alerts.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Call once at app startup (main.dart).
  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  /// Show a notification when an order is ready to serve.
  static Future<void> showOrderReady({
    required String orderId,
    required String customerName,
    required String? tableNumber,
  }) async {
    final title = tableNumber != null
        ? 'Table $tableNumber - Order Ready!'
        : 'Order #$orderId Ready!';

    final body = customerName.isNotEmpty
        ? '$customerName\'s order is ready to serve.'
        : 'Order #$orderId is ready.';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'order_ready',
        'Order Ready',
        channelDescription: 'Notifies when an order is ready to serve',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.show(
      orderId.hashCode,
      title,
      body,
      details,
    );
  }
}

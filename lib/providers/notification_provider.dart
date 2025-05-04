import 'package:flutter/foundation.dart';

class NotificationModel {
  final String title;
  final String body;
  final DateTime timestamp;
  final String type;
  final Map<String, dynamic>? payload;

  NotificationModel({
    required this.title, 
    required this.body, 
    required this.timestamp, 
    this.type = '',
    this.payload,
  });
}

class NotificationProvider with ChangeNotifier {
  final List<NotificationModel> _notifications = [];
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  void addNotification(String title, String body, {String type = '', Map<String, dynamic>? payload}) {
    // Add to the beginning of the list
    _notifications.insert(0, NotificationModel(
      title: title, 
      body: body, 
      timestamp: DateTime.now(),
      type: type,
      payload: payload,
    ));
    _unreadCount++;
    // Optional: Limit the number of stored notifications
    if (_notifications.length > 50) {
      _notifications.removeLast();
    }
    notifyListeners();
  }

  void markAsRead() {
    _unreadCount = 0;
    notifyListeners();
  }

  void removeNotification(NotificationModel notificationToRemove) {
    final index = _notifications.indexWhere((notification) => notification == notificationToRemove);
    if (index != -1) {
      _notifications.removeAt(index);
      notifyListeners();
    }
  }

  void clearNotifications() {
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }
}

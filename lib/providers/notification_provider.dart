import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:loczy/config_getter.dart';

class NotificationModel {
  final String title;
  final String body;
  final String type;
  final DateTime time;
  final Map<String, dynamic>? payload;
  final int? notificationId; // Added field for database ID
  bool isRead;

  NotificationModel({
    required this.title,
    required this.body,
    this.type = 'default',
    required this.time,
    this.payload,
    this.notificationId, // Added parameter
    this.isRead = false,
  });
}

class NotificationProvider with ChangeNotifier {
  final List<NotificationModel> _notifications = [];
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  void addNotification(
    String title, 
    String body, 
    {String type = 'default', 
    Map<String, dynamic>? payload,
    int? notificationId} // Added parameter
  ) {
    final notification = NotificationModel(
      title: title,
      body: body,
      type: type,
      time: DateTime.now(),
      payload: payload,
      notificationId: notificationId, // Pass database ID
      isRead: false,
    );

    _notifications.insert(0, notification);
    _unreadCount++;

    notifyListeners();
  }

  void removeNotification(NotificationModel notification) {
    _notifications.remove(notification);
    
    if (!notification.isRead) {
      _unreadCount--;
    }
    
    // If we have a database ID, mark it as read in the database
    if (notification.notificationId != null) {
      _markNotificationAsReadInDatabase(notification.notificationId!);
    }
    
    notifyListeners();
  }

  void markAsRead() {
    if (_unreadCount > 0) {
      for (var notification in _notifications) {
        if (!notification.isRead) {
          notification.isRead = true;
          
          // Mark each unread notification as read in the database
          if (notification.notificationId != null) {
            _markNotificationAsReadInDatabase(notification.notificationId!);
          }
        }
      }
      _unreadCount = 0;
      notifyListeners();
    }
  }

  void clearNotifications() {
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }
  
  // New method to mark notification as read in database
  Future<void> _markNotificationAsReadInDatabase(int notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('${ConfigLoader.apiUrl}/routers/notifications.php'),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'notification_id': notificationId}),
      );
      
      if (response.statusCode != 200) {
        print('Failed to mark notification $notificationId as read in database: ${response.statusCode}');
      }
    } catch (e) {
      print('Error marking notification as read in database: $e');
    }
  }
}

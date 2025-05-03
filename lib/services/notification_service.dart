import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:loczy/pages/chat_page.dart';
import 'package:http/http.dart' as http;
import 'package:loczy/config_getter.dart';

// Add this variable to hold navigation context globally
GlobalKey<NavigatorState>? navigatorKey;

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Use your app icon

    // Request permissions for iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Request notification permissions for Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
            'loczy_channel_id', // id
            'Loczy Notifications', // title
            description: 'Channel for Loczy app notifications.', // description
            importance: Importance.max,
        ));

     // Request permissions for Android 13+ explicitly
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
     // Request permissions for iOS explicitly
     await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Set up notification click handler
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response.payload);
      },
    );
  }

  // Enhanced to accept payload data
  Future<void> showNotification(int id, String title, String body, {String? payload}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'loczy_channel_id', // channel id
      'Loczy Notifications', // channel name
      channelDescription: 'Channel for Loczy app notifications.', // channel description
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics = DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload, // Pass the payload for handling tap
    );
  }

  // New method: Show a chat notification with sender info and message
  Future<void> showChatNotification(
    int senderId, 
    int? chatId, 
    String senderName, 
    String message
  ) async {
    // Create a payload with chat information
    final payload = json.encode({
      'type': 'chat_message',
      'senderId': senderId,
      'chatId': chatId,
      'senderName': senderName,
    });

    // Use the senderId as the notification ID to ensure we don't stack notifications from the same sender
    await showNotification(
      senderId, 
      senderName, // Title is the sender's name
      message,    // Body is the message content
      payload: payload,
    );
  }

  // New method to fetch user details (similar to mesajlar.dart)
  Future<Map<String, dynamic>> _fetchUserDetails(int? userId) async {
    if (userId == null) {
      return {
        'isim': 'Bilinmeyen',
        'soyisim': 'Kullanıcı',
        'nickname': 'bilinmeyen',
        'profil_fotosu_url': ConfigLoader.defaultProfilePhoto
      };
    }

    try {
      final userResponse = await http.get(
        Uri.parse('${ConfigLoader.apiUrl}/routers/users.php?id=$userId'),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
      );
      
      if (userResponse.statusCode == 200) {
        final dynamic decodedBody = json.decode(userResponse.body);
        Map<String, dynamic> userJson;
        
        if (decodedBody is List && decodedBody.isNotEmpty) {
          userJson = decodedBody[0] as Map<String, dynamic>;
        } else if (decodedBody is Map<String, dynamic>) {
          userJson = decodedBody;
        } else {
          throw Exception('Unexpected user data format');
        }
        
        return userJson;
      } else {
        print('ERROR: Failed to fetch user details for ID $userId: ${userResponse.statusCode}');
      }
    } catch (userError) {
      print('ERROR: Error fetching user details for ID $userId: $userError');
    }
    
    // Return default if fetch failed
    return {
      'isim': 'Bilinmeyen',
      'soyisim': 'Kullanıcı',
      'nickname': 'bilinmeyen',
      'profil_fotosu_url': ConfigLoader.defaultProfilePhoto
    };
  }

  // Handle notification tap based on payload
  void _handleNotificationTap(String? payload) async {
    if (payload == null || navigatorKey?.currentState == null) return;
    print('Notification tapped with payload: $payload');
    try {
      final data = json.decode(payload);
      
      // Handle chat notifications
      if (data['type'] == 'chat_message') {
        // Extract chat data
        final int senderId = data['senderId'];
        final int? chatId = data['chatId'];
        
        // Fetch complete user details (similar to mesajlar.dart)
        final userDetails = await _fetchUserDetails(senderId);
        
        final String name = '${userDetails['isim']} ${userDetails['soyisim']}';
        final String username = userDetails['nickname'] ?? 'bilinmeyen';
        final String profilePicUrl = userDetails['profil_fotosu_url'] ?? ConfigLoader.defaultProfilePhoto;
        print('name: $name, username: $username, profilePicUrl: $profilePicUrl, chatId: $chatId, senderId: $senderId');
        // Navigate to chat page with complete information
        navigatorKey!.currentState!.push(
          MaterialPageRoute(
            builder: (context) => ChatPage(
              chatId: chatId,
              userId: senderId,
              name: name,
              username: username,
              profilePicUrl: profilePicUrl,
            ),
          ),
        );
      }
    } catch (e) {
      print('ERROR: Error handling notification tap: $e');
    }
  }
}

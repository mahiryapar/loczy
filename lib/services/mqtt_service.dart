import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:loczy/config_getter.dart'; // Assuming this path is correct
import 'package:loczy/providers/notification_provider.dart';
import 'package:loczy/services/notification_service.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MqttService {
  final NotificationService _notificationService;
  final NotificationProvider _notificationProvider;
  MqttServerClient? client;
  String? _userId;
  bool _isConnected = false;

  MqttService({
    required NotificationService notificationService,
    required NotificationProvider notificationProvider,
  })  : _notificationService = notificationService,
        _notificationProvider = notificationProvider;

  Future<void> initializeAndConnect() async {
    print('MQTT Service: initializeAndConnect called.'); // DEBUG PRINT
    if (_isConnected) {
      print('MQTT Service: Already connected. Skipping initialization.'); // DEBUG PRINT
      return;
    }

    await _loadUserId();
    if (_userId == null) {
      print('MQTT Service: User ID not found after _loadUserId. Cannot connect.'); // DEBUG PRINT
      return;
    }
    print('MQTT Service: User ID loaded: $_userId'); // DEBUG PRINT

    final String brokerIp = await ConfigLoader.vm_ip;
    print('MQTT Service: Broker IP loaded: $brokerIp'); // DEBUG PRINT
    final String clientId = 'flutter_client_${_userId}_${DateTime.now().millisecondsSinceEpoch}'; // Unique client ID
    print('MQTT Service: Client ID generated: $clientId'); // DEBUG PRINT

    client = MqttServerClient(brokerIp, clientId);
    client!.port = 1883; // Default MQTT port
    client!.logging(on: kDebugMode); // Enable logging only in debug mode
    client!.keepAlivePeriod = 60;
    client!.onConnected = _onConnected;
    client!.onDisconnected = _onDisconnected;
    client!.onSubscribed = _onSubscribed;
    client!.onSubscribeFail = _onSubscribeFail;
    client!.onUnsubscribed = _onUnsubscribed;
    client!.pongCallback = _pong;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean() // Clean session for simplicity
        .withWillQos(MqttQos.atLeastOnce);
    client!.connectionMessage = connMessage;

    try {
      print('MQTT Service: Connecting to broker $brokerIp...');
      await client!.connect();
    } on NoConnectionException catch (e) {
      print('MQTT Service: Client exception - $e');
      client!.disconnect();
      _isConnected = false;
      _scheduleReconnect(); // Schedule reconnect on failure
    } on SocketException catch (e) {
      print('MQTT Service: Socket exception - $e');
      client!.disconnect();
      _isConnected = false;
      _scheduleReconnect(); // Schedule reconnect on failure
    } catch (e) {
      print('MQTT Service: Unexpected exception - $e');
      client?.disconnect();
      _isConnected = false;
      _scheduleReconnect(); // Schedule reconnect on failure
    }
  }

  Future<void> _loadUserId() async {
    print('MQTT Service: _loadUserId called.'); // DEBUG PRINT
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Get the value as Object first to check its type
    Object? userIdValue = prefs.get('userId');
    print('MQTT Service: Raw userId value from SharedPreferences: $userIdValue (Type: ${userIdValue?.runtimeType})'); // DEBUG PRINT

    if (userIdValue is String) {
      _userId = userIdValue;
    } else if (userIdValue is int) {
      // If it's an int, convert it to String
      _userId = userIdValue.toString();
      print('MQTT Service: Converted int userId to String: $_userId'); // DEBUG PRINT
    } else {
      // If it's null or another type, treat as null
      _userId = null;
    }
    print('MQTT Service: Final _userId after type check: $_userId'); // DEBUG PRINT
  }

  void _onConnected() {
    print('MQTT Service: Connected');
    _isConnected = true;
    // Subscribe to the user-specific topic
    final topic = 'user/$_userId/notifications';
    print('MQTT Service: Subscribing to $topic');
    client!.subscribe(topic, MqttQos.atLeastOnce);

    // Listen for messages
    client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      if (c != null && c.isNotEmpty) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        print('MQTT Service: Received message: topic is ${c[0].topic}, payload is $pt');
        _handleMessage(c[0].topic, pt);
      }
    });
  }

  void _onDisconnected() {
    print('MQTT Service: Disconnected');
    _isConnected = false;
    // Attempt to reconnect after a delay
     _scheduleReconnect();
     // Note: This simple reconnect won't work reliably if the app is killed.
     // A background service is needed for true background persistence.
  }

  void _scheduleReconnect() {
     if (!_isConnected) {
        print('MQTT Service: Scheduling reconnect in 10 seconds...');
        Future.delayed(const Duration(seconds: 10), () {
           if (!_isConnected) { // Check again before attempting connection
              initializeAndConnect();
           }
        });
     }
  }

  void _onSubscribed(String topic) {
    print('MQTT Service: Subscribed to topic: $topic');
  }

  void _onSubscribeFail(String topic) {
    print('MQTT Service: Failed to subscribe to $topic');
     // Maybe retry subscription or handle error
  }

  void _onUnsubscribed(String? topic) {
    print('MQTT Service: Unsubscribed from topic: $topic');
  }

  void _pong() {
    print('MQTT Service: Ping response received');
  }

  void _handleMessage(String topic, String payload) {
    try {
      // Assuming the payload is a simple string for now
      // You might need JSON decoding if the payload is structured:
      // final messageData = jsonDecode(payload);
      // final title = messageData['title'] ?? 'New Notification';
      // final body = messageData['body'] ?? payload;

      final title = 'Yeni Bildirim'; // Placeholder title
      final body = payload; // Use the raw payload as body for now

      // Show local notification
      _notificationService.showNotification(
        DateTime.now().millisecondsSinceEpoch.remainder(100000), // Unique ID
        title,
        body,
      );

      // Add to the notification provider list
      _notificationProvider.addNotification(title, body);

    } catch (e) {
      print('MQTT Service: Error handling message - $e');
    }
  }

  void disconnect() {
    print('MQTT Service: disconnect() called.'); // DEBUG PRINT
    client?.disconnect();
    _isConnected = false;
  }

  // IMPORTANT: For true background MQTT listening when the app is terminated,
  // you would need to integrate a background service package like
  // `flutter_background_service` and move the MQTT client logic there.
  // The current implementation only works while the app is running (foreground or backgrounded).
}

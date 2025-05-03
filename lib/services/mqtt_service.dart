import 'dart:async'; // Import async
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:loczy/config_getter.dart'; // Assuming this path is correct
import 'package:loczy/providers/notification_provider.dart';
import 'package:loczy/services/notification_service.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

// REMOVED ChatMessageEvent class

class MqttService {
  final NotificationService _notificationService;
  final NotificationProvider _notificationProvider;
  MqttServerClient? client;
  String? _userId;
  bool _isConnected = false;
  Timer? _reconnectTimer; // Keep track of the reconnect timer

  // --- Connection Status Stream ---
  final _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  // Public getter for current status
  bool get isConnected => _isConnected;
  // --- End Connection Status Stream ---

  // REMOVED _chatMessagesController and chatMessagesStream
  // REMOVED _currentChatTopic

  MqttService({
    required NotificationService notificationService,
    required NotificationProvider notificationProvider,
  })  : _notificationService = notificationService,
        _notificationProvider = notificationProvider;

  Future<void> initializeAndConnect() async {
    print('MQTT Service: initializeAndConnect called. Current state: $_isConnected, Client state: ${client?.connectionStatus?.state}'); // DEBUG PRINT
    _reconnectTimer?.cancel(); // Cancel any pending reconnect timer

    // Check actual client state too, not just the flag
    if (_isConnected && client?.connectionStatus?.state == MqttConnectionState.connected) {
      print('MQTT Service: Already connected. Skipping initialization.'); // DEBUG PRINT
      if (!_connectionStatusController.isClosed) {
         _connectionStatusController.add(true);
      }
      return;
    }
     // If client exists but is disconnected, ensure flag is false
     if (client != null && client?.connectionStatus?.state != MqttConnectionState.connected && client?.connectionStatus?.state != MqttConnectionState.connecting) {
        if (_isConnected) {
           print('MQTT Service: Flag was true but client state is ${client?.connectionStatus?.state}. Setting flag to false.');
           _isConnected = false;
           if (!_connectionStatusController.isClosed) {
             _connectionStatusController.add(false);
           }
        }
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

    // Create a new client instance ONLY if it doesn't exist or is disconnected/faulted
    // This prevents issues if called multiple times during reconnect attempts
    if (client == null ||
        (client != null &&
         client?.connectionStatus?.state != MqttConnectionState.connected &&
         client?.connectionStatus?.state != MqttConnectionState.connecting))
    {
        print('MQTT Service: Creating new MqttServerClient instance.');
        client = MqttServerClient(brokerIp, clientId);
        client!.port = 1883; // Default MQTT port
        client!.logging(on: kDebugMode); // Enable logging only in debug mode
        client!.keepAlivePeriod = 60;
        // Assign callbacks ONLY when creating a new client
        client!.onConnected = _onConnected;
        client!.onDisconnected = _onDisconnected; // This will handle setting _isConnected = false
        client!.onSubscribed = _onSubscribed; // Keep for notifications topic
        client!.onSubscribeFail = _onSubscribeFail; // Keep for notifications topic
        client!.onUnsubscribed = _onUnsubscribed; // Keep for notifications topic
        client!.pongCallback = _pong;

        final connMessage = MqttConnectMessage()
            .withClientIdentifier(clientId)
            .startClean() // Clean session for simplicity
            .withWillQos(MqttQos.atLeastOnce);
        client!.connectionMessage = connMessage;
    } else {
        print('MQTT Service: Reusing existing client instance (State: ${client?.connectionStatus?.state}).');
    }


    try {
      // Only connect if not already connected or connecting
      if (client?.connectionStatus?.state != MqttConnectionState.connected &&
          client?.connectionStatus?.state != MqttConnectionState.connecting)
      {
        print('MQTT Service: Attempting connection to broker $brokerIp...');
        await client!.connect();
        print('MQTT Service: connect() call completed. Waiting for _onConnected callback...');
      } else {
         print('MQTT Service: Skipping connect() call as client state is already ${client?.connectionStatus?.state}.');
      }
      // Note: _onConnected callback will set _isConnected = true and update stream
    } on NoConnectionException catch (e) {
      print('MQTT Service: Connect failed - NoConnectionException: $e');
      _handleConnectionFailure();
    } on SocketException catch (e) {
      print('MQTT Service: Connect failed - SocketException: $e');
      _handleConnectionFailure();
    } catch (e) {
      print('MQTT Service: Connect failed - Unexpected exception: $e');
      _handleConnectionFailure();
    }
  }

  void _handleConnectionFailure() {
      if (_isConnected) {
        _isConnected = false;
        if (!_connectionStatusController.isClosed) {
          _connectionStatusController.add(false);
        }
      }
      // Don't call client.disconnect() here if connect failed, it might already be null or in a bad state.
      // Just schedule a reconnect.
      _scheduleReconnect();
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
    print('*** MQTT Service: _onConnected CALLED ***'); // Prominent log
    _isConnected = true;
    _reconnectTimer?.cancel(); // Successfully connected, cancel any reconnect timer
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(true);
    }

    // Subscribe to the general user notifications topic ONLY
    final notificationTopic = 'user/$_userId/notifications';
    print('MQTT Service: Subscribing to $notificationTopic');
    client!.subscribe(notificationTopic, MqttQos.atLeastOnce);

    // Listen for messages
    client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      if (c != null && c.isNotEmpty) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String payloadString = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        final String topic = c[0].topic;
        print('MQTT Service: Received message: topic is $topic, payload is $payloadString');
        _processMessage(topic, payloadString); // Handle notifications or other non-chat messages
      }
    });
  }

  void _onDisconnected() {
    print('*** MQTT Service: _onDisconnected CALLED ***'); // Prominent log
    // Check if the disconnection was expected (e.g., called disconnect())
    // MqttClient lacks a clear way to distinguish, so we assume unexpected unless disconnect() was just called.
    if (_isConnected) { // Only trigger if we thought we were connected
        _isConnected = false;
        if (!_connectionStatusController.isClosed) {
          _connectionStatusController.add(false);
        }
        print('MQTT Service: Connection lost unexpectedly. Scheduling reconnect.');
        _scheduleReconnect(); // Schedule reconnect on unexpected disconnect
    } else {
        print('MQTT Service: _onDisconnected called, but _isConnected was already false.');
    }
  }

  void _scheduleReconnect() {
     _reconnectTimer?.cancel(); // Cancel existing timer if any
     if (!_isConnected) { // Check flag before scheduling
        print('MQTT Service: Scheduling reconnect attempt in 10 seconds...');
        _reconnectTimer = Timer(const Duration(seconds: 10), () {
           print('MQTT Service: Reconnect timer fired. Calling initializeAndConnect...');
           // Check flag again inside timer callback
           if (!_isConnected) {
              initializeAndConnect();
           } else {
              print('MQTT Service: Reconnect timer fired, but already connected. Skipping.');
           }
        });
     } else {
        print('MQTT Service: _scheduleReconnect called, but already connected. Not scheduling.');
     }
  }

  void _onSubscribed(String topic) {
    print('MQTT Service: Subscribed to topic: $topic'); // Will only show for notifications now
  }

  void _onSubscribeFail(String topic) {
    print('MQTT Service: Failed to subscribe to $topic'); // Will only show for notifications now
     // Maybe retry subscription or handle error
  }

  void _onUnsubscribed(String? topic) {
    print('MQTT Service: Unsubscribed from topic: $topic'); // Will only show for notifications now
  }

  void _pong() {
    print('MQTT Service: Ping response received');
  }

  void _processMessage(String topic, String message) {
    try {
      final Map<String, dynamic> data = json.decode(message);
      
      // Handle personal notifications for the user
      if (topic.startsWith('user/') && topic.endsWith('/notifications')) {
        _processUserNotification(data);
      } 
      // Handle other message types...
    } catch (e) {
      print('ERROR (MQTT Service): Error processing message - $e');
    }
  }

  void _processUserNotification(Map<String, dynamic> data) {
    // Check if this is a chat message notification
    if (data['type'] == 'chat_message') {
      final String title = data['title'] ?? 'Yeni Mesaj';
      final String body = data['body'] ?? '';
      final int senderId = data['senderId'] ?? 0;
      final int? chatId = data['chatId'];
      
      // Create a payload with chat navigation information
      final payload = json.encode({
        'type': 'chat_message',
        'senderId': senderId,
        'chatId': chatId,
        'senderName': title,
      });
      
      // Show notification
      _notificationService.showNotification(
        senderId.hashCode, // Use sender ID as notification ID
        title,
        body,
        payload: payload,
      );
      
      // Also add to notification provider for AppBar display
      _notificationProvider.addNotification(title, body);
    }
  }

  void _handleMessage(String topic, String payload) {
    try {
      // Check ONLY for general notifications
      if (topic == 'user/$_userId/notifications') {
        // Handle general notification (existing logic)
        final title = 'Yeni Bildirim'; // Placeholder title
        final body = payload; // Use the raw payload as body for now
        _notificationService.showNotification(
          DateTime.now().millisecondsSinceEpoch.remainder(100000), // Unique ID
          title,
          body,
        );
        _notificationProvider.addNotification(title, body);

      } else {
         print('MQTT Service: Received message on unexpected topic: $topic');
      }

    } catch (e) {
      print('MQTT Service: Error handling message - $e');
      print('MQTT Service: Faulty payload: $payload'); // Log the payload causing the error
    }
  }

  void disconnect() {
    print('MQTT Service: disconnect() CALLED MANUALLY.'); // DEBUG PRINT
    _reconnectTimer?.cancel(); // Cancel any pending reconnect attempts

    // --- Close connection status stream ---
    if (!_connectionStatusController.isClosed) {
       _connectionStatusController.close();
       print('MQTT Service: Connection status stream controller closed.'); // DEBUG PRINT
    }
    // --- End Close ---

    final wasConnected = _isConnected;
    _isConnected = false; // Set flag immediately to prevent race conditions/reconnects

    // Only disconnect client if it exists and isn't already disconnected
    if (client != null && client?.connectionStatus?.state != MqttConnectionState.disconnected) {
       print('MQTT Service: Calling client.disconnect()...');
       client?.disconnect();
    } else {
       print('MQTT Service: Client already null or disconnected. Skipping client.disconnect().');
    }

    print('MQTT Service: Manual disconnect complete.');
  }

  // IMPORTANT: For true background MQTT listening when the app is terminated,
  // you would need to integrate a background service package like
  // `flutter_background_service` and move the MQTT client logic there.
  // The current implementation only works while the app is running (foreground or backgrounded).
}

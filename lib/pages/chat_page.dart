import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import http package
import 'dart:convert'; // Import convert package
import 'dart:async'; // Import math for min/max
import 'package:loczy/pages/kullanici_goster.dart'; // Import profile page
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'package:loczy/config_getter.dart'; // Import ConfigLoader
import 'package:timeago/timeago.dart' as timeago; // Import timeago
import 'package:visibility_detector/visibility_detector.dart';
import 'package:mqtt_client/mqtt_client.dart'; // Import MQTT Client
import 'package:mqtt_client/mqtt_server_client.dart'; // Import MQTT Server Client
import 'dart:io'; // For Platform check if needed
import 'dart:math';
import 'package:loczy/pages/post_goster.dart'; // Import PostGosterPage

// Updated message model to handle post shares with thumbnails
class Message {
  final int id; // Assuming API provides an ID
  final String text;
  final int senderId;
  final int receiverId;
  final String time; // Assuming API provides formatted time/date string
  bool isRead; // Make isRead mutable to update from MQTT
  final bool isLocal; // Flag to indicate if message is only local (not yet confirmed from server/MQTT)
  final int? tempId; // Temporary ID for local messages before server ID is known
  
  // Enhanced fields for shared posts
  final bool isSharedPost;
  final int? postId;
  final String? postImageUrl;  // Original media URL (may be video or image)
  final String? thumbnailUrl;  // Thumbnail URL (for display in chat)
  final bool isVideo;          // Whether this is a video post
  final String? postCaption;

  Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.receiverId,
    required this.time,
    required this.isRead,
    this.isLocal = false, // Default to false
    this.tempId,
    this.isSharedPost = false,
    this.postId,
    this.postImageUrl,
    this.thumbnailUrl,
    this.isVideo = false,
    this.postCaption,
  });

  // Factory constructor to create a Message from JSON (API or MQTT)
  factory Message.fromJson(Map<String, dynamic> json, int currentUserId) {
    // ... existing date parsing logic ...
    String formattedTime = 'Tarih Yok'; // Default value
    // Handle potential differences in MQTT payload vs API
    dynamic dateValue = json['mesaj_tarihi'] ?? json['time']; // Check both API and potential MQTT field names

    String? dateString;

    // Check the type of dateValue
    if (dateValue is String) {
      dateString = dateValue;
    } else if (dateValue is Map<String, dynamic> && dateValue['date'] is String) {
      dateString = dateValue['date'];
    }

    // Try parsing if we have a valid date string
    if (dateString != null) {
      try {
        // Remove potential microseconds if present
        if (dateString.contains('.')) {
          dateString = dateString.substring(0, dateString.indexOf('.'));
        }
        // Handle potential 'Z' for UTC time
        if (dateString.endsWith('Z')) {
           dateString = dateString.substring(0, dateString.length - 1);
        }
        
        // Parse the date and convert to Turkey time (UTC+3)
        DateTime dt = DateTime.parse(dateString);
        // Add 3 hours to UTC time to get UTC+3
        DateTime turkeyTime = dt.add(Duration(hours: 3));
        formattedTime = timeago.format(turkeyTime, locale: 'tr');
      } catch (e) {
        print("DEBUG (ChatPage - Message.fromJson): Error parsing date string: '$dateString' - $e");
      }
    } else {
       print("DEBUG (ChatPage - Message.fromJson): Date field is null or not in expected format: $dateValue");
    }

    // Check if this is a shared post message with improved format
    bool isSharedPost = false;
    int? postId;
    String? postImageUrl;
    String? thumbnailUrl;
    bool isVideo = false;
    String? postCaption;
    
    String messageText = json['mesaj'] ?? json['text'] ?? '';
    
    if (messageText.startsWith('post:')) {
      // Legacy format with colon separator - kept for backward compatibility
      isSharedPost = true;
      // ... existing parsing logic for legacy format ...
      
      // Try parsing with old format
      try {
        // First get the postId which is right after 'post:'
        final idEndPos = messageText.indexOf(':', 5); // Start after 'post:'
        if (idEndPos > 5) {
          postId = int.tryParse(messageText.substring(5, idEndPos));
          
          // Now get the main imageUrl
          final urlStartPos = idEndPos + 1;
          final urlEndPos = messageText.indexOf(':', urlStartPos);
          if (urlEndPos > urlStartPos) {
            postImageUrl = messageText.substring(urlStartPos, urlEndPos);
            
            // Now get the thumbnail URL
            final thumbStartPos = urlEndPos + 1;
            final thumbEndPos = messageText.indexOf(':', thumbStartPos);
            if (thumbEndPos > thumbStartPos) {
              thumbnailUrl = messageText.substring(thumbStartPos, thumbEndPos);
              
              // Now get isVideo (0/1)
              final isVideoStartPos = thumbEndPos + 1;
              final isVideoEndPos = messageText.indexOf(':', isVideoStartPos);
              if (isVideoEndPos > isVideoStartPos) {
                isVideo = messageText.substring(isVideoStartPos, isVideoEndPos) == "1";
                
                // Finally get the caption (everything after the last colon)
                if (isVideoEndPos < messageText.length - 1) {
                  postCaption = messageText.substring(isVideoEndPos + 1);
                }
              }
            }
          }
        }
      } catch (e) {
        print("Error parsing legacy shared post message: $e");
        // Keep the original message text in case parsing fails
      }
    } 
    else if (messageText.startsWith('post|||')) {
      // New format with ||| separator
      isSharedPost = true;
      try {
        // Split by the new separator
        List<String> parts = messageText.split('|||');
        
        if (parts.length >= 2) {
          postId = int.tryParse(parts[1]);
          
          if (parts.length >= 3) {
            postImageUrl = parts[2]; // Original media URL
            
            if (parts.length >= 4) {
              thumbnailUrl = parts[3]; // Thumbnail URL
              
              if (parts.length >= 5) {
                isVideo = parts[4] == "1"; // Is this a video?
                
                if (parts.length >= 6) {
                  // Join remaining parts if caption contains the separator
                  postCaption = parts.sublist(5).join('|||');
                }
              }
            }
          }
        }
      } catch (e) {
        print("Error parsing new format shared post message: $e");
        // Keep the original message text in case parsing fails
      }
    }

    // If parsing failed for either format, show a placeholder
    if (isSharedPost && postId == null) {
      messageText = "Paylaşılan gönderiyi görüntülemek için tıklayın";
    }

    return Message(
      // Use 'id' from API or MQTT payload. Provide default if missing.
      // MQTT might send 'messageId' or just 'id'
      id: json['id'] ?? json['messageId'] ?? 0,
      text: messageText, // Check both API and MQTT field names
      senderId: json['kimden_id'] ?? json['senderId'] ?? 0,
      receiverId: json['kime_id'] ?? json['receiverId'] ?? 0,
      time: formattedTime,
      // Handle bool/int/string representations of read status
      // MQTT might send 'isRead' directly as bool
      isRead: (json['okundu_mu'] == 1),
      isLocal: false, // Messages from JSON are never local-only
      isSharedPost: isSharedPost,
      postId: postId,
      postImageUrl: postImageUrl,
      thumbnailUrl: thumbnailUrl,
      isVideo: isVideo,
      postCaption: postCaption,
    );
  }

  // Add toJson method for sending via MQTT
  Map<String, dynamic> toJson() => {
        'id': id, // Send the actual ID if known, otherwise maybe 0 or null?
        'text': text,
        'senderId': senderId,
        'receiverId': receiverId,
        // Send time in Turkey time zone (UTC+3)
        'time': DateTime.now().toUtc().add(Duration(hours: 3)).toIso8601String(),
        'isRead': isRead,
        // Add a type field for MQTT routing if needed (optional here, handled by topic)
        // 'type': 'message',
      };
}

class ChatPage extends StatefulWidget {
  final int? chatId; // Optional: ID of the existing chat (sohbet_id)
  final int userId; // This is the ID of the person being chatted with
  final String name;
  final String username;
  final String profilePicUrl;

  const ChatPage({
    Key? key,
    this.chatId, // Make chatId optional
    required this.userId,
    required this.name,
    required this.username,
    required this.profilePicUrl,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {  // Add WidgetsBindingObserver
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoadingMessages = false;
  bool _allMessagesLoaded = false;
  final int _messageLimit = 20; // Number of messages to fetch per request
  bool _isFetchingUserId = true; // Flag to track user ID fetching
  final String apiUrl = ConfigLoader.apiUrl; // Get apiUrl from ConfigLoader
  final String bearerToken = ConfigLoader.bearerToken; // Get bearerToken from ConfigLoader
  int? _myUserId;
  Set<int> _locallyMarkedAsSeenIds = {};
  double? _lastMaxScrollExtentBeforeLoad;
  bool _isKeyboardVisible = false;  // Track keyboard visibility

  // --- MQTT Client Variables ---
  MqttServerClient? _mqttClient;
  bool _isMqttConnected = false;
  int? _currentChatId; // Store the actual chat ID for the topic
  bool _isSubscribed = false;
  String? _chatTopicId; // Added declaration for chat topic ID (used for logging/fallback)
  // --- End MQTT Client Variables ---

  // Add a cache for post creator usernames to avoid redundant API calls
  final Map<int, String> _postCreatorCache = {};

  @override
  void initState() {
    super.initState();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    timeago.setLocaleMessages('tr', timeago.TrMessages());
    _scrollController.addListener(_scrollListener);
    // Fetch user ID first, then fetch messages and initialize MQTT
    _loadMyUserIdAndInitialize();
    _initializeMqttClient(); // Initialize MQTT client connection attempt
    
    // Add widget binding observer to detect keyboard visibility changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No longer needed to get MqttService from Provider
    // When dependencies change and we have messages, mark visible ones as read
    if (_messages.isNotEmpty && _myUserId != null) {
      // Add a slight delay to ensure UI is built
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          _markVisibleMessagesAsRead();
          // Also try to scroll to bottom again after dependencies change
          _scrollToBottom(isInitial: true, forceJump: true);
        }
      });
    }
  }

  // Override didChangeMetrics to detect keyboard visibility
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    final newValue = bottomInset > 0.0;
    if (newValue != _isKeyboardVisible) {
      setState(() {
        _isKeyboardVisible = newValue;
      });
      // Scroll to bottom when keyboard becomes visible
      if (newValue) {
        _scrollToBottom(withDelay: true);
      }
    }
  }

  // Initialize and connect MQTT Client
  Future<void> _initializeMqttClient() async {
    final String brokerIp = ConfigLoader.vm_ip; // Get broker IP
    final String clientId = 'flutter_client_${_myUserId ?? DateTime.now().millisecondsSinceEpoch}'; // Unique client ID

    _mqttClient = MqttServerClient(brokerIp, clientId);
    _mqttClient!.port = 1883; // Default MQTT port
    _mqttClient!.logging(on: false); // Disable logging for production
    _mqttClient!.keepAlivePeriod = 60;
    _mqttClient!.onDisconnected = _onMqttDisconnected;
    _mqttClient!.onConnected = _onMqttConnected;
    _mqttClient!.onSubscribed = _onMqttSubscribed;
    _mqttClient!.pongCallback = _pong;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean() // Clean session for simplicity
        .withWillQos(MqttQos.atLeastOnce);
    _mqttClient!.connectionMessage = connMessage;

    try {
      print('DEBUG (ChatPage - MQTT): Connecting to broker $brokerIp...');
      await _mqttClient!.connect();
    } catch (e) {
      print('DEBUG (ChatPage - MQTT): Client exception - $e');
      _mqttClient?.disconnect();
      _mqttClient = null;
      _isMqttConnected = false;
    }
  }

  void _onMqttConnected() {
    print('DEBUG (ChatPage - MQTT): Connected');
    if (mounted) {
      setState(() {
        _isMqttConnected = true;
      });
    } else {
       _isMqttConnected = true; // Update state even if not mounted yet
    }

    // Listen for incoming messages on all topics
    _mqttClient!.updates!.listen(_onMqttMessage);

    // Subscribe to the specific chat topic if chat ID is known
    _subscribeToChatTopic();
  }

  void _onMqttDisconnected() {
    print('DEBUG (ChatPage - MQTT): Disconnected');
     if (mounted) {
       setState(() {
         _isMqttConnected = false;
         _isSubscribed = false;
       });
     } else {
        _isMqttConnected = false;
        _isSubscribed = false;
     }
    // Optionally implement reconnection logic here
  }

  void _onMqttSubscribed(String topic) {
    print('DEBUG (ChatPage - MQTT): Subscribed to topic: $topic');
    if (topic == 'chat/$_currentChatId/messages') {
       if (mounted) {
         setState(() {
           _isSubscribed = true;
         });
       } else {
          _isSubscribed = true;
       }
    }
  }

  void _pong() {
    // print('DEBUG (ChatPage - MQTT): Ping response received');
  }

  // Subscribe to the specific chat topic
  void _subscribeToChatTopic() {
    if (_mqttClient != null && _isMqttConnected && _currentChatId != null && !_isSubscribed) {
      final topic = 'chat/$_currentChatId/messages';
      print('DEBUG (ChatPage - MQTT): Attempting to subscribe to $topic');
      _mqttClient!.subscribe(topic, MqttQos.atLeastOnce);
    } else {
       print('DEBUG (ChatPage - MQTT): Cannot subscribe yet (Client: ${_mqttClient != null}, Connected: $_isMqttConnected, ChatID: $_currentChatId, Subscribed: $_isSubscribed)');
    }
  }

  // Handle incoming MQTT messages - Fix encoding for emojis and Turkish characters
  void _onMqttMessage(List<MqttReceivedMessage<MqttMessage?>>? c) {
    if (c == null || c.isEmpty || c[0].payload == null) return;

    final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
    // Use utf8.decode for proper character support
    final String payload = utf8.decode(recMess.payload.message);
    final String topic = c[0].topic;

    print('DEBUG (ChatPage - MQTT): Received message: $payload from topic: $topic');

    // Ensure message is for the current chat topic
    if (topic != 'chat/$_currentChatId/messages') {
      print('DEBUG (ChatPage - MQTT): Ignoring message from unrelated topic $topic');
      return;
    }

    try {
      final Map<String, dynamic> messageData = json.decode(payload);

      // Check if it's a read receipt or a new message
      if (messageData['type'] == 'read') {
        _handleReadReceipt(messageData);
      } else {
        _handleNewMessage(messageData);
      }
    } catch (e) {
      print('Error (ChatPage - MQTT): Failed to decode or handle message: $e');
    }
  }

  void _handleNewMessage(Map<String, dynamic> messageData) {
     if (_myUserId == null) return; // Cannot process if own ID is unknown

     final newMessage = Message.fromJson(messageData, _myUserId!);

     // Ignore messages sent by self (MQTT echo)
     if (newMessage.senderId == _myUserId) {
       print("DEBUG (ChatPage - MQTT): Ignoring self-sent message echo.");
       // Optional: Could use this echo to confirm MQTT send success
       return;
     }

     // Avoid adding duplicates if already received via API fetch
     if (_messages.any((m) => m.id == newMessage.id && newMessage.id != 0)) {
        print("DEBUG (ChatPage - MQTT): Ignoring duplicate message ID: ${newMessage.id}");
        return;
     }

     // Add the new message to the list
     if (mounted) {
       setState(() {
         _messages.add(newMessage);
       });
       
       // Improved: Use a small delay to ensure scrolling works after state update is complete
       _scrollToBottom(withDelay: true);
       
       // Mark as read immediately if received while chat is open
       _markMessageAsRead(newMessage.id);
     }
  }

  // Enhanced handler for read receipts
  void _handleReadReceipt(Map<String, dynamic> receiptData) {
     if (_myUserId == null) return;

     final int? messageId = receiptData['messageId'];
     final int? readerId = receiptData['readerId'];
     final String? timestamp = receiptData['timestamp'];

     print("DEBUG (ChatPage - MQTT): Processing read receipt: messageId=$messageId, readerId=$readerId, timestamp=$timestamp");

     // Check if the receipt is from the other user for one of my messages
     if (messageId != null && readerId == widget.userId) {
        print("DEBUG (ChatPage - MQTT): Received read receipt for message $messageId from user $readerId");
        if (mounted) {
           setState(() {
              // Try to find the message in our messages list
              final messageIndex = _messages.indexWhere((m) => m.id == messageId && m.senderId == _myUserId);
              if (messageIndex != -1) {
                 _messages[messageIndex].isRead = true;
                 print("DEBUG (ChatPage - MQTT): Marked message $messageId as read in UI.");
              } else {
                 print("DEBUG (ChatPage - MQTT): Could not find message $messageId in messages list to mark as read.");
                 // Dump the first few messages for debugging
                 for (int i = 0; i < min(5, _messages.length); i++) {
                    final m = _messages[i];
                    print("DEBUG: Message[$i]: id=${m.id}, senderId=${m.senderId}, text=${m.text.substring(0, min(10, m.text.length))}...");
                 }
              }
           });
        }
     } else {
        print("DEBUG (ChatPage - MQTT): Ignoring read receipt (messageId=$messageId, readerId=$readerId, myUserId=$_myUserId, otherUserId=${widget.userId})");
     }
  }

  // Add method to mark all visible messages as read (call this when chat is opened)
  void _markVisibleMessagesAsRead() {
    if (_myUserId == null) return;
    
    print("DEBUG (ChatPage): Checking for messages to mark as read");
    
    // Find all messages from the other user that aren't marked as read
    final messagesToMark = _messages.where((m) => 
      m.senderId == widget.userId && 
      !m.isRead && 
      !_locallyMarkedAsSeenIds.contains(m.id) &&
      m.id != 0 // Skip temporary messages
    ).toList();
    
    print("DEBUG (ChatPage): Found ${messagesToMark.length} messages to mark as read");
    
    // Mark each message as read
    for (final message in messagesToMark) {
      print("DEBUG (ChatPage): Auto-marking message ${message.id} as read");
      _markMessageAsRead(message.id);
    }
  }

  Future<void> _loadMyUserIdAndInitialize() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? loadedUserId;
    if (mounted) {
      loadedUserId = prefs.getInt('userId');
      setState(() {
        _myUserId = loadedUserId;
        _isFetchingUserId = false;
        _currentChatId = widget.chatId; // Store initial chat ID
      });
    } else {
       loadedUserId = prefs.getInt('userId'); // Load even if not mounted
       _myUserId = loadedUserId;
       _currentChatId = widget.chatId;
    }


    if (_myUserId == null) {
      print("Error (ChatPage): User ID not found in SharedPreferences.");
      if (mounted) {
        setState(() {
           _isLoadingMessages = false;
           _allMessagesLoaded = true;
        });
      }
    } else {
      // Determine chat topic ID (for logging or fallback)
      if (_currentChatId != null) {
        _chatTopicId = _currentChatId.toString(); // Use actual chat ID if available
        print("DEBUG (ChatPage): Using provided chatId: $_currentChatId for MQTT topic base.");
        // Attempt subscription now if MQTT is already connected
        _subscribeToChatTopic();
      } else {
        // Generate potential ID for logging, but MQTT needs the real one
        _chatTopicId = _getChatTopicId(_myUserId!, widget.userId);
        print("DEBUG (ChatPage): ChatId is null initially. Generated potential ID: $_chatTopicId. MQTT subscription deferred.");
      }

      // Fetch initial messages
      await _fetchMessages(initialLoad: true); // Wait for initial messages
    }
  }

  // Generate a consistent chat topic ID (keep for potential future use or logging)
  String _getChatTopicId(int userId1, int userId2) {
    // Ensure consistent order (e.g., smaller ID first)
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  @override
  void dispose() {
    // Remove widget binding observer
    WidgetsBinding.instance.removeObserver(this);
    
    _messageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();

    // --- MQTT Cleanup ---
    print("DEBUG (ChatPage - MQTT): Disposing ChatPage for topic chat/$_currentChatId/messages");
    if (_mqttClient != null && _isSubscribed && _currentChatId != null) {
      final topic = 'chat/$_currentChatId/messages';
      _mqttClient!.unsubscribe(topic);
      print("DEBUG (ChatPage - MQTT): Unsubscribed from $topic");
    }
    _mqttClient?.disconnect();
    print("DEBUG (ChatPage - MQTT): Disconnected client.");
    // --- End MQTT Cleanup ---

    print("DEBUG (ChatPage): Disposed ChatPage complete.");
    super.dispose();
  }

  // Listener for scroll events to load more messages
  void _scrollListener() {
    // Check if scrolled to the top and not currently loading and not all messages loaded
    // Also ensure myUserId is loaded
    if (_myUserId != null &&
        _scrollController.position.pixels == _scrollController.position.minScrollExtent &&
        !_isLoadingMessages &&
        !_allMessagesLoaded) {
      // Store the current max scroll extent before fetching older messages
      _lastMaxScrollExtentBeforeLoad = _scrollController.position.maxScrollExtent;
      _fetchMessages(); // Fetch older messages
    }
  }

  // Function to fetch messages from the API
  Future<void> _fetchMessages({bool initialLoad = false}) async {
    // Ensure myUserId is loaded before fetching
    if (_myUserId == null) {
       print("Cannot fetch messages: _myUserId is null.");
       if (initialLoad) {
         if (mounted) { // Check mounted
           setState(() {
             _isLoadingMessages = false; // Stop loading indicator if user ID is missing
             _allMessagesLoaded = true; // Prevent future attempts
           });
         }
       }
       return;
    }

    if (_isLoadingMessages || (!initialLoad && _allMessagesLoaded)) return;

    // Reset scroll extent cache if it's an initial load
    if (initialLoad) {
      _lastMaxScrollExtentBeforeLoad = null;
    }

    if (mounted) { // Check mounted
      setState(() {
        _isLoadingMessages = true;
      });
    }

    // Determine the offset based on whether it's an initial load or pagination
    final String offset = initialLoad ? '0' : _messages.length.toString();

    // Construct the URL with query parameters
    final url = Uri.parse('$apiUrl/routers/messages.php').replace( // Use apiUrl and correct endpoint
      queryParameters: {
        'gonderen_id': _myUserId!.toString(),
        'alici_id': widget.userId.toString(),
        'coklu': offset, // Use calculated offset
      },
    );

    print("DEBUG (ChatPage): Fetching messages with offset: $offset"); // Debug log

    try {
      // Make the GET request with Authorization header
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $bearerToken', // Add Authorization header
          'Content-Type': 'application/json', // Keep Content-Type if needed by your API
        },
      );

      if (response.statusCode == 200 && mounted) { // Check mounted again
        final List<dynamic> data = json.decode(response.body);
        final List<Message> fetchedMessages = data
            .map((json) => Message.fromJson(json, _myUserId!)) // Use non-null assertion
            .toList();

        print("DEBUG (ChatPage): Fetched ${fetchedMessages.length} messages."); // Debug log

        // Check mounted before calling setState
        if (!mounted) return;

        setState(() {
          if (fetchedMessages.length < _messageLimit) {
            _allMessagesLoaded = true; // No more messages to load
            print("DEBUG (ChatPage): All messages loaded."); // Debug log
          }

          if (initialLoad) {
            _messages = fetchedMessages.reversed.toList(); // Show newest first
            
            // Improved initial scroll logic with multiple attempts
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // First scroll attempt (immediate)
              _scrollToBottom(isInitial: true);
              
              // Second attempt after a short delay
              Future.delayed(Duration(milliseconds: 200), () {
                if (mounted) _scrollToBottom(isInitial: true);
                
                // Third attempt after layout should be more stable
                Future.delayed(Duration(milliseconds: 500), () {
                  if (mounted) _scrollToBottom(isInitial: true, forceJump: true);
                });
              });
            });
          } else {
            // Prepend older messages to the top of the list
            _messages.insertAll(0, fetchedMessages.reversed);
            // Maintain scroll position after adding older messages
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients && _lastMaxScrollExtentBeforeLoad != null) {
                final newMaxScrollExtent = _scrollController.position.maxScrollExtent;
                final scrollOffsetToMaintain = newMaxScrollExtent - _lastMaxScrollExtentBeforeLoad!;
                _scrollController.jumpTo(scrollOffsetToMaintain);
                print("DEBUG (ChatPage): Jumped to offset: $scrollOffsetToMaintain after loading older messages."); // Debug log
                _lastMaxScrollExtentBeforeLoad = null; // Reset after use
              }
            });
          }
          // _messageOffset += fetchedMessages.length; // REMOVED: No longer needed
        });

        // Add this at the end, after setting _messages and scrolling to bottom
        // Mark visible messages as read after initial load
        if (initialLoad && _messages.isNotEmpty) {
          // Add a slight delay to ensure UI is built
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              _markVisibleMessagesAsRead();
            }
          });
        }
      } else {
        // Handle API error (e.g., show a SnackBar)
        print('Error (ChatPage): Failed to load messages: ${response.statusCode}'); // Log error
        print('Error (ChatPage): Response body: ${response.body}'); // Log response body for debugging
        if (mounted) { // Check mounted
          // ScaffoldMessenger.of(context).showSnackBar( // REMOVED SnackBar
          //   SnackBar(content: Text('Mesajlar yüklenemedi: ${response.statusCode}')),
          // );
          if (initialLoad) _allMessagesLoaded = true; // Prevent further loading attempts on error
          else _allMessagesLoaded = true; // Also stop trying if pagination fails
        }
      }
    } catch (e) {
      // Handle network or parsing error
      print('Error (ChatPage): Error fetching messages: $e'); // Log error
       if (mounted) { // Check mounted
         // ScaffoldMessenger.of(context).showSnackBar( // REMOVED SnackBar
         //   SnackBar(content: Text('Mesajlar yüklenirken bir hata oluştu: $e')),
         // );
         if (initialLoad) _allMessagesLoaded = true; // Prevent further loading attempts on error
         else _allMessagesLoaded = true; // Also stop trying if pagination fails
       }
    } finally {
      // Check mounted before calling setState
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  // Improved scroll function with better reliability
  void _scrollToBottom({bool isInitial = false, bool withDelay = false, bool forceJump = false}) {
    if (!_scrollController.hasClients) return;
     
    // If we need a delay (for keyboard or new messages), add a small delay
    final scrollDelay = withDelay ? 150 : (isInitial ? 100 : 0);
     
    Future.delayed(Duration(milliseconds: scrollDelay), () {
      if (!_scrollController.hasClients || !mounted) return;
       
      final maxScroll = _scrollController.position.maxScrollExtent;
      
      // Print debug info to help diagnose scroll issues
      print("DEBUG (ChatPage): Scrolling to bottom. Current: ${_scrollController.position.pixels}, Max: $maxScroll");
      
      // Using jumpTo for initial load or when force jump is needed for reliability
      if (isInitial || forceJump) {
        // Direct jump is more reliable for initial positioning
        _scrollController.jumpTo(maxScroll);
      } else {
        // Smooth animation for user-initiated scrolls
        _scrollController.animateTo(
          maxScroll,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Modified to send via POST to API and then publish via MQTT
  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    if (_myUserId == null) {
      print("Error (ChatPage - _sendMessage): Cannot send message. User ID null.");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Mesaj gönderilemedi. Kullanıcı bilgisi eksik.')),
         );
      }
      return;
    }

    final tempId = DateTime.now().millisecondsSinceEpoch; // Temporary ID

    // 1. Optimistic UI Update
    final tempMessage = Message(
      id: 0, // Server ID will be assigned later
      tempId: tempId,
      text: messageText,
      senderId: _myUserId!,
      receiverId: widget.userId,
      time: timeago.format(DateTime.now(), locale: 'tr'), // This is already in local time
      isRead: false,
      isLocal: true,
    );

    if (!mounted) return;
    setState(() {
      _messages.add(tempMessage);
      _messageController.clear();
    });
    // Improved: Force jump to bottom after sending a message for reliability
    _scrollToBottom(withDelay: true, forceJump: true);

    // Check if this is a new chat (no chat ID exists)
    if (_currentChatId == null) {
      // Create the chat first if it doesn't exist
      try {
        print("DEBUG (ChatPage): Creating new chat between users $_myUserId and ${widget.userId}");
        final createChatResponse = await http.post(
          Uri.parse('$apiUrl/routers/chats.php'),
          headers: {
            'Authorization': 'Bearer $bearerToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'kullanici1_id': _myUserId!,
            'kullanici2_id': widget.userId,
          }),
        );

        if (createChatResponse.statusCode == 200 || createChatResponse.statusCode == 201) {
          print("DEBUG (ChatPage): Successfully created chat: ${createChatResponse.body}");
          try {
            final chatData = json.decode(createChatResponse.body);
            if (chatData != null && chatData['id'] != null) {
              _currentChatId = chatData['id'];
              print("DEBUG (ChatPage): New chat created with ID: $_currentChatId");
              
              // Try to establish MQTT subscription with the new chat ID
              _subscribeToChatTopic();
            } else {
              print("ERROR (ChatPage): Failed to get chat ID from response: ${createChatResponse.body}");
            }
          } catch (e) {
            print("ERROR (ChatPage): Failed to parse chat creation response: $e");
          }
        } else {
          print("ERROR (ChatPage): Failed to create chat: ${createChatResponse.statusCode}, ${createChatResponse.body}");
        }
      } catch (e) {
        print("ERROR (ChatPage): Exception creating chat: $e");
      }
    }

    // 2. Send to API (messages.php) via POST
    int? newMessageId; // To store the ID from the API response
    int? newChatId; // To store the chat ID if it's a new chat

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/routers/messages.php'),
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'kimden_id': _myUserId!,
          'kime_id': widget.userId,
          'mesaj': messageText,
          // Include sohbet_id if known, API might use it or create/find it
          if (_currentChatId != null) 'sohbet_id': _currentChatId
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("DEBUG (ChatPage): Message successfully saved to database.");
        try {
           final responseData = json.decode(response.body);
           // Expecting API to return at least the new message ID and potentially the chat ID
           newMessageId = responseData['id'];
           newChatId = responseData['sohbet_id']; // Assuming API returns 'sohbet_id'

           if (newMessageId != null && newMessageId is int) {
              if (mounted) {
                 setState(() {
                    final tempIndex = _messages.indexWhere((m) => m.tempId == tempId);
                    if (tempIndex != -1) {
                       _messages[tempIndex] = Message(
                          id: newMessageId!, // Use the real ID
                          text: _messages[tempIndex].text,
                          senderId: _messages[tempIndex].senderId,
                          receiverId: _messages[tempIndex].receiverId,
                          time: _messages[tempIndex].time,
                          isRead: _messages[tempIndex].isRead,
                          isLocal: false, // No longer local
                       );
                       print("DEBUG (ChatPage): Updated local message with server ID: $newMessageId");
                    }
                 });
              }
           }
           
           // If a new chat ID was returned and we didn't have one, update and subscribe
           if (newChatId != null && (_currentChatId == null || _currentChatId != newChatId)) {
              print("DEBUG (ChatPage): Received new chat ID: $newChatId from API.");
              _currentChatId = newChatId;
              // Attempt subscription now that we have the ID
              _subscribeToChatTopic();
           }

           // Update chat metadata with the new message
           final chatIdToUpdate = _currentChatId ?? newChatId;
           if (chatIdToUpdate != null) {
             // Create a current timestamp for the message
             final messageTime = DateTime.now();
             _updateChatMetadata(chatIdToUpdate, messageText, messageTime);
           }

        } catch (e) {
           print("DEBUG (ChatPage): Could not parse message/chat ID from API response - $e");
        }
      } else {
        print('Error (ChatPage): Failed to save message to database: ${response.statusCode}');
        print('Error (ChatPage): Response body: ${response.body}');
        // Handle error: Maybe mark the message as "failed to send" in the UI
        if (mounted) {
           setState(() {
              final tempIndex = _messages.indexWhere((m) => m.tempId == tempId);
              if (tempIndex != -1) {
                 // Mark as failed visually? (e.g., add an error icon/state to Message)
                 print("Error (ChatPage): Marking message $tempId as failed to send.");
              }
           });
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Mesaj gönderilemedi (Sunucu Hatası).')),
           );
        }
        return; // Don't attempt MQTT publish if API failed
      }
    } catch (e) {
      print('Error (ChatPage): Error sending message to API: $e');
      // Handle error: Maybe mark the message as "failed to send"
      if (mounted) {
         setState(() {
            final tempIndex = _messages.indexWhere((m) => m.tempId == tempId);
            if (tempIndex != -1) {
               // Mark as failed visually?
               print("Error (ChatPage): Marking message $tempId as failed to send (Network Error).");
            }
         });
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Mesaj gönderilemedi (Ağ Hatası).')),
         );
      }
      return; // Don't attempt MQTT publish if API failed
    }

    // 3. Publish via MQTT if connected and chat ID is known
    if (_mqttClient != null && _isMqttConnected && _currentChatId != null) {
      final topic = 'chat/$_currentChatId/messages';
      // Construct payload - use data from the message, including the ID from API if possible
      final messagePayload = Message(
         id: newMessageId ?? 0, // Use real ID if available
         text: messageText,
         senderId: _myUserId!,
         receiverId: widget.userId,
         // Use Turkey time (UTC+3) for consistency
         time: DateTime.now().toUtc().add(Duration(hours: 3)).toIso8601String(),
         isRead: false,
      ).toJson(); // Use toJson helper

      final builder = MqttClientPayloadBuilder();
      
      // Fix for emojis and Turkish characters - encode payload to UTF-8 properly
      final jsonString = json.encode(messagePayload);
      builder.addUTF8String(jsonString);

      print("DEBUG (ChatPage - MQTT): Publishing message to $topic: $jsonString");
      try {
        _mqttClient!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
        
        // Add confirmation callback for MQTT messages to fix the "clock icon" issue
        // Store the tempId for matching in a confirmation handler
        final sentTempId = tempId;
        
        // After successful publishing, check after a short delay if we can confirm the message
        // This helps with the clock icon persistence issue
        if (newMessageId != null) {
          // If we already have the ID from API, mark as non-local immediately
          _updateMessageLocalStatus(tempId, newMessageId);
        } else {
          // Set a timeout to remove local flag after a reasonable period if no confirmation
          Future.delayed(Duration(seconds: 3), () {
            if (mounted) {
              _checkAndUpdatePendingMessage(sentTempId);
            }
          });
        }
        
        // After successfully sending the message, also send a notification to the recipient
        _sendChatNotificationToUser(widget.userId, messageText);
      } catch (e) {
         print("Error (ChatPage - MQTT): Failed to publish message - $e");
      }
    } else {
       print("DEBUG (ChatPage - MQTT): Cannot publish message (Client: ${_mqttClient != null}, Connected: $_isMqttConnected, ChatID: $_currentChatId)");
    }
  }

  // New method to update chat metadata after sending a message
  Future<void> _updateChatMetadata(int chatId, String messageText, DateTime messageTime) async {
    if (_myUserId == null) return;
    
    try {
      
      final response = await http.put(
        Uri.parse('${ConfigLoader.apiUrl}/routers/chats.php'),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'id': chatId,
          'son_mesaji_atan_id': _myUserId,
          'son_mesaj_metni': messageText,
        }),
      );

      if (response.statusCode == 200) {
        print("DEBUG (ChatPage): Chat metadata updated successfully for chat ID: $chatId"+response.body);
      } else {
        print("ERROR (ChatPage): Failed to update chat metadata: ${response.statusCode}, ${response.body}");
      }
    } catch (e) {
      print("ERROR (ChatPage): Exception updating chat metadata: $e");
    }
  }

  // New method to update message local status to fix the clock icon issue
  void _updateMessageLocalStatus(int tempId, int? messageId) {
    if (!mounted) return;
    
    setState(() {
      final tempIndex = _messages.indexWhere((m) => m.tempId == tempId);
      if (tempIndex != -1) {
        // Create a new message with isLocal set to false
        _messages[tempIndex] = Message(
          id: messageId ?? _messages[tempIndex].id,
          text: _messages[tempIndex].text,
          senderId: _messages[tempIndex].senderId,
          receiverId: _messages[tempIndex].receiverId,
          time: _messages[tempIndex].time,
          isRead: _messages[tempIndex].isRead,
          isLocal: false, // Mark as no longer local
          tempId: tempId, // Keep the tempId for future reference
        );
        print("DEBUG (ChatPage): Updated message local status, tempId: $tempId, messageId: $messageId");
      }
    });
  }

  // New method to check and update pending messages after timeout
  void _checkAndUpdatePendingMessage(int tempId) {
    final tempIndex = _messages.indexWhere((m) => m.tempId == tempId && m.isLocal);
    if (tempIndex != -1) {
      print("DEBUG (ChatPage): Auto-confirming pending message after timeout, tempId: $tempId");
      _updateMessageLocalStatus(tempId, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while fetching user ID
    if (_isFetchingUserId) {
      return Scaffold(
        appBar: AppBar(title: Text('Yükleniyor...')), // Simple loading app bar
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Show error if user ID couldn't be loaded
    if (_myUserId == null) {
       return Scaffold(
         appBar: AppBar(title: Text('Hata')),
         body: Center(child: Text('Sohbet yüklenemedi. Kullanıcı kimliği bulunamadı.')),
       );
    }

    // Original Scaffold build when user ID is available
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => KullaniciGosterPage(userId: widget.userId),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(widget.profilePicUrl),
              ),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '@${widget.username}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  // Add MQTT connection status indicator (optional)
                  // Text(
                  //   _isMqttConnected ? (_isSubscribed ? 'Bağlı (Sohbet)' : 'Bağlı') : 'Bağlantı Yok',
                  //   style: TextStyle(fontSize: 10, color: _isMqttConnected ? Colors.green : Colors.red),
                  // ),
                ],
              ),
            ],
          ),
        ),
        elevation: 1.0,
      ),
      body: Column(
        children: [
          // Show loading indicator at the top when fetching older messages
          // Use _messages.isNotEmpty to ensure it only shows during pagination
          if (_isLoadingMessages && _messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          Expanded(
            // Show initial loading indicator only when messages are empty AND loading
            child: _messages.isEmpty && _isLoadingMessages
                ? Center(child: CircularProgressIndicator()) // Loading indicator for initial load
                : _messages.isEmpty && !_isLoadingMessages
                    ? Center(child: Text('Henüz mesaj yok.')) // No messages text
                    : NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          // Check if user has stopped scrolling
                          if (scrollInfo is ScrollEndNotification) {
                            // Add a small delay to mark visible messages as read
                            Future.delayed(Duration(milliseconds: 300), () {
                              if (mounted) {
                                _markVisibleMessagesAsRead();
                              }
                            });
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.all(10.0),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return _buildMessageBubble(message);
                          },
                          // Add these properties to improve initial positioning
                          reverse: false, // Keep normal order with newest at bottom
                          shrinkWrap: false, // Better performance for long lists
                        ),
                      ),
          ),
          // Listen for keyboard resize using LayoutBuilder
          LayoutBuilder(
            builder: (context, constraints) {
              // When layout changes and keyboard is visible, trigger scroll
              if (_isKeyboardVisible) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });
              }
              return _buildMessageInputBar();
            }
          ),
        ],
      ),
      // Add resize behavior to handle keyboard better
      resizeToAvoidBottomInset: true,
    );
  }

  // Update _buildMessageBubble to fix shared post display
  Widget _buildMessageBubble(Message message) {
    final bool isSentByMe = message.senderId == _myUserId!;
    final align = isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isSentByMe ? Theme.of(context).primaryColor : Colors.grey[300];
    final textColor = isSentByMe ? Colors.white : Colors.black87;
    final radius = isSentByMe
        ? BorderRadius.only(
            topLeft: Radius.circular(15),
            bottomLeft: Radius.circular(15),
            bottomRight: Radius.circular(15),
          )
        : BorderRadius.only(
            topRight: Radius.circular(15),
            bottomLeft: Radius.circular(15),
            bottomRight: Radius.circular(15),
          );

    // Set consistent max width for all message types
    final maxMessageWidth = MediaQuery.of(context).size.width * 0.75;
    
    // Build message content based on type (regular text vs shared post)
    Widget messageContentWidget;
    
    if (message.isSharedPost && message.postId != null) {
      // Shared post content
      messageContentWidget = GestureDetector(
        onTap: () {
          // Navigate to post details page when post is tapped
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostGosterPage(postId: message.postId!),
            ),
          );
        },
        child: Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: radius,
          ),
          // Fixed width constraint to prevent expanding when username loads
          constraints: BoxConstraints(maxWidth: maxMessageWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      message.isVideo ? Icons.videocam : Icons.photo, 
                      size: 16, 
                      color: textColor
                    ),
                    SizedBox(width: 4),
                    Text(
                      "Paylaşılan Post",
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Post preview - Fixed to properly display the image
              Container(
                constraints: BoxConstraints(
                  maxWidth: maxMessageWidth - 8, // Account for parent padding
                  maxHeight: 150,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Image (either thumbnail or actual image)
                      message.thumbnailUrl != null && message.thumbnailUrl!.isNotEmpty
                          ? Image.network(
                              message.thumbnailUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 100,
                                  width: maxMessageWidth - 16, // Account for parent padding
                                  color: Colors.grey[200],
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 100,
                                  width: maxMessageWidth - 16, // Account for parent padding
                                  color: Colors.grey[200],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error, color: Colors.red),
                                      SizedBox(height: 4),
                                      Text(
                                        "Görüntü yüklenemedi",
                                        style: TextStyle(
                                          color: Colors.red[300],
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          : Container(
                              height: 100,
                              width: maxMessageWidth - 16, // Account for parent padding
                              color: Colors.grey[200],
                              child: Center(child: Text("Görüntü yok")),
                            ),
                      
                      // Play button overlay for videos
                      if (message.isVideo)
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // Post caption
              if (message.postCaption != null && message.postCaption!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    message.postCaption!,
                    style: TextStyle(color: textColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              
              // Add information about post creator (Fetch from post details) - Fix the width issue
              Container(
                constraints: BoxConstraints(maxWidth: maxMessageWidth - 8),
                child: FutureBuilder<String?>(
                  // Provide a unique key based on the postId to avoid rebuilds
                  key: ValueKey('post_creator_${message.postId}'),
                  future: _fetchPostCreator(message.postId!),
                  builder: (context, snapshot) {
                    // Simplify the builder logic
                    return Container(
                      constraints: BoxConstraints(maxWidth: maxMessageWidth - 8),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person,
                              size: 12,
                              color: textColor.withOpacity(0.7),
                            ),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                snapshot.connectionState == ConnectionState.done && snapshot.hasData
                                    ? "@${snapshot.data!}"
                                    : "Yükleniyor...",
                                style: TextStyle(
                                  color: textColor.withOpacity(0.7),
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Message footer (tap to view)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  "Görüntülemek için dokunun",
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Regular text message
      messageContentWidget = Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: maxMessageWidth),
        decoration: BoxDecoration(color: color, borderRadius: radius),
        child: Text(message.text, style: TextStyle(color: textColor)),
      );
    }

    // Combine the message content with timestamp and read indicators
    Widget messageContent = Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          messageContentWidget,
          SizedBox(height: 2),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(
                  message.time,
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
                // Show "Görüldü" based on message.isRead flag
                if (isSentByMe && message.isRead)
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Text(
                      'Görüldü',
                      style: TextStyle(color: Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                // Indicate sending status for local messages
                if (isSentByMe && message.isLocal)
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Icon(Icons.schedule, size: 10, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    // For messages NOT sent by me (received messages), wrap in VisibilityDetector
    if (!isSentByMe) {
      return VisibilityDetector(
        key: Key('msg_${message.id}'), // Unique key for each message
        onVisibilityChanged: (visibilityInfo) {
          var visiblePercentage = visibilityInfo.visibleFraction * 100;
          // Mark as read if >75% visible and not already read
          if (visiblePercentage > 75 && !message.isRead && !_locallyMarkedAsSeenIds.contains(message.id) && message.id != 0) {
            print("DEBUG (ChatPage): Message ${message.id} became visible (>${visiblePercentage.toStringAsFixed(1)}%) and is not marked as read. Marking as read.");
            _markMessageAsRead(message.id);
          }
        },
        child: messageContent,
      );
    } else {
      // Messages sent by me don't need visibility detection
      return messageContent;
    }
  }
  
  // New method to fetch post creator username
  Future<String?> _fetchPostCreator(int postId) async {
    // Check cache first
    if (_postCreatorCache.containsKey(postId)) {
      return _postCreatorCache[postId];
    }
    
    try {
      final response = await http.get(
        Uri.parse('${ConfigLoader.apiUrl}/routers/posts.php?id=$postId'),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final postData = json.decode(response.body);
        final creatorId = postData['atan_id'];
        
        if (creatorId != null) {
          final userResponse = await http.get(
            Uri.parse('${ConfigLoader.apiUrl}/routers/users.php?id=$creatorId'),
            headers: {
              'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
              'Content-Type': 'application/json',
            },
          );
          
          if (userResponse.statusCode == 200) {
            final userData = json.decode(userResponse.body);
            final username = userData['nickname'] ?? 'bilinmeyen';
            
            // Cache the result
            _postCreatorCache[postId] = username;
            return username;
          }
        }
      }
      return null;
    } catch (e) {
      print('Error fetching post creator: $e');
      return null;
    }
  }

  // Modified to send read receipt via POST to API and then publish via MQTT
  Future<void> _markMessageAsRead(int messageId) async {
    if (_myUserId == null) {
       print("DEBUG (ChatPage - _markMessageAsRead): Cannot mark message $messageId as read, missing User ID.");
       return;
    }

    // Skip local flag check for messageId = 0 (temporary messages)
    if (messageId == 0) {
      print("DEBUG (ChatPage - _markMessageAsRead): Skipping message with ID 0 (temporary)");
      return;
    }

    // Avoid redundant processing/sending if already marked locally
    if (_locallyMarkedAsSeenIds.contains(messageId)) {
      print("DEBUG (ChatPage - _markMessageAsRead): Message $messageId already marked locally.");
      return;
    }

    print("DEBUG (ChatPage): Marking message $messageId as read for user $_myUserId (API + MQTT)");
    _locallyMarkedAsSeenIds.add(messageId); // Mark locally immediately
    
    // Update local UI state immediately - don't wait for API
    if (mounted) {
      setState(() {
        final messageIndex = _messages.indexWhere((m) => m.id == messageId && m.senderId == widget.userId);
        if (messageIndex != -1) {
          _messages[messageIndex].isRead = true;
          print("DEBUG (ChatPage): Locally marked message $messageId as read in UI");
        }
      });
    }

    // 1. Send to API (messages.php) using GET request with "okundu" query parameter
    bool apiSuccess = false;
    try {
      // Use GET request with okundu as query parameter instead of POST with body
      final url = Uri.parse('$apiUrl/routers/messages.php?okundu=$messageId');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("DEBUG (ChatPage): Successfully marked message $messageId as read on backend.");
        apiSuccess = true;
      } else {
        print('DEBUG (ChatPage): Failed to mark message $messageId as read via API: ${response.statusCode} ${response.body}');
        _locallyMarkedAsSeenIds.remove(messageId); // Allow retry on API failure
      }
    } catch (e) {
      print('DEBUG (ChatPage): Error marking message $messageId as read via API: $e');
      _locallyMarkedAsSeenIds.remove(messageId); // Allow retry on API failure
    }

    // 2. Publish Read Receipt via MQTT if API succeeded, connected, and chat ID known
    if (apiSuccess && _mqttClient != null && _isMqttConnected && _currentChatId != null) {
       final topic = 'chat/$_currentChatId/messages';
       final receiptPayload = {
         'type': 'read', // Indicate message type
         'messageId': messageId,
         'readerId': _myUserId!, // ID of the user who read the message
         // Use Turkey time (UTC+3) for timestamp
         'timestamp': DateTime.now().toUtc().add(Duration(hours: 3)).toIso8601String(),
       };

       final builder = MqttClientPayloadBuilder();
       final jsonString = json.encode(receiptPayload);
       builder.addUTF8String(jsonString);

       print("DEBUG (ChatPage - MQTT): Publishing read receipt to $topic for message $messageId: $jsonString");
       try {
         _mqttClient!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
       } catch (e) {
          print("Error (ChatPage - MQTT): Failed to publish read receipt - $e");
       }
    } else if (apiSuccess) {
        print("DEBUG (ChatPage - MQTT): Cannot publish read receipt (API Success: $apiSuccess, Client: ${_mqttClient != null}, Connected: $_isMqttConnected, ChatID: $_currentChatId)");
    }
  }

  // New method to send chat notification to user
  void _sendChatNotificationToUser(int recipientId, String messageText) {
    if (_mqttClient == null || !_isMqttConnected || _myUserId == null) {
      print("DEBUG (ChatPage): Cannot send notification - MQTT not connected");
      return;
    }

    // Get current user's name from SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      final senderName = prefs.getString('userNickname') ?? 'Bilinmeyen Kullanıcı';
      
      // Create notification data with chat information
      final notificationData = {
        'type': 'chat_message',
        'title': senderName,  // Name of sender
        'body': messageText,  // Message content
        'senderId': _myUserId,  // ID of sender (current user)
        'chatId': _currentChatId,  // ID of the chat
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // Topic for the recipient's notifications
      final notificationTopic = 'user/$recipientId/notifications';
      
      // Build and publish the notification message
      final builder = MqttClientPayloadBuilder();
      final jsonString = json.encode(notificationData);
      builder.addUTF8String(jsonString);

      print("DEBUG (ChatPage - MQTT): Publishing notification to $notificationTopic");
      try {
        _mqttClient!.publishMessage(
          notificationTopic,
          MqttQos.atLeastOnce,
          builder.payload!
        );
        print("DEBUG (ChatPage - MQTT): Notification sent successfully");
      } catch (e) {
        print("ERROR (ChatPage - MQTT): Failed to publish notification - $e");
      }
    });
  }

  Widget _buildMessageInputBar() {
    return Container(
      // ... existing decoration ...
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, -1), // changes position of shadow
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              // ... existing decoration ...
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Mesaj yaz...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10)
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                // Send message on enter key press
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: 8.0),
          IconButton(
            icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
            // Use async version of _sendMessage here
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

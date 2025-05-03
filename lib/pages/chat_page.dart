import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import http package
import 'dart:convert'; // Import convert package
import 'package:loczy/pages/kullanici_goster.dart'; // Import profile page
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'package:loczy/config_getter.dart'; // Import ConfigLoader
import 'package:timeago/timeago.dart' as timeago; // Import timeago
import 'package:visibility_detector/visibility_detector.dart'; // Import VisibilityDetector

// Updated message model to match API response
class Message {
  final int id; // Assuming API provides an ID
  final String text;
  final int senderId;
  final int receiverId;
  final String time; // Assuming API provides formatted time/date string
  final bool isRead; // Assuming API provides read status

  Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.receiverId,
    required this.time,
    required this.isRead,
  });

  // Factory constructor to create a Message from JSON
  factory Message.fromJson(Map<String, dynamic> json, int currentUserId) {
    String formattedTime = 'Tarih Yok'; // Default value
    dynamic dateValue = json['mesaj_tarihi']; // Get the date value

    String? dateString;

    // Check the type of dateValue
    if (dateValue is String) {
      dateString = dateValue;
    } else if (dateValue is Map<String, dynamic> && dateValue['date'] is String) {
      // Handle nested date structure like {"date": "...", "timezone_type": ..., "timezone": ...}
      dateString = dateValue['date'];
    }

    // Try parsing if we have a valid date string
    if (dateString != null) {
      try {
        // Remove potential microseconds if present (adjust based on your exact format)
        if (dateString.contains('.')) {
          dateString = dateString.substring(0, dateString.indexOf('.'));
        }
        DateTime dt = DateTime.parse(dateString);
        // Use timeago for relative time formatting
        formattedTime = timeago.format(dt, locale: 'tr'); // Use Turkish locale
      } catch (e) {
        print("DEBUG (ChatPage): Error parsing date string: '$dateString' - $e");
        // Keep formattedTime as 'Tarih Yok' or handle differently
      }
    } else {
       print("DEBUG (ChatPage): mesaj_tarihi is null or not in expected format: $dateValue");
    }

    return Message(
      id: json['id'] ?? 0, // Provide default or handle potential null
      text: json['mesaj'] ?? '',
      senderId: json['kimden_id'] ?? 0,
      receiverId: json['kime_id'] ?? 0,
      time: formattedTime, // Use the formatted time
      isRead: json['okundu_mu'] == 1 || json['okundu_mu'] == true, // Handle bool/int
    );
  }
}

class ChatPage extends StatefulWidget {
  final int userId; // This is the ID of the person being chatted with
  final String name;
  final String username;
  final String profilePicUrl;
  // You might need to pass the current user's ID as well
  // final int currentUserId;

  const ChatPage({
    Key? key,
    required this.userId,
    required this.name,
    required this.username,
    required this.profilePicUrl,
    // required this.currentUserId,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoadingMessages = false;
  bool _allMessagesLoaded = false;
  // int _messageOffset = 0; // REMOVED: Use _messages.length instead
  final int _messageLimit = 20; // Number of messages to fetch per request
  bool _isFetchingUserId = true; // Flag to track user ID fetching
  final String apiUrl = ConfigLoader.apiUrl; // Get apiUrl from ConfigLoader
  final String bearerToken = ConfigLoader.bearerToken; // Get bearerToken from ConfigLoader
  int? _myUserId; // Make _myUserId nullable
  Set<int> _locallyMarkedAsSeenIds = {}; // Track messages marked as seen in this session
  double? _lastMaxScrollExtentBeforeLoad; // To preserve scroll position

  @override
  void initState() {
    super.initState();
    VisibilityDetectorController.instance.updateInterval = Duration.zero; // Trigger check immediately
    timeago.setLocaleMessages('tr', timeago.TrMessages()); // Set timeago locale
    // Add listener to scroll controller for pagination
    _scrollController.addListener(_scrollListener);
    // Fetch user ID first, then fetch messages
    _loadMyUserIdAndFetchMessages();
  }

  // New function to load user ID and then fetch messages
  Future<void> _loadMyUserIdAndFetchMessages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) { // Check if the widget is still in the tree
      setState(() {
        _myUserId = prefs.getInt('userId');
        _isFetchingUserId = false; // Done fetching user ID
      });

      if (_myUserId == null) {
        // Handle error: User ID not found in SharedPreferences
        print("Error (ChatPage): User ID not found in SharedPreferences."); // Log error
        // Optionally navigate back or show an error message permanently
        setState(() {
           _isLoadingMessages = false; // Ensure loading stops if user ID fails
           _allMessagesLoaded = true; // Prevent further loading attempts
        });
      } else {
        // User ID loaded successfully, fetch initial messages
        _fetchMessages(initialLoad: true);
      }
    }
  }


  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_scrollListener); // Remove listener
    _scrollController.dispose();
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
             // Scroll to bottom after initial load
             WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(isInitial: true));
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


  void _sendMessage() {
    // Ensure myUserId is loaded before sending
    if (_myUserId == null) {
      print("Error (ChatPage): Cannot send message: _myUserId is null."); // Log error
      // ScaffoldMessenger.of(context).showSnackBar( // REMOVED SnackBar
      //   SnackBar(content: Text('Mesaj gönderilemedi: Kullanıcı kimliği bulunamadı.')),
      // );
      return;
    }
    if (_messageController.text.trim().isEmpty) return;

    // Create a temporary local message for immediate display
    // Note: ID, actual time, and read status will come from backend/MQTT later
    final tempMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch, // Temporary local ID
      text: _messageController.text.trim(),
      senderId: _myUserId!, // Use non-null assertion
      receiverId: widget.userId,
      time: timeago.format(DateTime.now(), locale: 'tr'), // Use timeago for temp message time
      isRead: false, // Assume not read initially
    );

    // Check mounted before calling setState
    if (!mounted) return;

    setState(() {
      _messages.add(tempMessage); // Add to the end of the list
      _messageController.clear();
    });
    _scrollToBottom(); // Scroll after sending

    // TODO: Implement actual message sending logic here (e.g., via API or MQTT)
    // Example: await sendMessageToApi(tempMessage);
  }

  void _scrollToBottom({bool isInitial = false}) {
     if (_scrollController.hasClients) {
       final maxScroll = _scrollController.position.maxScrollExtent;
       final duration = isInitial ? Duration(milliseconds: 1) : Duration(milliseconds: 300); // Instant scroll on initial load
       final curve = Curves.easeOut;

       // Use addPostFrameCallback to ensure layout is complete before scrolling
       WidgetsBinding.instance.addPostFrameCallback((_) {
         if (_scrollController.hasClients) { // Check again inside callback
            _scrollController.animateTo(
              maxScroll,
              duration: duration,
              curve: curve,
            );
         }
       });
     }
  }

  // Function to mark a message as read via API
  Future<void> _markMessageAsRead(int messageId) async {
    if (_myUserId == null) {
      print("DEBUG (ChatPage): Cannot mark message $messageId as read, _myUserId is null.");
      return;
    }
    // Avoid marking again if already marked in this session
    if (_locallyMarkedAsSeenIds.contains(messageId)) {
      // print("DEBUG (ChatPage): Message $messageId already marked as seen locally.");
      return;
    }

    print("DEBUG (ChatPage): Marking message $messageId as read for user $_myUserId (API Call)");
    _locallyMarkedAsSeenIds.add(messageId); // Mark locally immediately

    try {
      // Assuming your API expects a POST request to update the status
      // Adjust the endpoint and body as per your API design
      final url = Uri.parse('$apiUrl/routers/messages.php'); // Use your message update endpoint
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
        // Send the ID of the message that was read
        // The backend should infer the reader is the recipient (_myUserId)
        body: json.encode({
          'okundu_id': messageId,
          // You might need to send the reader's ID if the backend requires it
          // 'reader_id': _myUserId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("DEBUG (ChatPage): Successfully marked message $messageId as read on backend.");
        // Optional: Find the message in _messages and update its isRead status locally
        // This provides immediate feedback but might be complex with immutable lists.
        // Consider if relying on the next fetch is sufficient.
        // if (mounted) {
        //   setState(() {
        //     final index = _messages.indexWhere((m) => m.id == messageId);
        //     if (index != -1) {
        //       // This requires Message to be mutable or recreating the list
        //       // _messages[index] = _messages[index].copyWith(isRead: true); // Example if using copyWith
        //     }
        //   });
        // }
      } else {
        print('DEBUG (ChatPage): Failed to mark message $messageId as read: ${response.statusCode} ${response.body}');
        // Optional: Remove from local set on failure to allow retry?
        _locallyMarkedAsSeenIds.remove(messageId);
      }
    } catch (e) {
      print('DEBUG (ChatPage): Error marking message $messageId as read: $e');
      // Optional: Remove from local set on failure to allow retry?
      _locallyMarkedAsSeenIds.remove(messageId);
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
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.all(10.0),
                        itemCount: _messages.length,
                        // reverse: true, // Keep false for top-loading pagination
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          // Determine if the message was sent by the current user
                          // Use non-null assertion for _myUserId as it's checked at the build method start
                          final bool isSentByMe = message.senderId == _myUserId!;
                          return _buildMessageBubble(message, isSentByMe);
                        },
                      ),
          ),
          _buildMessageInputBar(),
        ],
      ),
    );
  }

  // Update _buildMessageBubble to accept isSentByMe parameter
  Widget _buildMessageBubble(Message message, bool isSentByMe) {
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

    // Wrap the content with VisibilityDetector
    return VisibilityDetector(
      key: Key('msg_vis_${message.id}'), // Unique key for each message
      onVisibilityChanged: (visibilityInfo) {
        var visiblePercentage = visibilityInfo.visibleFraction * 100;
        // Check if mostly visible, received by me, and not already read/marked locally
        if (!isSentByMe &&
            !message.isRead &&
            visiblePercentage > 75 && // Adjust threshold as needed
            !_locallyMarkedAsSeenIds.contains(message.id))
        {
          _markMessageAsRead(message.id);
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: align,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), // Max width
              decoration: BoxDecoration(
                color: color,
                borderRadius: radius,
              ),
              child: Text(
                message.text,
                style: TextStyle(color: textColor),
              ),
            ),
            SizedBox(height: 2),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: Row( // Use Row to place time and seen status side-by-side
                mainAxisSize: MainAxisSize.min, // Row takes minimum space needed
                mainAxisAlignment: isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Text(
                    message.time, // Use time from message object
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  // Show "Görüldü" only if sent by me and read by receiver
                  if (isSentByMe && message.isRead)
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0), // Add space before "Görüldü"
                      child: Text(
                        'Görüldü',
                        style: TextStyle(
                          color: Colors.blueGrey, // Or another subtle color
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInputBar() {
    return Container(
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
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Mesaj yaz...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10,horizontal: 10) // Center hint text vertically
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null, // Allows multiline input
              ),
            ),
          ),
          SizedBox(width: 8.0),
          IconButton(
            icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

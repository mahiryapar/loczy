import 'dart:async'; // Import async library for Timer
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:loczy/pages/hesabim.dart';
import 'package:loczy/pages/kesfet.dart';
import 'package:loczy/pages/mesajlar.dart';
import 'package:loczy/pages/upload.dart';
import 'package:loczy/providers/notification_provider.dart';
import 'package:loczy/services/mqtt_service.dart';
import 'package:loczy/services/notification_service.dart';
import 'package:loczy/utils/time_utils.dart'; // Add import for the new utility
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loczy/pages/home_page.dart';
import 'package:loczy/config_getter.dart';
import 'package:http/http.dart' as http;
import 'package:loczy/pages/chat_page.dart'; // Import your chat page
import 'package:loczy/pages/post_goster.dart';

class AnaSayfa extends StatefulWidget {
  final Function logout;

  AnaSayfa({Key? key, required this.logout}) : super(key: key);
  @override
  _AnaSayfaState createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  int _selectedIndex = 0;
  String _username = '@KullanıcıAdı'; // Varsayılan kullanıcı adı
  bool _showNotifications = false;
  MqttService? _mqttService; // Make MqttService nullable
  bool _showExpandedContent = false; // Controls visibility of expanded content
  Timer? _expandTimer; // Timer for delayed appearance

  // Define the async logout function
  Future<void> _logout() async {
    // Disconnect MQTT before logging out
    _mqttService?.disconnect();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Clear notification provider state on logout
    Provider.of<NotificationProvider>(context, listen: false).clearNotifications();
    await prefs.remove('userId');
    await prefs.remove('userNickname');
    await prefs.remove('user_isim');
    await prefs.remove('user_soyisim');
    await prefs.remove('user_mail');
    await prefs.remove('user_number');
    await prefs.remove('user_ev_konum');
    await prefs.remove('user_hesap_turu');
    await prefs.remove('user_pp_url');
    await prefs.remove('user_takipci');
    await prefs.remove('biyografi');
    await prefs.remove('user_takip_edilenler');
    // Also remove the downloaded profile photo if needed
    String? photoPath = prefs.getString('user_profile_photo_path');
    if (photoPath != null) {
      try {
        final file = File(photoPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Handle potential file deletion errors
        print("Error deleting profile photo: $e");
      }
      await prefs.remove('user_profile_photo_path');
    }
    // Call the original logout function passed from MainScreen if needed
    // This assumes the function passed to AnaSayfa primarily updates the UI state in MainScreen
    widget.logout();
  }

  void _loadUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = '@' + (prefs.getString('userNickname') ?? 'KullanıcıAdı');
    });
  }

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _initializeMqtt(); // Initialize MQTT here
    _fetchStoredNotifications(); // Add this line to fetch stored notifications
    _pages = [
      HomePage(),
      MessagesPage(),
      ExplorePage(),
      UploadPage(),
      ProfilePage(logout: _logout),
    ];
  }

  // Add this new method to fetch stored notifications
  Future<void> _fetchStoredNotifications() async {
    print('DEBUG: ========== FETCH STORED NOTIFICATIONS STARTED ==========');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('userId');
    
    if (userId == null) {
      print('DEBUG: Cannot fetch notifications: userId not found');
      return;
    }
    
    print('DEBUG: Fetching notifications for user ID: $userId');
    try {
      final url = '${ConfigLoader.apiUrl}/routers/notifications.php?user_id=$userId';
      print('DEBUG: Fetch URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
      );
      
      print('DEBUG: Response status code: ${response.statusCode}');
      print('DEBUG: Raw response body: ${response.body}');
      
      if (response.statusCode == 200) {
        print('DEBUG: Response received successfully');
        final List<dynamic> notifications = json.decode(response.body);
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        
        print('DEBUG: Fetched ${notifications.length} notifications from database');
        print('DEBUG: Full notifications list: $notifications');
        
        // DEBUG: Print structure of the first notification if it exists
        if (notifications.isNotEmpty) {
          print('DEBUG: First notification structure:');
          final firstNotification = notifications[0];
          print('Keys: ${firstNotification.keys.toList()}');
          firstNotification.forEach((key, value) {
            print('$key: ${value.runtimeType} = $value');
          });
        }
        
        // Add unread notifications to the provider
        int unreadCount = 0;
        List<int> unreadNotificationIds = []; // Track IDs of unread notifications
        
        for (var notification in notifications) {
          print('DEBUG: \n--- Processing notification: $notification ---');
          
          // Debug read status
          print('DEBUG: Read status: ${notification['read']} (${notification['read'].runtimeType})');
          
          // Skip if already read (read = 1 or true)
          if (notification['read'] == 1 || notification['read'] == true) {
            print('DEBUG: Notification already read, skipping');
            continue;
          }
          
          unreadCount++;
          int notificationId = notification['id'];
          unreadNotificationIds.add(notificationId); // Add ID to list for marking later
          
          // Extract notification data from the nested 'content' field
          final Map<String, dynamic> content = notification['content'];
          print('DEBUG: Content: $content');
          
          // Get the actual values from content field
          final String type = content['type'] ?? 'default';
          final String title = content['title'] ?? 'Bildirim';
          final String body = content['body'] ?? '';
          
          print('DEBUG: Notification data:');
          print('  ID: $notificationId');
          print('  Type: $type');
          print('  Title: $title');
          print('  Body: $body');
          
          // Create payload based on notification type
          Map<String, dynamic> payloadData = {
            'type': type,
            'notification_id': notificationId,
          };
          
          // Add type-specific data to the payload
          // These are nested inside the content object, not directly in notification
          switch (type) {
            case 'post_like':
            case 'comment':
              if (content['post_id'] != null) {
                payloadData['post_id'] = content['post_id'];
                print('DEBUG: Added post_id: ${content['post_id']} to payload');
              }
              break;
              
            case 'follow_request':
              if (content['user_id'] != null) {
                payloadData['user_id'] = content['user_id'];
                print('DEBUG: Added user_id: ${content['user_id']} to payload');
              }
              break;
              
            case 'chat_message':
              if (content['sender_id'] != null) {
                payloadData['senderId'] = content['sender_id'];
              }
              if (content['chat_id'] != null) {
                payloadData['chatId'] = content['chat_id'];
              }
              break;
          }
          
          print('DEBUG: Final payload: $payloadData');
          
          // Add the notification to the provider with database ID
          notificationProvider.addNotification(
            title, 
            body, 
            type: type, 
            payload: payloadData,
            notificationId: notificationId,
          );
          
          // Instead of calling _markNotificationAsRead, inline the HTTP request code here
          try {
            final markResponse = await http.put(
              Uri.parse('${ConfigLoader.apiUrl}/routers/notifications.php?notification_id=$notificationId'), // notification_id as query parameter
              headers: {
              'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
              // Content-Type might not be strictly necessary for a PUT with no body,
              // but include if your API requires it.
              // 'Content-Type': 'application/json',
              },
              // Body is removed as the ID is now in the URL query parameter
            );
            
            if (markResponse.statusCode == 200) {
              print('DEBUG: Successfully marked notification $notificationId as read');
            } else {
              print('DEBUG: Failed to mark notification $notificationId as read: ${markResponse.statusCode}');
            }
          } catch (e) {
            print('DEBUG: Error marking notification $notificationId as read: $e');
          }
        }
        print('DEBUG: Added $unreadCount unread notifications to the provider');
        
        print('DEBUG: All notifications marked as read in database');
        
      } else {
        print('DEBUG: Failed to fetch notifications: ${response.statusCode}');
        print('DEBUG: Error response: ${response.body}');
        try {
          final errorBody = json.decode(response.body);
          print('DEBUG: Error details: $errorBody');
        } catch (_) {
          print('DEBUG: Could not parse error response as JSON');
        }
      }
    } catch (e) {
      print('DEBUG: Exception in _fetchStoredNotifications: $e');
    }
    print('DEBUG: ========== FETCH STORED NOTIFICATIONS COMPLETED ==========');
  }

  // Initialize and connect MQTT service
  void _initializeMqtt() async {
    print("AnaSayfa: _initializeMqtt called."); // DEBUG PRINT
    // Ensure context is available and mounted before accessing Provider
    if (mounted) {
       print("AnaSayfa: Widget is mounted. Initializing MQTT..."); // DEBUG PRINT
       try {
         final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
         print("AnaSayfa: NotificationProvider obtained."); // DEBUG PRINT
         _mqttService = MqttService(
           notificationService: NotificationService(), // Get singleton instance
           notificationProvider: notificationProvider,
         );
         print("AnaSayfa: MqttService instance created. Connecting..."); // DEBUG PRINT
         await _mqttService!.initializeAndConnect();
         print("AnaSayfa: MqttService initializeAndConnect called."); // DEBUG PRINT
       } catch (e) {
         print("AnaSayfa: Error during MQTT initialization (mounted): $e"); // DEBUG PRINT
       }
    } else {
       print("AnaSayfa: Widget not mounted yet. Scheduling MQTT initialization."); // DEBUG PRINT
       // If not mounted yet, schedule it for after the first frame
       WidgetsBinding.instance.addPostFrameCallback((_) {
         print("AnaSayfa: Post frame callback executed."); // DEBUG PRINT
         if (mounted) { // Check again after frame
           print("AnaSayfa: Widget is now mounted in post frame callback. Initializing MQTT..."); // DEBUG PRINT
           _initializeMqtt(); // Re-call the initialization logic
         } else {
           print("AnaSayfa: Widget still not mounted in post frame callback."); // DEBUG PRINT
         }
       });
    }
  }


  @override
  void dispose() {
    print("AnaSayfa: dispose called. Disconnecting MQTT."); // DEBUG PRINT
    _expandTimer?.cancel(); // Cancel timer if active
    // Disconnect MQTT when the widget is disposed
    _mqttService?.disconnect();
    super.dispose();
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Reset notification view when changing tabs (optional)
      // if (_showNotifications) {
      //   _showNotifications = false;
      //   Provider.of<NotificationProvider>(context, listen: false).markAsRead();
      // }
    });
  }

  void _toggleNotifications() {
    _expandTimer?.cancel(); // Cancel any existing timer

    if (!_showNotifications) { // ---- Expanding ----
      setState(() {
        _showNotifications = true; // Start expanding animation
        // Don't show content immediately to prevent overflow during animation
        _showExpandedContent = false;
      });
      // Start timer to show content shortly after animation starts
      _expandTimer = Timer(Duration(milliseconds: 150), () { // Delay before showing content
         // Check if still mounted and still in expanded state before updating state
         if (mounted && _showNotifications) {
            setState(() {
               _showExpandedContent = true; // Show content now
            });
         }
      });
      // Mark as read when opening
      Provider.of<NotificationProvider>(context, listen: false).markAsRead();

    } else { // ---- Collapsing ----
      setState(() {
        _showExpandedContent = false; // Hide content immediately
        _showNotifications = false; // Start collapsing animation
      });
    }
  }

  // Add new method to handle notification tap based on its type
  void _handleNotificationTap(NotificationModel notification) {
    final String type = notification.type;
    final Map<String, dynamic>? payload = notification.payload;
    
    // Mark notification as read in database if we have an ID
    if (notification.notificationId != null) {
      _markNotificationAsRead(notification.notificationId!);
    }
    
    if (payload == null) {
      _toggleNotifications(); // Just close panel if no payload
      return;
    }
    
    switch (type) {
      case 'chat_message':
        final int? senderId = payload['senderId'];
        if (senderId != null) {
          // Find user by ID and navigate to chat (existing logic)
          _findUserById(senderId).then((userData) {
            if (userData != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(
                    chatId: payload['chatId'],
                    userId: senderId,
                    name: userData['name'],
                    username: userData['username'],
                    profilePicUrl: userData['profilePicUrl'],
                  ),
                ),
              ).then((_) {
                _toggleNotifications(); // Close panel when returning
              });
            } else {
              _toggleNotifications();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Kullanıcı bilgisine erişilemedi.')),
              );
            }
          });
        } else {
          _toggleNotifications();
        }
        break;
        
      case 'post_like':
      case 'comment':
        final int? postId = payload['post_id'];
        if (postId != null) {
          // Navigate to post detail page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostGosterPage(postId: postId),
            ),
          ).then((_) {
            _toggleNotifications(); // Close panel when returning
          });
        } else {
          _toggleNotifications();
        }
        break;
        
      case 'follow':
      case 'follow_accept':
        // Just close notification panel, or navigate to profile if desired
        _toggleNotifications();
        break;
        
      case 'follow_request':
        // Don't close the panel - user might want to accept/reject
        // The buttons are already visible in the notification
        break;
        
      default:
        _toggleNotifications();
    }
  }
  
  // Helper method to find user by ID
  Future<Map<String, dynamic>?> _findUserById(int userId) async {
    int? foundChatId;

    try {
      // 1. Fetch user details
      final userResponse = await http.get(
        Uri.parse('${ConfigLoader.apiUrl}/routers/users.php?id=$userId'),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
      );

      if (userResponse.statusCode == 200) {
        final Map<String, dynamic> userData = json.decode(userResponse.body);

        if (userData.isNotEmpty) {
          // 2. Get the current user's ID
          SharedPreferences prefs = await SharedPreferences.getInstance();
          final int? currentUserId = prefs.getInt('userId');

          // 3. Check if there's an existing chat
          if (currentUserId != null) {
            try {
              final chatResponse = await http.get(
                Uri.parse('${ConfigLoader.apiUrl}/routers/chats.php?userId=$currentUserId'),
                headers: {
                  'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
                  'Content-Type': 'application/json',
                },
              );

              if (chatResponse.statusCode == 200) {
                final List<dynamic> chats = json.decode(chatResponse.body);
                for (var chat in chats) {
                  if (chat is Map<String, dynamic>) {
                    if ((chat['kullanici1_id'] == userId && chat['kullanici2_id'] == currentUserId) ||
                        (chat['kullanici2_id'] == userId && chat['kullanici1_id'] == currentUserId)) {
                      foundChatId = chat['id'];
                      break;
                    }
                  }
                }
              }
            } catch (e) {
              print('Error during chat fetch: $e');
            }
          }

          // 4. Return user data with chat ID
          return {
            'id': userId,
            'name': (userData['isim'] ?? '') + ' ' + (userData['soyisim'] ?? ''),
            'username': userData['nickname'] ?? 'bilinmeyen',
            'profilePicUrl': userData['profil_fotosu_url'] ?? ConfigLoader.defaultProfilePhoto,
            'chatId': foundChatId,
          };
        }
      }
    } catch (e) {
      print('Error in _findUserById: $e');
    }
    return null;
  }

  // Handle follow request accept/reject
  Future<void> _handleFollowRequestAction(int requesterId, bool isAccept) async {
    if (requesterId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Geçersiz kullanıcı ID\'si')),
      );
      return;
    }

    try {
      // Get current user ID
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? currentUserId = prefs.getInt('userId');

      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kullanıcı bilgileri alınamadı')),
        );
        return;
      }

      // Construct the URL with query parameters based on the action
      String url;
      if (isAccept) {
        url = '${ConfigLoader.apiUrl}/routers/follow_reqs.php?user_id_approved=$requesterId&requested_id=$currentUserId';
      } else {
        url = '${ConfigLoader.apiUrl}/routers/follow_reqs.php?user_id=$requesterId&requested_id=$currentUserId';
      }

      final response = await http.delete( // Still using POST, but parameters are in the URL
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json', // Keep Content-Type header if the API expects it, even without a body
        },
        // Remove the body as parameters are now in the URL
        // body: json.encode(requestData),
      );

      if (response.statusCode == 200) {
        // Success - remove the notification
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        
        // Fix: Use standard for loop to find and remove notification instead of firstWhere with null
        NotificationModel? notificationToRemove;
        for (var notification in notificationProvider.notifications) {
          if (notification.type == 'follow_request' && 
              notification.payload != null && 
              notification.payload!['user_id'] == requesterId) {
            notificationToRemove = notification;
            break;
          }
        }

        if (notificationToRemove != null) {
          notificationProvider.removeNotification(notificationToRemove);
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAccept ? 'Takip isteği kabul edildi' : 'Takip isteği reddedildi'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // Handle error
        String errorMessage = 'İstek işlenirken bir sorun oluştu: ${response.statusCode}';
        try {
          // Try to decode error message from response body if available
          final errorBody = json.decode(response.body);
          if (errorBody is Map && errorBody.containsKey('message')) {
            errorMessage += ' - ${errorBody['message']}';
          } else if (errorBody is Map && errorBody.containsKey('error')) {
             errorMessage += ' - ${errorBody['error']}';
          }
        } catch (_) {
          // Ignore decoding errors, use default message
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildAppBar() {
    // Use Consumer to listen to NotificationProvider changes
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final unreadCount = notificationProvider.unreadCount;
        final notifications = notificationProvider.notifications; // Get the list
        final latestNotification = notifications.isNotEmpty ? notifications.first : null;
        final marqueeText = unreadCount > 0 && latestNotification != null
            ? '$unreadCount okunmamış bildirim: ${latestNotification.body}'
            : 'Bildirim yok'; // Default text when no unread

        // Define heights
        const double collapsedHeight = 60.0;
        const double expandedEmptyHeight = 80.0; // Height when expanded but empty
        const double expandedListHeight = 300.0;

        // Determine current height based on state
        final double currentHeight = _showNotifications
            ? (notifications.isEmpty ? expandedEmptyHeight : expandedListHeight)
            : collapsedHeight;

        // Widget to display when collapsed OR expanded but empty/animating
        final Widget marqueeWidget = Center( // Collapsed Marquee View (Center vertically)
          child: Container(
            height: 20.0, // Explicit height for Marquee container
            child: Marquee(
              key: ValueKey(marqueeText), // Add key to force rebuild on text change
              text: marqueeText,
              style: TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
                color: Colors.white
              ),
              scrollAxis: Axis.horizontal,
              blankSpace: 50.0,
              velocity: 40.0,
              pauseAfterRound: Duration(seconds: 2),
              showFadingOnlyWhenScrolling: true,
              fadingEdgeStartFraction: 0.1,
              fadingEdgeEndFraction: 0.1,
              startPadding: 10.0,
              accelerationDuration: Duration(seconds: 1),
              accelerationCurve: Curves.linear,
              decelerationDuration: Duration(milliseconds: 500),
              decelerationCurve: Curves.easeOut,
            ),
          ),
        );

        return AnimatedPositioned(
          duration: Duration(milliseconds: 300), // Slightly faster animation
          curve: Curves.easeInOut, // Smoother curve
          top: 0,
          left: 0,
          right: 0,
          height: currentHeight,
          child: GestureDetector(
            // Allow toggling if not on profile page
            onTap: _selectedIndex != 4 ? _toggleNotifications : null, // Updated condition
            child: Material(
              elevation: 10.0,
              color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).primaryColor, // Use theme color
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(_showNotifications ? 20.0 : 10.0),
                bottomRight: Radius.circular(_showNotifications ? 20.0 : 10.0),
              ),
              child: ClipRRect( // Clip content to rounded corners
                 borderRadius: BorderRadius.only(
                   bottomLeft: Radius.circular(_showNotifications ? 20.0 : 10.0),
                   bottomRight: Radius.circular(_showNotifications ? 20.0 : 10.0),
                 ),
                 child: SafeArea( // Ensure content is below status bar
                   bottom: false, // No safe area needed at the bottom of the app bar
                   child: Container( // Use Container to manage content layout
                     height: currentHeight,
                     padding: EdgeInsets.only(top: 5, bottom: 5), // Add some vertical padding
                     child: _selectedIndex == 4
                         ? Center( // Profile Page Title
                             child: Text(
                               _username,
                               style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Colors.white),
                             ),
                           )
                         : _showNotifications // Expanded or animating state
                             ? (_showExpandedContent && notifications.isNotEmpty) // Expanded, has content, after delay
                                 ? Column( // Use Column for title + list
                                     children: [
                                       Padding(
                                         padding: const EdgeInsets.symmetric(vertical: 8.0),
                                         child: Text("Bildirimler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                       ),
                                       Expanded( // Make ListView take remaining space
                                         child: ListView.builder(
                                           padding: EdgeInsets.zero, // Remove default padding
                                           itemCount: notifications.length,
                                           itemBuilder: (context, index) {
                                             final notification = notifications[index];
                                             
                                             // Check if this is a follow request notification
                                             final bool isFollowRequest = notification.type == 'follow_request';
                                             
                                             // Create the base content widget based on notification type
                                             Widget contentWidget = ListTile(
                                               dense: true,
                                               title: Text(notification.title, 
                                                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                               subtitle: Text(notification.body, 
                                                 style: TextStyle(color: Colors.white70, fontSize: 12)),
                                               onTap: () => _handleNotificationTap(notification),
                                             );
                                             
                                             // For follow requests, add accept/reject buttons
                                             if (isFollowRequest && notification.payload != null) {
                                               final int requesterId = notification.payload!['user_id'] ?? 0;
                                               if (requesterId > 0) {
                                                 contentWidget = Column(
                                                   crossAxisAlignment: CrossAxisAlignment.start,
                                                   children: [
                                                     ListTile(
                                                       dense: true,
                                                       title: Text(notification.title, 
                                                         style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                                       subtitle: Text(notification.body, 
                                                         style: TextStyle(color: Colors.white70, fontSize: 12)),
                                                     ),
                                                     Padding(
                                                       padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                                                       child: Row(
                                                         mainAxisAlignment: MainAxisAlignment.end,
                                                         children: [
                                                           // Accept button
                                                           ElevatedButton(
                                                             onPressed: () => _handleFollowRequestAction(requesterId, true),
                                                             style: ElevatedButton.styleFrom(
                                                               backgroundColor: Colors.green,
                                                               padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                                               minimumSize: Size(60, 30),
                                                             ),
                                                             child: Text('Onayla', style: TextStyle(fontSize: 12)),
                                                           ),
                                                           SizedBox(width: 8),
                                                           // Reject button
                                                           ElevatedButton(
                                                             onPressed: () => _handleFollowRequestAction(requesterId, false),
                                                             style: ElevatedButton.styleFrom(
                                                               backgroundColor: Colors.red,
                                                               padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                                               minimumSize: Size(60, 30),
                                                             ),
                                                             child: Text('Reddet', style: TextStyle(fontSize: 12)),
                                                           ),
                                                         ],
                                                       ),
                                                     ),
                                                   ],
                                                 );
                                               }
                                             }
                                             
                                             // Make the notification dismissible
                                             return Dismissible(
                                               key: ValueKey(notification),
                                               direction: DismissDirection.horizontal,
                                               onDismissed: (direction) {
                                                 Provider.of<NotificationProvider>(context, listen: false)
                                                     .removeNotification(notification);
                                                 ScaffoldMessenger.of(context).removeCurrentSnackBar();
                                                 ScaffoldMessenger.of(context).showSnackBar(
                                                   SnackBar(
                                                     content: Text('${notification.title} silindi'),
                                                     duration: Duration(seconds: 2),
                                                    ),
                                                 );
                                               },
                                               background: Container(
                                                 color: Colors.redAccent.withOpacity(0.8),
                                                 alignment: Alignment.centerLeft,
                                                 padding: EdgeInsets.symmetric(horizontal: 20.0),
                                                 child: Icon(Icons.delete_sweep, color: Colors.white),
                                               ),
                                               secondaryBackground: Container(
                                                 color: Colors.redAccent.withOpacity(0.8),
                                                 alignment: Alignment.centerRight,
                                                 padding: EdgeInsets.symmetric(horizontal: 20.0),
                                                 child: Icon(Icons.delete_sweep, color: Colors.white),
                                               ),
                                               child: contentWidget,
                                             );
                                           },
                                         ),
                                       ),
                                     ],
                                   )
                                 : marqueeWidget // Show marquee if expanded but empty OR during animation delay
                             : marqueeWidget, // Collapsed state shows marquee
                   ),
                 ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory, // Su dalgasını kaldırır
        highlightColor: Colors.transparent, // Basılı tutunca oluşan efekti kaldırır
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        child: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(Icons.home),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(Icons.message),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(Icons.explore),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(Icons.upload_rounded),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(Icons.person),
              ),
              label: '',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFFD06100),
          unselectedItemColor: const Color(0xFF383633),
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          iconSize: 24.0,
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Ensure AppBar is built above the page content
    return Stack(
      children: [
        // Add fixed padding to the top of the page content
        // The AppBar will overlay this area. Adjust '60.0' if needed.
        Padding(
          padding: EdgeInsets.only(top: 5.0), // Reverted to fixed padding
          child: _pages[_selectedIndex],
        ),
        _buildAppBar(), // AppBar is drawn on top
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Remove Scaffold's AppBar, we are using a custom one in the Stack
      // appBar: _buildAppBar(), // REMOVE THIS
      body: _buildContent(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
  
  // Add this method to mark a notification as read
  Future<void> _markNotificationAsRead(int notificationId) async {
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
        print('Failed to mark notification $notificationId as read: ${response.statusCode}');
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }
}



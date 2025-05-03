import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import http
import 'dart:convert'; // Import convert
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'package:loczy/pages/chat_page.dart';
import 'package:loczy/config_getter.dart';
import 'package:timeago/timeago.dart' as timeago; // Import timeago
// Assuming FollowUser model is accessible, e.g., from takip_listele or defined here
import 'package:loczy/pages/takip_listele.dart'; // Import FollowUser model

// ChatPreview class remains the same
class ChatPreview {
  final int userId;
  final String name;
  final String username;
  final String profilePicUrl;
  final String lastMessage;
  final String time;

  ChatPreview({
    required this.userId,
    required this.name,
    required this.username,
    required this.profilePicUrl,
    required this.lastMessage,
    required this.time,
  });

  // Add a factory constructor for easier creation from API data + user details
  factory ChatPreview.fromApi(Map<String, dynamic> chatData, Map<String, dynamic> otherUserDetails, int otherUserId) {
    String formattedTime = 'Tarih Yok';
    dynamic dateValue = chatData['son_mesaj_tarihi']; // Get the value

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
        DateTime dt = DateTime.parse(dateString);
        // Use timeago for relative time formatting
        formattedTime = timeago.format(dt, locale: 'tr'); // Use Turkish locale
      } catch (e) {
        print("Error parsing date string: '$dateString' - $e");
        // Keep formattedTime as 'Tarih Yok' or handle differently
      }
    } else {
       print("DEBUG (Messages): son_mesaj_tarihi is null or not in expected format: $dateValue");
    }


    return ChatPreview(
      userId: otherUserId, // This is the ID of the *other* user in the chat
      name: otherUserDetails['isim']+' '+otherUserDetails['soyisim'] ?? 'Bilinmeyen Kullanıcı',
      username: otherUserDetails['nickname'] ?? 'bilinmeyen', // Assuming username field is 'kullanici_adi'
      profilePicUrl: otherUserDetails['profil_fotosu_url'] ?? ConfigLoader.defaultProfilePhoto,
      lastMessage: chatData['son_mesaj_metni'] ?? '',
      time: formattedTime, // Use the timeago formatted time
    );
  }
}

class MessagesPage extends StatefulWidget {
  @override
  _MessagesPageState createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _searchController = TextEditingController();
  List<ChatPreview> _chatPreviews = []; // Holds all fetched chats
  List<FollowUser> _followingList = []; // Holds users the current user follows
  List<dynamic> _displayList = []; // Holds combined ChatPreview and FollowUser for display
  bool _isLoading = true; // Combined loading state for chats and following list
  // bool _isSearchingApi = false; // REMOVED - Search is now local
  int? _currentUserId;
  final Map<int, Map<String, dynamic>> _userCache = {}; // Cache for user details

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('tr', timeago.TrMessages()); // Set timeago locale
    _initializeData(); // Renamed initialization function
    _searchController.addListener(_filterAndSearch); // Changed listener function
  }

  // Combined initialization for chats and following list
  Future<void> _initializeData() async {
    // Make sure isLoading is set at the beginning if not already handled by caller
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    await _loadCurrentUser();
    if (_currentUserId != null) {
      // Fetch chats and following list concurrently
      await Future.wait([
        _fetchChats(),
        _fetchFollowingUsers(),
      ]);
    } else {
      print("DEBUG: Cannot fetch data, user ID not found.");
      if (mounted) {
        setState(() {
          _isLoading = false; // Stop loading if no user ID
        });
      }
    }
     // Ensure loading is false after all fetches complete or if no user ID
     // This might be redundant if _fetchChats sets it, but safe to keep
     if (mounted) {
       setState(() {
         _isLoading = false;
         _filterAndSearch(); // Perform initial filter/display
       });
     }
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('userId');
    print("DEBUG (Messages): Loaded current user ID: $_currentUserId");
  }

  // Modified to fetch multiple users efficiently (can be further optimized)
  Future<Map<int, Map<String, dynamic>>> _fetchMultipleUserDetails(List<int> userIds) async {
    Map<int, Map<String, dynamic>> usersData = {};
    List<int> idsToFetch = [];

    // Check cache first
    for (int id in userIds) {
      if (_userCache.containsKey(id)) {
        usersData[id] = _userCache[id]!;
      } else {
        idsToFetch.add(id);
      }
    }

    // Fetch remaining users (consider batching if API supports it)
    for (int id in idsToFetch) {
       try {
         final userDetails = await _fetchUserDetails(id); // Reuse existing single fetch logic
         if (userDetails['nickname'] != 'Bilinmeyen') { // Check if fetch was successful
            usersData[id] = userDetails;
            _userCache[id] = userDetails; // Add to cache
         }
       } catch (e) {
          print("DEBUG (Messages): Error fetching details for user ID $id in batch: $e");
       }
    }
    return usersData;
  }

  // Helper to fetch user details with caching (similar to home_page.dart)
  Future<Map<String, dynamic>> _fetchUserDetails(int? userId) async {
    if (userId == null) {
      return {'nickname': 'Bilinmeyen', 'kullanici_adi': 'bilinmeyen', 'profil_fotosu_url': ConfigLoader.defaultProfilePhoto};
    }
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    try {
      final userResponse = await http.get(
        Uri.parse('${ConfigLoader.apiUrl}/routers/users.php?id=$userId'), // Assuming users.php takes 'id'
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
      );
      if (userResponse.statusCode == 200) {
        // IMPORTANT: Check if the response body is a single user object or a list containing one object
        final dynamic decodedBody = json.decode(userResponse.body);
        Map<String, dynamic> userJson;
        if (decodedBody is List && decodedBody.isNotEmpty) {
          userJson = decodedBody[0] as Map<String, dynamic>; // Take the first user if it's a list
        } else if (decodedBody is Map<String, dynamic>) {
          userJson = decodedBody; // Use directly if it's an object
        } else {
          throw Exception('Unexpected user data format');
        }
        _userCache[userId] = userJson;
        return userJson;
      } else {
        print('DEBUG (Messages): Failed to fetch user details for ID $userId: ${userResponse.statusCode}');
      }
    } catch (userError) {
      print('DEBUG (Messages): Error fetching user details for ID $userId: $userError');
    }
    // Return default if fetch failed
    return {'nickname': 'Bilinmeyen', 'kullanici_adi': 'bilinmeyen', 'profil_fotosu_url': ConfigLoader.defaultProfilePhoto};
  }

  // Fetch users followed by the current user
  Future<void> _fetchFollowingUsers() async {
    if (_currentUserId == null) return;

    List<FollowUser> fetchedFollowing = [];
    try {
      final response = await http.get(
        // Fetch who the current user is following
        Uri.parse('${ConfigLoader.apiUrl}/routers/follows.php?user_id_follow=$_currentUserId'),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
      );

      print("DEBUG (Messages): Following List API Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // Extract the IDs of users being followed
        final List<int> followingUserIds = data.map((item) => item['takip_edilen_id'] as int).toList();

        // Fetch details for these users
        final usersDetailsMap = await _fetchMultipleUserDetails(followingUserIds);

        // Create FollowUser objects
        for (int userId in followingUserIds) {
           if (usersDetailsMap.containsKey(userId)) {
              // Use FollowUser.fromJson or manually create if structure differs
              // Assuming FollowUser.fromJson works with the user details structure
              fetchedFollowing.add(FollowUser.fromJson(usersDetailsMap[userId]!));
           }
        }
         print("DEBUG (Messages): Fetched ${fetchedFollowing.length} following users.");
      } else {
        print('DEBUG (Messages): Failed to load following list: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG (Messages): Error fetching following list: $e');
    } finally {
      if (mounted) {
        setState(() {
          _followingList = fetchedFollowing;
          // No need to call _filterAndSearch here, it's called after Future.wait completes
        });
      }
    }
  }

  Future<void> _fetchChats() async {
    if (_currentUserId == null) return;
    if (!mounted) return; // Check if widget is still mounted

    setState(() {
      _isLoading = true; // Set loading state
    });

    List<ChatPreview> fetchedPreviews = [];

    try {
      final response = await http.get(
        Uri.parse('${ConfigLoader.apiUrl}/routers/chats.php?userId=$_currentUserId'),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
      );

      print("DEBUG (Messages): Chats API Response Status: ${response.statusCode}");
      // print("DEBUG (Messages): Chats API Response Body: ${response.body}"); // Uncomment for debugging

      if (response.statusCode == 200) {
        final List<dynamic> chatsData = json.decode(response.body);

        if (chatsData.isEmpty) {
           print("DEBUG (Messages): No chats found for user $_currentUserId.");
           // Keep fetchedPreviews empty
        } else {
          // Process each chat concurrently
          List<Future<ChatPreview?>> chatFutures = [];

          for (var chatJson in chatsData) {
            if (chatJson is Map<String, dynamic>) {
              // --- Add Debug Print ---
              // print("DEBUG (Messages): Processing chatJson: $chatJson"); // Keep commented unless needed
              // --- End Debug Print ---

              chatFutures.add(Future(() async {
                try {
                  // --- Safely parse user IDs ---
                  int? parseId(dynamic idValue) {
                    if (idValue == null) return null;
                    if (idValue is int) return idValue;
                    if (idValue is String) return int.tryParse(idValue);
                    return null; // Return null for other unexpected types
                  }

                  int? user1Id = parseId(chatJson['kullanici1_id']);
                  int? user2Id = parseId(chatJson['kullanici2_id']);
                  // --- End safe parsing ---


                  // Determine the ID of the *other* user
                  int? otherUserId;
                  if (user1Id != null && user1Id == _currentUserId) {
                    otherUserId = user2Id;
                  } else if (user2Id != null && user2Id == _currentUserId) {
                    otherUserId = user1Id;
                  } else {
                    print("DEBUG (Messages): Could not determine other user ID for chat: $chatJson");
                    return null; // Skip this chat if IDs are weird
                  }

                  if (otherUserId == null) {
                     print("DEBUG (Messages): Other user ID is null for chat: $chatJson");
                     return null;
                  }

                  // Fetch the other user's details
                  Map<String, dynamic> otherUserDetails = await _fetchUserDetails(otherUserId);

                  // Create ChatPreview object
                  return ChatPreview.fromApi(chatJson, otherUserDetails, otherUserId);

                } catch (e, stackTrace) { // Also catch stackTrace for better debugging
                  print("DEBUG (Messages): Error processing individual chat: $e");
                  print("DEBUG (Messages): StackTrace: $stackTrace"); // Print stack trace
                  return null; // Return null if error processing this chat
                }
              }));
            } else {
               print("DEBUG (Messages): Invalid item format in chatsData: $chatJson");
            }
          }

          // Wait for all user details fetches and preview creations
          final results = await Future.wait(chatFutures);
          fetchedPreviews = results.whereType<ChatPreview>().toList(); // Filter out nulls

          // Sort chats by last message time (descending - newest first)
          // Assuming ChatPreview.time stores a parsable date/time string or you adapt parsing
          // For now, we'll rely on the API order or skip sorting if time isn't easily comparable
          // fetchedPreviews.sort((a, b) => b.time.compareTo(a.time)); // Add proper date comparison if needed
        }

      } else {
        print('DEBUG (Messages): Failed to load chats: ${response.statusCode} ${response.body}');
        // Optionally show an error message to the user
      }
    } catch (e) {
      print('DEBUG (Messages): Error fetching chats: $e');
      // Optionally show an error message
    } finally {
      if (mounted) {
        setState(() {
          _chatPreviews = fetchedPreviews; // Update the main list
          _filterAndSearch(); // Apply initial filter/search (will just show chats if search is empty)
          _isLoading = false; // Set loading state to false
          print("DEBUG (Messages): Finished fetching chats. Count: ${_chatPreviews.length}");
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterAndSearch); // Update listener removal
    _searchController.dispose();
    super.dispose();
  }

  // Modified filter and search function (local search only)
  void _filterAndSearch() {
    String query = _searchController.text.toLowerCase().trim();

    // 1. Filter existing chats
    List<ChatPreview> filteredChats = _chatPreviews.where((chat) {
      return chat.name.toLowerCase().contains(query) ||
             chat.username.toLowerCase().contains(query);
    }).toList();

    List<FollowUser> filteredFollowing = [];
    if (query.isNotEmpty) {
      // 2. Filter the local following list
      filteredFollowing = _followingList.where((user) {
        final nicknameLower = user.nickname.toLowerCase();
        // Assuming FollowUser has 'name' which combines first/last name or is username
        final nameLower = user.name.toLowerCase();
        return nicknameLower.contains(query) || nameLower.contains(query);
      }).toList();

      // 3. Exclude followed users who already have a chat displayed
      final Set<int> chatUserIds = filteredChats.map((chat) => chat.userId).toSet();
      filteredFollowing.removeWhere((followUser) => chatUserIds.contains(followUser.id));
    }

    // 4. Combine lists for display
    if (mounted) {
      setState(() {
        _displayList = [...filteredChats, ...filteredFollowing];
        // _isSearchingApi = false; // REMOVED
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _initializeData,
        color: const Color(0xFFD06100),
        displacement: 70.0, // Added displacement to match home_page.dart
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 80.0, left: 16.0, right: 16.0, bottom: 8.0),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Kullanıcı Ara...', // Updated hint
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
                  ),
                ),
              ),
            ),
             // REMOVED LinearProgressIndicator for _isSearchingApi
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: const Color(0xFFD06100))) // Combined initial load
                  : _displayList.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.isEmpty
                                ? 'Henüz hiç sohbetin yok.' // Message when no chats and search is empty
                                : 'Sonuç bulunamadı.', // Message when search yields no results (in chats or followed users)
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _displayList.length,
                          itemBuilder: (context, index) {
                            final item = _displayList[index];

                            if (item is ChatPreview) {
                              // --- Existing Chat Item ---
                              // ... existing ListTile code for ChatPreview ...
                               return ListTile(
                                leading: CircleAvatar(
                                  radius: 25,
                                  backgroundColor: Colors.grey.shade300,
                                  backgroundImage: NetworkImage(item.profilePicUrl),
                                  onBackgroundImageError: (_, __) { /* Handle error */ },
                                ),
                                title: Text(item.name, style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  item.lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text(item.time, style: TextStyle(color: Colors.grey, fontSize: 12)),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatPage(
                                        userId: item.userId,
                                        name: item.name,
                                        username: item.username,
                                        profilePicUrl: item.profilePicUrl,
                                      ),
                                    ),
                                  ).then((_) {
                                     // Optional: Refresh data when returning
                                     // _initializeData(); // Re-fetch everything
                                  });
                                },
                              );
                            } else if (item is FollowUser) {
                              // --- Followed User Search Result Item ---
                              // ... existing ListTile code for FollowUser ...
                               return ListTile(
                                leading: CircleAvatar(
                                  radius: 25,
                                  backgroundColor: Colors.grey.shade300,
                                  backgroundImage: NetworkImage(item.profilePhotoUrl),
                                  onBackgroundImageError: (_, __) { /* Handle error */ },
                                ),
                                title: Text(item.nickname, style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('@${item.name}'), // Displaying username/name here
                                trailing: Icon(Icons.message_outlined, color: Colors.grey, size: 20), // Icon indicating new chat
                                onTap: () {
                                  // Navigate to ChatPage to start a new chat
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatPage(
                                        userId: item.id,
                                        name: item.nickname, // Pass nickname as name
                                        username: item.name, // Pass name as username (adjust if needed)
                                        profilePicUrl: item.profilePhotoUrl,
                                      ),
                                    ),
                                  ).then((_) {
                                    // Optional: Refresh data after starting a new one
                                    // _initializeData(); // Re-fetch everything
                                  });
                                },
                              );
                            } else {
                              return Container();
                            }
                          },
                          // ... existing separatorBuilder code ...
                           separatorBuilder: (context, index) {
                             // Add divider only between items, not after the last one
                             if (index < _displayList.length - 1) {
                                // Check if the next item is of the same type or different
                                bool isNextItemSameType = (_displayList[index].runtimeType == _displayList[index + 1].runtimeType);
                                // Optionally add thicker divider between chat previews and search results
                                // For now, just a standard divider
                                return Divider(height: 1, indent: 70);
                             }
                             return Container(); // No divider after the last item
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

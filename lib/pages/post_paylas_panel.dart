import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:loczy/pages/mesajlar.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loczy/config_getter.dart';
import 'package:loczy/pages/chat_page.dart';

class PostPaylasPanel extends StatefulWidget {
  final int postId;
  final String postImageUrl; // Post media URL (video or image)
  final String thumbnailUrl; // Thumbnail URL for videos
  final String postText; // Post description or caption
  final bool isVideo; // Whether this post is a video
  
  const PostPaylasPanel({
    Key? key, 
    required this.postId, 
    required this.postImageUrl,
    required this.thumbnailUrl,
    required this.postText,
    required this.isVideo,
  }) : super(key: key);

  @override
  _PostPaylasPanelState createState() => _PostPaylasPanelState();
}

class _PostPaylasPanelState extends State<PostPaylasPanel> {
  bool _isLoading = true;
  List<ChatPreview> _chats = [];
  int? _currentUserId;
  final TextEditingController _searchController = TextEditingController();
  List<ChatPreview> _filteredChats = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _searchController.addListener(_filterChats);
  }

  void _filterChats() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredChats = _chats.where((chat) => 
        chat.name.toLowerCase().contains(query) || 
        chat.username.toLowerCase().contains(query)
      ).toList();
    });
  }

  Future<void> _loadCurrentUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('userId');
    });
    if (_currentUserId != null) {
      _fetchChats();
    }
  }

  Future<void> _fetchChats() async {
    if (_currentUserId == null) return;
    
    try {
      final response = await http.get(
        Uri.parse('${ConfigLoader.apiUrl}/routers/chats.php?userId=$_currentUserId'),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> chatsData = json.decode(response.body);
        List<ChatPreview> fetchedPreviews = [];

        for (var chatJson in chatsData) {
          // Determine the other user's ID
          int? user1Id = chatJson['kullanici1_id'] is int 
              ? chatJson['kullanici1_id'] 
              : int.tryParse(chatJson['kullanici1_id'].toString());
          
          int? user2Id = chatJson['kullanici2_id'] is int 
              ? chatJson['kullanici2_id'] 
              : int.tryParse(chatJson['kullanici2_id'].toString());

          int? otherUserId = user1Id == _currentUserId ? user2Id : user1Id;

          if (otherUserId != null) {
            // Fetch other user's details
            final userResponse = await http.get(
              Uri.parse('${ConfigLoader.apiUrl}/routers/users.php?id=$otherUserId'),
              headers: {
                'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
                'Content-Type': 'application/json',
              },
            );

            if (userResponse.statusCode == 200) {
              final userJson = json.decode(userResponse.body);
              fetchedPreviews.add(
                ChatPreview(
                  chatId: chatJson['id'] is int ? chatJson['id'] : int.tryParse(chatJson['id'].toString()) ?? 0,
                  userId: otherUserId,
                  name: '${userJson['isim']} ${userJson['soyisim']}',
                  username: userJson['nickname'] ?? '',
                  profilePicUrl: userJson['profil_fotosu_url'] ?? ConfigLoader.defaultProfilePhoto,
                  lastMessage: chatJson['son_mesaj_metni'] ?? '',
                  time: '', // Not important for sharing
                )
              );
            }
          }
        }

        setState(() {
          _chats = fetchedPreviews;
          _filteredChats = fetchedPreviews;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        print('Failed to load chats: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching chats: $e');
    }
  }

  Future<void> _sharePostWithUser(int userId, int chatId) async {
    if (_currentUserId == null) return;
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Make sure thumbnailUrl is used for display
      String displayImageUrl = widget.thumbnailUrl;
      if (displayImageUrl.isEmpty) {
        displayImageUrl = widget.postImageUrl;
      }
      
      // Create a message with post information
      // NEW FORMAT: Using ||| as separator instead of colon to avoid URL parsing issues
      // Format: post|||postId|||mediaUrl|||thumbnailUrl|||isVideo|||caption
      final String postIdPart = widget.postId.toString();
      final String isVideoPart = widget.isVideo ? "1" : "0";
      final String messagePayload = 'post|||$postIdPart|||${widget.postImageUrl}|||$displayImageUrl|||$isVideoPart|||${widget.postText}';
      
      final response = await http.post(
        Uri.parse('${ConfigLoader.apiUrl}/routers/messages.php'),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'kimden_id': _currentUserId,
          'kime_id': userId,
          'mesaj': messagePayload,
          'sohbet_id': chatId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Successfully shared
        Navigator.pop(context, true); // Close panel with success result
        
        // Update post share count
        await http.post(
          Uri.parse('${ConfigLoader.apiUrl}/routers/post_shares.php'),
          headers: {
            'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'post_id': widget.postId,
            'paylasan_id': _currentUserId,
          }),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Post paylaşılamadı: ${response.statusCode}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error sharing post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post paylaşılırken hata oluştu')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterChats);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 10, bottom: 10),
                height: 4,
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Paylaş",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              
              // Search box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Kullanıcı ara...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              
              // Chat list
              Expanded(
                child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _filteredChats.isEmpty
                    ? Center(child: Text("Sohbet bulunamadı"))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = _filteredChats[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(chat.profilePicUrl),
                            ),
                            title: Text(chat.username),
                            subtitle: Text(chat.name),
                            trailing: IconButton(
                              icon: Icon(Icons.send, color: const Color(0xFFD06100)),
                              onPressed: () => _sharePostWithUser(chat.userId, chat.chatId),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

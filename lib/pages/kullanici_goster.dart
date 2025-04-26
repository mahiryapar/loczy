import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loczy/config_getter.dart';
import 'post_goster.dart';
import 'profile_edit.dart';
import 'takip_listele.dart'; // Import the new page

class KullaniciGosterPage extends StatefulWidget {
  final int userId; 

  KullaniciGosterPage({Key? key, required this.userId}) : super(key: key);

  @override
  _KullaniciGosterPageState createState() => _KullaniciGosterPageState();
}

class _KullaniciGosterPageState extends State<KullaniciGosterPage> {
  bool _isLoading = true;
  String _name = '';
  String _nickname = ''; 
  int _following = 0;
  int _followers = 0;
  String _pp_path = '';
  String _bio = '';
  bool _isPrivate = false; 
  bool _isFollowing = false;
  bool _followRequestSent = false; 
  int _currentUserId = -1; 

  final apiUrl = ConfigLoader.apiUrl;
  final bearerToken = ConfigLoader.bearerToken;
  bool _isRefreshing = false;

  Future<void> _refreshPage() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _isLoading = true; // Show loading indicator during refresh
    });
    await _loadUserData();
    setState(() {
      _isRefreshing = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('userId') ?? -1;

    if (_currentUserId == widget.userId) {
      await _loadOwnProfileData(prefs);
    } else {
      await _fetchOtherUserProfileData(_currentUserId);
    }
     if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOwnProfileData(SharedPreferences prefs) async {
     if (mounted) {
        setState(() {
          _nickname = '@' + (prefs.getString('userNickname') ?? '');
          _name = (prefs.getString('user_isim') ?? 'Null') +
              ' ' +
              (prefs.getString('user_soyisim') ?? 'Null');
          _following = prefs.getInt('user_takip_edilenler') ?? 0;
          _followers = prefs.getInt('user_takipci') ?? 0;
          _bio = prefs.getString('biyografi') ?? '';
          _pp_path = prefs.getString('user_profile_photo_path') ?? '';
          _isPrivate = (prefs.getString('user_hesap_turu') ?? 'public') == 'private'; // true if 'private', false otherwise
          _isFollowing = false; // Cannot follow yourself
          _followRequestSent = false;
        });
     }
  }

  Future<void> _fetchOtherUserProfileData(int _currentUserId) async {
    try {
      final profileResponse = await http.get(
        Uri.parse('$apiUrl/routers/users.php?id=${widget.userId}'), // Example endpoint
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );

      // --- API Call to check follow status ---
      final followStatusResponse = await http.get(
        Uri.parse('$apiUrl/routers/follows.php?user_id=${_currentUserId}&followed_id=${widget.userId}'), // Example endpoint
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );
      final reqStatusResponse = await http.get(
        Uri.parse('$apiUrl/routers/follow_reqs.php?user_id=${_currentUserId}&requested_id=${widget.userId}'), // Example endpoint
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );


      if (profileResponse.statusCode == 200 && followStatusResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body);
        final followStatusData = jsonDecode(followStatusResponse.body);
        final reqStatusData = jsonDecode(reqStatusResponse.body);
         if (mounted) {
            setState(() {
              _nickname = '@' + profileData['nickname'] ?? ''; // Use nickname from API
              _name = profileData['isim'] + ' ' + profileData['soyisim'];
              _following = profileData['takip_edilenler'] ?? 0;
              _followers = profileData['takipci'] ?? 0;
              _bio = profileData['biyografi'] ?? '';
              _pp_path = profileData['profil_fotosu_url'] ?? '';
                _isPrivate = (profileData['hesap_turu'] ?? 'public') == 'private'; // true if 'private', false otherwise
              _isFollowing = followStatusData['followed'] ?? false;
              _followRequestSent = reqStatusData['requested'] ?? false; // Check if request is pending
            });
         }
      } else {
        print('Failed to load user data: Profile Status ${profileResponse.statusCode}, Follow Status ${followStatusResponse.statusCode}');
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Kullanıcı bilgileri yüklenemedi.')),
            );
         }
      }
    } catch (e) {
      print('Error fetching user data: $e');
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bir hata oluştu: $e')),
          );
       }
    }
  }


  Future<void> _follow() async {
    try {
      final requestBody = jsonEncode({
        'takip_eden_id': _currentUserId,
        'takip_edilen_id': widget.userId,
      });

      final response = await http.post(
        Uri.parse('$apiUrl/routers/follows.php'), // Remove parameters from URL
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json', // Keep this header
        },
        body: requestBody, // Add the JSON body here
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['message'] == 'Takip başarılı') {
          // Update SharedPreferences for the current user's following count
          SharedPreferences prefs = await SharedPreferences.getInstance();
          int currentFollowingCount = prefs.getInt('user_takip_edilenler') ?? 0;
          await prefs.setInt('user_takip_edilenler', currentFollowingCount + 1);

          if (mounted) {
            setState(() {
              _isFollowing = true;
              _followers++; // Increment the displayed profile's follower count
              _followRequestSent = false;
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(responseData['error'] ?? 'Takip etme başarısız oldu.')),
            );
          }
          print('Follow failed: ${responseData['error']}');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Takip etme isteği başarısız oldu: ${response.statusCode}')),
          );
        }
        print('Follow request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bir hata oluştu: $e')),
        );
      }
      print('Error during follow request: $e');
    }
  }

  Future<void> _unfollow() async {
    try {
      final response = await http.delete( // Use DELETE method
        Uri.parse('$apiUrl/routers/follows.php?user_id=${_currentUserId}&followed_id=${widget.userId}'),
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['message'] == 'Takip silindi') {
           // Update SharedPreferences for the current user's following count
          SharedPreferences prefs = await SharedPreferences.getInstance();
          int currentFollowingCount = prefs.getInt('user_takip_edilenler') ?? 0;
          // Ensure count doesn't go below zero
          await prefs.setInt('user_takip_edilenler', (currentFollowingCount - 1) < 0 ? 0 : currentFollowingCount - 1);

          if (mounted) {
            setState(() {
              _isFollowing = false;
              // Ensure count doesn't go below zero
              _followers = (_followers - 1) < 0 ? 0 : _followers - 1; // Decrement the displayed profile's follower count
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(responseData['error'] ?? 'Takip silinemedi.')),
            );
          }
          print('Unfollow failed: ${responseData['error']}');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Takip silme isteği başarısız oldu: ${response.statusCode}')),
          );
        }
        print('Unfollow request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      // Handle exceptions during the request
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bir hata oluştu: $e')),
        );
      }
      print('Error during unfollow request: $e');
    }
  }

  Future<void> _sendFollowRequest() async {
    try {
      final requestBody = jsonEncode({
        'gonderen_id': _currentUserId,
        'alici_id': widget.userId,
      });

      final response = await http.post(
        Uri.parse('$apiUrl/routers/follow_reqs.php'), // Remove parameters from URL
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json', // Keep this header
        },
        body: requestBody, // Add the JSON body here
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['message'] == 'Takip isteği gönderildi') {
          if (mounted) {
            setState(() {
              _followRequestSent = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Takip isteği gönderildi.')),
            );
          }
        } else if (responseData['error'] != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(responseData['error'] ?? 'Takip isteği gönderilemedi.')),
            );
          }
          print('Follow request failed: ${responseData['error']}');
        } else {
           if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Bilinmeyen bir sunucu yanıtı.')),
            );
          }
           print('Unknown server response: ${response.body}');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Takip isteği gönderilemedi: ${response.statusCode}')),
          );
        }
        print('Follow request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bir hata oluştu: $e')),
        );
      }
      print('Error during follow request: $e');
    }
  }


  // SONRA YAPILACAKLAR
  void _sendMessage() {
    // Navigate to chat screen with widget.userId
    print('Navigate to chat with user ${widget.userId}');
    // Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(userId: widget.userId)));
  }

  void _navigateToFollowers() {
    print('Navigate to followers list for user ${widget.userId}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TakipListelePage(
          userId: widget.userId,
          initialTabIndex: 1, // Index 1 for Followers tab
        ),
      ),
    );
  }

  void _navigateToFollowing() {
    print('Navigate to following list for user ${widget.userId}');
     Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TakipListelePage(
          userId: widget.userId,
          initialTabIndex: 0, // Index 0 for Following tab
        ),
      ),
    );
  }


  Widget _buildProfileHeader() {
    bool isOwnProfile = _currentUserId == widget.userId;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name,
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Row(
                      // mainAxisAlignment: MainAxisAlignment.start, // Align left
                      children: [
                        GestureDetector(
                          onTap: _navigateToFollowing,
                          child: Column(
                            children: [
                              Text('Takip', style: TextStyle(fontSize: 16)),
                              Text('$_following',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        SizedBox(width: 40),
                        GestureDetector(
                          onTap: _navigateToFollowers,
                          child: Column(
                            children: [
                              Text('Takipçi', style: TextStyle(fontSize: 16)),
                              Text('$_followers',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Spacer(), // Removed Spacer to keep avatar closer
              CircleAvatar(
                radius: 40,
                backgroundImage: _pp_path.isNotEmpty
                    ? (_pp_path.startsWith('http')
                        ? NetworkImage(_pp_path)
                        : (File(_pp_path).existsSync() ? FileImage(File(_pp_path)) : null)
                      ) as ImageProvider?
                    : null, // Default avatar if no photo
                child: _pp_path.isEmpty ? Icon(Icons.person, size: 40) : null,
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(_bio, style: TextStyle(fontSize: 16)),
          SizedBox(height: 16), // Increased spacing before buttons
          _buildActionButtons(isOwnProfile), // Build buttons based on profile type
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isOwnProfile) {
    if (isOwnProfile) {
      // --- Buttons for Own Profile ---
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileEditPage()),
                ).then((_) => _refreshPage()); // Refresh after editing
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD06100),
                foregroundColor: const Color(0xFFF2E9E9),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Profilim'),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () { /* Navigate to Konumlarım page */ },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD06100),
                foregroundColor: const Color(0xFFF2E9E9),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Konumlarım'),
            ),
          ),
        ],
      );
    } else {
      // --- Buttons for Other User's Profile ---
      if (_isPrivate && !_isFollowing) {
        // --- Private Account, Not Following ---
        return Center( 
            child: SizedBox( 
            height: 45,
            width: double.infinity, 
            child: Padding( 
              padding: const EdgeInsets.symmetric(horizontal: 16.0), 
              child: ElevatedButton(
              onPressed: _followRequestSent ? null : _sendFollowRequest, // Disable if request sent
              style: ElevatedButton.styleFrom(
                backgroundColor: _followRequestSent ? Colors.grey : const Color(0xFFD06100),
                foregroundColor: const Color(0xFFF2E9E9),
                padding: EdgeInsets.symmetric(vertical: 12), // Adjust vertical padding if needed
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(_followRequestSent ? 'İstek Gönderildi' : 'Takip İsteği Gönder'),
              ),
            ),
            ),
          );
      } else {
        // --- Public Account OR Private Account & Following ---
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isFollowing ? _unfollow : _follow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFollowing ? Colors.grey : const Color(0xFFD06100), // Different style if following
                  foregroundColor: const Color(0xFFF2E9E9),
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(_isFollowing ? 'Takibi Bırak' : 'Takip Et'),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _sendMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD06100),
                  foregroundColor: const Color(0xFFF2E9E9),
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Mesaj Gönder'),
              ),
            ),
          ],
        );
      }
    }
  }


  Future<List<Map<String, dynamic>>> _fetchPosts() async {
    // Fetch posts for the displayed user (widget.userId)
    final response = await http.get(
        Uri.parse('$apiUrl/routers/posts.php?atan_id=${widget.userId}'), // Use widget.userId
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      List<Map<String, dynamic>> posts = [];

      for (var item in data) {
        final post = {
          'id': item['id'],
          'thumbnail_url': item['thumbnail_url']
        };
        posts.add(post);
      }

      return posts;
    } else {
      print('Failed to load posts: ${response.statusCode}');
      throw Exception('Failed to load posts');
    }
  }

  Widget _buildPostsGrid() {
    bool canViewPosts = (_currentUserId == widget.userId) || !_isPrivate || (_isPrivate && _isFollowing);

    if (!canViewPosts) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 50), // Add some spacing
            Icon(Icons.lock, size: 50, color: Colors.grey[600]),
            SizedBox(height: 10),
            Text(
              'Bu Hesap Gizli',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // --- Build Post Grid ---
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchPosts(), // Fetch posts for the displayed user
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show shimmer or placeholder while posts load
          return GridView.builder(
             shrinkWrap: true,
             physics: NeverScrollableScrollPhysics(),
             gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
               crossAxisCount: 3,
               crossAxisSpacing: 4,
               mainAxisSpacing: 4,
             ),
             itemCount: 6, // Placeholder count
             itemBuilder: (context, index) {
               return Container(color: Colors.grey[300]); // Placeholder item
             },
           );
        } else if (snapshot.hasError) {
          return Center(child: Text('Gönderiler yüklenirken hata oluştu.'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('Henüz gönderi yok.'));
        } else {
          List<Map<String, dynamic>> posts = snapshot.data!;
          return GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostGosterPage(postId: posts[index]['id']),
                    ),
                  );
                },
                child: Image.network(
                  '${posts[index]['thumbnail_url']}',
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                     if (loadingProgress == null) return child;
                     return Container(color: Colors.grey[300]); // Placeholder while loading image
                   },
                  errorBuilder: (context, error, stackTrace) {
                    print("Error loading image: ${posts[index]['thumbnail_url']}, Error: $error");
                    return Container(color: Colors.grey[300], child: Icon(Icons.broken_image, color: Colors.grey[500]));
                  },
                ),
              );
            },
          );
        }
      },
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      elevation: 1,
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        _isLoading ? 'Yükleniyor...' : _nickname, // Show name in AppBar title
        style: TextStyle( fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
    ),
    body: RefreshIndicator(
      onRefresh: _refreshPage,
      displacement: 100.0, // Adjust displacement as needed
      child: _isLoading
          ? Center(child: CircularProgressIndicator(color: const Color(0xFFD06100)))
          : ListView( // Use ListView to combine header and grid
              physics: AlwaysScrollableScrollPhysics(), // Ensure refresh works even if content is short
              children: [
                _buildProfileHeader(),
                Divider(color: Colors.grey[300]), // Lighter divider
                Padding(
                  padding: const EdgeInsets.all(4.0), // Reduced padding around grid
                  child: _buildPostsGrid(),
                ),
              ],
            ),
    ),
    // No FloatingActionButton for settings on this page
  );
}
}

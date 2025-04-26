import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ayarlar.dart';
import 'package:loczy/config_getter.dart';
import 'post_goster.dart';
import 'profile_edit.dart';
import 'takip_listele.dart'; // Import TakipListelePage

class ProfilePage extends StatefulWidget {
  final Function logout;

  ProfilePage({Key? key, required this.logout}) : super(key: key);
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  String _name = '';
  int _following = 0;
  int _followers = 0;
  String _pp_path = '';
  String _bio = '';
  final apiUrl = ConfigLoader.apiUrl;
  final bearerToken = ConfigLoader.bearerToken;
  bool _isRefreshing = false;
  int _currentUserId = -1; // Add current user ID state

  Future<void> _refreshPage() async {
    // Prevent multiple refreshes at the same time
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _isLoading = true; // Show loading indicator during refresh
    });
    await _loadProfileData(); // Fetch fresh data
    setState(() {
      _isRefreshing = false;
      // _isLoading is set to false inside _loadProfileData
    });
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('userId') ?? -1;

    if (_currentUserId == -1) {
      // Handle case where user ID is not found (e.g., logout or error)
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Optionally show an error message or navigate to login
        });
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/routers/users.php?id=$_currentUserId'),
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);

        // Update state with fresh data from API
        setState(() {
          _name = (data['isim'] ?? 'Null') + ' ' + (data['soyisim'] ?? 'Null');
          _following = data['takip_edilenler'] ?? 0;
          _followers = data['takipci'] ?? 0;
          _bio = data['biyografi'] ?? '';
          _pp_path = data['profil_fotosu_url'] ?? '';
          _isLoading = false;
        });

        // Update SharedPreferences with the fresh data
        await prefs.setString('user_isim', data['isim'] ?? 'Null');
        await prefs.setString('user_soyisim', data['soyisim'] ?? 'Null');
        await prefs.setInt('user_takip_edilenler', data['takip_edilenler'] ?? 0);
        await prefs.setInt('user_takipci', data['takipci'] ?? 0);
        await prefs.setString('biyografi', data['biyografi'] ?? '');
        await prefs.setString('user_profile_photo_path', data['profil_fotosu_url'] ?? '');
        // Update other relevant fields if necessary (e.g., nickname, account type)
        await prefs.setString('userNickname', data['nickname'] ?? '');
        await prefs.setString('user_hesap_turu', data['hesap_turu'] ?? 'public');


      } else {
        // Fallback to SharedPreferences if API call fails
        print('Failed to load profile data from API: ${response.statusCode}');
        if (mounted) {
           setState(() {
            _name = (prefs.getString('user_isim') ?? 'Null') +
                ' ' +
                (prefs.getString('user_soyisim') ?? 'Null');
            _following = prefs.getInt('user_takip_edilenler') ?? 0;
            _followers = prefs.getInt('user_takipci') ?? 0;
            _bio = prefs.getString('biyografi') ?? '';
            _pp_path = prefs.getString('user_profile_photo_path') ?? '';
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profil bilgileri güncellenemedi, eski veriler gösteriliyor.')),
          );
        }
      }
    } catch (e) {
      // Handle network or other errors
      print('Error loading profile data: $e');
       if (mounted) {
          setState(() {
            // Fallback to SharedPreferences on error
            _name = (prefs.getString('user_isim') ?? 'Null') +
                ' ' +
                (prefs.getString('user_soyisim') ?? 'Null');
            _following = prefs.getInt('user_takip_edilenler') ?? 0;
            _followers = prefs.getInt('user_takipci') ?? 0;
            _bio = prefs.getString('biyografi') ?? '';
            _pp_path = prefs.getString('user_profile_photo_path') ?? '';
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profil bilgileri yüklenirken bir hata oluştu.')),
          );
       }
    }
  }

  void _navigateToFollowingList() {
    if (_currentUserId != -1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TakipListelePage(
            userId: _currentUserId,
            initialTabIndex: 0, // Following tab
            isCurrentUserList: true, // This is the current user's list
          ),
        ),
      ).then((_) => _refreshPage()); // Refresh profile page after returning
    }
  }

  void _navigateToFollowersList() {
    if (_currentUserId != -1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TakipListelePage(
            userId: _currentUserId,
            initialTabIndex: 1, // Followers tab
            isCurrentUserList: true, // This is the current user's list
          ),
        ),
      ).then((_) => _refreshPage()); // Refresh profile page after returning
    }
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name,
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector( // Wrap Following count
                              onTap: _navigateToFollowingList,
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
                            GestureDetector( // Wrap Followers count
                              onTap: _navigateToFollowersList,
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
                    Spacer(),
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: _pp_path.isNotEmpty
                  ? (_pp_path.startsWith('http')
                      ? NetworkImage(_pp_path)
                      : (File(_pp_path).existsSync() ? FileImage(File(_pp_path)) : null)
                    ) as ImageProvider? // Cast to nullable ImageProvider
                  : null, // Profil fotoğrafı
                    ),
                  ],
                ),
                SizedBox(height: 8),
                SizedBox(height: 8),
                Text(_bio, style: TextStyle(fontSize: 16)),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ProfileEditPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD06100),
                      foregroundColor: const Color(0xFFF2E9E9),
                      padding:
                          EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Profilim'),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD06100),
                          foregroundColor: const Color(0xFFF2E9E9),
                          padding: EdgeInsets.symmetric(
                              horizontal: 30, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Konumlarım'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPosts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    
    final response = await http.get(
        Uri.parse('$apiUrl/routers/posts.php?atan_id=${userId.toString()}'),
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
      throw Exception('Failed to load posts');
    }
  }

  Widget _buildPostsGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('Bu kullanıcının henüz paylaşımı yok.'));
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
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.error, color: Colors.red);
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
    body: RefreshIndicator(
      onRefresh: _refreshPage,
      displacement: 100.0,
      child: _isLoading
          ? ListView(
              physics: AlwaysScrollableScrollPhysics(),
              children: [Center(child: CircularProgressIndicator())],
            )
          : ListView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 60.0),
              children: [
                _buildProfileHeader(),
                Divider(color: const Color(0xFFD06100)),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildPostsGrid(),
                ),
              ],
            ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AyarlarPage(logout: widget.logout)),
        );
      },
      backgroundColor: const Color(0xFFD06100),
      child: Icon(Icons.settings),
    ),
  );
}
}

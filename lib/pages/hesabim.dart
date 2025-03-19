import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ayarlar.dart';
import 'package:loczy/config_getter.dart';
import 'post_goster.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = (prefs.getString('user_isim') ?? 'Null') +
          ' ' +
          (prefs.getString('user_soyisim') ?? 'Null');
      _following = prefs.getInt('user_takip_edilenler') ?? 0;
      _followers = prefs.getInt('user_takipci') ?? 0;
      _bio = prefs.getString('bio') ?? 'Biyografi';
      _pp_path = prefs.getString('user_profile_photo_path') ?? '';
      _isLoading = false;
    });
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
                            Column(
                              children: [
                                Text('Takip', style: TextStyle(fontSize: 16)),
                                Text('$_following',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            SizedBox(width: 40),
                            Column(
                              children: [
                                Text('Takipçi', style: TextStyle(fontSize: 16)),
                                Text('$_followers',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    Spacer(),
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: FileImage(File(_pp_path)), // Profil fotoğrafı
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
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD06100),
                          foregroundColor: const Color(0xFFF2E9E9),
                          padding: EdgeInsets.symmetric(
                              horizontal: 30, vertical: 10),
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(
                    top: 60.0), // Sayfayı üstten marginleme
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    Divider(
                      color: const Color(0xFFD06100),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildPostsGrid(),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AyarlarPage(logout: widget.logout,)),
          );
        },
        backgroundColor: const Color(0xFFD06100),
        child: Icon(Icons.settings),
      ),
    );
  }
}

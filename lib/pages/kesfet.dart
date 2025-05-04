import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:loczy/config_getter.dart';
import 'kullanici_goster.dart';
import 'post_goster.dart';

class ExplorePage extends StatefulWidget {
  @override
  _ExplorePageState createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  // Arama işlevselliği için değişkenler
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  List<Map<String, dynamic>> _foundUsers = [];
  
  // Post gridi için değişkenler
  bool _isLoadingPosts = true;
  List<Map<String, dynamic>> _posts = [];

  // API bilgileri
  final String apiUrl = ConfigLoader.apiUrl;
  final String bearerToken = ConfigLoader.bearerToken;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchPosts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _searchQuery = query;
      // Sorgu boşsa arama yapma
      if (query.isEmpty) {
        _isSearching = false;
        _foundUsers = [];
      } else {
        _isSearching = true;
        _searchUsers(query);
      }
    });
  }

  // Sorguya göre kullanıcı arama
  Future<void> _searchUsers(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/routers/users.php'),
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> users = jsonDecode(response.body);
        // Sorguya göre kullanıcıları filtrele
        if (mounted) {
          setState(() {
            _foundUsers = users.where((user) {
              final String name = ((user['isim'] ?? '') + ' ' + (user['soyisim'] ?? '')).toLowerCase();
              final String nickname = (user['nickname'] ?? '').toLowerCase();
              return name.contains(query) || nickname.contains(query);
            }).map<Map<String, dynamic>>((user) => {
              'id': user['id'],
              'name': '${user['isim'] ?? ''} ${user['soyisim'] ?? ''}'.trim(),
              'nickname': user['nickname'] ?? 'bilinmeyen',
              'profilePicUrl': user['profil_fotosu_url'] ?? ConfigLoader.defaultProfilePhoto,
            }).toList();
          });
        }
      }
    } catch (e) {
      print('Kullanıcı araması sırasında hata: $e');
    }
  }

  // Tüm postları getir
  Future<void> _fetchPosts() async {
    setState(() => _isLoadingPosts = true);
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/routers/posts.php'),
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> postsData = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _posts = postsData.map<Map<String, dynamic>>((post) => {
              'id': post['id'],
              'thumbnail_url': post['thumbnail_url'] ?? post['video_foto_url'] ?? 'https://via.placeholder.com/150',
            }).toList();
            _isLoadingPosts = false;
          });
        }
      } else {
        setState(() => _isLoadingPosts = false);
        throw Exception('Postlar yüklenemedi');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPosts = false);
        print('Post getirme hatası: $e');
      }
    }
  }

  // Arama sonuçlarını oluştur
  Widget _buildSearchResults() {
    if (_foundUsers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(child: Text('Kullanıcı bulunamadı')),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _foundUsers.length,
      itemBuilder: (context, index) {
        final user = _foundUsers[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(user['profilePicUrl']),
            onBackgroundImageError: (e, s) => Icon(Icons.person),
          ),
          title: Text(user['nickname'], style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(user['name']),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => KullaniciGosterPage(userId: user['id']),
              ),
            );
          },
        );
      },
    );
  }

  // Post gridini oluştur
  Widget _buildPostsGrid() {
    if (_isLoadingPosts) {
      return Center(child: CircularProgressIndicator(color: const Color(0xFFD06100)));
    }

    if (_posts.isEmpty) {
      return Center(child: Text('Henüz post bulunmuyor.'));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostGosterPage(postId: _posts[index]['id']),
              ),
            );
          },
          child: Image.network(
            _posts[index]['thumbnail_url'],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: Icon(Icons.image_not_supported, color: Colors.red),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Add space to prevent overlap with custom app bar
            SizedBox(height: 40.0),
            
            // Arama çubuğu
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Kullanıcı ara (isim veya kullanıcı adı)...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding: EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            
            // Ana içerik
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  if (!_isSearching) {
                    await _fetchPosts();
                  }
                },
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Arama yapılıyorsa sonuçları göster
                      if (_isSearching) _buildSearchResults(),
                      
                      // Arama yapılmıyorsa post gridini göster
                      if (!_isSearching)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                child: Text(
                                  'Keşfet',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ),
                              _buildPostsGrid(),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
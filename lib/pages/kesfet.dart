import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:loczy/config_getter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'kullanici_goster.dart';
import 'post_goster.dart';
import 'package:geolocator/geolocator.dart'; // Import geolocator

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
  List<Map<String, dynamic>> _posts = []; // This will hold the filtered posts

  // API bilgileri
  final String apiUrl = ConfigLoader.apiUrl;
  final String bearerToken = ConfigLoader.bearerToken;

  // User ID from SharedPreferences
  int? currentUserId;

  @override
  void initState() {
    super.initState();
    print('KESFET DEBUG: initState called');
    _loadUserId(); // Load user ID from SharedPreferences
    _searchController.addListener(_onSearchChanged);
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

  // Load user ID from SharedPreferences
  Future<void> _loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      
      print('KESFET DEBUG: Loaded userId from SharedPreferences: $userId');
      
      if (userId != null) {
        setState(() {
          currentUserId = userId;
        });
      } else {
        print('KESFET DEBUG: WARNING - userId not found in SharedPreferences');
      }
      
      // Now fetch posts after we have the user ID
      _fetchPosts();
    } catch (e) {
      print('KESFET DEBUG: Error loading userId from SharedPreferences: $e');
      // Fetch posts anyway, but they won't be filtered by user
      _fetchPosts();
    }
  }

  // Tüm postları getir ve filtrele
  Future<void> _fetchPosts() async {
    print('KESFET DEBUG: _fetchPosts started');
    setState(() => _isLoadingPosts = true);
    List<Map<String, dynamic>> allPosts = [];
    List<Map<String, dynamic>> myPosts = [];
    List<Map<String, dynamic>> otherPosts = [];
    List<Map<String, dynamic>> filteredPosts = [];

    try {
      print('KESFET DEBUG: Fetching posts from API: $apiUrl/routers/posts.php');
      final response = await http.get(
        Uri.parse('$apiUrl/routers/posts.php'),
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );

      print('KESFET DEBUG: API response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> postsData = jsonDecode(response.body);
        print('KESFET DEBUG: Retrieved ${postsData.length} posts');
        
        // Parse all posts and extract location data
        allPosts = postsData.map<Map<String, dynamic>>((post) {
          double? latitude;
          double? longitude;
          String? locationName;
          String? locationJsonString = post['konum']; // Get location JSON string
          
          print('KESFET DEBUG: Processing post ${post['id']} with location data: $locationJsonString');
          
          if (locationJsonString != null && locationJsonString.isNotEmpty) {
            try {
              Map<String, dynamic> locationData = jsonDecode(locationJsonString);
              locationName = locationData['name'];
              latitude = locationData['latitude']?.toDouble();
              longitude = locationData['longitude']?.toDouble();
              
              print('KESFET DEBUG: Successfully parsed location for post ${post['id']}: $locationName, lat: $latitude, lng: $longitude');
            } catch (e) {
              print('KESFET DEBUG: Error decoding location JSON for post ${post['id']}: $e');
              // Try to print the problematic JSON for debugging
              print('KESFET DEBUG: Raw location data was: $locationJsonString');
              // Keep latitude/longitude as null if decoding fails
            }
          } else {
            print('KESFET DEBUG: Post ${post['id']} has no location data');
          }

          return {
            'id': post['id'],
            'user_id': post['atan_id'], // Assuming the API returns user_id
            'thumbnail_url': post['thumbnail_url'],
            'latitude': latitude,
            'longitude': longitude,
            'location_name': locationName,
          };
        }).toList();
        print('KESFET DEBUG: currentUserId: $currentUserId');
        // Separate user's posts from others
        for (var post in allPosts) {
          if (currentUserId != null && post['user_id'] == currentUserId) {
            myPosts.add(post);
            print('KESFET DEBUG: Found user\'s post ${post['id']} (userId: $currentUserId)');
          } else {
            otherPosts.add(post);
          }
        }
        
        print('KESFET DEBUG: Found ${myPosts.length} user posts and ${otherPosts.length} other user posts');

        // Filter other posts based on distance to user's posts
        for (var otherPost in otherPosts) {
          if (otherPost['latitude'] == null || otherPost['longitude'] == null) {
            print('KESFET DEBUG: Skipping post ${otherPost['id']} - missing location data');
            continue; // Skip posts without location
          }

          bool shouldInclude = false;
          for (var myPost in myPosts) {
            if (myPost['latitude'] == null || myPost['longitude'] == null) {
              print('KESFET DEBUG: User post ${myPost['id']} has no location, skipping comparison');
              continue; // Skip user's posts without location
            }

            try {
              double distance = Geolocator.distanceBetween(
                myPost['latitude']!,
                myPost['longitude']!,
                otherPost['latitude']!,
                otherPost['longitude']!,
              );
              
              print('KESFET DEBUG: Distance between user post ${myPost['id']} and post ${otherPost['id']} is ${distance.toStringAsFixed(2)} meters');

              if (distance < 1000) { // Check if distance is less than 1000 meters
                print('KESFET DEBUG: Including post ${otherPost['id']} as it\'s within 1000 meters (${distance.toStringAsFixed(2)}m) of user post ${myPost['id']}');
                shouldInclude = true;
                break; // Found a close post, no need to check others
              }
            } catch (e) {
              print('KESFET DEBUG: Error calculating distance: $e');
            }
          }

          if (shouldInclude) {
            filteredPosts.add(otherPost);
          } else {
            print('KESFET DEBUG: Post ${otherPost['id']} not included in explore feed - too far from user\'s posts');
          }
        }
        
        print('KESFET DEBUG: Final filtered posts count: ${filteredPosts.length}');

        // If we have no user posts with location or no other posts passed the filter,
        // let's include some posts anyway to avoid empty explore feed
        if (filteredPosts.isEmpty) {
          print('KESFET DEBUG: No posts match location criteria. Adding some posts to avoid empty feed.');
          // Add up to 10 random posts from otherPosts
          int count = 0;
          for (var post in otherPosts) {
            filteredPosts.add(post);
            count++;
            if (count >= 10) break;
          }
        }

        if (mounted) {
          setState(() {
            _posts = filteredPosts; // Update state with filtered posts
            _isLoadingPosts = false;
          });
          print('KESFET DEBUG: State updated with ${_posts.length} posts');
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingPosts = false);
        }
        print('KESFET DEBUG: Failed to load posts. Status code: ${response.statusCode}');
        print('KESFET DEBUG: Response body: ${response.body}');
        throw Exception('Postlar yüklenemedi: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPosts = false);
        print('KESFET DEBUG: Post getirme/filtreleme hatası: $e');
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
      print('KESFET DEBUG: Showing loading spinner for posts');
      return Center(child: CircularProgressIndicator(color: const Color(0xFFD06100)));
    }

    if (_posts.isEmpty) {
      print('KESFET DEBUG: No posts to display');
      return Center(child: Text('Yakınında keşfedilecek post bulunmuyor.'));
    }

    print('KESFET DEBUG: Building grid with ${_posts.length} posts');
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
        final post = _posts[index];
        String locationInfo = "";
        if (post['location_name'] != null) {
          locationInfo = " at ${post['location_name']}";
        }
        
        return GestureDetector(
          onTap: () {
            print('KESFET DEBUG: Tapped on post ${post['id']}$locationInfo');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostGosterPage(postId: post['id']),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                post['thumbnail_url'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('KESFET DEBUG: Error loading image for post ${post['id']}: $error');
                  return Container(
                    color: Colors.grey[300],
                    child: Icon(Icons.image_not_supported, color: Colors.red),
                  );
                },
              ),
              if (post['location_name'] != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${post['location_name']}',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    print('KESFET DEBUG: build called');
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
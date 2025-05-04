import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loczy/config_getter.dart';
import 'post_goster.dart';

class KaydedilenlerPage extends StatefulWidget {
  const KaydedilenlerPage({Key? key}) : super(key: key);

  @override
  State<KaydedilenlerPage> createState() => _KaydedilenlerPageState();
}

class _KaydedilenlerPageState extends State<KaydedilenlerPage> {
  bool _isLoading = true;
  final apiUrl = ConfigLoader.apiUrl;
  final bearerToken = ConfigLoader.bearerToken;
  bool _isRefreshing = false;
  // Store the future as a class variable to prevent recreating it on each build
  late Future<List<Map<String, dynamic>>> _savedPostsFuture;

  @override
  void initState() {
    super.initState();
    print("DEBUG: KaydedilenlerPage - initState called");
    print("DEBUG: API URL: $apiUrl");
    print("DEBUG: Bearer token exists: ${bearerToken != null}");
    // Initialize the future only once
    _savedPostsFuture = _fetchSavedPosts();
  }

  Future<void> _refreshPage() async {
    if (_isRefreshing) return;
    print("DEBUG: KaydedilenlerPage - _refreshPage called");
    setState(() {
      _isRefreshing = true;
      _isLoading = true;
    });
    // Create a new future only when explicitly refreshing
    _savedPostsFuture = _fetchSavedPosts();
    setState(() {
      _isRefreshing = false;
      _isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchSavedPosts() async {
    print("DEBUG: KaydedilenlerPage - _fetchSavedPosts started");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    print("DEBUG: User ID from SharedPreferences: $userId");
    
    List<Map<String, dynamic>> posts = [];
    
    try {
      // First, get the list of saved post IDs
      final savesUrl = '$apiUrl/routers/saves.php?user_id=$userId';
      print("DEBUG: Calling saves API: $savesUrl");
      
      final savesResponse = await http.get(
        Uri.parse(savesUrl),
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );

      print("DEBUG: Saves API status code: ${savesResponse.statusCode}");
      print("DEBUG: Saves API response body: ${savesResponse.body}");

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (savesResponse.statusCode == 200) {
        List<dynamic> savedPostsData = jsonDecode(savesResponse.body);
        print("DEBUG: Number of saved posts: ${savedPostsData.length}");
        
        // For each saved post ID, fetch the post details including thumbnail URL
        for (var savedPost in savedPostsData) {
          print("DEBUG: Processing saved post: $savedPost");
          int postId = savedPost['post_id'];
          print("DEBUG: Fetching details for post ID: $postId");
          
          // Get post details from posts.php
          final postUrl = '$apiUrl/routers/posts.php?id=$postId';
          print("DEBUG: Calling posts API: $postUrl");
          
          final postResponse = await http.get(
            Uri.parse(postUrl),
            headers: {
              'Authorization': 'Bearer $bearerToken',
              'Content-Type': 'application/json',
            },
          );
          
          print("DEBUG: Post API status code for post $postId: ${postResponse.statusCode}");
          if (postResponse.body.isNotEmpty) {
            print("DEBUG: Post API response body for post $postId: ${postResponse.body.substring(0, postResponse.body.length > 100 ? 100 : postResponse.body.length)}...");
          }
          
          if (postResponse.statusCode == 200) {
            Map<String, dynamic> postData = jsonDecode(postResponse.body);
            print("DEBUG: Post data keys: ${postData.keys.toList()}");
            print("DEBUG: Thumbnail URL for post $postId: ${postData['thumbnail_url']}");
            
            // Add post details to our list
            posts.add({
              'id': postId,
              'thumbnail_url': postData['thumbnail_url'] ?? postData['video_foto_url'] ?? 'https://via.placeholder.com/150',
            });
          } else {
            print("DEBUG: Failed to fetch post details for post ID: $postId");
          }
        }
      } else {
        print("DEBUG: Saves API failed with status code: ${savesResponse.statusCode}");
        throw Exception('Failed to load saved posts');
      }
      
      print("DEBUG: Successfully fetched ${posts.length} saved posts");
      return posts;
    } catch (e) {
      print("DEBUG: Error in _fetchSavedPosts: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      throw Exception('Error: $e');
    }
  }

  Widget _buildPostsGrid() {
    print("DEBUG: KaydedilenlerPage - _buildPostsGrid called");
    return FutureBuilder<List<Map<String, dynamic>>>(
      // Use the stored future instead of creating a new one
      future: _savedPostsFuture,
      builder: (context, snapshot) {
        print("DEBUG: FutureBuilder connection state: ${snapshot.connectionState}");
        print("DEBUG: FutureBuilder has error: ${snapshot.hasError}");
        if (snapshot.hasError) print("DEBUG: FutureBuilder error: ${snapshot.error}");
        print("DEBUG: FutureBuilder has data: ${snapshot.hasData}");
        if (snapshot.hasData) print("DEBUG: FutureBuilder data length: ${snapshot.data!.length}");
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          print("DEBUG: FutureBuilder - showing loading indicator");
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          print("DEBUG: FutureBuilder - showing error");
          return Center(child: Text('Hata: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          print("DEBUG: FutureBuilder - no data or empty data");
          return Center(child: Text('Henüz kaydedilen gönderi yok.'));
        } else {
          print("DEBUG: FutureBuilder - building grid with ${snapshot.data!.length} posts");
          List<Map<String, dynamic>> posts = snapshot.data!;
          return GridView.builder(
            shrinkWrap: true,
            physics: AlwaysScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              print("DEBUG: Building grid item for post ${posts[index]['id']} with thumbnail ${posts[index]['thumbnail_url']}");
              return GestureDetector(
                onTap: () {
                  print("DEBUG: Post ${posts[index]['id']} tapped");
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostGosterPage(postId: posts[index]['id']),
                    ),
                  ).then((_) => _refreshPage()); // Refresh after returning
                },
                child: Image.network(
                  posts[index]['thumbnail_url'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    print("DEBUG: Error loading image for post ${posts[index]['id']}: $error");
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
    print("DEBUG: KaydedilenlerPage - build called");
    return Scaffold(
      appBar: AppBar(
        title: Text('Kaydedilenler'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPage,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : ListView(
                physics: AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildPostsGrid(),
                  ),
                ],
              ),
      ),
    );
  }
}

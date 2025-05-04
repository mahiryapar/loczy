import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:loczy/config_getter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:loczy/pages/yorumlar_panel.dart';
// Import StoryItem along with StoryViewPage and Story
import 'package:loczy/pages/story_view_page.dart' show StoryViewPage, Story, StoryItem;
import 'package:loczy/pages/kullanici_goster.dart';
// REMOVED: import 'package:async/async.dart'; // Not strictly needed for this logic
import 'package:visibility_detector/visibility_detector.dart'; // Import VisibilityDetector
import 'package:collection/collection.dart'; // Import for groupBy
import 'package:loczy/pages/post_paylas_panel.dart'; // Import the new share panel

// Define a Post model (adapt based on your actual API response)
class Post {
  final int id;
  final int atanId;
  final String creatorNickname;
  final String creatorProfilePicUrl;
  final String mediaUrl;
  final String thumbnailUrl; // Add thumbnail URL if needed
  final String aciklama;
  final String konum;
  final DateTime paylasilmaTarihi;
  final int begeniSayisi;
  final int yorumSayisi;
  final int paylasilmaSayisi;
  final int portreMi; // 0: landscape/photo, 1: portrait video
  // Add fields for like/save status if your API provides them in the list
  // final bool isLikedByCurrentUser;
  // final bool isSavedByCurrentUser;

  Post({
    required this.id,
    required this.atanId,
    required this.creatorNickname,
    required this.creatorProfilePicUrl,
    required this.mediaUrl,
    required this.thumbnailUrl,
    required this.aciklama,
    required this.konum,
    required this.paylasilmaTarihi,
    required this.begeniSayisi,
    required this.yorumSayisi,
    required this.paylasilmaSayisi,
    required this.portreMi,
    // required this.isLikedByCurrentUser,
    // required this.isSavedByCurrentUser,
  });

  // Updated factory to accept userJson
  factory Post.fromJson(Map<String, dynamic> json, Map<String, dynamic> userJson) {
    return Post(
      id: json['id'] ?? 0,
      atanId: json['atan_id'] ?? 0,
      // Get nickname and profile pic from userJson
      creatorNickname: userJson['nickname'] ?? 'Bilinmeyen',
      creatorProfilePicUrl: userJson['profil_fotosu_url'] ?? ConfigLoader.defaultProfilePhoto,
      mediaUrl: json['video_foto_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '', // Add thumbnail URL if needed
      aciklama: json['aciklama'] ?? '',
      konum: json['konum'] ?? 'Konum Yok',
      paylasilmaTarihi: json['paylasilma_tarihi'] != null
          ? DateTime.parse(json['paylasilma_tarihi']['date'])
          : DateTime.now(),
      begeniSayisi: json['begeni_sayisi'] ?? 0,
      yorumSayisi: json['yorum_sayisi'] ?? 0,
      paylasilmaSayisi: json['paylasilma_sayisi'] ?? 0,
      portreMi: json['portre_mi'] ?? 0,
      // isLikedByCurrentUser: json['is_liked'] ?? false, // Example
      // isSavedByCurrentUser: json['is_saved'] ?? false, // Example
    );
  }
}

// Define a Story model (using the one from story_view_page.dart)
// Ensure story_view_page.dart defines this class or adapt as needed
// class Story {
//   final String username;
//   final String profileImageUrl;
//   final List<String> mediaUrls;
//   Story({required this.username, required this.profileImageUrl, required this.mediaUrls});
// }
// Using the class from story_view_page.dart directly if imported

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  List<Post> _posts = []; // Posts currently displayed in the ListView
  List<Story> _stories = []; // Use the Story class from story_view_page.dart
  Set<int> _seenPostIds = {}; // Store seen post IDs fetched from API
  List<Post> _allUnseenPosts = []; // Holds ALL unseen posts after fetching and filtering
  int _displayIndex = 0; // Index marking the end of currently displayed posts in _allUnseenPosts

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasMore = true; // Whether there are more posts to load from _allUnseenPosts
  final int _limit = 5; // Number of posts to load per batch
  int? _currentUserId; // Store current user ID

  // Cache for user details to avoid redundant API calls
  final Map<int, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeFeed();
  }

  Future<void> _initializeFeed() async {
    setState(() { _isLoading = true; });
    await _loadCurrentUser();
    if (_currentUserId != null) {
      // Fetch stories along with initial posts
      await _fetchInitialData(); // Already fetches stories if isRefresh is false initially? Let's ensure it does.
    } else {
      print("DEBUG: Cannot initialize feed, user ID not found.");
      // Handle case where user ID is not available (e.g., show login)
    }
    if (mounted) {
      setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when near the bottom and not already loading/refreshing, and there are more posts
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 && // Trigger loading a bit earlier
        !_isLoading && !_isRefreshing && _hasMore) {
       _loadMorePosts();
    }
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('userId');
    print("DEBUG: Loaded current user ID: $_currentUserId");
  }

  // --- New Data Fetching Orchestration ---

  Future<void> _fetchInitialData({bool isRefresh = false}) async {
    // Allow refresh to proceed even if loading more was happening.
    // Prevent multiple simultaneous initial fetches unless it's a refresh.
    // if (_isLoading && !isRefresh) return; // This line was potentially blocking refresh, removed for clarity.
    if (_currentUserId == null) {
      print("DEBUG: Cannot fetch data, user ID is null.");
      if (mounted) setState(() { _isLoading = false; _isRefreshing = false; }); // Ensure loading state is reset
      return;
    }

    print("DEBUG: Starting _fetchInitialData (isRefresh: $isRefresh)");
    // Set loading/refreshing state immediately
    if (mounted) {
      setState(() {
        _isLoading = true; // General loading indicator
        if (isRefresh) {
          _isRefreshing = true; // Specific refresh indicator
          // Clear everything on refresh
          _posts.clear();
          _seenPostIds.clear();
          _allUnseenPosts.clear();
          _stories.clear(); // Clear stories on refresh
          _userCache.clear(); // Clear user cache on refresh
          _displayIndex = 0;
          _hasMore = true;
        }
      });
    }


    try {
      // Fetch stories concurrently with other data
      List<Future> futures = [];
      // Fetch stories on initial load AND refresh
      futures.add(_fetchStories()); // Fetch stories
      futures.add(_fetchFollowedUserIds());
      futures.add(_fetchSeenPostIds()); // Fetch seen posts again

      // Wait for followed users and seen posts IDs
      // Adjust sublist index based on whether stories future was added
      final results = await Future.wait(futures.sublist(1)); // Wait for follows and seen posts

      final followedUserIds = results[0] as List<int>;
      // Note: _fetchSeenPostIds updates _seenPostIds via setState internally

      if (followedUserIds.isEmpty) {
        print("DEBUG: User follows no one.");
        if (mounted) setState(() { _hasMore = false; _allUnseenPosts.clear(); _posts.clear(); }); // Clear posts and set no more
        // Ensure stories future completes
        await futures[0]; // Wait for _fetchStories
        return; // Exit early
      }

      // Fetch all posts from followed users
      final allFollowedPosts = await _fetchAllFollowedPosts(followedUserIds);

      // Filter seen posts, sort, and prepare the initial display batch
      _filterSortAndPrepareDisplay(allFollowedPosts);

      // Ensure story fetch is also complete
      await futures[0]; // Wait for _fetchStories

    } catch (e) {
      print('DEBUG: Error during initial data fetch: $e');
      if (mounted) setState(() { _hasMore = false; }); // Stop trying on error
    } finally {
      // Ensure loading states are reset regardless of success or failure
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          print("DEBUG: Finished _fetchInitialData. Posts displayed: ${_posts.length}. Total unseen: ${_allUnseenPosts.length}. HasMore: $_hasMore");
        });
      }
    }
  }

  // --- Step 1: Fetch Followed User IDs ---
  Future<List<int>> _fetchFollowedUserIds() async {
    if (_currentUserId == null) return [];
    print("DEBUG: Fetching followed users for user $_currentUserId...");
    List<int> ids = []; // Initialize empty list for followed IDs
    try {
      final response = await http.get(
        // *** ADJUST URL AND PARSING BASED ON YOUR follows.php API RESPONSE ***
        Uri.parse('${ConfigLoader.apiUrl}/routers/follows.php?user_id_follow=$_currentUserId'),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // Assuming API returns a list of objects like [{"following_id": 12}, {"following_id": 34}]
        // OR a simple list like [12, 34]
        // List<int> ids = []; // Moved initialization up
        if (data.isNotEmpty) {
           if (data[0] is int) { // Simple list of IDs
              ids = List<int>.from(data);
           } else if (data[0] is Map<String, dynamic> && data[0].containsKey('takip_edilen_id')) { // List of Maps
              ids = data.map((item) => item['takip_edilen_id'] as int).toList();
           }
        }
        print("DEBUG: Fetched followed user IDs: $ids");
        // *** ADD CURRENT USER ID TO THE LIST ***
        if (_currentUserId != null && !ids.contains(_currentUserId!)) {
          ids.add(_currentUserId!);
          print("DEBUG: Added current user ID ($_currentUserId) to fetch list.");
        }
        return ids;
      } else {
        print('DEBUG: Failed to load followed users: ${response.statusCode} ${response.body}');
        // Still add current user ID even if fetching follows fails, so user sees their own posts
        if (_currentUserId != null) {
           print("DEBUG: Adding current user ID ($_currentUserId) after follow fetch failure.");
           return [_currentUserId!]; // Return list containing only the current user ID
        }
        return []; // Return empty if no current user ID either
      }
    } catch (e) {
      print('DEBUG: Error fetching followed users: $e');
       // Still add current user ID even if fetching follows fails, so user sees their own posts
        if (_currentUserId != null) {
           print("DEBUG: Adding current user ID ($_currentUserId) after follow fetch error.");
           return [_currentUserId!]; // Return list containing only the current user ID
        }
      return []; // Return empty on error if no current user ID
    }
  }

  // --- Step 2: Fetch Seen Post IDs (Existing Function, ensure it updates _seenPostIds) ---
  Future<void> _fetchSeenPostIds() async {
    if (_currentUserId == null) {
       print("DEBUG: User ID not loaded, cannot fetch seen posts.");
       return;
    }
    print("DEBUG: Fetching seen post IDs for user $_currentUserId...");
    Set<int> fetchedSeenIds = {}; // Use a local variable
    try {
      final response = await http.get(
        Uri.parse('${ConfigLoader.apiUrl}/routers/post_seens.php?user_id=$_currentUserId'),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
      );
      print("DEBUG: Seen posts API response status: ${response.statusCode}");
      // print("DEBUG: Seen posts API response body: ${response.body}"); // Keep for debugging if needed
      if (response.statusCode == 200) {
        final List<dynamic> seenDataJson = json.decode(response.body);
        fetchedSeenIds = Set<int>.from(seenDataJson.map((item) {
          if (item is Map<String, dynamic> && item.containsKey('post_id')) {
            return item['post_id'] as int?;
          }
          return null;
        }).where((id) => id != null).cast<int>());
      } else {
        print('DEBUG: Failed to load seen post IDs: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Error fetching seen post IDs: $e');
    }
    // Update state *once* after fetching
    if (mounted) {
        setState(() {
            _seenPostIds = fetchedSeenIds;
            print("DEBUG: Updated _seenPostIds: $_seenPostIds");
        });
    }
  }

  // --- Step 3: Fetch All Posts from Followed Users ---
  Future<List<Post>> _fetchAllFollowedPosts(List<int> followedUserIds) async {
    print("DEBUG: Fetching posts for ${followedUserIds.length} users...");
    List<Post> allPosts = [];
    List<Future> postFutures = [];

    // Create futures for fetching posts for each followed user
    for (int userId in followedUserIds) {
      postFutures.add(
        http.get(
          // *** NO PAGE/LIMIT NEEDED HERE ***
          Uri.parse('${ConfigLoader.apiUrl}/routers/posts.php?atan_id=$userId'),
          headers: {
            'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
            'Content-Type': 'application/json',
          },
        ).then((response) async {
          if (response.statusCode == 200) {
            List<dynamic> postsJson = json.decode(response.body);
            List<Post> userPosts = [];
            // Fetch user details (can be optimized further)
            for (var postJson in postsJson) {
               final int? atanId = postJson['atan_id'];
               Map<String, dynamic> userJson = await _fetchUserDetails(atanId); // Use cached fetch
               userPosts.add(Post.fromJson(postJson, userJson));
            }
            return userPosts; // Return posts for this user
          } else {
            print('DEBUG: Failed to load posts for user $userId: ${response.statusCode}');
            return <Post>[]; // Return empty list on error
          }
        }).catchError((e) {
          print('DEBUG: Error fetching posts for user $userId: $e');
          return <Post>[]; // Return empty list on error
        })
      );
    }

    // Wait for all post fetch operations to complete
    final results = await Future.wait(postFutures);

    // Combine results from all users
    for (var userPostsList in results) {
      if (userPostsList is List<Post>) { // Ensure it's the correct type
          allPosts.addAll(userPostsList);
      }
    }

    print("DEBUG: Fetched total ${allPosts.length} posts from followed users.");
    return allPosts;
  }

   // Helper to fetch user details with caching
  Future<Map<String, dynamic>> _fetchUserDetails(int? userId) async {
    if (userId == null) {
      return {'nickname': 'Bilinmeyen', 'profil_fotosu_url': ConfigLoader.defaultProfilePhoto};
    }
    // Check cache first
    if (_userCache.containsKey(userId)) {
      // print("DEBUG: Using cached details for user $userId");
      return _userCache[userId]!;
    }

    // print("DEBUG: Fetching details for user $userId");
    try {
      final userResponse = await http.get(
        Uri.parse('${ConfigLoader.apiUrl}/routers/users.php?id=$userId'),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
      );
      if (userResponse.statusCode == 200) {
        final userJson = json.decode(userResponse.body);
        _userCache[userId] = userJson; // Store in cache
        return userJson;
      } else {
        print('DEBUG: Failed to fetch user details for atan_id $userId: ${userResponse.statusCode}');
      }
    } catch (userError) {
      print('DEBUG: Error fetching user details for atan_id $userId: $userError');
    }
    // Return default if fetch failed
    return {'nickname': 'Bilinmeyen', 'profil_fotosu_url': ConfigLoader.defaultProfilePhoto};
  }


  // --- Step 4: Filter Seen, Sort, and Prepare Initial Display ---
  void _filterSortAndPrepareDisplay(List<Post> allFollowedPosts) {
    print("DEBUG: Filtering ${allFollowedPosts.length} posts against ${_seenPostIds.length} seen IDs.");

    // Filter out seen posts
    List<Post> unseenPosts = allFollowedPosts.where((post) => !_seenPostIds.contains(post.id)).toList();
    print("DEBUG: ${unseenPosts.length} posts remaining after filtering seen.");

    // Sort by date, newest first
    unseenPosts.sort((a, b) => b.paylasilmaTarihi.compareTo(a.paylasilmaTarihi));

    // Store the full list
    _allUnseenPosts = unseenPosts;

    // Prepare the initial batch for display
    int initialLoadCount = _allUnseenPosts.length < _limit ? _allUnseenPosts.length : _limit;
    List<Post> initialPosts = _allUnseenPosts.sublist(0, initialLoadCount);

    if (mounted) {
        setState(() {
            _posts = initialPosts; // Set the initial list to display
            _displayIndex = initialPosts.length; // Update the index
            _hasMore = _allUnseenPosts.length > _displayIndex; // Check if there are more posts left
            print("DEBUG: Prepared initial display. Displaying: ${_posts.length}. HasMore: $_hasMore");
        });
    }
  }

  // --- Step 5: Load More Posts (Client-Side Pagination) ---
  void _loadMorePosts() {
    if (_isLoading || !_hasMore) return; // Don't load if already loading or no more posts

    print("DEBUG: Loading more posts...");
    setState(() { _isLoading = true; }); // Indicate loading more

    // Simulate slight delay for smoother UX if needed
    Future.delayed(Duration(milliseconds: 100), () {
        if (!mounted) return; // Check if widget is still mounted

        int nextIndex = _displayIndex + _limit;
        if (nextIndex > _allUnseenPosts.length) {
            nextIndex = _allUnseenPosts.length; // Don't go beyond the list size
        }

        // Get the next batch from the full list
        List<Post> nextPosts = _allUnseenPosts.sublist(_displayIndex, nextIndex);

        setState(() {
            _posts.addAll(nextPosts); // Add the new batch to the displayed list
            _displayIndex = nextIndex; // Update the index
            _hasMore = _displayIndex < _allUnseenPosts.length; // Check if more posts remain
            _isLoading = false; // Done loading more
            print("DEBUG: Loaded ${nextPosts.length} more posts. Displaying: ${_posts.length}. HasMore: $_hasMore");
        });
    });
  }


  // --- Refresh Logic ---
  Future<void> _refreshPage() async {
    print("DEBUG: Starting _refreshPage...");
    // Reset state and fetch everything again
    // _fetchInitialData handles fetching stories, followed IDs, seen IDs, posts, filtering/sorting
    await _fetchInitialData(isRefresh: true); // *** Ensure isRefresh is true ***
    print("DEBUG: Finished _refreshPage.");
  }

  // --- Mark Post As Seen (Existing Function - Minor Update) ---
  Future<void> _markPostAsSeen(int postId) async {
     if (_currentUserId == null) {
       print("DEBUG: User ID not loaded, cannot mark post $postId as seen.");
       return;
     }
     // Add to local set immediately (already done in _buildPostItem's VisibilityDetector)
     // _seenPostIds.add(postId); // This is handled in VisibilityDetector now

     print("DEBUG: Marking post $postId as seen for user $_currentUserId (API Call)");
     try {
        final response = await http.post(
          Uri.parse('${ConfigLoader.apiUrl}/routers/post_seens.php'),
          headers: {
            'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'post_id': postId,
            'user_id': _currentUserId,
          }),
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
           print("Successfully marked post $postId as seen on backend.");
        } else {
           print('Failed to mark post $postId as seen on backend: ${response.statusCode} ${response.body}');
           // Consider if you need to remove from local _seenPostIds on failure
        }
     } catch (e) {
        print('Error marking post $postId as seen: $e');
        // Consider if you need to remove from local _seenPostIds on failure
     }
  }


  // --- Build Methods (Stories, Post Item, Main Build) ---

  // Builds the horizontal stories list
  Widget _buildStoriesSection() {
    // Show loading indicator while fetching stories initially or during refresh
    if ((_isLoading || _isRefreshing) && _stories.isEmpty) {
      return Container(
          height: 100.0,
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
    }

    // Show "No stories" message if fetching is done and stories are empty
    if (_stories.isEmpty && !_isLoading && !_isRefreshing) {
      return Container(
        height: 100.0,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: Text(
            "Henüz hiç hikaye yok.",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Build the stories list
    return Container(
      height: 110.0, // Adjust height as needed
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _stories.length,
        itemBuilder: (context, index) {
          final story = _stories[index];
          return GestureDetector(
            onTap: () {
              // Navigate to StoryViewPage
              Navigator.push(
                context,
                MaterialPageRoute(
                  // Pass the full list, initial index, and currentUserId
                  builder: (context) => StoryViewPage(
                    allStories: _stories,
                    initialStoryIndex: index, // Pass the index of the tapped story
                    currentUserId: _currentUserId!,
                  ),
                ),
              ).then((_) {
                 _refreshStoriesAfterViewing(); // Refresh after viewing
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container( // Wrap Avatar with Container for border
                    // Apply padding only for unwatched stories to make space for the gradient border
                    padding: EdgeInsets.all(story.hasUnwatched ? 2.5 : 1.5), // Slightly thicker padding for gradient
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // Apply gradient border if unwatched
                      gradient: story.hasUnwatched
                          ? LinearGradient(
                              colors: [Color(0xFFD06100), Color(0xFFF5851F)], // Orange theme gradient
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            )
                          : null, // No gradient if watched
                      // Apply solid grey border if watched
                      border: !story.hasUnwatched
                          ? Border.all(color: Colors.grey.shade400, width: 1.0) // Grey border for watched
                          : null, // No solid border if unwatched (gradient is used)
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey.shade200, // Background for loading/error
                      backgroundImage: NetworkImage(
                        story.profileImageUrl.isNotEmpty
                            ? story.profileImageUrl
                            : ConfigLoader.defaultProfilePhoto // Fallback
                      ),
                      onBackgroundImageError: (_, __) {
                        // Optionally handle image loading errors
                      },
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    // Truncate username if too long
                    story.username.length > 9 ? '${story.username.substring(0, 8)}...' : story.username,
                    style: TextStyle(
                      fontSize: 12,
                      // Style based on watched status
                        color: story.hasUnwatched
                          ? Theme.of(context).colorScheme.primary // Use theme's primary color for unwatched
                          : Colors.grey.shade600, // Grey for watched
                      fontWeight: story.hasUnwatched ? FontWeight.bold : FontWeight.normal, // Bold for unwatched
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Add a method to show the share panel with thumbnail support
  void _showSharePanel(Post post) {
    final bool isVideo = post.mediaUrl.endsWith('.mp4');
    
    // Use thumbnail URL if available, otherwise use the media URL itself
    final String thumbnailUrl = post.thumbnailUrl.isNotEmpty ? post.thumbnailUrl : post.mediaUrl;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostPaylasPanel(
        postId: post.id,
        postImageUrl: post.mediaUrl,
        thumbnailUrl: thumbnailUrl,
        postText: post.aciklama,
        isVideo: isVideo,
      ),
    ).then((shared) {
      if (shared == true) {
        // Refresh posts to get updated share count
        _refreshPage();
      }
    });
  }

  // Builds a single post item (Keep as is, VisibilityDetector handles seen logic)
  Widget _buildPostItem(Post post) {
    // ... (no changes needed here, relies on _seenPostIds state) ...
    bool isVideo = post.mediaUrl.endsWith('.mp4');

    // Wrap the Card with VisibilityDetector
    return VisibilityDetector(
      key: Key('post_vis_${post.id}'), // Unique key for each post item
      onVisibilityChanged: (visibilityInfo) {
        var visiblePercentage = visibilityInfo.visibleFraction * 100;
        // Check if > 75% visible and not already marked as seen
        if (visiblePercentage > 75 && !_seenPostIds.contains(post.id)) {
          print("DEBUG: Post ${post.id} became visible (>$visiblePercentage%) and is not in _seenPostIds. Marking as seen.");
          // Add immediately to local set to prevent multiple API calls
          if (mounted) { // Ensure widget is still mounted before calling setState
             setState(() { // Update local state immediately for responsiveness
               _seenPostIds.add(post.id);
             });
          } else { // If not mounted, just add to the set directly
             _seenPostIds.add(post.id);
          }
          // Call the API asynchronously
          _markPostAsSeen(post.id);
        }
      },
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        elevation: 2.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post Header (User Info)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  GestureDetector(
                     onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => KullaniciGosterPage(userId: post.atanId)),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(post.creatorProfilePicUrl),
                    ),
                  ),
                  SizedBox(width: 8),
                   GestureDetector(
                     onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => KullaniciGosterPage(userId: post.atanId)),
                    ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(post.creatorNickname, style: TextStyle(fontWeight: FontWeight.bold)),
                         Text(post.konum, style: TextStyle(fontSize: 12, color: Colors.grey)),
                       ],
                     ),
                   ),
                  Spacer(),
                  // Optional: More options button (...)
                ],
              ),
            ),
            // Post Media (Image or Video)
            isVideo
                ? VideoPlayerWidget(url: post.mediaUrl, portreMi: post.portreMi)
                : Image.network(
                    post.mediaUrl,
                    fit: BoxFit.contain, // Use contain to see the whole image
                    width: double.infinity,
                    // Add loading and error builders for better UX
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return AspectRatio(aspectRatio: 16/9, child: Icon(Icons.error, color: Colors.red));
                    },
                  ),
            // Action Buttons (Like, Comment, Save)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.thumb_up_alt_outlined, color: Colors.grey), // Placeholder icon
                        onPressed: () { /* TODO: Implement like action */ },
                      ),
                      Text('${post.begeniSayisi}'), // Placeholder count
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.comment_outlined, color: Colors.grey),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (context) => YorumlarPanel(postId: post.id),
                          );
                        },
                      ),
                       Text('${post.yorumSayisi}'),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.send_outlined, color: Colors.grey),
                        onPressed: () => _showSharePanel(post),
                      ),
                       Text('${post.paylasilmaSayisi}'),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.bookmark_border, color: Colors.grey), // Placeholder icon
                    onPressed: () { /* TODO: Implement save action */ },
                  ),
                ],
              ),
            ),
            // Description and Timestamp
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Text(post.aciklama),
            ),
             Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Text(
                // Format timestamp (e.g., using timeago package)
                '${post.paylasilmaTarihi.toLocal()}'.split(' ')[0], // Simple date for now
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Main build method
  @override
  Widget build(BuildContext context) {
    // The RefreshIndicator should now work correctly as the parent Stack's
    // GestureDetector is removed and the parent Padding handles the top offset.
    return RefreshIndicator(
      displacement: 70.0, // Keep displacement relative to the list's top
      onRefresh: () {
        print("DEBUG: RefreshIndicator onRefresh triggered!");
        return _refreshPage();
      },
      child: ListView.builder(
        controller: _scrollController,
        // Set physics to ensure scrollability for RefreshIndicator
        physics: const AlwaysScrollableScrollPhysics(),
        // Add top padding to account for the AppBar height (60) + some margin (10)
        padding: EdgeInsets.only(top: 70.0, bottom: 10.0),
        itemCount: 2 // Always count Stories + Divider
                 + (_isLoading && _posts.isEmpty && !_isRefreshing ? 1 : _posts.length) // Count initial loader OR actual posts
                 + 1, // Always count the final loader/end message slot
        itemBuilder: (context, index) {

          // Stories Section - Always build at index 0
          if (index == 0) {
            return _buildStoriesSection(); // *** Ensure this is called ***
          }
          // Divider - Always build at index 1
          else if (index == 1) {
            // Only show divider if there are stories or posts to separate from
            return (_stories.isNotEmpty || _posts.isNotEmpty || _isLoading || _isRefreshing)
                   ? Padding( // Add padding around the divider
                       padding: const EdgeInsets.symmetric(vertical: 6.0), // Add vertical space
                       child: Divider(color: const Color(0xFFD06100), thickness: 1, height: 1),
                     )
                   : SizedBox.shrink(); // Hide divider if nothing is loaded yet
          }
          // Initial Loading Indicator (when posts are empty and loading, but NOT refreshing) - Build at index 2
          else if (_isLoading && _posts.isEmpty && !_isRefreshing && index == 2) {
             return Container(
                alignment: Alignment.topCenter, // Show loader below stories/divider
                padding: EdgeInsets.only(top: 50),
                child: Center(child: CircularProgressIndicator())
             );
          }
          // Post Item - Build for indices 2 to 2 + _posts.length - 1
          else if (!_posts.isEmpty && index >= 2 && index < 2 + _posts.length) {
            final postIndex = index - 2;
            // Safety check
            if (postIndex >= 0 && postIndex < _posts.length) {
               return _buildPostItem(_posts[postIndex]);
            } else {
               return SizedBox.shrink(); // Should not happen
            }
          }
          // Last item: Loader or "All caught up" message
          // This will be at index 2 if posts are empty, or 2 + _posts.length otherwise
          else {
            // Show loading more indicator only if _hasMore is true and not refreshing/initial loading
            if (_hasMore && !_isRefreshing && !_isLoading) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            // Show "All caught up" only if not loading/refreshing and no more posts
            else if (!_hasMore && !_isLoading && !_isRefreshing) {
              // Only show "all caught up" if there were posts OR stories initially,
              // or if the user follows no one. Avoid showing it during initial empty load.
              bool followedSomeone = _userCache.isNotEmpty; // Crude check, better if _fetchFollowedUserIds result was stored
              bool hasContent = _posts.isNotEmpty || _stories.isNotEmpty;

              if (hasContent || !followedSomeone) {
                 return Padding(
                   padding: const EdgeInsets.symmetric(vertical: 32.0),
                   child: Center(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Icon(Icons.done_all, size: 40.0, color: Colors.grey),
                         SizedBox(height: 8),
                         Text(
                           // Adjust message based on whether the user follows anyone
                           !followedSomeone
                               ? "Gönderi görmek için kişileri takip et."
                               : (_allUnseenPosts.isEmpty && _posts.isEmpty
                                   ? "Takip ettiğin kişilerin yeni gönderisi yok."
                                   : "Şimdilik hepsi bu kadar!"),
                           style: TextStyle(fontSize: 16.0, color: Colors.grey),
                           textAlign: TextAlign.center,
                         ),
                       ],
                     ),
                   ),
                 );
              } else {
                 // Still loading initially or in a transient empty state
                 return SizedBox(height: 50);
              }
            } else {
               // Return empty space while refreshing or in other loading states at the end
               return SizedBox(height: 50);
            }
          }
        },
      ),
    );
  }

  // Helper to refresh story watched status after viewing
  Future<void> _refreshStoriesAfterViewing() async {
      print("DEBUG: Refreshing story watched status after viewing...");
      // Refetch stories to update the watched status visually
      await _fetchStories();
  }


  // Fetch Stories (Updated Implementation)
  Future<void> _fetchStories() async {
    if (_currentUserId == null) {
      print("DEBUG: Cannot fetch stories, user ID is null.");
      if (mounted) setState(() => _stories = []); // Clear stories if user ID lost
      return;
    }
    print("DEBUG: Fetching stories for user $_currentUserId...");

    List<Story> fetchedStories = [];
    Set<int> unwatchedStoryIds = {}; // Holds UNWATCHED story IDs

    try {
      // 1. Fetch UNWATCHED story IDs
      final unwatchedResponse = await http.get(
        Uri.parse('${ConfigLoader.apiUrl}/routers/story_watches.php?user_id=$_currentUserId'),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
      );

      if (unwatchedResponse.statusCode == 200) {
        final List<dynamic> unwatchedData = json.decode(unwatchedResponse.body);
        unwatchedStoryIds = Set<int>.from(unwatchedData
            .map((item) => item is Map<String, dynamic> ? item['id'] as int? : null)
            .where((id) => id != null));
        print("DEBUG: Fetched UNWATCHED story IDs: $unwatchedStoryIds");
      } else {
        print('DEBUG: Failed to load unwatched stories: ${unwatchedResponse.statusCode}');
      }

      // 2. Fetch stories from followed users (+ self)
      final storiesResponse = await http.get(
        Uri.parse('${ConfigLoader.apiUrl}/routers/storys.php?user_id_home=$_currentUserId'),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
      );

      if (storiesResponse.statusCode == 200) {
        final List<dynamic> storiesData = json.decode(storiesResponse.body);
        print("DEBUG: Fetched raw stories data count: ${storiesData.length}");

        // Group stories by user ID (atan_id)
        final groupedRawStories = groupBy<dynamic, int>(
            storiesData, (story) => story['atan_id'] as int? ?? 0);

        print("DEBUG: Grouped stories by ${groupedRawStories.length} users.");

        // 3. Process each user's stories
        List<Future<Story?>> storyFutures = [];
        final DateTime twentyFourHoursAgoProcessing = DateTime.now().subtract(const Duration(hours: 24)); // Define here for reuse

        groupedRawStories.forEach((atanId, rawStoriesList) {
          if (atanId == 0) return;

          storyFutures.add(Future(() async {
            try {
              Map<String, dynamic> userDetails = await _fetchUserDetails(atanId);

              // *** Create List<StoryItem> ***
              List<StoryItem> storyItems = rawStoriesList.map((story) {
                // ... existing StoryItem creation logic ...
                final int storyId = story['id'] as int? ?? 0;
                final String mediaUrl = story['post_url'] as String? ?? '';
                // *** Extract and parse creation time ***
                final String? dateString = story['atilma_tarihi']?['date'] as String?;
                final DateTime creationTime = dateString != null
                    ? DateTime.tryParse(dateString) ?? DateTime.now() // Parse or default to now
                    : DateTime.now(); // Default if field is missing

                // Determine mediaType based on extension using string manipulation
                String mediaType = 'image'; // Default to image
                if (mediaUrl.isNotEmpty) {
                  final uri = Uri.tryParse(mediaUrl);
                  if (uri != null && uri.pathSegments.isNotEmpty) {
                    final lastSegment = uri.pathSegments.last;
                    final dotIndex = lastSegment.lastIndexOf('.');
                    if (dotIndex != -1 && dotIndex < lastSegment.length - 1) {
                      final extension = lastSegment.substring(dotIndex + 1).toLowerCase();
                      if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension)) {
                        mediaType = 'video';
                      }
                    }
                  }
                }

                // Return StoryItem only if ID and URL are valid
                if (storyId != 0 && mediaUrl.isNotEmpty) {
                  // Assuming StoryItem constructor accepts mediaType
                  // You might need to update StoryItem definition in story_view_page.dart
                  return StoryItem(
                    id: storyId,
                    mediaUrl: mediaUrl,
                    mediaType: mediaType, // Pass the determined type
                    creationTime: creationTime, // Pass the parsed creation time
                  );
                } else {
                  return null; // Return null for invalid items to be filtered out
                }
              }).whereType<StoryItem>().toList(); // Filter out nulls and ensure correct type

              if (storyItems.isEmpty) return null; // Skip user if no valid items

              // *** Filter items to only include those within the last 24 hours ***
              List<StoryItem> recentStoryItems = storyItems.where((item) =>
                  item.creationTime.isAfter(twentyFourHoursAgoProcessing)
              ).toList();

              // *** Determine if the user has any UNWATCHED stories WITHIN THE LAST 24 HOURS ***
              bool hasUnwatched = recentStoryItems.any((item) => unwatchedStoryIds.contains(item.id));
              // Debug print for clarity
              if (hasUnwatched) {
                 print("DEBUG: User $atanId (${userDetails['nickname']}) has unwatched RECENT stories.");
              } else {
                 // Check if they had unwatched *older* stories (for debugging comparison)
                 bool hadOlderUnwatched = storyItems.any((item) =>
                     item.creationTime.isBefore(twentyFourHoursAgoProcessing) &&
                     unwatchedStoryIds.contains(item.id)
                 );
                 if (hadOlderUnwatched) {
                    print("DEBUG: User $atanId (${userDetails['nickname']}) has only OLDER unwatched stories. Setting hasUnwatched=false.");
                 }
              }


              // *** Keep the overall story if it has ANY recent items (watched or unwatched) ***
              // This filtering happens later, outside this specific user processing block.
              // We just need to return the Story object with the correct `hasUnwatched` flag based on recent items.

              // Return the Story object, ensuring we pass the *original* full list of items
              // but use the correctly calculated `hasUnwatched` flag.
              return Story(
                userId: atanId,
                username: userDetails['nickname'] ?? 'Bilinmeyen',
                profileImageUrl: userDetails['profil_fotosu_url'] ?? ConfigLoader.defaultProfilePhoto,
                items: storyItems, // Pass the original full list for viewing
                hasUnwatched: hasUnwatched, // Use the flag based on RECENT unwatched items
              );
            } catch (e) {
               print("DEBUG: Error processing stories for user $atanId: $e");
               return null;
            }
          }));
        });

        // Wait for all user details and story processing
        final processedStories = await Future.wait(storyFutures);
        List<Story> validStories = processedStories.whereType<Story>().toList(); // Filter out nulls

        // *** Filter stories older than 24 hours ***
        // This filter remains the same: Keep a user's story circle if *any* of their items are recent.
        final DateTime twentyFourHoursAgoFilter = DateTime.now().subtract(const Duration(hours: 24));
        List<Story> recentStories = validStories.where((story) {
          // Keep the story if ANY of its items were created within the last 24 hours
          return story.items.any((item) => item.creationTime.isAfter(twentyFourHoursAgoFilter));
        }).toList();
        print("DEBUG: Filtered stories. Kept ${recentStories.length} out of ${validStories.length} based on 24-hour rule.");

        // Assign the filtered list to fetchedStories for sorting
        fetchedStories = recentStories; // Contains only stories with at least one item < 24h old

        // *** Sort stories: Prioritize current user, then unwatched, then by username ***
        Story? currentUserStory;
        fetchedStories.removeWhere((story) { // Iterate through recentStories
          if (story.userId == _currentUserId) {
            currentUserStory = story; // Store the current user's story if found
            return true; // Remove it from fetchedStories for now
          }
          return false;
        });

        // Sort remaining stories (unwatched first, then username)
        fetchedStories.sort((a, b) {
          // Use the hasUnwatched flag (which is now based on recent items)
          if (a.hasUnwatched && !b.hasUnwatched) return -1; // Unwatched (recent) first
          if (!a.hasUnwatched && b.hasUnwatched) return 1;
          // If watched status is the same (both watched or both unwatched recent), sort by username
          return a.username.compareTo(b.username);
        });

        // Add current user's story to the beginning if it exists (i.e., if it was found and removed)
        if (currentUserStory != null) {
          fetchedStories.insert(0, currentUserStory!);
        }

        print("DEBUG: Processed and sorted ${fetchedStories.length} stories for display.");

      } else {
        print('DEBUG: Failed to load stories feed: ${storiesResponse.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Error fetching stories: $e');
    }

    // Update state with the filtered and sorted list
    if (mounted) {
      setState(() {
        _stories = fetchedStories;
        print("DEBUG: Stories state updated. Count: ${_stories.length}");
      });
    }
  }


} // End of _HomePageState

// VideoPlayerWidget (Keep as is)
class VideoPlayerWidget extends StatefulWidget {
  // ... (no changes needed here) ...
  final String url;
  final int portreMi;

  const VideoPlayerWidget({Key? key, required this.url, required this.portreMi}) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  // ... (no changes needed here) ...
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _controller.play();
            _controller.setLooping(true);
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return AspectRatio(aspectRatio: 16/9, child: Center(child: CircularProgressIndicator()));
    }

    // Simplified aspect ratio logic for brevity, reuse the complex one from post_goster if needed
     double aspectRatio = _controller.value.aspectRatio;
     if (widget.portreMi == 1 && aspectRatio > 1) {
       aspectRatio = 1 / aspectRatio; // Attempt to correct portrait
     }


    return AspectRatio(
      aspectRatio: aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}

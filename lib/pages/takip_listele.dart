import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:loczy/config_getter.dart';
import 'kullanici_goster.dart'; // Import KullaniciGosterPage
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences

// Model for user data in the list
class FollowUser {
  final int id;
  final String nickname;
  final String name;
  final String profilePhotoUrl;

  FollowUser({
    required this.id,
    required this.nickname,
    required this.name,
    required this.profilePhotoUrl,
  });

  factory FollowUser.fromJson(Map<String, dynamic> json) {
    return FollowUser(
      id: json['id'] ?? 0,
      nickname: json['nickname'] ?? 'N/A',
      name: '${json['isim'] ?? ''} ${json['soyisim'] ?? ''}'.trim(),
      profilePhotoUrl: json['profil_fotosu_url'] ?? ConfigLoader.defaultProfilePhoto,
    );
  }
}

class TakipListelePage extends StatefulWidget {
  final int userId;
  final int initialTabIndex; // 0 for Following, 1 for Followers
  final bool isCurrentUserList; // New parameter

  const TakipListelePage({
    Key? key,
    required this.userId,
    this.initialTabIndex = 0, // Default to Following tab
    this.isCurrentUserList = false, // Default to false
  }) : super(key: key);

  @override
  _TakipListelePageState createState() => _TakipListelePageState();
}

class _TakipListelePageState extends State<TakipListelePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<FollowUser> _followingList = [];
  List<FollowUser> _followersList = [];
  List<FollowUser> _filteredFollowingList = [];
  List<FollowUser> _filteredFollowersList = [];

  bool _isLoadingFollowing = true;
  bool _isLoadingFollowers = true;
  String _searchQuery = '';
  int _currentUserId = -1; // Store the logged-in user's ID

  final String apiUrl = ConfigLoader.apiUrl;
  final String bearerToken = ConfigLoader.bearerToken;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(_handleTabSelection); // Add listener to update lists on tab change
    _searchController.addListener(_onSearchChanged);
    _loadCurrentUserIdAndFetchData(); // Load current user ID first
  }

  // Add listener to ensure filtering happens when tab changes
  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      _filterUsers(); // Re-filter when tab changes
    }
  }

  Future<void> _loadCurrentUserIdAndFetchData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('userId') ?? -1;
    // Now fetch data
    _fetchFollowing();
    _fetchFollowers();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterUsers();
    });
  }

  Future<List<FollowUser>> _fetchUsersByIds(List<int> userIds) async {
    List<FollowUser> users = [];
    for (int userId in userIds) {
      try {
        final response = await http.get(
          Uri.parse('$apiUrl/routers/users.php?id=$userId'),
          headers: {
            'Authorization': 'Bearer $bearerToken',
            'Content-Type': 'application/json',
          },
        );
        if (response.statusCode == 200) {
          final userData = jsonDecode(response.body);
          // Ensure userData is a Map before creating FollowUser
          if (userData is Map<String, dynamic>) {
             users.add(FollowUser.fromJson(userData));
          } else {
             print('Unexpected user data format for ID $userId: $userData');
          }

        } else {
          print('Failed to load user data for ID $userId: ${response.statusCode}');
        }
      } catch (e) {
        print('Error fetching user data for ID $userId: $e');
      }
    }
    return users;
  }

  Future<void> _fetchFollowing() async {
    setState(() => _isLoadingFollowing = true);
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/routers/follows.php?user_id_follow=${widget.userId}'),
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        // The API returns the *follower* ID when querying by *followed* ID
        final List<int> followingUserIds = data.map((item) => item['takip_edilen_id'] as int).toList();
        final users = await _fetchUsersByIds(followingUserIds);
         if (mounted) {
            setState(() {
              _followingList = users;
              _filterUsers(); // Initial filter
              _isLoadingFollowing = false; // Set loading false here
            });
         }
      } else {
        print('Failed to load following list: ${response.statusCode}');
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Takip edilenler yüklenemedi.')),
            );
            setState(() => _isLoadingFollowing = false); // Ensure loading is set false on error too
         }
      }
    } catch (e) {
      print('Error fetching following list: $e');
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bir hata oluştu: $e')),
          );
          setState(() => _isLoadingFollowing = false); // Ensure loading is set false on error too
       }
    }
  }

  Future<void> _fetchFollowers() async {
    setState(() => _isLoadingFollowers = true);
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/routers/follows.php?user_id_follower=${widget.userId}'),
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
         // The API returns the *followed* ID when querying by *follower* ID
        final List<int> followerUserIds = data.map((item) => item['takip_eden_id'] as int).toList();
        final users = await _fetchUsersByIds(followerUserIds);
         if (mounted) {
            setState(() {
              _followersList = users;
              _filterUsers(); // Initial filter
              _isLoadingFollowers = false; // Set loading false here
            });
         }
      } else {
        print('Failed to load followers list: ${response.statusCode}');
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Takipçiler yüklenemedi.')),
            );
            setState(() => _isLoadingFollowers = false); // Ensure loading is set false on error too
         }
      }
    } catch (e) {
      print('Error fetching followers list: $e');
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bir hata oluştu: $e')),
          );
          setState(() => _isLoadingFollowers = false); // Ensure loading is set false on error too
       }
    }
  }

  void _filterUsers() {
    if (_searchQuery.isEmpty) {
      _filteredFollowingList = List.from(_followingList);
      _filteredFollowersList = List.from(_followersList);
    } else {
      _filteredFollowingList = _followingList.where((user) {
        final nicknameLower = user.nickname.toLowerCase();
        final nameLower = user.name.toLowerCase();
        return nicknameLower.contains(_searchQuery) || nameLower.contains(_searchQuery);
      }).toList();

      _filteredFollowersList = _followersList.where((user) {
        final nicknameLower = user.nickname.toLowerCase();
        final nameLower = user.name.toLowerCase();
        return nicknameLower.contains(_searchQuery) || nameLower.contains(_searchQuery);
      }).toList();
    }
     if (mounted) {
        setState(() {}); // Trigger rebuild after filtering
     }
  }

  // --- Unfollow User Logic ---
  Future<void> _unfollowUser(int userIdToUnfollow) async {
    if (_currentUserId == -1) return; // Should not happen if loaded correctly

    // Show confirmation dialog
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Takibi Bırak'),
          content: Text('Bu kullanıcıyı takip etmeyi bırakmak istediğinizden emin misiniz?'),
          actions: <Widget>[
            TextButton(
              child: Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop(false); // Return false
              },
            ),
            TextButton(
              child: Text('Takibi Bırak', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true); // Return true
              },
            ),
          ],
        );
      },
    ) ?? false; // Default to false if dialog is dismissed

    if (!confirm) return; // User cancelled

    try {
      final response = await http.delete(
        Uri.parse('$apiUrl/routers/follows.php?user_id=$_currentUserId&followed_id=$userIdToUnfollow'),
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
          await prefs.setInt('user_takip_edilenler', (currentFollowingCount - 1) < 0 ? 0 : currentFollowingCount - 1);

          if (mounted) {
            setState(() {
              // Remove from original and filtered lists
              _followingList.removeWhere((user) => user.id == userIdToUnfollow);
              _filterUsers(); // Re-filter the list
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Takip bırakıldı.'), duration: Duration(seconds: 1)),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(responseData['error'] ?? 'Takip bırakılamadı.')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Takip bırakma isteği başarısız oldu: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bir hata oluştu: $e')),
        );
      }
      print('Error during unfollow request: $e');
    }
  }

  // --- Remove Follower Logic ---
  Future<void> _removeFollower(int followerIdToRemove) async {
     if (_currentUserId == -1) return;

     // Show confirmation dialog
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Takipçiyi Çıkar'),
          content: Text('Bu takipçiyi listenizden çıkarmak istediğinizden emin misiniz?'),
          actions: <Widget>[
            TextButton(
              child: Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop(false); // Return false
              },
            ),
            TextButton(
              child: Text('Çıkar', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true); // Return true
              },
            ),
          ],
        );
      },
    ) ?? false; // Default to false if dialog is dismissed

    if (!confirm) return; // User cancelled

    try {
      // *** IMPORTANT: This assumes your API supports removing a follower via DELETE
      // *** You might need to adjust the endpoint and parameters based on your API design
      // *** Example: DELETE /routers/follows.php?follower_id=X&followed_id=Y
      final response = await http.delete(
        Uri.parse('$apiUrl/routers/follows.php?user_id=$followerIdToRemove&followed_id=$_currentUserId'),
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // *** Adjust the success message check based on your API response ***
        if (responseData['message'] == 'Takipçi silindi' || responseData['message'] == 'Takip silindi') { // Adjust as needed
          // Update SharedPreferences for the current user's follower count
          SharedPreferences prefs = await SharedPreferences.getInstance();
          int currentFollowerCount = prefs.getInt('user_takipci') ?? 0;
          await prefs.setInt('user_takipci', (currentFollowerCount - 1) < 0 ? 0 : currentFollowerCount - 1);

          if (mounted) {
            setState(() {
              // Remove from original and filtered lists
              _followersList.removeWhere((user) => user.id == followerIdToRemove);
              _filterUsers(); // Re-filter the list
            });
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Takipçi çıkarıldı.'), duration: Duration(seconds: 1)),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(responseData['error'] ?? 'Takipçi çıkarılamadı.')),
            );
          }
           print('Remove follower failed: ${responseData['error']}');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Takipçi çıkarma isteği başarısız oldu: ${response.statusCode}')),
          );
        }
         print('Remove follower request failed with status: ${response.statusCode}');
         print('Response body: ${response.body}'); // Log response body for debugging
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bir hata oluştu: $e')),
        );
      }
      print('Error during remove follower request: $e');
    }
  }

  Widget _buildUserList(List<FollowUser> users, bool isLoading) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: const Color(0xFFD06100)));
    }
    // Check which tab is active to determine the correct empty message
    String emptyListMessage = 'Liste boş.';
    if (_tabController.index == 0 && _followingList.isEmpty) { // Following tab
        emptyListMessage = 'Takip edilen kimse yok.';
    } else if (_tabController.index == 1 && _followersList.isEmpty) { // Followers tab
        emptyListMessage = 'Hiç takipçi yok.';
    }

    if (users.isEmpty) {
      return Center(child: Text(_searchQuery.isEmpty ? emptyListMessage : 'Sonuç bulunamadı.'));
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(user.profilePhotoUrl),
            onBackgroundImageError: (exception, stackTrace) {
               print("Error loading image for ${user.nickname}: $exception");
               // Optionally show a placeholder or default avatar here
            },
            child: user.profilePhotoUrl.isEmpty ? Icon(Icons.person) : null, // Fallback icon
          ),
          title: Text(user.nickname, style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(user.name),
          trailing: widget.isCurrentUserList // Conditionally show button
              ? IconButton(
                  icon: Icon(Icons.close, color: Colors.red),
                  tooltip: _tabController.index == 0 ? 'Takibi Bırak' : 'Takipçiyi Çıkar',
                  onPressed: () {
                    if (_tabController.index == 0) { // Following tab
                      _unfollowUser(user.id);
                    } else { // Followers tab
                      _removeFollower(user.id);
                    }
                  },
                )
              : null, // No button if not the current user's list
          onTap: () {
            // Prevent navigation to own profile from the list if it's the current user's list
            if (!widget.isCurrentUserList || user.id != _currentUserId) {
               Navigator.push(
                 context,
                 MaterialPageRoute(
                   builder: (context) => KullaniciGosterPage(userId: user.id),
                 ),
               ).then((_) {
                 // Optional: Refresh lists if needed after returning from profile view
                 // _fetchFollowing();
                 // _fetchFollowers();
               });
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine counts based on filtered lists
    int followingCount = _filteredFollowingList.length;
    int followersCount = _filteredFollowersList.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Takip Listesi'), // Or dynamically set based on initial tab?
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight + 56), // TabBar + Search Field height
          child: Column(
            children: [
                TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFD06100), // Keep the indicator orange
                labelColor: Colors.black, // Set selected label color to black for better visibility
                unselectedLabelColor: Colors.grey, // Keep unselected labels grey
                tabs: [
                  Tab(text: 'Takip Edilenler ($followingCount)'), // Show filtered count
                  Tab(text: 'Takipçiler ($followersCount)'), // Show filtered count
                ],
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: Colors.black), // Add this line
                  decoration: InputDecoration(
                  hintText: 'Kullanıcı ara (isim veya kullanıcı adı)...',
                  hintStyle: TextStyle(color: Colors.grey[600]), // Optional: Adjust hint text color if needed
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]), // Optional: Adjust icon color
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
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Following Tab
          _buildUserList(_filteredFollowingList, _isLoadingFollowing),
          // Followers Tab
          _buildUserList(_filteredFollowersList, _isLoadingFollowers),
        ],
      ),
    );
  }
}

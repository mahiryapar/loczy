import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart'; // Assuming video support needed
import 'package:http/http.dart' as http; // For API calls
import 'dart:convert'; // For JSON encoding
import 'package:loczy/config_getter.dart'; // For API URL and token

// Define individual story item
class StoryItem {
  final int id;
  final String mediaUrl;
  // Add other potential fields like mediaType ('image'/'video') if needed

  StoryItem({required this.id, required this.mediaUrl});
}

// Updated Story class
class Story {
  final int userId;
  final String username;
  final String profileImageUrl;
  final List<StoryItem> items; // Changed from mediaUrls to items
  final bool hasUnwatched;

  Story({
    required this.userId,
    required this.username,
    required this.profileImageUrl,
    required this.items, // Updated
    required this.hasUnwatched,
  });
}

class StoryViewPage extends StatefulWidget {
  final Story story;
  final int currentUserId; // Added: Pass current user ID for API call

  const StoryViewPage({
    super.key,
    required this.story,
    required this.currentUserId, // Added
  });

  @override
  State<StoryViewPage> createState() => _StoryViewPageState();
}

class _StoryViewPageState extends State<StoryViewPage> with TickerProviderStateMixin {
  late PageController _pageController;
  // Optional: Animation controller for progress bars
  // late AnimationController _animationController;
  int _currentIndex = 0;
  // Keep track of stories marked watched in this session to avoid redundant API calls
  final Set<int> _sessionWatchedStoryIds = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Mark the initial story as watched when the page loads
    if (widget.story.items.isNotEmpty) {
      _markStoryMediaAsWatched(widget.story.items[_currentIndex].id);
    }

    // Optional: Initialize animation controller for progress bars
    // _animationController = AnimationController(vsync: this);
    // _startStoryTimer(); // Start timer for the first story

     _pageController.addListener(() {
      final newIndex = _pageController.page?.round() ?? 0;
      if (_currentIndex != newIndex && newIndex < widget.story.items.length) {
        setState(() {
          _currentIndex = newIndex;
        });
        // Mark the new story as watched when page changes
        _markStoryMediaAsWatched(widget.story.items[_currentIndex].id);
        // Optional: Reset and start animation for the new story
        // _animationController.reset();
        // _startStoryTimer();
      }
    });
  }

  // Optional: Timer logic
  // void _startStoryTimer() {
  //   _animationController.duration = Duration(seconds: 5); // Example duration
  //   _animationController.forward().whenComplete(() {
  //     _nextStory(); // Go to next story when timer completes
  //   });
  // }

  @override
  void dispose() {
    _pageController.dispose();
    // _animationController.dispose(); // Dispose animation controller
    super.dispose();
  }

  void _nextStory() {
    if (_currentIndex < widget.story.items.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      Navigator.pop(context); // Pop only when on the last story item
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
    // Optional: Could pop here if on the first story and tapping left, or do nothing
  }

  // Function to mark story as watched via API
  Future<void> _markStoryMediaAsWatched(int storyId) async {
    // Avoid calling API if already marked in this session or if storyId is invalid
    if (storyId == 0 || _sessionWatchedStoryIds.contains(storyId)) {
      return;
    }

    print("DEBUG: Marking story $storyId as watched for user ${widget.currentUserId}");

    try {
      _sessionWatchedStoryIds.add(storyId);
      final response = await http.post(
        Uri.parse('${ConfigLoader.apiUrl}/routers/story_watches.php'),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'story_id': storyId,
          'izleyen_id': widget.currentUserId, // Use passed current user ID
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        print("DEBUG: Successfully marked story $storyId as watched on backend: ${response.body} ${response.statusCode}");
      } else {
        print('DEBUG: Failed to mark story $storyId as watched on backend: ${response.statusCode} ${response.body}');
        // Optional: Remove from _sessionWatchedStoryIds if API call fails?
        // _sessionWatchedStoryIds.remove(storyId);
      }
    } catch (e) {
      print('DEBUG: Error marking story $storyId as watched: $e');
      // Optional: Remove from _sessionWatchedStoryIds on error?
      // _sessionWatchedStoryIds.remove(storyId);
    }
  }


  @override
  Widget build(BuildContext context) {
    if (widget.story.items.isEmpty) {
      // Handle case where story has no items (should ideally not happen)
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(child: Text("Hikaye bulunamadı.", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Tapping on right side goes next, left side goes previous
        onTapUp: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx > screenWidth / 2) {
            _nextStory();
          } else {
            _previousStory();
          }
        },
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.story.items.length,
              itemBuilder: (context, index) {
                final item = widget.story.items[index];
                // TODO: Implement actual media display (Image or VideoPlayer)
                // Example using Image:
                return Container(
                   color: Colors.black, // Ensure background is black
                   child: Center(
                     child: Image.network(
                       item.mediaUrl,
                       fit: BoxFit.contain, // Fit media within the screen
                       loadingBuilder: (context, child, progress) {
                         return progress == null ? child : Center(child: CircularProgressIndicator());
                       },
                       errorBuilder: (context, error, stack) {
                         return Center(child: Icon(Icons.error, color: Colors.red, size: 50));
                       },
                     ),
                   ),
                 );
                // Add VideoPlayerWidget logic if media can be video
              },
            ),
            // Top section with progress bars and user info
            Positioned(
              top: MediaQuery.of(context).padding.top + 10, // Adjust for status bar
              left: 10,
              right: 10,
              child: Column(
                children: [
                  // Optional: Progress bars row
                  // Row(
                  //   children: List.generate(widget.story.items.length, (index) {
                  //     return Expanded(
                  //       child: Padding(
                  //         padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  //         child: LinearProgressIndicator(
                  //           value: index == _currentIndex ? _animationController.value : (index < _currentIndex ? 1.0 : 0.0),
                  //           backgroundColor: Colors.grey.withOpacity(0.5),
                  //           valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  //         ),
                  //       ),
                  //     );
                  //   }),
                  // ),
                  SizedBox(height: 8),
                  // User info and close button
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(widget.story.profileImageUrl),
                      ),
                      SizedBox(width: 8),
                      Text(
                        widget.story.username,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

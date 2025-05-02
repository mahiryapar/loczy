import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart'; // Assuming video support needed
import 'package:http/http.dart' as http; // For API calls
import 'dart:convert'; // For JSON encoding
import 'package:loczy/config_getter.dart'; // For API URL and token
import 'kullanici_goster.dart'; // Import KullaniciGosterPage
import 'dart:math'; // Import for clamp
import 'package:timeago/timeago.dart' as timeago; // Import timeago

// Define individual story item
class StoryItem {
  final int id;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final DateTime creationTime; // Add creation time

  StoryItem({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    required this.creationTime, // Add to constructor
  });
}

// Updated Story class
class Story {
  final int userId;
  final String username;
  final String profileImageUrl;
  final List<StoryItem> items; // Changed from mediaUrls to items
  final bool hasUnwatched; // Keep this if needed for initial state, though viewing marks it watched

  Story({
    required this.userId,
    required this.username,
    required this.profileImageUrl,
    required this.items, // Updated
    required this.hasUnwatched,
  });
}

class StoryViewPage extends StatefulWidget {
  // Updated parameters
  final List<Story> allStories;
  final int initialStoryIndex;
  final int currentUserId;

  const StoryViewPage({
    super.key,
    required this.allStories,
    required this.initialStoryIndex,
    required this.currentUserId,
  });

  @override
  State<StoryViewPage> createState() => _StoryViewPageState();
}

class _StoryViewPageState extends State<StoryViewPage> with TickerProviderStateMixin {
  // Removed PageController as we'll manage item index directly
  late AnimationController _animationController;
  VideoPlayerController? _videoController;
  bool _isVideoLoading = false;

  // State variables for current story and item
  late int _currentStoryIndex;
  int _currentItemIndex = 0; // Index of the item within the *visible* items list

  // Filtered list of items for the current story
  List<StoryItem> _currentVisibleItems = [];

  final Set<int> _sessionWatchedStoryIds = {};

  // Default story duration for images
  final Duration _defaultStoryDuration = const Duration(seconds: 5);

  // Getter for the currently active story
  Story get _currentStory => widget.allStories[_currentStoryIndex];
  // Getter for the currently active *visible* story item
  // Updated to use _currentVisibleItems
  StoryItem get _currentItem {
     // Add bounds check for safety
     if (_currentItemIndex >= 0 && _currentItemIndex < _currentVisibleItems.length) {
       return _currentVisibleItems[_currentItemIndex];
     }
     // Handle error case - should ideally not happen if logic is correct
     print("ERROR: _currentItemIndex out of bounds for _currentVisibleItems!");
     // Return a dummy or the first item if possible, or handle error appropriately
     return _currentVisibleItems.isNotEmpty ? _currentVisibleItems[0] : StoryItem(id: 0, mediaUrl: '', mediaType: 'image', creationTime: DateTime.now()); // Placeholder
  }


  @override
  void initState() {
    super.initState();
    // Initialize timeago locale
    timeago.setLocaleMessages('tr', timeago.TrMessages());

    _currentStoryIndex = widget.initialStoryIndex;

    // Validate initial story index
    if (_currentStoryIndex < 0 || _currentStoryIndex >= widget.allStories.length) {
      print("Error: Initial story index out of bounds.");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      _currentStoryIndex = 0; // Avoid crashing initState
      _animationController = AnimationController(vsync: this, duration: _defaultStoryDuration);
      return; // Exit initState early
    }

    // Initialize animation controller first
    _animationController = AnimationController(vsync: this, duration: _defaultStoryDuration);
    _animationController.addListener(() {
      if (mounted) setState(() {});
    });

    // Filter items for the initial story and load the first valid one
    _updateVisibleItemsAndLoad(); // New helper function
  }

  // Helper to filter items and load the first one
  void _updateVisibleItemsAndLoad({bool startFromLast = false}) {
    if (!mounted || _currentStoryIndex < 0 || _currentStoryIndex >= widget.allStories.length) {
       print("DEBUG: _updateVisibleItemsAndLoad - Invalid state, popping.");
       WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) Navigator.pop(context);
       });
       return;
    }

    final story = _currentStory;
    final DateTime twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));

    // Filter items
    _currentVisibleItems = story.items.where((item) => item.creationTime.isAfter(twentyFourHoursAgo)).toList();
    print("DEBUG: Story ${_currentStoryIndex} (${story.username}): Total items: ${story.items.length}, Visible items (last 24h): ${_currentVisibleItems.length}");

    if (_currentVisibleItems.isEmpty) {
      print("DEBUG: Story ${_currentStoryIndex} has no visible items. Trying to navigate or close.");
      // If this was the initial load or navigation resulted in an empty story,
      // try moving next/prev automatically, or close if no more valid stories exist.
      // This logic can become complex, for now, let's just close if it's empty.
      // A more robust solution might try finding the next/prev *valid* story.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context); // Close if current story becomes empty
      });
      return;
    }

    // Set the item index based on navigation direction
    _currentItemIndex = startFromLast ? _currentVisibleItems.length - 1 : 0;
    // Ensure index is valid (e.g., if startFromLast is true but there's only 1 item)
    _currentItemIndex = _currentItemIndex.clamp(0, _currentVisibleItems.length - 1);


    print("DEBUG: Loading item index $_currentItemIndex from visible items for story $_currentStoryIndex");
    // Initialize media for the determined item index
    _initializeAndMarkMedia(); // No need to pass indices, uses state variables
  }


  // Combined initialization and marking - Uses state variables directly
  Future<void> _initializeAndMarkMedia() async {
     // Validate indices based on _currentVisibleItems
     if (!mounted || _currentStoryIndex < 0 || _currentStoryIndex >= widget.allStories.length ||
         _currentItemIndex < 0 || _currentItemIndex >= _currentVisibleItems.length) {
        print("DEBUG: _initializeAndMarkMedia - Invalid state. Story: $_currentStoryIndex, Item: $_currentItemIndex, Visible Count: ${_currentVisibleItems.length}");
        // Maybe try to recover or pop
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
        return;
     }

     final item = _currentItem; // Use getter which accesses _currentVisibleItems

     // Mark as watched first
     if (item.id != 0) {
       await _markStoryMediaAsWatched(item.id);
     }
     // Then initialize media
     await _initializeMedia(item);
  }


  Future<void> _initializeMedia(StoryItem item) async {
    // Dispose previous video controller if exists
    await _videoController?.dispose();
    _videoController = null;
    _isVideoLoading = false; // Reset loading state

    if (!mounted) {
        print("DEBUG: _initializeMedia: Widget not mounted.");
        return;
    }

    print("DEBUG: _initializeMedia: Initializing item ID ${item.id}, type: ${item.mediaType}"); // DEBUG PRINT

    if (item.mediaType == 'video') {
      if (mounted) {
        setState(() { _isVideoLoading = true; });
      }
      _videoController = VideoPlayerController.networkUrl(Uri.parse(item.mediaUrl));
      try {
        await _videoController!.initialize();
        if (!mounted) return; // Check again after async gap
        setState(() { _isVideoLoading = false; });
        await _videoController!.play();
        _startStoryTimer(duration: _videoController!.value.duration);
      } catch (e) {
        print("Error initializing video ID ${item.id}: $e");
        if (!mounted) return;
        setState(() { _isVideoLoading = false; });
        _startStoryTimer(); // Start timer with default duration on error
      }
    } else { // Assume 'image'
      if (mounted && _isVideoLoading) {
          setState(() { _isVideoLoading = false; });
      }
      _startStoryTimer(); // Start timer with default duration for images
    }
  }


  void _startStoryTimer({Duration? duration}) {
    // ... (existing timer logic remains the same) ...
    if (!mounted) return;

    final effectiveDuration = duration ?? _defaultStoryDuration;
    if (effectiveDuration <= Duration.zero) {
      print("DEBUG: Invalid duration ($effectiveDuration), using default.");
      _animationController.duration = _defaultStoryDuration;
    } else {
      _animationController.duration = effectiveDuration;
    }

    _animationController.stop();
    _animationController.reset();
    _animationController.forward().whenCompleteOrCancel(() {
      if (mounted && _animationController.value == 1.0) {
        print("DEBUG: Timer completed naturally for story ${_currentStoryIndex}, item ${_currentItemIndex}. Calling _next.");
        _next(); // Use combined next logic
      } else if (mounted) {
         print("DEBUG: Timer interrupted or cancelled for story ${_currentStoryIndex}, item ${_currentItemIndex} (value: ${_animationController.value}). Not calling _next automatically.");
      }
    });
  }

  @override
  void dispose() {
    _animationController.stop();
    // Removed _pageController.dispose()
    _animationController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // Combined logic for moving next (item or story)
  void _next() {
    if (!mounted) return;
    print("DEBUG: _next called. Current story: $_currentStoryIndex, item: $_currentItemIndex (visible count: ${_currentVisibleItems.length})");

    _stopCurrentMedia(); // Stop timer/video

    // Check if there are more *visible* items in the current story
    if (_currentItemIndex < _currentVisibleItems.length - 1) {
      // Go to the next item in the current story
      setState(() {
        _currentItemIndex++;
      });
      print("DEBUG: Moving to next visible item: $_currentItemIndex in story $_currentStoryIndex");
      _initializeAndMarkMedia(); // Uses state variables
    } else {
      // At the last visible item, check if there's a next story
      if (_currentStoryIndex < widget.allStories.length - 1) {
        // Go to the first item of the next story
        setState(() {
          _currentStoryIndex++;
          // _currentItemIndex will be reset by _updateVisibleItemsAndLoad
        });
         print("DEBUG: Moving to next story: $_currentStoryIndex");
         _updateVisibleItemsAndLoad(); // Filter items for the new story and load first
      } else {
        // Last item of the last story, close the viewer
        print("DEBUG: Last visible item of last story reached. Closing.");
        Navigator.pop(context);
      }
    }
  }

  // Combined logic for moving previous (item or story)
  void _previous() {
    if (!mounted) return;
     print("DEBUG: _previous called. Current story: $_currentStoryIndex, item: $_currentItemIndex (visible count: ${_currentVisibleItems.length})");

    _stopCurrentMedia(); // Stop timer/video

    // Check if there are previous *visible* items in the current story
    if (_currentItemIndex > 0) {
      // Go to the previous item in the current story
      setState(() {
        _currentItemIndex--;
      });
      print("DEBUG: Moving to previous visible item: $_currentItemIndex in story $_currentStoryIndex");
      _initializeAndMarkMedia(); // Re-initialize (marks as watched again, but ok)
    } else {
      // At the first visible item, check if there's a previous story
      if (_currentStoryIndex > 0) {
        // Go to the *last* visible item of the *previous* story
        setState(() {
          _currentStoryIndex--;
           // _currentItemIndex will be set by _updateVisibleItemsAndLoad
        });
        print("DEBUG: Moving to previous story: $_currentStoryIndex");
        _updateVisibleItemsAndLoad(startFromLast: true); // Filter items and load LAST
      } else {
        // First item of the first story, restart it
        print("DEBUG: First visible item of first story. Restarting.");
        _initializeAndMarkMedia(); // Re-initialize first item
      }
    }
  }

  void _stopCurrentMedia() {
     if (!mounted) return;
     _animationController.stop();
     _videoController?.pause();
     print("DEBUG: Stopped media for story $_currentStoryIndex, item $_currentItemIndex");
  }


  // Function to mark story as watched via API
  Future<void> _markStoryMediaAsWatched(int storyItemId) async {
    // Use storyItemId directly
    if (storyItemId == 0 || _sessionWatchedStoryIds.contains(storyItemId)) {
      if (storyItemId == 0) print("DEBUG: Attempted to mark story item with ID 0 as watched. Skipping.");
      return;
    }

    print("DEBUG: Marking story item $storyItemId as watched for user ${widget.currentUserId}");

    try {
      _sessionWatchedStoryIds.add(storyItemId); // Add item ID

      final response = await http.post(
        Uri.parse('${ConfigLoader.apiUrl}/routers/story_watches.php'),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'story_id': storyItemId, // Send the specific item ID
          'izleyen_id': widget.currentUserId,
        }),
      );
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("DEBUG: Successfully marked story item $storyItemId as watched on backend: ${response.statusCode}");
      } else {
        print('DEBUG: Failed to mark story item $storyItemId as watched on backend: ${response.statusCode} ${response.body}');
        // _sessionWatchedStoryIds.remove(storyItemId); // Optional: remove on failure
      }
    } catch (e) {
      print('DEBUG: Error marking story item $storyItemId as watched: $e');
      // _sessionWatchedStoryIds.remove(storyItemId); // Optional: remove on error
    }
  }


  @override
  Widget build(BuildContext context) {
    // Handle cases where the initial story might be invalid or empty after initState adjustments
    // Updated check to use _currentVisibleItems
    if (_currentStoryIndex < 0 || _currentStoryIndex >= widget.allStories.length || _currentVisibleItems.isEmpty) {
      // Don't build the main UI if state is invalid (no visible items)
      print("DEBUG: Build - No visible items for story $_currentStoryIndex. Showing error/loading.");
      return Scaffold(
        backgroundColor: Colors.black,
        // Show loading briefly while potentially navigating away or closing
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // Ensure currentItemIndex is valid for the current *visible* items
    // This check might be redundant if _updateVisibleItemsAndLoad handles it, but good for safety
    if (_currentItemIndex < 0 || _currentItemIndex >= _currentVisibleItems.length) {
       print("WARN: _currentItemIndex ($_currentItemIndex) was out of bounds for _currentVisibleItems (len: ${_currentVisibleItems.length}), resetting to 0.");
       _currentItemIndex = 0; // Reset if invalid
        return Scaffold(
          backgroundColor: Colors.black,
          body: const Center(child: CircularProgressIndicator()), // Show loading briefly
       );
    }


    // Get the current item to access its creation time - Uses the getter which accesses _currentVisibleItems
    final currentItem = _currentItem;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          // Stop animation/video immediately on tap, before deciding direction
          _stopCurrentMedia(); // Use the helper

          final screenWidth = MediaQuery.of(context).size.width;
          print("DEBUG: Tap detected at ${details.globalPosition.dx}");
          if (details.globalPosition.dx > screenWidth / 2) {
            print("DEBUG: Tapped right side, calling _next.");
            _next(); // Use combined next logic
          } else {
            print("DEBUG: Tapped left side, calling _previous.");
            _previous(); // Use combined previous logic
          }
        },
        onLongPressStart: (_) {
           print("DEBUG: Long press start, pausing.");
           _stopCurrentMedia(); // Use the helper
        },
        onLongPressEnd: (_) {
           print("DEBUG: Long press end, resuming.");
           if (!mounted) return;

           // Resume video only if it was paused and is initialized for the current item
           final item = _currentItem; // Use getter
           if (item.mediaType == 'video' &&
               _videoController?.value.isInitialized == true &&
               _videoController?.value.isPlaying == false) {
              _videoController?.play();
           }
           // Resume timer
           if (_animationController.duration != null &&
               _animationController.duration! > Duration.zero &&
               _animationController.value < 1.0) {
               _animationController.forward();
           }
        },
        child: Stack(
          children: [
            // Media Display Area (Uses _currentItem getter)
            Builder( // Use Builder to ensure _currentItem is accessed within build context
              builder: (context) {
                final item = _currentItem; // Get current visible item safely
                Widget mediaWidget;

                if (item.mediaType == 'video') {
                  if (_videoController != null && _videoController!.value.isInitialized && !_isVideoLoading) {
                    mediaWidget = Center( // Center the FittedBox
                      child: FittedBox(
                        fit: BoxFit.cover, // Change fit to cover the screen
                        child: SizedBox( // Let SizedBox fill available space from Center/FittedBox
                          width: _videoController!.value.size.width, // Keep aspect ratio source
                          height: _videoController!.value.size.height,
                          child: VideoPlayer(_videoController!),
                        ),
                      ),
                    );
                  } else {
                    mediaWidget = const Center(child: CircularProgressIndicator());
                  }
                } else { // Image
                  mediaWidget = Center(
                    child: Image.network(
                      item.mediaUrl,
                      fit: BoxFit.contain, // Keep contain for images, or change if needed
                      loadingBuilder: (context, child, progress) {
                        return progress == null ? child : const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stack) {
                        print("Error loading image ID ${item.id}: $error");
                        return const Center(child: Icon(Icons.error, color: Colors.red, size: 50));
                      },
                    ),
                  );
                }
                // Ensure the container fills the space
                return Container(
                  color: Colors.black, // Background for letter/pillar boxing if needed
                  width: double.infinity,
                  height: double.infinity,
                  child: mediaWidget, // Place the media widget (Image or Video)
                );
              }
            ),

            // Top section with progress bars and user info
            Positioned(
              top: MediaQuery.of(context).padding.top + 10, // Adjust for status bar
              left: 10,
              right: 10,
              child: Column(
                children: [
                  // Progress bars row (uses _currentVisibleItems.length)
                  Row(
                    children: List.generate(_currentVisibleItems.length, (index) { // Use length of visible items
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: LinearProgressIndicator(
                            // Logic remains the same, but indices are relative to visible items
                            value: (index == _currentItemIndex
                                ? _animationController.value
                                : (index < _currentItemIndex ? 1.0 : 0.0)).clamp(0.0, 1.0),
                            backgroundColor: Colors.grey.withOpacity(0.5),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 2.0,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  // User info and close button (uses _currentStory and _currentItem)
                  Row(
                    children: [
                      // ... (GestureDetector for profile pic - NO CHANGE) ...
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => KullaniciGosterPage(userId: _currentStory.userId),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 16,
                          backgroundImage: NetworkImage(_currentStory.profileImageUrl),
                          onBackgroundImageError: (e, s) => print("Error loading profile image: $e"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded( // Wrap username and time in Expanded to handle potential overflow
                        child: GestureDetector(
                           // ... (GestureDetector for username/time - NO CHANGE) ...
                           onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => KullaniciGosterPage(userId: _currentStory.userId),
                              ),
                            );
                          },
                          child: Row( // Use Row to place username and time side-by-side
                            children: [
                              Flexible( // Allow username to shrink if needed
                                child: Text(
                                  _currentStory.username,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis, // Handle long usernames
                                ),
                              ),
                              const SizedBox(width: 8), // Space between username and time
                              Text(
                                // Uses currentItem getter which accesses the visible item
                                timeago.format(currentItem.creationTime, locale: 'tr'), // Format time
                                style: const TextStyle(color: Colors.white70, fontSize: 12), // Style for time
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ... (Close button - NO CHANGE) ...
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
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

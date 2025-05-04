import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:loczy/config_getter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:loczy/pages/yorumlar_panel.dart';
import 'package:loczy/pages/post_paylas_panel.dart'; // Import the new share panel

class PostGosterPage extends StatefulWidget {
  final int postId;

  const PostGosterPage({super.key, required this.postId});

  @override
  State<PostGosterPage> createState() => _PostGosterPageState();
}

class _PostGosterPageState extends State<PostGosterPage> {
  bool likechecked = false;
  bool isLiked = false;
  int begeni_sayisi = 0;

  bool saveChecked = false;
  bool isSaved = false;
  
  int paylasilma_sayisi = 0; // Add this to track share count

  Future<Map<String, dynamic>> _fetchPostDetails() async {
    final response = await http.get(
      Uri.parse(
          '${ConfigLoader.apiUrl}/routers/posts.php?id=${widget.postId}'),
      headers: {
        'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      Map<String, dynamic> data = jsonDecode(response.body);
      begeni_sayisi = data['begeni_sayisi'] ?? 0;
      paylasilma_sayisi = data['paylasilma_sayisi'] ?? 0; // Store share count

      SharedPreferences prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId')?.toString() ?? '';

      // --- LIKE STATUS ---
      final likeResponse = await http.get(
        Uri.parse(
            '${ConfigLoader.apiUrl}/routers/post_likes.php?post_id=${widget.postId}&user_id=$userId'),
        headers: {
          'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
          'Content-Type': 'application/json',
        },
      );
      if (likeResponse.statusCode == 200) {
        final likeData = jsonDecode(likeResponse.body);
        final likeStatus = likeData['status'];
        if (!likechecked) {
          setState(() {
            likechecked = true;
            isLiked = (likeStatus == 'liked');
          });
        }
      }

      // --- SAVE STATUS ---
      if (!saveChecked) {
        final saveResponse = await http.get(
          Uri.parse(
              '${ConfigLoader.apiUrl}/routers/saves.php?post_id=${widget.postId}&user_id=$userId'),
          headers: {
            'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
            'Content-Type': 'application/json',
          },
        );
        if (saveResponse.statusCode == 200) {
          final saveData = jsonDecode(saveResponse.body);
          final saveStatus = saveData['status'];
          // print('Save status: $saveStatus'); // Debug print
          setState(() {
            saveChecked = true;
            isSaved = (saveStatus == 'saved');
          });
        } else {
          print('Failed to fetch save status: ${saveResponse.body}');
        }
      }

      // --- FETCH POST CREATOR NICKNAME ---
      final postCreatorId = data['atan_id'];
      if (postCreatorId != null) {
        final userResponse = await http.get(
          Uri.parse('${ConfigLoader.apiUrl}/routers/users.php?id=$postCreatorId'),
          headers: {
            'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
            'Content-Type': 'application/json',
          },
        );
        if (userResponse.statusCode == 200) {
          final userData = jsonDecode(userResponse.body);
          data['creator_nickname'] = userData['nickname'] ?? 'Bilinmeyen Kullanıcı';
        } else {
          print('Failed to fetch user details: ${userResponse.body}');
          data['creator_nickname'] = 'Bilinmeyen Kullanıcı';
        }
      } else {
         data['creator_nickname'] = 'Bilinmeyen Kullanıcı';
      }


      return data;
    } else {
      throw Exception('Failed to load post details');
    }
  }

  // Removed _getNickname function

  Widget _buildPostContent(
      BuildContext context, Map<String, dynamic> postDetails) {
    final postUrl = postDetails['video_foto_url'];
    final isVideo = postUrl.endsWith('.mp4');
    final int portreMi = postDetails['portre_mi'] ?? 0; // Get portre_mi value

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  postDetails['konum'] ?? 'Konum Yok',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${DateTime.parse(postDetails['paylasilma_tarihi']['date']).add(Duration(hours: 3)).toString().split(' ')[0].split('-').reversed.join('-')} ${DateTime.parse(postDetails['paylasilma_tarihi']['date']).add(Duration(hours: 3)).toString().split(' ')[1].substring(0, 5)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Divider(color: const Color(0xFFD06100), thickness: 2, height: 0),
          Stack(
            children: [
              isVideo
                  ? VideoPlayerWidget(url: postUrl, portreMi: portreMi) // Pass portreMi
                  : Image.network(
                      postUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.error, color: Colors.red);
                      },
                    ),
            ],
          ),
          Divider(color: const Color(0xFFD06100), thickness: 2, height: 0),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // LIKE BUTTON
                        IconButton(
                          icon: Icon(
                            Icons.thumb_up,
                            color: isLiked ? Colors.red : Colors.grey,
                          ),
                          onPressed: () async {
                            final headers = {
                              'Authorization':
                                  'Bearer ${ConfigLoader.bearerToken}',
                              'Content-Type': 'application/json',
                            };
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            final uid = prefs.getInt('userId');

                            if (isLiked) {
                              final url = Uri.parse(
                                  '${ConfigLoader.apiUrl}/routers/post_likes.php?post_id=${widget.postId}&user_id=$uid');
                              final resp = await http.delete(url,
                                  headers: headers);
                              if (resp.statusCode == 200) {
                                setState(() {
                                  isLiked = false;
                                  begeni_sayisi--;
                                });
                              }
                            } else {
                              final url = Uri.parse(
                                  '${ConfigLoader.apiUrl}/routers/post_likes.php');
                              final resp = await http.post(url,
                                  headers: headers,
                                  body: jsonEncode({
                                    'post_id': widget.postId,
                                    'begenen_id': uid
                                  }));
                              if (resp.statusCode == 200) {
                                setState(() {
                                  isLiked = true;
                                  begeni_sayisi++;
                                });
                              }
                            }
                          },
                        ),
                        SizedBox(width: 8),
                        Text('$begeni_sayisi'),
                        SizedBox(width: 16),
                        IconButton(
                          icon: Icon(Icons.comment, color: Colors.grey),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20)),
                              ),
                              builder: (context) =>
                                  YorumlarPanel(postId: widget.postId),
                            );
                          },
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${postDetails['yorum_sayisi'] ?? 0}',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(width: 16),
                        // SHARE BUTTON - Updated with functionality
                        IconButton(
                          icon: Icon(Icons.send, color: Colors.grey),
                          onPressed: () {
                            _showSharePanel(postDetails);
                          },
                        ),
                        SizedBox(width: 8),
                        Text(
                          '$paylasilma_sayisi',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // SAVE BUTTON
                        IconButton(
                          icon: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            color: isSaved ? const Color(0xFFD06100) : Colors.grey,
                          ),
                          onPressed: () async {
                            final headers = {
                              'Authorization':
                                  'Bearer ${ConfigLoader.bearerToken}',
                              'Content-Type': 'application/json',
                            };
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            final uid = prefs.getInt('userId');

                            if (isSaved) {
                              // unsave
                              final url = Uri.parse(
                                  '${ConfigLoader.apiUrl}/routers/saves.php?post_id=${widget.postId}&user_id=$uid');
                              final resp =
                                  await http.delete(url, headers: headers);
                              if (resp.statusCode == 200) {
                                setState(() {
                                  isSaved = false;
                                });
                              }
                            } else {
                              // save
                              final url = Uri.parse(
                                  '${ConfigLoader.apiUrl}/routers/saves.php');
                              final resp = await http.post(url,
                                  headers: headers,
                                  body: jsonEncode({
                                    'post_id': widget.postId,
                                    'kaydeden_id': uid
                                  }));
                              if (resp.statusCode == 200) {
                                setState(() {
                                  isSaved = true;
                                });
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  postDetails['aciklama'] ?? 'Açıklama Yok',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // New method to show the share panel
  void _showSharePanel(Map<String, dynamic> postDetails) {
    final String mediaUrl = postDetails['video_foto_url'] ?? '';
    final bool isVideo = mediaUrl.endsWith('.mp4');
    
    // Use thumbnail URL if available, otherwise use the media URL itself
    final String thumbnailUrl = postDetails['thumbnail_url'] ?? mediaUrl;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostPaylasPanel(
        postId: widget.postId,
        postImageUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl,
        postText: postDetails['aciklama'] ?? '',
        isVideo: isVideo,
      ),
    ).then((shared) {
      if (shared == true) {
        // Refresh post details to get updated share count
        setState(() {
          paylasilma_sayisi++;
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Map<String, dynamic>>(
          future: _fetchPostDetails(), // Fetch details once
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text('Yükleniyor...');
            } else if (snapshot.hasError) {
              return Text('Hata');
            } else if (snapshot.hasData) {
              // Use the fetched nickname
              return Text('@'+snapshot.data!['creator_nickname'] ?? 'Kullanıcı');
            } else {
              return Text('Kullanıcı'); // Default title
            }
          },
        ),
        backgroundColor: const Color(0xFFD06100),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchPostDetails(), // Use the same future
        builder: (context, postSn) {
          if (postSn.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (postSn.hasError) {
            // Display error in the body, AppBar shows 'Hata'
            return Center(child: Text('Error: ${postSn.error}'));
          } else if (!postSn.hasData || postSn.data == null) {
             // Handle case where data is null or empty
            return Center(child: Text('Post bulunamadı.'));
          } else {
            // Pass the fetched data to build the content
            return _buildPostContent(context, postSn.data!);
          }
        },
      ),
    );
  }
}
class VideoPlayerWidget extends StatefulWidget {
  final String url;
  final int portreMi; // Add portreMi parameter

  const VideoPlayerWidget({super.key, required this.url, required this.portreMi}); // Update constructor

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _controller.play();
            });
            _controller.setLooping(true);
          }
        });
      _controller.addListener(() {
        if (_controller.value.hasError) {
          debugPrint(
              'Video oynatılamadı: ${_controller.value.errorDescription}');
        }
      });
    } catch (e) {
      debugPrint('Video yüklenirken hata oluştu: $e');
    }
  }

  @override
  void dispose() {
    if (_controller.value.isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isInitialized = _controller.value.isInitialized;
    final double screenWidth = MediaQuery.of(context).size.width.toDouble();

    if (!isInitialized) {
      return Container(
        width: screenWidth,
        height: screenWidth * (9.0 / 16.0), // Default 16:9 aspect ratio
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // --- Get Reported Video Size ---
    double reportedWidth = _controller.value.size.width;
    double reportedHeight = _controller.value.size.height;

    // --- Determine Correct Dimensions based on portreMi ---
    double actualWidth;
    double actualHeight;

    if (widget.portreMi == 1) {
      // Portrait video, dimensions might be swapped
      actualWidth = reportedHeight; // Assume height is the actual width
      actualHeight = reportedWidth; // Assume width is the actual height
      print('Portrait video (portre_mi=1): Using swapped dimensions W=$actualWidth, H=$actualHeight');
    } else {
      // Landscape video or unknown, use reported dimensions
      actualWidth = reportedWidth;
      actualHeight = reportedHeight;
       print('Landscape/Other video (portre_mi=${widget.portreMi}): Using reported dimensions W=$actualWidth, H=$actualHeight');
    }


    // --- Calculate Aspect Ratio ---
    double correctAspectRatio;
    // Ensure we don't divide by zero
    if (actualHeight > 0 && actualWidth > 0) {
       correctAspectRatio = actualWidth / actualHeight;
    } else {
      correctAspectRatio = 16.0 / 9.0; // Default if size is invalid
      print('Warning: Invalid video dimensions reported. Using default AR.');
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight, // Keep alignment for button
          children: [
            // Wrap AspectRatio in a Center widget
            Center(
              child: AspectRatio(
                aspectRatio: correctAspectRatio,
                child: VideoPlayer(_controller), // Video player fills the AspectRatio
              ),
            ),
            // Volume button positioned within the Stack
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _isMuted = !_isMuted;
                    _controller.setVolume(_isMuted ? 0 : 1);
                  });
                },
              ),
            ),
          ],
        ),
        // Progress indicator below the video area
        VideoProgressIndicator(
          _controller,
          allowScrubbing: true,
          colors: VideoProgressColors(
            playedColor: const Color(0xFFD06100),
            bufferedColor: Colors.grey,
            backgroundColor: Colors.black12,
          ),
        ),
      ],
    );
  }
}

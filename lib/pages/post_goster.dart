import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:loczy/config_getter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

class PostGosterPage extends StatelessWidget {
  final int postId;

  const PostGosterPage({super.key, required this.postId});

  Future<Map<String, dynamic>> _fetchPostDetails() async {
    final response = await http.get(
      Uri.parse(
          '${ConfigLoader.apiUrl}/routers/posts.php?id=${postId.toString()}'),
      headers: {
        'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      Map<String, dynamic> data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('Failed to load post details');
    }
  }

  Future<String> _getNickname() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return '@${prefs.getString('userNickname')}';
  }

  Widget _buildPostContent(
      BuildContext context, Map<String, dynamic> postDetails) {
    final postUrl = postDetails['video_foto_url'];
    final isVideo = postUrl.endsWith('.mp4');

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
                ? VideoPlayerWidget(url: postUrl)
                : Image.network(
                  postUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.error, color: Colors.red);
                  },
                ),
              Positioned.fill(
              child: IgnorePointer(
                child: Container(
                color: Colors.transparent,
                ),
              ),
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
                        Icon(Icons.thumb_up, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          '${postDetails['begeni_sayisi'] ?? 0}',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.comment, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          '${postDetails['yorum_sayisi'] ?? 0}',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.send, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          '${postDetails['paylasilma_sayisi'] ?? 0}',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.attach_file, color: Colors.grey),
                          onPressed: () {
                            // Save functionality here
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getNickname(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Yükleniyor...'),
              backgroundColor: const Color(0xFFD06100),
            ),
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Hata'),
              backgroundColor: const Color(0xFFD06100),
            ),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        } else {
          final nickname = snapshot.data!;
          return Scaffold(
            appBar: AppBar(
              title: Text(nickname),
              backgroundColor: const Color(0xFFD06100),
            ),
            body: FutureBuilder<Map<String, dynamic>>(
              future: _fetchPostDetails(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData) {
                  return Center(child: Text('Post bulunamadı.'));
                } else {
                  final postDetails = snapshot.data!;
                  return _buildPostContent(context, postDetails);
                }
              },
            ),
          );
        }
      },
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String url;

  const VideoPlayerWidget({super.key, required this.url});

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

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
          debugPrint('Video oynatılamadı: ${_controller.value.errorDescription}');
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
    double screenWidth = MediaQuery.of(context).size.width; // Ekran genişliği
    debugPrint("Video Aspect Ratio: ${_controller.value.aspectRatio}");
    return _controller.value.isInitialized
        ? Container(
          width: screenWidth,
          height: screenWidth / _controller.value.aspectRatio,
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller)))
        : const Center(child: CircularProgressIndicator());
  }
}

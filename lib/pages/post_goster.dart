import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:loczy/config_getter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PostGosterPage extends StatelessWidget {
  final int postId;

  const PostGosterPage({super.key, required this.postId});

  Future<Map<String, dynamic>> _fetchPostDetails() async {
    final response = await http.get(
      Uri.parse('${ConfigLoader.apiUrl}/routers/posts.php?id=${postId.toString()}'),
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

  Future<http.Response> _fetchPostFile(String postUrl) async {
    final response = await http.get(
      Uri.parse('${ConfigLoader.apiUrl}/get_files.php?fileurl=$postUrl'),
      headers: {
        'Authorization': 'Bearer ${ConfigLoader.bearerToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return response;
    } else {
      throw Exception('Failed to load post file');
    }
  }

  Future<String> _getNickname() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return '@${prefs.getString('userNickname')}' ?? 'Kullanıcı';
  }

  Widget _buildPostContent(BuildContext context, Map<String, dynamic> postDetails, http.Response fileResponse) {
    final postUrl = postDetails['video_foto_url'];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                Text(
                  postDetails['konum'] ?? 'Konum Yok',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${DateTime.parse(postDetails['paylasilma_tarihi']['date'])
                  .add(Duration(hours: 3))
                  .toString()
                  .split(' ')[0]
                  .split('-')
                  .reversed
                  .join('-')} ${DateTime.parse(postDetails['paylasilma_tarihi']['date'])
                  .add(Duration(hours: 3))
                  .toString()
                  .split(' ')[1].substring(0, 5)}', 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Divider(color: const Color(0xFFD06100), thickness: 2, height: 0),
          Image.memory(
            fileResponse.bodyBytes,
            fit: BoxFit.contain,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.error, color: Colors.red);
            },
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
                  final postUrl = postDetails['video_foto_url'];
                  return FutureBuilder<http.Response>(
                    future: _fetchPostFile(postUrl),
                    builder: (context, fileSnapshot) {
                      if (fileSnapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (fileSnapshot.hasError) {
                        return Center(child: Text('Error: ${fileSnapshot.error}'));
                      } else if (!fileSnapshot.hasData) {
                        return Center(child: Text('Dosya bulunamadı.'));
                      } else {
                        return _buildPostContent(context, postDetails, fileSnapshot.data!);
                      }
                    },
                  );
                }
              },
            ),
          );
        }
      },
    );
  }
}
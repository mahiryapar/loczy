import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:loczy/config_getter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'kullanici_goster.dart'; // Import the KullaniciGosterPage

class Yorum {
  final int id;
  final int isReply;
  final int yazanId;
  final String username;
  final String comment;
  final String profileImageUrl;
  final int begeniSayisi;
  final DateTime yazmaTarihi;
  final bool isLiked;

  Yorum({
    required this.id,
    required this.isReply,
    required this.yazanId,
    required this.username,
    required this.comment,
    required this.profileImageUrl,
    required this.begeniSayisi,
    required this.yazmaTarihi,
    required this.isLiked,
  });

  factory Yorum.fromJson(Map<String, dynamic> json, Map<String, dynamic> userJson, bool liked) {
    return Yorum(
      id: json['id'],
      isReply: json['is_reply'],
      yazanId: json['yazan_id'],
      username: userJson['nickname'],
      comment: json['yorum'],
      profileImageUrl: userJson['profil_fotosu_url'],
      begeniSayisi: json['begeni_sayisi'],
      yazmaTarihi: DateTime.parse(json['yazma_tarihi']['date']),
      isLiked: liked,
    );
  }
}

class YorumlarPanel extends StatefulWidget {
  final int postId;
  const YorumlarPanel({super.key, required this.postId});

  @override
  State<YorumlarPanel> createState() => _YorumlarPanelState();
}

class _YorumlarPanelState extends State<YorumlarPanel> {
  late Future<List<Yorum>> _yorumlarFuture;
  final String bearerToken = ConfigLoader.bearerToken;
  final String apiurl = ConfigLoader.apiUrl;
  int? replyingTo;
  String? replyingToUsername;
  final TextEditingController _yorumController = TextEditingController();

  int? currentUserId;
  int? postOwnerId;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('tr', timeago.TrMessages());
    _loadUserAndOwner();
    _yorumlarFuture = fetchYorumlar();
  }

  Future<void> _loadUserAndOwner() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('userId') ?? 0;
    final resp = await http.get(
      Uri.parse('$apiurl/routers/posts.php?id=${widget.postId}'),
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Content-Type': 'application/json',
      },
    );
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      setState(() {
        currentUserId = uid;
        postOwnerId = data['atan_id'];
      });
    } else {
      setState(() {
        currentUserId = uid;
        postOwnerId = null;
      });
    }
  }

  Future<List<Yorum>> fetchYorumlar() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('userId') ?? 0;

    final response = await http.get(
      Uri.parse('$apiurl/routers/comments.php?post_id=${widget.postId}'),
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Yorumlar yüklenemedi');
    }
    final List<dynamic> yorumlarJson = json.decode(response.body);
    List<Yorum> yorumlar = [];
    for (var yorumJson in yorumlarJson) {
      final yazanId = yorumJson['yazan_id'];
      final userResp = await http.get(
        Uri.parse('$apiurl/routers/users.php?id=$yazanId'),
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );
      if (userResp.statusCode == 200) {
        final userJson = json.decode(userResp.body);
        final likeResp = await http.get(
          Uri.parse('$apiurl/routers/comment_likes.php?yorum_id=${yorumJson['id']}&begenen_id=$uid'),
          headers: {
            'Authorization': 'Bearer $bearerToken',
            'Content-Type': 'application/json',
          },
        );
        bool liked = false;
        if (likeResp.statusCode == 200) {
          final m = json.decode(likeResp.body);
          liked = m['liked'] ?? false;
        }
        yorumlar.add(Yorum.fromJson(yorumJson, userJson, liked));
      }
    }
    return yorumlar;
  }

  Future<void> postYorum(String comment, int userId) async {
    final response = await http.post(
      Uri.parse('$apiurl/routers/comments.php'),
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'post_id': widget.postId,
        'yazan_id': userId,
        'yorum': comment,
        'is_reply': replyingTo ?? 0,
      }),
    );
    if (response.statusCode == 200) {
      setState(() {
        replyingTo = null;
        replyingToUsername = null;
        _yorumlarFuture = fetchYorumlar();
      });
    } else {
      throw Exception('Yorum gönderilemedi');
    }
  }

  Future<void> deleteComment(int commentId) async {
    final resp = await http.delete(
      Uri.parse('$apiurl/routers/comments.php?id=$commentId'),
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Content-Type': 'application/json',
      },
    );
    if (resp.statusCode == 200) {
      setState(() {
        _yorumlarFuture = fetchYorumlar();
      });
    }
  }

  @override
  void dispose() {
    _yorumController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return MediaQuery.removeViewInsets(
          removeBottom: false,
          context: context,
          child: FutureBuilder<List<Yorum>>(
            future: _yorumlarFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return const Center(child: Text('Yorumlar yüklenirken bir hata oluştu'));
              }

              final yorumlar = snapshot.data!;
              final anaYorumlar = yorumlar.where((y) => y.isReply == 0).toList();
              final yanitlar = yorumlar.where((y) => y.isReply != 0).toList();

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(height: 4, width: 50, color: Colors.grey),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: anaYorumlar.length,
                        itemBuilder: (context, i) {
                          final y = anaYorumlar[i];
                          final alt = yanitlar.where((a) => a.isReply == y.id).toList();
                          bool showReplies = false;

                          return StatefulBuilder(
                            builder: (ctx, setLocal) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () => Navigator.push( // Navigate to KullaniciGosterPage
                                        context,
                                        MaterialPageRoute(builder: (context) => KullaniciGosterPage(userId: y.yazanId)),
                                      ),
                                      child: CircleAvatar(
                                        backgroundImage: NetworkImage(y.profileImageUrl),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              GestureDetector(
                                                onTap: () => Navigator.push( // Navigate to KullaniciGosterPage
                                                  context,
                                                  MaterialPageRoute(builder: (context) => KullaniciGosterPage(userId: y.yazanId)),
                                                ),
                                                child: Text(y.username),
                                              ),
                                              Text(
                                                timeago.format(y.yazmaTarihi, locale: 'tr'),
                                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                          Text(y.comment),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  TextButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        replyingTo = y.id;
                                                        replyingToUsername = y.username;
                                                      });
                                                    },
                                                    child: const Text('Yanıtla', style: TextStyle(fontSize: 12)),
                                                  ),
                                                  if (alt.isNotEmpty)
                                                    TextButton(
                                                      onPressed: () => setLocal(() => showReplies = !showReplies),
                                                      child: Text(
                                                        showReplies ? 'Yanıtları gizle' : 'Yanıtları gör',
                                                        style: const TextStyle(fontSize: 12),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  if ((currentUserId != null) &&
                                                      (currentUserId == postOwnerId || currentUserId == y.yazanId))
                                                    IconButton(
                                                      icon: const Icon(Icons.delete, size: 16),
                                                      onPressed: () => deleteComment(y.id),
                                                    ),
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.thumb_up,
                                                      size: 20,
                                                      color: y.isLiked ? Colors.red : Colors.grey,
                                                    ),
                                                    onPressed: () async {
                                                      final prefs = await SharedPreferences.getInstance();
                                                      final uid = prefs.getInt('userId') ?? 0;
                                                      final headers = {
                                                        'Authorization': 'Bearer $bearerToken',
                                                        'Content-Type': 'application/json',
                                                      };
                                                      if (y.isLiked) {
                                                        await http.delete(
                                                          Uri.parse('$apiurl/routers/comment_likes.php?yorum_id=${y.id}&begenen_id=$uid'),
                                                          headers: headers,
                                                        );
                                                      } else {
                                                        await http.post(
                                                          Uri.parse('$apiurl/routers/comment_likes.php'),
                                                          headers: headers,
                                                          body: json.encode({
                                                            'yorum_id': y.id,
                                                            'begenen_id': uid,
                                                          }),
                                                        );
                                                      }
                                                      setState(() {
                                                        _yorumlarFuture = fetchYorumlar();
                                                      });
                                                    },
                                                  ),
                                                  Text(y.begeniSayisi.toString()),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (showReplies)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 40, top: 8),
                                    child: Column(
                                      children: alt.map((r) {
                                        return Column(
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                GestureDetector(
                                                  onTap: () => Navigator.push( // Navigate to KullaniciGosterPage
                                                    context,
                                                    MaterialPageRoute(builder: (context) => KullaniciGosterPage(userId: r.yazanId)),
                                                  ),
                                                  child: CircleAvatar(
                                                    radius: 14,
                                                    backgroundImage: NetworkImage(r.profileImageUrl),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          GestureDetector(
                                                            onTap: () => Navigator.push( // Navigate to KullaniciGosterPage
                                                              context,
                                                              MaterialPageRoute(builder: (context) => KullaniciGosterPage(userId: r.yazanId)),
                                                            ),
                                                            child: Text(r.username, style: const TextStyle(fontSize: 12)),
                                                          ),
                                                          Text(
                                                            timeago.format(r.yazmaTarihi, locale: 'tr'),
                                                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                          ),
                                                        ],
                                                      ),
                                                      Text(r.comment),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.end,
                                                        children: [
                                                          if ((currentUserId != null) &&
                                                              (currentUserId == postOwnerId || currentUserId == r.yazanId))
                                                            IconButton(
                                                              icon: const Icon(Icons.delete, size: 14),
                                                              onPressed: () => deleteComment(r.id),
                                                            ),
                                                          IconButton(
                                                            icon: Icon(
                                                              Icons.thumb_up,
                                                              size: 16,
                                                              color: r.isLiked ? Colors.red : Colors.grey,
                                                            ),
                                                            onPressed: () async {
                                                              final prefs = await SharedPreferences.getInstance();
                                                              final uid = prefs.getInt('userId') ?? 0;
                                                              final headers = {
                                                                'Authorization': 'Bearer $bearerToken',
                                                                'Content-Type': 'application/json',
                                                              };
                                                              if (r.isLiked) {
                                                                await http.delete(
                                                                  Uri.parse('$apiurl/routers/comment_likes.php?comment_id=${r.id}&user_id=$uid'),
                                                                  headers: headers,
                                                                );
                                                              } else {
                                                                await http.post(
                                                                  Uri.parse('$apiurl/routers/comment_likes.php'),
                                                                  headers: headers,
                                                                  body: json.encode({
                                                                    'comment_id': r.id,
                                                                    'begenen_id': uid,
                                                                  }),
                                                                );
                                                              }
                                                              setState(() {
                                                                _yorumlarFuture = fetchYorumlar();
                                                              });
                                                            },
                                                          ),
                                                          Text(r.begeniSayisi.toString(), style: const TextStyle(fontSize: 12)),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    AnimatedPadding(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (replyingToUsername != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Text('$replyingToUsername kişisine yanıt veriyorsunuz'),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setState(() {
                                      replyingTo = null;
                                      replyingToUsername = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _yorumController,
                                decoration: InputDecoration(
                                  hintText: "Yorum yaz...",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                if (_yorumController.text.isEmpty) return;
                                final prefs = await SharedPreferences.getInstance();
                                final userId = prefs.getInt('userId') ?? 0;
                                try {
                                  await postYorum(_yorumController.text, userId);
                                  _yorumController.clear();
                                } catch (_) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Yorum gönderilemedi')),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD06100),
                                foregroundColor: const Color(0xFFF2E9E9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text("Gönder"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
  }
}
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:loczy/config_getter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:timeago/timeago.dart' as timeago;

class Yorum {
  final int id;
  final int isReply;
  final int yazanId;
  final String username;
  final String comment;
  final String profileImageUrl;
  final int begeniSayisi;
  final DateTime yazmaTarihi;

  Yorum({
    required this.id,
    required this.isReply,
    required this.yazanId,
    required this.username,
    required this.comment,
    required this.profileImageUrl,
    required this.begeniSayisi,
    required this.yazmaTarihi,
  });

  factory Yorum.fromJson(Map<String, dynamic> json, Map<String, dynamic> userJson) {
    return Yorum(
      id: json['id'],
      isReply: json['is_reply'],
      yazanId: json['yazan_id'],
      username: userJson['nickname'],
      comment: json['yorum'],
      profileImageUrl: userJson['profil_fotosu_url'],
      begeniSayisi: json['begeni_sayisi'],
      yazmaTarihi: DateTime.parse(json['yazma_tarihi']['date']),
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
  final String bearerToken = ConfigLoader.bearerToken;
  final String apiurl = ConfigLoader.apiUrl;
  int? replyingTo;
  String? replyingToUsername;

  @override
  void initState() {
    timeago.setLocaleMessages('tr', timeago.TrMessages());
    super.initState();
  }

  Future<List<Yorum>> fetchYorumlar() async {
    final response = await http.get(
      Uri.parse('$apiurl/routers/comments.php?post_id=${widget.postId}'),
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> yorumlarJson = json.decode(response.body);

      List<Yorum> yorumlar = [];
      for (var yorumJson in yorumlarJson) {
        final yazanId = yorumJson['yazan_id'];
        final userResponse = await http.get(
          Uri.parse('$apiurl/routers/users.php?id=$yazanId'),
          headers: {
            'Authorization': 'Bearer $bearerToken',
            'Content-Type': 'application/json',
          },
        );

        if (userResponse.statusCode == 200) {
          final userJson = json.decode(userResponse.body);
          yorumlar.add(Yorum.fromJson(yorumJson, userJson));
        }
      }

      return yorumlar;
    } else {
      throw Exception('Yorumlar yüklenemedi');
    }
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
      });
    } else {
      throw Exception('Yorum gönderilemedi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController yorumController = TextEditingController();

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return FutureBuilder<List<Yorum>>(
          future: fetchYorumlar(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Yorumlar yüklenirken bir hata oluştu'));
            }

            final yorumlar = snapshot.data ?? [];
            final anaYorumlar = yorumlar.where((y) => y.isReply == 0).toList();
            final yanitlar = yorumlar.where((y) => y.isReply != 0).toList();

            return Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(height: 4, width: 50, color: Colors.grey),
                  SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: anaYorumlar.length,
                      itemBuilder: (context, index) {
                        final yorum = anaYorumlar[index];
                        final altYanitlar = yanitlar.where((y) => y.isReply == yorum.id).toList();
                        bool yanitlarGorunur = false;

                        return StatefulBuilder(
                          builder: (context, setStateLocal) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushNamed(context, '/kullanici_goruntule', arguments: yorum.yazanId);
                                    },
                                    child: CircleAvatar(
                                      backgroundImage: NetworkImage(yorum.profileImageUrl),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                Navigator.pushNamed(context, '/kullanici_goruntule', arguments: yorum.yazanId);
                                              },
                                              child: Text(yorum.username),
                                            ),
                                            Text(
                                              timeago.format(yorum.yazmaTarihi, locale: 'tr'),
                                              style: TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        Text(yorum.comment),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                TextButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      replyingTo = yorum.id;
                                                      replyingToUsername = yorum.username;
                                                    });
                                                  },
                                                  child: Text('Yanıtla', style: TextStyle(fontSize: 12)),
                                                ),
                                                if (altYanitlar.isNotEmpty)
                                                  TextButton(
                                                    onPressed: () {
                                                      setStateLocal(() => yanitlarGorunur = !yanitlarGorunur);
                                                    },
                                                    child: Text(
                                                      yanitlarGorunur ? 'Yanıtları gizle' : 'Yanıtları gör',
                                                      style: TextStyle(fontSize: 12),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: Icon(Icons.thumb_up, size: 20),
                                                  onPressed: () {},
                                                ),
                                                Text(yorum.begeniSayisi.toString()),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                              if (yanitlarGorunur)
                                Padding(
                                  padding: const EdgeInsets.only(left: 40.0),
                                  child: Column(
                                    children: altYanitlar.map((yanit) => Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.pushNamed(context, '/kullanici_goruntule', arguments: yanit.yazanId);
                                          },
                                          child: CircleAvatar(
                                            radius: 14,
                                            backgroundImage: NetworkImage(yanit.profileImageUrl),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  GestureDetector(
                                                    onTap: () {
                                                      Navigator.pushNamed(context, '/kullanici_goruntule', arguments: yanit.yazanId);
                                                    },
                                                    child: Text(yanit.username, style: TextStyle(fontSize: 12)),
                                                  ),
                                                  Text(
                                                    timeago.format(yanit.yazmaTarihi, locale: 'tr'),
                                                    style: TextStyle(fontSize: 10, color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                              Text(yanit.comment),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(Icons.thumb_up, size: 16),
                                                    onPressed: () {},
                                                  ),
                                                  Text(yanit.begeniSayisi.toString(), style: TextStyle(fontSize: 12)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )).toList(),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Divider(),
                  if (replyingToUsername != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        children: [
                          Text('${replyingToUsername!} kişisine yanıt veriyorsunuz'),
                          Spacer(),
                          IconButton(
                            icon: Icon(Icons.close),
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
                          controller: yorumController,
                          decoration: InputDecoration(
                            hintText: "Yorum yaz...",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (yorumController.text.isNotEmpty) {
                            SharedPreferences prefs = await SharedPreferences.getInstance();
                            final userId = await prefs.getInt('userId') ?? 0;
                            try {
                              await postYorum(yorumController.text, userId);
                              yorumController.clear();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Yorum gönderilemedi')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD06100),
                          foregroundColor: const Color(0xFFF2E9E9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text("Gönder"),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:loczy/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ayarlar.dart'; // Ayarlar sayfasını import ediyoruz

class ProfilePage extends StatefulWidget {
  final Function logout;

  ProfilePage({Key? key, required this.logout}) : super(key: key);
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  String _name = '';
  int _following = 0;
  int _followers = 0;
  String _pp_path = '';
  String _bio = '';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = (prefs.getString('user_isim') ?? 'Null') +
          ' ' +
          (prefs.getString('user_soyisim') ?? 'Null');
      _following = prefs.getInt('user_takip_edilenler') ?? 0;
      _followers = prefs.getInt('user_takipci') ?? 0;
      _bio = prefs.getString('bio') ?? 'Biyografi';
      _pp_path = prefs.getString('user_profile_photo_path') ?? '';
      _isLoading = false;
    });
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name,
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                Text('Takip', style: TextStyle(fontSize: 16)),
                                Text('$_following',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            SizedBox(width: 40),
                            Column(
                              children: [
                                Text('Takipçi', style: TextStyle(fontSize: 16)),
                                Text('$_followers',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    Spacer(),
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: FileImage(File(_pp_path)), // Profil fotoğrafı
                    ),
                  ],
                ),
                SizedBox(height: 8),
                SizedBox(height: 8),
                Text(_bio, style: TextStyle(fontSize: 16)),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD06100),
                          foregroundColor: const Color(0xFFF2E9E9),
                          padding: EdgeInsets.symmetric(
                              horizontal: 30, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Profilim'),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD06100),
                          foregroundColor: const Color(0xFFF2E9E9),
                          padding: EdgeInsets.symmetric(
                              horizontal: 30, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Konumlarım'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsGrid() {
    return FutureBuilder(
      future: Future.delayed(Duration(seconds: 2)), // Simulate network delay
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else {
          return GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: 20, // Yüklenen post sayısı
            itemBuilder: (context, index) {
              return Container(
                color: Colors.grey[300],
                child: Center(child: Text('Post ${index + 1}')),
              );
            },
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(
                    top: 60.0), // Sayfayı üstten marginleme
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    Divider(
                      color: const Color(0xFFD06100),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildPostsGrid(),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AyarlarPage(logout: widget.logout,)),
          );
        },
        backgroundColor: const Color(0xFFD06100),
        child: Icon(Icons.settings),
      ),
    );
  }
}

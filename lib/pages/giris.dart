import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:loczy/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:loczy/config_getter.dart';
import 'package:loczy/pages/kaydol.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class KaydolGiris extends StatefulWidget {
  final Function(bool) onLoginSuccess;

  const KaydolGiris({Key? key, required this.onLoginSuccess}) : super(key: key);
  @override
  _KaydolGirisState createState() => _KaydolGirisState();
}

class _KaydolGirisState extends State<KaydolGiris> {
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final String apiUrl = await ConfigLoader.apiUrl;
      final String bearerToken = await ConfigLoader.bearerToken;

      // Şifreyi Base64 ile hashle
      String hashedPassword = base64Encode(utf8.encode(passwordController.text));

      final response = await http.get(
        Uri.parse('$apiUrl/routers/users.php?nickname=${nicknameController.text}&password=$hashedPassword'),
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] != 'error') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('userId', responseData['id']);
          await prefs.setString('userNickname', nicknameController.text);
          await prefs.setString('user_isim', responseData['isim']);
          await prefs.setString('user_soyisim', responseData['soyisim']);
          await prefs.setString('user_mail', responseData['mail']);
          await prefs.setString('user_number', responseData['number']);
          await prefs.setString('user_ev_konum', responseData['ev_konum']);
          await prefs.setString('user_hesap_turu', responseData['hesap_turu']);
          await prefs.setString('user_pp_url', responseData['profil_fotosu_url']);
          await prefs.setInt('user_takipci', responseData['takipci']);
          await prefs.setInt('user_takip_edilenler', responseData['takip_edilenler']);
          final profilePhotoResponse = await http.get(
            Uri.parse('$apiUrl/get_files.php?fileurl=${(responseData['profil_fotosu_url'])}'), headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        });
            if (profilePhotoResponse.statusCode == 200) {
              final byteData = profilePhotoResponse.bodyBytes;
              final fileName = responseData['profil_fotosu_url'].split('/').last;
              final directory = await getApplicationDocumentsDirectory();
              final filePath = '${directory.path}/$fileName';
              final file = File(filePath);
              await file.writeAsBytes(byteData);
              await prefs.setString('user_profile_photo_path', filePath);
            }

          widget.onLoginSuccess(true);
        } else {
          setState(() {
            _errorMessage = responseData['message'] ?? 'Giriş başarısız!';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Sunucu hatası, lütfen tekrar deneyin!';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Bağlantı yok, bağlantınızı kontrol ediniz!'+e.toString();
      });
    }
  }

  void _showRegisterPage() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => KaydolPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              margin: EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: const Color(0xFFD06100),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                  color: Theme.of(context).extension<ShadowTheme>()!.shadowColor,
                  blurRadius: 10,
                  spreadRadius: 2,
                  )
                ],
                ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Giriş Yap', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 20),
                  TextField(
                    controller: nicknameController,
                    decoration: InputDecoration(labelText: 'Kullanıcı Adı'),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'Şifre'),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                  ),
                  SizedBox(height: 20),
                  _isLoading
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD06100),
                            foregroundColor: const Color(0xFFF2E9E9),
                            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Giriş Yap', style: TextStyle(fontSize: 18)),
                        ),
                  if (_errorMessage.isNotEmpty) ...[
                    SizedBox(height: 10),
                    Text(_errorMessage, style: TextStyle(color: Colors.red)),
                  ],
                  TextButton(
                    onPressed: _showRegisterPage,
                    child: Text('Hesabın yok mu? Kayıt Ol', style: TextStyle(color: const Color(0xFFD06100))),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            Text(
              'Loczy - Tüm hakları saklıdır.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

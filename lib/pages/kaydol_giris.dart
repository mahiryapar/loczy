import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:loczy/config_getter.dart';
import 'package:loczy/pages/kaydol_dialog.dart';

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

    final String apiUrl = await ConfigLoader.apiUrl; 
    final String bearerToken = await ConfigLoader.bearerToken; 

    final response = await http.get(
      Uri.parse('$apiUrl/routers/users.php?nickname=${nicknameController.text}&password=${passwordController.text}'),
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
        await prefs.setInt('userId', responseData['id']); // Kullanıcı ID'yi kaydet
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
        widget.onLoginSuccess(true);
      } else {
        setState(() {
          _errorMessage = responseData['message'] ?? 'Giriş başarısız!';
        });
      }
    } else {
      setState(() {
        final Map<String, dynamic> responseData = json.decode(response.body);
        _errorMessage = responseData['error'] ?? 'Sunucu hatası, lütfen tekrar deneyin!';
      });
    }
  }
  
   void _showRegisterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return KaydolDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Giriş Yap', style: Theme.of(context).textTheme.headlineLarge),
              SizedBox(height: 20),
              TextField(
                controller: nicknameController,
                decoration: InputDecoration(labelText: 'Kullanıcı Adı', border: OutlineInputBorder()),
              ),
              SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Şifre', border: OutlineInputBorder()),
              ),
              SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      child: Text('Giriş Yap'),
                    ),
              if (_errorMessage.isNotEmpty) ...[
                SizedBox(height: 10),
                Text(_errorMessage, style: TextStyle(color: Colors.red)),
              ],
              TextButton(
                onPressed: () {
                  _showRegisterDialog();
                },
                child: Text('Hesabın yok mu? Kayıt Ol'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

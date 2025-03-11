import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:loczy/config_getter.dart';


class KaydolDialog extends StatefulWidget {
  @override
  _KaydolDialogState createState() => _KaydolDialogState();
}

class _KaydolDialogState extends State<KaydolDialog> {
  final TextEditingController isimController = TextEditingController();
  final TextEditingController soyisimController = TextEditingController();
  final TextEditingController mailController = TextEditingController();
  final TextEditingController numberController = TextEditingController();
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isRegistering = false;
  String _registerError = '';

  Future<void> _register() async {
    setState(() {
      _isRegistering = true;
      _registerError = '';
    });

    final String apiUrl = await ConfigLoader.apiUrl;
    final response = await http.post(
      Uri.parse('$apiUrl/routers/users.php'),
      headers: {'Content-Type': 'application/json',
      'Authorization': 'Bearer ${await ConfigLoader.bearerToken}'},
      body: jsonEncode({
        'isim': isimController.text,
        'soyisim': soyisimController.text,
        'mail': mailController.text,
        'number': numberController.text,
        'nickname': nicknameController.text,
        'sifre': passwordController.text,
        'ev_konum': 'Ev Konumu',
        'hesap_turu': 'Private',
        'profil_fotosu_url': 'sdfs',
      }),
    );

    setState(() {
      _isRegistering = false;
    });

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['status'] == 'success') {
        Navigator.pop(context); 
      } else {
        setState(() {
          _registerError = responseData['message'] ?? 'Kayıt başarısız!';
        });
      }
    } else {
      setState(() {
        _registerError = 'Sunucu hatası, tekrar deneyin!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Kayıt Ol'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(controller: isimController, decoration: InputDecoration(labelText: 'İsim')),
            TextField(controller: soyisimController, decoration: InputDecoration(labelText: 'Soyisim')),
            TextField(controller: mailController, decoration: InputDecoration(labelText: 'E-Mail')),
            TextField(controller: numberController, decoration: InputDecoration(labelText: 'Telefon')),
            TextField(controller: nicknameController, decoration: InputDecoration(labelText: 'Kullanıcı Adı')),
            TextField(controller: passwordController, decoration: InputDecoration(labelText: 'Şifre'), obscureText: true),
            SizedBox(height: 10),
            _isRegistering ? CircularProgressIndicator() : ElevatedButton(onPressed: _register, child: Text('Kayıt Ol')),
            if (_registerError.isNotEmpty) Text(_registerError, style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

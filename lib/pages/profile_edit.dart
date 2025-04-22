import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:loczy/config_getter.dart';

class ProfileEditPage extends StatefulWidget {
  @override
  _ProfileEditPageState createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late TextEditingController _firstNameC, _lastNameC, _bioC, _emailC, _phoneC, _nicknameC;
  String _ppPath = '';
  bool _isPrivate = false, _loading = true, _updating = false;
  int uid = 0;
  String _errorMessage = '';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _firstNameC = TextEditingController();
    _lastNameC = TextEditingController();
    _bioC = TextEditingController();
    _emailC = TextEditingController();
    _phoneC = TextEditingController();
    _nicknameC = TextEditingController();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _firstNameC.text = prefs.getString('user_isim') ?? '';
      _lastNameC.text = prefs.getString('user_soyisim') ?? '';
      _bioC.text = prefs.getString('biyografi') ?? '';
      _emailC.text = prefs.getString('user_mail') ?? '';
      _phoneC.text = prefs.getString('user_number') ?? '';
      _nicknameC.text = prefs.getString('userNickname') ?? '';
      _ppPath = prefs.getString('user_profile_photo_path') ?? '';
      _isPrivate = prefs.getString('user_hesap_turu') == "private";
      uid = prefs.getInt('userId') ?? 0;
      _loading = false;
    });
  }

  bool _validateAll() {
    final emailRx = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRx.hasMatch(_emailC.text)) {
      _errorMessage = 'Geçerli bir e-posta giriniz!'; return false;
    }
    final digits = _phoneC.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) {
      _errorMessage = 'Geçerli bir telefon numarası giriniz!'; return false;
    }
    final nick = _nicknameC.text;
    if (nick.length < 4 || nick.length > 30) {
      _errorMessage = 'Kullanıcı adı 4-30 karakter arası olmalıdır!'; return false;
    }
    if (RegExp(r'^[0-9]+$').hasMatch(nick)) {
      _errorMessage = 'Kullanıcı adı sadece sayıdan oluşamaz!'; return false;
    }
    if (RegExp(r'[çğıöşüÇĞİÖŞÜ]').hasMatch(nick)) {
      _errorMessage = 'Kullanıcı adı Türkçe karakter içeremez!'; return false;
    }
    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(nick)) {
      _errorMessage = 'Kullanıcı adı sadece harf, rakam, _ ve . içerebilir!'; return false;
    }
    _errorMessage = '';
    return true;
  }

  Future<String?> _updateProfile() async {
    setState(() { _updating = true; _errorMessage = ''; });
    String? finalPhotoUrl; 
    try {
      final apiUrl = await ConfigLoader.apiUrl;
      // determine final photo URL
      if (_ppPath.isEmpty) {
        finalPhotoUrl = await ConfigLoader.defaultProfilePhoto;
      } else {
        final fileExists = await File(_ppPath).exists();
        if (fileExists) {
          final uploadUri = Uri.parse('$apiUrl/upload.php');
            final bearerToken = await ConfigLoader.bearerToken; 
            final uploadUriWithParam = uploadUri.replace(queryParameters: {
            'user_name': _nicknameC.text,
            });
            final req = http.MultipartRequest('POST', uploadUriWithParam)
            ..headers['Authorization'] = 'Bearer $bearerToken'
            ..files.add(await http.MultipartFile.fromPath('file', _ppPath));
          final streamed = await req.send();
          if (streamed.statusCode == 200) {
            final respStr = await streamed.stream.bytesToString();
            final data2 = json.decode(respStr);
            if (data2 != null && data2['file_url'] != null && data2['file_url'].isNotEmpty) {
               finalPhotoUrl = data2['file_url'];
            } else {
              _errorMessage = 'Fotoğraf yüklendi ancak URL alınamadı.';
               setState(() { _updating = false; });
               return null; // Indicate failure
            }
          } else {
            _errorMessage = 'Fotoğraf yükleme hatası: ${streamed.statusCode}';
            setState(() { _updating = false; });
          }
        } else {
          finalPhotoUrl = _ppPath;
        }
      }

      if (finalPhotoUrl == null || finalPhotoUrl.isEmpty) {
          _errorMessage = 'Profil fotoğrafı URL\'si belirlenemedi.';
          setState(() { _updating = false; });
      }

      final uri = Uri.parse('$apiUrl/routers/users.php');
      final bearerToken = await ConfigLoader.bearerToken; 
      final body = jsonEncode({
        "id": uid,
        "nickname": _nicknameC.text,
        "isim": _firstNameC.text,
        "soyisim": _lastNameC.text,
        "profil_fotosu_url": finalPhotoUrl, 
        "hesap_turu": _isPrivate ? "private" : "public",
        "mail": _emailC.text,
        "number": _phoneC.text.replaceAll(RegExp(r'\D'), ''),
        "biyografi": _bioC.text
      });
      final resp = await http.put(uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken'
        },
        body: body
      );

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['status'] == 'updated') {
           setState(() { _updating = false; });
           return finalPhotoUrl; 
        }
        _errorMessage = data['message'] ?? 'Güncelleme başarısız!';
      } else {
        _errorMessage = 'Sunucu hatası: ${resp.statusCode}';
      }
    } catch (e) {

      if (_errorMessage.isEmpty) {
         _errorMessage = 'Bir hata oluştu: ${e.toString()}';
      }
       print('Error during profile update: $e'); 
    } finally {

      if (_updating) {
        setState(() { _updating = false; });
      }
    }
    return null; 
  }

  Future<void> _confirmAndSave() async {
    if (!_validateAll()) {
      setState((){}); 
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Onay'),
        content: Text('Değişiklikleri kaydetmek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Hayır')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Evet')),
        ],
      ),
    );
    if (ok != true) return;

    final String? savedPhotoUrl = await _updateProfile();
    

    if (savedPhotoUrl != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_isim', _firstNameC.text);
      await prefs.setString('user_soyisim', _lastNameC.text);
      await prefs.setString('biyografi', _bioC.text);
      await prefs.setString('user_mail', _emailC.text);
      await prefs.setString('user_number', _phoneC.text.replaceAll(RegExp(r'\D'), '')); // Save cleaned number
      await prefs.setString('userNickname', _nicknameC.text);
      await prefs.setString('user_profile_photo_path', savedPhotoUrl);
      await prefs.setString('user_hesap_turu', _isPrivate ? "private" : "public");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil başarıyla güncellendi!')),
      );

      Navigator.pop(context, true); // Indicate success on pop
    } else {
      setState(() {});
    }
  }

  Future<void> _showPhotoOptions() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('Profil Fotoğrafı'),
        children: [
          SimpleDialogOption(
            child: Text('Fotoğrafı Kaldır'),
            onPressed: () => Navigator.pop(c, 'remove'),
          ),
          SimpleDialogOption(
            child: Text('Galeriden Seç'), 
            onPressed: () => Navigator.pop(c, 'upload'),
          ),
           SimpleDialogOption( 
            child: Text('İptal'),
            onPressed: () => Navigator.pop(c, null),
          ),
        ],
      ),
    );
    if (choice == 'remove') {
      setState(() => _ppPath = '');
    } else if (choice == 'upload') {
      try {
        final XFile? img = await _picker.pickImage(source: ImageSource.gallery);
        if (img != null) {
           setState(() => _ppPath = img.path); 
        }
      } catch (e) {
         print("Image picker error: $e");
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fotoğraf seçilemedi: ${e.toString()}'))
         );
      }
    }

  }

  @override
  void dispose() {
    _firstNameC.dispose();
    _lastNameC.dispose();
    _bioC.dispose();
    _emailC.dispose();
    _phoneC.dispose();
    _nicknameC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Profili Düzenle'),
        backgroundColor: const Color(0xFFD06100),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          GestureDetector(
            onTap: _showPhotoOptions,
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[300], 
              backgroundImage: _ppPath.isNotEmpty
                  ? (_ppPath.startsWith('http')
                      ? NetworkImage(_ppPath)
                      : (File(_ppPath).existsSync() ? FileImage(File(_ppPath)) : null)
                    ) as ImageProvider? 
                  : null, 
              child: _ppPath.isEmpty
                  ? Icon(Icons.person_add_alt_1, size: 60, color: Colors.grey[600]) // Icon when no photo
                  : null,
            ),
          ),
          SizedBox(height: 20),
          TextField(controller: _firstNameC, decoration: InputDecoration(labelText: 'İsim')),
          SizedBox(height: 20),
          TextField(controller: _lastNameC, decoration: InputDecoration(labelText: 'Soyisim')),
          SizedBox(height: 20),
          TextField(controller: _bioC, decoration: InputDecoration(labelText: 'Biyografi'), maxLines: 3),
          SizedBox(height: 20),
          TextField(
            controller: _emailC,
            decoration: InputDecoration(labelText: 'E‑posta'),
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() => _validateAll()),
          ),
          SizedBox(height: 20),
          TextField( 
            controller: _phoneC,
            decoration: InputDecoration(labelText: 'Telefon (05xxxxxxxxx)'), 
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
              TextInputFormatter.withFunction((oldValue, newValue) {
                 String text = newValue.text;
                 if (text.length > 11) return oldValue; 
                 return newValue;
              }),
            ],
            onChanged: (_) => setState(() => _validateAll()), 
          ),
          SizedBox(height: 20),
          TextField(
            controller: _nicknameC,
            decoration: InputDecoration(labelText: 'Kullanıcı Adı'),
            onChanged: (_) => setState(() => _validateAll()),
          ),
          if (_errorMessage.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(_errorMessage, style: TextStyle(color: Colors.red)),
          ],
          SizedBox(height: 20),
          SwitchListTile(
            title: Text('Gizli Hesap'),
            value: _isPrivate,
            onChanged: (v) => setState(() => _isPrivate = v),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _updating ? null : _confirmAndSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD06100),
              foregroundColor: const Color(0xFFF2E9E9),
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _updating ? CircularProgressIndicator(color: Colors.white) : Text('Kaydet', style: TextStyle(fontSize: 16)),
          ),
        ]),
      ),
    );
  }
}
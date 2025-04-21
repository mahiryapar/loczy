import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileEditPage extends StatefulWidget {
  @override
  _ProfileEditPageState createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late TextEditingController _firstNameC;
  late TextEditingController _lastNameC;
  late TextEditingController _bioC;
  late TextEditingController _emailC;
  late TextEditingController _phoneC;
  String _ppPath = '';
  bool _isPrivate = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _firstNameC = TextEditingController();
    _lastNameC = TextEditingController();
    _bioC = TextEditingController();
    _emailC = TextEditingController();
    _phoneC = TextEditingController();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _firstNameC.text = prefs.getString('user_isim') ?? '';
      _lastNameC.text = prefs.getString('user_soyisim') ?? '';
      _bioC.text       = prefs.getString('biyografi')   ?? '';
      _emailC.text     = prefs.getString('user_mail')       ?? '';
      _phoneC.text     = prefs.getString('user_number')     ?? '';
      _ppPath          = prefs.getString('user_profile_photo_path') ?? '';
      _isPrivate       = prefs.getString('hesap_turu') == "private" ? true : false;
      _loading = false;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_isim', _firstNameC.text);
    await prefs.setString('user_soyisim', _lastNameC.text);
    await prefs.setString('biyografi', _bioC.text);
    await prefs.setString('user_mail', _emailC.text);
    await prefs.setString('user_number', _phoneC.text);
    await prefs.setString('hesap_turu', _isPrivate== true ? "private" : "public");
  }

  Future<void> _confirmAndSave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Onay'),
        content: Text('Değişiklikleri kaydetmek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(c,false), child: Text('Hayır')),
          TextButton(onPressed: ()=>Navigator.pop(c,true),  child: Text('Evet')),
        ],
      ),
    );
    if (ok == true) {
      await _saveData();
      Navigator.pop(context);
    }
  }

  Future<void> _togglePrivacy(bool val) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Hesap Gizliliği'),
        content: Text(val
            ? 'Hesabınızı gizli yapmak istiyor musunuz?'
            : 'Hesabınızı açık yapmak istiyor musunuz?'),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(c,false), child: Text('İptal')),
          TextButton(onPressed: ()=>Navigator.pop(c,true),  child: Text('Onayla')),
        ],
      ),
    );
    if (yes == true) {
      setState(() => _isPrivate = val);
    }
  }

  @override
  void dispose() {
    _firstNameC.dispose();
    _lastNameC.dispose();
    _bioC.dispose();
    _emailC.dispose();
    _phoneC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: Text('Profili Düzenle'),
        backgroundColor: const Color(0xFFD06100),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage:
                  _ppPath.isNotEmpty ? FileImage(File(_ppPath)) : null,
              child: _ppPath.isEmpty ? Icon(Icons.person, size: 60) : null,
            ),
            SizedBox(height: 20),
            TextField(
              controller: _firstNameC,
              decoration: InputDecoration(labelText: 'İsim'),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _lastNameC,
              decoration: InputDecoration(labelText: 'Soyisim'),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _bioC,
              decoration: InputDecoration(labelText: 'Biyografi'),
              maxLines: 3,
            ),
            SizedBox(height: 20),
            TextField(
              controller: _emailC,
              decoration: InputDecoration(labelText: 'E‑posta'),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 20),
            TextField(
              controller: _phoneC,
              decoration: InputDecoration(labelText: 'Telefon'),
              keyboardType: TextInputType.phone,
            ),
            SwitchListTile(
              title: Text('Gizli Hesap'),
              value: _isPrivate,
              onChanged: _togglePrivacy,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _confirmAndSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD06100),
                foregroundColor: const Color(0xFFF2E9E9),
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Kaydet', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
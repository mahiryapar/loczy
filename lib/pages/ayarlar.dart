import 'package:flutter/material.dart';
import 'package:loczy/main.dart';

class AyarlarPage extends StatefulWidget {
  final Function logout;

  AyarlarPage({Key? key, required this.logout}) : super(key: key);
  @override
  State<AyarlarPage> createState() => _AyarlarPageState();
}

class _AyarlarPageState extends State<AyarlarPage> {
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ayarlar'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.language),
            title: Text('Dil Seçenekleri'),
            onTap: () {
              // Dil seçenekleri sayfasına yönlendirme
            },
          ),
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text('Bildirim Ayarları'),
            onTap: () {
              // Bildirim ayarları sayfasına yönlendirme
            },
          ),
          ListTile(
            leading: Icon(Icons.lock),
            title: Text('Gizlilik Ayarları'),
            onTap: () {
              // Gizlilik ayarları sayfasına yönlendirme
            },
          ),
          ListTile(
            leading: Icon(Icons.color_lens),
            title: Text('Tema Seçenekleri'),
            onTap: () {
              // Tema seçenekleri sayfasına yönlendirme
            },
          ),
          ListTile(
            leading: Icon(Icons.exit_to_app, color: Colors.red),
            title: Text(
              'Çıkış',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              await widget.logout();
              Navigator.of(context).pop();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainScreen()));
            },
          ),
        ],
      ),
    );
  }
}
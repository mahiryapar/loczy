import 'package:flutter/material.dart';
import 'package:loczy/main.dart';
import 'package:loczy/pages/kaydedilenler.dart'; // Add this import

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
            leading: Icon(Icons.bookmark),
            title: Text('Kaydedilenler'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => KaydedilenlerPage()),
              );
            },
          ),
            ListTile(
            leading: Icon(Icons.exit_to_app, color: Colors.red),
            title: Text(
              'Çıkış',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async { // Make onTap async
              await widget.logout(); // Await the logout function
              // Navigate to MainScreen and remove all previous routes
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => MainScreen()),
                (Route<dynamic> route) => false, // Remove all routes
              );
            },
            ),
        ],
      ),
    );
  }
}
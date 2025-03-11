import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loczy/pages/hesabim.dart';
import 'package:loczy/pages/ana_sayfa.dart';
import 'package:loczy/pages/kaydol_giris.dart';
import 'package:loczy/theme.dart';
import 'package:loczy/config_getter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigLoader.loadConfig(); 
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isLoggedIn = prefs.getInt('userId') != null;
    });
  }

  void _updateLoginStatus(bool loggedIn) {
    setState(() {
      isLoggedIn = loggedIn;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _updateLoginStatus(false);
  }

  @override
  Widget build(BuildContext context) {
    return isLoggedIn ? AnaSayfa(logout:_logout) : KaydolGiris(onLoginSuccess: _updateLoginStatus);
  }
}

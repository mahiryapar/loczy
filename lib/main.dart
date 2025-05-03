import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loczy/pages/ana_sayfa.dart';
import 'package:loczy/pages/giris.dart';
import 'package:loczy/theme.dart';
import 'package:loczy/config_getter.dart';
import 'package:loczy/providers/notification_provider.dart';
import 'package:loczy/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'dart:io';
// Import MqttService
import 'package:loczy/services/mqtt_service.dart';

// At the top of your main.dart file, add:
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Instantiate NotificationService here
  final notificationService = NotificationService();
  await notificationService.init(); // Initialize it
  await ConfigLoader.loadConfig();

  runApp(
    // Use MultiProvider to provide multiple services/providers
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => NotificationProvider(),
        ),
        // Provide MqttService
        Provider<MqttService>(
          create: (context) {
            // Get NotificationProvider from context
            final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
            print("--- Creating MqttService instance ---"); // Log creation
            // Create MqttService instance
            return MqttService(
              notificationService: notificationService, // Pass the instance
              notificationProvider: notificationProvider,
            );
          },
          // IMPORTANT: Add dispose to ensure disconnect is called when provider is removed
          dispose: (context, mqttService) {
             print("--- Disposing MqttService instance ---"); // Log disposal
             mqttService.disconnect();
          },
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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
  // Keep track of MqttService instance for disconnect
  MqttService? _mqttService;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get MqttService instance here if needed for logout
    // It's generally safer to get it just before use (in _logout)
    // _mqttService = Provider.of<MqttService>(context, listen: false);
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getInt('userId') != null;
    print("MainScreen: _checkLoginStatus - isLoggedIn: $loggedIn"); // Log status check
    setState(() {
      isLoggedIn = loggedIn;
    });

    if (isLoggedIn) {
      // --- CRITICAL ---
      // DO NOT CALL initializeAndConnect here.
      // It MUST be called AFTER login is confirmed AND the user navigates
      // to the main part of the app (e.g., AnaSayfa).
      // --- CRITICAL ---
      print("MainScreen: User logged in, navigating to home.");
      _navigateToHome();
    } else {
       print("MainScreen: User not logged in.");
    }
  }

  void _updateLoginStatus(bool loggedIn) {
     print("MainScreen: _updateLoginStatus called with: $loggedIn"); // Log status update
    setState(() {
      isLoggedIn = loggedIn;
    });

    if (loggedIn) {
      // --- CRITICAL ---
      // DO NOT CALL initializeAndConnect here.
      // It MUST be called AFTER login is confirmed AND the user navigates
      // to the main part of the app (e.g., AnaSayfa).
      // --- CRITICAL ---
      // Example: Place this inside AnaSayfa's initState:
      // @override
      // void initState() {
      //   super.initState();
      //   // Connect MQTT after user logs in and AnaSayfa loads
      //   WidgetsBinding.instance.addPostFrameCallback((_) {
      //      final mqttService = Provider.of<MqttService>(context, listen: false);
      //      print("AnaSayfa: initState - Calling initializeAndConnect");
      //      mqttService.initializeAndConnect();
      //   });
      // }
      // --- CRITICAL ---
      print("MainScreen: Login successful, navigating to home.");
      _navigateToHome();
    }
  }

  Future<void> _logout() async {
    print("MainScreen: _logout called."); // Log logout
    // Get MqttService instance before logging out to disconnect
    final mqttService = context.read<MqttService>();
    mqttService.disconnect(); // Disconnect MQTT before clearing prefs
    print("MQTT Service Disconnected on Logout."); // Debug print

    final prefs = await SharedPreferences.getInstance();
    
    // Remove the saved profile photo
    final profilePhotoPath = prefs.getString('user_profile_photo_path');
    if (profilePhotoPath != null) {
      final file = File(profilePhotoPath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await prefs.clear();

    _updateLoginStatus(false);
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AnaSayfa(logout: _logout,)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show splash/loading or decide based on isLoggedIn more clearly
    if (isLoggedIn) {
       // If logged in, AnaSayfa should be shown via _navigateToHome.
       // Showing an empty container might indicate a logic flaw if seen for long.
       print("MainScreen: Build - User is logged in (showing AnaSayfa via navigation)");
       return Scaffold(body: Center(child: CircularProgressIndicator())); // Placeholder until navigation completes
    } else {
       print("MainScreen: Build - User is NOT logged in (showing KaydolGiris)");
       return KaydolGiris(onLoginSuccess: _updateLoginStatus);
    }
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:loczy/pages/hesabim.dart';
import 'package:loczy/pages/kesfet.dart';
import 'package:loczy/pages/mesajlar.dart';
import 'package:loczy/pages/upload.dart';
import 'package:loczy/providers/notification_provider.dart';
import 'package:loczy/services/mqtt_service.dart';
import 'package:loczy/services/notification_service.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loczy/pages/home_page.dart';

class AnaSayfa extends StatefulWidget {
  final Function logout;

  AnaSayfa({Key? key, required this.logout}) : super(key: key);
  @override
  _AnaSayfaState createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  int _selectedIndex = 0;
  String _username = '@KullanıcıAdı'; // Varsayılan kullanıcı adı
  bool _showNotifications = false;
  MqttService? _mqttService; // Make MqttService nullable

  // Define the async logout function
  Future<void> _logout() async {
    // Disconnect MQTT before logging out
    _mqttService?.disconnect();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Clear notification provider state on logout
    Provider.of<NotificationProvider>(context, listen: false).clearNotifications();
    await prefs.remove('userId');
    await prefs.remove('userNickname');
    await prefs.remove('user_isim');
    await prefs.remove('user_soyisim');
    await prefs.remove('user_mail');
    await prefs.remove('user_number');
    await prefs.remove('user_ev_konum');
    await prefs.remove('user_hesap_turu');
    await prefs.remove('user_pp_url');
    await prefs.remove('user_takipci');
    await prefs.remove('biyografi');
    await prefs.remove('user_takip_edilenler');
    // Also remove the downloaded profile photo if needed
    String? photoPath = prefs.getString('user_profile_photo_path');
    if (photoPath != null) {
      try {
        final file = File(photoPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Handle potential file deletion errors
        print("Error deleting profile photo: $e");
      }
      await prefs.remove('user_profile_photo_path');
    }
    // Call the original logout function passed from MainScreen if needed
    // This assumes the function passed to AnaSayfa primarily updates the UI state in MainScreen
    widget.logout();
  }

  void _loadUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = '@' + (prefs.getString('userNickname') ?? 'KullanıcıAdı');
    });
  }

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _initializeMqtt(); // Initialize MQTT here
    _pages = [
      HomePage(),
      MessagesPage(),
      ExplorePage(),
      UploadPage(),
      ProfilePage(logout: _logout),
    ];
  }

  // Initialize and connect MQTT service
  void _initializeMqtt() async {
    print("AnaSayfa: _initializeMqtt called."); // DEBUG PRINT
    // Ensure context is available and mounted before accessing Provider
    if (mounted) {
       print("AnaSayfa: Widget is mounted. Initializing MQTT..."); // DEBUG PRINT
       try {
         final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
         print("AnaSayfa: NotificationProvider obtained."); // DEBUG PRINT
         _mqttService = MqttService(
           notificationService: NotificationService(), // Get singleton instance
           notificationProvider: notificationProvider,
         );
         print("AnaSayfa: MqttService instance created. Connecting..."); // DEBUG PRINT
         await _mqttService!.initializeAndConnect();
         print("AnaSayfa: MqttService initializeAndConnect called."); // DEBUG PRINT
       } catch (e) {
         print("AnaSayfa: Error during MQTT initialization (mounted): $e"); // DEBUG PRINT
       }
    } else {
       print("AnaSayfa: Widget not mounted yet. Scheduling MQTT initialization."); // DEBUG PRINT
       // If not mounted yet, schedule it for after the first frame
       WidgetsBinding.instance.addPostFrameCallback((_) {
         print("AnaSayfa: Post frame callback executed."); // DEBUG PRINT
         if (mounted) { // Check again after frame
           print("AnaSayfa: Widget is now mounted in post frame callback. Initializing MQTT..."); // DEBUG PRINT
           _initializeMqtt(); // Re-call the initialization logic
         } else {
           print("AnaSayfa: Widget still not mounted in post frame callback."); // DEBUG PRINT
         }
       });
    }
  }


  @override
  void dispose() {
    print("AnaSayfa: dispose called. Disconnecting MQTT."); // DEBUG PRINT
    // Disconnect MQTT when the widget is disposed
    _mqttService?.disconnect();
    super.dispose();
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Reset notification view when changing tabs (optional)
      // if (_showNotifications) {
      //   _showNotifications = false;
      //   Provider.of<NotificationProvider>(context, listen: false).markAsRead();
      // }
    });
  }

  void _toggleNotifications() {
    setState(() {
      _showNotifications = !_showNotifications;
      // Mark notifications as read when opening the detailed view
      if (_showNotifications) {
        Provider.of<NotificationProvider>(context, listen: false).markAsRead();
      }
    });
  }

  Widget _buildAppBar() {
    // Use Consumer to listen to NotificationProvider changes
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final unreadCount = notificationProvider.unreadCount;
        final latestNotification = notificationProvider.notifications.isNotEmpty
            ? notificationProvider.notifications.first
            : null;
        final marqueeText = unreadCount > 0 && latestNotification != null
            ? '$unreadCount okunmamış bildirim: ${latestNotification.body}'
            : 'Bildirim yok'; // Default text when no unread

        return AnimatedPositioned(
          duration: Duration(milliseconds: 500),
          curve: Curves.fastEaseInToSlowEaseOut,
          top: 0,
          left: 0,
          right: 0,
          // Adjust height based on whether notifications are shown and if there are any
          height: _showNotifications ? (notificationProvider.notifications.isEmpty ? 80.0 : 300.0) : 60.0,
          child: GestureDetector(
            onTap: _selectedIndex != 4 ? _toggleNotifications : null,
            child: Material(
              elevation: 10.0,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(_showNotifications ? 20.0 : 10.0),
                bottomRight: Radius.circular(_showNotifications ? 20.0 : 10.0),
              ),
              child: AppBar(
                toolbarHeight: _showNotifications ? (notificationProvider.notifications.isEmpty ? 80.0 : 300.0) : 60.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(_showNotifications ? 20.0 : 10.0),
                    bottomRight: Radius.circular(_showNotifications ? 20.0 : 10.0),
                  ),
                ),
                title: _selectedIndex == 4
                    ? Center( // Profile Page Title
                        child: Text(
                          _username,
                          style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
                        ),
                      )
                    : _showNotifications // Expanded Notification View
                        ? (notificationProvider.notifications.isEmpty
                            ? Center(child: Text("Yeni bildirim yok.", style: TextStyle(fontSize: 14.0)))
                            : ListView.builder( // Display list of notifications
                                itemCount: notificationProvider.notifications.length,
                                itemBuilder: (context, index) {
                                  final notification = notificationProvider.notifications[index];
                                  return ListTile(
                                    dense: true,
                                    title: Text(notification.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text(notification.body, style: TextStyle(fontSize: 12)),
                                    // You can add timestamps or actions here
                                  );
                                },
                              )
                          )
                        : Container( // Collapsed Marquee View
                            height: 20.0,
                            child: Marquee(
                              text: marqueeText,
                              style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: unreadCount > 0 ? Colors.redAccent : null, // Highlight if unread
                              ),
                              scrollAxis: Axis.horizontal,
                              blankSpace: 50.0, // Increased blank space
                              velocity: 40.0, // Slightly slower velocity
                              pauseAfterRound: Duration(seconds: 2), // Pause between scrolls
                              showFadingOnlyWhenScrolling: true,
                              fadingEdgeStartFraction: 0.1,
                              fadingEdgeEndFraction: 0.1,
                              startPadding: 10.0,
                              accelerationDuration: Duration(seconds: 1),
                              accelerationCurve: Curves.linear,
                              decelerationDuration: Duration(milliseconds: 500),
                              decelerationCurve: Curves.easeOut,
                            ),
                          ),
                // Add padding or SizedBox if needed when AppBar content changes height
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(5.0),
                  child: SizedBox(height: 5.0),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory, // Su dalgasını kaldırır
        highlightColor: Colors.transparent, // Basılı tutunca oluşan efekti kaldırır
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        child: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(Icons.home),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(Icons.message),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(Icons.explore),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(Icons.upload_rounded),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(Icons.person),
              ),
              label: '',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFFD06100),
          unselectedItemColor: const Color(0xFF383633),
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          iconSize: 24.0,
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Ensure AppBar is built above the page content
    return Stack(
      children: [
        // Add padding to the top of the page content so it doesn't hide behind the AppBar
        Padding(
          padding: EdgeInsets.only(top: 5.0), // Start with the collapsed AppBar height
          child: _pages[_selectedIndex],
        ),
        _buildAppBar(), // AppBar is drawn on top
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Remove Scaffold's AppBar, we are using a custom one in the Stack
      // appBar: _buildAppBar(), // REMOVE THIS
      body: _buildContent(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
}



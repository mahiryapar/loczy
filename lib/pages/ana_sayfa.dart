import 'dart:async'; // Import async library for Timer
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:loczy/pages/hesabim.dart';
import 'package:loczy/pages/kesfet.dart';
import 'package:loczy/pages/mesajlar.dart';
import 'package:loczy/pages/upload.dart';
import 'package:loczy/providers/notification_provider.dart';
import 'package:loczy/services/mqtt_service.dart';
import 'package:loczy/services/notification_service.dart';
import 'package:loczy/utils/time_utils.dart'; // Add import for the new utility
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
  bool _showExpandedContent = false; // Controls visibility of expanded content
  Timer? _expandTimer; // Timer for delayed appearance

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
    _expandTimer?.cancel(); // Cancel timer if active
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
    _expandTimer?.cancel(); // Cancel any existing timer

    if (!_showNotifications) { // ---- Expanding ----
      setState(() {
        _showNotifications = true; // Start expanding animation
        // Don't show content immediately to prevent overflow during animation
        _showExpandedContent = false;
      });
      // Start timer to show content shortly after animation starts
      _expandTimer = Timer(Duration(milliseconds: 150), () { // Delay before showing content
         // Check if still mounted and still in expanded state before updating state
         if (mounted && _showNotifications) {
            setState(() {
               _showExpandedContent = true; // Show content now
            });
         }
      });
      // Mark as read when opening
      Provider.of<NotificationProvider>(context, listen: false).markAsRead();

    } else { // ---- Collapsing ----
      setState(() {
        _showExpandedContent = false; // Hide content immediately
        _showNotifications = false; // Start collapsing animation
      });
    }
  }


  Widget _buildAppBar() {
    // Use Consumer to listen to NotificationProvider changes
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final unreadCount = notificationProvider.unreadCount;
        final notifications = notificationProvider.notifications; // Get the list
        final latestNotification = notifications.isNotEmpty ? notifications.first : null;
        final marqueeText = unreadCount > 0 && latestNotification != null
            ? '$unreadCount okunmamış bildirim: ${latestNotification.body}'
            : 'Bildirim yok'; // Default text when no unread

        // Define heights
        const double collapsedHeight = 60.0;
        const double expandedEmptyHeight = 80.0; // Height when expanded but empty
        const double expandedListHeight = 300.0;

        // Determine current height based on state
        final double currentHeight = _showNotifications
            ? (notifications.isEmpty ? expandedEmptyHeight : expandedListHeight)
            : collapsedHeight;

        // Widget to display when collapsed OR expanded but empty/animating
        final Widget marqueeWidget = Center( // Collapsed Marquee View (Center vertically)
          child: Container(
            height: 20.0, // Explicit height for Marquee container
            child: Marquee(
              key: ValueKey(marqueeText), // Add key to force rebuild on text change
              text: marqueeText,
              style: TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
                color: Colors.white
              ),
              scrollAxis: Axis.horizontal,
              blankSpace: 50.0,
              velocity: 40.0,
              pauseAfterRound: Duration(seconds: 2),
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
        );

        return AnimatedPositioned(
          duration: Duration(milliseconds: 300), // Slightly faster animation
          curve: Curves.easeInOut, // Smoother curve
          top: 0,
          left: 0,
          right: 0,
          height: currentHeight,
          child: GestureDetector(
            // Allow toggling if not on profile page
            onTap: _selectedIndex != 4 ? _toggleNotifications : null, // Updated condition
            child: Material(
              elevation: 10.0,
              color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).primaryColor, // Use theme color
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(_showNotifications ? 20.0 : 10.0),
                bottomRight: Radius.circular(_showNotifications ? 20.0 : 10.0),
              ),
              child: ClipRRect( // Clip content to rounded corners
                 borderRadius: BorderRadius.only(
                   bottomLeft: Radius.circular(_showNotifications ? 20.0 : 10.0),
                   bottomRight: Radius.circular(_showNotifications ? 20.0 : 10.0),
                 ),
                 child: SafeArea( // Ensure content is below status bar
                   bottom: false, // No safe area needed at the bottom of the app bar
                   child: Container( // Use Container to manage content layout
                     height: currentHeight,
                     padding: EdgeInsets.only(top: 5, bottom: 5), // Add some vertical padding
                     child: _selectedIndex == 4
                         ? Center( // Profile Page Title
                             child: Text(
                               _username,
                               style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Colors.white),
                             ),
                           )
                         : _showNotifications // Expanded or animating state
                             ? (_showExpandedContent && notifications.isNotEmpty) // Expanded, has content, after delay
                                 ? Column( // Use Column for title + list
                                     children: [
                                       Padding(
                                         padding: const EdgeInsets.symmetric(vertical: 8.0),
                                         child: Text("Bildirimler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                       ),
                                       Expanded( // Make ListView take remaining space
                                         child: ListView.builder(
                                           padding: EdgeInsets.zero, // Remove default padding
                                           itemCount: notifications.length,
                                           itemBuilder: (context, index) {
                                             final notification = notifications[index];
                                             // ---- Make ListTile Dismissible ----
                                             return Dismissible(
                                               key: ValueKey(notification), // Use notification object or a unique ID
                                               direction: DismissDirection.horizontal,
                                               onDismissed: (direction) {
                                                 // Remove the item from the data source
                                                 Provider.of<NotificationProvider>(context, listen: false)
                                                     .removeNotification(notification);

                                                 // Optional: Show a confirmation SnackBar
                                                 ScaffoldMessenger.of(context).removeCurrentSnackBar();
                                                 ScaffoldMessenger.of(context).showSnackBar(
                                                   SnackBar(
                                                     content: Text('${notification.title} silindi'),
                                                     duration: Duration(seconds: 2),
                                                    ),
                                                 );
                                               },
                                               // ... Dismissible backgrounds ...
                                               background: Container(
                                                 color: Colors.redAccent.withOpacity(0.8),
                                                 alignment: Alignment.centerLeft,
                                                 padding: EdgeInsets.symmetric(horizontal: 20.0),
                                                 child: Icon(Icons.delete_sweep, color: Colors.white),
                                               ),
                                               secondaryBackground: Container(
                                                 color: Colors.redAccent.withOpacity(0.8),
                                                 alignment: Alignment.centerRight,
                                                 padding: EdgeInsets.symmetric(horizontal: 20.0),
                                                 child: Icon(Icons.delete_sweep, color: Colors.white),
                                               ),
                                               child: ListTile( // The original ListTile
                                                 dense: true,
                                                 title: Text(notification.title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                                 subtitle: Text(notification.body, style: TextStyle(color: Colors.white70, fontSize: 12)),
                                               ),
                                             );
                                             // ---- End Dismissible ----
                                           },
                                         ),
                                       ),
                                     ],
                                   )
                                 : marqueeWidget // Show marquee if expanded but empty OR during animation delay
                             : marqueeWidget, // Collapsed state shows marquee
                   ),
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
        // Add fixed padding to the top of the page content
        // The AppBar will overlay this area. Adjust '60.0' if needed.
        Padding(
          padding: EdgeInsets.only(top: 5.0), // Reverted to fixed padding
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



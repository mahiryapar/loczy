import 'package:flutter/material.dart';
import 'package:loczy/pages/hesabim.dart';
import 'package:loczy/pages/kesfet.dart';
import 'package:loczy/pages/mesajlar.dart';
import 'package:loczy/pages/upload.dart';
import 'package:marquee/marquee.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    _pages = [
      HomePage(),
      MessagesPage(),
      ExplorePage(),
      UploadPage(),
      ProfilePage(logout: widget.logout),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleNotifications() {
    setState(() {
      _showNotifications = !_showNotifications;
    });
  }

  Widget _buildAppBar() {
    return AnimatedPositioned(
      duration: Duration(milliseconds: 500),
      curve: Curves.fastEaseInToSlowEaseOut, //easeInOutQuad  
      top: 0,
      left: 0,
      right: 0,
      height: _showNotifications ? 300.0 : 60.0,
      child: GestureDetector(
        onTap: _selectedIndex != 4 ? _toggleNotifications : null,
        child: Material(
          elevation: 10.0,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(_showNotifications ? 20.0 : 10.0),
            bottomRight: Radius.circular(_showNotifications ? 20.0 : 10.0),
          ),
          child: AppBar(
            toolbarHeight: _showNotifications ? 300.0 : 60.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(_showNotifications ? 20.0 : 10.0),
                bottomRight: Radius.circular(_showNotifications ? 20.0 : 10.0),
              ),
            ),
            title: Column(
              children: [
                if (_selectedIndex == 4)
                  Center(
                    child: Text(
                      _username,
                      style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (_showNotifications)
                  Column(
                    children: [
                      Text(
                        '1 okunmamış mesaj: @muratkarakoyun: Proje ne zaman bitecek?!',
                        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
                      ),
                      // Diğer bildirimler buraya eklenebilir
                    ],
                  )
                else if (_selectedIndex != 4)
                  Container(
                    height: 20.0,
                    child: Marquee(
                      text: '1 okunmamış mesaj: @muratkarakoyun: Proje ne zaman bitecek?!',
                      style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
                      scrollAxis: Axis.horizontal,
                      blankSpace: 20.0,
                      velocity: 50.0,
                    ),
                  ),
                SizedBox(height: 5.0),
              ],
            ),
          ),
        ),
      ),
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
    return Stack(
      children: [
        _pages[_selectedIndex],
        _buildAppBar(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildContent(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Ana Sayfa'));
  }
}




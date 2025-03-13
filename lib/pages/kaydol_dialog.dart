import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:loczy/config_getter.dart';
import 'package:loczy/theme.dart';
import 'package:flutter/services.dart';

class KaydolPage extends StatefulWidget {
  @override
  _KaydolPageState createState() => _KaydolPageState();
}

class _KaydolPageState extends State<KaydolPage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController isimController = TextEditingController();
  final TextEditingController soyisimController = TextEditingController();
  final TextEditingController mailController = TextEditingController();
  final TextEditingController numberController = TextEditingController();
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isRegistering = false;
  bool _isLoading = false;
  String _registerError = '';
  int _currentPage = 0;
  String _appBarTitle = 'İsim Soyisim';

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _progressAnimation =
        Tween<double>(begin: 0, end: 1).animate(_progressController);
    _pageController.addListener(() {
      final newPage = _pageController.page?.round() ?? 0;
      if (newPage != _currentPage) {
        setState(() {
          _currentPage = newPage;
          double progress = (_currentPage) / 5;
          _progressController.animateTo(progress,
              duration: Duration(milliseconds: 200));
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _isRegistering = true;
      _registerError = '';
    });

    try {
      final String apiUrl = await ConfigLoader.apiUrl;
      final response = await http.post(
        Uri.parse('$apiUrl/routers/users.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await ConfigLoader.bearerToken}'
        },
        body: jsonEncode({
          'isim': isimController.text,
          'soyisim': soyisimController.text,
          'mail': mailController.text,
          'number': numberController.text,
          'nickname': nicknameController.text,
          'sifre': passwordController.text,
          'ev_konum': 'Ev Konumu',
          'hesap_turu': 'Public',
          'profil_fotosu_url': 'sdfs',
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          return;
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
    } catch (e) {
      setState(() {
        _registerError = 'Bağlantı yok, bağlantınızı kontrol ediniz!';
      });
    } finally {
      setState(() {
        _isRegistering = false;
      });
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentPage++;
      _registerError = '';
      _setAppBarTitle();
    });
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentPage--;
      _registerError = '';
      _setAppBarTitle();
    });
  }

  Future<void> _checkIfExists(String type, String value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final String apiUrl = await ConfigLoader.apiUrl;
      final response = await http.get(
        Uri.parse('$apiUrl/routers/check.php?type=$type&value=$value'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await ConfigLoader.bearerToken}'
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status']=='error') {
          setState(() {
            _registerError = responseData['message'];
          });
        } else {
          setState(() {
            _registerError = '';
          });
        }
      } else {
        setState(() {
          _registerError = 'Sunucu hatası, tekrar deneyin!';
        });
      }
    } catch (e) {
      setState(() {
        _registerError = 'Bağlantı yok, bağlantınızı kontrol ediniz!';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text(_appBarTitle),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(4.0),
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: _progressAnimation
                      .value, // Progresi animasyonlu olarak gösteriyoruz
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                      const Color.fromARGB(255, 178, 84, 1)),
                );
              },
            ),
          ),
        ),
        body: PageView(
          controller: _pageController,
          physics: NeverScrollableScrollPhysics(),
          children: [
            _buildNamePage(),
            _buildEmailPage(),
            _buildPhonePage(),
            _buildUsernamePage(),
            _buildPasswordPage(),
            _buildSummaryPage(),
          ],
        ),
      ),
    );
  }

  String _setAppBarTitle() {
    switch (_currentPage) {
      case 0:
        return _appBarTitle = 'İsim Soyisim';
      case 1:
        return _appBarTitle = 'E-Mail';
      case 2:
        return _appBarTitle = 'Telefon';
      case 3:
        return _appBarTitle = 'Kullanıcı Adı';
      case 4:
        return _appBarTitle = 'Şifre';
      case 5:
        return _appBarTitle = 'Loczy\'e Hoş Geldin';
      default:
        return _appBarTitle = 'İsim Soyisim';
    }
  }

  Widget _buildNamePage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('İsim ve soyisminizi giriniz',
                style: TextStyle(fontSize: 16)),
          ),
          SizedBox(height: 10),
          TextField(
            controller: isimController,
            decoration: InputDecoration(labelText: 'İsim'),
            onChanged: (value) {
              if (RegExp(r'[^a-zA-Z\s]').hasMatch(value)) {
                setState(() {
                  _registerError = 'İsim sadece harflerden oluşmalıdır!';
                });
              } else {
                setState(() {
                  _registerError = isimController.text.isEmpty || soyisimController.text.isEmpty
                      ? 'Lütfen tüm alanları doldurun!'
                      : '';
                });
              }
            },
          ),
          SizedBox(height: 10),
          TextField(
            controller: soyisimController,
            decoration: InputDecoration(labelText: 'Soyisim'),
            onChanged: (value) {
              if (RegExp(r'[^a-zA-Z\s]').hasMatch(value)) {
                setState(() {
                  _registerError = 'Soyisim sadece harflerden oluşmalıdır!';
                });
              } else {
                setState(() {
                  _registerError = isimController.text.isEmpty || soyisimController.text.isEmpty
                      ? 'Lütfen tüm alanları doldurun!'
                      : '';
                });
              }
            },
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD06100),
                  foregroundColor: const Color(0xFFF2E9E9),
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Geri'),
              ),
              ElevatedButton(
                onPressed: _registerError.isNotEmpty
                    ? null
                    : () {
                        if (isimController.text.isNotEmpty &&
                            soyisimController.text.isNotEmpty) {
                          _nextPage();
                        } else {
                          setState(() {
                            _registerError = 'Lütfen tüm alanları doldurun!';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD06100),
                  foregroundColor: const Color(0xFFF2E9E9),
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Devam Et'),
              ),
            ],
          ),
          SizedBox(height: 20),
          if (_registerError.isNotEmpty)
            Text(_registerError, style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildEmailPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('E-Mail adresinizi giriniz',
                style: TextStyle(fontSize: 16)),
          ),
          SizedBox(height: 10),
          TextField(
            controller: mailController,
            decoration: InputDecoration(labelText: 'E-Mail'),
            keyboardType: TextInputType.emailAddress,
            onChanged: (value) {
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                setState(() {
                  _registerError = 'Geçerli bir e-posta adresi giriniz!';
                });
              } else {
                setState(() {
                  _registerError = '';
                });
              }
            },
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _previousPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD06100),
                  foregroundColor: const Color(0xFFF2E9E9),
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Geri'),
              ),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () async {
                        if (mailController.text.isEmpty) {
                          setState(() {
                            _registerError = 'Lütfen tüm alanları doldurun!';
                          });
                        } else if (_registerError.isEmpty) {
                          await _checkIfExists('mail', mailController.text);
                          if (mailController.text.isNotEmpty &&
                              _registerError.isEmpty) {
                            _nextPage();
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD06100),
                        foregroundColor: const Color(0xFFF2E9E9),
                        padding:
                            EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Devam Et'),
                    ),
            ],
          ),
          SizedBox(height: 20),
          if (_registerError.isNotEmpty)
            Text(_registerError, style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildPhonePage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Telefon numaranızı giriniz',
                style: TextStyle(fontSize: 16)),
          ),
          SizedBox(height: 10),
          TextField(
            controller: numberController,
            decoration: InputDecoration(labelText: 'Telefon'),
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
              TextInputFormatter.withFunction((oldValue, newValue) {
                if (newValue.text.length > 11) {
                  return oldValue;
                }
                String newText = newValue.text;
                if (newText.length >= 1 && newText[0] != '0') {
                  newText = '0' + newText;
                }
                if (newText.length > 1 && newText.length <= 4) {
                  newText = '0 (${newText.substring(1)}';
                } else if (newText.length > 4 && newText.length <= 7) {
                  newText =
                      '0 (${newText.substring(1, 4)}) ${newText.substring(4)}';
                } else if (newText.length > 7 && newText.length <= 9) {
                  newText =
                      '0 (${newText.substring(1, 4)}) ${newText.substring(4, 7)} ${newText.substring(7)}';
                } else if (newText.length > 9) {
                  newText =
                      '0 (${newText.substring(1, 4)}) ${newText.substring(4, 7)} ${newText.substring(7, 9)} ${newText.substring(9)}';
                }
                return newValue.copyWith(
                  text: newText,
                  selection: TextSelection.collapsed(offset: newText.length),
                );
              }),
            ],
            onChanged: (value) {
              String formattedNumber = value.replaceAll(RegExp(r'\D'), '');
              if (formattedNumber.isEmpty || formattedNumber.length != 11) {
                setState(() {
                  _registerError = 'Lütfen geçerli bir telefon numarası giriniz!';
                });
              } else {
                setState(() {
                  _registerError = '';
                });
              }
            },
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _previousPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD06100),
                  foregroundColor: const Color(0xFFF2E9E9),
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Geri'),
              ),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () async {
                        if (numberController.text.isEmpty) {
                          setState(() {
                            _registerError = 'Lütfen tüm alanları doldurun!';
                          });
                        } else if (_registerError.isEmpty) {
                          String formattedNumber =
                              numberController.text.replaceAll(RegExp(r'\D'), '');
                          await _checkIfExists('number', formattedNumber);
                          if (formattedNumber.isNotEmpty &&
                              formattedNumber.length == 11 &&
                              _registerError.isEmpty) {
                            numberController.text = formattedNumber;
                            _nextPage();
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD06100),
                        foregroundColor: const Color(0xFFF2E9E9),
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Devam Et'),
                    ),
            ],
          ),
          SizedBox(height: 20),
          if (_registerError.isNotEmpty)
            Text(_registerError, style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildUsernamePage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Kullanıcı adınızı giriniz',
                style: TextStyle(fontSize: 16)),
          ),
          SizedBox(height: 10),
          TextField(
            controller: nicknameController,
            decoration: InputDecoration(labelText: 'Kullanıcı Adı'),
            onChanged: (value) {
              if (value.length < 4 || value.length > 30) {
                setState(() {
                  _registerError =
                      'Kullanıcı adı 4 ile 30 karakter arasında olmalıdır!';
                });
              } else if (RegExp(r'^[0-9]+$').hasMatch(value)) {
                setState(() {
                  _registerError = 'Kullanıcı adı sadece sayıdan oluşamaz!';
                });
              } else if (RegExp(r'[çğıöşüÇĞİÖŞÜ]').hasMatch(value)) {
                setState(() {
                  _registerError =
                      'Kullanıcı adı Türkçe karakter içermemelidir!';
                });
              } else if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(value)) {
                setState(() {
                  _registerError =
                      'Kullanıcı adı sadece harf, rakam, _ ve . içerebilir!';
                });
              } else {
                setState(() {
                  _registerError = '';
                });
              }
            },
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _previousPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD06100),
                  foregroundColor: const Color(0xFFF2E9E9),
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Geri'),
              ),
              _isLoading
                  ? CircularProgressIndicator()
                  :ElevatedButton(
                onPressed:  _registerError.isNotEmpty
                          ? null
                          : () async {
                  await _checkIfExists('nickname', nicknameController.text);
                  if (nicknameController.text.isNotEmpty &&
                      _registerError.isEmpty) {
                    _nextPage();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD06100),
                  foregroundColor: const Color(0xFFF2E9E9),
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Devam Et'),
              ),
            ],
          ),
          SizedBox(height: 20),
          if (_registerError.isNotEmpty)
            Text(_registerError, style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildPasswordPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Şifrenizi giriniz', style: TextStyle(fontSize: 16)),
          ),
          SizedBox(height: 10),
          TextField(
            controller: passwordController,
            decoration: InputDecoration(labelText: 'Şifre'),
            obscureText: true,
            onChanged: (value) {
              String password = value;
              if (password.isEmpty) {
                setState(() {
                  _registerError = 'Lütfen tüm alanları doldurun!';
                });
              } else if (password.length < 8 || password.length > 20) {
                setState(() {
                  _registerError =
                      'Şifre 8 ila 20 karakter uzunluğunda olmalıdır!';
                });
              } else if (!RegExp(r'^(?=.*[A-Z])(?=.*[!@#\$&*~]).+$')
                  .hasMatch(password)) {
                setState(() {
                  _registerError =
                      'Şifre en az bir büyük harf ve bir sembol içermelidir!';
                });
              } else if (RegExp(r'^[0-9]+$').hasMatch(password)) {
                setState(() {
                  _registerError = 'Şifre sadece sayı içermemelidir!';
                });
              } else {
                setState(() {
                  _registerError = '';
                });
              }
            },
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _previousPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD06100),
                  foregroundColor: const Color(0xFFF2E9E9),
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Geri'),
              ),
              _isRegistering
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _registerError.isNotEmpty
                          ? null
                          : () async {
                              String password = passwordController.text;
                              String hashedPassword =
                                  base64Encode(utf8.encode(password));
                              passwordController.text = hashedPassword;

                              setState(() {
                                _isRegistering = true;
                              });

                              await _register();

                              setState(() {
                                _isRegistering = false;
                              });

                              if (_registerError.isEmpty) {
                                _nextPage();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD06100),
                        foregroundColor: const Color(0xFFF2E9E9),
                        padding:
                            EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Devam Et'),
                    ),
            ],
          ),
          SizedBox(height: 20),
          if (_registerError.isNotEmpty)
            Text(_registerError, style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildSummaryPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green, size: 100),
          SizedBox(height: 20),
          Text(
            'Loczy\'e Hoş Geldin ${isimController.text} ${soyisimController.text}!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          Text(
            'Şimdi bilgilerin ile hesabına giriş yapabilirsin.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD06100),
              foregroundColor: const Color(0xFFF2E9E9),
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Giriş Yap'),
          ),
        ],
      ),
    );
  }
}

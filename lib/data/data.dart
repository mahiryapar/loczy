import 'package:shared_preferences/shared_preferences.dart';

Future<void> saveLoginState(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('userId', userId);
}
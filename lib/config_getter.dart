import 'dart:convert';
import 'package:flutter/services.dart';

class ConfigLoader {
  static Map<String, dynamic>? _config;

  /// JSON dosyasını yükler
  static Future<void> loadConfig() async {
    final String jsonString = await rootBundle.loadString('assets/config.json');
    _config = jsonDecode(jsonString);
  }

  /// API URL'yi getir
  static String get apiUrl {
    return _config?['api_url'] ?? 'http://default-url.com';
  }

  /// Bearer Token'ı getir
  static String get bearerToken {
    return _config?['bearer_token'] ?? '';
  }


  static String get defaultProfilePhoto {
    return _config?['default_pp'] ?? '';
  }

  static String get vm_ip {
    return _config?['vm_ip'] ?? '';
  }
}
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiConfig {
  static const _override = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static String get registracija => '$baseUrl/api/registracija/';
  static String get prijava => '$baseUrl/api/prijava/';
  static String get osvjeziToken => '$baseUrl/api/token/osvjezi/';
  static String get ja => '$baseUrl/api/ja/';
  static String get odjava => '$baseUrl/api/odjava/';
  static String get pregled => '$baseUrl/api/pregled/';
  static String get racuni => '$baseUrl/api/racuni/';
  static String get kategorije => '$baseUrl/api/kategorije/';
  static String kategorijaId(int id) => '$baseUrl/api/kategorije/$id/';
  static String get budzeti => '$baseUrl/api/budzeti/';
  static String budzetId(int id) => '$baseUrl/api/budzeti/$id/';
  static String racunId(int id) => '$baseUrl/api/racuni/$id/';
  static String get transakcije => '$baseUrl/api/transakcije/';
}
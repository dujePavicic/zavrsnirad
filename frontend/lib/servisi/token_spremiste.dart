import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenSpremiste {
  static const _kljucAccess = 'access_token';
  static const _kljucRefresh = 'refresh_token';

  final FlutterSecureStorage _spremiste = const FlutterSecureStorage();

  Future<void> spremiTokene({
    required String access,
    required String refresh,
  }) async {
    await _spremiste.write(key: _kljucAccess, value: access);
    await _spremiste.write(key: _kljucRefresh, value: refresh);
  }

  Future<void> spremiAccess(String access) async {
    await _spremiste.write(key: _kljucAccess, value: access);
  }

  Future<String?> dohvatiAccess() => _spremiste.read(key: _kljucAccess);

  Future<String?> dohvatiRefresh() => _spremiste.read(key: _kljucRefresh);

  Future<void> obrisiTokene() async {
    await _spremiste.delete(key: _kljucAccess);
    await _spremiste.delete(key: _kljucRefresh);
  }
}
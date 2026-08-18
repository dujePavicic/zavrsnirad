import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import 'token_spremiste.dart';

class SesijaIstekla implements Exception {
  @override
  String toString() => 'Sesija je istekla. Prijavi se ponovno.';
}

class ApiKlijent {
  ApiKlijent._();

  static final ApiKlijent _instanca = ApiKlijent._();

  factory ApiKlijent() => _instanca;

  final TokenSpremiste _tokeni = TokenSpremiste();

  Future<bool>? _osvjezavanjeUTijeku;

  Future<http.Response> posalji(
    String metoda,
    String putanja, {
    Map<String, dynamic>? tijelo,
    Map<String, String>? upit,
  }) async {
    var odgovor = await _izvrsi(
      metoda,
      putanja,
      tijelo: tijelo,
      upit: upit,
    );

    if (odgovor.statusCode == 401) {
      final uspjelo = await osvjeziToken();

      if (!uspjelo) {
        await _tokeni.obrisiTokene();
        throw SesijaIstekla();
      }

      odgovor = await _izvrsi(
        metoda,
        putanja,
        tijelo: tijelo,
        upit: upit,
      );
    }

    return odgovor;
  }

  Future<http.Response> _izvrsi(
    String metoda,
    String putanja, {
    Map<String, dynamic>? tijelo,
    Map<String, String>? upit,
  }) async {
    final access = await _tokeni.dohvatiAccess();

    if (access == null) {
      throw SesijaIstekla();
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}$putanja').replace(
      queryParameters: upit == null || upit.isEmpty ? null : upit,
    );

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $access',
    };

    final body = tijelo == null ? null : jsonEncode(tijelo);

    switch (metoda.toUpperCase()) {
      case 'GET':
        return http.get(uri, headers: headers);
      case 'POST':
        return http.post(uri, headers: headers, body: body);
      case 'PATCH':
        return http.patch(uri, headers: headers, body: body);
      case 'PUT':
        return http.put(uri, headers: headers, body: body);
      case 'DELETE':
        return http.delete(uri, headers: headers, body: body);
      default:
        throw ArgumentError('Nepoznata HTTP metoda: $metoda');
    }
  }

  Future<bool> osvjeziToken() {
    return _osvjezavanjeUTijeku ??=
        _pokreniOsvjezavanje().whenComplete(() {
      _osvjezavanjeUTijeku = null;
    });
  }

  Future<bool> _pokreniOsvjezavanje() async {
    final refresh = await _tokeni.dohvatiRefresh();

    if (refresh == null) return false;

    try {
      final odgovor = await http.post(
        Uri.parse(ApiConfig.osvjeziToken),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'refresh': refresh,
        }),
      );

      if (odgovor.statusCode != 200) return false;

      final tijelo = jsonDecode(
        utf8.decode(odgovor.bodyBytes),
      ) as Map<String, dynamic>;

      final noviAccess = tijelo['access'] as String?;
      final noviRefresh = tijelo['refresh'] as String?;

      if (noviAccess == null || noviAccess.isEmpty) {
        return false;
      }

      // Backend koristi rotaciju refresh tokena.
      await _tokeni.spremiTokene(
        access: noviAccess,
        refresh: noviRefresh ?? refresh,
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> trenutniAccess() async {
    final access = await _tokeni.dohvatiAccess();

    if (access == null) {
      throw SesijaIstekla();
    }

    return access;
  }

  Future<void> obrisiTokene() => _tokeni.obrisiTokene();
}

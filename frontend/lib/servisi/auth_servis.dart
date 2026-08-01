import 'dart:convert';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../modeli/korisnik.dart';
import 'token_spremiste.dart';

/// Iznimka koja nosi čitljivu poruku o grešci prema korisniku.
class AuthGreska implements Exception {
  final String poruka;
  AuthGreska(this.poruka);

  @override
  String toString() => poruka;
}

class AuthServis {
  final TokenSpremiste _tokenSpremiste = TokenSpremiste();

  /// Registracija novog korisnika. Vraća kreiranog [Korisnik].
  Future<Korisnik> registriraj({
    required String email,
    required String korisnickoIme,
    required String ime,
    required String prezime,
    required String lozinka,
  }) async {
    final odgovor = await http.post(
      Uri.parse(ApiConfig.registracija),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'korisnicko_ime': korisnickoIme,
        'ime': ime,
        'prezime': prezime,
        'lozinka': lozinka,
      }),
    );

    if (odgovor.statusCode == 201) {
      final tijelo = jsonDecode(utf8.decode(odgovor.bodyBytes)) as Map<String, dynamic>;
      return Korisnik.izJsona(tijelo);
    } else {
      throw AuthGreska(_izvuciGresku(odgovor));
    }
  }

  /// Prijava. Ako uspije, sprema access i refresh token u sigurno spremište.
  Future<void> prijavi({
    required String identifikator,
    required String lozinka,
  }) async {
    final odgovor = await http.post(
      Uri.parse(ApiConfig.prijava),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifikator': identifikator,
        'lozinka': lozinka,
      }),
    );

    if (odgovor.statusCode == 200) {
      final tijelo = jsonDecode(utf8.decode(odgovor.bodyBytes)) as Map<String, dynamic>;
      await _tokenSpremiste.spremiTokene(
        access: tijelo['access'] as String,
        refresh: tijelo['refresh'] as String,
      );
    } else {
      throw AuthGreska(_izvuciGresku(odgovor));
    }
  }

  /// Osvježava access token pomoću spremljenog refresh tokena.
  Future<void> osvjeziToken() async {
    final refresh = await _tokenSpremiste.dohvatiRefresh();
    if (refresh == null) {
      throw AuthGreska('Nema spremljenog tokena. Prijavi se ponovno.');
    }

    final odgovor = await http.post(
      Uri.parse(ApiConfig.osvjeziToken),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refresh}),
    );

    if (odgovor.statusCode == 200) {
      final tijelo = jsonDecode(utf8.decode(odgovor.bodyBytes)) as Map<String, dynamic>;
      await _tokenSpremiste.spremiAccess(tijelo['access'] as String);
    } else {
      throw AuthGreska('Sesija je istekla. Prijavi se ponovno.');
    }
  }

  /// Odjava — briše spremljene tokene.
  Future<void> odjavi() async {
    await _tokenSpremiste.obrisiTokene();
  }

  /// Pretvara odgovor s greškom u čitljivu poruku.
  String _izvuciGresku(http.Response odgovor) {
    try {
      final tijelo = jsonDecode(utf8.decode(odgovor.bodyBytes)) as Map<String, dynamic>;
      // DRF obično vrati {"detail": "..."} ili {"polje": ["poruka"], ...}
      if (tijelo.containsKey('detail')) {
        return tijelo['detail'].toString();
      }
      final prvo = tijelo.values.first;
      if (prvo is List && prvo.isNotEmpty) {
        return prvo.first.toString();
      }
      return prvo.toString();
    } catch (_) {
      return 'Došlo je do greške (${odgovor.statusCode}).';
    }
  }
}
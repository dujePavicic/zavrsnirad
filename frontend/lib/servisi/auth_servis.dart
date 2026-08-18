import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../modeli/korisnik.dart';
import 'api_klijent.dart';
import 'token_spremiste.dart';

class AuthGreska implements Exception {
  final String poruka;

  AuthGreska(this.poruka);

  @override
  String toString() => poruka;
}

class AuthServis {
  final TokenSpremiste _tokenSpremiste =
      TokenSpremiste();

  final ApiKlijent _api = ApiKlijent();

  Future<Korisnik> registriraj({
    required String email,
    required String korisnickoIme,
    required String ime,
    required String prezime,
    required String lozinka,
  }) async {
    final odgovor = await http.post(
      Uri.parse(ApiConfig.registracija),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'korisnicko_ime': korisnickoIme,
        'ime': ime,
        'prezime': prezime,
        'lozinka': lozinka,
      }),
    );

    if (odgovor.statusCode == 201) {
      final tijelo = jsonDecode(
        utf8.decode(odgovor.bodyBytes),
      ) as Map<String, dynamic>;

      return Korisnik.izJsona(tijelo);
    }

    throw AuthGreska(_izvuciGresku(odgovor));
  }

  /// Prijava nema access token pa namjerno ne ide kroz ApiKlijent.
  Future<void> prijavi({
    required String identifikator,
    required String lozinka,
  }) async {
    final odgovor = await http.post(
      Uri.parse(ApiConfig.prijava),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'identifikator': identifikator,
        'lozinka': lozinka,
      }),
    );

    if (odgovor.statusCode == 200) {
      final tijelo = jsonDecode(
        utf8.decode(odgovor.bodyBytes),
      ) as Map<String, dynamic>;

      await _tokenSpremiste.spremiTokene(
        access: tijelo['access'] as String,
        refresh: tijelo['refresh'] as String,
      );

      return;
    }

    if (odgovor.statusCode == 429) {
      throw AuthGreska(
        'Previše pokušaja. Pokušaj ponovno za koju minutu.',
      );
    }

    throw AuthGreska(_izvuciGresku(odgovor));
  }

  Future<void> osvjeziToken() async {
    final uspjelo = await _api.osvjeziToken();

    if (!uspjelo) {
      await _tokenSpremiste.obrisiTokene();

      throw AuthGreska(
        'Sesija je istekla. Prijavi se ponovno.',
      );
    }
  }

  Future<Korisnik> dohvatiJa() async {
    final odgovor = await _api.posalji(
      'GET',
      '/api/ja/',
    );

    if (odgovor.statusCode == 200) {
      final tijelo = jsonDecode(
        utf8.decode(odgovor.bodyBytes),
      ) as Map<String, dynamic>;

      return Korisnik.izJsona(tijelo);
    }

    throw AuthGreska(
      _izvuciGresku(odgovor),
    );
  }

  Future<Korisnik> azurirajProfil({
    required String ime,
    required String prezime,
    required String korisnickoIme,
    Uint8List? slikaBytes,
    String? nazivSlike,
  }) async {
    Future<http.Response> posaljiMultipart() async {
      final access = await _api.trenutniAccess();

      final zahtjev = http.MultipartRequest(
        'PATCH',
        Uri.parse(ApiConfig.ja),
      );

      zahtjev.headers['Authorization'] =
          'Bearer $access';

      zahtjev.fields['ime'] = ime;
      zahtjev.fields['prezime'] = prezime;
      zahtjev.fields['korisnicko_ime'] =
          korisnickoIme;

      if (slikaBytes != null) {
        zahtjev.files.add(
          http.MultipartFile.fromBytes(
            'profilna_slika',
            slikaBytes,
            filename:
                nazivSlike ?? 'profilna_slika.jpg',
          ),
        );
      }

      final poslano = await zahtjev.send();

      return http.Response.fromStream(poslano);
    }

    var odgovor = await posaljiMultipart();

    if (odgovor.statusCode == 401) {
      final uspjelo = await _api.osvjeziToken();

      if (!uspjelo) {
        await _tokenSpremiste.obrisiTokene();

        throw AuthGreska(
          'Sesija je istekla. Prijavi se ponovno.',
        );
      }

      odgovor = await posaljiMultipart();
    }

    if (odgovor.statusCode == 200) {
      final tijelo = jsonDecode(
        utf8.decode(odgovor.bodyBytes),
      ) as Map<String, dynamic>;

      return Korisnik.izJsona(tijelo);
    }

    throw AuthGreska(
      _izvuciGresku(odgovor),
    );
  }

  Future<Korisnik> azurirajPostavkeObavijesti({
    required bool obavijestiGarancije,
    required int podsjetnikGarancijeDana,
  }) async {
    if (podsjetnikGarancijeDana < 1 ||
        podsjetnikGarancijeDana > 365) {
      throw AuthGreska(
        'Broj dana za podsjetnik mora biti između 1 i 365.',
      );
    }

    final odgovor = await _api.posalji(
      'PATCH',
      '/api/ja/',
      tijelo: {
        'obavijesti_garancije': obavijestiGarancije,
        'podsjetnik_garancije_dana': podsjetnikGarancijeDana,
      },
    );

    if (odgovor.statusCode == 200) {
      final tijelo = jsonDecode(
        utf8.decode(odgovor.bodyBytes),
      ) as Map<String, dynamic>;

      return Korisnik.izJsona(tijelo);
    }

    throw AuthGreska(_izvuciGresku(odgovor));
  }

  Future<void> odjavi() async {
    final refresh =
        await _tokenSpremiste.dohvatiRefresh();

    final access =
        await _tokenSpremiste.dohvatiAccess();

    if (refresh != null) {
      try {
        await http.post(
          Uri.parse(ApiConfig.odjava),
          headers: {
            'Content-Type': 'application/json',
            if (access != null)
              'Authorization': 'Bearer $access',
          },
          body: jsonEncode({
            'refresh': refresh,
          }),
        );
      } catch (_) {
      }
    }

    await _tokenSpremiste.obrisiTokene();
  }

  String _izvuciGresku(
    http.Response odgovor,
  ) {
    if (odgovor.statusCode == 429) {
      return 'Previše pokušaja. Pokušaj ponovno za koju minutu.';
    }

    try {
      final tijelo = jsonDecode(
        utf8.decode(odgovor.bodyBytes),
      ) as Map<String, dynamic>;

      if (tijelo.containsKey('detail')) {
        return tijelo['detail'].toString();
      }

      if (tijelo.isNotEmpty) {
        final prvo = tijelo.values.first;

        if (prvo is List && prvo.isNotEmpty) {
          return prvo.first.toString();
        }

        return prvo.toString();
      }
    } catch (_) {}

    return 'Došlo je do greške (${odgovor.statusCode}).';
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../modeli/racun.dart';
import 'api_klijent.dart';

/// Dohvaća, dodaje i briše račune iz arhive.
class RacunServis {
  final ApiKlijent _api = ApiKlijent();

  Future<Map<String, dynamic>> analizirajRacun(
    String prepoznatiTekst,
  ) async {
    final odgovor = await _api.posalji(
      'POST',
      '/api/racuni/analiziraj/',
      tijelo: {
        'prepoznati_tekst': prepoznatiTekst,
      },
    );

    if (odgovor.statusCode >= 200 &&
        odgovor.statusCode < 300) {
      return jsonDecode(
        utf8.decode(odgovor.bodyBytes),
      ) as Map<String, dynamic>;
    }

    throw Exception(_poruka(odgovor));
  }

  Future<List<Racun>> dohvatiRacune({
    String? search,
    String? trgovina,
    int? kategorija,
    String? datumOd,
    String? datumDo,
  }) async {
    final parametri = <String, String>{};

    if (search != null) parametri['search'] = search;
    if (trgovina != null) parametri['trgovina'] = trgovina;
    if (kategorija != null) {
      parametri['kategorija'] = '$kategorija';
    }
    if (datumOd != null) parametri['datum_od'] = datumOd;
    if (datumDo != null) parametri['datum_do'] = datumDo;

    final odgovor = await _api.posalji(
      'GET',
      '/api/racuni/',
      upit: parametri.isEmpty ? null : parametri,
    );

    if (odgovor.statusCode == 200) {
      final tijelo = jsonDecode(
        utf8.decode(odgovor.bodyBytes),
      ) as Map<String, dynamic>;

      final rezultati =
          (tijelo['results'] as List? ?? []);

      return rezultati
          .map(
            (e) => Racun.izJsona(
              e as Map<String, dynamic>,
            ),
          )
          .toList();
    }

    throw Exception(_poruka(odgovor));
  }

  /// Dodaje račun postojećoj transakciji.
  ///
  /// Multipart se mora posebno ponoviti nakon refresha jer već poslani
  /// MultipartRequest nije moguće ponovno koristiti.
  Future<Racun> dodajPostojecojTransakciji({
    required int transakcijaId,
    required Uint8List slikaBytes,
    required String nazivSlike,
    String trgovina = '',
    String prepoznatiTekst = '',
  }) async {
    Future<http.Response> posaljiMultipart() async {
      final access = await _api.trenutniAccess();

      final zahtjev = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.racuni),
      );

      zahtjev.headers['Authorization'] =
          'Bearer $access';

      zahtjev.fields['transakcija_id'] =
          '$transakcijaId';
      zahtjev.fields['trgovina'] = trgovina;
      zahtjev.fields['prepoznati_tekst'] =
          prepoznatiTekst;

      zahtjev.files.add(
        http.MultipartFile.fromBytes(
          'slika',
          slikaBytes,
          filename: nazivSlike,
        ),
      );

      final poslano = await zahtjev.send();

      return http.Response.fromStream(poslano);
    }

    var odgovor = await posaljiMultipart();

    if (odgovor.statusCode == 401) {
      final uspjelo = await _api.osvjeziToken();

      if (!uspjelo) {
        await _api.obrisiTokene();
        throw SesijaIstekla();
      }

      // Novi MultipartRequest s novim access tokenom.
      odgovor = await posaljiMultipart();
    }

    if (odgovor.statusCode == 201) {
      final tijelo = jsonDecode(
        utf8.decode(odgovor.bodyBytes),
      ) as Map<String, dynamic>;

      return Racun.izJsona(tijelo);
    }

    throw Exception(_poruka(odgovor));
  }

  Future<void> obrisi(int id) async {
    final odgovor = await _api.posalji(
      'DELETE',
      '/api/racuni/$id/',
    );

    if (odgovor.statusCode == 204) return;

    throw Exception(_poruka(odgovor));
  }

  String _poruka(http.Response odgovor) {
    try {
      final tijelo = jsonDecode(
        utf8.decode(odgovor.bodyBytes),
      );

      if (tijelo is Map<String, dynamic>) {
        if (tijelo['detail'] != null) {
          return tijelo['detail'].toString();
        }

        for (final vrijednost in tijelo.values) {
          if (vrijednost is List &&
              vrijednost.isNotEmpty) {
            return vrijednost.first.toString();
          }

          if (vrijednost != null) {
            return vrijednost.toString();
          }
        }
      }
    } catch (_) {}

    if (odgovor.statusCode == 429) {
      return 'Previše zahtjeva. Pokušaj ponovno za koju minutu.';
    }

    return 'Greška (${odgovor.statusCode}).';
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../modeli/transakcija.dart';
import 'api_klijent.dart';

/// Dohvaća, sprema, uređuje i briše transakcije.
class TransakcijaServis {
  final ApiKlijent _api = ApiKlijent();

  Future<List<Transakcija>> dohvatiTransakcije({
    String? tip,
    int? kategorija,
    String? datumOd,
    String? datumDo,
    int? godina,
    int? mjesec,
    String? search,
    bool? imaRacun,
  }) async {
    final parametri = <String, String>{};

    if (tip != null) parametri['tip'] = tip;
    if (kategorija != null) parametri['kategorija'] = '$kategorija';
    if (datumOd != null) parametri['datum_od'] = datumOd;
    if (datumDo != null) parametri['datum_do'] = datumDo;
    if (godina != null) parametri['godina'] = '$godina';
    if (mjesec != null) parametri['mjesec'] = '$mjesec';
    if (search != null && search.trim().isNotEmpty) {
      parametri['search'] = search.trim();
    }
    if (imaRacun != null) {
      parametri['ima_racun'] = imaRacun ? 'true' : 'false';
    }

    final odgovor = await _api.posalji(
      'GET',
      '/api/transakcije/',
      upit: parametri.isEmpty ? null : parametri,
    );

    if (odgovor.statusCode == 200) {
      final tijelo = jsonDecode(
        utf8.decode(odgovor.bodyBytes),
      ) as Map<String, dynamic>;
      final rezultati = (tijelo['results'] as List? ?? []);

      return rezultati
          .map((e) => Transakcija.izJsona(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception(_poruka(odgovor));
  }

  Future<Transakcija> dodaj({
    required String tip,
    required String iznos,
    required int kategorija,
    required String datum,
    String? opis,
  }) async {
    final odgovor = await _api.posalji(
      'POST',
      '/api/transakcije/',
      tijelo: {
        'tip': tip,
        'iznos': iznos,
        'kategorija': kategorija,
        'datum': datum,
        'opis': opis ?? '',
      },
    );

    if (odgovor.statusCode == 201) {
      return Transakcija.izJsona(
        jsonDecode(utf8.decode(odgovor.bodyBytes)) as Map<String, dynamic>,
      );
    }
    throw Exception(_poruka(odgovor));
  }

  Future<Transakcija> azuriraj({
    required int id,
    required String tip,
    required String iznos,
    required int kategorija,
    required String datum,
    String? opis,
  }) async {
    final odgovor = await _api.posalji(
      'PATCH',
      '/api/transakcije/$id/',
      tijelo: {
        'tip': tip,
        'iznos': iznos,
        'kategorija': kategorija,
        'datum': datum,
        'opis': opis ?? '',
      },
    );

    if (odgovor.statusCode == 200) {
      return Transakcija.izJsona(
        jsonDecode(utf8.decode(odgovor.bodyBytes)) as Map<String, dynamic>,
      );
    }
    throw Exception(_poruka(odgovor));
  }

  Future<void> obrisi(int id) async {
    final odgovor = await _api.posalji(
      'DELETE',
      '/api/transakcije/$id/',
    );
    if (odgovor.statusCode == 204) return;
    throw Exception(_poruka(odgovor));
  }

  String _poruka(http.Response odgovor) {
    try {
      final tijelo = jsonDecode(utf8.decode(odgovor.bodyBytes));
      if (tijelo is Map<String, dynamic>) {
        if (tijelo['detail'] != null) return tijelo['detail'].toString();
        for (final vrijednost in tijelo.values) {
          if (vrijednost is List && vrijednost.isNotEmpty) {
            return vrijednost.first.toString();
          }
          if (vrijednost != null) return vrijednost.toString();
        }
      }
    } catch (_) {}
    return 'Greška (${odgovor.statusCode}).';
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../modeli/transakcija.dart';
import 'token_spremiste.dart';

/// Dohvaća, sprema, uređuje i briše transakcije.
class TransakcijaServis {
  final TokenSpremiste _tokenSpremiste = TokenSpremiste();

  Future<String> _access() async {
    final a = await _tokenSpremiste.dohvatiAccess();
    if (a == null) throw Exception('Nisi prijavljen.');
    return a;
  }

  Future<List<Transakcija>> dohvatiTransakcije({
    String? tip,
    int? kategorija,
    String? datumOd,
    String? datumDo,
    String? search,
    bool? imaRacun,
  }) async {
    final access = await _access();

    final parametri = <String, String>{};

    if (tip != null) parametri['tip'] = tip;
    if (kategorija != null) parametri['kategorija'] = '$kategorija';
    if (datumOd != null) parametri['datum_od'] = datumOd;
    if (datumDo != null) parametri['datum_do'] = datumDo;
    if (search != null && search.trim().isNotEmpty) {
      parametri['search'] = search.trim();
    }
    if (imaRacun != null) {
      parametri['ima_racun'] = imaRacun ? 'true' : 'false';
    }

    final uri = Uri.parse(ApiConfig.transakcije).replace(
      queryParameters: parametri.isEmpty ? null : parametri,
    );

    final odgovor = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $access'},
    );

    if (odgovor.statusCode == 200) {
      final tijelo =
          jsonDecode(utf8.decode(odgovor.bodyBytes)) as Map<String, dynamic>;
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
    final access = await _access();

    final odgovor = await http.post(
      Uri.parse(ApiConfig.transakcije),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $access',
      },
      body: jsonEncode({
        'tip': tip,
        'iznos': iznos,
        'kategorija': kategorija,
        'datum': datum,
        'opis': opis ?? '',
      }),
    );

    if (odgovor.statusCode == 201) {
      final tijelo =
          jsonDecode(utf8.decode(odgovor.bodyBytes)) as Map<String, dynamic>;
      return Transakcija.izJsona(tijelo);
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
    final access = await _access();

    final odgovor = await http.patch(
      Uri.parse(ApiConfig.transakcijaId(id)),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $access',
      },
      body: jsonEncode({
        'tip': tip,
        'iznos': iznos,
        'kategorija': kategorija,
        'datum': datum,
        'opis': opis ?? '',
      }),
    );

    if (odgovor.statusCode == 200) {
      final tijelo =
          jsonDecode(utf8.decode(odgovor.bodyBytes)) as Map<String, dynamic>;
      return Transakcija.izJsona(tijelo);
    }

    throw Exception(_poruka(odgovor));
  }

  Future<void> obrisi(int id) async {
    final access = await _access();

    final odgovor = await http.delete(
      Uri.parse(ApiConfig.transakcijaId(id)),
      headers: {'Authorization': 'Bearer $access'},
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

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../modeli/transakcija.dart';
import 'token_spremiste.dart';

/// Dohvaća i sprema transakcije (/api/transakcije/).
class TransakcijaServis {
  final TokenSpremiste _tokenSpremiste = TokenSpremiste();

  Future<String> _access() async {
    final a = await _tokenSpremiste.dohvatiAccess();
    if (a == null) throw Exception('Nisi prijavljen.');
    return a;
  }

  Future<List<Transakcija>> dohvatiTransakcije({
    String? tip,
    String? datumOd,
    String? datumDo,
  }) async {
    final access = await _access();
    final parametri = <String, String>{};
    if (tip != null) parametri['tip'] = tip;
    if (datumOd != null) parametri['datum_od'] = datumOd;
    if (datumDo != null) parametri['datum_do'] = datumDo;

    final uri = Uri.parse(ApiConfig.transakcije)
        .replace(queryParameters: parametri.isEmpty ? null : parametri);
    final odgovor =
        await http.get(uri, headers: {'Authorization': 'Bearer $access'});

    if (odgovor.statusCode == 200) {
      final tijelo =
          jsonDecode(utf8.decode(odgovor.bodyBytes)) as Map<String, dynamic>;
      final rezultati = (tijelo['results'] as List? ?? []);
      return rezultati
          .map((e) => Transakcija.izJsona(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Ne mogu dohvatiti transakcije (${odgovor.statusCode}).');
  }

  Future<void> dodaj({
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
    if (odgovor.statusCode == 201) return;
    throw Exception(_poruka(odgovor));
  }

  String _poruka(http.Response o) {
    try {
      final t = jsonDecode(utf8.decode(o.bodyBytes)) as Map<String, dynamic>;
      final prvo = t.values.first;
      if (prvo is List && prvo.isNotEmpty) return prvo.first.toString();
      return prvo.toString();
    } catch (_) {
      return 'Greška (${o.statusCode}).';
    }
  }
}
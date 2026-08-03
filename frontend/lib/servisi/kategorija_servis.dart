import 'dart:convert';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../modeli/kategorija.dart';
import 'token_spremiste.dart';

/// Dohvaća kategorije s /api/kategorije/ (opcionalno filtrirane po tipu).
class KategorijaServis {
  final TokenSpremiste _tokenSpremiste = TokenSpremiste();

  Future<List<Kategorija>> dohvatiKategorije({String? tip}) async {
    final access = await _tokenSpremiste.dohvatiAccess();
    if (access == null) {
      throw Exception('Nisi prijavljen.');
    }

    final parametri = <String, String>{};
    if (tip != null) parametri['tip'] = tip;

    final uri = Uri.parse(ApiConfig.kategorije)
        .replace(queryParameters: parametri.isEmpty ? null : parametri);

    final odgovor = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $access'},
    );

    if (odgovor.statusCode == 200) {
      final tijelo = jsonDecode(utf8.decode(odgovor.bodyBytes));
      // Popis je straničen → podaci su u "results".
      final rezultati = (tijelo is Map<String, dynamic>)
          ? (tijelo['results'] as List? ?? [])
          : (tijelo as List);
      return rezultati
          .map((e) => Kategorija.izJsona(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Ne mogu dohvatiti kategorije (${odgovor.statusCode}).');
    }
  }
}
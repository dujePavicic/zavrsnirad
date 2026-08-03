import 'dart:convert';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../modeli/racun.dart';
import 'token_spremiste.dart';

/// Dohvaća račune iz arhive s /api/racuni/ (uz opcionalne filtre).
class RacunServis {
  final TokenSpremiste _tokenSpremiste = TokenSpremiste();

  Future<List<Racun>> dohvatiRacune({
    String? search,
    String? trgovina,
    int? kategorija,
    String? datumOd,
    String? datumDo,
  }) async {
    final access = await _tokenSpremiste.dohvatiAccess();
    if (access == null) {
      throw Exception('Nisi prijavljen.');
    }

    final parametri = <String, String>{};
    if (search != null) parametri['search'] = search;
    if (trgovina != null) parametri['trgovina'] = trgovina;
    if (kategorija != null) parametri['kategorija'] = '$kategorija';
    if (datumOd != null) parametri['datum_od'] = datumOd;
    if (datumDo != null) parametri['datum_do'] = datumDo;

    final uri = Uri.parse(ApiConfig.racuni)
        .replace(queryParameters: parametri.isEmpty ? null : parametri);

    final odgovor = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $access'},
    );

    if (odgovor.statusCode == 200) {
      final tijelo =
          jsonDecode(utf8.decode(odgovor.bodyBytes)) as Map<String, dynamic>;
      final rezultati = (tijelo['results'] as List? ?? []);
      return rezultati
          .map((e) => Racun.izJsona(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Ne mogu dohvatiti račune (${odgovor.statusCode}).');
    }
  }
}
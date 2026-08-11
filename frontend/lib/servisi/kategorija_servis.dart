import 'dart:convert';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../modeli/kategorija.dart';
import 'token_spremiste.dart';

/// Dohvaća i mijenja kategorije preko /api/kategorije/.
class KategorijaServis {
  final TokenSpremiste _tokenSpremiste = TokenSpremiste();

  Future<String> _access() async {
    final a = await _tokenSpremiste.dohvatiAccess();
    if (a == null) throw Exception('Nisi prijavljen.');
    return a;
  }

  Future<List<Kategorija>> dohvatiKategorije({String? tip}) async {
    final access = await _access();
    final parametri = <String, String>{};
    if (tip != null) parametri['tip'] = tip;
    final uri = Uri.parse(ApiConfig.kategorije)
        .replace(queryParameters: parametri.isEmpty ? null : parametri);
    final odgovor =
        await http.get(uri, headers: {'Authorization': 'Bearer $access'});
    if (odgovor.statusCode == 200) {
      final tijelo = jsonDecode(utf8.decode(odgovor.bodyBytes));
      final rezultati = (tijelo is Map<String, dynamic>)
          ? (tijelo['results'] as List? ?? [])
          : (tijelo as List);
      return rezultati
          .map((e) => Kategorija.izJsona(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Ne mogu dohvatiti kategorije (${odgovor.statusCode}).');
  }

  Future<Kategorija> dodaj({
    required String naziv,
    required String boja,
    required String ikona,
    String tip = 'TROSAK',
  }) async {
    final access = await _access();
    final odgovor = await http.post(
      Uri.parse(ApiConfig.kategorije),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $access',
      },
      body: jsonEncode({'naziv': naziv, 'tip': tip, 'boja': boja, 'ikona': ikona}),
    );
    if (odgovor.statusCode == 201) {
      return Kategorija.izJsona(
          jsonDecode(utf8.decode(odgovor.bodyBytes)) as Map<String, dynamic>);
    }
    throw Exception(_poruka(odgovor));
  }

  Future<Kategorija> azuriraj({
    required int id,
    String? naziv,
    String? boja,
    String? ikona,
  }) async {
    final access = await _access();
    final tijelo = <String, dynamic>{};
    if (naziv != null) tijelo['naziv'] = naziv;
    if (boja != null) tijelo['boja'] = boja;
    if (ikona != null) tijelo['ikona'] = ikona;
    final odgovor = await http.patch(
      Uri.parse(ApiConfig.kategorijaId(id)),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $access',
      },
      body: jsonEncode(tijelo),
    );
    if (odgovor.statusCode == 200) {
      return Kategorija.izJsona(
          jsonDecode(utf8.decode(odgovor.bodyBytes)) as Map<String, dynamic>);
    }
    if (odgovor.statusCode == 403) {
      throw Exception('Predefinirane kategorije se ne mogu mijenjati.');
    }
    throw Exception(_poruka(odgovor));
  }

  Future<void> obrisi(int id) async {
    final access = await _access();
    final odgovor = await http.delete(
      Uri.parse(ApiConfig.kategorijaId(id)),
      headers: {'Authorization': 'Bearer $access'},
    );
    if (odgovor.statusCode == 204) return;
    if (odgovor.statusCode == 403) {
      throw Exception('Predefinirane kategorije se ne mogu obrisati.');
    }
    throw Exception('Ne mogu obrisati kategoriju (${odgovor.statusCode}).');
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
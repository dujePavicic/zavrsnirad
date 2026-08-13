import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../modeli/racun.dart';
import 'token_spremiste.dart';

/// Dohvaća, dodaje i briše račune iz arhive.
class RacunServis {
  final TokenSpremiste _tokenSpremiste = TokenSpremiste();

Future<Map<String, dynamic>> analizirajRacun(
  String prepoznatiTekst,
) async {
  final access = await _access();

  final odgovor = await http.post(
    Uri.parse('${ApiConfig.racuni}analiziraj/'),
    headers: {
      'Authorization': 'Bearer $access',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'prepoznati_tekst': prepoznatiTekst,
    }),
  );

  if (odgovor.statusCode >= 200 &&
      odgovor.statusCode < 300) {
    return jsonDecode(
      utf8.decode(odgovor.bodyBytes),
    ) as Map<String, dynamic>;
  }

  throw Exception(_poruka(odgovor));
}


  Future<String> _access() async {
    final a = await _tokenSpremiste.dohvatiAccess();
    if (a == null) throw Exception('Nisi prijavljen.');
    return a;
  }

  Future<List<Racun>> dohvatiRacune({
    String? search,
    String? trgovina,
    int? kategorija,
    String? datumOd,
    String? datumDo,
  }) async {
    final access = await _access();
    final parametri = <String, String>{};

    if (search != null) parametri['search'] = search;
    if (trgovina != null) parametri['trgovina'] = trgovina;
    if (kategorija != null) parametri['kategorija'] = '$kategorija';
    if (datumOd != null) parametri['datum_od'] = datumOd;
    if (datumDo != null) parametri['datum_do'] = datumDo;

    final uri = Uri.parse(ApiConfig.racuni).replace(
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
          .map((e) => Racun.izJsona(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception(_poruka(odgovor));
  }

  /// Dodaje račun postojećoj transakciji bez stvaranja nove transakcije.
  /// Koristi bytes kako bi radio i na Flutter Webu.
  Future<Racun> dodajPostojecojTransakciji({
    required int transakcijaId,
    required Uint8List slikaBytes,
    required String nazivSlike,
    String trgovina = '',
    String prepoznatiTekst = '',
  }) async {
    final access = await _access();

    final zahtjev = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.racuni),
    );

    zahtjev.headers['Authorization'] = 'Bearer $access';

    zahtjev.fields['transakcija_id'] = '$transakcijaId';
    zahtjev.fields['trgovina'] = trgovina;
    zahtjev.fields['prepoznati_tekst'] = prepoznatiTekst;

    zahtjev.files.add(
      http.MultipartFile.fromBytes(
        'slika',
        slikaBytes,
        filename: nazivSlike,
      ),
    );

    final poslano = await zahtjev.send();
    final odgovor = await http.Response.fromStream(poslano);

    if (odgovor.statusCode == 201) {
      final tijelo =
          jsonDecode(utf8.decode(odgovor.bodyBytes)) as Map<String, dynamic>;
      return Racun.izJsona(tijelo);
    }

    throw Exception(_poruka(odgovor));
  }

  Future<void> obrisi(int id) async {
    final access = await _access();

    final odgovor = await http.delete(
      Uri.parse(ApiConfig.racunId(id)),
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

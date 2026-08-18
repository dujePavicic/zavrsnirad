import 'dart:convert';

import '../modeli/pregled.dart';
import 'api_klijent.dart';

class PregledServis {
  final ApiKlijent _api = ApiKlijent();

  Future<Pregled> dohvatiPregled({
    int? godina,
    int? mjesec,
  }) async {
    final parametri = <String, String>{};

    if (godina != null) {
      parametri['godina'] = '$godina';
    }

    if (mjesec != null) {
      parametri['mjesec'] = '$mjesec';
    }

    final odgovor = await _api.posalji(
      'GET',
      '/api/pregled/',
      upit: parametri.isEmpty ? null : parametri,
    );

    if (odgovor.statusCode == 200) {
      final tijelo = jsonDecode(
        utf8.decode(odgovor.bodyBytes),
      ) as Map<String, dynamic>;

      return Pregled.izJsona(tijelo);
    }

    if (odgovor.statusCode == 429) {
      throw Exception(
        'Previše zahtjeva. Pokušaj ponovno za koju minutu.',
      );
    }

    throw Exception(
      'Ne mogu dohvatiti pregled (${odgovor.statusCode}).',
    );
  }
}

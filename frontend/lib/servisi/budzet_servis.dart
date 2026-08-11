import 'dart:convert';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../modeli/budzet.dart';
import 'token_spremiste.dart';

/// Dohvaća i postavlja mjesečni budžet preko /api/budzeti/.
class BudzetServis {
  final TokenSpremiste _tokenSpremiste = TokenSpremiste();

  Future<String> _access() async {
    final a = await _tokenSpremiste.dohvatiAccess();
    if (a == null) throw Exception('Nisi prijavljen.');
    return a;
  }

  /// Budžet za zadani mjesec ili null ako nije postavljen.
  Future<Budzet?> dohvatiBudzet({
    required int godina,
    required int mjesec,
  }) async {
    final access = await _access();
    final uri = Uri.parse(ApiConfig.budzeti).replace(
      queryParameters: {'godina': '$godina', 'mjesec': '$mjesec'},
    );
    final odgovor =
        await http.get(uri, headers: {'Authorization': 'Bearer $access'});
    if (odgovor.statusCode == 200) {
      final tijelo =
          jsonDecode(utf8.decode(odgovor.bodyBytes)) as Map<String, dynamic>;
      final rezultati = (tijelo['results'] as List? ?? []);
      if (rezultati.isEmpty) return null;
      return Budzet.izJsona(rezultati.first as Map<String, dynamic>);
    }
    throw Exception('Ne mogu dohvatiti budžet (${odgovor.statusCode}).');
  }

  /// Postavi budžet: ako već postoji za taj mjesec -> PATCH, inače POST.
  Future<void> postaviBudzet({
    required int godina,
    required int mjesec,
    required String iznos,
  }) async {
    final access = await _access();
    final postojeci = await dohvatiBudzet(godina: godina, mjesec: mjesec);

    if (postojeci != null) {
      final odgovor = await http.patch(
        Uri.parse(ApiConfig.budzetId(postojeci.id)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $access',
        },
        body: jsonEncode({'iznos': iznos}),
      );
      if (odgovor.statusCode == 200) return;
      throw Exception('Ne mogu spremiti budžet (${odgovor.statusCode}).');
    } else {
      final odgovor = await http.post(
        Uri.parse(ApiConfig.budzeti),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $access',
        },
        body: jsonEncode({'godina': godina, 'mjesec': mjesec, 'iznos': iznos}),
      );
      if (odgovor.statusCode == 201) return;
      throw Exception('Ne mogu spremiti budžet (${odgovor.statusCode}).');
    }
  }
}
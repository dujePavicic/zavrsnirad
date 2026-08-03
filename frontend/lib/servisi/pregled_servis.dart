import 'dart:convert';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../modeli/pregled.dart';
import 'token_spremiste.dart';

/// Dohvaća podatke za dashboard s /api/pregled/.
class PregledServis {
  final TokenSpremiste _tokenSpremiste = TokenSpremiste();

  Future<Pregled> dohvatiPregled({int? godina, int? mjesec}) async {
    final access = await _tokenSpremiste.dohvatiAccess();
    if (access == null) {
      throw Exception('Nisi prijavljen.');
    }

    // Bez parametara backend uzima tekući mjesec; s njima traži zadani.
    final parametri = <String, String>{};
    if (godina != null) parametri['godina'] = '$godina';
    if (mjesec != null) parametri['mjesec'] = '$mjesec';

    final uri = Uri.parse(ApiConfig.pregled)
        .replace(queryParameters: parametri.isEmpty ? null : parametri);

    final odgovor = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $access'},
    );

    if (odgovor.statusCode == 200) {
      final tijelo =
          jsonDecode(utf8.decode(odgovor.bodyBytes)) as Map<String, dynamic>;
      return Pregled.izJsona(tijelo);
    } else {
      throw Exception('Ne mogu dohvatiti pregled (${odgovor.statusCode}).');
    }
  }
}
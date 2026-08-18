import 'dart:convert';

import 'package:http/http.dart' as http;

import '../modeli/garancija.dart';
import 'api_klijent.dart';

class GarancijaServis {
  final ApiKlijent _api = ApiKlijent();

  Future<List<Garancija>> dohvatiGarancije({
    bool? aktivne,
    bool? istekle,
    int? istjeceZaDana,
    String? search,
    int? racun,
  }) async {
    final upit = <String, String>{};

    if (aktivne != null) upit['aktivne'] = aktivne ? 'true' : 'false';
    if (istekle != null) upit['istekle'] = istekle ? 'true' : 'false';
    if (istjeceZaDana != null) {
      upit['istjece_za_dana'] = '$istjeceZaDana';
    }
    if (search != null && search.trim().isNotEmpty) {
      upit['search'] = search.trim();
    }
    if (racun != null) upit['racun'] = '$racun';

    final odgovor = await _api.posalji(
      'GET',
      '/api/garancije/',
      upit: upit.isEmpty ? null : upit,
    );

    if (odgovor.statusCode == 200) {
      final tijelo = jsonDecode(utf8.decode(odgovor.bodyBytes));

      final List lista;
      if (tijelo is Map<String, dynamic>) {
        lista = tijelo['results'] as List? ?? const [];
      } else if (tijelo is List) {
        lista = tijelo;
      } else {
        lista = const [];
      }

      return lista
          .map((e) => Garancija.izJsona(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception(_poruka(odgovor));
  }

  Future<Garancija> dohvati(int id) async {
    final odgovor = await _api.posalji(
      'GET',
      '/api/garancije/$id/',
    );

    if (odgovor.statusCode == 200) {
      return Garancija.izJsona(
        jsonDecode(utf8.decode(odgovor.bodyBytes))
            as Map<String, dynamic>,
      );
    }

    throw Exception(_poruka(odgovor));
  }

  Future<Garancija> dodaj({
    required String nazivProizvoda,
    required String datumKupnje,
    String? datumIsteka,
    required String serijskiBroj,
    required String napomena,
    required bool obavijesti,
    int? racun,
  }) async {
    final tijelo = <String, dynamic>{
      'naziv_proizvoda': nazivProizvoda,
      'datum_kupnje': datumKupnje,
      'serijski_broj': serijskiBroj,
      'napomena': napomena,
      'obavijesti': obavijesti,
      'racun': racun,
    };

    // Kod doživotne garancije datum_isteka se uopće ne šalje.
    if (datumIsteka != null) {
      tijelo['datum_isteka'] = datumIsteka;
    }

    final odgovor = await _api.posalji(
      'POST',
      '/api/garancije/',
      tijelo: tijelo,
    );

    if (odgovor.statusCode == 201 || odgovor.statusCode == 200) {
      return Garancija.izJsona(
        jsonDecode(utf8.decode(odgovor.bodyBytes))
            as Map<String, dynamic>,
      );
    }

    throw Exception(_poruka(odgovor));
  }

  Future<Garancija> azuriraj({
    required int id,
    required String nazivProizvoda,
    required String datumKupnje,
    String? datumIsteka,
    required bool dozivotna,
    required String serijskiBroj,
    required String napomena,
    required bool obavijesti,
    int? racun,
  }) async {
    final tijelo = <String, dynamic>{
      'naziv_proizvoda': nazivProizvoda,
      'datum_kupnje': datumKupnje,
      'serijski_broj': serijskiBroj,
      'napomena': napomena,
      'obavijesti': obavijesti,
      'racun': racun,
      // Kod PATCH-a null je potreban ako postojeću garanciju
      // mijenjamo u doživotnu.
      'datum_isteka': dozivotna ? null : datumIsteka,
    };

    final odgovor = await _api.posalji(
      'PATCH',
      '/api/garancije/$id/',
      tijelo: tijelo,
    );

    if (odgovor.statusCode == 200) {
      return Garancija.izJsona(
        jsonDecode(utf8.decode(odgovor.bodyBytes))
            as Map<String, dynamic>,
      );
    }

    throw Exception(_poruka(odgovor));
  }

  Future<void> obrisi(int id) async {
    final odgovor = await _api.posalji(
      'DELETE',
      '/api/garancije/$id/',
    );

    if (odgovor.statusCode == 204) return;

    throw Exception(_poruka(odgovor));
  }

  String _poruka(http.Response odgovor) {
    try {
      final tijelo = jsonDecode(utf8.decode(odgovor.bodyBytes));

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

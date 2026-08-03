import 'transakcija.dart';

/// Jedna stavka u razdiobi po kategorijama (za donut graf i legendu).
class StavkaKategorije {
  final int kategorija;
  final String naziv;
  final String boja; // hex
  final String ikona;
  final String iznos; // npr. "24.90"
  final double postotak; // npr. 62.4

  StavkaKategorije({
    required this.kategorija,
    required this.naziv,
    required this.boja,
    required this.ikona,
    required this.iznos,
    required this.postotak,
  });

  factory StavkaKategorije.izJsona(Map<String, dynamic> json) {
    return StavkaKategorije(
      kategorija: json['kategorija'] as int,
      naziv: json['naziv']?.toString() ?? '',
      boja: json['boja']?.toString() ?? '#9E9E9E',
      ikona: json['ikona']?.toString() ?? 'category',
      iznos: json['iznos'].toString(),
      postotak: (json['postotak'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Sve brojke za dashboard (odgovor s GET /api/pregled/).
class Pregled {
  final int godina;
  final int mjesec;
  final String ukupnoPrihodi;
  final String ukupnoTroskovi;
  final String saldo;
  final String? budzet; // null ako budžet za mjesec nije postavljen
  final String? preostaloBudzeta;
  final double? postotakBudzeta;
  final int brojTransakcija;
  final List<StavkaKategorije> poKategorijama;
  final List<Transakcija> zadnjeTransakcije;

  Pregled({
    required this.godina,
    required this.mjesec,
    required this.ukupnoPrihodi,
    required this.ukupnoTroskovi,
    required this.saldo,
    required this.budzet,
    required this.preostaloBudzeta,
    required this.postotakBudzeta,
    required this.brojTransakcija,
    required this.poKategorijama,
    required this.zadnjeTransakcije,
  });

  factory Pregled.izJsona(Map<String, dynamic> json) {
    final kategorije = (json['po_kategorijama'] as List? ?? [])
        .map((e) => StavkaKategorije.izJsona(e as Map<String, dynamic>))
        .toList();
    final transakcije = (json['zadnje_transakcije'] as List? ?? [])
        .map((e) => Transakcija.izJsona(e as Map<String, dynamic>))
        .toList();

    return Pregled(
      godina: json['godina'] as int,
      mjesec: json['mjesec'] as int,
      ukupnoPrihodi: json['ukupno_prihodi'].toString(),
      ukupnoTroskovi: json['ukupno_troskovi'].toString(),
      saldo: json['saldo'].toString(),
      budzet: json['budzet']?.toString(),
      preostaloBudzeta: json['preostalo_budzeta']?.toString(),
      postotakBudzeta: (json['postotak_budzeta'] as num?)?.toDouble(),
      brojTransakcija: json['broj_transakcija'] as int? ?? 0,
      poKategorijama: kategorije,
      zadnjeTransakcije: transakcije,
    );
  }
}
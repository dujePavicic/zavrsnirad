import 'transakcija.dart';

/// Jedna stavka u razdiobi po kategorijama
/// (za donut graf, legendu i budžet po kategorijama).
class StavkaKategorije {
  final int kategorija;
  final String naziv;
  final String boja;
  final String ikona;
  final String iznos;
  final double postotak;

  // Budžet kategorije može biti null ako nije postavljen.
  final String? budzet;
  final String? preostaloBudzeta;

  StavkaKategorije({
    required this.kategorija,
    required this.naziv,
    required this.boja,
    required this.ikona,
    required this.iznos,
    required this.postotak,
    required this.budzet,
    required this.preostaloBudzeta,
  });

  factory StavkaKategorije.izJsona(Map<String, dynamic> json) {
    return StavkaKategorije(
      kategorija: json['kategorija'] as int,
      naziv: json['naziv']?.toString() ?? '',
      boja: json['boja']?.toString() ?? '#9E9E9E',
      ikona: json['ikona']?.toString() ?? 'category',
      iznos: json['iznos']?.toString() ?? '0.00',
      postotak: (json['postotak'] as num?)?.toDouble() ?? 0,
      budzet: json['budzet']?.toString(),
      preostaloBudzeta: json['preostalo_budzeta']?.toString(),
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

  // Nove vrijednosti koje backend vraća.
  final String danasPotroseno;
  final String dnevniProsjek;

  final String? budzet;
  final String? raspoloziviBudzet;
  final String? preostaloBudzeta;
  final double? postotakBudzeta;

  final String rasporedenoPoKategorijama;
  final String preostaloZaRaspodjelu;

  final int brojTransakcija;

  final List<StavkaKategorije> poKategorijama;
  final List<Transakcija> zadnjeTransakcije;

  Pregled({
    required this.godina,
    required this.mjesec,
    required this.ukupnoPrihodi,
    required this.ukupnoTroskovi,
    required this.saldo,
    required this.danasPotroseno,
    required this.dnevniProsjek,
    required this.budzet,
    required this.raspoloziviBudzet,
    required this.preostaloBudzeta,
    required this.postotakBudzeta,
    required this.rasporedenoPoKategorijama,
    required this.preostaloZaRaspodjelu,
    required this.brojTransakcija,
    required this.poKategorijama,
    required this.zadnjeTransakcije,
  });

  factory Pregled.izJsona(Map<String, dynamic> json) {
    final kategorije = (json['po_kategorijama'] as List? ?? [])
        .map(
          (e) => StavkaKategorije.izJsona(
            e as Map<String, dynamic>,
          ),
        )
        .toList();

    final transakcije = (json['zadnje_transakcije'] as List? ?? [])
        .map(
          (e) => Transakcija.izJsona(
            e as Map<String, dynamic>,
          ),
        )
        .toList();

    return Pregled(
      godina: json['godina'] as int,
      mjesec: json['mjesec'] as int,

      ukupnoPrihodi: json['ukupno_prihodi']?.toString() ?? '0.00',
      ukupnoTroskovi: json['ukupno_troskovi']?.toString() ?? '0.00',
      saldo: json['saldo']?.toString() ?? '0.00',

      danasPotroseno: json['danas_potroseno']?.toString() ?? '0.00',
      dnevniProsjek: json['dnevni_prosjek']?.toString() ?? '0.00',

      budzet: json['budzet']?.toString(),
      raspoloziviBudzet: json['raspolozivi_budzet']?.toString(),
      preostaloBudzeta: json['preostalo_budzeta']?.toString(),
      postotakBudzeta:
          (json['postotak_budzeta'] as num?)?.toDouble(),
      rasporedenoPoKategorijama:
          json['rasporedeno_po_kategorijama']?.toString() ?? '0.00',
      preostaloZaRaspodjelu:
          json['preostalo_za_raspodjelu']?.toString() ?? '0.00',

      brojTransakcija: json['broj_transakcija'] as int? ?? 0,

      poKategorijama: kategorije,
      zadnjeTransakcije: transakcije,
    );
  }
}
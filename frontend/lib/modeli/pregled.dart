import 'transakcija.dart';

class StavkaKategorije {
  final int kategorija;
  final String naziv;
  final String boja;
  final String ikona;
  final String iznos;
  final double postotak;

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
    final kategorijaVrijednost = json['kategorija'];

    if (kategorijaVrijednost == null) {
      throw const FormatException('Stavka kategorije nema ID kategorije.');
    }

    final kategorijaId = kategorijaVrijednost is num
        ? kategorijaVrijednost.toInt()
        : int.tryParse(kategorijaVrijednost.toString());

    if (kategorijaId == null) {
      throw const FormatException('Neispravan ID kategorije.');
    }

    return StavkaKategorije(
      kategorija: kategorijaId,
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

class GarancijeSazetak {
  final int aktivne;
  final int istjeceUskoro;
  final String? najbliziIstek;

  const GarancijeSazetak({
    required this.aktivne,
    required this.istjeceUskoro,
    required this.najbliziIstek,
  });

  factory GarancijeSazetak.izJsona(Map<String, dynamic> json) {
    return GarancijeSazetak(
      aktivne: (json['aktivne'] as num?)?.toInt() ?? 0,
      istjeceUskoro: (json['istjece_uskoro'] as num?)?.toInt() ?? 0,
      najbliziIstek: json['najblizi_istek']?.toString(),
    );
  }
}

class Pregled {
  final int godina;
  final int mjesec;

  final String ukupnoPrihodi;
  final String ukupnoTroskovi;
  final String saldo;

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

  final GarancijeSazetak garancije;

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
    required this.garancije,
  });

  factory Pregled.izJsona(Map<String, dynamic> json) {

    final kategorije = (json['po_kategorijama'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .where((e) => e['kategorija'] != null)
        .map(StavkaKategorije.izJsona)
        .toList();

    final transakcije = (json['zadnje_transakcije'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Transakcija.izJsona)
        .toList();

    final godinaVrijednost = json['godina'];
    final mjesecVrijednost = json['mjesec'];

    final godina = godinaVrijednost is num
        ? godinaVrijednost.toInt()
        : int.tryParse(godinaVrijednost?.toString() ?? '');
    final mjesec = mjesecVrijednost is num
        ? mjesecVrijednost.toInt()
        : int.tryParse(mjesecVrijednost?.toString() ?? '');

    if (godina == null || mjesec == null) {
      throw const FormatException('Pregled nema ispravnu godinu ili mjesec.');
    }

    return Pregled(
      godina: godina,
      mjesec: mjesec,

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

      brojTransakcija: (json['broj_transakcija'] as num?)?.toInt() ?? 0,

      poKategorijama: kategorije,
      zadnjeTransakcije: transakcije,
      garancije: GarancijeSazetak.izJsona(
        json['garancije'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }
}

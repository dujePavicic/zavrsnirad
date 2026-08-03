import 'transakcija.dart';

/// Jedan račun iz arhive. Uz sebe ima ugniježđenu transakciju
/// (backend je uvijek stvori pri spremanju računa).
class Racun {
  final int id;
  final String trgovina;
  final String? slika; // puni URL slike ili null
  final String prepoznatiTekst; // sirovi OCR tekst
  final String datumSpremanja;
  final Transakcija? transakcija;

  Racun({
    required this.id,
    required this.trgovina,
    required this.slika,
    required this.prepoznatiTekst,
    required this.datumSpremanja,
    required this.transakcija,
  });

  factory Racun.izJsona(Map<String, dynamic> json) {
    return Racun(
      id: json['id'] as int,
      trgovina: json['trgovina']?.toString() ?? '',
      slika: json['slika']?.toString(),
      prepoznatiTekst: json['prepoznati_tekst']?.toString() ?? '',
      datumSpremanja: json['datum_spremanja']?.toString() ?? '',
      transakcija: json['transakcija'] != null
          ? Transakcija.izJsona(json['transakcija'] as Map<String, dynamic>)
          : null,
    );
  }

  // Pomoćni getteri za prikaz (podaci dolaze iz ugniježđene transakcije):
  String get iznos => transakcija?.iznos ?? '0.00';
  String get kategorijaNaziv => transakcija?.kategorijaNaziv ?? '';
  String get kategorijaBoja => transakcija?.kategorijaBoja ?? '#9E9E9E';
  String get kategorijaIkona => transakcija?.kategorijaIkona ?? 'category';
  String get datum => transakcija?.datum ?? '';
}
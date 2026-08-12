/// Jedna transakcija (trošak ili prihod).
/// Polja kategorije su "spljoštena" jer ih backend šalje uz transakciju.
class Transakcija {
  final int id;
  final String tip; // "TROSAK" ili "PRIHOD"
  final String iznos; // npr. "31.50"
  final int? kategorija;
  final String kategorijaNaziv;
  final String kategorijaBoja;
  final String kategorijaIkona;
  final String datum; // "2026-08-02"
  final String opis;

  /// null = ručna transakcija, int = povezana je s računom
  final int? racunId;

  Transakcija({
    required this.id,
    required this.tip,
    required this.iznos,
    required this.kategorija,
    required this.kategorijaNaziv,
    required this.kategorijaBoja,
    required this.kategorijaIkona,
    required this.datum,
    required this.opis,
    required this.racunId,
  });

  factory Transakcija.izJsona(Map<String, dynamic> json) {
    return Transakcija(
      id: json['id'] as int,
      tip: json['tip']?.toString() ?? 'TROSAK',
      iznos: json['iznos']?.toString() ?? '0.00',
      kategorija: json['kategorija'] as int?,
      kategorijaNaziv: json['kategorija_naziv']?.toString() ?? '',
      kategorijaBoja: json['kategorija_boja']?.toString() ?? '#9E9E9E',
      kategorijaIkona: json['kategorija_ikona']?.toString() ?? 'category',
      datum: json['datum']?.toString() ?? '',
      opis: json['opis']?.toString() ?? '',
      racunId: json['racun_id'] as int?,
    );
  }
}

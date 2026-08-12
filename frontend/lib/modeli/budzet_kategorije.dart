class BudzetKategorije {
  final int id;
  final int kategorija;
  final int godina;
  final int mjesec;
  final String iznos;

  final String kategorijaNaziv;
  final String kategorijaBoja;
  final String kategorijaIkona;

  BudzetKategorije({
    required this.id,
    required this.kategorija,
    required this.godina,
    required this.mjesec,
    required this.iznos,
    required this.kategorijaNaziv,
    required this.kategorijaBoja,
    required this.kategorijaIkona,
  });

  factory BudzetKategorije.izJsona(Map<String, dynamic> json) {
    return BudzetKategorije(
      id: json['id'] as int,
      kategorija: json['kategorija'] as int,
      godina: json['godina'] as int,
      mjesec: json['mjesec'] as int,
      iznos: json['iznos']?.toString() ?? '0.00',
      kategorijaNaziv:
          json['kategorija_naziv']?.toString() ?? '',
      kategorijaBoja:
          json['kategorija_boja']?.toString() ?? '#9E9E9E',
      kategorijaIkona:
          json['kategorija_ikona']?.toString() ?? 'category',
    );
  }
}
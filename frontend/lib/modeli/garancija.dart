class Garancija {
  final int id;
  final String nazivProizvoda;
  final String datumKupnje;
  final String? datumIsteka;
  final String serijskiBroj;
  final String napomena;
  final bool obavijesti;
  final int? racunId;
  final String? racunTrgovina;
  final String? racunSlika;
  final int? danaDoIsteka;
  final bool istekla;
  final bool dozivotna;

  const Garancija({
    required this.id,
    required this.nazivProizvoda,
    required this.datumKupnje,
    required this.datumIsteka,
    required this.serijskiBroj,
    required this.napomena,
    required this.obavijesti,
    required this.racunId,
    required this.racunTrgovina,
    required this.racunSlika,
    required this.danaDoIsteka,
    required this.istekla,
    required this.dozivotna,
  });

  factory Garancija.izJsona(Map<String, dynamic> json) {
    return Garancija(
      id: json['id'] as int,
      nazivProizvoda: json['naziv_proizvoda']?.toString() ?? '',
      datumKupnje: json['datum_kupnje']?.toString() ?? '',
      datumIsteka: json['datum_isteka']?.toString(),
      serijskiBroj: json['serijski_broj']?.toString() ?? '',
      napomena: json['napomena']?.toString() ?? '',
      obavijesti: json['obavijesti'] as bool? ?? true,
      racunId: json['racun'] as int?,
      racunTrgovina: json['racun_trgovina']?.toString(),
      racunSlika: json['racun_slika']?.toString(),
      danaDoIsteka: json['dana_do_isteka'] as int?,
      istekla: json['istekla'] as bool? ?? false,
      dozivotna: json['dozivotna'] as bool? ?? false,
    );
  }
}

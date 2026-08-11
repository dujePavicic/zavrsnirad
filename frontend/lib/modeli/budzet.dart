/// Mjesečni budžet korisnika (jedan po mjesecu).
class Budzet {
  final int id;
  final int godina;
  final int mjesec;
  final String iznos; // npr. "800.00"

  Budzet({
    required this.id,
    required this.godina,
    required this.mjesec,
    required this.iznos,
  });

  factory Budzet.izJsona(Map<String, dynamic> json) {
    return Budzet(
      id: json['id'] as int,
      godina: json['godina'] as int,
      mjesec: json['mjesec'] as int,
      iznos: json['iznos'].toString(),
    );
  }
}
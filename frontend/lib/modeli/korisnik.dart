class Korisnik {
  final int id;
  final String email;
  final String korisnickoIme;
  final String ime;
  final String prezime;
  final DateTime? datumRegistracije;

  Korisnik({
    required this.id,
    required this.email,
    required this.korisnickoIme,
    required this.ime,
    required this.prezime,
    this.datumRegistracije,
  });

  factory Korisnik.izJsona(Map<String, dynamic> json) {
    return Korisnik(
      id: json['id'] as int,
      email: json['email'] as String,
      korisnickoIme: json['korisnicko_ime'] as String,
      ime: json['ime'] as String,
      prezime: json['prezime'] as String,
      datumRegistracije: json['datum_registracije'] != null
          ? DateTime.parse(json['datum_registracije'] as String)
          : null,
    );
  }

  Map<String, dynamic> uJson() => {
        'id': id,
        'email': email,
        'korisnicko_ime': korisnickoIme,
        'ime': ime,
        'prezime': prezime,
        'datum_registracije': datumRegistracije?.toIso8601String(),
      };
}
class Korisnik {
  final int id;
  final String email;
  final String korisnickoIme;
  final String ime;
  final String prezime;
  final String? profilnaSlika;
  final DateTime? datumRegistracije;

  Korisnik({
    required this.id,
    required this.email,
    required this.korisnickoIme,
    required this.ime,
    required this.prezime,
    this.profilnaSlika,
    this.datumRegistracije,
  });

  factory Korisnik.izJsona(Map<String, dynamic> json) {
    return Korisnik(
      id: json['id'] as int,
      email: json['email']?.toString() ?? '',
      korisnickoIme:
          json['korisnicko_ime']?.toString() ?? '',
      ime: json['ime']?.toString() ?? '',
      prezime: json['prezime']?.toString() ?? '',
      profilnaSlika:
          json['profilna_slika']?.toString(),
      datumRegistracije:
          json['datum_registracije'] != null
              ? DateTime.parse(
                  json['datum_registracije'].toString(),
                )
              : null,
    );
  }

  Map<String, dynamic> uJson() => {
        'id': id,
        'email': email,
        'korisnicko_ime': korisnickoIme,
        'ime': ime,
        'prezime': prezime,
        'profilna_slika': profilnaSlika,
        'datum_registracije':
            datumRegistracije?.toIso8601String(),
      };
}
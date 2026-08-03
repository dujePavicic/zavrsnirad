/// Kategorija troška ili prihoda (sustavska ili korisnikova vlastita).
class Kategorija {
  final int id;
  final String naziv;
  final String tip; // "TROSAK" ili "PRIHOD"
  final String boja; // hex
  final String ikona; // naziv Material ikone
  final bool jeSustavska;

  Kategorija({
    required this.id,
    required this.naziv,
    required this.tip,
    required this.boja,
    required this.ikona,
    required this.jeSustavska,
  });

  factory Kategorija.izJsona(Map<String, dynamic> json) {
    return Kategorija(
      id: json['id'] as int,
      naziv: json['naziv']?.toString() ?? '',
      tip: json['tip']?.toString() ?? 'TROSAK',
      boja: json['boja']?.toString() ?? '#9E9E9E',
      ikona: json['ikona']?.toString() ?? 'category',
      jeSustavska: json['je_sustavska'] as bool? ?? false,
    );
  }
}
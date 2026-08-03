import 'package:flutter/material.dart';

/// Pretvara hex boju iz backenda ("#0F6E56") u Flutter Color.
Color bojaIzHexa(String hex) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h'; // dodaj punu neprozirnost (alfa)
  final vrijednost = int.tryParse(h, radix: 16) ?? 0xFF9E9E9E;
  return Color(vrijednost);
}

/// "31.50" -> "31,50 €"  (hrvatski zapis s zarezom)
String formatNovac(String iznos) => '${iznos.replaceAll('.', ',')} €';

/// "31.50" -> 31.5  (za izračun veličina u grafu)
double uBroj(String iznos) => double.tryParse(iznos) ?? 0;

const _mjeseci = [
  '', 'Siječanj', 'Veljača', 'Ožujak', 'Travanj', 'Svibanj', 'Lipanj',
  'Srpanj', 'Kolovoz', 'Rujan', 'Listopad', 'Studeni', 'Prosinac',
];

/// Broj mjeseca (1-12) -> hrvatski naziv.
String imeMjeseca(int m) => (m >= 1 && m <= 12) ? _mjeseci[m] : '';

/// Naziv Material ikone (kako ga backend šalje) -> IconData.
/// Flutter ne može dohvatiti ikonu iz stringa dinamički (tree-shaking izbaci
/// nekorištene ikone), zato držimo ručnu mapu. Ako neka kategorija dobije
/// drugu ikonu na backendu, dodaj njen naziv ovdje.
IconData ikonaIzNaziva(String naziv) {
  const mapa = <String, IconData>{
    'shopping_cart': Icons.shopping_cart,
    'directions_car': Icons.directions_car,
    'medical_services': Icons.medical_services,
    'local_hospital': Icons.local_hospital,
    'receipt': Icons.receipt_long,
    'bolt': Icons.bolt,
    'movie': Icons.movie,
    'checkroom': Icons.checkroom,
    'home': Icons.home,
    'restaurant': Icons.restaurant,
    'payments': Icons.payments,
    'attach_money': Icons.attach_money,
    'savings': Icons.savings,
    'category': Icons.category,
  };
  return mapa[naziv] ?? Icons.category;
}
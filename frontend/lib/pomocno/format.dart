import 'package:flutter/material.dart';

Color bojaIzHexa(String hex) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h'; // dodaj punu neprozirnost (alfa)
  final vrijednost = int.tryParse(h, radix: 16) ?? 0xFF9E9E9E;
  return Color(vrijednost);
}

String formatNovac(String iznos) => '${iznos.replaceAll('.', ',')} €';

double uBroj(String iznos) => double.tryParse(iznos) ?? 0;

const _mjeseci = [
  '', 'Siječanj', 'Veljača', 'Ožujak', 'Travanj', 'Svibanj', 'Lipanj',
  'Srpanj', 'Kolovoz', 'Rujan', 'Listopad', 'Studeni', 'Prosinac',
];

String imeMjeseca(int m) => (m >= 1 && m <= 12) ? _mjeseci[m] : '';

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
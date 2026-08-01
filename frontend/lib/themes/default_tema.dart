import 'package:flutter/material.dart';

/// Sjemenka boje iz koje se generiraju SVIJETLA i TAMNA paleta.
/// Promijeni samo ovu boju i mijenja se cijela aplikacija u oba načina.
const Color bojaNaglaska = Color(0xFF0F6E56); // zelena

/// Gradi temu za zadanu svjetlinu (Brightness.light ili Brightness.dark).
/// Ista pravila vrijede za oba načina — samo se paleta razlikuje.
ThemeData izradiTemu(Brightness svjetlina) {
  final shema = ColorScheme.fromSeed(
    seedColor: bojaNaglaska,
    brightness: svjetlina,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: shema,
    // Izgled polja (okvir + zaobljenost) živi ovdje, pa je isti svugdje
    // i automatski se prilagođava svijetlom/tamnom načinu:
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: shema.primary, width: 2),
      ),
    ),
  );
}

/// Samo SADRŽAJ polja (natpis, natuknica, ikone).
/// Izgled okvira dolazi iz teme gore, pa ga ovdje više ne diramo.
InputDecoration izgledPolja({
  required String oznaka,
  required String natuknica,
  required IconData ikona,
  Widget? sufiks,
}) {
  return InputDecoration(
    labelText: oznaka,
    hintText: natuknica,
    prefixIcon: Icon(ikona),
    suffixIcon: sufiks,
  );
}
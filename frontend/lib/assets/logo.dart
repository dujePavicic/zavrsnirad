import 'package:flutter/material.dart';

/// Logo aplikacije — koristi se na vrhu ekrana prijave i registracije
/// (i kasnije gdje god zatreba). Jedno mjesto za promjenu.
///
/// Zasad prikazuje PRIVREMENI znak. Kad pravi logo bude gotov:
///   1. stavi datoteku u  frontend/assets/logo.png
///   2. u pubspec.yaml pod  flutter:  dodaj:
///        assets:
///          - assets/logo.png
///   3. ovdje odkomentiraj Image.asset blok i obriši privremeni Container.
class Logo extends StatelessWidget {
  final double velicina;
  const Logo({super.key, this.velicina = 68});

  @override
  Widget build(BuildContext context) {
    final shema = Theme.of(context).colorScheme;

    // ---- PRAVI LOGO (odkomentirati kad datoteka postoji) ----
    // return Image.asset(
    //   'assets/logo.png',
    //   width: velicina,
    //   height: velicina,
    // );

    // ---- PRIVREMENI ZNAK (obrisati kad ubaciš pravi logo) ----
    return Container(
      width: velicina,
      height: velicina,
      decoration: BoxDecoration(
        color: shema.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        Icons.receipt_long,
        size: velicina * 0.5,
        color: shema.onPrimaryContainer,
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'ekrani/prijava.dart';
import 'themes/default_tema.dart';
import 'ekrani/glavni_ekran.dart';
import 'providers/pregled_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthPruzatelj()..provjeriPrijavu(),
        ),
        ChangeNotifierProxyProvider<AuthPruzatelj, PregledPruzatelj>(
          create: (_) => PregledPruzatelj(),
          update: (_, auth, pregled) {
            final provider = pregled ?? PregledPruzatelj();

            if (auth.status != AuthStatus.prijavljen) {
              provider.resetiraj();
            }

            return provider;
          },
        ),
      ],
      child: const ZavrsniApp(),
    ),
  );
}

class ZavrsniApp extends StatelessWidget {
  const ZavrsniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Završni projekt',
      debugShowCheckedModeBanner: false,
      theme: izradiTemu(Brightness.light),
      darkTheme: izradiTemu(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const PUTOKAZ(),
    );
  }
}

/// Odlučuje koji ekran prikazati ovisno o statusu prijave.
class PUTOKAZ extends StatelessWidget {
  const PUTOKAZ({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthPruzatelj>();

    switch (auth.status) {
      case AuthStatus.pocetno:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );

      case AuthStatus.prijavljen:
        return GlavniEkran(
          key: ValueKey(auth.korisnik?.id),
        );

      case AuthStatus.ucitavanje:
      case AuthStatus.odjavljen:
        return const PrijavaEkran();
    }
  }
}
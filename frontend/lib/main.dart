import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'ekrani/prijava.dart';
import 'themes/default_tema.dart';

void main() {
  runApp(
    // Provider se postavlja na vrhu, pa mu svi ekrani mogu pristupiti.
    // provjeriPrijavu() odmah gleda ima li spremljeni token.
    ChangeNotifierProvider(
      create: (_) => AuthPruzatelj()..provjeriPrijavu(),
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
/// context.watch znači: kad se status promijeni, Vratar se ponovno iscrta.
class PUTOKAZ extends StatelessWidget {
  const PUTOKAZ({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthPruzatelj>();

    switch (auth.status) {
      case AuthStatus.pocetno:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.prijavljen:
        return const PocetniEkran();
      case AuthStatus.ucitavanje:
      case AuthStatus.odjavljen:
        return const PrijavaEkran();
    }
  }
}

/// Privremeni početni ekran nakon prijave — pravi ćemo u kasnijem koraku.
class PocetniEkran extends StatelessWidget {
  const PocetniEkran({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthPruzatelj>();
    return Scaffold(
      appBar: AppBar(title: const Text('Moje financije')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Uspješno si prijavljen.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => auth.odjava(),
              child: const Text('Odjava'),
            ),
          ],
        ),
      ),
    );
  }
}
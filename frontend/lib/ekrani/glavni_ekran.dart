import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'pregled_ekran.dart';
import 'racuni_ekran.dart';
import 'budzet_ekran.dart';

/// Glavni ekran nakon prijave: donji navigacijski bar s četiri taba.
/// Sadržaj pojedinog taba puni se u sljedećim koracima.
class GlavniEkran extends StatefulWidget {
  const GlavniEkran({super.key});

  @override
  State<GlavniEkran> createState() => _GlavniEkranState();
}

class _GlavniEkranState extends State<GlavniEkran> {
  int _odabraniIndeks = 0;

  @override
  Widget build(BuildContext context) {
    // IndexedStack čuva stanje svakog taba (npr. poziciju skrolanja) kad
    // prebacuješ između tabova, umjesto da se svaki put gradi ispočetka.
    final tabovi = [
      const PregledEkran(),
      const RacuniEkran(),
      const BudzetEkran(),
      const _ProfilTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _odabraniIndeks, children: tabovi),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _odabraniIndeks,
        onDestinationSelected: (i) => setState(() => _odabraniIndeks = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Pregled',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Računi',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Budžet',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

/// Privremeni sadržaj taba dok ne napravimo pravi ekran.
class _UskoroTab extends StatelessWidget {
  final String naziv;
  final IconData ikona;
  const _UskoroTab({required this.naziv, required this.ikona});

  @override
  Widget build(BuildContext context) {
    final shema = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(naziv)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikona, size: 48, color: shema.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Ekran "$naziv" stiže uskoro',
              style: TextStyle(color: shema.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Privremeni profil s odjavom (dok ne napravimo pravi profil).
class _ProfilTab extends StatelessWidget {
  const _ProfilTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthPruzatelj>();
    final korisnik = auth.korisnik;
    final shema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (korisnik != null) ...[
              Text(
                '${korisnik.ime} ${korisnik.prezime}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(korisnik.email,
                  style: TextStyle(color: shema.onSurfaceVariant)),
              const SizedBox(height: 24),
            ],
            OutlinedButton.icon(
              onPressed: () => context.read<AuthPruzatelj>().odjava(),
              icon: const Icon(Icons.logout),
              label: const Text('Odjava'),
            ),
          ],
        ),
      ),
    );
  }
}
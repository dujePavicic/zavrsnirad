import 'package:flutter/material.dart';

import '../modeli/racun.dart';
import '../pomocno/format.dart';
import '../servisi/racun_servis.dart';
import '../servisi/transakcija_servis.dart';
import 'garancija_unos_ekran.dart';

enum _OpcijaBrisanja {
  samoRacun,
  cijelaTransakcija,
}

class RacunDetaljEkran extends StatelessWidget {
  final Racun racun;

  const RacunDetaljEkran({
    super.key,
    required this.racun,
  });

  Future<void> _obrisi(BuildContext context) async {
    final odabir = await showDialog<_OpcijaBrisanja>(
      context: context,
      builder: (dialogContext) {
        final shema = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: const Text('Što želiš obrisati?'),
          content: const Text(
            'Možeš obrisati samo račun i njegovu sliku ili cijelu '
            'transakciju zajedno s povezanim računom.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Odustani'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _OpcijaBrisanja.samoRacun,
              ),
              child: const Text('Samo račun'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: shema.error,
                foregroundColor: shema.onError,
              ),
              onPressed: racun.transakcija == null
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        _OpcijaBrisanja.cijelaTransakcija,
                      ),
              child: const Text('Cijelu transakciju'),
            ),
          ],
        );
      },
    );

    if (odabir == null) return;

    try {
      if (odabir == _OpcijaBrisanja.samoRacun) {
        await RacunServis().obrisi(racun.id);
      } else {
        final transakcija = racun.transakcija;

        if (transakcija == null) {
          throw Exception('Povezana transakcija nije pronađena.');
        }

        await TransakcijaServis().obrisi(transakcija.id);
      }

      if (context.mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    }
  }

  Future<void> _dodajGaranciju(BuildContext context) async {
    final rezultat = await Navigator.push<GarancijaFormaPodaci>(
      context,
      MaterialPageRoute(
        builder: (_) => GarancijaUnosEkran(
          racun: racun,
        ),
      ),
    );

    if (rezultat == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Garancija je pripremljena. '
          'Spremanje ćemo povezati s backendom.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final boja = bojaIzHexa(racun.kategorijaBoja);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _zaglavlje(context),
            const SizedBox(height: 18),
            _slika(context),
            const SizedBox(height: 22),

            Text(
              racun.trgovina.isNotEmpty ? racun.trgovina : 'Račun',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatNovac(racun.iznos),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Detalji',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            _InfoKartica(
              ikona: ikonaIzNaziva(racun.kategorijaIkona),
              bojaIkone: boja,
              naslov: 'Kategorija',
              vrijednost: racun.kategorijaNaziv,
            ),
            const SizedBox(height: 10),
            _InfoKartica(
              ikona: Icons.event_outlined,
              naslov: 'Datum',
              vrijednost: racun.datum,
            ),
            if (racun.trgovina.isNotEmpty) ...[
              const SizedBox(height: 10),
              _InfoKartica(
                ikona: Icons.store_outlined,
                naslov: 'Trgovina',
                vrijednost: racun.trgovina,
              ),
            ],

            const SizedBox(height: 22),

            OutlinedButton.icon(
              onPressed: () => _dodajGaranciju(context),
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text(
                'Dodaj garanciju za ovaj račun',
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _zaglavlje(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Row(
      children: [
        IconButton(
          tooltip: 'Natrag',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Detalji računa',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Obriši',
          onPressed: () => _obrisi(context),
          icon: Icon(
            Icons.delete_outline_rounded,
            color: shema.error,
          ),
        ),
      ],
    );
  }

  Widget _slika(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    if (racun.slika != null && racun.slika!.isNotEmpty) {
      return GestureDetector(
        onTap: () => _otvoriSliku(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 360),
            color: shema.surfaceContainerHigh,
            width: double.infinity,
            child: Image.network(
              racun.slika!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _placeholder(context),
              loadingBuilder: (c, w, p) {
                return p == null
                    ? w
                    : const SizedBox(
                        height: 220,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
              },
            ),
          ),
        ),
      );
    }

    return _placeholder(context);
  }

  Future<void> _otvoriSliku(BuildContext context) async {
    if (racun.slika == null || racun.slika!.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PregledSlikeRacuna(
          slikaUrl: racun.slika!,
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final shema = Theme.of(context).colorScheme;

    return Container(
      height: 190,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: shema.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: shema.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: shema.primary,
          ),
          const SizedBox(height: 10),
          Text(
            'Nema spremljene slike računa',
            style: TextStyle(
              color: shema.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PregledSlikeRacuna extends StatelessWidget {
  final String slikaUrl;

  const _PregledSlikeRacuna({
    required this.slikaUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pregled računa',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          boundaryMargin: const EdgeInsets.all(80),
          child: Center(
            child: Image.network(
              slikaUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;

                return const Center(
                  child: CircularProgressIndicator(),
                );
              },
              errorBuilder: (_, __, ___) {
                return const Center(
                  child: Text(
                    'Slika računa se ne može učitati.',
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoKartica extends StatelessWidget {
  final IconData ikona;
  final Color? bojaIkone;
  final String naslov;
  final String vrijednost;

  const _InfoKartica({
    required this.ikona,
    this.bojaIkone,
    required this.naslov,
    required this.vrijednost,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: shema.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: shema.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (bojaIkone ?? shema.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              ikona,
              color: bojaIkone ?? shema.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  naslov,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: shema.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  vrijednost.isNotEmpty ? vrijednost : '—',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

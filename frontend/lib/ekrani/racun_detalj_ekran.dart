import 'package:flutter/material.dart';

import '../modeli/racun.dart';
import '../pomocno/format.dart';
import '../servisi/racun_servis.dart';

class RacunDetaljEkran extends StatelessWidget {
  final Racun racun;

  const RacunDetaljEkran({
    super.key,
    required this.racun,
  });

  Future<void> _obrisi(BuildContext context) async {
    final potvrda = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Obrisati račun?'),
        content: const Text(
          'Bit će obrisani samo račun i njegova slika. '
          'Financijska transakcija će ostati spremljena i ponovno će se prikazati među ručnim transakcijama.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );

    if (potvrda != true) return;

    try {
      await RacunServis().obrisi(racun.id);

      if (context.mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final boja = bojaIzHexa(racun.kategorijaBoja);

    return Scaffold(
      backgroundColor: shema.surface,
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

            const SizedBox(height: 26),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Prepoznati tekst',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.document_scanner_outlined,
                  size: 20,
                  color: shema.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: shema.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: shema.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                racun.prepoznatiTekst.isNotEmpty
                    ? racun.prepoznatiTekst
                    : 'Nema prepoznatog teksta.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.45,
                  color: racun.prepoznatiTekst.isNotEmpty
                      ? shema.onSurface
                      : shema.onSurfaceVariant,
                ),
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
      return ClipRRect(
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
      );
    }

    return _placeholder(context);
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

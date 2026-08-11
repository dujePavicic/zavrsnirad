import 'package:flutter/material.dart';

import '../modeli/racun.dart';
import '../pomocno/format.dart';
import '../servisi/racun_servis.dart';

class RacunDetaljEkran extends StatelessWidget {
  final Racun racun;
  const RacunDetaljEkran({super.key, required this.racun});

  Future<void> _obrisi(BuildContext context) async {
    final potvrda = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Obrisati račun?'),
        content: const Text(
            'Račun i njegova transakcija bit će trajno obrisani.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Odustani')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (potvrda != true) return;

    try {
      await RacunServis().obrisi(racun.id);
      if (context.mounted) Navigator.pop(context, true); // javi da je obrisan
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shema = Theme.of(context).colorScheme;
    final boja = bojaIzHexa(racun.kategorijaBoja);

    return Scaffold(
      appBar: AppBar(
        title: Text(racun.trgovina.isNotEmpty ? racun.trgovina : 'Račun'),
        actions: [
          IconButton(
            tooltip: 'Obriši',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _obrisi(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _slika(shema),
          const SizedBox(height: 16),
          Text(formatNovac(racun.iznos),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          _redak(context,
              ikona: ikonaIzNaziva(racun.kategorijaIkona),
              boja: boja,
              oznaka: 'Kategorija',
              vrijednost: racun.kategorijaNaziv),
          _redak(context,
              ikona: Icons.event_outlined,
              oznaka: 'Datum',
              vrijednost: racun.datum),
          if (racun.trgovina.isNotEmpty)
            _redak(context,
                ikona: Icons.store_outlined,
                oznaka: 'Trgovina',
                vrijednost: racun.trgovina),
          const SizedBox(height: 20),
          Text('Prepoznati tekst',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: shema.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              racun.prepoznatiTekst.isNotEmpty
                  ? racun.prepoznatiTekst
                  : 'Nema prepoznatog teksta.',
              style: TextStyle(
                fontFamily: 'monospace',
                color: racun.prepoznatiTekst.isNotEmpty
                    ? null
                    : shema.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slika(ColorScheme shema) {
    if (racun.slika != null && racun.slika!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 360),
          color: shema.surfaceContainerHighest,
          width: double.infinity,
          child: Image.network(
            racun.slika!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _placeholder(shema),
            loadingBuilder: (c, w, p) => p == null
                ? w
                : const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator())),
          ),
        ),
      );
    }
    return _placeholder(shema);
  }

  Widget _placeholder(ColorScheme shema) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: shema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.receipt_long_outlined,
          size: 48, color: shema.onSurfaceVariant),
    );
  }

  Widget _redak(BuildContext context,
      {required IconData ikona,
      Color? boja,
      required String oznaka,
      required String vrijednost}) {
    final shema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(ikona, size: 20, color: boja ?? shema.onSurfaceVariant),
          const SizedBox(width: 12),
          Text('$oznaka: ', style: TextStyle(color: shema.onSurfaceVariant)),
          Expanded(
              child: Text(vrijednost.isNotEmpty ? vrijednost : '—')),
        ],
      ),
    );
  }
}
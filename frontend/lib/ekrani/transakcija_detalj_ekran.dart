import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../modeli/transakcija.dart';
import '../pomocno/format.dart';
import '../providers/pregled_provider.dart';
import '../servisi/racun_servis.dart';
import '../servisi/transakcija_servis.dart';
import 'transakcija_unos_ekran.dart';

class TransakcijaDetaljEkran extends StatefulWidget {
  final Transakcija transakcija;

  const TransakcijaDetaljEkran({
    super.key,
    required this.transakcija,
  });

  @override
  State<TransakcijaDetaljEkran> createState() =>
      _TransakcijaDetaljEkranState();
}

class _TransakcijaDetaljEkranState extends State<TransakcijaDetaljEkran> {
  late Transakcija _transakcija;

  @override
  void initState() {
    super.initState();
    _transakcija = widget.transakcija;
  }

  Future<void> _uredi() async {
    final rezultat = await Navigator.push<Transakcija>(
      context,
      MaterialPageRoute(
        builder: (_) => TransakcijaUnosEkran(
          transakcija: _transakcija,
        ),
      ),
    );

    if (rezultat == null || !mounted) return;

    setState(() {
      _transakcija = rezultat;
    });
  }

  Future<void> _obrisi() async {
    final potvrda = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Obrisati transakciju?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Transakcija će biti trajno obrisana.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );

    if (potvrda != true) return;

    try {
      await TransakcijaServis().obrisi(_transakcija.id);

      if (!mounted) return;

      await context.read<PregledPruzatelj>().osvjezi();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  Future<void> _dodajSlikuRacuna() async {
    final picker = ImagePicker();

    final slika = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2200,
    );

    if (slika == null || !mounted) return;

    final bytes = await slika.readAsBytes();

    if (!mounted) return;

    final trgovinaController = TextEditingController();

    final potvrda = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Dodaj sliku računa',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: trgovinaController,
              decoration: InputDecoration(
                labelText: 'Trgovina',
                hintText: 'Npr. Lidl',
                helperText: 'Nije obavezno.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Spremi račun'),
          ),
        ],
      ),
    );

    if (potvrda != true) {
      trgovinaController.dispose();
      return;
    }

    try {
      await RacunServis().dodajPostojecojTransakciji(
        transakcijaId: _transakcija.id,
        slikaBytes: bytes,
        nazivSlike: slika.name,
        trgovina: trgovinaController.text.trim(),
        prepoznatiTekst: '',
      );

      trgovinaController.dispose();

      if (!mounted) return;

      await context.read<PregledPruzatelj>().osvjezi();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Račun je dodan. Transakcija je sada dostupna u Računima.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      trgovinaController.dispose();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final boja = bojaIzHexa(_transakcija.kategorijaBoja);
    final prihod = _transakcija.tip == 'PRIHOD';

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

            Container(
              height: 190,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: boja.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: boja.withValues(alpha: 0.20),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: boja.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      ikonaIzNaziva(_transakcija.kategorijaIkona),
                      color: boja,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ručna transakcija',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nema povezanu sliku računa',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: shema.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            Text(
              _transakcija.opis.isNotEmpty
                  ? _transakcija.opis
                  : _transakcija.kategorijaNaziv,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${prihod ? '+' : '-'}${formatNovac(_transakcija.iznos)}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: prihod ? shema.primary : shema.onSurface,
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
              ikona: prihod
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              naslov: 'Vrsta',
              vrijednost: prihod ? 'Prihod' : 'Trošak',
              bojaIkone: prihod ? shema.primary : shema.error,
            ),
            const SizedBox(height: 10),
            _InfoKartica(
              ikona: ikonaIzNaziva(_transakcija.kategorijaIkona),
              bojaIkone: boja,
              naslov: 'Kategorija',
              vrijednost: _transakcija.kategorijaNaziv,
            ),
            const SizedBox(height: 10),
            _InfoKartica(
              ikona: Icons.event_outlined,
              naslov: 'Datum',
              vrijednost: _transakcija.datum,
            ),

            if (_transakcija.opis.isNotEmpty) ...[
              const SizedBox(height: 10),
              _InfoKartica(
                ikona: Icons.notes_rounded,
                naslov: 'Opis',
                vrijednost: _transakcija.opis,
              ),
            ],

            const SizedBox(height: 26),
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
            'Detalji transakcije',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Dodaj sliku računa',
          onPressed: _dodajSlikuRacuna,
          icon: const Icon(Icons.add_a_photo_outlined),
        ),
        IconButton(
          tooltip: 'Uredi',
          onPressed: _uredi,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Obriši',
          onPressed: _obrisi,
          icon: Icon(
            Icons.delete_outline_rounded,
            color: shema.error,
          ),
        ),
      ],
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

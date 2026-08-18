import 'dart:async';

import 'package:flutter/material.dart';

import '../modeli/racun.dart';
import '../modeli/garancija.dart';
import '../pomocno/format.dart';
import '../servisi/racun_servis.dart';
import '../servisi/transakcija_servis.dart';
import '../servisi/garancija_servis.dart';
import '../servisi/auth_servis.dart';
import '../servisi/obavijesti_servis.dart';
import 'garancija_unos_ekran.dart';
import 'garancija_detalj_ekran.dart';

enum _OpcijaBrisanja {
  samoRacun,
  cijelaTransakcija,
}

class RacunDetaljEkran extends StatefulWidget {
  final Racun racun;

  const RacunDetaljEkran({
    super.key,
    required this.racun,
  });

  @override
  State<RacunDetaljEkran> createState() => _RacunDetaljEkranState();
}

class _RacunDetaljEkranState extends State<RacunDetaljEkran> {
  final GarancijaServis _garancijaServis = GarancijaServis();
  List<Garancija>? _garancije;
  bool _ucitavaGarancije = true;

  Racun get racun => widget.racun;

  @override
  void initState() {
    super.initState();
    _ucitajGarancije();
  }

  Future<void> _ucitajGarancije() async {
    try {
      final lista = await _garancijaServis.dohvatiGarancije(racun: racun.id);
      if (!mounted) return;
      setState(() {
        _garancije = lista;
        _ucitavaGarancije = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _ucitavaGarancije = false);
    }
  }

  Future<void> _zakaziObavijestUpozadini(Garancija garancija) async {
    try {
      final korisnik = await AuthServis().dohvatiJa();
      await ObavijestiServis().zakaziGaranciju(garancija, korisnik);
    } catch (_) {}
  }

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

    try {
      final garancija = await GarancijaServis().dodaj(
        nazivProizvoda: rezultat.nazivProizvoda,
        datumKupnje: rezultat.datumKupnje,
        datumIsteka: rezultat.datumIsteka,
        serijskiBroj: rezultat.serijskiBroj,
        napomena: rezultat.napomena,
        obavijesti:
            rezultat.dozivotna ? false : rezultat.obavijesti,
        racun: racun.id,
      );

      if (!context.mounted) return;

      setState(() {
        _garancije = [garancija, ...?_garancije];
        _ucitavaGarancije = false;
      });

      unawaited(_zakaziObavijestUpozadini(garancija));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Garancija je spremljena i povezana s računom.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

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

            _GarancijeRacunaSekcija(
              garancije: _garancije ?? const <Garancija>[],
              ucitava: _ucitavaGarancije,
              onDodaj: () => _dodajGaranciju(context),
              onOtvori: (garancija) async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GarancijaDetaljEkran(garancija: garancija),
                  ),
                );
                await _ucitajGarancije();
              },
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

class _GarancijeRacunaSekcija extends StatelessWidget {
  final List<Garancija> garancije;
  final bool ucitava;
  final VoidCallback onDodaj;
  final ValueChanged<Garancija> onOtvori;

  const _GarancijeRacunaSekcija({
    required this.garancije,
    required this.ucitava,
    required this.onDodaj,
    required this.onOtvori,
  });

  String _datum(String? vrijednost) {
    if (vrijednost == null || vrijednost.isEmpty) return 'Doživotna';
    final d = DateTime.tryParse(vrijednost);
    if (d == null) return vrijednost;
    return '${d.day}.${d.month}.${d.year}.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    if (ucitava) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: shema.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Provjera povezanih garancija...'),
          ],
        ),
      );
    }

    if (garancije.isEmpty) {
      return OutlinedButton.icon(
        onPressed: onDodaj,
        icon: const Icon(Icons.verified_user_outlined),
        label: const Text('Dodaj garanciju za ovaj račun'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                garancije.length == 1 ? 'Povezana garancija' : 'Povezane garancije (${garancije.length})',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: onDodaj,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Dodaj još'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: shema.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: shema.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < garancije.length; i++) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onOtvori(garancije[i]),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: shema.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            garancije[i].dozivotna ? Icons.all_inclusive_rounded : Icons.verified_user_outlined,
                            color: shema.primary,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                garancije[i].nazivProizvoda,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                garancije[i].dozivotna ? 'Doživotna garancija' : 'Vrijedi do ${_datum(garancije[i].datumIsteka)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: garancije[i].istekla ? shema.error : shema.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, color: shema.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
                if (i != garancije.length - 1)
                  Divider(height: 1, indent: 68, color: shema.outlineVariant.withValues(alpha: 0.45)),
              ],
            ],
          ),
        ),
      ],
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

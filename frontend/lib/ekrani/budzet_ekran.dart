import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../modeli/pregled.dart';
import '../pomocno/format.dart';
import '../providers/pregled_provider.dart';
import '../servisi/budzet_servis.dart';
import '../modeli/kategorija.dart';
import '../servisi/kategorija_servis.dart';

class BudzetEkran extends StatelessWidget {
  const BudzetEkran({super.key});

  Future<void> _urediBudzet(BuildContext context, Pregled p) async {
    final unos = await showDialog<String>(
      context: context,
      builder: (_) => _DijalogBudzeta(pocetni: p.budzet),
    );

    if (unos == null) return;

    try {
      await BudzetServis().postaviBudzet(
        godina: p.godina,
        mjesec: p.mjesec,
        iznos: unos,
      );

      if (context.mounted) {
        await context.read<PregledPruzatelj>().osvjezi();
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

  Future<void> _dodajBudzetKategorije(
    BuildContext context,
    Pregled p,
  ) async {
    try {
      final sveKategorije =
          await KategorijaServis().dohvatiKategorije(
        tip: 'TROSAK',
      );

      // Kategorije koje već imaju postavljen budžet.
      final zauzeteKategorije = p.poKategorijama
          .where((k) => k.budzet != null)
          .map((k) => k.kategorija)
          .toSet();

      // U izboru ostavljamo samo kategorije koje još nemaju budžet.
      final kategorije = sveKategorije
          .where(
            (k) => !zauzeteKategorije.contains(k.id),
          )
          .toList();

      if (!context.mounted) return;

      // Ako sve kategorije već imaju budžet, ne otvaramo prazan dijalog.
      if (kategorije.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sve kategorije već imaju postavljen budžet.',
            ),
          ),
        );
        return;
      }

      final rezultat =
          await showDialog<_RezultatBudzetaKategorije>(
        context: context,
        builder: (_) => _DijalogBudzetaKategorije(
          kategorije: kategorije,
          maksimalniIznos: uBroj(p.preostaloZaRaspodjelu),
        ),
      );

      if (rezultat == null) return;

      await BudzetServis().postaviBudzetKategorije(
        godina: p.godina,
        mjesec: p.mjesec,
        kategorija: rezultat.kategorija.id,
        iznos: rezultat.iznos,
      );

      if (context.mounted) {
        await context.read<PregledPruzatelj>().osvjezi();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Budžet kategorije je spremljen.',
              ),
            ),
          );
        }
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

  Future<void> _urediBudzetKategorije(
    BuildContext context,
    Pregled p,
    StavkaKategorije stavka,
  ) async {
    try {
      final kategorije =
          await KategorijaServis().dohvatiKategorije(
        tip: 'TROSAK',
      );

      if (!context.mounted) return;

      Kategorija? kategorija;

      for (final k in kategorije) {
        if (k.id == stavka.kategorija) {
          kategorija = k;
          break;
        }
      }

      if (kategorija == null) return;

      final rezultat =
          await showDialog<_RezultatBudzetaKategorije>(
        context: context,
        builder: (_) => _DijalogBudzetaKategorije(
          kategorije: [kategorija!],
          pocetnaKategorija: kategorija,
          pocetniIznos: stavka.budzet,
          maksimalniIznos:
              uBroj(p.preostaloZaRaspodjelu) +
              uBroj(stavka.budzet ?? '0'),
          zakljucajKategoriju: true,
        ),
      );

      if (rezultat == null) return;

      await BudzetServis().postaviBudzetKategorije(
        godina: p.godina,
        mjesec: p.mjesec,
        kategorija: rezultat.kategorija.id,
        iznos: rezultat.iznos,
      );

      if (context.mounted) {
        await context.read<PregledPruzatelj>().osvjezi();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Budžet kategorije je ažuriran.',
              ),
            ),
          );
        }
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

  Future<void> _obrisiBudzetKategorije(
    BuildContext context,
    Pregled p,
    StavkaKategorije stavka,
  ) async {
    final potvrda = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Makni budžet kategorije?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Budžet za kategoriju "${stavka.naziv}" bit će uklonjen. '
          'Kategorija i njezine transakcije neće biti obrisane.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Makni budžet'),
          ),
        ],
      ),
    );

    if (potvrda != true) return;

    try {
      await BudzetServis().obrisiBudzetKategorije(
        godina: p.godina,
        mjesec: p.mjesec,
        kategorija: stavka.kategorija,
      );

      if (context.mounted) {
        await context.read<PregledPruzatelj>().osvjezi();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Budžet kategorije je uklonjen.'),
            ),
          );
        }
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
    final pruzatelj = context.watch<PregledPruzatelj>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Budžet',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _tijelo(context, pruzatelj),
    );
  }

  Widget _tijelo(
    BuildContext context,
    PregledPruzatelj pruzatelj,
  ) {
    if (pruzatelj.pregled == null) {
      if (pruzatelj.greska != null) {
        return _Greska(
          poruka: pruzatelj.greska!,
          naPokusaj: () =>
              context.read<PregledPruzatelj>().osvjezi(),
        );
      }

      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final p = pruzatelj.pregled!;

    return RefreshIndicator(
      onRefresh: () =>
          context.read<PregledPruzatelj>().osvjezi(),
      child: _sadrzaj(context, p),
    );
  }

  Widget _sadrzaj(
    BuildContext context,
    Pregled p,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final shema = Theme.of(context).colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          '${imeMjeseca(p.mjesec)} ${p.godina}',
          style: textTheme.bodyMedium?.copyWith(
            color: shema.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 22),

        if (p.budzet == null)
          _KarticaNema(
            naPostavi: () => _urediBudzet(context, p),
          )
        else
          _KarticaBudzet(
            pregled: p,
            naUredi: () => _urediBudzet(context, p),
          ),

        const SizedBox(height: 28),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budžet po kategorijama',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Postavi limite za pojedine kategorije.',
                    style: textTheme.bodySmall?.copyWith(
                      color: shema.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: () =>
                  _dodajBudzetKategorije(context, p),
              tooltip: 'Dodaj budžet kategorije',
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),

        const SizedBox(height: 14),

        if (p.budzet != null) ...[
          _RaspodjelaBudzeta(pregled: p),
          const SizedBox(height: 14),
        ],

        _BudzetiKategorija(
          pregled: p,
          naUredi: (stavka) =>
              _urediBudzetKategorije(context, p, stavka),
          naObrisi: (stavka) =>
              _obrisiBudzetKategorije(context, p, stavka),
        ),
      ],
    );
  }
}

class _KarticaNema extends StatelessWidget {
  final VoidCallback naPostavi;

  const _KarticaNema({
    required this.naPostavi,
  });

  @override
  Widget build(BuildContext context) {
    final shema = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: shema.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: shema.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: shema.primary,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Postavi mjesečni budžet',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Postavi koliko želiš potrošiti ovaj mjesec i prati koliko ti je još preostalo.',
            style: textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: shema.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: naPostavi,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Postavi budžet'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KarticaBudzet extends StatelessWidget {
  final Pregled pregled;
  final VoidCallback naUredi;

  const _KarticaBudzet({
    required this.pregled,
    required this.naUredi,
  });

  @override
  Widget build(BuildContext context) {
    final shema = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final postotak = pregled.postotakBudzeta ?? 0;
    final udio = (postotak / 100).clamp(0.0, 1.0);
    final prekoracen = postotak > 100;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: shema.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: shema.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  prekoracen
                      ? 'Budžet je prekoračen'
                      : 'Preostalo ovaj mjesec',
                  style: textTheme.bodyMedium?.copyWith(
                    color: prekoracen
                        ? shema.error
                        : shema.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: naUredi,
                tooltip: 'Uredi budžet',
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 21,
                ),
                style: IconButton.styleFrom(
                  backgroundColor:
                      shema.surfaceContainerHighest,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            formatNovac(
              pregled.preostaloBudzeta ?? '0',
            ),
            style: textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: prekoracen
                  ? shema.error
                  : shema.onSurface,
            ),
          ),

          const SizedBox(height: 24),

          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: udio,
              minHeight: 8,
              backgroundColor:
                  shema.surfaceContainerHighest,
              color: prekoracen
                  ? shema.error
                  : shema.primary,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${postotak.toStringAsFixed(0)}% iskorišteno',
                style: textTheme.bodySmall?.copyWith(
                  color: prekoracen
                      ? shema.error
                      : shema.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'od ${formatNovac(pregled.raspoloziviBudzet ?? pregled.budzet!)}',
                style: textTheme.bodySmall?.copyWith(
                  color: shema.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Divider(
            height: 1,
            color: shema.outlineVariant.withValues(
              alpha: 0.6,
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _InformacijaBudzeta(
                  naslov: 'Postavljeni budžet',
                  vrijednost:
                      formatNovac(pregled.budzet!),
                  ikona:
                      Icons.account_balance_wallet_outlined,
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: shema.outlineVariant.withValues(
                  alpha: 0.7,
                ),
              ),
              Expanded(
                child: _InformacijaBudzeta(
                  naslov: 'Raspoloživo',
                  vrijednost: formatNovac(
                    pregled.raspoloziviBudzet ?? pregled.budzet!,
                  ),
                  ikona: Icons.savings_outlined,
                ),
              ),
            ],
          ),

          if (uBroj(pregled.ukupnoPrihodi) > 0) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: shema.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    size: 19,
                    color: shema.primary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '+${formatNovac(pregled.ukupnoPrihodi)} prihoda ovog mjeseca uključeno je u raspoloživi budžet.',
                      style: textTheme.bodySmall?.copyWith(
                        color: shema.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InformacijaBudzeta extends StatelessWidget {
  final String naslov;
  final String vrijednost;
  final IconData ikona;

  const _InformacijaBudzeta({
    required this.naslov,
    required this.vrijednost,
    required this.ikona,
  });

  @override
  Widget build(BuildContext context) {
    final shema = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          ikona,
          size: 20,
          color: shema.onSurfaceVariant,
        ),
        const SizedBox(height: 7),
        Text(
          naslov,
          style: textTheme.bodySmall?.copyWith(
            color: shema.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          vrijednost,
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RaspodjelaBudzeta extends StatelessWidget {
  final Pregled pregled;

  const _RaspodjelaBudzeta({
    required this.pregled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    final rasporedeno = uBroj(pregled.rasporedenoPoKategorijama);
    final raspolozivo = uBroj(
      pregled.raspoloziviBudzet ?? pregled.budzet ?? '0',
    );

    final udio = raspolozivo > 0
        ? (rasporedeno / raspolozivo).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: shema.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: shema.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Raspodjela budžeta',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                formatNovac(pregled.preostaloZaRaspodjelu),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: shema.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Preostalo za raspodjelu',
            style: theme.textTheme.bodySmall?.copyWith(
              color: shema.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: udio,
              minHeight: 7,
              backgroundColor: shema.surfaceContainerHighest,
              color: shema.primary,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '${formatNovac(pregled.rasporedenoPoKategorijama)} raspoređeno od ${formatNovac(pregled.raspoloziviBudzet ?? pregled.budzet ?? '0')}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: shema.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudzetiKategorija extends StatelessWidget {
  final Pregled pregled;
  final void Function(StavkaKategorije) naUredi;
  final void Function(StavkaKategorije) naObrisi;

  const _BudzetiKategorija({
    required this.pregled,
    required this.naUredi,
    required this.naObrisi,
  });

  @override
  Widget build(BuildContext context) {
    final kategorije = pregled.poKategorijama
        .where((k) => k.budzet != null)
        .toList();

    if (kategorije.isEmpty) {
      return const _NemaBudzetaKategorija();
    }

    return Column(
      children: [
        for (int i = 0; i < kategorije.length; i++) ...[
          _BudzetKategorijeKartica(
            stavka: kategorije[i],
            naUredi: () => naUredi(kategorije[i]),
            naObrisi: () => naObrisi(kategorije[i]),
          ),
          if (i != kategorije.length - 1)
            const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _BudzetKategorijeKartica extends StatelessWidget {
  final StavkaKategorije stavka;
  final VoidCallback naUredi;
  final VoidCallback naObrisi;

  const _BudzetKategorijeKartica({
    required this.stavka,
    required this.naUredi,
    required this.naObrisi,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    final potroseno = uBroj(stavka.iznos);
    final budzet = uBroj(stavka.budzet ?? '0');

    final postotak =
        budzet > 0 ? (potroseno / budzet) * 100 : 0.0;

    final udio = budzet > 0
        ? (potroseno / budzet).clamp(0.0, 1.0)
        : 0.0;

    final prekoracen =
        potroseno > budzet && budzet > 0;

    final bojaKategorije =
        bojaIzHexa(stavka.boja);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: shema.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: shema.outlineVariant.withValues(
            alpha: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bojaKategorije.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  ikonaIzNaziva(stavka.ikona),
                  color: bojaKategorije,
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      stavka.naziv,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatNovac(stavka.iznos)} potrošeno',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(
                        color: shema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                tooltip: 'Opcije',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (vrijednost) {
                  if (vrijednost == 'uredi') {
                    naUredi();
                  } else if (vrijednost == 'obrisi') {
                    naObrisi();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'uredi',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 10),
                        Text('Uredi budžet'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'obrisi',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded),
                        SizedBox(width: 10),
                        Text('Makni budžet'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: udio,
              minHeight: 7,
              backgroundColor:
                  shema.surfaceContainerHighest,
              color: prekoracen
                  ? shema.error
                  : bojaKategorije,
            ),
          ),

          const SizedBox(height: 9),

          Row(
            children: [
              Text(
                '${postotak.toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall
                    ?.copyWith(
                  color: prekoracen
                      ? shema.error
                      : shema.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'od ${formatNovac(stavka.budzet!)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(
                  color: shema.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                prekoracen
                    ? 'Prekoračeno'
                    : 'Preostalo',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(
                  color: prekoracen
                      ? shema.error
                      : shema.onSurfaceVariant,
                ),
              ),
              Text(
                formatNovac(
                  stavka.preostaloBudzeta ?? '0',
                ),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(
                  color: prekoracen
                      ? shema.error
                      : shema.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NemaBudzetaKategorija extends StatelessWidget {
  const _NemaBudzetaKategorija();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: shema.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: shema.outlineVariant.withValues(
            alpha: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: shema.primary.withValues(
                alpha: 0.1,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pie_chart_outline_rounded,
              color: shema.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Nema postavljenih limita',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Dodaj budžet kategoriji kako bi lakše pratio svoju potrošnju.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: shema.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DijalogBudzeta extends StatefulWidget {
  final String? pocetni;

  const _DijalogBudzeta({
    this.pocetni,
  });

  @override
  State<_DijalogBudzeta> createState() =>
      _DijalogBudzetaState();
}

class _DijalogBudzetaState
    extends State<_DijalogBudzeta> {
  late final TextEditingController _controller;
  String? _greska;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.pocetni?.replaceAll('.', ',') ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spremi() {
    final tekst =
        _controller.text.trim().replaceAll(',', '.');

    final broj = double.tryParse(tekst);

    if (broj == null || broj < 0) {
      setState(() {
        _greska = 'Unesi ispravan iznos';
      });
      return;
    }

    Navigator.pop(
      context,
      broj.toStringAsFixed(2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: const Text(
        'Mjesečni budžet',
        style: TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType:
            const TextInputType.numberWithOptions(
          decimal: true,
        ),
        decoration: InputDecoration(
          labelText: 'Iznos',
          hintText: '0,00',
          suffixText: '€',
          errorText: _greska,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant,
            ),
          ),
        ),
        onSubmitted: (_) => _spremi(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: _spremi,
          child: const Text('Spremi'),
        ),
      ],
    );
  }
}

class _RezultatBudzetaKategorije {
  final Kategorija kategorija;
  final String iznos;

  const _RezultatBudzetaKategorije({
    required this.kategorija,
    required this.iznos,
  });
}

class _DijalogBudzetaKategorije
    extends StatefulWidget {
  final List<Kategorija> kategorije;
  final Kategorija? pocetnaKategorija;
  final String? pocetniIznos;
  final double maksimalniIznos;
  final bool zakljucajKategoriju;

  const _DijalogBudzetaKategorije({
    required this.kategorije,
    required this.maksimalniIznos,
    this.pocetnaKategorija,
    this.pocetniIznos,
    this.zakljucajKategoriju = false,
  });

  @override
  State<_DijalogBudzetaKategorije> createState() =>
      _DijalogBudzetaKategorijeState();
}

class _DijalogBudzetaKategorijeState
    extends State<_DijalogBudzetaKategorije> {
  late final TextEditingController _controller;

  Kategorija? _odabrana;
  String? _greska;

  @override
  void initState() {
    super.initState();

    _odabrana = widget.pocetnaKategorija;

    _controller = TextEditingController(
      text: widget.pocetniIznos
              ?.replaceAll('.', ',') ??
          '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spremi() {
    if (_odabrana == null) {
      setState(() {
        _greska = 'Odaberi kategoriju';
      });
      return;
    }

    final tekst =
        _controller.text.trim().replaceAll(',', '.');

    final broj = double.tryParse(tekst);

    if (broj == null || broj <= 0) {
      setState(() {
        _greska = 'Unesi ispravan iznos';
      });
      return;
    }

    if (broj > widget.maksimalniIznos + 0.001) {
      setState(() {
        _greska =
            'Maksimalno dostupno je ${formatNovac(widget.maksimalniIznos.toStringAsFixed(2))}';
      });
      return;
    }

    Navigator.pop(
      context,
      _RezultatBudzetaKategorije(
        kategorija: _odabrana!,
        iznos: broj.toStringAsFixed(2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Text(
        widget.zakljucajKategoriju
            ? 'Uredi budžet'
            : 'Dodaj budžet',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<Kategorija>(
            initialValue: _odabrana,
            decoration: InputDecoration(
              labelText: 'Kategorija',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: widget.kategorije.map((k) {
              return DropdownMenuItem(
                value: k,
                child: Text(k.naziv),
              );
            }).toList(),
            onChanged: widget.zakljucajKategoriju
                ? null
                : (vrijednost) {
                    setState(() {
                      _odabrana = vrijednost;
                      _greska = null;
                    });
                  },
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _controller,
            autofocus: widget.zakljucajKategoriju,
            keyboardType:
                const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: InputDecoration(
              labelText: 'Iznos',
              hintText: '0,00',
              suffixText: '€',
              errorText: _greska,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onSubmitted: (_) => _spremi(),
          ),
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Maksimalno dostupno: ${formatNovac(widget.maksimalniIznos.toStringAsFixed(2))}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: _spremi,
          child: const Text('Spremi'),
        ),
      ],
    );
  }
}

class _Greska extends StatelessWidget {
  final String poruka;
  final Future<void> Function() naPokusaj;

  const _Greska({
    required this.poruka,
    required this.naPokusaj,
  });

  @override
  Widget build(BuildContext context) {
    final shema = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: shema.error,
            ),
            const SizedBox(height: 14),
            Text(
              poruka,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: naPokusaj,
              child: const Text(
                'Pokušaj ponovno',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
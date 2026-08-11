import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../modeli/pregled.dart';
import '../pomocno/format.dart';
import '../providers/pregled_provider.dart';
import '../servisi/budzet_servis.dart';

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
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pruzatelj = context.watch<PregledPruzatelj>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Budžet',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
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

        Text(
          'Raspodjela',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 12),

        _KarticaKategorije(
          shema: shema,
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
                'od ${formatNovac(pregled.budzet!)}',
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
                  naslov: 'Potrošeno',
                  vrijednost:
                      formatNovac(pregled.ukupnoTroskovi),
                  ikona: Icons.trending_down_rounded,
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
                  naslov: 'Budžet',
                  vrijednost:
                      formatNovac(pregled.budzet!),
                  ikona:
                      Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
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

class _KarticaKategorije extends StatelessWidget {
  final ColorScheme shema;

  const _KarticaKategorije({
    required this.shema,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: shema.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.pie_chart_outline_rounded,
              color: shema.primary,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Budžet po kategorijama',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Raspodijeli budžet na pojedine kategorije.',
                  style: textTheme.bodySmall?.copyWith(
                    color: shema.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: shema.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              'Uskoro',
              style: textTheme.labelSmall?.copyWith(
                color: shema.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
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
      text:
          widget.pocetni?.replaceAll('.', ',') ?? '',
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
      setState(
        () => _greska = 'Unesi ispravan iznos',
      );
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
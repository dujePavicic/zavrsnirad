import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../modeli/pregled.dart';
import '../modeli/transakcija.dart';
import '../pomocno/format.dart';
import '../providers/pregled_provider.dart';
import '../servisi/pregled_servis.dart';
import '../servisi/transakcija_servis.dart';
import 'transakcija_detalj_ekran.dart';

class PregledEkran extends StatefulWidget {
  const PregledEkran({super.key});

  @override
  State<PregledEkran> createState() => _PregledEkranState();
}

class _PregledEkranState extends State<PregledEkran> {
  final PregledServis _pregledServis = PregledServis();
  final TransakcijaServis _transakcijaServis = TransakcijaServis();

  Pregled? _odabraniPregled;
  bool _ucitavaMjesec = false;
  Future<List<Transakcija>>? _tjedneTransakcije;

  bool _jeTrenutniMjesec(Pregled p) {
    final sada = DateTime.now();
    return p.godina == sada.year && p.mjesec == sada.month;
  }

  Future<void> _odaberiMjesec(Pregled trenutni) async {
    var godina = trenutni.godina;

    final odabir = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setModalState(() => godina--),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Text(
                            '$godina',
                            textAlign: TextAlign.center,
                            style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setModalState(() => godina++),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2.2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: 12,
                      itemBuilder: (_, i) {
                        final mjesec = i + 1;
                        final odabran = godina == trenutni.godina &&
                            mjesec == trenutni.mjesec;
                        return odabran
                            ? FilledButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, DateTime(godina, mjesec)),
                                child: Text(imeMjeseca(mjesec)),
                              )
                            : OutlinedButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, DateTime(godina, mjesec)),
                                child: Text(imeMjeseca(mjesec)),
                              );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (odabir == null || !mounted) return;

    setState(() => _ucitavaMjesec = true);
    try {
      final novi = await _pregledServis.dohvatiPregled(
        godina: odabir.year,
        mjesec: odabir.month,
      );
      if (mounted) setState(() => _odabraniPregled = novi);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _ucitavaMjesec = false);
    }
  }

  Future<void> _otvoriTransakcije({
    required String naslov,
    String? datumOd,
    String? datumDo,
    int? godina,
    int? mjesec,
    int? kategorija,
  }) async {
    final future = _transakcijaServis.dohvatiTransakcije(
      tip: 'TROSAK',
      datumOd: datumOd,
      datumDo: datumDo,
      godina: godina,
      mjesec: mjesec,
      kategorija: kategorija,
    ).then((transakcije) {
      if (godina == null || mjesec == null) {
        return transakcije;
      }

      return transakcije.where((transakcija) {
        final datum = DateTime.tryParse(transakcija.datum);

        return datum != null &&
            datum.year == godina &&
            datum.month == mjesec;
      }).toList();
    });

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _DetaljiPotrosnjeSheet(
        naslov: naslov,
        future: future,
      ),
    );
  }

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _pocetakTjedna(DateTime datum) {
    final samoDatum = DateTime(
      datum.year,
      datum.month,
      datum.day,
    );

    return samoDatum.subtract(
      Duration(days: samoDatum.weekday - DateTime.monday),
    );
  }

  Future<List<Transakcija>> _dohvatiTjedneTransakcije() {
    final danas = DateTime.now();
    final ponedjeljak = _pocetakTjedna(danas);

    return _transakcijaServis.dohvatiTransakcije(
      tip: 'TROSAK',
      datumOd: _iso(ponedjeljak),
      datumDo: _iso(danas),
    );
  }

  void _osvjeziTjedan() {
    _tjedneTransakcije = _dohvatiTjedneTransakcije();
  }

  @override
  void initState() {
    super.initState();
    _osvjeziTjedan();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<PregledPruzatelj>();
      if (p.pregled == null && !p.seUcitava) {
        p.osvjezi();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pruzatelj = context.watch<PregledPruzatelj>();
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _tijelo(context, pruzatelj),
      ),
    );
  }

  Widget _tijelo(BuildContext context, PregledPruzatelj pruzatelj) {
    if (pruzatelj.pregled == null) {
      if (pruzatelj.greska != null) {
        return _Greska(
          poruka: pruzatelj.greska!,
          naPokusaj: () => context.read<PregledPruzatelj>().osvjezi(),
        );
      }

      return const _Ucitavanje();
    }

    final prikaz = _odabraniPregled ?? pruzatelj.pregled!;

    return RefreshIndicator(
      onRefresh: () async {
        if (_odabraniPregled != null) {
          final novi = await _pregledServis.dohvatiPregled(
            godina: prikaz.godina,
            mjesec: prikaz.mjesec,
          );
          if (mounted) {
            setState(() {
              _odabraniPregled = novi;
              _osvjeziTjedan();
            });
          }
        } else {
          await context.read<PregledPruzatelj>().osvjezi();
          if (mounted) {
            setState(_osvjeziTjedan);
          }
        }
      },
      child: _sadrzaj(context, prikaz),
    );
  }

  Widget _sadrzaj(BuildContext context, Pregled p) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: [
        _Zaglavlje(
          mjesec: '${imeMjeseca(p.mjesec)} ${p.godina}',
          onMjesecTap: () => _odaberiMjesec(p),
          ucitava: _ucitavaMjesec,
        ),
        const SizedBox(height: 24),

        _GlavnaKartica(
          pregled: p,
          onTap: () => _otvoriTransakcije(
            naslov: 'Potrošnja · ${imeMjeseca(p.mjesec)} ${p.godina}',
            godina: p.godina,
            mjesec: p.mjesec,
          ),
          onKategorijaTap: (k) => _otvoriTransakcije(
            naslov: k.naziv,
            godina: p.godina,
            mjesec: p.mjesec,
            kategorija: k.kategorija,
          ),
        ),

        const SizedBox(height: 16),

        if (_jeTrenutniMjesec(p))
          FutureBuilder<List<Transakcija>>(
            future: _tjedneTransakcije ??= _dohvatiTjedneTransakcije(),
            builder: (context, snapshot) {
              final transakcije =
                  snapshot.data ?? const <Transakcija>[];

              final tjedanPotroseno = transakcije.fold<double>(
                0,
                (zbroj, t) => zbroj + uBroj(t.iznos),
              );

              return _BrziPregledKartice(
                danasPotroseno: p.danasPotroseno,
                tjedanPotroseno: tjedanPotroseno.toStringAsFixed(2),
                onDanasTap: () {
                  final danas = _iso(DateTime.now());

                  _otvoriTransakcije(
                    naslov: 'Današnja potrošnja',
                    datumOd: danas,
                    datumDo: danas,
                  );
                },
                onTjedanTap: () {
                  final danas = DateTime.now();
                  final ponedjeljak = _pocetakTjedna(danas);

                  _otvoriTransakcije(
                    naslov: 'Potrošnja ovaj tjedan',
                    datumOd: _iso(ponedjeljak),
                    datumDo: _iso(danas),
                  );
                },
              );
            },
          ),

        if (p.budzet != null) ...[
          const SizedBox(height: 16),
          _BudzetKartica(pregled: p),
        ],

        const SizedBox(height: 16),
        _GarancijeKartica(sazetak: p.garancije),

        const SizedBox(height: 28),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Zadnje transakcije',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            if (p.zadnjeTransakcije.isNotEmpty)
              Text(
                'Ovaj mjesec',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: shema.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (p.zadnjeTransakcije.isEmpty)
          const _PrazneTransakcije()
        else
          _TransakcijeKartica(
            transakcije: p.zadnjeTransakcije,
            onTap: (t) async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransakcijaDetaljEkran(transakcija: t),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _Zaglavlje extends StatelessWidget {
  final String mjesec;
  final VoidCallback onMjesecTap;
  final bool ucitava;

  const _Zaglavlje({
    required this.mjesec,
    required this.onMjesecTap,
    required this.ucitava,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pregled',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tvoje financije na jednom mjestu',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: shema.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: ucitava ? null : onMjesecTap,
          child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? shema.surfaceContainerHighest.withValues(alpha: 0.72)
                : shema.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: shema.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 17,
                color: shema.primary,
              ),
              const SizedBox(width: 7),
              Text(
                mjesec,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ),
      ],
    );
  }
}

class _GlavnaKartica extends StatelessWidget {
  final Pregled pregled;
  final VoidCallback onTap;
  final ValueChanged<StavkaKategorije> onKategorijaTap;

  const _GlavnaKartica({
    required this.pregled,
    required this.onTap,
    required this.onKategorijaTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: isDark
            ? shema.surfaceContainerHigh.withValues(alpha: 0.88)
            : shema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: shema.outlineVariant.withValues(
            alpha: isDark ? 0.25 : 0.55,
          ),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: shema.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.donut_large_rounded,
                  color: shema.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mjesečna potrošnja',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pregled po kategorijama',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: shema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Donut(pregled: pregled, onKategorijaTap: onKategorijaTap),
        ],
      ),
      ),
    );
  }
}

class _Donut extends StatelessWidget {
  final Pregled pregled;
  final ValueChanged<StavkaKategorije>? onKategorijaTap;

  const _Donut({
    required this.pregled,
    this.onKategorijaTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final imaTroskove = pregled.poKategorijama.isNotEmpty;

    return Column(
      children: [
        SizedBox(
          height: 210,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (imaTroskove)
                PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 68,
                    startDegreeOffset: -90,
                    borderData: FlBorderData(show: false),
                    sections: pregled.poKategorijama.map((k) {
                      return PieChartSectionData(
                        value: uBroj(k.iznos),
                        color: bojaIzHexa(k.boja),
                        radius: 18,
                        showTitle: false,
                      );
                    }).toList(),
                  ),
                )
              else
                SizedBox(
                  width: 172,
                  height: 172,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: shema.outlineVariant,
                        width: 18,
                      ),
                    ),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatNovac(pregled.ukupnoTroskovi),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'potrošeno',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: shema.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (pregled.budzet != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'od ${formatNovac(pregled.raspoloziviBudzet ?? pregled.budzet!)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: shema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        if (imaTroskove) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Kategorije',
              style: theme.textTheme.labelLarge?.copyWith(
                color: shema.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pregled.poKategorijama.map((k) {
              final boja = bojaIzHexa(k.boja);

              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onKategorijaTap?.call(k),
                child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: boja.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: boja.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: boja,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '${k.naziv} ${k.postotak.toStringAsFixed(0)}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _BrziPregledKartice extends StatelessWidget {
  final String danasPotroseno;
  final String tjedanPotroseno;
  final VoidCallback onDanasTap;
  final VoidCallback onTjedanTap;

  const _BrziPregledKartice({
    required this.danasPotroseno,
    required this.tjedanPotroseno,
    required this.onDanasTap,
    required this.onTjedanTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MalaStatistikaKartica(
            naslov: 'Danas',
            vrijednost: formatNovac(danasPotroseno),
            opis: 'potrošeno',
            ikona: Icons.today_rounded,
            onTap: onDanasTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MalaStatistikaKartica(
            naslov: 'Ovaj tjedan',
            vrijednost: formatNovac(tjedanPotroseno),
            opis: 'od ponedjeljka',
            ikona: Icons.date_range_rounded,
            onTap: onTjedanTap,
          ),
        ),
      ],
    );
  }
}

class _MalaStatistikaKartica extends StatelessWidget {
  final String naslov;
  final String vrijednost;
  final String opis;
  final IconData ikona;
  final VoidCallback onTap;

  const _MalaStatistikaKartica({
    required this.naslov,
    required this.vrijednost,
    required this.opis,
    required this.ikona,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? shema.surfaceContainerHigh.withValues(alpha: 0.82)
            : shema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: shema.outlineVariant.withValues(
            alpha: isDark ? 0.22 : 0.5,
          ),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: shema.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              ikona,
              size: 20,
              color: shema.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            naslov,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: shema.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              vrijednost,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            opis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: shema.onSurfaceVariant,
            ),
          ),
        ],
      ),
      ),
    );
  }
}




class _BudzetKartica extends StatelessWidget {
  final Pregled pregled;

  const _BudzetKartica({
    required this.pregled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final postotak = pregled.postotakBudzeta ?? 0;
    final udio = (postotak / 100).clamp(0.0, 1.0);

    final Color progressBoja;
    if (postotak >= 100) {
      progressBoja = shema.error;
    } else if (postotak >= 80) {
      progressBoja = Colors.orange;
    } else {
      progressBoja = shema.primary;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? shema.primary.withValues(alpha: 0.075)
            : shema.primary.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: shema.primary.withValues(alpha: isDark ? 0.16 : 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: shema.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
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
                      'Mjesečni budžet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Preostalo ${formatNovac(pregled.preostaloBudzeta ?? "0")}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: shema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${postotak.toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: progressBoja,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: udio,
              minHeight: 8,
              color: progressBoja,
              backgroundColor: shema.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _GarancijeKartica extends StatelessWidget {
  final GarancijeSazetak sazetak;

  const _GarancijeKartica({
    required this.sazetak,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? shema.surfaceContainerHigh.withValues(alpha: 0.82)
            : shema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: shema.outlineVariant.withValues(
            alpha: isDark ? 0.22 : 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: shema.primary.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              color: shema.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Garancije',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sazetak.aktivne == 0
                      ? 'Još nema spremljenih garancija'
                      : '${sazetak.aktivne} aktivne · ${sazetak.istjeceUskoro} istječe uskoro',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: shema.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.notifications_none_rounded,
            color: shema.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _TransakcijeKartica extends StatelessWidget {
  final List<Transakcija> transakcije;
  final ValueChanged<Transakcija> onTap;

  const _TransakcijeKartica({
    required this.transakcije,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? shema.surfaceContainerHigh.withValues(alpha: 0.82)
            : shema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: shema.outlineVariant.withValues(
            alpha: isDark ? 0.22 : 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < transakcije.length; i++) ...[
            _TransakcijaRedak(
              transakcija: transakcije[i],
              onTap: () => onTap(transakcije[i]),
            ),
            if (i != transakcije.length - 1)
              Divider(
                height: 1,
                indent: 72,
                endIndent: 16,
                color: shema.outlineVariant.withValues(alpha: 0.45),
              ),
          ],
        ],
      ),
    );
  }
}

class _TransakcijaRedak extends StatelessWidget {
  final Transakcija transakcija;
  final VoidCallback onTap;

  const _TransakcijaRedak({
    required this.transakcija,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final boja = bojaIzHexa(transakcija.kategorijaBoja);
    final prihod = transakcija.tip == 'PRIHOD';

    return InkWell(
      onTap: onTap,
      child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: boja.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              ikonaIzNaziva(transakcija.kategorijaIkona),
              color: boja,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transakcija.opis.isNotEmpty
                      ? transakcija.opis
                      : transakcija.kategorijaNaziv,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${transakcija.kategorijaNaziv} · ${transakcija.datum}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: shema.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${prihod ? '+' : '-'}${formatNovac(transakcija.iznos)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: prihod ? shema.primary : shema.onSurface,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _PrazneTransakcije extends StatelessWidget {
  const _PrazneTransakcije();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 30,
      ),
      decoration: BoxDecoration(
        color: shema.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: shema.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: shema.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: shema.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Još nema transakcija',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Transakcije za ovaj mjesec prikazat će se ovdje.',
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


class _DetaljiPotrosnjeSheet extends StatelessWidget {
  final String naslov;
  final Future<List<Transakcija>> future;

  const _DetaljiPotrosnjeSheet({
    required this.naslov,
    required this.future,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              naslov,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Transakcija>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        snapshot.error
                            .toString()
                            .replaceFirst('Exception: ', ''),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final transakcije = snapshot.data ?? const <Transakcija>[];

                  if (transakcije.isEmpty) {
                    return Center(
                      child: Text(
                        'Nema troškova za odabrani period.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: shema.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  final ukupno = transakcije.fold<double>(
                    0,
                    (zbroj, t) => zbroj + uBroj(t.iznos),
                  );

                  return ListView(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: shema.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text('Ukupno potrošeno'),
                            ),
                            Text(
                              formatNovac(ukupno.toStringAsFixed(2)),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final t in transakcije)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: bojaIzHexa(t.kategorijaBoja)
                                .withValues(alpha: 0.12),
                            child: Icon(
                              ikonaIzNaziva(t.kategorijaIkona),
                              color: bojaIzHexa(t.kategorijaBoja),
                            ),
                          ),
                          title: Text(
                            t.opis.isNotEmpty ? t.opis : t.kategorijaNaziv,
                          ),
                          subtitle: Text(
                            '${t.kategorijaNaziv} · ${t.datum}',
                          ),
                          trailing: Text(
                            '-${formatNovac(t.iznos)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TransakcijaDetaljEkran(transakcija: t),
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ucitavanje extends StatelessWidget {
  const _Ucitavanje();

  @override
  Widget build(BuildContext context) {
    final shema = Theme.of(context).colorScheme;

    return Center(
      child: CircularProgressIndicator(
        color: shema.primary,
      ),
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
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: shema.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: shema.onErrorContainer,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Nešto je pošlo po zlu',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              poruka,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: shema.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: naPokusaj,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Pokušaj ponovno'),
            ),
          ],
        ),
      ),
    );
  }
}

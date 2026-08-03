import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../modeli/pregled.dart';
import '../modeli/transakcija.dart';
import '../pomocno/format.dart';
import '../servisi/pregled_servis.dart';

class PregledEkran extends StatefulWidget {
  const PregledEkran({super.key});

  @override
  State<PregledEkran> createState() => _PregledEkranState();
}

class _PregledEkranState extends State<PregledEkran> {
  final _servis = PregledServis();
  late Future<Pregled> _buduciPregled;

  @override
  void initState() {
    super.initState();
    _buduciPregled = _servis.dohvatiPregled();
  }

  Future<void> _osvjezi() async {
    final novi = _servis.dohvatiPregled();
    setState(() => _buduciPregled = novi);
    await novi;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pregled')),
      body: FutureBuilder<Pregled>(
        future: _buduciPregled,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _Greska(poruka: snap.error.toString(), naPokusaj: _osvjezi);
          }
          return RefreshIndicator(
            onRefresh: _osvjezi,
            child: _sadrzaj(context, snap.data!),
          );
        },
      ),
    );
  }

  Widget _sadrzaj(BuildContext context, Pregled p) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${imeMjeseca(p.mjesec)} ${p.godina}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        // Donut je sada dio zaslona (bez kartice):
        _Donut(pregled: p),
        if (p.budzet != null) ...[
          const SizedBox(height: 16),
          _BudzetKartica(pregled: p),
        ],
        const SizedBox(height: 24),
        Text('Zadnje transakcije',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (p.zadnjeTransakcije.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Još nema transakcija ovaj mjesec.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          )
        else
          ...p.zadnjeTransakcije.map((t) => _TransakcijaRedak(transakcija: t)),
      ],
    );
  }
}

/// Donut graf potrošnje s iznosom u sredini i legendom.
/// Nije u kartici — sjedi direktno na zaslonu.
class _Donut extends StatelessWidget {
  final Pregled pregled;
  const _Donut({required this.pregled});

  @override
  Widget build(BuildContext context) {
    final shema = Theme.of(context).colorScheme;
    final imaTroskove = pregled.poKategorijama.isNotEmpty;

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (imaTroskove)
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 78,
                    sections: pregled.poKategorijama.map((k) {
                      return PieChartSectionData(
                        value: uBroj(k.iznos),
                        color: bojaIzHexa(k.boja),
                        radius: 20,
                        showTitle: false,
                      );
                    }).toList(),
                  ),
                )
              else
                SizedBox(
                  width: 196,
                  height: 196,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: shema.outlineVariant, width: 20),
                    ),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formatNovac(pregled.ukupnoTroskovi),
                      style: Theme.of(context).textTheme.headlineMedium),
                  Text('potrošeno',
                      style: TextStyle(color: shema.onSurfaceVariant)),
                  if (pregled.budzet != null)
                    Text('od ${formatNovac(pregled.budzet!)} budžeta',
                        style: TextStyle(
                            fontSize: 12, color: shema.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
        if (imaTroskove) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 8,
            children: pregled.poKategorijama.map((k) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: bojaIzHexa(k.boja), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text('${k.naziv} ${k.postotak.toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12)),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// Kartica budžeta s trakom napretka.
class _BudzetKartica extends StatelessWidget {
  final Pregled pregled;
  const _BudzetKartica({required this.pregled});

  @override
  Widget build(BuildContext context) {
    final shema = Theme.of(context).colorScheme;
    final udio = ((pregled.postotakBudzeta ?? 0) / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: shema.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Budžet', style: Theme.of(context).textTheme.titleMedium),
              Text('${(pregled.postotakBudzeta ?? 0).toStringAsFixed(0)}%',
                  style: TextStyle(color: shema.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: udio, minHeight: 10),
          ),
          const SizedBox(height: 8),
          Text('Preostalo: ${formatNovac(pregled.preostaloBudzeta ?? "0")}',
              style: TextStyle(color: shema.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Jedan redak u popisu zadnjih transakcija.
class _TransakcijaRedak extends StatelessWidget {
  final Transakcija transakcija;
  const _TransakcijaRedak({required this.transakcija});

  @override
  Widget build(BuildContext context) {
    final shema = Theme.of(context).colorScheme;
    final boja = bojaIzHexa(transakcija.kategorijaBoja);
    final prihod = transakcija.tip == 'PRIHOD';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: boja.withValues(alpha: 0.15),
        child: Icon(ikonaIzNaziva(transakcija.kategorijaIkona), color: boja),
      ),
      title: Text(transakcija.opis.isNotEmpty
          ? transakcija.opis
          : transakcija.kategorijaNaziv),
      subtitle: Text('${transakcija.kategorijaNaziv} · ${transakcija.datum}'),
      trailing: Text(
        '${prihod ? '+' : '-'}${formatNovac(transakcija.iznos)}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: prihod ? Colors.green : shema.onSurface,
        ),
      ),
    );
  }
}

/// Prikaz greške s gumbom za ponovni pokušaj.
class _Greska extends StatelessWidget {
  final String poruka;
  final Future<void> Function() naPokusaj;
  const _Greska({required this.poruka, required this.naPokusaj});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(poruka, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: naPokusaj, child: const Text('Pokušaj ponovno')),
        ],
      ),
    );
  }
}
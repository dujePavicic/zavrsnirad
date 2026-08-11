import 'package:flutter/material.dart';

import '../modeli/pregled.dart';
import '../pomocno/format.dart';
import '../servisi/budzet_servis.dart';
import '../servisi/pregled_servis.dart';

class BudzetEkran extends StatefulWidget {
  const BudzetEkran({super.key});

  @override
  State<BudzetEkran> createState() => _BudzetEkranState();
}

class _BudzetEkranState extends State<BudzetEkran> {
  final _pregledServis = PregledServis();
  final _budzetServis = BudzetServis();
  late Future<Pregled> _buduci;

  @override
  void initState() {
    super.initState();
    _buduci = _pregledServis.dohvatiPregled();
  }

  Future<void> _osvjezi() async {
    final novi = _pregledServis.dohvatiPregled();
    setState(() => _buduci = novi);
    await novi;
  }

  Future<void> _urediBudzet(Pregled p) async {
    final unos = await showDialog<String>(
      context: context,
      builder: (_) => _DijalogBudzeta(pocetni: p.budzet),
    );
    if (unos == null) return;
    try {
      await _budzetServis.postaviBudzet(
          godina: p.godina, mjesec: p.mjesec, iznos: unos);
      await _osvjezi();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budžet')),
      body: FutureBuilder<Pregled>(
        future: _buduci,
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
    final shema = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${imeMjeseca(p.mjesec)} ${p.godina}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (p.budzet == null)
          _KarticaNema(naPostavi: () => _urediBudzet(p))
        else
          _KarticaBudzet(pregled: p, naUredi: () => _urediBudzet(p)),
        const SizedBox(height: 24),
        // Mjesto za budžet po kategoriji (stiže kad kolega doda backend):
        Card(
          color: shema.surfaceContainerHighest,
          elevation: 0,
          child: ListTile(
            leading: Icon(Icons.donut_small, color: shema.onSurfaceVariant),
            title: const Text('Budžet po kategoriji'),
            subtitle: const Text('Uskoro — razdioba mjesečnog budžeta po kategorijama.'),
          ),
        ),
      ],
    );
  }
}

class _KarticaNema extends StatelessWidget {
  final VoidCallback naPostavi;
  const _KarticaNema({required this.naPostavi});

  @override
  Widget build(BuildContext context) {
    final shema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: shema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.savings_outlined, size: 40, color: shema.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('Za ovaj mjesec nije postavljen budžet.',
              style: TextStyle(color: shema.onSurfaceVariant)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: naPostavi,
            icon: const Icon(Icons.add),
            label: const Text('Postavi budžet'),
          ),
        ],
      ),
    );
  }
}

class _KarticaBudzet extends StatelessWidget {
  final Pregled pregled;
  final VoidCallback naUredi;
  const _KarticaBudzet({required this.pregled, required this.naUredi});

  @override
  Widget build(BuildContext context) {
    final shema = Theme.of(context).colorScheme;
    final udio = ((pregled.postotakBudzeta ?? 0) / 100).clamp(0.0, 1.0);
    final prekoracen = (pregled.postotakBudzeta ?? 0) > 100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: shema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mjesečni budžet',
                  style: Theme.of(context).textTheme.titleMedium),
              TextButton(onPressed: naUredi, child: const Text('Uredi')),
            ],
          ),
          Text(formatNovac(pregled.budzet!),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: udio,
              minHeight: 10,
              color: prekoracen ? shema.error : null,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Potrošeno ${formatNovac(pregled.ukupnoTroskovi)}',
                  style: TextStyle(color: shema.onSurfaceVariant)),
              Text(
                prekoracen
                    ? 'Prekoračeno ${formatNovac(pregled.preostaloBudzeta ?? "0")}'
                    : 'Preostalo ${formatNovac(pregled.preostaloBudzeta ?? "0")}',
                style: TextStyle(
                    color: prekoracen ? shema.error : shema.onSurfaceVariant,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dijalog za unos/izmjenu iznosa budžeta.
class _DijalogBudzeta extends StatefulWidget {
  final String? pocetni;
  const _DijalogBudzeta({this.pocetni});

  @override
  State<_DijalogBudzeta> createState() => _DijalogBudzetaState();
}

class _DijalogBudzetaState extends State<_DijalogBudzeta> {
  late final TextEditingController _controller;
  String? _greska;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
        text: widget.pocetni?.replaceAll('.', ',') ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spremi() {
    final tekst = _controller.text.trim().replaceAll(',', '.');
    final broj = double.tryParse(tekst);
    if (broj == null || broj < 0) {
      setState(() => _greska = 'Unesi ispravan iznos');
      return;
    }
    Navigator.pop(context, broj.toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mjesečni budžet'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Iznos',
          suffixText: '€',
          errorText: _greska,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onSubmitted: (_) => _spremi(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Odustani')),
        FilledButton(onPressed: _spremi, child: const Text('Spremi')),
      ],
    );
  }
}

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
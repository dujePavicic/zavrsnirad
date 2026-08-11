import 'dart:async';
import 'package:flutter/material.dart';

import '../modeli/kategorija.dart';
import '../modeli/racun.dart';
import '../pomocno/format.dart';
import '../pomocno/kategorije_redoslijed.dart';
import '../servisi/kategorija_servis.dart';
import '../servisi/racun_servis.dart';
import 'kategorije_ekran.dart';
import 'racun_detalj_ekran.dart';

class RacuniEkran extends StatefulWidget {
  const RacuniEkran({super.key});

  @override
  State<RacuniEkran> createState() => _RacuniEkranState();
}

class _RacuniEkranState extends State<RacuniEkran> {
  final _servis = RacunServis();
  final _kategorijaServis = KategorijaServis();
  final _pretragaController = TextEditingController();

  late Future<List<Racun>> _buduci;
  List<Kategorija> _vidljive = []; // kategorije za pilule (po redoslijedu)
  int? _odabranaKategorija; // null = "Sve"
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _buduci = _servis.dohvatiRacune();
    _ucitajKategorije();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pretragaController.dispose();
    super.dispose();
  }

  Future<void> _ucitajKategorije() async {
    try {
      final sve = await _kategorijaServis.dohvatiKategorije(tip: 'TROSAK');
      final spremljeno = await ucitajVidljive();
      final p = podijeli(sve, spremljeno);
      if (!mounted) return;
      setState(() {
        _vidljive = p.vidljive;
        // Ako je odabrana kategorija u međuvremenu skrivena, vrati na "Sve".
        if (_odabranaKategorija != null &&
            !_vidljive.any((k) => k.id == _odabranaKategorija)) {
          _odabranaKategorija = null;
        }
      });
    } catch (_) {
      // Pilule nisu ključne; ako padne, samo ih nema.
    }
  }

  String? get _upit {
    final t = _pretragaController.text.trim();
    return t.isEmpty ? null : t;
  }

  void _osvjeziListu() {
    setState(() {
      _buduci = _servis.dohvatiRacune(
        search: _upit,
        kategorija: _odabranaKategorija,
      );
    });
  }

  void _naPromjenuPretrage(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _osvjeziListu);
  }

  Future<void> _povuciZaOsvjezenje() async {
    final novi = _servis.dohvatiRacune(
        search: _upit, kategorija: _odabranaKategorija);
    setState(() => _buduci = novi);
    await novi;
  }

  Future<void> _otvoriUredjivanje() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KategorijeEkran()),
    );
    // Nakon povratka osvježi pilule (vidljivost/redoslijed su se mogli promijeniti).
    await _ucitajKategorije();
    _osvjeziListu();
  }

  Future<void> _otvoriDetalj(Racun r) async {
    final obrisan = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RacunDetaljEkran(racun: r)),
    );
    if (obrisan == true) _osvjeziListu(); // osvježi listu ako je obrisan
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Računi')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Skeniraj račun',
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Skeniranje računa stiže uskoro.')),
          );
        },
        child: const Icon(Icons.document_scanner),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _pretragaController,
              textInputAction: TextInputAction.search,
              onChanged: _naPromjenuPretrage,
              onSubmitted: (_) => _osvjeziListu(),
              decoration: InputDecoration(
                hintText: 'Pretraži po trgovini…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _pretragaController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _pretragaController.clear();
                          _osvjeziListu();
                        },
                      ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          _pilule(),
          Expanded(
            child: FutureBuilder<List<Racun>>(
              future: _buduci,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _Greska(
                      poruka: snap.error.toString(),
                      naPokusaj: _povuciZaOsvjezenje);
                }
                final racuni = snap.data!;
                if (racuni.isEmpty) {
                  return _Prazno(naOsvjezi: _povuciZaOsvjezenje);
                }
                return RefreshIndicator(
                  onRefresh: _povuciZaOsvjezenje,
                  child: _lista(context, racuni),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _pilule() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _pilula('Sve', null),
          ..._vidljive.map((k) => _pilula(k.naziv, k.id)),
          // Gumb za upravljanje kategorijama na kraju reda:
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(Icons.tune, size: 18),
              label: const Text('Dodajte i uredite'),
              onPressed: _otvoriUredjivanje,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pilula(String tekst, int? id) {
    final odabrano = _odabranaKategorija == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(tekst),
        selected: odabrano,
        onSelected: (_) {
          setState(() {
            _odabranaKategorija = id;
            _buduci = _servis.dohvatiRacune(search: _upit, kategorija: id);
          });
        },
      ),
    );
  }

  Widget _lista(BuildContext context, List<Racun> racuni) {
    final grupe = <String, List<Racun>>{};
    for (final r in racuni) {
      grupe.putIfAbsent(r.datum, () => []).add(r);
    }

    final djeca = <Widget>[];
    grupe.forEach((datum, stavke) {
      djeca.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Text(
          _labelDatuma(datum),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ));
      djeca.addAll(stavke.map((r) => _RacunRedak(racun: r, onTap: () => _otvoriDetalj(r))));
    });

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: djeca,
    );
  }
}

String _labelDatuma(String datum) {
  final d = DateTime.tryParse(datum);
  if (d == null) return datum;
  final danas = DateTime.now();
  final jucer = danas.subtract(const Duration(days: 1));
  bool istiDan(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  if (istiDan(d, danas)) return 'Danas';
  if (istiDan(d, jucer)) return 'Jučer';
  return '${d.day}. ${imeMjeseca(d.month).toLowerCase()} ${d.year}';
}

class _RacunRedak extends StatelessWidget {
  final Racun racun;
  final VoidCallback? onTap;
  const _RacunRedak({required this.racun, this.onTap});

  @override
  Widget build(BuildContext context) {
    final shema = Theme.of(context).colorScheme;
    final boja = bojaIzHexa(racun.kategorijaBoja);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: shema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _Slicica(
                    slika: racun.slika,
                    boja: boja,
                    ikona: racun.kategorijaIkona),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        racun.trgovina.isNotEmpty ? racun.trgovina : 'Račun',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(racun.kategorijaNaziv,
                          style: TextStyle(
                              fontSize: 12, color: shema.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text(formatNovac(racun.iznos),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Slicica extends StatelessWidget {
  final String? slika;
  final Color boja;
  final String ikona;
  const _Slicica(
      {required this.slika, required this.boja, required this.ikona});

  @override
  Widget build(BuildContext context) {
    if (slika != null && slika!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          slika!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
          loadingBuilder: (ctx, child, progress) =>
              progress == null ? child : _placeholder(ucitava: true),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder({bool ucitava = false}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: boja.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ucitava
          ? const Center(
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)))
          : Icon(ikonaIzNaziva(ikona), color: boja, size: 22),
    );
  }
}

class _Prazno extends StatelessWidget {
  final Future<void> Function() naOsvjezi;
  const _Prazno({required this.naOsvjezi});

  @override
  Widget build(BuildContext context) {
    final shema = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: naOsvjezi,
      child: ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.receipt_long_outlined,
              size: 48, color: shema.onSurfaceVariant),
          const SizedBox(height: 12),
          Center(
            child: Text('Nema računa za ovaj filter.',
                style: TextStyle(color: shema.onSurfaceVariant)),
          ),
        ],
      ),
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
import 'package:flutter/material.dart';

import '../modeli/kategorija.dart';
import '../pomocno/format.dart';
import '../pomocno/kategorije_redoslijed.dart';
import '../servisi/kategorija_servis.dart';

const _bojeIzbor = [
  '#0F6E56', '#2F6FED', '#E23B3B', '#E38B00', '#8E24AA',
  '#00897B', '#5E35B1', '#C2185B', '#546E7A', '#43A047',
];
const _ikoneIzbor = [
  'shopping_cart', 'directions_car', 'medical_services', 'receipt',
  'bolt', 'movie', 'checkroom', 'home', 'restaurant', 'payments',
  'savings', 'category',
];

class KategorijeEkran extends StatefulWidget {
  const KategorijeEkran({super.key});

  @override
  State<KategorijeEkran> createState() => _KategorijeEkranState();
}

class _KategorijeEkranState extends State<KategorijeEkran> {
  final _servis = KategorijaServis();
  bool _ucitava = true;
  String? _greska;
  List<Kategorija> _vidljive = [];
  List<Kategorija> _skrivene = [];

  @override
  void initState() {
    super.initState();
    _ucitaj();
  }

  Future<void> _ucitaj() async {
    setState(() {
      _ucitava = true;
      _greska = null;
    });
    try {
      final sve = await _servis.dohvatiKategorije(tip: 'TROSAK');
      final spremljeno = await ucitajVidljive();
      final p = podijeli(sve, spremljeno);
      setState(() {
        _vidljive = p.vidljive;
        _skrivene = p.skrivene;
        _ucitava = false;
      });
    } catch (e) {
      setState(() {
        _greska = e.toString();
        _ucitava = false;
      });
    }
  }

  Future<void> _spremiVidljive() async {
    await spremiVidljive(_vidljive.map((k) => k.id).toList());
  }

  void _sakrij(Kategorija k) {
    setState(() {
      _vidljive.removeWhere((x) => x.id == k.id);
      _skrivene.add(k);
    });
    _spremiVidljive();
  }

  void _prikazi(Kategorija k) {
    setState(() {
      _skrivene.removeWhere((x) => x.id == k.id);
      _vidljive.add(k);
    });
    _spremiVidljive();
  }

  void _presloziVidljive(int staro, int novo) {
    setState(() {
      if (novo > staro) novo -= 1;
      final k = _vidljive.removeAt(staro);
      _vidljive.insert(novo, k);
    });
    _spremiVidljive();
  }

  Future<void> _otvoriUrednik({Kategorija? postojeca}) async {
    final rez = await showModalBottomSheet<_Rezultat>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _Urednik(postojeca: postojeca),
    );
    if (rez == null) return;

    try {
      if (rez.obrisi && postojeca != null) {
        await _servis.obrisi(postojeca.id);
        await _ucitaj();
      } else if (postojeca == null) {
        final nova = await _servis.dodaj(
            naziv: rez.naziv, boja: rez.boja, ikona: rez.ikona);
        // Nova kategorija neka odmah bude vidljiva (na kraju popisa).
        final spremljeno = await ucitajVidljive();
        if (spremljeno != null) {
          spremljeno.add(nova.id);
          await spremiVidljive(spremljeno);
        }
        await _ucitaj();
      } else {
        await _servis.azuriraj(
            id: postojeca.id,
            naziv: rez.naziv,
            boja: rez.boja,
            ikona: rez.ikona);
        await _ucitaj();
      }
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
      appBar: AppBar(
        title: const Text('Dodajte i uredite'),
        actions: [
          IconButton(
            tooltip: 'Nova kategorija',
            icon: const Icon(Icons.add),
            onPressed: () => _otvoriUrednik(),
          ),
        ],
      ),
      body: _tijelo(),
    );
  }

  Widget _tijelo() {
    if (_ucitava) return const Center(child: CircularProgressIndicator());
    if (_greska != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_greska!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: _ucitaj, child: const Text('Pokušaj ponovno')),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _karticaVidljive(),
          const SizedBox(height: 16),
          _karticaSkrivene(),
        ],
      ),
    );
  }

  Widget _karticaVidljive() {
    final shema = Theme.of(context).colorScheme;
    return Card(
      color: shema.surfaceContainerHighest,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vidljive',
                style: Theme.of(context).textTheme.titleMedium),
            Text('Drži i povuci za redoslijed. Najvažnije na vrh.',
                style: TextStyle(fontSize: 12, color: shema.onSurfaceVariant)),
            const SizedBox(height: 4),
            if (_vidljive.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Nijedna kategorija nije prikazana.',
                    style: TextStyle(color: shema.onSurfaceVariant)),
              )
            else
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: _presloziVidljive,
                children: [
                  for (int i = 0; i < _vidljive.length; i++)
                    _redakVidljiv(_vidljive[i], i),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _redakVidljiv(Kategorija k, int i) {
    final shema = Theme.of(context).colorScheme;
    final boja = bojaIzHexa(k.boja);
    return ListTile(
      key: ValueKey('v_${k.id}'),
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: boja.withValues(alpha: 0.15),
        child: Icon(ikonaIzNaziva(k.ikona), color: boja),
      ),
      title: Text(k.naziv),
      onTap: k.jeSustavska ? null : () => _otvoriUrednik(postojeca: k),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Sakrij',
            icon: Icon(Icons.remove_circle_outline, color: shema.error),
            onPressed: () => _sakrij(k),
          ),
          ReorderableDragStartListener(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 4),
              child: Icon(Icons.drag_handle, color: shema.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _karticaSkrivene() {
    final shema = Theme.of(context).colorScheme;
    return Card(
      color: shema.surfaceContainerHighest,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Skrivene',
                style: Theme.of(context).textTheme.titleMedium),
            Text('Dodaj u prikaz s +.',
                style: TextStyle(fontSize: 12, color: shema.onSurfaceVariant)),
            const SizedBox(height: 4),
            if (_skrivene.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Sve kategorije su prikazane.',
                    style: TextStyle(color: shema.onSurfaceVariant)),
              )
            else
              ..._skrivene.map((k) {
                final boja = bojaIzHexa(k.boja);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: boja.withValues(alpha: 0.15),
                    child: Icon(ikonaIzNaziva(k.ikona), color: boja),
                  ),
                  title: Text(k.naziv),
                  onTap: k.jeSustavska ? null : () => _otvoriUrednik(postojeca: k),
                  trailing: IconButton(
                    tooltip: 'Prikaži',
                    icon: Icon(Icons.add_circle_outline, color: shema.primary),
                    onPressed: () => _prikazi(k),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// Rezultat uređivanja koji sheet vraća ekranu.
class _Rezultat {
  final String naziv;
  final String boja;
  final String ikona;
  final bool obrisi;
  _Rezultat(
      {required this.naziv,
      required this.boja,
      required this.ikona,
      this.obrisi = false});
}

/// Donji list za dodavanje / uređivanje VLASTITE kategorije.
class _Urednik extends StatefulWidget {
  final Kategorija? postojeca;
  const _Urednik({this.postojeca});

  @override
  State<_Urednik> createState() => _UrednikState();
}

class _UrednikState extends State<_Urednik> {
  late final TextEditingController _naziv;
  late String _boja;
  late String _ikona;

  @override
  void initState() {
    super.initState();
    _naziv = TextEditingController(text: widget.postojeca?.naziv ?? '');
    _boja = widget.postojeca?.boja ?? _bojeIzbor.first;
    _ikona = widget.postojeca?.ikona ?? _ikoneIzbor.first;
  }

  @override
  void dispose() {
    _naziv.dispose();
    super.dispose();
  }

  void _spremi() {
    final naziv = _naziv.text.trim();
    if (naziv.isEmpty) return;
    Navigator.pop(context, _Rezultat(naziv: naziv, boja: _boja, ikona: _ikona));
  }

  @override
  Widget build(BuildContext context) {
    final shema = Theme.of(context).colorScheme;
    final uredjivanje = widget.postojeca != null;
    final boja = bojaIzHexa(_boja);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(uredjivanje ? 'Uredi kategoriju' : 'Nova kategorija',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _naziv,
            autofocus: !uredjivanje,
            decoration: InputDecoration(
              labelText: 'Naziv',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Boja', style: TextStyle(color: shema.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _bojeIzbor.map((hex) {
              final odabrano = hex == _boja;
              return GestureDetector(
                onTap: () => setState(() => _boja = hex),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: bojaIzHexa(hex),
                    shape: BoxShape.circle,
                    border: odabrano
                        ? Border.all(color: shema.onSurface, width: 3)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Ikona', style: TextStyle(color: shema.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _ikoneIzbor.map((naziv) {
              final odabrano = naziv == _ikona;
              return GestureDetector(
                onTap: () => setState(() => _ikona = naziv),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: odabrano
                        ? boja.withValues(alpha: 0.2)
                        : shema.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        odabrano ? Border.all(color: boja, width: 2) : null,
                  ),
                  child: Icon(ikonaIzNaziva(naziv), color: boja),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (uredjivanje)
                TextButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    _Rezultat(
                        naziv: _naziv.text,
                        boja: _boja,
                        ikona: _ikona,
                        obrisi: true),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Obriši'),
                  style: TextButton.styleFrom(foregroundColor: shema.error),
                ),
              const Spacer(),
              FilledButton(
                  onPressed: _spremi,
                  child: Text(uredjivanje ? 'Spremi' : 'Dodaj')),
            ],
          ),
        ],
      ),
    );
  }
}
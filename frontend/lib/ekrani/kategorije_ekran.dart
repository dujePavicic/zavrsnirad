import 'package:flutter/material.dart';

import '../modeli/kategorija.dart';
import '../pomocno/format.dart';
import '../pomocno/kategorije_redoslijed.dart';
import '../servisi/kategorija_servis.dart';

const _bojeIzbor = [
  '#22C55E',
  '#2F6FED',
  '#E23B3B',
  '#E38B00',
  '#8E24AA',
  '#00897B',
  '#5E35B1',
  '#C2185B',
  '#546E7A',
  '#43A047',
];

const _ikoneIzbor = [
  'shopping_cart',
  'directions_car',
  'medical_services',
  'receipt',
  'bolt',
  'movie',
  'checkroom',
  'home',
  'restaurant',
  'payments',
  'savings',
  'category',
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

      if (!mounted) return;

      setState(() {
        _vidljive = p.vidljive;
        _skrivene = p.skrivene;
        _ucitava = false;
      });
    } catch (e) {
      if (!mounted) return;

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

  Future<void> _otvoriUrednik({
    Kategorija? postojeca,
  }) async {
    final rez = await showModalBottomSheet<_Rezultat>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _Urednik(
        postojeca: postojeca,
      ),
    );

    if (rez == null) return;

    try {
      if (rez.obrisi && postojeca != null) {
        await _servis.obrisi(postojeca.id);
        await _ucitaj();
      } else if (postojeca == null) {
        final nova = await _servis.dodaj(
          naziv: rez.naziv,
          boja: rez.boja,
          ikona: rez.ikona,
        );

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
          ikona: rez.ikona,
        );

        await _ucitaj();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Scaffold(
      backgroundColor: shema.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _otvoriUrednik(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova kategorija'),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
              child: _zaglavlje(context),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _tijelo(),
            ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kategorije',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Odaberi što želiš vidjeti i kojim redoslijedom',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: shema.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tijelo() {
    if (_ucitava) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_greska != null) {
      return _Greska(
        poruka: _greska!,
        naPokusaj: _ucitaj,
      );
    }

    return RefreshIndicator(
      onRefresh: _ucitaj,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          _karticaVidljive(),
          const SizedBox(height: 18),
          _karticaSkrivene(),
        ],
      ),
    );
  }

  Widget _karticaVidljive() {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? shema.surfaceContainerHigh.withValues(alpha: 0.9)
            : shema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: shema.outlineVariant.withValues(
            alpha: isDark ? 0.26 : 0.5,
          ),
        ),
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
                  Icons.visibility_outlined,
                  color: shema.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vidljive kategorije',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Drži i povuci za promjenu redoslijeda.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: shema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_vidljive.isEmpty)
            _prazno(
              ikona: Icons.visibility_off_outlined,
              tekst: 'Nijedna kategorija nije prikazana.',
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _vidljive.length,
              onReorder: _presloziVidljive,
              itemBuilder: (context, i) {
                return _redakVidljiv(
                  _vidljive[i],
                  i,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _redakVidljiv(
    Kategorija k,
    int i,
  ) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final boja = bojaIzHexa(k.boja);

    return Container(
      key: ValueKey('v_${k.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: shema.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: shema.outlineVariant.withValues(alpha: 0.38),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: boja.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              ikonaIzNaziva(k.ikona),
              color: boja,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: k.jeSustavska
                  ? null
                  : () => _otvoriUrednik(
                        postojeca: k,
                      ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                ),
                child: Text(
                  k.naziv,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sakrij',
            onPressed: () => _sakrij(k),
            icon: Icon(
              Icons.visibility_off_outlined,
              color: shema.error,
            ),
          ),
          ReorderableDragStartListener(
            index: i,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 10,
              ),
              child: Icon(
                Icons.drag_handle_rounded,
                color: shema.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _karticaSkrivene() {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? shema.surfaceContainerHigh.withValues(alpha: 0.9)
            : shema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: shema.outlineVariant.withValues(
            alpha: isDark ? 0.26 : 0.5,
          ),
        ),
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
                  color: shema.onSurfaceVariant.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.visibility_off_outlined,
                  color: shema.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skrivene kategorije',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vrati kategoriju u prikaz jednim dodirom.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: shema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_skrivene.isEmpty)
            _prazno(
              ikona: Icons.check_circle_outline_rounded,
              tekst: 'Sve kategorije su trenutno prikazane.',
            )
          else
            ..._skrivene.map(
              (k) => _redakSkriven(k),
            ),
        ],
      ),
    );
  }

  Widget _redakSkriven(Kategorija k) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final boja = bojaIzHexa(k.boja);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: shema.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: shema.outlineVariant.withValues(alpha: 0.38),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: boja.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              ikonaIzNaziva(k.ikona),
              color: boja,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: k.jeSustavska
                  ? null
                  : () => _otvoriUrednik(
                        postojeca: k,
                      ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                ),
                child: Text(
                  k.naziv,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Prikaži',
            onPressed: () => _prikazi(k),
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: shema.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _prazno({
    required IconData ikona,
    required String tekst,
  }) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 22,
      ),
      decoration: BoxDecoration(
        color: shema.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: shema.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Icon(
            ikona,
            color: shema.onSurfaceVariant,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            tekst,
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

class _Rezultat {
  final String naziv;
  final String boja;
  final String ikona;
  final bool obrisi;

  _Rezultat({
    required this.naziv,
    required this.boja,
    required this.ikona,
    this.obrisi = false,
  });
}

class _Urednik extends StatefulWidget {
  final Kategorija? postojeca;

  const _Urednik({
    this.postojeca,
  });

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

    _naziv = TextEditingController(
      text: widget.postojeca?.naziv ?? '',
    );

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

    Navigator.pop(
      context,
      _Rezultat(
        naziv: naziv,
        boja: _boja,
        ikona: _ikona,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final uredjivanje = widget.postojeca != null;
    final boja = bojaIzHexa(_boja);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              uredjivanje ? 'Uredi kategoriju' : 'Nova kategorija',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              uredjivanje
                  ? 'Promijeni naziv, boju ili ikonu.'
                  : 'Dodaj novu kategoriju koja će se prikazivati samo tebi.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: shema.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _naziv,
              autofocus: !uredjivanje,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _spremi(),
              decoration: const InputDecoration(
                labelText: 'Naziv',
                hintText: 'npr. Putovanja',
                prefixIcon: Icon(Icons.category_outlined),
              ),
            ),

            const SizedBox(height: 22),

            Text(
              'Boja',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _bojeIzbor.map((hex) {
                final odabrano = hex == _boja;
                final trenutna = bojaIzHexa(hex);

                return InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () {
                    setState(() => _boja = hex);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: trenutna,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: odabrano
                            ? shema.onSurface
                            : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: odabrano
                          ? [
                              BoxShadow(
                                color: trenutna.withValues(alpha: 0.28),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: odabrano
                        ? Icon(
                            Icons.check_rounded,
                            color: ThemeData.estimateBrightnessForColor(
                                      trenutna,
                                    ) ==
                                    Brightness.dark
                                ? Colors.white
                                : Colors.black,
                            size: 19,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 22),

            Text(
              'Ikona',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _ikoneIzbor.map((naziv) {
                final odabrano = naziv == _ikona;

                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() => _ikona = naziv);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: odabrano
                          ? boja.withValues(alpha: 0.16)
                          : shema.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: odabrano
                            ? boja
                            : shema.outlineVariant.withValues(alpha: 0.35),
                        width: odabrano ? 1.5 : 1,
                      ),
                    ),
                    child: Icon(
                      ikonaIzNaziva(naziv),
                      color: odabrano
                          ? boja
                          : shema.onSurfaceVariant,
                      size: 23,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                if (uredjivanje)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        _Rezultat(
                          naziv: _naziv.text,
                          boja: _boja,
                          ikona: _ikona,
                          obrisi: true,
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Obriši'),
                    style: TextButton.styleFrom(
                      foregroundColor: shema.error,
                    ),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _spremi,
                  icon: Icon(
                    uredjivanje
                        ? Icons.check_rounded
                        : Icons.add_rounded,
                  ),
                  label: Text(
                    uredjivanje ? 'Spremi' : 'Dodaj',
                  ),
                ),
              ],
            ),
          ],
        ),
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
              'Nismo mogli učitati kategorije',
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

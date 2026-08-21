import 'dart:async';

import 'package:flutter/material.dart';

import '../modeli/kategorija.dart';
import '../modeli/transakcija.dart';
import '../pomocno/format.dart';
import '../servisi/kategorija_servis.dart';
import '../servisi/transakcija_servis.dart';
import 'transakcija_detalj_ekran.dart';
import 'transakcija_unos_ekran.dart';
import 'skeniranje_racuna_ekran.dart';

class TransakcijeEkran extends StatefulWidget {
  const TransakcijeEkran({super.key});

  @override
  State<TransakcijeEkran> createState() => _TransakcijeEkranState();
}

class _TransakcijeEkranState extends State<TransakcijeEkran> {
  final _servis = TransakcijaServis();
  final _kategorijaServis = KategorijaServis();
  final _pretragaController = TextEditingController();

  late Future<List<Transakcija>> _buduci;

  String? _tip;
  int? _kategorijaId;
  DateTime? _datumOd;
  DateTime? _datumDo;

  List<Kategorija> _kategorije = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _buduci = _dohvati();
    _ucitajKategorije();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pretragaController.dispose();
    super.dispose();
  }

  String? get _search {
    final tekst = _pretragaController.text.trim();
    return tekst.isEmpty ? null : tekst;
  }

  String _datumIso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<Transakcija>> _dohvati() {
    return _servis.dohvatiTransakcije(
      tip: _tip,
      kategorija: _kategorijaId,
      datumOd: _datumOd == null ? null : _datumIso(_datumOd!),
      datumDo: _datumDo == null ? null : _datumIso(_datumDo!),
      search: _search,
      imaRacun: false,
    );
  }

  Future<void> _ucitajKategorije() async {
    try {
      final kategorije = await _kategorijaServis.dohvatiKategorije();

      if (!mounted) return;

      setState(() {
        _kategorije = kategorije;
      });
    } catch (_) {}
  }

  void _osvjeziListu() {
    setState(() {
      _buduci = _dohvati();
    });
  }

  Future<void> _povuciZaOsvjezenje() async {
    final novi = _dohvati();

    setState(() {
      _buduci = novi;
    });

    await novi;
  }

  void _promjenaPretrage(String _) {
    setState(() {});

    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 350), _osvjeziListu);
  }

  Future<void> _otvoriDodavanje() async {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dodaj',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Odaberi način unosa nove stavke.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: shema.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),

              _DodajOpcija(
                ikona: Icons.document_scanner_outlined,
                naslov: 'Skeniraj račun',
                opis: 'Fotografiraj račun i pripremi ga za OCR unos.',
                onTap: () {
                  Navigator.pop(sheetContext);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SkeniranjeRacunaEkran(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              _DodajOpcija(
                ikona: Icons.edit_note_rounded,
                naslov: 'Ručni unos',
                opis: 'Ručno dodaj novu transakciju.',
                onTap: () async {
                  Navigator.pop(sheetContext);

                  final rezultat = await Navigator.push<Transakcija>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransakcijaUnosEkran(),
                    ),
                  );

                  if (rezultat != null) {
                    _osvjeziListu();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _otvoriDetalj(Transakcija transakcija) async {
    final promijenjeno = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransakcijaDetaljEkran(transakcija: transakcija),
      ),
    );

    if (promijenjeno == true) {
      _osvjeziListu();
    } else {
      _osvjeziListu();
    }
  }

  Future<void> _otvoriFiltere() async {
    int? privremenaKategorija = _kategorijaId;
    DateTime? privremeniOd = _datumOd;
    DateTime? privremeniDo = _datumDo;

    final spremi = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                6,
                20,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filteri',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),

                    DropdownButtonFormField<int?>(
                      initialValue: privremenaKategorija,
                      decoration: InputDecoration(
                        labelText: 'Kategorija',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Sve kategorije'),
                        ),
                        ..._kategorije.map(
                          (k) => DropdownMenuItem<int?>(
                            value: k.id,
                            child: Text(k.naziv),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setSheetState(() {
                          privremenaKategorija = v;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    _DatumFilterRedak(
                      naslov: 'Datum od',
                      datum: privremeniOd,
                      onTap: () async {
                        final odabran = await showDatePicker(
                          context: context,
                          initialDate: privremeniOd ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (odabran != null) {
                          setSheetState(() {
                            privremeniOd = odabran;
                          });
                        }
                      },
                      onClear: privremeniOd == null
                          ? null
                          : () {
                              setSheetState(() {
                                privremeniOd = null;
                              });
                            },
                    ),

                    const SizedBox(height: 10),

                    _DatumFilterRedak(
                      naslov: 'Datum do',
                      datum: privremeniDo,
                      onTap: () async {
                        final odabran = await showDatePicker(
                          context: context,
                          initialDate: privremeniDo ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (odabran != null) {
                          setSheetState(() {
                            privremeniDo = odabran;
                          });
                        }
                      },
                      onClear: privremeniDo == null
                          ? null
                          : () {
                              setSheetState(() {
                                privremeniDo = null;
                              });
                            },
                    ),

                    const SizedBox(height: 22),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                privremenaKategorija = null;
                                privremeniOd = null;
                                privremeniDo = null;
                              });
                            },
                            child: const Text('Očisti'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(sheetContext, true),
                            child: const Text('Primijeni'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (spremi != true) return;

    setState(() {
      _kategorijaId = privremenaKategorija;
      _datumOd = privremeniOd;
      _datumDo = privremeniDo;
      _buduci = _dohvati();
    });
  }

  bool get _imaDodatneFiltere =>
      _kategorijaId != null || _datumOd != null || _datumDo != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_transakcije',
        onPressed: _otvoriDodavanje,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Dodaj'),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
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
                          'Transakcije',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ručni prihodi i troškovi bez spremljenog računa',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: shema.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _pretragaController,
                textInputAction: TextInputAction.search,
                onChanged: _promjenaPretrage,
                onSubmitted: (_) => _osvjeziListu(),
                decoration: InputDecoration(
                  hintText: 'Pretraži transakcije...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _pretragaController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Očisti pretragu',
                          onPressed: () {
                            _pretragaController.clear();
                            _osvjeziListu();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: shema.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _TipChip(
                    tekst: 'Sve',
                    odabrano: _tip == null,
                    onTap: () {
                      setState(() {
                        _tip = null;
                        _buduci = _dohvati();
                      });
                    },
                  ),
                  _TipChip(
                    tekst: 'Troškovi',
                    odabrano: _tip == 'TROSAK',
                    onTap: () {
                      setState(() {
                        _tip = 'TROSAK';
                        _buduci = _dohvati();
                      });
                    },
                  ),
                  _TipChip(
                    tekst: 'Prihodi',
                    odabrano: _tip == 'PRIHOD',
                    onTap: () {
                      setState(() {
                        _tip = 'PRIHOD';
                        _buduci = _dohvati();
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(
                        _imaDodatneFiltere
                            ? Icons.filter_alt_rounded
                            : Icons.tune_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _imaDodatneFiltere ? 'Filteri uključeni' : 'Filteri',
                      ),
                      onPressed: _otvoriFiltere,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            Expanded(
              child: FutureBuilder<List<Transakcija>>(
                future: _buduci,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snap.hasError) {
                    return _Greska(
                      poruka: snap.error.toString().replaceFirst(
                        'Exception: ',
                        '',
                      ),
                      naPokusaj: _povuciZaOsvjezenje,
                    );
                  }

                  final transakcije = snap.data ?? [];

                  if (transakcije.isEmpty) {
                    return _Prazno(naOsvjezi: _povuciZaOsvjezenje);
                  }

                  return RefreshIndicator(
                    onRefresh: _povuciZaOsvjezenje,
                    child: _lista(transakcije),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lista(List<Transakcija> transakcije) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    final grupe = <String, List<Transakcija>>{};

    for (final t in transakcije) {
      grupe.putIfAbsent(t.datum, () => []).add(t);
    }

    final djeca = <Widget>[];

    grupe.forEach((datum, stavke) {
      djeca.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: shema.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _labelDatuma(datum),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: shema.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );

      for (final t in stavke) {
        djeca.add(
          _TransakcijaRedak(transakcija: t, onTap: () => _otvoriDetalj(t)),
        );
      }
    });

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: djeca,
    );
  }
}

class _TipChip extends StatelessWidget {
  final String tekst;
  final bool odabrano;
  final VoidCallback onTap;

  const _TipChip({
    required this.tekst,
    required this.odabrano,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(tekst),
        selected: odabrano,
        showCheckmark: false,
        side: BorderSide(
          color: odabrano
              ? shema.primary.withValues(alpha: 0.25)
              : shema.outlineVariant.withValues(alpha: 0.55),
        ),
        selectedColor: shema.primary.withValues(alpha: 0.13),
        backgroundColor: shema.surfaceContainerLow,
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          color: odabrano ? shema.primary : shema.onSurfaceVariant,
          fontWeight: odabrano ? FontWeight.w700 : FontWeight.w600,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _TransakcijaRedak extends StatelessWidget {
  final Transakcija transakcija;
  final VoidCallback onTap;

  const _TransakcijaRedak({required this.transakcija, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final boja = bojaIzHexa(transakcija.kategorijaBoja);
    final prihod = transakcija.tip == 'PRIHOD';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? shema.surfaceContainerHigh.withValues(alpha: 0.85)
                  : shema.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: shema.outlineVariant.withValues(
                  alpha: isDark ? 0.24 : 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: boja.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    ikonaIzNaziva(transakcija.kategorijaIkona),
                    color: boja,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 13),
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: boja,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${prihod ? 'Prihod' : 'Trošak'} · ${transakcija.kategorijaNaziv}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: shema.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${prihod ? '+' : '-'}${formatNovac(transakcija.iznos)}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: prihod ? shema.primary : shema.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: shema.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DatumFilterRedak extends StatelessWidget {
  final String naslov;
  final DateTime? datum;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DatumFilterRedak({
    required this.naslov,
    required this.datum,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final shema = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: shema.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.event_outlined, color: shema.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  datum == null
                      ? naslov
                      : '$naslov: ${datum!.day}.${datum!.month}.${datum!.year}.',
                ),
              ),
              if (onClear != null)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
      ),
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

class _Prazno extends StatelessWidget {
  final Future<void> Function() naOsvjezi;

  const _Prazno({required this.naOsvjezi});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: naOsvjezi,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 70, 28, 120),
        children: [
          Container(
            width: 64,
            height: 64,
            margin: const EdgeInsets.symmetric(horizontal: 110),
            decoration: BoxDecoration(
              color: shema.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.swap_horiz_rounded,
              size: 30,
              color: shema.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Nema transakcija',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Za odabrane filtere trenutno nema ručno unesenih transakcija.',
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

class _Greska extends StatelessWidget {
  final String poruka;
  final Future<void> Function() naPokusaj;

  const _Greska({required this.poruka, required this.naPokusaj});

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

class _DodajOpcija extends StatelessWidget {
  final IconData ikona;
  final String naslov;
  final String opis;
  final VoidCallback onTap;

  const _DodajOpcija({
    required this.ikona,
    required this.naslov,
    required this.opis,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: shema.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: shema.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: shema.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(ikona, color: shema.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      naslov,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      opis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: shema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: shema.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

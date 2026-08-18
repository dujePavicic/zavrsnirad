import 'dart:async';

import 'package:flutter/material.dart';

import '../modeli/kategorija.dart';
import '../modeli/racun.dart';
import '../modeli/garancija.dart';
import '../pomocno/format.dart';
import '../pomocno/kategorije_redoslijed.dart';
import '../servisi/kategorija_servis.dart';
import '../servisi/racun_servis.dart';
import '../servisi/garancija_servis.dart';
import '../servisi/auth_servis.dart';
import '../servisi/obavijesti_servis.dart';
import 'kategorije_ekran.dart';
import 'racun_detalj_ekran.dart';
import 'transakcija_unos_ekran.dart';
import 'skeniranje_racuna_ekran.dart';
import 'garancija_unos_ekran.dart';
import 'garancija_detalj_ekran.dart';

class RacuniEkran extends StatefulWidget {
  final String initialPrikaz;

  const RacuniEkran({
    super.key,
    this.initialPrikaz = 'racuni',
  });

  @override
  State<RacuniEkran> createState() => _RacuniEkranState();
}

class _RacuniEkranState extends State<RacuniEkran> {
  final _servis = RacunServis();
  final _kategorijaServis = KategorijaServis();
  final _pretragaController = TextEditingController();
  final _garancijaServis = GarancijaServis();
  final _authServis = AuthServis();
  final _obavijestiServis = ObavijestiServis();

  late Future<List<Racun>> _buduci;
  late Future<List<Garancija>> _buduceGarancije;
  List<Kategorija> _vidljive = [];
  int? _odabranaKategorija;
  late String _odabraniPrikaz;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _odabraniPrikaz = widget.initialPrikaz == 'garancije'
        ? 'garancije'
        : 'racuni';
    _buduci = _servis.dohvatiRacune();
    _buduceGarancije = _garancijaServis.dohvatiGarancije();
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

        if (_odabranaKategorija != null &&
            !_vidljive.any((k) => k.id == _odabranaKategorija)) {
          _odabranaKategorija = null;
        }
      });
    } catch (_) {}
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
      search: _upit,
      kategorija: _odabranaKategorija,
    );

    setState(() => _buduci = novi);
    await novi;
  }

  Future<void> _otvoriUredjivanje() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KategorijeEkran()),
    );

    await _ucitajKategorije();
    _osvjeziListu();
  }

  Future<void> _otvoriDetalj(Racun r) async {
    final obrisan = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RacunDetaljEkran(racun: r)),
    );

    if (obrisan == true) {
      _osvjeziListu();
    }
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
                onTap: () async {
                  Navigator.pop(sheetContext);

                  final spremljen = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SkeniranjeRacunaEkran(),
                    ),
                  );

                  if (spremljen == true && mounted) {
                    _osvjeziListu();
                  }
                },
              ),

              const SizedBox(height: 10),

              _DodajOpcija(
                ikona: Icons.edit_note_rounded,
                naslov: 'Ručni unos',
                opis: 'Ručno dodaj novu transakciju.',
                onTap: () {
                  Navigator.pop(sheetContext);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransakcijaUnosEkran(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _zakaziObavijestUpozadini(Garancija garancija) async {
    try {
      final korisnik = await _authServis.dohvatiJa();
      await _obavijestiServis.zakaziGaranciju(garancija, korisnik);
    } catch (_) {}
  }

  Future<void> _otvoriDodavanjeGarancije() async {
    final rezultat = await Navigator.push<GarancijaFormaPodaci>(
      context,
      MaterialPageRoute(
        builder: (_) => const GarancijaUnosEkran(),
      ),
    );

    if (rezultat == null || !mounted) return;

    try {
      final garancija = await _garancijaServis.dodaj(
        nazivProizvoda: rezultat.nazivProizvoda,
        datumKupnje: rezultat.datumKupnje,
        datumIsteka: rezultat.datumIsteka,
        serijskiBroj: rezultat.serijskiBroj,
        napomena: rezultat.napomena,
        obavijesti:
            rezultat.dozivotna ? false : rezultat.obavijesti,
        racun: rezultat.racunId,
      );

      if (!mounted) return;

      final trenutne = await _buduceGarancije.catchError(
        (_) => <Garancija>[],
      );
      if (!mounted) return;

      setState(() {
        _buduceGarancije = Future.value([garancija, ...trenutne]);
      });

      unawaited(_zakaziObavijestUpozadini(garancija));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Garancija je spremljena.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  Future<void> _osvjeziGarancije() async {
    final novi = _garancijaServis.dohvatiGarancije();

    setState(() => _buduceGarancije = novi);

    await novi;
  }

  Future<void> _otvoriGaranciju(Garancija garancija) async {
    final promjena = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GarancijaDetaljEkran(
          garancija: garancija,
        ),
      ),
    );

    if (promjena == true && mounted) {
      await _osvjeziGarancije();
    } else if (mounted) {
      // Uređivanje detalja može promijeniti podatke i bez pop rezultata.
      setState(() {
        _buduceGarancije =
            _garancijaServis.dohvatiGarancije();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final prikazRacuna = _odabraniPrikaz == 'racuni';

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: prikazRacuna ? 'fab_racuni' : 'fab_garancije',
        onPressed: prikazRacuna
            ? _otvoriDodavanje
            : _otvoriDodavanjeGarancije,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          prikazRacuna ? 'Dodaj' : 'Dodaj garanciju',
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _Zaglavlje(),
            ),
            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'racuni',
                      icon: Icon(Icons.receipt_long_outlined),
                      label: Text('Računi'),
                    ),
                    ButtonSegment<String>(
                      value: 'garancije',
                      icon: Icon(Icons.verified_user_outlined),
                      label: Text('Garancije'),
                    ),
                  ],
                  selected: {_odabraniPrikaz},
                  showSelectedIcon: false,
                  onSelectionChanged: (odabrano) {
                    setState(() {
                      _odabraniPrikaz = odabrano.first;
                    });
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.comfortable,
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            if (prikazRacuna) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _Pretraga(
                  controller: _pretragaController,
                  onChanged: _naPromjenuPretrage,
                  onSubmitted: (_) => _osvjeziListu(),
                  onClear: () {
                    _pretragaController.clear();
                    _osvjeziListu();
                  },
                ),
              ),
              const SizedBox(height: 14),
              _pilule(),
              const SizedBox(height: 6),
              Expanded(
                child: FutureBuilder<List<Racun>>(
                  future: _buduci,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const _Ucitavanje();
                    }

                    if (snap.hasError) {
                      return _Greska(
                        poruka: snap.error.toString(),
                        naPokusaj: _povuciZaOsvjezenje,
                      );
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
            ] else ...[
              Expanded(
                child: FutureBuilder<List<Garancija>>(
                  future: _buduceGarancije,
                  builder: (context, snap) {
                    if (snap.connectionState ==
                        ConnectionState.waiting) {
                      return const _Ucitavanje();
                    }

                    if (snap.hasError) {
                      return _Greska(
                        poruka: snap.error.toString(),
                        naPokusaj: _osvjeziGarancije,
                      );
                    }

                    final garancije =
                        snap.data ?? const <Garancija>[];

                    if (garancije.isEmpty) {
                      return _PrazneGarancije(
                        onDodaj: _otvoriDodavanjeGarancije,
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _osvjeziGarancije,
                      child: _GarancijeLista(
                        garancije: garancije,
                        onTap: _otvoriGaranciju,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pilule() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _pilula('Sve', null),
          ..._vidljive.map((k) => _pilula(k.naziv, k.id)),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Uredi'),
              onPressed: _otvoriUredjivanje,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pilula(String tekst, int? id) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final odabrano = _odabranaKategorija == id;

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
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    final grupe = <String, List<Racun>>{};

    for (final r in racuni) {
      grupe.putIfAbsent(r.datum, () => []).add(r);
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

      djeca.addAll(
        stavke.map((r) => _RacunRedak(racun: r, onTap: () => _otvoriDetalj(r))),
      );
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

class _Zaglavlje extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Računi',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Čuvaj račune i prati garancije proizvoda',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: shema.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pretraga extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _Pretraga({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'Pretraži po trgovini...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Očisti pretragu',
                icon: const Icon(Icons.close_rounded),
                onPressed: onClear,
              ),
        fillColor: shema.surfaceContainerHigh,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: shema.outlineVariant.withValues(alpha: 0.42),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: shema.primary, width: 1.5),
        ),
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: shema.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _RacunRedak extends StatelessWidget {
  final Racun racun;
  final VoidCallback? onTap;

  const _RacunRedak({required this.racun, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final boja = bojaIzHexa(racun.kategorijaBoja);

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
                _Slicica(
                  slika: racun.slika,
                  boja: boja,
                  ikona: racun.kategorijaIkona,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        racun.trgovina.isNotEmpty ? racun.trgovina : 'Račun',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                              racun.kategorijaNaziv,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: shema.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (racun.slika != null &&
                              racun.slika!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.image_outlined,
                              size: 15,
                              color: shema.onSurfaceVariant,
                            ),
                          ],
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
                      formatNovac(racun.iznos),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
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

class _Slicica extends StatelessWidget {
  final String? slika;
  final Color boja;
  final String ikona;

  const _Slicica({
    required this.slika,
    required this.boja,
    required this.ikona,
  });

  @override
  Widget build(BuildContext context) {
    if (slika != null && slika!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          slika!,
          width: 54,
          height: 54,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(),
          loadingBuilder: (ctx, child, progress) {
            return progress == null ? child : _placeholder(ucitava: true);
          },
        ),
      );
    }

    return _placeholder();
  }

  Widget _placeholder({bool ucitava = false}) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: boja.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ucitava
          ? const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Icon(ikonaIzNaziva(ikona), color: boja, size: 24),
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

String _labelDatuma(String datum) {
  final d = DateTime.tryParse(datum);

  if (d == null) return datum;

  final danas = DateTime.now();
  final jucer = danas.subtract(const Duration(days: 1));

  bool istiDan(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

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
              Icons.receipt_long_outlined,
              size: 30,
              color: shema.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Nema računa',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Za odabrani filter trenutno nema spremljenih računa.',
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

class _GarancijeLista extends StatelessWidget {
  final List<Garancija> garancije;
  final ValueChanged<Garancija> onTap;

  const _GarancijeLista({
    required this.garancije,
    required this.onTap,
  });

  String _datumPrikaz(String datum) {
    final d = DateTime.tryParse(datum);

    if (d == null) return datum;

    return '${d.day}.${d.month}.${d.year}.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    final sortirane = [...garancije]
      ..sort((a, b) {
        if (a.dozivotna && !b.dozivotna) return 1;
        if (!a.dozivotna && b.dozivotna) return -1;

        final ad = a.datumIsteka == null
            ? DateTime(9999)
            : DateTime.tryParse(a.datumIsteka!) ?? DateTime(9999);
        final bd = b.datumIsteka == null
            ? DateTime(9999)
            : DateTime.tryParse(b.datumIsteka!) ?? DateTime(9999);

        return ad.compareTo(bd);
      });

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      itemCount: sortirane.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final g = sortirane[index];

        final status = g.dozivotna
            ? 'Doživotna'
            : g.istekla
                ? 'Istekla'
                : g.danaDoIsteka != null
                    ? '${g.danaDoIsteka} dana do isteka'
                    : 'Aktivna';

        final statusBoja = g.istekla
            ? shema.error
            : shema.primary;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onTap(g),
            child: Ink(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: shema.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: shema.outlineVariant
                      .withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: statusBoja.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      g.dozivotna
                          ? Icons.all_inclusive_rounded
                          : Icons.verified_user_outlined,
                      color: statusBoja,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.nazivProizvoda,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          g.dozivotna
                              ? 'Garancija: Doživotna'
                              : g.datumIsteka == null
                                  ? 'Bez datuma isteka'
                                  : 'Vrijedi do ${_datumPrikaz(g.datumIsteka!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: shema.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          status,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: statusBoja,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: shema.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PrazneGarancije extends StatelessWidget {
  final VoidCallback? onDodaj;

  const _PrazneGarancije({
    this.onDodaj,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(28, 56, 28, 120),
      children: [
        Container(
          width: 68,
          height: 68,
          margin: const EdgeInsets.symmetric(horizontal: 108),
          decoration: BoxDecoration(
            color: shema.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.verified_user_outlined,
            size: 32,
            color: shema.primary,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Još nema spremljenih garancija',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Garancije proizvoda koje spremiš prikazat će se ovdje.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: shema.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _Ucitavanje extends StatelessWidget {
  const _Ucitavanje();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
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

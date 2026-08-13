import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../servisi/racun_servis.dart';
import '../servisi/transakcija_servis.dart';

class SkeniranjeRacunaEkran extends StatefulWidget {
  const SkeniranjeRacunaEkran({super.key});

  @override
  State<SkeniranjeRacunaEkran> createState() =>
      _SkeniranjeRacunaEkranState();
}

class _SkeniranjeRacunaEkranState
    extends State<SkeniranjeRacunaEkran> {
  final ImagePicker _picker = ImagePicker();

  final RacunServis _racunServis = RacunServis();
  final TransakcijaServis _transakcijaServis = TransakcijaServis();

  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  final TextEditingController _trgovinaController =
      TextEditingController();
  final TextEditingController _iznosController =
      TextEditingController();
  final TextEditingController _datumController =
      TextEditingController();
  final TextEditingController _oibController =
      TextEditingController();

  XFile? _slika;
  String _prepoznatiTekst = '';
  Map<String, dynamic>? _analiza;

  int? _kategorijaId;
  String _kategorijaNaziv = '';

  bool _obrada = false;
  bool _spremanje = false;

  @override
  void dispose() {
    _textRecognizer.close();
    _trgovinaController.dispose();
    _iznosController.dispose();
    _datumController.dispose();
    _oibController.dispose();
    super.dispose();
  }

  void _ocistiRezultat() {
    _prepoznatiTekst = '';
    _analiza = null;
    _kategorijaId = null;
    _kategorijaNaziv = '';

    _trgovinaController.clear();
    _iznosController.clear();
    _datumController.clear();
    _oibController.clear();
  }

  Future<void> _fotografirajRacun() async {
    try {
      final slika = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (slika == null) return;

      setState(() {
        _slika = slika;
        _ocistiRezultat();
      });

      await _pokreniOcr(slika);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Greška pri fotografiranju: $e',
          ),
        ),
      );
    }
  }

  Future<void> _odaberiIzGalerije() async {
    try {
      final slika = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (slika == null) return;

      setState(() {
        _slika = slika;
        _ocistiRezultat();
      });

      await _pokreniOcr(slika);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Greška pri odabiru slike: $e',
          ),
        ),
      );
    }
  }

  Future<void> _pokreniOcr(XFile slika) async {
    setState(() {
      _obrada = true;
    });

    try {
      final inputImage = InputImage.fromFilePath(slika.path);

      final rezultat = await _textRecognizer.processImage(
        inputImage,
      );

      final tekst = rezultat.text;

      debugPrint(
        '========== OCR POČETAK ==========',
      );

      debugPrint(tekst);

      debugPrint(
        '=========== OCR KRAJ ===========',
      );

      if (tekst.trim().isEmpty) {
        if (!mounted) return;

        setState(() {
          _ocistiRezultat();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Na slici nije pronađen tekst.',
            ),
          ),
        );

        return;
      }

      debugPrint(
        '========== ANALIZA POČETAK ==========',
      );

      final analiza = await _racunServis.analizirajRacun(
        tekst,
      );

      debugPrint(
        analiza.toString(),
      );

      debugPrint(
        '=========== ANALIZA KRAJ ===========',
      );

      if (!mounted) return;

      final trgovina =
          analiza['trgovina']?.toString() ?? '';
      final iznos =
          analiza['iznos']?.toString() ?? '';
      final datum =
          analiza['datum']?.toString() ?? '';
      final oib =
          analiza['oib']?.toString() ?? '';

      final kategorija = analiza['kategorija'];

      setState(() {
        _prepoznatiTekst = tekst;
        _analiza = analiza;

        _trgovinaController.text = trgovina;
        _iznosController.text = iznos;
        _datumController.text = datum;
        _oibController.text = oib;

        _kategorijaId = kategorija is int
            ? kategorija
            : int.tryParse(
                kategorija?.toString() ?? '',
              );

        _kategorijaNaziv =
            analiza['kategorija_naziv']?.toString() ??
                '';
      });
    } catch (e) {
      debugPrint(
        'Greška tijekom OCR/analize: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Greška tijekom obrade računa: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _obrada = false;
        });
      }
    }
  }

  Future<void> _otvoriSliku() async {
    final slika = _slika;
    if (slika == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PregledRacunaEkran(
          putanja: slika.path,
        ),
      ),
    );
  }

  Future<void> _odaberiDatum() async {
    DateTime pocetniDatum =
        DateTime.tryParse(_datumController.text.trim()) ??
            DateTime.now();

    final odabran = await showDatePicker(
      context: context,
      initialDate: pocetniDatum,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (odabran == null) return;

    _datumController.text = _datumIso(odabran);
  }

  String _datumIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  bool _datumJeIspravan(String vrijednost) {
    final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');

    if (!regex.hasMatch(vrijednost)) {
      return false;
    }

    final datum = DateTime.tryParse(vrijednost);

    return datum != null &&
        _datumIso(datum) == vrijednost;
  }

  String _ispravljeniPrepoznatiTekst({
    required String trgovina,
    required String iznos,
    required String datum,
    required String oib,
  }) {
    final dijelovi = <String>[
      'Trgovina: ${trgovina.isEmpty ? '-' : trgovina}',
      'Iznos: $iznos',
      'Datum: $datum',
      'OIB: ${oib.isEmpty ? '-' : oib}',
      'Kategorija: ${_kategorijaNaziv.isEmpty ? '-' : _kategorijaNaziv}',
    ];

    return dijelovi.join('\n');
  }

  Future<void> _spremi() async {
    if (_slika == null || _analiza == null) {
      return;
    }

    final trgovina = _trgovinaController.text.trim();

    final iznosUnos = _iznosController.text
        .trim()
        .replaceAll(',', '.');

    final iznosBroj = double.tryParse(iznosUnos);

    if (iznosBroj == null || iznosBroj <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unesi ispravan iznos računa.',
          ),
        ),
      );
      return;
    }

    final datum = _datumController.text.trim();

    if (!_datumJeIspravan(datum)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unesi datum u formatu GGGG-MM-DD.',
          ),
        ),
      );
      return;
    }

    final kategorijaId = _kategorijaId;

    if (kategorijaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kategorija nije prepoznata. '
            'Račun se trenutno ne može spremiti.',
          ),
        ),
      );
      return;
    }

    final oib = _oibController.text.trim();
    final iznos = iznosBroj.toStringAsFixed(2);

    setState(() {
      _spremanje = true;
    });

    int? novaTransakcijaId;

    try {
      final transakcija = await _transakcijaServis.dodaj(
        tip: 'TROSAK',
        iznos: iznos,
        kategorija: kategorijaId,
        datum: datum,
        opis: trgovina,
      );

      novaTransakcijaId = transakcija.id;

      final slikaBytes = await _slika!.readAsBytes();

      final nazivSlike = _slika!.name.trim().isNotEmpty
          ? _slika!.name
          : 'racun.jpg';

      await _racunServis.dodajPostojecojTransakciji(
        transakcijaId: transakcija.id,
        slikaBytes: slikaBytes,
        nazivSlike: nazivSlike,
        trgovina: trgovina,
        prepoznatiTekst: _ispravljeniPrepoznatiTekst(
          trgovina: trgovina,
          iznos: iznos,
          datum: datum,
          oib: oib,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Račun je uspješno spremljen.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (novaTransakcijaId != null) {
        try {
          await _transakcijaServis.obrisi(
            novaTransakcijaId,
          );
        } catch (_) {
          // Ako rollback ne uspije, originalna greška se i dalje prikazuje.
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Greška pri spremanju računa: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _spremanje = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Skeniranje računa',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: shema.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            32,
          ),
          children: [
            Text(
              'OCR test',
              style: theme
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              'Fotografiraj račun ili odaberi postojeću sliku. '
              'ML Kit će prepoznati tekst, a backend će pokušati '
              'izvući podatke s računa.',
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: shema.onSurfaceVariant,
                height: 1.4,
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            if (_slika != null)
              GestureDetector(
                onTap: _otvoriSliku,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    20,
                  ),
                  child: Image.file(
                    File(
                      _slika!.path,
                    ),
                    height: 280,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: shema.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(
                    20,
                  ),
                  border: Border.all(
                    color: shema.outlineVariant,
                  ),
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 52,
                      color: shema.primary,
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Text(
                      'Još nema odabranog računa',
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

            if (_slika != null) ...[
              const SizedBox(height: 8),
              Text(
                'Dodirni sliku za pregled i zumiranje.',
                textAlign: TextAlign.center,
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: shema.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(
              height: 20,
            ),

            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _obrada || _spremanje
                        ? null
                        : _fotografirajRacun,
                    icon: const Icon(
                      Icons.camera_alt_outlined,
                    ),
                    label: const Text(
                      'Fotografiraj',
                    ),
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _obrada || _spremanje
                        ? null
                        : _odaberiIzGalerije,
                    icon: const Icon(
                      Icons.photo_library_outlined,
                    ),
                    label: const Text(
                      'Galerija',
                    ),
                  ),
                ),
              ],
            ),

            if (_obrada) ...[
              const SizedBox(
                height: 28,
              ),

              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),

                    SizedBox(
                      height: 12,
                    ),

                    Text(
                      'Obrada računa...',
                    ),
                  ],
                ),
              ),
            ],

            if (!_obrada &&
                _analiza != null) ...[
              const SizedBox(
                height: 28,
              ),

              Text(
                'Prepoznati tekst',
                style: theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(
                height: 6,
              ),

              Text(
                'Provjeri prepoznate podatke i po potrebi ih ispravi prije spremanja.',
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color: shema.onSurfaceVariant,
                  height: 1.4,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              Container(
                padding: const EdgeInsets.all(
                  16,
                ),
                decoration: BoxDecoration(
                  color: shema.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(
                    18,
                  ),
                  border: Border.all(
                    color: shema.outlineVariant,
                  ),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _trgovinaController,
                      enabled: !_spremanje,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Trgovina',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: _iznosController,
                      enabled: !_spremanje,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9,.]'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Iznos',
                        suffixText: '€',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: _datumController,
                      enabled: !_spremanje,
                      keyboardType: TextInputType.datetime,
                      decoration: InputDecoration(
                        labelText: 'Datum',
                        hintText: 'GGGG-MM-DD',
                        border:
                            const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Odaberi datum',
                          onPressed: _spremanje
                              ? null
                              : _odaberiDatum,
                          icon: const Icon(
                            Icons.calendar_month_outlined,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: _oibController,
                      enabled: !_spremanje,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'OIB',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 14),

                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Kategorija',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _kategorijaNaziv.isNotEmpty
                            ? _kategorijaNaziv
                            : 'Nije prepoznato',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _spremanje ? null : _spremi,
                  icon: _spremanje
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.save_outlined,
                        ),
                  label: Text(
                    _spremanje
                        ? 'Spremanje...'
                        : 'Spremi transakciju',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PregledRacunaEkran extends StatelessWidget {
  final String putanja;

  const _PregledRacunaEkran({
    required this.putanja,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pregled računa',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          boundaryMargin: const EdgeInsets.all(
            80,
          ),
          child: Center(
            child: Image.file(
              File(putanja),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

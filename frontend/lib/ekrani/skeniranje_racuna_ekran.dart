import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class SkeniranjeRacunaEkran extends StatefulWidget {
  const SkeniranjeRacunaEkran({super.key});

  @override
  State<SkeniranjeRacunaEkran> createState() =>
      _SkeniranjeRacunaEkranState();
}

class _SkeniranjeRacunaEkranState
    extends State<SkeniranjeRacunaEkran> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  XFile? _slika;
  String _prepoznatiTekst = '';
  bool _obrada = false;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
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
        _prepoznatiTekst = '';
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
        _prepoznatiTekst = '';
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
      final inputImage =
          InputImage.fromFilePath(slika.path);

      final rezultat =
          await _textRecognizer.processImage(inputImage);

      debugPrint('========== OCR POČETAK ==========');
      debugPrint(rezultat.text);
      debugPrint('=========== OCR KRAJ ===========');

      if (!mounted) return;

      setState(() {
        _prepoznatiTekst = rezultat.text;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Greška tijekom OCR obrade: $e',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Scaffold(
      backgroundColor: shema.surface,
      appBar: AppBar(
        title: const Text(
          'Skeniranje računa',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'OCR test',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Fotografiraj račun ili odaberi postojeću sliku. '
              'Prepoznati tekst zasad samo prikazujemo i ispisujemo u konzolu.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: shema.onSurfaceVariant,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 24),

            if (_slika != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  File(_slika!.path),
                  height: 280,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: shema.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
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
                    const SizedBox(height: 12),
                    Text(
                      'Još nema odabranog računa',
                      style:
                          theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        _obrada ? null : _fotografirajRacun,
                    icon: const Icon(
                      Icons.camera_alt_outlined,
                    ),
                    label: const Text(
                      'Fotografiraj',
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _obrada ? null : _odaberiIzGalerije,
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
              const SizedBox(height: 28),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Prepoznavanje teksta...',
                    ),
                  ],
                ),
              ),
            ],

            if (!_obrada &&
                _prepoznatiTekst.isNotEmpty) ...[
              const SizedBox(height: 28),

              Text(
                'Prepoznati tekst',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: shema.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: shema.outlineVariant,
                  ),
                ),
                child: SelectableText(
                  _prepoznatiTekst,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
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
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../modeli/korisnik.dart';
import '../providers/auth_provider.dart';

class ProfilUrediEkran extends StatefulWidget {
  final Korisnik korisnik;

  const ProfilUrediEkran({
    super.key,
    required this.korisnik,
  });

  @override
  State<ProfilUrediEkran> createState() =>
      _ProfilUrediEkranState();
}

class _ProfilUrediEkranState
    extends State<ProfilUrediEkran> {
  late final TextEditingController _imeController;
  late final TextEditingController _prezimeController;
  late final TextEditingController _korisnickoImeController;

  final ImagePicker _picker = ImagePicker();

  XFile? _novaSlika;
  Uint8List? _novaSlikaBytes;

  bool _sprema = false;

  @override
  void initState() {
    super.initState();

    _imeController = TextEditingController(
      text: widget.korisnik.ime,
    );

    _prezimeController = TextEditingController(
      text: widget.korisnik.prezime,
    );

    _korisnickoImeController = TextEditingController(
      text: widget.korisnik.korisnickoIme,
    );
  }

  @override
  void dispose() {
    _imeController.dispose();
    _prezimeController.dispose();
    _korisnickoImeController.dispose();

    super.dispose();
  }

  Future<void> _odaberiSliku() async {
    final slika = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (slika == null) return;

    final bytes = await slika.readAsBytes();

    if (bytes.length > 5 * 1024 * 1024) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profilna slika ne smije biti veća od 5 MB.',
          ),
        ),
      );

      return;
    }

    final ekstenzija = slika.name
        .split('.')
        .last
        .toLowerCase();

    const dozvoljeneEkstenzije = [
      'jpg',
      'jpeg',
      'png',
      'webp',
    ];

    if (!dozvoljeneEkstenzije.contains(ekstenzija)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dozvoljeni formati su JPEG, PNG i WEBP.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _novaSlika = slika;
      _novaSlikaBytes = bytes;
    });
  }

  Future<void> _spremi() async {
    final ime =
        _imeController.text.trim();

    final prezime =
        _prezimeController.text.trim();

    final korisnickoIme =
        _korisnickoImeController.text.trim();

    if (ime.isEmpty ||
        prezime.isEmpty ||
        korisnickoIme.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Popuni sva obavezna polja.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _sprema = true;
    });

    final uspjeh = await context
        .read<AuthPruzatelj>()
        .azurirajProfil(
          ime: ime,
          prezime: prezime,
          korisnickoIme: korisnickoIme,
          slikaBytes: _novaSlikaBytes,
          nazivSlike: _novaSlika?.name,
        );

    if (!mounted) return;

    setState(() {
      _sprema = false;
    });

    if (uspjeh) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profil je uspješno ažuriran.',
          ),
        ),
      );

      Navigator.pop(context);
      return;
    }

    final greska = context
        .read<AuthPruzatelj>()
        .greska;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          greska ??
              'Ne mogu spremiti promjene.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Scaffold(
      backgroundColor: shema.surface,
      appBar: AppBar(
        title: const Text(
          'Osobni podaci',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            32,
          ),
          children: [
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _ProfilnaSlika(
                    korisnik: widget.korisnik,
                    novaSlikaBytes: _novaSlikaBytes,
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Material(
                      color: shema.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _odaberiSliku,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.camera_alt_outlined,
                            size: 19,
                            color: shema.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: _odaberiSliku,
              child: const Text(
                'Promijeni fotografiju',
              ),
            ),

            const SizedBox(height: 22),

            _Polje(
              controller: _imeController,
              label: 'Ime',
              ikona: Icons.person_outline_rounded,
            ),

            const SizedBox(height: 14),

            _Polje(
              controller: _prezimeController,
              label: 'Prezime',
              ikona: Icons.person_outline_rounded,
            ),

            const SizedBox(height: 14),

            _Polje(
              controller: _korisnickoImeController,
              label: 'Korisničko ime',
              ikona: Icons.alternate_email_rounded,
            ),

            const SizedBox(height: 14),

            TextFormField(
              initialValue: widget.korisnik.email,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(
                  Icons.email_outlined,
                ),
                helperText:
                    'Email adresa se ne može mijenjati.',
                filled: true,
                fillColor: shema.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sprema
                    ? null
                    : _spremi,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      16,
                    ),
                  ),
                ),
                child: _sprema
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Spremi promjene',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Polje extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData ikona;

  const _Polje({
    required this.controller,
    required this.label,
    required this.ikona,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(ikona),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _ProfilnaSlika extends StatelessWidget {
  final Korisnik korisnik;
  final Uint8List? novaSlikaBytes;

  const _ProfilnaSlika({
    required this.korisnik,
    required this.novaSlikaBytes,
  });

  @override
  Widget build(BuildContext context) {
    final shema =
        Theme.of(context).colorScheme;

    Widget fallback() {
      return Container(
        color: shema.primary.withValues(
          alpha: 0.14,
        ),
        alignment: Alignment.center,
        child: Text(
          _inicijali(korisnik),
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
                color: shema.primary,
                fontWeight: FontWeight.w800,
              ),
        ),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: 104,
        height: 104,
        child: novaSlikaBytes != null
            ? Image.memory(
                novaSlikaBytes!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    fallback(),
              )
            : korisnik.profilnaSlika != null &&
                    korisnik.profilnaSlika!.isNotEmpty
                ? Image.network(
                    korisnik.profilnaSlika!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        fallback(),
                  )
                : fallback(),
      ),
    );
  }

  String _inicijali(
    Korisnik korisnik,
  ) {
    final prvo =
        korisnik.ime.isNotEmpty
            ? korisnik.ime[0]
            : '';

    final drugo =
        korisnik.prezime.isNotEmpty
            ? korisnik.prezime[0]
            : '';

    final rezultat =
        '$prvo$drugo'.toUpperCase();

    return rezultat.isEmpty
        ? '?'
        : rezultat;
  }
}
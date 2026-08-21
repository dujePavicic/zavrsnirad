import 'package:flutter/material.dart';

import '../modeli/korisnik.dart';
import '../servisi/auth_servis.dart';
import '../servisi/garancija_servis.dart';
import '../servisi/obavijesti_servis.dart';

class PostavkeObavijestiEkran extends StatefulWidget {
  const PostavkeObavijestiEkran({super.key});

  @override
  State<PostavkeObavijestiEkran> createState() =>
      _PostavkeObavijestiEkranState();
}

class _PostavkeObavijestiEkranState extends State<PostavkeObavijestiEkran> {
  final AuthServis _authServis = AuthServis();
  final GarancijaServis _garancijaServis = GarancijaServis();
  final ObavijestiServis _obavijestiServis = ObavijestiServis();

  Korisnik? _korisnik;
  bool _ucitavanje = true;
  bool _spremanje = false;

  bool _ukljucene = true;
  int _dana = 30;

  static const _ponudeniDani = <int>[1, 3, 7, 14, 30, 60, 90];

  @override
  void initState() {
    super.initState();
    _ucitaj();
  }

  Future<void> _ucitaj() async {
    try {
      final korisnik = await _authServis.dohvatiJa();

      if (!mounted) return;

      setState(() {
        _korisnik = korisnik;
        _ukljucene = korisnik.obavijestiGarancije;
        _dana = korisnik.podsjetnikGarancijeDana;
        _ucitavanje = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _ucitavanje = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('AuthGreska: ', ''))),
      );
    }
  }

  Future<void> _spremi() async {
    if (_spremanje) return;

    setState(() => _spremanje = true);

    try {
      var ukljucene = _ukljucene;

      if (ukljucene) {
        final dozvoljeno = await _obavijestiServis.zatraziDozvolu();

        if (!dozvoljeno) {
          ukljucene = false;

          if (mounted) {
            setState(() => _ukljucene = false);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Sustav nije dopustio obavijesti. '
                  'Možeš ih kasnije uključiti u postavkama uređaja.',
                ),
              ),
            );
          }
        }
      }

      final korisnik = await _authServis.azurirajPostavkeObavijesti(
        obavijestiGarancije: ukljucene,
        podsjetnikGarancijeDana: _dana,
      );

      final garancije = await _garancijaServis.dohvatiGarancije();

      if (korisnik.obavijestiGarancije) {
        await _obavijestiServis.sinkronizirajSve(garancije, korisnik);
      } else {
        await _obavijestiServis.otkaziSveGarancije(garancije);
      }

      if (!mounted) return;

      setState(() {
        _korisnik = korisnik;
        _ukljucene = korisnik.obavijestiGarancije;
        _dana = korisnik.podsjetnikGarancijeDana;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Postavke obavijesti su spremljene.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e
                .toString()
                .replaceFirst('AuthGreska: ', '')
                .replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _spremanje = false);
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
          'Obavijesti',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _ucitavanje
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: shema.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: shema.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _ukljucene,
                      onChanged: _spremanje
                          ? null
                          : (vrijednost) {
                              setState(() {
                                _ukljucene = vrijednost;
                              });
                            },
                      secondary: Icon(
                        Icons.notifications_active_outlined,
                        color: shema.primary,
                      ),
                      title: const Text('Obavijesti o garancijama'),
                      subtitle: const Text(
                        'Primi podsjetnik prije nego što garancija istekne.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Podsjetnik',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Odaberi koliko dana prije isteka želiš dobiti obavijest.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: shema.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _ponudeniDani.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.9,
                        ),
                    itemBuilder: (context, index) {
                      final dani = _ponudeniDani[index];
                      final odabrano = _dana == dani;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: !_ukljucene || _spremanje
                              ? null
                              : () {
                                  setState(() => _dana = dani);
                                },
                          child: Ink(
                            decoration: BoxDecoration(
                              color: odabrano
                                  ? shema.primary.withValues(alpha: 0.13)
                                  : shema.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: odabrano
                                    ? shema.primary.withValues(alpha: 0.45)
                                    : shema.outlineVariant.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                dani == 1 ? '1 dan' : '$dani dana',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: odabrano
                                      ? shema.primary
                                      : shema.onSurface,
                                  fontWeight: odabrano
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _spremanje ? null : _spremi,
                    icon: _spremanje
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _spremanje ? 'Spremanje...' : 'Spremi postavke',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_korisnik != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Doživotne garancije nemaju datum isteka i za njih se '
                      'obavijesti ne zakazuju.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: shema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

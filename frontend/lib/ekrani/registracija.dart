import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../themes/default_tema.dart';
import '../assets/logo.dart';

class RegistracijaEkran extends StatefulWidget {
  const RegistracijaEkran({super.key});

  @override
  State<RegistracijaEkran> createState() => _RegistracijaEkranState();
}

class _RegistracijaEkranState extends State<RegistracijaEkran> {
  final _obrazac = GlobalKey<FormState>();

  final _imeController = TextEditingController();
  final _prezimeController = TextEditingController();
  final _korisnickoImeController = TextEditingController();
  final _emailController = TextEditingController();
  final _lozinkaController = TextEditingController();
  final _potvrdaController = TextEditingController();

  bool _lozinkaSkrivena = true;
  bool _potvrdaLozinkaSkrivena = true;

  @override
  void dispose() {
    _imeController.dispose();
    _prezimeController.dispose();
    _korisnickoImeController.dispose();
    _emailController.dispose();
    _lozinkaController.dispose();
    _potvrdaController.dispose();
    super.dispose();
  }

  Future<void> _registrirajSe() async {
    if (!_obrazac.currentState!.validate()) return;

    final auth = context.read<AuthPruzatelj>();

    final uspjeh = await auth.registracija(
      email: _emailController.text.trim(),
      korisnickoIme: _korisnickoImeController.text.trim(),
      ime: _imeController.text.trim(),
      prezime: _prezimeController.text.trim(),
      lozinka: _lozinkaController.text,
    );

    if (!mounted) return;

    if (uspjeh) {
      Navigator.pop(context);
    } else if (auth.greska != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.greska!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthPruzatelj>();
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -60,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: shema.primary.withValues(
                    alpha: isDark ? 0.08 : 0.06,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -90,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: shema.primary.withValues(
                    alpha: isDark ? 0.05 : 0.04,
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 440,
                  ),
                  child: Form(
                    key: _obrazac,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        
                        const SizedBox(height: 8),

                        const Align(
                          alignment: Alignment.center,
                          child: Logo(),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'Napravite račun',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Kreirajte svoj račun i počnite pratiti financije na jednostavniji način.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: shema.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 28),

                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? shema.surfaceContainerHigh
                                    .withValues(alpha: 0.9)
                                : shema.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: shema.outlineVariant.withValues(
                                alpha: isDark ? 0.28 : 0.5,
                              ),
                            ),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.045),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Osnovni podaci',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Unesite podatke potrebne za registraciju.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: shema.onSurfaceVariant,
                                ),
                              ),

                              const SizedBox(height: 20),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _imeController,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.givenName,
                                      ],
                                      decoration: izgledPolja(
                                        oznaka: 'Ime',
                                        natuknica: 'Ime',
                                        ikona: Icons.badge_outlined,
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Unesite ime';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _prezimeController,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.familyName,
                                      ],
                                      decoration: izgledPolja(
                                        oznaka: 'Prezime',
                                        natuknica: 'Prezime',
                                        ikona: Icons.badge_outlined,
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Unesite prezime';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _korisnickoImeController,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.username,
                                ],
                                decoration: izgledPolja(
                                  oznaka: 'Korisničko ime',
                                  natuknica: 'npr. ime123',
                                  ikona: Icons.person_outline_rounded,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Unesite korisničko ime';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.email,
                                ],
                                decoration: izgledPolja(
                                  oznaka: 'Email',
                                  natuknica: 'ime.prezime@mail.hr',
                                  ikona: Icons.email_outlined,
                                ),
                                validator: (v) {
                                  final tekst = (v ?? '').trim();

                                  if (tekst.isEmpty) {
                                    return 'Unesite email';
                                  }

                                  final uzorak =
                                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

                                  if (!uzorak.hasMatch(tekst)) {
                                    return 'Neispravan email';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _lozinkaController,
                                obscureText: _lozinkaSkrivena,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                decoration: izgledPolja(
                                  oznaka: 'Lozinka',
                                  natuknica: 'Najmanje 8 znakova',
                                  ikona: Icons.lock_outline_rounded,
                                  sufiks: IconButton(
                                    tooltip: _lozinkaSkrivena
                                        ? 'Prikaži lozinku'
                                        : 'Sakrij lozinku',
                                    icon: Icon(
                                      _lozinkaSkrivena
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _lozinkaSkrivena =
                                            !_lozinkaSkrivena;
                                      });
                                    },
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Unesite lozinku';
                                  }

                                  if (v.length < 8) {
                                    return 'Lozinka mora imati barem 8 znakova';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _potvrdaController,
                                obscureText: _potvrdaLozinkaSkrivena,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                onFieldSubmitted: (_) {
                                  if (!auth.seUcitava) {
                                    _registrirajSe();
                                  }
                                },
                                decoration: izgledPolja(
                                  oznaka: 'Potvrdi lozinku',
                                  natuknica: 'Ponovite lozinku',
                                  ikona: Icons.lock_reset_rounded,
                                  sufiks: IconButton(
                                    tooltip: _potvrdaLozinkaSkrivena
                                        ? 'Prikaži lozinku'
                                        : 'Sakrij lozinku',
                                    icon: Icon(
                                      _potvrdaLozinkaSkrivena
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _potvrdaLozinkaSkrivena =
                                            !_potvrdaLozinkaSkrivena;
                                      });
                                    },
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Ponovite lozinku';
                                  }

                                  if (v != _lozinkaController.text) {
                                    return 'Lozinke se ne poklapaju';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 22),

                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: auth.seUcitava
                                      ? null
                                      : _registrirajSe,
                                  child: AnimatedSwitcher(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    child: auth.seUcitava
                                        ? const SizedBox(
                                            key: ValueKey('loading'),
                                            width: 21,
                                            height: 21,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Row(
                                            key: ValueKey('register'),
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.person_add_alt_1_rounded,
                                                size: 20,
                                              ),
                                              SizedBox(width: 9),
                                              Text('Registriraj se'),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Već imate račun?',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: shema.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Prijavite se'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 14,
                              color: shema.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Vaši podaci koriste se samo za vaš korisnički račun',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: shema.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

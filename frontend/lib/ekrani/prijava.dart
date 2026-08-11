import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../themes/default_tema.dart';
import '../assets/logo.dart';
import 'registracija.dart';

class PrijavaEkran extends StatefulWidget {
  const PrijavaEkran({super.key});

  @override
  State<PrijavaEkran> createState() => _PrijavaEkranState();
}

class _PrijavaEkranState extends State<PrijavaEkran> {
  final _obrazac = GlobalKey<FormState>();
  final _identifikatorController = TextEditingController();
  final _lozinkaController = TextEditingController();

  bool _lozinkaSkrivena = true;

  @override
  void dispose() {
    _identifikatorController.dispose();
    _lozinkaController.dispose();
    super.dispose();
  }

  Future<void> _prijaviSe() async {
    if (!_obrazac.currentState!.validate()) return;

    final auth = context.read<AuthPruzatelj>();

    final uspjeh = await auth.prijava(
      identifikator: _identifikatorController.text.trim(),
      lozinka: _lozinkaController.text,
    );

    if (!uspjeh && mounted && auth.greska != null) {
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
      backgroundColor: shema.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: shema.primary.withValues(
                    alpha: isDark ? 0.09 : 0.07,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -110,
              left: -80,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: shema.primary.withValues(
                    alpha: isDark ? 0.06 : 0.045,
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                  ),
                  child: Form(
                    key: _obrazac,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.center,
                          child: Logo(),
                        ),

                        const SizedBox(height: 28),

                        Text(
                          'Dobro došli natrag',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Prijavite se i nastavite pratiti svoje financije.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: shema.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 30),

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
                                'Prijava',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Unesite podatke svog korisničkog računa.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: shema.onSurfaceVariant,
                                ),
                              ),

                              const SizedBox(height: 20),

                              TextFormField(
                                controller: _identifikatorController,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                decoration: izgledPolja(
                                  oznaka: 'Email ili korisničko ime',
                                  natuknica: 'Unesite email ili korisničko ime',
                                  ikona: Icons.person_outline_rounded,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Unesite email ili korisničko ime';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _lozinkaController,
                                obscureText: _lozinkaSkrivena,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.password,
                                ],
                                onFieldSubmitted: (_) {
                                  if (!auth.seUcitava) {
                                    _prijaviSe();
                                  }
                                },
                                decoration: izgledPolja(
                                  oznaka: 'Lozinka',
                                  natuknica: 'Unesite lozinku',
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
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed:
                                      auth.seUcitava ? null : _prijaviSe,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(
                                      milliseconds: 180,
                                    ),
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
                                            key: ValueKey('login'),
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.login_rounded,
                                                size: 20,
                                              ),
                                              SizedBox(width: 9),
                                              Text('Prijavi se'),
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
                              'Nemate račun?',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: shema.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const RegistracijaEkran(),
                                  ),
                                );
                              },
                              child: const Text('Registrirajte se'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 14,
                              color: shema.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Vaši podaci ostaju zaštićeni',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: shema.onSurfaceVariant,
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

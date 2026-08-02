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
      // Registracija je automatski i prijavila korisnika →
      // Putokaz (u main.dart) već pokazuje početni ekran, pa samo
      // zatvorimo ovaj ekran da se otkrije ispod.
      Navigator.pop(context);
    } else if (auth.greska != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.greska!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthPruzatelj>();
    final shema = Theme.of(context).colorScheme;

    return Scaffold(
      // Prozirni AppBar samo zbog strelice za povratak na prijavu.
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _obrazac,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ---- ZAGLAVLJE ----
                    const Logo(),
                    const SizedBox(height: 18),
                    Text(
                      'Napravite račun',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ispunite podatke za novi račun',
                      style: TextStyle(color: shema.onSurfaceVariant),
                    ),
                    const SizedBox(height: 26),

                    // ---- KARTICA S POLJIMA ----
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: shema.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: shema.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          // Ime i prezime jedno pored drugoga:
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _imeController,
                                  decoration: izgledPolja(
                                    oznaka: 'Ime',
                                    natuknica: 'Ime',
                                    ikona: Icons.badge_outlined,
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Unesite ime'
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _prezimeController,
                                  decoration: izgledPolja(
                                    oznaka: 'Prezime',
                                    natuknica: 'Prezime',
                                    ikona: Icons.badge_outlined,
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Unesite prezime'
                                          : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Korisničko ime:
                          TextFormField(
                            controller: _korisnickoImeController,
                            decoration: izgledPolja(
                              oznaka: 'Korisničko ime',
                              natuknica: 'korisnickoime123',
                              ikona: Icons.person_outline,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Unesite korisničko ime'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Email:
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: izgledPolja(
                              oznaka: 'Email',
                              natuknica: 'imeprezime@mail.hr',
                              ikona: Icons.email_outlined,
                            ),
                            validator: (v) {
                              final tekst = (v ?? '').trim();
                              if (tekst.isEmpty) return 'Unesite email';
                              final uzorak = RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                              if (!uzorak.hasMatch(tekst)) {
                                return 'Neispravan email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Lozinka (s prekidačem vidljivosti):
                          TextFormField(
                            controller: _lozinkaController,
                            obscureText: _lozinkaSkrivena,
                            decoration: izgledPolja(
                              oznaka: 'Lozinka',
                              natuknica: 'lozinka123',
                              ikona: Icons.lock_outline,
                              sufiks: IconButton(
                                icon: Icon(
                                  _lozinkaSkrivena
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(
                                    () => _lozinkaSkrivena = !_lozinkaSkrivena),
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

                          // Potvrda lozinke (mora se poklapati):
                          TextFormField(
                            controller: _potvrdaController,
                            obscureText: _potvrdaLozinkaSkrivena,
                            decoration: izgledPolja(
                              oznaka: 'Potvrdi lozinku',
                              natuknica: 'lozinka123',
                              ikona: Icons.lock_outline,
                              sufiks: IconButton(
                                icon: Icon(
                                  _potvrdaLozinkaSkrivena
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(
                                    () => _potvrdaLozinkaSkrivena = !_potvrdaLozinkaSkrivena),
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
                          const SizedBox(height: 20),

                          // Gumb registracije:
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed:
                                  auth.seUcitava ? null : _registrirajSe,
                              child: auth.seUcitava
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: shema.onPrimary,
                                      ),
                                    )
                                  : const Text('Registriraj se'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ---- LINK NATRAG NA PRIJAVU ----
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text.rich(
                        TextSpan(
                          text: 'Već imate račun? ',
                          style: TextStyle(color: shema.onSurfaceVariant),
                          children: [
                            TextSpan(
                              text: 'Prijavite se',
                              style: TextStyle(
                                color: shema.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
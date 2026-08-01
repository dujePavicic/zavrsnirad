import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../themes/default_tema.dart';
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
    // Kontrolere uvijek treba osloboditi da ne curi memorija.
    _identifikatorController.dispose();
    _lozinkaController.dispose();
    super.dispose();
  }

  Future<void> _prijaviSe() async {
    // Prvo provjeri jesu li polja ispravno ispunjena.
    if (!_obrazac.currentState!.validate()) return;

    final auth = context.read<AuthPruzatelj>();
    final uspjeh = await auth.prijava(
      identifikator: _identifikatorController.text.trim(),
      lozinka: _lozinkaController.text,
    );

    // Ako ne uspije, provider je postavio poruku greške — prikaži je.
    // Ako uspije, Putokaz (u main.dart) automatski prebacuje na početni ekran.
    if (!uspjeh && mounted && auth.greska != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.greska!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthPruzatelj>();
    // Sve boje uzimamo iz sheme → automatski rade u svijetlom i tamnom načinu.
    final shema = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              // Ograniči širinu da na širokom ekranu (web/desktop) ne bude razvučeno.
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _obrazac,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ---- ZAGLAVLJE ----
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: shema.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet,
                        size: 34,
                        color: shema.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Dobro došli natrag',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prijavi se u svoj račun',
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
                          // Polje: email ili korisničko ime
                          TextFormField(
                            controller: _identifikatorController,
                            decoration: izgledPolja(
                              oznaka: 'Email ili korisničko ime',
                              natuknica: 'imeprezime@mail.hr',
                              ikona: Icons.person_outline,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Unesi email ili korisničko ime'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Polje: lozinka (s prekidačem vidljivosti)
                          TextFormField(
                            controller: _lozinkaController,
                            obscureText: _lozinkaSkrivena,
                            decoration: izgledPolja(
                              oznaka: 'Lozinka',
                              natuknica: '••••••••',
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
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Unesi lozinku'
                                : null,
                          ),
                          const SizedBox(height: 20),

                          // Gumb prijave (FilledButton sam koristi boju naglaska):
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: auth.seUcitava ? null : _prijaviSe,
                              child: auth.seUcitava
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: shema.onPrimary,
                                      ),
                                    )
                                  : const Text('Prijavi se'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ---- LINK NA REGISTRACIJU ----
                    TextButton(
                      onPressed: () {
                            Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RegistracijaEkran(),
                            ),
                          );
                      },
                      child: Text.rich(
                        TextSpan(
                          text: 'Nemaš račun? ',
                          style: TextStyle(color: shema.onSurfaceVariant),
                          children: [
                            TextSpan(
                              text: 'Registriraj se',
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
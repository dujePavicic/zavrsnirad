import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

import 'pregled_ekran.dart';
import 'racuni_ekran.dart';
import 'budzet_ekran.dart';
import 'transakcije_ekran.dart';
import 'profil_uredi_ekran.dart';

class GlavniEkran
    extends StatefulWidget {
  const GlavniEkran({
    super.key,
  });

  @override
  State<GlavniEkran>
      createState() =>
          _GlavniEkranState();
}

class _GlavniEkranState
    extends State<GlavniEkran> {
  int _odabraniIndeks = 0;
  int _racuniOsvjezenje = 0;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final shema =
        theme.colorScheme;

    final tabovi = [
      const PregledEkran(),
      const TransakcijeEkran(),
      RacuniEkran(key: ValueKey(_racuniOsvjezenje)),
      const BudzetEkran(),
      const _ProfilTab(),
    ];

    return Scaffold(
      backgroundColor: shema.surface,
      body: IndexedStack(
        index:
            _odabraniIndeks,
        children: tabovi,
      ),
      bottomNavigationBar:
          NavigationBar(
        selectedIndex:
            _odabraniIndeks,
        height: 72,
        onDestinationSelected:
            (i) {
          setState(() {
            _odabraniIndeks = i;

            if (i == 2) {
              _racuniOsvjezenje++;
            }
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Pregled',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz_rounded),
            label: 'Transakcije',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Računi',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Budžet',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _ProfilTab
    extends StatelessWidget {
  const _ProfilTab();

  @override
  Widget build(
    BuildContext context,
  ) {
    final auth =
        context.watch<AuthPruzatelj>();

    final korisnik =
        auth.korisnik;

    final theme =
        Theme.of(context);

    final shema =
        theme.colorScheme;

    final isDark =
        theme.brightness ==
            Brightness.dark;

    return Scaffold(
      backgroundColor:
          shema.surface,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics:
              const BouncingScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            28,
          ),
          children: [
            Text(
              'Profil',
              style: theme
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing:
                        -0.7,
                  ),
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              'Upravljaj svojim računom i postavkama',
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: shema
                        .onSurfaceVariant,
                  ),
            ),

            const SizedBox(
              height: 24,
            ),

            Container(
              padding:
                  const EdgeInsets
                      .all(18),
              decoration:
                  BoxDecoration(
                color: isDark
                    ? shema
                        .surfaceContainerHigh
                        .withValues(
                          alpha:
                              0.9,
                        )
                    : shema
                        .surfaceContainerLowest,
                borderRadius:
                    BorderRadius
                        .circular(
                  24,
                ),
                border:
                    Border.all(
                  color: shema
                      .outlineVariant
                      .withValues(
                        alpha:
                            isDark
                                ? 0.28
                                : 0.5,
                      ),
                ),
              ),
              child: Row(
                children: [
                  _ProfilnaSlikaMala(
                    ime:
                        korisnik?.ime,
                    prezime:
                        korisnik
                            ?.prezime,
                    url: korisnik
                        ?.profilnaSlika,
                  ),

                  const SizedBox(
                    width: 14,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          korisnik !=
                                  null
                              ? '${korisnik.ime} ${korisnik.prezime}'
                              : 'Korisnik',
                          style: theme
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                        ),

                        if (korisnik !=
                            null) ...[
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            '@${korisnik.korisnickoIme}',
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color:
                                      shema
                                          .primary,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                ),
                          ),
                        ],

                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          korisnik
                                  ?.email ??
                              '—',
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style: theme
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: shema
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            Text(
              'Račun',
              style: theme
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
            ),

            const SizedBox(
              height: 12,
            ),

            _ProfilStavka(
              ikona: Icons
                  .person_outline_rounded,
              naslov:
                  'Osobni podaci',
              opis:
                  'Ime, prezime i korisničko ime',
              onTap: korisnik ==
                      null
                  ? () {}
                  : () {
                      Navigator.of(
                        context,
                      ).push(
                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  ProfilUrediEkran(
                            korisnik:
                                korisnik,
                          ),
                        ),
                      );
                    },
            ),

            const SizedBox(
              height: 10,
            ),

            _ProfilStavka(
              ikona: Icons
                  .notifications_none_rounded,
              naslov:
                  'Obavijesti',
              opis:
                  'Upravljanje obavijestima',
              onTap: () {},
            ),

            const SizedBox(
              height: 24,
            ),

            Text(
              'Aplikacija',
              style: theme
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
            ),

            const SizedBox(
              height: 12,
            ),

            _ProfilStavka(
              ikona: Icons
                  .palette_outlined,
              naslov: 'Izgled',
              opis:
                  'Tema i izgled aplikacije',
              onTap: () {},
            ),

            const SizedBox(
              height: 28,
            ),

            OutlinedButton.icon(
              onPressed: () =>
                  context
                      .read<
                          AuthPruzatelj>()
                      .odjava(),
              icon: const Icon(
                Icons.logout_rounded,
              ),
              label:
                  const Text(
                'Odjava',
              ),
              style:
                  OutlinedButton
                      .styleFrom(
                foregroundColor:
                    shema.error,
                side: BorderSide(
                  color: shema.error
                      .withValues(
                    alpha: 0.35,
                  ),
                ),
                padding:
                    const EdgeInsets
                        .symmetric(
                  vertical: 14,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    16,
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

class _ProfilnaSlikaMala
    extends StatelessWidget {
  final String? ime;
  final String? prezime;
  final String? url;

  const _ProfilnaSlikaMala({
    required this.ime,
    required this.prezime,
    required this.url,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    Widget fallback() {
      final shema =
          Theme.of(context)
              .colorScheme;

      return Container(
        color: shema.primary
            .withValues(
          alpha: 0.14,
        ),
        alignment:
            Alignment.center,
        child: Text(
          _inicijali(
            ime,
            prezime,
          ),
          style:
              Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    color:
                        shema.primary,
                    fontWeight:
                        FontWeight.w800,
                  ),
        ),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: 64,
        height: 64,
        child: url != null &&
                url!.isNotEmpty
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) =>
                        fallback(),
              )
            : fallback(),
      ),
    );
  }

  String _inicijali(
    String? ime,
    String? prezime,
  ) {
    final prvo = ime != null &&
            ime!.isNotEmpty
        ? ime![0]
        : '';

    final drugo =
        prezime != null &&
                prezime!.isNotEmpty
            ? prezime![0]
            : '';

    final rezultat =
        '$prvo$drugo'
            .toUpperCase();

    return rezultat.isEmpty
        ? '?'
        : rezultat;
  }
}

class _ProfilStavka
    extends StatelessWidget {
  final IconData ikona;
  final String naslov;
  final String opis;
  final VoidCallback onTap;

  const _ProfilStavka({
    required this.ikona,
    required this.naslov,
    required this.opis,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final shema =
        theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        child: Ink(
          padding:
              const EdgeInsets
                  .all(14),
          decoration:
              BoxDecoration(
            color: shema
                .surfaceContainerHigh,
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border: Border.all(
              color: shema
                  .outlineVariant
                  .withValues(
                alpha: 0.4,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(
                  color: shema
                      .primary
                      .withValues(
                    alpha: 0.1,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    13,
                  ),
                ),
                child: Icon(
                  ikona,
                  color:
                      shema.primary,
                  size: 21,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      naslov,
                      style: theme
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      opis,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: shema
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons
                    .chevron_right_rounded,
                color: shema
                    .onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

import '../modeli/garancija.dart';
import '../servisi/auth_servis.dart';
import '../servisi/garancija_servis.dart';
import '../servisi/obavijesti_servis.dart';
import 'garancija_unos_ekran.dart';

class GarancijaDetaljEkran extends StatefulWidget {
  final Garancija garancija;

  const GarancijaDetaljEkran({
    super.key,
    required this.garancija,
  });

  @override
  State<GarancijaDetaljEkran> createState() =>
      _GarancijaDetaljEkranState();
}

class _GarancijaDetaljEkranState
    extends State<GarancijaDetaljEkran> {
  final GarancijaServis _servis = GarancijaServis();
  final ObavijestiServis _obavijesti = ObavijestiServis();
  final AuthServis _auth = AuthServis();

  late Garancija _garancija;

  @override
  void initState() {
    super.initState();
    _garancija = widget.garancija;
  }

  Future<void> _uredi() async {
    final podaci = await Navigator.push<GarancijaFormaPodaci>(
      context,
      MaterialPageRoute(
        builder: (_) => GarancijaUnosEkran(
          garancija: _garancija,
        ),
      ),
    );

    if (podaci == null || !mounted) return;

    try {
      final azurirana = await _servis.azuriraj(
        id: _garancija.id,
        nazivProizvoda: podaci.nazivProizvoda,
        datumKupnje: podaci.datumKupnje,
        datumIsteka: podaci.datumIsteka,
        dozivotna: podaci.dozivotna,
        serijskiBroj: podaci.serijskiBroj,
        napomena: podaci.napomena,
        obavijesti: podaci.dozivotna ? false : podaci.obavijesti,
        racun: podaci.racunId,
      );

      final korisnik = await _auth.dohvatiJa();

      await _obavijesti.zakaziGaranciju(
        azurirana,
        korisnik,
      );

      if (!mounted) return;

      setState(() => _garancija = azurirana);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Garancija je ažurirana.'),
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

  Future<void> _obrisi() async {
    final potvrda = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Obrisati garanciju?'),
        content: Text(
          'Garancija za ${_garancija.nazivProizvoda} '
          'bit će trajno obrisana.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );

    if (potvrda != true) return;

    try {
      await _servis.obrisi(_garancija.id);
      await _obavijesti.otkaziGaranciju(_garancija.id);

      if (mounted) {
        Navigator.pop(context, true);
      }
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

  String _datumPrikaz(String datum) {
    final d = DateTime.tryParse(datum);

    if (d == null) return datum;

    return '${d.day}.${d.month}.${d.year}.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    final statusTekst = _garancija.dozivotna
        ? 'Doživotna'
        : _garancija.istekla
            ? 'Istekla'
            : _garancija.danaDoIsteka != null
                ? 'Još ${_garancija.danaDoIsteka} dana'
                : 'Aktivna';

    final statusBoja = _garancija.istekla
        ? shema.error
        : shema.primary;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Natrag',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Detalji garancije',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Uredi',
                  onPressed: _uredi,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Obriši',
                  onPressed: _obrisi,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: shema.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: shema.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: shema.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: shema.primary.withValues(alpha: 0.13),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _garancija.dozivotna
                          ? Icons.all_inclusive_rounded
                          : Icons.verified_user_outlined,
                      size: 32,
                      color: shema.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _garancija.nazivProizvoda,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusBoja.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusTekst,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: statusBoja,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _InfoKartica(
              ikona: Icons.shopping_bag_outlined,
              naslov: 'Datum kupnje',
              vrijednost: _datumPrikaz(_garancija.datumKupnje),
            ),
            const SizedBox(height: 10),
            _InfoKartica(
              ikona: _garancija.dozivotna
                  ? Icons.all_inclusive_rounded
                  : Icons.event_available_outlined,
              naslov: 'Garancija vrijedi do',
              vrijednost: _garancija.dozivotna
                  ? 'Doživotna'
                  : _garancija.datumIsteka == null
                      ? '—'
                      : _datumPrikaz(_garancija.datumIsteka!),
            ),
            if (_garancija.serijskiBroj.isNotEmpty) ...[
              const SizedBox(height: 10),
              _InfoKartica(
                ikona: Icons.qr_code_2_rounded,
                naslov: 'Serijski broj',
                vrijednost: _garancija.serijskiBroj,
              ),
            ],
            if (_garancija.racunId != null) ...[
              const SizedBox(height: 10),
              _InfoKartica(
                ikona: Icons.receipt_long_outlined,
                naslov: 'Povezani račun',
                vrijednost:
                    _garancija.racunTrgovina?.isNotEmpty == true
                        ? _garancija.racunTrgovina!
                        : 'Račun #${_garancija.racunId}',
              ),
            ],
            const SizedBox(height: 10),
            _InfoKartica(
              ikona: _garancija.obavijesti
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              naslov: 'Podsjetnik',
              vrijednost: _garancija.dozivotna
                  ? 'Nije potreban'
                  : _garancija.obavijesti
                      ? 'Uključen'
                      : 'Isključen',
            ),
            if (_garancija.napomena.isNotEmpty) ...[
              const SizedBox(height: 10),
              _InfoKartica(
                ikona: Icons.notes_rounded,
                naslov: 'Napomena',
                vrijednost: _garancija.napomena,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoKartica extends StatelessWidget {
  final IconData ikona;
  final String naslov;
  final String vrijednost;

  const _InfoKartica({
    required this.ikona,
    required this.naslov,
    required this.vrijednost,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: shema.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: shema.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: shema.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              ikona,
              color: shema.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  naslov,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: shema.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  vrijednost,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../modeli/racun.dart';
import '../modeli/garancija.dart';

class GarancijaFormaPodaci {
  final String nazivProizvoda;
  final String datumKupnje;
  final String? datumIsteka;
  final bool dozivotna;
  final String serijskiBroj;
  final String napomena;
  final bool obavijesti;
  final int? racunId;

  const GarancijaFormaPodaci({
    required this.nazivProizvoda,
    required this.datumKupnje,
    required this.datumIsteka,
    required this.dozivotna,
    required this.serijskiBroj,
    required this.napomena,
    required this.obavijesti,
    required this.racunId,
  });
}

class GarancijaUnosEkran extends StatefulWidget {
  final Racun? racun;
  final Garancija? garancija;

  const GarancijaUnosEkran({
    super.key,
    this.racun,
    this.garancija,
  });

  @override
  State<GarancijaUnosEkran> createState() =>
      _GarancijaUnosEkranState();
}

class _GarancijaUnosEkranState extends State<GarancijaUnosEkran> {
  final _nazivController = TextEditingController();
  final _serijskiController = TextEditingController();
  final _napomenaController = TextEditingController();

  late DateTime _datumKupnje;
  DateTime? _datumIsteka;
  bool _dozivotna = false;
  bool _obavijesti = true;

  @override
  void initState() {
    super.initState();

    final postojeca = widget.garancija;

    if (postojeca != null) {
      _nazivController.text = postojeca.nazivProizvoda;
      _serijskiController.text = postojeca.serijskiBroj;
      _napomenaController.text = postojeca.napomena;

      _datumKupnje =
          DateTime.tryParse(postojeca.datumKupnje) ?? DateTime.now();

      _datumIsteka = postojeca.datumIsteka == null
          ? null
          : DateTime.tryParse(postojeca.datumIsteka!);

      _dozivotna = postojeca.dozivotna;
      _obavijesti =
          postojeca.dozivotna ? false : postojeca.obavijesti;
    } else {
      _datumKupnje =
          DateTime.tryParse(widget.racun?.datum ?? '') ??
              DateTime.now();
    }
  }

  @override
  void dispose() {
    _nazivController.dispose();
    _serijskiController.dispose();
    _napomenaController.dispose();
    super.dispose();
  }

  String _datumIso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _datumPrikaz(DateTime d) =>
      '${d.day}.${d.month}.${d.year}.';

  Future<void> _odaberiDatumKupnje() async {
    final odabran = await showDatePicker(
      context: context,
      initialDate: _datumKupnje,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (odabran != null) {
      setState(() => _datumKupnje = odabran);
    }
  }

  Future<void> _odaberiDatumIsteka() async {
    if (_dozivotna) return;

    final pocetni = _datumIsteka ??
        DateTime(
          _datumKupnje.year + 2,
          _datumKupnje.month,
          _datumKupnje.day,
        );

    final odabran = await showDatePicker(
      context: context,
      initialDate: pocetni,
      firstDate: _datumKupnje,
      lastDate: DateTime(2200),
    );

    if (odabran != null) {
      setState(() => _datumIsteka = odabran);
    }
  }

  void _postaviTrajanje(int godine) {
    if (_dozivotna) return;

    setState(() {
      _datumIsteka = DateTime(
        _datumKupnje.year + godine,
        _datumKupnje.month,
        _datumKupnje.day,
      );
    });
  }

  void _spremi() {
    final naziv = _nazivController.text.trim();

    if (naziv.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unesi naziv proizvoda.'),
        ),
      );
      return;
    }

    if (!_dozivotna && _datumIsteka == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Odaberi datum isteka garancije.'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      GarancijaFormaPodaci(
        nazivProizvoda: naziv,
        datumKupnje: _datumIso(_datumKupnje),
        datumIsteka:
            _dozivotna ? null : _datumIso(_datumIsteka!),
        dozivotna: _dozivotna,
        serijskiBroj: _serijskiController.text.trim(),
        napomena: _napomenaController.text.trim(),
        obavijesti: _obavijesti,
        racunId:
            widget.racun?.id ?? widget.garancija?.racunId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.garancija == null
              ? 'Nova garancija'
              : 'Uredi garanciju',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (widget.racun != null || widget.garancija?.racunId != null) ...[
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: shema.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: shema.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: shema.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.receipt_long_outlined,
                        color: shema.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Povezano s računom',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: shema.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.racun != null
                                ? (widget.racun!.trgovina.isNotEmpty
                                    ? widget.racun!.trgovina
                                    : 'Račun')
                                : (widget.garancija!.racunTrgovina?.isNotEmpty ==
                                        true
                                    ? widget.garancija!.racunTrgovina!
                                    : 'Povezani račun'),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.link_rounded,
                      color: shema.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            Text(
              'Podaci o proizvodu',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _nazivController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Naziv proizvoda',
                hintText: 'Npr. Bosch usisavač',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _serijskiController,
              decoration: const InputDecoration(
                labelText: 'Serijski broj',
                hintText: 'Nije obavezno',
                prefixIcon: Icon(Icons.qr_code_2_rounded),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Trajanje garancije',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            _DatumPolje(
              naslov: 'Datum kupnje',
              vrijednost: _datumPrikaz(_datumKupnje),
              ikona: Icons.shopping_bag_outlined,
              onTap: _odaberiDatumKupnje,
            ),

            const SizedBox(height: 12),

            SwitchListTile.adaptive(
              value: _dozivotna,
              onChanged: (vrijednost) {
                setState(() {
                  _dozivotna = vrijednost;

                  if (vrijednost) {
                    _datumIsteka = null;
                    _obavijesti = false;
                  }
                });
              },
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: shema.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              secondary: Icon(
                Icons.all_inclusive_rounded,
                color: shema.primary,
              ),
              title: const Text('Doživotna garancija'),
              subtitle: const Text(
                'Garancija nema datum isteka.',
              ),
            ),

            if (!_dozivotna) ...[
              const SizedBox(height: 12),

              Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('1 godina'),
                  onPressed: () => _postaviTrajanje(1),
                ),
                ActionChip(
                  label: const Text('2 godine'),
                  onPressed: () => _postaviTrajanje(2),
                ),
                ActionChip(
                  label: const Text('3 godine'),
                  onPressed: () => _postaviTrajanje(3),
                ),
              ],
            ),

            const SizedBox(height: 12),

              _DatumPolje(
                naslov: 'Garancija vrijedi do',
                vrijednost: _datumIsteka == null
                    ? 'Nije odabrano'
                    : _datumPrikaz(_datumIsteka!),
                ikona: Icons.verified_user_outlined,
                onTap: _odaberiDatumIsteka,
              ),
            ],

            const SizedBox(height: 24),

            Text(
              'Podsjetnik',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),

            SwitchListTile.adaptive(
              value: _dozivotna ? false : _obavijesti,
              onChanged: _dozivotna
                  ? null
                  : (vrijednost) {
                      setState(() => _obavijesti = vrijednost);
                    },
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: shema.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              secondary: Icon(
                Icons.notifications_active_outlined,
                color: shema.primary,
              ),
              title: const Text('Obavijesti o isteku'),
              subtitle: Text(
                _dozivotna
                    ? 'Doživotna garancija nema datum isteka.'
                    : 'Podsjeti me prije isteka garancije.',
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _napomenaController,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Napomena',
                hintText: 'Dodatni podaci o garanciji...',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),

            const SizedBox(height: 26),

            FilledButton.icon(
              onPressed: _spremi,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                widget.garancija == null
                    ? 'Spremi garanciju'
                    : 'Spremi promjene',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatumPolje extends StatelessWidget {
  final String naslov;
  final String vrijednost;
  final IconData ikona;
  final VoidCallback onTap;

  const _DatumPolje({
    required this.naslov,
    required this.vrijednost,
    required this.ikona,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
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
            Icon(
              Icons.chevron_right_rounded,
              color: shema.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

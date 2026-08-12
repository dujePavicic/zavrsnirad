import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../modeli/kategorija.dart';
import '../modeli/transakcija.dart';
import '../pomocno/format.dart';
import '../providers/pregled_provider.dart';
import '../servisi/kategorija_servis.dart';
import '../servisi/transakcija_servis.dart';

class TransakcijaUnosEkran extends StatefulWidget {
  final Transakcija? transakcija;

  const TransakcijaUnosEkran({
    super.key,
    this.transakcija,
  });

  bool get jeUredivanje => transakcija != null;

  @override
  State<TransakcijaUnosEkran> createState() => _TransakcijaUnosEkranState();
}

class _TransakcijaUnosEkranState extends State<TransakcijaUnosEkran> {
  final _servis = TransakcijaServis();
  final _kategorijaServis = KategorijaServis();

  late final TextEditingController _iznosController;
  late final TextEditingController _opisController;

  late String _tip;
  late DateTime _datum;

  List<Kategorija> _kategorije = [];
  int? _kategorijaId;
  bool _spremam = false;

  @override
  void initState() {
    super.initState();

    final t = widget.transakcija;

    _tip = t?.tip ?? 'TROSAK';
    _datum = DateTime.tryParse(t?.datum ?? '') ?? DateTime.now();
    _kategorijaId = t?.kategorija;

    _iznosController = TextEditingController(
      text: t?.iznos.replaceAll('.', ',') ?? '',
    );

    _opisController = TextEditingController(
      text: t?.opis ?? '',
    );

    _ucitajKategorije(zadrziPostojecu: true);
  }

  @override
  void dispose() {
    _iznosController.dispose();
    _opisController.dispose();
    super.dispose();
  }

  Future<void> _ucitajKategorije({
    bool zadrziPostojecu = false,
  }) async {
    try {
      final k = await _kategorijaServis.dohvatiKategorije(tip: _tip);

      if (!mounted) return;

      setState(() {
        _kategorije = k;

        if (zadrziPostojecu &&
            _kategorijaId != null &&
            k.any((e) => e.id == _kategorijaId)) {
          return;
        }

        _kategorijaId = k.isNotEmpty ? k.first.id : null;
      });
    } catch (_) {}
  }

  void _promijeniTip(String noviTip) {
    if (noviTip == _tip) return;

    setState(() {
      _tip = noviTip;
      _kategorije = [];
      _kategorijaId = null;
    });

    _ucitajKategorije();
  }

  Future<void> _odaberiDatum() async {
    final odabran = await showDatePicker(
      context: context,
      initialDate: _datum,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (odabran != null) {
      setState(() => _datum = odabran);
    }
  }

  String _datumIso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _spremi() async {
    final iznosTekst = _iznosController.text.trim().replaceAll(',', '.');
    final broj = double.tryParse(iznosTekst);

    if (broj == null || broj <= 0) {
      _poruka('Unesi ispravan iznos.');
      return;
    }

    if (_kategorijaId == null) {
      _poruka('Odaberi kategoriju.');
      return;
    }

    setState(() => _spremam = true);

    try {
      late final Transakcija rezultat;

      if (widget.transakcija == null) {
        rezultat = await _servis.dodaj(
          tip: _tip,
          iznos: broj.toStringAsFixed(2),
          kategorija: _kategorijaId!,
          datum: _datumIso(_datum),
          opis: _opisController.text.trim(),
        );
      } else {
        rezultat = await _servis.azuriraj(
          id: widget.transakcija!.id,
          tip: _tip,
          iznos: broj.toStringAsFixed(2),
          kategorija: _kategorijaId!,
          datum: _datumIso(_datum),
          opis: _opisController.text.trim(),
        );
      }

      if (!mounted) return;

      await context.read<PregledPruzatelj>().osvjezi();

      if (mounted) {
        Navigator.pop(context, rezultat);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _spremam = false);

      _poruka(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void _poruka(String t) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;
    final jeUredivanje = widget.jeUredivanje;

    return Scaffold(
      backgroundColor: shema.surface,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _zaglavlje(context),
            const SizedBox(height: 20),

            Text(
              'Vrsta transakcije',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),

            _TipPrekidac(
              tip: _tip,
              onPromjena: _promijeniTip,
            ),

            const SizedBox(height: 24),

            Text(
              'Iznos',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _iznosController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
              decoration: const InputDecoration(
                hintText: '0,00',
                suffixText: '€',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Kategorija',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),

            if (_kategorije.isEmpty)
              Container(
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: shema.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _kategorije.map((k) {
                  final odabrana = _kategorijaId == k.id;
                  final boja = bojaIzHexa(k.boja);

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => setState(() => _kategorijaId = k.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: odabrana
                            ? boja.withValues(alpha: 0.14)
                            : shema.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: odabrana
                              ? boja.withValues(alpha: 0.5)
                              : shema.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            ikonaIzNaziva(k.ikona),
                            size: 19,
                            color: boja,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            k.naziv,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: odabrana
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 24),

            Text(
              'Datum',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),

            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _odaberiDatum,
                child: Ink(
                  padding: const EdgeInsets.all(15),
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
                          Icons.event_outlined,
                          color: shema.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _datumIso(_datum),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: shema.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Opis',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _opisController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Dodaj opis transakcije (nije obavezno)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _spremam ? null : _spremi,
                icon: _spremam
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _spremam
                      ? 'Spremanje...'
                      : jeUredivanje
                          ? 'Spremi promjene'
                          : 'Spremi transakciju',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zaglavlje(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Row(
      children: [
        IconButton(
          tooltip: 'Natrag',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.jeUredivanje ? 'Uredi transakciju' : 'Nova transakcija',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.jeUredivanje
                    ? 'Promijeni podatke transakcije'
                    : 'Unesi osnovne podatke transakcije',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: shema.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TipPrekidac extends StatelessWidget {
  final String tip;
  final ValueChanged<String> onPromjena;

  const _TipPrekidac({
    required this.tip,
    required this.onPromjena,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shema = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: shema.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: shema.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TipOpcija(
              tekst: 'Trošak',
              ikona: Icons.arrow_upward_rounded,
              odabrano: tip == 'TROSAK',
              boja: shema.error,
              onTap: () => onPromjena('TROSAK'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _TipOpcija(
              tekst: 'Prihod',
              ikona: Icons.arrow_downward_rounded,
              odabrano: tip == 'PRIHOD',
              boja: shema.primary,
              onTap: () => onPromjena('PRIHOD'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipOpcija extends StatelessWidget {
  final String tekst;
  final IconData ikona;
  final bool odabrano;
  final Color boja;
  final VoidCallback onTap;

  const _TipOpcija({
    required this.tekst,
    required this.ikona,
    required this.odabrano,
    required this.boja,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        decoration: BoxDecoration(
          color: odabrano
              ? boja.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              ikona,
              size: 18,
              color: odabrano
                  ? boja
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 7),
            Text(
              tekst,
              style: theme.textTheme.labelLarge?.copyWith(
                color: odabrano
                    ? boja
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';

import '../modeli/pregled.dart';
import '../servisi/pregled_servis.dart';

/// Jedan izvor podataka pregleda koji dijele ekrani Pregledi i Budžet.
/// Kad se pozove osvjezi(), dohvati nove brojke pa notifyListeners() javi
/// svim ekranima koji ga slušaju da se ponovno iscrtaju.
class PregledPruzatelj extends ChangeNotifier {
  final PregledServis _servis = PregledServis();

  Pregled? _pregled;
  bool _ucitava = false;
  String? _greska;

  Pregled? get pregled => _pregled;
  bool get seUcitava => _ucitava;
  String? get greska => _greska;

  Future<void> osvjezi() async {
    _ucitava = true;
    notifyListeners();
    try {
      _pregled = await _servis.dohvatiPregled();
      _greska = null;
    } catch (e) {
      _greska = e.toString();
    }
    _ucitava = false;
    notifyListeners();
  }
}
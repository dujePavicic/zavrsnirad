import 'package:flutter/foundation.dart';

import '../modeli/korisnik.dart';
import '../servisi/auth_servis.dart';
import '../servisi/token_spremiste.dart';

/// Mogući statusi prijave u aplikaciji.
enum AuthStatus { pocetno, ucitavanje, prijavljen, odjavljen }

class AuthPruzatelj extends ChangeNotifier {
  final AuthServis _servis = AuthServis();
  final TokenSpremiste _tokenSpremiste = TokenSpremiste();

  AuthStatus _status = AuthStatus.pocetno;
  String? _greska;
  Korisnik? _korisnik;

  // Getteri koje ekran čita:
  AuthStatus get status => _status;
  String? get greska => _greska;
  Korisnik? get korisnik => _korisnik;
  bool get seUcitava => _status == AuthStatus.ucitavanje;
  bool get jePrijavljen => _status == AuthStatus.prijavljen;

  /// Poziva se pri pokretanju aplikacije — provjeri postoji li spremljeni token.
  Future<void> provjeriPrijavu() async {
    final refresh = await _tokenSpremiste.dohvatiRefresh();
    _status = (refresh != null) ? AuthStatus.prijavljen : AuthStatus.odjavljen;
    notifyListeners();
  }

  Future<bool> prijava({
    required String identifikator,
    required String lozinka,
  }) async {
    _postaviUcitavanje();
    try {
      await _servis.prijavi(identifikator: identifikator, lozinka: lozinka);
      // Dohvati podatke korisnika za kasnije ekrane (nije kritično za prijavu).
      try {
        _korisnik = await _servis.dohvatiJa();
      } catch (_) {}
      _status = AuthStatus.prijavljen;
      _greska = null;
      notifyListeners();
      return true;
    } on AuthGreska catch (e) {
      _postaviGresku(e.poruka);
      return false;
    } catch (_) {
      _postaviGresku('Ne mogu se povezati s poslužiteljem.');
      return false;
    }
  }

  /// Registracija, pa automatska prijava ako uspije.
  Future<bool> registracija({
    required String email,
    required String korisnickoIme,
    required String ime,
    required String prezime,
    required String lozinka,
  }) async {
    _postaviUcitavanje();
    try {
      _korisnik = await _servis.registriraj(
        email: email,
        korisnickoIme: korisnickoIme,
        ime: ime,
        prezime: prezime,
        lozinka: lozinka,
      );
      // Nakon uspješne registracije odmah prijavi korisnika:
      await _servis.prijavi(identifikator: email, lozinka: lozinka);
      _status = AuthStatus.prijavljen;
      _greska = null;
      notifyListeners();
      return true;
    } on AuthGreska catch (e) {
      _postaviGresku(e.poruka);
      return false;
    } catch (_) {
      _postaviGresku('Ne mogu se povezati s poslužiteljem.');
      return false;
    }
  }

  /// Odjava — briše tokene i vraća stanje na odjavljeno.
  Future<void> odjava() async {
    await _servis.odjavi();
    _korisnik = null;
    _status = AuthStatus.odjavljen;
    _greska = null;
    notifyListeners();
  }

  void _postaviUcitavanje() {
    _status = AuthStatus.ucitavanje;
    _greska = null;
    notifyListeners();
  }

  void _postaviGresku(String poruka) {
    _greska = poruka;
    _status = AuthStatus.odjavljen;
    notifyListeners();
  }
}
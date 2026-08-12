import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../modeli/korisnik.dart';
import '../servisi/auth_servis.dart';
import '../servisi/token_spremiste.dart';
import '../pomocno/kategorije_redoslijed.dart';

enum AuthStatus {
  pocetno,
  ucitavanje,
  prijavljen,
  odjavljen,
}

class AuthPruzatelj extends ChangeNotifier {
  final AuthServis _servis = AuthServis();

  final TokenSpremiste _tokenSpremiste =
      TokenSpremiste();

  AuthStatus _status = AuthStatus.pocetno;

  String? _greska;

  Korisnik? _korisnik;

  AuthStatus get status => _status;

  String? get greska => _greska;

  Korisnik? get korisnik => _korisnik;

  bool get seUcitava =>
      _status == AuthStatus.ucitavanje;

  bool get jePrijavljen =>
      _status == AuthStatus.prijavljen;

  Future<void> provjeriPrijavu() async {
    final refresh =
        await _tokenSpremiste.dohvatiRefresh();

    if (refresh == null) {
      _status = AuthStatus.odjavljen;
      notifyListeners();
      return;
    }

    try {
      _korisnik =
          await _servis.dohvatiJa();

      if (_korisnik != null) {
        await spremiTrenutnogKorisnika(
          _korisnik!.id,
        );
      }

      _status = AuthStatus.prijavljen;
    } catch (_) {
      _status = AuthStatus.prijavljen;
    }

    notifyListeners();
  }

  Future<bool> prijava({
    required String identifikator,
    required String lozinka,
  }) async {
    _postaviUcitavanje();

    try {
      await _servis.prijavi(
        identifikator: identifikator,
        lozinka: lozinka,
      );

      try {
        _korisnik =
            await _servis.dohvatiJa();
      } catch (_) {}

      if (_korisnik != null) {
        await spremiTrenutnogKorisnika(
          _korisnik!.id,
        );
      }

      _status = AuthStatus.prijavljen;
      _greska = null;

      notifyListeners();

      return true;
    } on AuthGreska catch (e) {
      _postaviGresku(
        e.poruka,
      );

      return false;
    } catch (_) {
      _postaviGresku(
        'Ne mogu se povezati s poslužiteljem.',
      );

      return false;
    }
  }

  Future<bool> registracija({
    required String email,
    required String korisnickoIme,
    required String ime,
    required String prezime,
    required String lozinka,
  }) async {
    _postaviUcitavanje();

    try {
      _korisnik =
          await _servis.registriraj(
        email: email,
        korisnickoIme: korisnickoIme,
        ime: ime,
        prezime: prezime,
        lozinka: lozinka,
      );

      await _servis.prijavi(
        identifikator: email,
        lozinka: lozinka,
      );

      try {
        _korisnik =
            await _servis.dohvatiJa();
      } catch (_) {}

      _status = AuthStatus.prijavljen;
      _greska = null;

      if (_korisnik != null) {
        await spremiTrenutnogKorisnika(
          _korisnik!.id,
        );
      }

      notifyListeners();

      return true;
    } on AuthGreska catch (e) {
      _postaviGresku(
        e.poruka,
      );

      return false;
    } catch (_) {
      _postaviGresku(
        'Ne mogu se povezati s poslužiteljem.',
      );

      return false;
    }
  }

  Future<bool> azurirajProfil({
    required String ime,
    required String prezime,
    required String korisnickoIme,
    Uint8List? slikaBytes,
    String? nazivSlike,
  }) async {
    try {
      _korisnik =
          await _servis.azurirajProfil(
        ime: ime,
        prezime: prezime,
        korisnickoIme: korisnickoIme,
        slikaBytes: slikaBytes,
        nazivSlike: nazivSlike,
      );

      _greska = null;

      notifyListeners();

      return true;
    } on AuthGreska catch (e) {
      _greska = e.poruka;

      notifyListeners();

      return false;
    } catch (_) {
      _greska =
          'Ne mogu spremiti promjene.';

      notifyListeners();

      return false;
    }
  }

  Future<void> osvjeziKorisnika() async {
    try {
      _korisnik =
          await _servis.dohvatiJa();

      notifyListeners();
    } catch (_) {}
  }

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

  void _postaviGresku(
    String poruka,
  ) {
    _greska = poruka;
    _status = AuthStatus.odjavljen;

    notifyListeners();
  }
}
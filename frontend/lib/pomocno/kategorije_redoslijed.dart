import 'package:shared_preferences/shared_preferences.dart';

import '../modeli/kategorija.dart';

// Postavke kategorija (vidljivost + redoslijed) pamtimo lokalno, ali PO KORISNIKU
// da se ne miješaju ako se na istom uređaju prijavi netko drugi.
const _kljucKorisnik = 'trenutni_korisnik_id';

/// Zapamti tko je trenutno prijavljen. Poziva se pri prijavi/registraciji,
/// pa i nakon ponovnog pokretanja aplikacije ključ pokazuje na pravog korisnika.
Future<void> spremiTrenutnogKorisnika(int id) async {
  final p = await SharedPreferences.getInstance();
  await p.setInt(_kljucKorisnik, id);
}

Future<String> _kljucVidljivih() async {
  final p = await SharedPreferences.getInstance();
  final id = p.getInt(_kljucKorisnik);
  return 'vidljive_kategorije_trosak_${id ?? 'gost'}';
}

/// Spremljeni popis vidljivih ID-eva za trenutnog korisnika, ili null ako
/// još ništa nije mijenjao (tada su sve kategorije vidljive u zadanom redoslijedu).
Future<List<int>?> ucitajVidljive() async {
  final p = await SharedPreferences.getInstance();
  final lista = p.getStringList(await _kljucVidljivih());
  if (lista == null) return null;
  return lista.map(int.parse).toList();
}

Future<void> spremiVidljive(List<int> idjevi) async {
  final p = await SharedPreferences.getInstance();
  await p.setStringList(
      await _kljucVidljivih(), idjevi.map((e) => e.toString()).toList());
}

/// Podijeli kategorije na vidljive (u spremljenom redoslijedu) i skrivene.
/// Ako ništa nije spremljeno -> sve su vidljive u zadanom redoslijedu.
({List<Kategorija> vidljive, List<Kategorija> skrivene}) podijeli(
    List<Kategorija> sve, List<int>? vidljiviIdjevi) {
  if (vidljiviIdjevi == null) {
    return (vidljive: List.of(sve), skrivene: <Kategorija>[]);
  }
  final poId = {for (final k in sve) k.id: k};
  final vidljive = <Kategorija>[];
  for (final id in vidljiviIdjevi) {
    final k = poId.remove(id);
    if (k != null) vidljive.add(k);
  }
  final skrivene = poId.values.toList();
  return (vidljive: vidljive, skrivene: skrivene);
}
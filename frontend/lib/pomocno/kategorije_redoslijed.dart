import 'package:shared_preferences/shared_preferences.dart';
import '../modeli/kategorija.dart';

const _kljucKorisnik = 'trenutni_korisnik_id';

Future<void> spremiTrenutnogKorisnika(int id) async {
  final p = await SharedPreferences.getInstance();
  await p.setInt(_kljucKorisnik, id);
}

Future<String> _kljucVidljivih() async {
  final p = await SharedPreferences.getInstance();
  final id = p.getInt(_kljucKorisnik);
  return 'vidljive_kategorije_trosak_${id ?? 'gost'}';
}

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
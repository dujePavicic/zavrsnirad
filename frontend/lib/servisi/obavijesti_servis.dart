import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../modeli/garancija.dart';
import '../modeli/korisnik.dart';

class ObavijestiServis {
  ObavijestiServis._();

  static final ObavijestiServis _instanca = ObavijestiServis._();

  factory ObavijestiServis() => _instanca;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _inicijalizirano = false;

  static const _kanalId = 'garancije_istek';
  static const _kanalNaziv = 'Istjecanje garancija';
  static const _kanalOpis =
      'Podsjetnici prije isteka spremljenih garancija.';

  int _idZaGaranciju(int garancijaId) => 100000 + garancijaId;

  Future<void> inicijaliziraj() async {
    if (_inicijalizirano || kIsWeb) return;

    tzdata.initializeTimeZones();

    try {
      final zona = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zona.identifier));
    } catch (_) {
      // Ako dohvat zone ne uspije, timezone paket ostaje na zadanoj zoni.
    }

    const android = AndroidInitializationSettings('ic_notification');

    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const postavke = InitializationSettings(
      android: android,
      iOS: ios,
    );

    await _plugin.initialize(settings: postavke);

    _inicijalizirano = true;
  }

  Future<bool> zatraziDozvolu() async {
    if (kIsWeb) return false;

    await inicijaliziraj();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final androidRezultat =
        await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    final iosRezultat = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Na platformi na kojoj implementation ne postoji vraća null.
    if (androidRezultat != null) return androidRezultat;
    if (iosRezultat != null) return iosRezultat;

    return true;
  }

  

  Future<void> zakaziGaranciju(
    Garancija garancija,
    Korisnik korisnik,
  ) async {
    if (kIsWeb) return;

    await inicijaliziraj();
    await otkaziGaranciju(garancija.id);

    if (!korisnik.obavijestiGarancije ||
        !garancija.obavijesti ||
        garancija.dozivotna ||
        garancija.datumIsteka == null ||
        garancija.istekla) {
      return;
    }

    final istek = DateTime.tryParse(garancija.datumIsteka!);
    if (istek == null) return;

    final datumPodsjetnika = DateTime(
      istek.year,
      istek.month,
      istek.day,
      9,).subtract(Duration(days: korisnik.podsjetnikGarancijeDana),
    );

    final lokalniDatum = tz.TZDateTime(
      tz.local,
      datumPodsjetnika.year,
      datumPodsjetnika.month,
      datumPodsjetnika.day,
      datumPodsjetnika.hour,
    );

    if (!lokalniDatum.isAfter(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const detalji = NotificationDetails(
      android: AndroidNotificationDetails(
        _kanalId,
        _kanalNaziv,
        channelDescription: _kanalOpis,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification',
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id: _idZaGaranciju(garancija.id),
      title: 'Garancija uskoro istječe',
      body:
          'Garancija za ${garancija.nazivProizvoda} istječe za '
          '${korisnik.podsjetnikGarancijeDana} dana.',
      scheduledDate: lokalniDatum,
      notificationDetails: detalji,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'garancija:${garancija.id}',
    );
  }

  Future<void> otkaziGaranciju(int garancijaId) async {
    if (kIsWeb) return;

    await inicijaliziraj();
    await _plugin.cancel(id: _idZaGaranciju(garancijaId));
  }

  Future<void> sinkronizirajSve(
    List<Garancija> garancije,
    Korisnik korisnik,
  ) async {
    if (kIsWeb) return;

    await inicijaliziraj();

    for (final garancija in garancije) {
      await zakaziGaranciju(garancija, korisnik);
    }
  }

  Future<void> otkaziSveGarancije(
    List<Garancija> garancije,
  ) async {
    if (kIsWeb) return;

    await inicijaliziraj();

    for (final garancija in garancije) {
      await otkaziGaranciju(garancija.id);
    }
  }
}

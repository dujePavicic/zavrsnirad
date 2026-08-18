from datetime import date
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from .models import Kategorija, Racun, Transakcija

from django.core.files.uploadedfile import SimpleUploadedFile

from django.core.cache import cache

from .models import Budzet, Kategorija, Racun, Transakcija, Garancija

from datetime import timedelta

LOZINKA = "TajnaLozinka123"


def napravi_korisnika(email, korisnicko_ime):
    Korisnik = get_user_model()
    korisnik = Korisnik(
        email=email, korisnicko_ime=korisnicko_ime, ime="Test", prezime="Testić"
    )
    korisnik.set_password(LOZINKA)
    korisnik.save()
    return korisnik


class AuthTest(APITestCase):
    """Registracija i prijava."""

    def setUp(self):
        cache.clear()
        self.korisnik = napravi_korisnika("ana@example.com", "ana")

    def test_registracija_stvara_korisnika(self):
        odgovor = self.client.post(
            reverse("registracija"),
            {
                "email": "novi@example.com",
                "korisnicko_ime": "novi",
                "ime": "Novi",
                "prezime": "Korisnik",
                "lozinka": LOZINKA,
            },
        )
        self.assertEqual(odgovor.status_code, status.HTTP_201_CREATED)
        self.assertNotIn("lozinka", odgovor.data)

    def test_registracija_odbija_zauzet_email(self):
        odgovor = self.client.post(
            reverse("registracija"),
            {
                "email": "ana@example.com",
                "korisnicko_ime": "druga",
                "ime": "Ana",
                "prezime": "Anić",
                "lozinka": LOZINKA,
            },
        )
        self.assertEqual(odgovor.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("email", odgovor.data)

    def test_prijava_emailom_i_korisnickim_imenom(self):
        for identifikator in ("ana@example.com", "ana"):
            odgovor = self.client.post(
                reverse("prijava"), {"identifikator": identifikator, "lozinka": LOZINKA}
            )
            self.assertEqual(odgovor.status_code, status.HTTP_200_OK)
            self.assertIn("access", odgovor.data)
            self.assertIn("refresh", odgovor.data)

    def test_prijava_odbija_krivu_lozinku(self):
        odgovor = self.client.post(
            reverse("prijava"), {"identifikator": "ana", "lozinka": "krivo"}
        )
        self.assertEqual(odgovor.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_bez_tokena_nema_pristupa(self):
        odgovor = self.client.get(reverse("transakcija-list"))
        self.assertEqual(odgovor.status_code, status.HTTP_401_UNAUTHORIZED)


class PodaciTest(APITestCase):
    """Izolacija podataka i pravila nad kategorijama."""

    def setUp(self):
        self.ana = napravi_korisnika("ana@example.com", "ana")
        self.ivan = napravi_korisnika("ivan@example.com", "ivan")
        self.namirnice = Kategorija.objects.get(naziv="Namirnice", vlasnik__isnull=True)
        self.transakcija_ane = Transakcija.objects.create(
            korisnik=self.ana,
            tip=Transakcija.TipTransakcije.TROSAK,
            iznos=Decimal("20.00"),
            kategorija=self.namirnice,
            datum=date(2026, 8, 2),
            opis="Konzum",
        )
        self.client.force_authenticate(user=self.ivan)

    def test_ne_vidi_tude_transakcije(self):
        odgovor = self.client.get(reverse("transakcija-list"))
        self.assertEqual(odgovor.data["count"], 0)

    def test_ne_moze_dohvatiti_tudu_transakciju(self):
        putanja = reverse("transakcija-detail", args=[self.transakcija_ane.pk])
        self.assertEqual(self.client.get(putanja).status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(self.client.delete(putanja).status_code, status.HTTP_404_NOT_FOUND)

    def test_korisnik_se_ne_moze_podmetnuti(self):
        odgovor = self.client.post(
            reverse("transakcija-list"),
            {
                "tip": "TROSAK",
                "iznos": "10.00",
                "kategorija": self.namirnice.pk,
                "datum": "2026-08-02",
                "korisnik": self.ana.pk,
            },
        )
        self.assertEqual(odgovor.status_code, status.HTTP_201_CREATED)
        stvorena = Transakcija.objects.get(pk=odgovor.data["id"])
        self.assertEqual(stvorena.korisnik, self.ivan)

    def test_predefinirana_kategorija_se_ne_brise(self):
        putanja = reverse("kategorija-detail", args=[self.namirnice.pk])
        self.assertEqual(self.client.delete(putanja).status_code, status.HTTP_403_FORBIDDEN)

    def test_vlastita_kategorija_se_moze_dodati(self):
        odgovor = self.client.post(
            reverse("kategorija-list"), {"naziv": "Kućni ljubimci", "tip": "TROSAK"}
        )
        self.assertEqual(odgovor.status_code, status.HTTP_201_CREATED)
        self.assertFalse(odgovor.data["je_sustavska"])

    def test_kriva_kategorija_za_tip(self):
        placa = Kategorija.objects.get(naziv="Plaća", vlasnik__isnull=True)
        odgovor = self.client.post(
            reverse("transakcija-list"),
            {
                "tip": "TROSAK",
                "iznos": "10.00",
                "kategorija": placa.pk,
                "datum": "2026-08-02",
            },
        )
        self.assertEqual(odgovor.status_code, status.HTTP_400_BAD_REQUEST)


class RacunPregledTest(APITestCase):
    """Arhiva racuna i zbrojevi za dashboard."""

    def setUp(self):
        self.ana = napravi_korisnika("ana@example.com", "ana")
        self.namirnice = Kategorija.objects.get(naziv="Namirnice", vlasnik__isnull=True)
        self.client.force_authenticate(user=self.ana)

    def test_racun_stvara_transakciju(self):
        odgovor = self.client.post(
            reverse("racun-list"),
            {
                "trgovina": "Konzum",
                "iznos": "31.50",
                "kategorija": self.namirnice.pk,
                "datum": "2026-08-02",
            },
        )
        self.assertEqual(odgovor.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Transakcija.objects.filter(korisnik=self.ana).count(), 1)
        self.assertEqual(odgovor.data["transakcija"]["iznos"], "31.50")

    def test_brisanje_racuna_ostavlja_transakciju(self):
        odgovor = self.client.post(
            reverse("racun-list"),
            {"trgovina": "Plodine", "iznos": "12.30", "datum": "2026-08-02"},
        )
        self.client.delete(reverse("racun-detail", args=[odgovor.data["id"]]))
        self.assertEqual(Racun.objects.count(), 0)
        self.assertEqual(Transakcija.objects.count(), 1)

    def test_pretraga_po_trgovini(self):
        self.client.post(
            reverse("racun-list"),
            {"trgovina": "Konzum", "iznos": "31.50", "datum": "2026-08-02"},
        )
        odgovor = self.client.get(reverse("racun-list"), {"trgovina": "konz"})
        self.assertEqual(odgovor.data["count"], 1)

    def test_pregled_racuna_zbrojeve(self):
        Transakcija.objects.create(
            korisnik=self.ana,
            tip=Transakcija.TipTransakcije.PRIHOD,
            iznos=Decimal("1000.00"),
            datum=date(2026, 8, 10),
        )
        Transakcija.objects.create(
            korisnik=self.ana,
            tip=Transakcija.TipTransakcije.TROSAK,
            iznos=Decimal("250.00"),
            kategorija=self.namirnice,
            datum=date(2026, 8, 11),
        )
        odgovor = self.client.get(reverse("pregled"), {"godina": 2026, "mjesec": 8})
        self.assertEqual(odgovor.data["ukupno_prihodi"], "1000.00")
        self.assertEqual(odgovor.data["ukupno_troskovi"], "250.00")
        self.assertEqual(odgovor.data["saldo"], "750.00")
        self.assertEqual(odgovor.data["po_kategorijama"][0]["postotak"], 100.0)

    def test_odbija_datoteku_koja_nije_slika(self):
        lazna = SimpleUploadedFile("racun.jpg", b"ovo nije slika", content_type="image/jpeg")
        odgovor = self.client.post(
            reverse("racun-list"),
            {"trgovina": "Konzum", "iznos": "10.00", "datum": "2026-08-02", "slika": lazna},
            format="multipart",
        )
        self.assertEqual(odgovor.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("slika", odgovor.data)

class OgranicenjeTest(APITestCase):
    """Zastita od grubog pogadjanja lozinke."""

    def setUp(self):
        cache.clear()
        napravi_korisnika("ana@example.com", "ana")

    def tearDown(self):
        cache.clear()

    def test_previse_pokusaja_prijave_vraca_429(self):
        podaci = {"identifikator": "ana", "lozinka": "krivo"}
        for _ in range(10):
            self.client.post(reverse("prijava"), podaci)
        odgovor = self.client.post(reverse("prijava"), podaci)
        self.assertEqual(odgovor.status_code, status.HTTP_429_TOO_MANY_REQUESTS)

    def test_ispravna_prijava_prolazi_unutar_ogranicenja(self):
        odgovor = self.client.post(
            reverse("prijava"), {"identifikator": "ana", "lozinka": LOZINKA}
        )
        self.assertEqual(odgovor.status_code, status.HTTP_200_OK)

class BudzetKategorijeTest(APITestCase):
    """Budzet po kategoriji i njegov prikaz u pregledu."""

    def setUp(self):
        self.ana = napravi_korisnika("ana@example.com", "ana")
        self.namirnice = Kategorija.objects.get(naziv="Namirnice", vlasnik__isnull=True)
        for mjesec in (8, 9):
            Budzet.objects.create(
                korisnik=self.ana, godina=2026, mjesec=mjesec, iznos=Decimal("2000.00")
            )
        self.client.force_authenticate(user=self.ana)

    def postavi(self, kategorija, iznos, mjesec=8):
        return self.client.post(
            reverse("budzet-kategorije-list"),
            {"kategorija": kategorija.pk, "godina": 2026, "mjesec": mjesec, "iznos": iznos},
        )

    def test_duplikat_za_isti_mjesec_vraca_400(self):
        self.assertEqual(self.postavi(self.namirnice, "300.00").status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.postavi(self.namirnice, "400.00").status_code, status.HTTP_400_BAD_REQUEST)

    def test_ne_moze_na_kategoriju_prihoda(self):
        placa = Kategorija.objects.get(naziv="Plaća", vlasnik__isnull=True)
        self.assertEqual(self.postavi(placa, "1000.00").status_code, status.HTTP_400_BAD_REQUEST)

    def test_pregled_prikazuje_budzet_i_preostalo(self):
        self.postavi(self.namirnice, "300.00")
        Transakcija.objects.create(
            korisnik=self.ana,
            tip=Transakcija.TipTransakcije.TROSAK,
            iznos=Decimal("37.99"),
            kategorija=self.namirnice,
            datum=date(2026, 8, 5),
        )
        odgovor = self.client.get(reverse("pregled"), {"godina": 2026, "mjesec": 8})
        stavka = odgovor.data["po_kategorijama"][0]
        self.assertEqual(stavka["budzet"], "300.00")
        self.assertEqual(stavka["preostalo_budzeta"], "262.01")

    def test_kategorija_s_budzetom_bez_troska_je_u_pregledu(self):
        self.postavi(self.namirnice, "300.00", mjesec=9)
        odgovor = self.client.get(reverse("pregled"), {"godina": 2026, "mjesec": 9})
        stavka = odgovor.data["po_kategorijama"][0]
        self.assertEqual(stavka["naziv"], "Namirnice")
        self.assertEqual(stavka["iznos"], "0.00")
        self.assertEqual(stavka["budzet"], "300.00")


class ProfilTest(APITestCase):
    """Uredjivanje vlastitog profila."""

    def setUp(self):
        self.ana = napravi_korisnika("ana@example.com", "ana")
        self.client.force_authenticate(user=self.ana)

    def test_moze_promijeniti_ime(self):
        odgovor = self.client.patch(reverse("ja"), {"ime": "Anamarija"})
        self.assertEqual(odgovor.status_code, status.HTTP_200_OK)
        self.ana.refresh_from_db()
        self.assertEqual(self.ana.ime, "Anamarija")

    def test_email_se_ne_moze_promijeniti(self):
        self.client.patch(reverse("ja"), {"email": "drugi@example.com"})
        self.ana.refresh_from_db()
        self.assertEqual(self.ana.email, "ana@example.com")

    def test_zauzeto_korisnicko_ime_vraca_400(self):
        napravi_korisnika("ivan@example.com", "ivan")
        odgovor = self.client.patch(reverse("ja"), {"korisnicko_ime": "ivan"})
        self.assertEqual(odgovor.status_code, status.HTTP_400_BAD_REQUEST)

class RaspolozivBudzetTest(APITestCase):
    """Prihodi povecavaju raspolozivo, a raspodjela ga ne smije prijeci."""

    def setUp(self):
        self.ana = napravi_korisnika("ana@example.com", "ana")
        self.namirnice = Kategorija.objects.get(naziv="Namirnice", vlasnik__isnull=True)
        self.prijevoz = Kategorija.objects.get(naziv="Prijevoz", vlasnik__isnull=True)
        self.client.force_authenticate(user=self.ana)

    def postavi_budzet(self, iznos):
        return self.client.post(
            reverse("budzet-list"), {"godina": 2026, "mjesec": 8, "iznos": iznos}
        )

    def postavi_kategoriju(self, kategorija, iznos):
        return self.client.post(
            reverse("budzet-kategorije-list"),
            {"kategorija": kategorija.pk, "godina": 2026, "mjesec": 8, "iznos": iznos},
        )

    def dodaj_prihod(self, iznos):
        Transakcija.objects.create(
            korisnik=self.ana,
            tip=Transakcija.TipTransakcije.PRIHOD,
            iznos=Decimal(iznos),
            datum=date(2026, 8, 3),
        )

    def test_bez_mjesecnog_budzeta_nema_kategorijskog(self):
        odgovor = self.postavi_kategoriju(self.namirnice, "100.00")
        self.assertEqual(odgovor.status_code, status.HTTP_400_BAD_REQUEST)

    def test_zbroj_ne_smije_prijeci_raspolozivo(self):
        self.postavi_budzet("1700.00")
        self.assertEqual(self.postavi_kategoriju(self.namirnice, "500.00").status_code, 201)
        odgovor = self.postavi_kategoriju(self.prijevoz, "1300.00")
        self.assertEqual(odgovor.status_code, status.HTTP_400_BAD_REQUEST)

    def test_prihod_povecava_prostor_za_raspodjelu(self):
        self.postavi_budzet("1700.00")
        self.postavi_kategoriju(self.namirnice, "1700.00")
        self.assertEqual(self.postavi_kategoriju(self.prijevoz, "200.00").status_code, 400)
        self.dodaj_prihod("300.00")
        self.assertEqual(self.postavi_kategoriju(self.prijevoz, "200.00").status_code, 201)

    def test_uredjivanje_izuzima_vlastiti_iznos(self):
        self.postavi_budzet("1700.00")
        odgovor = self.postavi_kategoriju(self.namirnice, "1700.00")
        putanja = reverse("budzet-kategorije-detail", args=[odgovor.data["id"]])
        self.assertEqual(self.client.patch(putanja, {"iznos": "1600.00"}).status_code, 200)

    def test_ne_moze_smanjiti_budzet_ispod_rasporedenog(self):
        odgovor = self.postavi_budzet("1700.00")
        self.postavi_kategoriju(self.namirnice, "1300.00")
        putanja = reverse("budzet-detail", args=[odgovor.data["id"]])
        self.assertEqual(self.client.patch(putanja, {"iznos": "1000.00"}).status_code, 400)

    def test_pregled_racuna_prihode_u_raspolozivom(self):
        self.postavi_budzet("1700.00")
        self.dodaj_prihod("300.00")
        Transakcija.objects.create(
            korisnik=self.ana,
            tip=Transakcija.TipTransakcije.TROSAK,
            iznos=Decimal("600.00"),
            kategorija=self.namirnice,
            datum=date(2026, 8, 5),
        )
        odgovor = self.client.get(reverse("pregled"), {"godina": 2026, "mjesec": 8})
        self.assertEqual(odgovor.data["budzet"], "1700.00")
        self.assertEqual(odgovor.data["raspolozivi_budzet"], "2000.00")
        self.assertEqual(odgovor.data["preostalo_budzeta"], "1400.00")


class NaknadniRacunTest(APITestCase):
    """Dodavanje racuna postojecoj transakciji i filtriranje po racunu."""

    def setUp(self):
        self.ana = napravi_korisnika("ana@example.com", "ana")
        self.namirnice = Kategorija.objects.get(naziv="Namirnice", vlasnik__isnull=True)
        self.rucna = Transakcija.objects.create(
            korisnik=self.ana,
            tip=Transakcija.TipTransakcije.TROSAK,
            iznos=Decimal("48.32"),
            kategorija=self.namirnice,
            datum=date(2026, 8, 12),
        )
        self.client.force_authenticate(user=self.ana)

    def test_dodavanje_racuna_ne_duplicira_transakciju(self):
        odgovor = self.client.post(
            reverse("racun-list"),
            {"transakcija_id": self.rucna.pk, "trgovina": "Konzum"},
        )
        self.assertEqual(odgovor.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Transakcija.objects.count(), 1)
        self.assertEqual(odgovor.data["transakcija"]["iznos"], "48.32")

    def test_transakcija_ne_moze_dobiti_dva_racuna(self):
        self.client.post(reverse("racun-list"), {"transakcija_id": self.rucna.pk})
        odgovor = self.client.post(reverse("racun-list"), {"transakcija_id": self.rucna.pk})
        self.assertEqual(odgovor.status_code, status.HTTP_400_BAD_REQUEST)

    def test_tuda_transakcija_se_ne_moze_povezati(self):
        ivan = napravi_korisnika("ivan@example.com", "ivan")
        tuda = Transakcija.objects.create(
            korisnik=ivan,
            tip=Transakcija.TipTransakcije.TROSAK,
            iznos=Decimal("10.00"),
            datum=date(2026, 8, 12),
        )
        odgovor = self.client.post(reverse("racun-list"), {"transakcija_id": tuda.pk})
        self.assertEqual(odgovor.status_code, status.HTTP_400_BAD_REQUEST)

    def test_filter_ima_racun(self):
        self.client.post(
            reverse("racun-list"),
            {"trgovina": "Plodine", "iznos": "12.30", "datum": "2026-08-12"},
        )
        bez = self.client.get(reverse("transakcija-list"), {"ima_racun": "false"})
        self.assertEqual(bez.data["count"], 1)
        self.assertIsNone(bez.data["results"][0]["racun_id"])

        sa = self.client.get(reverse("transakcija-list"), {"ima_racun": "true"})
        self.assertEqual(sa.data["count"], 1)
        self.assertIsNotNone(sa.data["results"][0]["racun_id"])

from core.uzorci import POLJA, ucitaj_uzorke

RACUN_PRELOMLJEN = """PLODINE d.d.
Racun br. 445/1/1
15.07.2026.
SVEUKUPNO
1.245,60
Kartica"""

# Iznosi koji su na tim racunima zamka - ne smiju zavrsiti kao ukupan iznos
KRIVI_IZNOSI = {
    "plodine": "85.33",
    "ina": "27.90",
    "lidl": "48.10",
    "konzum": "10.73",
    "tokic": "120.51",
}

# Endpoint vraca kategoriju pod drugim kljucem nego sama funkcija parsera
KLJUC_U_ODGOVORU = {"predlozena_kategorija": "kategorija_naziv"}

class OcrTest(APITestCase):
    """Izvlacenje podataka iz OCR teksta, na uzorcima stvarnih racuna."""

    def setUp(self):
        self.ana = napravi_korisnika("ana@example.com", "ana")
        self.client.force_authenticate(user=self.ana)

    def analiziraj(self, tekst):
        return self.client.post(
            reverse("racun-analiziraj"), {"prepoznati_tekst": tekst}, format="json"
        )

    def test_svi_uzorci_daju_ocekivane_vrijednosti(self):
        uzorci = ucitaj_uzorke()
        self.assertTrue(uzorci, "Nema uzoraka u mapi ocr_uzorci.")

        for uzorak in uzorci:
            odgovor = self.analiziraj(uzorak["tekst"])
            self.assertEqual(odgovor.status_code, status.HTTP_200_OK)
            for polje, kljuc_rezultata in POLJA.items():
                ocekivana = uzorak["ocekivano"].get(polje)
                if ocekivana is None:
                    continue
                kljuc = KLJUC_U_ODGOVORU.get(kljuc_rezultata, kljuc_rezultata)
                with self.subTest(uzorak=uzorak["naziv"], polje=polje):
                    self.assertEqual(odgovor.data[kljuc], ocekivana)

    def test_ne_uzima_zamke_umjesto_ukupnog_iznosa(self):
        for uzorak in ucitaj_uzorke():
            krivi = KRIVI_IZNOSI.get(uzorak["naziv"])
            if krivi is None:
                continue
            with self.subTest(uzorak=uzorak["naziv"]):
                odgovor = self.analiziraj(uzorak["tekst"])
                self.assertNotEqual(odgovor.data["iznos"], krivi)

    def test_kolicina_ne_znaci_ina(self):
        odgovor = self.analiziraj("Mali Ducan\n01.08.2026.\nkolicina 2\nUKUPNO 12,00")
        self.assertEqual(odgovor.data["iznos"], "12.00")
        self.assertIsNone(odgovor.data["kategorija"])

    def test_iznos_u_sljedecem_retku_i_tisucice(self):
        odgovor = self.analiziraj(RACUN_PRELOMLJEN)
        self.assertEqual(odgovor.data["iznos"], "1245.60")
        self.assertEqual(odgovor.data["trgovina"], "Plodine")

    def test_prazan_tekst_vraca_400(self):
        odgovor = self.analiziraj("   ")
        self.assertEqual(odgovor.status_code, status.HTTP_400_BAD_REQUEST)

class GarancijaTest(APITestCase):
    """Garancije, filtri i prikaz u pregledu."""

    def setUp(self):
        self.ana = napravi_korisnika("ana@example.com", "ana")
        self.danas = date.today()
        self.client.force_authenticate(user=self.ana)

    def stvori(self, naziv, dana_do_isteka, **dodatno):
        podaci = {
            "naziv_proizvoda": naziv,
            "datum_kupnje": (self.danas - timedelta(days=1)).isoformat(),
            "datum_isteka": (self.danas + timedelta(days=dana_do_isteka)).isoformat(),
        }
        podaci.update(dodatno)
        return self.client.post(reverse("garancija-list"), podaci)

    def test_stvaranje_bez_racuna(self):
        odgovor = self.stvori("Bosch usisavač", 730, serijski_broj="BOSCH123")
        self.assertEqual(odgovor.status_code, status.HTTP_201_CREATED)
        self.assertIsNone(odgovor.data["racun"])
        self.assertIsNone(odgovor.data["racun_trgovina"])
        self.assertFalse(odgovor.data["istekla"])

    def test_istek_prije_kupnje_vraca_400(self):
        odgovor = self.client.post(
            reverse("garancija-list"),
            {
                "naziv_proizvoda": "Test",
                "datum_kupnje": "2026-08-14",
                "datum_isteka": "2026-01-01",
            },
        )
        self.assertEqual(odgovor.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("datum_isteka", odgovor.data)

    def test_dozivotna_garancija_bez_datuma_isteka(self):
        odgovor = self.client.post(
            reverse("garancija-list"),
            {
                "naziv_proizvoda": "Victorinox nožić",
                "datum_kupnje": self.danas.isoformat(),
            },
        )
        self.assertEqual(odgovor.status_code, status.HTTP_201_CREATED)
        self.assertTrue(odgovor.data["dozivotna"])
        self.assertFalse(odgovor.data["istekla"])
        self.assertIsNone(odgovor.data["dana_do_isteka"])
        self.assertIsNone(odgovor.data["datum_isteka"])

    def test_dozivotna_je_aktivna_ali_ne_istjece(self):
        self.client.post(
            reverse("garancija-list"),
            {"naziv_proizvoda": "Doživotna", "datum_kupnje": self.danas.isoformat()},
        )
        self.stvori("Uskoro", 10)
        putanja = reverse("garancija-list")
        self.assertEqual(self.client.get(putanja, {"aktivne": "true"}).data["count"], 2)
        self.assertEqual(self.client.get(putanja, {"istekle": "true"}).data["count"], 0)
        self.assertEqual(
            self.client.get(putanja, {"istjece_za_dana": "365"}).data["count"], 1
        )

    def test_pregled_broji_dozivotnu_kao_aktivnu(self):
        self.client.post(
            reverse("garancija-list"),
            {"naziv_proizvoda": "Doživotna", "datum_kupnje": self.danas.isoformat()},
        )
        odgovor = self.client.get(reverse("pregled"))
        self.assertEqual(odgovor.data["garancije"]["aktivne"], 1)
        self.assertEqual(odgovor.data["garancije"]["istjece_uskoro"], 0)
        self.assertIsNone(odgovor.data["garancije"]["najblizi_istek"])

    def test_filtri_aktivne_istekle_i_skori_istek(self):
        self.stvori("Aktivna", 365)
        self.stvori("Uskoro", 10)
        Garancija.objects.create(
            korisnik=self.ana,
            naziv_proizvoda="Istekla",
            datum_kupnje=self.danas - timedelta(days=800),
            datum_isteka=self.danas - timedelta(days=1),
        )
        putanja = reverse("garancija-list")
        self.assertEqual(self.client.get(putanja, {"aktivne": "true"}).data["count"], 2)
        self.assertEqual(self.client.get(putanja, {"istekle": "true"}).data["count"], 1)
        self.assertEqual(
            self.client.get(putanja, {"istjece_za_dana": "30"}).data["count"], 1
        )

    def test_ne_vidi_tude_garancije(self):
        ivan = napravi_korisnika("ivan@example.com", "ivan")
        Garancija.objects.create(
            korisnik=ivan,
            naziv_proizvoda="Ivanova",
            datum_kupnje=self.danas,
            datum_isteka=self.danas + timedelta(days=10),
        )
        self.assertEqual(self.client.get(reverse("garancija-list")).data["count"], 0)

    def test_pregled_sadrzi_sazetak_garancija(self):
        self.stvori("Aktivna", 365)
        self.stvori("Uskoro", 10)
        odgovor = self.client.get(reverse("pregled"))
        sazetak = odgovor.data["garancije"]
        self.assertEqual(sazetak["aktivne"], 2)
        self.assertEqual(sazetak["istjece_uskoro"], 1)
        self.assertEqual(
            sazetak["najblizi_istek"], (self.danas + timedelta(days=10)).isoformat()
        )

    def test_pregled_bez_garancija(self):
        odgovor = self.client.get(reverse("pregled"))
        self.assertEqual(odgovor.data["garancije"]["aktivne"], 0)
        self.assertIsNone(odgovor.data["garancije"]["najblizi_istek"])


class TjedanIFilteriTest(APITestCase):
    """Tjedna potrosnja i filtriranje transakcija po mjesecu."""

    def setUp(self):
        self.ana = napravi_korisnika("ana@example.com", "ana")
        self.namirnice = Kategorija.objects.get(naziv="Namirnice", vlasnik__isnull=True)
        self.danas = date.today()
        self.client.force_authenticate(user=self.ana)

    def trosak(self, iznos, datum):
        return Transakcija.objects.create(
            korisnik=self.ana,
            tip=Transakcija.TipTransakcije.TROSAK,
            iznos=Decimal(iznos),
            kategorija=self.namirnice,
            datum=datum,
        )

    def test_tjedan_potroseno_racuna_od_ponedjeljka(self):
        pocetak = self.danas - timedelta(days=self.danas.weekday())
        self.trosak("20.00", pocetak)
        self.trosak("15.00", self.danas)
        self.trosak("99.00", pocetak - timedelta(days=1))
        odgovor = self.client.get(reverse("pregled"))
        self.assertEqual(odgovor.data["tjedan_potroseno"], "35.00")
        self.assertEqual(odgovor.data["tjedan_od"], pocetak.isoformat())

    def test_filtar_po_godini_i_mjesecu(self):
        self.trosak("10.00", date(2026, 8, 5))
        self.trosak("20.00", date(2026, 7, 5))
        odgovor = self.client.get(
            reverse("transakcija-list"), {"godina": 2026, "mjesec": 8}
        )
        self.assertEqual(odgovor.data["count"], 1)
        self.assertFalse(odgovor.data["results"][0]["ima_racun"])
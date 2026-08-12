from datetime import date
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from .models import Kategorija, Racun, Transakcija

from django.core.files.uploadedfile import SimpleUploadedFile

from django.core.cache import cache

from .models import Budzet, Kategorija, Racun, Transakcija



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


RACUN_PLODINE = """PLODINE
PLODINE d.d. Rijeka
Radnička 30, 51000 Rijeka
OIB: 92510681007
SUPERMARKET LOVRAN
Šetalište Maršala Tita 2A
51415 Lovran
Broj 75093-088-4
Blagajna 4
09.08.2026 09:01:22
Artikal Kol Cijena Iznos €
S.HOT DOG SA SIROM 155 g
3,000 x 1,49 4,47
KRUH PLANINSKI KUK.500 g
2,000 x 1,35 2,70
LEZ.KARLA 163x61x3cm TR 1 x 27,55 27,55
ZA PLATITI €
88,97
Porez Osnovica PDV Ukupno
5,0 % 2,90 0,14 3,04
25,0 % 68,26 17,07 85,33
Uključena povratna naknada na ambalažu
6.000 x 0.10 0.60
PLAĆENO KARTICA 88,97"""

RACUN_INA = """INA
INA - INDUSTRIJA NAFTE, d.d.
Zagreb, Av. V. Holjevca 10
PDVbr: HR27759560625
OIB: 27759560625
MPM Cernik
datum računa 04.08.2026. u 16:00:07
br naziv robe/usluge
kolicina cijena iznos TG
01 HELL CLASSIC 0,5L
2,00 kom 2,89 5,78 D1
Loyalty popust -1,40
02 DUHAN OLD HOLB.ORIG.
2,00 kom 9,00 18,00 D1
UKUPNO 27,90 €
Popust -1,40 €
ZA PLATITI 26,50 €
kartica-VISA 26,50 €
Povratna naknada 0,20 €
TG stopa osnovica iznos poreza
D1 25,00 % 21,04 € 5,26 €
UKUPNO POREZ 5,26 €"""

RACUN_PRELOMLJEN = """PLODINE d.d.
Racun br. 445/1/1
15.07.2026.
SVEUKUPNO
1.245,60
Kartica"""

RACUN_LIDL = """Lidl Hrvatska d.o.o. k.d.
Velika Gorica, PDVBr:HR66089976432
Ulica kneza Ljudevita Posavskog 53
OIB: 66089976432, PJ: 0223
Petra Jurčića 2A, Rijeka
Espresso Macchia 1,09x 2 2,18 C
Lidl Plus popust -1,00
Djevi. masl. ulj 6,39x 3 19,17 A
Kuhana šunka 2,39x 2 4,78 C
Stari Lisac 1,59x 9 14,31 C
za platiti 49,20
Kartica 49,20
POPUST 1,50
PDV% Osnovica PDV Ukupno
A 5,0 % 19,87 0,99 20,86
Ukupno 41,66 6,42 48,10
Pov. naknada 11 x 0,10 1,10
Datum: 10.07.2026 20:44:56"""

RACUN_KONZUM = """KONZUM
KONZUM plus d.o.o.
Zagreb, Ulica Marijana Čavića 1A
OIB 62226620908
Prod.br.1527, Tel. 0800 400 000
Rijeka, Riva 16
Naziv artikla Kol Cijena Iznos P
VRH KIS 200G DUK 1 1,39 1,39 A
LISTOVI CLARUM 500g 2 1,95 3,90 A
Ukupno EUR 10,88
P PDV Osnovica Iznos Ukupno
A 25% 8,62 2,16 10,73
UKLJUČ.POV.NAKNADA 1 0,10 0,10
PLAĆENO: Kartica 10,88
Račun broj 25324/1527/64
Datum 16.06.2026 15:14:14"""

RACUN_TISAK = """TISAK plus d.o.o.
www.tisak.hr
SLAVONSKA AV.11a,ZAGREB, OIB:32497003047
PM: 906730, RI-LUTKARSKO KAZALIŠTE
BLAGAJNA: 1 SPR: 4880
RN: 44320/906730/1 13.07.2026 10:07:57
ARTIKL PDV IZNOS
5,000 * 2,80
AUTOB. KARTA ZONA 1 25% 14,00
U K U P N O EUR 14,00
Stopa Osnovica Porez
25,00% 11,20 2,80
VISA 14,00"""

RACUN_TOKIC = """Tokić d.d.
Ulica 144. brigade Hrvatske vojske 1a
HR - 10360 Sesvete
Tel. 01 3033 999 ', Fax. 01 3033 932
OIB: 74867487620
web adresa: www.tokic.hr
Račun - otpremnica
3000/P033/2
26-003000/P033/2
Broj transakcije: 23267
Viškovo, 18.04.26 ; Str.: 1
Valuta plaćanja: 18.04.26
Datum izdavanja: 18.04.26
Vrijeme izdavanja: 11:31:19
OIB kupca: 86670913708
Rb. Br. artikla Kat. broj Opis JMJ Količina Cijena Iznos bez popusta Popust retka % Iznos
1. 253627 47961 MANŽETA ZGLOBA SET 1,00 19,20 19,20 32 13,05
2. 354213 616 050 002 VILICA KOM 1,00 85,28 85,28 36,998 53,73
Ukupno retci: 189,76 69,24 120,51
Ukupno EUR (bez PDV-a) 120,51
PDV 25 %: 30,13
Ukupno EUR s PDV-om: 150,64
Način plaćanja
Gotovina 150,64
Ukupna uplata: 150,64"""

class OcrTest(APITestCase):
    """Izvlacenje podataka iz OCR teksta, na primjerima stvarnih racuna."""

    def setUp(self):
        self.ana = napravi_korisnika("ana@example.com", "ana")
        self.client.force_authenticate(user=self.ana)

    def analiziraj(self, tekst):
        return self.client.post(
            reverse("racun-analiziraj"), {"prepoznati_tekst": tekst}, format="json"
        )

    def test_plodine_uzima_iznos_iz_sljedeceg_retka(self):
        odgovor = self.analiziraj(RACUN_PLODINE)
        self.assertEqual(odgovor.status_code, status.HTTP_200_OK)
        self.assertEqual(odgovor.data["iznos"], "88.97")
        self.assertEqual(odgovor.data["trgovina"], "Plodine")
        self.assertEqual(odgovor.data["datum"], "2026-08-09")
        self.assertEqual(odgovor.data["oib"], "92510681007")
        self.assertEqual(odgovor.data["kategorija_naziv"], "Namirnice")

    def test_plodine_ne_uzima_iznos_iz_porezne_tablice(self):
        odgovor = self.analiziraj(RACUN_PLODINE)
        self.assertNotEqual(odgovor.data["iznos"], "85.33")

    def test_ina_uzima_za_platiti_a_ne_ukupno(self):
        odgovor = self.analiziraj(RACUN_INA)
        self.assertEqual(odgovor.data["iznos"], "26.50")
        self.assertEqual(odgovor.data["trgovina"], "INA")
        self.assertEqual(odgovor.data["datum"], "2026-08-04")
        self.assertEqual(odgovor.data["oib"], "27759560625")
        self.assertEqual(odgovor.data["kategorija_naziv"], "Prijevoz")

    def test_kolicina_ne_znaci_ina(self):
        tekst = "Mali Ducan\n01.08.2026.\nkolicina 2\nUKUPNO 12,00"
        odgovor = self.analiziraj(tekst)
        self.assertEqual(odgovor.data["iznos"], "12.00")
        self.assertIsNone(odgovor.data["kategorija"])

    def test_iznos_u_sljedecem_retku_i_tisucice(self):
        odgovor = self.analiziraj(RACUN_PRELOMLJEN)
        self.assertEqual(odgovor.data["iznos"], "1245.60")
        self.assertEqual(odgovor.data["trgovina"], "Plodine")

    def test_prazan_tekst_vraca_400(self):
        odgovor = self.analiziraj("   ")
        self.assertEqual(odgovor.status_code, status.HTTP_400_BAD_REQUEST)

    def test_lidl_ne_uzima_iznos_iz_porezne_tablice(self):
        odgovor = self.analiziraj(RACUN_LIDL)
        self.assertEqual(odgovor.data["iznos"], "49.20")
        self.assertNotEqual(odgovor.data["iznos"], "48.10")
        self.assertEqual(odgovor.data["trgovina"], "Lidl")
        self.assertEqual(odgovor.data["datum"], "2026-07-10")
        self.assertEqual(odgovor.data["oib"], "66089976432")

    def test_konzum_ukupno_eur_u_istom_retku(self):
        odgovor = self.analiziraj(RACUN_KONZUM)
        self.assertEqual(odgovor.data["iznos"], "10.88")
        self.assertEqual(odgovor.data["trgovina"], "Konzum")
        self.assertEqual(odgovor.data["datum"], "2026-06-16")
        self.assertEqual(odgovor.data["kategorija_naziv"], "Namirnice")

    def test_tisak_razmaknuto_ukupno(self):
        odgovor = self.analiziraj(RACUN_TISAK)
        self.assertEqual(odgovor.data["iznos"], "14.00")
        self.assertEqual(odgovor.data["trgovina"], "Tisak")
        self.assertEqual(odgovor.data["datum"], "2026-07-13")
        self.assertEqual(odgovor.data["oib"], "32497003047")

    def test_tokic_uzima_iznos_s_pdv_om(self):
        odgovor = self.analiziraj(RACUN_TOKIC)
        self.assertEqual(odgovor.data["iznos"], "150.64")
        self.assertNotEqual(odgovor.data["iznos"], "120.51")
        self.assertEqual(odgovor.data["trgovina"], "Tokić")
        self.assertEqual(odgovor.data["datum"], "2026-04-18")
        self.assertEqual(odgovor.data["oib"], "74867487620")
        self.assertEqual(odgovor.data["kategorija_naziv"], "Prijevoz")
from datetime import date
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from .models import Kategorija, Racun, Transakcija

from django.core.files.uploadedfile import SimpleUploadedFile

from django.core.cache import cache



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

    def test_brisanje_racuna_brise_transakciju(self):
        odgovor = self.client.post(
            reverse("racun-list"),
            {"trgovina": "Plodine", "iznos": "12.30", "datum": "2026-08-02"},
        )
        self.client.delete(reverse("racun-detail", args=[odgovor.data["id"]]))
        self.assertEqual(Racun.objects.count(), 0)
        self.assertEqual(Transakcija.objects.count(), 0)

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
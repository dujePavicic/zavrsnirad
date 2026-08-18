from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoGreskaValidacije
from rest_framework import serializers
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.tokens import RefreshToken

from .models import Korisnik

from django.db.models import Q
from .models import Kategorija, Transakcija, Budzet

from decimal import Decimal

from django.db import transaction as db_transakcija
from django.utils import timezone

from .models import Budzet, Kategorija, Racun, Transakcija

from PIL import Image

from .models import BudzetKategorije

from .izracuni import prihodi_mjeseca, raspolozivi_budzet, rasporedeno_po_kategorijama

from .models import Garancija

NAJVECA_SLIKA = 5 * 1024 * 1024
DOPUSTENI_FORMATI_SLIKE = {"JPEG", "PNG", "WEBP"}


def provjeri_sliku(slika):
    """Provjerava velicinu i stvarni sadrzaj datoteke, ne samo nastavak imena."""
    if slika is None:
        return slika
    if slika.size > NAJVECA_SLIKA:
        raise serializers.ValidationError("Slika ne smije biti veća od 5 MB.")
    try:
        provjera = Image.open(slika)
        provjera.verify()
    except Exception:
        raise serializers.ValidationError("Datoteka nije valjana slika.")
    finally:
        slika.seek(0)
    if provjera.format not in DOPUSTENI_FORMATI_SLIKE:
        raise serializers.ValidationError("Dopušteni formati su JPEG, PNG i WEBP.")
    return slika



class KorisnikSerializer(serializers.ModelSerializer):
    """Prikaz korisnika prema van — nikad ne sadrzi lozinku."""

    class Meta:
        model = Korisnik
        fields = ["id", "email", "korisnicko_ime", "ime", "prezime", "datum_registracije", "profilna_slika"]
        read_only_fields = fields


class RegistracijaSerializer(serializers.ModelSerializer):
    lozinka = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = Korisnik
        fields = ["id", "email", "korisnicko_ime", "ime", "prezime", "lozinka", "datum_registracije"]
        read_only_fields = ["id", "datum_registracije"]

    def validate_email(self, vrijednost):
        vrijednost = vrijednost.strip().lower()
        if Korisnik.objects.filter(email__iexact=vrijednost).exists():
            raise serializers.ValidationError("Korisnik s ovim emailom već postoji.")
        return vrijednost

    def validate_korisnicko_ime(self, vrijednost):
        if not vrijednost:
            return vrijednost
        vrijednost = vrijednost.strip()
        if Korisnik.objects.filter(korisnicko_ime__iexact=vrijednost).exists():
            raise serializers.ValidationError("Korisničko ime je već zauzeto.")
        return vrijednost

    def validate_lozinka(self, vrijednost):
        try:
            validate_password(vrijednost)
        except DjangoGreskaValidacije as greska:
            raise serializers.ValidationError(list(greska.messages))
        return vrijednost

    def create(self, provjereni_podaci):
        lozinka = provjereni_podaci.pop("lozinka")
        korisnik = Korisnik(**provjereni_podaci)
        korisnik.set_password(lozinka)
        korisnik.save()
        return korisnik


class PrijavaSerializer(serializers.Serializer):
    identifikator = serializers.CharField()
    lozinka = serializers.CharField(write_only=True)

    def validate(self, podaci):
        korisnik = authenticate(
            request=self.context.get("request"),
            username=podaci["identifikator"],
            password=podaci["lozinka"],
        )
        if korisnik is None:
            raise AuthenticationFailed("Neispravno korisničko ime/email ili lozinka.")
        if not korisnik.is_active:
            raise AuthenticationFailed("Korisnički račun nije aktivan.")

        token_osvjezavanja = RefreshToken.for_user(korisnik)
        return {
            "access": str(token_osvjezavanja.access_token),
            "refresh": str(token_osvjezavanja),
        }

class KategorijaSerializer(serializers.ModelSerializer):
    je_sustavska = serializers.SerializerMethodField()

    class Meta:
        model = Kategorija
        fields = ["id", "naziv", "tip", "boja", "ikona", "je_sustavska"]
        read_only_fields = ["id"]

    def get_je_sustavska(self, kategorija):
        return kategorija.vlasnik_id is None

    def validate_naziv(self, vrijednost):
        vrijednost = vrijednost.strip()
        korisnik = self.context["request"].user
        postojece = Kategorija.objects.filter(naziv__iexact=vrijednost).filter(
            Q(vlasnik__isnull=True) | Q(vlasnik=korisnik)
        )
        if self.instance is not None:
            postojece = postojece.exclude(pk=self.instance.pk)
        if postojece.exists():
            raise serializers.ValidationError("Kategorija s ovim nazivom već postoji.")
        return vrijednost


class TransakcijaSerializer(serializers.ModelSerializer):
    kategorija_naziv = serializers.CharField(source="kategorija.naziv", read_only=True)
    kategorija_boja = serializers.CharField(source="kategorija.boja", read_only=True)
    kategorija_ikona = serializers.CharField(source="kategorija.ikona", read_only=True)

    class Meta:
        model = Transakcija
        fields = [
            "id",
            "tip",
            "iznos",
            "kategorija",
            "kategorija_naziv",
            "kategorija_boja",
            "kategorija_ikona",
            "datum",
            "opis",
            "datum_unosa",
            "racun_id",
            "ima_racun",
        ]
        read_only_fields = ["id", "datum_unosa"]

    racun_id = serializers.SerializerMethodField()
    ima_racun = serializers.SerializerMethodField()

    def get_ima_racun(self, transakcija):
        return getattr(transakcija, "racun", None) is not None

    def get_racun_id(self, transakcija):
        racun = getattr(transakcija, "racun", None)
        return racun.id if racun else None
    
    def validate_kategorija(self, kategorija):
        if kategorija is None:
            return kategorija
        korisnik = self.context["request"].user
        if kategorija.vlasnik_id not in (None, korisnik.id):
            raise serializers.ValidationError("Kategorija ne postoji.")
        return kategorija

    def validate(self, podaci):
        tip = podaci.get("tip", getattr(self.instance, "tip", None))
        kategorija = podaci.get("kategorija", getattr(self.instance, "kategorija", None))
        if kategorija is not None and tip is not None and kategorija.tip != tip:
            raise serializers.ValidationError(
                {"kategorija": "Kategorija ne odgovara tipu transakcije."}
            )
        return podaci


class BudzetSerializer(serializers.ModelSerializer):
    class Meta:
        model = Budzet
        fields = ["id", "godina", "mjesec", "iznos"]
        read_only_fields = ["id"]

    def validate_mjesec(self, vrijednost):
        if not 1 <= vrijednost <= 12:
            raise serializers.ValidationError("Mjesec mora biti između 1 i 12.")
        return vrijednost

    def validate(self, podaci):
        korisnik = self.context["request"].user
        godina = podaci.get("godina", getattr(self.instance, "godina", None))
        mjesec = podaci.get("mjesec", getattr(self.instance, "mjesec", None))
        postojeci = Budzet.objects.filter(korisnik=korisnik, godina=godina, mjesec=mjesec)
        if self.instance is not None:
            postojeci = postojeci.exclude(pk=self.instance.pk)
        if postojeci.exists():
            raise serializers.ValidationError(
                {"mjesec": "Budžet za taj mjesec već postoji."}
            )
        iznos = podaci.get("iznos", getattr(self.instance, "iznos", None))
        rasporedeno = rasporedeno_po_kategorijama(korisnik, godina, mjesec)
        if rasporedeno and iznos is not None:
            prihodi = prihodi_mjeseca(korisnik, godina, mjesec)
            if iznos + prihodi < rasporedeno:
                najmanje = rasporedeno - prihodi
                raise serializers.ValidationError(
                    {
                        "iznos": (
                            f"Po kategorijama je već raspoređeno {rasporedeno} €. "
                            f"Budžet ne može biti manji od {najmanje} €."
                        )
                    }
                )
        return podaci


class RacunSerializer(serializers.ModelSerializer):
    """Skenirani racun. Pri stvaranju ujedno radi i pripadnu transakciju."""

    transakcija = TransakcijaSerializer(read_only=True)
    iznos = serializers.DecimalField(
        max_digits=10, decimal_places=2, min_value=Decimal("0.01"),
        write_only=True, required=False,
    )
    transakcija_id = serializers.PrimaryKeyRelatedField(
        source="transakcija",
        queryset=Transakcija.objects.all(),
        write_only=True,
        required=False,
        help_text="Postojeća transakcija kojoj se naknadno dodaje račun.",
    )
    kategorija = serializers.PrimaryKeyRelatedField(
        queryset=Kategorija.objects.all(), write_only=True, required=False, allow_null=True
    )
    datum = serializers.DateField(write_only=True, required=False)
    opis = serializers.CharField(
        max_length=200, write_only=True, required=False, allow_blank=True
    )

    class Meta:
        model = Racun
        fields = [
            "id",
            "trgovina",
            "datum_izdavanja",
            "slika",
            "prepoznati_tekst",
            "datum_spremanja",
            "transakcija",
            "iznos",
            "transakcija_id",
            "kategorija",
            "datum",
            "opis",
        ]
        read_only_fields = ["id", "datum_spremanja", "transakcija"]

    NAJVECA_VELICINA = 5 * 1024 * 1024
    DOPUSTENI_FORMATI = {"JPEG", "PNG", "WEBP"}

    def validate_slika(self, slika):
        if slika is None:
            return slika
        if slika.size > self.NAJVECA_VELICINA:
            raise serializers.ValidationError("Slika ne smije biti veća od 5 MB.")
        try:
            provjera = Image.open(slika)
            provjera.verify()
        except Exception:
            raise serializers.ValidationError("Datoteka nije valjana slika.")
        finally:
            slika.seek(0)
        if provjera.format not in self.DOPUSTENI_FORMATI:
            raise serializers.ValidationError("Dopušteni formati su JPEG, PNG i WEBP.")
        return slika

    def validate_kategorija(self, kategorija):
        if kategorija is None:
            return kategorija
        korisnik = self.context["request"].user
        if kategorija.vlasnik_id not in (None, korisnik.id):
            raise serializers.ValidationError("Kategorija ne postoji.")
        if kategorija.tip != Kategorija.TipKategorije.TROSAK:
            raise serializers.ValidationError("Račun se može vezati samo uz kategoriju troška.")
        return kategorija

    def validate_transakcija_id(self, transakcija):
        korisnik = self.context["request"].user
        if transakcija.korisnik_id != korisnik.id:
            raise serializers.ValidationError("Transakcija ne postoji.")
        if getattr(transakcija, "racun", None) is not None:
            raise serializers.ValidationError("Transakcija već ima povezan račun.")
        return transakcija

    def validate(self, podaci):
        postojeca = podaci.get("transakcija") or getattr(self.instance, "transakcija", None)
        if postojeca is None and not podaci.get("iznos"):
            raise serializers.ValidationError({"iznos": "Iznos je obavezan."})
        if podaci.get("transakcija") and podaci.get("iznos"):
            raise serializers.ValidationError(
                {"iznos": "Kod postojeće transakcije iznos se ne šalje."}
            )
        return podaci

    def izdvoji_podatke_transakcije(self, provjereni_podaci):
        return {
            "iznos": provjereni_podaci.pop("iznos", None),
            "kategorija": provjereni_podaci.pop("kategorija", None),
            "datum": provjereni_podaci.pop("datum", None),
            "opis": provjereni_podaci.pop("opis", None),
        }

    @db_transakcija.atomic
    def create(self, provjereni_podaci):
        podaci = self.izdvoji_podatke_transakcije(provjereni_podaci)
        transakcija = provjereni_podaci.pop("transakcija", None)
        if transakcija is None:
            datum = (
                podaci["datum"]
                or provjereni_podaci.get("datum_izdavanja")
                or timezone.localdate()
            )
            transakcija = Transakcija.objects.create(
                korisnik=self.context["request"].user,
                tip=Transakcija.TipTransakcije.TROSAK,
                iznos=podaci["iznos"],
                kategorija=podaci["kategorija"],
                datum=datum,
                opis=podaci["opis"] or provjereni_podaci.get("trgovina", ""),
            )
        return Racun.objects.create(transakcija=transakcija, **provjereni_podaci)

    @db_transakcija.atomic
    def update(self, racun, provjereni_podaci):
        podaci = self.izdvoji_podatke_transakcije(provjereni_podaci)
        transakcija = racun.transakcija
        for polje, vrijednost in podaci.items():
            if vrijednost is not None:
                setattr(transakcija, polje, vrijednost)
        transakcija.save()
        return super().update(racun, provjereni_podaci)

class ProfilSerializer(serializers.ModelSerializer):
    """Uredjivanje vlastitog profila. Email i lozinka se ovdje ne mijenjaju."""

    class Meta:
        model = Korisnik
        fields = [
            "id",
            "email",
            "korisnicko_ime",
            "ime",
            "prezime",
            "datum_registracije",
            "profilna_slika",
            "obavijesti_garancije",
            "podsjetnik_garancije_dana",
        ]
        read_only_fields = ["id", "email", "datum_registracije"]

    def validate_korisnicko_ime(self, vrijednost):
        if not vrijednost:
            return vrijednost
        vrijednost = vrijednost.strip()
        zauzeto = Korisnik.objects.filter(korisnicko_ime__iexact=vrijednost).exclude(
            pk=self.instance.pk
        )
        if zauzeto.exists():
            raise serializers.ValidationError("Korisničko ime je već zauzeto.")
        return vrijednost

    def validate_profilna_slika(self, slika):
        return provjeri_sliku(slika)

    def update(self, korisnik, provjereni_podaci):
        stara = korisnik.profilna_slika
        nova = provjereni_podaci.get("profilna_slika", stara)
        if stara and nova != stara:
            stara.delete(save=False)
        return super().update(korisnik, provjereni_podaci)
    
    def validate_podsjetnik_garancije_dana(self, vrijednost):
        if not 1 <= vrijednost <= 365:
            raise serializers.ValidationError("Podsjetnik mora biti između 1 i 365 dana.")
        return vrijednost

class BudzetKategorijeSerializer(serializers.ModelSerializer):
    kategorija_naziv = serializers.CharField(source="kategorija.naziv", read_only=True)
    kategorija_boja = serializers.CharField(source="kategorija.boja", read_only=True)
    kategorija_ikona = serializers.CharField(source="kategorija.ikona", read_only=True)

    class Meta:
        model = BudzetKategorije
        fields = [
            "id", "kategorija", "kategorija_naziv", "kategorija_boja",
            "kategorija_ikona", "godina", "mjesec", "iznos",
        ]
        read_only_fields = ["id"]

    def validate_mjesec(self, vrijednost):
        if not 1 <= vrijednost <= 12:
            raise serializers.ValidationError("Mjesec mora biti između 1 i 12.")
        return vrijednost

    def validate_kategorija(self, kategorija):
        korisnik = self.context["request"].user
        if kategorija.vlasnik_id not in (None, korisnik.id):
            raise serializers.ValidationError("Kategorija ne postoji.")
        if kategorija.tip != Kategorija.TipKategorije.TROSAK:
            raise serializers.ValidationError("Budžet se postavlja samo za kategoriju troška.")
        return kategorija

    def validate(self, podaci):
        korisnik = self.context["request"].user
        kategorija = podaci.get("kategorija", getattr(self.instance, "kategorija", None))
        godina = podaci.get("godina", getattr(self.instance, "godina", None))
        mjesec = podaci.get("mjesec", getattr(self.instance, "mjesec", None))
        postojeci = BudzetKategorije.objects.filter(
            korisnik=korisnik, kategorija=kategorija, godina=godina, mjesec=mjesec
        )
        if self.instance is not None:
            postojeci = postojeci.exclude(pk=self.instance.pk)
        if postojeci.exists():
            raise serializers.ValidationError(
                {"kategorija": "Budžet za tu kategoriju u tom mjesecu već postoji."}
            )
        raspolozivo = raspolozivi_budzet(korisnik, godina, mjesec)
        if raspolozivo is None:
            raise serializers.ValidationError(
                {"iznos": "Za taj mjesec prvo treba postaviti ukupni mjesečni budžet."}
            )

        iznos = podaci.get("iznos", getattr(self.instance, "iznos", None))
        zauzeto = rasporedeno_po_kategorijama(
            korisnik, godina, mjesec, osim=self.instance.pk if self.instance else None
        )
        slobodno = raspolozivo - zauzeto
        if iznos is not None and iznos > slobodno:
            raise serializers.ValidationError(
                {"iznos": f"Za raspodjelu je preostalo {slobodno} € od {raspolozivo} €."}
            )
        return podaci

class GarancijaSerializer(serializers.ModelSerializer):
    racun_trgovina = serializers.CharField(source="racun.trgovina", read_only=True, default=None)
    racun_slika = serializers.SerializerMethodField()
    dana_do_isteka = serializers.IntegerField(read_only=True)
    istekla = serializers.BooleanField(read_only=True)
    dozivotna = serializers.BooleanField(read_only=True)

    class Meta:
        model = Garancija
        fields = [
            "id",
            "naziv_proizvoda",
            "datum_kupnje",
            "datum_isteka",
            "serijski_broj",
            "napomena",
            "obavijesti",
            "racun",
            "racun_trgovina",
            "racun_slika",
            "dana_do_isteka",
            "istekla",
            "dozivotna",
            "datum_unosa",
        ]
        read_only_fields = ["id", "datum_unosa"]

    def get_racun_slika(self, garancija):
        if not garancija.racun or not garancija.racun.slika:
            return None
        zahtjev = self.context.get("request")
        url = garancija.racun.slika.url
        return zahtjev.build_absolute_uri(url) if zahtjev else url

    def validate_racun(self, racun):
        if racun is None:
            return racun
        if racun.transakcija.korisnik_id != self.context["request"].user.id:
            raise serializers.ValidationError("Račun ne postoji.")
        return racun

    def validate(self, podaci):
        kupnja = podaci.get("datum_kupnje", getattr(self.instance, "datum_kupnje", None))
        istek = podaci.get("datum_isteka", getattr(self.instance, "datum_isteka", None))
        if kupnja and istek and istek < kupnja:
            raise serializers.ValidationError(
                {"datum_isteka": "Datum isteka ne može biti prije datuma kupnje."}
            )
        return podaci
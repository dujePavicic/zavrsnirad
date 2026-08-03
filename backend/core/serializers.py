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



class KorisnikSerializer(serializers.ModelSerializer):
    """Prikaz korisnika prema van — nikad ne sadrzi lozinku."""

    class Meta:
        model = Korisnik
        fields = ["id", "email", "korisnicko_ime", "ime", "prezime", "datum_registracije"]
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
        ]
        read_only_fields = ["id", "datum_unosa"]

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
        return podaci


class RacunSerializer(serializers.ModelSerializer):
    """Skenirani racun. Pri stvaranju ujedno radi i pripadnu transakciju."""

    transakcija = TransakcijaSerializer(read_only=True)
    iznos = serializers.DecimalField(
        max_digits=10, decimal_places=2, min_value=Decimal("0.01"), write_only=True
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
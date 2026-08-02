from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoGreskaValidacije
from rest_framework import serializers
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.tokens import RefreshToken

from .models import Korisnik


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
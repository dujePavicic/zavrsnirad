from django.contrib.auth.models import (
    AbstractBaseUser,
    BaseUserManager,
    PermissionsMixin,
)
from django.core.exceptions import ValidationError
from django.db import models
from django.utils import timezone


def provjeri_korisnicko_ime(vrijednost):
    if "@" in vrijednost:
        raise ValidationError("Korisničko ime ne smije sadržavati znak @.")


class KorisnikManager(BaseUserManager):
    use_in_migrations = True

    def _stvori_korisnika(self, email, lozinka, **dodatna_polja):
        if not email:
            raise ValueError("Email adresa je obavezna.")
        korisnik = self.model(email=self.normalize_email(email), **dodatna_polja)
        korisnik.set_password(lozinka)
        korisnik.save(using=self._db)
        return korisnik

    def create_user(self, email, password=None, **dodatna_polja):
        dodatna_polja.setdefault("is_staff", False)
        dodatna_polja.setdefault("is_superuser", False)
        return self._stvori_korisnika(email, password, **dodatna_polja)

    def create_superuser(self, email, password=None, **dodatna_polja):
        dodatna_polja.setdefault("is_staff", True)
        dodatna_polja.setdefault("is_superuser", True)
        if not dodatna_polja.get("is_staff") or not dodatna_polja.get("is_superuser"):
            raise ValueError("Superkorisnik mora imati is_staff i is_superuser.")
        return self._stvori_korisnika(email, password, **dodatna_polja)


class Korisnik(AbstractBaseUser, PermissionsMixin):
    email = models.EmailField("email adresa", unique=True)
    korisnicko_ime = models.CharField(
        "korisničko ime",
        max_length=150,
        unique=True,
        null=True,
        blank=True,
        validators=[provjeri_korisnicko_ime],
    )
    ime = models.CharField("ime", max_length=100, blank=True)
    prezime = models.CharField("prezime", max_length=100, blank=True)
    datum_registracije = models.DateTimeField("datum registracije", default=timezone.now)

    is_active = models.BooleanField("aktivan", default=True)
    is_staff = models.BooleanField("član osoblja", default=False)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []

    objects = KorisnikManager()

    class Meta:
        verbose_name = "korisnik"
        verbose_name_plural = "korisnici"

    def save(self, *args, **kwargs):
        if not self.korisnicko_ime:
            self.korisnicko_ime = None
        super().save(*args, **kwargs)

    def __str__(self):
        return self.email
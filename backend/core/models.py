from django.contrib.auth.models import (
    AbstractBaseUser,
    BaseUserManager,
    PermissionsMixin,
)
from django.core.exceptions import ValidationError
from django.db import models
from django.utils import timezone
from django.conf import settings
from django.core.validators import MinValueValidator

from decimal import Decimal

from django.db.models.signals import post_delete
from django.dispatch import receiver



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

    profilna_slika = models.ImageField(
        "profilna slika", upload_to="profili/", null=True, blank=True
    )
    obavijesti_garancije = models.BooleanField("obavijesti o garancijama", default=True)
    podsjetnik_garancije_dana = models.PositiveIntegerField(
        "podsjetnik (dana prije isteka)", default=30
    )
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

class Kategorija(models.Model):
    """Kategorija troska ili prihoda.

    Ako je vlasnik prazan, kategorija je sustavska i vide je svi korisnici.
    Ako je popunjen, kategorija pripada samo tom korisniku.
    """

    class TipKategorije(models.TextChoices):
        TROSAK = "TROSAK", "Trošak"
        PRIHOD = "PRIHOD", "Prihod"

    naziv = models.CharField("naziv", max_length=100)
    tip = models.CharField(
        "tip", max_length=10, choices=TipKategorije.choices, default=TipKategorije.TROSAK
    )
    boja = models.CharField("boja", max_length=7, default="#0F6E56")
    ikona = models.CharField("ikona", max_length=50, blank=True)
    vlasnik = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="vlasnik",
        on_delete=models.CASCADE,
        related_name="kategorije",
        null=True,
        blank=True,
        help_text="Prazno znaci sustavska kategorija dostupna svima.",
    )

    class Meta:
        verbose_name = "kategorija"
        verbose_name_plural = "kategorije"
        ordering = ["naziv"]
        constraints = [
            models.UniqueConstraint(
                fields=["naziv"],
                condition=models.Q(vlasnik__isnull=True),
                name="jedinstvena_sustavska_kategorija",
            ),
            models.UniqueConstraint(
                fields=["vlasnik", "naziv"],
                condition=models.Q(vlasnik__isnull=False),
                name="jedinstvena_korisnicka_kategorija",
            ),
        ]

    def __str__(self):
        return self.naziv

    @property
    def je_sustavska(self):
        return self.vlasnik_id is None


class Transakcija(models.Model):
    """Jedan prihod ili trosak korisnika."""

    class TipTransakcije(models.TextChoices):
        TROSAK = "TROSAK", "Trošak"
        PRIHOD = "PRIHOD", "Prihod"

    korisnik = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="korisnik",
        on_delete=models.CASCADE,
        related_name="transakcije",
    )
    tip = models.CharField(
        "tip", max_length=10, choices=TipTransakcije.choices, default=TipTransakcije.TROSAK
    )
    iznos = models.DecimalField(
        "iznos", max_digits=10, decimal_places=2, validators=[MinValueValidator(Decimal("0.01"))]
    )
    kategorija = models.ForeignKey(
        Kategorija,
        verbose_name="kategorija",
        on_delete=models.SET_NULL,
        related_name="transakcije",
        null=True,
        blank=True,
    )
    datum = models.DateField("datum")
    opis = models.CharField("opis", max_length=200, blank=True)
    datum_unosa = models.DateTimeField("datum unosa", auto_now_add=True)

    class Meta:
        verbose_name = "transakcija"
        verbose_name_plural = "transakcije"
        ordering = ["-datum", "-datum_unosa"]
        indexes = [models.Index(fields=["korisnik", "-datum"])]

    def __str__(self):
        return f"{self.get_tip_display()} {self.iznos} € ({self.datum})"


class Racun(models.Model):
    """Skenirani racun iz digitalne arhive, uvijek vezan uz transakciju."""

    transakcija = models.OneToOneField(
        Transakcija,
        verbose_name="transakcija",
        on_delete=models.CASCADE,
        related_name="racun",
    )
    trgovina = models.CharField("trgovina", max_length=150, blank=True)
    datum_izdavanja = models.DateField("datum izdavanja", null=True, blank=True)
    slika = models.ImageField("slika", upload_to="racuni/%Y/%m/", null=True, blank=True)
    prepoznati_tekst = models.TextField("prepoznati tekst", blank=True)
    datum_spremanja = models.DateTimeField("datum spremanja", auto_now_add=True)

    class Meta:
        verbose_name = "račun"
        verbose_name_plural = "računi"
        ordering = ["-datum_spremanja"]

    def __str__(self):
        return self.trgovina or f"Račun #{self.pk}"


class Budzet(models.Model):
    """Mjesecni budzet korisnika."""

    korisnik = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="korisnik",
        on_delete=models.CASCADE,
        related_name="budzeti",
    )
    godina = models.PositiveSmallIntegerField("godina")
    mjesec = models.PositiveSmallIntegerField("mjesec")
    iznos = models.DecimalField(
        "iznos", max_digits=10, decimal_places=2, validators=[MinValueValidator(Decimal("0.01"))]
    )

    class Meta:
        verbose_name = "budžet"
        verbose_name_plural = "budžeti"
        ordering = ["-godina", "-mjesec"]
        constraints = [
            models.UniqueConstraint(
                fields=["korisnik", "godina", "mjesec"], name="jedan_budzet_po_mjesecu"
            )
        ]

    def __str__(self): 
        return f"{self.mjesec}/{self.godina}: {self.iznos} €"

class BudzetKategorije(models.Model):
    """Mjesecni budzet za pojedinu kategoriju troska."""

    korisnik = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="korisnik",
        on_delete=models.CASCADE,
        related_name="budzeti_kategorija",
    )
    kategorija = models.ForeignKey(
        Kategorija,
        verbose_name="kategorija",
        on_delete=models.CASCADE,
        related_name="budzeti",
    )
    godina = models.PositiveSmallIntegerField("godina")
    mjesec = models.PositiveSmallIntegerField("mjesec")
    iznos = models.DecimalField(
        "iznos", max_digits=10, decimal_places=2, validators=[MinValueValidator(Decimal("0.01"))]
    )

    class Meta:
        verbose_name = "budžet kategorije"
        verbose_name_plural = "budžeti kategorija"
        ordering = ["-godina", "-mjesec", "kategorija__naziv"]
        constraints = [
            models.UniqueConstraint(
                fields=["korisnik", "kategorija", "godina", "mjesec"],
                name="jedan_budzet_po_kategoriji_i_mjesecu",
            )
        ]

    def __str__(self):
        return f"{self.kategorija}: {self.iznos} € ({self.mjesec}/{self.godina})"

@receiver(post_delete, sender=Racun)
def obrisi_datoteku_racuna(sender, instance, **kwargs):
    """Brise sliku s diska kad se racun obrise."""
    if instance.slika:
        instance.slika.delete(save=False)


@receiver(post_delete, sender=Korisnik)
def obrisi_profilnu_sliku(sender, instance, **kwargs):
    """Brise profilnu sliku s diska kad se korisnik obrise."""
    if instance.profilna_slika:
        instance.profilna_slika.delete(save=False)

class Garancija(models.Model):
    """Garancija za kupljeni proizvod. Moze, ali ne mora biti vezana uz racun."""

    korisnik = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="korisnik",
        on_delete=models.CASCADE,
        related_name="garancije",
    )
    racun = models.ForeignKey(
        Racun,
        verbose_name="račun",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="garancije",
        help_text="Neobavezno — garancija moze postojati i bez skeniranog racuna.",
    )
    naziv_proizvoda = models.CharField("naziv proizvoda", max_length=255)
    datum_kupnje = models.DateField("datum kupnje")
    datum_isteka = models.DateField(
        "datum isteka",
        null=True,
        blank=True,
        help_text="Prazno znaci dozivotna garancija.",
    )
    serijski_broj = models.CharField("serijski broj", max_length=255, blank=True, default="")
    napomena = models.TextField("napomena", blank=True, default="")
    obavijesti = models.BooleanField("obavijesti", default=True)
    datum_unosa = models.DateTimeField("datum unosa", auto_now_add=True)
    datum_izmjene = models.DateTimeField("datum izmjene", auto_now=True)

    class Meta:
        verbose_name = "garancija"
        verbose_name_plural = "garancije"
        ordering = ["datum_isteka"]
        indexes = [models.Index(fields=["korisnik", "datum_isteka"])]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(datum_isteka__isnull=True)
                | models.Q(datum_isteka__gte=models.F("datum_kupnje")),
                name="istek_nakon_kupnje",
            )
        ]

    def __str__(self):
        return f"{self.naziv_proizvoda} (do {self.datum_isteka})"

    @property
    def dozivotna(self):
        return self.datum_isteka is None

    @property
    def dana_do_isteka(self):
        if self.datum_isteka is None:
            return None
        return (self.datum_isteka - timezone.localdate()).days

    @property
    def istekla(self):
        if self.datum_isteka is None:
            return False
        return self.datum_isteka < timezone.localdate()
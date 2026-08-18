from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.contrib.auth.forms import UserChangeForm, UserCreationForm

from .models import Korisnik, Budzet, Kategorija, Racun, Transakcija

from .models import Garancija

class KorisnikCreationForm(UserCreationForm):
    class Meta:
        model = Korisnik
        fields = ("email", "korisnicko_ime")


class KorisnikChangeForm(UserChangeForm):
    class Meta:
        model = Korisnik
        fields = (
            "email",
            "korisnicko_ime",
            "ime",
            "prezime",
            "is_active",
            "is_staff",
            "is_superuser",
            "groups",
            "user_permissions",
        )


@admin.register(Korisnik)
class KorisnikAdmin(UserAdmin):
    add_form = KorisnikCreationForm
    form = KorisnikChangeForm
    model = Korisnik
    ordering = ("email",)
    list_display = ("email", "korisnicko_ime", "is_staff", "is_active")
    search_fields = ("email", "korisnicko_ime")
    readonly_fields = ("last_login", "datum_registracije")
    fieldsets = (
        (None, {"fields": ("email", "korisnicko_ime", "password")}),
        ("Osobni podaci", {"fields": ("ime", "prezime")}),
        ("Dozvole", {"fields": ("is_active", "is_staff", "is_superuser",
                                "groups", "user_permissions")}),
        ("Datumi", {"fields": ("last_login", "datum_registracije")}),
    )
    add_fieldsets = (
        (None, {
            "classes": ("wide",),
            "fields": ("email", "korisnicko_ime", "password1", "password2"),
        }),
    )


@admin.register(Kategorija)
class KategorijaAdmin(admin.ModelAdmin):
    list_display = ("naziv", "tip", "vlasnik", "boja")
    list_filter = ("tip",)
    search_fields = ("naziv",)


@admin.register(Transakcija)
class TransakcijaAdmin(admin.ModelAdmin):
    list_display = ("datum", "tip", "iznos", "kategorija", "korisnik", "opis")
    list_filter = ("tip", "kategorija", "datum")
    search_fields = ("opis",)
    date_hierarchy = "datum"


@admin.register(Racun)
class RacunAdmin(admin.ModelAdmin):
    list_display = ("trgovina", "datum_izdavanja", "transakcija", "datum_spremanja")
    search_fields = ("trgovina", "prepoznati_tekst")


@admin.register(Budzet)
class BudzetAdmin(admin.ModelAdmin):
    list_display = ("korisnik", "godina", "mjesec", "iznos")
    list_filter = ("godina", "mjesec")

@admin.register(Garancija)
class GarancijaAdmin(admin.ModelAdmin):
    list_display = ("naziv_proizvoda", "datum_kupnje", "datum_isteka", "korisnik")
    list_filter = ("datum_isteka",)
    search_fields = ("naziv_proizvoda", "serijski_broj")
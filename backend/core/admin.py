from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.contrib.auth.forms import UserChangeForm, UserCreationForm

from .models import Korisnik


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
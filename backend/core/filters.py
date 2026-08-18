import django_filters

from .models import Transakcija

from .models import Racun

from datetime import timedelta

from django.utils import timezone

from .models import Garancija

from django.db import models

class TransakcijaFilter(django_filters.FilterSet):
    """Filtriranje transakcija po rasponu datuma, tipu i kategoriji."""

    datum_od = django_filters.DateFilter(field_name="datum", lookup_expr="gte")
    datum_do = django_filters.DateFilter(field_name="datum", lookup_expr="lte")
    ima_racun = django_filters.BooleanFilter(method="filtriraj_po_racunu")
    godina = django_filters.NumberFilter(field_name="datum", lookup_expr="year")
    mjesec = django_filters.NumberFilter(field_name="datum", lookup_expr="month")

    def filtriraj_po_racunu(self, upit, naziv, vrijednost):
        return upit.filter(racun__isnull=not vrijednost)
    
    class Meta:
        model = Transakcija
        fields = ["tip", "kategorija", "datum_od", "datum_do", "ima_racun", "godina", "mjesec"]

class RacunFilter(django_filters.FilterSet):
    """Pretraga arhive po trgovini, rasponu datuma i kategoriji."""

    trgovina = django_filters.CharFilter(lookup_expr="icontains")
    kategorija = django_filters.NumberFilter(field_name="transakcija__kategorija")
    datum_od = django_filters.DateFilter(field_name="transakcija__datum", lookup_expr="gte")
    datum_do = django_filters.DateFilter(field_name="transakcija__datum", lookup_expr="lte")

    class Meta:
        model = Racun
        fields = ["trgovina", "kategorija", "datum_od", "datum_do"]

class GarancijaFilter(django_filters.FilterSet):
    """Filtriranje garancija po statusu i skorom isteku."""

    aktivne = django_filters.BooleanFilter(method="filtriraj_aktivne")
    istekle = django_filters.BooleanFilter(method="filtriraj_istekle")
    istjece_za_dana = django_filters.NumberFilter(method="filtriraj_istjece_za_dana")

    class Meta:
        model = Garancija
        fields = ["racun", "obavijesti", "aktivne", "istekle", "istjece_za_dana"]

    def filtriraj_aktivne(self, upit, naziv, vrijednost):
        danas = timezone.localdate()
        if vrijednost:
            # Dozivotne su uvijek aktivne
            return upit.filter(
                models.Q(datum_isteka__isnull=True) | models.Q(datum_isteka__gte=danas)
            )
        return upit.filter(datum_isteka__lt=danas)

    def filtriraj_istekle(self, upit, naziv, vrijednost):
        danas = timezone.localdate()
        if vrijednost:
            return upit.filter(datum_isteka__lt=danas)
        return upit.filter(
            models.Q(datum_isteka__isnull=True) | models.Q(datum_isteka__gte=danas)
        )

    def filtriraj_istjece_za_dana(self, upit, naziv, vrijednost):
        # Dozivotne se namjerno preskacu - nemaju istek na koji bi se podsjecalo
        danas = timezone.localdate()
        granica = danas + timedelta(days=int(vrijednost))
        return upit.filter(datum_isteka__gte=danas, datum_isteka__lte=granica)
import django_filters

from .models import Transakcija

from .models import Racun



class TransakcijaFilter(django_filters.FilterSet):
    """Filtriranje transakcija po rasponu datuma, tipu i kategoriji."""

    datum_od = django_filters.DateFilter(field_name="datum", lookup_expr="gte")
    datum_do = django_filters.DateFilter(field_name="datum", lookup_expr="lte")

    ima_racun = django_filters.BooleanFilter(method="filtriraj_po_racunu")

    def filtriraj_po_racunu(self, upit, naziv, vrijednost):
        return upit.filter(racun__isnull=not vrijednost)
    
    class Meta:
        model = Transakcija
        fields = ["tip", "kategorija", "datum_od", "datum_do", "ima_racun"]

class RacunFilter(django_filters.FilterSet):
    """Pretraga arhive po trgovini, rasponu datuma i kategoriji."""

    trgovina = django_filters.CharFilter(lookup_expr="icontains")
    kategorija = django_filters.NumberFilter(field_name="transakcija__kategorija")
    datum_od = django_filters.DateFilter(field_name="transakcija__datum", lookup_expr="gte")
    datum_do = django_filters.DateFilter(field_name="transakcija__datum", lookup_expr="lte")

    class Meta:
        model = Racun
        fields = ["trgovina", "kategorija", "datum_od", "datum_do"]
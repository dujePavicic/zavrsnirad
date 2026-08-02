import django_filters

from .models import Transakcija


class TransakcijaFilter(django_filters.FilterSet):
    """Filtriranje transakcija po rasponu datuma, tipu i kategoriji."""

    datum_od = django_filters.DateFilter(field_name="datum", lookup_expr="gte")
    datum_do = django_filters.DateFilter(field_name="datum", lookup_expr="lte")

    class Meta:
        model = Transakcija
        fields = ["tip", "kategorija", "datum_od", "datum_do"]
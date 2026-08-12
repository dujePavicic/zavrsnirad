"""Izracuni vezani uz budzet. Na jednom mjestu da se pravilo ne racuna dvaput."""

from decimal import Decimal

from django.db.models import Sum

from .models import Budzet, BudzetKategorije, Transakcija


def zbroj(upit):
    return upit.aggregate(ukupno=Sum("iznos"))["ukupno"] or Decimal("0")


def prihodi_mjeseca(korisnik, godina, mjesec):
    return zbroj(
        Transakcija.objects.filter(
            korisnik=korisnik,
            tip=Transakcija.TipTransakcije.PRIHOD,
            datum__year=godina,
            datum__month=mjesec,
        )
    )


def raspolozivi_budzet(korisnik, godina, mjesec):
    """Postavljeni mjesecni budzet + prihodi tog mjeseca.

    Vraca None ako mjesecni budzet uopce nije postavljen.
    """
    budzet = Budzet.objects.filter(
        korisnik=korisnik, godina=godina, mjesec=mjesec
    ).first()
    if budzet is None:
        return None
    return budzet.iznos + prihodi_mjeseca(korisnik, godina, mjesec)


def rasporedeno_po_kategorijama(korisnik, godina, mjesec, osim=None):
    """Zbroj kategorijskih budzeta. `osim` izuzima zapis koji se upravo uredjuje."""
    upit = BudzetKategorije.objects.filter(
        korisnik=korisnik, godina=godina, mjesec=mjesec
    )
    if osim is not None:
        upit = upit.exclude(pk=osim)
    return zbroj(upit)
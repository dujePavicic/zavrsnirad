from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .serializers import KorisnikSerializer, PrijavaSerializer, RegistracijaSerializer

from django.db.models import Q
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters, viewsets
from rest_framework.exceptions import PermissionDenied

from .filters import TransakcijaFilter
from .models import Kategorija, Transakcija
from .serializers import KategorijaSerializer, TransakcijaSerializer


from decimal import Decimal

from django.db.models import Sum
from django.utils import timezone

from .models import Budzet
from .serializers import BudzetSerializer

from rest_framework.parsers import FormParser, JSONParser, MultiPartParser

from .filters import RacunFilter
from .models import Racun
from .serializers import RacunSerializer

import calendar

from .models import BudzetKategorije
from .serializers import BudzetKategorijeSerializer, ProfilSerializer



class RegistracijaPogled(generics.CreateAPIView):
    """POST /api/registracija/ — stvara korisnika, vraca 201."""

    serializer_class = RegistracijaSerializer
    permission_classes = [AllowAny]
    throttle_scope = "registracija"

class PrijavaPogled(APIView):
    """POST /api/prijava/ — identifikator + lozinka, vraca access i refresh."""

    permission_classes = [AllowAny]
    throttle_scope = "prijava"

    def post(self, zahtjev):
        serijalizator = PrijavaSerializer(data=zahtjev.data, context={"request": zahtjev})
        serijalizator.is_valid(raise_exception=True)
        return Response(serijalizator.validated_data, status=status.HTTP_200_OK)


class JaPogled(generics.RetrieveUpdateAPIView):
    """GET/PATCH /api/ja/ — podaci i uredjivanje vlastitog profila."""

    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_serializer_class(self):
        return KorisnikSerializer if self.request.method == "GET" else ProfilSerializer

    def get_object(self):
        return self.request.user


class OdjavaPogled(APIView):
    """POST /api/odjava/ — stavlja refresh token na crnu listu."""

    permission_classes = [IsAuthenticated]

    def post(self, zahtjev):
        token = zahtjev.data.get("refresh")
        if not token:
            return Response(
                {"detail": "Nedostaje refresh token."}, status=status.HTTP_400_BAD_REQUEST
            )
        try:
            RefreshToken(token).blacklist()
        except Exception:
            return Response(
                {"detail": "Token nije valjan."}, status=status.HTTP_400_BAD_REQUEST
            )
        return Response(status=status.HTTP_205_RESET_CONTENT)


class KategorijaViewSet(viewsets.ModelViewSet):
    """Sustavske kategorije + vlastite kategorije prijavljenog korisnika."""

    serializer_class = KategorijaSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ["tip"]

    def get_queryset(self):
        return Kategorija.objects.filter(
            Q(vlasnik__isnull=True) | Q(vlasnik=self.request.user)
        )

    def perform_create(self, serializer):
        serializer.save(vlasnik=self.request.user)

    def provjeri_vlasnistvo(self, kategorija):
        if kategorija.vlasnik_id is None:
            raise PermissionDenied("Predefinirane kategorije se ne mogu mijenjati ni brisati.")

    def perform_update(self, serializer):
        self.provjeri_vlasnistvo(serializer.instance)
        serializer.save()

    def perform_destroy(self, kategorija):
        self.provjeri_vlasnistvo(kategorija)
        kategorija.delete()


class TransakcijaViewSet(viewsets.ModelViewSet):
    """Prihodi i troskovi prijavljenog korisnika."""

    serializer_class = TransakcijaSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_class = TransakcijaFilter
    search_fields = ["opis", "racun__trgovina"]
    ordering_fields = ["datum", "iznos", "datum_unosa"]

    def get_queryset(self):
        return Transakcija.objects.filter(korisnik=self.request.user).select_related("kategorija")

    def perform_create(self, serializer):
        serializer.save(korisnik=self.request.user)


class BudzetViewSet(viewsets.ModelViewSet):
    """Mjesecni budzeti prijavljenog korisnika."""

    serializer_class = BudzetSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ["godina", "mjesec"]

    def get_queryset(self):
        return Budzet.objects.filter(korisnik=self.request.user)

    def perform_create(self, serializer):
        serializer.save(korisnik=self.request.user)


class BudzetKategorijeViewSet(viewsets.ModelViewSet):
    """Mjesecni budzeti po kategorijama prijavljenog korisnika."""

    serializer_class = BudzetKategorijeSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ["godina", "mjesec", "kategorija"]

    def get_queryset(self):
        return BudzetKategorije.objects.filter(
            korisnik=self.request.user
        ).select_related("kategorija")

    def perform_create(self, serializer):
        serializer.save(korisnik=self.request.user)


def novac(vrijednost):
    """Decimal -> string s dvije decimale, da frontend uvijek dobije isti oblik."""
    return str((vrijednost or Decimal("0")).quantize(Decimal("0.01")))


class PregledPogled(APIView):
    """GET /api/pregled/?godina=&mjesec= — zbrojevi za pocetni ekran."""

    permission_classes = [IsAuthenticated]

    def get(self, zahtjev):
        danas = timezone.localdate()
        try:
            godina = int(zahtjev.query_params.get("godina", danas.year))
            mjesec = int(zahtjev.query_params.get("mjesec", danas.month))
        except (TypeError, ValueError):
            return Response(
                {"detail": "Godina i mjesec moraju biti brojevi."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not 1 <= mjesec <= 12:
            return Response(
                {"detail": "Mjesec mora biti između 1 i 12."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        transakcije = Transakcija.objects.filter(
            korisnik=zahtjev.user, datum__year=godina, datum__month=mjesec
        )

        prihodi = transakcije.filter(tip=Transakcija.TipTransakcije.PRIHOD).aggregate(
            zbroj=Sum("iznos")
        )["zbroj"] or Decimal("0")
        troskovi = transakcije.filter(tip=Transakcija.TipTransakcije.TROSAK).aggregate(
            zbroj=Sum("iznos")
        )["zbroj"] or Decimal("0")

        budzeti_kategorija = {
            stavka.kategorija_id: stavka.iznos
            for stavka in BudzetKategorije.objects.filter(
                korisnik=zahtjev.user, godina=godina, mjesec=mjesec
            )
        }

        skupine = (
            transakcije.filter(tip=Transakcija.TipTransakcije.TROSAK)
            .values("kategorija", "kategorija__naziv", "kategorija__boja", "kategorija__ikona")
            .annotate(zbroj=Sum("iznos"))
            .order_by("-zbroj")
        )

        po_kategorijama = []
        for skupina in skupine:
            potroseno = skupina["zbroj"]
            budzet_kategorije = budzeti_kategorija.pop(skupina["kategorija"], None)
            po_kategorijama.append(
                {
                    "kategorija": skupina["kategorija"],
                    "naziv": skupina["kategorija__naziv"] or "Bez kategorije",
                    "boja": skupina["kategorija__boja"] or "#6B7280",
                    "ikona": skupina["kategorija__ikona"] or "category",
                    "iznos": novac(potroseno),
                    "postotak": (
                        round(float(potroseno / troskovi * 100), 1) if troskovi else 0.0
                    ),
                    "budzet": novac(budzet_kategorije) if budzet_kategorije else None,
                    "preostalo_budzeta": (
                        novac(budzet_kategorije - potroseno) if budzet_kategorije else None
                    ),
                }
            )

        # Kategorije koje imaju budzet, a jos nista nije potroseno
        for kategorija in Kategorija.objects.filter(id__in=budzeti_kategorija.keys()):
            iznos_budzeta = budzeti_kategorija[kategorija.id]
            po_kategorijama.append(
                {
                    "kategorija": kategorija.id,
                    "naziv": kategorija.naziv,
                    "boja": kategorija.boja,
                    "ikona": kategorija.ikona or "category",
                    "iznos": "0.00",
                    "postotak": 0.0,
                    "budzet": novac(iznos_budzeta),
                    "preostalo_budzeta": novac(iznos_budzeta),
                }
            )

        dana_u_mjesecu = calendar.monthrange(godina, mjesec)[1]
        if (godina, mjesec) > (danas.year, danas.month):
            protekli_dani = 0
        elif (godina, mjesec) == (danas.year, danas.month):
            protekli_dani = danas.day
        else:
            protekli_dani = dana_u_mjesecu

        danas_potroseno = Decimal("0")
        if (godina, mjesec) == (danas.year, danas.month):
            danas_potroseno = transakcije.filter(
                tip=Transakcija.TipTransakcije.TROSAK, datum=danas
            ).aggregate(zbroj=Sum("iznos"))["zbroj"] or Decimal("0")

        dnevni_prosjek = troskovi / protekli_dani if protekli_dani else Decimal("0")

        budzet = Budzet.objects.filter(
            korisnik=zahtjev.user, godina=godina, mjesec=mjesec
        ).first()

        zadnje = TransakcijaSerializer(
            transakcije.select_related("kategorija")[:5],
            many=True,
            context={"request": zahtjev},
        ).data

        return Response(
            {
                "godina": godina,
                "mjesec": mjesec,
                "ukupno_prihodi": novac(prihodi),
                "ukupno_troskovi": novac(troskovi),
                "saldo": novac(prihodi - troskovi),
                "budzet": novac(budzet.iznos) if budzet else None,
                "preostalo_budzeta": novac(budzet.iznos - troskovi) if budzet else None,
                "postotak_budzeta": (
                    round(float(troskovi / budzet.iznos * 100), 1)
                    if budzet and budzet.iznos
                    else None
                ),
                "broj_transakcija": transakcije.count(),
                "danas_potroseno": novac(danas_potroseno),
                "dnevni_prosjek": novac(dnevni_prosjek),
                "po_kategorijama": po_kategorijama,
                "zadnje_transakcije": zadnje,
            }
        )


class RacunViewSet(viewsets.ModelViewSet):
    """Digitalna arhiva racuna prijavljenog korisnika."""

    serializer_class = RacunSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_class = RacunFilter
    search_fields = ["trgovina", "prepoznati_tekst"]
    ordering_fields = ["datum_spremanja", "datum_izdavanja"]

    def get_queryset(self):
        return Racun.objects.filter(
            transakcija__korisnik=self.request.user
        ).select_related("transakcija", "transakcija__kategorija")

    def perform_destroy(self, racun):
        racun.transakcija.delete()
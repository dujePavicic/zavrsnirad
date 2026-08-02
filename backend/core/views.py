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

class RegistracijaPogled(generics.CreateAPIView):
    """POST /api/registracija/ — stvara korisnika, vraca 201."""

    serializer_class = RegistracijaSerializer
    permission_classes = [AllowAny]


class PrijavaPogled(APIView):
    """POST /api/prijava/ — identifikator + lozinka, vraca access i refresh."""

    permission_classes = [AllowAny]

    def post(self, zahtjev):
        serijalizator = PrijavaSerializer(data=zahtjev.data, context={"request": zahtjev})
        serijalizator.is_valid(raise_exception=True)
        return Response(serijalizator.validated_data, status=status.HTTP_200_OK)


class JaPogled(generics.RetrieveAPIView):
    """GET /api/ja/ — podaci o trenutno prijavljenom korisniku."""

    serializer_class = KorisnikSerializer
    permission_classes = [IsAuthenticated]

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
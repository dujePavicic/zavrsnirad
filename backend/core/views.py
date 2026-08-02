from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .serializers import KorisnikSerializer, PrijavaSerializer, RegistracijaSerializer


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
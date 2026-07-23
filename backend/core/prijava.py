from django.contrib.auth import get_user_model
from django.contrib.auth.backends import ModelBackend
from django.db.models import Q


class EmailIliKorisnickoImeBackend(ModelBackend):
    def authenticate(self, request, username=None, password=None, **kwargs):
        ModelKorisnika = get_user_model()
        prijava = username or kwargs.get("email")

        if not prijava or not password:
            return None

        try:
            korisnik = ModelKorisnika.objects.get(
                Q(emailiexact=prijava) | Q(korisnicko_imeiexact=prijava)
            )
        except ModelKorisnika.DoesNotExist:
            ModelKorisnika().set_password(password)
            return None
        except ModelKorisnika.MultipleObjectsReturned:
            return None

        if korisnik.check_password(password) and self.user_can_authenticate(korisnik):
            return korisnik
        return None
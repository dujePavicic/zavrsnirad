import calendar
import random
from datetime import date
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from core.models import Budzet, Kategorija, Racun, Transakcija

# kategorija: (trgovine, najmanji iznos, najveci iznos, broj po mjesecu)
POTROSNJA = {
    "Namirnice": (["Konzum", "Plodine", "Lidl", "Kaufland", "Tommy"], 6, 65, 11),
    "Prijevoz": (["INA", "Petrol", "Autotrolej"], 10, 70, 4),
    "Zdravlje": (["Ljekarna Rijeka", "Poliklinika"], 8, 90, 1),
    "Režije": (["HEP", "Vodovod", "A1"], 25, 140, 3),
    "Zabava": (["Cineplexx", "Kino Art", "Steam"], 5, 45, 3),
    "Odjeća": (["Zara", "H&M", "Sport Vision"], 20, 120, 1),
    "Kućanstvo": (["Bauhaus", "Pevex", "JYSK"], 10, 80, 2),
}

TRGOVINE_S_RACUNOM = {"Namirnice", "Kućanstvo", "Odjeća"}


class Command(BaseCommand):
    help = "Puni bazu testnim transakcijama, racunima i budzetima."

    def add_arguments(self, parser):
        parser.add_argument("--korisnik", required=True, help="Email ili korisnicko ime")
        parser.add_argument("--mjeseci", type=int, default=4, help="Koliko mjeseci unatrag")
        parser.add_argument("--obrisi", action="store_true", help="Prvo obrisi postojece podatke")
        parser.add_argument("--sjeme", type=int, default=2026, help="Sjeme za ponovljive podatke")

    def handle(self, *args, **opcije):
        random.seed(opcije["sjeme"])
        korisnik = self.pronadi_korisnika(opcije["korisnik"])

        if opcije["obrisi"]:
            obrisano, _ = Transakcija.objects.filter(korisnik=korisnik).delete()
            Budzet.objects.filter(korisnik=korisnik).delete()
            self.stdout.write(f"Obrisano zapisa: {obrisano}")

        kategorije = {k.naziv: k for k in Kategorija.objects.filter(vlasnik__isnull=True)}
        danas = timezone.localdate()
        ukupno = 0

        for unatrag in range(opcije["mjeseci"] - 1, -1, -1):
            prvi = self.pocetak_mjeseca(danas, unatrag)
            dana_u_mjesecu = calendar.monthrange(prvi.year, prvi.month)[1]
            zadnji_dan = dana_u_mjesecu
            if prvi.year == danas.year and prvi.month == danas.month:
                zadnji_dan = danas.day
            udio = zadnji_dan / dana_u_mjesecu

            ukupno += self.napravi_prihode(korisnik, kategorije, prvi, zadnji_dan)
            ukupno += self.napravi_troskove(korisnik, kategorije, prvi, zadnji_dan, udio)

            Budzet.objects.update_or_create(
                korisnik=korisnik,
                godina=prvi.year,
                mjesec=prvi.month,
                defaults={"iznos": Decimal("1100.00")},
            )

        self.stdout.write(self.style.SUCCESS(f"Stvoreno transakcija: {ukupno}"))

    def pronadi_korisnika(self, oznaka):
        Korisnik = get_user_model()
        korisnik = (
            Korisnik.objects.filter(email__iexact=oznaka).first()
            or Korisnik.objects.filter(korisnicko_ime__iexact=oznaka).first()
        )
        if korisnik is None:
            raise CommandError(f"Korisnik '{oznaka}' ne postoji.")
        return korisnik

    def pocetak_mjeseca(self, danas, unatrag):
        godina, mjesec = danas.year, danas.month - unatrag
        while mjesec <= 0:
            mjesec += 12
            godina -= 1
        return date(godina, mjesec, 1)

    def iznos(self, od, do):
        return Decimal(str(round(random.uniform(od, do), 2)))

    def napravi_prihode(self, korisnik, kategorije, prvi, zadnji_dan):
        placa = kategorije.get("Plaća")
        if placa is None or zadnji_dan < 15:
            return 0
        Transakcija.objects.create(
            korisnik=korisnik,
            tip=Transakcija.TipTransakcije.PRIHOD,
            iznos=self.iznos(1150, 1350),
            kategorija=placa,
            datum=prvi.replace(day=15),
            opis="Plaća",
        )
        return 1

    def napravi_troskove(self, korisnik, kategorije, prvi, zadnji_dan, udio=1.0):
        stvoreno = 0
        for naziv, (trgovine, od, do, koliko) in POTROSNJA.items():
            kategorija = kategorije.get(naziv)
            if kategorija is None:
                continue
            for _ in range(max(1, round(koliko * udio))):
                trgovina = random.choice(trgovine)
                iznos = self.iznos(od, do)
                transakcija = Transakcija.objects.create(
                    korisnik=korisnik,
                    tip=Transakcija.TipTransakcije.TROSAK,
                    iznos=iznos,
                    kategorija=kategorija,
                    datum=prvi.replace(day=random.randint(1, zadnji_dan)),
                    opis=trgovina,
                )
                stvoreno += 1
                if naziv in TRGOVINE_S_RACUNOM and random.random() < 0.6:
                    Racun.objects.create(
                        transakcija=transakcija,
                        trgovina=trgovina,
                        datum_izdavanja=transakcija.datum,
                        prepoznati_tekst=(
                            f"{trgovina.upper()}\n"
                            f"Datum: {transakcija.datum.strftime('%d.%m.%Y.')}\n"
                            f"UKUPNO: {str(iznos).replace('.', ',')} EUR"
                        ),
                    )
        return stvoreno
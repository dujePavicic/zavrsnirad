from django.core.management.base import BaseCommand

from core.ocr import analiziraj_racun
from core.uzorci import POLJA, ucitaj_uzorke


class Command(BaseCommand):
    help = "Mjeri tocnost OCR parsera na uzorcima stvarnih racuna."

    def add_arguments(self, parser):
        parser.add_argument(
            "--detaljno",
            action="store_true",
            help="Ispisi ocekivanu i dobivenu vrijednost za svaki promasaj.",
        )

    def handle(self, *args, **opcije):
        uzorci = ucitaj_uzorke()
        if not uzorci:
            self.stdout.write(self.style.WARNING("Nema uzoraka u mapi ocr_uzorci."))
            return

        pogodaka = {polje: 0 for polje in POLJA}
        provjera = {polje: 0 for polje in POLJA}
        promasaji = []

        sirina = max(len(uzorak["naziv"]) for uzorak in uzorci) + 2
        zaglavlje = "UZORAK".ljust(sirina) + "  ".join(
            polje[:8].upper().ljust(10) for polje in POLJA
        )
        self.stdout.write(zaglavlje)
        self.stdout.write("-" * len(zaglavlje))

        for uzorak in uzorci:
            rezultat = analiziraj_racun(uzorak["tekst"])
            redak = uzorak["naziv"].ljust(sirina)

            for polje, kljuc_rezultata in POLJA.items():
                ocekivana = uzorak["ocekivano"].get(polje)
                if ocekivana is None:
                    redak += "-".ljust(12)
                    continue

                provjera[polje] += 1
                dobivena = rezultat.get(kljuc_rezultata)
                if dobivena == ocekivana:
                    pogodaka[polje] += 1
                    redak += "OK".ljust(12)
                else:
                    redak += "PROMASAJ".ljust(12)
                    promasaji.append((uzorak["naziv"], polje, ocekivana, dobivena))

            self.stdout.write(redak)

        self.stdout.write("")
        ukupno_pogodaka = sum(pogodaka.values())
        ukupno_provjera = sum(provjera.values())

        for polje in POLJA:
            if not provjera[polje]:
                continue
            postotak = pogodaka[polje] / provjera[polje] * 100
            self.stdout.write(
                f"{polje.ljust(12)} {pogodaka[polje]}/{provjera[polje]}  ({postotak:.0f} %)"
            )

        if ukupno_provjera:
            postotak = ukupno_pogodaka / ukupno_provjera * 100
            poruka = f"UKUPNO       {ukupno_pogodaka}/{ukupno_provjera}  ({postotak:.0f} %)"
            stil = self.style.SUCCESS if not promasaji else self.style.WARNING
            self.stdout.write("")
            self.stdout.write(stil(poruka))

        if promasaji and opcije["detaljno"]:
            self.stdout.write("")
            self.stdout.write("Promašaji:")
            for naziv, polje, ocekivana, dobivena in promasaji:
                self.stdout.write(f"  {naziv} / {polje}: očekivano {ocekivana}, dobiveno {dobivena}")
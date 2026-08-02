from django.db import migrations

SUSTAVSKE_KATEGORIJE = [
    ("Namirnice", "TROSAK", "#0F6E56", "shopping_cart"),
    ("Prijevoz", "TROSAK", "#2F6FED", "directions_car"),
    ("Zdravlje", "TROSAK", "#E14D4D", "favorite"),
    ("Režije", "TROSAK", "#F0A020", "receipt_long"),
    ("Zabava", "TROSAK", "#8B5CF6", "sports_esports"),
    ("Odjeća", "TROSAK", "#EC4899", "checkroom"),
    ("Kućanstvo", "TROSAK", "#0EA5A5", "home"),
    ("Ostalo", "TROSAK", "#6B7280", "category"),
    ("Plaća", "PRIHOD", "#0F6E56", "payments"),
    ("Ostali prihodi", "PRIHOD", "#16A34A", "savings"),
]


def dodaj_kategorije(apps, schema_editor):
    Kategorija = apps.get_model("core", "Kategorija")
    for naziv, tip, boja, ikona in SUSTAVSKE_KATEGORIJE:
        Kategorija.objects.get_or_create(
            naziv=naziv,
            vlasnik=None,
            defaults={"tip": tip, "boja": boja, "ikona": ikona},
        )


def ukloni_kategorije(apps, schema_editor):
    Kategorija = apps.get_model("core", "Kategorija")
    nazivi = [stavka[0] for stavka in SUSTAVSKE_KATEGORIJE]
    Kategorija.objects.filter(vlasnik=None, naziv__in=nazivi).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0002_kategorija_transakcija_racun_budzet_and_more"),
    ]

    operations = [
        migrations.RunPython(dodaj_kategorije, ukloni_kategorije),
    ]
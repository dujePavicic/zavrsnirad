"""Izvlacenje podataka iz teksta koji OCR prepozna na racunu."""

import re
import unicodedata
from datetime import date
from decimal import Decimal, InvalidOperation


def bez_kvacica(tekst):
    """Mala slova bez dijakritike, da se 'PLAĆENO' i 'placeno' poklope."""
    tekst = tekst.replace("đ", "d").replace("Đ", "D")
    razlozeno = unicodedata.normalize("NFKD", tekst)
    return "".join(znak for znak in razlozeno if not unicodedata.combining(znak)).lower()

def zbij(tekst):
    """Uklanja sve razmake — racuni znaju pisati 'U K U P N O' razmaknutim slovima."""
    return re.sub(r"\s+", "", tekst)

# Oznake ukupnog iznosa, od najpouzdanije prema manje pouzdanoj.
# "za platiti" mora doci prije "ukupno" jer racuni s popustom imaju oboje,
# a tada je "UKUPNO" iznos prije popusta.
KLJUCNE_RIJECI = [
    "sveukupno",
    "ukupno za platiti",
    "za platiti",
    "za placanje",
    "ukupan iznos",
    "iznos za platiti",
    "ukupno",
    "total",
    "placeno",
    "s pdv",
    "ukupna uplata",
]

# Retci koji sadrze iznose, ali nikad ukupan iznos racuna.
ZABRANJENI_RETCI = [
    "porez",
    "pdv",
    "osnovica",
    "stopa",
    "popust",
    "naknada",
    "povrat",
    "gotovina",
    "kusur",
    "ostatak",
    "bodova",
    "loyalty",
    "rabat",
    "bez pdv",
]

# Kljuc za trazenje -> (naziv za prikaz, predlozena kategorija).
# Kljucevi su bez kvacica i malim slovima.
POZNATE_TRGOVINE = {
    "konzum": ("Konzum", "Namirnice"),
    "plodine": ("Plodine", "Namirnice"),
    "lidl": ("Lidl", "Namirnice"),
    "kaufland": ("Kaufland", "Namirnice"),
    "spar": ("Spar", "Namirnice"),
    "tommy": ("Tommy", "Namirnice"),
    "studenac": ("Studenac", "Namirnice"),
    "eurospin": ("Eurospin", "Namirnice"),
    "ntl": ("NTL", "Namirnice"),
    "ina": ("INA", "Prijevoz"),
    "petrol": ("Petrol", "Prijevoz"),
    "crodux": ("Crodux", "Prijevoz"),
    "tifon": ("Tifon", "Prijevoz"),
    "autotrolej": ("Autotrolej", "Prijevoz"),
    "ljekarna": ("Ljekarna", "Zdravlje"),
    "muller": ("Müller", "Kućanstvo"),
    "bipa": ("Bipa", "Kućanstvo"),
    "pevex": ("Pevex", "Kućanstvo"),
    "bauhaus": ("Bauhaus", "Kućanstvo"),
    "jysk": ("JYSK", "Kućanstvo"),
    "ikea": ("IKEA", "Kućanstvo"),
    "zara": ("Zara", "Odjeća"),
    "h&m": ("H&M", "Odjeća"),
    "cineplexx": ("Cineplexx", "Zabava"),
    "hep": ("HEP", "Režije"),
    "tisak": ("Tisak", "Ostalo"),
    "dm": ("dm", "Kućanstvo"),
    "tokic": ("Tokić", "Prijevoz"),
}

# Kratke oznake (ina, dm, hep, ntl) traze se samo u zaglavlju racuna,
# jer se kao podniz javljaju i u obicnim rijecima ("kolicina", "trgovina").
NAJKRACI_IZVAN_ZAGLAVLJA = 4

OBRAZAC_IZNOSA = re.compile(r"\d[\d.\s]*[,.]\d{2}(?!\d)")
OBRAZAC_DATUMA = re.compile(r"\b(\d{1,2})[.\-/](\d{1,2})[.\-/](\d{2,4})\b")
OBRAZAC_ISO_DATUMA = re.compile(r"\b(\d{4})-(\d{2})-(\d{2})\b")
OBRAZAC_OIB_UZ_OZNAKU = re.compile(r"oib\D{0,6}(\d{11})")
OBRAZAC_BILO_KOJI_OIB = re.compile(r"\b\d{11}\b")


def u_decimal(zapis):
    """Pretvara zapis iznosa s racuna u Decimal. Podrzava 1.234,56 i 1234.56."""
    zapis = zapis.replace(" ", "")
    if "," in zapis:
        zapis = zapis.replace(".", "").replace(",", ".")
    else:
        dijelovi = zapis.split(".")
        # 1.234 je tisucica, 12.34 je decimalni zapis
        if len(dijelovi) > 2 or (len(dijelovi) == 2 and len(dijelovi[1]) == 3):
            zapis = zapis.replace(".", "")
    try:
        return Decimal(zapis).quantize(Decimal("0.01"))
    except InvalidOperation:
        return None


def iznosi_u_retku(redak):
    return [iznos for iznos in (u_decimal(z) for z in OBRAZAC_IZNOSA.findall(redak)) if iznos]


def je_zabranjen(ocisceni_redak):
    """Redak porezne tablice, popusta, povrata i slicnog nikad nije ukupan iznos."""
    if "%" in ocisceni_redak:
        return True
    return any(rijec in ocisceni_redak for rijec in ZABRANJENI_RETCI)


def je_tablicni_redak(redak):
    """Tri ili vise iznosa u retku znaci stavku ili porezni redak, ne ukupan iznos."""
    return len(iznosi_u_retku(redak)) >= 3


def pronadji_iznos(retci):
    """Trazi ukupan iznos: uz kljucnu rijec, pa u sljedecem retku, na kraju najveci."""
    ocisceni = [bez_kvacica(redak) for redak in retci]
    zbijeni = [zbij(redak) for redak in ocisceni]
    preskoci = [
        je_zabranjen(ocisceni[i]) or je_tablicni_redak(retci[i]) for i in range(len(retci))
    ]

    for kljucna in KLJUCNE_RIJECI:
        kljuc = zbij(kljucna)
        for redni_broj, redak in enumerate(zbijeni):
            if kljuc not in redak or preskoci[redni_broj]:
                continue
            nadjeni = iznosi_u_retku(retci[redni_broj])
            if nadjeni:
                return max(nadjeni)
            # OCR cesto prelomi oznaku i iznos u dva bloka
            sljedeci = redni_broj + 1
            if sljedeci < len(retci) and not preskoci[sljedeci]:
                nadjeni = iznosi_u_retku(retci[sljedeci])
                if nadjeni:
                    return max(nadjeni)

    svi = [
        iznos
        for redni_broj, redak in enumerate(retci)
        if not preskoci[redni_broj]
        for iznos in iznosi_u_retku(redak)
    ]
    return max(svi) if svi else None


def kandidati_datuma(tekst):
    nadjeni = []
    for dan, mjesec, godina in OBRAZAC_DATUMA.findall(tekst):
        godina = int(godina)
        if godina < 100:
            godina += 2000
        nadjeni.append((godina, int(mjesec), int(dan)))
    for godina, mjesec, dan in OBRAZAC_ISO_DATUMA.findall(tekst):
        nadjeni.append((int(godina), int(mjesec), int(dan)))
    return nadjeni


def pronadji_datum(tekst):
    """Prvo gleda retke koji spominju datum, pa tek onda cijeli tekst."""
    danas = date.today()
    retci = [redak for redak in tekst.splitlines() if redak.strip()]
    s_oznakom = "\n".join(
        redak for redak in retci if "datum" in bez_kvacica(redak)
    )

    for izvor in (s_oznakom, tekst):
        for godina, mjesec, dan in kandidati_datuma(izvor):
            try:
                nadjen = date(godina, mjesec, dan)
            except ValueError:
                continue
            if date(2015, 1, 1) <= nadjen <= danas:
                return nadjen
    return None


def pronadji_oib(tekst):
    uz_oznaku = OBRAZAC_OIB_UZ_OZNAKU.search(bez_kvacica(tekst))
    if uz_oznaku:
        return uz_oznaku.group(1)
    bilo_koji = OBRAZAC_BILO_KOJI_OIB.search(tekst)
    return bilo_koji.group() if bilo_koji else None


def pronadji_trgovinu(retci):
    """Vraca (naziv, predlozena kategorija). Nepoznata trgovina -> prvi smislen redak."""
    zaglavlje = bez_kvacica(" ".join(retci[:8]))
    cijeli = bez_kvacica(" ".join(retci))

    for tekst, najkraci in ((zaglavlje, 1), (cijeli, NAJKRACI_IZVAN_ZAGLAVLJA)):
        for kljuc, (naziv, kategorija) in POZNATE_TRGOVINE.items():
            if len(kljuc) < najkraci:
                continue
            obrazac = rf"(?<![a-z0-9]){re.escape(kljuc)}(?![a-z0-9])"
            if re.search(obrazac, tekst):
                return naziv, kategorija

    for redak in retci[:5]:
        ocisceno = redak.strip()
        slova = sum(1 for znak in ocisceno if znak.isalpha())
        if len(ocisceno) >= 3 and slova >= len(ocisceno) / 2:
            return ocisceno[:150], None
    return "", None


def analiziraj_racun(tekst):
    """Iz sirovog OCR teksta vraca prijedloge za ekran potvrde."""
    retci = [redak.strip() for redak in tekst.splitlines() if redak.strip()]
    trgovina, kategorija = pronadji_trgovinu(retci)
    iznos = pronadji_iznos(retci)
    datum = pronadji_datum(tekst)

    return {
        "trgovina": trgovina,
        "predlozena_kategorija": kategorija,
        "iznos": str(iznos) if iznos else None,
        "datum": datum.isoformat() if datum else None,
        "oib": pronadji_oib(tekst),
        "pouzdanost": {
            "iznos": iznos is not None,
            "datum": datum is not None,
            "trgovina": kategorija is not None,
        },
    }
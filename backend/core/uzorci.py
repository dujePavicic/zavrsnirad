"""Ucitavanje uzoraka OCR teksta sa stvarnih racuna."""

import json
from pathlib import Path

MAPA_UZORAKA = Path(__file__).resolve().parent / "ocr_uzorci"
DATOTEKA_OCEKIVANOG = MAPA_UZORAKA / "ocekivano.json"

# Kljuc u ocekivano.json -> kljuc u rezultatu parsera
POLJA = {
    "iznos": "iznos",
    "datum": "datum",
    "trgovina": "trgovina",
    "oib": "oib",
    "kategorija": "predlozena_kategorija",
}


def ucitaj_ocekivano():
    if not DATOTEKA_OCEKIVANOG.exists():
        return {}
    return json.loads(DATOTEKA_OCEKIVANOG.read_text(encoding="utf-8"))


def ucitaj_uzorke():
    """Vraca popis uzoraka: naziv, sirovi tekst i ocekivane vrijednosti."""
    ocekivano = ucitaj_ocekivano()
    uzorci = []
    for putanja in sorted(MAPA_UZORAKA.glob("*.txt")):
        uzorci.append(
            {
                "naziv": putanja.stem,
                "tekst": putanja.read_text(encoding="utf-8"),
                "ocekivano": ocekivano.get(putanja.stem, {}),
            }
        )
    return uzorci
"""Sprachcode des Pakets → Sprachfassung bei App Store Connect (#760, Epic #750).

Die Liste der ausgelieferten Sprachen steht nur im Swift-Code (`LanguagePacks.shipped`, `shipped_languages.py`).
Ein Code ohne Eintrag hier ist ein Fehler, kein stilles Weglassen: Eine neue Sprache braucht ihre Fassung bei Apple.
"""
from asc_wait_build import Fatal
from shipped_languages import ROOT, ShippedLanguagesError, shipped_languages

ASC_LOCALES = {"de": "de-DE", "en": "en-US"}
GERMAN = "de-DE"


def language_locales(root=ROOT):
    """[(Sprachcode, Locale)] in der Reihenfolge von `shipped`."""
    try:
        codes = shipped_languages(root)
    except ShippedLanguagesError as error:
        raise Fatal(str(error))
    unknown = [code for code in codes if code not in ASC_LOCALES]
    if unknown:
        raise Fatal(f"Language {', '.join(unknown)} is shipped but has no App Store Connect locale in scripts/asc_locales.py")
    return [(code, ASC_LOCALES[code]) for code in codes]


def asc_locales(root=ROOT):
    """Die Locales aller ausgelieferten Sprachen, etwa ["en-US", "de-DE"]."""
    return [locale for _, locale in language_locales(root)]

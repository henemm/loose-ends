"""Die ausgelieferten Sprachen, gelesen aus dem Swift-Code (#756, Epic #750).

Die Liste existiert nur einmal: `LanguagePacks.shipped` in `Shared/Language/LanguagePack.swift`. Skripte fragen sie hier ab,
statt `de` fest einzutragen.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LANGUAGE_FOLDER = "Shared/Language"
PACK_FILE = f"{LANGUAGE_FOLDER}/LanguagePack.swift"

SHIPPED = re.compile(r"static\s+let\s+shipped\s*:\s*\[LanguagePack\]\s*=\s*\[([^\]]*)\]")
PACK_NAME = re.compile(r"\.([A-Za-z_]\w*)")


class ShippedLanguagesError(Exception):
    pass


def shipped_languages(root=ROOT):
    """Sprachcodes in der Reihenfolge von `shipped`, etwa `["en", "de"]`. Wirft mit Dateiname, wenn etwas fehlt."""
    root = Path(root)
    pack_file = root / PACK_FILE
    if not pack_file.is_file():
        raise ShippedLanguagesError(f"{PACK_FILE} fehlt")
    match = SHIPPED.search(pack_file.read_text(encoding="utf-8"))
    if not match:
        raise ShippedLanguagesError(f"{PACK_FILE}: keine Zeile `static let shipped: [LanguagePack] = [...]`")
    names = PACK_NAME.findall(match.group(1))
    if not names:
        raise ShippedLanguagesError(f"{PACK_FILE}: `shipped` ist leer")
    sources = sorted((root / LANGUAGE_FOLDER).glob("*.swift"))
    codes = []
    for name in names:
        declaration = re.compile(rf"static\s+let\s+{re.escape(name)}\b")
        code = None
        for source in sources:
            text = source.read_text(encoding="utf-8")
            found = declaration.search(text)
            if found:
                code_match = re.search(r'\bcode:\s*"([a-z]{2,3})"', text[found.end():])
                if not code_match:
                    raise ShippedLanguagesError(f"{source.relative_to(root)}: `{name}` ohne `code: \"xx\"`")
                code = code_match.group(1)
                break
        if code is None:
            raise ShippedLanguagesError(f"{LANGUAGE_FOLDER}: keine Datei mit `static let {name}`")
        codes.append(code)
    return codes


if __name__ == "__main__":
    # `python3 scripts/shipped_languages.py` gibt die Liste als JSON aus, etwa `["en","de"]` (Matrix in ci.yml, #761).
    import json
    import sys
    try:
        print(json.dumps(shipped_languages(), separators=(",", ":")))
    except ShippedLanguagesError as error:
        print(f"::error::{error}")
        sys.exit(1)

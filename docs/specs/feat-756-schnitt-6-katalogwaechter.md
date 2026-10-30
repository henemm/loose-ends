---
entity_id: feat-756-schnitt-6-katalogwaechter
type: feature
created: 2026-10-30
updated: 2026-10-30
status: approved
workflow: feat-756-schnitt-6-katalogwaechter
---

# Spec: #756 Schnitt 6 — Katalogwächter liest `LanguagePacks.shipped`

Epic #750. Nach #751, parallel zu #752–#755. Modell: Haiku.

## Approval

- [x] Approved — pauschal durch Henning am 2026-10-30 über #750.

## Purpose

`scripts/test_infoplist_languages.py` prüft fest `de`. Die Sprachliste soll nur einmal existieren: im Swift-Code
(`LanguagePacks.shipped`). Skripte lesen sie von dort.

Ohne Modell geht es nicht: nicht relevant.

## Source

- `scripts/test_infoplist_languages.py`: `usage_keys`, `german_keys`, `missing_german`, `literals_missing_from_catalog`,
  Klassen `InfoPlistLanguageTests`, `CatalogLanguageTests`, `CodeLiteralTests`, `ComplicationLiteralTests`; `CODE_FOLDERS = ["LooseEnds", "Shared"]` (Z. 120).
- CI: `unittest discover -s scripts -p 'test_*.py'` (ci.yml Z. 33).
- `Shared/Language/LanguagePack.swift` (#751): `static let shipped: [LanguagePack] = [.english, .german]`; Packs mit `code: "en"` / `code: "de"`.

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| scripts/shipped_languages.py | NEW | `shipped_languages(root) -> list[str]`, Regex über `shipped` und die `code:`-Konstanten |
| scripts/test_catalog_languages.py | RENAME+MODIFY | aus `test_infoplist_languages.py`; Schleife über Sprachen ≠ `en` |
| scripts/test_shipped_languages.py | NEW | drei Tests |
| CLAUDE.md, docs/reference/testflight.md | MODIFY | Skriptname nachziehen (zwei Fundstellen) |

LoC Python ≈ +80 / −20.

## Implementation Details

- `shipped_languages()`: liest `LanguagePack.swift`, findet `static let shipped: [LanguagePack] = [ … ]`, zieht die Namen
  (`.english`, `.german`), sucht je Namen die Datei `Shared/Language/*.swift` mit `static let <name>` und darin `code: "xx"`.
  Fehler mit Dateiname und Zeile, wenn eins fehlt. Ergebnis in Reihenfolge der Liste.
- `test_catalog_languages.py`: `LANGUAGES = [c for c in shipped_languages(ROOT) if c != "en"]`. Jede bestehende Prüfung läuft je
  Sprache (`subTest(lang=…)`): `InfoPlist.strings` in `<lang>.lproj` schlüsselgleich zu `en.lproj`; jeder Katalogschlüssel der
  fünf `*.xcstrings` mit Einheit `state == "translated"` für `lang`; `AppShortcuts.xcstrings` je Sprache mindestens eine Phrase je Kurzbefehl.
- `CODE_FOLDERS` um `LooseEndsWatch` erweitern (fünf Literale, im Katalog vorhanden; geprüft 2026-10-30).
- Fehlermeldung nennt Sprache, Datei und ersten fehlenden Schlüssel.

## Test Plan

- [ ] `test_shipped_languages.py::test_real_file_lists_en_and_de`: GIVEN Repo THEN `["en", "de"]`.
- [ ] `::test_missing_code_names_file`: GIVEN Kopie ohne `code:` in einem Pack THEN Fehler nennt die Datei.
- [ ] `::test_missing_shipped_line_fails`: GIVEN Kopie ohne `shipped` THEN Fehler nennt `LanguagePack.swift`.
- [ ] Bestehende Tests der umbenannten Datei grün; neue `subTest`-Fälle je Sprache grün.
- [ ] Manuell im PR: GIVEN Wegwerf-Commit mit `.test`-Pack in `shipped` (oder `code: "zz"` in einer Kopie) WHEN `python3 -m unittest scripts.test_catalog_languages` THEN rot mit `zz` und dem ersten fehlenden Schlüssel; Logauszug im PR, Commit entfernt.

## Acceptance Criteria

- **AC-1:** `grep -rn '"de"' scripts/test_catalog_languages.py` liefert nichts außer Testdaten der Selbsttests.
- **AC-2:** CI-Job der Skripttests grün; der Wegwerf-Lauf rot mit Sprachcode.
- **AC-3:** Kein Verweis auf `test_infoplist_languages.py` mehr im Repo (`grep -rn test_infoplist_languages . --exclude-dir=.git` leer).

## Definition of Done

- [ ] AC-1 bis AC-3 belegt. PR `test: Katalogwächter liest die ausgelieferten Sprachen (Refs #750, Closes #756)`; Merge; Board Done.
- [ ] „Kein Pfad der Geräteliste berührt.“

## Changelog

- 2026-10-30: Spec erstellt.

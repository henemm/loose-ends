---
entity_id: feat-837-en-name
type: feature
created: 2026-11-06
updated: 2026-11-06
status: draft
workflow: feat-837-en-name
---

# Spec: #837 Englischer App-Name mit Zusatz

## Approval

- [ ] Approved

## Purpose

Das Anlegen der englischen App-Info-Lokalisierung (en-US) scheitert bei Apple mit HTTP 409 `ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE.DIFFERENT_ACCOUNT` (Lauf 42183585381, nach PR #850). Apple hält den Namen „Loose Ends“ im Englischen für vergeben. Henning hat am 2026-11-06 entschieden: englischer Name mit Zusatz, der deutsche Name bleibt „Loose Ends“. Gewählt: `Loose Ends: Voice Tasks` (23 Zeichen). Sichtbar ändert sich: im englischen App Store heißt die App künftig so; im deutschen bleibt alles. Die App selbst ändert sich nicht. Der Fehler ist keine Verschlechterung: der englische Auftritt lief nie.

Ohne Modell geht es nicht: nicht relevant, eine Textzeile in einer Referenzdatei.

Recherche (2026-11-06, vor der Analyse): Apple-Forum zum wörtlichen Code bei `appInfoLocalizations` (<https://developer.apple.com/forums/thread/844943>, ohne Antwort; Name blieb auch nach Löschen des alten Eintrags gesperrt); Apple-Hilfe „Add a new app“ (Name je Lokalisierung einmalig, <https://www.developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app>); Namensstreit mit fremder App: Markenformular und Forenberichte, praktisch half nur ein anderer Name (<https://developer.apple.com/forums/thread/685777>, <https://developer.apple.com/forums/thread/691494>). Zum Code selbst gibt es keine Apple-Dokumentation; die Deutung „Name vergeben“ ist ungeprüft, der Lauf nach dem Merge ist der Test.

## Source

- **File:** `docs/reference/app-store-untertitel.md`
- **Identifier:** Abschnitt `## en-US`, Zeile `Name:`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `scripts/asc_app_info.py` `wanted_texts` | module | liest Name/Untertitel aus der Datei, prüft ≤ 30 Zeichen vor jeder Anfrage; keine Änderung nötig |
| `.github/workflows/asc-app-info.yml` | workflow | Handlauf `untertitel` und `lesen` |
| App Store Connect API `appInfoLocalizations` | extern | nimmt den Namen an oder lehnt ihn ab |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| docs/reference/app-store-untertitel.md | MODIFY | `## en-US`: `Name: Loose Ends: Voice Tasks` |
| scripts/test_asc_app_info.py | MODIFY | `test_repo_text_file_parses_and_fits_limit` erwartet für en-US den neuen Namen (eigene Konstante `EN_NAME`; `NAME` bleibt der Name des deutschen Fake-Eintrags) |

### Estimated Changes
- Files: 2
- LoC: ca. +3/−2

## Implementation Details

Nur die Zeile `Name:` im Abschnitt en-US ändert sich; die Marke „Loose Ends“ bleibt vorn. Danach läuft der Handlauf `asc-app-info aktion=untertitel`. Der Parser teilt jede Zeile am ersten Doppelpunkt (`line.partition(":")`), der zweite Doppelpunkt bleibt im Wert; der Test belegt, dass der Wert vollständig ankommt.

**Alternativen:**
1. `Loose Ends – Quick Capture` (26 Zeichen): neutraler, weniger greifbar; der lange Gedankenstrich ist ein Zeichen mit Sonderfall im Parser und in der Anzeige.
2. Name „Loose Ends“ behalten und bei Apple klären (Support/Markenformular): spart den Zusatz, dauert unbestimmt, ohne Beleg, dass der Name uns zusteht. Kippt nichts, blockiert aber den englischen Auftritt.
3. Keine en-US-Lokalisierung anlegen: englische Besucher sähen den deutschen Untertitel; kippt die Entscheidung „Deutsch und Englisch“ aus #788.

Keine ADR wird gekippt.

## Test Plan

### Automated Tests (TDD RED)

`unittest`, `python3 scripts/test_asc_app_info.py`.

- [ ] `test_repo_text_file_parses_and_fits_limit` (angepasst): GIVEN die echte Textdatei THEN `wanted["en-US"]["name"] == "Loose Ends: Voice Tasks"` (vollständig, mit dem Doppelpunkt), deutscher Name unverändert, alle Werte ≤ 30 Zeichen. Vor der Dateiänderung rot.

Alle übrigen Tests bleiben unverändert grün (`scripts/test_asc_*.py`).

## Acceptance Criteria

- **AC-1:** Given die Textdatei, When `wanted_texts` sie liest, Then ist der en-US-Name `Loose Ends: Voice Tasks`, ≤ 30 Zeichen, und der de-DE-Name unverändert. Belegt durch `test_repo_text_file_parses_and_fits_limit`.
- **AC-2:** Given der Merge auf `main`, When `asc-app-info aktion=untertitel` läuft, Then legt Apple en-US mit Name und Untertitel an (kein 409), oder das Protokoll nennt Apples Fehlercode erneut. Belegt durch den Lauf-Link.
- **AC-3:** Given AC-2 gelungen, When `asc-app-info aktion=lesen` läuft, Then zeigt es en-US mit Name `Loose Ends: Voice Tasks` und Untertitel „Say it. Clear your head.“. Belegt durch den Lauf-Link.
- **AC-4:** Given AC-2 mit erneutem 409, Then wird kein weiterer Name blind versucht; der Abschlussbericht nennt Code und Befund, und Henning entscheidet über den nächsten Schritt.

**Abnahmeweg.** Kein Pfad der Geräteliste berührt, kein App-Code; Stufe 2 im Simulator entfällt sinngemäß, der Beleg ist der CI-Lauf nach dem Merge. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] Der angepasste Test war vor der Dateiänderung rot und ist danach grün; alle `scripts/test_asc_*.py` grün.
- [ ] Der Diff berührt nur die zwei genannten Dateien.
- [ ] Lauf-Links von `untertitel` und `lesen` stehen in #837.

## Seiteneffekte

- Öffentlich sichtbarer Name im englischen App Store; ein von Apple angenommener Name lässt sich danach nicht beliebig zurücknehmen. Er wirkt erst mit der nächsten Einreichung; Build 128 / 1.0 (#788) wartet nicht darauf.
- Keine Berechtigungen, `Info.plist`, AppStorage-Schlüssel, Audio-Dateien, Secrets oder Abhängigkeiten.

## Risiken

- **Apple lehnt auch den Zusatznamen ab:** Die Deutung „vergeben“ wäre dann falsch oder der Zusatz zu schwach; AC-4 greift, kein Blindversuch.
- **Parser schneidet am zweiten Doppelpunkt:** Der Test prüft den vollständigen Wert.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Textänderung einer Referenzdatei, kippt keine ADR.

## Changelog

- 2026-11-06: Initial spec created (#837 Schnitt 3, nach Lauf 42183585381)

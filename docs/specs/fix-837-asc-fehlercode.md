---
entity_id: fix-837-asc-fehlercode
type: bugfix
created: 2026-11-06
updated: 2026-11-06
status: draft
workflow: fix-837-asc-fehlercode
---

# Spec: #837 Schreibwerkzeug nennt Apples Fehlercode

## Approval

- [ ] Approved

## Purpose

Der Lauf `asc-app-info.yml aktion=untertitel` (2026-11-06, Lauf 42170051228) scheiterte beim Anlegen von en-US mit HTTP 409 und nannte Apples Grund nicht: `send_json` liest den Rumpf der Fehlerantwort nicht, und `asc_app_info.send` ersetzt 409 zusätzlich durch einen Festtext. Ohne den Grund lässt sich nicht entscheiden, ob die englische Versions-Lokalisierung fehlt (#842) oder etwas anderes vorliegt. Henning hat „erst Ursache klären“ gewählt. Diese Spec lässt das Werkzeug den Fehlercode ausgeben; danach läuft der Untertitel erneut. Der Fehler ist keine Verschlechterung: der Weg lief nie (erster Lauf 2026-11-06). Es wird nichts in App Store Connect geschrieben, das Ergebnis ist nur eine bessere Meldung.

Ohne Modell geht es nicht: nicht relevant, Betriebsskript (JSON lesen, Muster filtern).

Recherche (vor der Analyse): Apple „App Info Localizations“ (<https://developer.apple.com/documentation/appstoreconnectapi/app-info-localizations.md>); Forum zu 409 bei Lokalisierungen, Rumpf mit `errors[].code` unterscheidet „Sprache existiert“ von zustandsbedingt (<https://developer.apple.com/forums/thread/776315>, <https://developer.apple.com/forums/thread/823257>). Ein Fallbericht zu „appInfoLocalizations POST, PREPARE_FOR_SUBMISSION“ fand sich nicht; die Ursache bleibt offen, bis der Code vorliegt.

## Source

- **File:** `scripts/asc_what_to_test.py`
- **Identifier:** `send_json(config, method, path, payload)`; neu `error_codes(error)`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `urllib.error.HTTPError.read()` | stdlib | Rumpf der Fehlerantwort |
| `scripts/asc_app_info.py` `send` | module | wandelt 403/409 in Festtexte um, ruft `send_json` |
| `asc_beta_setup.py`, `asc_beta_invite.py`, `asc_review_notes.py` | module | weitere Aufrufer von `send_json`; keiner wertet den Meldungstext aus (nur `asc_app_info` prüft auf „HTTP 403“/„HTTP 409“) |
| Apples JSON:API-Fehlerformat `{"errors":[{"code","title","detail"}]}` | extern | Quelle der Codes |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_what_to_test.py | MODIFY | `error_codes` liest höchstens 8 KB des Rumpfs, nimmt aus `errors[].code` nur Werte nach `[A-Z0-9_.]+` (höchstens 5); `send_json` hängt sie an die Fatal-Meldung |
| scripts/asc_app_info.py | MODIFY | `send`: 409-Festtext behält die Codes (403 unverändert) |
| scripts/test_asc_what_to_test.py | MODIFY | Tests für Code in Meldung, Filter, unlesbaren Rumpf |
| scripts/test_asc_app_info.py | MODIFY | Test: 409-Zweig nennt den Code, `detail` nie |

### Estimated Changes
- Files: 4 (alle geändert)
- LoC: ca. +45/−3 (Skript ca. 15, Tests ca. 30)

## Implementation Details

Die Meldung behält das Präfix `ASC answered HTTP {code} for {method} {path}`; nur bei vorhandenen Codes folgt ` (codes: A, B)`. So greifen die bestehenden `in`-Prüfungen weiter.

```python
def error_codes(error):
    """Apples Fehlercodes aus dem Rumpf; jede Störung ergibt eine leere Liste."""
    try:
        errors = json.loads(error.read(8192)).get("errors", [])
        codes = [e["code"] for e in errors if re.fullmatch(r"[A-Z0-9_.]+", str(e.get("code", "")))]
    except (ValueError, AttributeError, TypeError, KeyError, OSError):
        return []
    return codes[:5]
```

Ausgegeben wird nur `code`, nie `title` oder `detail`: beide können Nutzertext (Untertitel, Name) wiederholen. Das gilt auch für Muster-Treffer: ein Code mit Kleinbuchstaben oder Leerzeichen wird verworfen.

`asc_app_info.send` ersetzt den 409-Text weiterhin, hängt aber die Codes an (`…nicht zulässig (codes: …)`); dafür liest es sie aus der Fatal-Meldung zurück oder `send_json` reicht sie in einer Fatal-Unterklasse mit. Umsetzung wählt die kleinere Änderung; der 403-Zweig bleibt wörtlich.

**Alternativen:**
- Nur Deutsch setzen, Englisch später: kippt Hennings Freigabe „Deutsch und Englisch jetzt“; verworfen.
- Rohantwort komplett ausgeben: einfacher, aber `detail` kann Nutzertext tragen; verworfen.
- Vorab per GET die Versions-Lokalisierungen prüfen (#842): prüft eine unbelegte Vermutung; erst nach dem Code.

Keine ADR wird gekippt.

## Test Plan

### Automated Tests (TDD RED)

`unittest`, lokaler HTTP-Nachbau (`FakeASC`, `scripts/test_asc_what_to_test.py`; Fake in `scripts/test_asc_app_info.py`, dessen Fehlerrumpf `RAW_SECRET` als `detail` trägt). Aufruf `python3 scripts/test_asc_what_to_test.py` und `python3 scripts/test_asc_app_info.py`.

- [ ] `test_rejected_write_names_apple_error_code` (what_to_test): GIVEN 409 mit Rumpf `{"errors":[{"code":"ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE","detail":"geheim"}]}` THEN Ausgabe enthält `HTTP 409` und den Code, nicht `geheim`.
- [ ] `test_error_code_filter_and_limit` (what_to_test): GIVEN Rumpf mit Code `kleinwert mit leerzeichen` und sieben gültigen Codes THEN nur gültige, höchstens fünf.
- [ ] `test_unreadable_error_body_keeps_old_message` (what_to_test): GIVEN 409 mit Rumpf, der kein JSON ist, und einer mit `errors` als Zahl THEN Meldung wie bisher `ASC answered HTTP 409 for …`, ohne `codes`.
- [ ] `test_409_message_keeps_code` (app_info): GIVEN Schreibaufruf mit 409 und Code im Rumpf THEN Ausgabe enthält „Konflikt“ und den Code, nicht `RAW_SECRET`.
- [ ] `test_403_message_unchanged` (app_info): GIVEN 403 mit Code im Rumpf THEN Ausgabe enthält „gesperrt“ wie bisher, ohne Code-Anhang.

Bestehende Tests (`test_403_and_409_give_clear_message`, `test_rejected_write_fails`) bleiben unverändert grün.

## Acceptance Criteria

- **AC-1:** Given eine 4xx-Antwort mit gültigem `errors[].code`, When `send_json` scheitert, Then steht der Code in der Fatal-Meldung hinter dem unveränderten Präfix. Belegt durch `test_rejected_write_names_apple_error_code`.
- **AC-2:** Given `title`/`detail` oder Codes außerhalb `[A-Z0-9_.]+`, When die Meldung entsteht, Then erscheinen sie nie; höchstens fünf Codes. Belegt durch `test_error_code_filter_and_limit`, `test_409_message_keeps_code`.
- **AC-3:** Given ein nicht lesbarer oder fremd geformter Rumpf, When `send_json` scheitert, Then ist die Meldung wie bisher. Belegt durch `test_unreadable_error_body_keeps_old_message`.
- **AC-4:** Given 403 oder 409 an `asc_app_info.send`, Then bleibt der 403-Text unverändert und der 409-Text nennt zusätzlich den Code. Belegt durch `test_403_message_unchanged`, `test_409_message_keeps_code`.
- **AC-5:** Given der Merge auf `main`, When `asc-app-info aktion=untertitel` erneut läuft, Then nennt das Protokoll Apples Fehlercode des 409 (oder der Lauf gelingt), und der Abschlussbericht benennt daraus die Ursache (#842 oder anders). Belegt durch den Lauf-Link.

**Abnahmeweg.** Kein Pfad der Geräteliste berührt, kein App-Code; Stufe 2 im Simulator entfällt sinngemäß, der Beleg ist der CI-Lauf nach dem Merge. Wiederholter Untertitel-Lauf schreibt höchstens, was Schnitt 2 ohnehin vorsieht.

## Definition of Done

- [ ] Die neuen Tests waren vor der Umsetzung rot und sind danach grün; alle `scripts/test_asc_*.py` bleiben grün.
- [ ] Der Diff berührt nur die vier genannten Dateien.
- [ ] Der Lauf-Link und die benannte Ursache des 409 stehen in #837.

## Seiteneffekte

- Keine Schreibaufrufe, nichts an Apple verändert; keine Berechtigungen, `Info.plist`, AppStorage-Schlüssel, Audio-Dateien, Secrets oder Abhängigkeiten.
- Fehlermeldungen aller Aufrufer von `send_json` (TestFlight „Was testen“, Beta-Einladung, Review-Notizen) tragen künftig Apples Code; Schlüssel, Token und Signatur bleiben ausgeschlossen.

## Risiken

- **Rumpf nicht lesbar oder kein Code:** Meldung bleibt wie heute; dann liefert erst der nächste Schritt (GET der Versions-Lokalisierungen) den Befund.
- **Code allein reicht nicht:** Dann wird gezielt `detail` im Einzelfall geprüft, nicht standardmäßig ausgegeben.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Fehlerpfad eines Betriebsskripts, kippt keine ADR.

## Changelog

- 2026-11-06: Initial spec created (Folge von Lauf 42170051228, #837 Schnitt 3)

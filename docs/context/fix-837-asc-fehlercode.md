# Context: fix-837-asc-fehlercode

## Request Summary
#837 Schnitt 3 (Untertitel setzen): Der Lauf `asc-app-info.yml aktion=untertitel` (2026-11-06, Lauf 42170051228) scheiterte beim
Anlegen von en-US mit HTTP 409, ohne Apples Grund zu nennen. Henning wählte „erst Ursache klären“: Das Schreibwerkzeug soll
Apples Fehlercode mit ausgeben, danach läuft der Untertitel erneut.

## Befund (belegt)
- App-Info `039b3fba…` steht auf `PREPARE_FOR_SUBMISSION`, Wächter meldet `LAGE=editierbar`, macOS 1.0 `READY_FOR_SALE`.
- Der Abbruch kam vor jeder Ausgabe „untertitel gesetzt“; es wurde nichts geschrieben (de-DE weiter „Gesagt. Sortiert.“).
- Apple nennt den Grund im Rumpf (`errors[].code`, z. B. `ENTITY_ERROR.ATTRIBUTE.INVALID…`); `send_json` liest den Rumpf nicht,
  `asc_app_info.send` ersetzt 409 zusätzlich durch einen Festtext.
- Ursache des 409 ist **nicht** belegt. Vermutung (unbelegt): fehlende englische Versions-Lokalisierung (#842).

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_what_to_test.py` | `send_json` (Z. 28–46): wirft `Fatal("ASC answered HTTP {code} for {method} {path}")` ohne Rumpf |
| `scripts/asc_app_info.py` | `send` (Z. 87–96) wandelt 403/409 in Festtexte um, ruft `send_json` |
| `scripts/test_asc_what_to_test.py` | `test_rejected_write_fails` erwartet `HTTP 409` in der Ausgabe (FakeASC mit `patch_status`) |
| `scripts/test_asc_app_info.py` | Tests des Untertitel-Wegs, 409-Zweig |
| `scripts/asc_beta_setup.py`, `asc_beta_invite.py`, `asc_review_notes.py` | weitere Aufrufer von `send_json`; keiner wertet den Meldungstext aus (nur `asc_app_info` prüft auf „HTTP 409“/„HTTP 403“) |

## Existing Patterns
- Fehlermeldungen tragen nie Schlüssel, Token oder Signatur; Rohantworten werden bisher nicht ausgegeben.
- Meldungsformat `ASC answered HTTP {code} for {method} {path}` bleibt als Präfix, damit `in`-Prüfungen weiter greifen.

## Dependencies / Dependents
- Upstream: `urllib` (Rumpf des `HTTPError` lesbar), Apples JSON:API-Fehlerformat `{"errors":[{"code","title","detail"}]}`.
- Downstream: alle Aufrufer von `send_json` (oben), CI-Läufe `asc-app-info`, `asc-beta-*`, `asc-review-notes`, TestFlight „Was testen“.

## Existing Specs
- `docs/specs/tooling/feat-846-waechter-appinfo.md` (Wächter), Spec von #837 Schnitt 2.

## Risks & Considerations
- `detail`/`title` können Nutzerdaten wiederholen (Untertitel, Name): nur `code` ausgeben, nicht `detail`.
- Ausgabe des Codes darf den 403-Zweig in `asc_app_info.send` nicht verändern.
- Gemeinsame Funktion: Änderung höchstens 1 Code-Zeile je Fehlerfall plus Test, keine neuen Abhängigkeiten.
- Alternative (verworfen für jetzt): nur deutschen Untertitel setzen; würde Hennings Freigabe „Deutsch und Englisch jetzt“ kippen.

## Analysis

### Type
Bugfix (Werkzeug-Diagnose): Schreibweg verschweigt Apples Fehlergrund. Verschlechterung? Nein, der Weg lief nie (erster Lauf 2026-11-06).

### Recherche (vor der Analyse)
- Apple-Referenz „App Info Localizations“: POST legt eine Sprache an, die es noch nicht gibt.
  https://developer.apple.com/documentation/appstoreconnectapi/app-info-localizations.md
- Forum: 409 bei Lokalisierungen kommt mit `ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE`-artigen Codes (Sprache existiert) oder
  zustandsbedingt (`ENTITY_ERROR.RELATIONSHIP.INVALID`); der Rumpf (`code`, `detail`) unterscheidet das.
  https://developer.apple.com/forums/thread/776315 , https://developer.apple.com/forums/thread/823257
- Ein Fallbericht zu genau „appInfoLocalizations POST, PREPARE_FOR_SUBMISSION“ fand sich nicht. Die Ursache bleibt offen, bis der Code vorliegt.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_what_to_test.py | MODIFY | `send_json`: Rumpf des HTTPError lesen, nur `errors[].code` (Muster `[A-Z0-9_.]+`, höchstens 5) an die Meldung hängen |
| scripts/asc_app_info.py | MODIFY | `send`: 409-Festtext behält die Codes (403 unverändert) |
| scripts/test_asc_what_to_test.py | MODIFY | Test: 409 mit Fehlerrumpf → Code in Meldung, `detail` nie; unlesbarer Rumpf → Meldung wie bisher |
| scripts/test_asc_app_info.py | MODIFY | Test: 409-Zweig nennt den Code |

### Scope Assessment
- Files: 4, Estimated LoC: +45/-3 (davon ~30 Tests), Risk Level: LOW (nur Fehlerpfad, Präfix `ASC answered HTTP {code} for …` bleibt)

### Technical Approach
Regeln, kein Modell. `error.read()` (begrenzt auf 8 KB), `json.loads`, Codes filtern; jede Störung → leere Liste, Meldung wie heute.
Ausgegeben wird nur `code`, nie `title`/`detail` (können Untertitel oder Namen wiederholen). Alle Aufrufer von `send_json` profitieren.
Danach Untertitel-Lauf erneut (`asc-app-info aktion=untertitel`), der Code sagt, ob es #842 (englische Versions-Lokalisierung) oder etwas anderes ist.

### Alternativen
- Nur Deutsch setzen, Englisch später: kippt Hennings Freigabe „Deutsch und Englisch jetzt“; verworfen.
- Rohantwort komplett ausgeben: einfacher, aber `detail` kann Nutzertext tragen; verworfen.
- Vorab GET der Versions-Lokalisierungen zur Prüfung von #842: prüft eine unbelegte Vermutung; erst nach dem Code.
Kein ADR wird gekippt.

### Dependencies
`urllib`, Apples JSON:API-Fehlerformat; Aufrufer: asc_beta_setup, asc_beta_invite, asc_review_notes, asc_app_info, TestFlight „Was testen“.

### Open Questions
- Keine für Henning. Die Ursache des 409 klärt der nächste Lauf.

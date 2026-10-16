---
entity_id: feat-268-schema-schranke
type: feature
created: 2026-10-15
updated: 2026-10-15
status: draft
workflow: feat-268-schema-schranke
---

# Spec: #268 — Schutzschranke: TestFlight hält an, wenn Production das Modell nicht kennt

## Approval

- [ ] Approved

## Purpose

TestFlight-Bauten sprechen mit der CloudKit-Umgebung Production. Production ist ab dem ersten Deploy nur noch
additiv und legt kein Schema von selbst an. Vergisst jemand nach einer Modelländerung den Deploy in der CloudKit
Console, läuft der TestFlight-Bau trotzdem durch, und der Abgleich scheitert still, sobald das neue Feld zum ersten
Mal einen Wert hat. Heute hängt der Schutz nur an der Doku. Diese Spec fügt dem TestFlight-Ablauf einen Prüfschritt
vor dem Archivieren hinzu: Er liest das Schema von Production (`cktool export-schema`), vergleicht es mit der
Schema-Datei im Repo und hält den Lauf an, wenn ein Typ oder Feld der Datei in Production fehlt. Teile 1 und 2 des
Tickets (Schema-Datei, Test „Modell = Abbild") liefert #448 und stehen im offenen PR #450; diese Spec ist Teil 3
samt Doku. Es ändert sich kein Produktcode und nichts Sichtbares in der App.

Rechenweg ohne Modell: Der Vergleich ist ein Mengenvergleich zweier Textdateien (Typnamen, Feldnamen). Ein
Sprachmodell kommt nicht vor.

**ADR-Nr.:** keine — reine CI-Schranke, keine Architekturentscheidung; die Alternative „Production gegen Development vergleichen" wurde verworfen (Development ist lückenhaft) und kippt keinen ADR.

## Source

- **File:** `.github/workflows/testflight.yml`
- **Identifier:** Job `upload` (iOS, ab Zeile 34), Kopf `needs` fehlt; Jobkette `upload` → `upload-mac` → `confirm-mac`, `confirm`
- **File:** `.github/workflows/cloudkit-schema.yml`
- **Identifier:** Schritt „Store the management token" und „Export" (`xcrun cktool save-token --type management`, `export-schema … --environment production`); Vorbild, nicht geändert
- **File:** `cloudkit/schema.ckdb` (Soll-Datei, kommt mit PR #450)
- **Identifier:** Blöcke `RECORD TYPE CD_<Klasse> ( CD_<feld> TYP …, "___…", GRANT … );`
- **File:** `scripts/test_cloudkit_schema.py` (kommt mit PR #450)
- **Identifier:** `record_fields()` — Regex-Parser derselben Syntax; Muster für den neuen Parser
- **File:** `docs/reference/testflight.md`
- **Identifier:** Abschnitt „5a. CloudKit-Schema vor jedem Build mit Modelländerung (#175)" und „Wenn es hakt"
- **File:** `CLAUDE.md`
- **Identifier:** Absatz „CloudKit schema before every TestFlight build that changes the model (#175)"

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| PR #450 (`cloudkit/schema.ckdb`, `scripts/test_cloudkit_schema.py`) | issue | Liefert die Soll-Datei auf `main`. Umsetzung beginnt, wenn #450 gemergt ist. Fehlt die Datei trotzdem, bricht die Schranke mit eigener Meldung ab |
| Secret `CLOUDKIT_MANAGEMENT_TOKEN` | tooling | Lesezugriff auf das Schema; gesetzt am 2026-10-15, gültig ein Jahr |
| `xcrun cktool` (Xcode 27 auf Image `xcode-27`) | tooling | `save-token`, `export-schema --environment production` |
| Composite-Action `./.github/actions/select-xcode-27` | tooling | Wählt Xcode 27.0 wie in den anderen Jobs |
| #448 / PR #449 | issue | Export/Import-Workflow, bereits auf `main` |
| #175 | issue | Ursprung der Regel „Schema vor TestFlight-Bau"; Doku 5a |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/check_cloudkit_production.py` | CREATE | Parser für beide `.ckdb`-Dateien und Mengenvergleich Abbild ⊆ Production; Exit 0 (alles da), 1 (Typ/Feld fehlt), 2 (Datei fehlt, leer oder ohne Typen) |
| `scripts/test_check_cloudkit_production.py` | CREATE | Unit-Tests des Skripts (Python `unittest`, von `ci.yml` per `discover` gefunden) |
| `.github/workflows/testflight.yml` | MODIFY | Neuer Job `schema-check` vor `upload`; `upload` bekommt `needs: schema-check` (`upload-mac` hängt über `upload` mit) |
| `docs/reference/testflight.md` | MODIFY | 5a und „Wenn es hakt": Schranke, drei Meldungen, kein Notausgang, Weg nach einem Halt |
| `CLAUDE.md` | MODIFY | Absatz „CloudKit schema before every TestFlight build …" nennt die Schranke |

### Estimated Changes

- Files: 5
- LoC: ca. +140/-2 (Skript ~55, Test ~55, Workflow ~30, Doku ~15)
- Kein Produktcode. Keine neuen Abhängigkeiten, keine neuen Berechtigungen, keine AppStorage-Schlüssel, keine Audiodateien, keine Änderung an `project.yml`, Entitlements oder Info.plist.
- Kein Pfad der Geräteliste berührt.

## Acceptance Criteria

- **AC-1:** Das Skript `check_cloudkit_production.py <abbild> <production>` beendet sich mit 0, wenn jeder Typ und jedes Feld des Abbilds auch in Production steht. Zusätzliche Typen und Felder in Production ändern daran nichts.
- **AC-2:** Fehlt in Production ein Feld des Abbilds, beendet sich das Skript mit 1 und nennt es als `CD_<Typ>.CD_<feld>` in der Meldung.
- **AC-3:** Fehlt in Production ein ganzer Typ des Abbilds, beendet sich das Skript mit 1 und nennt den Typ (`record type CD_<Typ>`).
- **AC-4:** Verglichen werden nur Typnamen und Feldnamen. Systemfelder (`"___…"`), `GRANT`-Zeilen, Index-Flags (`QUERYABLE`, `SEARCHABLE`, `SORTABLE`) und die Typangabe (`STRING`, `BYTES` …) beeinflussen das Ergebnis nicht: Dasselbe Feld mit anderen Flags oder anderem Typ in Production ist kein Fund.
- **AC-5:** Ist eine der beiden Dateien nicht vorhanden, leer oder ohne `RECORD TYPE`, beendet sich das Skript mit 2 und einer Meldung, die sich von der Meldung für „Feld fehlt" unterscheidet. Ein nicht prüfbarer Stand ist kein grüner Stand.
- **AC-6:** In `testflight.yml` läuft der Job `schema-check` auf `xcode-27` mit gewähltem Xcode 27.0, speichert den Management-Token, exportiert Production (`--environment production`) und ruft das Skript mit `cloudkit/schema.ckdb` auf. `upload` hat `needs: schema-check`. Läuft der Job nicht grün, wird weder iOS noch Mac archiviert noch hochgeladen. Der Job läuft bei Start von Hand und bei `v*`-Tag.
- **AC-7:** Fehlt das Secret `CLOUDKIT_MANAGEMENT_TOKEN`, hält der Job mit einer eigenen `::error::`-Meldung an. Scheitert `cktool` (Netz, Token abgelaufen, Berechtigung), hält er mit einer zweiten eigenen Meldung an. Beide unterscheiden sich voneinander und von „Feld fehlt".
- **AC-8:** Es gibt keinen Weg am Prüfschritt vorbei: kein Eingabefeld, keine Umgebungsvariable und keinen Schalter, der ihn auslässt.
- **AC-9:** Die Meldung bei „Feld fehlt" nennt die fehlenden Typen und Felder und verweist auf `docs/reference/testflight.md` 5a (Weg: Abbild im selben PR ergänzen, nach dem Merge importiert die CI nach Development, Deploy in der CloudKit Console, dann Lauf wiederholen).
- **AC-10:** Beleg im Lauf-Protokoll: Ein TestFlight-Lauf von einem Wegwerf-Zweig, dessen Abbild absichtlich ein Feld mehr hat als Production, hält in `schema-check` mit der Meldung aus AC-9 an; `upload` wird übersprungen. Es entsteht dabei kein TestFlight-Build.
- **AC-11:** Das Skript, gegen einen echten Production-Export (Artefakt von Lauf 38754886284, `exported-production.ckdb`) und das Abbild von `main` gelesen, liefert das erwartete Ergebnis: Exit 0, wenn das Abbild darin enthalten ist, sonst genau die Differenz.
- **AC-12:** Die Unit-Tests wurden vor dem Skript rot gesehen (Skript fehlt) und sind danach grün; `python -m unittest discover -s scripts -p 'test_*.py'` findet und führt sie aus.
- **AC-13:** `docs/reference/testflight.md` (5a und „Wenn es hakt") und der CLAUDE.md-Absatz zu „CloudKit schema before every TestFlight build" nennen die Schranke und ihre drei Meldungen.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — reine CI-Schranke. Verworfene Alternative: Production gegen Development vergleichen (Development ist lückenhaft). Kippt keine frühere Entscheidung.

## Test Plan

| Test | Datei | Prüft |
|------|-------|-------|
| `test_equal_schemas_pass` | `scripts/test_check_cloudkit_production.py` | AC-1: Exit 0 bei Gleichstand |
| `test_extra_fields_and_types_in_production_pass` | dto. | AC-1: Mehr in Production hält nie an |
| `test_missing_field_is_reported` | dto. | AC-2: Exit 1, Meldung `CD_<Typ>.CD_<feld>` |
| `test_missing_record_type_is_reported` | dto. | AC-3: Exit 1, Meldung `record type CD_<Typ>` |
| `test_flags_types_grants_and_system_fields_are_ignored` | dto. | AC-4: andere Flags/Typangabe sind kein Fund |
| `test_unreadable_input_is_exit_2` (fehlende Datei, leere Datei, Datei ohne `RECORD TYPE`) | dto. | AC-5: Exit 2, andere Meldung als bei „Feld fehlt" |
| `test_message_points_to_documentation` | dto. | AC-9: Meldung verweist auf `docs/reference/testflight.md` |
| Skript gegen Export von Lauf 38754886284 | Lauf, von Hand | AC-11 |
| TestFlight-Lauf vom Wegwerf-Zweig mit zusätzlichem Feld | Lauf-Protokoll | AC-6, AC-7 (Verdrahtung), AC-10 |
| `test_upload_waits_for_schema_check`, `test_no_input_skips_schema_check` (lesen `.github/workflows/testflight.yml` als Text: `needs: schema-check` am Job `upload`, kein `workflow_dispatch`-Eingabefeld und kein `if:` am Job `schema-check`) | `scripts/test_check_cloudkit_production.py` | AC-6, AC-8 |

Die Meldungen für „Secret fehlt" und „cktool scheitert" (AC-7) sind Shell im Workflow und nicht unit-testbar; der cktool-Fall wird im Probelauf einmal mit absichtlich falscher `--container-id` auf dem Wegwerf-Zweig ausgelöst. Der Secret-Fall lässt sich im Repo nicht erzeugen, ohne das echte Secret zu löschen; seine Meldung wird nur gelesen (Review), nicht ausgelöst.

## Definition of Done

- [ ] PR #450 ist auf `main`; `cloudkit/schema.ckdb` liegt dort (Voraussetzung)
- [ ] Unit-Tests rot ohne Skript, danach grün (AC-1 bis AC-5, AC-8, AC-12)
- [ ] `schema-check` in `testflight.yml`, `upload` davon abhängig, ohne Umgehung (AC-6, AC-7, AC-8)
- [ ] Lauf-Protokoll: Halt gegen absichtlich zusätzliches Feld, kein Upload (AC-10)
- [ ] Skript gegen echten Production-Export geprüft (AC-11)
- [ ] Doku und CLAUDE.md aktualisiert (AC-9, AC-13)
- [ ] Kein Produktcode geändert; Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt."

## Implementation Details

### Skript

`parse(text)` liest `RECORD TYPE (\w+) \((.*?)\);` (DOTALL) und gibt `{Typ: {Feld, …}}` zurück. Je Zeile im Block zählt das erste Wort, ohne Anführungszeichen; Zeilen, die mit `GRANT` beginnen, und Namen, die mit `___` beginnen, entfallen. `missing(soll, ist)` liefert die sortierte Liste der Funde (`record type X` bzw. `X.feld`). `main(argv)` liest beide Dateien, gibt Exit 2 bei Lesefehler/leerem Inhalt/ohne Typen, 1 mit Meldung bei Funden, sonst 0.

### Workflow

```yaml
schema-check:
  name: Production knows the CloudKit schema
  runs-on: xcode-27
  timeout-minutes: 15
  steps:
    - uses: actions/checkout@v7
    - uses: ./.github/actions/select-xcode-27
    - name: Store the management token   # Secret fehlt -> eigene Meldung
    - name: Export Production            # cktool scheitert -> eigene Meldung
    - name: Compare with cloudkit/schema.ckdb   # python3 scripts/check_cloudkit_production.py
upload:
  needs: schema-check
```

### Vergleichsrichtung und Grenzen

- Nur Abbild ⊆ Production. Tote Felder in Production (Production ist additiv) halten nie an.
- Nur Namen: Ein Typwechsel ist in Production nicht deploybar; der Deploy selbst lehnt ihn ab.
- Die Schranke prüft nicht, ob das Abbild vollständig ist; das sichert der Test „Modell = Abbild" aus #450.
- Der Deploy-Knopf in der Console bleibt bei Henning (Apple erlaubt Production per `cktool` nicht).

## Expected Behavior

- **Input:** TestFlight-Lauf (von Hand oder `v*`-Tag).
- **Output:** Fehlt Production etwas aus dem Abbild: Lauf rot in `schema-check`, kein Archiv, kein Upload, Meldung mit Liste. Sonst läuft `upload` wie bisher.
- **Side effects:** keine; der Job liest Production nur. Der Token wird im Schlüsselbund des flüchtigen Runners gespeichert.

## Known Limitations

- Nach einer Modelländerung hält der nächste TestFlight-Lauf an, bis Henning in der Console deployt hat. Das ist beabsichtigt.
- Läuft der Token ab (ein Jahr, ab 2026-10-15), hält jeder Lauf mit der cktool-Meldung an, bis ein neuer Token als Secret liegt.
- Indizes und Feldtypen in Production werden nicht verglichen (siehe oben).

## Changelog

- 2026-10-15: Initial spec für #268 (Teil 3 und Doku; Teile 1 und 2 über #448/PR #450)

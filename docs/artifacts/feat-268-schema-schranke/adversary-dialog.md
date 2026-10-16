# Adversary Dialog — feat-268-schema-schranke
Spec: docs/specs/tooling/feat-268-schema-schranke.md
Datum: 2026-10-16 06:55

## Checkliste
- [x] **Input:** TestFlight-Lauf (von Hand oder `v*`-Tag). Beide Trigger in `on:`; `schema-check` hat kein `if:`.
- [x] **Output:** Fehlt Production etwas: `schema-check` rot, `upload`/`upload-mac`/`confirm`/`confirm-mac` skipped (Lauf 38851565829 per `gh run view` nachgeprüft).
- [x] **Side effects:** keine; Job liest nur (`export-schema`), Token nur im Runner-Schlüsselbund.
- [x] **AC-1:** Exit 0 bei Teilmenge, Extras in Production egal. Test `test_equal_schemas_pass`, `test_extra_fields_and_types_in_production_pass`; echter Export: Exit 0.
- [x] **AC-2:** Feld fehlt -> Exit 1, `CD_Typ.CD_feld`. Eigenes Gegenbeispiel: Production ohne `CD_createdAt` -> Exit 1, nennt `CD_Revision.CD_createdAt, CD_TaskAttachment.CD_createdAt`.
- [x] **AC-3:** Typ fehlt -> Exit 1 `record type X` (Test + eigener Fall `cd_a` statt `CD_A`).
- [x] **AC-4:** Nur Namen. Anderer Typ/Flags/GRANT/`___`-Felder ohne Wirkung (Test; Production nur Systemfelder -> Feld wird korrekt als fehlend gemeldet).
- [x] **AC-5:** Fehlende/leere/typlose Datei -> Exit 2 mit anderer Meldung; ebenso falsche Argumentzahl (0 oder 3 Argumente -> Exit 2).
- [x] **AC-6:** `schema-check` auf `xcode-27`, `select-xcode-27`, Token speichern, `--environment production`, Skript mit `cloudkit/schema.ckdb`; `upload` `needs: schema-check`, `upload-mac` `needs: upload`, `confirm` `needs: upload`, `confirm-mac` `needs: upload-mac`; beide Trigger.
- [x] **AC-7:** Zwei eigene `::error::`-Meldungen in der Shell (Secret leer / `cktool` Exit != 0); unterscheiden sich von "Feld fehlt". Nur gelesen, nicht ausgelöst (siehe Findings F002, F003).
- [x] **AC-8:** Kein Eingabefeld/Schalter/`if:` (Test `test_no_input_skips_schema_check`, `on:` selbst gelesen).
- [x] **AC-9:** Meldung nennt Liste, verweist auf `docs/reference/testflight.md` 5a und den Weg (im echten Lauf-Log Zeile 9-11 belegt).
- [x] **AC-10:** `gh run view 38851565829`: Zweig `probe/268-schranke`, `workflow_dispatch`, `schema-check` failure (Schritt Compare), `upload`, `upload-mac`, `confirm`, `confirm-mac` skipped; Log nennt `CD_TaskItem.CD_probe268`.
- [x] **AC-11:** Skript gegen `prod/exported-production.ckdb` und `cloudkit/schema.ckdb`: Exit 0 (9 Typen). Negativfall selbst: ohne `CD_createdAt` -> Exit 1 mit genau den zwei Differenzen.
- [x] **AC-12:** `test-red-output.txt` zeigt FailedTest (Skript fehlt); selber Lauf jetzt: 10 Tests OK. Vollständiger `discover -p 'test_*.py'` wegen fehlendem PyYAML lokal nicht gelaufen (nur eigenes Modul).
- [x] **AC-13:** `docs/reference/testflight.md` 5a (drei Meldungen) und "Wenn es hakt", CLAUDE.md-Absatz nennt Schranke und die Meldungsarten.

## Dialog

### Runde 1
**Adversary:** Skript und Tests gelesen und ausgeführt. Code reference: scripts/check_cloudkit_production.py:14 (Regex), :22-28 (Zeilenparser), :36-41 (Vergleich), :60-79 (main). Code reference: scripts/test_check_cloudkit_production.py:131 (Wiring-Tests), :104 (Exit-2-Fälle). Code reference: .github/workflows/testflight.yml:36 (Job), :67 (`needs`), :362 und :520/:543 (Kette).
Eigene Gegenbeispiele gegen das Skript (Eingabe -> Ausgabe):
- Feldname klein/groß (`CD_X` statt `CD_x`) -> Exit 1 (case-sensitiv, korrekt für CloudKit).
- `"CD_x"` in Anführungszeichen vs. unquoted -> Exit 0 (strip).
- CRLF in Abbild oder Production -> Exit 0.
- Production nur Systemfelder -> Exit 1, nennt `CD_A.CD_x`.
- Typname anders in Production -> Exit 1 `record type CD_A`.
- Zusätzliche Argumente (`a b c`) / keine Argumente -> Exit 2.
- Tab zwischen `RECORD TYPE` und Name, `CD_A(` ohne Leerzeichen, letzter Block ohne `;` -> Exit 2 (fail-safe, auch auf Production-Seite).
- Kommentarzeile `// c` im Abbild-Block -> Exit 1 mit Fund `CD_A.//` (Fehlalarm, F001).
- Zwei Felder in einer Zeile (`CD_x STRING, CD_y STRING,`) im Abbild -> `CD_y` wird nie geprüft, Exit 0 (F004).
- Zwei Blöcke gleichen Typnamens: der spätere überschreibt den früheren (`types[name] = fields`, Zeile 29) -> Felder des ersten Blocks bleiben ungeprüft bzw. in Production Fehlalarm (F005).
- Semikolon innerhalb eines Anführungszeichen-Strings in GRANT -> Exit 0 (kein Problem hier, weil Regex nicht greedy bis `);` nur bei `);`).
Wiring: `upload` hängt an `schema-check`; `upload-mac` an `upload`; `confirm`/`confirm-mac` ohne `if:` -> bei übersprungenem `upload` ebenfalls skipped (im echten Lauf belegt). v*-Tag: kein `if:` am Job, läuft also auch dort.
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Beweise nachgeprüft statt geglaubt. `gh run view 38851565829 --json jobs`: Zweig probe/268-schranke, Event workflow_dispatch, Conclusion failure; Job schema-check failure (nur Schritt "Compare" rot, d.h. Token-Schritt und cktool-Export liefen real grün), alle vier Folgejobs skipped. Probe-Log Zeile 9-11 enthält die Meldung mit Feld und Weg-Text. AC-7 cktool-Fehlerpfad wurde NICHT ausgelöst (Spec-Testplan wollte falsche `--container-id` im Probelauf; im Beleg nur der Vergleichsfall) -> F002. Save-token-Schritt hat bei Fehlschlag von `xcrun cktool save-token` keine eigene Meldung (nur Secret-leer) -> F003. Doku 5a, "Wenn es hakt" und CLAUDE.md-Zeilen (git diff --cached) gegen AC-13 gelesen: Schranke, drei Fälle, kein Notausgang, Weg nach Halt stehen drin. Reale Dateien (`cloudkit/schema.ckdb`, Export) enthalten keine Kommentare, keine Mehrfachfelder pro Zeile und keine doppelten Typen, daher sind F001/F004/F005 theoretisch. Keine Regression: `upload`-Jobs unverändert bis auf `needs`.
**Implementierer:** (nicht beteiligt)

### Runde 3
**Adversary:** Nachprüfung der Fixes. Code reference: scripts/check_cloudkit_production.py:18 (`field_names`: Kommentar und Kommas), :34-42 (`parse` vereinigt gleichnamige Blöcke). Code reference: scripts/test_check_cloudkit_production.py:131 (jetzt 14 Tests, eigener Lauf: 14 OK, 0 übersprungen). Code reference: .github/workflows/testflight.yml:57 (Export-Schritt).
Meine Gegenbeispiele erneut gegen das neue Skript: Kommentarzeile im Abbild -> Exit 0 (F001 behoben); `CD_x STRING, CD_y STRING,` -> Exit 1 `CD_A.CD_y` (F004 behoben); doppelter Typblock in Production/Abbild -> vereinigt, Exit 0 (F005 behoben). Alle übrigen Fälle aus Runde 1 unverändert (Case, Quotes, CRLF, Systemfelder-only -> 1, Exit 2 bei typlosen Dateien/Argumenten, Semikolon im GRANT-String -> 0). Regression echte Dateien: `cloudkit/schema.ckdb` gegen `prod/exported-production.ckdb` -> Exit 0, 9 Typen.
F002: `gh run view 38852133191`: Zweig probe/268-cktool, workflow_dispatch, failure; Schritt "Export Production" failure, "Compare" skipped, upload/upload-mac/confirm/confirm-mac skipped; Log enthält `##[error]Production-Schema nicht lesbar ...` (cktool: authorization-failed). Damit ist die zweite Meldung real ausgelöst.
F003: Ein ungültiges Token scheitert nicht in `save-token` (speichert nur), sondern erst im Export und löst dort die eigene Meldung aus (durch F002-Lauf mit abgelehnter Autorisierung gestützt). `save-token` kann nur an der Schlüsselbund-Ablage scheitern; der Job wird dann rot, kein Upload. Kein Defekt, Beobachtung.
**Implementierer:** F001/F004/F005 und F002 bearbeitet (laut Koordinator).

## Findings
Finding:
  ID: F001
  Severity: LOW (BEHOBEN in Runde 3)
  Category: edge_case
  Code reference: scripts/check_cloudkit_production.py:26
  Description: Erstes Wort jeder Blockzeile gilt als Feldname, auch `//`-Kommentare.
  Spec requirement: AC-4 — nur Typ- und Feldnamen zählen
  Conflict: Kommentarzeile im Abbild -> Exit 1, Fund `CD_A.//`. Fehlalarm in Sicherheitsrichtung (hält an, übergeht nichts); reale Dateien enthalten keine Kommentare.
  Remediation: Zeilen mit `//` oder `--` überspringen.

Finding:
  ID: F002
  Severity: MEDIUM (BEHOBEN in Runde 3, Lauf 38852133191)
  Category: spec_violation
  Code reference: .github/workflows/testflight.yml:57
  Description: cktool-Fehlerpfad (Meldung "Production-Schema nicht lesbar") nie ausgelöst; Probelauf zeigte nur den Vergleichsfall.
  Spec requirement: AC-7 / Testplan — "cktool-Fall wird im Probelauf mit falscher --container-id ausgelöst"
  Conflict: Beleg fehlt, Meldung nur gelesen. Code ist einfach (`if ! cktool ...; then ::error:: exit 1`) und korrekt gelesen.
  Remediation: Probelauf mit falscher `--container-id` nachholen oder Abweichung in der Spec vermerken.

Finding:
  ID: F003
  Severity: LOW (Beobachtung, kein Defekt)
  Category: edge_case
  Code reference: .github/workflows/testflight.yml:54
  Description: Schlägt `xcrun cktool save-token` selbst fehl (Secret gesetzt, aber ungültig), zeigt der Schritt nur cktools eigene Meldung ohne `::error::`-Text der Schranke; Job wird dennoch rot, kein Upload.
  Spec requirement: AC-7
  Conflict: Schranke hält korrekt an, nur Meldung nicht eigen.
  Remediation: save-token in `if !`-Block mit der cktool-Meldung wrappen.

Finding:
  ID: F004
  Severity: LOW (BEHOBEN in Runde 3)
  Category: edge_case
  Code reference: scripts/check_cloudkit_production.py:23
  Description: Mehrere Felder in einer Zeile werden nicht aufgetrennt (nur erstes Wort).
  Spec requirement: AC-2
  Conflict: `CD_x STRING, CD_y STRING,` -> `CD_y` nie geprüft (Exit 0). Echte Exporte schreiben ein Feld pro Zeile.
  Remediation: Zeile an `,` trennen oder im Test festhalten.

Finding:
  ID: F005
  Severity: LOW (BEHOBEN in Runde 3)
  Category: edge_case
  Code reference: scripts/check_cloudkit_production.py:29
  Description: Doppelter Typname überschreibt statt zu vereinigen.
  Spec requirement: AC-1/AC-2
  Conflict: Zweiter Block gleichen Namens verwirft Felder des ersten. Echte Dateien haben keine Duplikate.
  Remediation: `types.setdefault(name, set()).update(fields)`.

## Confirmations
Confirmation:
  AC: AC-12
  Code reference: scripts/test_check_cloudkit_production.py:131
  Evidence: 10 Tests grün, Wiring-Tests lesen testflight.yml; Exit-2-Fälle Zeile 104.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: .github/workflows/testflight.yml:67
  Evidence: upload needs schema-check; upload-mac (Z.362) needs upload; kein if: am Job.
  Status: CONFIRMED

Confirmation:
  AC: AC-1
  Code reference: scripts/check_cloudkit_production.py:36
  Evidence: nur Abbild-Menge gegen Production geprüft; Extras ohne Wirkung.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: VERIFIED

Alle 13 ACs belegt. F001, F002, F004, F005 behoben und nachgeprüft; F003 ist Beobachtung (Job rot, kein Upload). Tests: 14 passed, 0 failed, 0 übersprungen (nur eigenes Modul; voller discover lokal ohne PyYAML nicht gelaufen). Nur gelesen, nicht ausgelöst: die Meldung "Secret CLOUDKIT_MANAGEMENT_TOKEN fehlt" (laut Spec nicht auslösbar), ein echter v*-Tag-Lauf (aus fehlendem `if:` geschlossen), der volle discover mit den Fremdmodulen.

## Geprüfte Dateien

- sha256:b5b498c156dfb383892acaa47717194e134a72d08dbbe48277efabf46bacc785  .github/workflows/testflight.yml
- sha256:d36b80be4b6b395eca430f5c9457728abf8b3a24011f7b83bd5aa9ffdfadf35d  scripts/check_cloudkit_production.py
- sha256:561ab92a48b6c60d22196c3b171abee3c8a9ec0382231b27d9602b012373912c  scripts/test_check_cloudkit_production.py

## Prüfbasis

- base: 683483f28ed2fa38dc7bd3e03f656c7917f1c8b2
- blob:d1cd61cd1809d0496cf6c810c10cb8ea2c664917  .github/workflows/testflight.yml
- blob:edc054afb46c73544d960f5f63fc34b76e6ef714  scripts/check_cloudkit_production.py
- blob:b229e176b7131d83110f734928a65ebf4d78fdd6  scripts/test_check_cloudkit_production.py

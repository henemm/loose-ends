---
entity_id: feat-183-testflight-beleg
type: feature
created: 2026-10-03
updated: 2026-10-03
status: draft
workflow: feature-183-testflight-beleg
---

# Spec: #183 — TestFlight-Lauf belegt Annahme bei Apple und Archiv-Tabelle im Protokoll

## Approval

- [ ] Approved

## Purpose

Der TestFlight-Lauf 37119618643 (#174) ist grün und endet mit „Upload succeeded“. Das sagt nur, dass
das Paket bei Apple angekommen ist, nicht, dass es verarbeitet wurde. Die Nachweistabelle des
Archivs steht außerdem nur in `$GITHUB_STEP_SUMMARY`, das die GitHub-REST-API nicht herausgibt. Beides
ließ sich in #174 nicht maschinell zitieren (AC-5, AC-7). Ohne belegten, verarbeiteten Build kann
#175 (Messung auf Hennings iPhone) und damit #176 nicht beginnen. Diese Spec lässt jeden
TestFlight-Lauf selbst belegen, was im Archiv stand (Tabelle im Protokoll) und dass App Store
Connect den Build mit der Lauf-Nummer kennt und `processingState` meldet (ASC-API, eigener Job,
Lauf rot bei `INVALID`, `FAILED` oder Zeitüberschreitung). Es ändert sich nichts an der App.

## Source

- **File:** `.github/workflows/testflight.yml`
- **Identifier:** Schritt „Verify the archive is built against the iOS 27 SDK“ (`SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"`, drei `>> "$SUMMARY"`-Stellen); Schritt „Upload to TestFlight“ (Ende des Jobs `upload`); Schritt „Remove the key“ (letzter Schritt)
- **File:** `docs/reference/testflight.md`
- **Identifier:** Abschnitt „5. Build starten“ (Punkt 2 „Grün heißt: hochgeladen.“), „Wenn es hakt“, „Was der Workflow tut“
- **File:** `scripts/sim_proof.py`, `scripts/test_sim_proof.py`
- **Identifier:** Vorbild für „stdlib-only Skript + Pythontest“ (nur gelesen)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| App-Store-Connect-API (`GET /v1/apps`, `GET /v1/builds`) | tooling | Liefert App-ID und `processingState` des Builds |
| Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` | tooling | Schlüssel für das Token; Admin-Schlüssel, Lesen von Builds genügt auch App Manager |
| `python3` (nur Standardbibliothek) und `openssl` | tooling | Auf `ubuntu-latest` und auf dem Mac vorhanden; kein `jwt`-Paket, kein `pip install` |
| #174 | issue | Vorgänger; liefert den Nachweisschritt und den Upload-Job |
| #175, #176 | issue | Nachgelagert; brauchen einen belegt verarbeiteten Build |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_wait_build.py` | CREATE | Wartet per ASC-API auf den Build mit `version` = Lauf-Nummer und protokolliert `processingState` |
| `scripts/test_asc_wait_build.py` | CREATE | Tests gegen lokalen Fake-Server und selbst erzeugten EC-Schlüssel |
| `.github/workflows/testflight.yml` | MODIFY | Nachweistabelle zusätzlich auf stdout; neuer Job `confirm` (`needs: upload`); Job `upload` sonst unverändert |
| `docs/reference/testflight.md` | MODIFY | Schritt 5, „Wenn es hakt“, „Was der Workflow tut“ |

### Estimated Changes

- Files: 4
- LoC: ca. +250 (Skript ~90, Test ~110, Workflow ~30, Doku ~20); am Limit. Bei Überschreitung: Tabelle im Protokoll bleibt, Test auf Kernfälle kürzen, nicht aufteilen.
- Kein Produktcode. Keine neuen Abhängigkeiten, keine neuen Berechtigungen, keine AppStorage-Schlüssel, keine Audiodateien, keine Änderung an `project.yml`, Entitlements oder Info.plist, keine neuen Secrets.
- Kein Pfad der Geräteliste berührt (`.github/`, `scripts/`, `docs/`).

## Definition of Done

- [ ] Ein Lauf zeigt im Protokoll die Tabelle mit vier Zeilen „OK“ (AC-1, AC-8)
- [ ] Derselbe Lauf protokolliert Build-Nummer und `processingState=VALID` aus der ASC-API (AC-3, AC-4, AC-8)
- [ ] `docs/reference/testflight.md` beschreibt den neuen Schritt (AC-7)
- [ ] Lokale Skripttests grün, Fehlerfälle rot gesehen (AC-5, AC-6)
- [ ] Upload-Job bleibt unverändert grün; rot wird nur der neue Job (AC-2)

## Implementation Details

### Änderung 1 — `scripts/asc_wait_build.py`

Aufruf: `asc_wait_build.py <build-nummer>`; Konfiguration über Umgebung: `ASC_KEY_ID`,
`ASC_ISSUER_ID`, `ASC_KEY_FILE` (Pfad zur `.p8`), `ASC_BUNDLE_ID` (Vorgabe `com.henning.looseends`),
`ASC_API_BASE` (Vorgabe `https://api.appstoreconnect.apple.com`, überschreibbar für Tests),
`ASC_POLL_SECONDS` (Vorgabe 30) und `ASC_TIMEOUT_SECONDS` (Vorgabe 2700 = 45 min), beide nur für
Tests verkürzbar. Nur Standardbibliothek (`urllib`, `json`, `base64`, `subprocess`, `time`).

- **Token (ES256):** Header `{"alg":"ES256","kid":<Key-ID>,"typ":"JWT"}`, Payload `iss`, `iat`,
  `exp` = `iat` + 600 s, `aud` = `appstoreconnect-v1`. Signatur über
  `openssl dgst -sha256 -sign <p8>` (Eingabe über stdin); `openssl` liefert DER, Python wandelt DER
  nach `r‖s` (je 32 Byte) um, base64url ohne Auffüllung. **Neues Token je Abfragerunde.**
- **App-ID:** einmal `GET /v1/apps?filter[bundleId]=<Bundle-ID>`; kein Treffer = Exit 1 mit
  klarer Meldung.
- **Polling:** `GET /v1/builds?filter[app]=<id>&filter[version]=<Nummer>` alle 30 s.
  Die Antwort wird nicht auf Vertrauen genommen: ein Datensatz zählt nur, wenn sein
  `attributes.version` genau der Build-Nummer entspricht (offene Frage zu `filter[version]`, siehe
  unten). Leere Liste oder Datensatz mit anderer `version` = „noch nicht da“, weiterwarten.
- **Zustände:** `VALID` = Exit 0. `PROCESSING` = weiterwarten. `FAILED` und `INVALID` = Exit 1 mit
  `::error::`-Zeile. Obergrenze erreicht = Exit 1 mit `::error::` („Build N not VALID after 45 min,
  last state: …“). HTTP-Fehler bei einer Runde (5xx, Zeitüberschreitung des Netzes) zählen als
  „noch nicht“ und werden protokolliert; 401/403 brechen sofort mit Exit 1 ab (Schlüssel oder Rolle
  falsch, Warten hilft nicht).
- **Ausgabe je Runde und am Ende** (eine Zeile, abrufbar im Protokoll):
  `build=<n> processingState=<…> uploadedDate=<…>`; bei noch nicht gelistetem Build
  `build=<n> processingState=nicht-gelistet`.
- **Geheimnisse:** Schlüsselinhalt, Token und Signatur werden nie ausgegeben, auch nicht in
  Fehlermeldungen oder bei Ausnahmen (Fehlertexte nennen Statuscode und Pfad der URL, nicht
  Header).

### Änderung 2 — `scripts/test_asc_wait_build.py`

`unittest` (wie `test_sim_proof.py`), lokaler `http.server` im Thread als Fake-ASC auf Port 0,
`ASC_API_BASE` zeigt darauf, `ASC_POLL_SECONDS=0.05`. Ein EC-Schlüssel (`prime256v1`) wird je Lauf
mit `openssl ecparam -genkey` und `openssl pkcs8 -topk8 -nocrypt` erzeugt. Der Fake-Server prüft den
`Authorization: Bearer`-Header: Header `alg`/`kid`/`typ`, Payload `iss`/`aud`/`exp`-Spanne, und
verifiziert die Signatur (r‖s zurück nach DER) mit `openssl dgst -sha256 -verify <öffentlicher Schlüssel>`;
ungültig = 401. Fälle:

1. `VALID` sofort: Exit 0, Ausgabezeile mit `processingState=VALID`.
2. `PROCESSING` ×2, dann `VALID`: Exit 0, drei Runden, drei verschiedene Token.
3. `INVALID`: Exit 1.
4. `FAILED`: Exit 1.
5. Dauerhaft `PROCESSING`, `ASC_TIMEOUT_SECONDS=1`: Exit 1, Meldung nennt Zeitüberschreitung.
6. Leere Antwort ×2, dann Treffer `VALID`: Exit 0.
7. Antwort enthält einen Datensatz mit falscher `version`: wird ignoriert (Exit 1 nach Zeitüberschreitung, nie `VALID` für die falsche Nummer).
8. Der Schlüsselinhalt (Base64-Rumpf der `.p8`) und das Token kommen in Standardausgabe und Fehlerausgabe nirgends vor (in Fall 1 und 3 geprüft).

### Änderung 3 — `.github/workflows/testflight.yml`

**a) Tabelle zusätzlich ins Protokoll.** Im Schritt „Verify the archive …“ schreiben die drei Stellen
mit `>> "$SUMMARY"` künftig in Zusammenfassung und stdout. Dazu `SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"`
und eine kleine Funktion `row() { printf '%s\n' "$1" | tee -a "$SUMMARY"; }` (lokal ohne
`GITHUB_STEP_SUMMARY` genau eine Ausgabe statt zwei). Die Prüflogik bleibt unverändert; die Tabelle
steht damit im Schritt-Protokoll und ist per `gh run view <id> --log` abrufbar.

**b) Neuer Job `confirm`:**

```yaml
  confirm:
    name: Confirm Apple processed the build
    needs: upload
    runs-on: ubuntu-latest
    timeout-minutes: 50
    env:
      ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
      ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
    steps:
      - uses: actions/checkout@v7
      - name: Wait until App Store Connect reports the build as VALID
        env:
          BUILD: ${{ github.run_number }}
        run: |
          trap 'rm -f "$RUNNER_TEMP/asc_key.p8"' EXIT
          umask 077
          printf '%s\n' "${{ secrets.ASC_PRIVATE_KEY }}" > "$RUNNER_TEMP/asc_key.p8"
          ASC_KEY_FILE="$RUNNER_TEMP/asc_key.p8" python3 scripts/asc_wait_build.py "$BUILD"
```

`needs: upload` setzt voraus, dass der Upload gelang; schlägt er fehl, läuft `confirm` nicht (kein
Warten auf einen Build, der nie hochgeladen wurde). Der Job läuft auf `ubuntu-latest`: Die 10 bis
30 Minuten Wartezeit verbrauchen keine macOS-Minuten, der Job `upload` bleibt grün, wenn der Upload
gelang, und der Lauf als Ganzes wird bei `INVALID`, `FAILED` oder Zeitüberschreitung trotzdem rot.
`timeout-minutes: 50` liegt über der Obergrenze von 45 min plus Start. Die Schlüsseldatei liegt nur
während des Schritts im Temp-Verzeichnis des Runners (Rechte 600) und wird per `trap` auch bei
Abbruch gelöscht; sie wird nie ausgegeben und nicht als Artefakt hochgeladen. Der Job `upload`
(Schritte, Reihenfolge, „Remove the key“) bleibt, abgesehen von a), unverändert. Die
`concurrency`-Gruppe `testflight` gilt für den ganzen Lauf und bleibt.

### Änderung 4 — `docs/reference/testflight.md`

- **5. Build starten:** Punkt 2 „Grün heißt: hochgeladen.“ ersetzen: Der Job „Archive and upload
  (iOS)“ grün heißt nur hochgeladen. Der zweite Job „Confirm Apple processed the build“ wartet bis
  zu 45 Minuten und ist grün erst, wenn App Store Connect den Build als `VALID` meldet; sein
  Protokoll nennt `build=<Nummer> processingState=… uploadedDate=…`. Lauf-Dauer entsprechend
  nachziehen (15 Minuten bis Upload, bis etwa 45 Minuten bis zur Bestätigung). Punkt 3 (Build
  erscheint in TestFlight) bleibt als Kontrolle in der Oberfläche.
- **Wenn es hakt:** Einträge „Job ‚Confirm …‘ rot: `INVALID`/`FAILED`“ (Grund steht in der Mail von
  Apple und in App Store Connect unter dem Build; Upload-Job war trotzdem grün), „Zeitüberschreitung“
  (Verarbeitung dauerte über 45 Minuten: in App Store Connect nachsehen, Job erneut starten ist
  nicht nötig, der Build kommt ggf. später an), „401/403“ (Schlüssel oder Rolle). Der Eintrag
  „Nachweisschritt rot“ nennt zusätzlich: Tabelle steht im Protokoll des Schritts, nicht nur in der
  Zusammenfassung.
- **Was der Workflow tut:** Absatz zum Job `confirm` (Skript `scripts/asc_wait_build.py`, ASC-API,
  45 min, Ausgabezeile) und zur Tabelle im Protokoll. Lokal ist die Abfrage nicht möglich (Schlüssel
  nur in den CI-Secrets); lokal laufen nur die Tests `python3 scripts/test_asc_wait_build.py`.

### Vorgehen: Reproduktion zuerst

1. **RED vorher (Lücke zeigen):** Aus dem Protokoll von Lauf 37119618643 belegen, dass dort weder
   die Tabelle (`gh run view 37119618643 --log | grep "Ergebnis"` ohne Treffer) noch ein
   `processingState` steht; Upload-Schritt endet nur mit „Upload succeeded“.
2. **Tests zuerst (TDD RED):** `test_asc_wait_build.py` vor dem Skript schreiben; alle Fälle rot (Skript fehlt).
3. **Skript, Tests GREEN.**
4. **Workflow und Doku;** YAML parsebar, Schrittblöcke mit `bash -n`, Tabelle lokal gegen das
   Fixture aus #174 einmal ausgeführt (genau eine Ausgabe der Zeilen, Exit-Code unverändert).
5. **Echter Lauf nach Freigabe:** `workflow_dispatch` vom PR-Zweig (kostet eine Build-Nummer und
   lädt einen Build zur internen Gruppe „Familie“ hoch); Tabelle und Ausgabezeile aus dem Protokoll
   (`gh run view <id> --log`) zitieren.

### Alternativen

- **A (gewählt): ASC-Polling auf `builds`/`processingState` im eigenen Job.** Erfüllt die DoD wörtlich, rührt den Upload-Job nicht an.
- **B: Schritt im bestehenden Job `upload`.** Einfacher, aber 10 bis 30 Minuten teure macOS-Laufzeit, und der Upload-Job würde rot, obwohl der Upload gelang.
- **C: `buildUploads`-Status (`BuildUploadState`).** Früheres Signal, aber für `xcodebuild -exportArchive`-Uploads nicht belegt; erst messen, nicht annehmen.
- **D: Bestätigung per Apple-Mail oder Webhook (`BUILD_UPLOAD_STATE_UPDATED`).** Mail ist nicht abrufbar (Befund aus #174), Webhook bräuchte einen öffentlichen Endpunkt.
- **E: Ganz ohne Warten, „Upload succeeded“ genügt.** Trägt #175 nicht, weil die Messung einen verarbeiteten Build braucht.
- **Regelweg vor Modell:** Nicht zutreffend, reine Protokoll- und HTTP-Aufgabe ohne Sprachverstehen.
- **Gekippt würde:** keine ADR, nur die Annahme aus #174 „grün heißt hochgeladen“.

### Nicht belegt und offen

- **`filter[version]` bei `GET /v1/builds`:** Die Apple-Seite „List builds“ nennt den Parameter nicht
  im Text; belegt ist er nur über Beispiele anderer Entwickler. Praktisch bestätigt erst der echte
  Lauf. Absicherung im Skript: Es prüft `attributes.version` jedes Datensatzes selbst und nimmt nie
  einen Treffer mit falscher Nummer. Ignoriert die API den Filter, liefert sie mehrere Builds, und
  das Skript findet den richtigen oder wartet bis zur Zeitüberschreitung (rot, nie falsch grün).
- Wie lange der Build nach „Upload succeeded“ bis zum Erscheinen in der Liste braucht (Forum: Minuten,
  teils Stunden); die Obergrenze von 45 Minuten ist eine Schätzung aus der Doku (10 bis 30 Minuten).
- Der Nachweis von AC-3 und AC-8 ist nur durch einen echten TestFlight-Lauf möglich, der eine
  Build-Nummer kostet. Freigabe dafür liegt in der Freigabe dieser Spec.

### Recherche (Quellen)

- Token: https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests (ES256, `iss`, `iat`, `exp` höchstens 20 min, `aud=appstoreconnect-v1`)
- Builds: `GET /v1/builds`, Status `PROCESSING | FAILED | INVALID | VALID`; Parameter über Beispiele anderer Entwickler (Suche 2026-10-03)
- Analyse: `docs/context/feature-183-testflight-beleg.md`

## Test Plan

Kein Produktcode. Die Logik steckt im Skript und wird mit Pythontests gegen einen Fake-Server
belegt; Workflow und Doku mit Syntaxprüfung und einem echten Lauf.

### Automated Tests (TDD RED)

- [ ] Test 1 (RED, Lücke): GIVEN Lauf 37119618643 WHEN sein Protokoll nach „Ergebnis“-Tabelle und `processingState` durchsucht wird THEN gibt es keinen Treffer.
- [ ] Test 2: GIVEN Fake-Server liefert sofort `VALID` WHEN das Skript läuft THEN Exit 0 und Zeile `build=<n> processingState=VALID uploadedDate=…`.
- [ ] Test 3: GIVEN `PROCESSING` ×2 dann `VALID` WHEN das Skript läuft THEN Exit 0, drei Anfragen mit drei verschiedenen Token.
- [ ] Test 4: GIVEN `INVALID` bzw. `FAILED` WHEN das Skript läuft THEN je Exit 1 mit `::error::`-Zeile.
- [ ] Test 5: GIVEN dauerhaft `PROCESSING` und `ASC_TIMEOUT_SECONDS=1` WHEN das Skript läuft THEN Exit 1 mit Meldung zur Zeitüberschreitung.
- [ ] Test 6: GIVEN leere Antwort ×2 dann Treffer WHEN das Skript läuft THEN Exit 0.
- [ ] Test 7: GIVEN Antwort mit falscher `attributes.version` WHEN das Skript läuft THEN kein `VALID` für die falsche Nummer (Exit 1 nach Zeitüberschreitung).
- [ ] Test 8: GIVEN Fake-Server prüft das Token WHEN das Skript läuft THEN verifiziert `openssl dgst -verify` die Signatur (r‖s zurück nach DER), Claims `iss`/`aud`/`exp` stimmen; falsche Signatur ergibt 401 und Exit 1.
- [ ] Test 9: GIVEN Lauf mit Schlüssel und Token WHEN Standardausgabe und Fehlerausgabe geprüft werden THEN enthalten sie weder Schlüsselrumpf noch Token.
- [ ] Test 10: GIVEN der geänderte `testflight.yml` WHEN als YAML geparst und die Schrittblöcke mit `bash -n` geprüft werden THEN kein Fehler; Job `confirm` hat `needs: upload`, `runs-on: ubuntu-latest`, `timeout-minutes` ≥ 50; im Job `upload` fehlt kein bisheriger Schritt.
- [ ] Test 11 (echter Lauf): GIVEN `workflow_dispatch` vom PR-Zweig WHEN der Lauf endet THEN `gh run view <id> --log` zeigt vier Tabellenzeilen „OK“ und die Zeile `build=<run_number> processingState=VALID uploadedDate=…`.

## Acceptance Criteria

- [ ] AC-1 Tabelle im Protokoll: Im Schritt-Protokoll des Nachweisschritts stehen Kopf und Zeilen der Tabelle (zusätzlich zur Zusammenfassung); lokal erscheint jede Zeile genau einmal.
- [ ] AC-2 Upload bleibt grün: Der Job `upload` ist bis auf die Ausgabe der Tabelle unverändert; `confirm` hat `needs: upload` und läuft auf `ubuntu-latest`. Bei `INVALID`, `FAILED` oder Zeitüberschreitung wird nur `confirm` rot (Lauf insgesamt rot), nicht `upload`.
- [ ] AC-3 Annahme belegt: `scripts/asc_wait_build.py` ermittelt die App-ID aus der Bundle-ID, wartet auf den Build mit `version` = Lauf-Nummer, prüft `attributes.version` selbst und gibt `build=<n> processingState=<…> uploadedDate=<…>` aus; Exit 0 nur bei `VALID`.
- [ ] AC-4 Fehlerfälle: Exit ≠ 0 bei `FAILED`, `INVALID`, Zeitüberschreitung (45 min), App nicht gefunden und 401/403; leere Antwort bedeutet weiterwarten; Intervall 30 s, neues Token je Runde.
- [ ] AC-5 Lokale Tests grün: `python3 scripts/test_asc_wait_build.py` läuft grün mit den Fällen 2 bis 9 des Test Plans; Signatur gegen `openssl dgst -verify` geprüft; Fehlerfälle jeweils einmal rot gesehen (Skript vor Implementierung fehlend, dann gezielt falsch).
- [ ] AC-6 Geheimnisse: Schlüssel, Token und Signatur erscheinen nirgends in Ausgabe oder Artefakten; im Workflow liegt die Schlüsseldatei nur in `$RUNNER_TEMP` und wird per `trap` gelöscht.
- [ ] AC-7 Doku: `docs/reference/testflight.md` beschreibt in Schritt 5 („Grün heißt: hochgeladen“ ersetzt), „Wenn es hakt“ und „Was der Workflow tut“ den Job `confirm`, die Tabelle im Protokoll und die Fehlerbilder.
- [ ] AC-8 Echter Lauf: Ein `workflow_dispatch`-Lauf vom PR-Zweig ist grün; aus `gh run view <id> --log` sind die Tabelle mit vier Zeilen „OK“ und die Zeile `build=<run_number> processingState=VALID` im Bericht zitiert. Die Build-Nummer (`github.run_number`) liegt über 10, der Nummer des Laufs 37119618643.
- [ ] AC-9 Offene Frage geklärt: Aus dem echten Lauf ist im Bericht festgehalten, ob `filter[version]` serverseitig greift (eine oder mehrere Treffer in der Antwort).
- [ ] AC-10 Geräteliste: Kein Pfad der Geräteliste berührt. Keine sichtbare UI-Änderung, daher keine Entwurfsvorschau. Kein Produktcode geändert: Das Diff berührt genau die vier genannten Dateien (plus Workflow-Artefakte unter `docs/`).
- [ ] AC-11 Ausliefern: Nach dem Merge ist `bash ~/.claude/scripts/loose-ends-sync-main.sh` gelaufen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Ergänzung der Build-Auslieferung um einen Beleg-Job ohne Architekturwirkung; keine bestehende Entscheidung wird gekippt, nur die Annahme aus #174 „grün heißt hochgeladen“.
- **Rationale:** Ein Skript gegen die ASC-API ist einfacher und belastbarer als Mail oder Zusage; stdlib plus `openssl` vermeidet eine Abhängigkeit, die auf dem Mac fehlt und lokal nicht testbar wäre. Der eigene Job hält teure macOS-Minuten frei und den Upload-Job aussagekräftig grün.

## Changelog

- 2026-10-03: Initial spec created (Analyse in `docs/context/feature-183-testflight-beleg.md`).

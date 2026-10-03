---
entity_id: fix-191-testflight-zertifikat
type: bug
created: 2026-10-03
updated: 2026-10-03
status: draft
workflow: fix-191-testflight-zertifikat
---

# Spec: #191 — TestFlight-Lauf verbraucht kein Signier-Zertifikat mehr dauerhaft

## Approval

- [ ] Approved

## Purpose

Jeder TestFlight-Lauf startet auf einem leeren Runner. Der Schritt „Archive“ findet mit
`-allowProvisioningUpdates` und ASC-Schlüssel keine Signier-Identität, legt ein Apple-Development-
Zertifikat „Created via API“ an, und der private Schlüssel geht mit dem Runner verloren. Das Zertifikat
bleibt im Konto. Lauf #10 (37119618643) lief damit grün; Lauf #12 (37128541497) brach nach 21 s im Schritt
Archive ab: „Choose a certificate to revoke. Your account has reached the maximum number of
certificates.“, danach „No profiles for 'com.henning.looseends…' were found“, `** ARCHIVE FAILED **`
(Exit 65). Das Konto steht jetzt am Limit, jeder weitere Lauf scheitert, und #183 (echter Lauf mit
Belegtabelle) wartet darauf. Diese Spec lässt den Lauf die Zertifikate, die er selbst anlegt, per
App-Store-Connect-API wieder widerrufen: einmal vor dem Archiv (heilt das jetzt volle Konto) und einmal
am Ende, auch bei Fehlern. Die Auswahl ist eng (nur Entwicklungs-Zertifikate mit Anzeigename „Created
via API“), der erste echte Einsatz ist ein Probelauf ohne Widerruf. Es ändert sich nichts an der App.

## Source

- **File:** `.github/workflows/testflight.yml`
- **Identifier:** Schritt „Archive“ (`-allowProvisioningUpdates`, `CODE_SIGN_STYLE=Automatic`), Schritt „Store the App Store Connect API key“, Schritt „Upload to TestFlight“ (`-exportArchive`), Schritt „Remove the key“; Trigger `workflow_dispatch`
- **File:** `docs/reference/testflight.md`
- **Identifier:** Abschnitte „Wenn es hakt“, „Was der Workflow tut“, „3. API-Schlüssel für GitHub“ (Rolle Admin)
- **File:** `scripts/asc_wait_build.py`, `scripts/test_asc_wait_build.py`
- **Identifier:** `make_token`, `der_to_rs`, `Fatal`; Testhelfer `make_key`, `openssl`, `b64d`, `rs_to_der` und Fake-Server-Muster (nur gelesen, wiederverwendet)
- **File:** `docs/context/fix-191-testflight-zertifikat.md`
- **Identifier:** Belege, Recherche, Analyse (Grundlage dieser Spec)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| App-Store-Connect-API (`GET /v1/certificates`, `DELETE /v1/certificates/{id}`) | tooling | Zertifikate listen und widerrufen |
| Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` | tooling | Token; Rolle Admin (vorhanden, nötig auch fürs Widerrufen) |
| `python3` (nur Standardbibliothek) und `openssl` | tooling | Auf dem macOS-Runner und lokal vorhanden; kein `pip install` |
| `scripts/asc_wait_build.py` | code | `make_token`, `Fatal` werden importiert, nicht kopiert |
| #183 | issue | Nachgelagert, wartet auf diesen Fix |
| #156 | issue | Gerätebauten (Kennung `com.henning.looseends.probe`) signieren lokal mit gespeicherten Profilen und sind nicht betroffen |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_cleanup_certs.py` | CREATE | Zertifikate per ASC-API listen, enge Auswahl widerrufen, `--dry-run`, Zahl vorher/nachher |
| `scripts/test_asc_cleanup_certs.py` | CREATE | Tests gegen lokalen Fake-Server und selbst erzeugten EC-Schlüssel; Workflow-Struktur |
| `.github/workflows/testflight.yml` | MODIFY | Schritt vor „Archive“, `always()`-Schritt nach dem Export, Eingabe `cleanup_dry_run` |
| `docs/reference/testflight.md` | MODIFY | „Wenn es hakt“, „Was der Workflow tut“ |

### Estimated Changes

- Files: 4
- LoC: ca. +250 (Skript ~90, Test ~100, Workflow ~35, Doku ~25); am Limit. Der Test importiert die Hilfen aus `test_asc_wait_build.py` statt sie zu kopieren. Bei Überschreitung: Testfälle bündeln, nicht aufteilen.
- Kein Produktcode. Keine neuen Abhängigkeiten, keine neuen Secrets, keine neuen Berechtigungen, keine AppStorage-Schlüssel, keine Audiodateien, keine Änderung an `project.yml`, Entitlements oder Info.plist.
- Kein Pfad der Geräteliste berührt (`.github/`, `scripts/`, `docs/`). Keine sichtbare UI-Änderung, daher keine Entwurfsvorschau.
- Risiko MEDIUM: Ein Widerruf im Konto ist nicht umkehrbar. Gegenmittel: enge Auswahl, Probelauf zuerst, Widerruf nie von Hand.

## Definition of Done

- [ ] Zwei `workflow_dispatch`-Läufe hintereinander sind grün, ohne dass im Konto von Hand aufgeräumt wurde (AC-14)
- [ ] Die Zertifikatszahl wächst durch einen Lauf nicht; vorher und nachher stehen im Protokoll und sind zitiert (AC-4, AC-14)
- [ ] `docs/reference/testflight.md` beschreibt den Weg (AC-10)
- [ ] Lokale Skripttests grün, Fehlerfälle rot gesehen (AC-1 bis AC-7, AC-11)
- [ ] Der Probelauf hat die Auswahl an echten Konto-Daten bestätigt oder widerlegt (AC-13)

## Implementation Details

### Änderung 1 — `scripts/asc_cleanup_certs.py`

Aufruf: `asc_cleanup_certs.py [--dry-run]`. Konfiguration über Umgebung wie bei `asc_wait_build.py`:
`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_FILE`, `ASC_API_BASE` (Vorgabe `https://api.appstoreconnect.apple.com`,
für Tests überschreibbar). Nur Standardbibliothek und `openssl`; `make_token` und `Fatal` kommen per
`from asc_wait_build import …`. Neues Token je Anfrage. Kein Warten und keine Wiederholung bei 5xx
(der Lauf wird dann rot, ein erneuter Lauf räumt nach).

- **Listen:** `GET /v1/certificates?limit=200`. Liefert die Antwort `links.next`, wird diese URL
  gelesen, solange sie mit `ASC_API_BASE` beginnt; zeigt sie auf einen anderen Host, bricht das Skript
  mit `Fatal` ab, bevor ein Token dorthin geschickt wird.
- **Auswahlregel (eng, ohne Ausnahme):** Ein Zertifikat wird nur dann zum Widerruf gewählt, wenn
  `attributes.certificateType` genau `DEVELOPMENT` oder `IOS_DEVELOPMENT` ist **und** der Anzeigename
  genau `Apple Development: Created via API` lautet (verglichen wird `attributes.name`, ersatzweise `attributes.displayName`;
  getrimmt, Groß-/Kleinschreibung relevant). Fehlen Typ oder Name, wird nicht gewählt. Distribution,
  andere Namen, andere Typen und Zertifikate von Hennings eigenem Xcode (sein Name) bleiben unberührt.
- **Ausgabe der Liste (immer, auch ohne `--dry-run`):** je Zertifikat eine Zeile
  `typ=<…> name=<…> ablauf=<…> id=<erste 6 Zeichen>… aktion=widerruf|bleibt`, dazu einmal die
  Attributschlüssel des ersten Datensatzes (`felder=<…>`), damit die tatsächlichen Feldnamen im
  Protokoll stehen.
- **Widerruf:** `DELETE /v1/certificates/{id}` je gewähltem Zertifikat; mit `--dry-run` kein einziger
  DELETE. Schlägt ein Widerruf fehl (z. B. 409), macht das Skript mit den übrigen weiter, gibt je
  Fehler `::error::` mit Statuscode und gekürzter ID aus und endet am Schluss mit Exit 1; der Lauf
  erscheint nie lautlos grün.
- **Zählung:** Zertifikate gesamt vor dem Widerruf, nach dem Widerruf erneut gelistet. Eine Zeile
  `zertifikate vorher=<n> nachher=<m> widerrufen=<k>`; mit `--dry-run`:
  `zertifikate vorher=<n> nachher=<n> widerrufen=0 wuerde-widerrufen=<k>`. Ist `GITHUB_STEP_SUMMARY`
  gesetzt, wird dieselbe Zeile dort angehängt.
- **Fehlerfälle:** 401/403 beim Listen: Exit 1 mit Hinweis auf Schlüssel und Rolle, bevor irgendein
  DELETE gesendet wurde. Fehlende Umgebung oder Schlüsseldatei: Exit 1.
- **Geheimnisse:** Schlüsselinhalt, Token und Signatur werden nie ausgegeben, auch nicht in Fehlern;
  Fehlertexte nennen Statuscode und Pfad der URL, keine Header. Zertifikatsinhalt
  (`certificateContent`) wird nie ausgegeben.

### Änderung 2 — `scripts/test_asc_cleanup_certs.py`

`unittest`, lokaler `http.server` im Thread als Fake-ASC auf Port 0, `ASC_API_BASE` zeigt darauf.
Schlüssel und Token-Prüfung (Signatur über `openssl dgst -verify`) wie in `test_asc_wait_build.py`
(Helfer von dort importiert). Der Fake-Server liefert eine einstellbare Zertifikatsliste (auch über
mehrere Seiten per `links.next`), zählt jeden DELETE mit ID und kann je Zertifikat einen Status
(204, 409) antworten; nach einem DELETE verschwindet das Zertifikat aus der Liste. Fälle:

1. Gemischte Liste (Entwicklung „Created via API“ ×2, Distribution „Created via API“, Entwicklung mit anderem Namen, anderer Typ mit anderem Namen, Eintrag ohne Namensfeld): genau die zwei gewählten werden gelöscht, DELETE-Zähler = 2 mit den richtigen IDs.
2. Je ein Fall allein für Distribution, anderen Namen, anderen Typ, fehlendes Namensfeld: DELETE-Zähler = 0.
3. Beide Typwerte `DEVELOPMENT` und `IOS_DEVELOPMENT` werden gewählt.
4. `--dry-run`: DELETE-Zähler = 0, Ausgabe nennt die Zeilen mit `aktion=widerruf`/`bleibt` und `wuerde-widerrufen=<k>`, Exit 0.
5. Zählung: Ausgabezeile `zertifikate vorher=<n> nachher=<m> widerrufen=<k>` stimmt mit der Fake-Liste überein; `GITHUB_STEP_SUMMARY` (Temp-Datei) enthält dieselbe Zeile.
6. Paginierung: Seite 1 mit `links.next` auf Seite 2; ein wählbares Zertifikat steht nur auf Seite 2 und wird gelöscht. Zeigt `links.next` auf einen fremden Host: Exit 1, dort kommt keine Anfrage an.
7. 401 und 403 beim Listen: Exit 1, DELETE-Zähler = 0, Meldung nennt den Statuscode.
8. 409 beim Widerruf eines von zwei Zertifikaten: das andere wird trotzdem gelöscht, Exit 1, `::error::` in der Ausgabe.
9. Token: Fake-Server verifiziert Header (`alg`/`kid`/`typ`), Claims (`iss`/`aud`/`exp`) und Signatur; falsche Signatur ergibt 401 und Exit 1.
10. Schlüsselrumpf (Base64 der `.p8`) und Token kommen in Standard- und Fehlerausgabe nirgends vor (im Erfolgs- und im 401-Fall geprüft).
11. Workflow: `testflight.yml` ist als YAML parsebar, alle `run`-Blöcke bestehen `bash -n`; Reihenfolge im Job `upload`: Schritt „Store the App Store Connect API key“ < Aufräum-Schritt < „Archive“ < „Upload to TestFlight“ < Aufräum-Schritt am Ende < „Remove the key“; der Nachschritt trägt `if: always()`; die bisherigen Schritte (Namen aus dem Stand vor der Änderung) fehlen nicht; `workflow_dispatch` hat die boolesche Eingabe `cleanup_dry_run`; der Job `confirm` bleibt unverändert.

Die Tests nehmen nur die Felder an, die das Skript selbst prüft (`certificateType`, `name`/`displayName`).
Wie Apple sie im Konto tatsächlich füllt, zeigt erst der Probelauf (siehe „Nicht belegt und offen“).

### Änderung 3 — `.github/workflows/testflight.yml`

**a) Eingabe.** `workflow_dispatch:` bekommt `inputs: cleanup_dry_run` (boolean, Vorgabe `false`,
Beschreibung: „Zertifikate nur auflisten, nichts widerrufen“). Bei Tag-Läufen ist die Eingabe leer, es
wird scharf geräumt. Beide Schritte lesen sie über `env: DRY: ${{ inputs.cleanup_dry_run == true && '--dry-run' || '' }}`.

**b) Schritt vor „Archive“** (nach „Store the App Store Connect API key“):

```yaml
      - name: Clear leftover development certificates
        env:
          DRY: ${{ inputs.cleanup_dry_run == true && '--dry-run' || '' }}
        run: |
          ASC_KEY_FILE="$HOME/private_keys/AuthKey_${ASC_KEY_ID}.p8" python3 scripts/asc_cleanup_certs.py $DRY
```

Er räumt, was frühere Läufe hinterlassen haben, und heilt damit das jetzt volle Konto. Zahl vorher und
nachher stehen im Protokoll und in der Zusammenfassung.

**c) Schritt am Ende** (nach „Upload logs“, vor „Remove the key“), `if: always()`:

```yaml
      - name: Clear the development certificates of this run
        if: always()
        env:
          DRY: ${{ inputs.cleanup_dry_run == true && '--dry-run' || '' }}
        run: |
          KEY="$HOME/private_keys/AuthKey_${ASC_KEY_ID}.p8"
          [ -f "$KEY" ] || { echo "No API key stored, nothing to clear"; exit 0; }
          ASC_KEY_FILE="$KEY" python3 scripts/asc_cleanup_certs.py $DRY
```

Er widerruft, was dieser Lauf angelegt hat, auch wenn Archiv, Nachweis oder Export fehlschlugen. Die
`concurrency`-Gruppe `testflight` serialisiert die Läufe; ein Nachschritt kann so kein Zertifikat eines
gleichzeitig laufenden Laufs treffen. Der Schritt steht vor „Remove the key“, weil er den Schlüssel
braucht. Die Liste im Protokoll dieses Schritts zeigt zugleich, welche Zertifikate Archiv **und Export**
hinterlassen haben (Messung der offenen Frage zum Export). Der Job `confirm` und alle bisherigen
Schritte bleiben unverändert.

### Änderung 4 — `docs/reference/testflight.md`

- **Wenn es hakt:** Eintrag „`Your account has reached the maximum number of certificates` / `Choose a
  certificate to revoke`“: Ursache (jeder Lauf legt auf dem leeren Runner ein Entwicklungs-Zertifikat
  „Created via API“ an), dass der Workflow sie jetzt selbst widerruft, und was bei Rot zu tun ist (Schritt
  „Clear …“ lesen: `aktion=widerruf`/`bleibt`, Fehler `::error::`; den Lauf einfach neu starten, der
  Vorschritt räumt nach; nie von Hand im Entwicklerportal widerrufen). Eintrag „Schritt ‚Clear …‘ rot mit
  HTTP 401/403“: Schlüssel oder Rolle (Admin nötig).
- **Was der Workflow tut:** Absatz zu den zwei Aufräum-Schritten, zur Auswahlregel (nur Entwicklung,
  Name „Created via API“; Distribution und Hennings eigene Zertifikate bleiben), zur Zeile
  `zertifikate vorher=… nachher=… widerrufen=…`, zum Schalter `cleanup_dry_run` (Run workflow →
  Haken „Zertifikate nur auflisten“) und dazu, dass Gerätebauten (#156) davon nicht berührt sind. Lokal
  laufen nur die Tests `python3 scripts/test_asc_cleanup_certs.py` (der Schlüssel liegt nur in den Secrets).
- Der Satz in „Was am Ende passiert“ bleibt; der Abschnitt „Notweg: lokaler Archiv-Lauf“ bekommt den
  Hinweis, dass auch dieser Weg ein „Created via API“-Zertifikat anlegt, das der nächste CI-Lauf räumt.

### Vorgehen: Reproduktion zuerst

1. **RED vorher (Fehlerzustand zeigen):** Der Zustand „Konto am Limit“ besteht. Aus dem Protokoll von
   Lauf 37128541497 (`gh run view 37128541497 --log | grep -E "Choose a certificate to revoke|ARCHIVE FAILED"`)
   die Meldung und `ARCHIVE FAILED` (Exit 65) im Schritt „Archive“ zitieren.
2. **Tests zuerst (TDD RED):** `test_asc_cleanup_certs.py` vor dem Skript schreiben; alle Fälle rot
   (Skript fehlt, Workflow-Schritte fehlen).
3. **Skript, dann Workflow und Doku, Tests GREEN.** YAML parsebar, Schrittblöcke mit `bash -n`.
4. **Probelauf (echt, nichts wird widerrufen):** `workflow_dispatch` vom PR-Zweig mit
   `cleanup_dry_run=true`. Bei vollem Konto scheitert der Schritt „Archive“ in diesem Lauf noch; das ist
   erwartet. Gebraucht wird die Liste aus dem Protokoll beider Aufräum-Schritte (`gh run view <id> --log`).
   Daran beurteilt Claude (technische Entscheidung, nicht Henning), ob „Entwicklung + Created via API“
   die richtigen Zertifikate trennt. Trennt sie sauber: weiter mit Schritt 5. Trennt sie nicht (Hennings
   eigene Zertifikate tragen denselben Namen, oder Feld/Wert weichen ab): Stopp, kein scharfer Lauf,
   Rückfall auf Alternative A (eigene Spec).
5. **Zwei scharfe Läufe hintereinander** (`workflow_dispatch` vom PR-Zweig, `cleanup_dry_run=false`; kostet
   zwei Build-Nummern und lädt zwei Builds zu TestFlight hoch). Zitiert werden aus dem Protokoll je Lauf
   die Zeilen `zertifikate vorher=… nachher=… widerrufen=…` des Vor- und des Nachschritts.
   Belegt ist die Behebung, wenn beide Läufe grün sind und die Zahl am Ende von Lauf 1, am Anfang von
   Lauf 2 und am Ende von Lauf 2 gleich ist.

### Alternativen

- **Gewählt: Aufräumen per ASC-API (vor dem Archiv und am Ende), Regelweg.** Behebt das volle Konto
  sofort und verhindert Wachstum, ohne neues Geheimnis.
- **A: Dauerhaftes Entwicklungs-Zertifikat samt Schlüssel als p12-Secret**, im Lauf in einen eigenen
  Schlüsselbund importiert; es wird nie widerrufen, kein Fehlgriff möglich. Kosten: zwei neue Secrets,
  Ablauf nach einem Jahr (Pflege), manuelle Profile. Ich könnte das Zertifikat selbst per ASC-API
  erzeugen und per `gh secret set` ablegen, Henning müsste nichts tippen. **Auslösekriterium:** Zeigt der
  Probelauf, dass „Created via API“ + Entwicklungstyp nicht sauber von Hennings eigenen Zertifikaten
  trennt, wird A die Empfehlung, und diese Spec wird für den Rückfall neu geschrieben, bevor etwas
  widerrufen wird.
- **B: Unsignierter Archiv-Schritt (`CODE_SIGNING_ALLOWED=NO`).** Widerlegt: Entitlements (App Groups
  in vier Zielen) werden beim Archivieren in die Binärdatei geschrieben, unsigniert fehlen sie
  (Apple-Forum 671800, ITMS-90078).
- **C: fastlane match.** Neue Abhängigkeit, braucht Freigabe, für ein Zertifikat unverhältnismäßig.
- **D: Nur am Ende aufräumen, kein Schritt davor.** Einfacher, heilt aber das jetzt volle Konto nicht:
  der erste Lauf scheitert weiter im Archiv, bevor der Nachschritt etwas ändern könnte (er läuft dann
  zwar mit `always()`, aber ein einmaliges Handaufräumen im Konto bliebe nötig, was die DoD ausschließt).
- **Regelweg vor Modell:** Reine API- und Regelaufgabe (Typ und Name vergleichen, löschen), kein
  Sprachverstehen, kein Modell. Der Regelweg ist hier die Empfehlung, nicht eine Alternative.
- **Gekippt würde:** keine ADR. Nur die Annahme, `-allowProvisioningUpdates` räume hinter sich auf.
  „TestFlight ruht bis andere testen“ (CLAUDE.md) bleibt; das Gerüst wird nur dauerhaft lauffähig.

### Nicht belegt und offen

- **Trennschärfe von „Created via API“:** Ob dieser Anzeigename in Hennings Konto Hennings eigene
  Entwicklungs-Zertifikate ausschließt, ist nicht belegt. Der Probelauf (Vorgehen 4) entscheidet; ohne
  sauberes Ergebnis kein scharfer Lauf.
- **ASC-API-Felder:** Wie Zertifikate in `GET /v1/certificates` heißen (`certificateType` und seine
  Werte `DEVELOPMENT`/`IOS_DEVELOPMENT`, `name` oder `displayName`, ob ein Filter nach Typ existiert)
  konnte nicht belegt werden. Das Skript behauptet nichts darüber hinaus: Es filtert selbst, prüft nur
  `certificateType` und `name`/`displayName`, und der Probelauf zeigt die tatsächlichen Felder
  (`felder=<…>`) und Werte im Protokoll. Die Tests nehmen nur diese im Skript geprüften Felder an. Weichen
  die Felder im echten Konto ab, wird das Skript nach dem Probelauf angepasst, bevor widerrufen wird.
- **Zertifikatsverbrauch des Exports:** Ob `-exportArchive` (Cloud-Verteilzertifikat) selbst eines
  anlegt, ist offen; `upload.log` nennt keine Signier-Identität. Gemessen wird es in Vorgehen 5 über die
  Liste im Nachschritt. Wächst die Gesamtzahl trotz Aufräumen, weil der Export ein nicht gewähltes
  Zertifikat (z. B. Distribution) hinterlässt, ist die DoD nicht erfüllt; die Auswahlregel wird dann nicht
  stillschweigend erweitert, sondern neu entschieden (Alternative A oder eigene Spec).
- **Profile nach dem Widerruf:** Der Widerruf macht die automatischen Profile ungültig;
  `-allowProvisioningUpdates` soll sie im Lauf neu erzeugen. Das ist im ersten scharfen Lauf zu
  bestätigen (Archiv ohne „No profiles for …“), nicht vorauszusetzen.
- **Xcode 27:** Eine Änderung am Verhalten (Zertifikat pro Lauf) wurde in der Recherche nicht gefunden;
  das heißt nicht, dass es sie nicht gibt.
- **Werkzeuge auf dem Runner:** `openssl` auf dem macOS-Runner ist vermutlich LibreSSL; ob
  `openssl dgst -sha256 -sign` dort dasselbe DER-Ergebnis liefert wie lokal, bestätigt erst der echte
  Lauf. (`python3` und `openssl` lokal geprüft durch die Tests.)

### Recherche (Quellen)

- Ursache (leerer Runner, `-allowProvisioningUpdates` legt Zertifikat an, Schlüssel geht verloren): https://rxliuli.com/blog/two-pitfalls-of-safari-cloud-signing-in-github-actions
- Wörtliche Meldung, Widerruf als Ausweg: https://support.bitrise.io/en/articles/9676601-error-your-account-has-reached-the-maximum-number-of-certificates
- Automatische Signierung auf CI nur im ersten Lauf, danach „private key is not installed“: https://developer.apple.com/forums/thread/764554, https://developer.apple.com/forums/thread/760819, https://developer.apple.com/forums/thread/695759
- Unsigniertes Archiv verliert Entitlements: https://developer.apple.com/forums/thread/671800 (ITMS-90078)
- Cloud-verwaltete Zertifikate (kein Wort zu Limit oder CI): https://developer.apple.com/help/account/create-certificates/cloud-managed-certificates
- Token: https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests
- Belege aus echten Läufen und Analyse: `docs/context/fix-191-testflight-zertifikat.md` (Lauf 37119618643 grün, Lauf 37128541497 rot)

## Test Plan

Kein Produktcode. Die Logik steckt im Skript und wird mit Pythontests gegen einen Fake-Server belegt;
Workflow mit Struktur- und Syntaxprüfung; die Wirkung im echten Konto nur durch echte Läufe.

### Automated Tests (TDD RED)

- [ ] Test 1 (RED, Fehlerzustand): GIVEN Lauf 37128541497 WHEN `gh run view 37128541497 --log` nach „Choose a certificate to revoke“ und „ARCHIVE FAILED“ durchsucht wird THEN gibt es Treffer im Schritt „Archive“ (AC-12).
- [ ] Test 2: GIVEN gemischte Zertifikatsliste (Fall 1) WHEN das Skript ohne `--dry-run` läuft THEN werden genau die zwei Entwicklungs-Zertifikate „Created via API“ gelöscht, DELETE-Zähler = 2 mit richtigen IDs (AC-1).
- [ ] Test 3: GIVEN Zertifikate vom Typ `DEVELOPMENT` und `IOS_DEVELOPMENT` mit Name „Created via API“ WHEN das Skript läuft THEN werden beide gelöscht (AC-1).
- [ ] Test 4: GIVEN je nur ein Zertifikat vom Typ Distribution, mit anderem Namen, mit anderem Typ, ohne Namensfeld WHEN das Skript läuft THEN DELETE-Zähler = 0 (AC-2).
- [ ] Test 5: GIVEN wählbare Zertifikate und `--dry-run` WHEN das Skript läuft THEN DELETE-Zähler = 0, Exit 0, Zeilen mit `aktion=widerruf`/`bleibt` und `wuerde-widerrufen=<k>` (AC-3).
- [ ] Test 6: GIVEN Fake-Liste und `GITHUB_STEP_SUMMARY` auf Temp-Datei WHEN das Skript läuft THEN stimmt `zertifikate vorher=<n> nachher=<m> widerrufen=<k>` mit der Liste überein und steht in Ausgabe und Temp-Datei (AC-4).
- [ ] Test 7: GIVEN zwei Seiten mit `links.next` WHEN das Skript läuft THEN wird das wählbare Zertifikat von Seite 2 gelöscht; GIVEN `links.next` auf fremden Host THEN Exit 1 und keine Anfrage dort (AC-5).
- [ ] Test 8: GIVEN 401 bzw. 403 beim Listen WHEN das Skript läuft THEN Exit 1, Meldung mit Statuscode, DELETE-Zähler = 0 (AC-6).
- [ ] Test 9: GIVEN zwei wählbare Zertifikate, das erste antwortet auf DELETE mit 409 WHEN das Skript läuft THEN wird das zweite trotzdem gelöscht, Exit 1, `::error::` in der Ausgabe (AC-6).
- [ ] Test 10: GIVEN Fake-Server prüft das Token WHEN das Skript läuft THEN verifiziert `openssl dgst -verify` die Signatur, Claims stimmen; falsche Signatur ergibt 401 und Exit 1 (AC-7).
- [ ] Test 11: GIVEN Lauf mit Schlüssel und Token WHEN Standard- und Fehlerausgabe geprüft werden THEN enthalten sie weder Schlüsselrumpf noch Token (Erfolgs- und 401-Fall) (AC-7).
- [ ] Test 12: GIVEN der geänderte `testflight.yml` WHEN als YAML geparst und die `run`-Blöcke mit `bash -n` geprüft werden THEN kein Fehler; Reihenfolge Store key < Aufräumen < Archive < Upload < Aufräumen (`if: always()`) < Remove the key; alle bisherigen Schritte vorhanden; `confirm` unverändert (AC-8).
- [ ] Test 13: GIVEN der geänderte `testflight.yml` WHEN `on.workflow_dispatch.inputs` gelesen wird THEN existiert `cleanup_dry_run` als boolean, Vorgabe `false`; beide Aufräum-Schritte reichen sie als `--dry-run` weiter (AC-9).
- [ ] Test 14: GIVEN `docs/reference/testflight.md` WHEN nach den Begriffen `Created via API`, `cleanup_dry_run`, `zertifikate vorher` und `maximum number of certificates` gesucht wird THEN stehen alle vier in „Wenn es hakt“ bzw. „Was der Workflow tut“ (AC-10).
- [ ] Test 15 (echter Probelauf): GIVEN `workflow_dispatch` vom PR-Zweig mit `cleanup_dry_run=true` WHEN der Lauf endet THEN zeigt `gh run view <id> --log` die Liste (`typ`, `name`, `ablauf`, `id`, `aktion`, `felder`) und `widerrufen=0`; Claudes Befund zur Trennschärfe steht im Bericht (AC-13).
- [ ] Test 16 (zwei echte Läufe): GIVEN zwei `workflow_dispatch`-Läufe hintereinander vom PR-Zweig mit `cleanup_dry_run=false` WHEN beide enden THEN beide grün; die Zahlen aus den Zeilen `zertifikate vorher=… nachher=…` (Ende Lauf 1 = Anfang Lauf 2 = Ende Lauf 2) sind zitiert (AC-14).

## Acceptance Criteria

- [ ] AC-1 Auswahl: `scripts/asc_cleanup_certs.py` widerruft nur Zertifikate mit `certificateType` `DEVELOPMENT` oder `IOS_DEVELOPMENT` und Anzeigename genau „Apple Development: Created via API“; Test 2 und 3 grün.
- [ ] AC-2 Nichts anderes: Zertifikate vom Typ Distribution, mit anderem Namen, mit anderem Typ oder ohne Namensfeld werden nie gelöscht (DELETE-Zähler 0); Test 4 grün.
- [ ] AC-3 Dry-run: Mit `--dry-run` wird kein DELETE gesendet; die Ausgabe listet je Zertifikat Typ, Name, Ablauf, gekürzte ID und Aktion `widerruf`/`bleibt`; Test 5 grün.
- [ ] AC-4 Zählung: Das Skript gibt `zertifikate vorher=<n> nachher=<m> widerrufen=<k>` aus (Probelauf zusätzlich `wuerde-widerrufen=<k>`) und hängt die Zeile an `$GITHUB_STEP_SUMMARY` an, wenn gesetzt; „nachher“ stammt aus einer erneuten Abfrage; Test 6 grün.
- [ ] AC-5 Paginierung: `links.next` wird gelesen; eine URL auf fremden Host bricht mit Exit 1 ab, bevor ein Token dorthin geht; Test 7 grün.
- [ ] AC-6 Fehler laut: 401/403 beim Listen ergibt Exit 1 ohne DELETE; ein fehlgeschlagener Widerruf (z. B. 409) lässt die übrigen laufen, ergibt `::error::` und Exit 1; Test 8 und 9 grün.
- [ ] AC-7 Geheimnisse: Schlüssel, Token, Signatur und Zertifikatsinhalt erscheinen nirgends in der Ausgabe; das Token wird wie in `asc_wait_build.py` (ES256, `openssl`) erzeugt und vom Fake-Server verifiziert; Test 10 und 11 grün.
- [ ] AC-8 Workflow: Im Job `upload` steht ein Aufräum-Schritt zwischen „Store the App Store Connect API key“ und „Archive“ und ein Aufräum-Schritt mit `if: always()` nach „Upload to TestFlight“ und vor „Remove the key“; alle bisherigen Schritte und der Job `confirm` bleiben; Test 12 grün.
- [ ] AC-9 Probelauf-Schalter: `workflow_dispatch` hat die boolesche Eingabe `cleanup_dry_run` (Vorgabe `false`), die beide Schritte als `--dry-run` weiterreichen; Test 13 grün.
- [ ] AC-10 Doku: `docs/reference/testflight.md` beschreibt in „Wenn es hakt“ und „Was der Workflow tut“ Ursache, die zwei Schritte, die Auswahlregel, die Zählzeile, den Schalter `cleanup_dry_run` und dass nie von Hand widerrufen wird; Test 14 grün.
- [ ] AC-11 Lokale Tests grün: `python3 scripts/test_asc_cleanup_certs.py` läuft grün; jeder Fehlerfall wurde einmal rot gesehen (Skript vor Implementierung fehlend, dann Auswahl gezielt verbreitert).
- [ ] AC-12 Fehlerzustand belegt: Vor der Änderung ist aus dem Protokoll von Lauf 37128541497 die Meldung „Choose a certificate to revoke“ samt `ARCHIVE FAILED` (Exit 65) im Bericht zitiert (Test 1).
- [ ] AC-13 Auswahl an echten Daten: Ein Probelauf mit `cleanup_dry_run=true` ist durchgelaufen, die Liste aus dem Protokoll im Bericht zitiert und mit Befund versehen, ob „Entwicklung + Created via API“ Hennings eigene Zertifikate sicher ausschließt; die tatsächlichen Feldnamen sind festgehalten. Ohne diesen Befund läuft kein scharfer Lauf (Test 15).
- [ ] AC-14 Behebung bewiesen: Zwei `workflow_dispatch`-Läufe hintereinander vom PR-Zweig sind grün, ohne Aufräumen im Konto von Hand; die Zertifikatszahl am Ende von Lauf 1, am Anfang von Lauf 2 und am Ende von Lauf 2 ist gleich und im Bericht aus `gh run view <id> --log` zitiert; im Bericht stehen ferner, ob der Export ein Zertifikat verbraucht hat und ob nach dem Widerruf das Archiv ohne „No profiles for …“ lief (Test 16).
- [ ] AC-15 Geräteliste und Umfang: Kein Pfad der Geräteliste berührt; keine sichtbare UI-Änderung, daher keine Entwurfsvorschau; das Diff berührt genau die vier genannten Dateien (plus Workflow-Artefakte unter `docs/`); keine neuen Secrets oder Abhängigkeiten.
- [ ] AC-16 Ausliefern: Nach dem Merge ist `bash ~/.claude/scripts/loose-ends-sync-main.sh` gelaufen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Ergänzung der Build-Auslieferung um zwei Aufräum-Schritte ohne Architekturwirkung; keine bestehende Entscheidung wird gekippt, nur die Annahme, `-allowProvisioningUpdates` räume hinter sich auf.
- **Rationale:** Ein Skript gegen die ASC-API mit enger Regel ist die kleinste Lösung, die das volle Konto heilt und Wachstum verhindert, ohne neues Geheimnis und ohne Wartung eines ablaufenden Zertifikats. Das Risiko (Widerruf ist nicht umkehrbar) wird durch eng gefasste Auswahl, Probelauf vor dem ersten Widerruf und ein benanntes Rückfallkriterium (Alternative A) begrenzt, nicht durch Vertrauen.

## Changelog

- 2026-10-03 (Nachbesserung nach Probelauf 37136927454, Henning: „override“): Der Anzeigename im Konto lautet
  `Apple Development: Created via API`, nicht `Created via API`. Die Auswahlregel in „Änderung 1“ (Anzeigename genau …),
  AC-1 und AC-13 lesen sich ab jetzt mit diesem vollen Namen. Trennschärfe am echten Konto belegt: vier Zertifikate
  `Apple Development: Created via API`, dazu `Apple Development: HENNING EMMRICH` (2×) und `Apple Development: Johannes Emmrich`
  bleiben. Feldnamen: `certificateType`, `name`, `displayName`. Export legt kein Zertifikat an (6 → 7 durch das Archiv allein).
  Beleg: `docs/artifacts/fix-191-testflight-zertifikat/probelauf-37136927454.txt`.

- 2026-10-03: Initial spec created (Analyse in `docs/context/fix-191-testflight-zertifikat.md`).

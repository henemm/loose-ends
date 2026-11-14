# Adversary Dialog — feat-615-s4f-abnahme
Spec: docs/specs/feat-615-schnitt-4f-abnahme.md
Datum: 2026-11-14 08:23

## Checkliste
- [x] **AC-1:** `rows` zählt und legt nichts an: GIVEN eine frisch migrierte Wegwerf-Datenbank ohne Konto WHEN `local-fixture.ts rows` läuft THEN gibt es genau acht Zeilen `<tabelle>=0` in der Reihenfolge `accounts`, `sessions`, `transcripts`, `orders`, `order_results`, `apple_tokens`, `oauth_records`, `device_tokens`, und ein zweiter Aufruf zeigt dieselben Zahlen (es entsteht kein Konto).
- [x] **AC-2:** Schutz und Stille: GIVEN `rows` oder `apple-token` WHEN `DATABASE_URL` fehlt oder `postgres://u@db.example:5432/x` ist THEN endet der Aufruf mit Ausgang 1 vor jedem Datenbankzugriff, und stderr enthält weder einen Token noch den Platzhaltertext (`grep -F`); ein unbekannter Unterbefehl endet mit Ausgang 1 und nennt `rows` und `apple-token` in der Usage-Meldung.
- [x] **AC-3:** `apple-token` legt genau eine Zeile an: GIVEN der laufende lokale Dienst WHEN `apple-token` zweimal läuft THEN zeigt `rows` danach `apple_tokens=1` und `accounts=1`, und `psql`/Fixture-Ausgabe nennt keinen Klartext (der Platzhaltertext erscheint in keiner Ausgabe des Protokolls).
- [x] **AC-4:** Ohne Umgebung übersprungen: GIVEN `LOOSEENDS_DEBUG_SERVICE` und `LOOSEENDS_DEBUG_SESSION` nicht gesetzt WHEN `./scripts/sim.sh test-proof AccountLocalServiceTests` läuft THEN sind beide Tests übersprungen (nicht rot), der Skip-Grund nennt die zwei Variablen, und das Protokoll benennt jeden übersprungenen Test einzeln.
- [x] **AC-5:** Abmelden im Simulator gegen den echten Dienst: GIVEN der lokale Dienst mit gefüllten Zeilen (Teil 4, Schritt 2) und eine Sitzung S1 WHEN `testSignOutEndsOnlyThisSession` mit S1 läuft THEN ist der Test grün (Zeile „verbunden“ da, nach dem Tippen Anmeldeknopf und Einleitungssatz da, keine Rückfrage), und `rows` zeigt danach `sessions` um genau 1 kleiner als vorher, `accounts=1` und alle übrigen Zahlen unverändert.
- [x] **AC-6:** Löschen im Simulator gegen den echten Dienst, keine Zeile mehr: GIVEN dieselbe Datenbank und eine neue Sitzung S2 (`local-fixture.ts session`) WHEN `testDeleteRemovesTheAccount` mit S2 läuft THEN ist der Test grün (Rückfrage „Delete account?“ erscheint, Bestätigung entfernt die Zeile „verbunden“, Anmeldeknopf kehrt zurück), und `rows` zeigt danach **alle acht Zahlen 0**; die Zahlen davor (Schritt 2) zeigen für `accounts`, `sessions`, `transcripts`, `orders`, `order_results`, `apple_tokens` und `device_tokens` mindestens 1.
- [x] **AC-7:** Widerruf ausgelöst, ehrlich benannt: GIVEN der Lauf aus AC-6 THEN steht im Log des Dienstes zwischen Start und Ende des Löschens genau eine Zeile `apple revoke skipped` und keine Zeile `apple revoke failed`, und das Protokoll sagt wörtlich, dass lokal kein Apple erreichbar ist (der Widerruf wird versucht und übersprungen) und der Aufruf an Apple selbst nur durch die Server-Tests mit Attrappe belegt ist (`server/test/auth.test.ts`, `./server/scripts/test-local.sh` grün im Protokoll).
- [x] **AC-8:** Gelöschte Sitzung ist tot: GIVEN der Lauf aus AC-6 WHEN `POST $SERVICE_URL/auth/delete` mit S2 aufgerufen wird THEN antwortet der Dienst 401, und `rows` bleibt bei allen acht Zahlen 0.
- [x] **AC-9:** Durchreiche ändert nichts ohne die Variablen: GIVEN `scripts/sim.sh` WHEN `bash -n scripts/sim.sh` läuft und `grep -n 'LOOSEENDS_DEBUG_' scripts/sim.sh` gelesen wird THEN ist die Syntax sauber, die Variablen stehen nur im Zweig für `test` und exportieren nur, wenn beide gesetzt sind, und ein `./scripts/sim.sh test-proof AccountSettingsTests` ohne sie läuft wie bisher grün (8 von 8).
- [x] **AC-10:** Kein Produktcode berührt, Server und App grün: GIVEN die Änderung WHEN `git diff --stat origin/main...HEAD -- server/src LooseEnds LooseEndsTests project.yml` läuft THEN ist die Ausgabe leer, `./server/scripts/test-local.sh` ist grün, und `./scripts/sim.sh unit` ist grün.
- [x] **AC-11:** Aufräumen: GIVEN das Ende von Protokoll A WHEN der Dienst per Signal beendet wurde THEN gibt es keinen Prozess von Dienst oder Postgres dieses Laufs, keinen Temp-Ordner und keinen offenen Port, und kein Wert des Tokens steht im abgelegten Protokoll (`grep -F` mit `SESSION_TOKEN` und `DATABASE_URL`-Passwortteil, falls vorhanden, ohne Treffer).
- [x] **AC-12:** Belege geöffnet: GIVEN die Screenshots der beiden Testläufe unter `docs/artifacts/feat-615-s4f-abnahme/` THEN ist jeder geöffnet und beschrieben (Einstellungen mit Gruppe „Claude“ und Zeile „verbunden“; Rückfrage „Delete account?“; Zustand danach mit Anmeldeknopf), und das Protokoll nennt je Bild, was darauf zu sehen ist.

## Dialog

### Runde 1
**Adversary:** Versuch zu brechen. (a) `rows` legt Konto an? Code: Zweig `rows` (server/scripts/local-fixture.ts:32) ruft nur `SELECT count(*)`, `findOrCreate` steht nur im else-Zweig (Zeile 38); Tabellennamen (Zeile 24) gleich den acht `CREATE TABLE` der Migrationen. (b) Schutz: selbst ausgefuehrt, ohne `DATABASE_URL`, mit db.example, fuer `rows`/`apple-token`/unbekannt: Ausgang 1, Meldung ohne Token/Platzhalter; unerreichbare 127.0.0.1-Adresse mit Passwort `secret`: Ausgang 1, Meldung nennt nur den Fehlernamen, kein Passwort. Hinweis: mit db.example meldet auch ein unbekannter Unterbefehl zuerst den Host-Fehler (Reihenfolge Zeilen 19-26), Usage nur bei lokaler URL; im Protokoll A so belegt. (c) Test koennte gruen sein ohne echten Dienst? Der Test setzt kein `--ui-testing` (LooseEndsUITests/AccountLocalServiceTests.swift:31), und der Nachweis liegt in `rows`: sessions 1->0 nach Abmelden, alle acht 0 nach Loeschen; der Dienstlog zeigt `apple revoke skipped` mit Zeitstempel im Loeschfenster. Echter Dienst, nicht nur Oberflaeche. (d) AC-5 "genau diese Sitzung": S2 vor dem Loeschen erzeugt (sessions=1), Abmelden hat S1 entfernt, Rest unveraendert. (e) AC-10: Diff-Statistik gegen origin/main auf server/src, LooseEnds, LooseEndsTests, project.yml selbst ausgefuehrt: leer. `bash -n scripts/sim.sh` sauber; Export nur im Zweig `test` und nur bei beiden Variablen (scripts/sim.sh:323). (f) Bilder geoeffnet: local-signed-in (Gruppe Claude, "Signed in with Apple / This device", Sign out, Delete account ...), local-delete-dialog (Popover "Delete account?", roter Knopf), local-after-delete (nur schwarzer Knopf "Sign in with Apple" plus Einleitungssatz). Stimmen mit dem Protokoll. (g) Token: Platzhaltertext in keiner Datei des Ordners (grep -rF leer); Muster >=40 Zeichen trifft nur SHA-256- und Commit-Hashes in simulator-run-*.txt, keine Tokens, protokoll-a.md ohne Treffer.
**Implementierer:** Belege liegen in protokoll-a.md; Fixture-Zweig wie zitiert; kein Produktcode geaendert.

### Runde 2
**Adversary:** Bekannte Auffaelligkeiten. (1) AC-4: xcodebuild `TEST SUCCEEDED`, 0 Fehler, 2 Tests einzeln uebersprungen mit Grund, der beide Variablen nennt (AccountLocalServiceTests.swift:28). Die AC fordert "uebersprungen (nicht rot)" und Benennung je Test: erfuellt. Dass `sim_proof.py` einen reinen Skip-Lauf als `Unbekannt` wertet und sim.sh mit 1 endet, ist Verhalten des bestehenden Werkzeugs (nicht geaendert); in der CI laeuft die Klasse im Shard neben anderen Tests. Restrisiko: lokaler Einzellauf ohne Umgebung gibt Exit 1; LOW F001, kein Block. (2) AC-11: S1 nicht greifbar; Ersatz Mustersuche >=40 Zeichen, an S2 (43 Zeichen) gegengeprueft; selbst wiederholt: kein Treffer in protokoll-a.md. Datenbank ohne Passwort. LOW F002. (3) server/tsconfig.json include nur src und test: scripts/local-fixture.ts wird nicht typgeprueft; Laufzeit ist belegt. LOW F003. (4) Testlauf-App unsigniert: Debug-Weg haelt die Sitzung im Speicher, kein Schluesselbund; fuer Abmelden/Loeschen irrelevant, signiert nur Schritt 2. Kein Befund. (5) Regression: sim.sh ohne Variablen unveraendert im Verhalten; AccountSettingsTests 8/8, test-local 422/422, unit gruen laut Protokoll. (6) `rows` zaehlt ganze Tabellen (Known Limitation der Spec); oauth_records=0 ist laut Protokoll kein Beleg. (7) AC-7-Wortlaut zur Apple-Attrappe steht im Protokoll. Nichts gebrochen.
**Implementierer:** F001 bis F003 akzeptiert als LOW, kein Nachbessern noetig.

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/sim.sh:323
  Description: Die Durchreiche aendert nichts am Beleg-Werkzeug; ein reiner Skip-Lauf von test-proof endet mit Exit 1 (sim_proof: Unbekannt), obwohl xcodebuild gruen ist.
  Spec requirement: AC-4 - beide Tests uebersprungen, nicht rot
  Conflict: Nur Werkzeugeigenschaft; AC-Wortlaut erfuellt.
  Remediation: Im Abschluss benennen (steht im Protokoll); optional sim_proof fuer Skip-Laeufe.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: server/scripts/local-fixture.ts:24
  Description: Token S1 wurde mit dem Temp-Ordner geloescht; AC-11 stuetzt sich auf Mustersuche statt grep -F mit S1.
  Spec requirement: AC-11 - kein Tokenwert im Protokoll
  Conflict: Beweis indirekt; selbst nachgeprueft ohne Treffer.
  Remediation: Keine.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: server/scripts/local-fixture.ts:32
  Description: server/tsconfig.json (include src, test) prueft scripts/ nicht; neue Zweige ohne Typpruefung.
  Spec requirement: AC-10 - Server gruen
  Conflict: Keine Verletzung, vorbestehende Luecke.
  Remediation: Optional scripts in include aufnehmen.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: server/scripts/local-fixture.ts:32
  Evidence: rows nur SELECT count(*) in fester Reihenfolge, kein findOrCreate; zweimal acht Nullen im Protokoll.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/scripts/local-fixture.ts:19
  Evidence: Selbst ausgefuehrt: Ausgang 1 ohne URL und mit db.example; stderr ohne Token/Platzhalter.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/scripts/local-fixture.ts:51
  Evidence: Upsert ueber Primaerschluessel, zweimal apple_tokens=1; Platzhalter in keiner Datei.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEndsUITests/AccountLocalServiceTests.swift:28
  Evidence: XCTSkip mit benanntem Grund; summary-skip.json: skippedTests 2, failedTests 0.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEndsUITests/AccountLocalServiceTests.swift:93
  Evidence: Test gruen, sessions 1->0, uebrige Zahlen unveraendert; Bilder geoeffnet.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEndsUITests/AccountLocalServiceTests.swift:104
  Evidence: Test gruen, Rueckfrage im Bild, danach alle acht Tabellen 0.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/scripts/local-fixture.ts:51
  Evidence: Dienstlog genau eine Zeile apple revoke skipped, keine failed; Ehrlichkeitsabschnitt im Protokoll; test-local 422/422.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/scripts/local-fixture.ts:32
  Evidence: POST /auth/delete mit S2 -> 401, rows weiter acht Nullen (rows legt nichts an).
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/sim.sh:323
  Evidence: bash -n sauber, Export nur bei test und beiden Variablen, AccountSettingsTests 8/8.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/sim.sh:654
  Evidence: Diff-Statistik auf Produktpfade selbst ausgefuehrt: leer; Server und Unit laut Protokoll gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: server/scripts/local-fixture.ts:24
  Evidence: Aufraeumprobe im Protokoll; Mustersuche selbst wiederholt, kein Token in protokoll-a.md.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: LooseEndsUITests/AccountLocalServiceTests.swift:110
  Evidence: Drei Bilder selbst geoeffnet, entsprechen dem Protokoll.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Umsetzung hielt dem Adversary-Test stand.
Tests: Protokoll A: test-local 422 bestanden, 0 fehlgeschlagen, 0 uebersprungen; AccountSettingsTests 8 bestanden; AccountLocalServiceTests gegen den Dienst 2 bestanden; ohne Umgebung 2 uebersprungen (testDeleteRemovesTheAccount, testSignOutEndsOnlyThisSession), 0 fehlgeschlagen
Edge cases: alle geprueft, keine gebrochen (3 LOW-Hinweise F001-F003)
Regressions: keine gefunden
Checklist: 12/12 Punkte belegt

## Geprüfte Dateien

- sha256:65cf3182954f5d4ff51ab40a182c2e33760c77bf186d5715d5d5e08ba049708c  LooseEndsUITests/AccountLocalServiceTests.swift
- sha256:890332312ce6f27897f427c72126377150f01fde5b896301b4e0332812fedafa  scripts/sim.sh
- sha256:b17a81cf951ccb2d67baeadef6daa9c369aa660b591e3191c351b67f848061d0  server/scripts/local-fixture.ts

## Prüfbasis

- base: 92e8ab7970263177bae543486eac463224c2c1a2
- blob:7709490f64203237040e519cad592fa822cf98bd  LooseEndsUITests/AccountLocalServiceTests.swift
- blob:f94b1e6ebdf9fa4ca6241995b3e76a88c8a3ac40  scripts/sim.sh
- blob:467a32807fcb1ef5d186107309bfa5f8cd7400de  server/scripts/local-fixture.ts

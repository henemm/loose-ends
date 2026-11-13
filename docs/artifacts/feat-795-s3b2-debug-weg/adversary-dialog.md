# Adversary Dialog — feat-795-s3b2-debug-weg
Spec: docs/specs/feat-795-schnitt-3b2-debug-weg.md
Datum: 2026-11-13 12:47

## Checkliste
- [x] **AC-1:** Beide Argumente da: GIVEN `-LEDebugService http://localhost:8780` und `-LEDebugSession TOKEN` und `debugBuild: true` WHEN `debugService` gerufen wird THEN ist das Ergebnis die Adresse `http://localhost:8780` und der Token `TOKEN`; die Reihenfolge der Argumente und weitere Argumente dazwischen ändern nichts (Test `debugServiceReadsAddressAndSession`).
- [x] **AC-2:** Nur im Debug-Bau: GIVEN dieselben Argumente und `debugBuild: false` THEN ist `debugService` `nil`, `isEnabled(info: nil, arguments:, debugBuild: false)` ist `false` und `forApp(info: nil, arguments:, debugBuild: false)` ist `nil` (Test `debugServiceNeverInRelease`).
- [x] **AC-3:** Beide Argumente nötig: GIVEN nur `-LEDebugService …` oder nur `-LEDebugSession …`, ein Argument ohne folgenden Wert (letztes Argument) oder ein leerer oder nur aus Leerraum bestehender Token THEN ist `debugService` `nil` (Test `debugServiceNeedsBothArguments`).
- [x] **AC-4:** Nur `http://localhost:<port>`: GIVEN die Adressen `https://localhost:8780`, `http://127.0.0.1:8780`, `http://fremd.example:8780`, `http://localhost.evil.example:8780`, `http://user@localhost:8780`, `http://user:pw@localhost:8780`, `http://localhost:8780#x`, `http://localhost:8780/pfad`, `http://localhost:8780/?x=1`, `ftp://localhost:8780`, `kein url` und leer THEN ist `debugService` jeweils `nil`; `http://LOCALHOST:8780` und `http://localhost:8780/` gelten (Test `debugServiceAcceptsOnlyLocalhostHTTP`).
- [x] **AC-5:** Port ist Pflicht: GIVEN `http://localhost` (ohne Port) THEN ist `debugService` `nil` (Test `debugServiceNeedsAPort`).
- [x] **AC-6:** Schalter: GIVEN `info: nil` und die Debug-Argumente mit `debugBuild: true` THEN ist `isEnabled` wahr; ohne die Argumente, nur mit einem davon oder mit ungültiger Adresse bleibt es `false` (kein `LEAccountEnabled`, kein `--ui-testing`); `--ui-testing` und `LEAccountEnabled` wirken wie bisher (Test `debugArgumentsSwitchTheAccountOn`).
- [x] **AC-7:** Verdrahtung: GIVEN `forApp(info: nil, arguments: [-LEDebugService http://localhost:<port>, -LEDebugSession TOKEN])` im Debug-Bau THEN ist das Ergebnis ein `AccountState` im Status `signedIn`, und `forApp(info: nil, arguments:)` mit denselben Argumenten, aber ungültiger Adresse, liefert `nil` (Test `forAppWithDebugArgumentsIsSignedIn`). Dass der Token über den echten Transport ankommt, belegt AC-12, nicht dieser Test.
- [x] **AC-8:** `--ui-testing` gewinnt: GIVEN die Debug-Argumente **und** `--ui-testing` THEN baut `forApp` den Stellvertreter (`UITestTransport`, Status `signedOut`), nicht den lokalen Weg (Test `uiTestingBeatsDebugArguments`).
- [x] **AC-9:** Skript, Aufbau: GIVEN `server/scripts/local-service.sh`, gestartet mit geerbtem `APPLE_TEAM_ID` WHEN es läuft THEN antwortet `$SERVICE_URL/health` mit 200, der Dienst bindet nur an `127.0.0.1`, `state.env` enthält genau `DATABASE_URL`, `PORT`, `SERVICE_URL`, `SESSION_TOKEN`, und `POST /auth/apple` antwortet 503 (die geerbte Apple-Variable ist entfernt) (Beleg: Selbsttest Schritte 1–2, Protokoll `selbsttest.md`).
- [x] **AC-10:** Skript, Aufräumen: GIVEN der laufende Dienst WHEN SIGTERM, SIGINT oder ein Fehler beim Start (belegter `LOCAL_SERVICE_PORT`) kommt THEN sind Dienst, Postgres und der Temp-Ordner danach weg und die Ports frei (Beleg: Selbsttest Schritte 4–5).
- [x] **AC-11:** Fixture: GIVEN der laufende lokale Dienst THEN nimmt `POST /app/transcript` mit `SESSION_TOKEN` das leere Dokument mit 2xx an; `transcript` gibt `tasks=0`, `order <text>` eine UUID, `result` dazu `waiting`, `result` mit unbekannter ID `unknown`, `due` ohne Datum Ausgang 1; ein unbekannter Unterbefehl, ein fehlendes Argument, eine fehlende `DATABASE_URL` und eine `DATABASE_URL` mit fremdem Host enden mit Ausgang 1, und stderr enthält weder den Wert des Tokens noch den Text (`grep -F`); `server/src/` ist unverändert (Beleg: Selbsttest Schritte 3 und 6).
- [x] **AC-12:** Abschrift von A: GIVEN Simulator A ohne `--ui-testing` mit den Debug-Argumenten und der vor dem Start gestellte Auftrag „Aufgabe von A“ WHEN A startet THEN zeigt `local-fixture.ts result <ID A>` innerhalb von 60 s `outcome=done`, und `transcript` zeigt innerhalb weiterer 60 s eine Abschrift mit dem Titel „Aufgabe von A“ (Beleg: Protokoll `ab-lauf.md` mit den Ausgaben).
- [x] **AC-13:** Auftrag an B: GIVEN die Abschrift von A im Dienst und A beendet WHEN `local-fixture.ts order "Aufgabe von B"` gelaufen ist und Simulator B (anderer Simulator, andere Gerätekennung) mit denselben Argumenten startet THEN zeigt `local-fixture.ts result <ID B>` innerhalb von 60 s den Zustand `result` mit `outcome=done` und einer `taskID`, und `transcript` enthält innerhalb weiterer 60 s „Aufgabe von B“ (Beleg: Protokoll `ab-lauf.md`).
- [x] **AC-14:** Revision „Claude“ auf B: GIVEN der Lauf aus AC-13 und der Auftrag `due` aus Teil 3, Schritt 4b WHEN `local-fixture.ts result <ID B2>` innerhalb von 60 s `outcome=done` mit derselben `taskID` zeigt und B's `LooseEnds.store` (gefunden wie in Teil 3, Schritt 5) nur lesend geöffnet wird (`sqlite3 -readonly`, `ZREVISION` samt `ZTASKITEM`) THEN trägt die Aufgabe „Aufgabe von B“ (`ZID` gleich `taskID`, `ZCAPTUREDVIARAW` = `claude`) eine Revision mit Grund „Claude“ für das Fälligkeitsdatum (Beleg: Ausgaben und Auszug der Abfrage im Protokoll).
- [x] **AC-15:** Screenshot B: GIVEN der Lauf aus AC-13 THEN zeigt `docs/artifacts/feat-795-s3b2-debug-weg/b-aufgabe.png` (Befehl in Teil 3, Schritt 5) die Startseite von B (nicht die Einführung) mit der neuen Aufgabe: ihr Titel „Aufgabe von B“ oder der Zähler „1 zum Durchsehen“ unter „Neu“ ist lesbar; der System-Dialog für Mitteilungen darf darüber liegen und wird dann benannt; der Screenshot wird geöffnet und beschrieben, bevor das AC abgehakt wird (Beleg: Bild im Artefaktordner).
- [x] **AC-18:** Signierter Bau nur auf Wunsch: GIVEN `scripts/sim.sh` WHEN `grep -n 'CODE_SIGNING_ALLOWED=NO\|LOOSEENDS_SIM_SIGN\|CODE_SIGN_IDENTITY' scripts/sim.sh` läuft THEN steht `CODE_SIGNING_ALLOWED=NO` weiter als Standard an beiden `xcodebuild`-Stellen und `CODE_SIGN_IDENTITY=-` nur im Zweig von `LOOSEENDS_SIM_SIGN=1`; `bash -n scripts/sim.sh` ist sauber; ein Bau ohne den Schalter (`./scripts/sim.sh build`) gelingt wie bisher, und der A/B-Lauf (AC-12, AC-13) läuft mit dem Schalter (Beleg: Befehle mit Ausgabe im Protokoll `ab-lauf.md`).
- [x] **AC-16:** Quellsuche: GIVEN die Änderung WHEN diese Befehle laufen THEN gilt je Befehl: `grep -n -- '-LEDebug' LooseEnds/Claude/AccountWiring.swift` trifft nur Zeilen in `debugService`; `grep -n 'static let debugBuild = true' -B2 LooseEnds/Claude/AccountWiring.swift` zeigt `#if DEBUG` darüber; `grep -n 'KeychainSessionStore' LooseEnds/Claude/AccountWiring.swift` trifft nur den bestehenden Nicht-Debug-Zweig; `grep -nE 'try\?|print\(|logger\.' LooseEnds/Claude/AccountWiring.swift` trifft keine neue Zeile (Beleg: die vier Befehle mit Ausgabe im Abschlussbericht). Die Wirkung im Release-Fall belegt AC-2.
- [x] **AC-17:** Ganze Suite grün: GIVEN die ganze Unit-Suite WHEN `./scripts/sim.sh unit` läuft THEN ist sie grün (Beleg: Lauf im Abschlussbericht).


## Dialog

### Runde 1
**Adversary:** Spec, Diff und Code gelesen. Eigener Lauf sim-unit AccountSectionTests (iPhone 17): Exit 0, alle 8 debug-Tests und die bestehenden gruen (adversary-test-output.txt). AC-16-Greps selbst gelaufen: -LEDebug nur Zeile 56 (in debugService); debugBuild = true steht unter #if DEBUG (Zeile 23); KeychainSessionStore nur Zeile 78 (alter Zweig); kein try?, print( oder logger. AC-18: bash -n scripts/sim.sh sauber, CODE_SIGNING_ALLOWED=NO bleibt Default (Zeilen 353/355), CODE_SIGN_IDENTITY=- nur im Schalterzweig (350). Diff-Statistik fuer server/src leer. Grenzfaelle der Adresspruefung gegen AC-4: alle gelisteten Faelle durch Code und Test abgedeckt. Eigene Probe URLComponents: Port 0 und 99999 werden akzeptiert (nur port != nil geprueft), [::1] abgelehnt, Leerzeichen am Ende ergibt URLComponents nil und damit abgelehnt, localhost ohne Portziffern abgelehnt. Argumentfolge -LEDebugSession -LEDebugService http://localhost:8780 ergibt Token "-LEDebugService".
**Implementierer:** (kein Gegenpart im Lauf; Belege selbsttest.md, ab-lauf.md)

### Runde 2
**Adversary:** Protokolle kritisch gelesen. ab-lauf.md (vierter Lauf): Store beider Simulatoren vorher deinstalliert; ID A 4ffbd48d, result nach 8 s done (taskID F3646E44), Abschrift nach 3 s "Aufgabe von A", A beendet vor Auftrag B; ID B ef87c374 waiting vor Start von B, dann done nach 4 s mit taskID 97B40E9F, Abschrift nach 3 s; due-Auftrag B2 3e9b37dd mit gleicher taskID, nach Neustart done in 7 s; sqlite3 readonly: ZID 97B40E9F, claude, genau eine Revision Grund "Claude", Feld dueDate, 1 Task, 1 Revision, also gehoert die Revision zum richtigen Task. Alle Fristen (60 s) eingehalten, IDs konsistent, UDIDs aus simctl. Aufraeumen: Temp-Ordner weg, kein Postgres, Port frei. kill -TERM geht an das Skript (pid 77169), der Dienst hatte 77217: konsistent. b-aufgabe.png selbst geoeffnet: Startseite (nicht Einfuehrung), "Heute draengt nichts.", Freitag 13. Nov., "Neu" mit "1 zum Durchsehen", Schreibzeile, "Jetzt 0", Liste "Lose Enden 1", "Erledigt"; darueber der Mitteilungsdialog (laut AC-15 zulaessig). Skripte: local-service.sh setzt Traps als erste Anweisung, unset aller APPLE_ und OAUTH Variablen, bindet 127.0.0.1, Zustandsdatei mit vier Schluesseln; local-fixture.ts lehnt Nicht-Loopback-Host vor DB-Zugriff ab, keine Token oder Texte in Fehlermeldungen. sim.sh: die Zeile mit && sign=(...) ist unter set -e unkritisch, Build mit und ohne Schalter belegt. Ganze Suite: test-green-output.txt endet mit "Unit-Tests bestanden", 0 Fehlschlaege; 3 Messstrecken uebersprungen (RawSentenceReportTests, SelfConsistencyReportTests, TextFormModelReportTests, fehlende Korpusdateien, nicht vom Schnitt verursacht). Offen nur LOW (F001, F002), kein Spec-Verstoss.
**Implementierer:** (keine Erwiderung)

### Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Claude/AccountWiring.swift:57
  Description: Adresspruefung verlangt nur parts.port != nil; Port 0 und 99999 werden akzeptiert (mit URLComponents nachgestellt).
  Spec requirement: AC-5 — Port ist Pflicht
  Conflict: Spec nennt keinen Wertebereich; ein ungueltiger Port scheitert erst beim Verbindungsversuch. Kein Sicherheitsproblem (Host bleibt localhost).
  Remediation: optional (1...65535).contains(port).

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Claude/AccountWiring.swift:50
  Description: value(after:) nimmt das naechste Argument blind als Wert; -LEDebugSession -LEDebugService http://localhost:8780 ergibt Token "-LEDebugService".
  Spec requirement: AC-3 — Argument ohne folgenden Wert ist ungueltig
  Conflict: Nur unscharf bei Wert, der wie ein Flag aussieht; Spec verlangt es nicht. Nur Debug-Bau, nur localhost.
  Remediation: optional Werte mit fuehrendem -LE ablehnen.

### Confirmations

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Claude/AccountWiring.swift:54
  Evidence: value(after:) liest beide Flags reihenfolgeunabhaengig; Test debugServiceReadsAddressAndSession gruen
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Claude/AccountWiring.swift:49
  Evidence: guard debugBuild; isEnabled und forApp reichen den Parameter durch; Test debugServiceNeverInRelease gruen
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Claude/AccountWiring.swift:56
  Evidence: beide Werte noetig, Token getrimmt nicht leer; Test debugServiceNeedsBothArguments gruen
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Claude/AccountWiring.swift:58
  Evidence: Scheme http, Host localhost (lowercased), kein User oder Passwort, Pfad leer oder Schraegstrich, keine Query, kein Fragment; Test gruen
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Claude/AccountWiring.swift:57
  Evidence: parts.port != nil; Test debugServiceNeedsAPort gruen
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Claude/AccountWiring.swift:14
  Evidence: isEnabled prueft debugService; Test debugArgumentsSwitchTheAccountOn gruen
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Claude/AccountWiring.swift:75
  Evidence: forApp baut AccountState mit InMemorySessionStore(token:), signedIn; Test forAppWithDebugArgumentsIsSignedIn gruen
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Claude/AccountWiring.swift:70
  Evidence: ui-testing-Zweig steht vor dem Debug-Zweig; Test uiTestingBeatsDebugArguments gruen
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: server/scripts/local-service.sh:41
  Evidence: unset APPLE_ und OAUTH Variablen, HOST=127.0.0.1, vier Schluessel; selbsttest.md
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: server/scripts/local-service.sh:6
  Evidence: Traps INT, TERM, EXIT und cleanup; selbsttest.md Schritte 4 und 5
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: server/scripts/local-fixture.ts:17
  Evidence: Host-Schutz, Unterbefehle, keine Werte in Fehlern; selbsttest.md, server/src unveraendert
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: docs/artifacts/feat-795-s3b2-debug-weg/ab-lauf.md:171
  Evidence: A done nach 8 s, Abschrift nach 3 s
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: docs/artifacts/feat-795-s3b2-debug-weg/ab-lauf.md:218
  Evidence: B done mit taskID, Abschrift nach 3 s
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: docs/artifacts/feat-795-s3b2-debug-weg/ab-lauf.md:271
  Evidence: Revision Grund Claude, dueDate, zur taskID von B
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: docs/artifacts/feat-795-s3b2-debug-weg/ab-lauf.md:43
  Evidence: Bild selbst geoeffnet: Startseite mit "1 zum Durchsehen", Mitteilungsdialog darueber
  Status: CONFIRMED

Confirmation:
  AC: AC-18
  Code reference: scripts/sim.sh:350
  Evidence: Schalterzweig, Default CODE_SIGNING_ALLOWED=NO an 353 und 355, bash -n sauber
  Status: CONFIRMED

Confirmation:
  AC: AC-16
  Code reference: LooseEnds/Claude/AccountWiring.swift:23
  Evidence: vier Greps selbst gelaufen
  Status: CONFIRMED

Confirmation:
  AC: AC-17
  Code reference: LooseEndsTests/AccountSectionTests.swift:203
  Evidence: 8 neue Tests gruen; ganze Suite in test-green-output.txt bestanden
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
The implementation withstood adversary testing.
Tests: Einzellauf AccountSectionTests bestanden (Exit 0); ganze Suite bestanden, 0 failed, 3 Messstrecken uebersprungen (RawSentenceReportTests, SelfConsistencyReportTests, TextFormModelReportTests: Korpusdateien fehlen)
Edge cases: zwei LOW (F001 Port-Bereich, F002 Flag als Wert), nicht blockierend
Regressions: None found
Checklist: 18/18 points proven

## Geprüfte Dateien

- sha256:3559d5a5ef5143e53b281aeb002474e67b27ef36dbfb5016623799232065006a  LooseEnds/Claude/AccountWiring.swift
- sha256:78162fd95f3831cdeba2d0a52947345e4264e303ed97600f8b471936e800c7e9  LooseEndsTests/AccountSectionTests.swift
- sha256:b210f4294050f68666310e2d7382f753d2cce089cd0f20387a96edccfa53013b  docs/artifacts/feat-795-s3b2-debug-weg/ab-lauf.md
- sha256:0caa9a73642ccb0a194c4fbc6448f1605b070411132bf73b23b2b9b6f9945d22  scripts/sim.sh
- sha256:a0b88cbc0cea3ef4609712fdeac9f90db056292ba4367772ec115a95390857d9  server/scripts/local-fixture.ts
- sha256:a28f2fbd1bbc8092b25c958c69dcdb6a945f82372608d73b9b659edfabf41fce  server/scripts/local-service.sh

## Prüfbasis

- base: 646c64252ff77f40fd8127875b08568351d55360
- blob:bc143ce30d69c20a70aabd56c799f51e0e908d5c  LooseEnds/Claude/AccountWiring.swift
- blob:b89ad0d7303b531e66dcbb26109b156c200b66ef  LooseEndsTests/AccountSectionTests.swift
- blob:b92cfd5ab71c61097ecdd8b527731395f15afaa3  docs/artifacts/feat-795-s3b2-debug-weg/ab-lauf.md
- blob:eb1825fe45fdff9849cdd20343f41027cbb822a7  scripts/sim.sh
- blob:0c3e62aa7c7786cb8835a80b6095e929d1f3852b  server/scripts/local-fixture.ts
- blob:0aff93686cf44d0786b2957eccbc4d2ff0ed6f51  server/scripts/local-service.sh

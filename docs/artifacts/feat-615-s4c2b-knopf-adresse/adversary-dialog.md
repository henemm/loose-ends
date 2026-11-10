# Adversary Dialog — feat-615-s4c2b-knopf-adresse
Spec: docs/specs/feat-615-schnitt-4c2b-knopf-adresse.md
Datum: 2026-11-10 13:31

## Checkliste
- [x] **AC-1:** Abbildung `Layout`: für jede Zeile der Tabelle oben liefert `AccountSection.layout(status:problem:)` genau die Felder der Tabelle; insbesondere zeigt `signingIn` den Apple-Knopf (`showsAppleButton == true`), er ist nicht bedienbar (`appleButtonEnabled == false`) und die Fortschrittszeile steht (`showsProgress == true`); `deleting` zeigt den Knopf nicht (`showsAppleButton == false`, `appleButtonEnabled == false`); `signedOut`, `notAllowed`, `retryLater` zeigen ihn bedienbar. Das **ersetzt AC-8 der 4c-1-Spec** („`signingIn` zeigt nie den Apple-Knopf“) für `signingIn`; für `deleting` und die Angemeldet-Zeilen gilt AC-8 weiter. Test: „account: layout je status“ (Unit, tabellengetrieben, angepasst).
- [x] **AC-2:** Kein zweites Tippen: in jedem Status ist `appleButtonEnabled` höchstens dann wahr, wenn `showsAppleButton` wahr ist, und während `signingIn` und `deleting` nie wahr; in der View steht `.disabled(!layout.appleButtonEnabled)` an beiden Knopf-Varianten. Test: „account: laufende anfrage hat keinen bedienbaren knopf“ (Unit, über alle `AccountState.Status`-Fälle) und der UI-Test aus AC-3 (tippt den deaktivierten Knopf ein zweites Mal; es entsteht weder ein Fehler noch eine zweite Anmeldung).
- [x] **AC-3:** Sichtbar im laufenden Ablauf: mit Startargument `--ui-testing-account-slow` und dem Weg „Einstellungen öffnen, Knopf antippen“ existiert während der Wartezeit der Knopf `accountAppleButton` (`exists == true`), `isEnabled == false`, und die Zeile `accountProgressRow` ist sichtbar mit dem Text „Signing in …“; ein weiteres Tippen auf den Knopf ändert nichts; danach (Wartezeit bis 30 s) steht `accountSignedInRow` und der Knopf existiert nicht mehr. Test: `testSigningInKeepsDisabledAppleButton` in `AccountSettingsTests` (UI) mit Screenshot-Beleg `account-signing-in`, aufgenommen erst nach der Prüfung des Zwischenstands, der geöffnet und beschrieben wird.
- [x] **AC-4:** Ersatz-Dienst langsam: `UITestTransport` mit dem Argument `--ui-testing-account-slow` hat eine Verzögerung von 15 Sekunden; ein Ersatz mit gesetzter Verzögerung antwortet erst danach; ohne das Argument ist die Verzögerung null und die Antwort sofort; die Ausgänge `allowed`/`notAllowed`/`retryLater` bleiben je Argument wie festgelegt; die bestehenden UI-Tests laufen ohne Verzögerung. Test: „account: ersatz-transport langsam nur auf wunsch“ (Unit: `UITestTransport` aus `arguments:`, `delay` mit und ohne Argument, Ausgang unverändert, Antwort eines Transports mit kurzer ausdrücklicher Verzögerung erst nach dieser Wartezeit, damit der Unit-Lauf nicht 15 s steht) sowie der unveränderte vorhandene Satz in `AccountSettingsTests`.
- [x] **AC-5:** Adressregel (Tabelle unten): `https` mit Host wird angenommen; `http` nur für `localhost` und `127.0.0.1` und nur mit `allowsLocalHTTP: true`; jeder andere Fall liefert `AccountWiring.fallbackURL`. Test: „account: dienstadresse nur https“ (Unit, tabellengetrieben, `allowsLocalHTTP` ausdrücklich gesetzt, damit beide Zweige im Debug-Lauf gelten).
- [x] **AC-6:** Standardfreigabe: ohne Angabe von `allowsLocalHTTP` gilt im Debug-Bau (`#if DEBUG`) `http://localhost:8780` als angenommen, in einem Bau ohne `DEBUG` als abgelehnt (Fallback); `forApp` benutzt diesen Standard und nimmt unter `--ui-testing` mit `LEServiceURL = http://fremd.example` die Fallback-Adresse als Basis des Ersatz-Dienstes. Test: „account: dienstadresse standard folgt debug“ (Unit: Erwartung per `#if DEBUG` im Test selbst, so dass sie in jedem Bau gilt, in dem der Test laufen kann) und `forApp` im selben Test.
- [x] **AC-7:** Keine Wirkung auf das Vorhandene: der bestehende Satz „account: wiring schalter und adresse“ (Schalter, `forApp` ohne Schlüssel gleich `nil`, Fallback bei fehlendem, leerem, kaputtem oder falsch getyptem Wert, `https://dienst.example` angenommen) bleibt unverändert grün; alle Fälle von `AccountSettingsTests` (Gruppe unter iCloud, Anmelden zeigt Angemeldet-Zeilen, Abmelden, Löschen abbrechen/bestätigen, `notAllowed`, `retryLater`) bleiben grün; die Gruppe „Claude“ bleibt in jedem echten Bau ausgeschaltet. Test: vorhandener `sim-unit`-Satz und `./scripts/sim.sh test-proof AccountSettingsTests` (maschineller Simulator-Beleg, Stufe 2).
- [x] **AC-8:** Bauten und Grenze: `./scripts/sim.sh generate` hinterlässt keinen Diff; `./scripts/sim.sh build` und `./scripts/sim.sh mac-build` bauen ohne Fehler und ohne neue Warnungen (die Änderung in `AccountSection` und `AccountWiring` wirkt auf iOS und Mac); `python3 scripts/test_catalog_languages.py` unverändert grün (keine neuen Texte, keine neuen Schlüssel). Die Dateigrenze des Schnitts (nur die Tabelle „Affected Files“) prüft `/60-validate` einmalig, kein Test gegen `origin/main` (Projektregel). Test: `sim-unit` (alle Unit-Tests), `build`, `mac-build`, `test_catalog_languages.py`, CI-Schritt „Generate leaves the tree clean“ auf dem PR.

## Dialog

### Runde 1
**Adversary:** Eigene Läufe (frisch): `./scripts/sim.sh sim-unit AccountSectionTests` (adversary-test-output.txt): 8 Tests der Suite, 0 Fehler, 0 Warnungen, darunter layout je status, laufende anfrage, dienstadresse nur https, standard folgt debug, ersatz-transport langsam (0,33 s), wiring. `./scripts/sim.sh mac-build` (adversary-mac-build-output.txt): Build Succeeded, 0 Warnungen. `python3 scripts/test_catalog_languages.py`: 8 Tests OK. `./scripts/sim.sh generate`: kein Diff an Quellen (nur AccountWiring.swift verändert, project.yml und Info.plist unberührt). Diff gegen ee7f14a gelesen: 15 s steht in AccountWiring.swift Zeile 82, der UI-Test wartet bis 30 s und fragt Knopf, Fortschrittszeile und Text in einem Snapshot ab, bevor shoot() läuft. Angriff Zeitfenster: Der Ersatz antwortet nach 15 s, der Snapshot kam auf der CI nach ca. 10 s, Reserve rund 5 s; nach waitForExistence(5) nur eine Abfrage im Fenster. Restrisiko bei noch langsamerer CI, siehe F001. Zweiter Angriff Koordinaten-Tap: endet die Anmeldung vor dem Tap, trifft er die Stelle des früheren Knopfes, siehe F002. Der Screenshot account-signing-in (F5FDB50D) wurde geöffnet: Gruppe Claude, Zeile "Sign in with Apple" (Apfelsymbol getönt, Text schwarz) steht, darunter "Signing in ..." mit Spinner, darunter der Hinweis intro, kein Fehler. Der Beleg ist also der Zwischenstand, nicht der Endzustand.

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Views/AccountSection.swift:22
  Evidence: layout() liefert je Status genau die Tabellenfelder (signingIn: Knopf sichtbar, appleButtonEnabled false, Fortschritt true; deleting: kein Knopf, nicht bedienbar); Test layoutPerStatus grün im eigenen Lauf.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Views/AccountSection.swift:154
  Evidence: `.disabled(!enabled)` an der Test-Variante (Zeile 154) und an SignInWithAppleButton (Zeile 160); busyHasNoTappableButton grün; alle Layout-Zeilen von Hand geprüft, Invariante enabled => shown und busy => nie enabled hält.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEndsUITests/AccountSettingsTests.swift:199
  Evidence: testSigningInKeepsDisabledAppleButton 32,9 s grün im frischen test-proof (8/8, 0 übersprungen, head 53281f1); isEnabled == false, Fortschrittstext, Reihenfolge, Endzustand und Wartezeit 30 s im Test; Screenshot vor dem Zweit-Tap aufgenommen und geöffnet.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Claude/AccountWiring.swift:82
  Evidence: delay .seconds(15) nur mit `--ui-testing-account-slow`, sonst .zero; send schläft nur bei delay > .zero; Unit-Test belegt 15 s, Kombination mit not-allowed, Ausgänge, >= 300 ms bei explizitem Delay und < 1 s ohne.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Claude/AccountWiring.swift:29
  Evidence: guard verlangt Schema und nicht leeren Host; switch nimmt https, http nur mit allowsLocalHTTP und Host localhost/127.0.0.1. Alle Tabellenfälle in serviceAddressOnlyHTTPS grün. Randfall http://localhost@evil.example: URL.host() liefert evil.example, also Fallback.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Claude/AccountWiring.swift:22
  Evidence: debugBuild per #if DEBUG true, sonst false (Release fail-closed); Test erwartet per #if DEBUG im selben Muster. forApp ruft serviceURL(info:) mit Standard (Zeile 48). Release-Bau nicht selbst gebaut, der #else-Zweig ist eine Konstante.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Claude/AccountWiring.swift:48
  Evidence: wiringSwitchAndAddress unverändert grün; UI 8/8 inkl. der sieben vorhandenen Fälle; forApp nur im Transport-Init geändert, Schalter-Logik unberührt, Gruppe bleibt ohne Schalter aus.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Views/AccountSection.swift:70
  Evidence: eigener iOS-Test-Build und mac-build grün, 0 Warnungen; catalog-Skript OK; generate hinterlässt keinen Quell-Diff; keine neuen Texte.
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsUITests/AccountSettingsTests.swift:208
  Description: Der Test nimmt nach waitForExistence(5) einen Snapshot; vergehen auf einem sehr langsamen Runner mehr als 15 s zwischen Tippen und Snapshot, existiert die Fortschrittszeile nicht mehr und der Test wird rot (Flake, nie falsch-grün). Der Kommentar am Testkopf (Zeile 197) nennt noch "2 s" statt 15 s.
  Spec requirement: AC-3 — Zwischenstand sichtbar prüfen
  Conflict: Reserve von rund 5 s bei beobachteten 10 s CI-Verzug; kein Spec-Verstoß, nur Robustheit und veralteter Kommentar.
  Remediation: Kommentar auf 15 s ändern; bei weiterem Flake Verzögerung erhöhen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsUITests/AccountSettingsTests.swift:221
  Description: Der Zweit-Tap geht per Koordinate an die Stelle des Knopfes. Endet die Anmeldung zwischen Snapshot und Tap, träfe er die Zeile, die dann dort steht (z. B. Abmelden). Der Test würde dann rot, nie falsch-grün; bei 15 s Verzögerung praktisch ausgeschlossen.
  Spec requirement: AC-2/AC-3 — ein weiteres Tippen ändert nichts
  Conflict: Wirkungsbeweis schwach (accountHint != retryLater fast wirkungslos), tragend ist isEnabled == false.
  Remediation: Keine Pflicht.

### Runde 2
**Adversary:** Gezielter Angriff auf die Nachbesserung selbst. (a) Ist 15 s nur dort geändert, wo nötig? Diff gegen ee7f14a zeigt im Produktcode nur die Konstante und den Init, keine Logikänderung. (b) Bleibt der Unit-Lauf schnell? Ja, 0,33 s dank Parametrisierung. (c) Andere UI-Tests betroffen? Delay nur mit `--ui-testing-account-slow`; die anderen sieben Tests liefen im frischen Beleg ohne Verzögerung grün. (d) Mutation appleButtonEnabled in signingIn = true färbte laut früherem Protokoll den UI-Test rot; die Nachbesserung ändert daran nichts. (e) AC-5/6/8: Code seit dem früheren Protokoll nicht angefasst, ich habe sie neu gelaufen. (f) Beweislücke aus dem früheren Protokoll (forApp-Test prüft nur != nil) besteht fort, siehe F003. (g) Beleg-Echtheit: simulator-run.txt nennt head 53281f1, basis ee7f14a, 8/8 bestanden, 0 übersprungen, Zeitstempel 13:26 bis 13:30. Kein Befund, der das Verdict kippt.

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Claude/AccountWiring.swift:82
  Evidence: Verzögerung 15 s deckt den Snapshot-Verzug von ca. 10 s plus Reserve; die Testwartezeit von 30 s deckt die Antwort nach 15 s.
  Status: CONFIRMED

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsTests/AccountSectionTests.swift:104
  Description: Der forApp-Teil von AC-6 prüft nur `!= nil`, nicht die Basis-URL des Ersatz-Dienstes (schon im früheren Protokoll vermerkt).
  Spec requirement: AC-6 — forApp nimmt die Fallback-Adresse
  Conflict: Test bliebe auch grün, wenn forApp die rohe Adresse übergäbe; der Code (AccountWiring.swift:48) ruft aber serviceURL(info:).
  Remediation: Keine Pflicht.

**Implementierer:** keine Rückmeldung nötig, keine CRITICAL/HIGH/MEDIUM-Befunde.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: Unit AccountSectionTests 8 bestanden, 0 fehlgeschlagen, 0 übersprungen (eigener Lauf); UI AccountSettingsTests 8/8 bestanden, 0 übersprungen (frischer Beleg); mac-build grün, 0 Warnungen; Katalogskript OK
Edge cases: geprüft, nur LOW-Befunde (F001 bis F003), kein Defekt
Regressions: keine gefunden
Checklist: 8/8 belegt (kein Release-Bau selbst gebaut)

Code reference: LooseEnds/Claude/AccountWiring.swift:82
Code reference: LooseEnds/Views/AccountSection.swift:22

## Geprüfte Dateien

- sha256:dbf8b452cf73c12d06458000c232b6649e476423bc03d232558f1710c64dd42b  LooseEnds/Claude/AccountWiring.swift
- sha256:faf5f30a567b3a531d591fcec804151d8fb2a860925a7b31ea2779d3f765c3fd  LooseEnds/Views/AccountSection.swift
- sha256:15aafb3f27e31084d8e9e35a5b71e2533cc24effa594016a5c771f67b527d209  LooseEndsTests/AccountSectionTests.swift
- sha256:8c7884e61eea2ef7de07ea304a6e902faab0e9a6f4a2101e6616cc798a955191  LooseEndsUITests/AccountSettingsTests.swift

## Prüfbasis

- base: ee7f14a30e96d56e20feb38118e769899bd298d4
- blob:c497fd0505aec7b364b4c4f4ba78bf2c76796d89  LooseEnds/Claude/AccountWiring.swift
- blob:051736d527361016adba49569b922fbd31e91126  LooseEnds/Views/AccountSection.swift
- blob:2bbd69576fd50176918ca274a62891fcb4e3f031  LooseEndsTests/AccountSectionTests.swift
- blob:8a3072f4bac7020ac4db5442146f1700a09de884  LooseEndsUITests/AccountSettingsTests.swift

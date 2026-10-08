# Adversary Dialog — feature-175-cloudkit-produktion
Spec: docs/specs/feat-175-cloudkit-produktion.md
Datum: 2026-10-08 10:37

## Checkliste
- [x] **Normaler Start (mit und ohne Debug, ohne Argument):** unverändert. Die App öffnet den Speicher wie bisher.
- [x] **Start mit `-LEInitializeCloudKitSchema` (Debug, kein Testlauf):** Die App zeigt keine Oberfläche, legt das
- [x] **Unter Tests (`--ui-testing`, XCTest):** Der Initialisierer läuft nie, auch nicht mit Argument.
- [x] **Release-Fassung (TestFlight):** Enthält den Weg nicht.
- [x] **Nach S2 und S3:** Eine Aufgabe, die auf dem iPhone in der TestFlight-Fassung erfasst wird, erscheint auf
- [x] **AC-1:** **Der Initialisierer legt das volle Schema an:** Given das aus `LooseEndsSchema.models` erzeugte Core-Data-Modell / When der Test es prüft / Then enthält es alle sechs Entitäten (TaskItem, TaskContext, Project, Revision, CompletionRecord, SavedView), außerdem die Attribute `placeRemindedAt`, `repeatRule`, `parkedAt`, `sourceURL` an `TaskItem` und die Beziehungen `project` und `parent`. Das ist genau die Lücke aus S0. Beleg: Unit-Test grün.
- [x] **AC-2:** **Der Wegwerf-Speicher berührt nie die echten Daten:** Given der Ort, den der Initialisierer für seinen Store wählt / When der Test ihn prüft / Then liegt er im temporären Verzeichnis, nicht im App-Gruppen-Container (`ModelContainerFactory.appGroup`) und nicht am Speicherort von `ModelContainerFactory`. Beleg: Unit-Test grün.
- [x] **AC-3:** **Die Start-Entscheidung ist eindeutig:** Given `shouldRun(arguments:isDebugBuild:isTestRun:)` / When Argument gesetzt, Debug, kein Testlauf / Then `true`. When das Argument fehlt, oder kein Debug, oder ein Testlauf / Then `false`. Beleg: Unit-Test mit allen acht Kombinationen, grün.
- [x] **AC-4:** **Kein Test spricht mit CloudKit:** Given `CloudKitSchemaInitializerTests` / When die Tests laufen / Then wird weder ein `NSPersistentCloudKitContainer` geöffnet noch `initializeCloudKitSchema` aufgerufen. Beleg: Durchsicht der Testdatei im Diff und voller Lauf `./scripts/sim.sh unit` grün.
- [x] **AC-5:** **Ohne Argument bleibt der Start unverändert:** Given ein Simulator-Start der App ohne das Argument / When sie startet / Then zeigt sie ihre gewohnte Oberfläche (Screenshot, geöffnet und beschrieben), und `git diff` zeigt, dass `ModelContainerFactory.swift` unverändert ist. Beleg: `./scripts/sim.sh build`, `launch`, `screenshot`.
- [x] **AC-6:** **Der Initialisierer schreibt das volle Schema nach Development:** Given der signierte macOS-Debug-Bau (oder Rückfallweg) mit dem Argument / When er läuft / Then endet er mit Exit-Code 0, das Protokoll nennt den Erfolg, und die CloudKit Console zeigt in Development die Typen `CD_TaskItem`, `CD_TaskContext`, `CD_Project`, `CD_Revision`, `CD_CompletionRecord`, `CD_SavedView` (und `CDMR`) mit allen Feldern aus AC-1. Beleg: Console-Screenshot oder `cktool export-schema` in `docs/artifacts/feature-175-cloudkit-produktion/`, im Messprotokoll beschrieben.
- [x] **AC-7:** **Die Lauf-Wege sind nicht Hennings Alltags-App:** Given der Initialisierer-Lauf / When er stattfindet / Then geschieht das nur über `./scripts/sim.sh mac-schema-init` (Mac-Bau der Hauptkennung) oder den Prüfbau `.probe`, nie über Hennings installierte Alltags-App. Beleg: Messprotokoll nennt Bau und Kennung des Laufs.
- [x] **AC-8:** **Production hat nach dem Deploy dasselbe Schema wie Development:** Given Hennings gesonderte Freigabe und der Deploy / When Production und Development verglichen werden / Then stehen dieselben Typen und Felder in beiden. Beleg: Console-Screenshot oder `cktool export-schema --environment production` und `--environment development`, Abgleich im Messprotokoll.
- [x] **AC-9:** **Hennings Daten sind gesichert, bevor installiert wird:** Given Hennings iPhone / When S3 beginnt / Then liegt eine Kopie des App-Gruppen-Speichers (per `devicectl device copy from --domain-type appGroupDataContainer`) auf dem Mac, bevor TestFlight installiert wird. Beleg: Pfad und Dateigröße im Messprotokoll.
- [x] **AC-10:** **O1 ist beantwortet:** Given die TestFlight-Fassung auf iPhone und iPad, Henning hat sie über die Xcode-Fassung installiert / When das iPad geöffnet wird / Then steht im Messprotokoll und im Issue, ob Hennings bestehende Aufgaben dort angekommen sind (ja oder nein, mit Zahl der Aufgaben auf beiden Geräten). Beleg: Screenshots beider Geräte, geöffnet und beschrieben.
- [x] **AC-11:** **Eine Aufgabe auf Gerät A erscheint auf Gerät B:** Given TestFlight auf iPhone und iPad / When auf dem iPhone eine neue Aufgabe mit eindeutigem Text erfasst wird / Then erscheint sie auf dem iPad. Beleg: Screenshots beider Geräte mit dem Text, Zeitstempel im Messprotokoll. Eine Sichtbarkeit nur auf demselben Gerät zählt nicht.
- [x] **AC-12:** **Ist O1 negativ, liegt ein Issue für den Umzug vor:** Given O1 = nein / When #175 abschließt / Then existiert ein eigenes GitHub-Issue mit den Alternativen Neustart in Production und Export/Import. Given O1 = ja / Then entfällt das Issue, und das Messprotokoll nennt das. Beleg: Issue-Nummer im Messprotokoll.
- [x] **AC-13:** **Die Doku ist nachgezogen:** Given `docs/reference/testflight.md` und `CLAUDE.md` / When sie gelesen werden / Then nennen beide: Production nur additiv, Initialisierer plus Deploy vor jedem TestFlight-Bau mit Modelländerung, und wie der Initialisierer gestartet wird. Beleg: Diff beider Dateien.
- [x] **AC-14:** **Folgetickets sind angelegt:** Given der Abschluss von #175 / When `gh issue list` läuft / Then gibt es ein Issue zur Schutzschranke (Schema-Abbild im Repo, Test „Modell = Abbild“, Prüfung in `testflight.yml` per `cktool`, R11) und ein Issue zu den Kontext-Dubletten in Production (#157/#163). Beleg: Issue-Nummern im Messprotokoll.
- [x] **AC-15:** **Regression:** Given `./scripts/sim.sh unit` / Then bleiben alle bestehenden Tests grün, `ModelContainerFactoryTests` unverändert.

## Dialog

### Runde 1
**Adversary:** Versuch, jeden Punkt zu widerlegen. Eigener voller Lauf `./scripts/sim.sh generate && ./scripts/sim.sh unit` (Ausgabe `docs/artifacts/feature-175-cloudkit-produktion/adversary-test-output.txt`): "Test Succeeded", 0 Fehler, Suite "CloudKit schema initializer (#175)" 5 Tests grün (Zeile 74-80), 440 Häkchen, kein übersprungener Test. Überschriebener Messbericht `docs/reference/date-title-fidelity.md` per Checkout zurückgesetzt. Zusätzlich selbst gebaut: iOS-App in Release (generic iOS Simulator) BUILD SUCCEEDED, LooseEndsWatch Debug BUILD SUCCEEDED (Shared/ kompiliert auch dort mit dem Initialisierer unter DEBUG). `mac-schema-init` NICHT ausgeführt.

Confirmation:
  AC: Erwartet 1 (normaler Start)
  Code reference: LooseEnds/App/LooseEndsApp.swift:13
  Evidence: Aufruf nur unter `#if DEBUG` und `guard shouldRun(...)`; ohne Argument kehrt die Funktion sofort zurück, `ModelContainerFactory.make()` folgt unverändert. Der gestagte Diff enthält ModelContainerFactory.swift nicht.
  Status: CONFIRMED

Confirmation:
  AC: Erwartet 2 und AC-6/AC-7
  Code reference: Shared/Persistence/CloudKitSchemaInitializer.swift:48
  Evidence: run() baut eigenen NSPersistentCloudKitContainer auf Wegwerf-Store, ruft initializeCloudKitSchema, Fehler werden geworfen, App beendet mit exit(0)/exit(1) (LooseEndsApp.swift:32-45), kein Fenster. Stores werden vor dem Löschen gelöst (Zeile 56/77, Arbeitsstand geprüft). `docs/artifacts/feature-175-cloudkit-produktion/s1-mac-schema-init-2.txt`: Exit 0, null Core-Data-Fehler; erster Lauf `docs/artifacts/feature-175-cloudkit-produktion/s1-mac-schema-init.txt` hatte ANSCKEVENT/6922-Fehler, Korrektur belegt. Bild `docs/artifacts/feature-175-cloudkit-produktion/s1-development-record-types.jpg` geöffnet: CDMR 9, CD_CompletionRecord 13, CD_Project 16, CD_Revision 23, CD_SavedView 19, CD_TaskContext 14, CD_TaskItem 74, Users 7. Lauf war Mac-Bau der Hauptkennung (Messprotokoll S1), nicht Alltags-App.
  Status: CONFIRMED

Confirmation:
  AC: Erwartet 3 und AC-3, AC-4
  Code reference: Shared/Persistence/CloudKitSchemaInitializer.swift:24
  Evidence: shouldRun = Argument && Debug && !Test; im App-Aufruf ist isTestRun = isRunningTests || isUITesting (LooseEndsApp.swift:33). Testdatei hat keinen NSPersistentCloudKitContainer und kein initializeCloudKitSchema (Suche in LooseEndsTests leer).
  Status: CONFIRMED

Confirmation:
  AC: Erwartet 4 (Release enthält den Weg nicht)
  Code reference: Shared/Persistence/CloudKitSchemaInitializer.swift:1
  Evidence: ganze Datei in `#if DEBUG` (Zeile 1 bis Dateiende); Aufruf und Funktion in LooseEndsApp.swift:13 und :29 ebenfalls. Release-Bau der iOS-App selbst gebaut: erfolgreich.
  Status: CONFIRMED

Confirmation:
  AC: AC-1, AC-2, AC-3
  Code reference: LooseEndsTests/CloudKitSchemaInitializerTests.swift:28
  Evidence: Tests prüfen alle sechs Entitäten und die Felder placeRemindedAt, repeatRule, parkedAt, sourceURL, Beziehungen project/parent; Scratch-Store im temporaryDirectory und nicht im App-Gruppen-Container oder Application Support; startDecision (Zeile 46) deckt 2x2 Kombinationen mit und ohne Argument = 8 Fälle ab. Alle grün im eigenen Lauf.
  Status: CONFIRMED

Confirmation:
  AC: AC-7 (Skript), AC-6 Exit-Code
  Code reference: scripts/sim.sh:196
  Evidence: cmd_mac_schema_init bricht bei xcodebuild-Fehler ab (rc aus PIPESTATUS), reicht Exit-Code des Programms durch; bestehende Befehle unverändert (Diff), nur Hilfezeilen 3,31 angepasst.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: docs/artifacts/feature-175-cloudkit-produktion/ac5-simulator-start.png
  Evidence: Bild geöffnet: iPhone-Simulator 08:42, gewohnte Startansicht "1 zum Durchsehen, nichts vorgemerkt", Listen Als nächstes/Neu 1/Fällig 1/Schnell 1, Projekte, Kontexte 6, Erledigt; keine leere oder Schema-Oberfläche.
  Status: CONFIRMED

Confirmation:
  AC: AC-8, AC-9 (Messprotokoll)
  Code reference: docs/artifacts/feature-175-cloudkit-produktion/s2-production-record-types.jpg
  Evidence: Bild geöffnet: Production zeigt exakt dieselben acht Typen mit denselben Feldzahlen wie Development, Schema gesperrt, Deploy ausgegraut. Sicherung AC-9: Pfad ~/Documents/LooseEnds-Sicherung-2026-10-08, 2,0 MB, LooseEnds.store 598 016 B im Messprotokoll S3.
  Status: CONFIRMED

Confirmation:
  AC: AC-10, AC-11, AC-12
  Code reference: docs/artifacts/feature-175-cloudkit-produktion/s4-ipad-neu-abgleich-1031.png
  Evidence: Drei Fotos geöffnet. iPhone 10:29 und iPad 10:29: identische Zahlen (Als nächstes 1, Neu 1, Fällig 1, Schnell 2, Projekte 1, Kontexte 13, Erledigt 6) und gleiche Aufgabe "Termin beim Hautarzt für OP"; iPad 10:31: Neu 2 mit "Abgleichtest 175 Kaktus gießen" (30 Min.). iPad war vorher ohne Installation, also kam alles über Production. O1 = ja, kein Umzugsticket nötig.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: scripts/sim.sh:190
  Evidence: Der gestagte Doku-Diff zeigt Abschnitt 5a und Ship-Absatz mit Befehl, Argument, LOOSEENDS_REGISTER, Rückfallweg, additiv-only und Deploy-Schritt; deckt sich mit dem Skript.
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: docs/artifacts/feature-175-cloudkit-produktion/messprotokoll.md
  Evidence: `gh issue list` bestätigt #268 Schutzschranke, #269 Kontext-Dubletten, #274 Spracheingabe als eigene Tickets.
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: docs/artifacts/feature-175-cloudkit-produktion/adversary-test-output.txt
  Evidence: Voller Unit-Lauf grün, kein bestehender Test rot; ModelContainerFactory.swift ungeändert.
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: docs/artifacts/feature-175-cloudkit-produktion/messprotokoll.md:1
  Description: AC-10 verlangt "Zahl der Aufgaben auf beiden Geräten". Das Protokoll nennt 18 Aufgaben (12 offen) nur aus der Sicherung. Die Fotos zeigen nur Teilmengen (Als nächstes 1, Neu 1, Fällig 1, Schnell 2, Erledigt 6); die 11 aktiven Aufgaben sind auf keinem Foto sichtbar, ein Gesamtzähler pro Gerät fehlt.
  Spec requirement: AC-10 — Zahl der Aufgaben auf beiden Geräten, Screenshots geöffnet und beschrieben
  Conflict: Die Gleichheit der Listenzähler und der 6 erledigten stützt "ja", beweist aber nicht 18 = 18.
  Remediation: Im Protokoll den Satz "Gesamtzahl nicht fotografiert; Beleg sind Listenzähler, 6 Erledigte und die identische Aufgabe" ergänzen, oder eine Ansicht mit allen Aufgaben auf beiden Geräten nachfotografieren.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: docs/artifacts/feature-175-cloudkit-produktion/s4-iphone-start-1029.png
  Description: Beide Geräte zeigen 13 Kontexte, die Sicherung hatte 7 (Simulator 6). Mögliche Dubletten durch das Zusammenführen zweier Geräte in Production.
  Spec requirement: AC-14 — Kontext-Dubletten als Folgeticket
  Conflict: Kein Verstoß gegen #175, aber ein Folgeeffekt; durch #269 abgedeckt.
  Remediation: In #269 klären (mergeDuplicateContexts, #157/#163).

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEndsTests/CloudKitSchemaInitializerTests.swift:7
  Description: Die Testdatei steht nicht unter `#if DEBUG`, verwendet aber CloudKitSchemaInitializer, das nur in Debug existiert. Ein Test-Lauf in Release würde nicht kompilieren.
  Spec requirement: Erwartet 4 — Release enthält den Weg nicht
  Conflict: Heute läuft die Test-Konfiguration in Debug (unit grün); latente Fehlerquelle, falls je Release getestet wird.
  Remediation: Testdatei in `#if DEBUG` einfassen.

**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Tiefer nachgebohrt an den Randfällen. (a) Argument im Testlauf: shouldRun liefert false, isRunningTests liest XCTestConfigurationFilePath (ModelContainerFactory.swift:40), isUITesting zusätzlich; der Aufruf läuft nur in LooseEndsApp.init(), Unit-Tests starten die App-Struktur nicht. (b) Ohne Berechtigung/Netz: loadError und initializeCloudKitSchema werfen, der Aufrufer loggt und beendet mit 1; kein stilles Verschlucken, `defer` räumt Store und Ordner auch im Fehlerfall. (c) Leeres Modell: guard wirft emptyModel, kein Teilschema. (d) Race mit dem Normalstart: exit() erfolgt vor ModelContainerFactory.make(), der App-Gruppen-Store wird nie geöffnet; Wegwerf-Pfad pro Lauf mit UUID. (e) Release/Watch/Widgets: Release iOS und Watch Debug kompilieren (selbst gebaut). (f) Production nach Deploy: Console-Bild zeigt Gleichheit, gesperrt, additiv. (g) Wiederholter Lauf laut Protokoll unschädlich (zweiter Lauf, Schema unverändert). Ergebnis: keine neue Abweichung außer F001-F003; keiner blockiert.
**Implementierer:** (nicht beteiligt, Kontextisolation)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

Tests: voller Unit-Lauf grün (Test Succeeded, 0 Fehler, 0 übersprungen). Edge cases: geprüft, keine kaputt. Regressions: keine. Checklist: alle Punkte belegt; F001 (MEDIUM, Protokolllücke AC-10), F002/F003 (LOW) nicht blockierend.

## Geprüfte Dateien

- sha256:bf67de0f9223f9d5c5386c22f427d9daa22b5493313d6396a3d5ea261d25d8d8  LooseEnds/App/LooseEndsApp.swift
- sha256:9a7c7d35e1c89ceb51c3a5d9f78bb16309eb92e22f5cfde016c37dd23cf4d43c  LooseEndsTests/CloudKitSchemaInitializerTests.swift
- sha256:ad4d3755c572de86c195802efefef82528d9c412be60398d152e6e487b8f0b3a  Shared/Persistence/CloudKitSchemaInitializer.swift
- sha256:9b13d703ec85ae7d7ecec290b909b33afef5d15d0c4df91b50216de83fe37e1d  docs/artifacts/feature-175-cloudkit-produktion/ac5-simulator-start.png
- sha256:3ecae5e3ca94fe93cedf4f238e5a34cc2ec8f98460801251182f2853ab356a52  docs/artifacts/feature-175-cloudkit-produktion/adversary-test-output.txt
- sha256:09a0a23115df13387a755c99b485aadb367e3852d8bf534899ac777a324b2f4c  docs/artifacts/feature-175-cloudkit-produktion/messprotokoll.md
- sha256:a67f5f03ba30450c8bf701ccf7c3c13f8659e153cedae6351713ae52172b0a2d  docs/artifacts/feature-175-cloudkit-produktion/s2-production-record-types.jpg
- sha256:5972234659976cd6676d86a0ff4734b11bbb21bdfe6c45d6d5d1ab2bb3352a2c  docs/artifacts/feature-175-cloudkit-produktion/s4-ipad-neu-abgleich-1031.png
- sha256:1a1260c7cbf4989fd31ee6f570a6714ef4c793246666a23ac74651e35c7af7dd  docs/artifacts/feature-175-cloudkit-produktion/s4-iphone-start-1029.png
- sha256:eaf19aaf3ad3bd10d57331b532bb9d88dcbadfef89f541eb8baef1f72530ec8a  scripts/sim.sh

## Prüfbasis

- base: 35b2863ab11a96e7a0ae4916c3d09c86ca7c8c9d
- blob:45fa1af4ae26ee964199cee29a8c511ea25a882d  LooseEnds/App/LooseEndsApp.swift
- blob:0bfe5de60575a3802bc3f11d3401eae4d55ba2ca  LooseEndsTests/CloudKitSchemaInitializerTests.swift
- blob:b1b97e480d162a1ec352d269a39d8c3e673c54c2  Shared/Persistence/CloudKitSchemaInitializer.swift
- blob:c6b8d90e9d8d5006b594d352237e4bb99c06c89f  docs/artifacts/feature-175-cloudkit-produktion/ac5-simulator-start.png
- blob:4a9fe3a479782f112afc3d07cefbd632ba77930d  docs/artifacts/feature-175-cloudkit-produktion/adversary-test-output.txt
- blob:2d760ed3718e89d460a8c52c65e1d03e7cf678b1  docs/artifacts/feature-175-cloudkit-produktion/messprotokoll.md
- blob:df11c8665c2bb09a89e5890800e467331b2d175d  docs/artifacts/feature-175-cloudkit-produktion/s2-production-record-types.jpg
- blob:21bfaf48b0e063318ba871dd2f3a95b79c0aac24  docs/artifacts/feature-175-cloudkit-produktion/s4-ipad-neu-abgleich-1031.png
- blob:40fbc68ffdf13177a04a3d6cf16805987c412c93  docs/artifacts/feature-175-cloudkit-produktion/s4-iphone-start-1029.png
- blob:ddaaf628d3c3ac9c47f6e749be55ddc2c9394284  scripts/sim.sh

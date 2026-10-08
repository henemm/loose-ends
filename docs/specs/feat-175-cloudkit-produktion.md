---
entity_id: feat-175-cloudkit-produktion
type: feature
created: 2026-10-08
updated: 2026-10-08
status: draft
workflow: feature-175-cloudkit-produktion
---

# Spec: #175 CloudKit-Produktion — Schema vollständig anlegen, ausrollen, Abgleich auf zwei Geräten belegen

## Approval

- [ ] Approved (Henning)

## Purpose

Die TestFlight-Fassung soll zwischen iPhone und iPad abgleichen. Heute kann sie das nicht: Production
(CloudKit-Bereich der TestFlight-Fassung) enthält **keinen einzigen App-Typ** (Messprotokoll S0). Das Schema
wurde nie ausgerollt. Ohne Schema lehnt Production Lesen und Schreiben ab, die Daten blieben nur lokal.

Der Ausgangsbefund aus S0 bestimmt den Schnitt. Auch der Bereich Development ist lückenhaft: Es fehlen die
Typen `Project`, `CompletionRecord` und `SavedView` ganz, bei `TaskItem` 11 Felder (u. a. `placeRemindedAt`,
`repeatRule`, `parkedAt`, `sourceURL`, Verweise `project`, `parent`). Ursache: Development legt Typen und
Felder nur an, wenn ein Datensatz sie mit einem Wert schreibt. Ein Deploy von heute brächte dieses
Teil-Schema nach Production, und die TestFlight-Fassung scheiterte an jedem fehlenden Feld, sobald es den
ersten Wert bekommt.

Deshalb dieser Ablauf, in dieser Reihenfolge:

1. **S1 (Code):** Ein kleiner Initialisierer legt das **volle** Schema aus dem Modell in Development an
   (`initializeCloudKitSchema`).
2. **S2 (Betrieb, Hennings Konto):** „Deploy Schema Changes“ in der CloudKit Console.
3. **S3 (Betrieb):** Speicher sichern, neuen TestFlight-Lauf, Henning installiert über die Xcode-Fassung.
4. **S4 (Betrieb):** Messen, ob Hennings bestehende Aufgaben auf dem iPad ankommen (O1), und den Abgleich
   iPhone → iPad belegen.
5. **S6 (Doku):** Festhalten, dass Production ab Deploy nur noch additiv ist und was vor jedem
   TestFlight-Bau mit Modelländerung zu tun ist.

Ohne Modell: Es ist keines im Spiel, der Regelweg ist der einzige Weg.

**Zuschnitt:** Code 4 Dateien (Initialisierer, `LooseEndsApp.swift`, Test, `scripts/sim.sh`) mit rund 170–220 Zeilen, dazu
Doku in 2 Dateien (rund 40 Zeilen) und das Messprotokoll. Das passt in die Grenzen (4–5 Dateien, ±250
Zeilen). **Eigene Tickets, nicht Teil dieser Spec:** S5 (Schutzschranke gegen Schema-Abweichung) und
„Kontext-Dubletten in Production ansehen“ (nach S4). Ein eventueller Datenumzug (falls O1 negativ ist)
wird ebenfalls in einem eigenen Ticket entschieden.

## Source

- **Neu:** `Shared/Persistence/CloudKitSchemaInitializer.swift` — `enum CloudKitSchemaInitializer`, nur unter
  `#if DEBUG`. Baut aus `LooseEndsSchema.models` ein Core-Data-Modell, öffnet einen
  `NSPersistentCloudKitContainer` mit einem Store an einem Wegwerf-Ort und ruft
  `initializeCloudKitSchema(options: [])`.
- **Geändert:** `LooseEnds/App/LooseEndsApp.swift` — Startargument `-LEInitializeCloudKitSchema` wird
  **vor** `ModelContainerFactory.make` ausgewertet.
- **Neu:** `LooseEndsTests/CloudKitSchemaInitializerTests.swift`
- **Neu (Betrieb, gehört zur Spec als Beleg):** Ergänzungen in
  `docs/artifacts/feature-175-cloudkit-produktion/messprotokoll.md` (S1-Lauf, S2, S3, S4)
- **Geändert:** `scripts/sim.sh` — neuer Befehl `mac-schema-init` (signierter Mac-Bau, Start mit dem Argument)
- **Geändert (Doku, S6):** `docs/reference/testflight.md`, `CLAUDE.md`
- **Unverändert, nur gelesen:** `Shared/Persistence/ModelContainerFactory.swift`
  (`LooseEndsSchema.models`, Lesart von `LECloudContainer`, `isRunningTests`, `isUITesting`),
  `project.yml`, `.github/workflows/testflight.yml`

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `LooseEndsSchema.models` | Eingabe | Das Schema aus dem Modell (TaskItem, TaskContext, Project, Revision, CompletionRecord, SavedView). Der Initialisierer legt genau dieses an, nicht mehr und nicht weniger. |
| `ModelContainerFactory.resolveIdentifiers`, `isRunningTests`, `isUITesting` | Wiederverwendung, unverändert | Gleiche Lesart des Containers aus `Info.plist` (`LECloudContainer`); gleiche Testerkennung. Der Initialisierer ruft **nie** `ModelContainerFactory.make` auf. |
| `NSManagedObjectModel.makeManagedObjectModel(for:)` | Systemschnittstelle | Erzeugt aus den SwiftData-Typen ein Core-Data-Modell. |
| `NSPersistentCloudKitContainer.initializeCloudKitSchema(options:)` | Systemschnittstelle | Apples eigener Weg, das Schema in Development vollständig anzulegen (R10). SwiftData hat dafür keine eigene Schnittstelle. |
| CloudKit Console | Betrieb | Deploy nach Production (R3: nur dort möglich), Ablesen beider Umgebungen. |
| `cktool` (`xcrun`) | Betrieb, nur Rückfallweg | `export-schema` / `import-schema` mit Management-Token. |
| `devicectl` | Betrieb | Sicherung des App-Gruppen-Speichers (nur lesend). |
| `.github/workflows/testflight.yml` | Betrieb | Neuer TestFlight-Lauf vom aktuellen `main`. |

## Implementation Details

### S1 — Schema-Initialisierer

**Warum ein eigener Speicherort:** `ModelContainerFactory` hält den Container je Prozess einmal
(`ProcessCache`, #50). CloudKit verbietet einen zweiten lebenden Spiegel für denselben Store im selben
Prozess. Der Initialisierer öffnet deshalb **nie** den App-Gruppen-Speicher und geht **nie** durch die Fabrik,
sondern arbeitet an einem eigenen Wegwerf-Store.

Ablauf in `CloudKitSchemaInitializer.run()` (nur `#if DEBUG`):

1. Container-Name aus `Bundle.main.infoDictionary["LECloudContainer"]` lesen (über
   `ModelContainerFactory.resolveIdentifiers`, gleiche Lesart; ein fehlender Schlüssel wird dort bereits
   protokolliert).
2. Modell bauen: `NSManagedObjectModel.makeManagedObjectModel(for: LooseEndsSchema.models)`.
3. Wegwerf-Ort: ein neues Unterverzeichnis im temporären Verzeichnis
   (`FileManager.default.temporaryDirectory`, Name mit UUID). Nie der App-Gruppen-Container.
4. `NSPersistentCloudKitContainer` mit **einer** `NSPersistentStoreDescription` an diesem Ort,
   `cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: <Container>)`.
5. Stores laden (`loadPersistentStores`, Ergebnis abwarten, Fehler weiterreichen).
6. `try container.initializeCloudKitSchema(options: [])`.
7. Den Wegwerf-Ordner entfernen (auch im Fehlerfall; ein Fehler beim Entfernen wird per `Logger` gemeldet,
   nicht geschluckt).
8. Erfolg und Fehler per `Logger` (Subsystem `com.henning.looseends`, Kategorie `Persistence`) melden. Kein
   `print`, kein `try?`, das einen Fehler verschluckt.

Die Funktion ist als `throws` gebaut; der Aufrufer entscheidet den Beendigungscode.

**Start-Entscheidung als reine Funktion:**

```swift
static func shouldRun(arguments: [String], isDebugBuild: Bool, isTestRun: Bool) -> Bool
```

Liefert `true` genau dann, wenn `-LEInitializeCloudKitSchema` in `arguments` steht, `isDebugBuild` wahr ist
und `isTestRun` falsch ist. `isTestRun` ist `ModelContainerFactory.isRunningTests ||
ModelContainerFactory.isUITesting`.

**Auslöser in `LooseEndsApp.swift`:** Vor dem Aufruf von `ModelContainerFactory.make()` wird
`shouldRun(…)` gefragt. Ist es wahr, läuft nur der Initialisierer. Danach beendet sich der Prozess mit
Exit-Code 0 (Erfolg) oder 1 (Fehler), ohne den App-Gruppen-Speicher zu öffnen und ohne Oberfläche. Ohne das
Argument bleibt der Start unverändert. Die Release-Fassung enthält den Weg nicht (`#if DEBUG`).

### Ausführungsort (Entscheidung des Tech Leads, Henning tippt nichts)

- **Erstweg:** signierter macOS-Debug-Bau der Hauptkennung auf diesem Mac (der Mac ist mit Hennings iCloud
  angemeldet). Gestartet mit dem Argument schreibt er in Development von `iCloud.com.henning.looseends`.
  `./scripts/sim.sh mac-build` baut nur unsigniert. Laut CLAUDE.md läuft jeder Bau über `scripts/sim.sh`,
  nie direkt über `xcodebuild`. Deshalb kommt ein neuer Befehl `./scripts/sim.sh mac-schema-init` dazu. Er
  baut signiert für `platform=macOS` mit Team `XK87E2B3VR` (eigener DerivedData-Ort, Hauptkennung, kein
  `BUNDLE_ID_SUFFIX`) und startet das gebaute Programm mit `-LEInitializeCloudKitSchema`. Der Rückgabewert
  kommt vom Programm selbst, nicht von einer Pipe (Lehre aus #144). Für das erste Profil gilt dieselbe Regel
  wie beim Gerätebau: Nur ein Registrierungslauf (`LOOSEENDS_REGISTER=1`) darf `-allowProvisioningUpdates`
  und damit Hennings Xcode-Anmeldung benutzen.
- **Rückfallweg**, falls Mac-Signierung oder Berechtigung scheitert: Prüfbau (`.probe`, Gerätebau über
  `./scripts/sim.sh device-build`) auf dem iPhone mit dem Argument. Der Initialisierer schreibt dann in
  Development des **Probe-Containers**. Danach `cktool export-schema` aus Probe-Development und
  `cktool import-schema` nach Haupt-Development (Management-Token in Hennings Chrome anlegen, Henning hat das
  erlaubt). Die Typnamen sind identisch, weil das Modell dasselbe ist.
- **Nie:** Hennings Alltags-Installation, weder mit dem Argument noch sonst.

### S2 — Deploy

„Deploy Schema Changes“ in der CloudKit Console ist ein Vorgang an Hennings Konto. Er wird **getrennt** von
Henning freigegeben, nicht mit dieser Spec. Vorher stehen der Development-Stand nach S1 und der Production-Stand
nebeneinander im Messprotokoll. Nach dem Deploy zeigt Production dieselben Typen und Felder wie Development
(Console-Screenshot oder `cktool export-schema` beider Umgebungen).

### S3 — Sicherung und TestFlight

1. Vor der Überinstallation wird der App-Gruppen-Speicher von Hennings iPhone mit
   `devicectl device copy from --domain-type appGroupDataContainer` auf den Mac gesichert (nur lesend).
2. Neuer TestFlight-Lauf vom aktuellen `main` (der Lauf vom 2026-10-04, Stand `723f3cd`, kennt die
   Ort-Felder nicht).
3. Henning installiert TestFlight **über** die Xcode-Fassung, nie löschen (R8: Löschen vernichtet den
   lokalen Stand).

### S4 — Messung und Nachweis

Zweites Gerät ist Hennings **iPad** mit derselben TestFlight-Fassung (Henning, 2026-10-08).

- **O1:** Erscheinen Hennings bestehende Aufgaben auf dem iPad? Ergebnis (ja/nein, mit Zahl) kommt ins
  Messprotokoll und ins Issue.
- **Sync-Nachweis:** Eine neue Aufgabe, auf dem iPhone erfasst, erscheint auf dem iPad (Bild und
  Protokoll). Wichtig (R9): Sichtbarkeit auf demselben Gerät beweist nichts, nur das zweite Gerät zählt.
- Ist O1 **negativ**, legt #175 ein **eigenes Issue** für den Datenumzug an (Alternativen: Neustart in
  Production = Empfehlung laut Issue, oder Export/Import). Das hält #175 nicht auf.

### S6 — Doku

`docs/reference/testflight.md` und `CLAUDE.md` halten fest:

- Production ist ab dem Deploy **nur additiv** (R4): nichts löschen, nichts umbenennen.
- Vor jedem TestFlight-Bau mit Modelländerung: Initialisierer laufen lassen, dann Deploy.
- Wie der Initialisierer gestartet wird (Argument, Erstweg, Rückfallweg).

## Expected Behavior

- **Normaler Start (mit und ohne Debug, ohne Argument):** unverändert. Die App öffnet den Speicher wie bisher.
  Es ist keine Änderung sichtbar.
- **Start mit `-LEInitializeCloudKitSchema` (Debug, kein Testlauf):** Die App zeigt keine Oberfläche, legt das
  volle Schema in Development an, protokolliert das Ergebnis und beendet sich mit 0 (Erfolg) oder 1 (Fehler).
  Der App-Gruppen-Speicher wird nicht geöffnet.
- **Unter Tests (`--ui-testing`, XCTest):** Der Initialisierer läuft nie, auch nicht mit Argument.
- **Release-Fassung (TestFlight):** Enthält den Weg nicht.
- **Nach S2 und S3:** Eine Aufgabe, die auf dem iPhone in der TestFlight-Fassung erfasst wird, erscheint auf
  dem iPad.

## Acceptance Criteria

- **AC-1:** **Der Initialisierer legt das volle Schema an:** Given das aus `LooseEndsSchema.models` erzeugte
  Core-Data-Modell / When der Test es prüft / Then enthält es alle sechs Entitäten (TaskItem, TaskContext,
  Project, Revision, CompletionRecord, SavedView), außerdem die Attribute `placeRemindedAt`, `repeatRule`,
  `parkedAt`, `sourceURL` an `TaskItem` und die Beziehungen `project` und `parent`. Das ist genau die Lücke
  aus S0. Beleg: Unit-Test grün.
- **AC-2:** **Der Wegwerf-Speicher berührt nie die echten Daten:** Given der Ort, den der Initialisierer
  für seinen Store wählt / When der Test ihn prüft / Then liegt er im temporären Verzeichnis, nicht im
  App-Gruppen-Container (`ModelContainerFactory.appGroup`) und nicht am Speicherort von
  `ModelContainerFactory`. Beleg: Unit-Test grün.
- **AC-3:** **Die Start-Entscheidung ist eindeutig:** Given `shouldRun(arguments:isDebugBuild:isTestRun:)` /
  When Argument gesetzt, Debug, kein Testlauf / Then `true`. When das Argument fehlt, oder kein Debug, oder
  ein Testlauf / Then `false`. Beleg: Unit-Test mit allen acht Kombinationen, grün.
- **AC-4:** **Kein Test spricht mit CloudKit:** Given `CloudKitSchemaInitializerTests` / When die Tests laufen /
  Then wird weder ein `NSPersistentCloudKitContainer` geöffnet noch `initializeCloudKitSchema` aufgerufen.
  Beleg: Durchsicht der Testdatei im Diff und voller Lauf `./scripts/sim.sh unit` grün.
- **AC-5:** **Ohne Argument bleibt der Start unverändert:** Given ein Simulator-Start der App ohne das Argument /
  When sie startet / Then zeigt sie ihre gewohnte Oberfläche (Screenshot, geöffnet und beschrieben), und
  `git diff` zeigt, dass `ModelContainerFactory.swift` unverändert ist. Beleg: `./scripts/sim.sh build`,
  `launch`, `screenshot`.
- **AC-6:** **Der Initialisierer schreibt das volle Schema nach Development:** Given der signierte
  macOS-Debug-Bau (oder Rückfallweg) mit dem Argument / When er läuft / Then endet er mit Exit-Code 0, das
  Protokoll nennt den Erfolg, und die CloudKit Console zeigt in Development die Typen `CD_TaskItem`,
  `CD_TaskContext`, `CD_Project`, `CD_Revision`, `CD_CompletionRecord`, `CD_SavedView` (und `CDMR`) mit allen
  Feldern aus AC-1. Beleg: Console-Screenshot oder `cktool export-schema` in
  `docs/artifacts/feature-175-cloudkit-produktion/`, im Messprotokoll beschrieben.
- **AC-7:** **Die Lauf-Wege sind nicht Hennings Alltags-App:** Given der Initialisierer-Lauf / When er
  stattfindet / Then geschieht das nur über `./scripts/sim.sh mac-schema-init` (Mac-Bau der Hauptkennung) oder den Prüfbau `.probe`, nie über
  Hennings installierte Alltags-App. Beleg: Messprotokoll nennt Bau und Kennung des Laufs.
- **AC-8:** **Production hat nach dem Deploy dasselbe Schema wie Development:** Given Hennings gesonderte
  Freigabe und der Deploy / When Production und Development verglichen werden / Then stehen dieselben Typen
  und Felder in beiden. Beleg: Console-Screenshot oder `cktool export-schema --environment production` und
  `--environment development`, Abgleich im Messprotokoll.
- **AC-9:** **Hennings Daten sind gesichert, bevor installiert wird:** Given Hennings iPhone / When S3 beginnt
  / Then liegt eine Kopie des App-Gruppen-Speichers (per `devicectl device copy from --domain-type
  appGroupDataContainer`) auf dem Mac, bevor TestFlight installiert wird. Beleg: Pfad und Dateigröße im
  Messprotokoll.
- **AC-10:** **O1 ist beantwortet:** Given die TestFlight-Fassung auf iPhone und iPad, Henning hat sie über
  die Xcode-Fassung installiert / When das iPad geöffnet wird / Then steht im Messprotokoll und im Issue, ob
  Hennings bestehende Aufgaben dort angekommen sind (ja oder nein, mit Zahl der Aufgaben auf beiden
  Geräten). Beleg: Screenshots beider Geräte, geöffnet und beschrieben.
- **AC-11:** **Eine Aufgabe auf Gerät A erscheint auf Gerät B:** Given TestFlight auf iPhone und iPad / When
  auf dem iPhone eine neue Aufgabe mit eindeutigem Text erfasst wird / Then erscheint sie auf dem iPad.
  Beleg: Screenshots beider Geräte mit dem Text, Zeitstempel im Messprotokoll. Eine Sichtbarkeit nur auf
  demselben Gerät zählt nicht.
- **AC-12:** **Ist O1 negativ, liegt ein Issue für den Umzug vor:** Given O1 = nein / When #175 abschließt /
  Then existiert ein eigenes GitHub-Issue mit den Alternativen Neustart in Production und Export/Import.
  Given O1 = ja / Then entfällt das Issue, und das Messprotokoll nennt das. Beleg: Issue-Nummer im
  Messprotokoll.
- **AC-13:** **Die Doku ist nachgezogen:** Given `docs/reference/testflight.md` und `CLAUDE.md` / When sie
  gelesen werden / Then nennen beide: Production nur additiv, Initialisierer plus Deploy vor jedem
  TestFlight-Bau mit Modelländerung, und wie der Initialisierer gestartet wird. Beleg: Diff beider Dateien.
- **AC-14:** **Folgetickets sind angelegt:** Given der Abschluss von #175 / When `gh issue list` läuft / Then
  gibt es ein Issue zur Schutzschranke (Schema-Abbild im Repo, Test „Modell = Abbild“, Prüfung in
  `testflight.yml` per `cktool`, R11) und ein Issue zu den Kontext-Dubletten in Production (#157/#163).
  Beleg: Issue-Nummern im Messprotokoll.
- **AC-15:** **Regression:** Given `./scripts/sim.sh unit` / Then bleiben alle bestehenden Tests grün,
  `ModelContainerFactoryTests` unverändert.

## Test Plan

`LooseEndsTests/CloudKitSchemaInitializerTests.swift`, Swift Testing wie `ModelContainerFactoryTests`, TDD
RED zuerst.

- **AC-1:** Test baut das Core-Data-Modell aus `LooseEndsSchema.models` und prüft Entitäten, Attribute
  (`placeRemindedAt`, `repeatRule`, `parkedAt`, `sourceURL`) und Beziehungen (`project`, `parent`). Dafür
  wird das Modell über eine kleine interne Funktion (z. B. `makeModel()`) erzeugt, die der Initialisierer
  selbst benutzt, damit der Test das echte Modell prüft und nicht eine Kopie.
- **AC-2:** Test fragt die Funktion ab, die den Wegwerf-Ort liefert, und vergleicht den Pfad mit dem
  temporären Verzeichnis, mit dem App-Gruppen-Container (sofern vorhanden) und mit dem Standardort von
  SwiftData. Der Test legt keinen Store an.
- **AC-3:** Test über die Wahrheitstabelle von `shouldRun` (2 × 2 × 2 Kombinationen, nur eine wahr).
- **AC-4:** Kein Test öffnet einen CloudKit-Container. Das zeigt die Durchsicht der Datei.
- **AC-15:** Voller Lauf `./scripts/sim.sh unit` ist der Beleg, kein eigener Test.
- **UI-Test: keiner.** Es ändert sich nichts Sichtbares: Das Argument wird nur von Hand oder vom
  Betriebsablauf gesetzt, und ein normaler Start sieht aus wie vorher. Stattdessen Stufe 2: Simulator-Start
  ohne Argument zeigt die App unverändert (Screenshot, AC-5).
- **Betriebsbelege (AC-6 bis AC-14)** sind keine Tests, sondern Protokolleinträge mit Bildern oder
  Exporten im Messprotokoll.

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `Shared/Persistence/CloudKitSchemaInitializer.swift` | NEU | `shouldRun`, `makeModel`, Wegwerf-Ort, `run()`; alles unter `#if DEBUG`, kein `try?` das schluckt, `Logger` statt `print`. |
| `LooseEnds/App/LooseEndsApp.swift` | GEÄNDERT | Startargument wird vor `ModelContainerFactory.make` ausgewertet, danach Beenden mit Exit-Code. |
| `LooseEndsTests/CloudKitSchemaInitializerTests.swift` | NEU | Tests zu AC-1 bis AC-3. |
| `scripts/sim.sh` | GEÄNDERT | Befehl `mac-schema-init`: signierter macOS-Bau der Hauptkennung, Start mit `-LEInitializeCloudKitSchema`, Exit-Code des Programms durchreichen. |
| `docs/reference/testflight.md` | GEÄNDERT | S6 |
| `CLAUDE.md` | GEÄNDERT | S6 |
| `docs/artifacts/feature-175-cloudkit-produktion/messprotokoll.md` | ERGÄNZT | S1-Lauf, S2, S3, S4 |

Erwartet: Code rund 170–220 Zeilen (Initialisierer rund 90, App rund 15, Tests rund 70, Skript rund 20), Doku rund 40
Zeilen, keine Funktion über 50 Zeilen. Das Projekt ist generiert: nach den neuen Dateien muss
`./scripts/sim.sh generate` laufen.

### Seiteneffekte (ausdrücklich)

- **Keine neuen Berechtigungen.**
- **Keine Änderung** an `Info.plist` oder `project.yml` oder an Entitlements. `scripts/sim.sh` bekommt nur den neuen Befehl, bestehende Befehle bleiben unverändert.
- **Keine neuen AppStorage- oder UserDefaults-Schlüssel.**
- **Kein Eingriff am Modell:** `TaskItem` und die übrigen Modelle bleiben unverändert, es gibt kein neues
  CloudKit-Feld. Die Änderung betrifft nur, dass das **bestehende** Modell vollständig in der Cloud
  angelegt wird.
- **Schreibt in Hennings CloudKit-Konto:** Der Initialisierer-Lauf legt Typen und Felder in Development an,
  keine Datensätze. Das ist additiv und in Development jederzeit rücksetzbar. Der Deploy in S2 ist dagegen
  endgültig (R4) und wird deshalb getrennt freigegeben.
- **Hennings Alltags-App wird in S3 überinstalliert** (TestFlight über Xcode-Fassung). Die Sicherung nach AC-9
  und die Kopie in Development federn das ab.

### Abnahme

`Shared/Persistence/` steht auf der Geräteliste, **Stufe 3 greift**. Der eigentliche Gerätenachweis ist S4
(TestFlight auf iPhone und iPad, AC-10 und AC-11). Vorher laufen Stufe 1 (Tests) und Stufe 2 (Simulator-Start
ohne Argument, AC-5).

**Nicht in diesem Ticket:**
- S5 (Schutzschranke, eigenes Ticket, AC-14).
- Kontext-Dubletten in Production (eigenes Ticket, AC-14).
- Der Datenumzug, falls O1 negativ ist (eigenes Ticket, AC-12).
- Widgets haben nur die App-Gruppe und keine iCloud-Berechtigung (`project.yml`); das ist ein eigener Befund,
  gehört nicht zu #175.

## Known Limitations

- **Production ist danach nur additiv (R4):** Felder und Typen lassen sich dort nicht löschen oder umbenennen.
  Jede künftige Modelländerung braucht vor dem TestFlight-Bau einen erneuten Lauf des Initialisierers und
  einen Deploy. Bis die Schutzschranke (S5) steht, hängt das an der Doku aus S6, nicht an einer Prüfung.
- **`initializeCloudKitSchema` ist ein Umweg (R10):** Apple bietet für SwiftData keine eigene Schnittstelle.
  Verhält sich der Weg in Xcode 27 anders, zeigt es AC-6; dann greift der Rückfallweg oder ein neuer Befund.
- **Mac-Signierung ist nicht belegt.** Scheitert sie, läuft der Rückfallweg über den Prüfbau und `cktool`.
- **O1 ist offen** und wird erst in S4 beantwortet. R8 spricht eher dagegen, dass die TestFlight-Fassung
  bestehende lokale Aufgaben hochlädt.
- **Push (`aps-environment`) und Abgleich zwischen zwei Geräten** sind nur auf echter Hardware prüfbar. Der
  Nachweis ist S4, nicht der Simulator.
- **Hennings Daten bleiben in Development**, auch nach einem erfolgreichen Abgleich in Production. Development
  bleibt Archiv.

## Alternativen

| | Weg | Dafür | Dagegen |
|---|---|---|---|
| **Diese Spec** | Initialisierer legt das volle Schema in Development an, Deploy, TestFlight, Messung | Apples eigener Generator, Typnamen und Verweise stimmen von selbst, kleiner Code, Release-Fassung enthält ihn nicht | Neuer Betriebsablauf bei jeder Modelländerung (bis S5 steht) |
| A | Xcode-Fassung auf Production stellen (R7) | Henning bleibt bei Xcode, beide Fassungen teilen Daten | Für Xcode 27 unbelegt, jeder Xcode-Lauf mit nicht ausgerolltem Modell schreibt gegen das echte Schema, berührt ADR-2 (Umgebungen getrennt); sinnvoll nur, falls Henning dauerhaft aus Xcode arbeitet (Probe O3 mit `.probe`) |
| B | Einmaliger Umzug per Export/Import | Sicherer Rückweg, falls O1 negativ ist | Eigenes Ticket, rund 200+ Zeilen (alle Felder, Revisionen, Wiederholungen, Kontexte nach Namen) |
| C | Neustart in Production ohne Übernahme | Am billigsten, Development bleibt Archiv | Henning sieht seine Aufgaben nur, solange der lokale Speicher sie hält |
| D | Schema von Hand per `cktool import-schema` schreiben statt Initialisierer | Kein Code im Produkt | **Verworfen:** `CD_`-Namen, Verweise, `CDMR` und Bytes-Felder von Hand sind fehleranfällig; der Apple-eigene Generator ist der Beleg, dass das Schema stimmt |

B und C werden nur relevant, wenn O1 negativ ist, und dann in einem eigenen Ticket entschieden. Keine der
Alternativen kippt eine bestehende ADR; A würde ADR-2 berühren und bräuchte dann eine eigene Entscheidung.

Quellen: Recherche R1–R11 in `docs/artifacts/feature-175-cloudkit-produktion/recherche.md`, darunter
[Forum 771966](https://developer.apple.com/forums/thread/771966),
[Forum 748719](https://developer.apple.com/forums/thread/748719),
[Apple: Using cktool](https://developer.apple.com/icloud/ck-tool/),
[fatbobman: initializeCloudKitSchema](https://fatbobman.com/en/snippet/resolving-incomplete-icloud-data-sync-in-ios-development-using-initializecloudkitschema/).

## ADR

**ADR-Nr.:** keine — Das Ticket setzt die bestehende Trennung der Umgebungen (ADR-2) um und kippt keine
Entscheidung. Eine ADR entstünde erst, wenn Alternative A (Xcode-Fassung auf Production) gewählt würde.

## Definition of Done

- Alle Unit-Tests grün (`./scripts/sim.sh unit`), Build und UI-Smoke der CI grün.
- Der Initialisierer ist gelaufen, Development und Production zeigen nach dem Deploy dasselbe Schema
  (AC-6, AC-8), belegt im Messprotokoll.
- O1 ist beantwortet, eine Aufgabe vom iPhone erscheint auf dem iPad (AC-10, AC-11), mit Bildern.
- Doku nachgezogen (AC-13), Folgetickets angelegt (AC-12, AC-14).
- Der Abschlussbericht benennt, dass Stufe 3 greift und der Gerätenachweis über TestFlight auf zwei Geräten
  geführt wurde.

## Changelog

- 2026-10-08: Entwurf. Aus `docs/context/feature-175-cloudkit-produktion.md` (Slices S0–S6) und dem Ergebnis von
  S0 im Messprotokoll: Development ist lückenhaft, daher S1 (Initialisierer) vor dem Deploy.
- 2026-10-08: Mac-Lauf über neuen Befehl `sim.sh mac-schema-init` statt direktem `xcodebuild` (CLAUDE.md: jeder Bau über `sim.sh`).

---
entity_id: fix-377-mac-abgleich
type: bugfix
created: 2026-10-13
updated: 2026-10-13
status: draft
workflow: fix-377-mac-abgleich
---

# Spec: #377 Schnitt 1 — Mac zeigt andere Aufgaben: Abgleich sichtbar machen, CloudKit am Mac binden

## Approval

- [ ] Approved (Henning)

## Purpose

Henning (Issue #377, 2026-10-12): Die Mac-App zeigt andere Aufgaben als iPhone und iPad (die untereinander stimmen).
„Ein Teil der Aufgaben ist gleich.“

**Hat es bisher funktioniert?** Teilweise, laut Henning (Intake 2026-10-12). Der Zeitpunkt des Bruchs ist unbekannt. Die
Mac-App läuft nicht aus TestFlight, sondern als Bau außerhalb von Xcode (`~/Applications`, #287) oder aus Xcode.
Verworfen: Development-vs-Production als Ursache (Henning; #175 hat gemessen, dass seine Daten in der TestFlight-Fassung
ankamen).

### Was belegt ist und was nicht

Belegt (Code, ohne Gerät): `CloudKit.framework` steht nirgends in `project.yml`, kein `import CloudKit`;
`ModelContainerFactory.make()` fällt an zwei Stellen still auf einen lokalen Speicher ohne Abgleich zurück (Z. 98–102
App-Gruppe nicht verfügbar, Z. 111–115 Container-Anlage mit CloudKit wirft), beides nur als `logger.error`. Nirgends in
`Shared/` oder `LooseEnds/` wird der Zustand der Spiegelung ausgewertet.

**Nicht belegt:** ob die Mac-App überhaupt mit CloudKit spricht. Zwei Hypothesen sind plausibel, keine ist bewiesen:

1. **Stiller Rückfall auf lokalen Speicher** (App-Gruppe, Berechtigung oder Profil des Mac-Baus). Erklärt „teilweise
   gleich“, wenn der lokale Speicher aus einer Zeit stammt, in der der Abgleich lief.
2. **Spiegelung startet nie oder bricht ab** (CloudKit.framework auf macOS nicht gebunden, Sandbox verweigert `cloudd`).
   Quellen: Apple-Forum 784215 und fatbobman („macOS builds don't include CloudKit by default“), Forum 759074 (Mac
   bekommt Pushes außerhalb von TestFlight/Store eingeschränkt).

Die Ursache ist ohne Hennings Mac nicht zu unterscheiden. Dieser Schnitt behebt deshalb nichts auf Verdacht, sondern
(a) macht den Zustand auf jedem Gerät sichtbar und (b) bindet das Framework, dessen Fehlen auf dem Mac dokumentiert zu einem
stillen Nichtstarten führt (billig, auf iOS wirkungslos). Die Anzeige liefert den Beleg, welche Hypothese stimmt; erst
danach folgt Schnitt 2 (Mac-TestFlight, eigene Teil-Spec, **ausdrücklich nicht Teil dieser Spec**).

Entwurf ist freigegeben: **Variante A**, Zeile „iCloud-Abgleich“ in einem eigenen Abschnitt „iCloud“ der Einstellungen
(Henning, 2026-10-13). Alternative B (Hinweis auf der Startseite) verworfen. Vorschau:
`docs/artifacts/fix-377-mac-abgleich/entwurf.html`.

Regelweg-Vermerk (Regeln vor Modell): Kein Modell beteiligt. Die Auswertung der Ereignisse ist eine reine Regel.

## Lösung

1. **`Shared/Persistence/SyncStatus.swift` (neu).**
   - Reine Regel, ohne UI und ohne Framework-Abhängigkeit (kompiliert auch für Watch und Widget, kein SwiftUI):
     `SyncStatus.State` (Enum) mit den Zuständen `waiting` (Spiegelung läuft an, noch kein Ereignis), `alive(kind,
     at: Date)` (letztes Ereignis ohne Fehler; `kind` = Einrichtung / Empfangen / Gesendet), `failed(message: String,
     at: Date)` (Ereignis mit Fehler), `localOnly(reason)` (Rückfall auf lokalen Speicher; `reason` = App-Gruppe fehlt /
     Container-Anlage mit CloudKit geworfen).
   - Reine Funktion `SyncStatus.reduce(_ state: State, event: Event) -> State` und eine reine Textregel
     (`SyncStatus.summary(for:now:)` → Wert, Zeichen, Erklärtext). Regeln: `localOnly` ist endgültig für den Prozess (kein
     späteres Ereignis überschreibt es); ein Ereignis mit Fehler ersetzt `alive`; ein erfolgreiches Ereignis ersetzt
     `failed`; unvollständige Ereignisse (ohne `endDate`, also „läuft noch“) ändern nichts; „vor n Min.“ aus `now - at`.
   - Dünne Hülle `SyncStatus.shared` (`@MainActor @Observable`): hört auf
     `NSPersistentCloudKitContainer.eventChangedNotification`, liest daraus `type`, `succeeded`, `endDate`, `error` und
     füttert `reduce`. Hinter `#if canImport(CoreData)`; die Hülle enthält keine Regel.
2. **`Shared/Persistence/ModelContainerFactory.swift`.** Die zwei stillen Rückfälle (und der Rückfall der Variante
   `syncs: false` bleibt **unberührt**, sie synchronisiert absichtlich nicht) melden zusätzlich zum Logger
   `SyncStatus.shared.fellBack(reason:)`. Das Verhalten „App startet immer“ (#55) bleibt: kein neuer Wurf, kein
   `fatalError`. `make()` startet den Beobachter (`SyncStatus.shared.start()`), bevor der Container entsteht, damit das
   Einrichtungsereignis nicht verpasst wird. Test-Container (in-memory) starten den Beobachter nicht.
3. **`LooseEnds/Views/SettingsView.swift`.** Neuer Abschnitt „iCloud“ unter „Mitteilungen“ (nach Entwurf A) mit einer Zeile
   „iCloud-Abgleich“: links Beschriftung, rechts Wert (+ Zeichen), darunter bei `failed` und `localOnly` ein grauer
   Erklärtext. Texte nach Entwurf:

   | Zustand | Wert | Zeichen (SF Symbol, Umriss) | Farbe | Erklärtext |
   |---|---|---|---|---|
   | `waiting` | „Wartet auf iCloud“ | `icloud` | grau | — |
   | `alive` | „Aktiv · Empfangen/Gesendet/Eingerichtet, vor n Min.“ | `checkmark.icloud` | Akzent | „Deine Aufgaben werden mit deinen anderen Geräten abgeglichen.“ |
   | `failed` | „Gestört“ | `exclamationmark.icloud` | grau | Fehlertext von Apple |
   | `localOnly` | „Nur auf diesem Gerät“ | `icloud.slash` | grau | „Dieses Gerät sieht nur seine eigenen Aufgaben. Starte die App neu. Hilft das nicht, melde dich bei iCloud an.“ |

   Farbbudget: **kein Rot** (Rot heißt Zeitdruck), Akzent nur für „lebt“, Grau für alles andere; nur SF Symbols, kein
   Emoji. Die Zeile trägt die Accessibility-Kennung `iCloudSyncRow` (Wert als Accessibility-Value). Die Ansicht liegt in
   `LooseEnds/Views`, nicht in `Shared/`; die Texte kommen aus der Regel von (1), die View enthält keine Entscheidung.
   Neue Texte werden im Zeichenkatalog Deutsch/Englisch ergänzt, soweit der Katalog dafür bereits Pflichtpflege ist
   (Prüfung in `/50-implement`, ohne weitere Datei: Einträge im bestehenden Katalog zählen nicht als eigener Dateischnitt,
   falls die Datei dort bereits generiert wird).
4. **`project.yml`.** Beim Ziel `LooseEnds` unter `dependencies` ein Eintrag `- sdk: CloudKit.framework` (XcodeGen-Syntax
   für System-Frameworks), nur für macOS, über `platformFilter: macOS` wie bei den vorhandenen Einträgen; ist ein Filter
   an einer `sdk:`-Abhängigkeit in der installierten XcodeGen-Version nicht zulässig, wird der Eintrag ohne Filter gesetzt
   (iOS: wirkungslos, das Framework ist dort ohnehin gebunden). **Keine** Änderung an Entitlements, `DEVELOPMENT_TEAM`,
   Info-Schlüsseln oder anderen Zielen.
5. **`LooseEndsTests/SyncStatusTests.swift` (neu, Swift Testing).** Prüft die reine Regel von (1), siehe Test Plan.

## Source

- **Neu:** `Shared/Persistence/SyncStatus.swift`
- **Geändert:** `Shared/Persistence/ModelContainerFactory.swift`, `LooseEnds/Views/SettingsView.swift`, `project.yml`
- **Neu:** `LooseEndsTests/SyncStatusTests.swift`
- **Geändert:** `LooseEndsUITests/SettingsSmokeTests.swift` (eine Zusicherung, siehe Scope)

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `Shared/Persistence/SyncStatus.swift` | CREATE | Zustände, `reduce`, Textregel, Hülle um `eventChangedNotification` |
| `Shared/Persistence/ModelContainerFactory.swift` | MODIFY | zwei stille Rückfälle werden Zustand (zusätzlich zum Logger); Beobachter starten |
| `LooseEnds/Views/SettingsView.swift` | MODIFY | Abschnitt „iCloud“ mit Zeile „iCloud-Abgleich“ |
| `project.yml` | MODIFY | `CloudKit.framework` explizit für das App-Target (macOS) |
| `LooseEndsTests/SyncStatusTests.swift` | CREATE | Unit-Tests der Auswertungsregel |
| `LooseEndsUITests/SettingsSmokeTests.swift` | MODIFY | Zusicherung: Zeile `iCloudSyncRow` im Einstellungsblatt sichtbar (ca. +4 LoC) |

Geschätzt **+190 / −5 LoC**, innerhalb von ±250.

**Dateigrenze:** Es sind **6 Dateien**, eine über der Grenze von 4–5. Die sechste (`SettingsSmokeTests.swift`) ist eine
einzelne Zusicherung in einem vorhandenen Test. Begründung für die Aufnahme statt Verzicht: Der Nachweis „Zeile ist im
Simulator sichtbar“ ist laut Hennings Regel („UI-Tests sind Pflicht“) und seiner „App wird benutzt“-Regel nicht durch einen
Unit-Test ersetzbar. Alternative, falls die Grenze strikt gelten soll: Beleg ausschließlich über `./scripts/sim.sh test-proof
SettingsSmokeTests` und Screenshot, ohne Dateiänderung am UI-Test, dann aber ohne maschinelle Zusicherung. **Entschieden
(Tech Lead): die sechste Datei bleibt**, weil die UI-Test-Pflicht schwerer wiegt als die Dateizahl und die Abweichung vier
Zeilen beträgt. Die Abweichung wird im Briefing offen genannt.

**Geräteliste berührt:** `Shared/Persistence/`, `project.yml`. Stufe 3 ist Pflicht (siehe AC-8), **nur nach Hennings
wörtlichem „jetzt ist ein Test möglich“**.

**Side-Effects:** Keine Änderung am Datenmodell (kein `mac-schema-init`, kein CloudKit-Deploy), an Berechtigungen,
Info.plist, AppStorage-Schlüsseln oder Audio. Neue Texte in den Einstellungen. Der Beobachter lauscht passiv auf eine
Systembenachrichtigung und ändert den Abgleich nicht. Auf dem Mac wird `CloudKit.framework` gebunden (kann die Spiegelung
erstmals starten, falls Hypothese 2 stimmt; dann sieht Henning auf dem Mac möglicherweise erstmals zusammengeführte Daten.
Es wird nichts gelöscht, ADR-3/Revisions-Prinzip).

### Nicht in diesem Ticket

- Mac-Archiv im TestFlight-Workflow (Schnitt 2, eigene Teil-Spec und eigener Workflow).
- Den stillen Rückfall verbieten (kippt #55, siehe Alternativen).
- Eine Reparatur von App-Gruppe oder Profil des Mac-Baus (erst nach dem Beleg, welche Hypothese stimmt).
- Die Variante `syncs: false` (Widget) und der Rückfall der Testcontainer.
- Der Hinweis auf der Startseite (verworfene Variante B).

## Test Plan

### Automated Tests (TDD RED zuerst)

`LooseEndsTests/SyncStatusTests.swift` (Swift Testing, `@Suite("SyncStatus (#377)")`, reine Funktionen, keine
CloudKit-Abhängigkeit, läuft im Simulator):

- `startsWaiting`: Anfangszustand ist `waiting`.
- `successfulEventBecomesAlive`: Import, Export und Einrichtung ohne Fehler ergeben `alive` mit der jeweiligen Art und dem
  `endDate`.
- `failedEventBecomesFailed`: Ereignis mit Fehler ergibt `failed` mit dem Fehlertext; ein späteres erfolgreiches Ereignis
  ersetzt es wieder durch `alive`.
- `unfinishedEventChangesNothing`: Ereignis ohne `endDate` lässt den Zustand unverändert.
- `localOnlyIsFinal`: nach dem Rückfall (beide Gründe getrennt getestet) ändert weder ein Erfolgs- noch ein Fehlerereignis den
  Zustand.
- `summaryTexts`: je Zustand Wert, Zeichenname und Farbrolle (Akzent nur bei `alive`, nie rot); „vor n Min.“ mit festem
  `now` (0 Min., 2 Min., über eine Stunde, Zukunftszeit durch Uhrabweichung ergibt „gerade eben“).
- `noRedAnywhere`: für alle Zustände ist die Farbrolle `accent` oder `secondary` (hält das Farbbudget fest).

`LooseEndsUITests/SettingsSmokeTests.swift`: im vorhandenen `testGearOpensSettingsWithReminderTime` zusätzlich die
Zusicherung, dass `iCloudSyncRow` im Einstellungsblatt existiert (iPhone/iPad-Simulator; auf dem Mac wird der Test
übersprungen, wie bisher). Unter `--ui-testing` ist der Container im Speicher, der Zustand also `waiting`; geprüft wird nur
das Vorhandensein, nicht ein Zustand.

Annahme zu verifizieren (Simulator, in `/50-implement`, bevor die Hülle als fertig gilt): **Liefert ein SwiftData-Container
`NSPersistentCloudKitContainer.eventChangedNotification`?** SwiftData baut auf demselben Spiegelungsmechanismus von Core
Data auf; die Benachrichtigung ist in Apples TN3164 für `NSPersistentCloudKitContainer` beschrieben und wird in
Fallberichten auch für SwiftData-Apps genutzt, aber nicht von Apple für SwiftData zugesagt. Prüfung: ein Lauf des echten
Produktpfads im Simulator (ohne `--ui-testing`, angemeldeter iCloud-Konto-Zustand wie vorhanden) und Mitschnitt der
Logger-Zeile pro empfangenem Ereignis. Bleibt die Benachrichtigung aus, wird das **vor** dem Weiterbau gemeldet (dann wäre
die Quelle der Anzeige zu wechseln, z. B. Core-Data-Verlauf; die Regel in `SyncStatus` bleibt).

Bestehende Unit-Tests und der volle Lauf `./scripts/sim.sh unit` bleiben grün.

### Abnahme (Stufen)

1. **Tests:** `SyncStatusTests` rot (vorher), grün (nachher); `./scripts/sim.sh unit` grün.
2. **Simulator:** `./scripts/sim.sh generate` (Projektdatei enthält danach `CloudKit.framework` für macOS),
   `./scripts/sim.sh build`, App starten, Einstellungen öffnen, Zeile „iCloud-Abgleich“ in Hell und Dunkel per Screenshot
   belegen und die Bilder öffnen und beschreiben; `./scripts/sim.sh test-proof SettingsSmokeTests`. Die Annahme zur
   Benachrichtigung wird hier belegt. Der Abgleich zwischen Geräten ist im Simulator nicht darstellbar.
3. **Gerät (Pflicht: `Shared/Persistence/` und `project.yml` stehen auf der Geräteliste):** über TestFlight auf iPhone/iPad
   und auf dem Mac, erst nach Hennings wörtlichem „jetzt ist ein Test möglich“; **nichts** auf seinen Geräten, auch nichts
   Lesendes, vorher. Der Mac hat noch keinen TestFlight-Weg (Schnitt 2); bis dahin geht der Mac-Teil über den Bau, den
   Henning selbst startet, und braucht seine Freigabe für genau diesen Durchgang. Vorher ist alles gebaut, installiert und
   startklar.

## Acceptance Criteria

- **AC-1:** Given der Anfangszustand / When die Auswertungsregel `reduce` erfolgreiche Ereignisse (Einrichtung, Empfangen,
  Gesendet) verarbeitet / Then ist der Zustand `alive` mit Art und Zeit; bei einem Ereignis mit Fehler `failed` mit
  Fehlertext; ein späteres erfolgreiches Ereignis ersetzt `failed`; ein unvollendetes Ereignis ändert nichts. Belegt durch
  Unit-Tests in `SyncStatusTests` (zuerst rot).
- **AC-2:** Given ein Rückfall auf den lokalen Speicher (App-Gruppe fehlt oder Container-Anlage mit CloudKit wirft) / When
  danach beliebige Ereignisse eintreffen / Then bleibt der Zustand `localOnly` mit dem jeweiligen Grund. Belegt durch
  Unit-Tests, beide Gründe getrennt.
- **AC-3:** Given `ModelContainerFactory.make()` / When einer der beiden stillen Rückfälle greift / Then wird der Zustand
  `localOnly` gesetzt, der Logger-Eintrag bleibt, und `make()` liefert weiterhin einen Container (die App startet immer,
  #55). Die Variante `syncs: false` und die Testcontainer setzen den Zustand nicht. Belegt durch Code-Prüfung am Diff und
  einen Unit-Test der Meldefunktion.
- **AC-4:** Given die Einstellungen (Blatt auf iPhone/iPad, Fenster auf dem Mac) / When sie geöffnet werden / Then zeigt
  der Abschnitt „iCloud“ eine Zeile „iCloud-Abgleich“ (Kennung `iCloudSyncRow`) mit Wert, Zeichen und bei `failed` und
  `localOnly` dem Erklärtext aus der Tabelle. Belegt im Simulator durch Screenshots in Hell und Dunkel (geöffnet und
  beschrieben) und die Zusicherung in `SettingsSmokeTests`.
- **AC-5:** Given die Zeile in jedem Zustand / When sie dargestellt wird / Then kommt kein Rot vor (Akzent nur bei `alive`,
  sonst Grau), die Zeichen sind SF Symbols (`icloud`, `checkmark.icloud`, `exclamationmark.icloud`, `icloud.slash`), kein
  Emoji, kein Zeichen als Ersatz. Belegt durch den Test `noRedAnywhere` und die Screenshots.
- **AC-6:** Given `project.yml` / When `./scripts/sim.sh generate` läuft / Then bindet das Ziel `LooseEnds` für macOS
  `CloudKit.framework` explizit (Treffer in der erzeugten Projektdatei, vorher 0), der iOS-Bau (`./scripts/sim.sh build`)
  und alle Tests laufen unverändert, und der Diff an `project.yml` berührt weder Entitlements noch `DEVELOPMENT_TEAM` noch
  ein anderes Ziel.
- **AC-7:** Given der Produktpfad im Simulator (ohne `--ui-testing`) / When die App mit einem Container mit CloudKit
  startet / Then ist belegt (Logger-Mitschnitt), ob `NSPersistentCloudKitContainer.eventChangedNotification` für den
  SwiftData-Container eintrifft. Das Ergebnis steht im Artefaktordner `docs/artifacts/fix-377-mac-abgleich/`. Trifft sie
  nicht ein, wird gemeldet, bevor weitergebaut wird.
- **AC-8:** Nachgelagert, **nur nach Hennings wörtlichem „jetzt ist ein Test möglich“** (Stufe 3): Auf seinem Mac zeigt die
  Zeile einen von drei lesbaren Befunden. (a) „Nur auf diesem Gerät“ mit Grund: Hypothese 1 (Rückfall) ist bestätigt, die
  Ursache ist App-Gruppe oder Container-Anlage. (b) „Wartet auf iCloud“ und bleibt es über einen Start mit Netz und
  iCloud-Anmeldung, oder „Gestört“ mit Fehlertext (z. B. CKError 6 der Sandbox): Hypothese 2 (Spiegelung startet nicht oder
  bricht ab). (c) „Aktiv“ mit Zeit: Die Spiegelung läuft; dann sind Hypothese 3 (fehlende Pushes) oder 4 (Schema)
  nachzuverfolgen. iPhone und iPad zeigen im Vergleich „Aktiv“. Das Ergebnis geht als Kommentar in #377 und entscheidet den
  Inhalt von Schnitt 2. #377 bleibt bis dahin offen (PR mit `Refs #377`, nicht `Closes`).
- **AC-9:** Given der Diff / When er geprüft wird / Then berührt er nur die sechs genannten Dateien, ändert kein
  Datenmodell (kein `mac-schema-init`), keinen Abgleichspfad und keinen Entitlement-Schlüssel, und alle bestehenden Tests
  sind grün.

## Dependencies

| Komponente | Beschreibung |
|---|---|
| `NSPersistentCloudKitContainer.eventChangedNotification` | Quelle der Ereignisse (CoreData); Verfügbarkeit für SwiftData ist Annahme, AC-7 |
| XcodeGen | `sdk: CloudKit.framework`, ggf. mit `platformFilter` |
| `ModelContainerFactory` | einzige Stelle der beiden Rückfälle |
| `SettingsView` | Ort der Zeile; Einstellungsblatt (iOS) und Fenster (Mac) |
| Zeichenkatalog | neue Texte Deutsch/Englisch |

Keine neue externe Abhängigkeit.

## Risiken

- **Benachrichtigung bleibt aus (mittel):** Liefert SwiftData sie nicht, zeigt die Zeile dauerhaft „Wartet auf iCloud“ und
  belegt nichts. Gegenmittel: AC-7 im Simulator vor dem Weiterbau; Quelle austauschbar, Regel bleibt.
- **Bindung ändert das Mac-Verhalten (niedrig bis mittel):** Startet die Spiegelung erstmals, tauchen auf dem Mac
  zusammengeführte Aufgaben auf. Nichts wird gelöscht; Henning wird im Gerätebericht darauf hingewiesen.
- **`platformFilter` an `sdk:`-Abhängigkeit (niedrig):** Wird in der XcodeGen-Version nicht angenommen; Rückfall: ohne Filter.
- **Falsche Beruhigung (mittel):** „Aktiv“ zeigt nur, dass Ereignisse ohne Fehler kamen, nicht dass beide Seiten gleich
  sind. Der Erklärtext behauptet deshalb nur den Abgleich, nicht den Gleichstand; der Vergleich mit dem zweiten Gerät
  bleibt Teil von AC-8.
- **Dateigrenze (niedrig):** sechste Datei, siehe Scope.
- **Der Simulator ersetzt den Mac nicht** (AC-8).

## Alternativen

- **Stillen Rückfall verbieten** (Hinweis statt lokalem Speicher): würde Hypothese 1 sofort hörbar machen und verhindert
  Aufgaben im Nirgendwo (auch aus der Menüleisten-Erfassung, #356). **Kippt die Entscheidung aus #55** („App startet
  immer“), die einen Absturz bei fehlender Berechtigung verhindert. Nicht jetzt; nach dem Beleg neu bewertbar.
- **Mac nur als Prüfbau behalten** (Variante C im Ticket), den Alltag auf iPhone/iPad belassen: spart Schnitt 2, **kippt**
  das Ziel „Mac ist eine gleichwertige Plattform“ (eine Multiplattform-App, Ground Rules). Verworfen.
- **Hinweis auf der Startseite** (Entwurf B): auffälliger, aber ständig sichtbar bei einem Problem, das nur manche Bau-Arten
  trifft; verworfen von Henning.
- **Nur `CloudKit.framework` binden, ohne Anzeige:** billig, aber ohne Beleg, ob es half. Gegen die Regel „erst messen“.
  Verworfen.
- **Core-Data-Verlauf statt Benachrichtigung als Quelle:** Rückfall, falls AC-7 scheitert.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: ADR-2 (SwiftData mit CloudKit, private Datenbank) bleibt unverändert; dieser Schnitt macht den
  Zustand sichtbar und bindet ein Framework, er ändert weder Speicherort noch Abgleichsweg. Die Entscheidung #55 („App
  startet immer“) wird nicht gekippt.

## Definition of Done

- AC-1 bis AC-7 und AC-9 erfüllt; `SyncStatusTests` zuerst rot, dann grün; alle bestehenden Tests grün.
- Simulator-Belege (Screenshots Hell/Dunkel, Mitschnitt zu AC-7) liegen unter `docs/artifacts/fix-377-mac-abgleich/`.
- AC-8 (Gerät) nur nach Hennings wörtlichem „jetzt ist ein Test möglich“; bis dahin bleibt #377 offen.
- Der PR verweist mit `Refs #377` (nicht `Closes`); Schnitt 2 wird nach dem Beleg als Teil-Spec geplant.
- Abschlussbericht ohne Git-Vokabular: Die Einstellungen zeigen jetzt, ob die App mit iCloud abgleicht. Henning soll auf dem
  Mac die Einstellungen öffnen und sagen, was in „iCloud-Abgleich“ steht.

## Changelog

- 2026-10-13: Initiale Spec für #377 Schnitt 1 (Abgleich sichtbar machen, CloudKit am Mac binden).

# Stand und nächste Schritte

Für jede neue Claude-Sitzung: erst `CLAUDE.md`, dann diese Datei, dann `docs/project/01-user-story.md`
für die Prioritäten. Henning ist PO und kein Entwickler; Claude entscheidet als Tech Lead nach Best
Practice, baut in kleinen Schnitten mit Tests und öffnet PRs.

Claude merged PRs eigenständig nach main, sobald alle CI-Checks grün sind und keine offenen
Rückfragen oder Zweifel bestehen. Nachfragen nur bei echtem Risiko: nicht eindeutig auflösbare
Merge-Konflikte, Breaking Changes an Auth/Daten/Architektur, oder wenn Claude selbst unsicher ist.
Henning hat als PO keine Grundlage, Merge-Bereitschaft technisch zu beurteilen — Rückfragen dazu
sind daher meist nur Zeitverlust.

## Gebaut (auf main oder im offenen PR-Stapel)

| Bereich | Was | Wo |
|---------|-----|----|
| Erfassung | Textfeld, Live-Spracherkennung mit Wellenform, Control Center, Siri-Intent, Watch-Diktat, Teilen-Menü (iOS) | `LooseEnds/Views/CaptureView.swift`, `LooseEnds/Speech`, `Shared/Intents`, `LooseEndsShare` |
| Veredelung | Foundation Models auf dem Gerät, Schwelle 0,6, je Feld eine KI-Revision, Nachzügler-Lauf | `Shared/Enrichment` |
| Ansichten | Als nächstes, Neu, Fällig, Schnell, Alt, Wartet, Wiederkehrend, Geparkt, Erledigt, Kontext, Projekt | `Shared/Models/ViewRules.swift`, `LooseEnds/Views/SidebarView.swift` |
| Liste | Wisch rechts/links, Erledigt drei Sekunden abbrechbar per Tipp auf die Zeile („Undo“, #32), Halten-Menü mit Verschieben (Morgen, Wochenende, nächste Woche, frei gewähltes Datum, #33), Parken, Löschen; Merkmalzeile; Drag-Sortierung in Als nächstes; Alt mit Alter und Verschiebungen; Erledigt nach Tagen; Projekt mit eingeklappten Unteraufgaben, per Pfeil aufklappbar und abhakbar (#28) | `LooseEnds/Views/TaskListView.swift`, `TaskRow.swift`, `Shared/Services/TaskActions.swift`, `PendingCompletions.swift` |
| Detail | Titel, Rohtext, Felder mit Editor, KI-Vorher/Nachher, Zurücksetzen, Änderungen-Sheet, Wiederholung, Unteraufgaben (eine Ebene, abhakbar), Im Kalender anzeigen, Neu analysieren (#34) | `LooseEnds/Views/TaskDetailView.swift`, `FieldEditorView.swift`, `SubtasksSection.swift`, `Shared/Services/RevisionService.swift`, `FieldCodec.swift`, `Subtasks.swift`, `Shared/Enrichment/EnrichmentCoordinator.swift` |
| Startscreen | Systemansichten mit Zähler, Projekte und Kontexte anlegen, umbenennen, löschen | `LooseEnds/Views/SidebarView.swift`, `Shared/Services/CatalogService.swift` |
| Mitteilung | "Heute fällig" um 9 Uhr mit Erledigt, Als nächstes, Morgen | `Shared/Notifications`, `LooseEnds/Notifications` |
| Kalender | Eigener Kalender "Loose Ends", ein Termin je Aufgabe mit Schalter und Fälligkeit, Abgleich nach jedem Speichern | `Shared/Services/CalendarSync.swift`, `LooseEnds/Calendar/CalendarBridge.swift` |
| Auslieferung | CI (Unit, iOS-Build, UI-Smoke, Design-Galerie hell/dunkel als Artefakt `DesignGallery`, #182), TestFlight-Workflow, Anleitung | `.github/workflows`, `docs/reference/testflight.md` |
| Lernkorpus | FocusBlox-Export (287 Aufgaben), Konfidenz-Kalibrierung gelaufen: Konfidenz trennt nicht (siehe `06-annahmen-und-experimente.md`, #65) | `scripts/export-focusblox-corpus.swift`, `LooseEndsTests/FocusBloxCalibrationTests.swift` |
| Messstrecke | Treue-Korpus (317 Sätze in Hennings Bauformen, Wahrheit als Regel gegen den Messtag), Labor-App auf dem iPhone, die in Scheiben misst und nach jedem Satz sichert, Abholung per `sim.sh lab-fetch`, Auswertung und Bericht auf dem Mac; Mehrfachlauf-Infrastruktur (#107) und Selbstkonsistenz-Auswertung (#108, Mechanismus fertig, Messlauf steht aus) | `Measurement/`, `LooseEndsLab/`, `LooseEndsTests/DateTitleReportTests.swift`, `scripts/sim.sh` |
| Logo | App-Icon "der Knoten" in Petrol: Hell, Dunkel, Getönt, Mac, Watch; Akzentfarbe Petrol; SVG-Quellen | `LooseEnds/Resources/Assets.xcassets`, `docs/design/logo/` |

## Offen, nach Priorität

Seit 2026-09-17 als GitHub Issues geführt, ticket-für-ticket mit eigener Definition of Done
(`gh issue list --label enhancement` / `--label spike`). Diese Liste ist nur noch die
Prioritätsreihenfolge; Details, Umfang und DoD stehen im jeweiligen Issue.

**Stabilität vor allem anderen** (Tech Lead, 2026-10-03): Ein Absturz in der Erfassung blockiert
jede Einladung externer Tester über TestFlight.

- [#184](https://github.com/henemm/loose-ends/issues/184) Absturz in `SpeechCapture.startEngine`, wenn
  der Audio-Dienst nicht rechtzeitig antwortet (gesehen im CI-Simulator, Gerätestufe Pflicht)

**Spikes zuerst** (technisches Risiko, blockieren die Umsetzung der Must-Features):

1. [#22](https://github.com/henemm/loose-ends/issues/22) Kaltstart Erfassungs-Szene unter einer Sekunde?
2. [#24](https://github.com/henemm/loose-ends/issues/24) Mail-Share-Extension: `message:`-URL zuverlässig?

**Tragende Annahmen des Produkts** (`docs/project/06-annahmen-und-experimente.md`, 2026-09-19): Die
Kalibrierung zu #23 zeigt, dass die Modell-Konfidenz richtig nicht von falsch trennt. Bevor weitere
Ansichten gebaut werden, laufen diese Spikes, in dieser Reihenfolge:

- [#67](https://github.com/henemm/loose-ends/issues/67) Datum- und Titel-Treue (falsch ist hier nicht „ein Handgriff")
  - davor [#83](https://github.com/henemm/loose-ends/issues/83) Labor-App nur im Vordergrund, Lebenslauf mitschreiben
  - davor [#82](https://github.com/henemm/loose-ends/issues/82) Korpus in Hennings Satzformen (Stichwörter, Fragen, Diktat) samt seinen FocusBlox-Rohsätzen
  - gemessen 2026-09-20 über 317 Sätze: Titel hält (0,3 % erfunden), Datum reißt (50 % exakt, 96,5 % erfunden)
  - daraus [#92](https://github.com/henemm/loose-ends/issues/92) Datum regelbasiert, ohne Modell (PO-Entscheidung: Regeln vor Modell) —
    Schnitt 1 gemessen: 99,3 % exakt, 0 % erfunden
  - daraus [#95](https://github.com/henemm/loose-ends/issues/95) Regelparser in den Produktpfad (Schnitt 2) —
    Fälligkeitsdatum kommt aus `DueDateRule`, das Modell hat die vier Datumsfelder verloren
  - daraus [#98](https://github.com/henemm/loose-ends/issues/98) Katalog-Lücke aus #95 geschlossen:
    die neun `DueDateRule`-Begründungssätze fehlten auf Deutsch im String-Katalog, jetzt übersetzt
  - Personen zurückgestellt (Henning, 2026-09-21): kein bekannter Use Case, nicht gemessen —
    offene Frage, ob das Feld überhaupt bleibt, in [#105](https://github.com/henemm/loose-ends/issues/105)
  - **#67 damit geschlossen:** alle drei zugesagten Feld-Entscheidungen getroffen (Datum, Titel, Personen)
- [#65](https://github.com/henemm/loose-ends/issues/65) Unsicherheitssignal, das richtig von falsch trennt
  - Schritt 1 gemergt (2026-09-22, [#107](https://github.com/henemm/loose-ends/issues/107)):
    Mess-Infrastruktur für Mehrfachläufe je Satz — Korpus per Namen wählbar, `runIndex` je Ergebnis,
    Läufe statt Sätze gezählt; reines Fundament, kein neues Signal
    (`docs/specs/measurement/spike-65-mehrfachlauf-infrastruktur.md`)
  - Schritt 2 gemergt (2026-09-22, [#108](https://github.com/henemm/loose-ends/issues/108)):
    Mechanismus für das Selbstkonsistenz-Signal — Schema-Erweiterung (`Corpus.Entry`,
    `MeasurementResult`) um die fünf FocusBlox-Wahrheitsfelder, `Measurement/SelfConsistency.swift`
    (Mehrheitswert + Einstimmigkeit je Feld, Trefferquote-über-Abdeckung-Tabelle), `--runs <n>` für
    die Labor-App; 150/150 Unit-Tests grün, alle 9 Acceptance Criteria erfüllt
    (`docs/specs/measurement/spike-108-selbstkonsistenz-signal.md`). Liefert noch kein Messergebnis —
    der mehrtägige Lauf auf Hennings Gerät (5 Läufe × 287 FocusBlox-Sätze) steht aus, ebenso die
    daraus folgende Entscheidung zu `EnrichmentWriter.confidenceThreshold`.
  - **Vor dem Messlauf zu klären (2026-09-22):** [#111](https://github.com/henemm/loose-ends/issues/111)
    — FocusBlox-„Wahrheit" für importance/urgency/energy ist kein verlässlicher Maßstab (geprüft
    gegen Quellcode und Datenbank: importance/urgency sind reine Fallback-Standardwerte, energy stammt
    von einem anderen, älteren Modell, nie von Henning bestätigt). Daraus Redesign-Vorschlag
    [#112](https://github.com/henemm/loose-ends/issues/112): Wichtigkeit/Dringlichkeit regelbasiert,
    Energie subjektiv (Skala −3…3) und Dauer per Retrieval-Beispielen geschärft statt gemessener
    Selbstkonsistenz — seit der B1-Entscheidung vom 2026-09-27 nicht mehr an #69 gebunden.
    - daraus [#117](https://github.com/henemm/loose-ends/issues/117) umgesetzt (2026-09-23):
      Wichtigkeit/Dringlichkeit regelbasiert über `ImportanceUrgencyRule` (analog `DueDateRule`
      aus #95), Modell liefert diese beiden Felder nicht mehr. Energie und Dauer sind seit
      2026-09-27 entschieden: Energie bleibt manuell (Retrieval schlägt dort die Konstante auf
      keiner Lesart), Dauer und Kontexte kommen bei **wortgleich wiederkehrendem Rohtext** aus der
      früheren Aufgabe — Gleichheit der normalisierten Wortmenge, keine Ähnlichkeitsschwelle; das
      Modell schätzt sie weiterhin für neu formulierte Aufgaben, überschreibt aber keinen gesetzten
      Wert ([#136](https://github.com/henemm/loose-ends/issues/136), umgesetzt 2026-09-27).
- [#66](https://github.com/henemm/loose-ends/issues/66) Steht die Information überhaupt im Text?
- [#68](https://github.com/henemm/loose-ends/issues/68) Nachweis: Modell je Gerät, Prozess, Zustand
- [#69](https://github.com/henemm/loose-ends/issues/69) Wirken Retrieval-Beispiele? — **abgeschlossen 2026-09-27**
  - Ticket A gemessen (2026-09-26): Regel-Baseline für den Konventionstest aus B1 trifft 10 von 10
    Wort→Kontext-Mustern, klar über der Abbruchschwelle (< 8/10) — Ticket B (Embedding-Auslass-Test)
    entfällt (`docs/reference/retrieval-convention-spike.md`,
    `docs/specs/measurement/spike-69-regel-baseline-konventionstest.md`).
  - [#131](https://github.com/henemm/loose-ends/issues/131) gemessen (2026-09-26): Regel-Auslass-Test
    (Wortüberlappung als Nachbarsuche), siehe `docs/reference/retrieval-leave-one-out-rules.md`.
  - **B1 entschieden (2026-09-27, Henning): Wiedererkennung ja, Lernen nein.** Aufgeschlüsselt nach
    Ähnlichkeit trägt die Nachbarsuche nur bei fast wortgleichem Text (Kontexte 100 %, Dauer 97,2 %
    bei ~60 % Abdeckung), bei teilweiser Ähnlichkeit fällt sie auf 55 %. Der Modell-Auslass-Test
    wird **nicht** gebaut — er würde die Beispiele mit derselben Nachbarsuche wählen und wäre auf
    diesem Korpus nicht sauber auswertbar. Begründung und verworfene Alternativen in
    `docs/project/06-annahmen-und-experimente.md` (B1). Folgen: ADR-5 neu gefasst,
    [#26](https://github.com/henemm/loose-ends/issues/26) geschlossen,
    [#136](https://github.com/henemm/loose-ends/issues/136) (Textabgleich setzt die früheren Werte)
    und [#137](https://github.com/henemm/loose-ends/issues/137) (Beleg im Bericht) angelegt,
    [#112](https://github.com/henemm/loose-ends/issues/112) entblockt.
  - **#69 damit abgeschlossen.**
- [#70](https://github.com/henemm/loose-ends/issues/70) Textform: getippt, diktiert, Mail, Englisch
- [#71](https://github.com/henemm/loose-ends/issues/71) Guardrail-Verweigerungsrate
- [#72](https://github.com/henemm/loose-ends/issues/72) Token- und Latenzbudget
- [#73](https://github.com/henemm/loose-ends/issues/73) Dauerlauf je OS-Stand

**Danach Features, nach Priorität:**

- [#180](https://github.com/henemm/loose-ends/issues/180) Eigener Charakter (Faden + Briefpapier):
  Schritt 1 (Papiergrund, Haarlinien) in #181; Schritt 2 (Serif, Kopfsatz statt „Views") vor der
  ersten Einladung externer Tester, Schritt 3 (Knoten-Zeichen) danach

5. [#25](https://github.com/henemm/loose-ends/issues/25) Siri über das Reminders-App-Schema (Must) — braucht Xcode 27 in der CI, bis dahin reicht die Shortcut-Phrase "Add to Loose Ends"
6. [#27](https://github.com/henemm/loose-ends/issues/27) Abhängigkeiten über Private Cloud Compute (`blockedBy`)
8. [#29](https://github.com/henemm/loose-ends/issues/29) Onboarding-Screen (Screen 12)
9. [#30](https://github.com/henemm/loose-ends/issues/30) Mac-Teilen-Erweiterung
10. [#31](https://github.com/henemm/loose-ends/issues/31) Kachel-Optik verfeinern
14. [#40](https://github.com/henemm/loose-ends/issues/40) Icon-Composer-Paket für das App-Icon (Liquid Glass mit Ebenen)

## Arbeitsweise, die sich bewährt hat

- Ein Schnitt = ein PR mit reiner Logik in `Shared/Services` oder `Shared/Models` plus Unit-Tests,
  dazu die View in `LooseEnds/Views` und ein UI-Smoke-Test unter `--ui-testing`.
- Gestapelte PRs gehen, aber jede Ebene schreibt `Localizable.xcstrings` am Ende weiter; beim Merge
  nach main jede Ebene erst mit main zusammenführen (Branch-Seite gewinnt, sie ist die Obermenge).
- Ein `ModelContext` hält seinen `ModelContainer` nicht: in Tests `TestStore` benutzen.
- Nichts mit `try?` verschlucken, `Logger` statt `print`, Berechtigungsabfragen unter Tests aus.
- **Zwingend:** Jede Änderung zuerst selbst im Simulator laufen lassen (Build + Start + der
  betroffene Ablauf), bevor Henning gebeten wird, etwas auf seinem eigenen Gerät zu testen.
  Ursache: ein per Kommandozeile lokal signierter Build hatte eine fehlende App-Group-Berechtigung
  (`SwiftData/DataUtilities.swift:1257: Fatal error: Unable to find App Group Container in
  Entitlements`) — ungetestet an Henning weitergegeben, auf seinem Gerät reproduziert statt vorher
  im Simulator gefunden.

## Abnahme in drei Stufen

Die Reihenfolge ist verbindlich, keine Stufe wird vorgezogen. Stufe 1 und 2 werden nie
übersprungen; Stufe 3 nur, wenn der Schnitt einen Pfad der Geräteliste berührt (`CLAUDE.md`).

1. **Tests** — `./scripts/sim.sh unit` und der betroffene UI-Test müssen grün sein.
2. **Simulator** — `./scripts/sim.sh build`, `launch`, `screenshot`: der betroffene Ablauf wird
   selbst durchgespielt und belegt. Nichts geht auf das Gerät, was hier nicht bewiesen ist.
3. **Hennings iPhone 16 Pro** — `./scripts/sim.sh device-status` (liest nur) und die Labor-App
   (`./scripts/sim.sh lab`), die Henning selbst antippt. Erst danach gilt eine Änderung als fertig.

Stufe 3 fährt seit #153 keinen nachgespielten Bedienablauf mehr. Der erste echte Versuch dafür —
derselbe UI-Test wie im Simulator, aber signiert auf dem Gerät — lief am 2026-09-30 zwar grün, war
dabei aber invasiv: Er überschrieb Hennings produktive Installation (gleiche Kennung
`com.henning.looseends`), die Sperr-Vorprüfung startete die App im Vordergrund und verdrängte, was
gerade lief, und das Telefon war 5–10 Minuten exklusiv belegt und musste entsperrt bleiben. Belegt
hat er dabei nichts von dem, wofür er gebaut wurde: Auf dem Beweisbild
(`docs/artifacts/feat-153-geraetestufe-ui-test/screenshots/`) hatte Apple Intelligence im Testlauf
nichts gesetzt — der Lauf prüfte damit dasselbe wie der Simulator, nur invasiver. Das verletzte eine
bestehende Entscheidung, die nie gekippt, sondern beim Bauen übersehen wurde (siehe die Begründung
zu `cmd_lab_run` unten in dieser Datei) und die Festlegung, nie eine App auf Hennings Gerät
fernzustarten.

`device-status` zeigt nur, ob und wie das Gerät verbunden ist — es baut, installiert und startet
nichts. Die frühere Begründung dieser Stufe über `device-console` ist hinfällig, nicht nur ersetzt:
Das Kommando liest die Standardausgabe (`--console`), die App schreibt aber ausschließlich über
`Logger`, nie über `print` (#160) — es hat nie gelesen, was sein Kommentar behauptete.

**Die dadurch entstehende Lücke wird hier benannt, nicht versteckt.** Für Apple Intelligence bleibt
die Labor-App der Messweg. Für Watch, Widgets, Share, Mikrofon und Mitteilungen gibt es auf echter
Hardware aktuell **keinen** automatisierten Nachweis mehr, nur den lesenden Statusblick. **#156 ist
erledigt (2026-10-01):** Gerätebauten tragen seither die eigene Kennung `com.henning.looseends.probe`
(„LE Prüfbau") mit eigener App-Gruppe und eigenem iCloud-Container, Hennings Installation bleibt
dabei unberührt — Nachweis per `devicectl device info apps` geführt. Offene Folgetickets für den
Verschluss: #143 (Spike: trägt `xctrace record --template Logging` als Beobachtungskanal, ohne die
App zu starten?), #160 (`device-console` klären oder ersetzen).

Was Stufe 3 findet und Stufe 2 prinzipiell nicht kann: Apple Intelligence auf dem Gerät,
CloudKit-Sync zwischen Geräten, Watch, Action Button, Widgets, Mikrofon — und alles, was an
Signierung, Provisioning und Entitlements hängt (siehe den App-Group-Absturz oben).

**TestFlight ist keine Stufe dieser Kette.** Es ist ein Verteilungskanal an Menschen und ruht,
bis andere als Henning testen sollen. Als Entwicklungswerkzeug ist es untauglich: kein Debugger,
keine Live-Logs, und Crash-Reports erreichen den Xcode Organizer erst mit bis zu einem Tag
Verzögerung — und nur die häufigsten. Ein Bug, der nicht abstürzt, erzeugt dort gar nichts.

## Der Hauptcheckout hält sich selbst aktuell

Alle Sessions arbeiten in Worktrees, PRs werden auf GitHub gemergt — Hennings `main` blieb dabei
zurück, ohne dass es jemandem auffiel. Am 2026-09-19 stand er 36 Commits hinter `origin/main` und
baute noch das Grundgerüst ohne Capture-Button; Henning installierte das aufs iPhone und fand eine
App ohne (+). Es dann geradezuziehen ist mühsam: Der Worktree-Zwang des Plugins sperrt schreibende
Werkzeuge im Hauptverzeichnis, und aus einem Worktree heraus sind Git-Befehle auf den
Hauptcheckout ebenfalls gesperrt.

Deshalb erledigt das ein SessionStart-Hook, der vor allen Werkzeug-Sperren läuft:
`~/.claude/scripts/loose-ends-sync-main.sh`, eingetragen in `~/.claude/settings.json`. Er springt
nur an, wenn die Sitzung zu diesem Projekt gehört, holt `origin/main` und zieht `main` per
Fast-Forward nach. Steht etwas im Weg — lokale Änderungen, ein anderer Branch, kein Netz —, bleibt
alles unangetastet und der Grund steht in der Ausgabe.

Das Skript liegt außerhalb des Repos, damit es nicht davon abhängt, wie alt der Checkout gerade
ist. Auf einem neuen Rechner muss es einmal neu angelegt werden.

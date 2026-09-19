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
| Liste | Wisch rechts/links, Halten-Menü mit Verschieben, Parken, Löschen; Merkmalzeile; Drag-Sortierung in Als nächstes; Alt mit Alter und Verschiebungen; Erledigt nach Tagen | `LooseEnds/Views/TaskListView.swift`, `TaskRow.swift`, `Shared/Services/TaskActions.swift` |
| Detail | Titel, Rohtext, Felder mit Editor, KI-Vorher/Nachher, Zurücksetzen, Änderungen-Sheet, Wiederholung, Unteraufgaben (eine Ebene, abhakbar), Im Kalender anzeigen | `LooseEnds/Views/TaskDetailView.swift`, `FieldEditorView.swift`, `SubtasksSection.swift`, `Shared/Services/RevisionService.swift`, `FieldCodec.swift`, `Subtasks.swift` |
| Startscreen | Systemansichten mit Zähler, Projekte und Kontexte anlegen, umbenennen, löschen | `LooseEnds/Views/SidebarView.swift`, `Shared/Services/CatalogService.swift` |
| Mitteilung | "Heute fällig" um 9 Uhr mit Erledigt, Als nächstes, Morgen | `Shared/Notifications`, `LooseEnds/Notifications` |
| Kalender | Eigener Kalender "Loose Ends", ein Termin je Aufgabe mit Schalter und Fälligkeit, Abgleich nach jedem Speichern | `Shared/Services/CalendarSync.swift`, `LooseEnds/Calendar/CalendarBridge.swift` |
| Auslieferung | CI (Unit, iOS-Build, UI-Smoke), TestFlight-Workflow, Anleitung | `.github/workflows`, `docs/reference/testflight.md` |
| Lernkorpus | FocusBlox-Export (287 Aufgaben), Konfidenzschwelle kalibriert und bestätigt (0,6) | `scripts/export-focusblox-corpus.swift`, `LooseEndsTests/FocusBloxCalibrationTests.swift` |
| Logo | App-Icon "der Knoten" in Petrol: Hell, Dunkel, Getönt, Mac, Watch; Akzentfarbe Petrol; SVG-Quellen | `LooseEnds/Resources/Assets.xcassets`, `docs/design/logo/` |

## Offen, nach Priorität

Seit 2026-09-17 als GitHub Issues geführt, ticket-für-ticket mit eigener Definition of Done
(`gh issue list --label enhancement` / `--label spike`). Diese Liste ist nur noch die
Prioritätsreihenfolge; Details, Umfang und DoD stehen im jeweiligen Issue.

**Spikes zuerst** (technisches Risiko, blockieren die Umsetzung der Must-Features):

1. [#20](https://github.com/henemm/loose-ends/issues/20) Control-Center-Werteabfrage unter iOS 27?
2. [#21](https://github.com/henemm/loose-ends/issues/21) SystemLanguageModel in Extension/BGAppRefreshTask verlässlich?
3. [#22](https://github.com/henemm/loose-ends/issues/22) Kaltstart Erfassungs-Szene unter einer Sekunde?
4. [#24](https://github.com/henemm/loose-ends/issues/24) Mail-Share-Extension: `message:`-URL zuverlässig?

**Danach Features, nach Priorität:**

5. [#25](https://github.com/henemm/loose-ends/issues/25) Siri über das Reminders-App-Schema (Must) — braucht Xcode 27 in der CI, bis dahin reicht die Shortcut-Phrase "Add to Loose Ends"
6. [#26](https://github.com/henemm/loose-ends/issues/26) Retrieval per Embedding (ADR-5)
7. [#27](https://github.com/henemm/loose-ends/issues/27) Abhängigkeiten über Private Cloud Compute (`blockedBy`)
8. [#28](https://github.com/henemm/loose-ends/issues/28) Projekt-Ansicht mit Unteraufgaben eingerückt/eingeklappt
9. [#29](https://github.com/henemm/loose-ends/issues/29) Onboarding-Screen (Screen 12)
10. [#30](https://github.com/henemm/loose-ends/issues/30) Mac-Teilen-Erweiterung
11. [#31](https://github.com/henemm/loose-ends/issues/31) Kachel-Optik verfeinern
12. [#32](https://github.com/henemm/loose-ends/issues/32) Drei Sekunden abbrechbares Erledigt
13. [#33](https://github.com/henemm/loose-ends/issues/33) "Datum" im Verschieben-Menü
14. [#34](https://github.com/henemm/loose-ends/issues/34) "Neu analysieren" im Detail
15. [#40](https://github.com/henemm/loose-ends/issues/40) Icon-Composer-Paket für das App-Icon (Liquid Glass mit Ebenen)

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

Die Reihenfolge ist verbindlich. Keine Stufe wird übersprungen, keine vorgezogen.

1. **Tests** — `./scripts/sim.sh unit` und der betroffene UI-Test müssen grün sein.
2. **Simulator** — `./scripts/sim.sh build`, `launch`, `screenshot`: der betroffene Ablauf wird
   selbst durchgespielt und belegt. Nichts geht auf das Gerät, was hier nicht bewiesen ist.
3. **Hennings iPhone 16 Pro** — `./scripts/sim.sh device`. Erst danach gilt eine Änderung als
   fertig.

Stufe 3 ist keine Bitte an Henning, sondern läuft von hier aus: Das Gerät ist über das lokale
Netzwerk gepairt, `xcrun devicectl` baut signiert, installiert drahtlos und startet. Installieren
geht auch bei gesperrtem iPhone, Starten braucht ein entsperrtes. `device-console` liest stdout
und stderr live mit — das ist der Grund, warum diese Stufe existiert und nicht durch TestFlight
ersetzt werden kann.

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

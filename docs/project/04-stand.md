# Stand und nächste Schritte

Für jede neue Claude-Sitzung: erst `CLAUDE.md`, dann diese Datei, dann `docs/project/01-user-story.md`
für die Prioritäten. Henning ist PO und kein Entwickler; Claude entscheidet als Tech Lead nach Best
Practice, baut in kleinen Schnitten mit Tests und öffnet PRs. Nach main wird nur auf Hennings
ausdrückliches "merge" gemerged.

## Gebaut (auf main)

| Bereich | Was | Wo |
|---------|-----|----|
| Erfassung | Textfeld, Live-Spracherkennung mit Wellenform, Control Center, Siri-Intent, Watch-Diktat, Teilen-Menü (iOS) | `LooseEnds/Views/CaptureView.swift`, `LooseEnds/Speech`, `Shared/Intents`, `LooseEndsShare` |
| Veredelung | Foundation Models auf dem Gerät, Schwelle 0,6, je Feld eine KI-Revision, Nachzügler-Lauf | `Shared/Enrichment` |
| Ansichten | Als nächstes, Neu, Fällig, Schnell, Alt, Wartet, Wiederkehrend, Geparkt, Erledigt, Kontext, Projekt | `Shared/Models/ViewRules.swift`, `LooseEnds/Views/SidebarView.swift` |
| Liste | Wisch rechts/links, Halten-Menü mit Verschieben, Parken, Löschen; Merkmalzeile | `LooseEnds/Views/TaskListView.swift`, `TaskRow.swift`, `Shared/Services/TaskActions.swift` |
| Detail | Titel, Rohtext, Felder mit Editor, KI-Vorher/Nachher, Zurücksetzen, Änderungen-Sheet, Wiederholung | `LooseEnds/Views/TaskDetailView.swift`, `FieldEditorView.swift`, `Shared/Services/RevisionService.swift`, `FieldCodec.swift` |
| Startscreen | Systemansichten mit Zähler, Projekte und Kontexte anlegen, umbenennen, löschen | `LooseEnds/Views/SidebarView.swift`, `Shared/Services/CatalogService.swift` |
| Mitteilung | "Heute fällig" um 9 Uhr mit Erledigt, Als nächstes, Morgen | `Shared/Notifications`, `LooseEnds/Notifications` |
| Auslieferung | CI (Unit, iOS-Build, UI-Smoke), TestFlight-Workflow, Anleitung | `.github/workflows`, `docs/reference/testflight.md` |

## Offen, nach Priorität

1. **Siri über das Reminders-App-Schema** (Must): braucht Xcode 27 in der CI. Bis dahin reichen die
   Shortcut-Phrasen "Add to Loose Ends".
2. **Als nächstes per Drag sortieren** (Screen 3): `nextRank` beim Verschieben neu vergeben.
3. **Alt und Erledigt** (Screen 11): Alter und "wie oft verschoben" je Zeile in Alt; Erledigt nach
   Tagen gruppiert.
4. **Unteraufgaben, eine Ebene** (Should): Modell hat `parent`/`subtasks`, UI fehlt.
5. **Kalender anzeigen** (Should): `showInCalendar` im Modell, EventKit-Anbindung fehlt.
6. **Retrieval per Embedding** (ADR-5): Beispiele für die Veredelung nach Ähnlichkeit statt "die
   letzten fünf".
7. **Abhängigkeiten über Private Cloud Compute** (ADR): `blockedBy` erkennen.
8. **Onboarding** (Screen 12), **Mac-Teilen-Erweiterung**, **Kachel-Optik** nach dem Design-Freeze.
9. **Drei Sekunden abbrechbares Erledigt**, "Datum" im Verschieben-Menü, "Neu analysieren" im Detail.

## Arbeitsweise, die sich bewährt hat

- Ein Schnitt = ein PR mit reiner Logik in `Shared/Services` oder `Shared/Models` plus Unit-Tests,
  dazu die View in `LooseEnds/Views` und ein UI-Smoke-Test unter `--ui-testing`.
- Gestapelte PRs gehen, aber jede Ebene schreibt `Localizable.xcstrings` am Ende weiter; beim Merge
  nach main jede Ebene erst mit main zusammenführen (Branch-Seite gewinnt, sie ist die Obermenge).
- Ein `ModelContext` hält seinen `ModelContainer` nicht: in Tests `TestStore` benutzen.
- Nichts mit `try?` verschlucken, `Logger` statt `print`, Berechtigungsabfragen unter Tests aus.

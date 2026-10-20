# Funktionsübersicht (gebaut)

Hierher ausgelagert aus `docs/project/04-stand.md` (aufgelöst am 2026-10-12). **Stand der Übernahme,
nicht fortlaufend gepflegt:** maßgeblich sind Code, `CLAUDE.md` („Where things live“) und die
Tickets. Was offen ist und in welcher Reihenfolge, steht in den Meilensteinen M1 bis M4 des Repos.

| Bereich | Was | Wo |
|---------|-----|----|
| Erfassung | Textfeld, Live-Spracherkennung mit Wellenform (nur auf dem Gerät über `SpeechAnalyzer`, fehlendes Sprachmodell auf Tipp „Laden“ mit Fortschritt, #64), Siri-Intent „Aufgabe erfassen“ (auch über das Kurzbefehle-Steuerelement im Kontrollzentrum, #326), Watch-Diktat, Teilen-Menü (iOS) | `LooseEnds/Views/CaptureView.swift`, `LooseEnds/Speech`, `Shared/Intents`, `LooseEndsShare` |
| Veredelung | Foundation Models auf dem Gerät, Schwelle 0,6, je Feld eine KI-Revision, Nachzügler-Lauf | `Shared/Enrichment` |
| Ansichten | Als nächstes, Neu, Fällig, Schnell, Alt, Wartet, Wiederkehrend, Geparkt, Alle offenen (alles außer Erledigtem, auch Geparktes und Wartendes, dringend zuerst, #319), Erledigt, Kontext, Projekt | `Shared/Models/ViewRules.swift`, `LooseEnds/Views/SidebarView.swift` |
| Liste | Wisch rechts/links, Erledigt drei Sekunden abbrechbar per Tipp auf die Zeile („Undo“, #32), Halten-Menü mit Verschieben (Morgen, Wochenende, nächste Woche, frei gewähltes Datum, #33), Parken, Löschen; Merkmalzeile; Drag-Sortierung in Als nächstes; Alt mit Alter und Verschiebungen; Erledigt nach Tagen; Projekt mit eingeklappten Unteraufgaben, per Pfeil aufklappbar und abhakbar (#28) | `LooseEnds/Views/TaskListView.swift`, `TaskRow.swift`, `Shared/Services/TaskActions.swift`, `PendingCompletions.swift` |
| Detail | Titel, Rohtext, Felder mit Editor, KI-Vorher/Nachher, Zurücksetzen, Änderungen-Sheet, Wiederholung, Unteraufgaben (eine Ebene, abhakbar; „Details“ öffnet das eigene Detail der Zeile, Merkmale grau darunter, Fällig und Etikett per Regel, Erledigen mit offenen Zeilen fragt nach, #565), Im Kalender anzeigen, Neu analysieren (#34) | `LooseEnds/Views/TaskDetailView.swift`, `FieldEditorView.swift`, `SubtasksSection.swift`, `Shared/Services/RevisionService.swift`, `FieldCodec.swift`, `Subtasks.swift`, `Shared/Enrichment/EnrichmentCoordinator.swift` |
| Startscreen | Als nächstes, Neu, Fällig immer; die übrigen Ansichten nur mit Inhalt; Projekte und Kontexte als einklappbare Gruppen, eingeklappt per Vorgabe; dort anlegen, umbenennen, löschen; unten immer „Alle offenen“ über „Erledigt“ (#319) | `LooseEnds/Views/SidebarView.swift`, `Shared/Services/CatalogService.swift` |
| Onboarding | Drei überspringbare Schritte beim ersten Start je Gerät: Siri-Satz, Mitteilungen erlauben, Startset der Kontexte; Hinweis, wenn Apple Intelligence fehlt (#29) | `LooseEnds/Views/OnboardingView.swift`, `OnboardingFlow.swift` |
| Mitteilung | „Heute fällig“ um 9 Uhr (einstellbar, geräteübergreifend) bzw. „Jetzt fällig“ zur Fälligkeitszeit, mit Erledigt, Als nächstes, Morgen; Tipp öffnet die Aufgabe (#311, #331) | `Shared/Notifications`, `LooseEnds/Notifications` |
| Kalender | Eigener Kalender „Loose Ends“, ein Termin je Aufgabe mit Schalter und Fälligkeit, Abgleich nach jedem Speichern; angelegt im ersten Konto, das es erlaubt (iCloud → Gerät → Standardkonto → übrige CalDAV, nie Exchange; Google lehnt ab, #203), Zielkalender als Zeile im Detail, Hinweis unter dem Schalter, wenn nichts klappt | `Shared/Services/CalendarSync.swift`, `LooseEnds/Calendar/CalendarBridge.swift` |
| Auslieferung | CI (Unit, iOS-Build, UI-Smoke, Design-Galerie hell/dunkel als Artefakt `DesignGallery`, #182), TestFlight-Workflow, Anleitung | `.github/workflows`, `docs/reference/testflight.md` |
| Lernkorpus | FocusBlox-Export (287 Aufgaben), Konfidenz-Kalibrierung gelaufen: Konfidenz trennt nicht (siehe `06-annahmen-und-experimente.md`, #65) | `scripts/export-focusblox-corpus.swift`; Kalibrierungs-Suite entfernt (#395), Bericht ist der Gerätestand aus #23 |
| Messstrecke | Treue-Korpus (317 Sätze in Hennings Bauformen, Wahrheit als Regel gegen den Messtag), Labor-App auf dem iPhone, die in Scheiben misst und nach jedem Satz sichert, Abholung per `sim.sh lab-fetch`, Auswertung und Bericht auf dem Mac; Mehrfachlauf-Infrastruktur (#107) und Selbstkonsistenz-Auswertung (#108) | `Measurement/`, `LooseEndsLab/`, `LooseEndsTests/DateTitleReportTests.swift`, `scripts/sim.sh` |
| Logo | App-Icon „der Knoten“ in Petrol: Hell, Dunkel, Getönt, Mac, Watch; Akzentfarbe Petrol; SVG-Quellen | `LooseEnds/Resources/Assets.xcassets`, `docs/design/logo/` |

Die Geschichte der Spikes zu den tragenden Annahmen (#65 bis #73, #92 bis #98, #111 bis #137) steht in
`docs/project/06-annahmen-und-experimente.md`.

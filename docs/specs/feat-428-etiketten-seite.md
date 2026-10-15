---
entity_id: feat-428-etiketten-seite
type: feature
created: 2026-10-15
updated: 2026-10-15
status: approved
workflow: feat-428-etiketten-seite
---

# Spec: #428 Etiketten und Projekte auf eigener Seite

## Approval

- [x] Approved (Henning, 2026-10-15, im Issue): „Eigene Seite.“

## Purpose

Befund in Build 59: Ein Tipp auf „Etiketten“ im Inhaltsverzeichnis (#421) klappte die Verwaltung ganz unten unter
„Erledigt“ auf, im alten Zellenstil, und der offene Zustand blieb über einen Neustart gespeichert. Seitdem öffnet die Zeile
eine eigene Seite im Stil des Inhaltsverzeichnisses. Rein Darstellung; keine Modelländerung.

## Source

| Datei | Änderung |
|---|---|
| `Shared/Models/ViewSelection.swift` | `case catalog(CatalogKind)`, `enum CatalogKind { tags, projects }` |
| `LooseEnds/Views/CatalogEditing.swift` | NEU: `CatalogEditor` und `catalogDialogs` (Anlegen, Umbenennen, Löschen, aus `SidebarView` herausgelöst), `NameEdit` |
| `LooseEnds/Views/CatalogPage.swift` | NEU: die Seite „Etiketten“ bzw. „Projekte“ |
| `LooseEnds/Views/StartZones.swift` | `IndexLineLabel` (Zeile des Verzeichnisses, von Index und Seite geteilt) |
| `LooseEnds/Views/SidebarView.swift` | iPhone: Zeilen öffnen die Seite, keine aufgeklappten Gruppen; iPad/Mac unverändert |
| `LooseEnds/App/ContentView.swift` | Detail zeigt `CatalogPage` bei `.catalog` |
| `LooseEndsUITests/*` | Tests gehen über die Seite statt über das Aufklappen |

## Acceptance Criteria

- **AC-1:** iPhone: Ein Tipp auf „Etiketten“ bzw. „Projekte“ öffnet eine eigene Seite: Name groß in New York, alle Einträge
  (auch ohne Aufgabe) in New York mit Punktlinie und Zahl (eine Null entfällt, #180), unten „Neues Etikett“ / „Neues Projekt“.
- **AC-2:** Auf der Seite: Tipp öffnet die Liste des Eintrags, langes Drücken bietet Umbenennen und Löschen, Wischen löscht nach
  Rückfrage. Ein doppelter Name wird weiter abgelehnt (#157).
- **AC-3:** Startseite iPhone: keine aufgeklappten Verwaltungszeilen mehr; die kursiven Wörter unter den Zeilen bleiben.
  `startShowsContexts`/`startShowsProjects` wirken auf dem iPhone nicht mehr.
- **AC-4:** iPad und Mac unverändert (einklappbare Gruppen der Seitenleiste).
- **AC-5:** Kennungen `contextsToggle`, `projectsToggle`, `newContextButton`, `newProjectButton`, `contextRow_<id>`,
  `projectRow_<id>` bleiben; neu `catalogTitle`.

## Abnahme

Stufe 1: Unit-Lauf und UI-Smoke in CI (`testProjectsLineOpensPage`, `ContextUniquenessTests`, `ProjectSubtasksTests`).
Stufe 2: Die Cloud-Sitzung hat keinen Simulator; Beleg ist der UI-Smoke-Lauf. Stufe 3: Kein Pfad der Geräteliste berührt.

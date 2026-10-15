---
entity_id: feat-421-inhaltsverzeichnis
type: feature
created: 2026-10-15
status: approved
---

# Spec: #421 Inhaltsverzeichnis unter „Jetzt“

## Approval

- [x] Approved (Henning, 2026-10-15): Entwurf E1 in https://claude.ai/artifact/AppBHrhym57SBMURaQck5P

## Source

| Datei | Änderung |
|---|---|
| `Shared/Models/ViewRules.swift` | `gridViews` → `indexViews`, „Schnell“ steht jetzt mit drin |
| `LooseEnds/Views/StartZones.swift` | `FitChips`, `AllViewsGrid` → `ContentsIndex` (Zeile mit Punktlinie, kursive Wörter) |
| `LooseEnds/Views/SidebarView.swift` | iPhone-Startseite nutzt `ContentsIndex` |
| `LooseEndsTests/StartViewsTests.swift` | `indexViews`, Schnell im Verzeichnis |

## Acceptance Criteria

- **AC-1:** Unter „Jetzt“ steht „Inhalt“ mit drei Gruppen: Als nächstes, Fällig, Neu und die seltenen Ansichten mit Inhalt
  (Schnell eingeschlossen) · Tags, Projekte · Alle offenen, Erledigt.
- **AC-2:** Namen in New York, Punktlinie, Zahl in SF grau; ab Bedienungshilfe-Schriftgröße entfällt die Punktlinie.
- **AC-3:** Tags und Projekte mit offenen Aufgaben stehen in Akzent unter ihrer Zeile, mit Zahl (seit #433 aufrecht, mit grauen Kommas wie im Entwurf); ein Tipp öffnet die Liste.
- **AC-4:** ~~Ein Tipp auf „Tags“ oder „Projekte“ klappt die Verwaltung auf und zu, wie bisher die Zellen.~~ Ersetzt durch
  #428 (Henning, 2026-10-15, Build 59: die Verwaltung erschien unten unter „Erledigt“ im alten Zellenstil): Der Tipp öffnet
  eine eigene Seite, siehe `feat-428-etiketten-seite.md`.
- **AC-5:** Keine Chips, kein Raster mehr; die Leiste „Neu“ und „Jetzt“ bleiben unverändert. iPad und Mac unverändert.
- **AC-6:** Kennungen `viewRow_*`, `contextsToggle`, `projectsToggle`, `chip_<id>` bleiben.

## Abnahme

Stufe 1: Unit-Tests und UI-Tests in CI. Stufe 2: Die Cloud-Sitzung hat keinen Simulator; Beleg ist der UI-Smoke-Lauf.
Stufe 3: Kein Pfad der Geräteliste berührt.

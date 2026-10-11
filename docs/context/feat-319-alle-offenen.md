# Context: feat-319-alle-offenen

## Request Summary
Issue #319: „Genauso wie es eine Ansicht "erledigt" gibt, muss es eine Ansicht für "alle offenen" geben.“
Eine neue Systemansicht, die alle offenen Aufgaben in einer Liste zeigt und auf dem Startbildschirm
wie „Erledigt“ als eigene Zeile erreichbar ist.

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Models/Enums.swift` | `enum ViewKind` (case, `titleKey`, `symbol`). Neuer Fall nötig, z. B. `.open` → „All open“ |
| `Shared/Models/ViewRules.swift` | `tasks(for:in:now:calendar:)` — Regel und Sortierung des neuen Falls; `dailyViews`/`occasionalViews`/`startViews` legen die Startbildschirm-Zeilen fest („Done sits apart at the bottom“) |
| `LooseEnds/Views/SidebarView.swift:110–113` | Eigene letzte Section mit der Erledigt-Zeile (`countRow(..., id: "viewRow_done")`, `.tag(.system(.done))`); Vorbild für die neue Zeile |
| `LooseEnds/Views/TaskListView.swift:105–118` | `emptySentence` — exhaustiver `switch kind`, braucht einen Leersatz für den neuen Fall |
| `LooseEnds/Views/TaskInteractions.swift:54–94` | Wischaktionen je Ansicht; der neue Fall fällt in `default` (Erledigen rechts, Als-nächstes links) — gewünscht, kein Eingriff nötig |
| `LooseEnds/Resources/Localizable.xcstrings` | Deutsche Texte („Completed“ → „Erledigt“); neuer Titel und Leersatz brauchen DE-Einträge. „All open“ existiert noch nicht, „Open“ → „Offen“ existiert |
| `Shared/Models/SavedView.swift` | `kindRaw` (CloudKit) mit Fallback `?? .next` — ein neuer Fall ist additiv, kein Schemaeingriff |
| `Shared/Models/ViewSelection.swift` | `.system(ViewKind)` — trägt den neuen Fall ohne Änderung |
| `LooseEndsTests/StartViewsTests.swift` | `everyViewHasAPlace` zieht `.done, .context, .project` von `allCases` ab — der neue Fall muss dort mit ausgenommen werden (sonst rot) |
| `LooseEndsTests/SubtaskTests.swift:78` | Liste der Ansichten, die keine Unteraufgaben zeigen — neuer Fall gehört dazu |
| `docs/project/02-datenmodell-und-ansichten.md:132–152` | Tabelle der Ansichtsregeln — neue Zeile |

## Existing Patterns
- Jede Systemansicht = ein `ViewKind`-Fall + ein `case` in `ViewRules.tasks(for:)`, reine Funktion über die geladenen Aufgaben, nur Oberaufgaben (`parent == nil`).
- „Offen“ ist im Code `TaskItem.isOpen` = `unprocessed || unverified || active` (`TaskItem.swift:131`). Geparkt und Erledigt sind damit nicht offen.
- Kontext- und Projektansichten nutzen bereits „alle offenen mit X“, sortiert nach `byUrgencyThenImportance` — die naheliegende Sortierung für „alle offenen“.
- „Wartet“ (blockiert) ist in den meisten Ansichten ausgeschlossen (`!isBlocked`), in „Alt“, Kontext und Projekt aber enthalten.
- Startbildschirm: drei Tagesansichten immer, gelegentliche nur mit Inhalt; „Erledigt“ unten abgesetzt in eigener Section mit Zähler.
- Zeilen-IDs `viewRow_<rawValue>` für UI-Tests.

## Dependencies
- Upstream: `TaskItem.isOpen`, `isBlocked`, `byUrgencyThenImportance`, `ViewSelection`, Lokalisierung.
- Downstream: `TaskListView` (Titel, Leersatz, Liste), `TaskInteractions` (Wischaktionen), Mac/iPad-Sidebar = dieselbe `SidebarView`. Widgets nutzen nur `.next` (`NextUpWidgetIntents.swift:90`), Watch nutzt `ViewKind` nicht — beide unberührt.

## Existing Specs
- Keine Spec zu Systemansichten in `docs/specs/`. Maßgeblich ist `docs/project/02-datenmodell-und-ansichten.md`.

## Risks & Considerations
- Exhaustive `switch`es über `ViewKind` (Enums.swift ×2, ViewRules, TaskListView.emptySentence) — Compiler meldet jede vergessene Stelle.
- `ViewKind.allCases` wird in Tests benutzt (StartViewsTests) — Test anpassen.
- CloudKit: kein Modellfeld neu, `kindRaw` ist ein String → kein `mac-schema-init` nötig.
- Geräteliste (CLAUDE.md Stufe 3): voraussichtlich kein Pfad berührt (nur `Shared/Models`, `LooseEnds/Views`, Resources).
- Produktfragen für die Analyse/den Entwurf: Blockierte (wartende) mitzeigen? Sortierung? Platz auf dem Startbildschirm (neben „Erledigt“ unten, oder oben bei den Tagesansichten)? Name („Alle offenen“ / „Offen“ / „Alle“)? Zähler an der Zeile?
- Scope klein: ~5 Dateien Code + Test + Doku, geschätzt < 80 LoC.

## Analysis

### Type
Feature

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Models/Enums.swift` | MODIFY | `ViewKind.open`, Titel „All open“, Symbol `circle` |
| `Shared/Models/ViewRules.swift` | MODIFY | `case .open`: Oberaufgaben mit `status != .done` (Neu, Wartende und Geparktes eingeschlossen), `byUrgencyThenImportance` |
| `LooseEnds/Views/SidebarView.swift` | MODIFY | Zeile `viewRow_open` in der letzten Section direkt über „Erledigt“, mit Zähler, immer sichtbar |
| `LooseEnds/Views/TaskListView.swift` | MODIFY | Leersatz für `.open` |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | „All open“ → „Alle offenen“, Leersatz DE |
| `LooseEndsTests/StartViewsTests.swift` | MODIFY | `.open` in `everyViewHasAPlace` ausnehmen; Regeltest (Erledigt/Unteraufgaben raus, Wartende und Geparkte rein, Sortierung) |
| `LooseEndsTests/SubtaskTests.swift` | MODIFY | `.open` zu den Ansichten ohne Unteraufgaben |
| UI-Test (bestehende Smoke-Datei) | MODIFY | Zeile `viewRow_open` antippen, Liste zeigt offene Aufgabe, nicht die erledigte |
| `docs/project/02-datenmodell-und-ansichten.md` | MODIFY | Zeile in der Regeltabelle |

### Scope Assessment
- Files: 4 Code + 2–3 Tests + 1 Doku
- Estimated LoC: +60/-2
- Risk Level: LOW (Compiler sichert die exhaustiven `switch`es; kein Modellfeld, kein CloudKit-Schema; `ViewSelection` wird nicht gespeichert, `SavedView.kindRaw` fällt auf `.next` zurück; Widgets/Watch/Intents nutzen `ViewKind` nicht)
- Geräteliste Stufe 3: kein Pfad berührt.

### Technical Approach
Neuer Systemfall nach dem Muster von „Erledigt“ (Plan-Bewertung bestätigt, keine Befunde dagegen). Wischaktionen fallen in `default`: nach rechts Erledigen, nach links Vormerken.
Entwurf: `docs/artifacts/feat-319-alle-offenen/index.html` (veröffentlicht: https://claude.ai/artifact/54cdy9kj31m8QSRCrVnvVE).
Empfehlung: Zeile unten über „Erledigt“, flache Liste. Alternativen: (1) Zeile oben vor den Tagesansichten, (2) Liste nach Fälligkeit gruppiert.
Recherche: keine Fehlermeldung, keine neue Schnittstelle (nur bestehende SwiftUI-Liste); Apple Erinnerungen hat dieselbe Sammelliste „Alle“ neben „Erledigt“.

### Dependencies
`TaskItem.isOpen`, `isBlocked`, `ViewRules.byUrgencyThenImportance`, `ViewSelection.system`, Lokalisierung.

### Open Questions
- [x] PO (Henning, 2026-10-11): Zeile unten über „Erledigt“; **Geparktes gehört dazu** (Abweichung von der Empfehlung); flache Liste, dringend zuerst.
- [ ] Spec klärt: Geparkte Zeile erkennbar machen (Mond-Glyphe) und ihr Wisch nach links = „Aktivieren“ statt „Vormerken“, denn eine geparkte Aufgabe erscheint nicht in „Als nächstes“ (Regel `isOpen`). Erledigen per Wisch nach rechts wie überall.

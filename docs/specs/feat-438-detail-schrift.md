---
entity_id: feat-438-detail-schrift
type: feature
created: 2026-10-15
updated: 2026-10-15
status: approved
workflow: feat-438-detail-schrift
---

# Spec: #438 Detail T1, Schrift und Abstände wie die Startseite

## Approval

- [x] Approved (Henning, 2026-10-15): „T1 + C“, Entwurf https://claude.ai/artifact/HD818Gm9YorDsjN7uFy9z5

## Source

| Datei | Änderung |
|---|---|
| `LooseEnds/Views/TaskDetailView.swift` | Titel 23 pt New York medium; „GESAGT“ + Satz als ein Text; Registerzeilen als Knopf mit `navigationDestination`; `listSectionSpacing(.compact)` |
| `LooseEnds/Views/FieldFormatting.swift` | `dueWords`: Heute/Morgen/Gestern, sonst kurzes Datum, Uhrzeit nach Komma |
| `LooseEnds/Views/Paper.swift` | `captionHead()` für Abschnittsköpfe |
| `LooseEnds/Views/PlaceSection.swift`, `SubtasksSection.swift`, `WaitingOnSection.swift` | Köpfe mit `captionHead()` |
| `LooseEnds/Resources/Localizable.xcstrings` | „You said:“ → „Said“ / „Gesagt“ |
| `LooseEndsTests/DueWordsTests.swift` | Unit-Tests |

## Acceptance Criteria

- **AC-1:** Der Titel steht in New York medium, 23 pt, und skaliert mit Dynamic Type.
- **AC-2:** Der gesagte Satz bricht am linken Rand um, davor steht klein „GESAGT“. Die Kennung `detailRawText` trägt den Rohtext als Beschriftung.
- **AC-3:** Feldzeilen haben den Namen grau in fester Spalte, den Wert in New York, keinen Pfeil. Ein Tipp öffnet den Editor. Die Kennungen `field_*` bleiben.
- **AC-4:** Fälligkeit in Worten. Rot bei Zeitdruck (dieselbe Regel wie die Randspalte), sonst Akzent für KI/Regel, sonst Primärfarbe.
- **AC-5:** Die Abschnittsköpfe Ort, Unteraufgaben, Wartet auf und Quelle stehen als kleine gesperrte Großbuchstaben.

## Abnahme

- Stufe 1: `DueWordsTests` und der volle Unit-Lauf in CI, UI-Smoke.
- Stufe 2: Die Cloud hat keinen Simulator, Beleg ist der UI-Smoke-Lauf.
- Stufe 3: Kein Pfad der Geräteliste berührt.

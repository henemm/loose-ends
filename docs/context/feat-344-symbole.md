# Context: feat-344-symbole (#344 Bessere Symbole, Epic #466)

## Request Summary
Henning (Screenshots in #344): Die Fahne (wichtig) und der Blitz (dringend) unter dem Titel in der Listenzeile sind unklar
(„wer da nicht ein! Und zwei! Für sehr dringlich, besser? recherchiere dazu!“). Die verwendeten Symbole sollen in der
Detailansicht hinter dem jeweiligen Wort stehen; auf dem Bild markiert: Wichtigkeit, Dringlichkeit, Fällig, Dauer, Projekt.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Views/TaskRow.swift:159-199` | Listenzeile: `flag.fill` (Wichtigkeit hoch), `bolt.fill` (Dringlichkeit hoch), beide schwarz, ohne Text; Traits `clock` (Dauer), `location`, `lock`, `checklist`; Fälligkeit steht im Rand |
| `LooseEnds/Views/TaskDetailView.swift:765-813` | `fieldRow`: Beschriftung klein grau in fester Spalte (`labelWidth` 92), Wert in New York; kein Symbol an der Beschriftung |
| `Shared/Models/DetailFields.swift` | Feld-Gruppen (what/when/weight/filing/connection/drive); mögliche Heimat einer Zuordnung Feld → Symbol |
| `Shared/Models/Enums.swift:94-110` | `symbol` der Ansichten (calendar, clock, tag, folder, star …): vorhandene Zeichensprache |
| `LooseEnds/Views/FieldEditorView.swift` | Editor-Seiten (Wichtigkeit/Dringlichkeit als Leiter mit Balken, #482) |
| `docs/project/03-design-briefing.md:110` | Beschluss: Fahne und Blitz als schwarze Glyphen am Anfang der Merkmalzeile, ohne Text, ohne Farbe, nie Emoji |
| `docs/project/00-entscheidungen.md:173` | Wichtigkeit hat keine Farbe, sie sortiert und trägt ein Glyph |
| `CLAUDE.md` Ground rules | „SF Symbols only“ (#350): kein Emoji, keine Zeichen als Symbol-Ersatz — „!“ / „!!“ als Text wäre ein Verstoß, außer als SF Symbol (`exclamationmark`, `exclamationmark.2`) |

## Existing Patterns
- Farbbudget: Akzent = antippbar, Rot = Zeitdruck, Grau = Hierarchie. Fahne und Blitz sind schwarz (Tinte), nicht antippbar.
- Listenzeile zeigt Wichtigkeit/Dringlichkeit nur bei „hoch“; im Detail stehen die Wörter Niedrig/Mittel/Hoch.
- Die Zeichen derselben Dinge stehen schon an anderen Stellen: Dauer `clock`, Ort `location`, Wartet `lock`, Etikett `tag`, Projekt `folder` (Ansichten).
- Geschwister-Tickets im Epic #466: #375 (Haken, geschlossen als Dublette von #435), #429 (Farbe der Wischzeichen, bestätigt 2026-10-16: `checkmark.circle`, `moon.zzz`, `sun.max`, `eye`).

## Dependencies
- Upstream: SwiftUI, SF Symbols; `FieldFormatting.label(field)` liefert die Beschriftung.
- Downstream: Listenzeile erscheint in jeder Liste, auf der Startseite, in „Jetzt“, im Mac-Layout; Detail auf iPhone, iPad, Mac (`labelWidth` ist skaliert). Watch/Widgets nutzen `TaskRow` nicht (Pfad der Geräteliste nicht berührt).

## Existing Specs
- Keine eigene Spec zu den Zeichen. Relevant: Design-Briefing Abschnitt Listenzeile und Detail (#438 Registerzeilen).

## Risks & Considerations
- Fahne und Blitz haben mehrere Bedeutungen in anderen Apps (Fahne = markiert/gekennzeichnet in Mail und Erinnerungen; Blitz = schnell/Energie). Die Recherche muss zeigen, was Menschen darin lesen.
- „!“ als Text verbietet die Projektregel; als SF Symbol (`exclamationmark`, `exclamationmark.2`) möglich, Wichtigkeit und Dringlichkeit müssen sich aber unterscheiden lassen, wenn beide hoch sind.
- Die Zeichen im Detail dürfen die Registerzeile nicht verbreitern (`labelWidth` 92 skaliert mit der Schriftgröße) und müssen für VoiceOver die Beschriftung behalten.
- Sichtbare Änderung: nach Projektregel Entwurf vor Spec (Artefakt unter `docs/artifacts/feat-344-symbole/`, Heute neben Entwurf, Dunkel und Hell, mindestens eine Alternative, grafisch verschieden).
- Alternative zum bisherigen Weg (für die Analyse): kein Zeichen mehr, sondern Worte in der Zeile („Wichtig“, „Dringend“), oder Zeichen nur im Detail und in der Zeile gar nichts, weil die Sortierung die Information schon trägt.

## Analysis

### Type
Feature (sichtbare Umgestaltung: Zeichen in Listenzeile und Detail).

### Recherche (2026-10-24)
- Outlook: hohe Wichtigkeit = rotes Ausrufezeichen; Fahne = „nachfassen“. Apple Erinnerungen: Fahne = „markiert“, Priorität = 1–3 Ausrufezeichen.
- Ayoa: Fahne = Wichtigkeit, Blitz = Dringlichkeit; Amazing Marvin: Stern/Feuer. Kein Standard. Quellen: support.ayoa.com/task-importance, support.ayoa.com/urgency-levels, intercom.help/amazing-marvin/en/articles/1950152-importance-levels.
- FocusBlox (Vorgänger, GitHub `henemm/timebox-ios`, `Sources/Helpers/TaskMetadataUI.swift`): Wichtigkeit = `exclamationmark` / `.2` / `.3` für Niedrig / Mittel / Hoch (Farbe blau/gelb/rot), Dringlichkeit = `flame.fill` (orange) bzw. `flame` (nicht dringend). Im Tippen-Badge mit Zugänglichkeits-Label „Wichtigkeit: Hoch“.
- Befund: Kein Zeichen erklärt sich allein; Wort daneben oder dieselbe Paarung an zweitem Ort hilft.

### Entwurf
`docs/artifacts/feat-344-symbole/entwurf.html` (Artefakt https://claude.ai/artifact/36Tbu353x1CVWVnyFm1aum): Heute, A (Hennings „!“ / „!!“), B (Zeichen + Wort, Empfehlung), C (nur Wörter in der Zeile, Zeichen im Detail). Ausstehend: Hennings Wahl (Design-Freigabe vor /30-write-spec).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Views/TaskRow.swift` | MODIFY | Zeichen (und Wort bei B) für Wichtig/Dringend in der Merkmalzeile |
| `LooseEnds/Views/TaskDetailView.swift` | MODIFY | `fieldRow`: Zeichen hinter dem Wort für Wichtigkeit, Dringlichkeit, Fällig, Dauer, Projekt; VoiceOver-Label bleibt |
| `Shared/Models/DetailFields.swift` | MODIFY | eine Quelle Feld → Symbol (auch für die Zeile) |
| `LooseEndsUITests/…` | CREATE/MODIFY | Smoke: Zeichen in Zeile und Detail vorhanden |
| `docs/project/03-design-briefing.md` | MODIFY | Beschluss „Fahne/Blitz ohne Text“ ersetzen |

### Scope Assessment
- Files: 4–5, ca. +120/−20 LoC, Risk: LOW (rein Darstellung; Listenzeile erscheint überall, Watch/Widgets nutzen `TaskRow` nicht; kein Pfad der Geräteliste).

### Technical Approach
Empfehlung B (nach FocusBlox-Befund geändert): eine Zuordnung Feld → SF Symbol (Wichtigkeit `exclamationmark`-Leiter 1/2/3 wie im Vorgänger, Hoch = `.3`; Dringend `flame`; Fällig `calendar`, Dauer `clock`, Projekt `folder`), in Zeile mit Wort, im Detail hinter dem Wort. Rein SwiftUI, ohne Modell. Alternative: A (Hennings Zeichen, kippt Beschluss in 03-design-briefing:110), C (nur Wörter). Kein Modell nötig („Regeln vor Modell“ trifft nicht zu).

### Dependencies
Detail-`labelWidth` (92, skaliert) darf nicht wachsen; Zeichen stehen hinter dem Wert. Alle Symbolnamen auf macOS geprüft vorhanden.

### Open Questions
- [ ] Hennings Wahl A / B / C
- [ ] Bei B: Sanduhr für „Dringend“ oder Blitz behalten?

### Entscheidung (Henning, 2026-10-24)
„B ohne Wort in der Zeile“: wie FocusBlox. Zeile: nur Zeichen, und nur bei „Hoch“ wie heute (Wichtigkeit `exclamationmark.3`, Dringlichkeit `flame`), kein Wort. Detail: dasselbe Zeichen hinter dem Wort für Wichtigkeit (Leiter 1/2/3 nach Stufe), Dringlichkeit, Fällig, Dauer, Projekt. VoiceOver-Label bleibt („Important“/„Urgent“). Beschluss in `docs/project/03-design-briefing.md:110` („Fahne und Blitz“) wird in der Spec ersetzt; Farbe bleibt Tinte (Henning hat keine Farbe verlangt; FocusBlox färbte, Loose Ends nicht: Farbbudget).
Open Questions erledigt: Wahl = B ohne Wort; „Dringend“ = Flamme statt Sanduhr/Blitz.

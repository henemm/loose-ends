---
entity_id: feat-344-symbole
type: feature
created: 2026-10-24
updated: 2026-10-24
status: draft
workflow: feat-344-symbole
---

# Spec: #344 Bessere Symbole (Wichtigkeit, Dringlichkeit, Fällig, Dauer, Projekt)

## Approval

- [ ] Approved (Henning)

## Purpose

Henning (#344): Die Fahne (wichtig) und der Blitz (dringend) unter dem Titel sind unklar („wer da nicht ein! Und zwei! Für sehr
dringlich, besser?“), und die Zeichen sollen in der Detailansicht beim jeweiligen Feld stehen (markiert: Wichtigkeit, Dringlichkeit,
Fällig, Dauer, Projekt). Recherche und Entwurf: `docs/context/feat-344-symbole.md`, `docs/artifacts/feat-344-symbole/entwurf.html`.

Entscheidung (Henning, 2026-10-24): „B ohne Wort in der Zeile“, wie im Vorgänger FocusBlox.

- **Listenzeile:** nur Zeichen, kein Wort, und nur bei „Hoch“ wie heute. Wichtigkeit hoch = `exclamationmark.3`, Dringlichkeit
  hoch = `flame`. Beide in Tinte (primär), nicht antippbar, VoiceOver-Label „Important“ / „Urgent“ bleibt.
- **Detail:** dasselbe Zeichen steht in der Registerzeile hinter dem Wert: Wichtigkeit als Leiter nach Stufe (Niedrig `exclamationmark`,
  Mittel `exclamationmark.2`, Hoch `exclamationmark.3`), Dringlichkeit `flame`, Fällig `calendar`, Dauer `clock`, Projekt `folder`.
- **Beschluss ersetzt:** `docs/project/03-design-briefing.md:110` („Fahne, Blitz, ohne Text“) wird durch diese Zuordnung ersetzt.

Regelweg-Vermerk (Regeln vor Modell): reine Darstellung, kein Modell beteiligt.

## Source

- **File:** `Shared/Models/FieldGlyph.swift` (neu)
- **Identifier:** `FieldGlyph.symbol(for:importance:)` und `FieldGlyph.symbol(for:)` (reine Zuordnung Feld → SF-Symbol-Name)

## Lösung

1. **`Shared/Models/FieldGlyph.swift` (neu).** Eine Quelle für Zeile und Detail, reine Strings, ohne SwiftUI (die Datei liegt in
   `Shared/`, das auch in Watch und Widgets übersetzt wird):
   - `importance(_: Importance) -> String`: `.low` → `exclamationmark`, `.medium` → `exclamationmark.2`, `.high` → `exclamationmark.3`.
   - `symbol(for: RevisedField) -> String?`: `.urgency` → `flame`, `.dueDate` → `calendar`, `.duration` → `clock`, `.project` → `folder`;
     alle anderen Felder `nil` (keine Zeichen für Energie, Etiketten, Wiederholung, Ort, Notiz …; nicht in diesem Ticket).
   - Dringlichkeit trägt in allen Stufen dasselbe Zeichen (die Stufe sagt das Wort); nur Wichtigkeit hat die Leiter.
2. **`LooseEnds/Views/TaskRow.swift`.** `flag.fill` wird `FieldGlyph.importance(.high)`, `bolt.fill` wird `FieldGlyph.symbol(for: .urgency)`.
   Bedingung (nur bei „Hoch“), Reihenfolge, Farbe `.primary` und Labels bleiben. Neu: Kennungen `importanceMarker_<id>` und
   `urgencyMarker_<id>` (Muster der vorhandenen `countsMarker_`/`knaeuelMarker_`).
3. **`LooseEnds/Views/TaskDetailView.swift`, `fieldRow`.** Hinter Wert (bzw. „New date“-Text) und vor dem Herkunftszeichen steht
   bei Wichtigkeit, Dringlichkeit, Fällig, Dauer und Projekt das Zeichen: `.imageScale(.small)`, `.foregroundStyle(.secondary)`
   (Grau = Hierarchie; rot/Akzent bleiben dem Wert und dem Herkunftszeichen), `.accessibilityHidden(true)` (die Zeile liest
   Beschriftung und Wert, das Zeichen wiederholt nur), Kennung `fieldGlyph_<field>`. `labelWidth` und die Beschriftungsspalte
   bleiben unverändert; das Zeichen verbreitert die Beschriftung nicht.
4. **`docs/project/03-design-briefing.md`.** Zeile 110 ersetzt den Fahne/Blitz-Beschluss durch Ausrufezeichen-Leiter und Flamme,
   in der Zeile nur bei Hoch ohne Text, im Detail hinter dem Wert.

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `Shared/Models/FieldGlyph.swift` | CREATE | Zuordnung Feld/Stufe → Symbolname |
| `LooseEnds/Views/TaskRow.swift` | MODIFY | Zeichen der Merkmalzeile aus `FieldGlyph`, neue Kennungen |
| `LooseEnds/Views/TaskDetailView.swift` | MODIFY | `fieldRow` zeigt das Zeichen hinter dem Wert |
| `LooseEndsTests/FieldGlyphTests.swift` | CREATE | Zuordnung (RED zuerst) |
| `LooseEndsUITests/FieldsSmokeTests.swift` | MODIFY | Zeichen in Zeile und Detail vorhanden |
| `docs/project/03-design-briefing.md` | MODIFY | Beschluss ersetzt (Dokumentation) |

### Estimated Changes

- Dateien: 5 Code/Test + 1 Dokument (Limit 4–5 gehalten, die Dokumentation zählt nicht als Code)
- LoC: ca. +90 / −10, jede Funktion ≤ 50 LoC

**Geräteliste (CLAUDE.md):** Berührt werden `Shared/Models/`, `LooseEnds/Views/`, `LooseEndsTests/`, `LooseEndsUITests/`, `docs/`.
Keiner dieser Pfade steht auf der Liste. Kein Eintrag in `project.yml`, keine Berechtigung, kein AppStorage-Schlüssel, keine Audio-Datei,
keine Modelländerung (kein CloudKit-Schema).

### Nicht in diesem Ticket

- Farbe für die Zeichen (Henning hat keine verlangt; FocusBlox färbte, Loose Ends nicht: Farbbudget).
- Zeichen für Energie, Etiketten, Wiederholung, Ort, Notiz, Unteraufgaben.
- Zeichen in den Editor-Seiten (Wichtigkeit/Dringlichkeit als Leiter mit Balken, #482), auf Watch und in Widgets (`TaskRow` läuft dort nicht).
- Das Zeichen für Fällig, Dauer und Projekt in der Listenzeile (die Randspalte und die Merkmale tragen sie bereits: `clock` für Dauer).

## Test Plan

### Automated Tests (TDD RED)

`LooseEndsTests/FieldGlyphTests.swift` (Swift Testing, im iOS-Simulator), zuerst rot, weil `FieldGlyph` fehlt:

- [ ] Test 1: GIVEN Wichtigkeit Niedrig/Mittel/Hoch THEN `exclamationmark` / `exclamationmark.2` / `exclamationmark.3`.
- [ ] Test 2: GIVEN die Felder Dringlichkeit, Fällig, Dauer, Projekt THEN `flame`, `calendar`, `clock`, `folder`.
- [ ] Test 3: GIVEN Felder ohne Zeichen (Energie, Etiketten, Wiederholung, Ort, Notiz, Titel …) THEN `nil`.
- [ ] Test 4: GIVEN alle Namen der Zuordnung WHEN als Systemsymbol gebaut THEN existiert jedes (`UIImage(systemName:)` ≠ nil), plus ein
  Symbol-Aus-Zeile-Test: kein Name ist `flag.fill` oder `bolt.fill`.

`LooseEndsUITests/FieldsSmokeTests.swift` (Smoke, nach dem Designfrost):

- [ ] UI-Test A: GIVEN eine Aufgabe mit Wichtigkeit Hoch und Dringlichkeit Hoch WHEN die Liste erscheint THEN stehen `importanceMarker_<id>`
  und `urgencyMarker_<id>` in der Zeile (mit Label „Important“ / „Urgent“), und es steht kein Wort „Important“/„Urgent“ als sichtbarer Text.
- [ ] UI-Test B: GIVEN dieselbe Aufgabe mit Fälligkeit, Dauer und Projekt WHEN das Detail öffnet THEN steht `fieldGlyph_importance`,
  `fieldGlyph_urgency`, `fieldGlyph_dueDate`, `fieldGlyph_duration`, `fieldGlyph_project` je in der Registerzeile des Feldes
  (`field_<name>`); die Zeile `field_importance` trägt weiter ihre Beschriftung „Importance“/„Wichtigkeit“ und den Wert.
- [ ] UI-Test C: GIVEN eine Aufgabe mit Wichtigkeit Niedrig THEN zeigt die Zeile kein Zeichen (nur bei Hoch), das Detail aber `exclamationmark`.

### Abnahme (Stufen)

1. **Tests:** `./scripts/sim.sh generate`, `./scripts/sim.sh sim-unit` (nie `unit`, nie Mac als Host): neue Tests rot vor, grün nach dem Bau.
2. **Simulator / Benutzung:** `./scripts/sim.sh build`, `launch`, `screenshot`, dann `./scripts/sim.sh test-proof FieldsSmokeTests`.
   Eine Aufgabe mit „Hoch/Hoch“ wird gesprochen/angelegt, Liste und Detail werden fotografiert (hell und dunkel), die Bilder
   geöffnet und beschrieben: Ausrufezeichen und Flamme in der Zeile, fünf Zeichen im Detail, Beschriftungsspalte unverändert breit.
3. **Gerät:** Kein Pfad der Geräteliste berührt.

## Acceptance Criteria

- **AC-1:** Given Wichtigkeit Niedrig, Mittel, Hoch / When `FieldGlyph.importance` fragt / Then `exclamationmark`, `exclamationmark.2`,
  `exclamationmark.3`. Belegt durch Unit-Test 1 (zuerst rot).
- **AC-2:** Given die Felder Dringlichkeit, Fällig, Dauer, Projekt / When `FieldGlyph.symbol(for:)` fragt / Then `flame`, `calendar`,
  `clock`, `folder`; alle anderen Felder `nil`, und jeder Name ist ein vorhandenes Systemsymbol. Belegt durch Unit-Tests 2 bis 4.
- **AC-3:** Given eine Aufgabe mit Wichtigkeit Hoch und Dringlichkeit Hoch / When die Listenzeile erscheint / Then stehen
  `exclamationmark.3` und `flame` in Tinte ohne Wort und ohne Farbe vor den übrigen Merkmalen (`importanceMarker_<id>`,
  `urgencyMarker_<id>`, Labels „Important“/„Urgent“); `flag.fill` und `bolt.fill` gibt es nirgends mehr. Belegt durch UI-Test A und Diff-Prüfung.
- **AC-4:** Given Wichtigkeit oder Dringlichkeit Niedrig/Mittel oder nicht gesetzt / When die Listenzeile erscheint / Then zeigt sie
  kein Zeichen dafür (unverändert „nur bei Hoch“). Belegt durch UI-Test C.
- **AC-5:** Given eine Aufgabe mit gesetzten Feldern Wichtigkeit, Dringlichkeit, Fällig, Dauer, Projekt / When das Detail öffnet /
  Then steht in jeder dieser Registerzeilen das Zeichen hinter dem Wert (`fieldGlyph_<field>`), Wichtigkeit nach Stufe.
  Belegt durch UI-Test B und C.
- **AC-6:** Given die Registerzeile / When sie mit Zeichen erscheint / Then bleibt die Beschriftungsspalte (`labelWidth` 92,
  skaliert) unverändert, VoiceOver liest Beschriftung und Wert wie bisher (Zeichen `accessibilityHidden`), und der Wert behält seine
  Farbe (rot bei Zeitdruck, Akzent bei KI/Regel). Belegt durch Diff-Prüfung, UI-Test B und die geöffneten Simulatorbilder.
- **AC-7:** Given `docs/project/03-design-briefing.md` / When geprüft / Then beschreibt Zeile 110 Ausrufezeichen-Leiter und Flamme
  statt Fahne und Blitz. Belegt durch Diff-Prüfung.
- **AC-8:** Given der Diff / When er geprüft wird / Then berührt er nur die genannten Dateien, kein Pfad der Geräteliste; kein `try?`,
  kein `print`, kein Emoji, nur SF Symbols; alle bestehenden Unit- und UI-Tests und der iOS-Bau sind grün.

## Dependencies

| Entity | Type | Purpose |
|---|---|---|
| SF Symbols (`exclamationmark`, `.2`, `.3`, `flame`, `calendar`, `clock`, `folder`) | Systemsymbole | alle auf macOS und iOS geprüft vorhanden |
| `RevisedField`, `Importance` (`Shared/Models/Enums.swift`) | Modell | Schlüssel der Zuordnung |
| `FieldFormatting.label(_:)` | Hilfe | Beschriftung bleibt unverändert |
| #482 (Leitern in den Editoren), #438 (Registerzeilen), #350 (nur SF Symbols), #466 (Epic) | Vorarbeit | bleiben unverändert |
| FocusBlox `Sources/Helpers/TaskMetadataUI.swift` | Vorbild | gleiche Ausrufezeichen-Leiter und Flamme |

Keine neue externe Abhängigkeit.

## Risiken

- **Lesbarkeit von `exclamationmark.3` klein (mittel):** Die drei Striche sind bei `.caption` und `.imageScale(.small)` eng. Beleg
  sind die Simulatorbilder hell/dunkel; bei Unlesbarkeit ändert sich nur der Maßstab, nicht die Zuordnung.
- **Ohne Wort bleibt „Flamme = dringend“ erlernt (mittel):** Henning hat „ohne Wort“ gewählt; das Detail bietet die Paarung Zeichen
  + Wort als Lernort, die Zeile selbst erklärt sich nicht. Alternative C (Wörter in der Zeile) bleibt offen, falls es nicht trägt.
- **„Hinter dem Wort“ gelesen als „hinter dem Wert“ (niedrig):** In der Registerzeile steht das Zeichen hinter dem Wert, nicht hinter
  der Beschriftung, damit die feste Spalte nicht wächst.
- **Gleiche Flamme in allen Dringlichkeitsstufen (niedrig):** Das Zeichen markiert das Feld; das Wort trägt die Stufe.

## Alternativen

- **A, „!“ / „!!“ als Text (Hennings Zeichen):** Verstößt gegen „SF Symbols only“ (#350) als Text; als `exclamationmark`/`.2` möglich,
  unterscheidet aber Wichtigkeit und Dringlichkeit nicht, wenn beide hoch sind. Verworfen.
- **C, Wörter in der Zeile, Zeichen nur im Detail:** erklärt sich selbst, macht die Zeile aber länger; widerspricht Hennings Wahl. Offen als Rückfall.
- **Zeichen und Wort in der Zeile (B mit Wort):** vom Entwurf empfohlen, von Henning abgewählt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: Reine Darstellungsänderung; weder Speicherort, Datenmodell, Plattformzuschnitt noch Abgleich ändern
  sich. Der Beschluss „Fahne und Blitz ohne Text“ im Design-Briefing (Zeile 110) wird ersetzt, ist aber kein ADR.

## Offene Fragen

- Keine. Entschieden: B ohne Wort in der Zeile, Flamme statt Sanduhr/Blitz, Tinte statt Farbe (Henning, 2026-10-24).

## Definition of Done

- [ ] AC-1 bis AC-8 erfüllt; Unit-Tests zuerst rot, dann grün; `./scripts/sim.sh sim-unit`, `build` und `test-proof FieldsSmokeTests` grün.
- [ ] Simulatorbilder von Zeile und Detail (hell/dunkel) geöffnet und beschrieben.
- [ ] Abschlussbericht: „Kein Pfad der Geräteliste berührt.“ PR mit `Closes #344`.

## Changelog

- 2026-10-24: Initiale Spec für #344 (Entscheidung „B ohne Wort in der Zeile“).

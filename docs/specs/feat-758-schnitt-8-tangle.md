---
entity_id: feat-758-schnitt-8-tangle
type: feature
created: 2026-10-30
updated: 2026-10-30
status: approved
workflow: feat-758-schnitt-8-tangle
---

# Spec: #758 Schnitt 8 — Das Knäuel heißt auf Englisch „the Tangle“

Epic #750. Unabhängig. Modell: Haiku.

## Approval

- [x] Approved — pauschal durch Henning am 2026-10-30 über #750. Wort „the Tangle“: Henning, 2026-10-30.
  Ausnahme der Geräteliste für reine Texte in `LooseEndsWidgets/`: Henning, 2026-10-30.

## Purpose

Knäuel wird je Sprache übersetzt. Deutsch bleibt „das Knäuel“, Englisch „the Tangle“. Englisch ist Quellsprache, also
ändern sich Code-Literale und Katalogschlüssel; die deutschen Werte bleiben.

Ohne Modell geht es nicht: nicht relevant.

## Source

Literale mit „Knäuel“ (Stand 2026-10-30): `LooseEnds/Views/TaskInteractions.swift` Z. 195, 198, 360, 365, 368;
`TaskDetailView.swift` 645, 648, 660; `Knaeuel.swift` 206, 222; `TaskRow.swift` 185; `FieldFormatting.swift` 20;
`FieldSettingsView.swift` 116; `LooseEndsWidgets/NextUpWidget.swift` 279, 335. Kataloge: `LooseEnds/Resources/Localizable.xcstrings`,
`LooseEndsWidgets/Localizable.xcstrings`. UI-Tests: `LooseEndsUITests/DriveSmokeTests.swift` (englische Wörter).
Doku: CLAUDE.md (Absätze „SF Symbols only“, „Shared/Models — the drive fields“, Stufe-3-Tabelle), `docs/project/03-design-briefing.md`.

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| 8 Swift-Dateien oben | MODIFY | „Knäuel“ → „Tangle“ in englischen Literalen; Typ-/Dateinamen bleiben |
| 2 `Localizable.xcstrings` | MODIFY | alte Schlüssel raus, neue rein, deutsche Werte übertragen, `translated` |
| LooseEndsUITests/DriveSmokeTests.swift | MODIFY | Wörter |
| CLAUDE.md | MODIFY | Stufe-3-Tabelle: Ausnahme-Zeile; zwei Absätze nennen „the Tangle“ |
| docs/reference/abnahme-und-arbeitsweise.md | MODIFY | nur falls die Tabelle dort wiederholt wird |
| docs/project/03-design-briefing.md | MODIFY | ein Klammerzusatz |

LoC Produkt ≈ 16 geänderte Zeilen.

## Implementation Details

- Wortlaut der Ausnahme in CLAUDE.md, unter der Zeile `LooseEndsWidgets/` der Tabelle:
  „Ausnahme (Henning, 2026-10-30, #758): Änderungen in `LooseEndsWidgets/`, die nur Katalogschlüssel oder Textliterale
  betreffen (kein Layout, keine Logik, keine Intents, keine `Info.plist`), enden nach Stufe 2. Beleg: Katalogwächter grün
  und Screenshot der Widget-Galerie im Simulator.“
- Vorgehen Katalog: Literale ändern, `./scripts/sim.sh generate && ./scripts/sim.sh build` (zieht neue Schlüssel in die
  Kataloge), dann je neuem Schlüssel die `de`-Einheit vom alten Schlüssel kopieren, alte Schlüssel löschen. Prüfen mit
  `python3 -m unittest scripts.test_catalog_languages` .
- Widget-Galerie-Screenshot: Simulator, Home-Bildschirm lange drücken → „+“ → Loose Ends; alternativ der UI-Test
  `NextUpWidgetTests`, falls er die Beschreibung rendert. Bild im PR.

## Test Plan

- [ ] `./scripts/sim.sh test-proof DriveSmokeTests` grün (en) und `LOOSEENDS_LANG=de ./scripts/sim.sh test-proof DriveSmokeTests` grün, Belege im PR.
- [ ] Katalogwächter grün.
- [ ] `NextUpWidgetTests` grün.

## Acceptance Criteria

- **AC-1:** `grep -rn "Knäuel" LooseEnds LooseEndsWidgets Shared --include=*.swift | grep -v '///' | grep -v '// '` leer.
- **AC-2:** `grep -c "Tangle" LooseEnds/Resources/Localizable.xcstrings` ≥ 12; jede dieser Einheiten hat `de` mit „Knäuel“.
- **AC-3:** Beide `test-proof`-Belege und der Galerie-Screenshot im PR.
- **AC-4:** CLAUDE.md enthält die Ausnahme-Zeile wörtlich.

## Definition of Done

- [ ] AC-1 bis AC-4 belegt. PR `feat: das Knäuel heißt auf Englisch the Tangle (Refs #750, Closes #758)`; Merge; Board Done.
- [ ] Abschlussbericht: „Stufe 2 reicht: Ausnahme der Geräteliste für reine Texte (Henning, 2026-10-30).“

## Changelog

- 2026-10-30: Spec erstellt.

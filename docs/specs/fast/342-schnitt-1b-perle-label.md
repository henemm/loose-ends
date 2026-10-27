# Mini-Spec: Label „Perle sammeln“ statt „Counts“, Test findet fehlende Katalogeinträge (#342, Schnitt 1b)

**ADR-Nr.:** keine — kein Architekturthema, eine Beschriftung und ein Test.

## Ausgangslage (belegt am Stand von `main`, 2026-10-26)

- `FieldFormatting.label(.counts)` liefert `String(localized: "Counts")` (`LooseEnds/Views/FieldFormatting.swift:21`). Der Schlüssel steht in keinem Katalog,
  also zeigt ein deutsches Gerät „Counts“. Sichtbar in der Änderungsliste der Detailansicht (`TaskDetailView.swift:836`), im Feldeditor
  (`FieldEditorView.swift:39`) und in der Feldzeile (`TaskDetailView.swift:711`). Das Nutzerwort ist seit #655 „Perle sammeln“.
- Ein Skript über alle Text-Literale in `LooseEnds/` und `Shared/` findet genau diesen einen Schlüssel ohne Katalogeintrag.
- `scripts/test_infoplist_languages.py` (#708) prüft nur Einträge, die schon im Katalog stehen. Ein Schlüssel, der ganz fehlt, bleibt unsichtbar.
- Das im Ticket genannte Skript `scripts/test_localization_complete.py` entfällt: Die Vollständigkeit der vier Kataloge hält der bestehende Test; neu kommt nur die Gegenrichtung (Code → Katalog) dazu.

## Acceptance Criteria

- **AC-1:** `FieldFormatting.label(.counts)` verwendet den Schlüssel „Collect bead“; `Localizable.xcstrings` bekommt ihn mit `de` = „Perle sammeln“ (`translated`).
- **AC-2:** In `scripts/test_infoplist_languages.py` prüft ein neuer Test, dass jedes Text-Literal der App (`String(localized:`, `Text(`, `Button(`, `Label(`,
  `LabeledContent(`, `navigationTitle(`; ohne Interpolation) in `LooseEnds/` und `Shared/` im Katalog `LooseEnds/Resources/Localizable.xcstrings` steht.
- **AC-3:** Eine Selbstprüfung im selben Test zeigt, dass der Scanner einen fehlenden Schlüssel findet und einen vorhandenen nicht meldet.
- **AC-4:** Vor der Änderung ist der neue Test rot („Counts“ gemeldet), danach grün; die übrigen Tests der Datei bleiben grün.

## Was darf sich nicht ändern

- Die Bezeichner `RevisedField.counts` und die gespeicherten Werte (`"counts"` in Revisionen): nur die Anzeige ändert sich.
- „Collect beads“ (Einstellungen) und alle anderen Katalogeinträge.
- Der Hinweistext ohne Modell aus #709.

## Betroffene Dateien (3, ca. +45/−1 LoC)

| Datei | Änderung |
|---|---|
| `LooseEnds/Views/FieldFormatting.swift` | eine Zeile: Schlüssel „Collect bead“ |
| `LooseEnds/Resources/Localizable.xcstrings` | ein Eintrag mit `de` |
| `scripts/test_infoplist_languages.py` | Scanner und zwei Tests |

## Alternative

Den vorhandenen Eintrag „Bead“ / „Perle“ verwenden: spart einen Eintrag, nennt aber nur das Ding, nicht die Handlung, und weicht vom Wortlaut im Ticket ab.

## Abnahme

- Stufe 1: `python3 -m unittest scripts/test_infoplist_languages.py` rot vorher, grün nachher; voller Lauf `scripts/test_*.py`; Build per `./scripts/sim.sh build` (der Katalog wird mitübersetzt).
- Stufe 2: Simulator auf Deutsch, Aufgabe öffnen, „Perle anhängen“ wählen, in der Änderungsliste steht „Perle sammeln“; Screenshot angesehen und beschrieben.
- Stufe 3: „Kein Pfad der Geräteliste berührt.“

## Manuelle Test-Schritte

Keine für Henning. Der Nachweis läuft automatisiert (siehe Abnahme).

## Inline-Test (wird während Implementierung geschrieben)

- [ ] `test_every_code_literal_has_a_catalog_entry` (rot vor AC-1, grün danach)
- [ ] `test_scanner_finds_a_missing_key` (Selbstprüfung)

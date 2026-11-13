---
entity_id: fix-864-komposita-amtswoerter
type: bugfix
created: 2026-11-12
updated: 2026-11-12
status: draft
workflow: fix-864-komposita-amtswoerter
tags: [enrichment, regel, wichtigkeit, deutsch]
---

# Spec: #864 — Zusammensetzungen mit Amtswörtern setzen die Wichtigkeit

## Approval

- [ ] Approved

## Purpose

Die Regel für Wichtigkeit (#117) sucht jedes Schlüsselwort mit Wortgrenze links **und** rechts. Deshalb trifft das
Amtswort „steuer“ nie in „Steuerbescheid“, „Steuernachzahlung“ oder „Steuerberater“, und „Amtsgericht“ oder
„Umsatzsteuer“ nur, wenn sie ausdrücklich in der Liste stehen. Diese Spec lässt deutsche Zusammensetzungen aus
dem Amtsbereich die Wichtigkeit wie das Amtswort selbst setzen, ohne Fehltreffer („Steuerrad“, „Steuerung“,
„Gesamt“, „Hauptgericht“). Hat es bisher funktioniert? Nein, nie: Die beidseitige Wortgrenze gilt seit #117, die
Gerichts- und Ämterliste hat nie Zusammensetzungen abgedeckt. Englisch trifft „tax“ als ganzes Wort schon und
bleibt unberührt. Kein Modell: Die Regel trifft alle Korpusformen, ohne Fehltreffer (Messung unten).

## Source

- **Datei:** `Shared/Enrichment/ImportanceUrgencyRule.swift`
- **Bezeichner:** `ImportanceSignal.official` (`range(in:)`), `range(of:in:from:)`
- **Datei:** `Shared/Language/GermanPack.swift`
- **Bezeichner:** `importanceWords` (zwei neue Schlüssel `officialStem`, `officialHead`)

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `LanguagePacks.importanceWords(for:)` | Bestand | liest die neuen Schlüssel ohne Strukturänderung (Dictionary `[String: [String]]`), fehlt ein Schlüssel in einem Paket, ist die Liste leer |
| `EnglishPack`, `TestPack` | Bestand | bleiben unverändert (kein neuer Schlüssel nötig) |
| `RuleTrigger.importanceTrigger`, `EnrichmentCoordinator.matchImportance` | Aufrufer | rufen `matchImportance`/`importanceTrigger`; unverändert |
| `RuleGoldenTests` + `Fixtures/rule-golden.json` | Bestand | halten die Regelausgabe über 545 Korpuszeilen gleich; Aktualisierung per `LOOSEENDS_UPDATE_GOLDEN=1` |
| `LanguagePackConformanceTests` | Bestand | prüfen die Wortlisten (kein Wort doppelt mit verschiedenem Wert, Tabellen nicht leer) |

## Scope

### Affected Files

| Datei | Änderungsart | Beschreibung |
|---|---|---|
| `Shared/Language/GermanPack.swift` | MODIFY | `importanceWords` um `officialStem` und `officialHead` erweitern (Listen unten) |
| `Shared/Enrichment/ImportanceUrgencyRule.swift` | MODIFY | `.official` sucht Ganzwörter wie bisher, dazu Stämme (Wortgrenze links, rechts offen) und Köpfe (links offen, Wortgrenze rechts); der Treffer deckt das ganze Wort ab |
| `LooseEndsTests/ImportanceUrgencyRuleTests.swift` | MODIFY | neue Treffer- und Nichttreffer-Tests; Kommentar zu „Steuerbescheid“ (Test `explicitWordSetsImportance`) nachziehen, denn „Steuerbescheid“ trifft jetzt das Amtssignal |
| `LooseEndsTests/Fixtures/rule-golden.json` | MODIFY | per `LOOSEENDS_UPDATE_GOLDEN=1` erneuert; jede geänderte Zeile begründet |

### Estimated Changes

- Dateien: 4 · LoC: Produktiv +~35/−~3, Tests +~60, Golden einige Zeilen — unter 250 LoC.
- Keine Änderung an `project.yml`, Berechtigungen, `Info.plist`, Schema, Katalogen. Keine neuen Texte (die Begründung „From official or legal language in the note.“ bleibt).

## Implementation Details

Positivlisten statt generischer Endungsregel. Gemessen am Golden-Korpus (545 Titel) und den Messkorpora:
generisches Präfix `steuer` trifft „Steuerung“, „Steuerrad“; generisches Suffix `amt` trifft „Gesamt“,
„insgesamt“; generisches Suffix `gericht` trifft „Hauptgericht“ (Speise). Darum:

- **`officialStem`** (Wortgrenze links, rechts offen, deckt auch Beugung und Mehrzahl): `steuerbescheid`,
  `steuerberater`, `steuernachzahlung`, `steuererstattung`, `steuerunterlagen`, `steuernummer`, `steuerschuld`,
  `steuerklasse`, `steuerid`, `umsatzsteuer`, `einkommensteuer`, `kirchensteuer`, `lohnsteuer`, `grundsteuer`,
  `gewerbesteuer`, `amtsgericht`, `landgericht`, `nachlassgericht`, `sozialgericht`, `arbeitsgericht`,
  `finanzgericht`, `ordnungsamt`, `gesundheitsamt`, `standesamt`, `jugendamt`, `sozialamt`, `bauamt`.
- **`officialHead`** (links offen, Wortgrenze rechts): `vertrag`, `anwalt`, `anwältin`, `notar`, `behörde`
  — Zusammensetzungen mit dem Amtswort **hinten** („Mietvertrag“, „Scheidungsanwalt“, „Waffenbehörde“,
  „Staatsanwalt“). Rechts bleibt die Wortgrenze, damit „Vertragsnummer“ unverändert nicht trifft.
- Die bestehende Liste `official` bleibt unverändert (Ganzwörter, beidseitige Grenze).
- Findet eine Suche etwas, deckt `range(in:)` das **ganze Wort** ab (vom Wortanfang bis Wortende); bei mehreren Treffern
  gilt der früheste, wie bisher. Dadurch markiert der Feld-Editor „Steuerbescheide“ ganz, nicht nur den Stamm.
- Negation (`isNegated`) gilt weiter nur für das ausdrückliche Wort „wichtig“; `official` bleibt ohne Negation.
- Kein Zugriff auf Referenzdatum (AC-5 von #117 bleibt gewahrt), `Shared/` bleibt rein `Foundation`.

### Messung (Regel-Spalte)

Golden-Korpus, Prototyp mit Stamm `steuer…`/Köpfen: neue Treffer `steuerberater` 4× (neue Wichtigkeit) + 1× schon hoch,
`steuerbescheide` 1×, `steuerbrater` (Sprachfehler) 1×, `mietvertrag` 2× schon hoch. 0 Fehltreffer im Korpus.
„Ohne Modell geht es, weil“ die Regelform alle gezählten Korpusformen trifft und keine Fehltreffer erzeugt.

### Alternativen

1. Nur ausgeschriebene Komposita als Ganzwörter in `official` (kein Regelcode): einfachste Variante, deckt aber
   Beugung („Steuerbescheide“) und Neubildungen nicht ab.
2. Generische Endungs-/Anfangsregel (Wortlaut des Issues): belegte Fehltreffer („Gesamt“, „Hauptgericht“,
   „Steuerung“), verworfen.
3. Modell: widerspricht „Regeln vor Modell“, nicht nötig. Keine ADR fällt.

## Expected Behavior

- **Input:** Notiztext.
- **Output:** `matchImportance` liefert `.high` mit Vertrauen 1.0 und der Begründung des Amtssignals, wenn der Text ein
  Amtswort-Kompositum der Listen enthält; sonst unverändert.
- **Side effects:** Aufgaben, deren Text eines dieser Wörter enthält und die vorher keine Wichtigkeit hatten, bekommen sie
  beim Erfassen oder bei „Neu analysieren“. Bereits gesetzte Werte des Nutzers bleiben (Revisionsregeln unverändert).

## Known Limitations

- Nur aufgezählte Stämme und Köpfe; ungewöhnliche Neubildungen („Steuerrückzahlungsbescheid“) treffen nicht, solange der
  Stamm nicht vorn steht. Erweiterung ist eine Listenänderung im Paket, kein Regelcode.
- „Vertragsnummer“, „Steuerung“, „Hauptgericht“ treffen weiterhin nicht (gewollt).
- Hat die Notiz schon Wichtigkeit über ein anderes Wort, ändert sich nichts.

## Definition of Done

Fertig ist diese Änderung, wenn:

- [ ] Jede Acceptance Criterion unten ist durch einen automatischen Test belegt
- [ ] Eine Aufgabe „Steuerbescheid prüfen“ bekommt im Simulator die hohe Wichtigkeit mit der Begründung „From official or legal language in the note.“, „Steuerrad reparieren“ nicht (Simulator-Durchlauf, Regelzweig)
- [ ] Der Golden-Diff ist Zeile für Zeile begründet: nur neu hinzugekommene Wichtigkeit, keine Zeile verliert sie
- [ ] Keine bestehende Funktion ist dabei kaputtgegangen (Regressionslauf grün)
- [ ] Abnahme endet nach Stufe 2: „Regelzweig, kein Modellaufruf, im Simulator belegt“ (Ausnahme #680, `EnrichmentCoordinator.swift` wird nicht geändert)

## Acceptance Criteria

- **AC-1:** Given ein deutscher Text mit einem Amtswort-Stamm vorn / When `matchImportance` läuft / Then `.high`, Vertrauen 1.0, Begründung des Amtssignals („Steuerbescheid prüfen“, „Steuernachzahlung überweisen“, „Steuerberater anrufen“, „Steuerbescheide ablegen“, „Umsatzsteuer melden“, „Amtsgerichts Post lesen“)
  - Test: `LooseEndsTests/ImportanceUrgencyRuleTests.swift::compoundStemsSetImportance`
- **AC-2:** Given ein Text mit einem Kompositum, dessen Amtswort hinten steht / When `matchImportance` läuft / Then `.high` („Mietvertrag kündigen“, „Scheidungsanwalt anrufen“, „Waffenbehörde fragen“, „Staatsanwalt“)
  - Test: `LooseEndsTests/ImportanceUrgencyRuleTests.swift::compoundHeadsSetImportance`
- **AC-3:** Given Wörter, die nur so aussehen / When `matchImportance` läuft / Then `nil` („Steuerrad reparieren“, „Steuerung einbauen“, „Steuerknüppel kaufen“, „Lenksteuer“, „Gesamt zählen“, „insgesamt drei“, „Hauptgericht kochen“, „Beamtenrecht lesen“, „Vertragsnummer notieren“)
  - Test: `LooseEndsTests/ImportanceUrgencyRuleTests.swift::lookAlikesDoNotSetImportance`
- **AC-4:** Given die bisherigen Treffer / When `matchImportance` läuft / Then unverändert („Finanzamt anrufen“, „Steuererklärung“, „Amt“, „Vertrag“, englisch „Check the tax notice today“); die Begründung bleibt die des Amtssignals; „Steuerbescheid“ trifft auch ohne „wichtig“
  - Test: `LooseEndsTests/ImportanceUrgencyRuleTests.swift::formerOfficialHitsStay`
- **AC-5:** Given „Steuerbescheide ablegen“ / When `importanceTrigger` läuft / Then die Spanne deckt das ganze Wort „Steuerbescheide“ ab; bei „Mietvertrag kündigen“ das ganze Wort „Mietvertrag“
  - Test: `LooseEndsTests/ImportanceUrgencyRuleTests.swift::triggerCoversWholeCompound`
- **AC-6:** Given der Golden-Korpus / When `RuleGoldenTests` mit dem erneuerten `rule-golden.json` läuft / Then grün, und im Diff steht je Zeile nur neu gesetzte Wichtigkeit (keine Zeile verliert eine)
  - Test: `LooseEndsTests/RuleGoldenTests.swift` (Gleichheitstest über `Fixtures/rule-golden.json`; Diff-Begründung in `/60-validate`)
- **AC-7:** Given alle Sprachpakete / When die Konformitätstests laufen / Then grün; Englisch und `TestPack` sind unverändert
  - Test: `LooseEndsTests/Language/LanguagePackConformanceTests.swift`

## Test Plan

Automatische Tests (jeweils an eine AC oben gebunden), Aufruf über `./scripts/sim.sh sim-unit`:
- `./scripts/sim.sh sim-unit ImportanceUrgencyRuleTests` (AC-1 bis AC-5)
- `./scripts/sim.sh sim-unit RuleGoldenTests` (AC-6, nach `LOOSEENDS_UPDATE_GOLDEN=1`-Lauf und Diff-Prüfung)
- `./scripts/sim.sh sim-unit LanguagePackConformanceTests` (AC-7)
- Vollständiger Unit-Lauf als Regression; Simulator-Durchlauf des Regelzweigs in `/60-validate`.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Wortlisten und Regeln innerhalb der bestehenden Pack-Struktur (`importanceWords` bleibt `[String: [String]]`); keine frühere Entscheidung wird gekippt.

## Changelog

- 2026-11-12: Initial spec created

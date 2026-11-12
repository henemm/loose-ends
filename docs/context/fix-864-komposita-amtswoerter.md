# Context: fix-864-komposita-amtswoerter

## Request Summary
Deutsche Zusammensetzungen mit einem Amtswort („Steuerbescheid“, „Steuernachzahlung“, „Steuerberater“, „Amtsgericht“) sollen die Wichtigkeit wie das Amtswort selbst setzen, ohne Fehltreffer („Steuerrad“, „Lenksteuer“). Englisch trifft „Check the tax notice today“ schon (`tax`).

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Enrichment/ImportanceUrgencyRule.swift` | `range(of:in:)` sucht jedes Schlüsselwort mit Wortgrenze links und rechts (`(?<![\p{L}\p{N}])…(?![\p{L}\p{N}])`); deshalb trifft „steuer“ nie in „Steuerbescheid“. Gewollt für „Amt“ in „Beamtenrecht“. |
| `Shared/Language/GermanPack.swift:52-54` | Gruppe `official`: finanzamt, amt, behörde, gericht, anwalt, anwältin, notar, vertrag, steuer, steuererklärung, bußgeld |
| `Shared/Language/EnglishPack.swift:41` | `official`: tax, official, contract, court, lawyer (Referenz, bleibt unverändert) |
| `Shared/Language/LanguagePack.swift:53,138` | `importanceWords: [String: [String]]`, `LanguagePacks.importanceWords(for:)`; Struktur würde sich bei neuem Feld für alle Packs (auch `TestPack`) ändern |
| `LooseEndsTests/ImportanceUrgencyRuleTests.swift` | Bestehende Treffer-/Nichttreffer-Tests; Zeile 53 hält fest, dass „Steuerbescheid“ das Amtssignal heute NICHT trifft (Kommentar muss nachgezogen werden) |
| `LooseEndsTests/RuleGoldenTests.swift` + `Fixtures/rule-golden.json` | Gleichheit der Regelausgabe über 545 Korpuszeilen; Aktualisierung per `LOOSEENDS_UPDATE_GOLDEN=1 ./scripts/sim.sh sim-unit RuleGoldenTests` |
| `Shared/Enrichment/RuleTrigger.swift:19`, `EnrichmentCoordinator.swift:435` | Aufrufer von `importanceTrigger`/`matchImportance` (Markierung im Feld-Editor, Pass beim Erfassen); keine Änderung nötig |

## Existing Patterns
- Regeln vor Modell; Wörter liegen in `Shared/Language/`, die Logik in der Regel (Negation `isNegated` bleibt dort).
- Deutsche Komposita sind rechtsköpfig: das Amtswort steht meist **hinten** („Amtsgericht“ ist die Ausnahme: Amt vorn, Gericht hinten, endet auf `gericht`; „Gesundheitsamt“, „Mietvertrag“, „Scheidungsanwalt“) oder **vorn als Bestimmungswort** („Steuerbescheid“, „Steuerberater“, „Steuerunterlagen“).
- Messung: Korpusabnahmen sind Schwellen, `RuleGoldenTests` Gleichheit. Jeder Bericht führt die Regel-Spalte.

## Korpus-Vorkommen (Golden + Messkorpora, Rohzählung)
vertrag 18, steuererklärung 18, steuerberater 16, amtsgericht 14, steuer 11, anwalt 10, notar 8, vertragsnummer 6, mietvertrag 5, steuerbescheide 3, steuerunterlagen 1, steuerbescheid 1, gesundheitsamt 2, finanzamt 2, standesamt 1, waffenbehörde 1, jagdbehörde 1, nachlassgericht 1, umsatzsteuer 1, kirchensteuer 1, einkommensteuer 1, stromvertrag 1, handyvertrag 1, aufhebungsvertrag 1, scheidungsanwalt 1. Fehltreffer-Kandidaten im Korpus: „finanzierung“ (7), „finanzen“ (4), „vertragsnummer“ — „finanz“ ist kein Amtswort der Liste, bleibt unberührt. Welche dieser Sätze heute schon über andere Wörter Wichtigkeit bekommen, zeigt der Golden-Diff.

## Dependencies
- Upstream: `LanguagePacks` (Wortlisten, Reihenfolge = Gleichstand-Reihenfolge), `NSRegularExpression`.
- Downstream: `EnrichmentCoordinator` (setzt Wichtigkeit mit Regelmarke), `RuleTrigger` (»«-Markierung im Detail), Widgets/Listen über `ViewRules`-Sortierung nach Wichtigkeit. Gerätestufe: nicht berührt (`EnrichmentCoordinator.swift` wird nicht geändert; falls doch, greift die Ausnahme #680 Regelzweig).

## Existing Specs / Entscheidungen
- CLAUDE.md „Rules before the model“: Regel- und Wortlistenweg, Messung mit Regel-Spalte; kein Modell.
- #117 (Regel), #214/#220 (Negation, explizites Wort), #217 (Marker/Titel: nur das ausdrückliche Wort verlässt den Titel; Amtswörter bleiben im Titel), Epic #750 (Sprachpakete; neue Sprachen kommen über `docs/reference/neue-sprache.md`).

## Risks & Considerations
- Fehltreffer durch Suffixsuche: „gericht“ (Hauptgericht, Nachgericht = Speise), „amt“ am Wortende (selten), „steuer“ als Anfang („Steuerrad“, „Steuerung“, „Steuerknüppel“) und als Ende („Lenksteuer“ gibt es kaum; „Ruder-/Mantelsteuer“ nicht relevant).
- `LanguagePack`-Struktur ändern zieht alle Packs, `TestPack`, Konformitätstests mit; eine reine Wortlisten-Lösung (ausgeschriebene Komposita als eigene Wörter) bleibt in der Struktur, deckt aber nur Aufgezähltes ab.
- Golden-Diff muss Zeile für Zeile begründet werden; Sätze, die schon Wichtigkeit hatten, ändern sich nicht.
- Englisches Paket und „wichtig“-Negation bleiben unberührt; Alle Packs werden gleichzeitig gelesen (kein Sprachfeld), also darf eine deutsche Endungsregel englische Wörter nicht falsch treffen („…amt“, „…gericht“ kommen im Englischen praktisch nicht vor; vor dem Bauen gegen den englischen Korpus prüfen).
- Umfang: Regel + Pack + Tests + Golden = 4–5 Dateien, unter 250 LoC.

## Analysis

### Type
Bugfix (Regelzweig, kein Modell). Hat es bisher funktioniert? Nein: nie; `range(of:)` verlangt seit #117 Wortgrenzen beidseitig, Komposita wurden nie erkannt (Englisch trifft `tax` als ganzes Wort).

### Recherche / Messung (Regel-Spalte)
- Golden-Korpus (545 Titel), Prototyp: Präfix `steuer` + Suffixe `amt|behörde|gericht|anwalt|anwältin|notar|vertrag|steuer`:
  neue Treffer `steuerberater` 4× NEU + 1× schon hoch, `steuerbescheide` 1× NEU, `steuerbrater` (Sprachfehler) 1× NEU, `mietvertrag` 2× schon hoch. Keine Fehltreffer im Korpus.
- Suffix `amt` ist ungeeignet: „Gesamt“, „insgesamt“ endet auf `amt` → Fehltreffer. Darum kein generisches `-amt`; die gängigen Amtsnamen ausgeschrieben (z. B. ordnungsamt, gesundheitsamt, standesamt, jugendamt, sozialamt, bauamt).
- Prefix `steuer` generisch trifft „Steuerung“, „Steuerrad“, „Steuerknüppel“ → Fehltreffer. Darum Positivliste von Stämmen als Präfix: steuerbescheid, steuerberater, steuernachzahlung, steuererstattung, steuerunterlagen, steuernummer, steuerschuld, steuerklasse, steuerid.
- Grenze: Golden enthält nur Titel (nicht Rohtext); die Rohzählung (Context, 25 Wörter) zeigt gleiche Wortformen. Vor Bau: Golden-Diff Zeile für Zeile begründen.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| Shared/Language/GermanPack.swift | MODIFY | neue Schlüssel in `importanceWords`: `officialPrefix`, `officialSuffix` (Dictionary-Schlüssel, keine Strukturänderung) |
| Shared/Enrichment/ImportanceUrgencyRule.swift | MODIFY | `official` liest Ganzwörter + Präfix-Stämme (Wortgrenze links, rechts offen) + Suffixe (links offen, Wortgrenze rechts, Mindestlänge) |
| LooseEndsTests/ImportanceUrgencyRuleTests.swift | MODIFY | Treffer (Steuerbescheid, Steuernachzahlung, Steuerberater, Amtsgericht, Umsatzsteuer, Mietvertrag) und Nicht-Treffer (Steuerrad, Steuerung, Gesamt, Beamtenrecht, Hauptgericht*); Kommentar Zeile 53 nachziehen |
| LooseEndsTests/Fixtures/rule-golden.json | MODIFY | per `LOOSEENDS_UPDATE_GOLDEN=1`, Diff begründet |

*„Hauptgericht“ = Speise endet auf `gericht` → Fehltreffer; Suffix `gericht` nur für `amtsgericht`, `landgericht`, `nachlassgericht`, `sozialgericht`… als Positivliste, nicht generisch.

### Scope Assessment
- Files: 4 · LoC ca. +80/-5 · Risk: LOW (nur Wichtigkeit hoch auf Wörtern, die Amtssprache sind; Englisch unberührt, Gerätestufe nicht berührt)

### Technical Approach (Empfehlung)
Positivlisten statt generischer Regex: Präfix-Stämme und Suffix-Köpfe in `GermanPack`, Rule matcht sie mit einseitiger Wortgrenze. Kein Modell: „Ohne Modell geht es“ — Regel trifft 100 % der Korpusformen, 0 Fehltreffer.

### Alternativen
1. Nur ausgeschriebene Komposita als Ganzwörter (kein Rule-Code, aber Flexion: „Steuerbescheide“ fehlt, jede Neubildung auch) — einfachste Variante, deckt weniger.
2. Generische Suffix-/Präfix-Regel (Issue-Wortlaut) — Fehltreffer „Gesamt“, „Hauptgericht“, „Steuerung“ belegt; verworfen.
3. Modell — widerspricht „Regeln vor Modell“ (ADR/Regel), nicht nötig.
Gekippt würde keine ADR; Struktur `LanguagePack` bleibt.

### Open Questions
- [ ] Keine für den PO (technisch, Claude entscheidet). Entwurf-Vorschau entfällt: keine sichtbare UI-Änderung.

# Context: fix-670-testsprache

## Request Summary
`sim-unit` und `test-proof` sollen eine Testsprache annehmen (`LOOSEENDS_LANG=en`) und als
`-testLanguage`/`-testRegion` an `xcodebuild` geben, ohne den Simulator umzustellen. Auslöser: #659.

## Recherche
`xcodebuild` kennt `-testLanguage <ISO-639-1>` und `-testRegion <ISO-3166-1>`, nur für die Testaktion,
überschreibt die Scheme-Einstellung (xcodebuild-Manpage, https://leancrew.com/all-this/man/man1/xcodebuild.html).
Kein Beleg gefunden, dass es unter Xcode 27 im Simulator auf Unit-Tests wirkt: wird am echten Lauf geprüft
(ein Test, der die Sprache liest, zeigt `en` mit und `de` ohne Variable).

## Related Files
| File | Relevance |
|------|-----------|
| scripts/sim.sh `run_xcodebuild()` (Z. 288) | Einzige Stelle, die `xcodebuild` aufruft. Hängt schon `-collect-test-diagnostics never` an, wenn `$1 = test` (#298). Dort gehört die Sprache hin: deckt `sim-unit`, `test`, `test-proof`, `watch-test-proof` und Mac-Läufe ab. |
| scripts/sim.sh `cmd_sim_unit` (Z. 563), `cmd_test_proof` (Z. 586) | Aufrufer; bleiben unverändert. |
| scripts/test_sim_run_xcodebuild.py | Vorhandener Skripttest: zieht `run_xcodebuild()` per Regex aus sim.sh, ersetzt `xcodebuild` durch eine Attrappe. Hier kommen die neuen Tests (RED) hin. |
| CLAUDE.md, Abschnitt „Build“ | Die Zeile laut Definition of Done. |

## Existing Patterns
- Bedingte Zusatzargumente im Muster `[ "${1:-}" = test ] && set -- "$@" ...` (#298).
- Umgebungsvariablen `LOOSEENDS_*` (`LOOSEENDS_SILENCE_MAX`, `LOOSEENDS_MAC_HOST`).

## Dependencies / Dependents
- Upstream: xcodebuild. Downstream: jeder lokale Testlauf (nicht die CI; sie ruft xcodebuild direkt auf).

## Existing Specs
Keine einschlägige.

## Risks & Considerations
- Betrifft jeden Testlauf: ohne Variable muss die Argumentliste unverändert bleiben (Test).
- Region-Zuordnung: `en`→`US`; ein unbekannter Code bekommt nur `-testLanguage`, keine erfundene Region. Ungültiger Wert (leer, Sonderzeichen) wird laut abgelehnt, nicht still ignoriert.
- Alternative: zweiter, dauerhaft englischer Simulator (schwerer, wird vergessen); den Simulator umzustellen scheidet laut Ticket aus.
- Kein Pfad der Geräteliste berührt.

## Analysis

### Type
Feature (Werkzeug-Verbesserung an `scripts/sim.sh`, kein Produktcode)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/sim.sh | MODIFY | `run_xcodebuild()`: bei `$1 = test` und gesetztem `LOOSEENDS_LANG` `-testLanguage`/`-testRegion` anhängen; ungültiger Wert bricht laut ab |
| scripts/test_sim_run_xcodebuild.py | MODIFY | Neue Tests: ohne Variable unveränderte Argumente; `en` → `-testLanguage en -testRegion US`; unbekannter Code nur `-testLanguage`; Leer/Sonderzeichen → Abbruch mit Meldung; Nicht-`test`-Aktion unberührt |
| CLAUDE.md | MODIFY | Eine Zeile unter „Build“ |

### Scope Assessment
- Files: 3, ca. +45/-0 LoC, Risiko LOW (ohne Variable bleibt die Argumentliste byte-gleich, per Test bewiesen)

### Technical Approach
Regelweg, kein Modell: eine Stelle (`run_xcodebuild`), Muster wie #298. Region über kleine Tabelle (`en`→US, `de`→DE, `fr`→FR …), unbekannter Code ohne Region. Validierung per Regex `^[a-z]{2}$`.
Abnahme am echten Lauf (Stufe 2): `LOOSEENDS_LANG=en ./scripts/sim.sh sim-unit <Klasse>` mit einem sprachabhängigen Test zeigt `en`, ohne Variable `de`. Wirkt `-testLanguage` unter Xcode 27 auf Unit-Tests im Simulator nicht, ist der Rückfall das Launch-Argument `-AppleLanguages (en)`.
Alternative (nicht gewählt): zweiter, dauerhaft englischer Simulator; oder `AppleLanguages` per Launch-Argument im Schema. Kippt keine ADR.
Ohne Modell geht es nicht: nicht relevant, reine Skriptlogik.

### Dependencies
xcodebuild (Upstream); alle lokalen Testläufe (Downstream); CI unberührt.

### Open Questions
- [ ] Wirkt `-testLanguage` unter Xcode 27 auf Unit-Tests im iOS-Simulator? (wird in der Abnahme am echten Lauf belegt; Rückfall: Launch-Argument `-AppleLanguages (en)`)

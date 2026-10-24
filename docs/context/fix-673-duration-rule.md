# Context: fix-673-duration-rule

## Request Summary
`DurationRule` (#441) ist im Produktpfad nirgends aufgerufen: "20 Minuten" im Erfassungstext setzt nie eine Dauer.
Henning (PO) hat die Entscheidung dem Tech Lead überlassen (2026-10-24): anschließen, nicht löschen.

## Beleg (Reproduktion auf Codeebene)
`grep -rn DurationRule Shared LooseEnds LooseEndsTests` trifft nur `Shared/Enrichment/DurationRule.swift`
und `LooseEndsTests/DurationRuleTests.swift`. Hat es bisher funktioniert? Nein: #441 hat die Regel nie angeschlossen
(`git log` der Datei: ein Commit, 97af77d). Der Simulator-Durchlauf folgt in /20-analyse.

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Enrichment/DurationRule.swift` | die Regel: `match(in:)` liefert `Guess<DurationBucket>` (Konfidenz 1.0) und Textbereich |
| `Shared/Enrichment/EnrichmentCoordinator.swift:215` | `applyRules` ruft alle Regeln; dort kommt `applyDurationRule` hin, Muster `applyImportanceRule` (Z. 408) |
| `Shared/Enrichment/EnrichmentCoordinator.swift:89,171` | beide Aufrufer: erster Lauf (`.firstRun`) und "Neu analysieren" (`.reanalysis`) |
| `Shared/Enrichment/EnrichmentWriter.swift:80` | Modell schreibt Dauer; `ruleFields` hält das Modell von einem Regelfeld fern |
| `Shared/Enrichment/RecognitionRule.swift` | setzt Dauer + Kontexte aus früherem, gleichem Rohtext (Nutzerwert) |
| `LooseEndsTests/DurationRuleTests.swift` | Regeltests existieren; Koordinatortest fehlt |
| `LooseEndsTests/EnrichmentTests.swift` | Muster für Koordinatortests (StubEnricher, In-Memory-Speicher) |

## Existing Patterns
- Regel pro Feld im Coordinator: `mayWrite(...)` entscheidet (erster Lauf nur leer, Neu analysieren alles, was der Nutzer nie anfasste), dann `Revision` mit Autor `.rule`, `durationSourceRaw = FieldSource.rule`, `durationConfidence`.
- Rückgabe `true` = Regel hat getroffen (auch wenn nicht geschrieben); Treffer geht in `matched` und hält das Modell fern (#34).
- Reihenfolge Kontexte: Erkennung (früherer Nutzerwert) vor Wortliste (#232). Für die Dauer analog: Erkennung zuerst, `DurationRule` nur wo sie keine Dauer gesetzt hat. Offene Frage für die Analyse.

## Dependencies
- Upstream: `DurationBucket`, `Revision`, `FieldSource`, `EnrichmentWriter.mayWrite`.
- Downstream: Detailansicht (`DetailFields` Gruppe Dauer, Feldzeichen Uhr aus #344), Kalender-Rückfrage (`CalendarAskSheet` liest `duration`), Erkennung (`RecognitionRule` übernimmt Dauer nur mit `durationSourceRaw` = Nutzer, #244, Regelwerte werden nie weitergegeben).

## Existing Specs
- `docs/specs/feat-101-feldursprung-regel.md` (Herkunft `rule`), `docs/specs/feat-112-energie-skala.md` (Skala-Stil). Keine Spec zu #441 gefunden, der Spec-Schritt klärt das.

## Risks & Considerations
- `EnrichmentCoordinator.swift` steht auf der Geräteliste: Stufe 3 über TestFlight nach dem Merge.
- Das Modell setzt die Dauer heute bei Konfidenz ≥ Schwelle selbst; mit Regeltreffer bleibt es draußen (`ruleFields`). Ohne Treffer bleibt das Modellverhalten unverändert.
- Kalender: eine Regeldauer füllt künftig die Rückfrage "Dauer" vor; das ist gewollt (der Nutzer hat sie genannt), aber im Simulator zu prüfen.
- Unteraufgaben bekommen die Dauer-Regel nicht (#565: nur Datum und Etikett-Wort).
- Bestand: Aufgaben, bei denen der Regelschritt schon lief (`rulesAppliedAt` gesetzt), bekommen die Dauer nicht nachträglich, nur über "Neu analysieren". Bewusst so, kein Nachlauf über den Bestand.

## Analysis

### Type
Bug (Regel nie angeschlossen). Hat es bisher funktioniert? Nein, nie (#441 lieferte nur die Regel und ihre Tests).

### Reproduktion (2026-10-24, iOS-Simulator, Weg wie Henning: Erfassen → Detail)
Wegwerf-UI-Test in `FieldsSmokeTests` (nicht eingecheckt): Erfassungstext „Steuerbescheid prüfen 20 Minuten“, danach
Detail. Ergebnis: `field_duration` steht als angebotene Zeile da (leer, „+ Duration“), `fieldGlyph_duration` fehlt →
„Repro 673: kein Uhr-Zeichen“. Beleg: `docs/artifacts/fix-673-duration-rule/simulator-run.txt`.
Im Test `testSignsStand…` (#344) kommen Wichtig, Dringend und Datum aus demselben Text an, nur die Dauer nicht.

### Recherche
Rein interne Logik (kein Apple-API, keine Fehlermeldung): keine Internetrecherche nötig. Belegt durch `grep`
(nur Regeldatei + Tests) und die Reproduktion.

### Ursache
`EnrichmentCoordinator.applyRules` (Z. 215) ruft Fälligkeit, Wichtigkeit, Dringlichkeit, Erkennung, Wortliste, Telefon,
Projektname, aber keine `DurationRule`. Das Modell darf die Dauer schreiben (`EnrichmentWriter` Z. 80), nur nicht unter
`--ui-testing` (`ModelOffEnricher`) und nicht ohne Apple Intelligence.

### Without the model this fails because: (entfällt)
Die Regel ist der Weg, das Modell wird nicht vorgeschlagen. Sie liefert nur, was der Nutzer ausdrücklich sagt (Konfidenz 1.0).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Enrichment/EnrichmentCoordinator.swift` | MODIFY | `applyDurationRule` nach Muster `applyImportanceRule`; Aufruf in `applyRules` NACH der Erkennung, nur wenn `.duration` nicht schon von ihr getroffen; Treffer in `matched` (hält das Modell fern) |
| `LooseEndsTests/EnrichmentTests.swift` (oder neue `DurationRuleCoordinatorTests.swift`) | MODIFY/CREATE | Koordinatortests: erster Lauf setzt Dauer + Revision (Autor `.rule`, Herkunft `rule`); Nutzerwert bleibt; „Neu analysieren“ ersetzt Regelwert; Erkennung schlägt Regel; Modell überschreibt Regeltreffer nicht; Unteraufgabe bekommt keine Dauer |
| `LooseEndsUITests/FieldsSmokeTests.swift` | MODIFY | `testSignsStand…` um Dauer-Zeile mit Uhr-Zeichen ergänzen (Kommentar Z. 156 stimmt dann nicht mehr) |

### Scope Assessment
- Files: 3
- Estimated LoC: +~35 Produktcode, +~90 Tests
- Risk Level: LOW (neues Feld im bestehenden Regelschritt, Muster 1:1; Modellverhalten ohne Treffer unverändert)

### Technical Approach
1. `applyDurationRule(to:mode:)`: `DurationRule.match(in: rawText)`; ohne Treffer `false`; `mayWrite(.duration, firstRun: duration == nil && !userHasTouched(.duration), changes:)`; `Revision(author: .rule, reason: guess.reason)`, `durationSourceRaw = rule`, `durationConfidence`.
2. Reihenfolge: Erkennung (früherer Nutzerwert für denselben Rohtext) vor `DurationRule`, wie bei Kontexten (#232). Ist `.duration` schon in `matched`, überspringt die Wortregel.
3. Unteraufgaben bekommen die Regel nicht (#565 bleibt).
4. Kalender-Rückfrage liest `duration` und ist künftig vorbefüllt; im Simulator-Durchlauf prüfen.

### Alternativen
- A (Empfehlung): anschließen, Regel nach Erkennung.
- B: Regel entfernen, Dauer nur Modell/Nutzer. Verworfen: Modell fehlt ohne Apple Intelligence, bei Dauer ungemessen, „20 Minuten“ ist ausdrücklich gesagt. Würde #441 kippen.
- C: Regel nur als Vorschlag im Detail („Dauer 30 min übernehmen?“) statt automatisch zu setzen. Verworfen für jetzt: weicht vom Muster aller Regelfelder ab, mehr UI; eigenes Ticket, falls die Aufrundung (20 Min → „30 min“) stört.

### Befunde gegen den Plan
Die Aufrundung in den nächsten Eimer (20 Min → „30 min“) zeigt einen anderen Wert als gesagt. Das ist die Entscheidung aus #441, nicht Teil von #673.

### Dependencies
`DurationBucket`, `Revision`, `FieldSource`, `EnrichmentWriter.mayWrite`/`userHasTouched`; abwärts Detail (Uhr-Zeichen #344), `CalendarAskSheet`, `RecognitionRule` (übernimmt nur Nutzerwerte, #244; Regelwerte pflanzen sich nicht fort).

### Open Questions
- [ ] Keine für den PO. Bestand ohne Nachlauf bleibt wie im Kontext festgelegt.
- Stufe 3: `EnrichmentCoordinator.swift` steht auf der Geräteliste, TestFlight nach dem Merge.
- Kein UI-Entwurf nötig: keine Neugestaltung, nur ein Wert, der bisher fehlte.

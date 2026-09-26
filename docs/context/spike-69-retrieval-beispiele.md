# Context: Spike #69 — Wirken Retrieval-Beispiele messbar?

## Request Summary
ADR-5 nimmt an: fünf ähnliche alte Aufgaben als Prompt-Beispiele lenken das 3B-Modell messbar zu
Hennings Konventionen, und On-Device-Embeddings finden bei Fünf-Wort-Texten die richtigen Nachbarn.
Diese Annahme (B1, `docs/project/06-annahmen-und-experimente.md`) ist ungemessen. #69 misst sie über
zwei Experimente (Auslass-Test, Konventionstest) und entscheidet, ob #26 (Retrieval per Embedding)
wie geplant, als Regelmotor oder als Kombination gebaut wird.

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Enrichment/EnrichmentCoordinator.swift:145-163` | `examples(in:limit:)` liefert heute die letzten 5 erledigten Aufgaben nach Datum — Platzhalter für die Ähnlichkeitssuche aus ADR-5, noch keine Embeddings |
| `Shared/Enrichment/EnrichmentDraft.swift:39-58` | `EnrichmentInput.examples: [EnrichmentExample]`, das Prompt-Beispiel-Format, das der Auslass-Test mit/ohne befüllt |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | baut den Prompt inkl. Beispiele fürs Modell — Stelle, an der der Auslass-Test ansetzt |
| `Measurement/Corpus.swift` | Treue-Korpus (317 Sätze), Wahrheit als Regel gegen den Messtag; kennt keine Korrektur-Historie oder Konventions-Muster — für den Konventionstest reicht die vorhandene Form nicht |
| `Measurement/MeasurementRun.swift`, `Measurement/SelfConsistency.swift` | Muster für Messläufe: `--runs <n>`, Mehrfachlauf-Infrastruktur (#107), Selbstkonsistenz-Auswertung (#108) — Vorlage für den Auslass-Test-Aufbau |
| `LooseEndsTests/FocusBloxCalibrationTests.swift`, `scripts/export-focusblox-corpus.swift` | FocusBlox-Export (287 echte Aufgaben Hennings) — mögliche Quelle für realistische Nachbarschaften statt synthetischer Sätze |
| `docs/reference/date-title-fidelity.md` | Berichtsformat für einen abgeschlossenen Treue-Messlauf (#67), Vorlage für den B1-Bericht |
| `docs/project/06-annahmen-und-experimente.md:131,154` | Annahme B1 selbst: Experimentaufbau, Abbruchkriterium, Alternativen, betroffene Festlegung (ADR-5) |
| `docs/project/00-entscheidungen.md:94` | ADR-5 im Wortlaut: „Lernen ist Retrieval, kein Training" |

## Existing Patterns
- Jeder Spike bisher (#92, #95, #107, #108, #117) baute eine reine Messstrecke in `Measurement/`
  (kompiliert nur in `LooseEndsTests` und die Labor-App, kein Produktpfad), maß auf dem Gerät oder
  Mac, schrieb einen Bericht nach `docs/reference/`, und erst danach änderte ein *eigenes* Ticket
  Produktcode (Beispiel: #92 misst, #95 baut den Regelparser in den Pfad ein).
- **Regeln-vor-Modell-Pflicht** (`CLAUDE.md`, zweimal von Henning bekräftigt): Jede Empfehlung für
  das Modell braucht die Zeile „Ohne Modell geht es nicht, weil …" mit Beleg; die Nulllinie
  (Regelweg) steht immer mit im Bericht. B1 hat bereits im Voraus zwei modell-lose Alternativen
  benannt: „Regeln aus Korrekturen ohne Modell" und „Retrieval-Mehrheit statt Prompt-Beispiel" —
  beide gehören als Nulllinie in den Messaufbau, nicht nur als nachträgliche Notiz.
- Konfidenz trennt laut A1-Messung (#65) nicht — jede neue Methodik, die sich auf Modell-Konfidenz
  stützen würde, ist bereits widerlegt.

## Dependencies
- Upstream: On-Device-Embeddings (`NLContextualEmbedding`, Deutsch unterstützt laut Recherche vom
  2026-09-19) — im Projekt noch nirgends verwendet, keine bestehende Nachbarschaftssuche.
- Braucht eine Korpus-Erweiterung für den Konventionstest (zehn Muster: drei gleiche Korrekturen,
  dann eine vierte Aufgabe) — existiert in `Measurement/Corpus.swift` noch nicht.

## Dependents
- **#26** (Retrieval per Embedding, ADR-5) — wird nach diesem Spike entweder wie geplant gebaut,
  als Regelmotor ersetzt, oder als Kombination (laut B1-Alternativen).
- Die Festlegung „Lernen über Prompt-Beispiele" (ADR-5, `docs/project/06-annahmen-und-experimente.md`
  Tabelle „Was bereits festgelegt ist") steht zur Disposition, falls das Abbruchkriterium greift.

## Existing Specs
- Keine Produktspec betroffen — reiner Messcode. Vorlage-Specs: `docs/specs/measurement/spike-65-mehrfachlauf-infrastruktur.md`, `docs/specs/measurement/spike-108-selbstkonsistenz-signal.md`.

## Risks & Considerations
- **Kein Korpus für Konventionen.** Der bestehende Treue-Korpus kennt nur Datum/Titel-Wahrheit, keine
  Historie aus Korrekturen. Der Konventionstest (zehn Muster) braucht neue Testdaten — Umfang der
  Spec muss das einpreisen, sonst sprengt es den Standard-Track.
  UI-Testing/Labor-App auf dem echten Gerät, nicht als Xcode-Testlauf.
- **Reproduzierbarkeit.** Wie bei #92: Wahrheit muss als Regel gegen den Referenztag des Laufs
  bewertet werden, keine festen Daten im Korpus (siehe `Corpus.swift`-Kommentar oben).
- **Rauschen zuerst messen.** Das Abbruchkriterium ist „Differenz ≤ Rauschen" — ohne eine
  Wiederholungslauf-Messung des Rauschens (gleicher Satz, gleiche Bedingung, mehrfach) ist die
  Differenz nicht interpretierbar. #107s Mehrfachlauf-Infrastruktur liefert das Werkzeug dafür.
- **Regeln-vor-Modell zuerst prüfen.** Bevor der Auslass-Test mit Embeddings aufgesetzt wird: prüfen,
  ob die naheliegenden Konventionen (Wort → Kontext, Wort → Projekt) sich schon per einfachem
  Wörterbuch/Regel aus Korrekturen ableiten lassen — das ist die Nulllinie, an der sich Retrieval
  und Modell messen lassen müssen, nicht ein Nice-to-have danach.

## Analysis

### Type
Feature (Mess-Spike, reine Messstrecke in `Measurement/`, kein Produktpfad).

### Entscheidung zum Zuschnitt (Henning, 2026-09-25)
Der volle Zuschnitt aus der Issue (Regel-Baseline + Embedding-Auslass-Test + Konventionstest in
einem Durchgang) sprengt das Scoping-Limit real (geschätzt 6 Dateien, ~350–400 LoC). Henning hat
sich für den kleineren ersten Schritt entschieden: **erst die einfache Regel messen.** Der
Embedding-Test folgt nur als eigenes, ebenfalls kleines Ticket, falls die Regel den Konventionstest
nicht schon besteht.

### Affected Files (with changes) — Ticket A (dieser Workflow)
| File | Change Type | Description |
|------|-------------|-------------|
| `Measurement/ConventionCorpus.swift` | CREATE | Typ + Ladefunktion für die zehn Konventions-Muster (drei Korrekturen + Sonde), analog zu `Corpus.swift` |
| `Measurement/convention-corpus.json` | CREATE | Zehn Muster, Quelle: FocusBlox-Export (287 echte Aufgaben) wenn dort genug wiederkehrende Wort→Kontext/Projekt-Muster vorkommen, sonst begründet synthetisch |
| `Measurement/RuleBaseline.swift` | CREATE | Wörterbuch-Mapping (Kernwort → häufigster Kontext/Projekt aus den drei Korrekturen) + Mehrheitsentscheid, reine Zeichenkettenverarbeitung, kein Modell-Call |
| `LooseEndsTests/ConventionBaselineTests.swift` (Name vorläufig) | CREATE | Testet die Regel-Baseline gegen den Konventionstest-Korpus, läuft ohne Gerät/Modell in der normalen Testsuite |
| `docs/reference/retrieval-convention-spike.md` | CREATE | Bericht: Trefferquote der Regel-Baseline, Entscheidung ob Ticket B (Embedding) nötig ist |

Nicht Teil dieses Tickets: `Measurement/RetrievalAblation.swift` (Embedding-Auslass-Test),
`NLContextualEmbedding`-Anbindung — folgt nur als eigenes Ticket, falls nötig.

### Scope Assessment
- Dateien: 5 (4 Code/Daten + 1 Bericht) — innerhalb des Limits
- Geschätzte LoC: ca. +150/-0
- Risiko: NIEDRIG — reiner Messcode ohne Produktpfad-Berührung, kein Gerätetestlauf nötig (reine
  Zeichenkettenverarbeitung läuft in der normalen Testsuite)

### Technical Approach
1. Konventionstest-Korpus bauen: zehn Muster (drei gleiche Korrekturen eines Wort→Kontext- oder
   Wort→Projekt-Zusammenhangs, dann eine vierte Aufgabe als Sonde mit erwartetem Wert). Quelle
   bevorzugt der FocusBlox-Export für realistische Muster statt synthetischer Sätze.
2. Regel-Baseline: Kernwort der Aufgabe extrahieren, häufigsten Kontext/Projekt aus den drei
   Korrekturen ableiten, gegen die Sonde prüfen. Kein Modell, kein Embedding — reine Regel.
3. Trefferquote über die zehn Muster berechnen (Schwelle aus der Issue: ≥ 8/10).
4. Bericht schreiben (Format wie `docs/reference/date-title-fidelity.md`): Trefferquote, pro Muster
   richtig/falsch, Entscheidung.

### Dependencies
- Braucht den FocusBlox-Export (`scripts/export-focusblox-corpus.swift`) als bevorzugte Musterquelle
  — vorhanden, aber Muster müssen manuell/skriptgestützt aus den 287 Aufgaben herausgesucht werden.
- Kein Gerätetestlauf nötig für diesen Teil (reine Zeichenkettenverarbeitung, kompiliert in
  `LooseEndsTests`).

### Folgeentscheidung
Erreicht die Regel-Baseline ≥ 8/10 im Konventionstest: B1 ist im Sinne der Alternative „Regeln aus
Korrekturen ohne Modell" beantwortet. Das stellt nicht nur den geplanten Zuschnitt von #26 zur
Disposition, sondern **ADR-5 selbst** („Lernen ist Retrieval, kein Training") — dann bräuchte es für
dieses Feld kein Embedding-Retrieval, und ADR-5 müsste auf „Regeln aus Korrekturen, kein Retrieval
nötig" umgeschrieben werden.
Erreicht sie das nicht: Ein neues, eigenes Ticket für den Embedding-Auslass-Test (Ticket B) wird
angelegt — Umfang dann bereits jetzt bekannt (~2 Dateien, ~150–200 LoC).

### Open Questions
Keine offenen Fragen mehr — Zuschnitt von Henning entschieden.

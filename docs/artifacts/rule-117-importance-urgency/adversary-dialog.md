# Adversary-Dialog: #117 Wichtigkeit und Dringlichkeit regelbasiert

- Workflow: `rule-117-importance-urgency`
- Spec: `docs/specs/enrichment/rule-117-importance-urgency.md`
- Datum: 2026-09-23
- Rolle: unabhaengige, adversariale Zweitpruefung (kein Nachvollziehen des Orchestrator-Laufs)
- Testlaeufe: `./scripts/sim.sh unit`, drei Laeufe, Rohausgaben im selben Ordner

## Beweismittel

| Datei | Inhalt |
|---|---|
| `unit-test-output.txt` | Lauf 1: Projektsuite unveraendert, 156 Tests gruen |
| `adversary-probe-output.txt` | Lauf 2: Projektsuite + 9 eigene Angriffstests, 165 gruen |
| `adversary-probe-round3.txt` | Lauf 3: Projektsuite + 12 eigene Angriffstests, alle gruen |

Die Angriffstests lagen temporaer in `LooseEndsTests/AdversaryProbe117Tests.swift`
und wurden nach dem Lauf wieder entfernt, das Xcode-Projekt danach neu erzeugt.

### Runde 1

Frage 1: Laeuft die Suite ueberhaupt, und deckt sie jede AC ab?

Befund: `./scripts/sim.sh unit` ist gruen, 156 Tests, 36 Suites, kein `error:`,
Abschlusszeile `Test Succeeded` / `Unit-Tests bestanden`
(`unit-test-output.txt`). Die AC-benannten Tests existieren und laufen:

```
Suite "Regelschritt: Wichtigkeit und Dringlichkeit" started
    ✔ "Wichtigkeits-Treffer je Kategorie (AC-1)"
    ✔ "Dringlichkeits-Treffer je Kategorie (AC-2)"
    ✔ "Kein Treffer bleibt nil, kein Default (AC-3)"
    ✔ "Wichtigkeit und Dringlichkeit sind unabhaengig (AC-4)"
    ✔ "Alle fuenf Begruendungssaetze sind im deutschen Bundle uebersetzt (AC-8)"
    ✔ "Der Regelschritt liegt im Produktmodul"
Suite "ModelEnrichment ohne Wichtigkeit/Dringlichkeit (AC-7)" started
    ✔ "Das Schema traegt keine importance/urgency-Eigenschaften mehr"
Suite "EnrichmentCoordinator"
    ✔ "Wichtigkeit ist unabhaengig vom Erfassungszeitpunkt (AC-5)"
    ✔ "Der Nachhol-Durchgang verdoppelt keine Wichtigkeits-/Dringlichkeits-Revision (AC-6)"
```

Frage 2: Gruen heisst nicht bewiesen. Wo sind die Luecken?

Vier Einwaende aus dem Lesen von Spec und Code, alle in Runde 1 noch **offen**:

1. Die Prioritaetsregel aus den Implementation Details (`money` vor `official` vor
   `peopleWaiting`, `deadline` vor `immediacy`) hat **keinen einzigen Test**. Ein Satz
   mit zwei Kategorien desselben Feldes ist nirgends geprueft.
2. Der AC-5-Test prueft nur `importance`, obwohl die AC woertlich `importance` **und**
   `urgency` verlangt, und der Testsatz hat gar kein Dringlichkeits-Signal.
3. Wortgrenzen und Gross-/Kleinschreibung sind im Code kommentiert, aber nicht belegt.
4. AC-7 haengt an `Mirror(reflecting:)` auf einem Makro-Typ. Liefert `Mirror` dort keine
   Kinder, besteht der Test **leer** — er koennte gar nicht fehlschlagen.

Runde 1 akzeptiert (Beweis liegt vor):

- [x] AC-3: `ImportanceUrgencyRuleTests.noHitStaysNil` gruen; Code kann strukturell kein
      `.low`/`.medium` liefern (`ImportanceUrgencyRule.swift:25,31` geben fest `.high`).
- [x] AC-7 (Teil 1, statisch): `FoundationModelsEnricher.swift` enthaelt nach
      `grep -inE "importance|urgency"` **keine** Fundstelle mehr; `EnrichmentWriter.swift`
      ebenfalls keine. Die sechs `@Guide`-Eigenschaften, der Signalsatz in `instructions`
      und die zwei `prompt(for:)`-Zeilen sind weg.
- [x] AC-8 (Teil 1, Katalog): alle fuenf Schluessel stehen mit `state: translated` und
      deutschem Wert in `LooseEnds/Resources/Localizable.xcstrings`.

Offen nach Runde 1: AC-1, AC-2, AC-4, AC-5, AC-6, AC-7 (Nicht-Leerheit), AC-8 (Nicht-Leerheit).

### Runde 2

Forderung: Die Einwaende 1-3 werden nicht diskutiert, sondern mit eigenen Tests
angegriffen. Neun Angriffstests, geschrieben ohne Ruecksicht auf die Projekttests:

| Test | Angriff |
|---|---|
| P1 | `"Rechnung vom Anwalt zahlen, er wartet auf Antwort"` trifft money + official + peopleWaiting — bleibt der Grund `money`? Und `"Der Anwalt wartet auf Unterschrift"` — schlaegt official peopleWaiting? |
| P2 | `"Dringend, die Frist laeuft ab"` trifft deadline + immediacy — bleibt der Grund `deadline`? |
| P3 | Sieben Fehltreffer-Kandidaten: `Beamtenrecht`, `Steuerrad`, `Gerichtete`, `Eurovision`, `Vertragen`, `Jetztzeit`, `Fristlos` |
| P4 | `DRINGEND` / `dringend` / `DrInGeNd`, `SPAETESTENS` mit Umlaut, `250 EURO`, `250€` ohne Leerzeichen |
| P5 | Neun Saetze: nie `.low`, nie `.medium`; Grenzeingaben `""`, `" "`, Emoji, `"..."`, 5000 Zeichen |
| P6 | Ein vom **Benutzer** gesetztes `.low` — ueberschreibt die Regel es? |
| P7 | `importance` gesetzt, `urgency` leer — sind die zwei Guards wirklich getrennt? |
| P8 | `EnrichmentWriter.apply` mit `draft.importance`/`.urgency` bei Konfidenz **1.0** |
| P9 | AC-5 haerter: derselbe Satz mit beiden Signalen, `capturedAt` heute vs. vor 10 Jahren, verglichen werden Wert, Grund **und** Konfidenz beider Felder |

Ergebnis (`adversary-probe-output.txt`, 165 Tests gruen):

```
Suite "Adversary Probe 117" started
    ✔ "P1 money schlaegt official und peopleWaiting"
    ✔ "P2 deadline schlaegt immediacy"
    ✔ "P3 Wortgrenzen, keine Fehltreffer mitten im Wort"
    ✔ "P4 Gross- und Kleinschreibung, Umlaute, Eurozeichen"
    ✔ "P5 nie .low oder .medium, Grenzeingaben liefern nil"
    ✔ "P6 Benutzerwert wird von der Regel nicht ueberschrieben"
    ✔ "P7 die beiden Guards sind wirklich getrennt"
    ✔ "P8 EnrichmentWriter schreibt importance und urgency auch bei Konfidenz 1.0 nicht"
    ✔ "P9 AC-5 haerter: Wichtigkeit UND Dringlichkeit UND Grund unabhaengig vom Erfassungszeitpunkt"
Suite "Adversary Probe 117" passed after 1.191 seconds
```

Kein einziger Angriff ging durch. Die Einwaende 1-3 aus Runde 1 sind damit erledigt:
Die Prioritaet ist deterministisch (P1, P2 — Deklarationsreihenfolge in
`ImportanceUrgencyRule.swift:37,66` ist die Prioritaet, `allCases.first(where:)` in
Z. 24/30 liest sie), die Wortgrenzen halten (P3, `contains(_:in:)` Z. 92-101), und
AC-5 gilt auch fuer `urgency`, den Grund und die Konfidenz (P9).

Zwei Erkenntnisse ueber die Spec hinaus, beide **staerker** als verlangt:

- P6 zeigt: Der Guard `task.importance == nil` (`EnrichmentCoordinator.swift:110,128`)
  schuetzt nicht nur vor der zweiten Regel-Revision (AC-6), sondern auch einen vom
  Benutzer gesetzten Wert. Die Regel schreibt nie ueber einen belegten Wert.
- P7 zeigt: Die Guards sind tatsaechlich unabhaengig — bei gesetzter Wichtigkeit
  entsteht die Dringlichkeit trotzdem, mit `sourceRaw = "ai"` und Konfidenz 1.0.

Runde 2 akzeptiert:

- [x] AC-1: drei Kategorien, je `.high`, Konfidenz 1.0, drei verschiedene, nicht-leere
      Gruende (Projekttest + P1 + P11).
- [x] AC-2: zwei Kategorien, je `.high`, Konfidenz 1.0, zwei verschiedene Gruende
      (Projekttest + P2 + P11).
- [x] AC-4: `"Sofort zurueckrufen"` -> nur Dringlichkeit, `"250 Euro …"` -> nur
      Wichtigkeit (Projekttest); P7 zeigt die Unabhaengigkeit zusaetzlich im Koordinator.
- [x] AC-5: P9 vergleicht beide Felder, den Grund und die Konfidenz bei 10 Jahren
      Altersunterschied — identisch. Strukturell abgesichert: die Signaturen
      `matchImportance(in:)`/`matchUrgency(in:)` (Z. 23/29) haben keinen Datumsparameter.
- [x] AC-6: Projekttest (zweiter Durchgang, genau eine Revision je Feld) + P6 + P7.

Offen nach Runde 2: Einwand 4. AC-7 und AC-8 sind gruen, aber ich habe noch **nicht
bewiesen, dass diese beiden Tests ueberhaupt fehlschlagen koennen**. Ein Test, der nicht
fehlschlagen kann, beweist nichts.

### Runde 3

Forderung: Gegenproben, die zeigen, dass die AC-7- und AC-8-Pruefungen greifen.

| Test | Gegenprobe |
|---|---|
| P10 | Ein erfundener Schluessel muss im `de.lproj`-Bundle auf sich selbst zurueckfallen; der echte money-Schluessel muss `"Aus einem Geldbetrag in der Notiz."` liefern |
| P11 | Die fuenf Gruende muessen fuenf **verschiedene**, nicht-leere Saetze sein |
| P12 | `Mirror` auf `ModelEnrichment` muss genau 18 Eigenschaften sehen und `title`, `durationConfidence`, `projectReason` **enthalten** — sonst waere die AC-7-Pruefung leer |

Ergebnis (`adversary-probe-round3.txt`, alle 12 Angriffstests gruen, Gesamtlauf
`Test Succeeded` / `Unit-Tests bestanden`):

```
    ✔ "P10 Gegenprobe zu AC-8: ein unuebersetzter Schluessel faellt sichtbar zurueck"
    ✔ "P11 der DE-Grund landet wirklich in der Revision, wenn die App deutsch laeuft"
Suite "Adversary Probe 117: AC-7 Gegenprobe" started
    ✔ "P12 Mirror sieht die verbliebenen Eigenschaften, die AC-7-Pruefung ist nicht leer"
```

Damit ist Einwand 4 erledigt: `Mirror` sieht 18 Eigenschaften und nennt `title`,
`durationConfidence` und `projectReason` — die Abwesenheit der sechs entfernten
Eigenschaften ist ein echter Befund, kein leerer Test. Zweite, unabhaengige Absicherung:
Der Projekttest ruft den memberwise Initialisierer von `ModelEnrichment` mit genau zwoelf
Argumenten auf; waeren die sechs Eigenschaften noch da, wuerde die Testdatei **nicht
kompilieren**. Und P10 zeigt, dass die Bundle-Abfrage bei fehlender Uebersetzung
tatsaechlich den englischen Schluessel zurueckgibt, der Test also fehlschlagen kann.

Runde 3 akzeptiert:

- [x] AC-7: Schema, `instructions`, `prompt(for:)`, `draft(from:)`-Mapping und die beiden
      `EnrichmentWriter`-Bloecke sind entfernt (statisch belegt); P8 beweist zur Laufzeit,
      dass ein Modell-Draft mit Konfidenz 1.0 nichts mehr schreibt (`written == 0`); P12
      beweist, dass die Reflexionspruefung nicht leer laeuft.
- [x] AC-8: fuenf Schluessel mit deutscher Uebersetzung im Katalog, im gebauten
      `de.lproj` nachgeschlagen (Projekttest), Gegenprobe P10 zeigt, dass die Methode
      einen fehlenden Eintrag sichtbar macht, P11 zeigt fuenf verschiedene Gruende.

### Regressionspruefung

- `EnrichmentWriter.apply` — einziger Produktaufrufer ist
  `EnrichmentCoordinator.processPending`; der Rueckgabewert geht nur in eine Logzeile.
  Die angepassten Erwartungen in `EnrichmentTests`/`RevisionServiceTests` (5 -> 4
  geschriebene Felder) sind konsistent mit den entfernten Bloecken.
- `RevisionService.aiSetFields` (`Shared/Services/RevisionService.swift:84-85`) zaehlt
  `importance`/`urgency` weiter, wenn die Quelle `ai` ist. Die Regel setzt genau diese
  Quelle — "Alles zuruecksetzen" raeumt Regelwerte also mit weg, exakt wie beim
  Faelligkeitsdatum aus #95. Kein Bruch, gewollte Fortfuehrung.
- `ViewRules.byUrgencyThenImportance`, `FieldCodec`, `TaskDetailView`, `FieldEditorView`
  unveraendert; die zugehoerigen Suites laufen gruen.
- `Shared/Enrichment/ImportanceUrgencyRule.swift` nutzt nur `Foundation` und steht ohne
  `#if canImport(FoundationModels)` — uebersetzt damit auch in Watch, Widgets und
  Share-Erweiterung. Der Projekttest `ruleLivesInProductModule` belegt die Modulzugehoerigkeit.

### Findings

Keine Finding der Stufe CRITICAL, HIGH oder MEDIUM. Zwei Beobachtungen der Stufe LOW,
beide von der Spec ausdruecklich vorweggenommen — keine Spec-Verletzung:

```
Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEndsTests/FocusBloxCalibrationTests.swift:108-130
  Description: Der Kalibrierungstest liest weiter draft.importance/draft.urgency. Diese
    Felder liefert der Modell-Adapter nach dem Schemaschrumpf nie mehr, also bleiben
    importanceOutcomes/urgencyOutcomes leer und die Zusicherung in Z. 130
    (#expect(!importanceOutcomes.isEmpty)) wuerde fehlschlagen.
  Spec requirement: Risiko 5 der Spec — "bewusst nicht Teil dieser Spec … als #118 vorgemerkt"
  Conflict: Keiner. Die Suite ist ueber die Existenz von
    docs/reference/focusblox-corpus.json gated (Z. 23); die Datei fehlt im Worktree und in
    Hennings Hauptordner, die Suite laeuft nie in CI. Issue #118 ist geprueft OPEN.
  Remediation: #118 abarbeiten, bevor der FocusBlox-Korpus das naechste Mal exportiert wird.
```

```
Finding:
  ID: F002
  Severity: LOW
  Category: anti_pattern
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:158-159
  Description: examples(in:) befuellt EnrichmentExample weiter mit importance und urgency,
    obwohl prompt(for:) die beiden Zeilen nicht mehr schreibt. Die Werte werden erhoben
    und dann verworfen.
  Spec requirement: AC-7 verlangt nur, dass die zwei Zeilen in prompt(for:) entfernt sind.
  Conflict: Keiner — die Spec nennt EnrichmentExample nicht unter Affected Files, und ein
    Aufraeumen waere Drive-by-Refactoring ausserhalb des Tickets (CLAUDE.md Scoping).
  Remediation: Bei naechster Beruehrung des Beispielpfads mitnehmen, nicht hier.
```

Zwei bewusst **nicht** als Finding gewertete Punkte, damit sie nachvollziehbar sind:

- `"jetzt"` ist ein sehr haeufiges deutsches Fuellwort und macht `"Jetzt endlich das
  Buch lesen"` dringend. Das ist ein Fehltreffer — aber die Spec listet `"jetzt"`
  woertlich als immediacy-Schluesselwort und beschreibt genau diesen Fall als Risiko 2
  mit der Begruendung "kein Rueckschritt gegenueber dem Status quo". Umsetzung
  spec-konform; wer das anders will, aendert die Spec, nicht den Code.
- Deutsche Komposita wie `"Stromrechnung"` oder `"Ordnungsamt"` treffen wegen der
  Wortgrenzen **nicht**. Das ist Risiko 1 der Spec: Der Ausfall ist `nil`, nicht ein
  falscher Wert, und Luecken werden als eigene kleine Issues nachgezogen.

### Endstand je Acceptance Criterion

- [x] AC-1 Wichtigkeits-Treffer je Kategorie: money/official/peopleWaiting je `.high`,
      Konfidenz 1.0, drei verschiedene nicht-leere Gruende; Prioritaet bei Mehrfachtreffern
      deterministisch bewiesen (P1).
- [x] AC-2 Dringlichkeits-Treffer je Kategorie: immediacy/deadline je `.high`,
      Konfidenz 1.0, zwei verschiedene Gruende; `deadline` schlaegt `immediacy` (P2).
- [x] AC-3 Kein Treffer bleibt `nil`: `"Blumen giessen"` liefert beidseitig `nil`; ueber
      neun Saetze und fuenf Grenzeingaben kam nie `.low` oder `.medium` (P5).
- [x] AC-4 Wichtigkeit und Dringlichkeit unabhaengig: beide Richtungen belegt, im
      Baustein und im Koordinator (P7).
- [x] AC-5 Alter der Notiz ist kein Signal: strukturell (keine Datumsparameter) und
      empirisch ueber 10 Jahre Altersunterschied fuer Wert, Grund und Konfidenz beider
      Felder (P9).
- [x] AC-6 Guard gegen Doppel-Revision, getrennt je Feld: genau eine Revision je Feld im
      Nachhol-Durchgang; zusaetzlich bleibt ein Benutzerwert unangetastet (P6) und die
      Guards greifen unabhaengig voneinander (P7).
- [x] AC-7 Modellschema verliert die sechs Eigenschaften: statisch (kein Treffer mehr in
      `FoundationModelsEnricher.swift` und `EnrichmentWriter.swift`), zur Laufzeit
      (`written == 0` trotz Konfidenz 1.0, P8) und als Gegenprobe gegen einen leeren
      Reflexionstest (P12).
- [x] AC-8 Lokalisierung von Anfang an: fuenf Schluessel mit deutscher Uebersetzung im
      Katalog und im gebauten `de.lproj`; Gegenprobe P10 zeigt, dass ein fehlender
      Eintrag den Test zum Fallen braechte.

## Verdict
**VERIFIED**

Tests: 156 Projekttests gruen (Lauf 1), 165 gruen mit 9 Angriffstests (Lauf 2),
alle 12 Angriffstests gruen im Lauf 3. Null Fehlschlaege in allen drei Laeufen.
Edge Cases: 12 eigene Angriffe (Prioritaet, Wortgrenzen, Gross-/Kleinschreibung,
Umlaute, Eurozeichen, Leer- und Riesen-Eingaben, Benutzerwert, getrennte Guards,
Writer-Pfad, Nicht-Leerheit von zwei Pruefungen) — kein einziger ging durch.
Regressionen: keine.
Checkliste: 8 von 8 Punkten bewiesen.

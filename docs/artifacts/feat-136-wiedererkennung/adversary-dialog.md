# Adversary Dialog — feat-136-wiedererkennung

Massstab: docs/specs/enrichment/feat-136-wiedererkennung.md. Arbeitsverzeichnis:
/Users/hem/Developer/loose-ends/.claude/worktrees/issue-136.

### Runde 1

Eigener Testlauf (nicht nur das behauptete Artefakt uebernommen): scripts/sim.sh generate dann
scripts/sim.sh unit, Output gesichert unter /tmp/adversary_test_output.txt (eigene Kopie des Laufs,
unabhaengig vom uebergebenen test-green-output.txt erzeugt).
Ergebnis: Test Succeeded, 220 gruene Haekchen, keine failed/issue(s)-Zeile ausser der erwarteten
"Executed 0 tests" des leeren Host-App-Ziels.
Code reference: Shared/Enrichment/RecognitionRule.swift:1

- [x] AC-1: EnrichmentTests.swift:425-451 (adoptsDurationAndContextsFromIdenticalRawText) laeuft ueber
  EnrichmentCoordinator.processPending(), prueft fresh.duration == .minutes30,
  durationSourceRaw == "ai", durationConfidence == 1.0, contexts == ["Garten"],
  contextsSourceRaw == "ai", contextsConfidence == 1.0 sowie je eine Revision mit author == .ai fuer
  .duration und .contexts. Gruener Testlauf bestaetigt.
  Code reference: LooseEndsTests/EnrichmentTests.swift:425
- [x] AC-2: RecognitionRule.match liefert nil bei unterschiedlicher Wortmenge, geprueft in
  RecognitionRuleTests.differentTextYieldsNothing und end-to-end in
  EnrichmentTests.differentWordBlocksAdoption (unrelated.duration == nil).
  Code reference: LooseEndsTests/RecognitionRuleTests.swift:56
- [x] AC-3: Gross-/Kleinschreibung, Satzzeichen, Wortstellung ignoriert - RecognitionRule.wordSet
  normalisiert ueber RawTextWords, ein Set statt Array macht die Reihenfolge irrelevant.
  RecognitionRuleTests.normalisationIsIgnored deckt drei Varianten ab, gruen.
  Code reference: Shared/Enrichment/RecognitionRule.swift:69
- [x] AC-4: Kein Vier-Zeichen-Filter in RawTextWords.words(in:)/RecognitionRule.wordSet (Filter
  existiert nur in LeaveOneOut.similarityWords). "Tee holen"/"Bad holen" und
  "30 Minuten Sport"/"60 Minuten Sport" liefern beide nil.
  Code reference: Shared/Services/RawTextWords.swift:21
- [x] AC-5: RecognitionRule.Match/Candidate besitzen strukturell kein Energiefeld, per Mirror-
  Reflection in RecognitionRuleTests.energyIsStructurallyAbsent geprueft, nicht nur "Testdaten setzen
  keine Energie". End-to-end: EnrichmentTests.energyIsNeverAdopted.
  Code reference: Shared/Enrichment/RecognitionRule.swift:42
- [x] AC-6: winner(among:source:value:reason:) sortiert zuerst nach source == .user, dann aufsteigend
  nach id.uuidString. RecognitionRuleTests.userSetValuesWin und .tiesBreakByIdNotByPoolOrder laufen je
  zweimal mit vertauschter Pool-Reihenfolge, gleiches Ergebnis.
  Code reference: Shared/Enrichment/RecognitionRule.swift:76
- [x] AC-7: Pool kommt ausschliesslich aus FetchDescriptor<TaskItem>(predicate: processedAt != nil) in
  recognitionInputs, einmal vor der Schleife geholt. EnrichmentTests.unprocessedTasksAreNotPartOfThePool
  bestaetigt: zwei unverarbeitete, wortgleiche Aufgaben im selben Lauf befruchten sich nicht.
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:160
- [x] AC-8: applyRecognitionRule prueft task.duration == nil bzw. (task.contexts ?? []).isEmpty vor
  dem Setzen. EnrichmentTests.catchUpPassAddsNoSecondRevision simuliert das Szenario (Modell
  zunaechst nicht verfuegbar, processedAt bleibt leer, zweiter Lauf mit Modell).
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:186
- [x] AC-9: EnrichmentWriter.apply prueft task.duration == nil (Zeile 51) und
  (task.contexts ?? []).isEmpty (Zeile 67) vor dem Schreiben. EnrichmentTests.modelDoesNotOverwriteAnExistingValue
  ruft EnrichmentWriter.apply isoliert (ohne Coordinator) mit einem Draft ueber der Schwelle gegen
  eine Aufgabe mit bereits gesetzter Dauer/Kontexten; beide Felder unveraendert, keine neue Revision.
  Einschraenkung siehe Finding F003: der Test prueft nicht den Rueckgabewert written, den der Test
  Plan der Spec ausdruecklich verlangt.
  Code reference: Shared/Enrichment/EnrichmentWriter.swift:51
- [x] AC-10: RawTextWords.normalized(_:)/.words(in:) leben in Shared/Services/RawTextWords.swift.
  LeaveOneOut.similarityWords ruft sie auf (mit Vier-Zeichen-Filter danach), RecognitionRule.wordSet
  ruft dieselbe Funktion (ohne Filter). RawTextWordsTests.measurementUsesTheSharedTokenizer vergleicht
  beide Zerlegungen direkt; measurementDeclaresNoOwnTokenizer prueft strukturell, dass
  Measurement/Corpus.swift normalized(/words(in nicht mehr selbst deklariert. Bestaetigt durch eigenen
  git diff: TitleCheck.normalized/.words(in:) sind aus Corpus.swift entfernt, RuleBaseline.swift ruft
  ebenfalls RawTextWords auf.
  Code reference: Measurement/Corpus.swift:236
- [x] AC-11: Localizable.xcstrings traegt den Schluessel "From a raw text captured before, word for
  word." mit extractionState: translated und deutschem Wert "Aus einem schon einmal erfassten Text,
  wortgleich." (per Skript aus der gebauten Ressource gelesen). RecognitionRuleTests.reasonIsTranslatedToGerman
  bestaetigt zur Laufzeit im gebauten de.lproj-Bundle translated != key. Siehe Runde 2 fuer die
  vertiefte Pruefung des Testumbaus (Punkt a des Auftrags).
  Code reference: LooseEnds/Resources/Localizable.xcstrings:1
- [x] AC-12: RecognitionRuleCorpusTests.fullPoolReproducesTheMeasuredNumbers bestaetigt 61/104
  Kontext- und 169/276 Dauer-Treffer, je 100 Prozent korrekt; deduplicatedPoolShowsItIsRecognitionNotSimilarity
  bestaetigt 0/0 auf dem entduplizierten Pool. Beide Tests liefen in meinem eigenen Testlauf gruen,
  mit lokal vorhandener docs/reference/focusblox-corpus.json (200315 Bytes, im Worktree vorhanden).
  Der Klassenkommentar traegt den geforderten Vermerk: Zahlen gelten fuer gepflegte Titel aus dem
  FocusBlox-Export, nicht fuer diktierten Rohtext (#82/#88). @Suite(.enabled(if:)) gattert korrekt
  ueber FileManager.default.fileExists.
  Code reference: LooseEndsTests/RecognitionRuleTests.swift:255

Erste Runde ergibt: alle 12 nummerierten AC beweisbar auf Code- und Testebene. Das genuegt nicht als
Freigabe - Runde 2 prueft die drei ausdruecklich benannten Eingriffe (a, b, c) und den Rest der Spec
(Definition of Done), die ueber die 12 AC hinausgeht.

### Runde 2

Punkt a - Umbau von reasonIsTranslatedToGerman (AC-11): Begruendung des Entwicklers geprueft, nicht
uebernommen. Das urspruengliche RED-Muster nutzte den zur Laufzeit erzeugten reason als
Nachschlage-Schluessel in der de.lproj-Bundle. xcstrings-Schluessel sind aber immer der englische
Basistext. Laeuft der Testprozess mit deutscher Systemsprache, liefert String(localized:) in der
Produktionsregel bereits den deutschen Satz als reason zurueck - und dieser deutsche Satz als
Schluessel in die Tabelle nachgeschlagen existiert dort nicht; Foundation gibt bei fehlendem
Schluessel und value: nil den Schluessel selbst zurueck, also translated == reason immer, Test
schlaegt strukturell fehl, unabhaengig von der Uebersetzung. Beleg, dass das kein erfundenes Argument
ist: genau dasselbe Muster wie die Neufassung existiert bereits und funktioniert seit #98 in
DueDateRuleTests.reasonsAreTranslatedToGerman - dort steht sogar der Kommentar, warum: Bundle.main im
Testprozess ist damit der App-Bundle, der Test liest die deutsche Uebersetzung direkt aus dem
gebauten de.lproj-Bundle, unabhaengig von der Simulator-/Geraete-Systemsprache; die Schluessel sind
woertlich aus DueDateRule.swift kopiert. Die Neufassung fuer RecognitionRule uebernimmt exakt dieses
Muster und geht noch einen Schritt weiter als das Vorbild: sie bindet zusaetzlich reason an genau
diesen Schluessel (reason == key oder reason == translated), was DueDateRuleTests nicht einmal tut -
die Neufassung ist strenger, nicht schwaecher. Eigener Testlauf bestaetigt: der Test ist gruen in
dieser (vermutlich deutschsprachigen) Umgebung, was nur moeglich ist, wenn die Bundle-Uebersetzung
UND die Laufzeit-reason beide zum harten Schluessel passen - ein weichgespuelter Test haette auch bei
fehlender Uebersetzung gruen bleiben koennen, das tut dieser nicht (Gegenprobe: fehlte die
Uebersetzung, gaebe localizedString(forKey: key, value: key, table: nil) den key zurueck und
translated != key schluege fehl).
Verdikt zu (a): kein weichgespueltes Kriterium, Begruendung wahr, AC-11 weiterhin vollstaendig
geprueft.
Code reference: LooseEndsTests/DueDateRuleTests.swift:125

Punkt b - task.contexts == nil vs. (task.contexts ?? []).isEmpty: reale Luecke, wenn auch mit
begrenztem Fenster. Nachvollzogen anhand des bestehenden Codes (nicht nur behauptet):
1. FieldCodec.apply (Fall .contexts) setzt task.contextsSourceRaw auf nil, sobald task.contexts leer
   ist - bereits vor #136 vorhanden, nicht Teil dieser Aenderung. Raeumt ein Nutzer ueber
   FieldEditorView alle Kontexte einer Aufgabe bewusst ab, wird task.contexts = [] (nicht nil) UND
   contextsSourceRaw faellt auf nil zurueck - nicht unterscheidbar von "nie gesetzt".
   Code reference: Shared/Services/FieldCodec.swift:64
2. Keine View gattert das Bearbeiten von Kontexten auf bereits verarbeitete Aufgaben. Eigene Suche
   (grep processedAt in LooseEnds/Views/*.swift) liefert keinen Treffer. Ein Nutzer kann also eine
   noch nicht durchgelaufene Aufgabe (processedAt == nil, z. B. weil das Modell nicht verfuegbar ist -
   exakt das in AC-8 durchgespielte Szenario) jederzeit oeffnen und ihre Kontexte aendern.
   Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:29
3. Trifft beides zusammen (Regel setzt faelschlich einen Kontext auf einer noch offenen Aufgabe, der
   Nutzer korrigiert auf "keine", das Modell bleibt weiterhin unverfuegbar oder ein erneuter
   Nachzuegler-Lauf greift vorher), sieht applyRecognitionRule beim naechsten Lauf
   (task.contexts ?? []).isEmpty == true (weil [], nicht weil nil) und setzt exakt den vom Nutzer
   entfernten Kontext erneut, mit einer neuen KI-Revision - die Nutzerkorrektur wird stillschweigend
   rueckgaengig gemacht. Das widerspricht ADR-5 woertlich ("Korrekturen des Nutzers bleiben Beispiele
   erster Klasse") und dem in dieser Spec selbst fuer duration/durationSourceRaw angewendeten
   Vorrangprinzip (AC-6), das fuer contexts durch die Kollision mit dem vorbestehenden
   FieldCodec-Verhalten faktisch aufgehoben wird.
   Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:200
4. Waere stattdessen woertlich task.contexts == nil geprueft worden (wie im Signaturvorschlag der
   Spec, Implementation Details Punkt 4), haette task.contexts = [] (eine echte, explizit zugewiesene
   leere Liste) die Bedingung nicht erfuellt - die Regel haette den Nutzerentscheid stehen lassen. Der
   im Code hinterlegte Kommentar (ein leeres Relationship-Array sei so gut wie nil) behauptet
   Aequivalenz, die fuer den Fall "nie zugewiesen" zutrifft, aber nicht fuer den Fall "explizit auf
   leer gesetzt". Kein Test der Suite deckt dieses Szenario ab. Betrifft nur contexts
   (Relationship/Array), nicht duration (skalares Optional ohne diese Sonderflaeche).
   Code reference: Shared/Enrichment/EnrichmentWriter.swift:67

Punkt c - test-red-behaviour.txt: der Vergleich gegen den Commit 84f2fd1 (git diff) zeigt: die alte
Fassung endete abgeschnitten mitten in der Suite "TaskActions" (kein Zeilenumbruch am Dateiende). Die
neue Fassung haengt lediglich den Rest desselben, bereits abgeschlossenen Testlaufs an (weitere
bereits gruene Suiten). Die entscheidende Stelle bleibt unveraendert erhalten: "Suite Wiedererkennung
im Coordinator (#136) failed after 1.057 seconds with 18 issue(s)" steht weiterhin in Zeile 540, mit
allen sieben fehlgeschlagenen Einzeltests (AC-1, AC-3, AC-5, AC-6, AC-8, AC-9). Kein Fehlschlag wurde
entfernt oder veraendert.
Verdikt zu (c): kein Verschleiern eines RED-Befunds, reine Vervollstaendigung eines abgeschnittenen
Artefakts.
Code reference: docs/artifacts/feat-136-wiedererkennung/test-red-behaviour.txt:540

Zusaetzlich gefunden (nicht in den drei benannten Punkten, aber Teil der Spec): Definition of Done
unvollstaendig. Die Spec verlangt unter "Definition of Done" ausdruecklich drei Dokument-Korrekturen
als eigene Punkte - mit der Vorgeschichte, dass Henning genau diesen DoD-Punkt fuer 04-stand.md schon
einmal nachtragen musste, weil die erste Spec-Fassung ihn ausliess (Changelog-Eintrag 2 der Spec).
Geprueft: keine der drei Dateien ist im Arbeitsverzeichnis veraendert (Arbeitsbaum-Status zeigt sie
nicht, kein Commit seit 8c41c09 fasst sie an) - UND ihr Inhalt traegt weiterhin exakt die von der Spec
als falsch benannten Saetze:
- docs/project/02-datenmodell-und-ansichten.md:178-180: "Ab einer Aehnlichkeit von 0,34 setzt der
  beste Treffer ... das Modell wird fuer diese beiden Felder nicht mehr gefragt." - beides laut Spec
  falsch (Mechanismus ist Gleichheit, nicht Schwelle 0,34; das Modell wird laut PO-Entscheidung
  weiterhin gefragt) und laut DoD zu korrigieren.
- docs/project/06-annahmen-und-experimente.md:151: Tabellenkopf "Nachbar fast wortgleich (Jaccard >=
  0,34)" ist laut DoD in "Faelle im Band vs. Trefferquote" umzubeschriften, mit ergaenztem Band unter
  0,34 - unveraendert im Ist-Zustand.
- docs/project/04-stand.md:115: #136 steht weiterhin in der Prioritaetenliste der offenen Features
  ("6. #136 Bekannter Rohtext setzt die frueheren Werte"), obwohl dieses Ticket #136 gerade umsetzt -
  der DoD verlangt ausdruecklich die Entfernung aus dieser Liste.
Code reference: docs/project/04-stand.md:115

### Runde 3

Eigener Testlauf, unabhängig vom übergebenen `test-green-output.txt`: `./scripts/sim.sh generate`
dann `./scripts/sim.sh unit`, Log unter `~/Library/Developer/Xcode/DerivedData/LooseEnds-session-default/xcodebuild.log`.
Ergebnis: `Test Succeeded`, 222 grüne Häkchen, 0 fehlgeschlagene Assertions (`grep -c "✔"` = 222 im
eigenen Mitschnitt, deckungsgleich mit dem committeten `test-green-output.txt`). Korpus-Suite lief
real, nicht übersprungen: `RecognitionRuleCorpusTests` zeigt „Voller Pool: 61 von 104 Kontext- und
169 von 276 Dauer-Aufgaben, je 100 % richtig (AC-12)" und „Entduplizierter Pool: praktisch kein
Treffer" beide grün, mit lokal vorhandener `docs/reference/focusblox-corpus.json`. Die drei durch den
Testlauf überschriebenen Referenzberichte (`docs/reference/date-title-fidelity.md`,
`focusblox-calibration-report.md`, `retrieval-leave-one-out-rules.md`) wurden danach per
`git checkout --` zurückgesetzt; Arbeitsstand sauber.
Code reference: LooseEndsTests/RecognitionRuleTests.swift:236

Vorgeschichten-Korrekturen des ersten Durchgangs unabhängig nachvollzogen (Auftrag, Absatz 2):

1. „Betrifft nur contexts, nicht duration" war falsch — bestätigt. `FieldCodec.swift:55-57` zeigt:
   `task.durationSourceRaw = task.duration == nil ? nil : sourceRaw` kollabiert den Herkunftsvermerk
   beim Leeren exakt so wie `:62-66` es für `contexts` tut. Der jetzige Fix behandelt beide Felder in
   beiden Schreibpfaden.
   Code reference: Shared/Services/FieldCodec.swift:55
2. „Auslöser ist Kontext-Löschen in einer View" existiert nicht — bestätigt per eigener Suche:
   `grep -rn ".contexts = " Shared LooseEnds --include=*.swift` liefert als einzige Schreibstellen
   `EnrichmentWriter.swift:54/75`, `EnrichmentCoordinator.swift:197/214`, `CatalogService.swift:44` und
   `FieldCodec.swift:64` — keine View. Der reale Auslöser ist der `RevisionService`-Reset
   (`RevisionService.swift:28`, `set(..., force: true)` ruft `FieldCodec.apply` auf, das den Wert
   leert und den Herkunftsvermerk mitreißt).
   Code reference: Shared/Services/RevisionService.swift:28

F002-Fix nachvollzogen, nicht nur behauptet:

- `EnrichmentWriter.userHasTouched(_:on:)` (`EnrichmentWriter.swift:103-105`) prüft
  `(task.revisions ?? []).contains { $0.field == field && $0.author == .user }` — feldscharf.
  Prüfpunkt 2 des Auftrags: kann eine Nutzer-Revision an einem ANDEREN Feld einen echten Erst-Treffer
  blockieren? Nein — `$0.field == field` schließt das strukturell aus.
  Code reference: Shared/Enrichment/EnrichmentWriter.swift:51
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:190
- Zwei Regressionstests bestätigt gelaufen: `userResetOfDurationIsNotUndone`
  (`EnrichmentTests.swift:621-650`) und `userResetOfContextsIsNotUndone` (`:655-683`) — beide bauen den
  Reproduktionsfall aus dem Changelog nach und sind grün im eigenen Testlauf.
  Code reference: LooseEndsTests/EnrichmentTests.swift:621

Prüfpunkt 1 des Auftrags — Tragfähigkeit des Revisions-Markers vertieft: `CatalogService.delete(_
taskContext:in:)` (`CatalogService.swift:42-47`) entfernt einen gelöschten Kontext-Tag aus ALLEN
Aufgaben per direktem Array-Filter, ohne jede Revision und ohne `contextsSourceRaw` zu berühren — eine
echte Lücke gegen „Revisions, not undo" (CLAUDE.md), vorbestehend, nicht durch #136 eingeführt.
Eigenständig geprüft, ob sie den Wiedererkennungs-Guard aushebelt: tut sie nicht, aus zwei
unabhängigen Gründen:
  a) `applyRecognitionRule` läuft nur über `pending` (`processedAt == nil && status == unprocessed`,
     `EnrichmentCoordinator.swift:36-38`). Ein Kontext, der vom Nutzer gesetzt wurde, hinterlässt über
     `RevisionService.set` eine Nutzer-Revision (schützt bereits).
  b) Selbst wenn eine noch offene Aufgabe (Modellfehler, `processedAt == nil`) den Kontext von der
     Regel selbst bekam und der Tag danach global gelöscht wird: das gelöschte `TaskContext`-Objekt
     verschwindet auch bei allen Pool-Kandidaten. `RecognitionRule.winner(...)`
     (`RecognitionRule.swift:61`, `value: { $0.contextNames.flatMap { $0.isEmpty ? nil : $0 } }`)
     filtert jeden Kandidaten mit leerer Kontextliste aus der Gewinner-Berechnung — kein Kandidat mit
     gültigem Wert übrig, `match.contexts` wird `nil`, der Guard bekommt nie einen Treffer zu sehen.
  Fazit: reale, vorbestehende Lücke in `CatalogService`, aber kein Weg gefunden, sie in eine
  tatsächliche Regression gegen AC-1/AC-6/AC-8/AC-9 dieses Tickets zu verwandeln. Empfehlung: eigenes
  Issue außerhalb des Scopes von #136.
  Code reference: Shared/Services/CatalogService.swift:42

Prüfpunkt 3 des Auftrags — sechs DoD-Forderungen einzeln gegen die drei Dokumente geprüft:

- Mechanismus Gleichheit statt Schwelle 0,34: `docs/project/02-datenmodell-und-ansichten.md:174-176`
  „Gleichheit der normalisierten Wortmenge, keine Ähnlichkeitsschwelle" — erfüllt.
  Code reference: docs/project/02-datenmodell-und-ansichten.md:174
- Satz „das Modell wird für diese beiden Felder nicht mehr gefragt" entfernt: derselbe Absatz sagt
  jetzt das Gegenteil, begründet: „Das Modell wird für Dauer und Kontexte weiter gefragt ... sein Wert
  greift aber nur auf ein noch leeres Feld" — erfüllt.
  Code reference: docs/project/02-datenmodell-und-ansichten.md:177
- Spaltenbeschriftung Fälle-im-Band vs. Trefferquote: `docs/project/06-annahmen-und-experimente.md:149-150`
  „steht die Zahl der Fälle im Band ... und dahinter die Trefferquote innerhalb dieses Bandes" —
  erfüllt.
  Code reference: docs/project/06-annahmen-und-experimente.md:149
- Band unter 0,34 ergänzt: Tabellenkopf trägt jetzt die vierte Spalte „0 < Jaccard < 0,34" (`:153`) —
  vorher fehlte sie laut Runde-2-Befund komplett — erfüllt.
  Code reference: docs/project/06-annahmen-und-experimente.md:153
- #136 aus der Prioritätenliste entfernt: `grep -n "#136" docs/project/04-stand.md` liefert nur noch
  zwei historische Erwähnungen (Zeile 88, Zeile 105), keine mehr in der mit „5. #25 ..." beginnenden
  Prioritätenliste der offenen Features — erfüllt.
  Code reference: docs/project/04-stand.md:88
- Satz zur geschärften Dauer auf den umgesetzten Mechanismus gebracht: `docs/project/04-stand.md:86-88`
  „Dauer und Kontexte kommen bei wortgleich wiederkehrendem Rohtext aus der früheren Aufgabe —
  Gleichheit der normalisierten Wortmenge, keine Ähnlichkeitsschwelle" — erfüllt.
  Code reference: docs/project/04-stand.md:86

Zahlenprobe gegen den Swift-Testlauf: Tabelle nennt 61/104 (Kontexte) und 169/276 (Dauer) bei
Jaccard = 1,0, mit dem Kommentar, die Zahlen seien in Swift bestätigt. Eigener Testlauf bestätigt
exakt diese Zahlen (`RecognitionRuleCorpusTests`) — deckungsgleich, keine Abweichung gefunden.
Code reference: docs/project/06-annahmen-und-experimente.md:151

### Runde 4

Alle 12 AC erneut einzeln geprüft, kein Übernehmen aus Runde 1/2 ohne eigenen Beleg:

- [x] AC-1: `EnrichmentTests.swift:426-455` (`adoptsDurationAndContextsFromIdenticalRawText`), grün im
  eigenen Lauf; prüft Wert, Herkunft, Konfidenz und Revision für beide Felder.
  Code reference: LooseEndsTests/EnrichmentTests.swift:427
- [x] AC-2: `RecognitionRuleTests.swift:56-60` und `EnrichmentTests.swift:475-495`, grün.
  Code reference: LooseEndsTests/RecognitionRuleTests.swift:57
- [x] AC-3: `RecognitionRuleTests.swift:64-79` und `EnrichmentTests.swift:457-470`, grün.
  Code reference: LooseEndsTests/RecognitionRuleTests.swift:65
- [x] AC-4: `RecognitionRuleTests.swift:81-90`, kein Vier-Zeichen-Filter in `RawTextWords.words(in:)`,
  grün.
  Code reference: Shared/Enrichment/RecognitionRule.swift:69
- [x] AC-5: `RecognitionRuleTests.swift:93-108` (Mirror-Reflection) und `EnrichmentTests.swift:497-515`,
  grün. `RecognitionRule.Match`/`Candidate` besitzen strukturell kein Energiefeld.
  Code reference: Shared/Enrichment/RecognitionRule.swift:27
- [x] AC-6: `RecognitionRuleTests.swift:110-141` und `EnrichmentTests.swift:519-533`, grün. `winner(...)`
  sortiert nach `source == .user` zuerst, dann `id.uuidString` aufsteigend, feldgetrennt.
  Code reference: Shared/Enrichment/RecognitionRule.swift:76
- [x] AC-7: `EnrichmentTests.swift:538-554`, grün. Pool kommt ausschließlich aus
  `#Predicate { $0.processedAt != nil }`.
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:160
- [x] AC-8: `EnrichmentTests.swift:556-578`, grün. Guard `task.duration == nil`/
  `(task.contexts ?? []).isEmpty` verhindert den zweiten Regelschritt.
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:190
- [x] AC-9: `EnrichmentTests.swift:584-615`, grün, jetzt mit explizitem `written == 0` (Zeile 609) —
  F003 aus Runde 2 geschlossen, selbst nachgeprüft im Quelltext.
  Code reference: LooseEndsTests/EnrichmentTests.swift:609
- [x] AC-10: `RawTextWordsTests` (`RecognitionRuleTests.swift:191-233`), zwei Nachweise (Verhalten +
  Struktur), grün. `Measurement/Corpus.swift` deklariert `normalized`/`words(in:)` nicht mehr selbst.
  Code reference: Measurement/Corpus.swift:241
- [x] AC-11: `RecognitionRuleTests.swift:171-184`, grün; Schlüssel im `Localizable.xcstrings` mit
  `extractionState: translated` und deutschem Wert bestätigt (eigene Prüfung).
  Code reference: LooseEnds/Resources/Localizable.xcstrings:1
- [x] AC-12: `RecognitionRuleCorpusTests.swift:280-330`, beide Tests grün im eigenen Lauf mit lokal
  vorhandenem Korpus: voller Pool 61/104 Kontexte, 169/276 Dauer, je 100 %; entduplizierter Pool 0/0.
  `@Suite(.enabled(if:))` gattert korrekt.
  Code reference: LooseEndsTests/RecognitionRuleTests.swift:255

Definition of Done (Dokument-Trio) — alle drei Korrekturen inhaltlich, nicht nur formal, geprüft (siehe
Runde 3). F001 aus Runde 2 vollständig geschlossen.

Verbleibender Punkt, kein Finding: die Checkbox-Liste unter „Definition of Done" in der Spec selbst
steht weiterhin auf `[ ]` für alle Punkte — betrifft Prozessschritte, die erst beim Zusammenführen
anfallen (Gerätetest, PR, `sync-main`, CI), nicht den hier geprüften Code- und Dokumentationsstand.

## Structured Findings

F001, F002, F003 (Runde 1/2): geschlossen, siehe Belege in Runde 3/4 oben.

Empfehlung (kein Finding gegen #136, da keine nachweisbare Regression):
  Kontext: `CatalogService.delete(_ taskContext:in:)` entfernt einen gelöschten Kontext-Tag aus allen
  Aufgaben ohne Revision (`CatalogService.swift:42-47`), ein Verstoß gegen „Revisions, not undo"
  (CLAUDE.md), unabhängig von #136 vorbestehend.
  Vorschlag: eigenes Issue, außerhalb dieses Tickets.

## Verdict

VERDICT: VERIFIED

Tests: 222 bestanden, 0 fehlgeschlagen (eigener Lauf, `Test Succeeded`), inklusive der gegatterten
Korpus-Suite mit realen Zahlen (61/104, 169/276, entdupliziert 0/0).
Checkliste: 12/12 Acceptance Criteria bewiesen.
Regressionen: keine gefunden; die beiden vom ersten Durchgang selbst falsch eingeschätzten Punkte
(„nur contexts", „Auslöser ist eine View") wurden unabhängig nachvollzogen und als korrigiert
bestätigt. Die zusätzlich aufgedeckte `CatalogService`-Lücke ist vorbestehend und führt zu keiner
nachweisbaren Regression gegen die 12 AC dieses Tickets.

## Geprüfte Dateien

- sha256:310fc45b58163a10fe417a5c07b4bf72ba0399b750ea947731bcdbda20712542  LooseEnds/Resources/Localizable.xcstrings
- sha256:bf36653652e6ebaedb824a6c1bd610b1834740bd26a7c77163d354402675a3d7  LooseEndsTests/DueDateRuleTests.swift
- sha256:a802e367cfdead07a9665816f3bf7f126f81798760c9c3930e9fd83bd01911a6  LooseEndsTests/EnrichmentTests.swift
- sha256:cb8df88035110c062fa8a2727f4bae451a305dcaf6e08ff32c398c09b227e3aa  LooseEndsTests/RecognitionRuleTests.swift
- sha256:43663ee1dd8a6f3dbb0f67f05a9ad6ed08fae09d5158eecde4f4513ee38ae2b2  Measurement/Corpus.swift
- sha256:26063da13c24d9ba482ea65c6d200a03a7942cd35ef9c6a2a304d7fb87734cc8  Shared/Enrichment/EnrichmentCoordinator.swift
- sha256:b9e0c3f515067b3e494ff9cd13affed22ba0d82019e08611ce8c978696d94595  Shared/Enrichment/EnrichmentWriter.swift
- sha256:67d902ae88bf39351973465b5acda426cd090fae3a8f9837a8fe3711cb43d97c  Shared/Enrichment/RecognitionRule.swift
- sha256:7307daf78f81dc766a7f234769560193c472b7e485cd7ae06981ad3db8d6af71  Shared/Services/CatalogService.swift
- sha256:208552d64f79f138613af36a0385bb5301a9fca5f666a4428e6bd1d1436ccfc1  Shared/Services/FieldCodec.swift
- sha256:45bfb701cd7457d866bba02778d472d3f879275f636c75c231ef5547bb917b36  Shared/Services/RawTextWords.swift
- sha256:6b2923d3090dc9e4f0f989059a5eb5df998ad53e25f54aab7044303bc9c07c27  Shared/Services/RevisionService.swift
- sha256:f287d94ff86e1acd63b68d1cb57c54275667afa73c11fd19093e61bee4fa9dbf  docs/artifacts/feat-136-wiedererkennung/test-red-behaviour.txt
- sha256:2ac863b7fd60324208bd091d8154eafcab99bcf797a64253fb83732af1e38ba0  docs/project/02-datenmodell-und-ansichten.md
- sha256:99d8ba2127a98d6bc27d40c497db3d8e20a7290e03a483beca41564f2b020412  docs/project/04-stand.md
- sha256:772ce513ea15d88ec05258881e9657a355e86d4aeb1178dabe913d2eb27c44ff  docs/project/06-annahmen-und-experimente.md

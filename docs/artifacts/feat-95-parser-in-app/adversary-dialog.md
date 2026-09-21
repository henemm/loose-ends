# Adversary-Protokoll - #95 Regelparser in die App

Arbeitsverzeichnis: .claude/worktrees/issue-67-messbericht, HEAD = 71aff8e (TDD-RED-Commit),
alle Implementierungs-Aenderungen liegen unkommittiert (teils staged) im Arbeitsbaum.
Eigene Testlaeufe: sim.sh generate, sim.sh unit (voller Lauf, exit 0, 127 gruene Tests, 0 rote),
sim.sh build (App+Watch+Widgets+Share), xcodebuild LooseEndsLab build,
xcodebuild LooseEndsUITests build-for-testing. Volle Ausgabe: /tmp/adversary_test_output.txt.

### Runde 1 - Checkliste

Checkliste AC-1 bis AC-10 (Kurzform, Details je Punkt weiter unten):

- [x] AC-1 Ein Parser-Stand, keine Typkollision - Shared/Services/DateExpressionParser.swift:6,73, repoweite Suche ohne Treffer in Measurement/, eigener Unit-Lauf kompiliert
- [x] AC-2 "Naechsten Freitag" = Folgewoche - DateExpressionParser.swift:99 inFollowingWeek(...), Test weekdayEitherNext() erwartet 2026-03-20, eigener Testlauf gruen
- [x] AC-3 Regression der uebrigen acht Ausdrucksarten - Suiten "Regelparser: Datum" (15) und "Regelparser: Uhrzeit" (7) eigener Lauf gruen
- [x] AC-4 Alle sieben Build-Ziele kompilieren - sim.sh build, sim.sh unit, xcodebuild LooseEndsLab und LooseEndsUITests build-for-testing, alle selbst ausgefuehrt, alle erfolgreich
- [x] AC-5 DueDateRule kombiniert Datum und Uhrzeit - DueDateRule.swift:24-38, Test combinesDateAndTime() und reasonIsDistinctPerExpressionKind() eigener Lauf gruen
- [x] AC-6 Uhrzeit ohne Datum bleibt leer - DueDateRule.match Zeile 26-28, Test timeWithoutDateYieldsNothing() eigener Lauf gruen
- [x] AC-7 Ohne verfuegbares Modell schreibt die Regel trotzdem das Datum - EnrichmentCoordinator.swift:29-31,48-49, Test ruleWritesDueDateWithoutModel() eigener Lauf gruen
- [x] AC-8 Zweiter Durchgang dupliziert die Regel-Revision nicht - applyRules-Guard auf dueDate == nil, Test catchUpPassDoesNotDuplicateRuleRevision() eigener Lauf gruen
- [x] AC-9 Feldursprung bleibt "ai" - EnrichmentCoordinator.swift:81-82, FieldSource unveraendert (kein neuer Fall), Test confidenceIsAlwaysOne() eigener Lauf gruen
- [x] AC-10 Modellschema schrumpft - EnrichmentParsing.dueDate und die vier ModelEnrichment-Felder repoweit ohne Treffer, Suiten EnrichmentWriter/EnrichmentCoordinator/Korpus-Regelwerk/DateTitleReportTests eigener Lauf gruen
AC-1 Ein Parser-Stand, keine Typkollision
Beweis gefordert: DateExpression/DateExpressionParser/TimeExpressionParser genau einmal im Repo.
Beweis erhalten: repoweite Suche nach den Typnamen -> nur Shared/Services/DateExpressionParser.swift:6,73
und Shared/Services/TimeExpressionParser.swift:9, kein Treffer in Measurement/. ls Measurement/ zeigt
nur noch Corpus.swift, MeasurementRun.swift, date-title-corpus.json, results/. Status zeigt den Move
als "renamed", nicht als add+delete - ein Commit, keine Zwischenstaende. Eigener Unit-Lauf kompiliert
ohne Redeclaration-Fehler.
Bewertung: AKZEPTIERT.

AC-2 "Naechsten Freitag" = Folgewoche
Beweis gefordert: date(in:reference:) loest "Naechsten Freitag..." mit Referenz Do 12.3.2026 auf den
20.3.2026 auf.
Beweis erhalten: Shared/Services/DateExpressionParser.swift:99 case .weekdayEitherNext(let weekday):
return inFollowingWeek(weekday, from: day) (vorher next(..., includingToday: false)). Test
LooseEndsTests/DateExpressionParserTests.swift:79-88, weekdayEitherNext(): erwartet 2026-03-20.
Eigener Testlauf: Suite "Regelparser: Datum" -> Test fuer die Folgewoche gruen.
Bewertung: AKZEPTIERT.

AC-3 Regression der uebrigen acht Ausdrucksarten
Beweis gefordert: alle Faelle fuer die uebrigen Ausdrucksarten und TimeExpressionParserTests bleiben gruen.
Beweis erhalten: eigener Lauf zeigt Suite "Regelparser: Datum" (15 Tests) und "Regelparser: Uhrzeit"
(7 Tests) alle gruen, dazu "Regelparser: Abnahme ueber den Korpus" gruen.
Bewertung: AKZEPTIERT.

AC-4 Alle sieben Build-Ziele kompilieren
Beweis gefordert: App, Watch, Widgets, Share, Lab, Tests, UITests kompilieren.
Beweis erhalten (selbst reproduziert):
- sim.sh generate - ohne Fehler
- sim.sh build -> Target dependency graph (4 targets) LooseEnds+Watch+Widgets+Share, Build Succeeded
- sim.sh unit -> LooseEndsTests, Test Succeeded, 127/127 gruen
- xcodebuild -scheme LooseEndsLab -destination generic/platform=iOS Simulator build -> BUILD SUCCEEDED
- xcodebuild -scheme LooseEnds build-for-testing -only-testing:LooseEndsUITests -> TEST BUILD SUCCEEDED
project.yml unveraendert (leerer Diff) - konsistent mit der Spec-Pruefung, dass Shared/Enrichment/*
Einzelpfade fuer Lab bereits reichen, weil LooseEndsLab/Measurement DateExpressionParser/
TimeExpressionParser/DueDateRule gar nicht referenzieren (Suchtreffer leer).
Bewertung: AKZEPTIERT, alle sieben Ziele selbst gebaut, nicht nur den Artefakten geglaubt.

AC-5 DueDateRule kombiniert Datum und Uhrzeit
Beweis gefordert: "Naechsten Freitag..., um 14 Uhr" -> Freitag Folgewoche 14:00, Konfidenz 1.0,
nicht-leerer lokalisierter Grundsatz.
Beweis erhalten: Shared/Enrichment/DueDateRule.swift:24-38 kombiniert DateExpressionParser und
TimeExpressionParser, setzt confidence = 1.0 fest, liefert reason(for:) je Ausdrucksart (9 Faelle,
Zeile 44-55). Test LooseEndsTests/DueDateRuleTests.swift:22-30 combinesDateAndTime() gruen im
eigenen Lauf. reasonIsDistinctPerExpressionKind() (Zeile 91-110) prueft alle neun Grundsaetze auf
Verschiedenheit und Nicht-Leere - gruen.
Bewertung: AKZEPTIERT.

AC-6 Uhrzeit ohne Datum bleibt leer
Beweis gefordert: "Jeden Tag um 7 Uhr..." -> kein Ergebnis, weder dueDate noch dueHasTime werden
geschrieben.
Beweis erhalten: DueDateRule.match (Zeile 26-28) verlangt zwingend eine erkannte DateExpression,
bevor ueberhaupt eine Uhrzeit gesucht wird - DateExpressionParser.isRepetition blockt "jeden Tag"
bereits auf Ausdrucksebene. Test timeWithoutDateYieldsNothing() (Zeile 61-70) deckt drei
Wiederholungssaetze DE/EN ab, gruen. Weil EnrichmentCoordinator.applyRules bei match == nil gar
nichts schreibt (guard-Ausstieg, Zeile 78-79), schreibt auch EnrichmentWriter nichts - der
Modellpfad liefert wegen des Schemaschrumpfs (AC-10) ohnehin nie mehr einen dueDate-Guess.
Bewertung: AKZEPTIERT.

AC-7 Ohne verfuegbares Modell schreibt die Regel trotzdem das Datum
Beweis gefordert: Enricher mit unavailableReason gesetzt -> Regel schreibt dueDate,
dueSourceRaw == "ai", eine Revision mit author == .ai, processedAt bleibt nil, Enricher nicht
aufgerufen.
Beweis erhalten: EnrichmentCoordinator.swift:29-31 liest unavailableReason, kehrt aber nicht mehr
zurueck - der komplette Durchgang laeuft weiter. applyRules (Zeile 48) laeuft fuer jede Aufgabe vor
dem if modelUnavailable == nil-Block (Zeile 49), der den Enricher-Aufruf klammert. Test
ruleWritesDueDateWithoutModel() (Zeile 226-254): stub.calls == 0, Datum auf 2026-03-20,
dueSourceRaw == FieldSource.ai.rawValue, genau eine Revision mit author == .ai und nicht-leerem
Grund, processedAt == nil. Eigener Lauf: gruen.
Bewertung: AKZEPTIERT.

AC-8 Zweiter Durchgang holt Titel nach, ohne die Regel-Revision zu duplizieren
Beweis gefordert: Enricher genau einmal, Titel + processedAt gesetzt, weiterhin genau eine
dueDate-Revision.
Beweis erhalten: applyRules guardet auf task.dueDate == nil (Zeile 77) - nach dem ersten,
regel-only Durchgang ist dueDate gesetzt, also legt der zweite Durchgang keine zweite Revision an.
Das Modell liefert wegen AC-10 ohnehin nie einen dueDate-Guess, also kann auch
EnrichmentWriter.apply keine zusaetzliche Revision auf dieses Feld schreiben. Test
catchUpPassDoesNotDuplicateRuleRevision() (Zeile 260-288): stub.calls == 1, Titel gesetzt,
processedAt != nil, dueDate unveraendert, genau eine dueDate-Revision. Eigener Lauf: gruen.
Bewertung: AKZEPTIERT.

AC-9 Feldursprung bleibt "ai"
Beweis gefordert: dueSourceRaw == "ai", dueConfidence == 1.0, kein neuer FieldSource-Wert.
Beweis erhalten: EnrichmentCoordinator.swift:81 task.dueSourceRaw = FieldSource.ai.rawValue,
Zeile 82 task.dueConfidence = match.guess.confidence (= 1.0, DueDateRule.confidence). Diff auf
Shared/Models/Enums.swift ist leer - enum FieldSource mit den Faellen ai und user unveraendert.
Test confidenceIsAlwaysOne() deckt vier verschiedene Ausdrucksarten ab.
Bewertung: AKZEPTIERT.

AC-10 Modellschema schrumpft
Beweis gefordert: EnrichmentParsing.dueDate(day:time:) existiert nicht mehr, ModelEnrichment ohne
die vier Felder, vier genannte Suiten bleiben gruen.
Beweis erhalten: repoweite Suche nach EnrichmentParsing.dueDate -> kein Treffer. Suche nach den vier
Feldnamen in FoundationModelsEnricher.swift -> kein Treffer. Eigener Lauf bestaetigt: Suite
"EnrichmentWriter" (3/3), "EnrichmentCoordinator" (6/6), "Korpus-Regelwerk" (10/10),
"DateTitleReportTests" (1/1) - alle gruen.
Bewertung: AKZEPTIERT.

### Runde 2 - Gezielte Nachfragen (Risikoliste)

Doppelte Quelle - bereits unter AC-1 mit repoweiter Suche widerlegt. Kein Fund.

processedAt-Semantik - applyRules (Zeile 76-84) beruehrt task.processedAt an keiner Stelle; der
einzige Schreibzugriff auf processedAt bleibt EnrichmentWriter.apply Zeile 100, das nur nach einem
tatsaechlichen Enricher-Aufruf laeuft. Eine Aufgabe kann also nicht dauerhaft vom Modell
abgeschnitten werden, nur weil die Regel gegriffen hat.

Zweite Revision - applyRules guardet strikt auf task.dueDate == nil (Zeile 77). Eine vom Nutzer
selbst gesetzte Faelligkeit (dueDate != nil, unabhaengig von dueSourceRaw) blockt die Regel genauso
wie ein bereits von der Regel gesetztes Datum - der Guard prueft nur den Wert, nicht die Quelle, was
fuer den Schutzzweck ausreicht. Kein expliziter Test fuer den Nutzer-gesetzt-Fall, aber durch
Code-Lesen zweifelsfrei belegt.

Plattform - Shared/Enrichment/DueDateRule.swift importiert nur Foundation, keine
canImport(FoundationModels)-Klammer. project.yml nimmt LooseEndsWatch/LooseEndsWidgets den
kompletten Shared-Ordner in die sources. Eigener sim.sh build baut Watch, Widgets und Share
zusammen mit der App erfolgreich - bewiesen, nicht nur behauptet.

Speichern (Finding F001, siehe unten) - echter Befund, kein Fehlalarm: das Verhalten hat sich
gegenueber dem Ausgangsstand verschlechtert.

Bestehendes Verhalten (unavailableModelIsSkipped) - Test bleibt gruen (eigener Lauf bestaetigt,
stub.calls == 0), weil die Testaufgabe "Irgendwas" keinen Datumsausdruck enthaelt und
DueDateRule.match dafuer nil liefert. Der Test bleibt technisch wahr, ist aber nach der Aenderung
kein vollstaendiger Beweis mehr fuer "das Modell wird bei fehlender Verfuegbarkeit gar nicht erst
befragt" im Sinne des ganzen Durchgangs - das leistet jetzt erst ruleWritesDueDateWithoutModel()
(AC-7). Keine Diskrepanz zur Spec, nur eine Beobachtung.

## Finding F001

Finding:
  ID: F001
  Severity: HIGH
  Category: regression
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:48-65
  Description: In der for-Schleife ueber pending liegt try context.save() (Zeile 65) jetzt
    AUSSERHALB des per-Task do/catch, das den Enricher-Aufruf umschliesst (Zeilen 50-63). Vor der
    Aenderung lag try context.save() INNERHALB dieses do/catch: ein Speicherfehler fuer Aufgabe A
    wurde dort abgefangen, geloggt, und die Schleife lief mit Aufgabe B weiter. Jetzt wirft ein
    Speicherfehler fuer Aufgabe A durch den aeusseren do/catch (Zeile 68-70, Enrichment pass
    failed) und beendet die gesamte for-Schleife - alle noch ausstehenden Aufgaben dieses
    Durchgangs (B, C, D, ...) werden in diesem Durchlauf gar nicht mehr angefasst, weder von der
    Regel noch vom Modell.
  Spec requirement: kein AC nennt diesen Fall explizit, aber der Pruefauftrag selbst listet ihn als
    Risiko (bricht ein Speicherfehler jetzt den ganzen Durchgang ab, wo vorher nur eine Aufgabe
    uebersprungen wurde), und die Projektregeln fordern keine Seiteneffekte ausserhalb des Tickets -
    die robustere Fehlerisolation pro Aufgabe war unveraendertes Bestandsverhalten, nicht Teil des
    Schnitt-2b-Auftrags (Naht Regel/Modell), und wird durch den Umbau stillschweigend geaendert.
  Conflict: Der Klassendoc-Kommentar (Zeile 6, sinngemaess: ein Fehler laesst die Aufgabe fuer den
    naechsten Durchgang unverarbeitet, nichts wird still verschluckt) beschreibt Verhalten pro
    Aufgabe; mit dem Umbau gilt er de facto nur noch fuer die erste fehlschlagende Aufgabe eines
    Durchgangs, alle folgenden werden durch denselben Fehler ebenfalls unprocessed - nicht weil sie
    fehlschlugen, sondern weil sie gar nicht erst versucht wurden. Kein Test deckt einen
    Speicherfehler bei mehreren ausstehenden Aufgaben ab (weder vorher noch nachher), die
    Verhaltensaenderung ist daher unbemerkt und unbewiesen.
  Remediation: try context.save() zurueck in das per-Task do/catch verschieben (oder ein eigenes
    do/catch nur um das Save legen), damit ein Speicherfehler weiterhin nur die betroffene Aufgabe
    ueberspringt und die Schleife mit der naechsten Aufgabe fortfaehrt.

## Verdict Runde 1 (ueberholt, siehe Runde 3): BROKEN wegen F001, seither behoben

Alle zehn Acceptance Criteria sind durch eigene Testlaeufe und Code-Referenzen bewiesen (AC-1 bis
AC-10: AKZEPTIERT). Ein struktureller Befund ausserhalb der nummerierten Checkliste, aber innerhalb
des vom Auftrag selbst benannten Risikokatalogs: F001, Speicherfehler-Isolation pro Aufgabe ist
durch den Koordinator-Umbau verloren gegangen, ungetestet und nicht in der Spec verhandelt.

---

### Runde 3 - Nachpruefung des F001-Fixes

Auftrag: nur Shared/Enrichment/EnrichmentCoordinator.swift geaendert, kein Commit, alles im
Arbeitsbaum. Eigene Pruefung, nicht der Zusammenfassung vertraut.

## 1. Ist die Isolation wirklich wiederhergestellt?

Aktueller Code (selbst gelesen, Shared/Enrichment/EnrichmentCoordinator.swift:60-67):
das nackte try context.save() liegt jetzt in einem eigenen do/catch, das nur
logger.error("Saving failed for ...") aufruft, keinen Fehler weiterwirft. Dieses do/catch ist ein
Geschwister-Statement zum if modelUnavailable == nil-Block, beide innerhalb des for task in
pending-Rumpfs. Ein Fehler beim Speichern von Aufgabe A wird also lokal abgefangen; die
for-Schleife laeuft mit Aufgabe B weiter, ohne dass der aeussere pass-level catch (Zeile 70-72)
ausgeloest wird.
Bewertung: AKZEPTIERT - Isolation ist wiederhergestellt.

## 2. Sind alle drei Speicherfaelle noch abgedeckt?

Der try context.save()-Aufruf liegt nach dem schliessenden } des if modelUnavailable == nil-Blocks,
unbedingt und pro Iteration genau einmal, unabhaengig davon, was im if-Block passiert ist:

- Nur Regel (Modell nicht verfuegbar): if-Block wird uebersprungen, save() laeuft trotzdem -
  die applyRules-Mutation wird persistiert.
- Regel + Modell erfolgreich: EnrichmentWriter.apply mutiert die Aufgabe inklusive processedAt,
  danach laeuft save() - beides wird persistiert.
- Regel + gescheiterter Modellaufruf: der innere catch (Zeile 55-56) faengt den Fehler von
  enricher.enrich ab und loggt "Enrichment failed", aber die Aufgabe bleibt mit der
  Regel-Mutation aus applyRules im Speicher; save() laeuft danach trotzdem und persistiert
  genau diese Regel-Mutation, obwohl das Modell fehlschlug.
Bewertung: AKZEPTIERT - alle drei Faelle bleiben abgedeckt, exakt der Zustand, fuer den save()
urspruenglich (in #95 Schnitt 2b) nach aussen gewandert war.

## 3. Was faengt der aeussere catch jetzt noch?

Der aeussere do/catch (Zeile 33-72) umschliesst weiterhin vier eigenstaendige fetch-Aufrufe vor
der Schleife: pending (TaskItem), contexts (TaskContext), projects (Project) und examples
(Self.examples(in:), selbst ein throws-Aufruf). Diese laufen unbedingt, auch wenn das Modell nicht
verfuegbar ist (nur examples wird bei modelUnavailable != nil durch [] ersetzt, ohne fetch).
Schlaegt einer dieser vier fehl, kann der Durchgang ohnehin nichts Sinnvolles tun - ein
berechtigter Grund, den ganzen Durchgang abzubrechen. applyRules(to:) ist keine throwing function
(Signatur: private func applyRules(to task: TaskItem), kein throws), kann den aeusseren catch also
nicht mehr ausloesen. Der aeussere catch ist nicht tot, sondern auf die vier Vorab-Abfragen
reduziert - genau dort, wo ein Abbruch des ganzen Durchgangs weiterhin angemessen bleibt.
Bewertung: AKZEPTIERT.

## 4. Traegt der Klassenkommentar jetzt wirklich?

Vorher (Runde 1, defekter Zustand): "A failure leaves the task unprocessed for the next pass;
nothing is swallowed silently" - stimmte fuer einen Enrich-Fehler, nicht mehr fuer einen
Save-Fehler (der brach den ganzen Durchgang ab statt nur die eine Aufgabe zu ueberspringen).
Jetzt (Shared/Enrichment/EnrichmentCoordinator.swift:5-7): "A failure - model call or save -
stays with that one task, leaves it unprocessed for the next pass and does not stop the pass;
nothing is swallowed silently." Das deckt sich mit dem tatsaechlichen Code: beide Fehlerquellen
(enrich, save) sind jetzt pro Aufgabe abgefangen und geloggt, keine bricht die Schleife ab.
Bewertung: AKZEPTIERT - der Kommentar beschreibt wieder den echten Code, nicht mehr nur einen Teil
davon.

## 5. Volle Suite selbst laufen lassen

sim.sh generate - ohne Fehler.
sim.sh unit (voller Lauf, eigene Ausgabe in /tmp/adversary_test_output_round2.txt) - Ergebnis:
127 gruene Haken (Zaehlung ueber die Ausgabe), 0 rote Kreuze, kein Treffer fuer "skip" im gesamten
Protokoll, "Test Succeeded", "Unit-Tests bestanden.", Exit 0.

Das weicht von der im Auftrag genannten Erwartung ab: dort wurden 128 bestanden, 0 fehlgeschlagen,
1 uebersprungen erwartet. Ich finde 127 bestanden, 0 fehlgeschlagen, 0 uebersprungen - identisch
zu Runde 1 (dieselben Suiten, dieselben Testnamen, nur andere Laufzeiten und Ausfuehrungsreihenfolge).
Das deckt sich mit dem eigenen Beleg des Entwicklers
(docs/artifacts/feat-95-parser-in-app/test-green-f001.txt: ebenfalls 127 Haken, 0 Kreuze, kein
"skip"-Treffer) und mit dem Umstand, dass LooseEndsTests/EnrichmentTests.swift gegenueber Runde 1
unveraendert ist (Aenderungsvergleich zur vorherigen Pruefung identisch) - es kam kein neuer Test
hinzu, also kann auch kein 128. oder uebersprungener Test entstanden sein. Die im Auftrag genannte
Erwartung (128/0/1) ist damit durch die eigene Testausfuehrung wie auch durch den eigenen Beleg des
Entwicklers widerlegt. Das ist kein Code-Defekt, sondern eine falsche Angabe in der an mich
gerichteten Aufgabenbeschreibung - hier ausdruecklich festgehalten, weil genau das Nicht-Vertrauen
in Beschreibungen der Auftrag dieser Runde war.
Bewertung: Testsuite selbst bleibt gruen (127/0/0), AC-1 bis AC-10 unveraendert bewiesen. Die
genannte Erwartung (128/0/1) ist falsch.

## 6. Begruendung fuer die fehlende Testabdeckung

Behauptung des Entwicklers: EnrichmentCoordinator nehme einen konkreten ModelContainer ohne
Injektionspunkt, und das In-Memory-Schema habe weder unique-Attribute noch Validierungsregeln -
es gebe nichts, woran save() scheitern koennte, ohne eine neue Abstraktion in den Produktionscode
zu ziehen.

Geprueft: Shared/Models/*.swift enthalten keine Attribute mit Eindeutigkeits-Zwang, nur
Relationship-Deklarationen (Project.swift:12, TaskItem.swift:71-76, TaskContext.swift:11) - keine
davon erzwingt eine Validierung, die save() in einem In-Memory-Store deterministisch scheitern
liesse. Dieser Teil der Begruendung ist korrekt.

Der zweite Teil ("ohne Injektionspunkt") ist so nicht richtig: Shared/Enrichment/
EnrichmentCoordinator.swift Zeile 17-20 zeigt init(enricher: any TaskEnricher, container:
ModelContainer) - der Coordinator nimmt bereits jeden beliebigen ModelContainer entgegen, das IST
der Injektionspunkt, und LooseEndsTests/EnrichmentTests.swift nutzt ihn schon heute (TestStore,
Zeile 30-38) fuer einen In-Memory-Container ueber ModelContainerFactory.make(inMemory: true).

Ein konkreter Weg ohne neue Produktionsabstraktion: ModelContainerFactory.make() erzwingt einen
In-Memory-Store, sobald der Prozess unter XCTest laeuft (isRunningTests prueft
XCTestConfigurationFilePath, Shared/Persistence/ModelContainerFactory.swift Zeile 19-21, 46) -
das gilt unabhaengig vom inMemory-Parameter fuer jeden Unit-Test. Ein Test kann diese Fabrik
umgehen und direkt einen eigenen ModelContainer bauen: eine ModelConfiguration mit einer echten
Datei-URL in einem temporaeren Verzeichnis (Standard-SwiftData-API, kein neuer Produktionscode),
zwei ausstehende Aufgaben einfuegen und einmal sichern, damit die Datei existiert, dann die
Schreibrechte der Datei entziehen (FileManager.setAttributes mit posixPermissions 0o444) und
processPending() aufrufen. Das erste save() in der Schleife scheitert an der schreibgeschuetzten
Datei; der Test kann anschliessend am selben Kontext (derselbe context, den der Coordinator schon
benutzt hat) pruefen, dass applyRules fuer die zweite Aufgabe trotzdem gelaufen ist (dueDate im
Speicherobjekt gesetzt, ohne dass gespeichert werden musste) und dass der Enricher fuer beide
Aufgaben aufgerufen wurde (stub.calls == 2) - der Beweis fuer Weiterlaufen braucht keinen
erfolgreichen Save, nur den Zustand der bereits im Kontext lebenden Objekte.

Bewertung: teilweise widerlegt. Die Aussage "keine Validierungsregel im Schema" ist richtig; die
Aussage "kein Injektionspunkt, daher unmoeglich ohne neue Produktionsabstraktion" ist falsch - ein
Test ist mit vorhandenen Mitteln (Konstruktor-Parameter, Standard-SwiftData-API, Dateisystem-Trick
im Testcode) machbar. Das ist kein Beleg dafuer, dass der Produktionsfix falsch ist - er ist durch
eigenes Code-Lesen bereits bewiesen (Punkte 1-4) - aber die Begruendung fuer den bewusst
ausgelassenen Test haelt nicht vollstaendig.

## Finding F002

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:17-20 (init), Shared/Persistence/ModelContainerFactory.swift:19-21,44-46
  Description: die Begruendung fuer den ausgelassenen Test zu F001 nennt als Haupthindernis einen
    fehlenden Injektionspunkt. Der Coordinator nimmt aber bereits jeden ModelContainer im
    Konstruktor entgegen; ein file-basierter Container mit entzogenen Schreibrechten wuerde einen
    deterministischen save()-Fehlschlag erzeugen, ganz ohne neuen Produktionscode.
  Spec requirement: keine AC verlangt diesen Test explizit; das ist eine Beobachtung zur
    Testabdeckung, kein Verstoss gegen die Spec.
  Conflict: die im Auftrag gegebene Begruendung fuer die fehlende Abdeckung ist nur zur Haelfte
    zutreffend (Schema ohne Validierungsregeln: richtig; kein Injektionspunkt: falsch) und sollte
    nicht unwidersprochen als abschliessende Rechtfertigung stehen bleiben.
  Remediation: optional - ein Test wie oben unter Punkt 6 skizziert wuerde F001 dauerhaft gegen
    Regressionen absichern. Kein Muss fuer dieses Ticket, da der Fix bereits durch Code-Lesen
    bewiesen ist.

## Verdict Runde 3 (Zwischenstand, siehe Schlusszeile unten): VERIFIED

Der F001-Fix haelt der Nachpruefung stand: Isolation pro Aufgabe ist wiederhergestellt (Punkt 1),
alle drei Speicherfaelle bleiben abgedeckt (Punkt 2), der aeussere catch bleibt sinnvoll auf die
vier Vorab-Abfragen begrenzt (Punkt 3), der Klassenkommentar beschreibt wieder den echten Code
(Punkt 4). Die volle Suite bleibt gruen, 127 bestanden, 0 fehlgeschlagen, 0 uebersprungen, Exit 0,
identisch zu Runde 1 - AC-1 bis AC-10 sind unveraendert bewiesen (Punkt 5). Die im Auftrag genannte
Erwartung 128/0/1 ist durch die eigene Ausfuehrung und den eigenen Beleg des Entwicklers widerlegt,
aber kein Code-Defekt. F002 (MEDIUM) haelt fest, dass die Begruendung fuer den ausgelassenen Test
nur teilweise zutrifft, aendert aber nichts an der Korrektheit des Fixes selbst.

---

VERDICT: VERIFIED

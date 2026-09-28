# Adversary Dialog -- fix-144-recognition-pool-empty

Massstab: docs/specs/enrichment/fix-144-recognition-pool-empty.md. Arbeitsverzeichnis:
/Users/hem/Developer/loose-ends/.claude/worktrees/piped-wiggling-boole.

### Runde 1

Produktivcode-Diff gegen HEAD gelesen (Shared/Enrichment/EnrichmentCoordinator.swift,
Shared/Models/TaskItem.swift, beide staged, unkommittiert), RED-Commits (50fcb8c, be53c43) und
vorgelegte Artefakte geprueft: test-red-output.txt, test-red-verhalten.txt, test-red-simulator.txt,
test-green-output.txt, test-green-mit-korpus.txt, test-green-simulator.txt, korpus-messung.md,
screenshots/. Eigene SHA-256-Pruefsummen von TaskItem.swift, EnrichmentCoordinator.swift und
RecognitionRule.swift gegen die in korpus-messung.md behaupteten Pruefsummen verglichen: identisch
-- die Belegdatei bezieht sich auf exakt den aktuellen Arbeitsstand, nicht auf einen veralteten. Kein
eigener zwoelf-Minuten-Testlauf noetig, weil die vorgelegten Artefakte durch Pruefsummen-Abgleich,
Zeilen-Diff und Commit-Historie unabhaengig verifizierbar waren.

- [x] AC-1: recognitionWorksWithoutTheModel (EnrichmentTests.swift:696-726) laeuft ohne Modell
  zweimal durch processPending(), second.duration == .minutes30 und
  second.contexts.map(name) == ["Garten"]. RED bei 302b453 (test-red-verhalten.txt Zeile 16-17,
  Expectation failed), GREEN im vorgelegten Lauf (test-green-output.txt Zeile 331). Testkoerper
  zwischen RED-Commit be53c43 und Arbeitsstand unveraendert (Zeilen-Diff liefert keine Ausgabe).
  Code reference: LooseEndsTests/EnrichmentTests.swift:696
- [x] AC-2: ruleMarkerFillsThePoolWithoutTheModel (EnrichmentTests.swift:731-748) belegt
  rulesAppliedAt != nil fuer alle drei frischen Aufgaben und processedAt == nil fuer dieselben drei.
  RED-Fehlschlag bei 302b453 (test-red-verhalten.txt Zeile 19, pool.count == 3 schlaegt fehl, weil
  rulesAppliedAt noch nicht existiert), GREEN in test-green-output.txt Zeile 332.
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:52
- [x] AC-3: ruleMarkerSurvivesAFailingModelCall (EnrichmentTests.swift:756-770) mit einem
  StubEnricher(failure:): task.processedAt == nil, task.rulesAppliedAt != nil nach einem werfenden
  enrich(_:). Greift, weil task.rulesAppliedAt = Date() (Zeile 52) vor dem
  if modelUnavailable == nil Block und ausserhalb von dessen do/catch (Zeile 53-68) steht -- ein
  Wurf im catch-Zweig (Zeile 65-67) kann den bereits gesetzten Vermerk nicht mehr zuruecknehmen.
  Gruen in test-green-output.txt Zeile 333.
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:61
- [x] AC-4: legacyProcessedTaskStaysReachable (EnrichmentTests.swift:776-802) legt eine Aufgabe mit
  processedAt != nil, rulesAppliedAt == nil an; eine wortgleiche frische Aufgabe uebernimmt
  duration == .hour1 und contexts == ["Garten"]. Traegt, weil recognitionInputs ueber den
  byModel-Fetch (processedAt != nil) UND den byRules-Fetch (rulesAppliedAt != nil) zusammenfuehrt.
  Gruen in test-green-output.txt Zeile 334.
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:168
- [x] AC-5: aTaskWithBothMarkersAppearsOnceInThePool (EnrichmentTests.swift:809-838) prueft direkt an
  EnrichmentCoordinator.recognitionInputs(in:): inputs.pool gefiltert auf die ID liefert genau 1
  Treffer, inputs.tasksByID.count == 1, dazu end-to-end genau eine .duration-Revision auf einer
  dritten, wortgleichen Aufgabe. Dictionary(uniquingKeysWith: erster gewinnt) entdoppelt nach id.
  Gruen in test-green-output.txt Zeile 335.
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:170
- [x] AC-6: ruleMarkerDoesNotHideATaskFromTheModelPass (EnrichmentTests.swift:846-869): erster
  Durchgang ohne Modell setzt rulesAppliedAt, processedAt bleibt leer; zweiter Durchgang mit jetzt
  verfuegbarem Modell (stub.calls == 1 beim zweiten Aufruf) liefert title/energy und setzt
  processedAt. Der Pending-Fetch (Zeile 38) filtert weiterhin nur auf
  processedAt == nil && statusRaw == unprocessed -- kein rulesAppliedAt-Ausschluss. Gruen in
  test-green-output.txt Zeile 336.
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:38
- [x] AC-7: repeatedRulePassesAddNoSecondRevision (EnrichmentTests.swift:876-908): drei
  aufeinanderfolgende processPending()-Durchgaenge ohne Modell, am Ende genau eine .duration- und
  eine .contexts-Revision auf der Zielaufgabe. Traegt durch die Guards task.duration == nil
  (Zeile 199) und (task.contexts ?? []).isEmpty (Zeile 216) in applyRecognitionRule -- ein
  Selbsttreffer im zweiten/dritten Durchgang ist wirkungslos, weil das Feld beim ersten Durchgang
  bereits gesetzt wurde. Gruen in test-green-output.txt Zeile 337.
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:199
- [x] AC-8: Die fuenf woertlich benannten Zusagen stehen exakt an den genannten Zeilen und sind seit
  be53c43 unveraendert (Zeilen-Diff liefert keine Ausgabe): Zeile 255 task.processedAt == nil
  (Titel und Wichtigkeit stehen noch aus), Zeile 286 task.processedAt != nil (jetzt hat das Modell
  die Aufgabe gesehen), Zeile 570/636/670 je fresh.processedAt == nil. Alle in test-green-output.txt
  gruen (u. a. Zeilen 308, 320, 321).
  Code reference: LooseEndsTests/EnrichmentTests.swift:255
- [x] AC-9: UI-Test testWordEqualRecaptureTakesOverDurationAndContext
  (RecognitionWalkthroughTests.swift:105-153) durchlaeuft erfassen, Dauer/Kontext von Hand setzen,
  wortgleich erneut erfassen (maehen Rasen vs. Rasen maehen), die zweite Aufgabe zeigt 30 min und
  Garden. RED bei 302b453 (test-red-simulator.txt Zeile 16, Dauer der ersten Aufgabe wurde nicht
  uebernommen), GREEN in test-green-simulator.txt Zeile 23 (Executed 1 test, with 0 failures,
  54.887s). Screenshot 4 (screenshots/4-zweite-aufgabe-mit-uebernommenen-werten.png) zeigt
  "Duration 30 min" und "Contexts Garden" mit KI-Sternchen auf der zweiten Aufgabe. Vorlaeufig
  bestaetigt -- siehe Runde 2 fuer den Abgleich mit AC-10, der den Gesamtbefund beeinflusst.
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:105
- [x] AC-10: korpus-messung.md weist 225 (ohne Korpus) gegen 229 (mit Korpus) Einzeltests aus, mit
  Zeitstempeln und Pruefsummen des gemessenen Codes (selbst nachgerechnet, identisch). Die Datei
  benennt aber selbst einen Widerspruch zur Spec: von den vier in AC-10 genannten Suiten
  (RecognitionRuleCorpusTests, RuleLeaveOneOutTests, FocusBloxCalibrationTests,
  SelfConsistencyReportTests) liefen nur zwei tatsaechlich zusaetzlich mit Korpus
  (RecognitionRuleCorpusTests, FocusBloxCalibrationTests). Wird in Runde 2 vertieft.
  Code reference: LooseEndsTests/RecognitionRuleTests.swift:255

Erste Runde: 8 von 10 AC klar bewiesen. AC-9 vorlaeufig bestaetigt, AC-10 zeigt eine vom
Implementierer selbst gemeldete Abweichung, die noch nicht bewertet ist. Genuegt nicht als Freigabe
-- Runde 2 prueft AC-10 im Detail, den zweiten gemeldeten Befund (ueberschriebene Messberichte), das
RED/GREEN-Identitaetsversprechen (Risiko 4) und den Umfang gegen die Spec-Schaetzung.

### Runde 2

AC-10 vertieft, eigene Nachpruefung des gemeldeten Befunds a) -- Code selbst gelesen, nicht nur die
Behauptung der Belegdatei uebernommen:

FocusBloxCalibrationTests.swift:23 gattert auf focusBloxCorpusURL.
RecognitionRuleTests.swift:255 gattert auf recognitionCorpusURL.
RuleLeaveOneOutTests.swift:58 (struct RuleLeaveOneOutTests) traegt KEIN enabled(if:) -- laeuft immer.
RuleLeaveOneOutTests.swift:197-198 (struct RuleLeaveOneOutReportTests) ist die tatsaechlich
gegatterte Suite.
SelfConsistencyReportTests.swift:18 definiert selfConsistencyRunURL als
docs/reference/selfconsistency-run.json.
SelfConsistencyReportTests.swift:21-23 gattert auf ZWEI Dateien zugleich (Korpus-Wahrheit UND diese
zweite Datei).

Bestaetigt: RuleLeaveOneOutTests (der Name in AC-10) ist die immer laufende Logik-Suite, nicht
gegattert -- die gegatterte Suite heisst RuleLeaveOneOutReportTests und lief tatsaechlich mit Korpus
(test-green-mit-korpus.txt Zeile 296-298). SelfConsistencyReportTests haengt an einer zweiten Datei,
die weder im Arbeitsstand noch im Hauptordner existiert -- sie entsteht laut Quellcode-Kommentar nur
aus einem Geraetelauf (Spike #108). Diese Suite kann mit keinem Codestand aus diesem Ticket zum
Laufen gebracht werden, weil #144 weder RuleLeaveOneOutTests.swift noch
SelfConsistencyReportTests.swift aendert (bestaetigt ueber die Liste der geaenderten Dateien: nur
EnrichmentTests.swift auf der Testseite) und die fehlende zweite Datei ausserhalb der
Spec-Affected-Files liegt.

Bewertung: AC-10, woertlich gelesen (die vier korpusgegatterten Suiten werden ausgefuehrt statt
uebersprungen), ist NICHT erfuellt -- zwei der vier genannten Namen sind falsch beziehungsweise
strukturell unerfuellbar, unabhaengig davon, was #144 am Produktivcode aendert. Das ist ein Fehler in
der Spec-Formulierung selbst, nicht im Produktivcode: die fuer #144 tatsaechlich einschlaegige
Messstrecke (RecognitionRuleCorpusTests, direkt gegen RecognitionRule -- die von #144 nicht
angefasste Datei, Pruefsumme oben bestaetigt unveraendert) lief nachweislich mit Korpus und lieferte
die erwarteten Zahlen (61 von 61, 169 von 169, entdupliziert 0 von 0 -- hartkodierte Erwartungen im
Testcode, ein gruener Lauf ist zugleich der Nachweis der Unveraenderlichkeit). Trotzdem: eine AC, die
im DoD explizit zur Freigabebedingung gemacht wird, kann nicht durch eigene Auslegung des Pruefers zu
erfuellt umgedeutet werden, wenn ihr Wortlaut zwei von vier genannten Bedingungen nicht abdeckt. Das
ist ein AMBIGUOUS-Fall, kein VERIFIED: Henning muss entscheiden, ob AC-10 inhaltlich als erfuellt gilt
und die Spec entsprechend korrigiert wird, oder ob der Wortlaut bindend bleibt und damit offen ist.

Finding F001:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: docs/specs/enrichment/fix-144-recognition-pool-empty.md:297 (AC-10) und
    LooseEndsTests/RuleLeaveOneOutTests.swift:58,197-198 sowie
    LooseEndsTests/SelfConsistencyReportTests.swift:18-23
  Description: AC-10 nennt vier korpusgegatterte Suiten. RuleLeaveOneOutTests ist keine gegatterte
    Suite (laeuft immer, ungegattert) -- die tatsaechlich gegatterte Suite heisst
    RuleLeaveOneOutReportTests. SelfConsistencyReportTests ist zusaetzlich an
    docs/reference/selfconsistency-run.json gegattert, eine Datei, die nirgends im Projekt existiert
    und nur durch einen Geraetelauf (Spike #108) entsteht -- diese Suite kann durch keinen im Rahmen
    von #144 moeglichen Schritt zum Laufen gebracht werden.
  Spec requirement: AC-10 verlangt woertlich, dass die vier korpusgegatterten Suiten ausgefuehrt
    statt uebersprungen werden.
  Conflict: Nur zwei von vier genannten Suiten liefen tatsaechlich zusaetzlich im Korpus-Lauf
    (test-green-mit-korpus.txt gegen test-green-output.txt, Differenz plus vier Einzeltests, plus
    drei Suiten: FocusBloxCalibrationTests, RecognitionRuleCorpusTests,
    RuleLeaveOneOutReportTests). Der vierte in der AC genannte Suitenname existiert unter diesem
    Namen nicht als gegatterte Suite, der dritte ist strukturell nie erfuellbar ohne einen ausserhalb
    dieses Tickets liegenden Schritt.
  Remediation: AC-10 in der Spec auf die tatsaechlichen Suitennamen korrigieren
    (RuleLeaveOneOutReportTests statt RuleLeaveOneOutTests) und SelfConsistencyReportTests entweder
    aus der AC entfernen (sie misst Modell-Selbstkonsistenz, nicht Wiedererkennung) oder als
    strukturell nicht pruefbar ohne Geraetelauf explizit vermerken, statt sie als ausfuehrbare
    Bedingung zu listen.

Zweiter gemeldeter Befund b), ueberschriebene Messberichte tatsaechlich zurueckgesetzt: eigenstaendig
geprueft, nicht nur die Selbstauskunft der Belegdatei uebernommen. Der Arbeitsbaum zeigt keine
Aenderung unter docs/reference/ (weder als unstaged- noch als staged-Aenderung gegen main), alle drei
vom Lauf ueberschriebenen Berichte (date-title-fidelity.md, focusblox-calibration-report.md,
retrieval-leave-one-out-rules.md) stehen exakt auf dem Stand des Repositories -- bestaetigt durch
Ausbleiben jeder Diff-Zeile, nicht durch eine Behauptung in korpus-messung.md. Kein Rest der vom
Simulator-Lauf entwerteten focusblox-calibration-report.md (Nullen, nan Prozent) ist in der Aenderung
enthalten. Befund b) ist damit sauber geloest, kein Finding.

RED/GREEN-Identitaet (Risiko 4): der Zeilen-Diff zwischen dem RED-Commit be53c43 und dem
Arbeitsstand liefert fuer EnrichmentTests.swift und RecognitionWalkthroughTests.swift keine Ausgabe
-- kein Testkoerper wurde nach dem RED-Commit veraendert, um ihn zum Bestehen zu zwingen. Die
einzige Praedikat-Aenderung (processedAt zu rulesAppliedAt in ruleMarkerFillsThePoolWithoutTheModel)
geschah bereits im RED-Commit be53c43 selbst -- davor, im vorherigen Commit 50fcb8c, stand noch das
alte Praedikat unter dem alten Namen poolNeverFillsWithoutTheModel. Der Test kompilierte danach nicht
mehr (rulesAppliedAt existierte noch nicht, test-red-output.txt Zeile 13-19) -- das ist echtes RED,
keine nachtraegliche Absenkung. Die numerische Aussage (pool.count == 3) ist in beiden Staenden
identisch. Risiko 4 damit eingehalten.

Umfang gegen Spec-Schaetzung: Produktivcode plus 21 minus 9 (EnrichmentCoordinator.swift) und plus 3
minus 0 (TaskItem.swift) macht 33 geaenderte Zeilen, Spec-Schaetzung plus 25 minus 8 macht ebenfalls
33 -- exakt getroffen. Dateien: sechs betroffene (zwei Produktivcode, zwei Test/UI-Test, zwei Doku)
wie in der Spec aufgelistet, keine zusaetzliche Datei ausserhalb der Spec-Tabelle angefasst. Tests:
plus 172 minus 5 (EnrichmentTests.swift) plus 159 (neue Datei RecognitionWalkthroughTests.swift)
macht 331 geaenderte Zeilen gegen die Spec-Schaetzung von plus 120 -- etwa das Dreifache der
Schaetzung. Kein Scope-Verstoss (jede neue Zeile gehoert zu einem der sieben in der Spec selbst
benannten Testfaelle, keine themenfremde Datei), aber die Spec-Schaetzung selbst war zu knapp
bemessen (die neue UI-Test-Datei mit 159 Zeilen wurde in der Zeilenschaetzung schlicht vergessen).
Kein Finding gegen die Umsetzung, aber ein Hinweis fuer kuenftige Schaetzungen.

Zweite Runde bestaetigt: AC-1 bis AC-8 stehen fest, AC-9 ist durch Screenshot und Testlauf bewiesen.
AC-10 haelt im Wortlaut nicht -- F001 ist ein echter, vom Implementierer selbst redlich gemeldeter
und hier unabhaengig bestaetigter Befund. Er betrifft die Spec-Formulierung, nicht den geaenderten
Produktivcode (RecognitionRule.swift ist per Pruefsumme nachweislich unangetastet), aber die DoD
macht AC-10 explizit zur Freigabebedingung -- eine Umdeutung durch den Pruefer waere genau die
Nachsicht, die hier ausdruecklich nicht gewuenscht ist.

## VERDICT: AMBIGUOUS

Ambiguous findings (require human review):
  F001: AC-10 nennt zwei Suitennamen, die entweder falsch (RuleLeaveOneOutTests statt
  RuleLeaveOneOutReportTests) oder strukturell unerfuellbar sind (SelfConsistencyReportTests, fehlende
  zweite Datei ausserhalb dieses Tickets) -- wortgetreu ist AC-10 damit nicht erfuellt, inhaltlich
  (die fuer #144 einschlaegige Suite RecognitionRuleCorpusTests lief echt und zeigt unveraenderte
  Zahlen) schon. Henning muss entscheiden, ob AC-10 inhaltlich als erfuellt gilt und die Spec
  entsprechend korrigiert wird, oder ob der Wortlaut bindend bleibt.

Proven points: 9/10 (AC-1 bis AC-9 CONFIRMED, AC-10 AMBIGUOUS)
Tests: 225 gruen ohne Korpus, 229 gruen mit Korpus, 0 fehlgeschlagen (test-green-output.txt,
test-green-mit-korpus.txt, test-green-simulator.txt) -- eigene Pruefsummen-Verifikation bestaetigt
Aktualitaet der Artefakte gegen den aktuellen Arbeitsstand.
Regressions: keine gefunden -- AC-8 (fuenf woertlich benannte Bestandszusagen) unveraendert gruen,
RecognitionRule.swift nachweislich unangetastet (Pruefsumme), keine anderen Aufrufer von
processedAt/rulesAppliedAt betroffen (Volltextsuche ueber Shared/ und die App-Ziele, keine weiteren
Fundstellen).
Recommendation: F001 vor dem Zusammenfuehren entweder per workflow.py override-ambiguous mit
Begruendung freigeben (Empfehlung: ja, weil die einschlaegige Messstrecke echt gelaufen ist und die
beiden problematischen Suitennamen ausserhalb des Aenderungsumfangs von #144 liegen) oder AC-10 in
der Spec zuerst korrigieren und den Adversary-Lauf wiederholen.

## Geprüfte Dateien

- sha256:39de30ee8b3c476916c2bba27eda20b9fe32f10b8e5f87b1884c2b7dc9cf3aba  LooseEndsTests/EnrichmentTests.swift
- sha256:cb8df88035110c062fa8a2727f4bae451a305dcaf6e08ff32c398c09b227e3aa  LooseEndsTests/RecognitionRuleTests.swift
- sha256:80d82d9adb2a11727056cd52c5dd60d4357c39f281bf61f4b9d2afc84784fa6b  LooseEndsUITests/RecognitionWalkthroughTests.swift
- sha256:9df2d1f42664652dd89c01feb38c7152e04c0745e8f897260edf34f47e7b3baf  Shared/Enrichment/EnrichmentCoordinator.swift
- sha256:b97354d72f3150775537247e047ee316d58aeb507a073fc82fd360f7a8838280  docs/specs/enrichment/fix-144-recognition-pool-empty.md

### Runde 3

Kontext: Runde 2 endete AMBIGUOUS mit genau F001 (AC-10 nennt vier korpusgegatterte Suiten, zwei
Namen falsch/strukturell nie lauffaehig). Henning hat NICHT uebersteuert, sondern die Spec
korrigiert. Diese Runde prueft mit Misstrauen, ob die Korrektur eine Richtigstellung oder eine
heimliche Abschwaechung ist -- unabhaengig nachgerechnet, nicht die Selbstauskunft der Spec
uebernommen.

Diff-Umfang zuerst geprueft (git diff --stat, git status): Seit Runde 2 ist ausschliesslich
docs/specs/enrichment/fix-144-recognition-pool-empty.md unstaged veraendert (37 Einfuegungen, 12
Loeschungen, ein File). Die vier staged Aenderungen (EnrichmentCoordinator.swift, TaskItem.swift,
00-entscheidungen.md, feat-136-wiedererkennung.md) und alle Artefakte unter
docs/artifacts/fix-144-recognition-pool-empty/ waren bereits in Runde 1/2 vorhanden und ungeaendert.
Kein Produktivcode, kein Testcode wurde in dieser Runde angefasst -- bestaetigt durch git diff --stat
(ein File) und durch eigene SHA-256-Neuberechnung:

| Datei | gestempelter Hash Runde 1/2 | Hash jetzt | Gleich |
|---|---|---|---|
| EnrichmentCoordinator.swift | 9df2d1f4...7b3baf | 9df2d1f4...7b3baf | ja |
| TaskItem.swift | 2a8b66eb...918d1c3a6 | 2a8b66eb...918d1c3a6 | ja |
| RecognitionRule.swift | 67d902ae...1cb43d97c | 67d902ae...1cb43d97c | ja |

Damit ist AC-1 bis AC-9 aus Runde 1/2 ohne erneuten Testlauf weiter tragfaehig: der gemessene Code
ist byte-identisch zu dem Stand, gegen den die Artefakte in Runde 1/2 unabhaengig geprueft wurden.

Kernfrage: Korrektur oder Abschwaechung? Jede Einzelbehauptung der Korrektur selbst am Code
nachgelesen, nicht der Spec geglaubt:

1. RuleLeaveOneOutTests traegt kein Gatter, laeuft immer -- nachgelesen: Zeile 57 ist
   "@Suite(Regel-Auslass-Test: Logik, Spike #69, #131)", Zeile 58 "struct RuleLeaveOneOutTests {",
   kein enabled(if:) an dieser Stelle. Stimmt.
2. Die tatsaechlich gegatterte Suite heisst RuleLeaveOneOutReportTests, Zeile 197 -- nachgelesen:
   Zeile 197 ist exakt ein enabled(if: FileManager fileExists focusBloxTruthURL) Suite-Attribut,
   Zeile 198 "struct RuleLeaveOneOutReportTests {". Stimmt, Zeilennummer exakt.
3. SelfConsistencyReportTests gattert auf ZWEI Dateien (Zeilen 21-22) -- nachgelesen: ein
   zweizeiliger enabled(if:)-Ausdruck ueber Korpus UND selfConsistencyRunURL, letztere zeigt auf
   docs/reference/selfconsistency-run.json (Zeile 18). Stimmt.
4. Diese zweite Datei existiert nirgends -- selbst geprueft: Datei fehlt im Arbeitsverzeichnis und im
   Hauptordner (zwei ls-Aufrufe, beide "No such file or directory"), kein Treffer in git log --all,
   kein Treffer in git check-ignore, kein Treffer per find im ganzen Repo. Stimmt vollstaendig.
5. Die drei tatsaechlich mit Korpus zusaetzlich gelaufenen Suiten sind exakt die drei jetzt in AC-10
   genannten -- eigener Abgleich der beiden Testausgaben per diff: die einzigen inhaltlich neuen
   Suiten im Korpus-Lauf sind FocusBloxCalibrationTests, RecognitionRuleCorpusTests,
   RuleLeaveOneOutReportTests (zwei weitere Differenzen sind Artefakte nebenlaeufiger Testausgabe --
   sie erscheinen im Lauf ohne Korpus als "passed" ohne vorheriges "started", reine Interleaving-
   Unschaerfe von Swift Testing, keine echten Suiten-Unterschiede).
6. Zahlencheck der Differenz: 229 minus 225 Haken macht vier. Eigene Auszaehlung je Suite:
   FocusBloxCalibrationTests 1, RuleLeaveOneOutReportTests 1, RecognitionRuleCorpusTests 2 -- Summe
   vier, exakt die Differenz. SelfConsistencyReportTests traegt keinen einzigen Haken bei (keine
   "Suite SelfConsistencyReportTests started"-Zeile in keiner der beiden Ausgaben).
7. Die inhaltliche Bedingung von AC-10 -- RecognitionRuleCorpusTests laeuft echt und liefert
   unveraenderte Messzahlen -- ist im korrigierten Wortlaut woertlich erhalten, derselbe
   Artefakt-Zwang bleibt.

Bewertung der Kernfrage: Die Korrektur ist eine Richtigstellung, keine Abschwaechung. Sie nimmt
nichts von der fuer #144 tatsaechlich einschlaegigen Bedingung zurueck (RecognitionRuleCorpusTests
muss laufen, Zahlen muessen gleich bleiben -- unveraendert Pflicht), sondern korrigiert zwei
Suitennamen, die beim urspruenglichen Verfassen der Spec offenkundig durch oberflaechliches
Aufzaehlen aller enabled(if:)-Fundstellen entstanden, ohne jede Stelle einzeln nachzulesen. Der
Fehler war nur durch den tatsaechlichen Lauf sichtbar (genau der Zweck von AC-10) und wird jetzt mit
Zeilennummern, eigenen Pruefsummen und einer Tabelle in korpus-messung.md belegt, nicht bloss
behauptet. Besonders stark gegen eine Abschwaechungs-These spricht: SelfConsistencyReportTests war in
der urspruenglichen Fassung ohnehin niemals erfuellbar (Datei aus Spike #108, ausserhalb des
Aenderungsumfangs von #144) -- sie aus AC-10 zu entfernen nimmt keine reale Verpflichtung weg,
sondern beendet eine Verpflichtung, die von Anfang an unmoeglich war und AC-10 sonst auf ewig
unerfuellbar gemacht haette.

Confirmation:
  AC: AC-10
  Code reference: docs/artifacts/fix-144-recognition-pool-empty/korpus-messung.md:44-66,
    LooseEndsTests/RuleLeaveOneOutTests.swift:57-58,197-198,
    LooseEndsTests/SelfConsistencyReportTests.swift:18-23,
    LooseEndsTests/RecognitionRuleTests.swift:255
  Evidence: Eigene Nachrechnung bestaetigt alle sieben Einzelbehauptungen der Spec-Korrektur exakt
    (Zeilennummern, Dateiabwesenheit, Suitendifferenz, Haken-Differenz 4 = 1+1+2). Die fuer #144
    einschlaegige Bedingung (RecognitionRuleCorpusTests laeuft echt, Zahlen unveraendert) ist
    woertlich erhalten und durch Pruefsumme plus hartkodierte Testerwartungen belegt.
  Status: CONFIRMED

Finding F001 aus Runde 2 gilt hiermit als durch die Spec-Korrektur behoben -- kein neues Finding in
dieser Runde, kein AMBIGUOUS-Rest.

### Runde 4

Zweiter, unabhaengiger Durchgang gegen vorschnelle Konvergenz (Regel: nicht in einer Runde
zustimmen). Geprueft, ob die Korrektur selbst neue Probleme einfuehrt, die Runde 3 uebersehen haben
koennte:

- Wurde die Abnahme-Liste sonst irgendwo veraendert? Vollstaendiger Blick auf die aktuelle Spec
  (AC-1 bis AC-9): sie stehen woertlich wie vor der Korrektur, nur der AC-10-Absatz und die
  vorangehende Passage "Korpus-Messung als Nulllinie" sowie der Changelog-Eintrag am Dateiende wurden
  veraendert -- bestaetigt durch den vollstaendigen git diff, der ausschliesslich diese drei Stellen
  zeigt (37 Einfuegungen, 12 Loeschungen, keine weiteren Hunks).
- Ist die neue Begruendung fuer Spike #108 (Geraetelauf) plausibel und nicht erfunden? Der
  Quellcode-Kommentar am Kopf von SelfConsistencyReportTests.swift nennt selbst "Spike #65 Schritt 2
  (#108)" und einen Geraete-Fetch (sim.sh lab-fetch) -- die Spec-Korrektur erfindet die Herkunft
  nicht, sie zitiert eine bereits im Code stehende Tatsache.
- Koennte die Entfernung von SelfConsistencyReportTests aus AC-10 kuenftig eine echte Regression
  verstecken? Nein: die Suite lief in BEIDEN Laeufen (mit und ohne Korpus) nicht, und lief auch in
  Runde 1/2 nicht -- ihre Herausnahme aendert die Beweislast von #144 nicht.
- Wurde durch das Entfernen des vierten Suiten-Namens die noetige Test-Differenz (hoehere Zahl
  ausgefuehrter Tests) verwaessert? Nein: die geforderte Differenz bezieht sich weiterhin auf ALLE
  ausgefuehrten Tests (225 vs. 229), nicht auf eine Teilmenge.
- Nochmaliger Gegencheck der Ausgangsfrage: Koennte diese Korrektur genutzt worden sein, um sich
  einer laestigen Pflicht zu entledigen? Nein -- die tatsaechlich pruefbare und fuer #144 relevante
  Pflicht (RecognitionRuleCorpusTests, 61/169-Zahlen) ist unveraendert Pflicht geblieben. Die
  entfernte Pflicht war fuer #144 nie einloesbar, unabhaengig davon, wer sie ausgefuehrt haette.

Kein neuer Befund in dieser Runde. Beide Runden (3 und 4) stuetzen dieselbe Schlussfolgerung aus
unabhaengigen Blickwinkeln.

## VERDICT: VERIFIED

Die Spec-Korrektur vom 2026-09-28 ist eine Richtigstellung, keine Abschwaechung. Alle sieben
Einzelbehauptungen der Korrektur wurden unabhaengig am Code, an den Testausgaben und per eigener
Pruefsummen-/Haken-Zaehlung nachgerechnet und bestaetigt. Die fuer #144 inhaltlich einschlaegige
Bedingung von AC-10 (RecognitionRuleCorpusTests laeuft echt gegen den Korpus, Messzahlen 61/104 und
169/276 unveraendert) blieb woertlich erhalten. Der entfernte vierte Suitenname
(SelfConsistencyReportTests) war fuer #144 strukturell nie erfuellbar (haengt an einer
Geraetelauf-Datei aus Spike #108, die ausserhalb des Aenderungsumfangs liegt) -- seine Herausnahme
beendet eine unerfuellbare Pflicht, nimmt aber keine reale Verpflichtung weg. F001 aus Runde 2 gilt
als behoben.

Proven points: 10/10 (AC-1 bis AC-9 durch Pruefsummen-Identitaet mit Runde 1/2 weiter bestaetigt,
AC-10 in dieser Runde neu bewiesen).
Tests: 225 gruen ohne Korpus, 229 gruen mit Korpus, 0 fehlgeschlagen -- unveraendert seit Runde 1/2
(Pruefsummen von EnrichmentCoordinator.swift, TaskItem.swift, RecognitionRule.swift identisch zum
gestempelten Stand von Runde 1/2, kein erneuter Testlauf noetig).
Edge cases: Missbrauchs-Check in Runde 4 (koennte die Korrektur eine reale Pflicht verstecken?)
durchgefuehrt, verneint.
Regressions: keine -- ausschliesslich die Spec-Datei wurde seit Runde 2 veraendert (git diff --stat:
ein File), Produktivcode und Tests byte-identisch.
Checklist: 10/10 Punkte bewiesen (AC-1 bis AC-9 aus Runde 1/2 uebernommen und per Pruefsumme
bestaetigt, AC-10 in Runde 3/4 neu und vollstaendig bewiesen).

## Geprüfte Dateien

- sha256:39de30ee8b3c476916c2bba27eda20b9fe32f10b8e5f87b1884c2b7dc9cf3aba  LooseEndsTests/EnrichmentTests.swift
- sha256:cb8df88035110c062fa8a2727f4bae451a305dcaf6e08ff32c398c09b227e3aa  LooseEndsTests/RecognitionRuleTests.swift
- sha256:80d82d9adb2a11727056cd52c5dd60d4357c39f281bf61f4b9d2afc84784fa6b  LooseEndsUITests/RecognitionWalkthroughTests.swift
- sha256:9df2d1f42664652dd89c01feb38c7152e04c0745e8f897260edf34f47e7b3baf  Shared/Enrichment/EnrichmentCoordinator.swift
- sha256:fc3d172643dab549df6bdb8ee1b9793768349f29d9318f05e3d6ab192823187b  docs/artifacts/fix-144-recognition-pool-empty/korpus-messung.md
- sha256:e186109cde444d8ab4c7e9384bfbcc18d7f05d018582e802d624de317d211367  docs/specs/enrichment/fix-144-recognition-pool-empty.md

# Adversary Dialog - Spike #69, Ticket A (Regel-Baseline fuer den Konventionstest)

Spec: docs/specs/measurement/spike-69-regel-baseline-konventionstest.md
Workflow: spike-69-retrieval-beispiele
Datum: 2026-09-26

## Testlauf

./scripts/sim.sh unit frisch ausgefuehrt (nicht nur das mitgelieferte Artefakt uebernommen).
Vollstaendiges Protokoll: docs/artifacts/spike-69-retrieval-beispiele/_adversary_run.log
(Spiegel: /tmp/adversary_test_output.txt). Ergebnis: TEST SUCCEEDED, 0 Failures ueber die
gesamte Suite (u.a. CorpusTests, MeasurementRunTests, SelfConsistencyTests, EnrichmentTests
unveraendert gruen). Die Suite Regel-Baseline fuer den Konventionstest lief mit allen sechs
Tests gruen (AC-1 bis AC-6, siehe Log Zeilen 37-44).

docs/reference/retrieval-convention-spike.md wurde vom Report-Test frisch neu geschrieben,
Ergebnis identisch zum mitgelieferten Artefakt: Trefferquote 10 von 10, Ticket B nicht noetig.

### Runde 1

Pruefung jedes AC gegen Spec-Text, Testcode und die tatsaechliche Implementierung
(Measurement/ConventionCorpus.swift, Measurement/RuleBaseline.swift,
Measurement/convention-corpus.json).

- [x] AC-1: Measurement/convention-corpus.json enthaelt genau zehn Eintraege (haendisch nachgezaehlt:
  Rasen, Heizung, Rechnung, Reifen, Angebot, Spuelmaschine, Katze, Koffer, Blutdruck, Fenster), jeder
  mit drei corrections und einer probe. ConventionCorpus.Pattern (Zeilen 16-33) dekodiert ohne
  Kuerzung (kein .prefix, kein optionales Array). Test loadsTenPatterns bestaetigt count == 10
  und corrections.count == 3 je Muster - GRUEN.
- [x] AC-2: RuleBaseline.predict (Zeilen 16-35) tokenisiert ueber TitleCheck.words(in:)
  (Measurement/Corpus.swift:278-280) und TitleCheck.normalized (Zeilen 236-240). Test
  predictsFromSharedCoreWord mit dem exakten Spec-Beispiel (Rasen maehen / Rasen waessern)
  liefert Garten - GRUEN, per eigenem Nachbau (swift-Standalone-Reproduktion derselben Logik)
  bestaetigt.
- [x] AC-3: Test majorityWinsOverLastSeen bestaetigt 2-von-3 gewinnt im spezifischen Testfall. Bei
  eigener Tiefenpruefung (siehe Runde 2) zeigt sich aber: die Implementierung zaehlt nicht
  Korrekturen, sondern die Summe geteilter Woerter je Kontext - im Testfall sind das zufaellig
  aequivalent (je 1 geteiltes Wort pro Korrektur), im Allgemeinen nicht (siehe F002).
- [x] AC-4: Test noMatchYieldsNil - Sonde Fahrrad reparieren gegen drei Finanzen-Korrekturen
  ohne jedes gemeinsame Wort liefert nil - GRUEN. Deckt aber nur den Fall ab, in dem gar kein
  Wort geteilt wird, nicht den Fall, in dem nur Fuellwoerter geteilt werden (siehe F002).
- [x] AC-5: Test evaluatesAllPatterns erzeugt zwei Outcome-Werte, correct korrekt fuer Treffer
  und Fehltreffer - GRUEN. Fuer den vollen Korpus bestaetigt writesReport zehn Outcome-Werte mit
  hits = 10.
- [x] AC-6: grep ueber Measurement/ConventionCorpus.swift, Measurement/RuleBaseline.swift und
  LooseEndsTests/ConventionBaselineTests.swift nach FoundationModelsEnricher,
  canImport(FoundationModels), LanguageModelSession - keine Treffer. Der Report-Test schreibt
  docs/reference/retrieval-convention-spike.md synchron im normalen sim.sh unit-Lauf, ohne Geraet
  - bestaetigt durch den frischen Testlauf oben.

Ergebnis Runde 1: Alle sechs ACs sind durch Tests belegt und durch eigene Code-Lektuere
nachvollzogen. Kein Test schlaegt fehl, keine Regression in den unveraenderten Suiten.

### Runde 2 - vertiefte Pruefung (Wortform-Grenze und eigene Gegenproben)

Der selbst gemeldete Schwachpunkt aus der Implementierungsrunde: Die zehn Korpus-Muster sind so
gebaut, dass das Kernwort wortwoertlich identisch in allen drei Korrekturen und der Sonde vorkommt
(z. B. Rasen/Rasen, nicht Rasen/Rasenmaehen oder Koffer/Koffern). Geprueft, ob
RuleBaseline.predict bei einer Wortformaenderung tatsaechlich nil liefert oder falsch verhaelt, und
ob das dokumentiert ist.

Eigene Reproduktion (Standalone-Swift-Skript, byte-identische Uebernahme der Logik aus
Measurement/RuleBaseline.swift:16-35 und Measurement/Corpus.swift:236-240,278-280, gegen den
Mac-Compiler laufen lassen, kein Xcode-Projekt noetig, weil reine Foundation-Zeichenkettenverarbeitung):

- Kernwort Koffer (Korrekturen) gegen Kompositum Kofferraum (Sonde) -> nil.
- Kernwort Koffer (Korrekturen) gegen Flexion Koffern (Sonde) -> nil.
- Kernwort Rasen (Korrekturen) gegen Kompositum Rasenmaehen (Sonde) und umgekehrt -> nil in
  beiden Richtungen.

Befund zu diesem Punkt: predict liefert bei Wortformaenderung tatsaechlich nil - kein falscher
Kontext, kein erzwungener Default. Das ist im Sinne von AC-4 die sichere Fehlrichtung (lieber kein
Treffer als ein falscher). Es handelt sich also nicht um einen Defekt, der ein falsches Ergebnis
produziert, sondern um eine Recall-Grenze: Die Regel erkennt nur Kernwoerter, die als exakt
dasselbe Token vorkommen. Diese Grenze ist implizit durch die Spec selbst vorgegeben
(Technische Umsetzung, Schritt 2: drei corrections mit demselben Kernwort, eine probe mit
demselben Kernwort - die Spec verlangt woertlich identische Kernwoerter fuer diesen Schnitt), aber
nirgends explizit als Grenze benannt - weder im Abschnitt Zweck noch in Nicht in diesem
Schnitt, noch im generierten Bericht docs/reference/retrieval-convention-spike.md. Ein Leser des
Berichts koennte 10 von 10 als Beleg lesen, dass die Regel Hennings Konventionen allgemein trifft,
obwohl real formulierte Korrekturen fast immer Flexion oder Komposita enthalten wuerden und dort
unbewiesen bleibt, ob die Regel dieselbe Trefferquote hielte. Siehe F001 unten.

Eigene Zusatzprobe, ueber die gemeldete Frage hinaus: Weil predict Kontexte nicht nach Anzahl
der Korrekturen, sondern nach Summe geteilter Woerter gewichtet, wurde geprueft, ob das zu falschen,
nicht durch AC-4 abgefangenen Treffern fuehren kann.

- Drei Finanzen-Korrekturen und eine themenfremde Sonde Fahrrad am Montag reparieren, bei der
  einzig die Fuellwoerter am und Montag mit allen drei Korrekturen uebereinstimmen (kein
  inhaltliches Kernwort gemeinsam) -> Ergebnis Finanzen, kein nil. Reproduziert mit derselben
  Logik wie oben.
- Zwei Garten-Korrekturen (kurz, je 1 geteiltes Wort mit der Sonde) gegen eine einzelne
  Keller-Korrektur, die zufaellig mehr Woerter mit der Sonde teilt (3 statt 1) -> Ergebnis
  Keller, obwohl die Spec-Formulierung von AC-3 ausdruecklich verlangt, dass die 2-von-3-Mehrheit
  gewinnt, nicht der zuletzt gesehene Wert (und implizit: nicht eine einzelne, zufaellig
  wortreichere Korrektur). Siehe F002 unten.

## Structured Findings

Finding F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: Measurement/RuleBaseline.swift:16-35
  Code reference: Measurement/convention-corpus.json:1-61
  Description: RuleBaseline.predict erkennt ein Kernwort nur, wenn es als exakt identisches Token
    (nach Gross-/Kleinschreibung und Diakritika-Faltung ueber TitleCheck.normalized) in Korrektur und
    Sonde vorkommt. Komposita (Rasen/Rasenmaehen) und Flexionsformen (Koffer/Koffern) werden
    nicht erkannt und liefern nil (durch eigene Standalone-Reproduktion der Funktion bestaetigt: alle
    drei Gegenproben nil). Alle zehn Muster in convention-corpus.json sind so konstruiert, dass das
    Kernwort wortwoertlich identisch in allen drei Korrekturen und der Sonde steht.
  Spec requirement: Zweck - misst, ob sich Hennings Konventionen ableiten lassen; Nicht in
    diesem Schnitt nennt diese Wortform-Grenze nicht.
  Conflict: Die im Bericht ausgewiesene Trefferquote 10 von 10 ist nur fuer den Spezialfall
    wortwoertlich identischer Kernwoerter bewiesen. Reale Korrekturen Hennings werden absehbar auch
    Flexion und Komposita enthalten; fuer diese ist die Trefferquote unbewiesen, das Risiko einer
    falschen Ticket-B-Entscheidung dadurch nicht durch die Messung abgedeckt. Weder der
    Spec-Abschnitt Nicht in diesem Schnitt noch der generierte Bericht nennen diese Grenze.
  Remediation: Vor der endgueltigen Ticket-B-Entscheidung im Bericht (oder als Begleitsatz in der
    Spec) explizit festhalten: Trefferquote gilt nur fuer Sonden mit identischem Kernwort-Token,
    nicht fuer Flexion/Komposita - fuer reale Korrekturen ungeprueft. Optional (nicht in diesem
    Schnitt): einfache Stamm-/Praefixheuristik statt exaktem Token-Vergleich, falls Ticket B kommt.

Finding F002
  Severity: HIGH
  Category: edge_case
  Code reference: Measurement/RuleBaseline.swift:21-33
  Description: Der Mehrheitsentscheid gewichtet nach Summe geteilter Woerter pro Kontext, nicht nach
    Anzahl der Korrekturen. Dadurch (a) zaehlt jedes geteilte Wort inklusive Praepositionen und
    Wochentagsnamen als Stimme, ohne Filterung von Funktionswoertern, und (b) kann eine einzelne
    Korrektur mit vielen geteilten Woertern eine 2-von-3-Mehrheit anderer Korrekturen ueberstimmen.
    Durch eigene Standalone-Reproduktion der exakten Funktion belegt: (1) drei Finanzen-
    Korrekturen plus eine voellig themenfremde Sonde Fahrrad am Montag reparieren liefert
    Finanzen statt nil, einzig weil am und Montag zufaellig geteilt werden; (2) zwei kurze
    Garten-Korrekturen (je 1 geteiltes Wort) gegen eine einzelne Keller-Korrektur mit 3 geteilten
    Woertern liefert Keller statt der laut AC-3 verlangten 2-von-3-Mehrheit Garten.
  Spec requirement: AC-3 - gewinnt Garten (2 von 3), nicht der zuletzt gesehene Wert, die
    Funktion zaehlt Haeufigkeiten, sie ueberschreibt nicht einfach den letzten Treffer. AC-4 - Kein
    Treffer liefert nil, keinen geratenen Kontext.
  Conflict: Die im Test abgedeckten Faelle (AC-3, AC-4) haben zufaellig ueberall genau ein geteiltes
    Wort pro Korrektur bzw. gar keine Ueberschneidung, weshalb Korrektur-Mehrheit und Wort-Mehrheit
    dort identisch ausfallen und kein Test die Divergenz zeigt. In der Praxis (unterschiedlich lange
    Korrekturen, gemeinsame Praepositionen/Wochentage zwischen thematisch unabhaengigen Notizen) ist
    weder die 2-von-3-Garantie aus AC-3 noch die kein-geratener-Kontext-Garantie aus AC-4
    allgemein erfuellt - nur fuer den engen, kuratierten Korpus, der aktuell keine solchen
    Ueberschneidungen enthaelt (mit einer Ausnahme: das Rasen-Muster teilt zusaetzlich bevor
    zwischen einer Korrektur und der Sonde, wirkt sich dort aber nicht aus, weil alle drei
    Korrekturen ohnehin denselben Kontext Garten haben).
  Remediation: Vor der Ticket-B-Entscheidung entweder (a) auf Korrektur-Zaehlung umstellen (ein Vote
    pro Korrektur mit mindestens einem geteilten Wort, nicht Summe der geteilten Woerter), und/oder
    (b) eine Stoppwortliste/Mindestwortlaenge einfuehren, bevor ein geteiltes Wort als Kernwort
    zaehlt. Ohne das ist unklar, ob die 10/10-Messung robust genug ist, um die ADR-5-Folgeentscheidung
    zu tragen.

## Confirmations

Confirmation AC-1
  Code reference: Measurement/ConventionCorpus.swift:16-46
  Code reference: Measurement/convention-corpus.json:1-61
  Evidence: JSON enthaelt exakt zehn Eintraege mit je drei corrections und einer probe; Pattern-Struct
    dekodiert ohne Kuerzung; Test loadsTenPatterns gruen (frischer Testlauf, Zeile 38 im Protokoll).
  Status: CONFIRMED

Confirmation AC-2
  Code reference: Measurement/RuleBaseline.swift:16-35
  Evidence: predict() tokenisiert ueber TitleCheck.words(in:)/normalized; Test
    predictsFromSharedCoreWord mit dem Spec-eigenen Rasen-Beispiel liefert Garten, gruen.
  Status: CONFIRMED

Confirmation AC-3
  Code reference: Measurement/RuleBaseline.swift:21-33
  Evidence: Test majorityWinsOverLastSeen gruen fuer den in der Spec vorgegebenen Testfall (2 Garten
    gegen 1 Keller, je ein geteiltes Wort). Einschraenkung siehe F002: die Garantie ist nicht
    allgemein robust, aber fuer den spezifizierten Testfall und den ausgelieferten Korpus bewiesen.
  Status: CONFIRMED (mit dokumentierter Einschraenkung, siehe F002)

Confirmation AC-4
  Code reference: Measurement/RuleBaseline.swift:34
  Evidence: Test noMatchYieldsNil gruen; predict liefert nil, wenn kein Sondenwort in der
    Haeufigkeitstabelle steht. Fuer den Fall voelliger Wortueberschneidungslosigkeit exakt erfuellt.
  Status: CONFIRMED (fuer den getesteten Fall; siehe F002 fuer den nicht getesteten Fall reiner
    Funktionswort-Ueberschneidung)

Confirmation AC-5
  Code reference: Measurement/RuleBaseline.swift:44-50
  Evidence: evaluate(patterns:) liefert einen Outcome pro Pattern; Test evaluatesAllPatterns gruen,
    Bericht bestaetigt zehn Outcomes mit hits=10 fuer den echten Korpus.
  Status: CONFIRMED

Confirmation AC-6
  Code reference: LooseEndsTests/ConventionBaselineTests.swift:109-132
  Evidence: writesReport() schreibt docs/reference/retrieval-convention-spike.md synchron im
    normalen sim.sh-unit-Lauf; grep ueber alle drei neuen Dateien nach FoundationModelsEnricher,
    canImport(FoundationModels), LanguageModelSession liefert keinen Treffer; frischer Testlauf
    bestaetigt TEST SUCCEEDED ohne Geraet.
  Status: CONFIRMED

## VERDICT

VERDICT: AMBIGUOUS

Ambiguous findings (require human review):
  F001: Wortform-Grenze (Komposita/Flexion) ist real, aber sicher (liefert nil, keinen falschen
    Kontext) - implizit durch die Spec selbst vorgegeben (Korpus-Konstruktion mit identischem
    Kernwort), aber nirgends als Grenze der Trefferquote benannt. Kein Defekt, aber eine
    unausgesprochene Einschraenkung der externen Validitaet der Messung.
  F002: Der Mehrheitsentscheid gewichtet nach Wortanzahl statt Korrekturanzahl und hat keine
    Stoppwortfilterung - durch eigene Reproduktion nachgewiesen, dass das zu falschen, nicht durch
    AC-4 abgefangenen Treffern und zu einer durch AC-3 nicht gedeckten Mehrheitsumkehr fuehren kann.
    Im ausgelieferten Zehn-Muster-Korpus tritt der Fall nicht auf, ist dort also nicht sichtbar.

Alle sechs ACs sind durch gruene Tests UND eigene Code-Reproduktion belegt (kein Verstoss gegen den
Wortlaut einer AC). Der Zweifel betrifft nicht die Buchstaben der Spec, sondern die Tragfaehigkeit
der Messung fuer die nachgelagerte Entscheidung (Ticket B noetig: nein bzw. spaetere ADR-5-Frage):
Ob die 10/10-Trefferquote auf reale, morphologisch variierende und unterschiedlich lange Korrekturen
uebertragbar ist, ist durch diesen Korpus nicht bewiesen und durch F002 aktiv in Zweifel gezogen.

Proven points: 6/6 ACs (Buchstabe der Spec)
Tests: alle gruen, 0 Failures, volle Suite (sim.sh unit, frisch gelaufen,
  docs/artifacts/spike-69-retrieval-beispiele/_adversary_run.log)
Regressions: keine gefunden
Recommendation: Henning/Entwickler soll vor der Ticket-B/ADR-5-Folgeentscheidung klaeren, ob (a) ein
  Hinweis auf die Wortform-Grenze im Bericht reicht (F001) und ob (b) die Wortzahl-Gewichtung im
  Mehrheitsentscheid (F002) fuer diesen kleinen Erstschnitt hingenommen wird oder vor der
  Entscheidung noch auf Korrektur-Zaehlung mit Stoppwortfilter umgestellt werden soll - sonst bei
  workflow.py override-ambiguous die Risikoabwaegung ausdruecklich benennen.

## Geprüfte Dateien

- sha256:41799ae135fcc48730c9bdc3749cab3572858a72f0cc245fda09f2b153f22853  LooseEndsTests/ConventionBaselineTests.swift
- sha256:af420c75216776075759c4041d22fd42ac86f890c7469f7567b5e16c58260617  Measurement/ConventionCorpus.swift
- sha256:5359f26aa080ba988b2a1f9a165f4da8751038b14f7d87b71d11476f500fa34b  Measurement/RuleBaseline.swift
- sha256:b769e72d0e97ca266d65f2aec7e1166eec5c11130db043b1488e0820a4bcfbd6  Measurement/convention-corpus.json

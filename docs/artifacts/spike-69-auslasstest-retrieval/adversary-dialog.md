# Adversary-Dialog: Regel-Auslass-Test (Spike #69, Issue #131)

- **Workflow:** spike-69-auslasstest-retrieval
- **Spec:** docs/specs/measurement/spike-69-regel-auslasstest.md
- **Datum:** 2026-09-26
- **Rolle:** Adversary Validation, kontext-isoliert, ohne Kenntnis der Implementierer-Begruendung
- **Testausgaben:** docs/artifacts/spike-69-auslasstest-retrieval/adversary-test-output.txt und
  docs/artifacts/spike-69-auslasstest-retrieval/adversary-independent-recompute.txt
- **Eigene Nachrechnung:** docs/artifacts/spike-69-auslasstest-retrieval/adversary-recompute.py

## Wie geprueft wurde

1. Spec und Implementierung gelesen, danach die gesamte Messrechnung **unabhaengig in Python
   nachgebaut** (Tokenisierung, Diakritika-Faltung, Laengenfilter, Jaccard, Nachbarsuche,
   Mehrheit, Nulllinie, exakter McNemar) und gegen den echten Korpus gerechnet. Die Faltung wurde
   vorher in Swift nachgemessen (aus "für" wird "fur", aus "straße" wird "strasse"), damit die
   Nachrechnung nicht an einer falschen Annahme scheitert.
2. Vollen Testlauf gefahren (./scripts/sim.sh unit), danach einen zweiten Lauf nur mit der
   Bericht-Suite als Determinismus- und Modell-Gegenprobe.
3. Die scharf benannten Angriffspunkte gezielt beschossen: Leerlisten-Behandlung an jeder Stelle,
   leere Strings bei Dauer und Energie, k-Invarianz bei Kontexten, AC-5-Semantik, hartkodierte
   Werte, Modellaufruf im Lauf, Determinismus ueber die Set-Iterationsreihenfolge.

### Runde 1 — Testlauf, Nachrechnung, AC-Abgleich

Voller Lauf gruen: "Test run with 198 tests in 43 suites passed after 27.716 seconds". Keine
Fehlschlaege. Uebersprungen ist nur SelfConsistencyReportTests, wie vorgesehen gegatet.

Die unabhaengige Nachrechnung reproduziert **jede Zahl** des Berichts exakt: Hauptspalten,
Nebenspalten, b, c, p-Wert, Saetze ohne Nachbarn. Der Bericht ist damit nicht mehr eine
Behauptung der Implementierung, sondern von zwei getrennten Implementierungen bestaetigt.

- [x] AC-1 Auslass, kein Selbst-Nachbar
- [x] AC-2 Jaccard-Rangfolge mit deterministischem Gleichstand
- [x] AC-3 Laengenfilter ab vier Zeichen
- [x] AC-4 Mehrheitsentscheid mit Gleichstandsregel
- [x] AC-5 nil ohne Nachbarn zaehlt als Fehltreffer
- [x] AC-6 Nulllinie aus dem Pool gerechnet, nie hartkodiert
- [x] AC-7 Kontextmengen-Normalisierung
- [x] AC-8 McNemar-Exakttest inklusive b plus c gleich null
- [x] AC-9 Bericht mit allen Pflichtspalten, ohne Modell- oder Geraeteaufruf

Confirmation:
  AC: AC-1
  Code reference: Measurement/LeaveOneOut.swift:39
  Evidence: neighbors filtert die Kandidaten auf ungleiche id zur Zielaufgabe, bevor irgendein
    Score gerechnet wird. Die Zielaufgabe ist nie Kandidat, egal wie hoch ihre
    Selbst-Aehnlichkeit waere. Test targetIsNeverItsOwnNeighbor gruen. Gegenprobe am echten
    Korpus: waere die Zielaufgabe ihr eigener Nachbar, koennte die Zahl "19 Saetze ohne
    Nachbarn" nicht 19 sein, sie muesste 0 sein.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Measurement/LeaveOneOut.swift:43-45
  Evidence: Der Komparator vergleicht bei gleichem Score aufsteigend nach id, sonst absteigend
    nach Score. Testfall selbst nachgerechnet: Ziel "Rasen mähen" ergibt die Wortmenge rasen,
    mahen. "Rasen mähen bitte" erreicht zwei Drittel, "Rasen wässern" und "Rasen düngen" je ein
    Drittel, der id-Tiebreak ergibt z, a, b. Test gruen. Gleiche Bruchwerte sind bitidentisch,
    weil die IEEE-Division exakt gerundet ist. Der Komparator ist damit eine totale Ordnung ueber
    eindeutige ids, im Korpus geprueft: null doppelte ids.
    Determinismus empirisch: ein zweiter, getrennter Prozess schreibt den Bericht byte-identisch,
    SHA-256 4624fcdc2905a826e790281bf0961c7d508b048090376f3b9354fbce3bbe5e0f in beiden Laeufen.
    Ein zweiter Prozess hat einen anderen Set-Hash-Seed. Haenge irgendeine Zahl an der
    Set-Iterationsreihenfolge, waere der Bericht abgewichen. Zusaetzlich per Code belegt: keine
    Stelle iteriert ueber ein Set oder ein Dictionary, majority entscheidet ueber das Array
    valuesInOrder (Measurement/LeaveOneOut.swift:60), Mengen werden nur ueber count gelesen.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Measurement/LeaveOneOut.swift:21
  Evidence: Der Laengenfilter ab vier Zeichen greift NACH TitleCheck.normalized. Der gefaehrliche
    Fall waere eine Faltung, die "für" auf "fuer" mit vier Zeichen verlaengert. In Swift
    nachgemessen: "für" wird "fur" mit drei Zeichen, "Müll" wird "mull", "straße" wird "strasse".
    Der Testfall "Das Auto ist da für uns" liefert genau die Menge mit dem einen Wort auto, gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Measurement/LeaveOneOut.swift:63-74
  Evidence: valuesInOrder haelt die Reihenfolge des ersten Auftretens, die Auswahl nimmt nur bei
    **strikt** mehr Stimmen einen spaeteren Wert. Bei einer Stimme zu einer Stimme bleibt der
    naehere Nachbar. Eigene Kontrollfaelle ueber dieselbe Logik: A, B, B ergibt B, die Mehrheit
    schlaegt also den naechsten Nachbarn. A, B, A ergibt A. Die leere Liste ergibt nil. Test
    majorityBreaksTiesByNeighborRank gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Measurement/LeaveOneOut.swift:117
  Evidence: rate teilt correct durch total, also durch pool.count, nicht durch answered. Ein Satz
    ohne Vorhersage senkt die verbindliche Quote. Am echten Korpus nachgerechnet: Kontext-Pool
    104, davon 19 ohne einen einzigen Nachbarn, eigene Zaehlung exakt 19, beantwortet 85. Damit
    75 von 104 gleich 72,1 Prozent und 75 von 85 gleich 88,2 Prozent, genau die zwei Zahlen im
    Bericht, und 104 minus 19 gleich 85 geht auf. Dauer 28 ohne Nachbarn bei 276 und 248, Energie
    28 bei 211 und 183, beides eigenstaendig nachgezaehlt. Zusaetzlich geprueft, dass die Spalte
    "ohne Nachbarn" nicht falsch benannt ist: sie zeigt total minus answered, was hier identisch
    mit "keine Nachbarn" ist, weil in jedem Pool jeder Nachbar per Konstruktion einen Wert traegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: Measurement/LeaveOneOut.swift:80-85
  Evidence: baselineClass delegiert an majority ueber den ganzen Pool. In
    Measurement/LeaveOneOut.swift steht kein Klassenname und kein Prozentwert mit
    Ergebniswirkung, gegrept ohne Treffer fuer minutes, low, computer, 56.7, 51.1, 77.3
    ausserhalb von Doc-Kommentaren. Die Nulllinien fallen aus den Daten: computer 59 von 104
    gleich 56,7 Prozent, minutes15 141 von 276 gleich 51,1 Prozent, low 163 von 211 gleich 77,3
    Prozent, von mir direkt aus dem Korpus gezaehlt. Die einzigen ergebniswirksamen
    Zahlenliterale sind die vorab in der Spec festgelegten Schwellen zehn Prozentpunkte Abstand
    und p unter 0,05 in LooseEndsTests/RuleLeaveOneOutTests.swift:264. Die
    Pool-Groessen-Zusicherungen in LooseEndsTests/RuleLeaveOneOutTests.swift:215-217 sind reine
    Erwartungszusicherungen und fliessen in keine Rechnung ein.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: Measurement/LeaveOneOut.swift:91
  Evidence: Die Kontextliste wird kleingeschrieben in eine Menge gelegt. Die Reihenfolge faellt
    durch die Menge heraus, die Schreibweise durch das Kleinschreiben. Test
    contextClassNormalisesCaseAndOrder prueft genau das Spec-Paar Computer, Learning gegen
    learning, computer, gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: Measurement/LeaveOneOut.swift:168-178
  Evidence: Der guard auf n gleich null liefert pValue 1.0 und deckt damit b plus c gleich null.
    Die Schleife ueber j bis ausschliesslich min von b und c baut tail als Summe der
    Binomialkoeffizienten von j gleich null bis min von b und c, also p gleich zwei mal Summe
    geteilt durch zwei hoch n. Unabhaengig nachgerechnet: b gleich 9 und c gleich 1 ergibt
    22 durch 1024 gleich 0,021484, also unter 0,05. b gleich 8 und c gleich 2 ergibt 112 durch
    1024 gleich 0,109375, also ueber 0,05. Alle drei Faelle im Test, gruen. Randfall b gleich c
    gleich 5 geprueft: die Formel ergibt 1,246 und wird auf 1,0 gedeckelt, ein p ueber eins ist
    im Bericht also nicht moeglich.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: LooseEndsTests/RuleLeaveOneOutTests.swift:242-271
  Evidence: Die Haupttabelle fuehrt alle acht Pflichtspalten plus Urteil. Die
    Kontext-Nebenspalten "enthält erwarteten Kontext" und "Jaccard-Mittel" stehen in
    LooseEndsTests/RuleLeaveOneOutTests.swift:288-308. Im geschriebenen Bericht belegt:
    docs/reference/retrieval-leave-one-out-rules.md:23-33 fuer die Hauptzeilen je Merkmal und k,
    :40-44 fuer die Nebenspalten, :51-53 fuer das Urteil je Merkmal. Die Nebenspalten habe ich
    unabhaengig nachgerechnet, 73,1 Prozent und 72,6 Prozent fuer alle drei k, Treffer. Kein
    Modellaufruf aus diesem Schnitt: der Gegenprobe-Lauf enthaelt nur
    RuleLeaveOneOutReportTests und im Rohlog null Zeilen "Model Catalog", null "TokenGenerator",
    null "ModelManagerError". Im vollen Lauf liegen alle 59 Modellzeilen zwischen Logzeile 311
    und 488, also innerhalb von FocusBloxCalibrationTests, Zeile 308 bis 490.
    RuleLeaveOneOutReportTests laeuft erst ab Zeile 666. Keine Geraetekommunikation: der Lauf ist
    ein Simulator-Lauf auf dem Mac, kein devicectl, kein gepaartes iPhone.
  Status: CONFIRMED

### Runde 2 — die scharf benannten Angriffspunkte

**(a) Ist der Leerlisten-Fix vollstaendig? Ja, an jeder Stelle.** contextValue in
Measurement/LeaveOneOut.swift:100-103 ist die einzige Wertfunktion fuer Kontexte und wird benutzt
fuer den Pool-Filter (LooseEndsTests/RuleLeaveOneOutTests.swift:207), die Hauptzeile (:276), die
Nulllinie ueber den line-Helfer (:254), die Nachbar-Kandidaten, weil der Pool contextPool ist
(:297), und die Nebenspalten (:296 und :299). Gegrept: es gibt keinen Pfad mehr, der auf
contextsTruth ungleich nil prueft oder eine leere Liste als Ersatzwert auf die Wahrheit legt. Der
eine verbleibende Ersatzwert in LooseEndsTests/RuleLeaveOneOutTests.swift:300 liegt auf der
**Vorhersage** der Nebenspalte. Dort wird nil zur leeren Menge, deren Schnitt mit der Wahrheit
leer ist, der Satz zaehlt also als Fehltreffer und nicht als Klasse. Kopftabelle und Fliesstext
rechnen 287 minus 104 gleich 183 aus denselben Groessen, nicht aus einer Konstante, siehe
docs/reference/retrieval-leave-one-out-rules.md:9-19.

**(b) Sind Dauer und Energie vom selben Problem betroffen? Nein.** Im Korpus nachgezaehlt:
durationTruth hat 141 mal minutes15, 66 mal minutes5, 52 mal minutes30, 17 mal hour1 und 11 mal
keinen Schluessel. energyTruth hat 163 mal low, 48 mal high und 76 mal keinen Schluessel.
**Kein einziger leerer String**, kein null. Ein leerer String als eigene Klasse kann hier nicht
auftreten, der nil-Filter ist fuer diese zwei Felder korrekt.

**(c) k-Invarianz bei Kontexten, 72,1 Prozent fuer k gleich 1, 3 und 5 mit identischem b gleich 25
und c gleich 9: kein Fehler, und k wirkt nachweisbar.** Nachbarzahl-Verteilung im Kontext-Pool:
19 Aufgaben ohne Nachbarn, 8 mit einem, 15 mit zwei, 7 mit drei, 7 mit vier, 48 mit fuenf oder
mehr. 77 Aufgaben haben also mindestens zwei Nachbarn, und k liefert dort verschiedene
Nachbarlisten. Trotzdem wechselt bei keiner der 104 Aufgaben die Vorhersage von k gleich 1 auf
k gleich 3 oder 5, weil bei 55 der 62 Aufgaben mit mindestens drei Nachbarn **alle** Nachbarn
dieselbe Kontextklasse tragen und in den restlichen 7 Faellen der naechste Nachbar auch die
Mehrheit stellt. Kontrolle: derselbe Code laesst Dauer variieren, 73,9 dann 72,1 dann 72,1
Prozent mit b gleich 101, 98, 97, und Energie ebenso, 60,2 dann 59,7 dann 59,2 Prozent mit b
gleich 2, 0, 16. Meine Nachrechnung trifft alle drei k-Zeilen bei Kontexten auf die Zahl.

**(d) AC-5 scharf:** 75 von 104 gleich 72,115 Prozent wird zu "72.1 %", 75 von 85 gleich 88,235
Prozent wird zu "88.2 %", und 104 minus 19 gleich 85. Das ist genau die Spec-Semantik: die
verbindliche Quote laeuft ueber ALLE Saetze, nil ist ein Fehltreffer.

**(e) AC-6 scharf:** siehe Confirmation AC-6. Ergebniswirksam sind nur die vorab festgelegten
Schwellen zehn Prozentpunkte und p unter 0,05.

**(f) AC-9 scharf, Modellaufruf:** geklaert. Die Zeilen "Model Catalog error" stammen aus
FocusBloxCalibrationTests, einer vorbestehenden, auf Hennings lokalen Korpus gegateten Suite aus
den Tickets 23 und 41, die in LooseEndsTests/FocusBloxCalibrationTests.swift:98 den Enricher
aufruft. Beweis durch Ausschluss: ein Lauf mit ausschliesslich RuleLeaveOneOutReportTests erzeugt
null Modellzeilen.

**(g) Determinismus ueber den echten Korpus:** zwei getrennte Prozesse, byte-identischer Bericht,
gleiche SHA-256. Siehe Confirmation AC-2.

**Was Runde 2 zusaetzlich gefunden hat, nicht an den AC vorbei, sondern unter ihnen:**

Finding:
  ID: F001
  Severity: HIGH
  Category: edge_case
  Code reference: LooseEndsTests/RuleLeaveOneOutTests.swift:321-333
  Description: Der vom Test geschriebene Abschnitt "Grenzen dieser Zahlen" nennt drei Grenzen,
    naemlich gepflegte Titel als Rohtext, den Laengenfilter und den Satz, dass ein Nullergebnis
    nur den Mechanismus widerlegt. Er nennt NICHT, dass der Korpus grosse Gruppen exakt
    textgleicher Aufgaben enthaelt und dass das Erfuellt-Urteil praktisch vollstaendig aus diesen
    Gruppen kommt. Von mir am Korpus gemessen: im Kontext-Pool liegen 61 der 104 Aufgaben in
    sieben textgleichen Gruppen, 43 mal "LinkedIn Nachrichten beantworten", 4 mal
    "Fehlerbehebung FocusBlox", 4 mal "Klavier spielen", 3 mal "Fahrradkette reinigen", 3 mal
    "Zehnagel behandel", 2 mal "Energie-Abrechnung erstellen", 2 mal "1 Blink lesen". Fuer alle
    61 hat der naechste Nachbar Jaccard 1,0, und alle 61 sind Treffer. 16 der 25 b-Faelle bei
    Kontexten und 89 der 101 b-Faelle bei Dauer sind solche Jaccard-1,0-Faelle. Entdupliziert,
    also ein Vertreter je textgleicher Gruppe, kippt das Ergebnis auf allen drei Merkmalen ins
    Negative: Kontexte 30,0 Prozent gegen eine Nulllinie von 32,0 Prozent, Abstand minus 2,0,
    b gleich 6, c gleich 7, p gleich 1,0. Dauer 32,2 gegen 56,5 Prozent, Abstand minus 24,3.
    Energie 49,6 gegen 83,2 Prozent, Abstand minus 33,6. Belegt in
    docs/artifacts/spike-69-auslasstest-retrieval/adversary-independent-recompute.txt.
  Spec requirement: AC-9. Der Bericht ist laut Spec-Zweck die Entscheidungsvorlage fuer Henning,
    ob der Modell-Auslass-Test noch eine Frage beantwortet, die das Produkt aendert, und
    Technische Umsetzung Punkt 5 verlangt "plus die Grenzen aus dieser Spec".
  Conflict: Buchstabengetreu ist AC-9 erfuellt. Die drei in der Spec aufgezaehlten Grenzen stehen
    im Bericht, die Pflichtspalten auch, und die Zahlen sind richtig, zweifach nachgerechnet.
    Aber die Aussage, auf die Henning eine ADR-5-Entscheidung stuetzen soll, naemlich "Kontexte:
    erfuellt" und "Dauer: erfuellt" in docs/reference/retrieval-leave-one-out-rules.md:51-52,
    traegt eine Lesart, die die Daten nicht stuetzen. "Wortueberlappung als Nachbarsuche schlaegt
    die Konstante" liest sich als Aussage ueber Aehnlichkeit, waehrend die Treffer aus
    Wiederholungen desselben Titels kommen. Fuer neu formulierte Aufgaben liegt die Regel deutlich
    UNTER der Konstante. Beide Lesarten sind vertretbar, denn bei wiederkehrenden Erfassungen ist
    der Effekt echter Produktnutzen, aber die Entscheidung daraus ist eine andere, je nachdem
    welche gilt, und der Bericht laesst Henning die Wahl nicht sehen.
  Remediation: Eine vierte Zeile in "Grenzen dieser Zahlen" plus zwei aus den Daten gerechnete
    Zahlen, naemlich den Anteil der Saetze mit einem Jaccard-1,0-Nachbarn und Trefferquote sowie
    Nulllinie auf dem entduplizierten Pool. Rund zehn Zeilen im Bericht-Test, kein Eingriff in
    LeaveOneOut. Alternativ die Spec um diese Grenze ergaenzen und den Bericht danach neu
    schreiben lassen.

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEndsTests/FocusBloxCalibrationTests.swift:98
  Description: AC-9 verlangt woertlich, dass im gesamten Testlauf kein Modellaufruf stattfindet.
    Im vollen Lauf von ./scripts/sim.sh unit auf Hennings Mac wird das Modell aufgerufen, und
    zwar von der vorbestehenden, gegateten Suite FocusBloxCalibrationTests aus den Tickets 23 und
    41, belegt durch 59 Zeilen "Model Catalog error" zwischen Logzeile 311 und 488.
  Spec requirement: AC-9, ohne dass im gesamten Testlauf FoundationModelsEnricher.enrich
    aufgerufen oder mit einem Geraet kommuniziert wird.
  Conflict: Die woertliche Lesart "gesamter Testlauf" ist mit der Spec selbst unvereinbar, denn
    ihr Testplan verlangt gleichzeitig, dass die bestehenden Suiten gruen bleiben, und
    FocusBloxCalibrationTests ist per Konstruktion eine Modellmessung. Die einzige kohaerente
    Lesart ist "aus diesem Schnitt heraus kein Modellaufruf", und die ist bewiesen. Kein Defekt
    dieses Schnitts, sondern eine zu weit gefasste Formulierung im AC.
  Remediation: AC-9 im Changelog praezisieren auf "kein Modellaufruf aus RuleLeaveOneOutTests und
    RuleLeaveOneOutReportTests". Kein Codeeingriff.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsTests/RuleLeaveOneOutTests.swift:343
  Description: Der Bericht-Test schreibt den Messtag in den Bericht und prueft danach mit einem
    zweiten Aufruf derselben Hilfsfunktion, dass er drinsteht. Laeuft der Test ueber Mitternacht,
    liefern die zwei Aufrufe verschiedene Tage und der Test schlaegt fehl, ohne dass etwas kaputt
    ist.
  Spec requirement: AC-9. Der Bericht soll den Messtag tragen, eine Zusicherung darauf fordert
    die Spec nicht.
  Conflict: Kein Spec-Verstoss, aber eine zeitabhaengige Zusicherung in einem sonst vollstaendig
    deterministischen Test.
  Remediation: Den Tag einmal in eine Konstante legen und beide Stellen daraus bedienen.

## Was NICHT gefunden wurde, obwohl gezielt gesucht

- Kein Pfad, der leere Kontextlisten wieder als Klasse hereinlaesst.
- Keine leeren Strings in durationTruth oder energyTruth im Korpus.
- Kein ignoriertes k.
- Kein hartkodierter Prozentwert und kein hartkodierter Klassenname mit Ergebniswirkung.
- Keine Abhaengigkeit von der Set-Iterationsreihenfolge, bewiesen durch den zweiten Prozess mit
  identischen Bytes.
- Keine Geraetekommunikation und kein Modellaufruf aus diesem Schnitt.
- Keine Regression: 198 Tests in 43 Suiten gruen, MeasurementFieldScopeTests deckt die neue Datei
  ab (LooseEndsTests/MeasurementFieldScopeTests.swift:32-37), kein Produktpfad beruehrt.

═══════════════════════════════════════
VERDICT: AMBIGUOUS
═══════════════════════════════════════

Alle neun Acceptance Criteria sind buchstabengetreu erfuellt und doppelt belegt: voller Testlauf
gruen mit 198 Tests in 43 Suiten und null Fehlschlaegen, und jede Berichtszahl unabhaengig
nachgerechnet. Determinismus, Leerlisten-Fix, k-Wirksamkeit sowie das Fehlen von Modell- und
Geraeteaufruf sind bewiesen.

Ambiguous bleibt F001. Der Bericht ist rechnerisch richtig, aber seine Kernaussage "Kontexte:
erfuellt" und "Dauer: erfuellt" wird zu 64 beziehungsweise 88 Prozent der entscheidenden b-Faelle
von exakt textgleichen Aufgaben getragen. Entdupliziert verliert die Regel auf allen drei
Merkmalen gegen die Konstante. Ob das ein Erfolg ist, weil wiederkehrende Erfassungen zuverlaessig
zugeordnet werden, oder ein Artefakt, weil Wortueberlappung nicht generalisiert, ist eine
Produktfrage und keine technische. Und sie steht nicht im Bericht, obwohl Henning auf dieser
Grundlage ueber ADR-5 und Ticket 112 entscheiden soll.

Bewiesene Punkte: 9 von 9
Tests: 198 passed, 0 failed, plus Gegenprobe-Lauf mit 1 passed, 0 failed
Findings: F001 HIGH, Berichtsaussage ohne den entscheidenden Vorbehalt. F002 LOW,
  AC-9-Formulierung zu weit gefasst. F003 LOW, zeitabhaengige Zusicherung.
Empfehlung: F001 vor dem Merge klaeren, entweder durch die vierte Grenze plus die
Entduplizierungszahlen im Bericht, rund zehn Zeilen im Bericht-Test und kein Eingriff in
LeaveOneOut, oder Henning entscheidet ausdruecklich, dass die Wiederholungen mitgezaehlt werden,
und genau das steht dann im Bericht.

## Geprüfte Dateien

- sha256:05a94f69aa123e16add92386c4d3b1e246d3c74920c2c8136733890762ce6266  LooseEndsTests/FocusBloxCalibrationTests.swift
- sha256:032efefcac2e06ee59dedd2511a328ab3ed97bcb6578e9717ad2d09ca32481b2  LooseEndsTests/RuleLeaveOneOutTests.swift
- sha256:7bf00def07736c11a095328ac8bec1cfc034047cecb372175070abd9a162596c  Measurement/LeaveOneOut.swift

---

**Hinweis:** Der Verdict AMBIGUOUS oben schliesst Runde 1 und 2 ab. Fuer den Stand nach Fix-Loop 1
gilt der Verdict am Ende dieses Dokuments (Runde 4).

### Runde 3 — Fix-Loop 1 nachgeprueft: Gegenprobe, Determinismus, unveraenderte Logik

Zweite Gegenpruefung, kontext-isoliert. Geprueft wurde ausschliesslich gegen Spec, Code und eigene
Nachrechnung, nicht gegen die Begruendung des Implementierers.

1. Voller Testlauf erneut gefahren: "Test run with 198 tests in 43 suites passed after 15.724
   seconds", null Fehlschlaege, uebersprungen nur die gegatete SelfConsistencyReportTests.
   Rohlog: docs/artifacts/spike-69-auslasstest-retrieval/adversary-round3-test-output.txt
   und /tmp/adversary_test_output.txt.
2. Danach ein zweiter, getrennter Prozess mit ausschliesslich RuleLeaveOneOutReportTests
   (18:37:20). Auch dort gruen, und im Rohlog null Zeilen "Model Catalog".
3. Die gesamte Gegenprobe-Rechnung unabhaengig in Python nachgebaut, einschliesslich
   Entduplizierung, Nachbarsuche, Nulllinie, Sätze ohne Nachbarn, Quote unter beantworteten und
   exaktem McNemar. Skript:
   docs/artifacts/spike-69-auslasstest-retrieval/adversary-dedup-recompute.py.

- [x] F001 behoben: die Gegenprobe steht im geschriebenen Bericht, mit allen Pflichtspalten
- [x] Alle 18 Gegenprobe-Zahlen unabhaengig nachgerechnet und identisch
- [x] Vierte Grenze vorhanden und benennt das Problem, ohne es zu beschoenigen
- [x] Entduplizierung exakt textgleich, nicht fuzzy, Vertreterwahl deterministisch
- [x] Determinismus empirisch: zwei getrennte Prozesse schreiben den Bericht byte-identisch
- [x] F003 behoben: Messtag einmal gebildet, zweimal benutzt
- [x] AC-1 bis AC-8 unberuehrt, Measurement/LeaveOneOut.swift byte-identisch zu Runde 1
- [x] Voller Testlauf gruen, 198 Tests in 43 Suiten, null Fehlschlaege

Confirmation:
  AC: F001 (Remediation aus Runde 2)
  Code reference: LooseEndsTests/RuleLeaveOneOutTests.swift:313-329
  Evidence: Der Bericht-Test schreibt die Sektion "Gegenprobe ohne Textdubletten (k = 1)" mit
    demselben Spaltenkopf wie die Haupttabelle und einer Zeile je Merkmal, erzeugt aus demselben
    line-Helfer. Im geschriebenen Bericht belegt:
    docs/reference/retrieval-leave-one-out-rules.md:35-44. Alle von der Remediation geforderten
    Werte stehen dort: n, Trefferquote, Quote unter beantworteten, Sätze ohne Nachbarn, Nulllinie,
    Abstand, b, c, p-Wert und Urteil. Zusicherung, dass die Sektion tatsaechlich in der Datei
    landet und nicht nur gerechnet wird: LooseEndsTests/RuleLeaveOneOutTests.swift:376-377.
  Status: CONFIRMED

Confirmation:
  AC: Gegenprobe-Zahlen (unabhaengige Nachrechnung)
  Code reference: docs/reference/retrieval-leave-one-out-rules.md:42-44
  Evidence: Eigene Python-Implementierung, getrennt geschrieben, trifft jede Zahl:
    Kontexte n = 50, 30,0 Prozent gegen Nulllinie 32,0 Prozent, Abstand minus 2,0, b = 6, c = 7,
    p = 1,0000, 23 Sätze ohne Nachbarn, 55,6 Prozent unter den beantworteten.
    Dauer n = 115, 32,2 gegen 56,5 Prozent, Abstand minus 24,3, b = 12, c = 40, p = 0,0001,
    32 ohne Nachbarn, 44,6 Prozent.
    Energie n = 119, 49,6 gegen 83,2 Prozent, Abstand minus 33,6, b = 2, c = 42, p = 0,0000,
    32 ohne Nachbarn, 67,8 Prozent.
    Zusaetzlich die Jaccard-1,0-Anteile der vierten Grenze: 58,7 Prozent (61 von 104),
    61,2 Prozent (169 von 276), 47,9 Prozent (101 von 211) — exakt die Werte im Bericht
    (docs/reference/retrieval-leave-one-out-rules.md:70-72). Kontrolle ueber k = 3 und k = 5 auf
    den entduplizierten Pools ebenfalls gerechnet: das Urteil bleibt auf allen drei Merkmalen und
    allen drei k "nicht erfuellt", die Gegenprobe ist also nicht k-abhaengig guenstig gewaehlt.
  Status: CONFIRMED

Confirmation:
  AC: Entduplizierung korrekt und deterministisch
  Code reference: LooseEndsTests/RuleLeaveOneOutTests.swift:225-230
  Evidence: Der Schluessel ist der getrimmte, kleingeschriebene Text, also exakte Stringgleichheit
    nach Trimmen und Kleinschreiben. Keine Fuzzy-Gruppierung, keine Wortmengen-, Praefix- oder
    Aehnlichkeitsheuristik, die zu viel zusammenfassen koennte. Das Kleinschreiben in Swift ist
    gebietsunabhaengig, also kein Tuerkisch-I-Effekt.
    Determinismus: das Set dient nur der Mitgliedschaftspruefung, die Reihenfolge kommt aus dem
    Array-filter, also aus der Korpus-Reihenfolge. Der erste Vertreter gewinnt. Keine Stelle
    iteriert ueber ein Set oder Dictionary.
    Empirisch bewiesen: zwei getrennte Prozesse (voller Lauf 18:25, isolierter Lauf 18:37)
    schreiben den Bericht byte-identisch, SHA-256
    a9de83bcff546157f782d2c8d4195508fd68952b5d8a30a3037a426764851968 in beiden Faellen. Ein
    zweiter Prozess hat einen anderen Set-Hash-Seed; haenge irgendeine Zahl an der
    Set-Iterationsreihenfolge, waere der Bericht abgewichen. Mein Python-Nachbau liefert mit
    PYTHONHASHSEED 1 dieselben Vertreter-ids wie mit dem Standard-Seed.
    Gegenprobe gegen Uebergruppierung: eine zweite, unabhaengige Gruppierung nach normalisierter
    Wortmenge statt nach Text ergibt exakt dieselben Pool-Groessen 50, 115, 119 UND dieselbe
    Vertreterliste. Der Textschluessel fasst also genau die Jaccard-1,0-Gruppen zusammen, nicht
    mehr, und im entduplizierten Pool bleibt kein Jaccard-1,0-Paar uebrig.
  Status: CONFIRMED

Confirmation:
  AC: Vierte Grenze benennt das Problem
  Code reference: LooseEndsTests/RuleLeaveOneOutTests.swift:357-363
  Evidence: Die Grenze steht fett als "Der Korpus enthält große Gruppen exakt textgleicher
    Aufgaben", nennt die drei gemessenen Anteile, sagt ausdruecklich "fuer sie ist die Nachbarsuche
    Wiedererkennung desselben Titels, keine Ähnlichkeitsaussage" und stellt "wiederkehrende" gegen
    "neu formulierte" Aufgaben. Dazu der Satz im Urteilsabschnitt
    (docs/reference/retrieval-leave-one-out-rules.md:55-56): das Urteil gilt fuer den vollen Pool,
    die Gegenprobe faellt anders aus, "wer nur das Urteil liest, liest halb". Kein Beschoenigen:
    die Gegenprobe-Tabelle steht im Bericht selbst, nicht nur als Fussnote.
    Einzige verbleibende Luecke, bewusst nicht als Finding gefuehrt, weil die Remediation aus
    Runde 2 sie nicht verlangt: der Bericht quantifiziert nicht, dass 16 der 25 b-Faelle bei
    Kontexten und 89 der 101 bei Dauer Jaccard-1,0-Faelle sind. Die Gegenprobe-Tabelle macht den
    Effekt direkt sichtbar, damit ist die Information nicht verborgen.
  Status: CONFIRMED

Confirmation:
  AC: F003 behoben
  Code reference: LooseEndsTests/RuleLeaveOneOutTests.swift:207
  Evidence: Der Messtag wird einmal in die Konstante day gelegt und an beiden Stellen daraus
    bedient, im Berichtskopf (:263) und in der Zusicherung (:374). Kein zweiter Date-Aufruf, die
    Mitternachtsfalle ist weg.
  Status: CONFIRMED

Confirmation:
  AC: AC-1 bis AC-8 unberuehrt
  Code reference: Measurement/LeaveOneOut.swift:11
  Evidence: SHA-256 der Datei ist 7bf00def07736c11a095328ac8bec1cfc034047cecb372175070abd9a162596c
    und damit byte-identisch zu dem in Runde 1 gestempelten Wert. Kein Zeichen der Logik hat sich
    geaendert, alle acht Logik-Tests laufen unveraendert gruen (Rohlog Zeilen 646 bis 665).
    Zusaetzlich ist ein neunter Logik-Test fuer die leere Kontextliste dabei, ebenfalls gruen.
    Der 118er-Waechter deckt die neue Datei weiterhin ab
    (LooseEndsTests/MeasurementFieldScopeTests.swift:32-37).
  Status: CONFIRMED

### Runde 4 — was der Pflichttausch gekostet hat

Die wichtigste Frage dieser Runde: Der Bericht hat die Kontext-Nebenspalten "enthält erwarteten
Kontext" und "Jaccard-Mittel" verloren. AC-9 nennt sie ausdruecklich als Pflichtinhalt. Die Spec
erlaubt im Abschnitt "Geschätzter Umfang" als Streichposten (1) genau diese zwei Nebenmetriken —
aber nur "bei Überschreitung" der LoC-Grenze. Ich habe deshalb beides geprueft: was der Bericht
noch enthaelt, und ob die Bedingung fuer den Streichposten ueberhaupt erfuellt ist und ihr Zweck
erreicht wurde.

Ergebnis: Die Bedingung ist erfuellt, sogar deutlich. Der Zweck ist es nicht. Der Schnitt liegt
nach dem Streichen weiter bei rund 569 neuen Codezeilen gegen den Abzweigpunkt, also mehr als dem
Doppelten der Grenze. Die freigewordenen rund 15 Zeilen sind nicht in die Einhaltung der Grenze
geflossen, sondern in eine Berichtssektion, die die Spec nirgends verlangt. Die weiteren
Streichposten (2) k-Kurve auf k = 3 verkuerzen und (3) den Schnitt teilen wurden nicht angewandt.
Damit steht eine freigegebene Spec, deren AC-9 und deren Definition of Done ("AC-1 bis AC-9
erfüllt") der gelieferte Bericht nicht erfuellt, und nichts im Repo haelt diesen Tausch fest.

- [x] Nichts ausser dem Bericht verweist auf die entfernten Nebenspalten
- [x] Keine Zusicherung ist mit ihnen verloren gegangen
- [x] Keine Regression durch den Tausch, 198 Tests gruen, keine Compiler-Warnung
- [x] AC-9 Restklauseln geprueft: Pflichtspalten, Urteil, kein Modell- und kein Geraeteaufruf
- [x] LoC-Grenze nachgerechnet: ueberschritten

Finding:
  ID: F004
  Severity: HIGH
  Category: spec_violation
  Code reference: LooseEndsTests/RuleLeaveOneOutTests.swift:313-329
  Description: An der Stelle, an der der Bericht-Test vorher die Sektion "Nebenspalten für
    Kontexte" mit den Spalten "enthält erwarteten Kontext" und "Jaccard-Mittel" fuer k = 1, 3, 5
    geschrieben hat, schreibt er jetzt die Gegenprobe-Sektion. Die zwei Nebenspalten sind
    vollstaendig entfernt, im Test und damit im Bericht: durchsucht wurden docs, LooseEndsTests,
    Measurement und scripts, kein Treffer fuer "Jaccard-Mittel" oder "erwarteten Kontext"
    ausserhalb der Spec, des Analyse-Kontexts und des Protokolls aus Runde 1.
    docs/reference/retrieval-leave-one-out-rules.md hat keine solche Sektion mehr.
  Spec requirement: AC-9 verlangt woertlich, dass der Bericht je eine Zeile pro Merkmal und k
    enthaelt und dazu die Kontext-Nebenspalten "enthält erwarteten Kontext" und "Jaccard-Mittel"
    (docs/specs/measurement/spike-69-regel-auslasstest.md:162-169). Die Definition of Done
    verlangt "AC-1 bis AC-9 erfüllt" (:395).
  Conflict: Der gelieferte Bericht erfuellt AC-9 nicht. Die Spec enthaelt zwar in
    docs/specs/measurement/spike-69-regel-auslasstest.md:217-219 eine ausdrueckliche Erlaubnis,
    genau diese zwei Nebenmetriken als Erstes zu streichen, aber unter der Bedingung
    "bei Überschreitung" der LoC-Grenze und mit dem Zweck, die Grenze einzuhalten. Nachgerechnet:
    gegen den Abzweigpunkt 07a22ab stehen 382 neue Zeilen in
    LooseEndsTests/RuleLeaveOneOutTests.swift, 7 in
    LooseEndsTests/MeasurementFieldScopeTests.swift und 180 in der noch nicht versionierten
    Measurement/LeaveOneOut.swift, zusammen 569 Zeilen bei einer Grenze von 250. Die Bedingung
    greift also, der Zweck wird aber verfehlt: nach dem Streichen ist der Schnitt netto um 69
    Zeilen groesser als vorher, und die Streichposten (2) und (3) blieben unangetastet. Der
    Streichposten wurde damit nicht als Notbremse benutzt, sondern als Waehrung, um eine von der
    Spec nicht verlangte Sektion zu bezahlen. Ob das zulaessig ist, entscheidet nicht der
    Implementierer und nicht ich: die Spec ist freigegeben, ihr AC-9 und ihre Definition of Done
    sind unveraendert, und der Tausch ist nirgends dokumentiert. Sachlich kostet der Verlust nichts
    — die Spec selbst sagt, auf diese zwei Zahlen stuetzt sich keine Entscheidung, und ich habe
    nachgewiesen, dass kein anderer Test und kein anderes Dokument sie liest. Formal ist es
    trotzdem eine offene AC-Verletzung.
  Remediation: Zwei gleichwertige Wege, beide billig. Entweder die rund 15 Zeilen Nebenspalten
    zurueckholen (der Bericht bekommt dann eine dritte kleine Tabelle, die Zahlen dafuer sind
    bekannt: 73,1 Prozent "enthält erwarteten Kontext" und 72,6 Prozent Jaccard-Mittel fuer alle
    drei k, in Runde 1 unabhaengig nachgerechnet). Oder AC-9 mit dem PO praezisieren und den
    Tausch samt LoC-Begruendung in den Spec-Changelog schreiben, so wie die Spec ihre vier
    bisherigen Korrekturen dokumentiert hat. Kein Eingriff in Measurement/LeaveOneOut.swift in
    beiden Faellen.

Finding:
  ID: F005
  Severity: MEDIUM
  Category: anti_pattern
  Code reference: Measurement/LeaveOneOut.swift:1
  Description: Der Schnitt ueberschreitet die in der Spec zugesagte LoC-Grenze deutlich. Gegen den
    Abzweigpunkt 07a22ab (main) stehen 569 neue Codezeilen: 180 in Measurement/LeaveOneOut.swift,
    382 in LooseEndsTests/RuleLeaveOneOutTests.swift, 7 in
    LooseEndsTests/MeasurementFieldScopeTests.swift. Rechnet man streng Additions plus Deletions,
    kommen die 37 in Fix-Loop 1 ersetzten Zeilen hinzu, also 606 beruehrte Zeilen. Die Zahl 249,
    die den Schnitt knapp innerhalb der Grenze erscheinen laesst, entsteht nur, wenn man die 313
    Zeilen des eigenen RED-Test-Commits 807b6fa als vorbestehenden Bestand behandelt. Sie gehoeren
    zum selben Ticket 131 und damit in dieselbe Rechnung.
  Spec requirement: docs/specs/measurement/spike-69-regel-auslasstest.md:216 sagt, die LoC seien
    geschaetzt rund 240 und damit an der Obergrenze der 250-LoC-Grenze, aber innerhalb; CLAUDE.md
    setzt 250 LoC je Aenderung als Grenze.
  Conflict: Tatsaechlich sind es rund 569 Zeilen, also mehr als das Doppelte des Zugesagten. Kein
    Funktionsfehler, aber der Punkt, an dem laut Spec die Streichreihenfolge greift, und die wurde
    nur bei Posten (1) angewandt. Ohne diesen Befund liest sich die Entfernung der Nebenspalten als
    freie Entscheidung, obwohl sie an eine Bedingung gebunden ist, die zwar erfuellt, aber nicht
    aufgeloest wurde.
  Remediation: Entscheidung des Tech Leads, nicht von mir: entweder die Ueberschreitung mit
    Begruendung im Spec-Changelog festhalten (Messcode, kein Produktpfad, Risiko niedrig), oder
    Streichposten (2) anwenden und die k-Kurve auf k = 3 verkuerzen. In jedem Fall gehoert die
    tatsaechliche Zahl in die Spec, nicht die geschaetzte.

Confirmation:
  AC: AC-9 (Restklauseln ausser den Nebenspalten)
  Code reference: LooseEndsTests/RuleLeaveOneOutTests.swift:272-306
  Evidence: Die Haupttabelle fuehrt weiterhin alle acht Pflichtspalten plus Urteil, je eine Zeile
    pro Merkmal und k, belegt in docs/reference/retrieval-leave-one-out-rules.md:23-33, und das
    Urteil je Merkmal in :51-53. Kein Modellaufruf aus diesem Schnitt: der isolierte Lauf mit
    ausschliesslich RuleLeaveOneOutReportTests enthaelt null Zeilen "Model Catalog". Im vollen Lauf
    liegen alle 118 Modellzeilen zwischen Logzeile 311 und 488, also innerhalb von
    FocusBloxCalibrationTests (Suite-Start 308, Suite-Ende 490); RuleLeaveOneOutReportTests laeuft
    ab Zeile 667. Keine Geraetekommunikation, der Lauf ist ein Simulator-Lauf auf dem Mac.
    Damit bleibt F002 aus Runde 2 unveraendert stehen: die woertliche Lesart "im gesamten
    Testlauf" ist eine Formulierungsfrage der Spec, kein Defekt dieses Schnitts.
  Status: CONFIRMED

Confirmation:
  AC: Keine Luecke durch den Pflichttausch
  Code reference: LooseEndsTests/MeasurementFieldScopeTests.swift:32-37
  Evidence: Gesucht, was die entfernten Nebenspalten geschuetzt haben koennten: nichts. Sie
    erzeugten keine Zusicherung, sondern nur zwei Tabellenzeilen. Der Spec-Testplan nennt sie in
    keinem seiner elf Faelle. Kein anderer Test liest den Bericht. Kein anderes Dokument unter
    docs/reference verweist auf sie. Die Spec selbst sagt, auf sie stuetzt sich keine Entscheidung.
    Die einzigen Verweise ausserhalb der Spec stehen im Analyse-Kontext und im Protokoll aus
    Runde 1, beide historisch. Der einzige Waechter, der etwas schuetzt, ist der 118er-Fall, und
    der greift unveraendert auf die neue Datei.
    Auch technisch keine Leiche: LeaveOneOut.jaccard und LeaveOneOut.contextClass bleiben benutzt,
    jaccard im identicalShare-Helfer, contextClass in contextValue. Keine Compiler-Warnung im
    Rohlog.
  Status: CONFIRMED

## Was in Runde 3 und 4 NICHT gefunden wurde, obwohl gezielt gesucht

- Keine Fuzzy-Gruppierung in der Entduplizierung und keine Uebergruppierung: die Gruppierung nach
  Text und die nach normalisierter Wortmenge liefern dieselben Vertreter.
- Keine Abhaengigkeit von einer Set- oder Dictionary-Reihenfolge: zwei getrennte Prozesse, gleiche
  Bytes, gleiche SHA-256.
- Keine abweichende Zahl: alle 18 Gegenprobe-Werte und die drei Jaccard-1,0-Anteile unabhaengig
  reproduziert.
- Keine Aenderung an Measurement/LeaveOneOut.swift, am Produktpfad oder an der Spec.
- Kein Modellaufruf und keine Geraetekommunikation aus diesem Schnitt.
- Kein Fehlschlag und keine Compiler-Warnung im vollen Lauf.

═══════════════════════════════════════
VERDICT: BROKEN
═══════════════════════════════════════

Finding F004: Der Bericht enthaelt die von AC-9 woertlich verlangten Kontext-Nebenspalten
  "enthält erwarteten Kontext" und "Jaccard-Mittel" nicht mehr.
  Severity: HIGH
  Evidence: LooseEndsTests/RuleLeaveOneOutTests.swift:313-329 (dort stand die Sektion),
    docs/reference/retrieval-leave-one-out-rules.md hat keine solche Sektion mehr,
    docs/specs/measurement/spike-69-regel-auslasstest.md:162-169 verlangt sie.
  Reproduktion: Unit-Tests laufen lassen, danach den geschriebenen Bericht nach "Jaccard-Mittel"
    durchsuchen — kein Treffer. Der Streichposten aus
    docs/specs/measurement/spike-69-regel-auslasstest.md:217-219 deckt die Streichung nur unter
    der Bedingung einer LoC-Ueberschreitung; die Bedingung ist erfuellt (569 statt 250 Zeilen),
    ihr Zweck aber nicht, weil der Schnitt nach dem Streichen groesser ist als vorher und die
    Streichposten (2) und (3) unangetastet blieben. Die freigegebene Spec ist nicht geaendert, die
    Definition of Done verlangt weiter AC-1 bis AC-9.

Finding F005: LoC-Grenze ueberschritten, 569 neue Codezeilen gegen 250 erlaubte.
  Severity: MEDIUM
  Evidence: Measurement/LeaveOneOut.swift 180 Zeilen neu,
    LooseEndsTests/RuleLeaveOneOutTests.swift 382 neu gegen 07a22ab,
    LooseEndsTests/MeasurementFieldScopeTests.swift 7 neu.
  Reproduktion: Zeilen-Diff gegen den Abzweigpunkt 07a22ab plus die Zeilenzahl der noch nicht
    versionierten Measurement/LeaveOneOut.swift.

Was haelt: alles andere. Voller Testlauf gruen mit 198 Tests in 43 Suiten und null
Fehlschlaegen. F001 aus Runde 2 ist behoben, die Gegenprobe steht mit allen Pflichtspalten im
geschriebenen Bericht und jede ihrer 18 Zahlen ist unabhaengig nachgerechnet. Die vierte Grenze
benennt die Textdubletten deutlich. F003 ist behoben. Die Entduplizierung ist exakt, nicht fuzzy,
und deterministisch, empirisch belegt durch zwei byte-identische Berichte aus getrennten
Prozessen. Measurement/LeaveOneOut.swift ist byte-identisch zu Runde 1, AC-1 bis AC-8 sind
unberuehrt. F002 bleibt wie vereinbart als Spec-Formulierungsfrage offen und ist kein Defekt.

Bewiesene Punkte: 8 von 9 AC vollstaendig, AC-9 in allen Klauseln ausser den Nebenspalten.
Tests: 198 passed, 0 failed, plus isolierter Gegenprobe-Lauf 1 passed, 0 failed.
Empfehlung: F004 vor dem Merge aufloesen — entweder die rund 15 Zeilen Nebenspalten zurueckholen
oder AC-9 mit dem PO praezisieren und den Tausch samt LoC-Zahl in den Spec-Changelog schreiben.
F005 als Tech-Lead-Entscheidung im Changelog festhalten.

## Geprüfte Dateien

- sha256:05a94f69aa123e16add92386c4d3b1e246d3c74920c2c8136733890762ce6266  LooseEndsTests/FocusBloxCalibrationTests.swift
- sha256:f57e790dfbb9a7053ea1a180849ddce133a44ac2307f4b23776b74e40e086d81  LooseEndsTests/MeasurementFieldScopeTests.swift
- sha256:d06af27528a5aef5873e9def6960edf4ab47272cca49967520e7960c490a9619  LooseEndsTests/RuleLeaveOneOutTests.swift
- sha256:7bf00def07736c11a095328ac8bec1cfc034047cecb372175070abd9a162596c  Measurement/LeaveOneOut.swift
- sha256:a9de83bcff546157f782d2c8d4195508fd68952b5d8a30a3037a426764851968  docs/reference/retrieval-leave-one-out-rules.md

---

**Hinweis:** Der Verdict BROKEN oben schliesst Runde 3 und 4 ab. Fuer den Stand nach Fix-Loop 2
gilt der Verdict am Ende dieses Dokuments (Runde 5).

### Runde 5 — Fix-Loop 2 nachgeprueft: sind die Nebenspalten zurueck, und rechnen sie richtig

Dritte Gegenpruefung, eng auf F004 und die Nebenwirkungen des Zurueckholens gefasst. Geprueft
wurde gegen Spec, Code, geschriebenen Bericht und eigene Nachrechnung, nicht gegen die
Begruendung des Implementierers.

Wie geprueft wurde:

1. Voller Testlauf ueber scripts/sim.sh unit, Destination platform=macOS, also kein Simulator und
   kein Geraet. Rohlog: docs/artifacts/spike-69-auslasstest-retrieval/_adversary_round5_run.log,
   Kopie in /tmp/adversary_test_output.txt.
2. Danach ein zweiter, getrennter Prozess mit ausschliesslich RuleLeaveOneOutReportTests
   (docs/artifacts/spike-69-auslasstest-retrieval/_adversary_round5_isolated.log) und ein dritter
   nach dem Zurueckspielen der Datei
   (docs/artifacts/spike-69-auslasstest-retrieval/_adversary_round5_restore.log).
3. Die Nebenspalten unabhaengig in Python nachgebaut und bewusst gegen drei Fehlervarianten
   gerechnet, damit ein durchschlagender 287er-Pool nicht unentdeckt bleiben kann. Skript:
   docs/artifacts/spike-69-auslasstest-retrieval/adversary-sidecolumn-recompute.py.
4. Haupttabelle und Gegenprobe erneut komplett nachgerechnet
   (adversary-recompute.py und adversary-dedup-recompute.py).
5. Mutationstest: der Bericht-Test wurde in drei Varianten absichtlich kaputtgemacht und jede
   Variante gefahren, um zu messen, ob die neuen Zusicherungen wirklich beissen. Danach wurde die
   Datei aus einer Sicherung zurueckgespielt und per SHA-256 als byte-identisch bestaetigt.
   Rohlogs: _mutation_drop_append.log, _mutation_pool287.log, _mutation_neighbourpool.log.

- [x] F004 behoben: beide Nebenspalten stehen im GESCHRIEBENEN Bericht, je eine Zeile fuer k = 1, 3, 5
- [x] AC-9 Klausel fuer Klausel durchgegangen, jede Klausel belegt
- [x] Nebenspalten rechnen auf dem korrigierten Pool 104, nicht auf 287: 73,1 Prozent und 72,6 Prozent unabhaengig reproduziert
- [x] 287er-Pool positiv ausgeschlossen: jede Fehlervariante liefert nachweislich andere Zahlen
- [x] F001-Behebung intakt: Gegenprobe, vierte Grenze, Urteilszusatz, Pool-Zusicherungen 50, 115, 119 unveraendert
- [x] Alle 27 Werte der Haupttabelle und alle 18 der Gegenprobe erneut unabhaengig nachgerechnet
- [x] Die neuen Zusicherungen greifen: im Mutationstest wird der Test rot, wenn die Nebenspalten aus dem Bericht fallen
- [x] Voller Testlauf gruen: 198 Tests in 43 Suiten, null Fehlschlaege, keine Compiler-Warnung
- [x] Determinismus: drei getrennte Prozesse schreiben den Bericht byte-identisch, gleiche SHA-256
- [x] Kein Modellaufruf und keine Geraetekommunikation aus diesem Schnitt
- [x] Measurement/LeaveOneOut.swift byte-identisch zum gestempelten Hash, AC-1 bis AC-8 unberuehrt
- [x] Bericht als Ganzes gelesen: keine doppelte, widerspruechliche oder verwaiste Aussage

Confirmation:
  AC: AC-9, Klausel "Kontext-Nebenspalten enthaelt erwarteten Kontext und Jaccard-Mittel"
  Code reference: LooseEndsTests/RuleLeaveOneOutTests.swift:331-362
  Evidence: Der Bericht-Test schreibt die Sektion mit Ueberschrift, Kopfzeile und einer Zeile je k
    aus kValues. Im geschriebenen Bericht belegt:
    docs/reference/retrieval-leave-one-out-rules.md:46-57 — Ueberschrift auf :46, Kopfzeile auf
    :53, die drei Zeilen fuer k = 1, 3, 5 auf :55, :56, :57 mit 73,1 Prozent und 72,6 Prozent.
    Beide von AC-9 woertlich genannten Spaltennamen stehen unveraendert in der Kopfzeile. Damit
    ist die in Runde 4 als F004 gemeldete Luecke geschlossen. Die Sektion ist nicht die alte aus
    der Historie: sie ruft LeaveOneOut.contextValue statt contextsTruth.map(contextClass) und
    traegt einen zusaetzlichen Satz, der den Pool ausdruecklich benennt (:50-51).
  Status: CONFIRMED

Confirmation:
  AC: AC-9, Nebenspalten rechnen auf dem korrigierten Pool 104
  Code reference: LooseEndsTests/RuleLeaveOneOutTests.swift:344-361
  Evidence: Die Schleife iteriert contextPool (:348), sucht die Nachbarn im contextPool (:350),
    bildet Wahrheit und Vorhersage ueber LeaveOneOut.contextValue (:349, :351-353) und teilt durch
    contextPool.count (:358). contextPool ist der contextValue-Filter (:211) und per Zusicherung
    104 Eintraege (:219).
    Unabhaengige Nachrechnung in Python, getrennt geschrieben, gegen drei Fehlervarianten
    gerechnet:
    korrekt, Pool 104, ergibt 73,1 Prozent und 72,6 Prozent fuer k = 1, 3 und 5 — exakt die drei
    Berichtszeilen.
    Variante A, alle 287 als Pool und Nenner, ergibt 19,5 dann 23,7 dann 24,4 Prozent.
    Variante B, 287 als Nachbarpool bei Nenner 104, ergibt 53,8 dann 65,4 dann 67,3 Prozent.
    Variante C, Filter auf contextsTruth nicht null statt contextValue (der Ursprungsdefekt dieses
    Tickets), ergibt dieselben Zahlen wie A, weil der Export die leere Liste statt null schreibt.
    Keine dieser Fehlervarianten liegt in der Naehe der Berichtszahlen. Der 287er-Pool ist damit
    nicht nur nicht sichtbar, sondern positiv ausgeschlossen.
    Rohausgabe reproduzierbar ueber
    docs/artifacts/spike-69-auslasstest-retrieval/adversary-sidecolumn-recompute.py.
  Status: CONFIRMED

Confirmation:
  AC: AC-9, uebrige Klauseln (Pflichtspalten, Urteil, kein Modell, kein Geraet)
  Code reference: LooseEndsTests/RuleLeaveOneOutTests.swift:272-306
  Evidence: Klausel fuer Klausel, jede an der geschriebenen Datei belegt:
    (1) Korpus liegt lokal vor, 287 Aufgaben, die gegatete Suite lief (Rohlog Zeile 247 bis 249),
    war also nicht uebersprungen.
    (2) Die Datei docs/reference/retrieval-leave-one-out-rules.md wird geschrieben (:400) und zur
    Pruefung zurueckgelesen (:402).
    (3) Je eine Zeile pro Merkmal und k: neun Zeilen auf
    docs/reference/retrieval-leave-one-out-rules.md:25-33.
    (4) Alle acht Pflichtspalten plus Urteil in der Kopfzeile auf :23 und in jeder Zeile gefuellt:
    verbindliche Trefferquote, Trefferquote unter den beantworteten Saetzen, Saetze ohne Nachbarn,
    Nulllinie, b, c, p-Wert, Erfuellt-Aussage; die Spalte Abstand kommt als Zusatz dazu.
    Erneut unabhaengig nachgerechnet, alle 27 Werte treffen: Kontexte 72,1 Prozent bei 88,2
    Prozent, 19 ohne Nachbarn, Nulllinie 56,7 Prozent, b = 25, c = 9, p = 0,0090 fuer alle drei k;
    Dauer 73,9 dann 72,1 dann 72,1 Prozent mit b = 101, 98, 97; Energie 60,2 dann 59,7 dann 59,2
    Prozent mit b = 2, 0, 16.
    (5) Nebenspalten: siehe die zwei Confirmations davor.
    (6) Kein Modellaufruf aus diesem Schnitt: der isolierte Lauf mit ausschliesslich
    RuleLeaveOneOutReportTests enthaelt null Zeilen "Model Catalog", gezaehlt im Rohlog
    _adversary_round5_isolated.log. Keine Geraetekommunikation: cmd_unit in scripts/sim.sh:172
    fuehrt den Lauf gegen platform=macOS, kein Simulator, kein devicectl, kein gepaartes iPhone.
    F002 bleibt davon unberuehrt als Formulierungsfrage der Spec.
  Status: CONFIRMED

Confirmation:
  AC: F001-Behebung intakt geblieben
  Code reference: LooseEndsTests/RuleLeaveOneOutTests.swift:313-329
  Evidence: Die Gegenprobe-Sektion steht unveraendert vor den Nebenspalten und schreibt
    docs/reference/retrieval-leave-one-out-rules.md:35-44. Alle 18 Werte erneut unabhaengig
    nachgerechnet und identisch zu Runde 3: Kontexte n = 50, 30,0 Prozent, 55,6 Prozent, 23 ohne
    Nachbarn, Nulllinie 32,0 Prozent, Abstand minus 2,0, b = 6, c = 7, p = 1,0000. Dauer n = 115,
    32,2 Prozent, 44,6 Prozent, 32 ohne Nachbarn, 56,5 Prozent, minus 24,3, b = 12, c = 40,
    p = 0,0001. Energie n = 119, 49,6 Prozent, 67,8 Prozent, 32 ohne Nachbarn, 83,2 Prozent,
    minus 33,6, b = 2, c = 42, p = 0,0000.
    Die Pool-Zusicherungen 50, 115, 119 stehen weiter im Test (:235-237), die vierte Grenze mit
    58,7 dann 61,2 dann 47,9 Prozent im Bericht (:83-89), der Urteilszusatz "wer nur das Urteil
    liest, liest halb" auf :68-69. Die Entduplizierung ist unveraendert exakt nach getrimmtem,
    kleingeschriebenem Text (:225-230); die Kontrollgruppierung nach normalisierter Wortmenge
    liefert erneut dieselben Pool-Groessen und dieselben Vertreter-ids.
  Status: CONFIRMED

Confirmation:
  AC: Die neuen Zusicherungen greifen wirklich (Mutationstest)
  Code reference: LooseEndsTests/RuleLeaveOneOutTests.swift:411-416
  Evidence: Nicht nur gelesen, sondern gemessen. Variante 1: die Anweisung, die die Nebenspalten
    an den Bericht haengt, wurde entfernt. Ergebnis: Suite RuleLeaveOneOutReportTests failed,
    "Expectation failed: written.contains(sideColumns)" an RuleLeaveOneOutTests.swift:415
    (Rohlog _mutation_drop_append.log, Zeile 24 bis 26). Die Nebenspalten koennen also nicht noch
    einmal still aus dem Bericht fallen.
    Zweite Sperre unabhaengig davon: die Zusicherung auf :416 vergleicht die Zeilenzahl des Blocks
    mit der Zahl der k-Werte; ein Block mit null oder einer Zeile faellt dort auf, selbst wenn er
    im Bericht landet. Dritte und vierte Sperre: Ueberschrift (:413) und Kopfzeile (:414) mit den
    beiden von AC-9 woertlich genannten Spaltennamen.
    Kontrollmutation zur Abgrenzung: die Iteration von contextPool auf alle 287 umgestellt aendert
    keine Zahl, weil der guard auf contextValue (:349) die 183 Aufgaben ohne Kontext-Wahrheit
    ueberspringt und der Nachbarpool contextPool bleibt — die Sektion ist gegen genau diesen
    Fehlgriff also von sich aus unempfindlich (Rohlog _mutation_pool287.log).
  Status: CONFIRMED

Confirmation:
  AC: Determinismus mit der zusaetzlichen Sektion
  Code reference: docs/reference/retrieval-leave-one-out-rules.md:55
  Evidence: Vier Schreibvorgaenge aus drei getrennten Prozessen, alle byte-identisch, SHA-256
    ec829cb365a8ad0843855da17915718b79dc5f783c3b297cb5f753e948ca7c4e: der Stand vor meinem Lauf,
    mein voller Lauf um 19:21:36, mein isolierter Lauf um 19:25:35 und der Lauf nach dem
    Zurueckspielen der Datei. Ein zweiter Prozess hat einen anderen Set-Hash-Seed; haenge
    irgendeine Zahl der neuen Sektion an einer Set- oder Dictionary-Reihenfolge, waeren die Bytes
    auseinandergelaufen. Zusaetzlich per Code belegt: die Nebenspalten-Schleife laeuft ueber das
    Array kValues und ueber das Array contextPool, Mengen werden nur ueber count, intersection und
    union gelesen, nie iteriert.
  Status: CONFIRMED

Confirmation:
  AC: AC-1 bis AC-8 unberuehrt
  Code reference: Measurement/LeaveOneOut.swift:11
  Evidence: SHA-256 der Datei ist
    7bf00def07736c11a095328ac8bec1cfc034047cecb372175070abd9a162596c und damit byte-identisch zu
    dem in Runde 1 und Runde 3 gestempelten Wert. Fix-Loop 2 hat ausschliesslich
    LooseEndsTests/RuleLeaveOneOutTests.swift angefasst (127 neue, 19 ersetzte Zeilen). Die neun
    Logik-Tests laufen unveraendert gruen (Rohlog _adversary_round5_run.log, Zeile 236 bis 246),
    der 118er-Waechter deckt die Datei weiterhin ab (Zeile 171).
  Status: CONFIRMED

Confirmation:
  AC: Keine Regression durch das Zurueckholen, Bericht als Ganzes gelesen
  Code reference: docs/reference/retrieval-leave-one-out-rules.md:46-51
  Evidence: Der Bericht hat jetzt drei Tabellen und sechs Abschnitte in dieser Reihenfolge: Kopf,
    Ergebnis je Merkmal und k, Gegenprobe ohne Textdubletten, Nebenspalten fuer Kontexte, Urteil,
    Grenzen. Gezielt nach Widerspruechen gesucht:
    Keine doppelte Aussage. Die drei Tabellen rechnen verschiedene Dinge auf verschiedenen Pools,
    und jede sagt selbst, welchen: die Gegenprobe nennt ihre n-Werte in der Merkmalsspalte, die
    Nebenspalten nennen ihren Pool im Fliesstext (:50-51, "auf demselben Kontext-Pool wie die
    Haupttabelle, 104 Aufgaben mit Kontext-Wahrheit, nicht auf allen 287").
    Kein verwaister Verweis. Alle drei Ortsangaben im Bericht stimmen nach dem Einschub weiter:
    "Verbindlich ist allein die exakte Mengengleichheit oben" (:48) meint die Haupttabelle und ist
    im naechsten Satz an den Pool gebunden; "Die Gegenprobe ohne Textdubletten oben" (:68-69)
    steht im Urteilsabschnitt, die Gegenprobe steht tatsaechlich darueber; "beide Tabellen" (:89)
    bezieht sich auf die zwei im Satz davor genannten, Haupttabelle und Gegenprobe, und die
    Nebenspalten sind ausdruecklich als entscheidungsfrei markiert.
    Keine Leiche und keine Warnung: LeaveOneOut.jaccard, contextClass, contextValue, majority und
    neighbors sind alle weiter benutzt, im vollen Rohlog steht keine Compiler-Warnung.
    Die Spec schreibt fuer den Berichtsaufbau keine verbindliche Reihenfolge fest (Abschnitt
    Technische Umsetzung, Punkt 5 zaehlt Inhalte auf, anders als das ausdrueckliche
    "in dieser Reihenfolge" bei der Streichreihenfolge) — der Einschub der Gegenprobe vor die
    Nebenspalten verletzt also keine Zusage.
  Status: CONFIRMED

Finding:
  ID: F006
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsTests/RuleLeaveOneOutTests.swift:350
  Description: Keine Zusicherung bindet die WERTE der Nebenspalten an den Kontext-Pool. Gemessen,
    nicht vermutet: stellt man den Nachbarpool der Nebenspalten-Schleife von contextPool auf alle
    287 Eintraege um, schreibt der Bericht 53,8 dann 65,4 dann 67,3 Prozent statt dreimal 73,1 —
    und der Test bleibt gruen. Rohlog _mutation_neighbourpool.log, Suite passed, dazu der mutierte
    Berichtsauszug. Der Grund: die vier neuen Zusicherungen (:413-416) pruefen Ueberschrift,
    Kopfzeile, Zeilenanzahl und die Anwesenheit des Blocks, aber keine Zahl, und die
    Pool-Zusicherung 104 (:219) trifft nur contextPool selbst, nicht dessen Verwendung.
  Spec requirement: AC-9 verlangt die zwei Nebenspalten als Berichtsinhalt; eine Zusicherung auf
    ihre Zahlenwerte verlangt die Spec nicht, und die Spec sagt ausdruecklich, auf diese zwei
    Zahlen stuetzt sich keine Entscheidung
    (docs/specs/measurement/spike-69-regel-auslasstest.md:308-309).
  Conflict: Kein Spec-Verstoss und kein Defekt im gelieferten Stand — die Zahlen sind richtig,
    zweimal unabhaengig nachgerechnet. Es ist eine Luecke in der Absicherung: genau die
    Fehlerklasse, die dieses Ticket ausgeloest hat (ein zu grosser Kontext-Pool), koennte in
    dieser einen Sektion wiederkehren, ohne dass ein Test rot wird. Die Haupttabelle ist gegen
    denselben Fehlgriff besser geschuetzt, weil ihr Pool ueber die Groessenzusicherung laeuft.
  Remediation: Eine Zeile genuegt, zum Beispiel eine Zusicherung, dass die erste Nebenspalte
    mindestens so gross ist wie die exakte Trefferquote derselben k-Zeile, oder schlicht die
    Erwartung auf 73,1 Prozent wie bei den Pool-Groessen. Nicht blockierend: LOW, weil kein
    gelieferter Wert falsch ist.

## Was in Runde 5 NICHT gefunden wurde, obwohl gezielt gesucht

- Kein 287er-Pool in den Nebenspalten: alle drei Fehlervarianten liefern nachweislich andere Zahlen.
- Keine stille Streichmoeglichkeit mehr: der Mutationstest macht den Test rot.
- Keine veraenderte Zahl gegenueber Runde 3 in Haupttabelle, Gegenprobe und vierter Grenze.
- Keine Aenderung an Measurement/LeaveOneOut.swift, am Produktpfad, an der Spec oder an
  MeasurementFieldScopeTests.
- Kein Widerspruch, keine Dopplung und kein verwaister Verweis im Bericht nach dem Einschub.
- Kein Fehlschlag, keine Compiler-Warnung, kein Modellaufruf und keine Geraetekommunikation aus
  diesem Schnitt.

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════

F004 aus Runde 4 ist behoben und nachgewiesen, nicht nur behauptet. Die von AC-9 woertlich
verlangten Kontext-Nebenspalten stehen mit Ueberschrift, Kopfzeile und je einer Zeile fuer
k = 1, 3, 5 im geschriebenen Bericht, sie rechnen auf dem korrigierten Pool 104, und der
287er-Pool ist positiv ausgeschlossen: meine unabhaengige Nachrechnung trifft 73,1 Prozent und
72,6 Prozent auf den Punkt, waehrend jede der drei Fehlervarianten deutlich andere Zahlen ergibt.
AC-9 ist damit Klausel fuer Klausel erfuellt. Die F001-Behebung ist unveraendert intakt, alle 18
Gegenprobe-Werte und alle 27 Werte der Haupttabelle erneut unabhaengig reproduziert. Die neuen
Zusicherungen greifen nicht nur auf dem Papier: im Mutationstest wird der Test rot, sobald die
Nebenspalten aus dem Bericht fallen. Measurement/LeaveOneOut.swift ist byte-identisch zum
gestempelten Hash, AC-1 bis AC-8 sind unberuehrt.

Tests: 198 passed, 0 failed, 43 Suiten, null Compiler-Warnungen; dazu zwei isolierte Laeufe der
Bericht-Suite (je 1 passed, 0 failed) und drei Mutationslaeufe, von denen der entscheidende
erwartungsgemaess rot wurde.
Edge cases: Determinismus ueber drei getrennte Prozesse byte-identisch, Pool-Verwechslung gezielt
beschossen, Mitternachtsfalle weiter geschlossen, Leerlisten-Semantik unveraendert.
Regressionen: keine.
Checklist: AC-1 bis AC-9 bewiesen, 9 von 9.

Offen und ausdruecklich NICHT blockierend, im VERIFIED so festgehalten:
- F005 (MEDIUM, LoC-Ueberschreitung rund 569 gegen 250): vom Tech Lead bewusst stehen gelassen,
  reiner Messcode, kein Produktpfad, Risiko niedrig, wird dem PO offen gemeldet. Ich habe die Zahl
  in Runde 4 nachgerechnet und bewerte sie hier nicht erneut.
- F002 (LOW, AC-9-Formulierung "im gesamten Testlauf"): Formulierungsfrage der Spec, kein Defekt
  dieses Schnitts, Praezisierung in Phase 7.
- F006 (LOW, neu): keine Zusicherung auf die Zahlenwerte der Nebenspalten. Kein falscher Wert im
  gelieferten Stand, aber die Fehlerklasse dieses Tickets koennte dort unbemerkt wiederkehren.

## Geprüfte Dateien

- sha256:05a94f69aa123e16add92386c4d3b1e246d3c74920c2c8136733890762ce6266  LooseEndsTests/FocusBloxCalibrationTests.swift
- sha256:f57e790dfbb9a7053ea1a180849ddce133a44ac2307f4b23776b74e40e086d81  LooseEndsTests/MeasurementFieldScopeTests.swift
- sha256:ee90a96611ff10d347ffc093938802bc399c4db247296ad086e350069db6e7a2  LooseEndsTests/RuleLeaveOneOutTests.swift
- sha256:7bf00def07736c11a095328ac8bec1cfc034047cecb372175070abd9a162596c  Measurement/LeaveOneOut.swift
- sha256:ec829cb365a8ad0843855da17915718b79dc5f783c3b297cb5f753e948ca7c4e  docs/reference/retrieval-leave-one-out-rules.md

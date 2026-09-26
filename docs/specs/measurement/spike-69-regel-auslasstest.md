---
entity_id: spike-69-regel-auslasstest
type: feature
created: 2026-09-26
updated: 2026-09-26
status: draft
workflow: spike-69-auslasstest-retrieval
---

# Spec: Spike #69, Regel-Auslass-Test — Wortüberlappung als Nachbarsuche gegen die Konstante (#131)

**Status:** draft · **Workflow:** spike-69-auslasstest-retrieval · **Erstellt:** 2026-09-26 · **Aktualisiert:** 2026-09-26

## Freigabe

- [ ] Freigegeben

## Problem

Annahme B1 (`docs/project/06-annahmen-und-experimente.md:106-118,144`, „Retrieval lernt wirklich")
hat zwei Teile: den Konventionstest und den Auslass-Test. Ticket A (#69, geschlossen) hat nur den
Konventionstest beantwortet — die Regel-Baseline aus `Measurement/RuleBaseline.swift` erreichte
10/10 auf zehn eigens gebauten Mustern. Der Auslass-Test selbst ist nie gelaufen. Issue **#131**
(„Regel-Auslass-Test: schlägt Wortüberlappung als Nachbarsuche die Konstante?") ist der Nachfolger.

Die Analyse (`docs/context/spike-69-auslasstest-retrieval.md`) hat die Fragestellung verschoben,
bevor sie den Messaufbau festlegt. Stellt man die heutige Modellgüte neben die Nulllinie desselben
Feldes, ist das Modell auf **keinem** der beiden Felder, auf die #112 (Dauer und Energie) wartet,
besser als eine Konstante:

| Feld | Nulllinie | Modell heute | Abstand |
|---|---|---|---|
| Dauer | 51,1 % | 51 % | ±0 — das Modell liefert nichts über „immer minutes15" hinaus |
| Energie | 77,3 % | 25 % | **−52 Punkte** — „immer low" ist massiv besser als das Modell |
| Kontexte | 56,7 % | nie gemessen | unbekannt, weil das Vokabular in der Labor-App leer übergeben wird |

Damit lautet die Frage nicht mehr „helfen Beispiele dem Modell", sondern „kann irgendein
Nachbarschafts-Mechanismus überhaupt eine Konstante schlagen — und wenn ja, reicht dafür schon die
Regel, oder braucht es das Modell mit Beispielen". Nach `CLAUDE.md` („Regeln vor Modell", „Die
einfachste Lösung wird zuerst gebaut oder zuerst widerlegt") wird deshalb zuerst die Regel geprüft,
nicht das Modell. Ticket A hat den Regelweg nur auf zehn gebauten Mustern belegt — diese Zahl sagt
nichts darüber, wie die Regel auf Hennings echten 104 bis 276 Aufgaben trifft. Genau diese Zahl
fehlt, und sie ist ohne Modell, ohne Gerät und ohne Labor-App zu bekommen.

**PO-Entscheidung Henning, 2026-09-26:** „Erst die Regel, dann entscheiden." Alle drei Merkmale auf
dem Mac, keine Gerätezeit, kein Umbau der Labor-App.

## Zweck

Dieser Schnitt baut den Regel-Auslass-Test für alle drei lernbaren Felder (Kontexte, Dauer,
Energie) über den echten FocusBlox-Korpus: für jede Aufgabe werden die k ähnlichsten *anderen*
Aufgaben über Wortüberlappung gesucht, deren Werte entscheiden per Mehrheit, das Ergebnis wird
gegen die Wahrheit und gegen eine aus dem Korpus gerechnete Konstante gestellt — für k = 1, 3, 5.
Er liefert einen Bericht mit Trefferquote, Nulllinie, Sätzen ohne Nachbarn und einem
McNemar-Exakttest je Merkmal und k, sowie die vorab festgelegte Erfüllt/Nicht-erfüllt-Aussage, die
entscheidet, ob der Mechanismus „Wortüberlappung als Nachbarsuche" die Konstante schlägt. Das
Ergebnis ist die Entscheidungsvorlage für Henning, ob der Modell-Auslass-Test (rund 1,5 Stunden
Gerätezeit plus Umbau der Labor-App) noch eine Frage beantwortet, die das Produkt ändert. Nicht
Teil dieses Schnitts: der Modell-Auslass-Test selbst, jede Embedding-Anbindung, die Labor-App, und
die Entscheidung über ADR-5.

## Die Abbruchschwelle und ihre Herleitung

Verbindlich, vorab festgelegt: Die Regel schlägt die Konstante bei einem Merkmal, wenn bei
mindestens einem k ∈ {1, 3, 5} **beides** gilt — (a) Trefferquote ≥ Nulllinie + 10 Prozentpunkte
und (b) zweiseitiger McNemar-Exakttest gegen die Nulllinie mit p < 0,05.

Die beiden Hälften tun verschiedene Dinge, und das muss vor dem Lauf feststehen, sonst wird das
Ergebnis hinterher passend gelesen:

- **(b) p < 0,05 schützt gegen Zufall.** Regel und Konstante sind beide deterministisch, es gibt
  hier also kein Lauf-zu-Lauf-Rauschen wie beim Modell — die einzige Zufallsquelle ist die
  Stichprobe selbst. Genau dafür ist der gepaarte Test da.
- **(a) die 10 Prozentpunkte sind eine Produkt-Relevanzschwelle, keine statistische.** Sie ist eine
  Festlegung des Tech Leads, kein abgeleiteter Wert: Ein Vorsprung unter 10 Punkten würde an
  `EnrichmentCoordinator.examples(in:limit:)` nichts ändern, der Umbau lohnte sich nicht.

**Welche Hälfte bindet, hängt an der Stichprobengröße — nachgerechnet, nicht geschätzt:**

| Merkmal | n | 10 Punkte entsprechen | greift zuerst |
|---|---|---|---|
| Kontexte | 104 | ~10 Sätzen Vorsprung | **(b)**: 10 Punkte sind nur bei wenigen uneinigen Paaren signifikant (b+c = 16 → p = 0,021; b+c = 30 → p = 0,099). Bei mittlerer Uneinigkeit braucht es eher 12 Punkte. |
| Dauer | 276 | ~28 Sätzen Vorsprung | **(a)**: 10 Punkte sind hier fast immer signifikant (b+c = 120 → p = 0,013). Die Relevanzschwelle ist die eigentliche Hürde. |
| Energie | 211 | ~21 Sätzen Vorsprung | **(a)**, wie bei Dauer. |

**Was das kostet, offen benannt:** Bei Kontexten kann ein echter Vorsprung von 10 bis 12 Punkten an
der Signifikanz scheitern — die Stichprobe ist dafür schlicht zu klein, und größer wird sie nicht,
weil nur 104 von 287 Aufgaben eine Kontext-Wahrheit tragen. Bei Dauer und Energie kann umgekehrt
ein statistisch sauberer Vorsprung von 5 bis 9 Punkten als „nicht erfüllt" gelten, obwohl er real
ist. Der Bericht schreibt deshalb **immer alle Zahlen** (Trefferquote, Nulllinie, Abstand, b, c,
p-Wert) und nicht nur das Urteil, damit die Festlegung später überprüfbar bleibt, statt die Daten
zu verschlucken.

Diese Herleitung gilt für **Regel gegen Konstante**. Die Tabelle „Nachweisbare Differenz und
Aufwand" im Analyse-Kontext rechnet etwas anderes (zwei Modell-Arme mit und ohne Beispiele, drei
Wiederholungsläufe) und ist hier nicht die Grundlage.

## Quelle

- **Datei:** `Measurement/LeaveOneOut.swift` (neu)
  **Bezeichner:** `enum LeaveOneOut` — `static func similarityWords(_:) -> Set<String>`,
  `static func jaccard(_:_:) -> Double`, `static func neighbors(of:in:k:) -> [Corpus.Entry]`,
  `static func majority<Value: Hashable>(among:value:) -> Value?`,
  `static func baselineClass<Value: Hashable>(pool:value:) -> Value?`,
  `static func contextClass(_:) -> Set<String>`, `struct McNemarResult`,
  `static func mcNemar(ruleCorrect:baselineCorrect:) -> McNemarResult`
- **Datei:** `LooseEndsTests/RuleLeaveOneOutTests.swift` (neu)
  **Bezeichner:** `struct RuleLeaveOneOutTests` (ungegatet, reine Logik) und
  `struct RuleLeaveOneOutReportTests` (gegatet über `@Suite(.enabled(if:))`) — zwei Suiten in einer
  Datei, weil `.enabled(if:)` eine ganze Suite schaltet und die Logik-Tests in CI laufen müssen
- **Datei:** `docs/reference/retrieval-leave-one-out-rules.md` (neu)
  Bericht: Trefferquote je Merkmal und k, Nulllinie, McNemar-Zahlen, Sätze ohne Nachbarn,
  Erfüllt/Nicht-erfüllt je Merkmal
- **Datei:** `LooseEndsTests/MeasurementFieldScopeTests.swift` (geändert)
  Neuer Testfall: der #118-Wächter deckt auch `LeaveOneOut`/`RuleLeaveOneOutTests` ab

## Acceptance Criteria

- **AC-1 Auslass — kein Selbst-Nachbar:** Given ein Pool, der die Zielaufgabe selbst enthält /
  When `LeaveOneOut.neighbors(of:in:k:)` für diese Zielaufgabe aufgerufen wird / Then enthält das
  Ergebnis die Zielaufgabe nie, auch wenn ihre Jaccard-Ähnlichkeit zu sich selbst 1,0 wäre — der
  Testsatz ist nie sein eigener Nachbar.
- **AC-2 Jaccard-Rangfolge mit deterministischem Gleichstand:** Given zwei Kandidaten mit exakt
  gleicher Jaccard-Ähnlichkeit zur Zielaufgabe / When `neighbors(of:in:k:)` die Kandidaten sortiert
  / Then steht der Kandidat mit der kleineren `id` zuerst; bei ungleicher Ähnlichkeit steht der
  Kandidat mit der höheren Jaccard-Zahl zuerst. Bei gleichen Eingaben ist die Reihenfolge immer
  identisch, unabhängig von `Set`-Iterationsreihenfolge.
- **AC-3 Längenfilter ≥ 4 auf der Ähnlichkeits-Wortmenge:** Given ein Aufgabentext, der nur aus
  deutschen Funktionswörtern unter vier Zeichen besteht („für", „die", „am") neben genau einem
  Inhaltswort mit vier oder mehr Zeichen / When `LeaveOneOut.similarityWords(_:)` die Wortmenge
  bildet / Then enthält die Menge nur das eine Inhaltswort — die Funktionswörter tragen keine
  Ähnlichkeit.
- **AC-4 Mehrheitsentscheid mit Gleichstandsregel:** Given zwei Nachbarn in Rangfolge mit
  unterschiedlichen Werten und gleicher Stimmenzahl (1:1 bei zwei stimmberechtigten Nachbarn) /
  When `LeaveOneOut.majority(among:value:)` aufgerufen wird / Then gewinnt der Wert des
  bestplatzierten (näheren) Nachbarn, nicht der des zweiten — die Funktion zählt Häufigkeiten und
  bricht Gleichstände über die Rangfolge, nicht über „zuletzt gesehen".
- **AC-5 `nil` ohne Nachbarn zählt als Fehltreffer:** Given eine Zielaufgabe, deren
  Ähnlichkeits-Wortmenge mit keiner anderen Aufgabe im Pool eine Schnittmenge hat (Jaccard 0 zu
  jedem Kandidaten) / When Vorhersage über `neighbors` und `majority` gebildet und gegen die
  Wahrheit ausgewertet wird / Then ist die Vorhersage `nil`, und die Auswertung zählt diesen Satz
  in der verbindlichen Trefferquote als Fehltreffer, nicht als ausgelassen oder ignoriert.
- **AC-6 Nulllinie wird aus dem Pool gerechnet, nie hartkodiert:** Given ein Pool mit bekannter
  Werteverteilung (z. B. 6 von 10 Testaufgaben mit demselben Dauer-Wert, die übrigen vier verteilt)
  / When `LeaveOneOut.baselineClass(pool:value:)` aufgerufen wird / Then liefert es den im Pool am
  häufigsten vorkommenden Wert, berechnet aus den übergebenen Daten — kein fester Prozentwert oder
  Klassenname steht im Code.
- **AC-7 Kontextmengen-Normalisierung:** Given zwei Aufgaben mit denselben Kontexten in
  unterschiedlicher Schreibweise und Reihenfolge (`["Computer", "Learning"]` und
  `["learning", "computer"]`) / When `LeaveOneOut.contextClass(_:)` auf beide angewendet wird /
  Then sind die beiden Ergebnisse gleich (`Set<String>`-Gleichheit) — sie zählen als dieselbe
  Klasse, nicht als Mismatch wegen Reihenfolge oder Schreibweise im JSON.
- **AC-8 McNemar-Exakttest inklusive b+c = 0:** Given zwei gepaarte Korrektheits-Listen ohne einen
  einzigen diskordanten Fall (Regel und Konstante stimmen bei jeder Aufgabe im Ergebnis überein) /
  When `LeaveOneOut.mcNemar(ruleCorrect:baselineCorrect:)` aufgerufen wird / Then ist `b == 0`,
  `c == 0` und `pValue == 1.0`. Ein zweiter Fall mit b = 9, c = 1 liefert `pValue ≈ 0,0215`
  (zweiseitiger Exakttest, n = 10: `2 · (C(10,0) + C(10,1)) / 2¹⁰ = 22/1024`) — von Hand
  nachgerechnet und damit Regressionsschutz für die Formel, nicht nur für ihr Vorzeichen.
  Gegenprobe im selben Test: b = 8, c = 2 ergibt `pValue ≈ 0,1094` (`2 · 56/1024`) und liegt damit
  **über** 0,05 — die Schwelle aus dem Abbruchkriterium ist bei n = 10 knapp, das muss der Test
  festhalten, damit niemand sie später für großzügiger hält, als sie ist.
- **AC-9 Bericht mit allen Pflichtspalten, ohne Modell- oder Geräteaufruf:** Given der reale
  FocusBlox-Korpus liegt lokal vor (`docs/reference/focusblox-corpus.json`) / When
  `RuleLeaveOneOutTests` läuft / Then schreibt sie `docs/reference/retrieval-leave-one-out-rules.md`
  mit je einer Zeile pro Merkmal und k (verbindliche Trefferquote, Trefferquote unter den
  beantworteten Sätzen, Zahl der Sätze ohne Nachbarn, Nulllinie, b, c, p-Wert,
  Erfüllt/Nicht-erfüllt), den Kontext-Nebenspalten „enthält erwarteten Kontext" und
  „Jaccard-Mittel", und ohne dass im gesamten Testlauf `FoundationModelsEnricher.enrich(_:)`
  aufgerufen oder mit einem Gerät kommuniziert wird.

## Nicht in diesem Schnitt

- Der Modell-Auslass-Test selbst (beide Arme, mit/ohne Beispiele, auf dem Gerät gemessen). Er
  entscheidet sich erst nach dem Ergebnis dieses Schnitts (Henning, 2026-09-26).
- Jede Embedding-Anbindung (`NLContextualEmbedding`, `SpotlightSearchTool`) — bleiben Alternativen
  für den Fall, dass die Regel die Konstante nicht schlägt.
- Die Installationslücken der Labor-App (`contextVocabulary: []`, hart verdrahteter
  Ergebnisdateiname, `lab-run` ohne `--corpus`/`--runs`-Durchreichung, fehlendes Arm-Feld in
  `MeasurementResult`). Sie werden erst gebraucht, wenn der Modell-Auslass-Test tatsächlich gebaut
  wird.
- Jede Änderung am Produktpfad: `EnrichmentCoordinator.examples(in:limit:)`,
  `FoundationModelsEnricher`, `EnrichmentDraft` bleiben unverändert. Dieser Schnitt misst, er greift
  nicht ein.
- Die Entscheidung über ADR-5 selbst. Ein Nullergebnis widerlegt „Wortüberlappung als Nachbarsuche
  für dieses Merkmal", nicht B1 insgesamt und nicht den Modellweg — siehe „Architektur-Entscheidung"
  unten.
- Wichtigkeit und Dringlichkeit (`importanceTruth`/`urgencyTruth`) — durch #117/#118 aus
  Messberichten gesperrt, hier nicht ausgewertet.

## Abhängigkeiten

| Baustein | Art | Zweck |
|----------|-----|-------|
| `TitleCheck.words(in:)` / `TitleCheck.normalized(_:)` (`Measurement/Corpus.swift:238-280`) | Funktion | Bestehende, reine Tokenisierung und Normalisierung — wiederverwendet für die Ähnlichkeits-Wortmenge statt einer zweiten Implementierung. |
| `Corpus.Entry`, `Corpus.load(fileName:)` (`Measurement/Corpus.swift:27-66,121-128`) | Typ/Funktion | Datengrundlage: `text` für die Ähnlichkeit, `contextsTruth`/`durationTruth`/`energyTruth` als Wahrheit je Merkmal. |
| `Measurement/RuleBaseline.swift` | Vorbild | Das Abstimmungsprinzip aus Ticket A (eine Korrektur = eine Stimme, Gleichstand fällt an den zuerst gesehenen Wert, `nil` statt erzwungenem Default) wird hier auf Nachbarn statt Korrekturen verallgemeinert. |
| `ImportanceUrgencyRule` (`Shared/Enrichment/ImportanceUrgencyRule.swift`) | Stil-Vorbild | „Kein Treffer heißt `nil`, nie ein erzwungener Default" — Programmierstil für `LeaveOneOut.majority`/`baselineClass`. |
| `LooseEndsTests/SelfConsistencyReportTests.swift:11-22` | Berichtsmuster | `repoFile(...)`-Helfer und `@Suite(.enabled(if:))` auf eine lokal vorhandene, gitignorierte Datei — Vorbild für `RuleLeaveOneOutTests`, damit CI ohne die Korpus-Datei grün bleibt. |
| `LooseEndsTests/MeasurementFieldScopeTests.swift` | Wächter | #118-Schutz gegen erneute Auswertung von Wichtigkeit/Dringlichkeit — wird um einen Fall für die neue Datei erweitert. |
| `docs/reference/focusblox-corpus.json` (gitignored, 287 Aufgaben, nur lokal bei Henning) | Datenquelle | Liefert die drei Wahrheitsfelder und die Pools (Kontexte 104, Dauer 276, Energie 211). |

## Umfang

### Betroffene Dateien

| Datei | Änderungsart | Beschreibung |
|-------|---------------|--------------|
| `Measurement/LeaveOneOut.swift` | CREATE | Ähnlichkeits-Wortmenge (Längenfilter ≥ 4), Jaccard, Nachbarsuche mit Auslass und deterministischer Rangfolge, generischer Mehrheitsentscheid, aus dem Pool gerechnete Nulllinie, Kontextklassen-Normalisierung, McNemar-Exakttest. ~110 LoC |
| `LooseEndsTests/RuleLeaveOneOutTests.swift` | CREATE | Logik-Tests (AC-1 bis AC-8) gegen kleine, über JSON-Dekodierung gebaute `Corpus.Entry`-Werte, plus ein gegateter Bericht-Test (AC-9) über den echten FocusBlox-Korpus, der für Kontexte/Dauer/Energie bei k=1,3,5 rechnet und den Bericht schreibt. ~120 LoC |
| `docs/reference/retrieval-leave-one-out-rules.md` | CREATE | Der Bericht, vom Test geschrieben, nie von Hand gepflegt. |
| `LooseEndsTests/MeasurementFieldScopeTests.swift` | MODIFY | Neuer Testfall: `RuleLeaveOneOutTests.swift` darf `importanceTruth`/`urgencyTruth` nicht auswerten (Quelltext-Prüfung wie bei den bestehenden zwei Fällen). ~8 LoC |

### Geschätzter Umfang

- Dateien: 4 — innerhalb des Standard-Richtwerts (4-5 Dateien).
- LoC: geschätzt rund **+240/−0** — an der Obergrenze der ±250-LoC-Grenze, aber innerhalb.
- **Streichreihenfolge bei Überschreitung, in dieser Reihenfolge:** (1) die beiden
  Kontext-Nebenmetriken „enthält erwarteten Kontext" und Jaccard-Mittel (~15 LoC) — sie dienen nur
  der Nachprüfbarkeit der Metrikwahl, keine Entscheidung stützt sich auf sie; (2) die k-Kurve auf
  k = 3 verkürzen (~10 LoC in der Berichts-Schleife) — kostet die Aussage, ob mehr Nachbarn helfen
  oder schaden, nicht aber die Hauptzahl; (3) den Schnitt in zwei Tickets teilen (Logik, dann
  Bericht). **Der McNemar-Teil wird nicht gestrichen.** Ohne p-Wert lässt sich die
  Erfüllt/Nicht-erfüllt-Aussage aus dem Abbruchkriterium nicht treffen, und genau die ist das
  Ergebnis dieses Schnitts — ihn zu opfern hieße, den Schnitt zu fahren und ohne Antwort
  dazustehen.
- Risiko: **niedrig** — reiner Messcode in `Measurement/` und `LooseEndsTests/` (kompiliert laut
  `CLAUDE.md` nie in den Produktpfad), kein Gerät, keine Änderung an `project.yml` (das
  Test-Ziel compiliert `Measurement/` bereits), keine Änderung an der Messstrecke aus #67/#108.
- Laufzeit: Sekunden auf dem Mac, keine Gerätezeit.

## Technische Umsetzung

1. **`Measurement/LeaveOneOut.swift` (neue Datei):**
   - `static func similarityWords(_ text: String) -> Set<String>`: tokenisiert über
     `TitleCheck.words(in:)`, normalisiert jedes Wort über `TitleCheck.normalized(_:)`, filtert auf
     `count >= 4` (dieselbe Schwelle wie `TitleCheck.foreignWords`, kein neuer Wert). Begründung im
     Doc-Kommentar: `TitleCheck.words(in:)` filtert nichts, ohne Längenfilter trügen deutsche
     Funktionswörter („eine", „für", „mit", „der") die Ähnlichkeit, und die Nachbarn wären Rauschen.
   - `static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double`: `|a ∩ b| / |a ∪ b|`,
     `0` wenn die Vereinigung leer ist (verhindert Division durch null, ein solches Paar hat ohnehin
     keine gemeinsamen Wörter).
   - `static func neighbors(of target: Corpus.Entry, in pool: [Corpus.Entry], k: Int) -> [Corpus.Entry]`:
     berechnet `similarityWords(target.text)` einmal, bildet für jeden Kandidaten mit `id != target.id`
     das Paar (Kandidat, Jaccard), verwirft Paare mit Jaccard `0`, sortiert absteigend nach Jaccard und
     bei Gleichstand aufsteigend nach `id` (Determinismus, AC-2), nimmt die ersten `k`. Der Auslass
     (AC-1) folgt allein aus dem `id != target.id`-Filter — der Testsatz kann sich selbst nie als
     Kandidat vorliegen.
   - `static func majority<Value: Hashable>(among neighbors: [Corpus.Entry], value: (Corpus.Entry) -> Value?) -> Value?`:
     iteriert die (bereits nach Rang sortierten) Nachbarn, überspringt Nachbarn ohne Wert für dieses
     Merkmal (`value(neighbor) == nil`) — sie werden **nicht** durch weiter entfernte Nachbarn
     ersetzt, das ist eine bewusste Festlegung, damit dieselbe Funktion für alle drei Merkmale
     funktioniert, ohne dass der Aufrufer den Pool vorher filtern muss. Zählt eine Stimme je Nachbar
     mit Wert, merkt sich die Reihenfolge des ersten Auftretens je Wert (das ist die Rangfolge der
     Nachbarn), wählt den Wert mit den meisten Stimmen; bei Gleichstand gewinnt der zuerst gesehene
     Wert — und weil die Nachbarn nach Rang sortiert hereinkommen, ist das genau der Wert des
     bestplatzierten Nachbarn unter den gleichauf liegenden (AC-4). `nil`, wenn kein Nachbar einen
     Wert trägt (AC-5).
   - `static func baselineClass<Value: Hashable>(pool: [Corpus.Entry], value: (Corpus.Entry) -> Value?) -> Value?`:
     ruft `majority(among: pool, value: value)` — dieselbe Zähl- und Gleichstandslogik, angewandt auf
     den gesamten Pool statt auf k Nachbarn. Das ist die aus dem Korpus gerechnete Konstante
     (AC-6), nie ein hartkodierter Prozentwert; die Zahlen aus der Analyse (56,7 %/51,1 %/77,3 %)
     sind Erwartungswerte zur Plausibilitätsprüfung im Test, keine Werte im Produktcode.
   - `static func contextClass(_ contexts: [String]) -> Set<String>`: `Set(contexts.map { $0.lowercased() })`
     — eine Aufgabe mit den Kontexten `["computer", "learning"]` ist eine eigene Klasse, nicht zwei
     Nennungen; `Set`-Gleichheit ignoriert bereits die Reihenfolge im JSON, nur die Schreibweise muss
     normalisiert werden (AC-7).
   - `struct McNemarResult: Sendable { let b: Int; let c: Int; let pValue: Double }`.
   - `static func mcNemar(ruleCorrect: [Bool], baselineCorrect: [Bool]) -> McNemarResult`: gepaart über
     dieselben Sätze, `b` = Regel richtig und Konstante falsch, `c` = Regel falsch und Konstante
     richtig (konkordante Paare — beide richtig oder beide falsch — fallen heraus). Bei `b + c == 0`
     ist `pValue == 1.0` (AC-8, kein Unterschied zwischen zwei ununterscheidbaren Armen feststellbar).
     Sonst ein zweiseitiger Exakttest über die Binomialverteilung mit p = 0,5 auf `n = b + c`:
     Binomialkoeffizienten werden iterativ als Verhältnis berechnet (`coefficient *= Double(n - j) / Double(j + 1)`),
     nicht über `n!`, damit `n` bis in die Hunderte nicht überläuft — kein Statistik-Framework, reine
     Kombinatorik in eigenem Code.
2. **Kontextvokabular/Klasse als Vorhersagewert:** Für das Merkmal Kontexte ist `Value` in
   `majority`/`baselineClass` `Set<String>` (über `contextClass(_:)` gebildet), für Dauer und Energie
   ist `Value` schlicht `String` (`durationTruth`/`energyTruth` unverändert). Dieselben zwei
   generischen Funktionen bedienen alle drei Merkmale.
3. **`Corpus.Entry`-Konstruktion in den Logik-Tests:** `Corpus.Entry` hat keine memberweise
   Initialisierung (nur `Decodable`). Die Logik-Tests bauen ihre kleinen Testfälle deshalb über
   JSON-Dekodierung kleiner Literale (`JSONDecoder().decode([Corpus.Entry].self, from: ...)` mit
   einem inline geschriebenen JSON-String je Testfall) statt über ein zweites, schmales Protokoll.
   Das hält `LeaveOneOut` an den bestehenden `Corpus.Entry`-Typ gebunden — der einfachere Weg, weil
   kein Adapter zwischen zwei Datentypen gepflegt werden muss.
4. **`LooseEndsTests/RuleLeaveOneOutTests.swift` (neue Datei), zwei Suiten:**
   - `struct RuleLeaveOneOutTests` (ungegatet): acht kleine, unabhängige Testfälle für AC-1 bis AC-8
     gegen inline dekodierte `Corpus.Entry`-Werte. Keine Korpus-Datei nötig, laufen immer, auch in CI.
   - `struct RuleLeaveOneOutReportTests` (gegatet) mit
     `@Suite(.enabled(if: FileManager.default.fileExists(atPath: ...)))` nach dem Muster von
     `SelfConsistencyReportTests`. **Zwei getrennte Suiten sind Pflicht, keine Stilfrage:**
     `.enabled(if:)` schaltet eine ganze Suite, nicht einen einzelnen Test — lägen alle neun Fälle in
     einer Suite, verschwänden die acht Logik-Tests aus CI, sobald die gitignorierte Korpus-Datei
     fehlt, also immer. Der `repoFile(...)`-Helfer wird in dieser Datei als `private func` neu
     geschrieben; die bestehende Funktion ist `private` in einer anderen Datei und nicht sichtbar.
     Diese Suite lädt `docs/reference/focusblox-corpus.json`, bildet für
     jedes Merkmal den Pool (Einträge mit nicht-`nil` Wahrheit in diesem Feld), rechnet für k = 1, 3, 5
     Trefferquote (verbindlich: `nil` zählt als Fehltreffer), Trefferquote unter den beantworteten
     Sätzen, Zahl der Sätze ohne Nachbarn, `baselineClass` als Nulllinie, `mcNemar` gegen die
     Nulllinie, und für Kontexte zusätzlich die Nebenmetriken „enthält erwarteten Kontext" und
     Jaccard-Mittel der Kontextmengen. Schreibt `docs/reference/retrieval-leave-one-out-rules.md`.
5. **Bericht-Format** (`docs/reference/retrieval-leave-one-out-rules.md`), angelehnt an
   `docs/reference/date-title-fidelity.md` und `retrieval-convention-spike.md`, ohne
   Geräte-/Akkuzeilen (keine Modellmessung):
   - Kopf: Korpusquelle, Messtag, Methode (Regel-Auslass-Test, kein Modell), Pool-Größen je Merkmal.
   - Haupttabelle: eine Zeile je Merkmal × k mit Trefferquote (verbindlich), Trefferquote (unter
     beantworteten Sätzen), Sätze ohne Nachbarn, Nulllinie, Abstand in Prozentpunkten, b, c, p-Wert.
   - Nebenspalten für Kontexte: „enthält erwarteten Kontext"-Quote, Jaccard-Mittel — zur
     Nachprüfbarkeit der Metrikwahl, ohne dass eine Entscheidung darauf gestützt wird.
   - Fazit je Merkmal: „Erfüllt" oder „Nicht erfüllt" nach der vorab festgelegten Schwelle (mind. ein
     k mit Trefferquote ≥ Nulllinie + 10 Punkte **und** p < 0,05), plus die Grenzen aus dieser Spec
     (gepflegte Titel als Rohtext, Längenfilter verliert kurze Inhaltswörter, ein Nullergebnis
     widerlegt nur den Mechanismus).
6. **`LooseEndsTests/MeasurementFieldScopeTests.swift` (Erweiterung):** ein zusätzlicher Test nach
   dem Muster der zwei bestehenden — liest `RuleLeaveOneOutTests.swift` als Quelltext und prüft,
   dass er `importanceOutcomes`/`urgencyOutcomes` bzw. `field: "importance"`/`field: "urgency"`
   nicht enthält, je nachdem, welche Bezeichner die Implementierung tatsächlich verwendet.
7. **Reihenfolge der Umsetzung:** `LeaveOneOut.swift` zuerst (reine Logik, TDD RED über die acht
   Logik-Tests), dann GREEN, dann der gegatete Bericht-Test, zuletzt die Erweiterung von
   `MeasurementFieldScopeTests`.

## Alternativen

- **Direkt den Modell-Auslass-Test bauen** (beide Arme, Kontexte, ~1,5 Stunden Gerätezeit plus
  Umbau der Labor-App: Kontextvokabular, Ergebnisdateiname, `--corpus`/`--runs`-Durchreichung,
  Arm-Feld in `MeasurementResult`). Beantwortet B1 wörtlich, kostet aber Gerätezeit für eine Frage,
  deren Produktrelevanz von der noch fehlenden Regel-Zahl abhängt. Kippt keine bestehende ADR.
- **Spike schließen, Regelweg auf Basis von Ticket A ausliefern.** Die 10/10 aus dem
  Konventionstest gelten als ausreichender Beleg, Kontexte gehen regelbasiert ins Produkt, ADR-5
  wird auf „Regeln plus Retrieval" umgeschrieben. Spart die gesamte Messung dieses Schnitts — nimmt
  aber in Kauf, dass die 10/10 aus zehn eigens gebauten, wohlwollenden Mustern stammen und die
  Trefferquote auf echten Daten unbekannt bleibt. Würde ADR-5 kippen, ohne dass die reale Zahl
  dafür vorliegt — deshalb nicht der Vorschlag.
- **Statt Jaccard über Wortmengen eine IDF-Gewichtung oder `NLContextualEmbedding` als
  Nachbarsuche.** Würde seltene, aussagekräftige Wörter stärker gewichten bzw. semantische statt
  wörtlicher Nähe nutzen. IDF bliebe dabei sogar regelbasiert und käme ohne Modell aus — es ist
  trotzdem ein zweiter, komplexerer Mechanismus, den erst zu bauen lohnt, wenn die einfache
  Wortüberlappung nachweislich scheitert (Regel „die einfachste Lösung wird zuerst gebaut oder
  zuerst widerlegt"). Bei
  `NLContextualEmbedding` gilt zusätzlich der Rechercheeinwand aus der Analyse: ein zweites
  nachzuladendes Modell mit dokumentierten Fehlern beim Nachladen. Kippt keine bestehende ADR.
- **Nur Kontexte messen statt aller drei Merkmale.** Kontexte sind das Erfolgskriterium aus B1 und
  hätten die kleinste Stichprobe (104). Henning hat sich am 2026-09-26 explizit für alle drei
  entschieden, weil Dauer und Energie auf dem Mac nichts extra kosten und #112 auf beide wartet.
  Kippt keine bestehende ADR, ist aber gegen die getroffene PO-Entscheidung.

## Testplan

### Automatisierte Tests (TDD RED)

- [ ] `RuleLeaveOneOutTests`, Fall Auslass: GIVEN ein Pool, der die Zielaufgabe enthält / WHEN
  `LeaveOneOut.neighbors(of:in:k:)` aufgerufen wird / THEN fehlt die Zielaufgabe im Ergebnis (AC-1).
- [ ] `RuleLeaveOneOutTests`, Fall Rangfolge und Gleichstand: GIVEN zwei Kandidaten mit identischer
  Jaccard-Ähnlichkeit und unterschiedlicher `id` / WHEN `neighbors(of:in:k:)` sortiert / THEN steht
  der Kandidat mit der kleineren `id` zuerst (AC-2).
- [ ] `RuleLeaveOneOutTests`, Fall Längenfilter: GIVEN ein Text aus kurzen Funktionswörtern und
  genau einem Wort mit vier oder mehr Zeichen / WHEN `LeaveOneOut.similarityWords(_:)` aufgerufen
  wird / THEN enthält das Ergebnis nur das eine Inhaltswort (AC-3).
- [ ] `RuleLeaveOneOutTests`, Fall Mehrheitsentscheid bei Gleichstand: GIVEN zwei Nachbarn in
  Rangfolge mit unterschiedlichen Werten, je einer Stimme / WHEN `LeaveOneOut.majority(among:value:)`
  aufgerufen wird / THEN gewinnt der Wert des ersten (näheren) Nachbarn (AC-4).
- [ ] `RuleLeaveOneOutTests`, Fall kein Nachbar: GIVEN eine Zielaufgabe ohne gemeinsame Wörter mit
  irgendeinem Pool-Kandidaten / WHEN Vorhersage gebildet wird / THEN ist sie `nil` und zählt in der
  Auswertung als Fehltreffer (AC-5).
- [ ] `RuleLeaveOneOutTests`, Fall Nulllinie: GIVEN ein Pool mit bekannter Werteverteilung / WHEN
  `LeaveOneOut.baselineClass(pool:value:)` aufgerufen wird / THEN entspricht das Ergebnis dem
  von Hand nachgerechneten häufigsten Wert (AC-6).
- [ ] `RuleLeaveOneOutTests`, Fall Kontextklasse: GIVEN zwei Kontextlisten mit gleichem Inhalt in
  unterschiedlicher Schreibweise/Reihenfolge / WHEN `LeaveOneOut.contextClass(_:)` auf beide
  angewendet wird / THEN sind die Ergebnisse gleich (AC-7).
- [ ] `RuleLeaveOneOutTests`, Fall McNemar ohne Diskordanz: GIVEN zwei identische
  Korrektheits-Listen / WHEN `LeaveOneOut.mcNemar(ruleCorrect:baselineCorrect:)` aufgerufen wird /
  THEN ist `b == 0`, `c == 0`, `pValue == 1.0`; ein zweiter Fall mit b=9, c=1 liefert
  `pValue ≈ 0,0215` und ein dritter mit b=8, c=2 `pValue ≈ 0,1094` (beide von Hand nachgerechnet,
  Toleranz 1e-6) — der dritte hält fest, dass die 0,05-Schwelle bei n=10 knapp verfehlt wird (AC-8).
- [ ] `RuleLeaveOneOutTests`, Fall Bericht (gegated): GIVEN
  `docs/reference/focusblox-corpus.json` liegt lokal vor / WHEN die Suite läuft / THEN existiert
  `docs/reference/retrieval-leave-one-out-rules.md` mit allen Pflichtspalten je Merkmal und k, ohne
  Aufruf an `FoundationModelsEnricher.enrich(_:)` im gesamten Testlauf (AC-9).
- [ ] `MeasurementFieldScopeTests`, neuer Fall: GIVEN `RuleLeaveOneOutTests.swift` als Quelltext /
  WHEN der Test läuft / THEN enthält die Datei keine Auswertung von `importance`/`urgency`.
- [ ] Bestehende Suiten bleiben grün: GIVEN der neue Code / WHEN `./scripts/sim.sh unit` läuft /
  THEN bestehen `CorpusTests`, `RuleBaselineTests`/`ConventionBaselineTests`,
  `SelfConsistencyReportTests`, `MeasurementFieldScopeTests` unverändert, weil dieser Schnitt keinen
  Produktpfad berührt und außer der einen genannten Erweiterung keine bestehende Datei ändert.

Kein UI-Test: Dieser Schnitt ändert keine SwiftUI-View und keinen Produktcode — die gesamte
Erweiterung lebt in `Measurement/` und `LooseEndsTests/`. Kein Test ruft das Modell auf oder
kommuniziert mit einem Gerät ([[feedback-phone-is-not-a-test-bench]] bleibt gewahrt): `LeaveOneOut`
ist reine In-Memory-Verarbeitung über bereits geladene Daten, der Bericht-Test liest nur die lokal
vorhandene, gitignorierte Korpus-Datei. Der Nachweis läuft vollständig über den Mac-Testlauf.

## Definition of Done

- [ ] AC-1 bis AC-9 erfüllt, belegt durch die im Testplan genannten Tests
- [ ] `./scripts/sim.sh unit` grün, inklusive aller bestehenden Suiten
- [ ] CI grün
- [ ] PR mit `Closes #131` gemergt
- [ ] Hennings Hauptordner nachgezogen und Projekt neu erzeugt
  (`bash ~/.claude/scripts/loose-ends-sync-main.sh`)
- [ ] `docs/reference/retrieval-leave-one-out-rules.md` existiert mit den tatsächlichen Zahlen (kein
  Platzhalter) und der ausdrücklichen Erfüllt/Nicht-erfüllt-Aussage je Merkmal (Kontexte, Dauer,
  Energie) nach der vorab festgelegten Schwelle

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Der gesamte Code liegt in `Measurement/` und `LooseEndsTests/` — reiner Messcode,
  kein Produktpfad, keine neue Abhängigkeit, wie schon in Ticket A. „Regeln vor Modell" ist hier
  nicht als Prüfpflicht einschlägig, weil dieser Schnitt kein Modell vorschlägt oder ersetzt: Er
  baut die Regel-Alternative zum Modell-Retrieval aus ADR-5 und liefert die Zahl, gegen die sich
  der Modell-Auslass-Test erst messen müsste. Schlägt die Regel die Konstante auf einem oder
  mehreren Feldern (Erfüllt-Aussage), stellt das ADR-5 („Lernen ist Retrieval, kein Training") und
  den Zuschnitt von #26/#112 zur Disposition — diese Entscheidung fällt aber erst nach dem
  Messergebnis, durch Henning, nicht in dieser Spec. Bleibt jedes Feld „Nicht erfüllt", ist nur der
  Mechanismus „Wortüberlappung als Nachbarsuche" widerlegt, nicht B1 insgesamt und nicht ADR-5.

## Changelog

- 2026-09-26: Spec aus dem Analyse-Kontext (`docs/context/spike-69-auslasstest-retrieval.md`) und
  Issue #131 erstellt, offene Fragen durch Tech-Lead-Entscheidung (exakte Mengengleichheit, Kurve
  über k=1,3,5, vorab festgelegte Abbruchschwelle) aufgelöst.
- 2026-09-26, nach dem ersten PO-Briefing überarbeitet: (1) AC-8 hatte ein falsch gerechnetes
  Zahlenbeispiel (b=8, c=2 ergibt p = 0,109, nicht < 0,05) — korrigiert auf b=9, c=1 mit dem alten
  Fall als Gegenprobe. (2) Der Bericht-Test hätte als eine Suite die acht Logik-Tests aus CI
  genommen, sobald die gitignorierte Korpus-Datei fehlt — jetzt zwei getrennte Suiten. (3) Die
  Abbruchschwelle hatte keine Herleitung für den Vergleich Regel-gegen-Konstante; der neue
  Abschnitt „Die Abbruchschwelle und ihre Herleitung" rechnet sie je Merkmal nach und benennt,
  welche Hälfte bindet und was sie kostet. (4) Der Streichposten bei LoC-Überschreitung war der
  McNemar-Teil — ohne ihn wäre die Erfüllt/Nicht-erfüllt-Aussage aus der Definition of Done
  unmöglich; die Streichreihenfolge lautet jetzt Kontext-Nebenmetriken, dann k-Kurve, dann
  Ticket-Teilung.

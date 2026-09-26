# Context: Spike #69 — Auslass-Test (Modell mit/ohne k Retrieval-Beispiele)

## Request Summary

Der noch offene Teil von Annahme B1: Verschieben k ähnliche alte Aufgaben als Prompt-Beispiele die
Trefferquote des Modells messbar über das Rauschen hinaus? Ticket A hat nur den Konventionstest
beantwortet (Regel-Baseline, 10/10, `docs/reference/retrieval-convention-spike.md`); der
Auslass-Test mit/ohne k Nachbarn ist nie gelaufen. Er ist Voraussetzung für #112 (Dauer und Energie,
`docs/project/04-stand.md:87-88`) und entscheidet über ADR-5 („Lernen über Prompt-Beispiele").

**Nicht Teil dieses Auftrags:** das verworfene „Ticket B" aus der Ticket-A-Spec. Das war ein
bedingtes Folge-Ticket für den Fall, dass die Regel-Baseline die 8/10-Schwelle verfehlt — sie hat sie
mit 10/10 erreicht.

## Recherche vorab (2026-09-26): drei Wege zur Nachbarsuche, nicht einer

B1 nennt `NLContextualEmbedding` als Mechanismus. Die Recherche zeigt, dass die Schnittstellenlage
sich seit dem Schreiben der Annahme geändert hat und zwei Alternativen existieren.

| Weg | Stand | Kosten und Risiko |
|---|---|---|
| **Wortüberlappung** (Regelweg) | In `Measurement/RuleBaseline.swift` bereits gebaut, Ticket A: 10/10 | Kein Framework, kein Nachladen, läuft im Unit-Test auf dem Mac |
| `NLContextualEmbedding` | Nicht veraltet, iOS 17+/macOS 14+, Deutsch über das Latin-Modell | Zweites nachzuladendes Modell (`requestAssets` vor `load`); dokumentierte Fehler „Embedding model requires compilation" (Code 7) und Rechteprobleme im Cache; im Simulator unzuverlässig |
| `SpotlightSearchTool` (neu, iOS 27) | Im installierten iOS-27-SDK verifiziert (`_CoreSpotlight_FoundationModels.framework`), `Tool`-Konformität, `GuidanceProfile.similarityMatch` | Auf watchOS nicht verfügbar (`Shared/` compiliert in das Watch-Ziel → Guards nötig); die App indexiert bisher nichts in Core Spotlight; das Modell formuliert die Anfrage selbst, also kein kontrollierbares k |

Nach „Regeln vor Modell" ist die Wortüberlappung die Nulllinie, die die beiden Modellwege erst
schlagen müssen. Für den **Messaufbau** ist das entscheidend: Der Auslass-Test fragt, ob *Beispiele*
wirken — welcher Mechanismus die Nachbarn auswählt, ist eine zweite, nachgelagerte Frage. Ein
Messaufbau, der beides koppelt, kann bei einem Nullergebnis nicht trennen, ob die Beispiele nicht
wirken oder die Nachbarsuche schlecht war.

Quellen: [NLContextualEmbedding](https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding) ·
[Sprachunterstützung](https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding/languages) ·
[Fehlerbericht Nachladen](https://developer.apple.com/forums/thread/799951) ·
[What's new in Foundation Models, WWDC26](https://developer.apple.com/videos/play/wwdc2026/241/) ·
[LLM search using Core Spotlight, WWDC26](https://developer.apple.com/videos/play/wwdc2026/246/)

## Related Files

| Datei | Relevanz |
|---|---|
| `Shared/Enrichment/FoundationModelsEnricher.swift:35-54` | Der Einhängepunkt für Beispiele **existiert schon**: `input.examples` wird als „Past tasks and how they ended up:" gerendert (Titel, Dauer, Energie, Kontexte). Kein neues Prompt-Gerüst nötig. |
| `Shared/Enrichment/FoundationModelsEnricher.swift:30,39` | `instructions`: Kontexte müssen aus der erlaubten Liste kommen, sonst leer. Prompt schreibt „Allowed contexts: none" bei leerem Vokabular. |
| `Shared/Enrichment/EnrichmentDraft.swift:45,51` | `EnrichmentInput.contextVocabulary`; `EnrichmentExample` trägt `rawText, title, importance, urgency, duration, energy, contexts` |
| `Shared/Enrichment/EnrichmentCoordinator.swift:53,147-165` | Produktpfad übergibt echte Kontextnamen. `examples(in:limit:)` sortiert nach `completedAt` — **Rezenz, nicht Ähnlichkeit**; der Doc-Kommentar sagt selbst, Ähnlichkeit ersetze das „in a later slice" |
| `Measurement/Corpus.swift:45-49` | Wahrheitsfelder `importanceTruth, urgencyTruth, durationTruth, energyTruth, contextsTruth`; `load(fileName:)`, `corpusFileName(from:)`, `runsPerEntry(from:)` aus Kommandozeilen-Argumenten |
| `Measurement/MeasurementRun.swift` | `MeasurementResult` (Bedingungen je Satz, `runIndex`), `Conditions`, `MeasurementPacing` (60 s nach Fehlschlag, Abbruch nach 3), `MeasurementStore` |
| `Measurement/SelfConsistency.swift` | Mehrheit und Einstimmigkeit über Wiederholungsläufe, reine Zählung |
| `Measurement/RuleBaseline.swift` | Ticket A: Mehrheitsentscheid über Wortüberlappung — der Regelweg für die Nachbarsuche, wiederverwendbar |
| `LooseEndsLab/MeasurementRunner.swift:137` | **Hier sitzt der Blocker:** `contextVocabulary: [], projectNames: [], examples: []` |
| `LooseEndsLab/MeasurementRunner.swift:53` | Ergebnisdateiname hart „date-title" — ein neuer Lauf überschreibt den #67-Lauf |
| `LooseEndsLab/LabApp.swift:13-15,69` | Übergibt `corpusFileName` und `runsPerEntry` aus `CommandLine.arguments`, `--measure` startet ohne Tippen |
| `scripts/sim.sh:353,389` | `lab-fetch` hat „date-title" als Vorgabe; `lab-run` reicht nur `--measure` durch, nicht `--corpus`/`--runs` |
| `project.yml:171-192` | Ziel `LooseEndsLab`: Quellen sind `LooseEndsLab` + ganzes `Measurement/` + genau drei Shared-Dateien |
| `LooseEndsTests/SelfConsistencyReportTests.swift:21-22,61` | **Berichtsmuster der Wahl:** `@Suite(.enabled(if:))` auf lokal vorhandene, gitignorierte Ergebnisdatei, kein Modellaufruf im Test, schreibt Markdown |
| `LooseEndsTests/MeasurementFieldScopeTests.swift` | Wächter aus #118: neue Messberichte dürfen `importance`/`urgency` nicht auswerten |
| `LooseEndsTests/FocusBloxCalibrationTests.swift:78,91` | Ruft das Modell aus einem Unit-Test (auf dem Mac = alte Modellgeneration) und strippt Kontexte aus den Beispielen — **Muster nicht kopieren** |

## Existing Patterns

- **Messen in Scheiben, nicht im Testlauf.** Labor-App `LooseEndsLab`, ein Satz messen → sofort
  sichern → prüfen, ob weiter; Szenenwechsel pausiert. Ergebnisse holt der Mac per `sim.sh lab-fetch`.
- **Bericht aus geholter Datei, nicht aus dem Messlauf.** Ein Test mit `@Suite(.enabled(if:))` liest
  die gitignorierte Ergebnisdatei und schreibt den Markdown-Bericht; ohne Datei wird die Suite
  übersprungen. So bleibt CI grün, ohne dass Messdaten im Repo liegen.
- **Bedingungen je Satz.** Jeder Ergebnissatz trägt Messtag, Vordergrund/Hintergrund, Akku/Strom,
  Akkustand, Stromsparmodus, Wärmezustand. Der Bericht weist getrennt aus.
- **Erweiterung von `MeasurementResult`** geschieht über ein neues Feld plus `decodeIfPresent`-Zeile
  im `init(from:)`, damit alte Ergebnisdateien weiter lesbar bleiben.

## Dependencies

- **Upstream:** `FoundationModelsEnricher` (Prompt und Schema), `Corpus` (Wahrheit),
  `MeasurementRun`/`MeasurementStore` (Läufe und Sicherung), Labor-App und `sim.sh`.
  Der FocusBlox-Export `scripts/export-focusblox-corpus.swift` für die Wahrheitsfelder.
- **Downstream:** #112 (Dauer und Energie) wartet auf dieses Ergebnis. ADR-5 und #26 (Lernen)
  hängen daran. Ein Nullergebnis kippt ADR-5 auf „Regeln plus Retrieval" oder streicht das Lernen
  über Prompt-Beispiele.

## Existing Specs

- `docs/specs/measurement/spike-69-regel-baseline-konventionstest.md` — Ticket A, derselbe Spike,
  liefert das Format für Korpus, Bericht und Abbruchschwelle
- `docs/reference/retrieval-convention-spike.md` — Ticket-A-Bericht (10/10)
- `docs/project/06-annahmen-und-experimente.md:106-118,144` — Annahme B1 mit Abbruch und Alternativen
- `docs/reference/date-title-fidelity.md`, `docs/reference/focusblox-calibration-report.md` —
  frühere Messreihen, liefern Laufzeiten und das heutige Güteniveau

## Risks & Considerations

1. **Kontexte können heute strukturell nicht zurückkommen.** Die Labor-App übergibt
   `contextVocabulary: []` (`LooseEndsLab/MeasurementRunner.swift:137`), der Prompt schreibt daraufhin
   „Allowed contexts: none", und die Instructions verbieten Kontexte außerhalb der Liste. Kontext ist
   aber das Erfolgskriterium aus B1 („Abrechnung erstellen" → „Computer"). Ohne diese Änderung misst
   der Auslass-Test auf dem entscheidenden Feld garantiert Null — und zwar aus einem Grund, der nichts
   mit Retrieval zu tun hat. **Das ist die Vorbedingung, ohne die der Spike nichts aussagt.**
2. **Die Wahrheit für die lernbaren Felder lag nicht auf der Platte — jetzt schon.** `durationTruth`,
   `energyTruth`, `contextsTruth` gibt es nur im FocusBlox-Export `docs/reference/focusblox-corpus.json`
   (gitignoriert, enthält echte Aufgabentitel). Der Hauptkorpus `date-title-corpus.json` (319 Sätze)
   hat **null** Sätze mit `contextsTruth`. Der Export wurde am 2026-09-26 neu erzeugt
   (`swift scripts/export-focusblox-corpus.swift`, liest den FocusBlox-Store schreibgeschützt) —
   die Abdeckung steht unten und ist die Grundlage der Stichprobenrechnung.
3. **Wichtigkeit und Dringlichkeit sind gesperrt.** #117 hat sie regelbasiert gelöst, #118 bewacht,
   dass Messberichte sie nicht mehr auswerten. Bleiben als lernbare Felder: Kontexte, Dauer, Energie.
4. **Der Messaufwand vervielfacht sich.** #67 brauchte zwei Messtage für 319 Sätze bei 8,8 s je Satz
   und 23 Fehlversuchen. Zwei Arme (mit/ohne Beispiele) × k Wiederholungen fürs Rauschen multiplizieren
   das. Die Stichprobe muss klein bleiben, und der Schnitt muss vorher ausrechnen, wie klein.
5. **Das Rauschmaß ist neu.** `--runs`/`runIndex`/`SelfConsistency` liefern Einstimmigkeit je Satz,
   nicht ein Rauschband der Trefferquote. Die Kennzahl „Differenz gegen das Rauschen" existiert nicht.
   Nebenbefund: Der #108-Wiederholungslauf wurde auf dem Gerät nie gefahren — dieser Spike wäre der
   erste echte Nutzer von `--runs`.
6. **Das heutige Güteniveau liegt unter der Nulllinie.** Dauer 51 % gegen Nulllinie 51,1 %, Energie
   25 % gegen 77,3 %; Kontexte nie gemessen. Siehe die Tabelle „Der Befund, der die Fragestellung
   verschiebt" — ein Beispiel-Effekt in der nachweisbaren Größenordnung (9 bis 15 Punkte) ändert an
   diesem Bild nichts.
7. **Labor-App-Installation fehlt.** Ergebnisdateiname ist hart verdrahtet, `lab-run` reicht
   `--corpus`/`--runs` nicht durch, und `MeasurementResult` hat kein Feld für den Arm (mit/ohne
   Beispiele). Drei kleine, aber unvermeidliche Änderungen.
8. **Woher kommen die Beispiele im Messlauf?** Im Produkt sind es abgeschlossene Aufgaben des Nutzers.
   Im Messlauf gibt es keine Historie — der Korpus selbst muss die Nachbarn liefern, und zwar ohne
   den Testsatz (daher „Auslass"). Das ist Aufbau-Arbeit, keine bloße Schalterstellung.

## Die Wahrheitsabdeckung im FocusBlox-Korpus (gemessen 2026-09-26, 287 Aufgaben)

| Feld | Sätze mit Wahrheit | Anmerkung |
|---|---|---|
| `durationTruth` | 276 von 287 | größte Stichprobe, heutige Güte 51 % |
| `energyTruth` | 211 von 287 | heutige Güte 25 % Precision |
| `contextsTruth` | **104 von 287** | das Erfolgskriterium aus B1, und die kleinste Stichprobe |
| `importanceTruth`/`urgencyTruth` | 284 / 285 | durch #118 für Messberichte gesperrt, nicht verwendbar |

**Das Kontextvokabular besteht aus zehn Namen** — damit ist beantwortet, woher die Liste für
`contextVocabulary` kommt (Risiko 1): computer, garten, haus, besorgen, learning, musik, draußen,
telefon, familie, energie.

**Die Verteilung ist stark schief, und das ist der wichtigste Befund für den Messaufbau.** Gezählt
wird je Aufgabe die exakte Kontextmenge als eine Klasse (`('computer','learning')` ist eine eigene
Klasse, nicht zwei Nennungen): 11 Klassen, die häufigste ist `('computer')` mit 59 von 104.

- **Die Nulllinie liegt bei 56,7 %.** „Immer computer antworten" trifft 59 von 104 Sätzen — ohne
  Modell, ohne Beispiele, ohne irgendetwas. Der Bericht muss diese Spalte führen (Regel „Die
  Nulllinie zählt", `CLAUDE.md`), sonst sieht ein Modellergebnis von 60 % nach Erfolg aus.
  *(Korrektur vom 2026-09-26: eine frühere Fassung nannte 61 %. Das waren Kontext-Nennungen
  — „computer" kommt 63-mal vor — statt exakter Treffer je Aufgabe.)*
- **Nachbarn sind reichlich vorhanden, anders als zuerst befürchtet.** Weil die großen Klassen die
  Masse tragen, haben bei k=3 noch 97 von 104 Sätzen genug Nachbarn derselben Klasse, bei k=5 sind es
  84. Die Schwanzklassen mit 1 bis 5 Vertretern fallen zahlenmäßig kaum ins Gewicht.

### Nachweisbare Differenz und Aufwand

Gepaart gerechnet (McNemar, α 0,05, Power 80 %), je nach Anteil diskordanter Paare (10/20/30 %):

| Feld | n | nachweisbare Differenz | Aufwand 2 Arme × 3 Läufe |
|---|---|---|---|
| Kontexte | 104 | 9 / 12 / 15 Prozentpunkte | 624 Aufrufe ≈ 1,5 h |
| Dauer | 276 | 5 / 8 / 9 Prozentpunkte | 1656 Aufrufe ≈ 4,0 h |
| Energie | 211 | 6 / 9 / 11 Prozentpunkte | 1266 Aufrufe ≈ 3,1 h |

Bei 8,8 s je Aufruf (gemessen in #67), zuzüglich Fehlversuche mit 60 s Wartezeit. In Scheiben
machbar; alle drei Felder mit voller Stichprobe nicht.

### Der Befund, der die Fragestellung verschiebt

Stellt man die heutige Modellgüte neben die Nulllinie desselben Feldes, ist das Modell auf **keinem**
der beiden Felder, auf die #112 wartet, besser als eine Konstante:

| Feld | Nulllinie | Modell heute | Abstand |
|---|---|---|---|
| Dauer | 51,1 % | 51 % | ±0 — das Modell liefert nichts über „immer minutes15" hinaus |
| Energie | 77,3 % | 25 % | **−52 Punkte** — „immer low" ist massiv besser als das Modell |
| Kontexte | 56,7 % | nie gemessen | unbekannt, weil das Vokabular leer übergeben wird |

Damit lautet die eigentliche Frage nicht mehr „helfen Beispiele dem Modell", sondern „kann das Modell
auf diesen Feldern überhaupt eine Konstante schlagen". Ein Retrieval-Effekt von 9 Punkten auf Energie
wäre immer noch 43 Punkte schlechter als eine einzige Regelzeile.

## Offene Fragen für `/20-analyse`

- Welche Felder werden gemessen: alle drei (Kontexte, Dauer, Energie) oder nur Kontexte als
  Erfolgskriterium aus B1? Das bestimmt, ob der FocusBlox-Korpus reicht oder erweitert werden muss.
- Welcher Mechanismus wählt die Nachbarn im Messlauf — Wortüberlappung als Nulllinie, oder direkt
  Embeddings? Und wird der Mechanismus überhaupt variiert, oder ist er festgehalten, um die Frage
  „wirken Beispiele?" sauber zu isolieren?
- Wie groß ist die Stichprobe, damit zwei Arme × k Wiederholungen in vertretbarer Zeit durchlaufen,
  und reicht diese Größe statistisch, um eine Differenz vom Rauschen zu trennen? Bei Kontexten stehen
  104 Sätze zur Verfügung, die Nulllinie liegt aber bei 61 % — die Analyse muss begründen, welcher
  Effekt in diesem Band überhaupt nachweisbar ist, sonst ist der Spike vor dem Start entschieden.
- Beschränkt sich die Kontextmessung auf die drei tragenden Kontexte (91 von 104 Sätzen), weil der
  Schwanz keine k Nachbarn hergibt?
- Lohnt sich Dauer (276 Sätze) oder Energie (211 Sätze) als zusätzliches oder alternatives Feld?
  Beide haben mehr Material als Kontext, und #112 wartet genau auf diese zwei.

# Tragende Annahmen und Experimente

> Erstellt: 2026-09-19
> Status: Analyse, Tech-Lead-Vorschlag (PO-Fragen in #74)
> Zweck: Klären, ob das Versprechen der App einlösbar ist, bevor weitere Ansichten gebaut werden

## Das Versprechen

Ein roher Fetzen Text wird still und ohne Rückfrage zu einer strukturierten Aufgabe: Titel, Fälligkeit,
Dauer, Energie, Kontext, Personen, Projekt, Abhängigkeit. Diese Struktur trägt Ansichten, die nicht
„meine Liste" zeigen, sondern „was jetzt hier geht". Der Mensch pflegt nichts. Er sieht, was die KI
getan hat, und nimmt es mit einem Wisch zurück. Entschieden: lieber ein Feld leer lassen als falsch
füllen (Precision vor Recall).

Der Eingangsweg (Siri, Watch, Teilen, Textfeld) ist austauschbar. Das Thema ist der Rohtext.

## Was schon feststeht

### Die Kalibrierung zu #23 wurde falsch gelesen

Sie sollte die Schwelle 0,6 bestätigen. Was sie zeigt: Die Konfidenz, die das Modell über sich selbst
berichtet, trennt richtige von falschen Antworten nicht. Über alle Schwellen von 0,3 bis 0,9 bleibt die
Trefferquote gleich, und das Modell setzt fast jedes Feld.

| Feld | Gesetzt (von 59) | Trefferquote bei 0,6 | Zufall |
|---|---|---|---|
| Wichtigkeit | 54 | 35 % | 33 % (3 Klassen) |
| Dringlichkeit | 52 | 25 % | 33 % (3 Klassen) |
| Dauer | 57 | 51 % | 20 % (5 Klassen) |
| Energie | 47 | 23 % | 33 % (3 Klassen) |

Wichtigkeit, Dringlichkeit und Energie liegen auf Zufallsniveau, und das Modell füllt sie in über 90 %
der Fälle. „Lieber leer als falsch" setzt einen Schalter voraus, der leer von falsch unterscheidet.
Diesen Schalter gibt es Stand heute nicht: Das Gerätemodell liefert keine Wahrscheinlichkeiten, nur eine
erfundene Zahl im Ausgabeschema. Die tragendste Annahme des Produkts ist damit die einzige, die bereits
gemessen wurde, und sie hält nicht.

Zwei Einschränkungen: Der FocusBlox-Korpus ist kein Rohtext-Korpus (`rawText` ist dort der gepflegte
Titel), und Wichtigkeit, Dringlichkeit und Energie wurden in FocusBlox von Hand in einer Matrix gesetzt,
nicht aus dem Text abgeleitet. Die Wahrheit, gegen die gemessen wurde, ist also selbst nur teilweise aus
dem Text ableitbar. Das entschuldigt das Ergebnis nicht, es verschiebt die Frage: Steht die Information
überhaupt im Text? (Annahme A2.)

### Belegt aus der Recherche (Stand 2026-09-19)

- **Gerätemodell je Familie.** iPhone 16 Pro bekommt unter iOS 27 nur AFM 3 Core (3 Mrd. Parameter).
  Core Advanced (20 Mrd.) braucht 12 GB Speicher: iPhone 17 Pro/Air, M4-iPad, M3-Mac. Die Watch hat kein
  Gerätemodell, nur Private Cloud Compute ab watchOS 27 (online, Tageslimit). iPad nur ab M1 oder A17 Pro.
- **Sprache.** Ob das Modell antwortet, hängt an der Sprache unter „Apple Intelligence & Siri", nicht an
  der Systemsprache. Deutsch wird unterstützt.
- **Messumgebung.** Hennings Mac (M4, 16 GB, macOS 26.6.1) hat das Modell aktiv, Deutsch, Kontext 4096
  Token. Er rechnet aber mit der Modellgeneration von 2025; das iPhone rechnet mit dem neu gebauten
  27er-Modell. Jede Messung auf dem Mac misst ein anderes Modell als das im Produkt. Die Annahme, der
  Simulator nutze das Modell des Mac, hat sich nicht bestätigt — siehe „Die Messumgebung" weiter unten.
- **Bekannte Ausfälle.** Verweigerungen durch Guardrails bei harmlosem Text (in iOS 27 reduziert, nicht
  beseitigt), Rate Limit in Erweiterungsprozessen (#21), Kaltstart ein bis zwei Sekunden, Typen und
  Verhalten wechseln zwischen Punktversionen.
- **Werkzeuge.** Apple liefert mit macOS 27 die `fm`-Kommandozeile und ein Evaluations-Framework mit
  Modell-Richter. Beides fehlt auf macOS 26. Für die Experimente reicht ein Swift-Skript (verifiziert).

### A3 gemessen (2026-09-20, iPhone 16 Pro, 317 Sätze in zwölf Bauformen)

Bericht: `docs/reference/date-title-fidelity.md`, Befund in #67.

| Kriterium | Abbruch | Modell | `NSDataDetector` | Regelparser (#92) |
|---|---|---|---|---|
| Datum exakt | < 95 % | 50 % von 138 | 65 % | 99,3 % von 139 |
| Erfundene Daten bei Sätzen ohne Zeitangabe | > 2 % | 96,5 % von 170 | 0 % | 0 % von 170 |
| Uhrzeit exakt | – | 57,1 % von 21 | – | 100 % von 24 |
| Titel mit erfundenen Fakten | > 2 % | 0,3 % von 308 | – | – |

**Titel hält, Datum reißt.** Der Titel ist über alle Bauformen sauber, auch bei Diktaten,
Stichwörtern und Tippfehlern; die Satzform spielt keine Rolle (stützt B2). Das Datum reißt
doppelt: Wochentage rechnet das Modell falsch (0–22 % exakt, „morgen / in N Tagen" 78 %), und bei
Sätzen ohne Zeitangabe setzt es fast immer den Erfassungstag aus dem Prompt. Das ist A1 am Datum:
Das Modell weiß nicht, dass es nichts weiß. Im Produkt wäre das keine Korrektur per Handgriff,
sondern eine Heute-Ansicht voller erfundener Fälligkeiten.

**PO-Entscheidung (Henning):** „Warum willst du Dinge mit einem LLM lösen, die sich durch einfache
Regel und RegEx lösen lassen?" Das Datum kommt aus einem deterministischen Parser (#92), das Modell
verliert das Datumsfeld. Die Kalenderrechnung dafür existiert bereits als Regelwerk des Korpus.
Dieselbe Frage gilt künftig für jedes Feld zuerst: Regeln, wo sie reichen; das Modell nur für
Sprachverstehen. #86 und #90 sind damit geschlossen.

**Der Regelparser, gemessen (2026-09-20, #92 Schnitt 1).** Der eigene Zeitausdruck-Parser DE/EN
(`Measurement/DateExpressionParser.swift`, `Measurement/TimeExpressionParser.swift`) trifft 138 der
139 Datumssätze; der eine Fehlversuch ist der Tippfehler „Am Freitga den Zählerstand melden", und er
lässt das Feld leer, statt zu raten. Auf den 170 Kontrollsätzen und den acht Wiederholungen erfindet
er kein einziges Datum, die Uhrzeit trifft er auf allen 24 Sätzen. Gerechnet wurde auf dem Mac gegen
einen festen Referenztag (Do 12.3.2026), ohne Modell und ohne Gerät — die Zahl ist in CI
wiederholbar (`DateParserCorpusTests`). Die Grenze aus #67 hält damit für das Datum, aber ohne das
Modell: Regeln 99,3 %, Modell 50 %. Der Umbau der App (Schnitt 2) ist damit freigegeben.

## Die Annahmen, nach Tödlichkeit

Jede Annahme hat ein Experiment, das ohne App, ohne Oberfläche und ohne Henning läuft, ein
Abbruchkriterium und mindestens eine Alternative zum bisherigen Weg. Die Alternativen sind der Grund,
warum diese Liste vor dem nächsten Feature steht: Vieles ist entschieden, aber nichts davon ist Gesetz.

### Stufe A: Bricht sie, ist das Produkt tot

| # | Annahme | Experiment | Abbruch | Alternative | Issue |
|---|---|---|---|---|---|
| A1 | Das Modell weiß, wann es nicht weiß | Drei Ersatzsignale je Feld: Selbstkonsistenz über fünf Läufe, Enthaltung bei signalfreiem Text, Zweitmeinung eines stärkeren Modells. Kurve Trefferquote über Abdeckung | Kein Signal erreicht ≥ 85 % Trefferquote bei ≥ 30 % Abdeckung | Vorschlag statt Setzen (kippt „still" für dieses Feld); Feld aus Historie statt Text; Feld und Ansicht in v1 weglassen | #65 |
| A2 | Die Information steht im Text | Obergrenze: starkes Modell, gleiche Eingaben, gleiche Wahrheit, mehrfach gesampelt | Starkes Modell unter 60 % je Feld | Feld nur aus Historie; Feld nie automatisch; Feld aus der Pipeline streichen | #66 |
| A3 | Falsch kostet nur einen Handgriff | Datum: relative Ausdrücke DE/EN gegen den Tag des Laufs plus Kontrolle ohne Datum, zusätzlich `NSDataDetector` als Vergleich. Titel: Entitäten erhalten, nichts erfunden | Datum < 95 % exakt oder > 2 % erfunden; Titel > 2 % Halluzination | Datum deterministisch parsen, Modell wählt nur; Titel = gekürzter Rohtext; Personen ohne Modell oder weglassen | #67 |
| A4 | Das Modell ist da, wenn erfasst wird | Nachweis auf Geräten: Matrix Gerät × Prozess × Zustand, Wartezeit bis Veredelung | Kein Abbruch, Designfolge | Veredelung auf genau einem Gerät, Sperrfeld gegen Doppellauf; nur im Vordergrund, sichtbar „wird geprüft"; PCC-Fallback für Geräte ohne Modell | #68 |

Zu A3 gehört eine Beobachtung, die kein Experiment löst: Ein falscher Kontext ist unsichtbar. Die Aufgabe
erscheint unter Garten, gesucht wird sie unter Computer, der Marker steht dort, wo niemand hinschaut.
Das Versprechen „ich sehe, was die KI getan hat" gilt nur für Felder an der Aufgabe, nicht für die
Ansicht, in der sie fehlt. Alternative: „Neu" zeigt jede KI-Zuordnung zu einem Kontext als eigene Zeile,
bis sie gesehen wurde.

### Stufe B: Das Produkt lebt, aber „still und ohne Pflege" gilt nicht mehr

| # | Annahme | Experiment | Abbruch | Alternative | Issue |
|---|---|---|---|---|---|
| B1 | Retrieval lernt wirklich | Auslass-Test mit/ohne k Nachbarn gegen Rauschen; Konventionstest (drei Korrekturen, vierte Aufgabe) | Differenz ≤ Rauschen, oder Konventionstest < 8/10 | Regeln aus Korrekturen ohne Modell; Retrieval-Mehrheit statt Prompt-Beispiel; ADR-5 auf „Regeln plus Retrieval" | #69 |
| B2 | Die Textform ist egal | Gleicher Inhalt in vier Formen: getippt, diktiert, Mail-Auszug, Englisch | < 80 % Übereinstimmung getippt/diktiert; Mail setzt Felder aus Signatur | Vorverarbeitung ohne Modell (kürzen, Signatur weg, Diktat normalisieren); kanalspezifische Prompts | #70 |
| B3 | Guardrails lassen Alltag durch | Korpus plus 100 heikle Alltagstexte, Mac und iPhone getrennt | > 1 % Verweigerung | Verweigerung als sichtbarer Zustand; zweiter Versuch gekürzt; Parser-Fallback | #71 |
| B4 | Der Lauf ist bezahlbar | Token je Prompt/Antwort, Sekunden je Aufgabe, Nachzügler mit 50 Aufgaben | > 2500 Token oder > 10 s je Aufgabe | Schema ohne Begründungen und ohne Konfidenz; zwei Läufe (Titel/Datum zuerst, weiche Felder später); Beispiele als Kurzform | #72 |
| B5 | Das Modell bleibt, wie gemessen | Dauerlauf: Messreihe je OS-Stand, Vergleich zur letzten | Feld fällt um > 10 Punkte | Apples Evaluations-Framework; eigenes lokales Modell über die `LanguageModel`-Schnittstelle, selbst versioniert | #73 |

### Stufe C: Kostet Komfort

- **Abhängigkeiten über PCC** (#27): online, Tageslimit, und im Korpus gibt es keine Wahrheit dafür,
  weil `blockerTaskID` in FocusBlox nie gesetzt war. Unprüfbar, bis echte Daten existieren.
  Alternative: Abhängigkeit nur per Nutzergeste, keine Erkennung in v1.
- **Personen ohne Kontakte:** Diktat macht aus Andrea einen Andreas. Messbar wie Titel-Treue (#67) —
  **zurückgestellt (Henning, 2026-09-21):** kein bekannter Use Case, deshalb nicht gemessen. Das
  Feld (`TaskItem.people`) bleibt vorerst im Produkt (Merkmalzeile, Detail, Signal für Wichtigkeit/
  Dringlichkeit), aber ohne Qualitätsnachweis. Offene Frage, ob es überhaupt bleiben soll: #105.
- **Projektzuordnung** nur aus der Namensliste, bei null Projekten leer. Harmlos.

## Was bereits festgelegt ist, und welche Alternative jede Festlegung hat

| Festlegung | Wo | Alternative, falls die Messung sie kippt |
|---|---|---|
| Still setzen, Schwelle 0,6, Marker danach | ADR-3, R2-3 | Vorschlag statt Setzen je Feld; oder Schwelle durch Selbstkonsistenz ersetzen (#65) |
| Veredelung im Intent-Prozess, Nachzügler beim App-Start | ADR-4, ADR-9 | Ein Gerät veredelt, alle anderen liefern Rohtext (#68) |
| Lernen über Prompt-Beispiele | ADR-5 | Regelmotor aus Korrekturen, Retrieval-Mehrheit (#69) |
| Ein Prompt, ein Schema für alle Felder und Kanäle | `FoundationModelsEnricher` | Zwei Läufe; Parser für Datum; kanalspezifische Vorverarbeitung (#67, #70, #72) |
| Apples Gerätemodell als einziges Modell | Antwort 8 | PCC als Fallback; Fremdmodell über die neue Schnittstelle; eigenes lokales Modell (#73, #74) |
| Zehn abgeleitete Felder | Datenmodell | Weniger Felder in v1: nur die, deren Signal trägt. Ansichten folgen den Feldern, nicht umgekehrt |

## Die Messumgebung, am 2026-09-19 auf dem Gerät nachgemessen

Die Fragen aus #74 sind mit Runde 4 beantwortet (R4-1 bis R4-4). Beim Aufbau der ersten Messreihe
(#67) kamen drei Befunde dazu, die jede weitere Messreihe betreffen:

- **Der Simulator misst nichts.** Der iOS-27-Simulator meldet `SystemLanguageModel` als verfügbar,
  jeder Aufruf scheitert aber auf einem macOS-26-Host an fehlenden Modelldateien („Model Catalog
  error … no underlying assets"). Messreihen laufen deshalb ausschließlich auf dem iPhone.
- **Ein echtes iPhone führt keinen Test ohne Träger-App aus.** Apple unterstützt reine Logiktests
  nur im Simulator; auf dem Gerät braucht das Testbündel eine Host-App und eine eigene Info.plist
  zum Signieren. Beides steht jetzt in `project.yml`, gefahren wird über `sim.sh device-measure`.
- **Auf Akku drosselt Apple nach wenigen Aufrufen.** Der erste vollständige Lauf brach nach drei
  Sätzen ab: „Client rate limit exceeded" aus der Guardrail-Prüfung. Apple nennt als Bedingung
  Akkubetrieb und Hintergrundprozess; am Netzteil ist keine Drosselung zu erwarten. Messläufe
  brauchen das iPhone am Strom, entsperrt und ohne automatische Sperre. Für das Produkt heißt
  derselbe Befund: Ein Nachzügler-Lauf über viele Aufgaben im Hintergrund läuft in dieselbe Grenze
  (#21, #72).

**Daraus folgt der Aufbau jeder weiteren Messreihe.** Ein Testlauf belegt das Gerät am Stück und
entsperrt, bis er fertig ist — Hennings iPhone ist ein Arbeitsgerät, kein Prüfstand. Gemessen wird
deshalb in einer eigenen, wegwerfbaren Labor-App (`LooseEndsLab`), die in Scheiben misst: Er öffnet
sie, wenn es ihm passt, jeder Satz wird sofort gesichert, ein Abbruch kostet nichts, beim nächsten
Öffnen läuft sie weiter. Nach seinem Tippen darf sie über `BGContinuedProcessingTask` im
Hintergrund weiterrechnen — sichtbar in der Dynamic Island, jederzeit abbrechbar; von selbst
startet nichts (seine Entscheidung). Die Ergebnisse holt der Mac still aus dem App-Container
(`sim.sh lab-fetch`), gerechnet wird dort.

Weil sich eine Messreihe damit über Tage zieht, trägt **jeder einzelne Satz seinen eigenen Messtag
und seine eigenen Bedingungen** (Vordergrund/Hintergrund, Akku/Strom, Akkustand, Stromsparmodus,
Wärmezustand). Der Bericht weist die Trefferquote nach Bedingung getrennt aus. Damit ist die Frage
„wurde unter realistischen Bedingungen gemessen?" nicht mehr Auslegungssache, sondern eine Zeile in
der Tabelle.

## Was vorher geklärt werden muss (#74)

- **Welches Modell gemessen wird.** Mac = 26er-Generation, iPhone = 27er. Entweder macOS 27 auf dem Mac
  (Hennings Arbeitsrechner, seine Entscheidung; misst dann Core Advanced, also wieder nicht das iPhone),
  oder die Messreihe läuft als Test auf dem iPhone (langsam, entsperrt). Empfehlung: iPhone als Referenz.
- **Geräteinventar.** Welches iPad, welche Watch, und je Gerät die Sprache unter Apple Intelligence & Siri.
- **Ein Rohtext-Korpus mit Wahrheit existiert nicht.** Die FocusBlox-Datenbank liegt auf dem Mac
  (iCloud-Sync der macOS-App, kein USB nötig) und wurde am 2026-09-19 direkt geprüft: 287 Aufgaben,
  alle mit Quelle `local`, keine aus Siri oder Mail. Titel im Schnitt 27 Zeichen; 108 Aufgaben haben
  eine Beschreibung, die im Schnitt 38 Zeichen lang und meist eine Kopie des Titels ist. Rohe Sätze,
  wie sie Loose Ends erfasst, gibt es dort nicht. Was es dort gibt und was die Spikes nutzen sollen:
  Tags an allen 287 Aufgaben (Wahrheit für Kontexte, nach Zuordnung auf das neue Startset), 159
  KI-Dauer-Vorschläge, von denen Henning 46 geändert hat, und 86 KI-Tag-Vorschläge. Das sind echte
  Korrekturpaare, die einzigen im Bestand. Für Wichtigkeit, Dringlichkeit und Energie gab es keine
  Vorschläge, nur Handwerte. Für Datum und Titel-Treue ist selbst geschriebene Wahrheit objektiv und
  erlaubt. Die einzige Quelle für echte Rohtexte sind die Erfassungen, die Loose Ends seit dem Start
  auf dem iPhone gespeichert hat, samt Hennings Korrekturen.
- **Ob der Korpus das Gerät verlassen darf.** Für die Obergrenzen-Messung und für einen Modell-Richter.
  PCC oder Dritter, das ist ein Datenschutzentscheid.
- **Hintergrund und Sperre.** Ob das Modell bei gesperrtem Gerät antwortet und ob der Nachzügler-Lauf im
  Hintergrund startet, ist nirgends dokumentiert. Nur auf dem Gerät prüfbar (#68).

## Was sich nicht messen lässt, und warum der Versuch schadet

- **Vertrauen.** Es entsteht in Hennings ersten Wochen mit der App. Jede Frage danach erzeugt Antworten,
  die den Wunsch spiegeln, bei einer Person, und verbraucht den einzigen unverdorbenen Ersteindruck.
  Ehrlicher Ersatz: die Korrekturquote über Wochen, ohne Vergleichsgruppe.
- **Ob Garten, Schnell und Alt die richtigen Fragen sind.** Produktdefinition. Eine Metrik dafür würde
  Bedeutung vortäuschen.
- **Die wahre Energie oder Wichtigkeit einer Aufgabe.** Es gibt keine Wahrheit außer Hennings Urteil im
  Moment, und das schwankt. Die Obergrenze zu kennen hieße, ihn dieselben Aufgaben zweimal bewerten zu
  lassen. Das macht ihn zum Annotator und widerspricht dem Produkt, in dem er nichts pflegt.
- **Wie schwer ein Fehler wiegt.** Der Schaden je Fehlerart ist ein Werturteil. Die Rangfolge oben ist
  eine Setzung, keine Messung.
- **Künftiges Modellverhalten.** Apple tauscht das Modell. Beobachtbar (#73), nie beweisbar.

## Empfohlene Reihenfolge

#74 (Antworten), dann #67 und #65 auf dem iPhone, dann #66. Erst wenn ein Feld ein tragfähiges
Unsicherheitssignal hat, verdient es eine Ansicht. #68 läuft parallel, sobald das Inventar bekannt ist.
#69 vor #26. #70 bis #72 danach, #73 als Rahmen für alles.

## Quellen

- [What's new in the Foundation Models framework, WWDC26](https://developer.apple.com/videos/play/wwdc2026/241/)
- [Introducing the Third Generation of Apple's Foundation Models](https://machinelearning.apple.com/research/introducing-third-generation-of-apple-foundation-models)
- [Apple Support: Siri AI und Gerätestufen](https://support.apple.com/en-us/127893)
- [Apple Support: Apple Intelligence Geräte und Sprachen](https://support.apple.com/en-us/121115)
- [Foundation Models unavailable due to language restriction, Apple Developer Forums](https://developer.apple.com/forums/thread/805378)
- [Overly strict rate limit in app extension, Apple Developer Forums](https://developer.apple.com/forums/thread/789788)
- [Guardrail false positives, Apple Developer Forums](https://developer.apple.com/forums/thread/793876)
- [Vadim Drobinin: Foundation Models in a real app](https://drobinin.com/consulting/foundation-models-apple-intelligence/putting-apple-foundation-models-in-a-real-app/)
- [Michael Tsai: Apple Foundation Models in appleOS 27](https://mjtsai.com/blog/2026/06/16/apple-foundation-models-in-appleos-27/)
- [Meet the Evaluations framework, WWDC26](https://developer.apple.com/videos/play/wwdc2026/298/)
- [Build AI-powered scripts with the fm CLI, WWDC26](https://developer.apple.com/videos/play/wwdc2026/334/)
- [NLContextualEmbedding, Sprachen, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10042/)
- [TN3193: Context window](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window)

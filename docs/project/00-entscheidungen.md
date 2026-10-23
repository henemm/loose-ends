# Nachfolger-App: Entscheidungslog

> Erstellt: 2026-09-16
> Status: Briefing abgeschlossen (PO: Henning, Tech Lead: Claude)
> Zweck: Grundlage für User Story, Datenmodell und das Claude-Design-Briefing

## Grundsatzentscheidung

**Neues Projekt statt Refactoring.** FocusBlox ist eine Timeboxing- und Coaching-App;
die Nachfolger-App ist ein Erfassungs- und Ansichten-Werkzeug mit stiller KI-Veredelung.
Das ist ein anderes Produkt, kein aufgeräumtes altes. FocusBlox wird eingefroren.

Begründung aus der Codebase-Analyse (siehe Session-Protokoll):
- 39.400 LoC Produktivcode, 61.300 LoC Tests, davon 770 UI-Tests an Accessibility-IDs gebunden
- 8.800 LoC Mac-Parallel-UI mit duplizierter Geschäftslogik
- Task-Modell mit ~45 Feldern, dreifach handgepflegt (LocalTask, WatchLocalTask, PlanItem)
- Keine ViewModel-Schicht, SwiftData-Objekte direkt in Views
- Hooks erlauben max. 5 Dateien / ±250 LoC je Workflow: Strukturumbau darunter nicht durchführbar

**Organspende aus FocusBlox** (kopieren, nicht refactoren):
Foundation-Models-Services (Enrichment, Titel-Engine, Scoring, Split), EventKitRepository
mit Protokoll und Mock, SpotlightIndexingService, App-Intents-Entities, beide Share-Extensions,
NotificationService, `docs/reference/learnings.md`.

**Nicht übernehmen:** RecurrenceService, Fokusblöcke, Coach, Review, Disziplin,
alles in `FocusBloxMac/`, alle UI-Tests.

## Antworten des PO (Runde 1 und 2)

| # | Frage | Antwort |
|---|-------|---------|
| 1 | App Store? | Noch nicht. Keine Nutzer außer Henning. |
| 2 | Warum gescheitert? | Die Idee Timeboxing hat nicht gezündet. |
| 3 | Kalender zurück? | Nur als Option: terminierte Aufgabe im Kalender anzeigen. |
| 4 | Migration? | Nicht zwingend. Daten als Lernkorpus exportieren: ja. |
| 5 | Kanäle zuerst | Siri, Watch, Control Center. |
| 6 | E-Mail | Nur Apple Mail. Wege: Siri auf einer Mail und Teilen-Menü. Rücksprung zur Mail: ja. |
| 7 | Erfassung | Ein Textfeld. Im Hintergrund die meisten FocusBlox-Attribute. App lernt aus alten Aufgaben. |
| 8 | Modelle | On-device, Private Cloud Compute ok, Fremdmodell als Fallback optional. |
| 9 | Wichtigkeit | Wörter, Historie, weitere Signale (siehe Datenmodell). |
| 10 | KI-Änderungen | Überschreiben ok. Muss sichtbar (Marker an der Aufgabe) und reversibel sein. Nur eine Prozessierung je Aufgabe. |
| 11 | Abhängigkeiten | Nur innerhalb der App. |
| 12 | Lernen aus Korrekturen | Ja. |
| 13 | Ansichten | Feste Dimensionen. Natürliche Sprache später als Experiment. |
| 14 | Standort | ~~Keine Standort-Berechtigung.~~ Neu gefasst 2026-10-06 (#226): Eine Aufgabe kann einen Ort tragen und erinnert beim Ankommen oder Verlassen. Gefragt wird „Beim Verwenden der App“, erst beim ersten Ort. Anlass: Siri liefert im Reminders-Schema einen Ort (#25), und ohne Feld ginge er verloren. "Garten" bleibt Kontext (Tag), nicht Ort. |
| 15 | Heute-Ansicht | Nein. "Als nächstes" mit manueller Sortierung. |
| 16 | Plattformen | iPhone, Mac, Watch (nur Sprache rein). Maximales Code-Sharing. |
| 17 | Erinnerungen-Sync | Nein. |
| 18 | Teilen | Später. Einheit: Projekt = Liste. |
| 19 | iPhone 15 Pro Minimum | Ja. |
| 20 | Prozess | Plugin `henemm/agent-os-openspec`. |
| 21 | UI | Nach abgeschlossenem Briefing mit Claude Design. |
| R2-2 | Kontexte | Tags mit löschbarem Startset. |
| R2-3 | Unsicherheit | Konfidenzschwelle; darunter passiert nichts, Aufgabe ist als ungeprüft erkennbar. |
| R2-6 | Control Center | Direkt Diktat ohne App. Textfeld als Alternative. FocusBlox-Weg über Kurzbefehle war eine Katastrophe. |
| R2-10 | Kalender | Apple Kalender, nur anzeigen. Verschieben später. |
| R2-11 | Ansichten v1 | Vorschlag angenommen, plus "Wiederkehrend". |
| R2-12 | Blockierte Aufgaben | Aus "Als nächstes" ausgeblendet. |
| R2-13 | Projekte, Hierarchie | Ja, beides. Braucht exzellente UI. |
| R2-14 | Wiederholung in v1 | Ja, aber einfach gedacht. |
| R2-15 | Sprachen | Englisch Default, Deutsch von Anfang an. |
| R2-17 | Identität | Alles neu: Name, Bundle-ID, CloudKit-Container. |
| R2-18 | Tests/Prozess | Fast-Track für Gerüst, Unit-Tests statt UI-Tests bis die UI steht. |
| R3-1 | Navigation iPhone | Startscreen mit Kacheln (Option A). Tab-Leiste verworfen. |
| R3-2 | KI-Marker | Variante C: getönte Merkmale. Geänderter Titel trägt zusätzlich den Funken. |
| R3-3 | Farbe | Sehr einfarbig ist gewollt, aber mit Farbbudget (ADR-14). FocusBlox war bunt, nicht unübersichtlich. |
| R3-4 | Parken | Ja, in Version 1. |
| R3-5 | Mitteilungs-Aktionen | Ja, in Version 1: Erledigt, Als nächstes, Morgen. |
| R4-1 | Daten für Messungen (#74) | Nur Apples Cloud (Private Cloud Compute). Kein Fremdmodell. |
| R4-2 | Messgerät (#74) | iPhone 16 Pro ist die Referenz. Der Mac bleibt auf macOS 26. |
| R4-3 | Geräte (#74) | iPhone 16 Pro, iPad mit M-Chip, ein älteres iPad ohne Gerätemodell, Apple Watch. |
| R4-4 | Rohtexte als Messkorpus (#74) | Ja, die echten Erfassungen aus Loose Ends. Lokal auf dem Mac, nie im Repository. |

## Tech-Lead-Entscheidungen (ADR-Kurzform)

**ADR-1 Ein App-Target für iOS und macOS.** SwiftUI-Multiplattform-Target, Layout über
NavigationSplitView und Größenklassen. Kein separates Mac-Target, damit niemand hineinduplizieren kann.
Zusätzliche Targets: Watch-App, Widgets/Controls-Extension, App-Intents-Extension, Share-Extension.

**ADR-2 SwiftData mit CloudKit, private Datenbank, neuer Container.** Alle Entities mit UUID
und Besitzer-Feld, damit Projekt-Sharing später ohne Schema-Bruch möglich ist.
Enums als typsichere Swift-Enums mit String-Rohwert, keine losen Strings im Modell.

**ADR-3 Rohtext ist unveränderlich, alles andere ist abgeleitet.** Jedes abgeleitete Feld
trägt Herkunft (KI oder Nutzer) und Konfidenz. Kein Feld ist Pflicht.

**ADR-4 Veredelung genau einmal.** Bei der Erfassung, im Intent-Prozess (kein App-Start nötig),
mit Nachzügler-Lauf beim nächsten App-Start für Aufgaben ohne `processedAt`.
Erneute Analyse nur auf ausdrücklichen Nutzerwunsch.
Seit #95 markiert `processedAt` nur noch den Modelllauf: Der Regelschritt für das Fälligkeitsdatum
(`DueDateRule`) läuft unabhängig davon bei jeder Veredelung, weil er ohne Modell auskommt und
deterministisch ist — „genau einmal" gilt für das Modell, nicht für die regelbasierten Felder.
Seit #144 markiert `rulesAppliedAt` unabhängig davon, ob das Modell verfügbar war oder der
Modellaufruf glückte, dass der Regelschritt (Fälligkeitsdatum, Wichtigkeit, Dringlichkeit,
Wiedererkennung) für diese Aufgabe gelaufen ist; die Vergleichsmenge der Wiedererkennung
(`RecognitionRule`) liest `processedAt` und `rulesAppliedAt` gemeinsam, damit sie nicht am
Modell hängt.
Seit #535 setzt ein dauerhafter Modellfehler (Guardrail, Kontextfenster) `processedAt` ohne
KI-Revision, damit die Aufgabe nicht bei jedem Durchlauf erneut ans Modell geht; vorübergehende
Fehler (Zeitgrenze, Last, Gerätezustand, unbekannte Fehler) lassen es leer. „Neu analysieren"
bleibt der ausdrückliche zweite Versuch.
Seit #34 ist die erneute Analyse „Neu analysieren" im Detail-Menü: derselbe Regelschritt und
derselbe Modellaufruf wie beim ersten Mal (`EnrichmentCoordinator.reanalyze`). Sie darf jedes
Feld neu setzen, das der Nutzer nie angefasst hat — von der KI gesetzt oder noch leer —, jede
Änderung als neue KI-Revision vom alten Wert aus. Was der Nutzer gesetzt hat, bleibt; ein gleicher
Wert erzeugt keine Revision; fehlt ein Feld im neuen Ergebnis, wird nichts gelöscht. Regeln vor dem
Modell gilt auch hier: Ein Feld, das eine Regel trifft, überschreibt das Modell nicht.

**ADR-5 Lernen ist Wiedererkennung, kein Training** (geändert 2026-09-27, Henning, nach #69/#131).
Ursprünglich: ähnliche alte Aufgaben über Embeddings als Prompt-Beispiele. Die Messung hat das
gekippt — auf Hennings 287 echten Aufgaben trägt die Ähnlichkeitssuche nur dort, wo der Text fast
wortgleich wiederkehrt (Kontexte 100 %, Dauer 97,2 % bei ~60 % Abdeckung); bei bloß teilweise
ähnlichem Text fällt sie auf Rateniveau (55 %), bei Energie unter die Konstante. Deshalb gilt:
Ein bekannter Rohtext setzt die damaligen Werte still, mit KI-Marker und Revision wie jede
Anreicherung. Alles andere wird nicht aus Nachbarn abgeleitet. Korrekturen des Nutzers bleiben
Beispiele erster Klasse, erledigte Aufgaben werden nie gelöscht, die FocusBlox-Historie bleibt
Startkorpus und Evaluations-Datensatz. Prompt-Beispiele nach Ähnlichkeit sind damit gestrichen,
nicht verschoben — Beleg: `docs/reference/retrieval-leave-one-out-rules.md`.

**ADR-6 Revisionen statt Undo-Stack.** Jede KI- oder Nutzeränderung an einem abgeleiteten Feld
ist ein Revisions-Eintrag. Rückgängig pro Feld. Ein Rückgängig ist eine Korrektur und damit ein Lernbeispiel.

**ADR-7 Wiederholung ohne Serien.** Eine Aufgabe trägt optional eine Wiederholungsregel.
Beim Erledigen wird ein Erledigungs-Protokoll geschrieben und dieselbe Aufgabe rückt auf die
nächste Fälligkeit. Keine Vorlagen, keine Instanzen, keine Serien-IDs, kein Stacking.

**ADR-8 Hierarchie im Modell unbegrenzt, in der UI eine Ebene.** `parent` ist optional.
Version 1 zeigt Unteraufgaben als Liste innerhalb der Aufgabe. Projekte sind Listen und die
spätere Sharing-Einheit.

**ADR-9 Erfassung ohne App-Start.**
- Siri und Action Button: App-Schema `reminders.createReminder`, läuft in der App-Intents-Extension.
- Watch: Complication und Intent mit Diktat, läuft ohne iPhone-App.
- Control Center: Ein Control kann keine Eingabe abfragen. Das Control öffnet die App direkt in
  einer schlanken Erfassungs-Szene (kein Tab, kein Laden), das Mikrofon hört sofort (Speech-Framework),
  Textfeld als Alternative. Budget: unter einer Sekunde bis Eingabebereitschaft, per Test gemessen.
  Annahme zu prüfen im Spike: ob iOS 27 Controls mit Werteabfrage erlaubt. Falls ja, entfällt der App-Start.
- Mail: App-Schema für "mach daraus eine Aufgabe" plus Share-Extension. Aufgabe speichert die `message:`-URL.

**ADR-10 Lokalisierung ab Tag eins.** String Catalog, Englisch Basis, Deutsch parallel.
Prompts an das Modell in der Sprache des Nutzers, Ergebnisstruktur sprachunabhängig.

**ADR-11 Tests.** Unit-Tests für Veredelung (mit Fake-Modell über das `LanguageModel`-Protokoll),
Ansichtsberechnung, Wiederholungsregel, Revisionen. Evaluations-Framework für Prompts mit dem
FocusBlox-Korpus. UI-Tests erst nach Design-Freeze und nur als Smoke-Tests.
Auf Hennings Gerät läuft kein Testlauf und kein Fernstart einer App. Was sich nur auf echter
Hardware zeigt, wird gemessen (Labor-App) oder beobachtet, nie bedient. Bedienabläufe — auch
UI-Tests — bleiben im Simulator; ein Versuch, sie signiert auf dem Gerät zu fahren, überschrieb
2026-09-30 Hennings produktive Installation und bewies dabei nicht, wofür er gebaut war (#153).

**ADR-12 Prozess.** Plugin `agent-os-openspec`. Fast-Track für Projektgerüst, Modell, Targets,
Container. Danach Standard-Workflow mit 250-LoC-Grenze. Kein `try?` ohne Behandlung,
`Logger` statt `print`, Swift 6 Strict Concurrency, Deployment Target iOS/macOS/watchOS 27.

**ADR-13 Kalender.** EventKit: Aufgabe mit Fälligkeit und Schalter "im Kalender anzeigen"
erzeugt einen Termin in einem eigenen Kalender der App ("Loose Ends"); mit Uhrzeit ein Block so lang
wie die Dauer, ohne Uhrzeit ganztägig. Die App liest keine fremden Termine. Technisch braucht sie
trotzdem den vollen Zugriff, weil nur der eigene Termine wiederfinden, aktualisieren und entfernen
lässt (der reine Schreibzugriff seit iOS 17 kann das nicht). Gefragt wird erst, wenn die erste
Aufgabe in den Kalender will. Priorität Should, nicht Must.

**ADR-14 Farbbudget.** Jede Farbe hat genau eine Bedeutung, nie Farbe als einziger Unterschied:
Akzent = tippbar (inklusive KI-Tönung), Rot = Zeitdruck (überfällig, heute fällig, immer mit Text),
Grau-Abstufung = Hierarchie (blockiert, erledigt, ungeprüft), Grün = nur im Moment des Erledigens.
Nachgeschärft (Henning, 2026-10-14, #414): Nach ihrem Tag bleibt nur eine Fälligkeit mit Uhrzeit rot. Eine
Fälligkeit ohne Uhrzeit ist meist ein gesprochener Vorsatz („morgen“, „am Freitag“) und kein Zeitdruck; sie
steht danach grau als „Seit gestern“ bzw. „Seit N Tagen“ (`ViewRules.dueState`).
Neu gefasst (Henning, 2026-10-18, #548): Eine verpasste Frist ist erloschen („die alte kann ich nicht mehr einhalten“).
Mit Uhrzeit ist sie nach der Uhrzeit vorbei, ohne Uhrzeit nach dem Tag. Danach ist nichts mehr rot: In der Randspalte
steht der Akzent-Knopf „Neues Datum“ (tippbar) über der grauen Spur „war heute 15:00“ / „war gestern“ / „war Di.“
(`NewDateRule`, `ViewRules.MarginMark.passed`). Der Knopf öffnet die Datumswahl (Heute später, Morgen, Wochenende,
Nächste Woche, Kalender mit Uhrzeit, Parken, Erledigt). Die alte Zeit bleibt in den Revisionen.
Wichtigkeit und Energie haben keine Farbe, sie sortieren und tragen ein Glyph. Projekte dürfen eine
Nutzerfarbe zur Identifikation tragen (später), Kontexte bekommen Symbole. Jeder Screen muss in
Graustufen funktionieren. Begründung: FocusBlox nutzte zehn Farbtöne für elf Bedeutungen, Rot stand
für Wichtigkeit, Überfälligkeit, Tier und Löschen zugleich.

**ADR-15 Parken.** Status `parked`. Geparkte Aufgaben verlassen alle Ansichten außer „Geparkt“,
zählen in keinem Zähler und keiner Mitteilung, bleiben aber Lernkorpus und Wiederholungs-fähig.
Parken per Wisch in „Alt“ und über das Halten-Menü, Aktivieren per Wisch in „Geparkt“.

**ADR-16 Mitteilung mit Aktionen.** Version 1 kennt genau eine Mitteilung: am Fälligkeitstag zur
eingestellten Uhrzeit. Drei Aktionen ohne App-Start: Erledigt, Als nächstes, Morgen (Fälligkeit +1 Tag,
zählt als Korrektur). Keine Mitteilung für KI-Verarbeitung, keine Zusammenfassungen.
Ergänzt (Henning, 2026-10-14, #414): Die Einstellung „Noch offen am Tagesende“ erlaubt eine zweite, gebündelte
Mitteilung. „Morgens erinnern“ (Vorgabe) bringt zur Erinnerungszeit alles, was nach seinem Tag noch offen ist, in einer
Mitteilung zurück, an höchstens drei Morgen, mit „Heute nochmal“ und „Anzeigen“. „Still weitertragen“ schickt keine.
„Abends durchsehen“ schickt zur eigenen Abendzeit (Vorgabe 20:00) eine Mitteilung mit allem, was an diesem Tag fällig
und noch offen ist, mit „Alle auf morgen“ und „Durchsehen“ (Blatt „Von heute offen“: Erledigt, Morgen, Wochenende,
nächste Woche, Parken). Das ist ein freiwilliger Tagesreview; als Vorgabe bleibt er aus.
Neu gefasst (Henning, 2026-10-17, #518): Liegengebliebenes wird nicht weitergetragen, es braucht eine neue Fälligkeit.
Statt der Auswahl gibt es zwei Schalter, beide an: „Abends: neue Termine planen“ (Abendzeit, Vorgabe 20:00: „Neues Datum
nötig: N“ mit allem, was an dem Tag fällig war, an den drei Tagen danach und dann montags, bis es ein neues Datum hat;
„Alle auf morgen“ und „Durchsehen“) und „Morgens: lose Enden ansehen“ (eigene Morgenzeit, Vorgabe 9:00, jeden Tag, solange etwas offen ist:
„Lose Enden: N“, darunter was ein neues Datum braucht oder was am längsten offen ist; öffnet „Lose Enden“).
Nachgeschärft (Henning, 2026-10-18, #550, #551): Der Abend fragt erst, wenn die Frist hinter der Abendzeit liegt (mit
Uhrzeit nach der Uhrzeit, ohne Uhrzeit nach der Erinnerungszeit des Tages; liegt sie später, am nächsten Abend), und
„Alle auf morgen“ verschiebt nur, was beim Tippen noch kein neues Datum hat. Der Morgen ist nur die Einladung: „Lose
Enden: N“ (ohne Geparktes und ohne „wartet auf“) und „Am längsten offen“; die Zahl der Undatierten gehört dem Abend.
Zahl auf dem App-Icon (Henning, 2026-10-20, #584): genau „Fällig“ plus „Als nächstes“, jede Aufgabe einmal, wie die
Listen zählen; eine vorbeigegangene Zeit und ein früherer Tag zählen weiter, bis die Aufgabe ein neues Datum hat
(seit #518 fielen sie heraus, und das Icon sagte 3, während „Fällig“ 4 zeigte). Die Zahl ändert sich damit nur beim
Bearbeiten und beim Tageswechsel; den Tageswechsel bringt die Morgenmitteilung mit (`badge` im Inhalt), damit das Icon
ohne App-Start stimmt. Der Abend trägt keine Zahl.
Fallen Morgen- und Erinnerungszeit zusammen, kommt eine Mitteilung „Lose Enden: N · Heute: …“ statt zweier, und
Aufgaben ohne Uhrzeit bekommen an dem Tag keine Einzelmitteilung. Jedes Gerät meldet für sich. Der Plan hält ohne
App-Start: tägliche Hintergrund-Auffrischung und Neuplanung bei einem CloudKit-Import (#553).

**ADR-7 ergänzt (Henning, 2026-10-18, #552).** Ein neues Datum an einer wiederkehrenden Aufgabe gilt nur für diese
Runde: Die Serie steht auf ihrem Anker (`RepeatRule.anchor`), das Erledigen rechnet von dort weiter, nicht vom
verschobenen Datum. Der Anker wandert mit jeder Runde; Regeln von früher ohne Anker rechnen wie bisher vom Datum.

**ADR-19 Felder: zeigen, was da ist (Henning, 2026-10-18, #538).** Die Detailseite zeigt nur, was die Aufgabe trägt,
in fünf Gruppen und einer Ordnung (Was · Wann · Gewicht · Ablage · Zusammenhang); alles Leere steht in einer Wortzeile
darunter, je Gruppe umgebrochen. Wiederholung und Kalender warten auf Fällig, Unteraufgaben und Wartet auf auf die oberste
Ebene. Fest ohne Schalter: Titel, Gesagt, Fällig, Herkunft, Quelle. Eine Seite „Felder“ in den Einstellungen
schaltet je Feld, ob es angeboten wird; aus heißt nie versteckt. Vorgabe an: Notiz, Anhänge, Im Kalender, Dauer,
Etiketten. Die Wahl gilt auf allen Geräten (iCloud-Schlüsselwertspeicher) und steuert auch die Gruppen der Startseite.

**ADR-8 ergänzt: eine Zeile, die bei Bedarf Aufgabe wird (Henning, 2026-10-20, #565).** Eine Unteraufgabe wird schnell
als Zeile angelegt und abgehakt; „Details“ an der Zeile öffnet ihr eigenes Detail mit denselben Feldern wie eine Aufgabe,
oben „Teil von …“. Eine Ebene tief, kein zweites Konzept „Checkliste“ daneben. Außerhalb ihrer Aufgabe erscheint sie nur
mit eigenem Merkmal: eigenes Datum überall, wo eine Aufgabe mit Datum steht („Fällig“, „Jetzt“, „Lose Enden“ bei den
Datierten, „Nächste Tage“ auf dem Mac; Henning, 2026-10-21, nachdem eine auf morgen verschobene Zeile bis dahin nirgends
mehr stand), eigenes Etikett in dessen Liste, immer mit ihrer Aufgabe in der Zeile; „Neu“ und „Als nächstes“ bleiben
bei obersten Aufgaben. Wer eine Aufgabe mit
offenen Unteraufgaben erledigt, wird gefragt: „Alle erledigen“ oder „Offene behalten“; Widget und Mitteilung fragen nicht
und lassen Offenes offen. Regeln lesen auch die Zeile (Fällig aus dem Text, Etikett-Wort), das On-Device-Modell nie: die
Zeile bleibt, was der Nutzer gegliedert hat, und bekommt kein zweites Konzept als Aufgabe im Eingang. Die anderen Regeln
(Wichtigkeit, Dringlichkeit, Wiedererkennen, Telefonnummer, Projekt) bleiben bei obersten Aufgaben; „Neu analysieren“
an einer Zeile läuft nur über diese zwei Regeln.

**ADR-20 Antrieb: Das Knäuel und die Perlen (Henning, 2026-10-23, #642, Recherche und Konzept in
`07-antrieb-recherche-und-konzept.md`).** Zwei optionale Felder einer Aufgabe, beide aus für neue Nutzer, beide in der
Felder-Liste (ADR-19), keine Seite „Antrieb“. **Das Knäuel** (#643): genau eine offene Aufgabe, vor der man sich drückt,
von Hand gesetzt (Halten-Menü, „…“ im Detail); eine zweite Aufgabe fragt erst, ob es wandern soll. Solange es eins gibt,
steht im Kopf der Startseite am Datum statt des grauen Knotens das schwarze Knäuel (ein Fünftel größer, das Datum beginnt
64 pt eingerückt bündig über dem Aufgabentext), und die Aufgabe steht als eigene Zeile unter dem Datum, vor dem Satz des
Tages, nicht noch einmal in „Jetzt“. `knaeuelAt` auf `TaskItem`, jede Änderung eine Revision mit `author == user`
(`RevisedField.knaeuel`); Erledigen lässt die Marke auf der erledigten Aufgabe (die Schnur liest sie), Parken, Zurückholen
und Löschen nehmen sie, eine neue Runde einer Wiederholung auch. Das Knäuel ist eine von Hand gezeichnete Linie aus der
Familie des Logo-Fadens (`ThreadShape.Form.knaeuel`): **zweite Ausnahme von #350** nach dem Faden selbst. Kein Satz
darüber, kein Zähler, kein Rot, wenn es liegen bleibt. **Zählt** (#645): eine Aufgabe zählt oder nicht, keine Gewichte,
keine Punkte, höchstens fünf offene zugleich (`TaskActions.countsBudget`; der Eintrag heißt dann „Zählt (5 von 5)“ und ist
grau); das Knäuel zählt immer. `countsAt` auf `TaskItem`, Revision `RevisedField.counts`. Die Perle (Schnur mit hohler
Perle und Glanzpunkt, `PearlGlyph`, dritte Ausnahme von #350) steht an erster Stelle der Merkmalzeile. Die **Schnur der
Woche** (`ViewRules.weekBeads`, Montag bis Sonntag unabhängig vom Gebietsschema) steht unter „Jetzt“, solange die Woche
eine Perle hat: eine durchhängende Schnur, die Perlen von links dicht aufgereiht, keine leeren Plätze, kein Wochenziel, die
neueste 1,1 s grün (der eine grüne Moment, ADR-14). Nichts wird gespeichert: die Schnur ist aus `completedAt` bzw. den
`CompletionRecord`s zählender Aufgaben gerechnet. Bewusst nicht gebaut: Serien, Punkte für jede Aufgabe, Vergleich,
Mitteilungen, Lob (Belege in 07, Teil 2.4).

**ADR-17 Ergänzte Screens nach Lückenprüfung.** Als nächstes (manuell sortiert), Neu (Eingang),
Feld-Picker statt Formular, Wisch- und Halten-Gesten mit Verschieben (Morgen, Wochenende, nächste Woche,
Datum), Erledigt mit Zurückholen, Erfassung aus Mail, Bestätigung, Alt mit Parken, Mitteilung.
Aus FocusBlox übernommen: verzögertes Erledigen mit Abbrechen durch erneuten Tipp, Halten-Vorschau,
Suche, Wiederherstellen aus Erledigt. Nicht übernommen: tippbare Badges in der Zeile, Kategoriefarben,
Prioritäts-Score, Hygiene-Kartenstapel, Sprint-Button.

**ADR-18 Prüfkennung.** Jeder signierte Gerätebau (`./scripts/sim.sh device-build` und jeder
künftige Geräte-Testweg) trägt die Kennung `com.henning.looseends.probe` samt eigener App-Gruppe
und eigenem iCloud-Container, Anzeigename „LE Prüfbau". Debug (Hennings Xcode-„Run") und Release
bleiben beim Standard-Suffix (leer) und damit bitgleich zu heute. Anlass: Der Gerätelauf von #153
installierte 2026-09-30 unter Hennings Produktivkennung und überschrieb seine Installation. Die
Kennung hängt am Prüfweg, nicht an der Build-Konfiguration — Begründung und Alternative in
`docs/specs/tooling/fix-156-pruefkennung.md` (#156).

## Bewusst nicht in Version 1

Fokusblöcke, Timer, Coaching, Tagesreview (außer der Wahl „Abends durchsehen“, #414), Disziplin-Statistiken, Aufgabentyp (Einkommen,
Wartung, Erholung), Erinnerungen-Sync, Teilen, freie Fragen in natürlicher Sprache,
Kalender-Verschieben, Watch-Lesen, Projektfarben, Mehrfachauswahl.

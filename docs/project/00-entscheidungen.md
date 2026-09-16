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
| 14 | Standort | Keine Standort-Berechtigung. "Garten" ist Kontext (Tag), nicht Ort. |
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

**ADR-5 Lernen ist Retrieval, kein Training.** Ähnliche alte Aufgaben (on-device Embeddings,
NaturalLanguage-Framework) werden mit ihren endgültigen Attributen als Beispiele in den Prompt gegeben.
Korrekturen des Nutzers sind Beispiele erster Klasse. Erledigte Aufgaben werden nie gelöscht.
Die FocusBlox-Historie wird als Startkorpus und als Evaluations-Datensatz exportiert.

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

**ADR-12 Prozess.** Plugin `agent-os-openspec`. Fast-Track für Projektgerüst, Modell, Targets,
Container. Danach Standard-Workflow mit 250-LoC-Grenze. Kein `try?` ohne Behandlung,
`Logger` statt `print`, Swift 6 Strict Concurrency, Deployment Target iOS/macOS/watchOS 27.

**ADR-13 Kalender.** EventKit nur schreibend: Aufgabe mit Fälligkeitszeit und Schalter
"im Kalender anzeigen" erzeugt einen Termin in einem eigenen Kalender der App. Priorität Should, nicht Must.

**ADR-14 Farbbudget.** Jede Farbe hat genau eine Bedeutung, nie Farbe als einziger Unterschied:
Akzent = tippbar (inklusive KI-Tönung), Rot = Zeitdruck (überfällig, heute fällig, immer mit Text),
Grau-Abstufung = Hierarchie (blockiert, erledigt, ungeprüft), Grün = nur im Moment des Erledigens.
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

**ADR-17 Ergänzte Screens nach Lückenprüfung.** Als nächstes (manuell sortiert), Neu (Eingang),
Feld-Picker statt Formular, Wisch- und Halten-Gesten mit Verschieben (Morgen, Wochenende, nächste Woche,
Datum), Erledigt mit Zurückholen, Erfassung aus Mail, Bestätigung, Alt mit Parken, Mitteilung.
Aus FocusBlox übernommen: verzögertes Erledigen mit Abbrechen durch erneuten Tipp, Halten-Vorschau,
Suche, Wiederherstellen aus Erledigt. Nicht übernommen: tippbare Badges in der Zeile, Kategoriefarben,
Prioritäts-Score, Hygiene-Kartenstapel, Sprint-Button.

## Bewusst nicht in Version 1

Fokusblöcke, Timer, Coaching, Tagesreview, Disziplin-Statistiken, Aufgabentyp (Einkommen,
Wartung, Erholung), Standort, Erinnerungen-Sync, Teilen, freie Fragen in natürlicher Sprache,
Kalender-Verschieben, Watch-Lesen, Projektfarben, Mehrfachauswahl.

# Datenmodell und Ansichten (Version 1)

> Erstellt: 2026-09-16
> Status: Entwurf, Tech-Lead-Vorschlag
> Grundlage: `00-entscheidungen.md` (ADR-2 bis ADR-8)

## Prinzipien

1. Der Rohtext ist die einzige Nutzereingabe und unveränderlich.
2. Jedes abgeleitete Feld ist optional und trägt Herkunft und Konfidenz.
3. Es gibt genau eine Aufgabe je Sache. Keine Vorlagen, Instanzen, Spiegel-Structs, Watch-Kopien.
4. Alles, was die UI zeigt, ist aus dem Modell berechnet. Nur "Als nächstes" hat manuellen Zustand.
5. Enums sind Swift-Enums mit String-Rohwert. Beziehungen sind optional (CloudKit-Anforderung).

## Entities

### Task

| Feld | Typ | Herkunft | Anmerkung |
|------|-----|----------|-----------|
| id | UUID | System | stabil, auch für App Intents und Spotlight |
| ownerID | String | System | für späteres Sharing |
| rawText | String | Nutzer | unveränderlich |
| capturedAt | Date | System | |
| capturedVia | enum CaptureChannel | System | siri, watch, control, share, mail, app, actionButton |
| sourceURL | URL? | System | `message:` bei Mail, sonst Share-URL |
| status | enum TaskStatus | System/Nutzer | unprocessed, unverified, active, parked, done |
| parkedAt | Date? | Nutzer | gesetzt bei Parken, gelöscht bei Aktivieren |
| processedAt | Date? | System | genau einmal gesetzt (ADR-4) |
| nextRank | Double? | Nutzer | nur gesetzt, wenn in "Als nächstes" |
| completedAt | Date? | Nutzer | bei Wiederholung: siehe CompletionRecord |
| project | Project? | KI/Nutzer | |
| parent | Task? | Nutzer | Hierarchie, UI zeigt eine Ebene |
| blockedBy | [Task] | KI/Nutzer | Finish-to-Start, Zyklus verboten |
| repeatRule | RepeatRule? | KI/Nutzer | eingebettet, siehe unten |
| showInCalendar | Bool | Nutzer | ADR-13 |
| calendarEventID | String? | System | |

### Abgeleitete Felder auf Task

Jedes dieser Felder existiert dreifach: Wert, `…Source` (enum FieldSource: ai, user), `…Confidence` (Double 0…1).
Leerer Wert bedeutet: nicht gesetzt oder unter Schwelle.

| Feld | Typ | Werte |
|------|-----|-------|
| title | String? | kurzer, aktiver Satz; nie leer, sonst Rohtext anzeigen |
| dueDate | Date? | Tag oder Tag mit Uhrzeit (`dueHasTime: Bool`) |
| importance | enum Importance? | low, medium, high |
| urgency | enum Urgency? | low, medium, high |
| duration | enum Duration? | minutes5, minutes15, minutes30, hour1, hours2plus |
| energy | enum Energy? | low, medium, high |
| contexts | [Context] | 0…n, Startset löschbar |
| people | [String] | Namen aus dem Text, keine Kontakte-Berechtigung in v1 |

### Context

| Feld | Typ |
|------|-----|
| id | UUID |
| name | String (lokalisierbar für Startset) |
| isSystemDefault | Bool |
| sortOrder | Int |

Startset: Computer, Telefon, Haus, Garten, Unterwegs, Besorgung. Alle löschbar und umbenennbar.

### Project

| Feld | Typ | Anmerkung |
|------|-----|-----------|
| id | UUID | |
| ownerID | String | Sharing-Einheit später |
| name | String | |
| sortOrder | Int | |
| archivedAt | Date? | |

### Revision

| Feld | Typ | Anmerkung |
|------|-----|-----------|
| id | UUID | |
| task | Task? | |
| field | enum RevisedField | title, dueDate, importance, urgency, duration, energy, contexts, people, project, blockedBy, repeatRule |
| oldValue | String? | JSON-kodiert |
| newValue | String? | JSON-kodiert |
| author | enum FieldSource | ai, user |
| reason | String? | Modellbegründung, ein Satz |
| createdAt | Date | |

Regeln: Eine Aufgabe zeigt den Marker, solange sie Revisionen mit `author == ai` hat, die der Nutzer
noch nicht gesehen hat (`seenAt` auf der Revision). Rückgängig schreibt eine neue Revision mit
`author == user` und dem alten Wert. Revisionen werden nie gelöscht.

### CompletionRecord

| Feld | Typ |
|------|-----|
| id | UUID |
| task | Task? |
| completedAt | Date |
| dueDateAtCompletion | Date? |

Bei Aufgaben ohne Wiederholung reicht `Task.completedAt`. Bei Wiederholung wird je Erledigung
ein Record geschrieben und die Aufgabe rückt weiter. Der Korpus fürs Lernen sieht so alle Erledigungen.

### RepeatRule (eingebettet, Codable)

| Feld | Typ | Werte |
|------|-----|-------|
| frequency | enum | daily, weekly, monthly, yearly |
| interval | Int | 1…n |
| weekdays | [Weekday]? | nur bei weekly |
| basis | enum | fromDueDate, fromCompletion |

Beim Erledigen: `CompletionRecord` schreiben, `dueDate` auf das nächste Datum gemäß Regel setzen,
`status` bleibt active. Kein Erledigt-Zustand für die wiederkehrende Aufgabe selbst.
Beenden der Wiederholung: `repeatRule = nil`, dann normale Erledigung.

### SavedView

| Feld | Typ | Anmerkung |
|------|-----|-----------|
| id | UUID | |
| name | String | |
| kind | enum ViewKind | next, new, due, quick, old, waiting, repeating, parked, done, context, project |
| contextID / projectID | UUID? | bei kind context/project |
| isSystem | Bool | Systemansichten nicht löschbar, aber ausblendbar |
| sortOrder | Int | |

Version 1 hat keine freien Filterregeln. Die Ansichtsarten sind im Code definiert und getestet.

## Ansichten (Berechnungsregeln)

Alle Ansichten zeigen nur `status in (unprocessed, unverified, active)` und keine Aufgaben mit
`parent != nil` (Unteraufgaben erscheinen in ihrer Elternaufgabe). Ausnahmen: "Alt" zeigt auch
blockierte, "Geparkt" zeigt nur `parked`, "Erledigt" zeigt nur `done`.

| Ansicht | Regel | Sortierung |
|---------|-------|------------|
| Als nächstes | `nextRank != nil` und nicht blockiert | nextRank manuell |
| Neu | `status in (unprocessed, unverified)` oder Revision `author == ai` ungesehen | capturedAt absteigend |
| Fällig | `dueDate <= heute + 7 Tage` | dueDate aufsteigend, überfällig zuerst |
| Schnell | `duration in (minutes5, minutes15)` | urgency, importance |
| Alt | `capturedAt < heute − 30 Tage` | capturedAt aufsteigend |
| Wartet | `blockedBy` enthält mindestens eine offene Aufgabe | blockierende Aufgabe zuerst |
| Wiederkehrend | `repeatRule != nil` | dueDate aufsteigend |
| Geparkt | `status == parked` | parkedAt absteigend |
| Erledigt | `status == done` | completedAt absteigend, nach Tagen gruppiert |
| Kontext X | `contexts` enthält X | urgency, importance, dann capturedAt |
| Projekt P | `project == P` | manuell innerhalb des Projekts, sonst capturedAt |

"Blockiert" heißt: mindestens eine Aufgabe in `blockedBy` hat `status != done`.

## Aktionen auf einer Aufgabe

| Aktion | Wo | Wirkung |
|--------|----|---------|
| Erledigt | Wisch rechts, Halten-Menü, Mitteilung | `status = done`, `completedAt`; bei repeatRule: CompletionRecord und nächste Fälligkeit. Drei Sekunden abbrechbar durch erneuten Tipp. |
| Als nächstes | Wisch links, Halten-Menü, Mitteilung | `nextRank` setzen oder entfernen |
| Verschieben | Halten-Menü: Morgen, Wochenende, nächste Woche, Datum; Mitteilung: Morgen | `dueDate` ändern, Revision `author == user` |
| Parken / Aktivieren | Wisch in „Alt“ und „Geparkt“, Halten-Menü | `status = parked` bzw. `active`, `parkedAt` |
| Zurückholen | Wisch rechts in „Erledigt“ | `status = active`, `completedAt = nil`, letzter CompletionRecord bleibt |
| Feld ändern | Detail, Picker je Feld | Revision `author == user`, Lernbeispiel |
| Löschen | Halten-Menü, Detail-Menü | hart, nach Rückfrage, nicht rückgängig |
| Neu analysieren | Detail-Menü | zweite Verarbeitung, ausdrücklich |

## Mitteilungen

Genau eine Art in Version 1: „Heute fällig“ am Fälligkeitstag zur eingestellten Uhrzeit (Standard 9:00),
nur für `status == active`. Aktionen ohne App-Start: Erledigt, Als nächstes, Morgen. Keine Mitteilung
für KI-Verarbeitung.

## Veredelungs-Pipeline

1. **Auslöser:** Erfassung (im Intent-Prozess oder in der App). Nachzügler: beim App-Start alle
   Tasks mit `processedAt == nil`.
2. **Retrieval:** Embedding des Rohtexts (NaturalLanguage-Framework, on-device). Die fünf ähnlichsten
   Tasks mit `status == done` oder mit mindestens einer Revision `author == user` werden geladen.
   Ihre endgültigen Attribute gehen als Beispiele in den Prompt.
3. **Modell:** `SystemLanguageModel` (on-device) mit `@Generable`-Ergebnisstruktur: alle abgeleiteten
   Felder je mit Konfidenz und einer Begründung in einem Satz. Kontextvokabular und Projektnamen
   werden als erlaubte Werte mitgegeben. Deutsche und englische Eingaben.
4. **Schwelle:** Konfidenz unter 0,6 (initial, per Eval justiert): Feld bleibt leer.
   Titel unter Schwelle: `status = unverified`, Titel = Rohtext.
5. **Abhängigkeiten:** Zweiter, optionaler Schritt mit `PrivateCloudComputeLanguageModel`
   (32K Kontext) gegen die Titel aller offenen Aufgaben. Nur wenn mehr als zehn offene Aufgaben
   existieren und das Gerät online ist. Ergebnis: `blockedBy` mit Konfidenz.
6. **Schreiben:** Felder setzen, je Feld eine Revision mit `author == ai`, `processedAt` setzen,
   Spotlight-Index aktualisieren (`IndexedEntity`).
7. **Fehler:** Modell nicht verfügbar (kein Apple Intelligence, Gerät gesperrt, Limit): Task bleibt
   `unprocessed`, Nachzügler-Lauf beim nächsten Start. Keine stillen `try?`.

### Signale für Wichtigkeit und Dringlichkeit (Prompt-Anweisung)

- Explizite Wörter: dringend, sofort, bis, spätestens, Frist, Mahnung, Kündigung, Steuer
- Personen im Text: jemand wartet darauf
- Geldbeträge und Behördensprache
- Ähnliche Aufgaben der Vergangenheit: wie wurden sie bewertet, wie schnell erledigt
- Herkunft: Mail von bestimmten Absendern, Erfassung unterwegs
- Wichtigkeit und Dringlichkeit bleiben getrennte Felder.
- Alter ist keine Wichtigkeit, sondern eine eigene Ansicht.

## Lernkorpus aus FocusBlox

Export aus `LocalTask` nach JSON mit Mapping:
`title` → rawText und title (Source user), `tags` → contexts, `importance` (1…3) → Importance,
`urgency` → Urgency, `estimatedDuration` → Duration-Bucket, `aiEnergyLevel` → Energy,
`dueDate`, `createdAt` → capturedAt, `completedAt`, `blockerTaskID` → blockedBy,
`recurrencePattern` → RepeatRule wo abbildbar. Aufgabentyp und Fokusblock-Felder entfallen.
Der Export dient dem Retrieval (Startwissen) und dem Evaluations-Framework (Messung der Prompts),
nicht der Migration in die App-Datenbank.

Umgesetzt in `scripts/export-focusblox-corpus.swift` (Issue #23). Liest den SwiftData-Store von
FocusBlox direkt (read-only, per SQLite), keine Abhängigkeit vom FocusBlox-Xcode-Projekt. Konkrete
Zuordnungen, die in der Mapping-Tabelle offen waren:

- `urgency`: FocusBlox kennt nur `urgent`/`not_urgent` → `high`/`low`. `medium` bleibt unbelegt, da
  es dafür keine Quelle im Korpus gibt.
- `estimatedDuration` (Minuten) → `DurationBucket`: ≤5 `minutes5`, ≤15 `minutes15`, ≤30 `minutes30`,
  ≤60 `hour1`, sonst `hours2plus`.
- `recurrencePattern` "custom" kodiert seine Basis-Frequenz in `recurrenceMonthDay`
  (1001=täglich, 1002=wöchentlich, 1003=monatlich, 1004=jährlich — FocusBlox-interner Hack in
  `RecurrenceService.nextDueDate`), `recurrenceInterval` ist der Multiplikator. `monthDay` selbst
  (Tag im Monat) hat in `RepeatRule` keine Entsprechung und entfällt.
- Wochentage: FocusBlox zählt 1=Montag…7=Sonntag, `RepeatRule.weekdays` nutzt die
  `Calendar`-Zählung 1=Sonntag…7=Samstag — der Export rechnet um.
- Export lief am 2026-09-18 gegen den echten Store: 287 Aufgaben, `blockerTaskID` bei keiner davon
  gesetzt (Feld war in FocusBlox in der Praxis ungenutzt).

Export-Ausgabe enthält echte private Aufgabentitel und wird nie committed
(`docs/reference/focusblox-corpus.json` ist in `.gitignore`).

## App Intents und Spotlight

- `TaskEntity` konform zu `AppEntity`, `IndexedEntity`, Reminders-App-Schema (`reminders.reminder`).
  Schema-Felder: title, dueDate, notes (= rawText), isCompleted, list (= Project).
- Intents: `createReminder`, `updateReminder`, `deleteReminders`, `createList`; plus eigene:
  `CaptureTextIntent` (Rohtext rein), `CompleteTaskIntent`, `ShowViewIntent(kind)`.
- `ExecutionTargets`: Capture und Complete in der App-Intents-Extension, Show in der App.
- Watch: dieselben Intents, Diktat als Eingabe.
- Control Center: `ControlWidgetButton` mit `OpenCaptureIntent` (öffnet Erfassungs-Szene, ADR-9).

## Offene Punkte für den Spike

1. ~~Erlaubt iOS 27 einem Control die Werteabfrage (Diktat ohne App-Start)?~~ **Beantwortet
   (2026-09-17, Issue #20): Nein.** Controls unter iOS 27 bleiben auf Button-/Toggle-Intents
   beschränkt (`AppIntentControlConfiguration`, neu: `RunSystemShortcutIntent` fürs Starten von
   Shortcuts/Apps aus einem Widget-Button) — keine freie Werteabfrage oder Diktat direkt im Control
   Center. Die bestehende Lösung (Control öffnet die App in der schlanken Erfassungs-Szene,
   `LooseEndsWidgets/CaptureControl.swift`) bleibt damit der richtige Weg, kein App-Start-Entfall
   in Sicht.
2. ~~Läuft `SystemLanguageModel` verlässlich in der App-Intents-Extension und als Nachzügler in `BGAppRefreshTask`?~~
   **Beantwortet (2026-09-17, Issue #21): Nein, nicht verlässlich.** Foundation Models unterliegen in
   Extension-Prozessen einem strengen, nicht dokumentierten Rate Limit — ein Entwickler löste es
   bereits nach vier Anfragen im 30-Sekunden-Abstand aus (Fehlermeldung irreführend: "Safety guardrail
   was triggered", tatsächliche Ursache laut Systemlog Rate Limiting). Ein Apple-Frameworks-Engineer
   bestätigte: Rate Limiting greift, wenn das Gerät im Akkubetrieb ist UND der Prozess im Hintergrund
   läuft — der Entwickler berichtete Limits aber auch im Netzbetrieb. Offener Report bei Apple:
   FB18332004. Apples Empfehlung (nicht streamen, `respond` statt `streamResponse` nutzen) ist im
   Code bereits umgesetzt (`FoundationModelsEnricher.swift:19`).

   **Konsequenz für ADR-4:** Die Veredelung im Intent-Prozess (Siri/Shortcut-Erfassung ohne App-Start)
   darf nicht als verlässlich angenommen werden. Die bestehende Fehlerbehandlung der Pipeline (Schritt
   7: Modell nicht verfügbar → Task bleibt `unprocessed`, Nachzügler-Lauf beim nächsten App-Start)
   passt genau zu diesem Risiko und bleibt der Rettungsanker — keine Architekturänderung nötig, aber
   das Rate Limit sollte beim Eval/Test bewusst mit einkalkuliert werden (nicht nur "Modell nicht
   verfügbar auf altem Gerät" als Fehlerquelle testen, sondern auch "Rate Limit im Extension-Prozess").
   Für `BGAppRefreshTask` (App-Prozess, nicht Extension) ist laut Engineer-Aussage kein Rate Limit zu
   erwarten, solange das Gerät am Netz hängt — dort bleibt Verlässlichkeit ungetestet, aber das Risiko
   ist geringer als im Extension-Prozess.
3. Wie schnell ist der Kaltstart in die Erfassungs-Szene auf iPhone 15 Pro? Ziel unter einer Sekunde.
4. Konfidenzschwelle mit dem FocusBlox-Korpus kalibrieren (Evaluations-Framework).
5. Kann die Share-Extension aus Apple Mail die `message:`-URL zuverlässig erhalten?

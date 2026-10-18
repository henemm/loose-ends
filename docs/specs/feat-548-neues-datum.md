---
entity_id: feat-548-neues-datum
type: feature
created: 2026-10-18
updated: 2026-10-18
status: approved
workflow: feat-548-neues-datum
---

# Spec: #548, #550, #551, #552, #553 — Verpasste Frist ist keine Frist

## Approval

- [x] Approved (Henning, 2026-10-18, AskUserQuestion im Gespräch): alle Entscheidungen unten, „setze sie in einer für
  Dich passenden Reihenfolge ohne weitere Rückfrage um“.

## Purpose

Henning vor dem Abendblatt (Screenshot, 19:11, eine Aufgabe mit roter 15:00): „Was soll ich hier machen? Die Aufgabe
braucht ein neues Datum, aber wie?“ Und: „Ich habe mir vorgenommen, etwas bis heute Mittag zu erledigen. Hat nicht
geklappt. Nun muss ich mir eine neue Deadline überlegen, denn die alte kann ich nicht mehr einhalten.“

**Rein regelbasiert.** Datum, Uhrzeit, Kalendertage; kein Modell.

## Entscheidungen (Henning, 2026-10-18)

| Frage | Entscheidung |
|---|---|
| Verpasste Frist | Erloschen. Kein Rot. Knopf „Neues Datum“ (Akzent) plus graue Spur „war heute 15:00“ / „war gestern“ / „war Di.“, überall. |
| Wann vorbei | Mit Uhrzeit nach der Uhrzeit. Ohne Uhrzeit: in den Listen nach dem Tag; für den Abend nach der Erinnerungszeit des Tages (stille Uhrzeit). Liegt das nach der Abendzeit: nächster Abend. |
| Datumswahl | Heute später (solange der Tag läuft), Morgen, Wochenende, Nächste Woche, Kalender mit Uhrzeit, Parken, Erledigt. In der Ästhetik der App. |
| Unteraufgaben | Wie Aufgaben, mit dem Namen der übergeordneten Aufgabe. |
| Morgen | Nur Einladung: „Lose Enden: N“ und „Am längsten offen“. N ohne Geparktes und Wartendes. |
| Gleiche Minute | Morgenzeit = Erinnerungszeit → eine Mitteilung „Lose Enden: N · Heute: …“, keine Einzelmitteilung ohne Uhrzeit. Sonst beide. |
| Geräte | Jedes Gerät meldet für sich. |
| Wiederkehrend | Neues Datum nur für diese Runde; der Takt bleibt (nächster Montag). |
| Altes „Alle auf morgen“ | Verschiebt nur, was beim Tippen noch kein neues Datum hat (technische Festlegung). |

Abweichung vom Ticket #548, bewusst: „ohne Uhrzeit nach der Erinnerungszeit“ gilt nur für den Abend. In den Listen,
in „Jetzt“ und am App-Symbol bleibt eine Aufgabe ohne Uhrzeit den ganzen Tag heutig; sonst verließe um 9:01 alles
Tagesfällige die Startseite.

## Source

| Datei | Änderung |
|---|---|
| `Shared/Models/NewDateRule.swift` | NEU: `needsNewDate` (Listen), `deadline`/`passed` (Abend), `trace`, `laterToday` |
| `Shared/Models/ViewRules.swift` | `leftovers` über die Regel (Unteraufgaben dabei), `dueState` mit verpasster Uhrzeit von heute, `MarginMark.passed(Trace)` statt `missed`/`carried` |
| `Shared/Models/MarginText.swift` | Spur-Texte „was …“ |
| `Shared/Services/TaskActions.swift` | `setDue(_:to:hasTime:)`, Wiederholung vom Anker, Vorrollen bis hinter den Abschluss |
| `Shared/Models/RepeatRule.swift` | `anchor` (nur kodiert, wenn gesetzt; kein Schema) |
| `Shared/Notifications/CarryReminders.swift` | Abend erst nach der Frist, Unteraufgaben; Morgen als Einladung, `today` bei gleicher Minute, `mergesReminders`; `handle` nur für noch Undatiertes |
| `Shared/Notifications/DueReminders.swift` | `skipsDayOnly` |
| `LooseEnds/Views/TaskRow.swift` | Knopf plus Spur in der Randspalte (`onNewDate`, `asksNewDate`) |
| `LooseEnds/Views/NewDateSheet.swift` | NEU: die Datumswahl |
| `LooseEnds/Views/CarryReviewSheet.swift` | Zeilen mit Knopf, kein Wisch, kein Menü |
| `LooseEnds/Views/TaskListView.swift`, `TaskDetailView.swift`, `FieldEditorView.swift` | Sektion mit Unteraufgaben, Knopf und Wisch öffnen das Blatt; Detail zeigt „Neues Datum“ und Spur; Anker beim Anlegen einer Regel |
| `LooseEnds/Notifications/DueNotificationCenter.swift` | Erinnerungszeit in Plan und Aktion, Morgen-Text, Zusammenlegen, Import-Beobachter |
| `LooseEnds/Notifications/BackgroundRefresh.swift` | NEU (iOS): tägliche Auffrischung |
| `LooseEnds/App/LooseEndsApp.swift`, `ContentView.swift`, `project.yml` | Registrierung, Anforderung beim Gang in den Hintergrund, `fetch` und erlaubte Kennung |
| `LooseEndsTests/NewDateRuleTests.swift`, `RepeatAnchorTests.swift` | NEU; dazu angepasst: `MarginMarkTests`, `DueStateTests`, `CarryRemindersTests`, `DueRemindersTests`, `DueNotificationCenterTests` |

## Acceptance Criteria

- **AC-1:** Offene Aufgabe mit Uhrzeit, Uhrzeit vorbei (auch heute) → `MarginMark.passed`, Zeile mit Knopf „Neues Datum“ und Spur, nicht rot; aus „Jetzt“ und der Zahl am App-Symbol.
- **AC-2:** Offene Aufgabe ohne Uhrzeit → bis Tagesende `today`, danach `passed` mit Spur „war gestern“ / „war Di.“ / Datum.
- **AC-3:** Datumswahl: Heute später (nächste volle Stunde, mindestens 30 Minuten entfernt, nur bis 23:00), Morgen, Wochenende, Nächste Woche, Kalender mit Uhrzeiten als Wörtern, Parken, Erledigt; jede Wahl Nutzer-Revision.
- **AC-4:** Unteraufgabe mit verpasster Frist steht in „Neues Datum nötig“ (Fällig, Lose Enden) mit „Unteraufgabe von …“ und abends in der Mitteilung.
- **AC-5:** Abend: 15:00 heute → heute 20:00; 22:00 heute und 20:00 genau → Folgeabend; ohne Uhrzeit mit Erinnerungszeit 9:00 → heute, mit 21:00 → Folgeabend. Rhythmus drei Abende, dann montags.
- **AC-6:** „Alle auf morgen“ lässt eine inzwischen umdatierte Aufgabe stehen.
- **AC-7:** Morgen: Titel „Lose Enden: N“ ohne Geparktes und Wartendes, Text „Am längsten offen: …“; keine Liste von Undatierten. Nur Geparktes → kein Morgen.
- **AC-8:** Morgenzeit = Erinnerungszeit → Text beginnt mit „Heute: …“ für Tagesfällige ohne Uhrzeit, für sie keine Einzelmitteilung; mit Uhrzeit bleibt sie. Andere Minuten → beides.
- **AC-9:** Montag-Serie, auf Mittwoch verschoben, Mittwoch erledigt → nächster Montag; über den Folgemontag hinaus verschoben → der Montag danach; „ab Erledigung“ unverändert; alte Regel ohne Anker wie bisher.
- **AC-10:** Ein CloudKit-Import plant neu (`storeChangedElsewhere`); die Hintergrund-Auffrischung ist registriert und wird beim Gang in den Hintergrund angefordert.

## Abnahme

Stufe 1: Unit-Tests in CI. Stufe 2: Simulator-Belege für Zeile, Blatt und Abendblatt (offen, von der Cloud-Sitzung
nicht ausführbar). Stufe 3 über TestFlight, weil `LooseEnds/Notifications/`, `project.yml` und `Info.plist` berührt
sind: Abendmitteilung mit einer 22:00-Aufgabe erst am Folgeabend; morgens eine Mitteilung mit „Heute: …“ und keine
zweite in derselben Minute; eine auf der Watch erledigte Aufgabe fehlt abends; nach acht Tagen ohne App-Start kommt
die Morgenmitteilung weiter.

---
entity_id: feat-203-teil-c-zielkalender
type: feature
created: 2026-10-09
updated: 2026-10-09
status: draft
workflow: bug-203-kalender-termin
---

# Spec: #203 Teil C1 — Zielkalender je Aufgabe

## Approval

- [x] Freigegeben: Henning, 2026-10-09; gebaut trotz M4 auf seinen Wunsch (2026-10-12)

## Purpose

Entscheidung vom 2026-10-05 (#203): ein Kalender für alle Aufgaben, Standard „Loose Ends“, **je Aufgabe
änderbar**, sichtbar als Zeile „Kalender · ● Name ›“. Teil A (Konto) und Teil B (Rückfrage, Zeile
„Termin“) sind in `main`. Entscheidungen vom 2026-10-09:

- Die Auswahl bietet **alle beschreibbaren Kalender** (iCloud, Google, Exchange, Gerät; ohne
  abonnierte und Geburtstage).
- Fehlt der gewählte Kalender auf einem Gerät, trägt **dieses Gerät nichts ein** und zeigt einen
  grauen Hinweis.
- Der Standard für neue Termine wird änderbar, **je Gerät**, in einem neuen Einstellungsbildschirm.
  Das ist **Teil C2**, eigene Spec mit Entwurf vorab. C1 lässt den Standard bei „Loose Ends“.

## Verhalten (Acceptance Criteria)

- **AC-1 Zeile „Kalender“ wird tippbar.** „Kalender · ● Name ›“ öffnet die Auswahl. Ohne Wahl steht
  dort der Standard („Loose Ends“).
- **AC-2 Auswahl.** Liste der beschreibbaren Kalender, nach Konto gruppiert („iCloud“, „Google“ …),
  je Zeile Farbpunkt (Systemfarbe) und Name, Häkchen an der aktuellen Wahl. Ganz oben „Loose Ends“
  mit dem Zusatz „Standard“. Tippen wählt und schließt.
- **AC-3 Die Wahl gilt für die Aufgabe auf allen Geräten.** Gespeichert werden Kontoname und
  Kalendername (neue optionale Felder am `TaskItem`, `nil` = Standard). Jedes Gerät sucht den Kalender
  über diese beiden Namen.
- **AC-4 Termin wandert mit.** Wechselt die Wahl, steht der Termin danach im neuen Kalender und nicht
  mehr im alten.
- **AC-5 Kalender fehlt auf diesem Gerät.** Kein Termin von diesem Gerät, der Hinweis unter dem
  Schalter lautet „Den Kalender „Name“ gibt es auf diesem Gerät nicht.“ Die Zeile zeigt den Namen
  ohne Farbpunkt.
- **AC-6 Kein doppelter Termin.** Jeder Termin trägt eine Marke der Aufgabe (`looseends://task/<id>`
  als URL des Termins). Bevor ein Gerät einen Termin anlegt, sucht es im Zielkalender einen mit dieser
  Marke und übernimmt ihn. Das verhindert doppelte Termine, wenn zwei Geräte denselben iCloud-Kalender
  sehen (die Termin-ID gilt nur je Gerät).
- **AC-7 Aufräumen nur mit Marke.** Liegengebliebene Termine gelöschter Aufgaben werden im
  „Loose Ends“-Kalender wie bisher entfernt. In fremden Kalendern nur Termine mit der Marke — nie einen
  Termin, den die App nicht angelegt hat.
- **AC-8 Reste aus der Gegenprüfung von Teil A.** Scheitert ein Abgleich, verschwindet die alte
  Kalenderzeile, statt neben dem Hinweis stehen zu bleiben. Wird der Kalenderzugriff entzogen, ersetzt
  der Hinweis „Zugriff aus“ jeden älteren Hinweis sofort.
- **AC-9** Deutsche Texte im String-Katalog. Keine Revision für die Kalenderwahl: Sie ist kein
  abgeleitetes Feld (wie der Schalter selbst).

## Scope

`Shared/Models/TaskItem.swift` (zwei optionale Felder), `Shared/Services/CalendarSync.swift`
(Auflösung, Marke, Hinweis), `LooseEnds/Calendar/CalendarBridge.swift`, neue
`LooseEnds/Views/CalendarPickerSheet.swift`, `LooseEnds/Views/TaskDetailView.swift`,
`Localizable.xcstrings`, Unit-Tests `CalendarSyncTests`, ein UI-Test im Simulator für Auswahl und Zeile.
Geschätzt +230 LoC ohne Tests.

## Abnahme

- Unit-Tests für Auflösung, Marke, Aufräumen, Hinweis.
- Simulator: Kalender wählen, Termin steht im neuen Kalender, Zeile zeigt ihn (Bildbeleg).
- Neues Modellfeld: Vor dem nächsten TestFlight-Build läuft das CloudKit-Schema auf dem Mac und wird
  in Production veröffentlicht (CLAUDE.md, #175). Henning bekommt dafür nach dem Merge die Zeile.
- Geräteliste: kein Pfad berührt (`Shared/Models` steht nicht darauf).

## Alternativen (verworfen)

- Kalender-ID statt Namen speichern: Die ID gilt nur auf einem Gerät.
- Ersatzweise in „Loose Ends“ eintragen, wenn der Kalender fehlt: kann doppelte Termine erzeugen
  (Henning: dort nichts eintragen).

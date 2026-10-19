---
entity_id: feat-538-felder-ordnung
type: feature
created: 2026-10-19
updated: 2026-10-19
status: approved
workflow: feat-538-felder-ordnung
---

# Spec: #538 Detailseite zeigt, was da ist; Felder anbieten an einer Stelle; Einstellung „Felder“

## Approval

- [x] Entwurf freigegeben (Henning, 2026-10-18): https://claude.ai/artifact/VTnLFmeExsoRfF8N9AzGgW, Tafeln unter
  `docs/artifacts/feat-538-felder-ordnung/`. Umsetzung aller drei Schnitte beauftragt (Henning, 2026-10-19).

## Purpose

Die Detailseite hatte neun Abschnitte, sieben davon immer da, auch leer, jeder mit Überschrift und Knopf. Sie bot
alles an, statt zu zeigen, was die Aufgabe hat. Die sieben Regeln des Entwurfs:

1. Ein Abschnitt erscheint nur mit Inhalt.
2. Eine Wortzeile für alles Leere: `+ Notiz`, `+ Anhang`, `+ Fällig`, `+ Wiederholung`, `+ Kalender`, `+ Ort`, …,
   `+ Unteraufgabe`, `+ Wartet auf`. Die Knöpfe der leeren Abschnitte entfallen. („Ergänzen“ aus dem Entwurf ist
   seit #560 aus dem Detail entfernt.)
3. Eine Ordnung überall: Was · Wann · Gewicht · Ablage · Zusammenhang; Gruppen trennt ein Abstand, die Wortzeile
   bricht je Gruppe um.
4. Abhängige Felder warten: Wiederholung und Kalender erst mit Fällig; Unteraufgaben und Wartet auf nur oben.
5. Aus heißt nicht angeboten, nie versteckt.
6. Fest, ohne Schalter: Titel, Gesagt, Fällig, Herkunft, Quelle.
7. Eine Seite „Felder“ in den Einstellungen, ein Schalter je Feld, gilt für Detail, Wortzeile und Startseitengruppe,
   auf allen Geräten (iCloud-Schlüsselwertspeicher).

**Vorgabe (Henning, 2026-10-18):** an Notiz, Anhänge, Im Kalender, Dauer, Etiketten; aus Wichtigkeit, Dringlichkeit,
Energie, Wiederholung, Ort, Projekt, Unteraufgaben, Wartet auf.

**Rein regelbasiert.** Kein Modell.

## Source

| Datei | Änderung |
|---|---|
| `Shared/Models/DetailFields.swift` | NEU: `DetailField` (Gruppen, fest, Abhängigkeiten), `DetailFieldSettings` (an/aus, Speicherform), `DetailFields.carried`/`offered` (Regeln 1–5, rein) |
| `LooseEnds/App/FieldSettingsStore.swift` | NEU: Defaults + iCloud-Schlüsselwertspeicher; unter UI-Tests alles an, `--ui-testing-fields-standard` für die Vorgabe |
| `LooseEnds/Views/FieldSettingsView.swift` | NEU: Seite „Felder“, dieselbe Ordnung, Schalter je Feld, Hinweise aus dem Entwurf |
| `LooseEnds/Views/TaskDetailView.swift` | Fünf Gruppen, Abschnitte nur mit Inhalt oder nach Tipp auf ihr Wort (`opened`), eine Wortzeile je Gruppe, Kalender als Abschnitt erst wenn an |
| `LooseEnds/Views/NoteSection.swift`, `SubtasksSection.swift`, `WaitingOnSection.swift` | Öffnen bereit zur Eingabe (`startsEditing`/`startsPicking`); Notiz ohne Kopf |
| `LooseEnds/Views/SidebarView.swift` | Etiketten und Projekte auf der Startseite nur, solange ihr Feld an ist (Regel 7) |
| `LooseEnds/Views/SettingsView.swift`, `LooseEnds/App/LooseEndsApp.swift` | Zeile „Felder“, Speicher in die Umgebung |
| `LooseEndsTests/DetailFieldsTests.swift` | NEU: Ordnung, Vorgabe, Speicherform, Wortzeile, Abhängigkeiten, Getragenes, Speicher, iCloud |
| `LooseEndsUITests/FieldsSmokeTests.swift` | NEU: mit der Vorgabe: nur die fünf Wörter, keine leeren Abschnitte, Kalender erst mit Datum, Schalter wirkt auf Wortzeile und Startseite |
| `LooseEndsUITests/*` | Abschnitte über ihr Wort öffnen; Wiederholung und Kalender mit einem Datum im Text (Regel 4) |

## Acceptance Criteria

- **AC-1 (#539):** Notiz, Anhänge, Kalender, Ort, Unteraufgaben, Wartet auf erscheinen nur mit Inhalt; ihr Wort in der
  Wortzeile öffnet den Abschnitt bereit zur Eingabe (Notiz und Unteraufgabe mit Fokus, Wartet auf mit Auswahl, Ort mit
  Suche, Kalender schaltet ein und fragt wie #203).
- **AC-2 (#540):** Gesetzte Zeilen stehen in Gruppen Was · Wann · Gewicht · Ablage · Zusammenhang, je Gruppe ein
  Abschnitt (Abstand, keine Überschrift); die Wortzeile bricht je Gruppe um, dieselbe Ordnung.
- **AC-3 (#540):** Wiederholung und Kalender werden ohne Fällig nicht angeboten; Unteraufgaben und Wartet auf nicht an
  einer Unteraufgabe.
- **AC-4 (#541):** Einstellungen › Felder: ein Schalter je Feld in derselben Ordnung; Titel/Gesagt/Fällig stehen als
  „immer“. Aus nimmt das Feld aus der Wortzeile; Gesetztes bleibt sichtbar und bearbeitbar.
- **AC-5 (#541):** Etiketten und Projekte aus → ihre Gruppe fehlt auf der Startseite (Index-Zeile, iPad-Faltgruppe).
- **AC-6 (#541):** Die Wahl steht in Defaults und im iCloud-Schlüsselwertspeicher; ein anderes Gerät übernimmt sie.
- **AC-7:** Vorgabe wie oben; eine neue Aufgabe ohne Datum bietet Notiz, Anhänge · Fällig · Dauer · Etiketten.

## Abnahme

Stufe 1: `DetailFieldsTests`, `FieldSettingsStoreTests`, voller Unit-Lauf. Stufe 2: UI-Smoke und Mac-Galerie in CI
(Wortzeile, Abschnitte nach Tipp, Kalender über das Wort). Stufe 3: Kein Pfad der Geräteliste berührt (die Einstellung
läuft über den Schlüsselwertspeicher, nicht über `Shared/Persistence`).

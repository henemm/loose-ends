---
entity_id: feat-439-notiz
type: feature
created: 2026-10-15
updated: 2026-10-15
status: approved
workflow: feat-439-notiz
---

# Spec: #439 Notiz

## Approval

- [x] Approved (Henning, 2026-10-15): „langes Textfeld, dem ich zum Beispiel Telefonnummern oder andere Dinge ablegen kann,
  die idealerweise auch erkannt und verlinkt werden“. Eine diktierte Telefonnummer wandert automatisch in die Notiz.

## Schnitte

| Schnitt | Inhalt | Geräteliste |
|---|---|---|
| 1 | Feld `notes`/`notesSourceRaw`, `RevisedField.notes`, Abschnitt „Notiz“ in der Detailansicht, Erkennung per `NSDataDetector` | nicht berührt; Modelländerung → `mac-schema-init` vor dem TestFlight-Bau |
| 2 | Regel: Telefonnummer aus dem Rohtext in die Notiz (Regelschritt), raus aus dem Titel (`TitleRule`) | `Shared/Enrichment/EnrichmentCoordinator.swift` → Stufe 3 über TestFlight |

Rein regelbasiert, kein Modell. Ohne Modell funktioniert es, weil `NSDataDetector` Telefonnummern, Links und Adressen erkennt.

## Schnitt 1

### Source

| Datei | Änderung |
|---|---|
| `Shared/Models/TaskItem.swift` | `notes`, `notesSourceRaw` (additiv) |
| `Shared/Models/Enums.swift` | `RevisedField.notes` (am Ende) |
| `Shared/Services/FieldCodec.swift`, `RevisionService.swift` | Kodierung, Herkunft |
| `Shared/Services/NoteLinks.swift` | NEU: Treffer und `AttributedString` mit Links |
| `LooseEnds/Views/NoteSection.swift` | NEU: Abschnitt „Notiz“ |
| `LooseEnds/Views/TaskDetailView.swift` | Abschnitt nach den Feldern |
| `LooseEndsTests/NoteLinksTests.swift` | Unit-Tests |

### Acceptance Criteria

- **AC-1:** Die Detailansicht hat einen Abschnitt „Notiz“. Leer steht dort ein Eingabefeld, gefüllt der Text in New York mit einem Stift zum Bearbeiten.
- **AC-2:** Im Text sind Telefonnummern (`tel:` nur mit Ziffern und führendem +), Links, Mails und Adressen (Apple Karten) antippbar.
- **AC-3:** Beim Verlassen des Felds wird die Notiz als Nutzer-Revision geschrieben. Leer löscht sie, unverändert schreibt nichts.
- **AC-4:** Das Schema ändert sich nur additiv. Vor dem TestFlight-Bau läuft `mac-schema-init`, danach deployt Henning in der CloudKit-Konsole.

### Offen

- Das Siri-Schema (#25) bildet `notes` heute auf `rawText` ab. Mit dem echten Feld ist das neu zu entscheiden, sobald #25 drankommt.
- Ältere Builds lesen eine Revision mit `notes` als `title` (Fallback in `Revision.field`). Betrifft nur Geräte ohne den neuen Build.

### Abnahme

- Stufe 1: `NoteLinksTests`, voller Unit-Lauf und UI-Smoke in CI.
- Stufe 2: Die Cloud hat keinen Simulator, Beleg ist der UI-Smoke-Lauf.
- Stufe 3: Kein Pfad der Geräteliste berührt. Der TestFlight-Bau braucht wegen der Modelländerung vorher das CloudKit-Schema.

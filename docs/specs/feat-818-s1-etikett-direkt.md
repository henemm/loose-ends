---
entity_id: feat-818-s1-etikett-direkt
type: feature
created: 2026-11-04
updated: 2026-11-04
status: approved
workflow: feat-818-s1-etikett-direkt
---

# Spec: #818 Schnitt 1 — Etikett direkt an der Aufgabe anlegen

Issue #818 Punkt 2 „Etiketten müssen erweiterbar sein“. Henning, 2026-11-04 (Rückfrage): gemeint ist das Anlegen direkt an der Aufgabe.

## Approval

- [x] Approved — Henning am 2026-11-04 (Auswahl „Direkt an der Aufgabe anlegen“).

## Purpose

Eigene Etiketten gab es nur über „Neues Etikett“ in Seitenleiste und Katalogseite. Im Feldeditor „Etiketten“ der Aufgabe
lässt sich ein neues Etikett jetzt eintippen: gefunden oder angelegt, dann gleich auf die Aufgabe gesetzt.

Ohne Modell geht es nicht: nicht relevant (reine Eingabe, das Modell setzt nie Etiketten, #215).

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| Shared/Services/CatalogService.swift | MODIFY | `contextNamed(_:in:existing:defaults:)`: vorhandenes Etikett gleichen Namens (#157) oder neues |
| LooseEnds/Views/EditorPage.swift | MODIFY | `TagSentence` mit Feld „New tag“ unter dem Satz (`create`) |
| LooseEnds/Views/FieldEditorView.swift | MODIFY | `addTyped`: Etikett holen, als Nutzer-Revision auf die Aufgabe setzen |
| LooseEndsTests/CatalogServiceTests.swift | MODIFY | drei Tests |

LoC ≈ +90. Kein neuer Katalogschlüssel („New tag“ besteht). Kein Pfad der Geräteliste berührt.

## Implementation Details

- Ein getippter Name, den es gibt (getrimmt, Groß-/Kleinschreibung und Akzente egal), legt kein zweites Etikett an (#157), er setzt das vorhandene.
- Leerer Name tut nichts. Hat die Aufgabe das Etikett schon, bleibt alles.
- Das frisch eingefügte Etikett steht noch nicht im Query-Array `contexts`; der Codec ordnet nach Namen zu, deshalb wird er mit `contexts + [neu]` aufgerufen.
- Die Änderung ist eine Nutzer-Revision wie jedes Umschalten (ADR-6), `RevisionService.set`.

## Test Plan

- [ ] `typedNameFindsExisting`: „ garden “ findet „Garden“, es bleibt bei einem Etikett.
- [ ] `typedNameAddsNew`: „  Reading “ wird „Reading“, `sortOrder` hinter dem letzten.
- [ ] `typedBlankRejected`: Leerer Name wirft `emptyName`.
- [ ] Simulator-Abnahme (Stufe 2) in CI/`test-proof` nachzuholen: Feld tippen, Etikett erscheint im Satz, unterstrichen.

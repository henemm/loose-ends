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
steht jetzt nach dem letzten Etikett „Neues Etikett“. Es öffnet **denselben Namensdialog** wie dort (`CatalogEditor`,
Henning, 2026-11-04: nicht neu erfinden); das neue Etikett kommt sofort auf die Aufgabe.

Ohne Modell geht es nicht: nicht relevant (reine Eingabe, das Modell setzt nie Etiketten, #215).

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| LooseEnds/Views/CatalogEditing.swift | MODIFY | `catalogDialogs(…, didAddContext:)`: meldet ein eben angelegtes Etikett |
| LooseEnds/Views/EditorPage.swift | MODIFY | `TagSentence.addNew`: Knopf „New tag“ |
| LooseEnds/Views/FieldEditorView.swift | MODIFY | eigener `CatalogEditor`, `putOnTask` als Nutzer-Revision |

LoC ≈ +35. Kein neuer Katalogschlüssel („New tag“ besteht). Kein Pfad der Geräteliste berührt.

## Implementation Details

- Ein vorhandener Name wird wie auf den Katalogseiten abgelehnt („A tag with this name already exists.“, #157). Leer ist ein Abbruch.
- Das frisch eingefügte Etikett steht noch nicht im Query-Array `contexts`; der Codec ordnet nach Namen zu, deshalb wird er mit `contexts + [neu]` aufgerufen.
- Die Änderung ist eine Nutzer-Revision wie jedes Umschalten (ADR-6), `RevisionService.set`.

## Test Plan

Keine neue reine Logik, deshalb kein neuer Unit-Test; `CatalogServiceTests` decken Anlegen und Duplikat ab.

- [ ] Simulator-Abnahme (Stufe 2): im Etiketten-Feld „Neues Etikett“ tippen, Name eingeben, „Add“; das Etikett steht unterstrichen im Satz und auf der Aufgabe. Zweimal derselbe Name zeigt den Duplikat-Hinweis.

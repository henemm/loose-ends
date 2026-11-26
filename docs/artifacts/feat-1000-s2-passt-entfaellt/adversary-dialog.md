# Adversary Dialog — feat-1000-s2-passt-entfaellt
Spec: docs/specs/feat-1000-schnitt-2-passt-entfaellt.md
Datum: 2026-11-26 17:29

## Checkliste
- [x] **AC-1:** Das Detail einer frisch über die Schreibzeile erfassten Aufgabe zeigt keinen Knopf „Passt“ (`detailConfirmButton`) und keinen Hinweis `reviewNote`; das „…“-Menü hat keinen Eintrag „Passt“ und weiterhin „Erledigen“ (Test 1).
- [x] **AC-2:** Im App-Code gibt es keinen Wisch und keinen Menüeintrag „Looks right“, keine Datei `ReviewNote.swift`, keinen Parameter `reviewing` und keinen Abschnitt „Needs a look“; `grep -rn "Looks right\|ReviewNote\|reviewing\|Needs a look" LooseEnds/` findet nichts außer im Katalog (Codeprüfung in der Validierung).
- [x] **AC-3:** Öffnen des Details markiert die Änderungen der Regeln immer als gesehen (`markSeen()` ohne Bedingung in `onAppear`, Codeprüfung).
- [x] **AC-4:** Alle übrigen Unit- und UI-Tests bestehen, `StoreScreenshotsTests` ohne „Passt“-Schritt (Tests 2, 3).
- [x] **AC-5:** Simulatordurchlauf auf dem iPhone: Satz getippt, Return, Detail geöffnet, kein „Passt“; Beleg über `./scripts/sim.sh test-proof InboxDrawerSmokeTests`, Screenshot des Details geöffnet und beschrieben (Test 1).

## Dialog

### Runde 1
**Adversary:** Diff geprüft (5 Dateien, -171/+12). Grep über LooseEnds/ LooseEndsWatch/ Widgets/ Share/ Shared/ nach Looks right|ReviewNote|reviewing|Needs a look|detailConfirmButton|reviewNote|swipeConfirm|menuConfirm: im App-Code nur Kommentare in Shared/ (ViewRules, TaskActions, EnrichmentCoordinator) und die weiter bestehende `TaskActions.confirmReview` (Shared, S3-Kandidat, von Tests genutzt). Kein Aufrufer von `TaskDetailView(task:reviewing:)` mehr (ContentView:80, TaskListView:152, TaskDetailView:304/307, WaitingOnSection:28 kompilieren; `./scripts/sim.sh build` Build Succeeded).

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Views/TaskDetailView.swift:551
  Evidence: Toolbar enthält nur noch showsBarActions-Zweig und Menü; Test testFreshTaskDetailOffersNoLooksRight grün (test-proof 3/3); Screenshots s2-detail.png (keine Passt-Zeile, nur Zurück und „…“) und s2-menue.png (Complete, Next up, Tangle, bead, Move, Park, Analyze again, Delete) selbst geöffnet.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Views/TaskInteractions.swift:97
  Code reference: LooseEnds/Views/TaskListView.swift:117
  Code reference: LooseEnds/Views/TaskListView.swift:565
  Evidence: Swipe-Zweig `.new?` und Menüeintrag samt `confirm(_:)` entfernt; ReviewNote.swift gelöscht; `reviewSections` und New-Notiz in TaskListView entfernt (TaskListView.swift:117, :565); Grep ohne Treffer im Code.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Views/TaskDetailView.swift:313
  Evidence: `markSeen()` steht unbedingt in onAppear.
  Status: CONFIRMED

**Implementierer:** Kein Einwand.

### Runde 2
**Adversary:** Edge Cases. Breites iPad/Mac: `showsBarActions = isWide && task.isOpen` (TaskDetailView.swift:589) unberührt, Leiste zeigt Undo/Complete/Next/Move/Park; früher stand dort zusätzlich Passt nur im Nicht-Wide-Pfad, nun nichts. Erledigte/geparkte Tasks: Menü zeigt Restore/Activate (TaskInteractions.swift:133ff) unverändert. Gespeicherte Ansicht „Neu“ (ViewKind.new): fällt in den Standardzweig, Wisch „Complete“ (TaskInteractions.swift:97 default) statt vorher Passt; in Spec-Risiken genannt, nur über gespeicherten Zustand erreichbar, S3 entfernt den Fall. `kind`-Parameter bleibt für andere Zweige benutzt. Mac-Build (sim.sh mac-build) Build Succeeded. Abweichung (a) `Paper.wideNoteInsets` ungenutzt (Paper.swift:11): tote Konstante, harmlos, S3. (c) StoreScreenshotsTests: Diff entfernt nur den Passt-Schritt, die nachfolgenden Asserts (tags, duration) bleiben und hängen nicht von Passt ab; Kompilierung durch Gesamtbuild der UI-Tests (test-green UI-Lauf) gedeckt; Ausführung nur CI.

Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEnds/Views/Paper.swift:11
  Description: `wideNoteInsets` ist nach dem Entfernen von ReviewNote ohne Verwendung.
  Spec requirement: AC-2 — keine Reste der Review-Note
  Conflict: toter Code, kein Funktionsfehler; ausserhalb der Spec-Dateiliste.
  Remediation: in S3 mit ViewKind.new entfernen.

AC-4: test-green-output.txt: UI 3/3, Unit 1396 bestanden, 0 fehlgeschlagen, 13 übersprungen (die 13 sind Bestandsüberspringungen, unverändert, nicht durch diese Änderung). Unit-Tests ReviewTrayTests nutzen `TaskActions.confirmReview`, das bleibt, also kein Bruch.
**Implementierer:** F001 akzeptiert, S3.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: 1396 Unit bestanden, 0 fehlgeschlagen, 13 übersprungen (Bestand); UI InboxDrawerSmokeTests 3/3
Edge cases: geprüft, nur F001 (LOW, toter Code)
Checklist: 5/5

## Geprüfte Dateien

- sha256:9f4070ac21945baade6f78e4846381a9c313a0059f5d75e19e128a99318f6cdb  LooseEnds/Views/Paper.swift
- sha256:4d4e3c91e2f641cda0a265b47d0a33a60374289964d686154a0768ec5b2a90f3  LooseEnds/Views/TaskDetailView.swift
- sha256:929750b05ba9a7e41dcfc0cdf4319a8373d9ceb27d4c8284be4b01552c057cc4  LooseEnds/Views/TaskInteractions.swift

## Prüfbasis

- base: 6c87205ef8ee754c2eee5016b862d52528e90fcc
- blob:21932fbac116abd002c512d6c400a951e911e6ae  LooseEnds/Views/Paper.swift
- blob:77661508f4026030bf9355989534e5debd9f4f4f  LooseEnds/Views/TaskDetailView.swift
- blob:377e87c8afe93142902c7a58edeca70d323c5a5d  LooseEnds/Views/TaskInteractions.swift

## Geprüfte Dateien

- sha256:9f4070ac21945baade6f78e4846381a9c313a0059f5d75e19e128a99318f6cdb  LooseEnds/Views/Paper.swift
- sha256:4d4e3c91e2f641cda0a265b47d0a33a60374289964d686154a0768ec5b2a90f3  LooseEnds/Views/TaskDetailView.swift
- sha256:929750b05ba9a7e41dcfc0cdf4319a8373d9ceb27d4c8284be4b01552c057cc4  LooseEnds/Views/TaskInteractions.swift
- sha256:7544b5de7e58171c9214a6a39e7f5fbd34c6c8d1d2272f5b3a05099e5e127cfc  LooseEnds/Views/TaskListView.swift

## Prüfbasis

- base: 6c87205ef8ee754c2eee5016b862d52528e90fcc
- blob:21932fbac116abd002c512d6c400a951e911e6ae  LooseEnds/Views/Paper.swift
- blob:77661508f4026030bf9355989534e5debd9f4f4f  LooseEnds/Views/TaskDetailView.swift
- blob:377e87c8afe93142902c7a58edeca70d323c5a5d  LooseEnds/Views/TaskInteractions.swift
- blob:c9833b47771b421bad44103088eead150cc90f0e  LooseEnds/Views/TaskListView.swift

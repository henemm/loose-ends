---
entity_id: feat-622-schnitt-1-claude-revisionen
type: feature
created: 2026-11-15
updated: 2026-11-15
status: draft
workflow: feat-622-claude-verlauf
---

# Spec: Aufträge von Claude hinterlassen eine Revision, Schnitt 1 (Logik, #622)

## Approval

- [ ] Approved

## GitHub Issue

#622 (Epic #612). Schnitt 1 von 2; das Issue bleibt offen (PR mit `Refs #622`, nie `Closes #622`), weil Schnitt 2 und der claude.ai-Nachweis offen bleiben.
Analyse: `docs/context/feat-622-claude-verlauf.md`. Vorgänger: #613 C4b-2 (`docs/specs/feat-613-c4b2-mcp-complete-setdue.md`) und PR #867 (Aufträge `complete`, `setNext`, `park`, `addSubtask`).

## Purpose

Die Definition of Done von #622 verlangt „Jede Änderung ist eine Nutzer-Revision mit Grund Claude“. Heute schreibt nur `setDue` eine Revision; `complete`, `setNext`, `park` und `addSubtask` ändern die Aufgabe, ohne dass die App später sagen kann, dass Claude es war. Dieser Schnitt schließt die Lücke in der Logik: jeder dieser vier Aufträge schreibt genau eine Revision (Autor `.user`, Grund „Claude“), und Nebenrevisionen, die die Aktion selbst schreibt (Knäuel-Marke fällt), tragen denselben Grund.

**Regeln vor Modell:** reine Datenlogik über das Revisionsmodell, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Nicht in diesem Schnitt

- **Schnitt 2 (Sichtbarkeit)** mit eigener Teil-Spec und eigenem Workflow: Einstiegszeile „Zuletzt von Claude · <Zeit>“ im Detail (Entwurf A, von Henning am 2026-11-15 gewählt, `docs/artifacts/feat-622-claude-verlauf/index.html`), Autor „Claude“ im Änderungsblatt, UI-Test dazu. Bis dahin sind die neuen Zeilen nur im Änderungsblatt sichtbar, das sich bisher nur bei automatischen Feldern öffnen lässt.
- Der claude.ai-Nachweis aus #622 („einmal aus claude.ai belegt, erscheint in der App mit Revision“) braucht die angemeldete App (#615) und ist Nacharbeit von Claude nach diesem Schnitt, kein AC hier.
- Keine Änderung am Auftragsvertrag (`docs/reference/claude-abschrift-vertrag.md`, Version 1) und am Dienst (`server/`).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — die Grundregel „Revisions, not undo“ (bisher für abgeleitete Felder) wird für Claude-Aufträge auf Status, „Als Nächstes“ und Teilaufgaben ausgedehnt; keine bestehende ADR fällt, es entsteht kein Schemawechsel.

## Source

**Files:** `Shared/Models/Enums.swift`, `Shared/Services/FieldCodec.swift`, `Shared/Services/RevisionService.swift`, `Shared/Models/DetailFields.swift`, `Shared/Services/OrderExecutor.swift`, `Shared/Services/Subtasks.swift`, `LooseEnds/Views/FieldFormatting.swift`, `LooseEnds/Views/TaskDetailView.swift`, `LooseEnds/Resources/Localizable.xcstrings`, `LooseEndsTests/OrderExecutorTests.swift`
**Identifier:** `RevisedField`, `OrderExecutor`, `Subtasks.add`, `FieldFormatting`

## Implementation Details

### Drei neue Felder

`RevisedField` bekommt am Ende (wie `notes`, `knaeuel`, `counts` vor ihnen) die Fälle `status`, `nextRank`, `subtasks`. `Revision.fieldRaw` ist ein String, die neuen Rohwerte brauchen keinen CloudKit-Schemawechsel (`cloudkit/schema.ckdb` bleibt, `scripts/test_cloudkit_schema.py` bleibt grün).

### Gewählte Form: Revision neben der Aktion, nicht über `apply`

`RevisionService.set` schreibt über `FieldCodec.apply` und verändert dabei die Aufgabe. Status, Rang und Teilaufgaben ändern aber `TaskActions` und `Subtasks` (Fortschreiben einer Wiederholung, Knäuel-Marke, Rangvergabe), nicht ein Feldschreiber. Deshalb:

- `FieldCodec.encode` liefert für die neuen Fälle einen Wert: `status` = `task.status.rawValue`, `nextRank` = der Rang als Text oder nil, `subtasks` = nil (eine Aufgabe hat nicht „den“ Teilaufgaben-Wert; die Zeile steht nur in der Revision).
- `FieldCodec.apply` ist für die neuen Fälle ein No-op (`break`, wie bei `blockedBy`). So kann ein Zurücksetzen nie versehentlich Status oder Teilaufgaben verändern.
- `OrderExecutor` legt die Revision selbst an, über eine kleine private Hilfsfunktion: `Revision(task:field:oldValue:newValue:author: .user)`, `reason = "Claude"`, `createdAt` und `seenAt` = `now`, an `task.revisions` angehängt (dasselbe Muster wie `RevisionService.set`). Alt und Neu stammen aus `FieldCodec.encode` vor und nach der Aktion; die Aktion selbst bleibt unverändert die aus `TaskActions`/`Subtasks`.

### Was jeder Auftrag schreibt

| Auftrag | Revision (Autor `.user`, Grund „Claude“) |
|---|---|
| `complete` | `status`: alt = Rohwert vor der Aktion, neu = `done`; bei einer Wiederholung ebenfalls „→ done“ für die Runde (die Aufgabe bleibt danach offen, der `CompletionRecord` trägt das Datum) |
| `setNext` | `nextRank`: alt/neu = Rang als Text oder nil |
| `park` | `status`: alt = Rohwert vor der Aktion, neu = `parked` |
| `addSubtask` | `subtasks` an der Elternaufgabe: alt = nil, neu = die Zeile |
| `setDue` | unverändert: eine `dueDate`-Revision mit Grund „Claude“ (eine Verschiebung durch Claude ist die Verschiebung des Nutzers und zählt) |
| `capture` | keine; eine Erzeugung ist keine Änderung, `capturedVia = .claude` genügt |

### Nebenrevisionen bekommen denselben Grund

`TaskActions.park` und `TaskActions.complete` einer Wiederholung rufen `releaseKnaeuel` auf und schreiben damit eine `.knaeuel`-Revision ohne Grund. Der Executor merkt sich vor der Aktion die `persistentModelID`s der Revisionen der Aufgabe, setzt danach bei jeder neuen Revision, deren `reason` noch nil ist, den Grund „Claude“. Kein neuer Parameter in `TaskActions`.

### Wiederholung: keine dueDate-Revision

`TaskActions.complete` verschiebt `dueDate` einer Wiederholung ohne Revision. Der Executor ergänzt keine: `ViewRules.postponeCount` zählt jede `.user`-Revision von `dueDate` mit neu > alt als Verschiebung, ein Abschluss würde die Aufgabe als „oft verschoben“ brandmarken. Die `status`-Revision „offen → erledigt“ steht stattdessen für die Runde.

### Teilaufgabe über Claude

`Subtasks.add(_:to:in:now:via:)` bekommt `via: CaptureSource = .app` und gibt es an `TaskItem(capturedVia:)` weiter; der Executor übergibt `.claude`. Alle bestehenden Aufrufer bleiben unverändert (Standardwert).

### Nie umkehrbar, bestehende Leser unverändert

- Autor `.user` heißt: kein Zurücksetzen-Knopf (nur automatische Revisionen haben ihn), `RevisionService.revertAll` und `automaticFields` nehmen nur automatische Autoren. `RevisionService.origin(of:)` gibt für die neuen Fälle nil, ebenso `DetailField(revised:)`; die Markierung „neu von der KI“ und der Ungesehen-Zähler (nur automatische Autoren) bleiben unberührt.
- `ViewRules.postponeCount` liest nur `field == .dueDate`: die neuen Felder zählen nie, und für Wiederholungen schreiben wir keine `dueDate`-Revision (oben). Verhalten unverändert.
- `EnrichmentWriter.userHasTouched(field)` fragt je Feld, die Anreicherung schreibt die neuen Felder nie: ein „berührt“ blockiert nichts. Verhalten unverändert.
- Keine Lernlogik liest Nutzerrevisionen dieser Felder (`RecognitionRule`, `ContextWordLearning` lesen sie nicht, Analyse-Befund).

### Anzeige (nur Beschriftung und Wert, keine Oberfläche)

`FieldFormatting.label`: „Status“, „Next up“ (de „Als Nächstes“), „Subtask“ (de „Teilaufgabe“). `FieldFormatting.value`: `status` als „Open“/„Done“/„Parked“ (de „Offen“/„Erledigt“/„Geparkt“ (vorhandener Schlüssel „Parked“); `unprocessed`, `unverified`, `active` lesen als „Open“), `nextRank` nicht leer als „Yes“ (leer bleibt wie überall nil und wird vom Blatt als leer gezeigt), `subtasks` die Zeile selbst. Vorhandene Katalogschlüssel werden wiederverwendet, fehlende mit de-Text in `LooseEnds/Resources/Localizable.xcstrings` ergänzt (englischer Schlüssel, de als Übersetzung, wie dort üblich); `scripts/test_catalog_languages.py` muss grün bleiben. `TaskDetailView.value(of:)` bekommt die neuen Fälle in den bestehenden `nil`-Zweig. Verlangt der Compiler in `FieldEditorView` einen Fall, ist es eine Zeile im `default`-Zweig; sonst bleibt die Datei unberührt.

## Dependencies

| Entität | Art | Zweck |
|---|---|---|
| `Shared/Services/TaskActions.swift` | bestehend, unverändert | `complete`, `toggleNext`, `park` machen die Änderung weiter selbst |
| `Shared/Models/Revision.swift` | bestehend, unverändert | `fieldRaw` als String, `reason`, `author`, `seenAt` |
| `Shared/Services/RevisionService.swift` | bestehend, eine Zeile | `origin(of:)` |
| `ViewRules.postponeCount`, `EnrichmentWriter.userHasTouched` | bestehend, unverändert | Leser von Nutzerrevisionen, Verhalten belegt |
| `docs/reference/claude-abschrift-vertrag.md` | bestehend, unverändert | Auftragsformat Version 1 |
| Downstream | Schnitt 2 (Sichtbarkeit), CloudKit-Abgleich der `Revision`-Zeilen (kein Schemawechsel) | |

## Scope

### Affected Files

| Datei | Änderung | Beschreibung | LoC |
|---|---|---|---|
| `Shared/Models/Enums.swift` | MODIFY | drei Fälle am Ende von `RevisedField` | +3 |
| `Shared/Services/FieldCodec.swift` | MODIFY | `encode` für die neuen Fälle, `apply` No-op | +6 |
| `Shared/Services/RevisionService.swift` | MODIFY | `origin` → nil | +1 |
| `Shared/Models/DetailFields.swift` | MODIFY | `init?(revised:)` → nil | +1 |
| `Shared/Services/Subtasks.swift` | MODIFY | Parameter `via` | +3/-2 |
| `Shared/Services/OrderExecutor.swift` | MODIFY | Hilfsfunktion, Revision je Auftrag, Nebenrevisionen stempeln | +45/-5 |
| `LooseEnds/Views/FieldFormatting.swift` | MODIFY | Beschriftung und Werte | +22 |
| `LooseEnds/Views/TaskDetailView.swift` | MODIFY | `value(of:)` nimmt die Fälle auf | +1/-1 |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | neue Schlüssel de/en | +8 |
| `LooseEndsTests/OrderExecutorTests.swift` | MODIFY | neue XCTest-Klasse | +90 |

### Estimated Changes

- Files: 10
- LoC: etwa +180/-10, unter dem Limit von ±250.

**Begründete Abweichung von „4 bis 5 Dateien“ (Tech-Lead-Entscheidung nach `openspec.yaml`):** Die Dateizahl kommt vom Compiler. `RevisedField` wird an fünf Stellen ausgeschöpft geschaltet (`FieldCodec`, `RevisionService`, `DetailFields`, `FieldFormatting`, dazu `TaskDetailView.value(of:)`); jede braucht eine Zeile. Fachlich ist es eine Änderung an einem Ort (`OrderExecutor`). Teilen würde die Zwischenstände nicht übersetzbar machen. Die Oberfläche (Einstiegszeile, Blatt-Autor, UI-Test) ist ausdrücklich in Schnitt 2 ausgelagert, damit dieser unter 250 LoC bleibt.

## Test Plan

### Automated Tests (TDD RED)

XCTest in `LooseEndsTests/OrderExecutorTests.swift` als eigene Klasse `OrderExecutorRevisionTests: XCTestCase` neben der bestehenden Swift-Testing-Suite (das QA-Gate zählt nur XCTest); sie nutzt die Helfer der Suite (`TestStore`, `run`, `insert`, `Snapshot`).

- [ ] Test 1: GIVEN eine offene Aufgabe WHEN `complete` THEN genau eine `status`-Revision (`active` → `done`), Autor `.user`, Grund „Claude“.
- [ ] Test 2: GIVEN eine wiederholende Aufgabe mit Knäuel-Marke WHEN `complete` THEN keine `dueDate`-Revision, `ViewRules.postponeCount` bleibt 0, die `.knaeuel`-Revision trägt „Claude“.
- [ ] Test 3: GIVEN eine Aufgabe ohne Rang WHEN `setNext` an THEN genau eine `nextRank`-Revision (nil → Rang), danach aus: (Rang → nil), je Grund „Claude“.
- [ ] Test 4: GIVEN eine Knäuel-Aufgabe WHEN `park` THEN eine `status`-Revision (→ `parked`) und die `.knaeuel`-Revision, beide „Claude“, beide `.user`.
- [ ] Test 5: GIVEN eine offene Aufgabe WHEN `addSubtask` THEN eine `subtasks`-Revision an der Elternaufgabe (alt nil, neu die Zeile), die neue Zeile hat `capturedVia == .claude`; `Subtasks.add` ohne `via` liefert weiter `.app`.
- [ ] Test 6: GIVEN `setDue` und `capture` WHEN ausgeführt THEN `setDue` wie bisher eine `dueDate`-Revision „Claude“, `capture` keine Revision.
- [ ] Test 7: GIVEN abgelehnte Aufträge (stale, invalid, missing) für alle vier Arten WHEN ausgeführt THEN die Revisionszahl im `Snapshot` bleibt gleich.
- [ ] Test 8: GIVEN die neuen Revisionen WHEN `RevisionService.automaticFields`, `revertAll` und `origin(of:)` abgefragt werden THEN keine automatischen Felder, `revertAll` schreibt nichts, `origin` ist nil.
- [ ] Test 9: GIVEN die neuen Fälle WHEN `FieldCodec.encode` und `FieldFormatting.label/value` THEN erwartete Rohwerte und Worte; `apply` verändert die Aufgabe nicht.

Kein UI-Test in diesem Schnitt (keine sichtbare Änderung außer neuen Zeilen im Änderungsblatt; Sichtbarkeit = Schnitt 2).

### Abnahme

Stufe 1: neue Tests rot vor, grün nach der Umsetzung, alle Unit-Tests und `scripts/test_catalog_languages.py` grün. Stufe 2: `./scripts/sim.sh test-proof FieldsSmokeTests` (öffnet das Detail und die Feldzeilen; belegt, dass die erweiterte Enum und die Formatierung die App nicht stören) mit Beleg. Stufe 3: Kein Pfad der Geräteliste berührt (`Shared/Services`, `Shared/Models`, `LooseEnds/Views`, `Localizable.xcstrings` stehen nicht in der Tabelle).

## Acceptance Criteria

- **AC-1:** `RevisedField` enthält `status`, `nextRank`, `subtasks` am Ende der Fallliste; die Rohwerte der bisherigen Fälle sind unverändert, es gibt keine Änderung an `cloudkit/schema.ckdb`.
- **AC-2:** Ein `complete`-Auftrag auf eine nicht wiederholende Aufgabe schreibt genau eine `status`-Revision (alt vor der Aktion, neu `done`) mit Autor `.user` und Grund „Claude“.
- **AC-3:** Ein `complete`-Auftrag auf eine wiederholende Aufgabe schreibt genau eine `status`-Revision „→ done“ und keine `dueDate`-Revision; `ViewRules.postponeCount` der Aufgabe bleibt unverändert.
- **AC-4:** Ein `setNext`-Auftrag schreibt genau eine `nextRank`-Revision mit richtigem Alt- und Neuwert (Rang als Text oder nil), Autor `.user`, Grund „Claude“.
- **AC-5:** Ein `park`-Auftrag schreibt genau eine `status`-Revision „→ parked“ mit Grund „Claude“.
- **AC-6:** Ein `addSubtask`-Auftrag schreibt genau eine `subtasks`-Revision an der Elternaufgabe (alt nil, neu die Zeile) mit Grund „Claude“, und die neue Zeile hat `capturedVia == .claude`; `Subtasks.add` ohne `via` setzt weiter `.app`.
- **AC-7:** Jede Revision, die eine dieser Aktionen nebenbei schreibt (Knäuel-Marke fällt bei `park` und beim `complete` einer Wiederholung), trägt ebenfalls den Grund „Claude“; Revisionen, die schon einen Grund hatten, werden nicht überschrieben.
- **AC-8:** `setDue` verhält sich unverändert (eine `dueDate`-Revision mit Grund „Claude“), `capture` schreibt keine Revision.
- **AC-9:** Ein abgelehnter Auftrag (`stale`, `invalid`, `missing`) hinterlässt keine Revision und ändert den Store nicht.
- **AC-10:** Die neuen Revisionen sind nicht per Zurücksetzen umkehrbar: `RevisionService.automaticFields` und `revertAll` ignorieren sie, `origin(of:)` ist für die neuen Felder nil, `FieldCodec.apply` ändert die Aufgabe für sie nicht.
- **AC-11:** `FieldCodec.encode` und `FieldFormatting.label/value` liefern für die drei Felder die in „Anzeige“ beschriebenen Rohwerte und Worte, de und en; `scripts/test_catalog_languages.py` und der Katalogwächter bleiben grün.
- **AC-12:** Alle Unit-Tests sind grün, und `./scripts/sim.sh test-proof FieldsSmokeTests` ist grün mit registriertem Beleg.

## Definition of Done

- [ ] Neue Tests aus dem Test Plan rot vor der Umsetzung, grün danach; alle Unit-Tests grün
- [ ] `scripts/test_catalog_languages.py` grün
- [ ] `./scripts/sim.sh test-proof FieldsSmokeTests` grün, Beleg registriert
- [ ] Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“
- [ ] Ausgeliefert per PR mit `Refs #622`, CI grün, gemergt; #622 bleibt offen (Schnitt 2 und claude.ai-Nachweis)

## Alternativen

- **Eigenes Protokollmodell je Aufgabe (`ClaudeTrace`):** zusätzliche SwiftData-Klasse und CloudKit-Schemawechsel, dessen Deploy in Production hinter Hennings Anmeldung läuft (CLAUDE.md, CloudKit-Schema); dazu eine zweite Verlaufsquelle neben den Revisionen, die die App schon anzeigt. Kein Gewinn gegenüber Ansatz A, verworfen.
- **Nur `CompletionRecord` und `capturedVia`:** deckt Abschluss und Erfassung ab, nicht Status „geparkt“, „Als Nächstes“, Teilaufgabe und Datum; die DoD bliebe offen. Verworfen.
- **DoD-Punkt streichen (die ungefragte Entscheidung aus PR #867):** widerspricht dem Tickettext und bräuchte Hennings Wort; er hat stattdessen Sichtbarkeit gewählt (Entwurf A). Verworfen.
- **`dueDate`-Revision beim Abschluss einer Wiederholung:** würde in `postponeCount` als Verschiebung zählen; deshalb die `status`-Revision. Verworfen.
- Keine ADR fällt (siehe oben).

## Risiken

- **Ältere Bauten (App Store 1.0/1.0.1):** lesen einen unbekannten `fieldRaw` über den Rückfall in `Revision.field` als `.title` und zeigen so eine Zeile im Änderungsblatt als Titeländerung („Title: x → y“). Das erreicht nur Nutzer mit Konto (der Store-Build hat die Kontogruppe aus, praktisch Henning), ist rein kosmetisch, ungefährlich, da Nutzerrevisionen dort keinen Zurücksetzen-Knopf haben, und wird angenommen.
- **Doppelte Wirkung über `persistentModelID`-Differenz:** ein Auftrag läuft auf dem Hauptakteur und speichert sofort; ein gleichzeitiger CloudKit-Import könnte fremde neue Revisionen zwischen Vorher und Nachher einstreuen. Der Stempel gilt nur für Revisionen mit `reason == nil`, die in genau dieser synchronen Aktion entstanden; da Executor und Aktion ohne Suspensionspunkt laufen, ist das Fenster leer.
- **Dateizahl 10** (siehe Scope): begründet, in der PR-Beschreibung genannt.

## Changelog

- 2026-11-15: Erste Fassung (Schnitt 1, Logik); Schnitt 2 (Sichtbarkeit) bekommt eigene Teil-Spec.

# Adversary Dialog — feat-622-claude-verlauf
Spec: docs/specs/feat-622-schnitt-1-claude-revisionen.md
Datum: 2026-11-15 02:42

## Checkliste
- [x] **AC-1:** `RevisedField` enthält `status`, `nextRank`, `subtasks` am Ende der Fallliste; die Rohwerte der bisherigen Fälle sind unverändert, es gibt keine Änderung an `cloudkit/schema.ckdb`.
- [x] **AC-2:** Ein `complete`-Auftrag auf eine nicht wiederholende Aufgabe schreibt genau eine `status`-Revision (alt vor der Aktion, neu `done`) mit Autor `.user` und Grund „Claude“.
- [x] **AC-3:** Ein `complete`-Auftrag auf eine wiederholende Aufgabe schreibt genau eine `status`-Revision „→ done“ und keine `dueDate`-Revision; `ViewRules.postponeCount` der Aufgabe bleibt unverändert.
- [x] **AC-4:** Ein `setNext`-Auftrag schreibt genau eine `nextRank`-Revision mit richtigem Alt- und Neuwert (Rang als Text oder nil), Autor `.user`, Grund „Claude“.
- [x] **AC-5:** Ein `park`-Auftrag schreibt genau eine `status`-Revision „→ parked“ mit Grund „Claude“.
- [x] **AC-6:** Ein `addSubtask`-Auftrag schreibt genau eine `subtasks`-Revision an der Elternaufgabe (alt nil, neu die Zeile) mit Grund „Claude“, und die neue Zeile hat `capturedVia == .claude`; `Subtasks.add` ohne `via` setzt weiter `.app`.
- [x] **AC-7:** Jede Revision, die eine dieser Aktionen nebenbei schreibt (Knäuel-Marke fällt bei `park` und beim `complete` einer Wiederholung), trägt ebenfalls den Grund „Claude“; Revisionen, die schon einen Grund hatten, werden nicht überschrieben.
- [x] **AC-8:** `setDue` verhält sich unverändert (eine `dueDate`-Revision mit Grund „Claude“), `capture` schreibt keine Revision.
- [x] **AC-9:** Ein abgelehnter Auftrag (`stale`, `invalid`, `missing`) hinterlässt keine Revision und ändert den Store nicht.
- [x] **AC-10:** Die neuen Revisionen sind nicht per Zurücksetzen umkehrbar: `RevisionService.automaticFields` und `revertAll` ignorieren sie, `origin(of:)` ist für die neuen Felder nil, `FieldCodec.apply` ändert die Aufgabe für sie nicht.
- [x] **AC-11:** `FieldCodec.encode` und `FieldFormatting.label/value` liefern für die drei Felder die in „Anzeige“ beschriebenen Rohwerte und Worte, de und en; `scripts/test_catalog_languages.py` und der Katalogwächter bleiben grün.
- [x] **AC-12:** Alle Unit-Tests sind grün, und `./scripts/sim.sh test-proof FieldsSmokeTests` ist grün mit registriertem Beleg.

## Dialog

### Runde 1
**Adversary:** Ausgangspunkt Spec. Ich habe die Diffs aller 9 geaenderten Dateien gelesen und die Tests selbst gefahren (Ausgabe: docs/artifacts/feat-622-claude-verlauf/adversary-test-output.txt, Ende `Executed 9 tests, with 0 failures`, `Test Succeeded`, EXIT 0; Swift-Testing-Suite OrderExecutorTests: adv-swifttesting.txt, Test Succeeded, EXIT 0; scripts/test_catalog_languages.py: 8 Tests OK; volle Suite test-green-output.txt: ohne Fehler, uebersprungen sind nur die drei Messstrecken ohne Korpus, nicht die Produkttests). Bekannte, akzeptierte Abweichungen: Spec nennt `CaptureSource`, real `CaptureChannel` (Subtasks.swift:18); deutsche Woerter kommen aus vorhandenen Katalogschluesseln (Done, Parked, Open, Subtask, Next up). Beide gelten nicht als Defekt.

Bohrende Fragen: (1) Doppelte Revision, weil `Revision(task:)` den Inverse setzt UND `task.revisions` neu zugewiesen wird? (2) Wird eine Revision mit vorhandenem Grund ueberschrieben? (3) Wiederholung mit Knaeuel: dueDate-Revision, postponeCount? (4) setNext aus: Neuwert nil? (5) addSubtask, das wirft? (6) abgelehnte Auftraege? (7) Zuruecksetzen/apply? (8) aeltere Revisionen unberuehrt?

**Implementierer (Belege aus Code und Test):**
1. Das Muster `task.revisions = (task.revisions ?? []) + [revision]` ist identisch zu RevisionService.set (RevisionService.swift:73); die Tests pruefen `count == 1` je Feld und laufen gruen, keine Duplikate.
2. OrderExecutor.recording stempelt nur Revisionen mit `reason == nil` und nicht in der Vorher-Menge der persistentModelIDs (OrderExecutor.swift:159ff). Der Test legt eine Revision mit reason "Siri" an und prueft, dass sie bleibt.
3. TaskActions.complete verschiebt dueDate ohne Revision, der Executor ergaenzt keine; Test prueft dueDate-Revisionen leer und postponeCount gleich.
4. `testSetNextWritesRankRevisionOnAndOff`: an (nil -> Rang als Text), aus (Rang -> nil), Autor .user, Grund Claude.
5. `recording` ist `rethrows`; Subtasks.add wirft vor dem Einfuegen (leerer Text, verschachtelt), der catch liefert `.invalid`; die Revision entsteht erst nach erfolgreicher Aktion. AC-9-Test deckt leeren Text.
6. `testRefusedOrdersLeaveNoRevision` vergleicht Snapshot vor/nach acht abgelehnten Auftraegen: gleich.
7. FieldCodec.apply ist fuer die drei Faelle `break` (FieldCodec.swift:27ff); automaticFields/revertAll filtern ueber `origin`, das nil liefert (RevisionService.swift:108).
8. Revisionen werden nur angehaengt; veraendert wird nur `reason == nil` der neuen Menge.

### Runde 2
**Adversary:** Zweiter Angriff auf Randfaelle, die die Tests nicht abdecken.
- `TaskActions.park` setzt `task.nextRank = nil` (TaskActions.swift:106) ohne nextRank-Revision. Ein geparkter Auftrag aus "Als Naechstes" verliert den Rang stumm; die Spec verlangt aber genau eine status-Revision fuer park, also spec-konform, aber eine Luecke im Verlauf (F001, LOW).
- toggleNext vergibt nur den Rang der Zielaufgabe (kein Umnummerieren): kein stiller Seiteneffekt auf andere Aufgaben.
- Alter Status unprocessed/unverified/active wird roh gespeichert, die Anzeige liest alle als "Open" (FieldFormatting.status). removed und unbekannte Rohwerte -> nil; kein Auftrag schreibt removed.
- Aeltere Builds lesen unbekannten fieldRaw als `.title` (Spec-Risiko, angenommen).
- DetailField(revised:) und TaskDetailView.value(of:) nehmen die Faelle in den nil-Zweig: kein Einfluss auf Feldschalter/Ungesehen-Zaehler.
- Test 9 prueft Katalogeintraege nur auf Vorhandensein eines de-Werts, nicht das Rendering unter de-Locale (F002, LOW); Katalogwaechter gruen.
- cloudkit/schema.ckdb unveraendert (Statusabfrage ohne Eintrag), AC-1.
- Simulator-Beleg: test-proof-fields.txt endet mit `Test Succeeded` und "UI-Test bestanden, Beleg: .../simulator-run.txt"; simulator-run/summary.json: passedTests 5, failedTests 0, result Passed.
**Implementierer:** F001 entspricht dem Spec-Wortlaut (genau eine status-Revision); Schnitt 2 oder Folgeticket kann entscheiden. F002 durch Katalogwaechter abgedeckt.

### Confirmations
Confirmation:
  AC: AC-1
  Code reference: Shared/Models/Enums.swift:72
  Evidence: drei Faelle am Ende von RevisedField, Test prueft suffix(3) und die ersten 15 Rohwerte, schema.ckdb ohne Diff
  Status: CONFIRMED
Confirmation:
  AC: AC-2
  Code reference: Shared/Services/OrderExecutor.swift:76
  Evidence: complete ruft recording(.status) mit neu = done; Test OneOff gruen
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: Shared/Services/OrderExecutor.swift:159
  Evidence: recording legt nur eine status-Revision an, keine dueDate; Test Repeating gruen
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: Shared/Services/FieldCodec.swift:27
  Evidence: encode liefert Rang als Text/nil, setNext-Test an und aus gruen
  Status: CONFIRMED
Confirmation:
  AC: AC-5
  Code reference: Shared/Services/OrderExecutor.swift:125
  Evidence: park nutzt recording(.status) mit neu parked
  Status: CONFIRMED
Confirmation:
  AC: AC-6
  Code reference: Shared/Services/Subtasks.swift:18
  Evidence: Parameter via mit Standard .app, Executor uebergibt .claude, subtasks-Revision am Elternteil
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: Shared/Services/OrderExecutor.swift:159
  Evidence: Stempelschleife nur fuer reason == nil und neue IDs; Siri-Grund bleibt
  Status: CONFIRMED
Confirmation:
  AC: AC-8
  Code reference: Shared/Services/OrderExecutor.swift:48
  Evidence: setDue/capture unveraendert, Test AC-8 gruen
  Status: CONFIRMED
Confirmation:
  AC: AC-9
  Code reference: Shared/Services/OrderExecutor.swift:142
  Evidence: Fehler vor der Revision, Snapshot-Test gleich
  Status: CONFIRMED
Confirmation:
  AC: AC-10
  Code reference: Shared/Services/RevisionService.swift:108
  Evidence: origin nil, automaticFields/revertAll leer, apply No-op; Shared/Models/DetailFields.swift:86 gibt nil
  Status: CONFIRMED
Confirmation:
  AC: AC-11
  Code reference: LooseEnds/Views/FieldFormatting.swift:22
  Evidence: Labels und Werte wie spezifiziert; LooseEnds/Views/TaskDetailView.swift:413 nil-Zweig; Katalogtest OK
  Status: CONFIRMED
Confirmation:
  AC: AC-12
  Code reference: LooseEnds/Views/TaskDetailView.swift:413
  Evidence: Unit-Suite gruen, FieldsSmokeTests 5/5 bestanden mit Beleg
  Status: CONFIRMED

Zusaetzliche Code-Referenzen (Abdeckung aller geaenderten Dateien):
Confirmation:
  AC: AC-10
  Code reference: Shared/Models/DetailFields.swift:86
  Evidence: init?(revised:) liefert nil fuer status, nextRank, subtasks
  Status: CONFIRMED
Confirmation:
  AC: AC-11
  Code reference: LooseEnds/Views/TaskDetailView.swift:413
  Evidence: value(of:) nil-Zweig nimmt die drei Faelle auf
  Status: CONFIRMED

### Findings
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Services/OrderExecutor.swift:125
  Description: park ruft TaskActions.park, das nextRank auf nil setzt, ohne nextRank-Revision; es entsteht nur die status-Revision.
  Spec requirement: AC-5 - genau eine status-Revision
  Conflict: kein Verstoss; der Rangverlust ist im Verlauf nicht sichtbar.
  Remediation: in Schnitt 2 oder Folgeticket pruefen, ob der Rangverlust im Blatt erwaehnt werden soll.
Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Views/FieldFormatting.swift:22
  Description: Tests pruefen die deutschen Woerter nur auf Vorhandensein im Katalog, nicht das Rendering unter de-Locale.
  Spec requirement: AC-11 - de und en
  Conflict: kein Verstoss, schwacher Beleg.
  Remediation: optional LOOSEENDS_LANG=de Testlauf.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
The implementation withstood adversary testing.
Tests: OrderExecutorRevisionTests 9 passed, 0 failed; OrderExecutorTests (Swift Testing) gruen; Katalog 8 OK; volle Suite gruen; FieldsSmokeTests 5/5; 3 Messstrecken ohne Korpus uebersprungen (nicht Produkttests)
Edge cases: All checked, only LOW findings F001, F002
Regressions: None found
Checklist: 12/12 points proven

## Geprüfte Dateien

- sha256:4925b64c780f7a83467dda78711f2311c369a9e5acb67022bbd431f16607494e  LooseEnds/Views/FieldFormatting.swift
- sha256:a0c0342e8edb441f9a70882d75b1cd9291f1a0bf3cdadb9dab998e11c3b907d4  LooseEnds/Views/TaskDetailView.swift
- sha256:bbaa318e5f044d4ed05c23165641f298f81b71bd2d1407cafccd9c7d188a164a  Shared/Models/DetailFields.swift
- sha256:2ac0feda5db6515a259c9d9ba738a78af65ce7c0633c733093e71e55cbc1390f  Shared/Models/Enums.swift
- sha256:e6a1cc77ffd72bcf0100d11981ff3415a23cacf400df49fca3224a31ebee8881  Shared/Services/FieldCodec.swift
- sha256:522950bd0c9967a621bde930acae4e9736c586128d5bb00ca9e6c5c3a1e2af91  Shared/Services/OrderExecutor.swift
- sha256:c54f0ebcb5d89d87860444d4830898b8b7362b335d98e68f5af7d169dd26d5d0  Shared/Services/RevisionService.swift
- sha256:f7e640c594123e8a63cb2a96d46c1e1d81b6e7ada505a39d9f47cab34b884272  Shared/Services/Subtasks.swift

## Prüfbasis

- base: ecfd2228ddd94c16edbaa96bc8acea859fe87a6d
- blob:b21fc2f8afc6caa9e34e1b802e15f8eaec68ff9f  LooseEnds/Views/FieldFormatting.swift
- blob:965dd269fbd1e65dd3926fa2e369e3f707634717  LooseEnds/Views/TaskDetailView.swift
- blob:8bb130e1f003e9e0f6b1608cca4cf59bb044c3fe  Shared/Models/DetailFields.swift
- blob:f772d9cc7723455ca4a57a46cef30407a626a425  Shared/Models/Enums.swift
- blob:8c6a4c3d8d34f150100970f7a13b1df8f31ae7e5  Shared/Services/FieldCodec.swift
- blob:87db8cd73da6277c3054738b8f5e8889a86f1b2e  Shared/Services/OrderExecutor.swift
- blob:e38c4f2b67daf6594f556c07fefb59cfd28779f8  Shared/Services/RevisionService.swift
- blob:c18df63a149bf20b9cd43b5940f656f2a9c2d61b  Shared/Services/Subtasks.swift

# Adversary-Dialog — feat-127-repeat-reminder

- Spec: `docs/specs/enrichment/feat-127-repeat-reminder.md`
- Beweise: `docs/artifacts/feat-127-repeat-reminder/adversary-test-output.txt` (`Test Succeeded`, `EXIT=0`),
  `docs/artifacts/feat-127-repeat-reminder/adversary-build-output.txt` (`Build Succeeded`, `EXIT=0`)
- Datum: 2026-09-25

## Testlauf (Grundlage, nicht erneut ausgeführt)

- `./scripts/sim.sh unit`: `Test Suite 'All tests' passed` (Zeile 17), `Test Succeeded` (Zeile 269), `EXIT=0` (Zeile 272).
  Kein `failed` im gesamten Output.
- `./scripts/sim.sh build`: `Build Succeeded`, `EXIT=0`.
- Änderungsumfang laut Arbeitskopie: 2 Produktionsdateien, +15 Zeilen
  (`Shared/Models/RepeatRule.swift`, `LooseEnds/Views/FieldEditorView.swift`).

### Runde 1 — Angriff auf jede Acceptance Criterion

- [x] **AC-1 `firstDueDate` berechnet Datum und optional Uhrzeit korrekt**
  - Angriff: Werden wirklich alle drei geforderten Fälle geprüft (mit Uhrzeit, ohne Uhrzeit, wöchentlich ohne `weekdays`) —
    oder nur der bequeme Happy Path?
  - Beweis 1 (mit Uhrzeit): `Code reference: LooseEndsTests/RepeatRuleTests.swift:99` — `firstDueDateUsesStoredTime`,
    `rule.hour = 19` / `minute = 0`, `now` = 24. um 08:00 (Europe/Berlin), Erwartung exakt 25. um 19:00. Also echter
    Wertvergleich, nicht nur „nicht nil". Bestätigt zugleich Risiko 5 der Spec (nächster Zyklus, nicht heute).
    Output: Zeile 211 `✔ "firstDueDate kombiniert den nächsten Termin mit der gespeicherten Uhrzeit (AC-1)"`.
  - Beweis 2 (ohne Uhrzeit): `Code reference: LooseEndsTests/RepeatRuleTests.swift:112` —
    `firstDueDateWithoutTimeFallsBackToStartOfDay`, Erwartung `calendar.startOfDay(for: nextDueDate(previousDue: nil, …))`.
    Output: Zeile 212 `✔`.
  - Beweis 3 (wöchentlich ohne `weekdays`): `Code reference: LooseEndsTests/RepeatRuleTests.swift:124` —
    `firstDueDateWeeklyWithoutWeekdaysReusesFallback`, Erwartung Gleichheit mit
    `nextDueDate(previousDue: nil, completedOn: now, …)`, d.h. der bestehende „+7×interval"-Rücksprung wird unverändert
    durchgereicht. Output: Zeile 213 `✔`.
  - Bewertung: **AKZEPTIERT**

- [x] **AC-2 Implizites `dueDate` bei Neuanlage einer Regel ohne bestehendes Fälligkeitsdatum**
  - Angriff: Wird `dueHasTime` wirklich aus `rule.hour != nil` abgeleitet, und existiert eine `Revision` mit
    `field == .dueDate` / `author == .user` — oder wird nur „irgendwas gesetzt"?
  - Beweis: `Code reference: LooseEndsTests/RepeatEditTests.swift:116` — `firstRuleImplicitlySetsDueDate`:
    Task „Jeden Tag um 7 Uhr die Tabletten nehmen" ohne `repeatRule` und ohne `dueDate`, Regel über
    `RepeatRule.selecting(.daily, …)`, danach `#expect(task.dueDate != nil)`, `#expect(task.dueHasTime == true)`,
    `#require(task.revisions?.first { $0.field == .dueDate })` und `#expect(dueRevision.author == .user)`.
    Output: Zeile 197 `✔ "Erstmaliges Anlegen einer Regel setzt implizit ein Fälligkeitsdatum (AC-2)"`.
  - Offene Nachfrage für Runde 2: Der Test ruft nicht `FieldEditorView.applyRepeat` auf, sondern eine private
    Nachstellung (`LooseEndsTests/RepeatEditTests.swift:106`). Und der Datumswert selbst wird nicht verglichen.
  - Bewertung: **NACHFRAGE** (siehe Runde 2, N1 und N3)

- [x] **AC-3 Kein Überschreiben eines bereits gesetzten `dueDate`**
  - Angriff: Reicht ein Datumsvergleich? Es könnte eine zweite Revision mit demselben Wert geschrieben werden
    (Revisionshistorie verschmutzt, ADR-3 verletzt), ohne dass der Datumsvergleich anschlägt.
  - Beweis: `Code reference: LooseEndsTests/RepeatEditTests.swift:133` — `existingDueDateIsNotOverwritten`:
    manuelles `dueDate` (+3 Tage) vorab über `RevisionService.set`, danach Regel-Neuanlage; geprüft wird sowohl
    `#expect(task.dueDate == dueDateBefore)` als auch `#expect(task.revisions?.filter { $0.field == .dueDate }.count == 1)`.
    Der Revisionszähler schließt genau die stille Doppelschreibung aus. Output: Zeile 198 `✔`.
  - Bewertung: **AKZEPTIERT**

- [x] **AC-4 Kein erneuter Prefill bei Änderung einer bestehenden Regel**
  - Angriff: Wird der Zustand „Regel existiert bereits" echt durchlaufen (erst anlegen, dann ändern), oder nur ein
    künstlich vorgesetzter Zustand geprüft?
  - Beweis: `Code reference: LooseEndsTests/RepeatEditTests.swift:153` — `changingExistingRuleDoesNotRewriteDueDate`:
    erst `.daily` anlegen (dabei entsteht das implizite `dueDate`, `#expect(dueDateBefore != nil)` sichert den
    Vorzustand), dann `.weekly` auf dieselbe Task anwenden; danach `#expect(task.dueDate == dueDateBefore)` und
    `.dueDate`-Revisionen bleiben bei `count == 1`. Also echter Zustandsübergang init → Neuanlage → Änderung.
    Output: Zeile 199 `✔`.
  - Bewertung: **AKZEPTIERT**

- [x] **AC-5 Downstream: Sammel-Push um 9 Uhr, kein individueller Reminder zur `repeatRule.hour`-Zeit**
  - Angriff: Ein Test, der nur „Reminder existiert" prüft, würde Risiko 1 der Spec (Erwartungslücke Uhrzeit) nicht
    belegen. Wird der *Zeitpunkt* geprüft?
  - Beweis: `Code reference: LooseEndsTests/DueRemindersTests.swift:93` — `planIncludesImplicitRepeatDueDate`:
    Regel `.daily` mit `hour = 19`, `dueDate = rule.firstDueDate(now:calendar:)`, `now` = 16. um 08:00;
    `#expect(reminders.map(\.taskID) == [task.id])` **und** `#expect(reminders.first?.fireDate == date(17, hour: 9))`
    mit der Begründung „Sammel-Push um 9 Uhr, nicht um die in der Regel gespeicherten 19 Uhr". Damit ist beides
    belegt: Aufnahme in den Push und die Abgrenzung gegen einen individuellen Zeitpunkt.
    Output: Zeile 113 `✔ "Eine über firstDueDate implizit gesetzte Fälligkeit landet im Sammel-Push (AC-5)"`,
    Suite „DueReminders" passed (Zeile 114). `Shared/Notifications/DueReminders.swift` ist nicht geändert.
  - Bewertung: **AKZEPTIERT**

- [x] **AC-6 Regression: #102-Tests und bestehende `DueReminders.plan`-Abdeckung bleiben grün**
  - Angriff: „Alle Tests grün" kann auch heißen, dass Altfälle gelöscht oder aufgeweicht wurden.
  - Beweis: Die #102-Fälle stehen unverändert im Testcode und laufen grün:
    `Code reference: LooseEndsTests/RepeatRuleTests.swift:26` (`timeGuess`, `selecting`, Codec-Round-Trip) —
    Suite „Regelschritt: Wiederholungs-Uhrzeit" passed (Output Zeile 214);
    `Code reference: LooseEndsTests/RepeatEditTests.swift:19` (Round-Trip, Revisionsschreiben, #102-AC-2/AC-3) —
    Suite „Repeat rule edits" passed (Output Zeile 201);
    `Code reference: LooseEndsTests/DueRemindersTests.swift:17` (die drei bestehenden `plan`/`handle`-Fälle) —
    Suite „DueReminders" passed (Output Zeile 114). Ebenso grün: „RepeatRule roll-forward" (Zeile 188),
    „TaskActions" (Zeile 254), „Show in calendar" (Zeile 25) — die in der Spec benannten Downstream-Nachbarn.
    Gesamt: `Test Suite 'All tests' passed` (Zeile 17), `Test Succeeded` (Zeile 269), `EXIT=0` (Zeile 272),
    Build `EXIT=0`. Kein einziges `failed` im Output.
  - Bewertung: **AKZEPTIERT**

### Runde 2 — Nachfragen, Randfälle, Regressionssuche

- [x] **N1 (aus AC-2): Testen die AC-2/3/4-Fälle überhaupt den Produktionscode?**
  - Befund: Nicht direkt. `Code reference: LooseEndsTests/RepeatEditTests.swift:106` ist eine private Nachstellung
    `applyRepeat(_:on:)` im Testziel; `FieldEditorView.applyRepeat` wird von keinem Test aufgerufen (View-Code,
    kein UI-Test in diesem Ticket — von der Spec so vorgesehen, Test Plan Zeile 138-150).
  - Gegenprobe am echten Code: `Code reference: LooseEnds/Views/FieldEditorView.swift:229` — der produktive Guard
    (`let isNewRule = task.repeatRule == nil && rule != nil`, danach `if isNewRule, let rule, task.dueDate == nil`)
    ist zeichengleich mit dem der Nachstellung (deren Zeilen 107 und 109). Einziger Unterschied ist der Schreibweg:
    Produktion `setDue(rule.firstDueDate(), hasTime: rule.hour != nil)` statt `RevisionService.set(.dueDate, …)`
    plus `task.dueHasTime = rule.hour != nil` im Test. `setDue` (`Code reference:
    LooseEnds/Views/FieldEditorView.swift:240`) normalisiert zusätzlich auf `startOfDay`, wenn `hasTime == false` —
    ein No-op, weil `firstDueDate` in genau diesem Fall (`hour == nil`) bereits `startOfDay` liefert
    (`Code reference: Shared/Models/RepeatRule.swift:49`). `task.dueHasTime = stored != nil && hasTime` ist bei
    nicht-nil Datum identisch zu `rule.hour != nil`. Semantisch äquivalent, die ACs bleiben bewiesen.
  - Restrisiko: Eine spätere Änderung an `applyRepeat` oder `setDue` bliebe von den Tests unbemerkt (der Spiegel
    driftet still). Nicht blockierend, festgehalten als F001 (LOW).
  - Bewertung: **AKZEPTIERT mit Finding F001 (LOW)**

- [x] **N2 (Randfall): Was passiert bei `hour != nil`, aber `minute == nil`?**
  - Dann liefert `firstDueDate` wegen `guard let hour, let minute` den `startOfDay`
    (`Code reference: Shared/Models/RepeatRule.swift:49`), während `applyRepeat` `hasTime: rule.hour != nil` = `true`
    übergibt (`Code reference: LooseEnds/Views/FieldEditorView.swift:233`) — die Aufgabe trüge „Mitternacht" als
    echte Uhrzeit und liefe in `CalendarSync` als Termin statt als Ganztag.
  - Erreichbarkeit geprüft: `hour` und `minute` werden ausschließlich gemeinsam gesetzt, aus `RepeatRule.timeGuess`
    heraus (`Code reference: Shared/Models/RepeatRule.swift:67`, `created.hour` und `created.minute` direkt
    hintereinander aus demselben Tupel). Eine Suche über `LooseEnds/` und `Shared/` zeigt keinen weiteren
    produktiven Schreibpfad für `hour`; in `FieldEditorView` ist `.hour` nur an der neuen Zeile 233 referenziert
    (kein Zeit-Picker für die Regel). Über die Produkt-Pfade damit nicht auslösbar.
  - Bewertung: **AKZEPTIERT mit Finding F002 (LOW, latent)**

- [x] **N3 (aus AC-2): Der AC-2-Test prüft nur `dueDate != nil`, nicht den Wert.**
  - AC-2 fordert wörtlich „`task.dueDate` trägt den Wert von `rule.firstDueDate()`". Der Test
    (`Code reference: LooseEndsTests/RepeatEditTests.swift:127`) prüft nur auf „nicht nil".
  - Relativierung: Die Nachstellung setzt das Datum selbst aus `rule.firstDueDate()` ohne injizierten `now`; ein
    Wertvergleich wäre dort tautologisch und an der Sekundengrenze flaky. Der Wert ist über AC-1 mit drei exakten
    Vergleichen abgedeckt (`RepeatRuleTests.swift:99`, `:112`, `:124`), die Ableitung von `dueHasTime` in Zeile 128.
    Die geforderte Eigenschaft ist in Summe belegt, nur nicht in einem einzigen Test.
  - Bewertung: **AKZEPTIERT mit Finding F003 (LOW)**

- [x] **N4 (Regression): Bricht der neue Schreibpfad einen der Aufrufer?**
  - `applyRepeat` hat vier Aufrufer (Frequenz-Picker, Interval-Stepper, Wochentag-Zeile, Basis-Picker; einer davon
    `Code reference: LooseEnds/Views/FieldEditorView.swift:217`). Für alle greift derselbe Guard: der Zusatz feuert
    nur beim Übergang nil → non-nil und nur bei leerem `dueDate`. Beim Löschen der Regel (`rule == nil`) bleibt
    `isNewRule` false, es wird also kein Datum geschrieben.
  - Downstream unangetastet: geändert sind nur `Shared/Models/RepeatRule.swift` und
    `LooseEnds/Views/FieldEditorView.swift` (+15 Zeilen). `DueReminders`, `ViewRules`, `CalendarSync` und
    `TaskActions` sind unverändert, ihre Suiten grün (Output-Zeilen 114, 40, 25, 254).
  - Bewertung: **AKZEPTIERT**


## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEndsTests/RepeatEditTests.swift:106
  Description: Die AC-2/3/4-Tests rufen eine private Nachbildung von `applyRepeat` im Testziel auf statt
    `FieldEditorView.applyRepeat`. Der produktive Guard ist heute zeichengleich
    (LooseEnds/Views/FieldEditorView.swift:229-235), `setDue` semantisch äquivalent — die ACs sind belegt,
    aber eine spätere Änderung am View-Code bliebe unbemerkt.
  Spec requirement: AC-2/AC-3/AC-4 — von der Spec selbst so geplant (Test Plan, Zeile 138-150).
  Conflict: Kein Spec-Verstoß; Abdeckungslücke gegenüber dem echten Aufrufpfad.
  Remediation: Guard und Schreibschritt in eine reine, testbare Funktion ziehen, die die View nur aufruft —
    oder später ein UI-Smoke-Test nach dem Design-Freeze.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Models/RepeatRule.swift:49
  Description: `firstDueDate` verlangt `hour` UND `minute` (`guard let hour, let minute`), `applyRepeat`
    leitet `hasTime` dagegen nur aus `hour != nil` ab (LooseEnds/Views/FieldEditorView.swift:233). Bei
    `hour != nil, minute == nil` entstünde ein Datum auf `startOfDay` mit `dueHasTime == true`.
  Spec requirement: AC-1/AC-2 — Uhrzeit-Ableitung und `dueHasTime` müssen zusammenpassen.
  Conflict: Über die Produkt-Pfade nicht erreichbar, weil `hour`/`minute` nur gemeinsam aus `timeGuess`
    gesetzt werden (Shared/Models/RepeatRule.swift:67-68) und kein weiterer Schreibpfad existiert. Latent.
  Remediation: Entweder `hasTime: rule.hour != nil && rule.minute != nil` oder `minute` auf 0 defaulten.

Finding:
  ID: F003
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEndsTests/RepeatEditTests.swift:127
  Description: Der AC-2-Test prüft `task.dueDate != nil` statt der von AC-2 wörtlich geforderten Gleichheit
    mit `rule.firstDueDate()`.
  Spec requirement: AC-2 — „Then trägt `task.dueDate` den Wert von `rule.firstDueDate()`".
  Conflict: Nur die schwächere Eigenschaft ist in diesem Test geprüft. Der Wert selbst ist über AC-1
    (LooseEndsTests/RepeatRuleTests.swift:99, :112, :124 — drei exakte Wertvergleiche) und die Ableitung von
    `dueHasTime` (Zeile 128) abgedeckt; ein Wertvergleich wäre hier tautologisch und zeitabhängig.
  Remediation: `now` in die Nachbildung injizieren und exakt gegen `rule.firstDueDate(now:)` vergleichen.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: LooseEndsTests/RepeatRuleTests.swift:99
  Evidence: Drei Tests mit exakten Wertvergleichen (Zeilen 99, 112, 124) decken „mit Uhrzeit" (25. 19:00),
    „ohne Uhrzeit" (startOfDay) und „wöchentlich ohne weekdays" (Gleichheit mit nextDueDate) ab.
    Output-Zeilen 211-213 alle ✔, Suite „Regelschritt: Wiederholungs-Uhrzeit" passed (Zeile 214).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEndsTests/RepeatEditTests.swift:116
  Evidence: `dueDate` gesetzt, `dueHasTime == true` bei Regel mit erkannter 7-Uhr-Zeit, Revision mit
    `field == .dueDate` und `author == .user` per #require/#expect. Output Zeile 197 ✔. Produktionspfad
    gegengeprüft: LooseEnds/Views/FieldEditorView.swift:229-235 ruft setDue (Zeile 240), das über
    RevisionService mit `author: .user` schreibt und `dueHasTime` setzt. Einschränkungen: F001, F003 (LOW).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEndsTests/RepeatEditTests.swift:133
  Evidence: Vorhandenes `dueDate` bleibt identisch UND die Zahl der `.dueDate`-Revisionen bleibt 1 —
    schließt auch eine stille wertgleiche Doppelschreibung aus. Output Zeile 198 ✔.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEndsTests/RepeatEditTests.swift:153
  Evidence: Echter Zustandsübergang (Regel anlegen, dann ändern); `dueDate` unverändert,
    `.dueDate`-Revisionen bleiben bei 1. Output Zeile 199 ✔.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEndsTests/DueRemindersTests.swift:93
  Evidence: `DueReminders.plan` liefert genau diese Task, `fireDate` = 9:00 am Fälligkeitstag, nicht die
    19:00 aus der Regel. Output Zeile 113 ✔, Suite „DueReminders" passed (Zeile 114).
    Shared/Notifications/DueReminders.swift ist unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEndsTests/RepeatRuleTests.swift:26
  Evidence: Alle #102-Fälle stehen unverändert im Testcode (RepeatRuleTests.swift:26-87,
    RepeatEditTests.swift:19-98) und sind grün (Output-Zeilen 214, 201); die bestehende
    `DueReminders.plan`-Abdeckung (DueRemindersTests.swift:17-88) ebenfalls (Zeile 114). Gesamtlauf:
    `Test Suite 'All tests' passed` (Zeile 17), `Test Succeeded` (Zeile 269), `EXIT=0` (Zeile 272);
    Build `Build Succeeded`, `EXIT=0`.
  Status: CONFIRMED

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Umsetzung hat die Adversary-Prüfung bestanden.
Tests: alle Suiten grün (`Test Succeeded`, `EXIT=0`), 0 Fehlschläge. Build: `Build Succeeded`, `EXIT=0`.
Randfälle: `hour` ohne `minute` (F002, über Produkt-Pfade nicht auslösbar), Regel-Löschung (`rule == nil`,
Guard greift nicht), bereits gesetztes `dueDate`, zweite Regeländerung — alle geprüft, keiner bricht.
Regressionen: keine. Geändert sind 2 Dateien mit +15 Zeilen; alle vier `applyRepeat`-Aufrufer und die
Downstream-Nachbarn (`DueReminders`, `ViewRules`, `CalendarSync`, `TaskActions`) unverändert und grün.
Checkliste: 6/6 Punkte bewiesen. Drei LOW-Findings (F001-F003), nicht blockierend, kein Fix in diesem Scope nötig.

## Geprüfte Dateien

- sha256:30b3e17e9f39519a55e2a1a312254d6cd89496fe1d94db1c2b2db320b7ced609  LooseEndsTests/DueRemindersTests.swift
- sha256:5e77d9bee0611770b37ba04362306f5d508f5f4806a6bd57fd11be54e107f220  LooseEndsTests/RepeatEditTests.swift
- sha256:4a40e5c490888011b777b8240f152244a0726f662e9d1ded3d0537c48da00919  LooseEndsTests/RepeatRuleTests.swift
- sha256:70e220a751934e328bbe8e736a4853cdb8597ef36b26bd5c1e19534f811f42c6  Shared/Models/RepeatRule.swift

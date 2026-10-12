# Zwischenstand #25 (Sicherung vom 2026-10-12)

**Nur Sicherung, kein Auslieferungsstand.** Die Umsetzung von #25 lag bisher ausschließlich vorgemerkt (nicht committet) in einem lokalen Arbeitsordner (`polished-skipping-valley`). Hier liegt sie als Patch, damit sie nicht verloren geht.

- `wip-stand-2026-10-12.patch` — die vorgemerkten Änderungen gegen den damaligen Stand von `wip/25-siri-red-tests` (enthält die neue Datei `Shared/Intents/ReminderSchema.swift`, Änderungen an `Shared/Services/CaptureService.swift`, `LooseEndsTests/IntentExecutionTests.swift`, `LooseEndsTests/ReminderSchemaTests.swift`, dazu den Testbeleg).
- Die Tests (RED) liegen als Commit auf dem Zweig `wip/25-siri-red-tests`.
- Der Stand ist **72 Commits hinter `main`** gewesen, nicht gegen aktuelles `main` gebaut oder getestet und nicht durch den Workflow gelaufen (Spec-Abgleich mit F1/F2/F3/F5, Gegenprüfung, Gerätestufe).
- Der Patch enthält auch eine Änderung an `docs/project/04-stand.md`; die Datei ist aufgelöst (#343) und gehört nicht zurückgeholt.

Wiederherstellen: Zweig `wip/25-siri-red-tests` ausgehend von `main` neu aufsetzen, dann `git apply wip-stand-2026-10-12.patch` (die Hunks zu `04-stand.md` weglassen: `--exclude=docs/project/04-stand.md`).

Fortsetzung: Meilenstein M2, Ticket #25.

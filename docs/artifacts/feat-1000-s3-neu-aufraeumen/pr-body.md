## #1000 Schnitt 3a – Ansicht „Neu“ und Sichtungsregeln entfallen (ADR-22)

- `ViewKind.new` (Titel, Symbol), `ViewRules.ReviewReason`/`needsLook`/`isInNew`/`canConfirm`/`reviewReason`, `case .new` in `tasks(for:)`, `TaskActions.confirmReview`, `.new?` in `RowKeyAction`, Leersatz in `TaskListView` entfernt (5 App-Dateien, +3/−65).
- `ReviewTrayTests` gelöscht, Einzeltests auf „Lose Enden“ bzw. `hasUnseenAutomaticRevisions` umgestellt; neu `ViewKindWithoutNewTests` (RED → GREEN).
- Eine gespeicherte Ansicht mit Rohwert `new` liest sich als „Als nächstes“ (`SavedView` wird in der App nirgends angelegt).
- Belege: Unit-Lauf grün, `test-proof InboxDrawerSmokeTests` 3/3, Startseite ohne „Neu“ (`docs/artifacts/feat-1000-s3-neu-aufraeumen/`). Adversary VERIFIED (2 Runden, 2 LOW: veraltete Kommentare → 3b).
- Kein Pfad der Geräteliste berührt. Die Abnahme endet nach Stufe 2.
- Offen in Schnitt 3b: Tönung „noch nicht angesehen“ in `TaskRow`, `Paper.wideNoteInsets`, Katalogschlüssel, Design-Briefing, Funktionsübersicht, veraltete Kommentare.

Refs #1000

🤖 Generated with [Claude Code](https://claude.com/claude-code)

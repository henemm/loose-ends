## Regel „Jetzt“ für die Startseite (#368, Schnitt 1)

Neue reine Regel `ViewRules.now(in:now:calendar:)`: „Heute fällig“ und „Als nächstes“ als eine Liste, jede Aufgabe einmal.
Zuerst überfällig (älteste zuerst), dann heute fällig (früheste Uhrzeit zuerst), dann die übrigen vorgemerkten nach `nextRank`.
Eine vorgemerkte und fällige Aufgabe steht bei den fälligen (Zeitdruck gewinnt).

- `dueToday`, `badgeCount`, `tasks(for:)` unverändert; die Zahl am App-Symbol zählt dieselben zwei Mengen.
- Die Startseite ändert sich in diesem Schnitt nicht; Schnitt 2 baut den Block „Jetzt“ auf dieser Regel.
- 13 Unit-Tests (`NowRuleTests`), Doku in `docs/project/02-datenmodell-und-ansichten.md`.
- PR #340 geschlossen, nicht gemergt (ersetzt durch diese Regel).
- Kein Pfad der Geräteliste berührt.

Spec: `docs/specs/feat-368-schnitt-1-regel-jetzt.md` (Teil der Gesamt-Spec `docs/specs/feat-368-startseite-drei-zonen.md`).

Closes #339
Refs #368

🤖 Generated with [Claude Code](https://claude.com/claude-code)

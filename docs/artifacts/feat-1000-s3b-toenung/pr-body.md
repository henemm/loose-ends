## #1000 Schnitt 3b – Tönung „noch nicht angesehen“ und Katalogschlüssel von „Neu“ entfallen (ADR-22)

- `TaskRow`: Rand grau oder rot (Zeitdruck), Merkmale immer grau, kein Funke „Changed by AI“; Akzent nur noch am Knopf „Neues Datum“ (Entwurf A, Henning 2026-11-26).
- `Paper.wideNoteInsets` entfernt (unbenutzt seit S2).
- Katalog: neun Schlüssel entfernt („New“, „%lld to look over“, „Looks right“, „Needs a look“, „was: %@“, „Title not checked“, „Not sorted yet“, „Nothing to look over.“, „Changed by AI“), nur Löschzeilen.
- Kommentare in `TaskItem`/`ViewRules` ohne „New“; Design-Briefing, Funktionsübersicht, CLAUDE.md nachgezogen.
- Test: `CatalogWithoutNewTests` (RED → GREEN), voller Unit-Lauf grün (0 rot, 13 Mess-/Modelltests übersprungen), `test-proof InboxDrawerSmokeTests` 3/3; Bild vorher/nachher unter `docs/artifacts/feat-1000-s3b-toenung/` („Phone“ Petrol → grau). Adversary VERIFIED (2 Runden, keine Funde).
- Kein Pfad der Geräteliste berührt. Die Abnahme endet nach Stufe 2.
- Rest außerhalb der Spec: verwaister Schlüssel „Check the tinted values, then “Looks right”.“ (ohne Aufrufer, älter als #1000).

Closes #1000

🤖 Generated with [Claude Code](https://claude.com/claude-code)

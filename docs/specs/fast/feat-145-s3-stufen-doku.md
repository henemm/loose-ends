# Mini-Spec: feat-145-s3-stufen-doku

Refs #145 (Schnitt 3). Das Ticket bleibt offen, bis der Pilot (erstes UI-Ticket durch die Sperre) gelaufen ist.

**ADR-Nr.:** keine — reine Doku, keine Architekturentscheidung.

## Was ändert sich
- `docs/reference/abnahme-und-arbeitsweise.md`, Abschnitt „Abnahme in drei Stufen“, Stufe 2: ein Absatz grenzt
  vier Dinge ab — übersetzen ist nicht bauen, bauen ist nicht installieren, installieren ist nicht **benutzen**.
  Nur „benutzen“ (der geänderte Ablauf wird im Simulator durchgespielt und belegt) ist die Stufe. Der Absatz nennt
  die Sperre: `phase8_complete` verlangt den Beleg aus `./scripts/sim.sh test-proof <Klasse>`, sobald eine
  Code-Datei außerhalb von `LooseEnds/Mac/` geändert wurde (Plugin ≥ 3.42.0).
- `CLAUDE.md`, Absatz „Acceptance runs in stages“: derselbe Gedanke in einem Satz, mit Verweis auf die Referenz.

## Was darf sich nicht ändern
- Kein Code, kein Skript, kein Gate, keine Geräteliste, keine `project.yml`.
- Die Reihenfolge und Verbindlichkeit der drei Stufen bleibt wörtlich.

## Test-Schritte
1. `git diff --stat` zeigt genau zwei Dateien, nur Text.
2. `grep -n "benutzen" docs/reference/abnahme-und-arbeitsweise.md CLAUDE.md` findet die neue Abgrenzung.
3. Die Aussage zur Sperre stimmt mit `docs/artifacts/feat-145-s2-gate/` und `scripts/sim.sh test-proof` überein.

## Inline-Test
- [ ] Kein Code geändert: `git diff --name-only` nennt nur `*.md`.

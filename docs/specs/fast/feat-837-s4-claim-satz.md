# Mini-Spec: feat-837-s4-claim-satz

Schnitt 4 von #837. Der Store-Untertitel steht (de-DE „Einfach sagen. Kopf frei.“, en-US „Say it. Clear your head.“, Beleg: Läufe 42208957863 und 42209069974). Der Einleitungssatz in `CLAUDE.md` und `README.md` („Say it, it's sorted.“) verspricht noch das Verworfene („Sortiert“, Henning 2026-11-04) und wird an den freigegebenen Kern angeglichen.

## Was ändert sich
- **AC-1:** `README.md`, Zeile 3: „Say it, it's sorted.“ wird „Say it. Clear your head.“
- **AC-2:** `CLAUDE.md`, Zeile 3: „Say it, it's sorted.“ wird „Say it. Clear your head.“; der Rest des Satzes („Task capture with on-device Apple Intelligence …“) bleibt.
- **AC-3:** In beiden Dateien bleibt außer dieser Zeile jede Zeile unverändert (Diff: genau 2 Dateien, je 1 Zeile).

## Was darf sich nicht ändern
- Kein Produktcode, keine `project.yml`, keine Store-Texte, keine Dokumente unter `docs/context/` (historische Belege).
- Der Untertitel-Wortlaut in `docs/reference/app-store-untertitel.md` bleibt wie freigegeben.

## Manuelle Test-Schritte
1. `grep -rn "it's sorted" README.md CLAUDE.md` liefert keine Treffer.
2. `grep -n "Clear your head" README.md CLAUDE.md` liefert je eine Zeile 3.

## Inline-Test (wird während Implementierung geschrieben)
- [ ] Kein Test nötig: reine Textzeile; Prüfung per `grep` wie oben, Ergebnis im Abschlussbericht.

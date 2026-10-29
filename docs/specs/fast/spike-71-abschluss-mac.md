# Mini-Spec: #71 Abschluss mit dem Mac-Wert

## Was ändert sich
- `docs/reference/modell-guardrails.md`: Abschnitt „Entscheidung“. Gesamtwert Mac 0,52 % (2 von 387), unter der 1-%-Schwelle. Die iPhone-Spalte entfällt auf Hennings Wort (2026-10-29), mit Begründung: Die App behandelt eine endgültige Ablehnung seit #535 (`TaskItem`, `ModelFailure`); ein iPhone-Wert über oder unter 1 % ändert nichts, was gebaut wird. Messweg `lab-guardrail` bleibt im Repo.
- `docs/project/06-annahmen-und-experimente.md`, Zeile B3: Ergebnis „nicht widerlegt, 0,52 % auf dem Mac (obere Grenze 1,86 %)“, Verzicht auf iPhone, Wiedereinstieg über Rückmeldungen aus TestFlight.
- Ticket #71 wird geschlossen.

## Was darf sich nicht ändern
- Kein Code, kein Skript, kein Test; kein Zugriff auf ein Gerät.
- Zahlen im Mac-Bericht bleiben wörtlich.

## Manuelle Test-Schritte
1. Entfällt (nur Dokumentation); `git diff --stat` zeigt zwei Dateien.

## Inline-Test
- [ ] `scripts/test_*` für Dokumente (falls vorhanden) bleiben grün

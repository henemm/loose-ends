# Übergabe S3b-2 (Stand 2026-11-13, nach /clear als Erstes lesen)

Spec (3. Nachtrag, auto-freigegeben, Ampel grün): docs/specs/feat-795-schnitt-3b2-debug-weg.md. Phase phase6_implement.

Erledigt (gestaged, NICHT committet — Commit-Gate verlangt erst Adversary VERIFIED):
- AccountWiring.swift, AccountSectionTests.swift (RED-Commit 19292d9), server/scripts/local-service.sh, server/scripts/local-fixture.ts
  (Unterbefehle session, transcript, order, result, due), scripts/sim.sh (LOOSEENDS_SIM_SIGN=1), CLAUDE.md,
  Belege selbsttest.md, ab-lauf.md, spike-signatur.md, b-aufgabe.png, test-green-output.txt.
- AC-1..18 belegt: selbsttest.md (zweiter Lauf, mit `due` mit Datum → UUID, `due` ohne Datum → Ausgang 1),
  ab-lauf.md (vierter Lauf 11:42 UTC, A und B vorher deinstalliert; Schritt 4b: `due` → `done`, gleiche taskID,
  B's ZREVISION eine Zeile dueDate/user/Claude, ZCAPTUREDVIARAW claude), Unit-Suite grün (test-green-output.txt).
- LoC der Code-Dateien ohne CLAUDE.md: 248 von 250 (local-fixture.ts 59 statt 54 Zeilen).

Offen (Orchestrator):
add-artifact test_output, auto-green, phase6b_adversary, Adversary-Dialog (Step 8 von /50-implement), Commit.

Entscheidung PO 2026-11-13: Art des Nachweises ist Tech-Lead-Sache (nicht fragen).

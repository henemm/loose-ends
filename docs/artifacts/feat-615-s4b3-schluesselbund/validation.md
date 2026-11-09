# Validation Report: feat-615-s4b3-schluesselbund (2026-11-09)

## Test Results
- Voller Unit-Lauf (`./scripts/sim.sh sim-unit`, `validate-full-unit.txt`, xcresult): 1241 bestanden, 0 fehlgeschlagen, 13 übersprungen.
  Übersprungen, alle ohne Bezug zu diesem Schnitt (Messstrecken ohne Eingabedatei, echtes Modell, Sprachlatenz):
  Guardrail report from the iPhone result file (#71); RawSentenceReportTests; Rohsatz-Export (2 Hilfstests);
  RealModelGuardrailTests; RealModelLatencyTests; RealModelTests (3); SelfConsistencyReportTests;
  Speech latency (#274) (2); TextFormModelReportTests.
- Neue Tests alle bestanden, parametrisierte mit allen Fällen: abfragen; statusabbildung save (5); save duplikat wird update;
  update ohne treffer ist fehler ohne retry (3); load statusabbildung; clear statusabbildung (6); leere und ungueltige daten (3);
  fehlende berechtigung ist kein nil; fehler ohne token; serviceclient: abbruch ist cancellation (3); serviceclient: transportfehler (3).
- `./scripts/sim.sh build`: Build erfolgreich, keine Warnung aus den geänderten Dateien (`validate-build.txt`).
- Simulator-Beleg: `test-proof CaptureSmokeTests/testPlusButtonProof` bestanden, Bilder angesehen (Erfassungsblatt leer und mit Text).

## Spec Compliance
- AC-1 bis AC-10: erfüllt (Tests oben, Prüfagent mit Datei:Zeile).
- AC-11: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` = CLAUDE.md, LooseEnds/Claude/KeychainSessionStore.swift,
  LooseEnds/Claude/ServiceClient.swift, LooseEnds/Claude/SessionStore.swift, LooseEndsTests/KeychainSessionStoreTests.swift,
  LooseEndsTests/ServiceClientTests.swift. `grep -nE 'print\(' KeychainSessionStore.swift`: kein Treffer; kein `try?`; längste Funktion ≈ 20 Zeilen.
- AC-12: `grep -n KeychainSessionStore CLAUDE.md` → Zeile 450; in der Validierung ergänzt: „no caller yet“ auch bei `SessionStoring`.
- AC-13: Lauf und Bau grün (oben).

## Regression Check
- Keine Regressionen.

## Scope Check
- Code/Test-Dateien: 5 (plus CLAUDE.md Doku).
- LoC: +296/−4 (Code 108, Tests 183, Doku); Überhang über 250 von Henning angenommen („So annehmen“, docs/context).
- Out-of-scope: keine.

## Abnahme
- Stufe 1 und 2 belegt. Kein Pfad der Geräteliste berührt.
- Echter Schlüsselbund bleibt unbelegt bis 4c; F4 ändert Verhalten (Abbruch = CancellationError).

## Result: PASS

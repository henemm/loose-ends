# Validierungsprotokoll: feat-615-s4b-app-kern (Schnitt 4b-1, Refs #615)

Datum: 2026-11-09. Spec: `docs/specs/feat-615-schnitt-4b1-dienst-client.md`. Adversary: VERIFIED (2 Runden, 11 Punkte).

## Tests (AC-1 bis AC-9, AC-11)

- `./scripts/sim.sh unit` (iOS-Simulator, voller Lauf): `Test Succeeded`, 1173 Swift-Testing-Fälle ✔, 0 ✘; XCTest 12 Tests, 0 Fehler.
  Suite „ServiceClient (#615)“ grün, darin alle neun Tests der Spec.
- Übersprungen (einzeln, vom Skript benannt, unabhängig von diesem Schnitt):
  - `RawSentenceReportTests`, fehlt `loose-ends-rawtexts.json`
  - `SelfConsistencyReportTests`, fehlt `selfconsistency-run.json`
  - `TextFormModelReportTests`, fehlt `textform-run.json`
  - Latenzschutz #274 „The first word arrives within 3 s of speech start“ und „The final text keeps the key words“: de_DE im Simulator nicht unterstützt
- `./scripts/sim.sh build` nach `generate`: `Build Succeeded`; keine Warnung und kein Fehler aus `LooseEnds/Claude/`.
- Keine Regressionen.

## AC-9 (grep-Teil)

`grep -nE 'Logger|print\(' LooseEnds/Claude/Nonce.swift LooseEnds/Claude/ServiceClient.swift`: kein Treffer (Exit 1).
`grep -n 'try?' LooseEnds/Claude/*.swift`: kein Treffer.

Anmerkung zum Marker-Test „serviceclient: fehler ohne token und koerper“: Er prüft nicht selbst, dass ein Fehler geworfen wird.
Jede seiner fünf Antworten (401, 503, 500, 200 mit leerem Token bzw. 200 auf einer 204-Route, `URLError(.timedOut)`) wirft nachweislich
in den Tests zu AC-5, AC-7 und AC-8; die Prüfung ist damit gedeckt. Kein Code-Fix, keine neue Adversary-Runde.

## AC-10

- `git diff --name-only origin/main -- . ':!docs' ':!.claude'`: `CLAUDE.md`, `LooseEnds/Claude/Nonce.swift`,
  `LooseEnds/Claude/ServiceClient.swift`, `LooseEndsTests/ServiceClientTests.swift`. Kein `project.yml`, keine Entitlements,
  keine `Info.plist`, nichts unter `Shared/` oder `server/`.
- Längste Funktion: `ServiceClient.send(_:success:)` unter 30 Zeilen; keine über 50.
- `grep -n 'LooseEnds/Claude' CLAUDE.md`: genau ein Treffer (Zeile 446, „Where things live“).
- **Umfang: +275 LoC** (34 + 99 + 139 + 3), 25 über dem Ziel von 250. Überhang liegt in den Tests (139 statt ≈ 120); wie in der Spec
  („Estimated Changes“) vorgesehen hier benannt.

## Abnahme

- Stufe 1: grün (oben). Stufe 2: kein Bedienablauf, die App ruft `Nonce` und `ServiceClient` nicht auf; Beleg ist der Unit-Lauf im
  Simulator samt Bau. Stufe 3: Kein Pfad der Geräteliste berührt.

## Ergebnis: PASS

## Simulator-Beleg (Evidence-Gate)

`./scripts/sim.sh test-proof CaptureSmokeTests/testPlusButtonProof`: bestanden (iPhone 17, iOS 27.0), Beleg `simulator-run.txt`.
Bild angesehen: Startseite „All tied up.“, Erfassungszeile, „Now 0“, Inhaltsliste (Next up bis Completed), Tags 6; die App startet mit dem
neuen Ordner unverändert. Der Schnitt hat keinen eigenen Bedienablauf (kein Aufrufer).

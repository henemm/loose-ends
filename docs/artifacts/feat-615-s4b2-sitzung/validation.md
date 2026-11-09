# Validierungsprotokoll: feat-615-s4b2-sitzung (Schnitt 4b-2, Refs #615)

Datum: 2026-11-09

## Tests (AC-18)

- `./scripts/sim.sh generate`, dann `./scripts/sim.sh sim-unit` (alle Unit-Tests, iOS-Simulator): Exit 0, „Test Succeeded“,
  1186 bestandene Testfälle im Log, 0 Fehlschläge; die 16 neuen `account:`-Tests darin grün.
- Übersprungen (unverändert gegenüber main, nicht durch diesen Schnitt): Messstrecken `RawSentenceReportTests`
  (fehlt `loose-ends-rawtexts.json`), `SelfConsistencyReportTests` (fehlt `selfconsistency-run.json`),
  `TextFormModelReportTests` (fehlt `textform-run.json`); Latenzschutz #274 „The first word arrives within 3 s of speech
  start“ und „The final text keeps the key words“ (Sprache de_DE im Simulator nicht installiert).
- `./scripts/sim.sh build`: Exit 0, „Build Succeeded“; keine Warnung aus `LooseEnds/Claude/`.

## Keine Preisgabe (AC-16, grep-Teil)

- `grep -nE 'print\(|try\?' LooseEnds/Claude/SessionStore.swift LooseEnds/Claude/AccountState.swift`: keine Treffer.
- Alle acht `logger.`-Zeilen (`AccountState.swift` 57, 79, 86, 108, 116, 127, 136, 147) gesichtet: nur Typname des Fehlers
  oder `ServiceError`-Fallname (`rejected(Int)` trägt nur den Statuscode), nie Token, Nonce, Identity-Token, Code oder Körper.

## Grenze und Länge (AC-17)

- `git diff --name-only origin/main -- . ':!docs' ':!.claude'`: genau `LooseEnds/Claude/AccountState.swift`,
  `LooseEnds/Claude/SessionStore.swift`, `LooseEndsTests/AccountStateTests.swift`. Kein `project.yml`, keine Entitlements,
  keine `Info.plist`, nichts unter `Shared/` oder `server/`, keine Schlüsselbund-Anbindung.
- Längste Funktion `deleteAccount` 24 Zeilen, alle unter 50.
- **LoC: +526** (Produkt 218, Tests 308) gegen ±250. Der Produktcode liegt innerhalb der Grenze; der Überhang sind die
  Tests, vor allem die Sicherheitsfälle (veraltete 401, Doppelaufrufe, Abmelden lokal zuerst, Marker-Test) mit
  Haken-Transport. Wie in 4b-1 angenommen (Spec „Estimated Changes“).

## Spec-Abgleich AC-1 bis AC-16

Unabhängiger Abgleich (Lese-Agent): alle 16 Kriterien erfüllt, Testnamen wörtlich wie in der Spec.
Abweichungen ohne Verstoß: AC-4 prüft „verschiedene Werte“ über eine zweite Instanz statt einen zweiten Lauf derselben
(jede Nonce entsteht frisch, gleichwertig); Transport ist ein eigener Haken-Transport statt `FakeTransport` (Spec erlaubt ihn).

## Befund für Folgeschnitte

- **F4:** `ServiceClient.send` (4b-1) bildet jeden `URLError` auf `unavailable` ab. Bricht eine echte `URLSession`-Anfrage
  durch Task-Abbruch ab, kommt `URLError(.cancelled)` an, nicht `CancellationError`; `AccountState` zeigte dann
  `retryLater` (bzw. beim Löschen `lastProblem = .retryLater`) statt eines stillen Abbruchs. Im Kern dieses Schnitts nicht
  erreichbar (nichts ruft ihn auf); vor 4c in `ServiceClient` `.cancelled` auf `CancellationError` abbilden, im Issue
  #615 vermerkt.

## Abnahme

Stufe 1 und 2: Unit-Lauf und Bau im Simulator, kein Bedienablauf (nichts ruft den Kern auf). Kein Pfad der Geräteliste berührt.

## Simulator-Beleg (Stufe 2)

`scripts/sim.sh test-proof CaptureSmokeTests/testPlusButtonProof` bestanden (iPhone 17, iOS 27.2): Startseite wie gewohnt, erfasste
Aufgabe „Reifen wechseln lassen“ erscheint unter „New“. Rauchprobe, dass die App mit den neuen Dateien startet und nutzbar bleibt;
der Kern selbst hat keinen Bedienablauf.

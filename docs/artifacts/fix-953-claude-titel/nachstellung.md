# Nachstellung #953 (Analyse, 2026-11-19)

Weg: derselbe Code, der auf Hennings Gerät nach dem Abholen eines Auftrags läuft — `OrderExecutor.execute` mit einem
`capture`-Auftrag ohne `fields` (so schickt Claude `capture_task` im Normalfall), danach `EnrichmentCoordinator.processPending`
bzw. `reanalyze`. Nur das Modell ist durch `StubEnricher` ersetzt (im Simulator meldet Apple Intelligence
„Simulator is not supported“, siehe `docs/artifacts/feat-795-s3b2-debug-weg/spike-signatur.md`); der Stub liefert einen
verkürzten Titel mit Konfidenz 0,9, wie ihn das echte Modell regelmäßig liefert (Memory #202: „Titel oft fast derselbe Text“).

Lauf: `./scripts/sim.sh sim-unit Repro953Tests` (Wegwerf-Suite, nicht eingecheckt), iPhone-17-Simulator, 2026-11-19 07:59.

```
Test "Capture ohne fields: Modell schreibt den Titel um" recorded an issue at Repro953Tests.swift:27:9:
  Expectation failed: task.title == Self.text
  task.title → "Angebot Gartenhütte einholen"
  Self.text → "Angebot für die Gartenhütte bei Müller einholen"
Test "Erneut analysieren nach Capture ohne fields" recorded an issue at Repro953Tests.swift:38:9:
  Expectation failed: task.title == Self.text
  task.title → "Angebot Gartenhütte einholen"
  Self.text → "Angebot für die Gartenhütte bei Müller einholen"
Suite "Repro 953" failed after 0.665 seconds with 2 issue(s)
```

Befund: Fehler in beiden Wegen gezeigt (Erstlauf und „Erneut analysieren“). Der Titel eines Claude-Auftrags hat keine
Nutzer-Revision, also gibt `EnrichmentWriter` ihn dem Modell frei (`may(.title, firstRun: !userHasTouched(.title, …))`).
Mit `fields.title` (#932) besteht die Nutzer-Revision und der Titel bleibt; das deckt den Normalfall nicht.

## Nach dem Fix (Validierung, 2026-11-19 08:25)

Derselbe Weg (`OrderExecutor.execute` mit `capture` ohne `fields`, dann `processPending` bzw. `reanalyze`, Stub mit dem
verkürzten Titel, Konfidenz 0,9), jetzt als eingecheckte Klasse `ClaudeTitleTests` im vollen Lauf `./scripts/sim.sh unit`,
iPhone-17-Simulator:

```
Test Suite 'ClaudeTitleTests' started at 2026-11-19 08:25:50.469.
    ✔ testAnalyzeAgainKeepsTheTitleOfAClaudeTask (0.238 seconds)
    ✔ testClaudeTaskEndsActiveEvenWithoutAModelTitle (0.125 seconds)
    ✔ testFirstRunKeepsTheTitleOfAClaudeTask (0.171 seconds)
    ✔ testModelStillSetsTheDurationOfAClaudeTask (0.237 seconds)
    ✔ testTaskFromTheAppIsStillRefinedByTheModel (0.107 seconds)
    ✔ testTitleClaudeSetKeepsAgainstTheModel (0.186 seconds)
Executed 6 tests, with 0 failures (0 unexpected) in 1.063 (1.066) seconds
```

Befund: Der Titel bleibt „Angebot für die Gartenhütte bei Müller einholen“, im Erstlauf und bei „Erneut analysieren“; der
Fehler aus dem Lauf oben ist weg. Ein UI-Test kann den Unterschied nicht zeigen: unter `--ui-testing` ist das Modell aus
(`ModelOffEnricher`), und der Simulator hat kein Apple Intelligence. Der Simulatorbeleg `simulator-run.txt`
(`test-proof CaptureSmokeTests`) belegt deshalb den Erfassungsablauf der App über den geänderten `EnrichmentWriter`
(keine Verschlechterung für App-Aufgaben), nicht die Modellstelle.

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

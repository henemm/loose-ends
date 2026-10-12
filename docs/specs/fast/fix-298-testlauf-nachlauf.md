# Mini-Spec: fix-298-testlauf-nachlauf

Issue #298 — Testläufe hängen nach dem Ergebnis: Simulator-Diagnose abschalten.

## Befund und Recherche

- `xcodebuild test` startet nach dem Ergebnis `simctl diagnose -l -b --timeout=600 …` und wartet darauf.
  Beobachtet am 2026-10-09: 19 Min Nachlauf nach bestandenem `CalendarTargetTests`; `kill` auf den
  `simctl diagnose`-Prozess beendete `xcodebuild` sofort mit rc=0 („Test Succeeded“). Dieselbe Eigenheit
  steckt hinter „sim.sh unit hängt ~10 Min nach“ (Memory „Unit-Lauf-Eigenheiten“).
- Xcode 27.0 (`xcodebuild -help`): `-collect-test-diagnostics on-failure|never` — „Whether or not testing
  collects verbose diagnostics (like a sysdiagnose) when encountering a failure“. Standard ist `on-failure`.
- Apple-Foren: https://developer.apple.com/forums/thread/756767 (xcodebuild hängt),
  https://developer.apple.com/forums/thread/818688 (xcodebuild hängt bei XCFail). Chromiums Testläufer
  setzt `-collect-test-diagnostics never`.
- Laut Hilfetext greift die Sammlung nur „bei Fehlschlag“, beobachtet wurde sie nach einem bestandenen Lauf.
  Was Xcode dabei als Fehlschlag zählt, klärt die Reproduktion (Schritt 1 unten), bevor der Fix kommt.

## Was ändert sich

- `scripts/sim.sh`, Funktion `run_xcodebuild`: Ist die Aktion `test`, wird `-collect-test-diagnostics never`
  angehängt. Das deckt alle vier Testaufrufe ab (`unit` auf dem Mac, `sim-unit`, `test`, `test-proof`);
  `build` und die Gerätebauten bleiben unberührt.
- `scripts/test_sim_run_xcodebuild.py` (neu): Test der Funktion `run_xcodebuild` mit einem
  Platzhalter-`xcodebuild` im `PATH`, der seine Argumente mitschreibt.
- Memory „Unit-Lauf-Eigenheiten“: Nachlauf behoben, Umgehung per `kill` nicht mehr nötig.

## Alternative (verworfen)

- `on-failure` lassen und nur einen Zeitdeckel ums `xcodebuild` legen: Diagnosen bei echten Fehlschlägen
  blieben erhalten. Verworfen, weil der Nachlauf laut Forum 818688 gerade bei einem Fehlschlag kommt — also
  dann, wenn die schnelle Rückmeldung am meisten zählt — und weil ein Zeitdeckel einen laufenden Test
  abwürgen kann. Die Fehlermeldung des Tests selbst steht weiter im Log und im Ergebnisbündel; es fehlt nur
  der sysdiagnose-artige Mitschnitt des Simulators.

## Was darf sich nicht ändern

- Rückgabewert und Ausgabe der Testläufe (`** TEST SUCCEEDED/FAILED **`, `test-proof`-Beleg, `sim_proof.py`).
- Build-, Mac- und Gerätebefehle (`build`, `mac-build`, `device-build`, `lab` …) bekommen die Option nicht.
- Die CI (`ci.yml`, `speech-stress.yml`) ruft `xcodebuild` direkt auf und bleibt unverändert.
- Unit-Tests laufen nur im Simulator (`sim-unit`), nie mit dem Mac als Testhost.

## Ablauf und Nachweis (automatisiert, nur Simulator)

1. **Vorher reproduzieren:** `./scripts/sim.sh sim-unit` und ein UI-Test auf dem unveränderten Stand;
   mitschreiben: Zeit „Test Succeeded“ im Log, Zeit Prozessende, ob ein `simctl diagnose`-Kind lief.
2. Fix in `run_xcodebuild`.
3. **Nachher:** derselbe Ablauf; Zeit zwischen „Test Succeeded“ und Prozessende < 30 s, kein
   `simctl diagnose`-Kind. Vorher/Nachher-Zahlen als Kommentar ins Ticket.

## Inline-Test (wird während Implementierung geschrieben)

- [ ] `run_xcodebuild test …` ruft `xcodebuild` mit `-collect-test-diagnostics never` auf
- [ ] `run_xcodebuild build …` ruft `xcodebuild` ohne diese Option auf

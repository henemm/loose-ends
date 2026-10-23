Refs #534 (Schnitt 2 von 3, das Ticket bleibt offen). Epic #563.

## Was
- Labor-App: `--result`, `--context-words`, `--exit-when-done`. Eine Messreihe läuft selbstständig durch (alle 12 Aufrufe je Start), danach beendet sich die App.
- `./scripts/sim.sh lab-latency <n>`: n Starts auf dem iPhone, nur Labor-App, holt die Ergebnisse, wertet aus.
- `scripts/latency_summary.py` liest das Labor-Format, trennt kalt/warm, zeigt Maximum je Hitzestufe und Aufrufe je Stromquelle.
- Bericht `docs/reference/modell-latenz.md` um den iPhone-Teil ergänzt, Rohdaten unter `docs/artifacts/534-modell-latenz/iphone/`.

## Ergebnis (iPhone 16 Pro, iOS 27.0.1, 10 Starts, 120 Aufrufe)
- kalt: n 10, Median 4,68 s, Maximum 7,92 s
- warm: n 110, Median 4,83 s, Maximum 6,72 s
- keine Fehler; 112 von 120 Aufrufen bei Hitzestufe „serious“, alle auf Akku
- Verhältnis kalt/warm 1,2 (Schwelle 5): eine Grenze genügt
- Vorschlag nach der Regel: 3 × 7,92 s, aufgerundet **25 s**. Das Produkt bleibt unverändert, die Konstante ändert Schnitt 3 (Stufe 3, TestFlight).

## Nicht in diesem Schnitt
Die Konstante im `EnrichmentCoordinator` (Schnitt 3). Unter `Shared/` und `LooseEnds/` ist nichts geändert.

## Prüfung
Simulator-Unit-Suite: 897 bestanden, 0 fehlgeschlagen; Auswertungs-Tests 9 OK. Adversary in zwei Runden: Er fand vor dem Gerätelauf, dass jeder Start nur 6 statt 12 Aufrufe gemacht hätte (behoben, Test dazu), und die Spec-Abweichung AC-4/AC-8 (Henning akzeptiert).

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_016hdxUS4tHoJnZwog7cypE1

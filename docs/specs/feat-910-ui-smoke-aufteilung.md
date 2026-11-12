---
entity_id: feat-910-ui-smoke-aufteilung
type: feature
created: 2026-11-12
updated: 2026-11-12
status: draft
workflow: ci-910-ui-smoke-laufzeit
---

# Spec: UI-Smoke-Job in vier Teile aufteilen (#910)

## Approval

- [ ] Approved

## GitHub Issue

#910 (Befund aus #905). Analyse: `docs/context/ci-910-ui-smoke-laufzeit.md` (Messung Lauf 43200602690; verbindlich).
Reiner CI-Umbau: **kein App-Code, kein Pfad der Geräteliste.**

## Für den PO

Die automatische Prüfung der App-Bedienung braucht heute fast zwei Stunden, bis ein Ergebnis da ist. Der Grund: 98 Bedienabläufe laufen nacheinander in einem einzigen Simulator, und sie warten fast nur (der Rechner ist nie ausgelastet). Keine einzelne Testklasse ist schuld. Dieser Schnitt verteilt die Abläufe auf vier Simulatoren, die gleichzeitig laufen. Erwartet werden rund 30 Minuten; das Ziel aus dem Ticket sind unter 60.

An der App und an dem, was geprüft wird, ändert sich nichts. Die Prüfung, die GitHub vor jedem Zusammenführen verlangt, heißt weiter „UI Smoke (iOS Simulator)“ und wird rot, sobald auch nur ein Teil rot oder abgebrochen ist.

## Purpose

Der Job `ui-smoke` führt alle Klassen von `LooseEndsUITests` in einem Simulator nacheinander aus (78 min Testzeit + 14 min Bau/Boot). Mehrere Simulatoren im selben Job sind durch #228 widerlegt (Speicherdruck); ein Simulator je Job (Matrix) ist der Weg, den `ui-smoke-lang` schon geht.

Ohne Aufteilung geht es nicht, weil: 98 Tests × 48 s wartedominierte Laufzeit (Runner meist < 50 % CPU) = 78 min; das Kürzen fester Wartezeiten (Alternative B) spart geschätzt 10–15 min und erreicht 60 min nicht.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — #228 („kein Parallelbetrieb im selben Simulator“) bleibt gültig, jeder Teil hat seinen eigenen Runner und Simulator.
- **Rationale:** Aufteilung wird aus dem Code gelesen, nicht als feste Klassenliste geführt; sonst liefe eine neue Testklasse still nie.
- **Alternativen:** (A) 5–6 Teile: ≈ 28 min, aber 12–13 gleichzeitige macOS-Jobs, bisher liefen 7–8 ohne Warteschlange; erst nach Beleg erhöhen (nur die Zahl). (B) Wartezeiten in den Hilfsfunktionen kürzen: eigenes Ticket, ändert Teststabilität. (C) UI-Smoke nur bei App-Änderungen: verworfen, Branch-Schutz verlangt die Prüfung immer.

## Source

| Datei | Änderung |
|---|---|
| `scripts/ui_smoke_shards.py` | neu: liest die `XCTestCase`-Klassen aus `LooseEndsUITests/*.swift` (ohne Unterordner `Watch`), zählt `func test…`, verteilt gierig (schwerstes zuerst) auf N Teile, gibt JSON für die Matrix aus |
| `scripts/test_ui_smoke_shards.py` | neu: Beweis der Aufteilung (siehe ACs) |
| `.github/workflows/ci.yml` | Job `ui-smoke` → Job `ui-smoke-shard` als Matrix (4 Teile, `fail-fast: false`), Vorlauf-Job liest die Aufteilung, Sammel-Job mit dem alten Namen |
| `CLAUDE.md` | Abschnitt CI: Job als 4er-Matrix mit Sammel-Prüfung beschreiben |

**Aufteilung:** Gewicht einer Klasse = Zahl ihrer `func test…`. Die zwei Foto-Klassen `DesignGalleryTests` und `StoreScreenshotsTests` (je 1 Test, 155–183 s) bekommen festes Gewicht 4, damit sie nicht im selben Teil liegen. Mac-Klassen (laufen auf iOS nur als übersprungen) haben Gewicht 0 und liegen im leichtesten Teil. Gleichstand wird nach Klassenname entschieden (deterministisch). Je Teil `-only-testing:LooseEndsUITests/<Klasse>` für jede Klasse des Teils.

**Sammel-Job:** `name: UI Smoke (iOS Simulator)`, `needs: [ui-smoke-shard]`, `if: always()`, ein Schritt, der mit `exit 1` endet, wenn `needs.ui-smoke-shard.result` nicht `success` ist (übersprungen und abgebrochen zählen als rot).

**Je Teil:** Aufbau über die vorhandene Composite-Action `prepare-ui-simulator` statt der Inline-Schritte, Zeitgrenzen enger (Job 60, Testschritt 45 min), Artefakte `UITestResults-<n>` und `DesignGallery-<n>`; der Galerie-Export toleriert „keine Bilder“.

## Acceptance Criteria

- **AC-1:** `ui_smoke_shards.py` ordnet jede `XCTestCase`-Klasse aus `LooseEndsUITests/` (ohne `Watch/`) genau einem Teil zu; keine Klasse fehlt, keine liegt doppelt (Test liest die Klassen unabhängig per Regex und vergleicht).
- **AC-2:** Bei N = 4 ist kein Teil leer, und `DesignGalleryTests` und `StoreScreenshotsTests` liegen in verschiedenen Teilen.
- **AC-3:** Die Aufteilung ist deterministisch (zweimal aufgerufen, gleiche Ausgabe), und eine neu angelegte Testklasse in einem temporären Verzeichnis wird automatisch einem Teil zugeordnet.
- **AC-4:** Das Gewicht des schwersten Teils übersteigt den Durchschnitt höchstens um das größte Einzelgewicht (Güte der gierigen Verteilung, geprüft am echten Verzeichnis).
- **AC-5:** In `ci.yml` heißt genau ein Job `UI Smoke (iOS Simulator)`, es ist der Sammel-Job mit `if: always()` und `needs: [ui-smoke-shard]`; der Test liest die YAML und prüft das.
## Definition of Done

Die Skript-Tests sind grün (AC-1 bis AC-5); `CLAUDE.md` beschreibt die neue Aufteilung. Dazu drei Belege aus dem echten CI-Lauf auf dem PR (Phase 7, bewusst keine ACs, weil das QA-Gate in Phase 6 keinen Aufschub kennt); die Zahlen stehen im PR und im Issue #910:

- **Beleg A (Laufzeit):** alle vier Teile grün, jeder Teil unter 45 min, die Gesamtzeit der Prüfung „UI Smoke (iOS Simulator)“ unter 60 min.
- **Beleg B (rote Probe vor dem Merge):** ein absichtlich roter Teil (Testzweig oder `workflow_dispatch`) macht „UI Smoke (iOS Simulator)“ rot; ein abgebrochener Teil ebenso.
- **Beleg C (Berichtsdaten):** `UITestResults-<n>` je Teil und `DesignGallery-<n>` bleiben erhalten (der Teil mit `DesignGalleryTests` ist nicht leer).

## Test Plan

- `scripts/test_ui_smoke_shards.py` (Python `unittest`, läuft im CI-Schritt der Skriptprüfungen mit): AC-1 bis AC-5.
- Belege A bis C: echter CI-Lauf auf dem PR und die rote Probe; Auswertung der Laufzeiten per `gh run view`.

## Changelog

- 2026-11-12: AC-6 bis AC-8 aus den Acceptance Criteria in die Definition of Done verschoben (Belege A bis C), weil sie erst auf dem PR belegbar sind und das QA-Gate in Phase 6 sonst blockiert.

## Scope

4 Dateien, ≈ +170/−60 LoC. Risiko mittel: Der Name der Sammel-Prüfung steht im Branch-Schutz; ein Fehler dort blockiert jeden PR oder lässt rote Teile durch (deshalb AC-5 und AC-7).

## Abnahme

Stufe 1–2 = Tests und echter CI-Lauf auf dem PR. „Kein Pfad der Geräteliste berührt.“

## Offene Fragen

Keine für den PO. Teilzahl 4 ist der Startwert; eine Erhöhung folgt nur nach Messung.

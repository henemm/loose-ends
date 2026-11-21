---
entity_id: fix-939-ci-ui-smoke-zeitbudget
type: bugfix
created: 2026-11-20
updated: 2026-11-20
status: draft
workflow: fix-939-ci-simulator
---

# Spec: UI-Smoke-Teile beim ersten Versuch grün, Schnitt 1 (#939)

## Approval

- [ ] Approved

## GitHub Issue

#939. Analyse: `docs/context/fix-939-ci-simulator.md` (Abschnitte „Klassifikation“ und „Analysis“, verbindlich), Rohdaten
`docs/artifacts/fix-939-ci-simulator/klassifikation.md`. Reiner CI-Umbau: **kein App-Code, kein Pfad der Geräteliste.**

## Für den PO

Die automatische Prüfung der App-Bedienung scheitert bei fast jedem Änderungsvorschlag erst beim zweiten oder dritten Versuch. Der häufigste Grund (43 von 94 roten Läufen): Ein Prüfteil bekommt zu wenig Zeit. Er muss zuerst die App bauen (10 bis 22 Minuten) und dann seine Abläufe durchspielen, und beides zusammen sprengt das Zeitlimit von 45 Minuten, obwohl alle Abläufe noch grün laufen. Besonders trifft es Teil 1, weil eine einzelne große Testgruppe (29 Abläufe) dort fast alles belegt.

Dieser Schnitt verteilt die Abläufe feiner auf sechs gleichzeitige Teile (jeder trägt rund 21 Abläufe statt bis zu 31), erhöht das Zeitlimit maßvoll und sorgt dafür, dass ein Fehler beim Hochladen der Berichtsdaten einen grünen Teil nicht mehr rot färbt. An der App und an dem, was geprüft wird, ändert sich nichts. Die Prüfung, die GitHub vor jedem Zusammenführen verlangt, heißt weiter „UI Smoke (iOS Simulator)“.

## Purpose

Der Schritt „Run UI smoke tests“ jedes Teils enthält Bau und Tests (`xcodebuild test`), beides zählt gegen das 45-min-Limit. Gemessen: Bau im Schritt Median 14,3 min (7,6 bis 21,6), Tests bei grünen Teilen Median 24,7 min. Reserve nur etwa 7 min; ein langsamer Runner kippt den Teil. Teil 1 besteht fast nur aus `CaptureSmokeTests` (29 Tests), die die Aufteilung nach Klassen nicht zerlegen kann: auch mit 5 oder 6 Teilen bliebe der größte Teil bei 29 Tests. Drei weitere rote Teile entstanden nur durch einen fehlgeschlagenen Artefakt-Upload (ENOTFOUND/404) nach grünen Tests.

Ohne feinere Aufteilung geht es nicht, weil: die größte Klasse allein (29 Tests ≈ 25 min bei grünem, ≈ 44 min bei schlechtem Runner, plus Bau) das Limit ausfüllt (Beleg: 43 Fehlschläge am Schrittlimit, 23 davon Teil 1, Lauf 44705007016: Bau 21,6 min, 13 Tests grün, dann Abbruch).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Es ändert sich nur die Verteilung der Tests auf die bestehende Matrix und deren Zeitgrenzen; #228 („kein Parallelbetrieb im selben Simulator“) und #910 (Aufteilung aus dem Code lesen, Sammel-Check mit geschütztem Namen) bleiben unverändert gültig.
- **Alternativen:**
  - (A) Sofort einmal bauen (`build-for-testing`, Produkte und `.xctestrun` weiterreichen, je Teil `test-without-building`): entfernt den Bau aus den Teilen, löst aber Teil 1 allein nicht (31 Tests bleiben) und braucht einen seriellen Bau-Job davor (Gesamtdauer ≈ 58 min) sowie eine gemessene Artefaktgröße. Bleibt Schnitt 2, falls Schnitt 1 nicht reicht.
  - (C) Nur Limits höher (65/80): maskiert das Problem und verlängert echte Hänger; kein Ursachenfix.
  - (B8) Acht Teile: Laufzeit ≈ 25 min, aber acht gleichzeitige macOS-Runner (Warteschlangenrisiko, andere Sitzungen laufen parallel).

## Source

| Datei | Änderung |
|---|---|
| `scripts/ui_smoke_shards.py` (`weights()`, `split()`, `matrix()`, neu: Methodenliste je Klasse und Einheitenbildung) | Klassen, deren Gewicht über der Zielgröße (Gesamtgewicht / N, aufgerundet) liegt, werden auf Methodenebene zerlegt; Ausgabe je Teil mit Einträgen `LooseEndsUITests/<Klasse>` oder `LooseEndsUITests/<Klasse>/<test>` |
| `scripts/test_ui_smoke_shards.py` | Tests der Zerlegung (siehe ACs), N = 6 |
| `.github/workflows/ci.yml` (Jobs `ui-smoke-plan`, `ui-smoke-shard`) | `ui_smoke_shards.py 6`; Testschritt 45 → 55 min, Job 60 → 70 min; `continue-on-error: true` an den zwei Upload-Schritten der Teile |

**Methodenerkennung:** Das Skript zählt heute schon `func test…(` je Klasse mit dem Muster `TEST` (zwischen dem Klassenkopf und dem nächsten Klassenkopf derselben Datei). Die Zerlegung benutzt dasselbe Muster mit Namensgruppe, damit Zählung und Namensliste nie auseinanderlaufen. Methodennamen werden in Dateireihenfolge gelesen und für die Verteilung alphabetisch sortiert (deterministisch).

**Zerlegung:** Zielgröße = aufgerundet (Gesamtgewicht / N). Eine Klasse mit Gewicht über der Zielgröße, die nicht in `FIXED` steht (Foto-Klassen) und nicht Gewicht 0 hat (Mac-Klassen, Basisklassen), wird in Einheiten `<Klasse>/<test>` mit Gewicht 1 zerlegt; alle anderen Klassen bleiben eine Einheit mit ihrem Gewicht. Danach dieselbe gierige Verteilung wie bisher (schwerste Einheit zuerst in den leichtesten Teil, Gleichstand nach Name, die zwei Foto-Klassen nie im selben Teil, solange es einen Teil ohne Foto-Klasse gibt). Eine Klasse erscheint nie ganz und zerlegt zugleich. Ein Teil darf Einheiten derselben zerlegten Klasse enthalten.

**Ausgabeformat** (JSON für die Matrix, unverändert in den Feldnamen): `shard`, `classes` (Klassennamen des Teils, für das Log), `only` (`-only-testing:…`-Argumente, durch Leerzeichen getrennt). Ein Teil ohne Eintrag in `only` bleibt ein Fehler (leeres `$ONLY` würde das ganze Target laufen lassen). Der Aufruf in `ci.yml` bleibt `$ONLY` unquotiert.

**Zeitbudget** (Hochrechnung aus den Messwerten, grün ≈ 52 s/Test, Bau 11 min; schlechter Runner ≈ 90 s/Test, Bau 14 min): größter Teil ≈ 21 Tests, grün ≈ 29 min, schlechter Runner ≈ 46 min, Limit 55 min lässt Luft. Jobgrenze 70 min, damit nach einem Testschritt am Limit Diagnose und Upload noch laufen.

**Uploads:** `continue-on-error: true` an „Upload design gallery“ und „Upload UI test results“ der Teile. Der Test-Schritt bleibt maßgeblich; die Berichtsdaten sind Beiwerk. Der Sammel-Job `UI Smoke (iOS Simulator)` (`needs: [ui-smoke-shard]`, `if: always()`) und der Matrixname bleiben unverändert.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `LooseEndsUITests/*.swift` (ohne `Watch/`) | Eingabe | Klassen und `func test…` werden aus dem Code gelesen |
| `.github/workflows/ci.yml` Jobs `ui-smoke-plan`, `ui-smoke-shard`, `ui-smoke` | CI | Matrix-Erzeugung, Teile, Sammel-Check mit geschütztem Namen |
| Runner-Label `xcode-27`, Xcode 27.0, iPhone 17 / iOS 27.0 | Plattform | unverändert; sechs statt vier gleichzeitige macOS-Runner |
| Branch-Schutz auf `main` | GitHub | verlangt „UI Smoke (iOS Simulator)“, Name unverändert |
| `scripts/test_ui_smoke_shards.py` | Test | läuft im CI-Schritt der Skriptprüfungen mit |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/ui_smoke_shards.py` | MODIFY | Methoden-Zerlegung übergroßer Klassen, Einheiten `Klasse/test` |
| `scripts/test_ui_smoke_shards.py` | MODIFY | neue Tests, bestehende von N = 4 auf Schnittstelle mit Einheiten anpassen |
| `.github/workflows/ci.yml` | MODIFY | 6 Teile, Limits 55/70 min, Uploads tolerant |
| `CLAUDE.md` | MODIFY | CI-Absatz: „matrix of four parts“ → sechs Teile, Methoden-Zerlegung übergroßer Klassen, Limits 55/70 min |

### Estimated Changes

- Files: 4
- LoC: +105/−12 (Skript ≈ 40, Tests ≈ 40, YAML ≈ 15, CLAUDE.md ≈ 5), kein App-Code

## Out of Scope

- **Schnitt 2 (A):** einmal bauen, `build-for-testing` plus `test-without-building`. Nur, wenn b1 (Schrittlimit) nach Schnitt 1 in 3 bis 5 Läufen noch auftritt; vorher Artefaktgröße messen.
- Wacklige Einzeltests (`testDefaultCalendarIsStampedOnSwitchOn`, #882, `testDeleteCancelKeepsSignedIn`, Mac Gallery `testSubtaskOpensItsOwnDetailAndLeadsBack`): eigenes Ticket mit eigener Ursache, nicht gebündelt.
- Runner-seitige Fehler: Simulator-Laufzeit verloren (Image-Ereignis 2026-11-16), UI-Abfrage hängt, „Restarting after unexpected exit“: kein Fix in Reichweite.
- `ui-smoke-lang`, `ui-ipad`, `mac-gallery`: unverändert.

## Implementation Details

Die Kernlogik steht in `weights()` und `split()` in `scripts/ui_smoke_shards.py`. `weights()` bleibt Klasse → Gewicht (Mac-Klassen 0, Foto-Klassen fest 4). Neu kommt eine Funktion, die zu jeder Klasse die Methodennamen liefert, und eine Ebene darüber, die Einheiten bildet; `split()` und `matrix()` arbeiten auf Einheiten. `matrix()` schreibt je Einheit `-only-testing:LooseEndsUITests/<Klasse>` bzw. `…/<Klasse>/<test>`; die Klassenliste `classes` nennt jede betroffene Klasse einmal. Wichtig: Eine Klasse mit Gewicht 0 steht weiter nie in `only`.

## Test Plan

### Automated Tests (TDD RED)

- [ ] Test 1: GIVEN das echte Verzeichnis `LooseEndsUITests` und N = 6 WHEN die Teile gebildet werden THEN kommt jede Testmethode (unabhängig per Regex gezählt, Klassen mit Gewicht > 0 außer den Foto-Klassen und Mac-Klassen) in genau einem Teil vor, entweder über ihre ganze Klasse oder als `Klasse/test`.
- [ ] Test 2: GIVEN die Teile für N = 6 WHEN man die Einträge je Klasse prüft THEN steht keine Klasse sowohl ganz als auch zerlegt in den Teilen.
- [ ] Test 3: GIVEN die Teile für N = 6 WHEN man das Gewicht je Teil summiert THEN liegt keines über Zielgröße plus größtem Einzelgewicht einer unzerlegten Einheit.
- [ ] Test 4: GIVEN `DesignGalleryTests` und `StoreScreenshotsTests` WHEN N = 6 THEN liegen sie in verschiedenen Teilen.
- [ ] Test 5: GIVEN beliebige Eingaben (echtes Verzeichnis und temporäres mit einer Klasse über der Zielgröße und einer Mac-Klasse) WHEN `matrix()` läuft THEN ist `only` in keinem Teil leer, und eine Gewicht-0-Klasse steht in keinem `-only-testing`.
- [ ] Test 6: GIVEN dasselbe Verzeichnis WHEN die Aufteilung zweimal berechnet wird THEN ist die Ausgabe gleich.
- [ ] Test 7: GIVEN der Aufruf `python3 scripts/ui_smoke_shards.py 6` WHEN er läuft THEN enthält das JSON sechs Teile mit `shard`, `classes` und `only`.
- [ ] Test 8: GIVEN die bestehenden Tests #910-AC-1 bis #910-AC-5 (`docs/specs/feat-910-ui-smoke-aufteilung.md`) WHEN das Skript zerlegt THEN bleiben sie grün (Anpassung an die Einheiten-Schnittstelle erlaubt, Inhalt unverändert).

Lauf: `python3 scripts/test_ui_smoke_shards.py` (Python `unittest`, läuft auch im CI-Schritt der Skriptprüfungen).

## Acceptance Criteria

- **AC-1:** Bei N = 6 kommt jede Testmethode der Klassen aus `LooseEndsUITests/` (ohne `Watch/`, Gewicht > 0) genau einmal in den Teilen vor; keine Klasse steht ganz und zerlegt zugleich (Test liest Klassen und Methoden unabhängig per Regex und vergleicht).
- **AC-2:** Bei N = 6 ist kein Teil leer, `only` ist in keinem Teil leer, keine Gewicht-0-Klasse steht in `only`, und `DesignGalleryTests` und `StoreScreenshotsTests` liegen in verschiedenen Teilen.
- **AC-3:** Kein Teil wiegt mehr als die Zielgröße (Gesamtgewicht / N, aufgerundet) plus das größte Einzelgewicht einer unzerlegten Einheit; die Planausgabe für N = 6 am echten Verzeichnis hält diese Grenze (Hochrechnung der Analyse: größter Teil rund 21 Tests), und der größte Teil liegt unter den 31 Tests von heute.
- **AC-4:** Die Aufteilung ist deterministisch (zweimal berechnet, gleiche Ausgabe), und eine neue Testklasse in einem temporären Verzeichnis wird automatisch einem Teil zugeordnet.
- **AC-5:** `ci.yml` ruft `ui_smoke_shards.py 6` auf, der Schritt „Run UI smoke tests“ hat `timeout-minutes: 55`, der Job `ui-smoke-shard` 70, die Schritte „Upload design gallery“ und „Upload UI test results“ haben `continue-on-error: true`, und genau ein Job heißt `UI Smoke (iOS Simulator)` mit `if: always()` und `needs: [ui-smoke-shard]` (Test liest die YAML).

## Definition of Done

- [ ] Skripttests grün (AC-1 bis AC-5).
- [ ] `CLAUDE.md`-CI-Absatz auf sechs Teile, Methoden-Zerlegung und Limits 55/70 min angepasst.

Belege aus dem echten CI-Lauf auf dem PR (Phase 7, bewusst keine ACs, weil das QA-Gate in Phase 6 keinen Aufschub kennt); die Zahlen stehen im PR und in #939:

- [ ] **Beleg A (erster Versuch):** Im CI-Lauf des PR sind alle sechs Teile beim ersten Versuch grün und der Sammel-Check „UI Smoke (iOS Simulator)“ grün.
- [ ] **Beleg B (Wiederholung):** drei aufeinanderfolgende CI-Läufe (per „Re-run all jobs“ auf demselben Stand) ohne Schrittlimit-Abbruch in einem UI-Smoke-Teil; Testschrittdauer je Teil und Bauzeit stehen im Beleg.
- [ ] **Beleg C (Berichtsdaten):** `UITestResults-<n>` je Teil und `DesignGallery-<n>` bleiben erhalten (der Teil mit `DesignGalleryTests` ist nicht leer); ein Upload-Fehler färbt den Teil nicht rot.

Kein App-Code und kein Pfad der Geräteliste berührt (`ci.yml` und `scripts/` stehen nicht in der Geräteliste der CLAUDE.md). Der CI-Absatz in der `CLAUDE.md` („matrix of four parts“) wird im selben Schnitt auf sechs Teile, die Methoden-Zerlegung und die Limits 55/70 min angepasst.

## Abnahme

Stufe 1 (Skripttests) und der echte CI-Lauf auf dem PR. „Kein Pfad der Geräteliste berührt.“

## Risiken

- Sechs statt vier gleichzeitige macOS-Runner: mögliche Warteschlange bei parallelen Sitzungen. Beobachtung im Beleg A; bei Stau Teilzahl prüfen (nur die Zahl).
- Zerlegte Klasse auf mehreren Simulatoren: geprüft, `CaptureSmokeTests` hat keine geteilten statischen Zustände; jeder Teil startet die App frisch.
- Der Name der Sammel-Prüfung steht im Branch-Schutz; AC-5 sichert ihn.
- Schnitt 1 löst Hänger und Runner-Verluste nicht (siehe Out of Scope); der Beleg kann deshalb an diesen scheitern und wird dann als eigene Klasse benannt, nicht als Misserfolg des Schnitts.

## Offene Fragen

Keine für den PO.

## Changelog

- 2026-11-20: Initial spec created

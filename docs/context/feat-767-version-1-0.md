# Context: feat-767-version-1-0

## Request Summary
In App Store Connect wartet die App-Store-Version 1.0 auf einen Build. Alle Builds tragen 0.1.0, daher ist keiner auswählbar. Ein neuer Build mit Version 1.0 muss hochgeladen werden (Henning, 2026-10-30; Frage „vielleicht 1.1?“ → nein, siehe Risiken).

## Related Files
| File | Relevance |
|------|-----------|
| `project.yml:24` | `MARKETING_VERSION: "0.1.0"` — einzige Quelle; alle Ziele (App, Watch, Widgets, Watch-Widgets, Share, Labor) lesen `$(MARKETING_VERSION)` |
| `.github/workflows/testflight.yml:148` | iOS-Archivprüfung: `MARKETING="0.1.0"` fest eingetragen, vergleicht jede Bundle-Version mit `$MARKETING ($BUILD)` |
| `.github/workflows/testflight.yml:423` | macOS-Archivprüfung: dasselbe fest eingetragen |
| `.github/workflows/testflight.yml:6` | Kommentar „tag like v0.1.0“ |
| `docs/reference/testflight.md:288,292` | beschreibt Quelle und erwartete Version `0.1.0 (<Lauf-Nummer>)` |
| `Shared/Services/AppVersion.swift`, `LooseEndsTests/AppVersionTests.swift` | zeigen die Version nur an; Tests mit festem Beispielwert, unberührt |

## Existing Patterns
- Buildnummer = `github.run_number`, Version aus `project.yml`; die Archivprüfung dupliziert die Version als Literal (Doppelpflege, genau die Falle bei einem Versionswechsel).
- `scripts/test_info_plist_sync.py` vergleicht Info.plist-Abbild mit `project.yml`; dort steht die Version als Variable, kein Diff.

## Dependencies
- Upstream: Apple-Regel — ein Build lässt sich einer App-Store-Version nur zuordnen, wenn `CFBundleShortVersionString` gleich ist; Erweiterungen tragen dieselbe Version wie die App (Apple-Forum 730234).
- Downstream: TestFlight-Lauf (iOS + macOS), App-Store-Einreichung, Versionsanzeige in den Einstellungen.

## Existing Specs
- keine zur Versionsnummer.

## Risks & Considerations
- 1.0 statt 1.1: keine veröffentlichte 1.0; die vorbereitete App-Store-Version heißt 1.0; 1.0 > 0.1.0, also zulässig. 1.1 passte nicht zur vorbereiteten Version.
- Schreibweise exakt „1.0“ wie in App Store Connect.
- Buildnummer läuft weiter (Lauf-Nummer > 125), kein Konflikt.
- In TestFlight gibt es bereits „Version 1.0, Build 1“, Status „Abgelaufen“ (Screenshot Henning, 2026-10-30; ein früher Upload vor dem Wechsel auf 0.1.0). Kein Hindernis: Innerhalb einer Version muss nur die Buildnummer neu und höher sein (Lauf-Nummer > 1); ein abgelaufener Build ist für die Einreichung ohnehin nicht wählbar. Deshalb kein Grund für 1.1.
- Externe TestFlight-Tester: der neue Versionszug 1.0 braucht bei Apple vermutlich erneut eine Beta-Prüfung, bevor er extern verteilt wird (bisher Build 125 unter 0.1.0 freigegeben).
- Literal in `testflight.yml` vergessen → Archivprüfung stoppt den Upload. Besser die Version dort aus `project.yml` lesen.
- `project.yml` steht auf der Geräteliste (Stufe 3) — Prüfung über TestFlight (Build zeigt „1.0 (N)“).

## Analysis

### Type
Feature (Auslieferungs-Konfiguration)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `project.yml` | MODIFY | `MARKETING_VERSION: "0.1.0"` → `"1.0"` |
| `.github/workflows/testflight.yml` | MODIFY | beide Archivprüfungen (iOS Z. 148, macOS Z. 423) lesen `MARKETING` aus `project.yml` statt Literal; Kommentar Z. 6 `v0.1.0` → `v1.0` |
| `scripts/test_marketing_version.py` | CREATE | Version ist 1.0; kein Versions-Literal in `testflight.yml`; Auslese-Befehl liefert in bash genau den Wert aus `project.yml` |
| `docs/reference/testflight.md` | MODIFY | Z. 292 erwartete Version `1.0 (<Lauf-Nummer>)`, Hinweis: Archivprüfung liest `project.yml` |

### Scope Assessment
- Files: 4
- Estimated LoC: +45/-5
- Risk Level: MEDIUM (Upload-Weg; Fehler zeigt sich spätestens in der Archivprüfung, nicht beim Nutzer)

### Technical Approach
Eine Quelle für die Version: `project.yml`. In beiden Prüf-Schritten
`MARKETING=$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"$/\1/p' project.yml)` plus Abbruch, wenn leer.
Beide Jobs (`upload`, `upload-mac`) checken das Repo aus, Arbeitsordner ist die Wurzel; lokal (`ARCHIVE=… BUILD=…`) ebenso aus der Wurzel.
Danach TestFlight-Lauf (manuell, `what_to_test` auf Deutsch) → Build `1.0 (N)` für iOS und macOS.
Bestehende Tests über `testflight.yml` (`test_asc_wait_build.py`: bash -n je Block, Tabelle per tee) bleiben gültig.
Skripttests laufen in der CI über `unittest discover -s scripts`.

Alternative: Version nur in `project.yml` ändern und die beiden Literale mitziehen (3 Zeilen). Verworfen: Die Doppelpflege ist genau die Falle, die beim nächsten Versionssprung (1.0.1, 1.1) wieder zuschlägt.
Alternative 2: `agvtool`/`xcodebuild -showBuildSettings` im Prüfschritt. Verworfen: langsamer, braucht erzeugtes Projekt; `project.yml` ist die Quelle.

### Dependencies
Apple: Build-Version muss der App-Store-Version gleichen (1.0); Buildnummer neu je Version (Lauf-Nummer). Externe Tester: neuer Versionszug braucht ggf. neue Beta-Prüfung (Einreichung nur auf Hennings Wort).

### Open Questions
- keine

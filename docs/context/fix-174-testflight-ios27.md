# Context: fix-174-testflight-ios27

## Request Summary
Issue #174: Ein TestFlight-Build mit dem heutigen Stand, der dieselben Fähigkeiten hat wie die
Xcode-Fassung auf iOS 27, über einen wiederholbaren Weg (CI oder lokal), dokumentiert in
`docs/reference/testflight.md`.

## Befunde (2026-10-03, mit Beleg)

| Befund | Beleg |
|---|---|
| Letzter TestFlight-Lauf 2026-09-19, seither keiner | `gh run list --workflow testflight.yml`: 35434941080 (09-19), 35397291276, 35380563881 — alle grün |
| Das Standard-Image `macos-26` hat **heute noch kein Xcode 27** | CI-Lauf 37108095080 (2026-10-03), Image `macos-26-arm64` 20260907.0351.1: „No Xcode 27 on this image: deployment targets lowered to 26.0", `Xcode 26.6 / 17F113` |
| Xcode 27 gibt es als **eigenes Image** mit eigenem Label `xcode-27-arm64`, Status „public preview" | [runner-images xcode-27-arm64/20260805.0079](https://newreleases.io/project/github/actions/runner-images/release/xcode-27-arm64%2F20260805.0079), [xcode-27/20260728.0060](https://newreleases.io/project/github/actions/runner-images/release/xcode-27%2F20260728.0060). Darin zuletzt Beta-Builds (27A5218g, 27A5228h) — welche Version das Image heute trägt, ist offen |
| Hennings Mac hat **Xcode 27.0, Build 27A266a** (kein Beta-Suffix) als einziges Xcode | `xcodebuild -version`, `ls /Applications/Xcode*.app` |
| Im Code gibt es **keine einzige** `#available(iOS 27…)`-Abschirmung | `grep -rn "available(.*27"` über alle Produkt-Ziele: 0 Treffer; einzige Abschirmung `FoundationModelsEnricher.swift:1` `#if canImport(FoundationModels) && !os(watchOS)` |
| Kein `PrivacyInfo.xcprivacy` im Repo | `find . -name PrivacyInfo.xcprivacy`: 0 Treffer |
| Required-Reason-API-Kandidaten (`UserDefaults`/`@AppStorage`) in 3 Dateien | `LooseEnds/Calendar/CalendarBridge.swift`, `LooseEnds/Speech/SpeechCapture.swift`, `Shared/Persistence/ContextSeeder.swift` |

**Folge für die Prämisse des Issues:** „iOS-27-Pfade hinter `#available`" fehlen im Build nicht, weil
es keine gibt. Der Unterschied einer 26.0-Fassung liegt woanders: gebaut gegen das **iOS-26.6-SDK**
(FoundationModels-, SwiftData-, SwiftUI-Verhalten nach SDK-Version, „linked-on-or-after"), mit
Deployment-Ziel 26.0. Was das konkret am Verhalten ändert, klärt `/20-analyse` — nicht geraten.

## Related Files
| File | Relevance |
|------|-----------|
| `.github/workflows/testflight.yml` | Archiv + Upload; Zeilen 38–47 senken ohne Xcode 27 auf 26.0; `runs-on: macos-26`; Build-Nummer = `github.run_number` (Z. 75) |
| `.github/workflows/ci.yml` | Gleiche Absenkungslogik in drei Jobs (Z. 12–30, 64–76, 94–106) — **nicht** Teil dieses Tickets, aber gleiche Ursache |
| `project.yml` | Deployment-Ziele 27.0 (Z. 6–9), `MARKETING_VERSION 0.1.0`, `CURRENT_PROJECT_VERSION 1`, `BUNDLE_ID_SUFFIX ""`, Ziele LooseEnds/Watch/Widgets/Share (+Lab, Tests), Datenschutztexte Z. 80–82, 120–121, `ITSAppUsesNonExemptEncryption: false` Z. 74. **Steht auf der Geräteliste.** |
| `LooseEnds*/**.entitlements`, `LooseEnds*/Info.plist` | Generiert/gepflegt über project.yml; Geräteliste |
| `docs/reference/testflight.md` | Einrichtung + „Was der Workflow tut"; DoD verlangt Aktualisierung |
| `scripts/sim.sh` | `device-build`/`lab` signieren mit lokalen Profilen ohne Apple-Kontakt (#156); Vorlage für einen möglichen lokalen Archiv-Weg |

## Existing Patterns
- Xcode-Wahl per `ls -d /Applications/Xcode_27*.app` + `sed` auf project.yml (CI und TestFlight identisch).
- Signierung in CI: Cloud-managed, `-allowProvisioningUpdates` + ASC-API-Schlüssel (Admin-Rolle nötig).
- Lokale Gerätebauten (#156) sprechen bewusst **nicht** mit Apple, damit Hennings Xcode-Anmeldung
  nicht verloren geht (Memory `loose-ends-xcode-ohne-konto`). Ein lokaler Archiv-Weg müsste
  denselben Grundsatz halten: nur eigener ASC-Schlüssel, nie die Xcode-Anmeldung.
- Workflow-Skripte gehen über `scripts/sim.sh`, nicht direkt über `xcodebuild` (Projekt-CLAUDE.md).

## Dependencies
- Upstream: GitHub-Runner-Images, App Store Connect API (4 Secrets gesetzt), Apples Annahmeregeln
  für Uploads (SDK-/Xcode-Version, Privacy-Manifest), XcodeGen.
- Downstream: Hennings TestFlight-Installation (interne Gruppe „Familie"); `docs/project/04-stand.md`.

## Existing Specs
- Keine Spec zu TestFlight unter `docs/specs/`. Bezüge: #156 (Prüfbau-Kennung), #145 (Simulator-Beleg).

## Risks & Considerations
- **Beta-Xcode und TestFlight:** Ob App Store Connect Uploads aus einer Xcode-27-Vorschau annimmt,
  ist offen → Recherche in `/20-analyse` (Apple-Regel zu Beta-SDKs).
- **Build-Nummer:** CI nutzt `github.run_number`; ein lokaler Weg muss darüber liegen, sonst lehnt
  ASC den Upload als Dublette ab.
- **Privacy-Manifest:** Ob Apple es für `UserDefaults` (Reason `CA92.1`) beim Upload verlangt
  (ITMS-91053), ist zu recherchieren.
- **Geräteliste:** Berührt der Schnitt `project.yml`/Entitlements/Info.plist (Privacy-Manifest als
  Ressource), läuft Stufe 3 (`device-status`).
- **Hennings Xcode-Anmeldung** darf durch einen lokalen Archiv-Lauf nicht verloren gehen (#156).
- **Upload ist nach außen wirkend:** Ein TestFlight-Upload landet bei Henning auf dem Gerät; der
  Lauf selbst ist Teil der DoD, aber erst nach freigegebener Spec.
- Alternative zum Ticket-Weg (Pflicht laut Henning): lokaler Archiv-Weg auf Hennings Mac mit Xcode
  27.0 final statt Preview-Image in CI; oder CI-Absenkung belassen und nur prüfen, ob der Unterschied
  überhaupt verhaltensrelevant ist (es gibt keine `#available`-Pfade).

## Analysis

### Type
Feature (Auslieferungsweg). Kein Produktcode.

### Recherche (2026-10-03, mit Quellen)

| Frage | Ergebnis | Quelle |
|---|---|---|
| Hat `macos-26` Xcode 27? | Nein: Xcode 26.0.1 bis 26.6, Standard 26.6. Xcode 27 gibt es nur als eigenes Image | runner-images README, Zeilen 30–32 |
| Label des Xcode-27-Images | **`xcode-27`** (oder `xcode-27-xlarge`), Status Vorschau. Basis seit 2026-09-16 macOS 27 | runner-images Issue #14404; README Z. 30 |
| Xcode-Versionen im Image (Readme auf `main`, Stand 20260928) | `Xcode_27.app` = **27.0, 27A266a, Standard** (Symlinks `Xcode_27.0.app`, `Xcode.app`); `Xcode_27.1_beta.app` 27A9269 (Symlink `Xcode_27.1.app`); `Xcode_27.2_beta.app` 27B5019j (Symlink `Xcode_27.2.app`). SDKs iOS 27.0, watchOS 27.0. Simulatoren iOS 27.0 / watchOS 27.0. xcbeautify ja, xcodegen nicht gelistet | `images/macos/xcode-27-arm64-Readme.md` |
| Gleiche Version wie bei Henning? | Ja: 27A266a auf beiden | `xcodebuild -version` lokal |
| Nimmt App Store Connect Xcode-27-Builds an? | Ja, finales Xcode 27 seit **2026-09-14** für App Store und TestFlight (RC seit 09-09, 27.2 beta 2 seit 09-28 nur TestFlight) | App Store Connect Release Notes (developer.apple.com/help/app-store-connect/release-notes) |
| Was ändert das Linken gegen das iOS-27-SDK? | Startbildschirm Pflicht (vorhanden: `UILaunchScreen: {}`, project.yml Z. 69/202). Scene-Lebenszyklus Pflicht (SwiftUI-`App`, erfüllt). Läuft bei Henning aus Xcode 27 bereits | blakecrosley.com/blog/xcode-27-release |
| Privacy-Manifest Pflicht für TestFlight? | Nein. ITMS-91053 kommt bei TestFlight als Warnmail, Pflicht ist es erst bei der App-Store-Prüfung. Gegenprobe: Stand c2356d1 (09-19) enthielt dieselben drei `UserDefaults`-Stellen, der Upload ging durch. Eine Warnmail liegt im Postfach nicht vor (Gmail-Suche ab 09-01: keine Treffer, möglicherweise anderes Postfach) | Apple-Foren 750057, 748355; `git grep UserDefaults c2356d1` |

**Neuer Befund, der den Ticket-Weg verändert:** Die bestehende Auswahl
`ls -d /Applications/Xcode_27*.app | sort -V | tail -1` würde auf dem Xcode-27-Image die **27.2-Beta**
nehmen und nicht 27.0. Ein bloßer Wechsel des Labels reicht also nicht, Xcode muss fest gewählt werden.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `.github/workflows/testflight.yml` | MODIFY | `runs-on: xcode-27`; Auswahl fest auf `/Applications/Xcode_27.app` und prüfen, dass `xcodebuild -version` „Xcode 27.0" meldet, sonst Abbruch; `sed`-Absenkung entfernen; neuer Schritt **vor dem Upload**: `plutil` liest aus dem Archiv `DTSDKName` (muss `iphoneos27.` bzw. `watchos27.` sein) und `MinimumOSVersion` (muss `27.0` sein) für App, Watch, Widgets und Teilen, schreibt sie in `$GITHUB_STEP_SUMMARY` und bricht bei Abweichung ab |
| `docs/reference/testflight.md` | MODIFY | Runner-Label, fest gewählte Xcode-Version, Nachweisschritt, Vorgehen bei Wegfall des Vorschau-Labels, lokaler Notweg als Alternative |

### Scope Assessment
- Files: 2
- Estimated LoC: +50 / −10
- Risk Level: LOW für das Produkt (kein App-Code). MEDIUM für den Lauf: das Image ist eine Vorschau (Wartezeiten, Label kann sich ändern)
- Geräteliste: kein Pfad berührt (`.github/`, `docs/`). Die Abnahme endet nach den Stufen Tests und CI-Lauf. Das Feature selbst ist der Upload; die Nutzer-Abnahme der TestFlight-Fassung ist #176

### Technical Approach
1. Label auf `xcode-27`, Xcode 27.0 fest wählen und auf „Xcode 27.0" prüfen. Die Build-Kennung wird nur protokolliert, damit ein Image-Update auf 27.0.x nicht unnötig bricht.
2. Absenkung ersatzlos streichen. Ohne Xcode 27 bricht der Lauf mit klarer Meldung ab, statt still eine 26er-Fassung zu bauen.
3. Nachweisschritt aus dem Archiv (`plutil` auf die `Info.plist` jeder eingebetteten App bzw. Erweiterung). Das erfüllt den DoD-Punkt „nicht auf 26.0 abgesenkt" maschinell und in jedem künftigen Lauf.
4. Build-Nummer bleibt `github.run_number`. Sie zählt je Workflow monoton weiter und liegt damit über dem Lauf vom 09-19.
5. Lauf per `workflow_dispatch` aus dem gemergten Stand. Danach per App-Store-Connect-API (`altool`/API mit ASC-Schlüssel in der CI) oder im Lauf-Log prüfen, dass der Build angenommen wurde. Erst nach freigegebener Spec, weil der Upload bei Henning ankommt.

### Alternativen
- **Lokaler Archiv-Lauf auf Hennings Mac** (Xcode 27.0, eigener ASC-Schlüssel, nie seine Xcode-Anmeldung, #156). Vorteil: keine Abhängigkeit vom Vorschau-Image. Nachteil: hängt an seinem Mac, nicht per Tag auslösbar, Schlüssel muss lokal liegen, Build-Nummern müssen mit der CI abgestimmt werden. Taugt als dokumentierter Notweg, nicht als Hauptweg.
- **Absenkung belassen** und nur belegen, dass der Unterschied nicht verhaltensrelevant ist. Verworfen: Das Linken gegen 26.6 statt 27.0 ändert SDK-gebundenes Verhalten (SwiftUI, SwiftData, FoundationModels), und die DoD verlangt ausdrücklich eine 27er-Fassung.
- **Neueste Xcode-Version (27.2-Beta) zulassen**, wie die heutige Auswahl es täte. Verworfen: ASC nimmt sie zwar für TestFlight an, sie entspricht aber nicht Hennings Xcode, und Beta-Werkzeuge sind keine Grundlage für eine Fassung, die „sich wie die aus Xcode verhält".

### Abgegrenzt (eigene Tickets, anderes Ziel)
- #177 Privacy-Manifest für alle Ziele (Pflicht erst bei App-Store-Einreichung)
- #178 CI (`ci.yml`, drei Jobs) auf Xcode 27 umstellen, gleiche Ursache, anderes Ziel
- #176 Nutzer-Abnahme der TestFlight-Fassung (besteht bereits)

### Dependencies
GitHub-Image `xcode-27` (Vorschau), ASC-API-Schlüssel mit Admin-Rolle (4 Secrets gesetzt), XcodeGen per brew.
Cloud-Signierung erzeugt Profile für alle vier Ziele selbst, wie am 09-17/09-19.

### Open Questions
- Keine PO-Frage offen. Ob das Vorschau-Image Wartezeiten hat, zeigt erst der Lauf.

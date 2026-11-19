---
entity_id: feat-795-schnitt-5c2b-aps-umgebung
type: feature
created: 2026-11-19
updated: 2026-11-19
status: draft
workflow: feat-795-s5c2b-aps-umgebung
---

# Spec: APNs-Umgebung als Info-Marke im Bau, Schnitt S5c-2b (#795, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#795 (Epic #612). Schnitt S5c-2b; das Issue bleibt offen (`Refs #795`, nie `Closes #795`).
Analyse: `docs/context/feat-795-s5c2b-aps-umgebung.md` (verbindlich).
Vorgabe aus: `docs/specs/feat-795-schnitt-5c1-weckruf-kern.md` (Abschnitt „Out of Scope / Folgeschnitte“). Dienst-Seite: `docs/specs/feat-795-schnitt-5b-weckruf-betrieb.md`.
Reihenfolge: S5c-2b (dieser Schnitt) → S5c-2b2 (Mac-Push-Schlüssel) → S5c-2a (Delegates).

## Für den PO

Die App meldet dem Dienst künftig, über welchen Apple-Weg sie angestoßen werden will (Test oder echt). Dafür muss jeder Bau von Anfang an wissen, welcher Weg zu ihm gehört. Dieser Schnitt setzt diese Angabe im Bau: normal „Test“, in den TestFlight-Bauten „echt“, und der TestFlight-Lauf prüft das vor dem Hochladen.

Für dich ändert sich nichts Sichtbares. Du musst nichts entscheiden und nichts tun.

## Purpose

`PushEnvironment.current` (S5c-1) liest die Info-Marke `LEApsEnvironment`, die es im Bau noch nicht gibt; es ergibt deshalb immer `.sandbox`. Würde S5c-2a so ausgeliefert, meldete ein TestFlight-Bau `sandbox`, und der Dienst verwürfe den Token (APNs 400 `BadDeviceToken`). Dieser Schnitt bringt die Marke in den Bau, ohne App-Code zu ändern:

1. `project.yml`: im App-Ziel unter `info.properties` die Marke `LEApsEnvironment: sandbox` (Vorgabe für jeden Bau, auch „LE Prüfbau“ und `launch-measure`, die mit Entwicklungsprofil laufen). Abbild in `LooseEnds/Info.plist`. Der Kommentar am Schlüssel `aps-environment` wird korrigiert (gilt nur für iOS).
2. `.github/workflows/testflight.yml`: in beiden Jobs (`upload` iOS, `upload-mac`) ein Schritt „Set the APNs environment“ nach `generate`, **ohne `if:`** (jeder Lauf dort ist ein Upload, auch `v*`-Tags, anders als `konto`): `plutil -replace LEApsEnvironment -string production`.
3. Archivprüfung (iOS „Verify the archive …“, Mac „Verify the macOS archive“): `LEApsEnvironment` hat den Typ `string` und den Wert `production`, sonst bricht der Lauf vor dem Upload ab; in der Step-Summary steht die Zeile `LEApsEnvironment | string production | OK`. iOS prüft zusätzlich per `entitled com.henning.looseends aps-environment`, dass das signierte Entitlement vorhanden ist (nur Vorhandensein: das Archiv ist mit dem Entwicklungsprofil signiert und trägt `development`; erst der Export mit Verteilungsprofil setzt `production`, Apple DTS, https://developer.apple.com/forums/thread/703422, https://developer.apple.com/forums/thread/710061). Die neuen Prüfzeilen stehen außerhalb der `# account-switch-check`-Blöcke.
4. Mac: Das Mac-Archiv trägt heute kein Push-Entitlement (belegt: CI-Lauf 43975783706, `archive-mac.log`). Das ist **nicht** Teil dieses Schnitts (eigener Folgeschnitt S5c-2b2, Schlüssel `com.apple.developer.aps-environment`). Die Marke wird auf dem Mac trotzdem gesetzt und geprüft, damit S5c-2b2 und S5c-2a darauf aufbauen können.
5. Doku und Kommentar: `docs/reference/testflight.md`, `CLAUDE.md` (Absatz `LooseEnds/Claude`/Ship), Kommentar in `LooseEnds/Claude/DeviceRegistration.swift` („set from S5c-2b on“ statt „kommt erst mit S5c-2b“).

Kein Laufzeitverhalten ändert sich: `PushEnvironment.init(infoValue:)` bleibt (nur exakt `"production"` ergibt `.production`). Nichts ruft den Weckruf-Weg auf.

Regeln vor Modell: reine Bau- und CI-Frage ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue ADR; Entscheidung A aus S5c-1 (Umgebung aus einer Marke im Bau, Muster `LEAccountEnabled`) gilt und wird hier umgesetzt, ADR-21 samt Addendum Weckruf bleibt unverändert.
- **Rationale:** Die Marke ist belegbar richtig, weil der TestFlight-Lauf sie setzt und das Archiv sie prüft; eine Laufzeitvermutung (`#if DEBUG`, Profil lesen) wäre es nicht. Kein neues Schema, keine neue Abhängigkeit, keine neue Berechtigung.

## Source

- **File:** `project.yml`, `LooseEnds/Info.plist`, `.github/workflows/testflight.yml`, `scripts/test_aps_environment.py` (neu)
- **Identifier:** Info-Schlüssel `LEApsEnvironment`; Workflow-Schritt „Set the APNs environment“ in `upload` und `upload-mac`

**Unberührt (außer Kommentar):** `LooseEnds/Claude/DeviceRegistration.swift` (nur der Kommentar), jeder andere Swift-Code, `*.entitlements`, Watch, Widgets, `server/`, `scripts/mac_ci_entitlements.py`, die `account-switch-check`-Blöcke.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `PushEnvironment.init(infoValue:)` (S5c-1) | module | liest die Marke, unverändert |
| XcodeGen (`generate`) | tool | erzeugt `Info.plist` aus `project.yml` |
| `plutil` | tool | setzt und liest die Marke im TestFlight-Lauf |
| `codesign -d --entitlements` / `entitled` | tool | Vorhandensein von `aps-environment` im iOS-Archiv |
| `scripts/test_info_plist_sync.py`, CI-Schritt „Generate leaves the tree clean“ | test | halten Quelle und Abbild gleich |
| Muster `LEAccountEnabled` (`scripts/test_asc_what_to_test.py` Z. 236–330) | pattern | Vorlage der Python-Tests |
| Downstream S5c-2b2, S5c-2a; Dienst `server/src/apns.ts` | module | wählt den Host nach `environment` |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `project.yml` | MODIFY | `LEApsEnvironment: sandbox` in `info.properties` des App-Ziels, Kommentare; ≈ +4 |
| `LooseEnds/Info.plist` | MODIFY | Abbild der Marke; ≈ +2 |
| `.github/workflows/testflight.yml` | MODIFY | Schritt „Set the APNs environment“ je Job, Prüfzeilen iOS und Mac; ≈ +45 |
| `scripts/test_aps_environment.py` | CREATE | Quell-, Workflow- und Ausführungstests nach Muster `LEAccountEnabled`; ≈ +110 |
| `docs/reference/testflight.md`, `CLAUDE.md`, `LooseEnds/Claude/DeviceRegistration.swift` (Kommentar) | MODIFY | Doku, zählen nicht zum Dateilimit; ≈ +12 / −2 |

### Estimated Changes

- **Dateien: 4** (eine neu, drei geändert) plus Doku; Limit 4–5 eingehalten.
- **LoC: ≈ +165 / −2**, im Limit von ±250. Keine Funktion über 50 Zeilen.
- Keine Berechtigungen, keine AppStorage-Keys, kein CloudKit-Schema, keine Audio-Dateien, keine Oberfläche. Neue Info-Marke `LEApsEnvironment` (Pfad der Geräteliste). `generate` muss laufen und darf danach keinen Diff hinterlassen.
- **Parallele Arbeit:** `CLAUDE.md` und `project.yml` sind Hotspots; vor dem PR gegen `origin/main` und offene PRs abgleichen.

## Implementation Details

- Quelle: ein Eintrag `LEApsEnvironment: sandbox` neben `LEAccountEnabled` in `info.properties` des App-Ziels; `generate` schreibt das Abbild.
- Workflow: der Schritt gleicht dem „Set the account switch“, aber ohne `if:`; Reihenfolge nach `generate`, vor dem Archiv. Die Prüfung liest per `plutil -type` und `plutil -extract` und bricht bei Abweichung ab; sie wird, wie bei `LEAccountEnabled`, als eigener Ausschnitt geschrieben, den der Python-Test herauslösen und gegen Beispiel-Plists ausführen kann.
- Nur der TestFlight-Lauf setzt `production`, nicht `CONFIGURATION`: Bauten mit Entwicklungsprofil behalten `sandbox`.
- Die Watch trägt ebenfalls `aps-environment`, hat aber kein Konto: keine Marke nötig.

## Test Plan

### Automated Tests (TDD RED)

Python-Tests in `scripts/test_aps_environment.py` (Lauf: `python3 scripts/test_aps_environment.py`; vorher RED, weil Marke und Schritte fehlen). Keine neuen UI- oder Swift-Tests: kein App-Code, keine Oberfläche.

- [ ] Test 1: GIVEN `project.yml` und `LooseEnds/Info.plist` WHEN gelesen THEN steht `LEApsEnvironment` mit Wert `sandbox` in beiden.
- [ ] Test 2: GIVEN `testflight.yml` WHEN die Jobs `upload` und `upload-mac` gelesen werden THEN hat jeder genau einen Schritt „Set the APNs environment“ ohne `if:`, nach `generate` und vor dem Archivschritt, mit `plutil -replace LEApsEnvironment -string production`.
- [ ] Test 3: GIVEN beide Prüfschritte WHEN gelesen THEN prüfen sie Typ `string` und Wert `production` außerhalb der `account-switch-check`-Blöcke, iOS zusätzlich `entitled … aps-environment`.
- [ ] Test 4: GIVEN der herausgelöste Prüfausschnitt WHEN er gegen Beispiel-Plists läuft THEN gelingt `production` als String, und `sandbox`, fehlende Marke und falscher Typ (Bool) schlagen fehl.
- [ ] Test 5: GIVEN die `account-switch-check`-Blöcke WHEN verglichen THEN sind sie unverändert (Muster `test_privacy_manifest.py`).

## Acceptance Criteria

Belegt durch `scripts/test_aps_environment.py` und die vorhandenen Wächter.

- **AC-1:** GIVEN `project.yml` und `LooseEnds/Info.plist` WHEN `LEApsEnvironment` gelesen wird THEN ist der Wert in beiden `sandbox` (Test `sourceAndImageDefaultToSandbox`).
- **AC-2:** GIVEN `./scripts/sim.sh generate` WHEN es läuft THEN bleibt der Baum sauber, und `scripts/test_info_plist_sync.py` und `scripts/test_entitlements_sync.py` sind grün (Beleg: Lauf und CI-Schritt „Generate leaves the tree clean“).
- **AC-3:** GIVEN `testflight.yml` WHEN die Jobs `upload` und `upload-mac` gelesen werden THEN setzt jeder den Wert per `plutil -replace LEApsEnvironment -string production` in einem Schritt ohne `if:`, nach `generate` und vor dem Archiv, auch bei `v*`-Tags (Test `stepIsUnconditionalInBothJobs`).
- **AC-4:** GIVEN die iOS-Archivprüfung WHEN gelesen THEN verlangt sie Typ `string` und Wert `production` für `LEApsEnvironment` sowie `entitled com.henning.looseends aps-environment` (nur Vorhandensein), außerhalb der `account-switch-check`-Blöcke (Test `iosVerifyChecksMarkAndEntitlement`).
- **AC-5:** GIVEN die Mac-Archivprüfung WHEN gelesen THEN verlangt sie Typ `string` und Wert `production` für `LEApsEnvironment` und kein Push-Entitlement, außerhalb der `account-switch-check`-Blöcke (Test `macVerifyChecksMark`).
- **AC-6:** GIVEN der Prüfausschnitt WHEN er gegen Beispiel-Plists ausgeführt wird THEN gelingt er für `production` (String) und schlägt für `sandbox`, fehlende Marke und falschen Typ fehl (Test `verifySnippetAcceptsOnlyProductionString`).
- **AC-7:** GIVEN die Blöcke `# account-switch-check:begin/end` WHEN mit dem Stand vor dem Schnitt verglichen THEN sind sie unverändert, und `LEAccountEnabled` wird weiter nur bei `konto` gesetzt (Test `accountSwitchBlocksUntouched`).
- **AC-8:** GIVEN der Swift-Code WHEN der Diff gelesen wird THEN ändert sich in `DeviceRegistration.swift` nur ein Kommentar; `PushEnvironment.init(infoValue:)` und `DeviceRegistrationTests` bleiben unverändert und grün (Beleg: Diff und `./scripts/sim.sh sim-unit DeviceRegistrationTests`).
- **AC-9:** GIVEN die ganze Suite WHEN sie läuft THEN sind `./scripts/sim.sh unit`, die Python-Wächter und die CI grün, und der Simulator-Bau gelingt (`./scripts/sim.sh build`; Beleg im Abschlussbericht).

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): Marke im Bau, nur TestFlight setzt `production`** | Entscheidung A aus S5c-1 | belegbar, Muster `LEAccountEnabled` | Archiv kann den Wert des Entitlements nicht prüfen (`development` bis zum Export) | nichts; keine ADR |
| **B (Fallback für S5c-2b2): getrennte Entitlements-Datei je SDK** | `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]` | sauber gegen Rückwirkung auf iOS | zweite Datei, Anpassung `test_entitlements_sync.py` und `mac_ci_entitlements.py`; nur falls ein iOS-Archiv den gemeinsamen Mac-Schlüssel nicht verträgt | nichts; gehört zu S5c-2b2 |
| **C: Umgebung zur Laufzeit aus `embedded.mobileprovision`** | Profil lesen | übliche Praxis | kippt Entscheidung A aus S5c-1; das Archivprofil ist das Entwicklungsprofil, die Mac-Datei heißt anders; verworfen | die Entscheidung A aus S5c-1 (keine ADR) |
| **D: Marke und Mac-Schlüssel in einem Schnitt** | alles zusammen | passt ins Limit | ein Signierfehler durch den Mac-Schlüssel risse die Marke mit; verworfen | nichts |

## Out of Scope / Folgeschnitte

- **S5c-2b2:** Mac-Push-Schlüssel `com.apple.developer.aps-environment` in `project.yml` und `.entitlements`, Prüfung im Mac-Archiv, iOS-Archiv darf nicht brechen. Kommt vor S5c-2a.
- **S5c-2a:** Delegates, Token-Rückrufe, Weckruf-Eingang, `registerForRemoteNotifications`.
- Nebenbefund: `com.apple.developer.siri` fehlt im Mac-Archiv, eigenes Issue.

## Abnahme

Pfade der Geräteliste berührt: `project.yml` und `Info.plist`. Stufe 1 sind die Python-Tests und die Unit-Suite, Stufe 2 der Simulator-Bau samt `generate` ohne Diff (kein Bedienablauf, die App startet unverändert). Stufe 3 ist hier der TestFlight-Lauf nach dem Merge, durch Claude gestartet und belegt: die Step-Summary trägt für iOS und Mac je die Zeile `LEApsEnvironment | string production | OK`. Es gibt keinen Bedienweg für Henning; die sichtbare Wirkung entsteht erst mit S5c-2a. Der Lauf steht in der Definition of Done, nicht als AC (das QA-Gate kennt keinen Aufschub).

## Definition of Done

- [ ] AC-1 bis AC-9 erfüllt, Tests vor dem Code geschrieben (RED belegt)
- [ ] Abnahme Stufe 1 und 2 belegt
- [ ] Stufe 3: TestFlight-Lauf nach Merge, Step-Summary mit `LEApsEnvironment | string production | OK` für iOS und Mac, von Claude belegt
- [ ] Doku: `docs/reference/testflight.md`, `CLAUDE.md`, Kommentar in `DeviceRegistration.swift` aktualisiert
- [ ] Folgeissues angelegt: S5c-2b2 (Mac-Push-Schlüssel) und Siri-Entitlement auf dem Mac
- [ ] PR mit `Refs #795`, CI grün, Merge durch Claude; #795 kommentiert, Board aktuell, Memory geschrieben

## Known Limitations

- Das Archiv trägt `aps-environment = development`; geprüft wird nur das Vorhandensein, der Wert `production` entsteht erst im Export.
- Das Mac-Archiv trägt kein Push-Entitlement; die Marke dort ist bis S5c-2b2 ohne Wirkung.
- Bauten mit Entwicklungsprofil außerhalb TestFlight melden bewusst `sandbox`.

## Changelog

- 2026-11-19: Initial spec created (Schnitt S5c-2b)

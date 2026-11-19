---
entity_id: feat-795-schnitt-5c2b2-mac-push
type: feature
created: 2026-11-19
updated: 2026-11-19
status: draft
workflow: feat-795-s5c2b2-mac-push
---

# Spec: Push-Berechtigung im Mac-Archiv, Schnitt S5c-2b2 (#795, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#795 (Epic #612). Schnitt S5c-2b2; das Issue bleibt offen (`Refs #795`, nie `Closes #795`).
Analyse: `docs/context/feat-795-s5c2b2-mac-push.md` (verbindlich).
Vorgänger: `docs/specs/feat-795-schnitt-5c2b-aps-umgebung.md` (Marke `LEApsEnvironment`, Muster der Archivprüfung und des Wächtertests).
Reihenfolge: S5c-2b (erledigt) → S5c-2b2 (dieser Schnitt) → S5c-2a (Delegates).

## Für den PO

Damit der Mac später vom Dienst geweckt werden kann und Änderungen aus iCloud schneller bemerkt, muss die Mac-App von Apple die Erlaubnis für Push-Nachrichten bekommen. Bisher fehlt sie im Mac-Bau, ohne dass es jemand gemerkt hat. Dieser Schnitt trägt sie ein und lässt den TestFlight-Lauf prüfen, dass sie im Mac- und im iPhone-Bau steckt.

Für dich ändert sich nichts Sichtbares. Du musst nichts entscheiden und nichts tun.

## Purpose

Das signierte Mac-Archiv trägt kein Push-Entitlement (belegt: CI-Lauf 43975783706, `archive-mac.log`): Xcode lässt auf macOS den iOS-Schlüssel `aps-environment` still weg. Der macOS-Schlüssel heißt `com.apple.developer.aps-environment` (Apple DTS, https://developer.apple.com/forums/thread/799000). Ohne ihn bekommt der Mac weder CloudKit-Pushes noch (S5c-2a) den Weckruf des Dienstes. Dieser Schnitt bringt den Schlüssel in den Bau und die Prüfung, ohne App-Code zu ändern:

1. `project.yml`, Ziel `LooseEnds`, `entitlements.properties`: zusätzlich `com.apple.developer.aps-environment: development` neben `aps-environment`. Eine gemeinsame Datei für iOS und macOS (Alternative A). Abbild `LooseEnds/LooseEnds.entitlements` entsteht mit `./scripts/sim.sh generate`, nie von Hand. Der Kommentar am Schlüssel `aps-environment` wird angepasst (der Mac-Schlüssel steht jetzt daneben).
2. `.github/workflows/testflight.yml`, Job `upload-mac`, Schritt „Verify the macOS archive“: die Schleife der Pflicht-Schlüssel (`for key in …`, heute Zeile 532) verlangt zusätzlich `com.apple.developer.aps-environment`. Nur das Vorhandensein wird geprüft, nicht der Wert: wie bei iOS (S5c-2b) ist das Archiv mit dem Entwicklungsprofil signiert und trägt `development`, erst der Export mit Verteilungsprofil setzt `production` (Apple DTS, https://developer.apple.com/forums/thread/703422). Ein Wertvergleich auf `production` würde den Lauf fälschlich stoppen; die Mac-Schleife prüft bereits alle anderen Schlüssel nur auf Vorhandensein, das Muster passt.
3. iOS-Archivprüfung unverändert: sie verlangt weiter `entitled com.henning.looseends aps-environment` (Zeile 230). Der Mac-Schlüssel kommt dort nicht dazu, denn iOS lässt ihn voraussichtlich weg.
4. Wächtertest `scripts/test_aps_environment.py` um Fälle für Quelle, Mac-Prüfung und iOS-Prüfung erweitern (vorher rot).
5. Doku: `docs/reference/testflight.md` (Absatz „APNs-Umgebung als Marke“, der Satz zum Mac-Archiv) und die Zeile zu S5c-2b in `CLAUDE.md` (`LooseEnds/Claude`, „both archive checks demand …“) um den Mac-Schlüssel ergänzen, knapp.

Nicht-Ziel und Prüfpunkt: `scripts/mac_ci_entitlements.py` filtert alles mit dem Präfix `com.apple.developer.` sowie `aps-environment` aus den Berechtigungen der ad hoc signierten Mac-CI (Konstante `NEEDS_PROFILE`, durch Lesen verifiziert). Der neue Schlüssel fällt unter den Filter; Mac Gallery und Klicktests bleiben unberührt, die Datei wird nicht geändert. Ebenfalls unberührt: Simulator-Bau (`CODE_SIGNING_ALLOWED=NO`), Watch (eigenes `aps-environment`), Widgets (kein Push).

Kein Laufzeitverhalten ändert sich: Nichts ruft den Weckruf-Weg auf, kein Swift-Code wird angefasst.

Regeln vor Modell: reine Bau- und CI-Frage ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue ADR; ADR-21 samt Addendum Weckruf (Push als Weckweg) bleibt unverändert, hier wird nur die Berechtigung dafür auf dem Mac nachgezogen.
- **Rationale:** Ein zusätzlicher Schlüssel in der bestehenden Berechtigungsquelle ist kein Architekturschnitt: kein neues Schema, keine neue Abhängigkeit, keine neue Mechanik. Die Wahl zwischen gemeinsamem Schlüssel und getrennter Datei (Alternative B) ist Bau-Detail und unten begründet; die Regel „Berechtigungen nur in `project.yml`“ (#311) bleibt gewahrt.

## Source

- **File:** `project.yml`, `LooseEnds/LooseEnds.entitlements`, `.github/workflows/testflight.yml`, `scripts/test_aps_environment.py`
- **Identifier:** Berechtigung `com.apple.developer.aps-environment`; Schleife der Pflicht-Schlüssel im Schritt „Verify the macOS archive“ des Jobs `upload-mac`

**Unberührt:** jeder Swift-Code, `scripts/mac_ci_entitlements.py`, `scripts/test_entitlements_sync.py` (läuft nur zur Gegenprobe), die `account-switch-check`- und `aps-environment-check`-Blöcke, Watch, Widgets, `server/`.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| XcodeGen (`generate`) | tool | schreibt `LooseEnds.entitlements` aus `entitlements.properties` |
| `scripts/test_entitlements_sync.py` | test | hält Quelle und Abbild der Berechtigungen gleich, muss grün bleiben |
| `scripts/mac_ci_entitlements.py` | module | filtert `com.apple.developer.*` in der Mac-CI, bleibt unverändert |
| `codesign -d --entitlements` | tool | liest die Berechtigungen des Mac-Archivs |
| `entitled` (Hilfsfunktion der iOS-Prüfung) | tool | Vorhandensein von `aps-environment` im iOS-Archiv, unverändert |
| Cloud-Signierung (`-allowProvisioningUpdates`) | service | legt das Mac-Profil mit Push-Fähigkeit an; App-ID `com.henning.looseends` hat Push |
| `scripts/test_aps_environment.py` (S5c-2b) | test | Muster und Ort der neuen Fälle |
| Downstream S5c-2a, CloudKit-Pushes am Mac | module | bauen auf dem Schlüssel auf |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `project.yml` | MODIFY | `com.apple.developer.aps-environment: development` in `entitlements.properties` des App-Ziels, Kommentar; ≈ +3 |
| `LooseEnds/LooseEnds.entitlements` | MODIFY | Abbild per `generate`, nie von Hand; ≈ +2 |
| `.github/workflows/testflight.yml` | MODIFY | Schlüssel in die Pflicht-Schlüssel-Schleife der Mac-Prüfung; ≈ +1 |
| `scripts/test_aps_environment.py` | MODIFY | Klasse `EntitlementTests` mit vier Fällen; ≈ +40 |
| `docs/reference/testflight.md`, `CLAUDE.md` | MODIFY | Doku, zählen nicht zum Dateilimit; ≈ +6 / −2 |

### Estimated Changes

- **Dateien: 4** Code/Config plus Doku (zwei Dateien); Limit 4–5 eingehalten.
- **LoC: ≈ +55 / −2**, weit im Limit von ±250. Keine Funktion über 50 Zeilen.
- Neue Berechtigung `com.apple.developer.aps-environment` (Pfade der Geräteliste: `project.yml`, `*.entitlements`). Keine AppStorage-Keys, kein CloudKit-Schema, keine Audio-Dateien, keine Oberfläche, keine `Info.plist`-Änderung. `generate` muss laufen und darf danach keinen weiteren Diff hinterlassen.
- **Parallele Arbeit:** `CLAUDE.md` und `project.yml` sind Hotspots; vor dem PR gegen `origin/main` und offene PRs abgleichen.

## Implementation Details

- Quelle: ein Eintrag in `entitlements.properties` des App-Ziels, Wert `development`; der Export setzt wie bei iOS `production`. `generate` schreibt das Abbild; `test_entitlements_sync.py` vergleicht beide.
- Workflow: Der Schlüsselname wird in die vorhandene Leseliste der Mac-Prüfung aufgenommen; Fehlen setzt `fail=1` und stoppt den Lauf vor dem Upload (Muster der übrigen Schlüssel, Meldung „macOS app is not signed with …“). Die iOS-Prüfung bleibt Zeile für Zeile gleich.
- Test: Der Wächtertest liest `project.yml` (Entitlements-Quelle) und die Schrittblöcke aus `testflight.yml` textuell, wie die vorhandenen Tests; kein neuer Ausführungsaufbau nötig.
- Risiko: Die gemeinsame Datei trägt nun beide Schlüssel. Forum 683199 (Nutzerbericht 2021) nennt Signierfehler, wenn ein Profil einen der Schlüssel nicht enthält; unser Mac-Archiv hat den iOS-Schlüssel aber still weggelassen, statt zu scheitern. Ob das iOS-Archiv den Mac-Schlüssel ebenso still weglässt, ist nur durch einen TestFlight-Lauf zu belegen (siehe Abnahme). Bricht es, stoppt der Lauf vor dem Upload; es erreicht nichts Henning, und Alternative B folgt als eigener Schnitt.

## Test Plan

### Automated Tests (TDD RED)

Python-Tests in `scripts/test_aps_environment.py` (Lauf: `python3 scripts/test_aps_environment.py`; vorher RED, weil Schlüssel und Prüfzeile fehlen). Keine neuen UI- oder Swift-Tests: kein App-Code, keine Oberfläche.

- [ ] Test 1: GIVEN `project.yml` WHEN die `entitlements.properties` des App-Ziels gelesen werden THEN tragen sie `com.apple.developer.aps-environment: development` und weiter `aps-environment: development`.
- [ ] Test 2: GIVEN `testflight.yml` WHEN der Schritt „Verify the macOS archive“ im Job `upload-mac` gelesen wird THEN steht `com.apple.developer.aps-environment` in der Schleife der Pflicht-Schlüssel (`for key in … ; do`), vor den `account-switch-check`-Blöcken, und die Prüfung vergleicht keinen Wert.
- [ ] Test 3: GIVEN `testflight.yml` WHEN der iOS-Prüfschritt gelesen wird THEN verlangt er weiter `entitled com.henning.looseends aps-environment` und nennt den Mac-Schlüssel nicht.
- [ ] Test 4: GIVEN die Abbild-Datei `LooseEnds/LooseEnds.entitlements` WHEN sie als Plist gelesen wird THEN trägt sie beide Schlüssel mit Wert `development`.

## Acceptance Criteria

Belegt durch `scripts/test_aps_environment.py` und die vorhandenen Wächter.

- **AC-1:** GIVEN `project.yml` WHEN `entitlements.properties` des App-Ziels gelesen wird THEN steht dort `com.apple.developer.aps-environment` mit Wert `development` und `aps-environment` unverändert daneben (Test `sourceCarriesMacPushKey`).
- **AC-2:** GIVEN `./scripts/sim.sh generate` WHEN es läuft THEN trägt `LooseEnds/LooseEnds.entitlements` beide Schlüssel mit `development`, der Baum bleibt danach sauber, und `scripts/test_entitlements_sync.py` und `scripts/test_info_plist_sync.py` sind grün (Test `imageCarriesMacPushKey`; Beleg: Lauf und CI-Schritt „Generate leaves the tree clean“).
- **AC-3:** GIVEN die Mac-Archivprüfung in `testflight.yml` WHEN gelesen THEN verlangt ihre Schlüsselschleife `com.apple.developer.aps-environment` nur auf Vorhandensein, und Fehlen setzt `fail=1` (Test `macVerifyRequiresPushKey`).
- **AC-4:** GIVEN die iOS-Archivprüfung WHEN gelesen THEN verlangt sie weiter `entitled com.henning.looseends aps-environment` und enthält den Mac-Schlüssel nicht (Test `iosVerifyKeepsApsEnvironment`).
- **AC-5:** GIVEN `scripts/mac_ci_entitlements.py` und `scripts/test_mac_ci_entitlements.py` WHEN der Diff gelesen und die Tests ausgeführt werden THEN sind beide unverändert und grün, der neue Schlüssel wird weiter herausgefiltert (Beleg: Diff und Lauf; Mac Gallery und `MacDetailClickTests` bleiben unberührt).
- **AC-6:** GIVEN der Diff WHEN gelesen THEN ändert sich kein Swift-Code, keine `Info.plist`, kein Watch- oder Widget-Ziel, und `account-switch-check`- und `aps-environment-check`-Blöcke bleiben unverändert (Tests `test_account_switch_blocks_untouched` und `test_verify_snippet_accepts_only_production_string` aus S5c-2b bleiben grün).
- **AC-7:** GIVEN die ganze Suite WHEN sie läuft THEN sind die Python-Wächter, `./scripts/sim.sh unit` und die CI grün, und der Simulator-Bau gelingt unverändert (`./scripts/sim.sh build`; Beleg im Abschlussbericht).

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): gemeinsamer Schlüssel** | beide Schlüssel in `entitlements.properties` | eine Datei, keine neue Mechanik, Regel #311 gewahrt; passt zum beobachteten stillen Weglassen des Fremdschlüssels | iOS-Archiv könnte den Mac-Schlüssel nicht still weglassen (Forum 683199); nur per TestFlight-Lauf zu belegen | nichts; keine ADR |
| **B (Fallback): getrennte Datei je SDK** | `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]: LooseEnds/LooseEnds-macOS.entitlements` (DTS-Muster, Forum 763093) | sauber gegen Rückwirkung auf iOS | zweite Datei, die XcodeGen nicht aus `entitlements.properties` schreibt; `test_entitlements_sync.py` und `mac_ci_entitlements.py` müssten erweitert, alle übrigen Schlüssel doppelt gepflegt werden; kippt die Regel „Berechtigungen nur in `project.yml`“ (#311) in Teilen | die Einquellen-Regel aus #311 (Ergänzung, keine ADR); nur falls A das iOS-Archiv bricht, dann eigener Schnitt |
| **C: Mac ohne Push, Mac fragt nur ab** | Takt über `ClaudeSyncTrigger` beim Aktivwerden, wie heute | kein Signierrisiko, kein Schnitt nötig | kippt die PO-Entscheidung vom 2026-11-13 (echter Weckruf) für den Mac; CloudKit-Verzögerung am Mac bliebe („Mac per iCloud verzögert“, #932) | die Entscheidung zum Weckruf (ADR-21 Addendum) für den Mac |
| **D: Wertprüfung `production` im Mac-Archiv** | wie die Marke aus S5c-2b | schärfer | falsch: das Archiv trägt `development`, erst der Export setzt `production`; der Lauf bräche immer | nichts; verworfen |

## Out of Scope / Folgeschnitte

- **S5c-2a:** Delegates, Token-Rückrufe, Weckruf-Eingang, `registerForRemoteNotifications`, auch am Mac. Dort entsteht die sichtbare Wirkung.
- **Alternative B**, falls das iOS-Archiv am Mac-Schlüssel bricht.
- Nebenbefund aus S5c-2b: `com.apple.developer.siri` fehlt im Mac-Archiv, eigenes Issue; nicht Teil dieses Schnitts.
- Lokale signierte Mac-Bauten (`mac-schema-init`, `sim.sh mac`): brauchen ggf. einen Registrierungslauf, damit das Entwicklungsprofil die Fähigkeit enthält; nur auf Hennings Wort relevant, nicht Teil dieses Schnitts.

## Abnahme

Pfade der Geräteliste berührt: `project.yml` und `LooseEnds.entitlements`. Stufe 1 sind die Python-Tests und die Unit-Suite, Stufe 2 der Simulator-Bau samt `generate` ohne Diff (kein Bedienablauf, die App startet unverändert; der Simulator-Bau ist unsigniert und sieht die Berechtigung nicht). Stufe 3 ist hier der TestFlight-Lauf nach dem Merge, durch Claude gestartet und belegt: Step-Summary und Archivprüfung beider Jobs grün, im Mac-Job mit der Zeile `com.apple.developer.aps-environment | vorhanden | OK`, im iOS-Job mit weiter bestandener `aps-environment`-Prüfung. Es gibt keinen Bedienweg für Henning; die sichtbare Wirkung entsteht erst mit S5c-2a. Der Lauf steht in der Definition of Done, nicht als AC (das QA-Gate kennt keinen Aufschub).

## Definition of Done

- [ ] AC-1 bis AC-7 erfüllt, Tests vor dem Code geschrieben (RED belegt)
- [ ] Abnahme Stufe 1 und 2 belegt
- [ ] Stufe 3: TestFlight-Lauf nach Merge, von Claude gestartet; beide Archivprüfungen grün (Mac-Zeile `com.apple.developer.aps-environment | vorhanden | OK`, iOS-Prüfung bestanden). Bricht das iOS-Archiv am Mac-Schlüssel, stoppt der Lauf vor dem Upload, und Alternative B wird als eigener Schnitt angelegt
- [ ] Doku: `docs/reference/testflight.md` und `CLAUDE.md` aktualisiert
- [ ] PR mit `Refs #795`, CI grün, Merge durch Claude; #795 kommentiert, Board aktuell, Memory geschrieben

## Known Limitations

- Das Mac-Archiv trägt `com.apple.developer.aps-environment = development`; geprüft wird nur das Vorhandensein, `production` entsteht erst im Export.
- Ob das iOS-Archiv den gemeinsamen Mac-Schlüssel verträgt, zeigt erst der TestFlight-Lauf nach dem Merge.
- Ohne S5c-2a bleibt die Wirkung am Mac unsichtbar.

## Changelog

- 2026-11-19: Initial spec created (Schnitt S5c-2b2)

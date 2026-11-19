# Context: feat-795-s5c2b-aps-umgebung (#795 Schnitt 5c-2b)

## Request Summary
Die App soll beim Dienst melden, ob ihr Gerätetoken zur APNs-Umgebung `sandbox` oder `production` gehört.
`PushEnvironment.current` (S5c-1) liest dafür die Info-Marke `LEApsEnvironment`, die es im Bau noch nicht gibt
(bis jetzt immer `.sandbox`). Dieser Schnitt bringt die Marke in den Bau: Vorgabe `sandbox` in `project.yml`, nur
der TestFlight-Lauf setzt `production`, die Archivprüfung belegt das. Muss vor S5c-2a (Delegates) ausgeliefert sein,
sonst meldet ein TestFlight-Bau `sandbox` und der Dienst verwirft den Token (APNs 400 `BadDeviceToken`).

## Related Files
| File | Relevance |
|------|-----------|
| `project.yml` (App-Ziel, `info.properties` ab Z. 75; `entitlements` Z. 70 `aps-environment: development`) | neue Info-Marke `LEApsEnvironment: sandbox` |
| `LooseEnds/Info.plist` | generiertes Abbild, muss die Marke tragen (`test_info_plist_sync.py`) |
| `.github/workflows/testflight.yml` | Jobs `upload` (iOS) und `upload-mac`: Schritt „Set the account switch“ (nur bei `konto`) setzt per `plutil` nach `generate`; Prüfschritte „Verify the archive …“ / „Verify the macOS archive“ mit `entitled`, `account_switch`-Block (`# account-switch-check:begin/end`), Export `method app-store-connect`, `destination upload` |
| `LooseEnds/Claude/DeviceRegistration.swift` Z. 1–25 | `PushEnvironment` mit `init(infoValue:)` (nur exakt `"production"` → `.production`) und `current` |
| `LooseEndsTests/DeviceRegistrationTests.swift` | Unit-Tests der Lesart |
| `scripts/test_asc_what_to_test.py` Z. 236–330 | Vorlage: Quell- und Workflow-Tests für `LEAccountEnabled` (Hilfen `job`, `step`, `app_target`, Ausführung des Prüfausschnitts gegen Beispiel-Plists) |
| `scripts/test_privacy_manifest.py` | zweite Vorlage (#625 S2), prüft u. a., dass `account-switch-check`-Blöcke unverändert bleiben |
| `scripts/test_info_plist_sync.py`, `scripts/test_entitlements_sync.py` | Wächter Quelle ↔ Abbild |
| `scripts/mac_ci_entitlements.py` | Mac-CI entfernt `aps-environment` (braucht Profil) – betrifft nur Mac Gallery |
| `docs/specs/feat-795-schnitt-5c1-weckruf-kern.md` Z. 145–175 | Vorgabe für S5c-2b: Marke im Bau, Archivprüfung kreuzweise gegen Entitlement, iOS und Mac, Mac-Schlüssel zu klären |
| `docs/reference/testflight.md` | Doku der Archivprüfungen |

## Existing Patterns
- `LEAccountEnabled` (#615 S4c-2a): Quelle in `project.yml` als echter Wert, `plutil -replace` nach `generate` im
  TestFlight-Lauf, Archivprüfung beider Plattformen mit Typ und Wert, Python-Tests lesen den Workflow-Text.
- `PrivacyInfo` (#625 S2): Hilfsskript mit `apply`/`check`, Archivprüfung ruft `check` auf.
- Signierte Berechtigungen prüft `entitled` (iOS) bzw. die Schleife über `ents` (Mac) nur auf Vorhandensein des Schlüssels.

## Dependencies
- Upstream: `PushEnvironment.init(infoValue:)` (fertig), XcodeGen, `plutil`, `codesign -d --entitlements`.
- Downstream: S5c-2a (`DeviceRegistration.register` mit `PushEnvironment.current`), Dienst `src/apns.ts` wählt den
  Host nach `environment` und löscht bei 400 `BadDeviceToken` nur die Zeile dieser Umgebung.

## Existing Specs
- `docs/specs/feat-795-schnitt-5c1-weckruf-kern.md` (Vorgabe), `docs/specs/feat-795-schnitt-5b-weckruf-betrieb.md`
  (Dienst-Seite, „S5c prüft das gegen `aps-environment`“), Konto-Schalter #615 S4c-2a.

## Recherche (2026-11-19)
- Das Archiv wird in der CI mit Entwicklungsprofil signiert (`aps-environment = development`); erst der Export mit
  Verteilungsprofil (`app-store-connect`) setzt `production` ein, unabhängig vom Wert in der Entitlements-Datei
  (Apple DTS: die Verteilungs-Allowlist enthält für `aps-environment` immer `production`).
  https://developer.apple.com/forums/thread/703422, https://developer.apple.com/forums/thread/710061
  → „kreuzweise gegen das signierte Entitlement“ kann im Archiv nur „Schlüssel vorhanden“ prüfen, nicht den Wert.
- macOS heißt der Schlüssel `com.apple.developer.aps-environment`, iOS `aps-environment`
  (https://developer.apple.com/forums/thread/799000; Mac-Verteilung: Wert `production`,
  https://developer.apple.com/tutorials/data/documentation/xcode/creating-distribution-signed-code-for-the-mac.md).
  Das Mehrplattform-Ziel hat eine gemeinsame Entitlements-Quelle mit `aps-environment`; ob das Mac-Archiv überhaupt
  ein Push-Entitlement trägt, ist offen (die Mac-Archivprüfung prüft es heute nicht). Lokal gibt es keinen Mac-Bau.

## Risks & Considerations
- Mac: trägt der Mac-Bau kein Push-Entitlement, bekommt der Mac nie einen Weckruf; dann ist die Marke dort zwar
  harmlos, aber die Mac-Hälfte von S5c-2a hängt an einer Entitlement-Änderung (Pfad der Geräteliste). Belegbar nur
  per CI-Archiv (`codesign -d --entitlements`) – Analyse muss das klären, nicht raten.
- Ein Release-Bau außerhalb TestFlight (`launch-measure`, „LE Prüfbau“ per Entwicklungsprofil) muss `sandbox` behalten:
  deshalb Marke nur im TestFlight-Lauf setzen, nicht an `CONFIGURATION` koppeln.
- `v*`-Tag-Läufe sind ebenfalls TestFlight-Uploads → `production` gilt dort auch (anders als `konto`).
- Watch hat ebenfalls `aps-environment`, aber kein Konto → keine Marke nötig.
- `test_info_plist_sync.py` und der CI-Schritt „Generate leaves the tree clean“ verlangen, dass `LooseEnds/Info.plist`
  mit `project.yml` übereinstimmt.
- Geräteliste: `project.yml` und `Info.plist` → Stufe 3 formal ausgelöst; sichtbar wird die Wirkung erst mit S5c-2a.
- Alternative ohne Marke: Umgebung zur Laufzeit (`#if DEBUG` → sandbox) – kippt die Entscheidung A aus S5c-1 und
  irrt bei Release-Bauten mit Entwicklungsprofil.

## Analysis

### Type
Feature (#795 Schnitt 5c-2b, Bau-/CI-Schnitt ohne App-Code)

### Befund Mac (belegt 2026-11-19)
CI-Lauf 43975783706, `archive-mac.log`, `ProcessProductPackaging LooseEnds.entitlements`: Das signierte Mac-Archiv trägt
**kein** Push-Entitlement. Xcode lässt auf macOS `aps-environment` (iOS-Schlüssel) und `com.apple.developer.siri` weg; das
iOS-Archiv trägt `aps-environment = development`. Der macOS-Schlüssel heißt `com.apple.developer.aps-environment`
(https://developer.apple.com/forums/thread/799000). Folge: Der Mac bekommt heute weder CloudKit-Pushes (passt zu
„Mac per iCloud verzögert“, #932) noch könnte er den Weckruf erhalten. Die Mac-Hälfte von S5c-2a hängt damit an einem
eigenen Schnitt **S5c-2b2** (Mac-Schlüssel in `project.yml`/`.entitlements`, Prüfung im Mac-Archiv, iOS-Archiv darf
nicht brechen), vor S5c-2a. `scripts/mac_ci_entitlements.py` filtert `com.apple.developer.`, Mac Gallery bliebe heil.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `project.yml` | MODIFY | `LEApsEnvironment: sandbox` in `info.properties` des App-Ziels, Kommentar; Kommentar an `aps-environment` korrigieren (gilt nur iOS) |
| `LooseEnds/Info.plist` | MODIFY | Abbild: `LEApsEnvironment` = `sandbox` (Wächter `test_info_plist_sync.py`, CI „Generate leaves the tree clean“) |
| `.github/workflows/testflight.yml` | MODIFY | beide Jobs: Schritt „Set the APNs environment“ nach `generate`, ohne `if:` (auch `v*`-Tag), `plutil -replace LEApsEnvironment -string production`; iOS-Prüfung: Typ string + Wert `production`, `entitled com.henning.looseends aps-environment`; Mac-Prüfung: Typ string + Wert `production`; außerhalb der `account-switch-check`-Blöcke |
| `scripts/test_asc_what_to_test.py` (oder neue `scripts/test_aps_environment.py`) | MODIFY/CREATE | Quell- und Workflow-Tests nach Muster `LEAccountEnabled`: Vorgabe sandbox, Schritt unbedingt in beiden Jobs vor dem Archiv, Prüfausschnitt gegen Beispiel-Plists (production OK, sandbox/fehlend/falscher Typ FEHLER) |
| `docs/reference/testflight.md`, `CLAUDE.md`, `DeviceRegistration.swift`-Kommentar | MODIFY (Doku) | Marke und Prüfung beschreiben; „set from S5c-2b on“ aktualisieren |

### Scope Assessment
- Files: 4 (+ Doku)
- Estimated LoC: +80–110 / −2
- Risk Level: LOW (kein App-Code; Wirkung nur im TestFlight-Archiv; ein Fehler lässt den Lauf vor dem Upload rot werden)

### Technical Approach
Weg A aus S5c-1 bleibt: Marke im Bau, Vorgabe `sandbox`, nur `testflight.yml` setzt `production` (jeder Lauf dort ist ein
Upload). Im Archiv steht das Entitlement noch auf `development` (Export setzt `production`, Apple DTS) → kreuzweise nur
„Schlüssel vorhanden“ (iOS). Nachweis: Python-Tests lokal, `generate` lässt Baum sauber, ein TestFlight-Lauf nach Merge mit
Zeilen `LEApsEnvironment | string production | OK` für iOS und Mac in der Step-Summary (Lauf durch Claude, gehört zur Session des Epics #795 = diese).
Abnahme: Pfade der Geräteliste (`project.yml`, `Info.plist`) berührt, sichtbare Wirkung erst mit S5c-2a; Gerätepunkt = TestFlight-Archivbeleg, kein Bedienweg.

### Alternativen
- **B (Fallback für S5c-2b2): getrennte Entitlements-Datei je SDK** (`CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`) — sauber gegen iOS-Rückwirkung, aber zweite Datei, Anpassung `test_entitlements_sync`/`mac_ci_entitlements.py`; nur falls ein iOS-Archiv den gemeinsamen Mac-Schlüssel nicht verträgt.
- **C: Umgebung zur Laufzeit aus `embedded.mobileprovision`** — kippt Entscheidung A aus S5c-1; das Archiv-Profil ist das Entwicklungsprofil, Mac-Datei heißt anders; verworfen.
- **D: Marke und Mac-Schlüssel in einem Schnitt** — passt ins Limit, aber ein Signierfehler durch den Mac-Schlüssel risse die Marke mit; verworfen.

### Dependencies
Upstream `PushEnvironment.init(infoValue:)` (fertig, nur exakt `"production"`). Downstream S5c-2a; Dienst `apns.ts` wählt Host nach `environment`, löscht bei 400 `BadDeviceToken` die Zeile dieser Umgebung.

### Open Questions
- keine an den PO. Reihenfolge festgelegt: S5c-2b → S5c-2b2 (Mac-Push-Schlüssel) → S5c-2a.
- Nebenbefund `com.apple.developer.siri` fehlt im Mac-Archiv: eigenes Issue, nicht Teil dieses Schnitts.

# Context: feat-795-s5c2b2-mac-push

## Request Summary
#795 Schnitt 5c-2b2: Das Mac-Archiv soll das Push-Entitlement tragen (`com.apple.developer.aps-environment`), damit der
Mac CloudKit-Pushes und später (S5c-2a) den Weckruf des Dienstes bekommt. Das iOS-Archiv darf dabei nicht brechen.

## Befund (belegt 2026-11-19, S5c-2b-Analyse)
CI-Lauf 43975783706, `archive-mac.log`: Das signierte Mac-Archiv trägt kein Push-Entitlement. Xcode lässt auf macOS den
iOS-Schlüssel `aps-environment` und `com.apple.developer.siri` still weg (kein Signierfehler). Der macOS-Schlüssel heißt
`com.apple.developer.aps-environment` (Apple DTS, Forum 799000; Doku `bundleresources/entitlements/aps-environment`).
Folge heute: Der Mac hört CloudKit-Änderungen anderer Geräte erst beim nächsten Start/Abruf (passt zu „Mac per iCloud
verzögert“, #932).

## Related Files
| File | Relevance |
|------|-----------|
| `project.yml` (Ziel `LooseEnds`, `entitlements.properties`, Z. 49–75) | eine gemeinsame Datei für iOS und macOS (`supportedDestinations: [iOS, macOS]`); hier kommt der Mac-Schlüssel hinzu |
| `LooseEnds/LooseEnds.entitlements` | Abbild, von `generate` geschrieben; `scripts/test_entitlements_sync.py` vergleicht |
| `.github/workflows/testflight.yml` Z. 531–535 | Mac-Archivprüfung: Schleife über Pflicht-Schlüssel (`codesign -d --entitlements`); hier `com.apple.developer.aps-environment` ergänzen |
| `.github/workflows/testflight.yml` Z. 217–230 | iOS-Prüfung `entitled …`; `aps-environment` muss bleiben |
| `scripts/mac_ci_entitlements.py` | Ad-hoc-Signatur der Mac-CI filtert `com.apple.developer.*` und `aps-environment` → Mac Gallery/Klicktests unberührt |
| `scripts/test_aps_environment.py` | Wächter aus S5c-2b (Muster für einen Test der Mac-Prüfzeile) |
| `docs/reference/testflight.md` | beschreibt die Archivprüfungen |

## Existing Patterns
- Berechtigungen nur in `project.yml` (#311); Abbild-Datei wird mit `generate` geschrieben, Wächter `test_entitlements_sync.py`.
- Archivprüfung je Plattform in `testflight.yml`, Fehler stoppt den Upload (`fail=1`).
- Plattformabhängige Werte bisher ohne `[sdk=…]`-Bedingung für Entitlements; `[sdk=macosx*]` nur bei Test-Host-Settings.

## Recherche (2026-11-19)
- Apple DTS (Forum 799000, Quinn): „`aps-environment` (`com.apple.developer.aps-environment` on macOS)“.
- Forum 683199 (Nutzerbericht 2021, CoreDataCloudKitDemo, multiplatform): beide Schlüssel in einer Datei → Signierfehler
  „Provisioning profile … doesn't include the aps-environment entitlement“ auf der Plattform, deren Profil den Schlüssel
  nicht hat; Umgehung: getrennte Dateien. Kein DTS-Kommentar.
- Forum 763093 (Quinn, App-Gruppen, multiplatform): Empfehlung „conditional `.entitlements` file build setting“.
- Blog Iconfactory (Wallaroo Teil 3): Mac braucht `com.apple.developer.aps-environment` zusätzlich, danach lief es.
- Widerspruch zum eigenen Befund: Unser Mac-Archiv (Cloud-Signierung, `-allowProvisioningUpdates`) ließ den fremden
  iOS-Schlüssel still weg statt zu scheitern. Ob das iOS-Archiv den fremden Mac-Schlüssel ebenso still weglässt, ist
  ungeklärt und nur mit einem TestFlight-Lauf zu belegen.

## Analysis

### Type
Feature (#795 Schnitt 5c-2b2, Bau-/CI-Schnitt ohne App-Code)

### Technical Approach (Empfehlung: A)
**A: gemeinsamer Schlüssel.** `com.apple.developer.aps-environment: development` in `entitlements.properties` des App-Ziels
(Abbild per `generate`), Mac-Archivprüfung verlangt den Schlüssel, iOS-Prüfung bleibt (verlangt `aps-environment`).
Wert `development`: der Export setzt `production`, wie bei iOS. Eine Datei, keine neue Mechanik; passt zum beobachteten
Verhalten (Xcode lässt den Fremdschlüssel weg). Nachweis nach Merge: ein TestFlight-Lauf mit beiden Prüfzeilen grün.
Bricht das iOS-Archiv daran, stoppt der Lauf vor dem Upload, nichts erreicht Henning, und es folgt B.

### Alternativen
- **B: getrennte Entitlements-Datei für macOS** (`CODE_SIGN_ENTITLEMENTS[sdk=macosx*]: LooseEnds/LooseEnds-macOS.entitlements`),
  DTS-Muster aus 763093. Sauber gegen iOS-Rückwirkung, aber zweite Datei, die XcodeGen nicht aus `entitlements.properties`
  schreibt → `test_entitlements_sync.py`, `mac_ci_entitlements.py` und die Regel „Berechtigungen nur in project.yml“ (#311)
  müssten erweitert werden; doppelte Pflege aller übrigen Schlüssel. Nur falls A das iOS-Archiv bricht.
- **C: Mac ohne Push lassen, Mac pollt** (Takt über `ClaudeSyncTrigger` beim Aktivwerden, wie heute) — kippt die
  PO-Entscheidung vom 2026-11-13 (echter Weckruf) für den Mac; CloudKit-Verzögerung am Mac bliebe.

### Scope Assessment
- Files: `project.yml`, `LooseEnds/LooseEnds.entitlements`, `.github/workflows/testflight.yml`, `scripts/test_aps_environment.py` (+ Doku `docs/reference/testflight.md`, `CLAUDE.md`)
- Estimated LoC: +30–50
- Risk Level: HIGH (Signierung; Geräteliste: `project.yml`, `*.entitlements`)

### Risks & Considerations
- iOS-Archiv könnte den Mac-Schlüssel nicht still weglassen → Lauf rot vor Upload (Fallback B).
- Mac-Archiv: Das App-ID-Profil muss Push für macOS enthalten; die App-ID hat Push (iOS nutzt es). Cloud-Signierung legt das
  Mac-Profil selbst an. Fehlt es, Lauf rot vor Upload.
- Lokale signierte Mac-Bauten (`mac-schema-init`, `sim.sh mac` mit Prüfbau-Kennung) laufen mit Entwicklungsprofil:
  `-allowProvisioningUpdates` muss die Fähigkeit nachziehen; sonst Registrierungslauf. Nur auf Hennings Wort relevant.
- Simulator-Bau unsigniert (`CODE_SIGNING_ALLOWED=NO`), Mac-CI ad hoc mit Filter → unberührt.
- Watch und Widgets: nicht betroffen (Watch hat eigenes `aps-environment`, Widgets kein Push).
- Stufe 3: Pfade der Geräteliste berührt; Gerätepunkt = TestFlight-Archivbeleg (beide Prüfzeilen), sichtbare Wirkung erst mit S5c-2a.

### Dependencies
- Upstream: Cloud-Signierung in `testflight.yml`, App-ID `com.henning.looseends` mit Push-Fähigkeit.
- Downstream: S5c-2a (Delegates, Token-Meldung am Mac), CloudKit-Pushes am Mac.

### Open Questions
- keine an den PO (reine Technik, Ziel unverändert).

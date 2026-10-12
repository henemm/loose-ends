# Context: fix-311-kvstore-entitlement

## Request Summary
Der Abgleich der Mitteilungs-Uhrzeit zwischen den Geräten (#311, Prüfschritt 3) braucht den Schlüssel
`com.apple.developer.ubiquity-kvstore-identifier`. Er steht seit c846dcf (#313) in der eingecheckten
`LooseEnds/LooseEnds.entitlements`, aber nicht in `project.yml`. Jedes `xcodegen generate` — also auch der
TestFlight-Workflow (`.github/workflows/testflight.yml`, Schritt „Generate project“) — entfernt ihn.

## Befund (reproduziert, 2026-10-12)
- `./scripts/sim.sh generate` auf einem frischen Stand von main: `git diff LooseEnds/LooseEnds.entitlements`
  zeigt genau die zwei Zeilen des Schlüssels als gelöscht.
- Der TestFlight-Workflow generiert vor dem Archiv; sein Prüfschritt „Verify the archive“ kennt keine
  Berechtigungen. Daraus folgt (nicht am Archiv geprüft): kein TestFlight-Bau seit Build 29 trägt den Schlüssel.
- Henning-Checkout: `M LooseEnds/LooseEnds.entitlements` im Status — dieselbe Ursache.
- Quellen: XcodeGen schreibt die Berechtigungsdatei aus `entitlements.properties` neu (project.yml ist die
  Quelle); Apple-Forum zum Key-Value-Speicher: ohne gültigen Schlüssel kein Abgleich
  (https://developer.apple.com/forums/thread/741162).

## Related Files
| File | Relevance |
|------|-----------|
| `project.yml` (Ziel LooseEnds, `entitlements.properties`, Z. 47–59) | trägt den Schlüssel nicht; hier gehört er hin |
| `LooseEnds/LooseEnds.entitlements` | erzeugte, aber eingecheckte Datei; wird bei `generate` neu geschrieben |
| `LooseEnds/Notifications/DueNotificationCenter.swift` (Z. 39, 59–63, 250–256) | einziger Nutzer von `NSUbiquitousKeyValueStore` (`reminderTime`, `takeCloudTime`) |
| `.github/workflows/testflight.yml` (Z. 58–59 generate, 75–90 archive, 94–161 Prüfschritt) | baut aus `project.yml`; Prüfschritt ohne Berechtigungsprüfung |
| `docs/context/feat-311-mitteilung-faelligkeitszeit.md` (Z. 32, 57–60) | ursprüngliche Entscheidung: KVS, Alternative SwiftData-Einstellungsdatensatz |
| `scripts/sim.sh` | `generate`, `device-build`, `mac-schema-init`, `mac` bauen ebenfalls aus `project.yml` |

## Existing Patterns
- Berechtigungen der Ziele stehen in `project.yml` unter `entitlements.properties`; die `.entitlements`-Dateien
  sind erzeugt, aber versioniert (Widget, Share, Watch genauso).
- #312/#307: Der CI-Schlüssel (cloud-managed signing) konnte dem **Widget** die neue iCloud-Fähigkeit nicht
  hinzufügen („No profiles for 'com.henning.looseends.widgets'“, Build 26). Die Berechtigung wurde dort
  zurückgenommen. Präzedenz für das Risiko dieses Fixes.
- Prüfkennung: `BUNDLE_ID_SUFFIX` hängt an Container und App-Gruppe. Der Schlüsselwert
  `$(TeamIdentifierPrefix)$(CFBundleIdentifier)` folgt der Kennung von selbst.

## Dependencies
- Upstream: Apple Developer Portal (App ID `com.henning.looseends` hat iCloud/CloudKit; ob der
  Key-Value-Dienst dazugehört, ist **nicht belegt**), cloud-managed signing der CI.
- Downstream: Mac-App und iOS-App teilen sich dieselbe Berechtigungsdatei; Widget und Share nutzen den
  Speicher nicht und bekommen den Schlüssel nicht.

## Existing Specs
- Keine Spec zu diesem Schlüssel; Entscheidung steht im Kommentar von #311 (2026-10-10, „neue Berechtigung
  `ubiquity-kvstore-identifier`, Stufe 3 über TestFlight“) und im Context zu #311.

## Risks & Considerations
1. **Signierung (Hauptrisiko):** Ob die Cloud-Signierung der CI dem Profil der Haupt-Kennung den Schlüssel
   gibt, ist offen. Scheitert das, bricht der TestFlight-Bau ab (wie Build 26). Nachweis nur über einen
   echten Archiv-Lauf; der Lauf lädt bei Erfolg einen Bau hoch (kein Trockenlauf).
2. **Unsichtbarer Rückfall:** Ohne Prüfung im Archiv fällt der Schlüssel beim nächsten Umbau der
   `project.yml` wieder still weg. Ein Prüfschritt (`codesign -d --entitlements` auf die Haupt-App) im
   Workflow würde es sichtbar machen.
3. **Alternative ohne Berechtigung:** Einstellung als Datensatz im vorhandenen Datenmodell (CloudKit
   Production ist additiv; Modelländerung → `mac-schema-init` + Deploy). Größer, kippt die Entscheidung vom
   2026-10-10.
4. **Geräteliste:** `project.yml`, `*.entitlements` → Stufe 3 über TestFlight. Nichts auf Hennings Geräten
   ohne „jetzt ist ein Test möglich“.
5. **Der Nachweis der Funktion** (Abgleich iPhone ↔ Mac) braucht zwei Geräte; kein Simulatornachweis möglich.

## Analysis

### Type
Bug (Konfigurationsabweichung zwischen eingecheckter und erzeugter Berechtigungsdatei), Verschlechterung ist
nicht belegt: der Abgleich der Uhrzeit wurde nie bestätigt (Prüfschritt 3 in #311 steht offen).

### Ursache (belegt)
`project.yml` (Ziel LooseEnds, `entitlements.properties`, Z. 49–59) kennt den Schlüssel
`com.apple.developer.ubiquity-kvstore-identifier` nicht. `LooseEnds/LooseEnds.entitlements` wird von jedem
`xcodegen generate` aus `project.yml` neu geschrieben (reproduziert: `git diff` nach `./scripts/sim.sh generate`
entfernt genau diesen Schlüssel, sonst ändert sich nichts). Der TestFlight-Workflow generiert vor dem Archiv
(`testflight.yml` Z. 58–59), der Prüfschritt danach prüft keine Berechtigungen.

### Signierrisiko (Hauptrisiko aus dem Kontext) — geklärt
Die lokal abgelegten Xcode-Profile für `com.henning.looseends` (iOS und Mac) enthalten bereits
`com.apple.developer.ubiquity-kvstore-identifier = XK87E2B3VR.*`; die Profile des Widgets (ohne iCloud) nicht.
Der Schlüssel hängt also an der iCloud-Fähigkeit der Haupt-Kennung, die schon besteht. Die CI muss keine neue
Fähigkeit vergeben (im Unterschied zu #312, wo das Widget iCloud neu bekommen sollte). Nicht belegt: das
App-Store-Profil, das die Cloud-Signierung beim Archiv erzeugt — es liegt nicht lokal. Nachweis: Prüfung des
Archivs im Workflow (s. u.) und der erste TestFlight-Lauf.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `project.yml` | MODIFY | Schlüssel unter `entitlements.properties` des Ziels LooseEnds (`$(TeamIdentifierPrefix)$(CFBundleIdentifier)`) |
| `scripts/test_entitlements_sync.py` | CREATE | Skripttest (läuft in der CI im Schritt „Script tests“, ohne Xcode): `project.yml` gegen die eingecheckten `.entitlements`-Dateien. Ersetzt den zuerst erwogenen `git diff`-Schritt in `ci.yml` (Spec, Alternativen) |
| `.github/workflows/testflight.yml` | MODIFY | Prüfschritt: `codesign -d --entitlements` auf die Haupt-App im Archiv, Schlüssel muss vorhanden sein |

`LooseEnds/LooseEnds.entitlements` bleibt unverändert (erzeugte Datei entspricht danach der eingecheckten).

### Scope Assessment
- Files: 3
- Estimated LoC: +25/-0
- Risk Level: MEDIUM (Signierung des TestFlight-Baus; Gerätelistenpfade `project.yml`, `*.entitlements`)

### Technical Approach
Schlüssel in `project.yml` eintragen; zwei Prüfungen, die das Wegfallen künftig sichtbar machen (CI-Abgleich
erzeugt gegen eingecheckt; Berechtigungen im Archiv). RED-Nachweis: Der CI-Abgleich schlägt auf dem
heutigen `main` fehl (reproduziert), nach dem Eintrag nicht mehr.

### Alternativen (bewertet)
1. **Schlüssel in `project.yml` (empfohlen):** kleinster Schnitt, ein Eintrag, belegte Ursache.
2. **Erzeugte Berechtigungsdateien nicht mehr einchecken** (`.gitignore`): beseitigt die Klasse „zwei Quellen“
   ganz, fasst aber vier Berechtigungs- und mehrere Info-Dateien an; Hooks und Skripte, die sie lesen, müssten
   geprüft werden. Als Folge-Ticket denkbar, nicht Teil dieses Fixes.
3. **Einstellung als Datensatz im Datenmodell statt Key-Value-Speicher:** keine Berechtigung nötig, aber
   Schemaänderung in CloudKit Production (additiv, `mac-schema-init` + Deploy) und kippt die Entscheidung vom
   2026-10-10 (Key-Value, neue Berechtigung). Nur nötig, falls das App-Store-Profil den Schlüssel verweigert.
4. **Nur lokal je Gerät, ohne Abgleich:** kippt die Festlegung „auf allen Geräten gleich“. Verworfen.

### Dependencies
Wie im Kontext. Zusätzlich: Mac-Bau (`sim.sh mac`, `mac-schema-init`) bekommt den Schlüssel ebenfalls; das Mac-Profil
enthält ihn bereits.

### Geräte-/Abnahmestufe
Stufe 3 über TestFlight (Henning, erst nach seinem wörtlichen „jetzt ist ein Test möglich“): Uhrzeit auf dem
iPhone ändern, auf dem zweiten Gerät erscheint dieselbe Uhrzeit (#311 Schritt 3).

### Open Questions
- [ ] Keine für den PO. Technisch offen bis zum ersten Lauf: nimmt das Cloud-signierte App-Store-Profil den Schlüssel auf
  (Rückfall: Alternative 3).

---
entity_id: fix-174-testflight-ios27
type: bugfix
created: 2026-10-03
updated: 2026-10-03
status: draft
workflow: fix-174-testflight-ios27
---

# Spec: #174 — TestFlight-Build wieder herstellen: iOS-27-Stand, alle Ziele, wiederholbarer Weg

## Approval

- [ ] Approved

## Purpose

Der letzte TestFlight-Lauf war am 2026-09-19. Der Workflow `testflight.yml` läuft auf dem
Standard-Image `macos-26`, das kein Xcode 27 enthält. Bei fehlendem Xcode 27 senkt er die
Deployment-Ziele in `project.yml` still auf 26.0 und baut gegen das iOS-26.6-SDK. Eine so gebaute
Fassung verhält sich nicht wie die aus Xcode 27 gestartete (SDK-gebundenes Verhalten von SwiftUI,
SwiftData, FoundationModels). #174 verlangt einen TestFlight-Build mit heutigem Stand auf
iOS-27-Basis über einen wiederholbaren, dokumentierten Weg. Diese Spec stellt den Workflow auf das
Xcode-27-Image um, wählt Xcode 27.0 fest, entfernt die stille Absenkung und prüft das Archiv vor dem
Upload maschinell: iOS-27-Stand, Versionsnummer, Symbole und Datenschutzangaben aller vier Ziele.
Es ändert sich kein Produktcode und nichts Sichtbares in der App.

## Source

- **File:** `.github/workflows/testflight.yml`
- **Identifier:** `runs-on: macos-26` (Zeile 20); Schritt „Select newest Xcode (27 when the image has it)" (Zeile 38–47) mit `sed`-Absenkung (Zeile 44); Build-Nummer `CURRENT_PROJECT_VERSION="${{ github.run_number }}"` (Zeile 75)
- **File:** `docs/reference/testflight.md`
- **Identifier:** Abschnitt „5. Build starten" (Zeile 75–82), Abschnitt „Was der Workflow tut" (Zeile 103–109)
- **File:** `project.yml`
- **Identifier:** `deploymentTarget` (Zeile 6–9: iOS/macOS/watchOS 27.0), Ziele `LooseEnds` (Bundle-ID `com.henning.looseends$(BUNDLE_ID_SUFFIX)`), `LooseEndsWatch` (`….watchkitapp`), `LooseEndsWidgets` (`….widgets`), `LooseEndsShare` (`….share`); nur gelesen, nicht geändert

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| GitHub-Runner-Image `xcode-27` (Vorschau) | tooling | Liefert Xcode 27.0 (27A266a), iOS-27.0-SDK, watchOS-27.0-SDK |
| App-Store-Connect-API-Schlüssel (Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`, `APPLE_TEAM_ID`) | tooling | Cloud-Signierung, Upload, Abfrage der Builds |
| XcodeGen (`brew install xcodegen`) | tooling | Erzeugt das Projekt im Lauf |
| `plutil` (macOS) | tooling | Liest `DTSDKName` und `MinimumOSVersion` aus den Info.plist im Archiv |
| #176 | issue | Nutzer-Abnahme der TestFlight-Fassung; abgegrenzt |
| #177 | issue | Privacy-Manifest für alle Ziele; abgegrenzt (für TestFlight keine Pflicht) |
| #178 | issue | `ci.yml` auf Xcode 27 umstellen, gleiche Ursache, anderes Ziel; abgegrenzt |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `.github/workflows/testflight.yml` | MODIFY | `runs-on: xcode-27`; Xcode fest auf `/Applications/Xcode_27.app`, Versionsprüfung mit Abbruch; `sed`-Absenkung ersatzlos entfernt; neuer Schritt „Verify the archive is built against the iOS 27 SDK" nach „Archive", vor „Write export options" bzw. Upload |
| `docs/reference/testflight.md` | MODIFY | Runner-Label, fest gewählte Xcode-Version, Nachweisschritt, Vorgehen bei Wegfall oder Umbenennung des Vorschau-Labels, lokaler Notweg, Prüfung der Annahme per API |

### Estimated Changes

- Files: 2
- LoC: ca. +110/-10 (Nachweis-Block ~50 Zeilen, Xcode-Wahl ~8, Doku ~45)
- Kein Produktcode. Keine neuen Abhängigkeiten, keine neuen Berechtigungen, keine AppStorage-Schlüssel, keine Audiodateien, keine Änderung an `project.yml`, Entitlements oder Info.plist.

## Definition of Done

- [ ] Alter Zustand belegt: Zeile „deployment targets lowered to 26.0" und Xcode-Version aus dem Protokoll des alten TestFlight-Laufs 35434941080 (bzw. 37108095080) zitiert (AC-1)
- [ ] Nachweisschritt einmal rot gesehen gegen ein absichtlich falsches Archiv, danach grün gegen ein richtiges (AC-2)
- [ ] Nachweisschritt grün gegen ein echtes, lokal unsigniert gebautes Xcode-27.0-Archiv (AC-12)
- [ ] Versionsnummer, Symbole und Datenschutzangaben aller Ziele im Archiv geprüft (AC-5)
- [ ] `testflight.yml` ohne `sed`-Absenkung, mit `runs-on: xcode-27` und fest gewähltem Xcode 27.0 (AC-3, AC-4)
- [ ] Archiv-Lauf mit heutigem Stand grün, Build erscheint in App Store Connect → TestFlight (AC-6, AC-7)
- [ ] Beleg, dass die iOS-27-Pfade im Build aktiv sind und nicht auf 26.0 abgesenkt wurden (AC-5)
- [ ] Vorgehen in `docs/reference/testflight.md` aktualisiert (AC-8)
- [ ] Kein Produktcode geändert (AC-9)

## Implementation Details

### Ausgangslage mit Beleg

CI-Lauf 37108095080 (2026-10-03, Image `macos-26-arm64` 20260907.0351.1) meldet „No Xcode 27 on
this image: deployment targets lowered to 26.0" und `Xcode 26.6 / 17F113`. `testflight.yml` hat
denselben Zweig (Zeile 38–47) auf demselben Image-Label. Das Label `macos-26` trägt Xcode 26.0.1
bis 26.6. Xcode 27 gibt es nur im eigenen Image `xcode-27` (Vorschau). Dort liegt `Xcode_27.app` =
27.0 (27A266a, Standard), außerdem `Xcode_27.1_beta.app` und `Xcode_27.2_beta.app`. Die bisherige
Auswahl `ls -d /Applications/Xcode_27*.app | sort -V | tail -1` würde auf diesem Image die
27.2-Beta nehmen. Ein bloßer Labelwechsel genügt deshalb nicht.

### Änderung 1 — Image und Xcode

```yaml
runs-on: xcode-27
```

Der Schritt „Select newest Xcode" wird ersetzt durch „Select Xcode 27.0":

```yaml
- name: Select Xcode 27.0
  run: |
    sudo xcode-select -s /Applications/Xcode_27.app
    xcodebuild -version
    version=$(xcodebuild -version | sed -n 1p)   # sed liest bis zum Ende: kein SIGPIPE unter pipefail
    if [ "$version" != "Xcode 27.0" ]; then
      echo "::error::Expected Xcode 27.0 at /Applications/Xcode_27.app, got: $version. Not building an older or beta toolchain. See docs/reference/testflight.md"
      exit 1
    fi
```

Geprüft wird nur „Xcode 27.0". Die Build-Kennung (27A266a) wird protokolliert, aber nicht
verglichen, damit ein Image-Update auf 27.0.x nicht unnötig bricht. Der `sed`-Zweig auf 26.0
entfällt ersatzlos. Ohne Xcode 27.0 bricht der Lauf mit klarer Meldung ab, statt still eine
26er-Fassung zu bauen.

### Änderung 2 — Nachweisschritt im Archiv

Neuer Schritt nach „Archive", vor dem Upload. Er sucht die eingebetteten Bundles im Archiv, rät
keinen festen Pfad, identifiziert die vier erwarteten Ziele über ihre Bundle-Kennung aus
`project.yml` und prüft je Ziel, was das Issue verlangt:

- **iOS-27-Stand:** `DTSDKName` (SDK, gegen das gelinkt wurde) und `MinimumOSVersion`
- **Versionsnummer:** `CFBundleShortVersionString` = `0.1.0` (`MARKETING_VERSION`, project.yml Z. 24)
  und `CFBundleVersion` = Build-Nummer des Laufs (`github.run_number`), in allen vier Zielen gleich
  (App Store Connect lehnt abweichende Nummern in eingebetteten Zielen ab)
- **Symbole:** je Ziel ein `dSYMs/<Bundlename>.dSYM` im Archiv; hochgeladen werden sie über
  `uploadSymbols` in den Export-Optionen (besteht schon)
- **Datenschutzangaben:** die Zweckbeschreibungen aus project.yml (Z. 80–82, 120–121) sind im
  gebauten Bundle vorhanden und nicht leer; `ITSAppUsesNonExemptEncryption` = `false` (Z. 74)

Erwartung, Kennungen mit leerem `BUNDLE_ID_SUFFIX`:

| Ziel | `CFBundleIdentifier` | `DTSDKName` beginnt mit | `MinimumOSVersion` | Pflichtschlüssel |
|------|----------------------|-------------------------|--------------------|------------------|
| LooseEnds (App) | `com.henning.looseends` | `iphoneos27.` | `27.0` | `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSCalendarsFullAccessUsageDescription`, `ITSAppUsesNonExemptEncryption=false` |
| LooseEndsWatch (Watch-App) | `com.henning.looseends.watchkitapp` | `watchos27.` | `27.0` | `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` |
| LooseEndsWidgets (Erweiterung) | `com.henning.looseends.widgets` | `iphoneos27.` | `27.0` | – |
| LooseEndsShare (Erweiterung) | `com.henning.looseends.share` | `iphoneos27.` | `27.0` | – |

Die Logik steht als Shell-Block im Workflow (Schritt-Umgebung `BUILD: ${{ github.run_number }}`)
und nimmt Archivpfad und Build-Nummer aus den Variablen `ARCHIVE` (Vorgabe
`build/LooseEnds.xcarchive`) und `BUILD`, damit sie lokal gegen ein Verzeichnis lauffähig ist und
aus dem Workflow-Schritt 1:1 kopiert werden kann:

```bash
ARCHIVE="${ARCHIVE:-build/LooseEnds.xcarchive}"
BUILD="${BUILD:?BUILD (build number) must be set}"
MARKETING="0.1.0"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
APPS="$ARCHIVE/Products/Applications"
[ -d "$APPS" ] || { echo "::error::No Products/Applications in $ARCHIVE"; exit 1; }
fail=0
{
  echo "| Ziel | Bundle | DTSDKName | Minimum | Version | dSYM | Ergebnis |"
  echo "|------|--------|-----------|---------|---------|------|----------|"
} >> "$SUMMARY"
get() { plutil -extract "$1" raw "$2" 2>/dev/null || true; }
check() { # Bundle-Kennung, SDK-Präfix, Pflichtschlüssel (Schlüssel oder Schlüssel=Wert) ...
  local id="$1" sdk="$2" p found="" name mini ver dsym res=OK key want have
  shift 2
  while IFS= read -r bundle; do
    [ "$(get CFBundleIdentifier "$bundle/Info.plist")" = "$id" ] && { found="$bundle"; break; }
  done < <(find "$APPS" \( -name '*.app' -o -name '*.appex' \))
  if [ -z "$found" ]; then
    echo "| $id | fehlt im Archiv | - | - | - | - | FEHLER |" >> "$SUMMARY"
    echo "::error::Target $id not found in the archive"; fail=1; return
  fi
  p="$found/Info.plist"
  name=$(get DTSDKName "$p"); mini=$(get MinimumOSVersion "$p")
  ver="$(get CFBundleShortVersionString "$p") ($(get CFBundleVersion "$p"))"
  dsym=da; [ -d "$ARCHIVE/dSYMs/$(basename "$found").dSYM" ] || dsym=fehlt
  case "$name" in "$sdk"*) ;; *) res=FEHLER; echo "::error::$id linked against '$name', expected $sdk*" ;; esac
  [ "$mini" = "27.0" ] || { res=FEHLER; echo "::error::$id minimum '$mini', expected 27.0"; }
  [ "$ver" = "$MARKETING ($BUILD)" ] || { res=FEHLER; echo "::error::$id version '$ver', expected $MARKETING ($BUILD)"; }
  [ "$dsym" = da ] || { res=FEHLER; echo "::error::$id has no dSYM in the archive"; }
  for key in "$@"; do
    want=""; [ "${key#*=}" != "$key" ] && { want="${key#*=}"; key="${key%%=*}"; }
    have=$(get "$key" "$p")
    if [ -z "$have" ] || { [ -n "$want" ] && [ "$have" != "$want" ]; }; then
      res=FEHLER; echo "::error::$id: $key is '$have'${want:+, expected $want}"
    fi
  done
  echo "| $id | ${found#$APPS/} | $name | $mini | $ver | $dsym | $res |" >> "$SUMMARY"
  [ "$res" = OK ] || fail=1
}
check com.henning.looseends iphoneos27. NSMicrophoneUsageDescription NSSpeechRecognitionUsageDescription \
  NSCalendarsFullAccessUsageDescription ITSAppUsesNonExemptEncryption=false
check com.henning.looseends.watchkitapp watchos27. NSMicrophoneUsageDescription NSSpeechRecognitionUsageDescription
check com.henning.looseends.widgets iphoneos27.
check com.henning.looseends.share iphoneos27.
[ "$fail" = 0 ]
```

`find` sucht alle `*.app` und `*.appex` unter `Products/Applications/` (die Watch-App und die
Erweiterungen liegen eingebettet in der App, der genaue Unterpfad wird nicht vorausgesetzt). Jede
Abweichung bricht den Schritt ab; der Upload läuft dann nicht. Die Tabelle landet in
`$GITHUB_STEP_SUMMARY` und ist damit in jedem künftigen Lauf der Beleg für „nicht auf 26.0
abgesenkt", Versionsnummer, Symbole und Datenschutzangaben.

**Gegenprobe an einem echten Archiv vor dem Merge:** Die Schreibweisen (`DTSDKName` der Watch-App,
dSYM-Namen) werden nicht geraten, sondern an einem lokalen, unsignierten Archiv mit Xcode 27.0
belegt: `xcodebuild archive … CODE_SIGNING_ALLOWED=NO CURRENT_PROJECT_VERSION=<Nummer>` in einer
Wegwerf-Kopie, ohne `-allowProvisioningUpdates` und ohne Schlüssel — der Lauf spricht nicht mit
Apple und berührt Hennings Xcode-Anmeldung nicht (#156). Der Nachweis-Block läuft mit
`ARCHIVE=<Pfad> BUILD=<Nummer>` dagegen. Weicht ein Wert in der Schreibweise ab, wird das Muster
nach dem Wert im Archiv korrigiert, nicht umgekehrt. Dieser lokale Lauf dient nur der Prüfung des
Blocks; er lädt nichts hoch.

### Änderung 3 — Build-Nummer und Lauf

Die Build-Nummer bleibt `github.run_number`. Sie zählt je Workflow monoton und liegt über dem Lauf
vom 2026-09-19. Der Lauf wird per `workflow_dispatch` aus dem gemergten `main`-Stand gestartet,
erst nach dem Merge. Der Upload wirkt nach außen: Der Build landet bei der internen Gruppe „Familie"
auf Hennings Gerät. Deshalb kein Probelauf mit Upload vor dem Merge.

Annahme des Builds wird auf zwei Wegen belegt:

1. Lauf-Protokoll des Schritts „Upload to TestFlight": „EXPORT SUCCEEDED" bzw. „Upload succeeded".
2. App-Store-Connect-API, Abfrage der Builds der App (mit dem ASC-Schlüssel, Endpunkt `GET /v1/builds`
   gefiltert nach App und `version`): Build-Nummer und `processingState` werden im Bericht zitiert.

### Änderung 4 — Dokumentation

`docs/reference/testflight.md`:

- „Was der Workflow tut": Runner-Label `xcode-27`, Xcode 27.0 fest gewählt (kein „neuestes"), keine
  Absenkung mehr, Nachweisschritt mit Tabelle in der Zusammenfassung des Laufs.
- „5. Build starten": Hinweis, dass der Lauf mit klarer Meldung abbricht, wenn Xcode 27.0 fehlt.
- Neuer Abschnitt „Wenn das Vorschau-Image wegfällt oder umbenannt wird": Das Label `xcode-27` ist
  eine Vorschau. Fällt es weg oder wird umbenannt, schlägt der Lauf beim Start fehl (kein Runner).
  Vorgehen: in den Runner-Images (README, Abschnitt Xcode 27) das neue Label nachschlagen, in
  `testflight.yml` `runs-on` anpassen, Lauf neu starten. Hat `macos-26` oder ein Nachfolger Xcode 27.0
  als Standard, wechselt das Label dorthin. Die Versionsprüfung und der Nachweisschritt bleiben.
- Neuer Abschnitt „Notweg: lokaler Archiv-Lauf": auf Hennings Mac mit Xcode 27.0, ausschließlich mit
  eigenem ASC-Schlüssel (`-authenticationKeyPath`), nie mit der Anmeldung in Xcode (#156). Die
  Build-Nummer muss über der letzten CI-Nummer liegen, sonst lehnt App Store Connect den Upload als
  Dublette ab. Der Nachweisschritt-Block läuft lokal mit `ARCHIVE=<Pfad>` gegen das Archiv.
- Abschnitt „Wenn es hakt": Eintrag „Lauf bricht mit ‚Expected Xcode 27.0' ab".

### Vorgehen: Reproduktion zuerst (Hennings Regel)

1. **RED vorher:** Aus dem Protokoll des alten TestFlight-Laufs 35434941080 (2026-09-19) die Zeilen
   „No Xcode 27 on this image: deployment targets lowered to 26.0 for this build." und
   `xcodebuild -version` zitieren (`gh run view 35434941080 --log`). Ist das Protokoll abgelaufen,
   dieselben Zeilen aus CI-Lauf 37108095080 zitieren (gleiche Absenkungslogik, Xcode 26.6).
2. **RED Nachweisschritt:** In einer Wegwerf-Kopie im Scratchpad ein Archiv-Fixture bauen
   (`Products/Applications/LooseEnds.app/Info.plist`, je eine Info.plist für Watch, Widgets,
   Share mit den erwarteten Kennungen, dazu `dSYMs/<Bundlename>.dSYM`-Verzeichnisse). Rote
   Fixtures, je eines pro Fehlerart, jedes muss mit Exit-Code 1, passender `::error::`-Zeile und
   „FEHLER" in der Tabelle abbrechen: (a) `DTSDKName` = `iphoneos26.6`, `MinimumOSVersion` = `26.0`;
   (b) Share-Erweiterung fehlt („not found in the archive"); (c) Widgets mit `CFBundleVersion`
   ungleich `BUILD`; (d) dSYM der Watch-App fehlt; (e) App ohne `NSMicrophoneUsageDescription`;
   (f) `ITSAppUsesNonExemptEncryption` = `true`.
3. **GREEN Nachweisschritt:** Fixture mit `iphoneos27.0`/`watchos27.0`, `27.0`, `0.1.0 (BUILD)`,
   allen dSYMs und Pflichtschlüsseln: Exit-Code 0, alle Zeilen „OK".
4. **Gegenprobe echtes Archiv:** lokales unsigniertes Archiv mit Xcode 27.0 (siehe Änderung 2),
   Block grün, Tabelle im Bericht zitiert.
5. Änderungen in `testflight.yml` und Doku, Syntaxprüfung des Workflows (YAML parsebar),
   Schrittblock per `bash -n` geprüft.
6. Nach Freigabe und Merge: Lauf per `workflow_dispatch`, Tabelle aus der Zusammenfassung und
   API-Abfrage zitieren.

### Alternativen

- **Lokaler Archiv-Lauf auf Hennings Mac** (Xcode 27.0, eigener ASC-Schlüssel, nie seine
  Xcode-Anmeldung, #156) als Hauptweg: keine Abhängigkeit vom Vorschau-Image, aber an seinen Mac
  gebunden, nicht per Tag auslösbar, Schlüssel muss lokal liegen, Build-Nummern müssen mit der CI
  abgestimmt werden. Taugt als dokumentierter Notweg (Änderung 4), nicht als Hauptweg.
- **Absenkung belassen** und nur belegen, dass der Unterschied nicht verhaltensrelevant ist.
  Verworfen: Das Linken gegen das 26.6-SDK ändert SDK-gebundenes Verhalten, und die DoD des Issues
  verlangt ausdrücklich eine 27er-Fassung. Im Code gibt es zudem keine `#available(iOS 27…)`-Pfade,
  die der Unterschied sichtbar machen würde; der Beleg über Verhalten wäre also nur schwer zu führen.
- **Neueste Xcode-Version zulassen** (27.2-Beta, wie die bisherige Auswahl es täte). Verworfen: App
  Store Connect nimmt sie für TestFlight zwar an, sie entspricht aber nicht Hennings Xcode 27.0, und
  Beta-Werkzeuge sind keine Grundlage für eine Fassung, die sich wie die aus Xcode verhält.
- **Fällt das Vorschau-Label `xcode-27` weg oder wird umbenannt:** Label nachziehen, siehe
  Dokumentation (Änderung 4); notfalls der lokale Notweg.

### Abgegrenzt (eigene Tickets, anderes Ziel)

- #177 Privacy-Manifest für alle Ziele (Pflicht erst bei der App-Store-Einreichung; für TestFlight
  nur Warnmail, der Upload vom 2026-09-19 mit denselben `UserDefaults`-Stellen ging durch)
- #178 `ci.yml` (drei Jobs) auf Xcode 27 umstellen
- #176 Nutzer-Abnahme der TestFlight-Fassung

### Nicht belegt und offen

- Ob das Vorschau-Image Wartezeiten bei der Runner-Zuteilung hat, zeigt erst der Lauf.
- Das Image-Readme nennt `xcodegen` nicht; der Schritt `brew install xcodegen` bleibt. Schlägt er auf
  dem Vorschau-Image fehl, ist das ein neuer Befund mit eigener Analyse.
- Die Schreibweisen von Watch-`DTSDKName` und dSYM-Namen sind erst an der Gegenprobe mit dem
  lokalen Archiv belegt (Änderung 2); bis dahin sind sie Annahme.
- Ein unsigniertes Archiv kann sich vom signierten CI-Archiv in Signaturdaten unterscheiden; die
  geprüften Info.plist-Schlüssel und dSYMs entstehen beim Bauen, nicht beim Signieren.

### Recherche (Quellen)

- runner-images, Readme Xcode-27-Image (`images/macos/xcode-27-arm64-Readme.md`): Xcode 27.0 (27A266a, Standard), 27.1 beta, 27.2 beta; SDKs iOS/watchOS 27.0
- runner-images README (Label-Tabelle, Zeilen 30–32): `macos-26` ohne Xcode 27; `xcode-27` / `xcode-27-xlarge` als Vorschau
- runner-images Issue #14404 (Label `xcode-27`, Basis macOS 27 seit 2026-09-16): https://github.com/actions/runner-images/issues/14404
- Release `xcode-27-arm64/20260805.0079`: https://newreleases.io/project/github/actions/runner-images/release/xcode-27-arm64%2F20260805.0079
- App Store Connect Release Notes (Xcode 27 final für App Store und TestFlight seit 2026-09-14; 27.2 beta nur TestFlight): https://developer.apple.com/help/app-store-connect/release-notes
- Apple-Forum, Privacy-Manifest / ITMS-91053 bei TestFlight nur Warnung: https://developer.apple.com/forums/thread/750057 und https://developer.apple.com/forums/thread/748355
- Xcode 27 Release, Auswirkungen des Linkens gegen das iOS-27-SDK: https://blakecrosley.com/blog/xcode-27-release

## Test Plan

Kein Produktcode, daher keine neuen Unit-Tests. Die Änderung ist Workflow-Konfiguration und
Dokumentation; nachgewiesen wird mit Reproduktion vor der Änderung, Fixture-Läufen des
Nachweisschritts und dem echten Lauf nach dem Merge.

### Automated Tests (TDD RED)

- [ ] Test 1 (RED, alter Zustand): GIVEN das Protokoll des alten TestFlight-Laufs 35434941080 (ersatzweise CI-Lauf 37108095080) WHEN die Zeilen zur Xcode-Wahl gelesen werden THEN steht dort „deployment targets lowered to 26.0" und eine Xcode-26-Version.
- [ ] Test 2 (RED, falsches SDK): GIVEN ein Archiv-Fixture, dessen Info.plist `DTSDKName` = `iphoneos26.6` und `MinimumOSVersion` = `26.0` tragen WHEN der Nachweis-Block mit `ARCHIVE=<Fixture> BUILD=<Nummer>` läuft THEN bricht er mit Exit-Code 1 und einer `::error::`-Zeile ab und die Tabelle zeigt „FEHLER".
- [ ] Test 3 (RED, fehlendes Ziel): GIVEN ein Fixture ohne Teilen-Erweiterung WHEN der Block läuft THEN bricht er mit „Target com.henning.looseends.share not found in the archive" ab.
- [ ] Test 3b (RED, Version/Symbole/Datenschutz): GIVEN je ein Fixture mit (c) Widgets-`CFBundleVersion` ≠ `BUILD`, (d) fehlendem Watch-dSYM, (e) App ohne `NSMicrophoneUsageDescription`, (f) `ITSAppUsesNonExemptEncryption` = `true` WHEN der Block läuft THEN bricht er jeweils mit Exit-Code 1 und einer `::error::`-Zeile ab, die das betroffene Ziel und den Schlüssel nennt.
- [ ] Test 4 (GREEN): GIVEN ein Fixture mit `iphoneos27.0`, `watchos27.0` für die Watch-App, `27.0`, `0.1.0 (BUILD)`, allen dSYMs und Pflichtschlüsseln WHEN der Block läuft THEN endet er mit Exit-Code 0 und alle vier Zeilen zeigen „OK".
- [ ] Test 4b (GREEN, echtes Archiv): GIVEN ein lokal mit Xcode 27.0 unsigniert gebautes Archiv (`CODE_SIGNING_ALLOWED=NO`, ohne Schlüssel, ohne `-allowProvisioningUpdates`) WHEN der Block mit dessen Pfad und Build-Nummer läuft THEN endet er mit Exit-Code 0 und alle vier Zeilen zeigen „OK".
- [ ] Test 5: GIVEN der geänderte `testflight.yml` WHEN er als YAML geparst und der Nachweis-Block mit `bash -n` geprüft wird THEN gibt es keinen Syntaxfehler, und `grep` findet weder `sed -i` noch `26.0` im Workflow.
- [ ] Test 6 (echter Lauf nach Merge): GIVEN der gemergte `main`-Stand WHEN `testflight.yml` per `workflow_dispatch` läuft THEN meldet der Schritt „Select Xcode 27.0" `Xcode 27.0`, der Nachweisschritt zeigt vier Zeilen „OK" in der Zusammenfassung, und der Upload-Schritt endet mit „EXPORT SUCCEEDED".
- [ ] Test 7: GIVEN der hochgeladene Build WHEN die App-Store-Connect-API die Builds der App liefert THEN steht dort die Build-Nummer des Laufs (`github.run_number`) mit `processingState`.

## Acceptance Criteria

- [ ] AC-1 Reproduktion: Die Zeile „deployment targets lowered to 26.0" und die Xcode-Version sind aus dem Protokoll des alten TestFlight-Laufs 35434941080 (ersatzweise 37108095080) im Bericht zitiert.
- [ ] AC-2 Nachweisschritt belegt: Der Block ist gegen jedes der sechs roten Fixtures (a)–(f) rot gesehen (Exit-Code und `::error::`-Zeile je Fixture zitiert) und gegen das richtige Fixture grün.
- [ ] AC-3 `testflight.yml` läuft auf `runs-on: xcode-27`, wählt `/Applications/Xcode_27.app` fest und bricht mit `::error::`-Meldung ab, wenn `xcodebuild -version` nicht „Xcode 27.0" meldet; die Build-Kennung wird nur protokolliert.
- [ ] AC-4 Die `sed`-Absenkung auf 26.0 ist ersatzlos entfernt; im Workflow steht kein `26.0` mehr.
- [ ] AC-5 Der Nachweisschritt steht nach „Archive" und vor dem Upload, prüft App, Watch-App, Widgets und Teilen über ihre Bundle-Kennung (`DTSDKName` mit Präfix `iphoneos27.` bzw. `watchos27.`, `MinimumOSVersion` = `27.0`, Version `0.1.0 (<github.run_number>)`, dSYM vorhanden, Datenschutz-Zweckbeschreibungen nicht leer, `ITSAppUsesNonExemptEncryption` = `false`), schreibt die Tabelle in `$GITHUB_STEP_SUMMARY` und bricht bei Abweichung oder fehlendem Ziel ab. Die Bundles werden per Suche nach `*.app`/`*.appex` unter `Products/Applications/` gefunden, nicht über einen festen Pfad. Die Tabelle des echten Laufs (vier Zeilen „OK") ist im Bericht zitiert.
- [ ] AC-6 Ein Archiv-Lauf per `workflow_dispatch` aus dem gemergten `main`-Stand ist grün; die Zeile „EXPORT SUCCEEDED" bzw. „Upload succeeded" aus dem Upload-Schritt ist im Bericht zitiert.
- [ ] AC-7 Der Build erscheint in App Store Connect → TestFlight: Build-Nummer und `processingState` aus der App-Store-Connect-API-Abfrage der Builds sind im Bericht zitiert. Die Build-Nummer (`github.run_number`) liegt über der des Laufs vom 2026-09-19.
- [ ] AC-8 `docs/reference/testflight.md` beschreibt Runner-Label, fest gewähltes Xcode, Nachweisschritt, Vorgehen bei Wegfall oder Umbenennung des Labels `xcode-27` und den lokalen Notweg (nur eigener ASC-Schlüssel, Build-Nummer über der CI-Nummer).
- [ ] AC-9 Kein Produktcode geändert: Das Diff berührt genau `.github/workflows/testflight.yml` und `docs/reference/testflight.md` (plus die Workflow-Artefakte unter `docs/`).
- [ ] AC-10 Geräteliste: Kein Pfad der Geräteliste berührt. Keine sichtbare UI-Änderung, daher keine Entwurfsvorschau.
- [ ] AC-11 Ausliefern: Nach dem Merge ist `bash ~/.claude/scripts/loose-ends-sync-main.sh` gelaufen.
- [ ] AC-12 Gegenprobe vor dem Merge: Der Block ist gegen ein lokal mit Xcode 27.0 unsigniert gebautes Archiv grün (vier Zeilen „OK", Tabelle zitiert); der Lauf nutzt weder Schlüssel noch `-allowProvisioningUpdates` und lädt nichts hoch.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Änderung an Build- und Auslieferungskonfiguration ohne Architekturwirkung; es wird keine bestehende Entscheidung gekippt, die Absenkung auf 26.0 war ein Übergangsbehelf bis zum Xcode-27-Image.
- **Rationale:** Der Regelweg (feste Toolchain plus maschinelle Prüfung der Info.plist im Archiv) ist einfacher und belastbarer als eine Zusage, dass das Image „schon Xcode 27 haben wird". Der lokale Archiv-Lauf bleibt als dokumentierter Notweg, falls das Vorschau-Image dauerhaft ausfällt; machte man ihn zum Hauptweg, wäre das eine neue Entscheidung.

## Changelog

- 2026-10-03: Initial spec created (Analyse in `docs/context/fix-174-testflight-ios27.md`).
- 2026-10-03: Nach PO-Briefing ergänzt: Nachweisschritt prüft zusätzlich Versionsnummer, Symbole und Datenschutzangaben (Teile des Issues); Gegenprobe an einem lokalen unsignierten Archiv vor dem Merge.

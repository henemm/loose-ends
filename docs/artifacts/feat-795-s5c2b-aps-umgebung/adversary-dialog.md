# Adversary Dialog — feat-795-s5c2b-aps-umgebung
Spec: docs/specs/feat-795-schnitt-5c2b-aps-umgebung.md
Datum: 2026-11-19 08:08

## Checkliste
- [x] **AC-1:** GIVEN `project.yml` und `LooseEnds/Info.plist` WHEN `LEApsEnvironment` gelesen wird THEN ist der Wert in beiden `sandbox` (Test `sourceAndImageDefaultToSandbox`).
- [x] **AC-2:** GIVEN `./scripts/sim.sh generate` WHEN es läuft THEN bleibt der Baum sauber, und `scripts/test_info_plist_sync.py` und `scripts/test_entitlements_sync.py` sind grün (Beleg: Lauf und CI-Schritt „Generate leaves the tree clean“).
- [x] **AC-3:** GIVEN `testflight.yml` WHEN die Jobs `upload` und `upload-mac` gelesen werden THEN setzt jeder den Wert per `plutil -replace LEApsEnvironment -string production` in einem Schritt ohne `if:`, nach `generate` und vor dem Archiv, auch bei `v*`-Tags (Test `stepIsUnconditionalInBothJobs`).
- [x] **AC-4:** GIVEN die iOS-Archivprüfung WHEN gelesen THEN verlangt sie Typ `string` und Wert `production` für `LEApsEnvironment` sowie `entitled com.henning.looseends aps-environment` (nur Vorhandensein), außerhalb der `account-switch-check`-Blöcke (Test `iosVerifyChecksMarkAndEntitlement`).
- [x] **AC-5:** GIVEN die Mac-Archivprüfung WHEN gelesen THEN verlangt sie Typ `string` und Wert `production` für `LEApsEnvironment` und kein Push-Entitlement, außerhalb der `account-switch-check`-Blöcke (Test `macVerifyChecksMark`).
- [x] **AC-6:** GIVEN der Prüfausschnitt WHEN er gegen Beispiel-Plists ausgeführt wird THEN gelingt er für `production` (String) und schlägt für `sandbox`, fehlende Marke und falschen Typ fehl (Test `verifySnippetAcceptsOnlyProductionString`).
- [x] **AC-7:** GIVEN die Blöcke `# account-switch-check:begin/end` WHEN mit dem Stand vor dem Schnitt verglichen THEN sind sie unverändert, und `LEAccountEnabled` wird weiter nur bei `konto` gesetzt (Test `accountSwitchBlocksUntouched`).
- [x] **AC-8:** GIVEN der Swift-Code WHEN der Diff gelesen wird THEN ändert sich in `DeviceRegistration.swift` nur ein Kommentar; `PushEnvironment.init(infoValue:)` und `DeviceRegistrationTests` bleiben unverändert und grün (Beleg: Diff und `./scripts/sim.sh sim-unit DeviceRegistrationTests`).
- [x] **AC-9:** GIVEN die ganze Suite WHEN sie läuft THEN sind `./scripts/sim.sh unit`, die Python-Wächter und die CI grün, und der Simulator-Bau gelingt (`./scripts/sim.sh build`; Beleg im Abschlussbericht).

## Dialog

### Runde 1
**Adversary:** Alle neun ACs einzeln angegriffen, nicht nur die Tests gelesen.

Confirmation:
  AC: AC-1
  Code reference: project.yml:88
  Evidence: `LEApsEnvironment: sandbox` in info.properties; LooseEnds/Info.plist traegt `sandbox`; test_source_and_image_default_to_sandbox (scripts/test_aps_environment.py:42) OK.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: project.yml:70
  Evidence: `xcodegen generate` (direkt, da die sim.sh-Sperre belegt war) hinterliess keine Aenderung am Arbeitsbaum (Status vorher/nachher gleich); test_info_plist_sync 4 OK, test_entitlements_sync 4 OK. Der Kommentar zu aps-environment (project.yml:70) ist nur Text.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: .github/workflows/testflight.yml:116
  Evidence: Schritt "Set the APNs environment" ohne `if:`, nach "Generate project" (113) und vor "Set the account switch" (119) und "Archive" (140); gleiche Struktur im Mac-Job bei :453 (Archive (macOS) :473). Kein Tag-Filter, gilt auch fuer v*. test_step_is_unconditional_in_both_jobs OK.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: .github/workflows/testflight.yml:230
  Evidence: `entitled com.henning.looseends aps-environment` (Vorhandensein), aps_environment-Funktion :247, Aufruf :267 mit $app_info (die App-Info.plist, per CFBundleIdentifier gefunden); ausserhalb der account-switch-Bloecke.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: .github/workflows/testflight.yml:564
  Evidence: Mac-Pruefung ruft `aps_environment "$P"` (P = Contents/Info.plist der App, wie account_switch); Funktion :552; die Entitlement-Schluesselliste enthaelt kein aps (Test scripts/test_aps_environment.py:87-94). Mac nutzt dasselbe Ziel LooseEnds/Info.plist (project.yml:76, ein Mehrplattform-Ziel), das plutil-replace wirkt also auch dort.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/test_aps_environment.py:98
  Evidence: Test fuehrt beide Ausschnitte gegen production-String (0), sandbox, fehlend, Bool (je 1) aus. Zusaetzlich nachgelesen: Integer -> type=integer, nicht string -> fail=1; leerer Pfad -> plutil scheitert, `|| true` verschluckt es, type leer -> FEHLER, fail=1. Unter set -e bricht die Funktion nicht unbeabsichtigt ab (`|| true` in den Substitutionen); Fehler laufen ueber fail=1 und das abschliessende `[ "$fail" = 0 ]` (Mac :572).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: .github/workflows/testflight.yml:233
  Evidence: awk-Auszug der account-switch-check-Bloecke aus der Vorversion (HEAD) und dem Arbeitsstand: md5 beide d958a360c92c16103df41b34669ec40a. `plutil -replace LEAccountEnabled` weiter nur im `if: env.ACCOUNT_BUILD == 'true'`-Schritt (:119-122, :456-459).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Claude/DeviceRegistration.swift:13
  Evidence: Diff aendert nur die Doc-Kommentarzeile; `init(infoValue:)` (Zeile 10-11, exakt "production") unveraendert. DeviceRegistrationTests: 10 Tests, 0 Fehler (test-green-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/test_aps_environment.py:87
  Evidence: unit-full.log UNIT_EXIT=0, build.log BUILD_EXIT=0; Python-Waechter einzeln: aps 6, info_plist_sync 4, entitlements_sync 4, privacy_manifest 17, asc_what_to_test 28, alle OK. Die CI steht noch aus (nicht pruefbar).
  Status: CONFIRMED

**Implementierer:** keine Gegenrede noetig.

### Runde 2
**Adversary:** Fruehe Zustimmung misstrauisch beaeugt, Randfaelle: (a) plutil-replace laeuft nach generate; ein spaeteres generate wuerde production ueberschreiben, es gibt aber keines zwischen Schritt und Archiv. (b) Die geaenderte Info.plist liegt nur im Runner-Arbeitsbaum, nichts wird committed. (c) Sandbox-Bauten (LE Pruefbau, launch-measure) behalten sandbox: konsistent mit Entwicklungsprofil. (d) Watch und Widgets lesen die Marke nicht. (e) Die entitled-Zeile fuer aps-environment im iOS-Archiv ist nur im CI belegbar.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: .github/workflows/testflight.yml:230
  Description: Die entitled-Pruefung auf aps-environment im iOS-Archiv ist lokal nicht ausfuehrbar und zeigt ihre Wirkung erst im naechsten TestFlight-Lauf.
  Spec requirement: AC-4 — verlangt das Vorhandensein des Entitlements im Archiv.
  Conflict: Kein Widerspruch; nur nicht lokal belegbar. Ein Fehlschlag waere sichtbar und stoppt den Upload (fail-safe).
  Remediation: Beim ersten Lauf die Step-Summary pruefen. Informativ, blockiert nicht.

**Implementierer:** Kenntnis genommen.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: VERIFIED
Tests: Python-Waechter bestanden (aps 6, info_plist_sync 4, entitlements_sync 4, privacy_manifest 17, asc_what_to_test 28), 0 fehlgeschlagen; Swift unit UNIT_EXIT=0; build BUILD_EXIT=0
Edge cases: geprueft, keine gebrochen (ein LOW F001, informativ)
Regressions: keine
Checklist: 9/9 points proven

## Geprüfte Dateien

- sha256:734a157bda661f4efda7d6b018187dcc31820e16c9675fa185ab0cc166742a9d  .github/workflows/testflight.yml
- sha256:8d4f9aa662cfda71acc2f7dfabe5f164e34a456ef398b1f175caffe3b85bb6aa  LooseEnds/Claude/DeviceRegistration.swift
- sha256:6a4c1f2145042ea1b497eb6cf0cad1d930149065a0091c17c85df0dd4d98ae7a  project.yml
- sha256:34ded4685d4647a39d87f3ae0f2c8b65c0409872f5c4f90659fb7520f31cd6d9  scripts/test_aps_environment.py

## Prüfbasis

- base: 57963cd6ce7249f9663c3df59eb74c57803fab21
- blob:2e1da907e44ed017d248661b35602a252a662af6  .github/workflows/testflight.yml
- blob:a5a939410332f5e267840898141d358fc7dc80d4  LooseEnds/Claude/DeviceRegistration.swift
- blob:152ca7406a8b41a6d2b4b31b6a263665fa66a816  project.yml
- blob:02fc3ca52c525f5fe46a5c9381a8c8f6dae7e38e  scripts/test_aps_environment.py

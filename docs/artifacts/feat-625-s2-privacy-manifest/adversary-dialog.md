# Adversary Dialog — feat-625-s2-privacy-manifest
Spec: docs/specs/feat-625-schnitt-2-privacy-manifest.md
Datum: 2026-11-18 19:11

## Checkliste
- [x] **AC-1:** GIVEN `scripts/privacy_manifest.py` WHEN `apply` auf eine Kopie der echten `LooseEnds/PrivacyInfo.xcprivacy` läuft THEN steht in `NSPrivacyCollectedDataTypes` genau die Liste mit den drei Typen UserID, DeviceID, OtherUserContent, je Linked true, Tracking false und dem einen Zweck AppFunctionality, und `check --account true` auf dieser Kopie endet mit 0.
- [x] **AC-2:** GIVEN die Kopie aus AC-1 WHEN `apply` ein zweites Mal läuft THEN ist die Datei inhaltlich gleich (Plist-Vergleich), und alle anderen Schlüssel (`NSPrivacyTracking`, `NSPrivacyAccessedAPITypes` samt CA92.1) sind nach `apply` gleich dem Stand davor.
- [x] **AC-3:** GIVEN die unveränderte Quelldatei WHEN `check --account false` läuft THEN endet es mit 0; GIVEN dieselbe Datei WHEN `check --account true` läuft THEN endet es mit einem Wert ungleich 0 und die Meldung nennt die fehlenden Typen.
- [x] **AC-4:** GIVEN ein befülltes Manifest (drei Typen) WHEN `check --account false` läuft THEN endet es mit einem Wert ungleich 0 und nennt, dass für diesen Bau keine erfassten Datentypen stehen dürfen.
- [x] **AC-5:** GIVEN ein Manifest mit einem zusätzlichen fremden Typ, einem doppelten Eintrag, einem fehlenden Typ, `Tracking` = true oder fehlendem Zweck WHEN `check --account true` läuft THEN endet es jeweils mit einem Wert ungleich 0 und die Meldung benennt den Befund.
- [x] **AC-6:** GIVEN eine unlesbare Datei, ein Pfad ohne Datei oder ein anderer Wert als `true`/`false` für `--account` WHEN das Skript läuft THEN endet es mit einem Wert ungleich 0 und einer verständlichen Meldung, ohne Python-Traceback.
- [x] **AC-7:** GIVEN `LooseEnds/PrivacyInfo.xcprivacy` im Repo WHEN der Test sie liest THEN hält sie `NSPrivacyCollectedDataTypes` leer, und der Test schlägt bei einem befüllten Eintrag fehl (Store-Bauten erheben nichts, die Quelle wird in diesem Schnitt nicht geändert).
- [x] **AC-8:** GIVEN `scripts/test_privacy_manifest.py` (ein `unittest.TestCase`) WHEN `python -m unittest discover -s scripts -p 'test_*.py'` läuft THEN ist der Test sichtbar enthalten und grün, und der RED-Lauf vor dem Skript (Beleg `red.txt`) ist rot, der Lauf danach (Beleg `green.txt`) grün.
- [x] **AC-9:** GIVEN `.github/workflows/testflight.yml` WHEN der Schritt „Set the account switch“ im iOS-Job und im Mac-Job gelesen wird THEN ruft er bei `ACCOUNT_BUILD == 'true'` zusätzlich `python3 scripts/privacy_manifest.py apply LooseEnds/PrivacyInfo.xcprivacy` auf, nach `xcodegen generate` und vor dem Archivieren; ohne `konto` ruft kein Schritt `apply` auf.
- [x] **AC-10:** GIVEN die iOS-Archivprüfung WHEN sie gelesen wird THEN prüft sie nur das App-Bundle `com.henning.looseends` mit `python3 scripts/privacy_manifest.py check <Manifest im Archiv> --account "$ACCOUNT_BUILD"`, die Manifeste von Watch, Share und Widgets werden dabei nicht angefasst, und ein fehlendes Bundle oder ein Befund setzt `fail=1` (der Upload hält an); GIVEN die Mac-Archivprüfung THEN ruft sie dasselbe `check` gegen `$APP/Contents/Resources/PrivacyInfo.xcprivacy` auf und setzt bei einem Befund `fail=1`. Beide Prüfungen schreiben eine Zeile in die Zusammenfassung wie `account_switch`.
- [x] **AC-11:** GIVEN die Workflow-Datei WHEN sie als YAML gelesen wird THEN ist sie weiterhin gültig (Parsing ohne Fehler), die Marker `account-switch-check:begin`/`:end` und der bestehende `account_switch`-Block sind unverändert, und die Zeilen für Store-Bauten (ohne `konto`) bleiben im Verhalten gleich (der Diff enthält keine Änderung außerhalb der genannten Schritte).
- [x] **AC-12:** GIVEN der lokale Simulator-Bau mit `apply` auf dem Arbeitsstand WHEN `check --account true` gegen das `PrivacyInfo.xcprivacy` im gebauten `.app` läuft THEN endet es mit 0; GIVEN danach die zurückgesetzte Quelle und ein neuer Bau WHEN `check --account false` gegen das gebaute `.app` läuft THEN endet es mit 0 (Beleg `simulator-true.txt`, `simulator-false.txt` mit Befehl, Pfad und Ausgang; die Quelle ist danach wieder unverändert, `git diff -- LooseEnds/PrivacyInfo.xcprivacy` leer).
- [x] **AC-13:** GIVEN `docs/reference/datenschutz-entwurf.md` und `docs/reference/testflight.md` WHEN die Beleg-Zeile zum Manifest und der Abschnitt Konto-Schalter gelesen werden THEN nennen beide die Regel „Store-Bauten leer, Konto-Bauten drei Typen aus `scripts/privacy_manifest.py`“ samt Hinweis auf die Archivprüfung; der öffentliche Text des Entwurfs (Abschnitte vor „Beleg im Code“) ist unverändert (Diff).
- [x] **AC-14:** GIVEN der Diff des PR WHEN er geprüft wird THEN enthält er genau diese fünf Pfade (`scripts/privacy_manifest.py`, `scripts/test_privacy_manifest.py`, `.github/workflows/testflight.yml`, `docs/reference/datenschutz-entwurf.md`, `docs/reference/testflight.md`) plus den Belegordner, weder `LooseEnds/PrivacyInfo.xcprivacy` noch `project.yml` noch eine `Info.plist` noch Dateien unter `LooseEnds/`, `Shared/`, `server/`, und `LEAccountEnabled` ist in `project.yml` weiterhin `false` (Beleg `schalter.txt`).
- [x] **AC-15:** GIVEN die Abnahme WHEN sie begründet wird THEN lautet der Satz im Bericht „Kein Pfad der Geräteliste berührt.“, die Abnahme endet nach Stufe 2 (Simulator-Bau und Prüfung des gebauten `.app`, AC-12), und es gibt keinen Lauf auf Hennings Geräten.

## Dialog

### Runde 1
**Adversary:** Eigenlauf der Tests: 17 von 17 OK (adversary-test-output.txt). Randfälle im Scratchpad (binäre Plist, Typ ohne Purposes, zwei Zwecke, Linked false, Liste kein Array, Eintrag kein dict oder unhashbar, Datei kein Plist, Verzeichnis, Array als oberste Ebene, --account TRUE, leer, fehlend): jeder Ausgang 1 oder 2 mit Meldung, kein Traceback. Workflow: YAML lädt, vier run-Blöcke bash -n gleich 0.
Code reference: scripts/privacy_manifest.py:90
Code reference: scripts/test_privacy_manifest.py:55
Code reference: .github/workflows/testflight.yml:249
**Implementierer:** (Belege liegen im Belegordner, keine Einwände.)

### Runde 2
**Adversary:** Zweiter Angriff auf den Auslieferungsweg. Die Zeile mit ACCOUNT_BUILD:=false verletzt weder Store-Verhalten noch AC-11: die Variable ist workflow-weit immer gesetzt (Z.38), die Zeile ist toter Code und gleichbedeutend mit dem Vorgabewert in account_switch. iOS: fehlendes App-Bundle gibt leeres app_info, daher fail=1; Mac: fehlende Manifest-Datei gibt rc 1, fail=1. Watch, Share und Widgets bleiben wie in der Spec ungeprüft. Gegenprobe gebautes .app (Simulator): check false gleich 0. Jeder AC einzeln belegt (siehe Confirmations), keine Frühübereinstimmung.
Code reference: .github/workflows/testflight.yml:529
Code reference: docs/reference/datenschutz-entwurf.md:146
**Implementierer:** (keine Einwände.)

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: scripts/privacy_manifest.py:49
  Evidence: apply schreibt ACCOUNT_TYPES (Z.16); Test und Eigenlauf: apply auf binäre Plist, danach check true gibt 0
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/privacy_manifest.py:49
  Evidence: zweiter apply identisch (Test AC-2); Eigenlauf: übrige Schlüssel gleich der Quelle
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/privacy_manifest.py:90
  Evidence: Quelle: check false gibt 0; check true gibt 1 mit Meldung type missing (Test Z.106)
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/privacy_manifest.py:90
  Evidence: befüllt und false: must be empty for a build without the account, found 3 entries
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/privacy_manifest.py:73
  Evidence: fremd, doppelt, fehlend, Tracking true, fehlender oder zweiter Zweck, Linked false: je rc 1 mit Befund (Tests Z.115-145, Eigenläufe)
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/privacy_manifest.py:35
  Evidence: unlesbar, Verzeichnis, kein Plist, Array statt dict, --account TRUE, leer, fehlend: rc 1 bzw. 2, nie Traceback
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/test_privacy_manifest.py:106
  Evidence: Quelle leer; Test liest die echte Datei; befüllter Fall schlägt bei check false an; Quelle ohne Diff
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/test_privacy_manifest.py:55
  Evidence: Eigenlauf 17 Tests OK (adversary-test-output.txt); red.txt rot, green.txt grün vorhanden
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: .github/workflows/testflight.yml:117
  Evidence: apply in iOS (Z.117-121) und Mac (Z.434-438) nur im Schritt mit if ACCOUNT_BUILD true; bash -n beider Blöcke 0; sonst kein apply (Test Z.175)
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: .github/workflows/testflight.yml:249
  Evidence: iOS: nur app_info des Bundles com.henning.looseends, fehlendes Bundle gibt fail=1 (Z.252), Zeile in Zusammenfassung; Mac Z.529-533 gegen APP/Contents/Resources, fail=1; bash -n 0
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: .github/workflows/testflight.yml:229
  Evidence: YAML lädt; Marker und account_switch-Block unverändert (Diff nur Hinzufügungen in den genannten Schritten); die Zeile mit ACCOUNT_BUILD:=false ist toter Code, da die Variable workflow-weit (Z.38) immer true oder false ist; ohne konto: check --account false, kein apply
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: scripts/privacy_manifest.py:90
  Evidence: simulator-true und simulator-false mit Befehl, Pfad, Ausgang 0; eigene Gegenprobe des gebauten .app: check false gibt 0; Quelle ohne Diff
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: docs/reference/datenschutz-entwurf.md:146
  Evidence: Diff nur nach Z.141 Beleg im Code (zwei Zeilen); testflight.md Z.371 nennt Regel und Archivprüfung
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: docs/reference/testflight.md:371
  Evidence: geänderte Dateien gegen die Basis: die fünf Pfade plus Workflow-Dokumente (docs/specs, context, briefings) und Belegordner; kein App- oder Server-Code, kein project.yml, keine Info.plist, kein PrivacyInfo; LEAccountEnabled false (project.yml:84)
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: scripts/privacy_manifest.py:1
  Evidence: kein Produktpfad der Geräteliste im Diff; kein Geräteaufruf in den Belegen; Satz Kein Pfad der Geräteliste berührt gilt
  Status: CONFIRMED

Findings: keine (LOW-Hinweis ohne Blockade: totes ACCOUNT_BUILD:=false in beiden Prüfungen, Code reference: .github/workflows/testflight.yml:249)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: 17 passed, 0 failed, 0 übersprungen
Edge cases: All checked, none broken
Regressions: None found
Checklist: 15/15 points proven

## Geprüfte Dateien

- sha256:269f063acc38d3c69aea62eed29e600ba21a03909baed1f84321e720c6626c24  .github/workflows/testflight.yml
- sha256:4d9fc790a7eb2abec9189d99061a8227b6d52fabc4a81cbff6ec3c47c280e63e  docs/reference/datenschutz-entwurf.md
- sha256:36b0f882cab3c3a5143c11de69fb790974bfab3358620f563171b5eb3d88e31c  docs/reference/testflight.md
- sha256:e12ab4b733b4178571159f27663da87eadfa061c3ab3374ce044968c59de1ad8  scripts/privacy_manifest.py
- sha256:eba4fe6f4448d789f8e9fc28cdce791e2e51cbd116e53690837380f225fa1cb8  scripts/test_privacy_manifest.py

## Prüfbasis

- base: beda7d388a1c9140084fb5b8371991938eacfd63
- blob:2de17ea90844af6380561991bc12d4d501411e8c  .github/workflows/testflight.yml
- blob:7d2a79d3a93b12bfeb33d2a9c55e05efc61d6878  docs/reference/datenschutz-entwurf.md
- blob:e9386c649192d3eef73a8e0bc3b63a6c83812f42  docs/reference/testflight.md
- blob:4955983f479aee58ae6e0d5b0205be1bb7f74948  scripts/privacy_manifest.py
- blob:252a801d34f966ab0942b9c5c78b4a8546095cb5  scripts/test_privacy_manifest.py

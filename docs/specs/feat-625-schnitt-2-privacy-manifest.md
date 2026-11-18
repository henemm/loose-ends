---
entity_id: feat-625-schnitt-2-privacy-manifest
type: feature
created: 2026-11-18
updated: 2026-11-18
status: draft
workflow: feat-625-s2-privacy-manifest
---

# Spec: Datenschutz-Manifest folgt dem Konto-Schalter, Schnitt 2 (#625)

## Approval

- [ ] Approved

## GitHub Issue

#625 (Store-Datenschutzangaben, Store-Schalter, Einreichung). Schnitt 2 von 4; das Issue bleibt offen (`Refs #625`, nie `Closes #625`).
Analyse: `docs/context/feat-625-s2-privacy-manifest.md` (Abschnitte „Recherche“, „Risks“, „Analysis“; PO-Entscheidung 2026-11-17: jetzt nur vorbereiten, Schalter und Einreichung erst, wenn #795, #796 und #624 geschlossen sind).
Vorbild in Aufbau und Strenge: `docs/specs/feat-625-schnitt-1-datenschutztext.md`.
Es gibt keinen App-Code, keinen Dienstcode und keine Oberfläche. Geändert werden ein neues Skript samt Test, der TestFlight-Workflow und zwei Doku-Dateien. **Kein Pfad der Geräteliste berührt.**

**Folgt in späteren Schnitten (nicht Teil dieser Spec):** Schnitt 3 Vorlage für den App-Store-Fragebogen; Schnitt 4 Auftragsverarbeitung mit Hetzner; später der Schalter-Schnitt (`LEAccountEnabled` an; dann wandert `apply` in die Quelldatei und `check` wird fest auf `true`).

## Für den PO

Jede App hat bei Apple eine Pflicht-Liste, das Datenschutz-Manifest: Darin steht, welche Daten die App erhebt. Für die Store-Version ist sie heute leer, und das stimmt, solange die Verbindung zu Claude im Store ausgeschaltet ist.

Die Testbauten mit Claude-Verbindung erheben aber tatsächlich Daten (deine Apple-Kennung, die Abschrift deiner Aufgaben, eine Kennung der Installation). Dieser Schnitt sorgt dafür, dass genau diese Testbauten das jetzt korrekt in der Liste führen, und dass die Store-Version unverändert leer bleibt, weil sie nichts erhebt. Ein automatischer Test und eine Prüfung beim Bau halten das fest, damit sich beides nicht wieder auseinanderentwickelt.

Du musst nichts tun und nichts entscheiden. Auf deinem iPhone, im Store und in der App ändert sich nichts Sichtbares.

## Purpose

Das Manifest `LooseEnds/PrivacyInfo.xcprivacy` hat `NSPrivacyCollectedDataTypes` leer. Das gilt für Store-Bauten (Schalter `LEAccountEnabled` aus, kein Verkehr zum Dienst). TestFlight-Bauten mit `konto` an senden aber Daten an den Dienst: `apple_sub` als Konto-Kennung (User ID), die Abschrift der offenen Aufgaben (Other User Content) und die Installations-UUID `X-Device` (Device ID, Apples Definition umfasst „other device-level ID“). Diese Bauten deklarieren heute falsch. Der Schnitt lässt das Manifest dem Schalter folgen: Konto-Bauten bekommen im CI genau drei Einträge, Store-Bauten bleiben leer, und die Archivprüfung hält beides fest.

**Regeln vor Modell:** reine Datei- und Listenprüfung (`plistlib`); die Zeile „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine – keine ADR fällt; das Muster des Schalters (#615 S4c-2a: Archivinhalt folgt der Eingabe `konto`) wird fortgesetzt.
- **Rationale:** Kein neues Verfahren und keine neue Abhängigkeit; eine Quelle der Wahrheit (die Liste im Skript), Prüfung im Archiv statt Vertrauen auf den Patch.

## Source

**Dateien:** `scripts/privacy_manifest.py` (neu), `scripts/test_privacy_manifest.py` (neu), `.github/workflows/testflight.yml`, `docs/reference/datenschutz-entwurf.md` (nicht öffentlicher Beleg-Abschnitt, ca. Z. 145), `docs/reference/testflight.md` (Abschnitt Konto-Schalter).
**Nicht berührt:** `LooseEnds/PrivacyInfo.xcprivacy` und die Manifeste von Watch, Share, Widgets und Watch-Widgets (ohne Konto-Code, bleiben leer), `project.yml`, jede `Info.plist`, der öffentliche Datenschutztext, App- und Dienstcode.

**Gegen den Code geprüft (Spec-Phase):**

- `testflight.yml` Schritt „Set the account switch“ (iOS ca. Z. 116, Mac ca. Z. 423) läuft nur bei `ACCOUNT_BUILD == 'true'`, nach `xcodegen generate`. `generate` schreibt `PrivacyInfo.xcprivacy` nicht neu (Ressource), die Reihenfolge ist unkritisch.
- Die iOS-Archivprüfung ruft `check` je Bundle (Z. 169–197) für fünf Bundles, jedes mit eigenem `PrivacyInfo.xcprivacy` (Z. 187 prüft nur das Vorhandensein). Die Manifestprüfung für den Konto-Inhalt gehört **nur** an das App-Bundle `com.henning.looseends`; Watch, Share und Widgets haben kein Konto, ihr Manifest bleibt unangetastet. Sie wird deshalb nicht in die Schleife `check` eingebaut, sondern als eigener Aufruf nach `account_switch` mit derselben Suche nach der Bundle-Kennung (`find "$APPS" -name '*.app'`, Kennung `com.henning.looseends`).
- Mac: `$APP/Contents/Resources/PrivacyInfo.xcprivacy` (Z. 493), Aufruf nach `account_switch "$P"`.
- `ci.yml` Z. 34 führt `scripts/test_*.py` per `unittest discover -s scripts` aus; der neue Test läuft damit ohne weitere Änderung.
- Der Workflow hat **keinen Trockenlauf** für den Bau (nur `cleanup_dry_run` für Zertifikate). Der Nachweis läuft daher über Unit-Tests und den lokalen Simulator-Bau (siehe Test Plan); der Archivbeleg kommt mit dem nächsten regulären Konto-Lauf.

### Skript `scripts/privacy_manifest.py` (nur Standardbibliothek, `plistlib`)

Eine Liste `ACCOUNT_TYPES` mit genau drei Einträgen: `NSPrivacyCollectedDataTypeUserID`, `NSPrivacyCollectedDataTypeDeviceID`, `NSPrivacyCollectedDataTypeOtherUserContent`; je `NSPrivacyCollectedDataTypeLinked` = true, `NSPrivacyCollectedDataTypeTracking` = false, `NSPrivacyCollectedDataTypePurposes` = [`NSPrivacyCollectedDataTypePurposeAppFunctionality`].

- `apply <manifest>`: setzt `NSPrivacyCollectedDataTypes` auf diese Liste (idempotent: ein zweiter Aufruf ändert nichts), alle anderen Schlüssel (`NSPrivacyTracking`, `NSPrivacyAccessedAPITypes` mit CA92.1 u. a.) bleiben unverändert.
- `check <manifest> --account true|false`: `true` verlangt genau die drei Typen (Reihenfolge egal, keine fremden, keine doppelten, je mit Linked true, Tracking false und genau dem einen Zweck); `false` verlangt eine leere oder fehlende Liste. Ausgang 0 bei Treffer, sonst ungleich 0 mit verständlicher Meldung auf stderr; unlesbare oder keine gültige Plist-Datei ebenfalls ungleich 0; ein anderer Wert für `--account` ist ein Aufruffehler.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `LooseEnds/PrivacyInfo.xcprivacy` | datei | Eingabe für `apply` und Test; bleibt im Repo unverändert |
| `.github/workflows/testflight.yml` (`ACCOUNT_BUILD`) | workflow | Schalter, dem das Manifest folgt; Archivprüfung iOS und Mac |
| `ci.yml` (`unittest discover -s scripts`) | workflow | führt den neuen Test aus |
| `Shared/Services/TranscriptCodec.swift`, `LooseEnds/Claude/DeviceIdentity.swift`, `server/migrations/002_accounts.sql` | belege | belegen die drei Datentypen (Abschrift, `X-Device`, `apple_sub`) |
| `docs/specs/feat-625-schnitt-1-datenschutztext.md` | spec | Vorgänger; öffentlicher Text unverändert |
| Downstream | schnitte | Schnitt 3 (Fragebogen), Schalter-Schnitt |

## Acceptance Criteria

Belege liegen unter `docs/artifacts/feat-625-s2-privacy-manifest/` („Belegordner“). Kein Beleg enthält Zugangsdaten, Tokens oder `sub`-Werte.

- **AC-1:** GIVEN `scripts/privacy_manifest.py` WHEN `apply` auf eine Kopie der echten `LooseEnds/PrivacyInfo.xcprivacy` läuft THEN steht in `NSPrivacyCollectedDataTypes` genau die Liste mit den drei Typen UserID, DeviceID, OtherUserContent, je Linked true, Tracking false und dem einen Zweck AppFunctionality, und `check --account true` auf dieser Kopie endet mit 0.
- **AC-2:** GIVEN die Kopie aus AC-1 WHEN `apply` ein zweites Mal läuft THEN ist die Datei inhaltlich gleich (Plist-Vergleich), und alle anderen Schlüssel (`NSPrivacyTracking`, `NSPrivacyAccessedAPITypes` samt CA92.1) sind nach `apply` gleich dem Stand davor.
- **AC-3:** GIVEN die unveränderte Quelldatei WHEN `check --account false` läuft THEN endet es mit 0; GIVEN dieselbe Datei WHEN `check --account true` läuft THEN endet es mit einem Wert ungleich 0 und die Meldung nennt die fehlenden Typen.
- **AC-4:** GIVEN ein befülltes Manifest (drei Typen) WHEN `check --account false` läuft THEN endet es mit einem Wert ungleich 0 und nennt, dass für diesen Bau keine erfassten Datentypen stehen dürfen.
- **AC-5:** GIVEN ein Manifest mit einem zusätzlichen fremden Typ, einem doppelten Eintrag, einem fehlenden Typ, `Tracking` = true oder fehlendem Zweck WHEN `check --account true` läuft THEN endet es jeweils mit einem Wert ungleich 0 und die Meldung benennt den Befund.
- **AC-6:** GIVEN eine unlesbare Datei, ein Pfad ohne Datei oder ein anderer Wert als `true`/`false` für `--account` WHEN das Skript läuft THEN endet es mit einem Wert ungleich 0 und einer verständlichen Meldung, ohne Python-Traceback.
- **AC-7:** GIVEN `LooseEnds/PrivacyInfo.xcprivacy` im Repo WHEN der Test sie liest THEN hält sie `NSPrivacyCollectedDataTypes` leer, und der Test schlägt bei einem befüllten Eintrag fehl (Store-Bauten erheben nichts, die Quelle wird in diesem Schnitt nicht geändert).
- **AC-8:** GIVEN `scripts/test_privacy_manifest.py` (ein `unittest.TestCase`) WHEN `python -m unittest discover -s scripts -p 'test_*.py'` läuft THEN ist der Test sichtbar enthalten und grün, und der RED-Lauf vor dem Skript (Beleg `red.txt`) ist rot, der Lauf danach (Beleg `green.txt`) grün.
- **AC-9:** GIVEN `.github/workflows/testflight.yml` WHEN der Schritt „Set the account switch“ im iOS-Job und im Mac-Job gelesen wird THEN ruft er bei `ACCOUNT_BUILD == 'true'` zusätzlich `python3 scripts/privacy_manifest.py apply LooseEnds/PrivacyInfo.xcprivacy` auf, nach `xcodegen generate` und vor dem Archivieren; ohne `konto` ruft kein Schritt `apply` auf.
- **AC-10:** GIVEN die iOS-Archivprüfung WHEN sie gelesen wird THEN prüft sie nur das App-Bundle `com.henning.looseends` mit `python3 scripts/privacy_manifest.py check <Manifest im Archiv> --account "$ACCOUNT_BUILD"`, die Manifeste von Watch, Share und Widgets werden dabei nicht angefasst, und ein fehlendes Bundle oder ein Befund setzt `fail=1` (der Upload hält an); GIVEN die Mac-Archivprüfung THEN ruft sie dasselbe `check` gegen `$APP/Contents/Resources/PrivacyInfo.xcprivacy` auf und setzt bei einem Befund `fail=1`. Beide Prüfungen schreiben eine Zeile in die Zusammenfassung wie `account_switch`.
- **AC-11:** GIVEN die Workflow-Datei WHEN sie als YAML gelesen wird THEN ist sie weiterhin gültig (Parsing ohne Fehler), die Marker `account-switch-check:begin`/`:end` und der bestehende `account_switch`-Block sind unverändert, und die Zeilen für Store-Bauten (ohne `konto`) bleiben im Verhalten gleich (der Diff enthält keine Änderung außerhalb der genannten Schritte).
- **AC-12:** GIVEN der lokale Simulator-Bau mit `apply` auf dem Arbeitsstand WHEN `check --account true` gegen das `PrivacyInfo.xcprivacy` im gebauten `.app` läuft THEN endet es mit 0; GIVEN danach die zurückgesetzte Quelle und ein neuer Bau WHEN `check --account false` gegen das gebaute `.app` läuft THEN endet es mit 0 (Beleg `simulator-true.txt`, `simulator-false.txt` mit Befehl, Pfad und Ausgang; die Quelle ist danach wieder unverändert, `git diff -- LooseEnds/PrivacyInfo.xcprivacy` leer).
- **AC-13:** GIVEN `docs/reference/datenschutz-entwurf.md` und `docs/reference/testflight.md` WHEN die Beleg-Zeile zum Manifest und der Abschnitt Konto-Schalter gelesen werden THEN nennen beide die Regel „Store-Bauten leer, Konto-Bauten drei Typen aus `scripts/privacy_manifest.py`“ samt Hinweis auf die Archivprüfung; der öffentliche Text des Entwurfs (Abschnitte vor „Beleg im Code“) ist unverändert (Diff).
- **AC-14:** GIVEN der Diff des PR WHEN er geprüft wird THEN enthält er genau diese fünf Pfade (`scripts/privacy_manifest.py`, `scripts/test_privacy_manifest.py`, `.github/workflows/testflight.yml`, `docs/reference/datenschutz-entwurf.md`, `docs/reference/testflight.md`) plus den Belegordner, weder `LooseEnds/PrivacyInfo.xcprivacy` noch `project.yml` noch eine `Info.plist` noch Dateien unter `LooseEnds/`, `Shared/`, `server/`, und `LEAccountEnabled` ist in `project.yml` weiterhin `false` (Beleg `schalter.txt`).
- **AC-15:** GIVEN die Abnahme WHEN sie begründet wird THEN lautet der Satz im Bericht „Kein Pfad der Geräteliste berührt.“, die Abnahme endet nach Stufe 2 (Simulator-Bau und Prüfung des gebauten `.app`, AC-12), und es gibt keinen Lauf auf Hennings Geräten.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/privacy_manifest.py` | CREATE | Liste der drei Typen, `apply`, `check`; ca. +65 |
| `scripts/test_privacy_manifest.py` | CREATE | unittest für AC-1 bis AC-7; ca. +90 |
| `.github/workflows/testflight.yml` | MODIFY | `apply` in beiden Jobs, `check` in beiden Archivprüfungen; ca. +18 |
| `docs/reference/datenschutz-entwurf.md` | MODIFY | Beleg-Zeile zum Manifest; ca. +2/−1 |
| `docs/reference/testflight.md` | MODIFY | Abschnitt Konto-Schalter: Manifest folgt `konto`; ca. +5 |
| `docs/artifacts/feat-625-s2-privacy-manifest/` | CREATE | Belege; zählt nicht zum Dateilimit |

### Estimated Changes

- Files: 5 (Limit 4 bis 5 eingehalten; Belegordner zählt nicht)
- LoC: +180/−1, innerhalb von ±250
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, kein `generate`-Diff, keine neue Abhängigkeit.
- **Seiteneffekte (explizit):** Ein Fehler in `apply` oder `check` hält jeden TestFlight-Lauf an (gewollt, laut statt still). Store-Bauten ändern ihren Inhalt nicht.
- **Parallele Arbeit:** vor dem PR `origin/main` und offene PRs auf `testflight.yml` und `datenschutz-entwurf.md` prüfen (Hotspots; `konto`-Läufe der Epic-Sitzung).

## Implementation Details

Reihenfolge (TDD): erst `scripts/test_privacy_manifest.py` schreiben und rot belegen (Skript fehlt), dann `scripts/privacy_manifest.py`, grün belegen. Danach `testflight.yml` (beide Jobs), dann Doku, dann Simulator-Nachweis. Das Skript nutzt `plistlib.load`/`dump` (Binärformat wird als XML geschrieben, was für Xcode gültig ist) und bleibt unter 30 Zeilen je Funktion. Die Archivprüfung ruft das Skript über denselben Repo-Pfad auf wie `apply`.

## Test Plan

### Automated Tests (TDD RED)

- [ ] Test 1 (AC-1, AC-2): GIVEN eine Kopie der echten `PrivacyInfo.xcprivacy` WHEN `apply` einmal und ein zweites Mal läuft THEN gilt `check --account true`, die Datei ist nach dem zweiten Lauf gleich, und die anderen Schlüssel sind unverändert.
- [ ] Test 2 (AC-3, AC-7): GIVEN die unveränderte Quelldatei WHEN `check --account false` läuft THEN 0, und `check --account true` ist ungleich 0; die Quelle hält die Liste leer.
- [ ] Test 3 (AC-4): GIVEN ein befülltes Manifest WHEN `check --account false` läuft THEN ungleich 0.
- [ ] Test 4 (AC-5): GIVEN fremder Zusatztyp, doppelter Eintrag, fehlender Typ, Tracking true oder fehlender Zweck WHEN `check --account true` läuft THEN je ungleich 0 mit Befund in der Meldung.
- [ ] Test 5 (AC-6): GIVEN unlesbare Datei, fehlender Pfad oder ungültiger `--account`-Wert WHEN das Skript läuft THEN ungleich 0 ohne Traceback.
- [ ] Test 6 (AC-9, AC-10, AC-11): GIVEN `testflight.yml` WHEN der Test sie liest THEN ist sie gültiges YAML (sofern `yaml` fehlt, Textprüfung) und enthält in iOS- und Mac-Job je einen `apply`- und einen `check`-Aufruf mit `--account "$ACCOUNT_BUILD"`.

| Prüfung | Beleg | AC |
|---|---|---|
| Test rot ohne Skript, grün mit Skript, CI-Befehl | `red.txt`, `green.txt`, CI | AC-1 bis AC-8 |
| Stufe 2 im Simulator: `apply`, Bau, `check true` am `.app`; Quelle zurück, Bau, `check false` | `simulator-true.txt`, `simulator-false.txt` | AC-12, AC-15 |
| Diff-Dateiliste, Schalter | `schalter.txt` | AC-14 |

**Ehrlich zur Belegkraft:** Die Unit-Tests und der Simulator-Bau belegen, dass das Skript das Manifest richtig schreibt und prüft und dass Xcode die Datei unverändert ins Bundle kopiert. Dass die Archivprüfung in einem echten Konto-Lauf grün ist, belegt erst der nächste reguläre TestFlight-Lauf (Definition of Done).

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **Gewählt: Manifest folgt dem Schalter** | Quelle leer, Konto-Bauten bekommen drei Einträge im CI, Archivprüfung hält beides fest | Konto-Bauten deklarieren korrekt, Store-Bauten bleiben bei „Keine Daten erfasst“; folgt dem Muster `LEAccountEnabled` | CI-Code im Auslieferungsweg; später ist ein Schnitt nötig, der die Einträge in die Quelle verschiebt | — |
| **A Nichts jetzt, Manifest erst mit dem Schalter-Schnitt** | kein CI-Code | kleinster Aufwand | Konto-TestFlight-Bauten bleiben bis dahin falsch deklariert, die Lücke wäre unbelegt offen | die Beleg-Regel „Deklaration folgt dem tatsächlichen Verkehr“ |
| **B Sofort in die Quelldatei** | drei Einträge direkt in `PrivacyInfo.xcprivacy` | einfachste Änderung, eine Quelle | jeder Store-Bau 1.0.x (Schalter aus, erhebt nichts) widerspräche dem Store-Label „Keine Daten erfasst“ und dem Text „ohne Konto kein Verkehr“; Risiko in der Store-Prüfung | das Store-Label und die Aussage des Datenschutztextes |

Keine ADR fällt bei keiner Variante.

## Out of Scope / Folgeschnitte

- **#625 Schnitt 3:** `docs/reference/app-store-datenschutzangaben.md` (Vorlage Fragebogen); Eintragen in App Store Connect erst mit der Version, die den Schalter an hat.
- **#625 Schnitt 4:** Auftragsverarbeitung mit Hetzner (Beleg).
- **#625 zweiter Teil:** Schalter-Schnitt: `apply` wandert in die Quelldatei, `check` wird fest auf `true`; erst nach #795, #796, #624.
- Manifeste von Watch, Share und Widgets: bleiben leer, solange dort kein Konto-Code läuft.

## Risiken

- **CI-Fehler hält jeden TestFlight-Lauf an.** Gegenmittel: Unit-Tests, Simulator-Nachweis beider Zustände, Archivprüfung macht jeden Fehler laut; Adversary-Prüfung zwei Runden (CI-Code).
- **`check` im Archiv trifft das falsche Bundle.** Gegenmittel: Suche nach Bundle-Kennung `com.henning.looseends` wie bei `entitled`, ein fehlendes Bundle ist ein Fehler.
- **Skript und Datenschutztext laufen auseinander.** Gegenmittel: Beleg-Zeile im Entwurf nennt das Skript als Quelle; Schnitt 3 übernimmt die Liste für den Fragebogen.
- **Apple-Anforderung nicht amtlich belegt:** Ob Apple ein Manifest mit Einträgen gegen das Label „Keine Daten erfasst“ ablehnt, ist nur aus Fallberichten bekannt; die Wahl bleibt sicher, weil Store-Bauten leer bleiben.

## Definition of Done

- [ ] AC-1 bis AC-15 erfüllt, Belege im Belegordner
- [ ] PR mit `Refs #625` (nie `Closes`), CI grün, gemergt
- [ ] Offener Punkt im Issue #625 mit Datum festgehalten: Archivbeleg mit `konto` an (Manifest im Archiv trägt die drei Typen, `check` grün) kommt mit dem nächsten regulären TestFlight-Lauf mit `konto` = true; Claude prüft den Lauf selbst nach und trägt den Beleg ein; kein eigener Upload nur für den Beweis
- [ ] #625 kommentiert (Stand Schnitt 2, Folgen Schnitt 3 und 4 und Schalter), Board-Karte aktuell, Memory geschrieben

Keine Gerätepunkte (Stufe 3 greift nicht).

## Changelog

- 2026-11-18: Initial spec created (Schnitt 2 von #625, Datenschutz-Manifest folgt dem Konto-Schalter)

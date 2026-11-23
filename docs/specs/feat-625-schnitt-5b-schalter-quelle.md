---
entity_id: feat-625-schnitt-5b-schalter-quelle
type: feature
created: 2026-11-23
updated: 2026-11-23
status: draft
workflow: feat-625-s5b-schalter-quelle
---

# Spec: Konto-Schalter an der Quelle (Schnitt 5b, #625)

## Approval

- [ ] Approved

## GitHub Issue

#625 (Store-Schalter, Einreichung). Schnitt 5b; das Issue bleibt offen (`Refs #625`, nie `Closes #625`).
Analyse: `docs/context/feat-625-s5b-schalter-quelle.md`. Schnittplan S5a bis S5d und PO-Entscheidung vom 2026-11-22: `docs/context/feat-625-konto-schalter.md`.
Vorgänger: `docs/specs/feat-625-schnitt-5a-offene-tuer.md` (Dienst: offene Tür mit Tagesgrenze, ausgerollt), `docs/specs/feat-625-schnitt-2-privacy-manifest.md` (Manifest folgt dem Schalter), `docs/specs/feat-615-schnitt-4c2a-freischalten.md` (Konto-Bau-Mechanik).

**Nicht in diesem Schnitt (Folgeschnitte von #625):**

- **S5c:** Konto-Mechanik in CI und Skripten zurückbauen (Eingang `konto`, Marke „KONTO-BAU“, Store-Sperre markierter Bauten, Archivprüfungen gegen `ACCOUNT_BUILD`). `testflight.yml` bleibt in S5b unverändert.
- **S5d:** Store: datiertes Ja zur Fragebogen-Vorlage, Etikett im ASC-Web, Version 1.0.2, Texte, Review-Notizen, Einreichen; Betriebs-Tür auf `ALLOWED_APPLE_SUBS=*` stellen.

## Für den PO

Bisher war die Verbindung zu Claude nur in TestFlight-Bauten mit einem Sonderschalter an. Du hast am 2026-11-22 entschieden, dass sie künftig immer an ist, damit der Store-Bau sie enthält und Apples Prüfer sie sieht. Dieser Schnitt schaltet sie in der Quelle ein: Jede Ausgabe der App zeigt ab dann in den Einstellungen die Gruppe „Claude“, und die Datenschutz-Liste der App führt die drei Datenarten, die dabei fließen (deine Apple-Kennung, die Abschrift der offenen Aufgaben, die Kennung der Installation).

Was sich für dich nicht ändert: Im Store liegt weiter 1.0.1 ohne Claude-Verbindung, bis die Version in S5d eingereicht wird. Der Dienst lässt bis dahin weiter nur dein Konto herein; ein fremdes Konto sähe „noch nicht freigeschaltet“. Du musst nichts entscheiden. Dein nächster TestFlight-Bau nach dem Folgeschnitt enthält die Änderung und wird dir in einfachen Worten zum Ausprobieren benannt.

## Purpose

`LEAccountEnabled` steht in `project.yml` auf `false` und wird nur von einem TestFlight-Lauf mit `konto` im Archiv auf `true` gesetzt; das Manifest `LooseEnds/PrivacyInfo.xcprivacy` hält `NSPrivacyCollectedDataTypes` leer und füllt sie nur in diesem Lauf. Das sind zwei Wahrheiten (Quelle aus, Archiv an). Der Schnitt macht die Quelle zur einen Wahrheit: Schalter `true` in `project.yml`, Abbild in `Info.plist`, Manifest-Quelle mit den drei `ACCOUNT_TYPES`. Zwei Wächtertests, die heute „aus“ und „leer“ festhalten, werden auf „an“ und „drei Typen“ umgedreht.

**Regeln vor Modell:** reine Konfigurations- und Dateiprüfung; die Zeile „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Setzt die PO-Entscheidung vom 2026-11-22 (Schalter an der Quelle, Schnittplan S5a bis S5d) um; kein neues Verfahren, keine neue Abhängigkeit. Die Grundregel „The service is open to every Apple account …“ in `CLAUDE.md` deckt es ab; keine ADR fällt.

## Source

**Dateien (App-/Konfig-Code, 4):** `project.yml`, `LooseEnds/Info.plist`, `LooseEnds/PrivacyInfo.xcprivacy`, `scripts/privacy_manifest.py` (nur Docstring).
**Dazu (zählen nicht zum App-Code-Limit):** `scripts/test_privacy_manifest.py`, `scripts/test_asc_what_to_test.py`, `CLAUDE.md`.
**Identifier:** `LEAccountEnabled` (Schlüssel `info.properties` des Ziels `LooseEnds`), `ACCOUNT_TYPES` in `scripts/privacy_manifest.py` (eine Quelle, nicht geändert), `AccountWiring.isEnabled` (nicht geändert).

**Gegen den Code geprüft (Analyse-Phase, 2026-11-23, `origin/main` 04f697f):**

- `AccountWiring.isEnabled` verlangt ein echtes Bool `true`; `AccountSectionTests` prüfen mit eingespeisten Dicts, nicht mit der Bundle-Info: unberührt.
- Alle UI-Tests laufen mit `--ui-testing`; dort ist die Gruppe schon an (Speicher im Arbeitsspeicher, kein Netz): unverändert. Store-Bilder ebenso.
- Unit-Host (kein `--ui-testing`, `XCTestConfigurationFilePath` gesetzt): `forApp` baut künftig ein `AccountState` mit `KeychainSessionStore`; `init` liest einmal den Schlüsselbund (`storedToken`, bei Fehler wie −34018 im unsignierten Lauf `nil`, also `signedOut`). `ClaudeSyncTrigger` ist unter Tests stumm, `PushWakeUp` `nil`. Kein Netz, kein Absturz erwartet; im Unit-Lauf zu belegen (AC-8).
- `testflight.yml` mit `konto` an (Vorgabe): `plutil … YES` und `privacy_manifest.py apply` werden Nullschritte (`apply` ist idempotent, getestet); die Archivprüfungen vergleichen mit `ACCOUNT_BUILD=true` und bleiben grün. Nur ein Lauf mit `konto` aus oder ein `v*`-Tag-Lauf (immer aus) scheitert danach an `account_switch` und `check --account false`.
- Watch, Widgets, Share tragen kein `LEAccountEnabled` und eigene Manifeste: unberührt.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `scripts/privacy_manifest.py` (`ACCOUNT_TYPES`, `apply`, `check`) | skript | erzeugt und prüft die Manifest-Quelle; eine Quelle der Wahrheit |
| `scripts/sim.sh generate` (xcodegen) | skript | schreibt `Info.plist` als Abbild von `project.yml` |
| `scripts/test_info_plist_sync.py`, CI-Schritt „Generate leaves the tree clean“ | test, ci | halten `project.yml` und `Info.plist` gleich |
| `scripts/test_app_store_datenschutzangaben.py` | test | hält die Fragebogen-Vorlage gleich `ACCOUNT_TYPES`; unberührt, bleibt grün |
| `LooseEnds/Claude/AccountWiring.swift`, `LooseEnds/Views/AccountSection.swift` | app | lesen den Schalter, zeigen die Gruppe; unverändert |
| `.github/workflows/testflight.yml` | workflow | unverändert; Rückbau in S5c |
| Vorgänger S5a (Dienst nimmt technisch alle Konten an, Betriebs-Tür noch zu) | schnitt | Voraussetzung, ausgerollt |
| Downstream | schnitte | S5c (CI-Rückbau, direkt danach), S5d (Store) |

## Acceptance Criteria

Belege liegen unter `docs/artifacts/feat-625-s5b-schalter-quelle/` („Belegordner“). Kein Beleg enthält Zugangsdaten, Tokens oder `sub`-Werte.

- **AC-1:** GIVEN `project.yml` WHEN `info.properties` des Ziels `LooseEnds` gelesen wird THEN ist `LEAccountEnabled` das Bool `true` (kein String), `LEServiceURL` bleibt ungesetzt, und die Kommentare an `LEAccountEnabled` und `com.apple.developer.applesignin` sagen nicht mehr „off by default“, „without effect while LEAccountEnabled is off“ oder „only a TestFlight run with konto“, sondern „an der Quelle an (#625 S5b)“. Test: `scripts/test_asc_what_to_test.py` `AccountBuildSourceTests.test_account_switch_is_a_true_bool` (umgedrehter `test_account_switch_is_a_false_bool`), Kommentare durch Lesen und Diff.
- **AC-2:** GIVEN `LooseEnds/Info.plist` WHEN sie gelesen wird THEN trägt sie `LEAccountEnabled` als Bool `true` und kein `LEServiceURL`; GIVEN `./scripts/sim.sh generate` WHEN er läuft THEN hinterlässt er keinen Diff (`git status --porcelain` leer für `LooseEnds/`). Test: derselbe umgedrehte Test (zweiter Teil prüft `Info.plist`), `scripts/test_info_plist_sync.py` grün; Beleg `generate.txt`.
- **AC-3:** GIVEN `LooseEnds/PrivacyInfo.xcprivacy` WHEN der Test sie liest THEN steht in `NSPrivacyCollectedDataTypes` genau die Liste `ACCOUNT_TYPES` (UserID, DeviceID, OtherUserContent; je Linked true, Tracking false, Zweck AppFunctionality); GIVEN eine Kopie der Quelle WHEN `privacy_manifest.py apply` darauf läuft THEN ist sie inhaltlich unverändert (Plist-Vergleich), und alle anderen Schlüssel (`NSPrivacyTracking`, `NSPrivacyAccessedAPITypes` mit CA92.1) sind unverändert. Test: `scripts/test_privacy_manifest.py` `CheckTests.test_source_carries_the_three_types_and_passes_only_with_account` (ersetzt `test_source_is_empty_and_passes_only_without_account`).
- **AC-4:** GIVEN die Quelle WHEN `python3 scripts/privacy_manifest.py check LooseEnds/PrivacyInfo.xcprivacy --account true` läuft THEN endet es mit 0; WHEN `--account false` läuft THEN endet es ungleich 0 mit der Meldung zu `NSPrivacyCollectedDataTypes`. Test: derselbe Test wie AC-3; die übrigen Tests von `test_privacy_manifest.py` (Fehlerfälle, `apply`) bleiben in Aussage unverändert grün.
- **AC-5:** GIVEN die Manifest-Quelle WHEN sie neu geschrieben wird THEN geschieht das nur mit `python3 scripts/privacy_manifest.py apply LooseEnds/PrivacyInfo.xcprivacy` (byte-gleich zu dem, was der Konto-Lauf in CI erzeugt, keine Handkopie); GIVEN der Docstring von `scripts/privacy_manifest.py` WHEN er gelesen wird THEN beschreibt er, dass die Quelle die drei Typen trägt und `check --account` weiter beide Zustände prüft (kein „Store-Bauten leer“ mehr). Beleg: `apply.txt` (Befehl, Ausgang 0, `git diff --stat` nur diese Datei), Lesen des Docstrings.
- **AC-6:** GIVEN alle Python-Tests WHEN `python3 -m unittest discover -s scripts -p 'test_*.py'` läuft THEN ist der Lauf grün, einschließlich `test_info_plist_sync.py`, `test_app_store_datenschutzangaben.py` und der Konto-Bau-Prüfungen in `test_asc_what_to_test.py`; der RED-Lauf vor der Änderung (die beiden umgedrehten Tests rot gegen die alte Quelle, Beleg `red.txt`) und der grüne Lauf danach (`green.txt`) liegen im Belegordner.
- **AC-7:** GIVEN die Gesamt-Diffliste WHEN sie geprüft wird THEN enthält sie genau diese Pfade: `project.yml`, `LooseEnds/Info.plist`, `LooseEnds/PrivacyInfo.xcprivacy`, `scripts/privacy_manifest.py`, `scripts/test_privacy_manifest.py`, `scripts/test_asc_what_to_test.py`, `CLAUDE.md`, die Spec, die Kontextdatei und den Belegordner; `.github/workflows/testflight.yml` und jede Swift-Datei sind nicht darin. Beleg: `dateiliste.txt` (`git diff --name-only origin/main...HEAD`).
- **AC-8:** GIVEN der Unit-Lauf im Simulator WHEN `./scripts/sim.sh unit` mit der neuen Quelle läuft THEN endet er grün ohne Absturz des Test-Hosts (der Unit-Host baut jetzt `AccountState` mit `KeychainSessionStore`), und kein Test ist neu übersprungen; jede „übersprungen“-Zahl wird mit Namen belegt. Beleg: `unit.txt`.
- **AC-9:** GIVEN die App im iOS-Simulator, gebaut und installiert aus dem Arbeitsstand, WHEN sie **ohne** `--ui-testing` gestartet und die Einstellungen geöffnet werden THEN zeigt die Gruppe „Claude“ direkt unter iCloud ihre Zeile für „Mit Apple anmelden“ (abgemeldet, kein Netzverkehr, nichts wird ohne Tippen gesendet), und die App startet ohne Absturz. Beleg: Screenshot `einstellungen-claude.png` (geöffnet und beschrieben, nicht gezählt) und `launch.txt` mit Befehl und Start ohne `--ui-testing`; Stufe 2.
- **AC-10:** GIVEN `CLAUDE.md` WHEN der Absatz zu `AccountWiring` (Abschnitt „Where things live“, `LooseEnds/Claude`) und der Absatz zum Eingang `konto` im Abschnitt „Ship“ gelesen werden THEN steht dort: `LEAccountEnabled` ist in `project.yml` `true` (Schalter an der Quelle, #625 S5b), das Manifest trägt die drei Typen, fehlender oder fremder Typ blendet die Gruppe weiter aus; der Eingang `konto` ist bis S5c ohne Wirkung auf den Inhalt und wird dort zurückgebaut; kein Satz behauptet mehr „`project.yml` holds `false`“. Beleg: Lesen und Diff (`claude-md.txt`).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `project.yml` | MODIFY | `LEAccountEnabled: true`, Kommentare (Schalter, applesignin) angepasst; ca. +4/−4 |
| `LooseEnds/Info.plist` | MODIFY | Abbild per `./scripts/sim.sh generate`, `<true/>`; ca. +1/−1 |
| `LooseEnds/PrivacyInfo.xcprivacy` | MODIFY | per `apply` die drei `ACCOUNT_TYPES`; ca. +30/−2 |
| `scripts/privacy_manifest.py` | MODIFY | nur Docstring; ca. +3/−3 |
| `scripts/test_privacy_manifest.py` | MODIFY | Quelle trägt drei Typen, besteht nur mit `--account true`; Test umbenannt; ca. +6/−4 |
| `scripts/test_asc_what_to_test.py` | MODIFY | `test_account_switch_is_a_true_bool` (Bool `True` in `project.yml` und `Info.plist`); ca. +2/−2 |
| `CLAUDE.md` | MODIFY | zwei Stellen (AC-10); ca. +4/−3 |
| `docs/artifacts/feat-625-s5b-schalter-quelle/` | CREATE | Belege; zählt nicht zum Dateilimit |

### Estimated Changes

- Files: 4 App-/Konfig-Dateien (Limit 4 bis 5 eingehalten) plus zwei Testdateien und `CLAUDE.md`, die nicht zum App-Code zählen.
- LoC: App-/Konfig-Code grob +38/−10 (davon ca. 30 Manifest-Einträge), Tests ca. +8/−6, Doku ca. +4/−3; unter ±250.
- **Berührte Berechtigungen und Schlüssel (explizit):** keine neue Berechtigung (Sign in with Apple steht seit S4c-2a im Entitlement), kein neuer AppStorage-Schlüssel, kein CloudKit-Schema, keine Audio-Dateien. Geändert wird der Wert eines vorhandenen Info-Schlüssels (`LEAccountEnabled`) und der Inhalt des Privacy-Manifests.
- **Seiteneffekte (explizit):**
  1. Jede Ausgabe der App (Xcode-Lauf auf Hennings Mac, Simulator, TestFlight, Store) zeigt die Gruppe „Claude“ und führt die drei Datenarten im Manifest.
  2. Ein TestFlight-Lauf mit `konto` **aus** und jeder `v*`-Tag-Lauf scheitern bis S5c in der Archivprüfung (Quelle an, Erwartung aus). Der Lauf mit `konto` an (Vorgabe) bleibt grün.
  3. Ein Konto-Bau trägt bis S5c weiter die Marke „KONTO-BAU – nie für den App Store“, und `asc_store_version.py` ordnet ihn keiner Store-Version zu.
- **Randbedingung (verbindlich):** Zwischen dem Merge von S5b und dem Merge von S5c läuft **kein** TestFlight-Lauf und kein `v*`-Tag-Lauf. Läufe startet nur die Epic-Sitzung (#612); S5c folgt unmittelbar. Kein Store-Bau zwischen S5b und S5d: Im Store bleibt bis zur Einreichung 1.0.1 ohne Konto.
- **Parallele Arbeit:** Hotspots `project.yml` und `CLAUDE.md`; vor dem PR `origin/main` und offene PRs prüfen.

## Implementation Details

Reihenfolge (TDD): zuerst die zwei Tests umdrehen (`test_account_switch_is_a_true_bool`, `test_source_carries_the_three_types_and_passes_only_with_account`) und rot belegen (`red.txt`), dann `project.yml` (Wert und Kommentare), `./scripts/sim.sh generate` (Abbild `Info.plist`), `python3 scripts/privacy_manifest.py apply LooseEnds/PrivacyInfo.xcprivacy`, Docstring, grün belegen (`green.txt`). Danach `CLAUDE.md`, Unit-Lauf, Simulator-Durchlauf. Kein Wert wird von Hand in `Info.plist` oder Manifest getippt: beide Dateien sind Erzeugnisse von `generate` und `apply`. Kommentare in `project.yml` knapp auf Englisch.

Der PR geht mit `Refs #625`, die CI muss grün sein (insbesondere „Generate leaves the tree clean“ und die Python-Tests), danach Merge. S5c beginnt unmittelbar nach dem Merge.

## Test Plan

### Automated Tests (TDD RED)

- [ ] Test 1 (AC-1, AC-2): GIVEN `project.yml` und `Info.plist` WHEN `test_account_switch_is_a_true_bool` läuft THEN ist `LEAccountEnabled` in beiden das Bool `True` und `LEServiceURL` fehlt; rot gegen den alten Stand.
- [ ] Test 2 (AC-3, AC-4): GIVEN die Manifest-Quelle WHEN `test_source_carries_the_three_types_and_passes_only_with_account` läuft THEN stehen genau die drei Typen darin, `check --account true` ergibt 0 und `--account false` ungleich 0; rot gegen den alten Stand.
- [ ] Test 3 (AC-3): GIVEN eine Kopie der neuen Quelle WHEN `apply` läuft THEN ist sie unverändert (bestehender Idempotenz-Test, auf die Quelle angewendet).
- [ ] Test 4 (AC-6): GIVEN der Gesamtlauf der Python-Tests WHEN `unittest discover -s scripts` läuft THEN grün.
- [ ] Test 5 (AC-8): GIVEN der Unit-Lauf WHEN `./scripts/sim.sh unit` läuft THEN grün ohne Absturz des Hosts.

| Prüfung | Beleg | AC |
|---|---|---|
| `generate` ohne Diff | `generate.txt` | AC-2 |
| `apply` auf die Quelle, nur diese Datei geändert | `apply.txt` | AC-5 |
| Test rot vorher, grün nachher | `red.txt`, `green.txt` | AC-1 bis AC-6 |
| Unit-Lauf | `unit.txt` | AC-8 |
| Simulator-Start ohne `--ui-testing`, Einstellungen | `einstellungen-claude.png`, `launch.txt` | AC-9 |
| Dateiliste | `dateiliste.txt` | AC-7 |

**Keine neuen UI-Tests:** Der sichtbare Ablauf (Gruppe „Claude“ in den Einstellungen) ist durch die bestehenden Smoke-Tests unter `--ui-testing` abgedeckt, wo die Gruppe schon an war; der neue Zustand ohne `--ui-testing` ist ein Simulator-Durchlauf (AC-9), den ein UI-Test nicht herstellen kann (`--ui-testing` ist dort die Voraussetzung). Benannte Lücke: Der Archivinhalt (Manifest und Info im echten TestFlight-Bau) wird erst vom nächsten Lauf nach S5c belegt.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **Gewählt: Schalter an der Quelle, S5b und S5c in getrennten PRs** | Quelle `true`, Manifest gefüllt, CI-Rückbau danach | eine Wahrheit; Prüfung je Schnitt klar; unter dem Limit | kurzer Zwischenstand, in dem ein Lauf mit `konto` aus scheitert (gelöst durch die Randbedingung) | — |
| **A Schalter bleibt in der CI (`konto`), nur die Store-Sperre fällt** | keine Quelländerung | kleinster Eingriff | Xcode-, Simulator- und Tag-Läufe blieben ohne Konto; zwei Wahrheiten (Quelle aus, Archiv an) bleiben | die PO-Entscheidung vom 2026-11-22 (Schnittplan S5b/S5c) |
| **B S5b und S5c in einem PR** | kein Zwischenstand | sicher gegen versehentlichen Lauf dazwischen | Prüfung weniger klar, Hotspot `testflight.yml` mit der Quelländerung vermischt | keine ADR; verworfen, weil die Randbedingung den Zwischenstand abdeckt |
| **C Manifest-Quelle von Hand pflegen** | Einträge direkt tippen | kein Skriptaufruf | Abweichung von `ACCOUNT_TYPES` und Fragebogen-Vorlage möglich | verworfen; `apply` ist die eine Quelle |

Keine ADR fällt bei keiner Variante.

## Risiken

- **Gruppe „Claude“ in jeder Ausgabe, Dienst noch zu für Fremde.** Ein Fremder sähe „noch nicht freigeschaltet“. Gegenmittel: kein Store-Bau vor S5d; die Betriebs-Tür öffnet erst dort.
- **Versehentlicher TestFlight- oder Tag-Lauf zwischen S5b und S5c schlägt fehl.** Gegenmittel: Randbedingung; S5c unmittelbar danach; der Fehler wäre laut, nicht still.
- **Unit-Host stürzt am Schlüsselbund ab.** Gegenmittel: AC-8 belegt den Lauf; `storedToken` liefert bei Fehler `nil`.
- **Manifest weicht von `ACCOUNT_TYPES` ab.** Gegenmittel: nur per `apply`, AC-3 und AC-4 halten es im Test gleich.
- **Geräteverhalten (Signierung, Berechtigung, Anmeldung) nur dort sichtbar.** Gegenmittel: Gerätepunkt in der Definition of Done, Stufe 3 über TestFlight.

## Out of Scope / Folgeschnitte

- S5c (CI-Rückbau, Marke, Store-Sperre) und S5d (Store, Betriebs-Tür auf `*`).
- Änderung am Datenschutztext oder an der Fragebogen-Vorlage (Stand unverändert seit S1 bis S4).
- Neue Tests für `AccountWiring` (prüfen eingespeiste Dicts, nicht die Bundle-Info).

## Definition of Done

- [ ] AC-1 bis AC-10 erfüllt, Belege im Belegordner
- [ ] Python-Tests, Unit-Lauf und CI grün; „Generate leaves the tree clean“ grün
- [ ] PR mit `Refs #625` (nie `Closes`), gemergt; S5c unmittelbar danach, kein TestFlight-Lauf dazwischen
- [ ] Stufe 3 (Geräteliste: `project.yml`, `Info.plist`): **Gerätepunkt, kein AC.** Über TestFlight nach S5c, in Hennings normaler App; Henning bekommt in einfachen Worten, was er ausprobieren soll (Einstellungen zeigen die Gruppe „Claude“, Anmeldung mit Apple möglich). Nichts auf seinen Geräten vor seinem „jetzt ist ein Test möglich“. Das Ticket bleibt ohnehin bis S5d offen.
- [ ] #625 kommentiert (Stand Schnitt 5b, Folgen S5c, S5d), Board-Karte aktuell, Memory geschrieben

## Changelog

- 2026-11-23: Initial spec created (Schnitt 5b von #625, Konto-Schalter an der Quelle)

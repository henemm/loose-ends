---
entity_id: feat-615-schnitt-4c2a-freischalten
type: feature
created: 2026-11-09
updated: 2026-11-09
status: draft
workflow: feat-615-s4c2-freischalten
---

# Spec: Berechtigung „Mit Apple anmelden“, Schalter für Konto-Bauten, Store-Sperre, Schnitt 4c-2a (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Teil-Spec für Schnitt 4c-2a; das Issue bleibt offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-s4c2-freischalten.md` (Abschnitte „Befunde“, „Scope Assessment“, „Technical Approach“ sind verbindlich).
Vorgänger: 4c-1 (`docs/specs/feat-615-schnitt-4c1-konto-gruppe.md`, PR #889: Gruppe „Claude“, `AccountWiring`, Fallback aus).
Diese Spec deckt nur 4c-2a ab. Folgeschnitte siehe „Nicht in diesem Schnitt“.

## Für den PO

Die App bekommt die Berechtigung „Mit Apple anmelden“, und TestFlight bekommt einen Schalter „Konto“: Nur wenn er an ist, zeigt
der Bau die Gruppe „Claude“ in den Einstellungen. Ein solcher Bau trägt in seinem „Was testen“-Text eine feste Kennzeichnung, und
das Werkzeug, das Bauten der App-Store-Version zuordnet, nimmt so einen Bau nie. So kann kein Konto-Bau versehentlich in den Store
gehen, bevor der Datenschutztext dafür online steht. **Für dich ändert sich nichts**: Die normale TestFlight-App startet wie
bisher und zeigt die Gruppe „Claude“ nicht. Du musst nichts tun.

## Purpose

Vier kleine, getrennt prüfbare Bausteine, damit 4d (Dienst öffnen) und die Geräteprobe der Anmeldung auf festem Boden stehen:
(1) die Berechtigung `com.apple.developer.applesignin` im App-Ziel (iOS und Mac teilen es), (2) der Info-Wert `LEAccountEnabled`
als echtes Bool, standardmäßig aus, (3) eine TestFlight-Eingabe `konto`, die ihn nur für diesen Lauf einschaltet, belegt und
kennzeichnet, (4) eine Sperre in `scripts/asc_store_version.py`, die gekennzeichnete und unlesbare Bauten nie einer Store-Version
zuordnet. **Regeln vor Modell:** reine Build- und Werkzeugarbeit, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“
entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue — folgt ADR-21 (Weg B: nichts verlässt das Gerät ohne Tippen) und dem Muster von #311/#499 (Berechtigungen und Info-Werte nur in `project.yml`); keine neue Abhängigkeit.
- **Rationale:** (1) Der Schalter bleibt ein echtes Bool (`AccountWiring.isEnabled` verlangt `CFBoolean`, bleibt unverändert); ein Build-Setting würde in der Info.plist zum Text. Deshalb setzt der Lauf den Wert nach `xcodegen generate` per `plutil -replace … -bool YES` und belegt ihn am fertigen Archiv. (2) Die ASC-API kennt kein freies Merkmal am Bau, lesbar ist aber je Bau `GET /v1/builds/{id}/betaBuildLocalizations` mit dem Text „Was testen“ (Feld `whatsNew`, so schreibt es `asc_what_to_test.py` schon). Die Kennzeichnung dort ist das einzige Merkmal, das Apple am Bau speichert und das Claude per GET wieder liest. (3) Die Sperre ist fail-closed: ein Bau, dessen Texte nicht lesbar oder leer sind, gilt als gesperrt. Ein zu Unrecht gesperrter Bau kostet nur einen neuen Lauf, ein zu Unrecht zugeordneter Konto-Bau einen Store-Bau ohne Konto-Datenschutztext. (4) Die Berechtigung steht in jedem Bau (Store und TestFlight), ist aber ohne den Schalter folgenlos: Gruppe verborgen, `forApp` liefert `nil`, kein Schlüsselbund, kein Netz. (5) `LEServiceURL` wird **nicht** gesetzt: `AccountWiring.serviceURL` fällt ohne Wert auf `https://loose-ends.henemm.com` zurück, und es gibt keinen zweiten Dienst; ein eigener Schlüssel wäre nur eine zweite Stelle, die falsch stehen kann. Ein Test-Dienst käme erst mit einem Anlass.
- **Alternativen (verworfen):**
  - **Eigene Versionsschiene** (`MARKETING_VERSION` 1.1 nur bei `konto`): Apple selbst verböte dann die Zuordnung zu 1.0.1, stärker als jede Skriptprüfung. Nachteile: die Sperre fällt, sobald eine Store-Version 1.1 entsteht, und TestFlight zeigt zwei Versionsnummern. Würde gewählt, wenn die Prüfung der Kennzeichnung je einmal einen Konto-Bau durchließe. Kippt keine ADR, nur die Festlegung aus 4c (Entwurf A: „asc-store-version ordnet nie zu“, an die Kennzeichnung gebunden).
  - **Buildnummer mit Suffix** (`<run>.1`) als Merkmal: ohne zusätzlichen API-Aufruf, aber im Store-Dialog nicht sprechend, und `pick_build` ordnet Buildnummern numerisch (`\d+(\.\d+)*`), ein Suffix würde den Vergleich der Reihenfolge verfälschen.
  - **Laufzeit-Erkennung** (AppTransaction oder Sandbox-Beleg) statt Schalter: in 4c verworfen, weil App Review in derselben Umgebung läuft.
  - **Schalter als Build-Setting `YES`** und `isEnabled` liest auch Text: lockert die Typprüfung aus 4c-1 (ein falsch gesetzter Text „NO“ wäre dann auch „an“?) und widerspricht AC-9 von 4c-1. Verworfen.

## Recherche (2026-11-09, Quellen)

- Beta-Build-Texte lesen und schreiben: developer.apple.com/documentation/appstoreconnectapi/beta-build-localizations und …/builds (Pfad `/v1/builds/{id}/betaBuildLocalizations`, Attribute `locale`, `whatsNew`).
- Berechtigung: developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.applesignin (Wert `Default`; gilt für iOS und macOS); Capability am App-ID `com.henning.looseends` ist seit #621 S6b eingeschaltet, Cloud-Signierung übernimmt sie ins Profil, sobald die Berechtigung im Archiv steht (Muster #311).
- Kein Diff-Test gegen `origin/main`; Gerätestufe für `project.yml`/`.entitlements`/`Info.plist` laut CLAUDE.md.

## Source

**Files (MODIFY):** `project.yml`, `.github/workflows/testflight.yml`, `scripts/asc_what_to_test.py`, `scripts/asc_store_version.py`, `scripts/test_asc_what_to_test.py`, `scripts/test_asc_store_version.py`, `docs/reference/testflight.md`, `CLAUDE.md`
**Files (generiert, nach `./scripts/sim.sh generate` eingecheckt):** `LooseEnds/LooseEnds.entitlements`, `LooseEnds/Info.plist`
**Identifier:** `ACCOUNT_BUILD_MARK`, `mark_account_build`, `is_account_build`, `pick_build`, Eingabe `konto`, Schritt „Set the account switch“

### 1. `project.yml`

- `entitlements.properties` des App-Ziels: `com.apple.developer.applesignin: [Default]`. Der Wert hängt nicht von `BUNDLE_ID_SUFFIX` ab; er gilt für Hauptkennung und Prüfbau-Kennung. Derselbe Block gilt für iOS und Mac (ein Ziel).
- `info.properties`: `LEAccountEnabled: false` (YAML-Bool, in der Plist `<false/>`), mit Kommentar: Standard aus, nur der TestFlight-Lauf mit `konto` setzt ihn um (#615 S4c-2a).
- `LEServiceURL` bleibt ungesetzt (Begründung siehe ADR).
- Die zwei generierten Abbilder müssen nach `generate` zum Quelltext passen (`test_entitlements_sync.py`, `test_info_plist_sync.py`, CI-Schritt „Generate leaves the tree clean“).

### 2. `.github/workflows/testflight.yml`

- Neue Eingabe `konto` (`type: boolean`, `default: false`, Beschreibung: „Konto-Bau: schaltet die Gruppe „Claude“ ein, nie für den App Store“). Ein `v*`-Tag-Lauf hat keine Eingaben und ist immer `konto=false`. Der Wert wird einmal als Job-übergreifende Umgebung `ACCOUNT_BUILD: ${{ inputs.konto == true && 'true' || 'false' }}` gesetzt.
- Neuer Schritt „Set the account switch“, `if: env.ACCOUNT_BUILD == 'true'`, **nach** „Generate project“ und **vor** „Archive“ (iOS) bzw. „Archive (macOS)“ (Mac), in beiden Jobs `upload` und `upload-mac`: `plutil -replace LEAccountEnabled -bool YES LooseEnds/Info.plist`. Die Datei ist das Abbild des Ziels; ein Schritt davor ist nötig, weil `xcodegen generate` sie neu schreibt.
- Die Archivprüfung iOS und die Mac-Prüfung belegen je Archiv `LEAccountEnabled`: Typ **bool** (`plutil -type LEAccountEnabled` = `bool`) und Wert gleich der Eingabe (`true` bei `konto=true`, sonst `false`); fehlt der Schlüssel, hat er einen anderen Typ oder den falschen Wert, ist die Prüfung rot und es wird nichts hochgeladen (der Export liegt hinter der Prüfung). Gilt auch für `konto=false`, damit jeder gewöhnliche Bau als „aus“ belegt ist.
- Dieselben Prüfungen belegen die Berechtigung `com.apple.developer.applesignin` im **signierten** Archiv: iOS mit dem vorhandenen `entitled com.henning.looseends com.apple.developer.applesignin`, Mac in der Liste der Berechtigungsschlüssel der Mac-Prüfung. Die Zeile steht in der Ergebnistabelle der Zusammenfassung.
- Die Jobs `confirm` und `confirm-mac` geben `ACCOUNT_BUILD` an `scripts/asc_what_to_test.py` weiter (dieselbe Job-Umgebung).

### 3. `scripts/asc_what_to_test.py` (Kennzeichnung, eine Stelle)

- Konstante `ACCOUNT_BUILD_MARK = "KONTO-BAU – nie für den App Store"` (sprachneutral, für jede Lokalisierung gleich). Sie steht **nur hier**; `asc_store_version.py` importiert sie, der Workflow nennt den Wortlaut nirgends.
- `mark_account_build(sections)`: hängt die Marke als eigene letzte Zeile an **jeden** Abschnitt (`{Locale: Text}`) an; weil `text_for` für Sprachen ohne Abschnitt auf den deutschen Text zurückfällt, trägt auch jede angelegte oder überschriebene Lokalisierung die Marke. Läuft, wenn die Umgebungsvariable `ACCOUNT_BUILD` genau `true` ist; bei `false` oder fehlend bleibt der Text unverändert.
- Die Längenprüfung (4000 Zeichen je Sprache) läuft **nach** dem Anhängen. Die Marke wird nicht doppelt angehängt, wenn der Text sie schon trägt.
- `is_account_build(texts)`: wahr, wenn irgendeiner der Texte die Marke enthält (Teilstring). Wird in `asc_store_version.py` benutzt.

### 4. `scripts/asc_store_version.py` (`pick_build`)

- Zusätzlich zu den bestehenden Kriterien (VALID, nicht abgelaufen, numerische Buildnummer) liest `pick_build` je Kandidat `GET /v1/builds/{id}/betaBuildLocalizations` und nimmt den Bau **nur**, wenn die Liste lesbar und nicht leer ist und **keine** Lokalisierung die Marke trägt.
- Fail-closed: HTTP-Fehler (404, 5xx), nicht antwortend nach den bestehenden Wiederholungen (`get_data`), leere Liste oder ein Eintrag ohne lesbaren Text → Bau übersprungen, mit Ausgabe „bau <Plattform> <Nummer> übersprungen: konto“ bzw. „… übersprungen: texte nicht lesbar“ (nie der Text, nie Apples Rohantwort).
- Bleibt kein Kandidat, ist das wie bisher `Fatal` („kein gültiger Bau … nichts geschrieben“, ergänzt um die Zahl der übersprungenen), und es ist nichts geschrieben. Die Auswahl bleibt „höchste Buildnummer unter den zugelassenen“. Die Prüfung ist nur GET; ein schon zugeordneter Bau wird nie angefasst (unverändertes Verhalten).

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `AccountWiring.isEnabled` / `serviceURL` (4c-1) | unverändert; verlangt Bool, Fallback-URL genügt |
| `scripts/asc_what_to_test.py`: `split_sections`, `write_what_to_test`, `get_data` | Marke wird vor dem Schreiben angehängt |
| `scripts/asc_store_version.py`: `pick_build`, `get_data`, `anlegen` | liest zusätzlich die Lokalisierungen |
| `scripts/test_entitlements_sync.py`, `scripts/test_info_plist_sync.py` | belegen die generierten Abbilder |
| `.github/workflows/asc-store-version.yml` | führt `scripts/test_asc_store_version.py` aus (unverändert) |
| App-ID `com.henning.looseends` | Capability „Sign in with Apple“ schon an (#621 S6b) |
| Prüfbau-Kennung `com.henning.looseends.probe` | trägt die Capability noch nicht; relevant nur beim nächsten `LOOSEENDS_REGISTER=1 device-build` (nur nach Hennings „jetzt ist ein Test möglich“) |
| Upstream | 4c-1 (gemergt) |
| Downstream | 4c-2b (F001/F002), 4d (nginx, Datenschutztext), #795 |

## Acceptance Criteria

Python-Tests als `unittest` im Stil der vorhandenen Skripttests (lokaler HTTP-Nachbau mit Zustand, `FakeASC`), Lauf mit
`python3 scripts/test_asc_store_version.py`, `python3 scripts/test_asc_what_to_test.py`, `python3 scripts/test_entitlements_sync.py`,
`python3 scripts/test_info_plist_sync.py`. Workflow-Aussagen (Reihenfolge, Bedingung) prüft ein Textlauf über die YAML-Datei im Stil
von `WORKFLOW` in `test_asc_store_version.py`.

- **AC-1:** Berechtigung: `project.yml` führt `com.apple.developer.applesignin: [Default]` in `entitlements.properties` des App-Ziels, `LooseEnds/LooseEnds.entitlements` trägt `<key>com.apple.developer.applesignin</key>` mit `Default`, und `generate` hinterlässt keinen Diff. Test: `scripts/test_entitlements_sync.py` (vorhandene Vergleiche) plus Fall `test_app_target_has_applesignin` (liest die Quelle und prüft den Schlüssel und `Default`).
- **AC-2:** Schalter aus als Bool: `project.yml` führt `LEAccountEnabled: false`, `LooseEnds/Info.plist` trägt den Schlüssel als `<false/>` (Typ Bool, nicht Text), `LEServiceURL` fehlt in beiden. Test: `scripts/test_info_plist_sync.py` (vorhandene Vergleiche) plus Fall `test_account_switch_is_a_false_bool` (`plistlib` liefert `False`, Typ `bool`, kein `LEServiceURL`).
- **AC-3:** Eingabe: `testflight.yml` hat die Eingabe `konto` mit `type: boolean` und `default: false`; `ACCOUNT_BUILD` ist nur dann `true`, wenn `inputs.konto == true`, ein `v*`-Tag-Lauf also immer `false`. Test: `test_workflow_has_konto_input_default_false` (Textlauf).
- **AC-4:** Setzen vor dem Archiv: in beiden Jobs `upload` und `upload-mac` steht der Schritt mit `plutil -replace LEAccountEnabled -bool YES LooseEnds/Info.plist` unter der Bedingung `ACCOUNT_BUILD == 'true'`, hinter „Generate project“ und vor dem Archiv-Schritt desselben Jobs; ohne die Bedingung käme er nirgends vor. Test: `test_switch_step_is_conditional_and_between_generate_and_archive` (Textlauf, je Job).
- **AC-5:** Beleg am Archiv: die Archivprüfung (iOS) und die Mac-Prüfung enthalten je eine Prüfung von `LEAccountEnabled` auf Typ `bool` und Wert gleich der Eingabe; Abweichung (Schlüssel fehlt, Text statt Bool, falscher Wert) setzt den Schritt auf rot. Test: `test_archive_checks_prove_switch_type_and_value` (Textlauf: Schlüssel und `plutil -type` in beiden Prüfungen) sowie `test_switch_check_logic`, der den Prüfausschnitt des Workflows für die Fälle `bool true`, `bool false`, `string YES`, fehlend gegen die Eingabe `true`/`false` ausführt (Shell auf einer erzeugten Beispiel-Plist; erwartet 8 Ergebnisse als Tabelle).
- **AC-6:** Beleg der Berechtigung am signierten Archiv: die iOS-Prüfung ruft `entitled com.henning.looseends com.apple.developer.applesignin` auf, die Mac-Prüfung führt `com.apple.developer.applesignin` in der Schlüsselliste; fehlt sie, ist der Schritt rot. Test: `test_archive_checks_prove_applesignin_entitlement` (Textlauf). Der echte Beleg am echten Archiv entsteht erst im ersten TestFlight-Lauf nach dem Merge (siehe Definition of Done).
- **AC-7:** Kennzeichnung: `scripts/asc_what_to_test.py` hängt bei `ACCOUNT_BUILD=true` die Marke `ACCOUNT_BUILD_MARK` als letzte Zeile an **jeden** Abschnitt an (auch bei `de:`/`en:`-Abschnitten und bei Text ohne Marker); bei `false` und fehlender Variable bleibt der Text unverändert; kein doppeltes Anhängen; die 4000-Zeichen-Grenze gilt inklusive Marke (ein Text mit 3990 Zeichen ist mit Marke zu lang → `Fatal`). Gegenprobe am Nachbau: jede beim Schreiben (PATCH und POST) gesendete Fassung enthält die Marke. Test: `test_mark_is_added_to_every_section`, `test_mark_not_added_when_off`, `test_mark_respects_length_limit`, `test_mark_in_every_written_localization` in `scripts/test_asc_what_to_test.py`.
- **AC-8:** Eine Quelle: der Wortlaut der Marke steht genau einmal als Konstante in `scripts/asc_what_to_test.py`; `scripts/asc_store_version.py` importiert sie, `testflight.yml` nennt den Wortlaut nicht. Test: `test_mark_defined_once` (liest die drei Dateien, zählt den Wortlaut: eine Fundstelle).
- **AC-9:** Sperre: Gegeben Bauten 133 (ohne Marke), 134 (Marke in einer Lokalisierung), 135 (Marke in allen), 136 (ohne Marke) für Version 1.0.1, wählt `pick_build` 136; sind 136 und 135 gekennzeichnet, wählt es 133; die Ausgabe nennt je Übersprungenen die Buildnummer mit Grund `konto`. `anlegen` ordnet nie einen gekennzeichneten Bau zu (PATCH-Aufrufe geprüft). Test: `test_pick_build_skips_account_builds`, `test_anlegen_never_assigns_account_build` in `scripts/test_asc_store_version.py`.
- **AC-10:** Fail-closed: ist für einen Kandidaten `GET …/betaBuildLocalizations` nicht lesbar (404, 500 und kein Antworten nach den Wiederholungen) oder die Liste leer, wird der Bau übersprungen (Grund `texte nicht lesbar`) und nie gewählt; bleibt kein Kandidat, endet der Lauf mit `Fatal` und **keinem** Schreibaufruf; kein Apple-Rohtext in der Ausgabe. Test: `test_pick_build_fail_closed_on_unreadable`, `test_pick_build_fail_closed_on_empty`, `test_pick_build_nothing_left_writes_nothing` in `scripts/test_asc_store_version.py`.
- **AC-11:** Keine Wirkung auf das Vorhandene: ohne gekennzeichnete Bauten und mit lesbaren Lokalisierungen wählt `pick_build` wie bisher den Bau mit der höchsten (numerischen) Buildnummer; ein schon zugeordneter Bau bleibt unverändert; die bestehenden Tests von `test_asc_store_version.py` bleiben grün (der Nachbau liefert für Bauten ohne Angabe eine Lokalisierung ohne Marke). Test: `test_pick_build_unchanged_without_marks` plus der vorhandene Satz.
- **AC-12:** Doku: `docs/reference/testflight.md` beschreibt die Eingabe `konto`, die Kennzeichnung samt der Regel „nie einem Store-Bau zuordnen, nie ohne Datenschutztext“ und die zwei neuen Prüfungen; der Abschnitt „Ship“ in `CLAUDE.md` nennt Eingabe, Marke und Sperre in einem Satz. Test: `test_docs_name_account_build` in `scripts/test_asc_what_to_test.py` (liest beide Dateien: `konto`, `applesignin` und `LEAccountEnabled` in `testflight.md`, `konto` im Abschnitt „Ship“ von `CLAUDE.md`; der Wortlaut der Marke steht in keiner der beiden, AC-8).
- **AC-13:** Regression und Grenze: `./scripts/sim.sh generate` hinterlässt keinen Diff gegen die eingecheckten Abbilder; `./scripts/sim.sh sim-unit` (alle Unit-Tests) grün; `./scripts/sim.sh build` und `./scripts/sim.sh mac-build` bauen ohne Fehler und ohne neue Warnungen (die Berechtigung ändert beide Bauten); `python3 scripts/test_catalog_languages.py` unverändert grün. Test: `test_entitlements_sync.py` und `test_info_plist_sync.py` (Abbild = Quelle), der vorhandene `sim-unit`-Satz, die Bauläufe `build`/`mac-build` und der CI-Schritt „Generate leaves the tree clean“ auf dem PR. Die Dateigrenze des Schnitts (nur die Tabelle „Affected Files“) prüft `/60-validate` einmalig, kein Test gegen `origin/main` (Projektregel).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `project.yml` | MODIFY | Berechtigung `applesignin`, Info `LEAccountEnabled: false`, ≈ +6 |
| `LooseEnds/LooseEnds.entitlements` | MODIFY (generiert) | Abbild, ≈ +2 |
| `LooseEnds/Info.plist` | MODIFY (generiert) | Abbild, ≈ +2 |
| `.github/workflows/testflight.yml` | MODIFY | Eingabe, `ACCOUNT_BUILD`, Schalt-Schritt in zwei Jobs, Prüfungen, ≈ +50 |
| `scripts/asc_what_to_test.py` | MODIFY | Konstante, `mark_account_build`, `is_account_build`, ≈ +20 |
| `scripts/asc_store_version.py` | MODIFY | `pick_build` mit Sperre, ≈ +25 |
| `scripts/test_asc_what_to_test.py` | MODIFY | AC-7, AC-8, Workflow-Textläufe AC-3 bis AC-6, ≈ +90 |
| `scripts/test_asc_store_version.py` | MODIFY | Nachbau für `betaBuildLocalizations`, AC-9 bis AC-11, ≈ +70 |
| `docs/reference/testflight.md`, `CLAUDE.md` | MODIFY | Doku, ≈ +8, zählt nicht als Code |

### Estimated Changes

- Handgeschriebene Dateien: 6 (project.yml, Workflow, zwei Skripte, zwei Testdateien) plus 2 generierte Abbilder plus Doku (2). **Produktseite ≈ 100 LoC** (project.yml, Workflow, zwei Skripte), **Tests ≈ 160 LoC**, generiert ≈ 4, gesamt ≈ 265. Das liegt knapp über „±250 LoC“ und über „4 bis 5 Dateien“ durch Tests und generierte Abbilder, nicht durch Produktlogik; wie in 4b-2/4b-3 und 4c-1 zählen Tests und generierte Dateien nicht gegen die Produktgrenze (4 Quelldateien, ≈ 100 LoC). Das ist beim Annehmen der Spec ausdrücklich zu bestätigen. Teilungsvorschlag, falls nicht bestätigt: **4c-2a-1** = Berechtigung und Schalter (project.yml, Abbilder, Workflow), **4c-2a-2** = Kennzeichnung und Sperre (zwei Skripte, Tests). Empfehlung: nicht teilen, weil die Sperre den Schalter erst sicher macht und beide zusammen geprüft werden müssen, bevor ein Konto-Bau entstehen darf.
- Permissions: **eine neue Berechtigung** (`com.apple.developer.applesignin`) in jedem Bau (Store und TestFlight), folgenlos ohne Schalter. Neue `Info.plist`-Schlüssel: `LEAccountEnabled` (aus). Keine AppStorage-Schlüssel, kein CloudKit-Schema, keine neuen Pakete, kein Audio, keine Änderung an Swift-Code.
- Seiteneffekte: die Cloud-Signierung legt beim nächsten Lauf die Capability im Provisioning-Profil an (beide Plattformen); das Mac-Profil muss sie tragen, sonst scheitert der Mac-Lauf mit klarer Profil-Meldung (Rückfall: Eingabe `konto` bleibt aus, Berechtigung prüft Beleg). Der Prüfbau (`.probe`) braucht die Capability an seiner Kennung erst bei einem Registrierungslauf.

## Risiken

- **Signierung und Berechtigung (Klasse App-Group-Absturz):** eine neue Berechtigung im Archiv kann, wenn das Profil sie nicht trägt, einen Bau unsignierbar oder beim Start abgelehnt machen. Gegenmittel: die Capability ist am App-ID eingeschaltet (#621 S6b); die signierte Archivprüfung (AC-6) stoppt vor dem Hochladen; Stufe 3 (siehe Definition of Done).
- **Mac-Profil:** `applesignin` am Mac-Ziel in der Sandbox ist unbelegt, bis der erste Mac-Lauf es zeigt (Rückfall aus 4c-1: Web-Anmeldung, Alternative C).
- **Marke in „Was testen“ ist schreibbar:** wer den Text später in App Store Connect von Hand überschreibt, löscht die Sperre. Gegenmittel: fail-closed deckt nur Unlesbares ab, nicht Überschriebenes; deshalb ist die Archivprüfung (Typ und Wert am Archiv) der eigentliche Beleg und die Marke nur der Weg, den die Zuordnung liest. Ein späterer, stärkerer Weg ist die Versionsschiene (Alternative oben). Im Abschlussbericht benannt.
- **Zeitfenster:** zwischen Upload und `asc_what_to_test.py` (Job `confirm`) trägt ein Konto-Bau die Marke noch nicht; eine Zuordnung in genau diesem Fenster würde ihn nicht erkennen, weil dann die Lokalisierung fehlt oder leer ist, und fail-closed ihn **sperrt** (leere Liste = gesperrt). Das Fenster ist damit geschlossen.
- **Umfang:** siehe Estimated Changes.
- **Nicht geprüft:** das echte Verhalten von Apples API bei `betaBuildLocalizations` eines frisch hochgeladenen Baus ist nur im Nachbau belegt; der echte Beleg ist der erste Lauf mit `konto=true` (siehe Definition of Done).

## Test Plan

### Automated Tests (TDD RED)

RED: die neuen Fälle schlagen zunächst fehl, weil `project.yml` die Schlüssel nicht trägt, `ACCOUNT_BUILD_MARK`, `mark_account_build` und `is_account_build` fehlen, `pick_build` keine Lokalisierungen liest und der Workflow weder Eingabe noch Schritt hat. Gegenrichtungen sind Prüfungen: AC-7 (aus → Text unverändert), AC-10 (nichts geschrieben), AC-11 (ohne Marke wie bisher).

| Testname | AC |
|---|---|
| `test_app_target_has_applesignin` + `test_entitlements_sync.py` | AC-1 |
| `test_account_switch_is_a_false_bool` + `test_info_plist_sync.py` | AC-2 |
| `test_workflow_has_konto_input_default_false` | AC-3 |
| `test_switch_step_is_conditional_and_between_generate_and_archive` | AC-4 |
| `test_archive_checks_prove_switch_type_and_value`, `test_switch_check_logic` | AC-5 |
| `test_archive_checks_prove_applesignin_entitlement` | AC-6 |
| `test_mark_is_added_to_every_section`, `test_mark_not_added_when_off`, `test_mark_respects_length_limit`, `test_mark_in_every_written_localization` | AC-7 |
| `test_mark_defined_once` | AC-8 |
| `test_pick_build_skips_account_builds`, `test_anlegen_never_assigns_account_build` | AC-9 |
| `test_pick_build_fail_closed_on_unreadable`, `test_pick_build_fail_closed_on_empty`, `test_pick_build_nothing_left_writes_nothing` | AC-10 |
| `test_pick_build_unchanged_without_marks` + vorhandener Satz | AC-11 |
| `test_docs_name_account_build` | AC-12 |
| `test_entitlements_sync.py`, `test_info_plist_sync.py`, vorhandener `sim-unit`-Satz, `build`, `mac-build`, `test_catalog_languages.py`, CI „Generate leaves the tree clean“ | AC-13 |

- [ ] Test 1 (AC-9): GIVEN Bauten 133, 134 (gekennzeichnet), 135 (gekennzeichnet), 136 WHEN `pick_build` für 1.0.1 THEN 136; GIVEN 136 und 135 gekennzeichnet THEN 133; die Ausgabe nennt die übersprungenen Nummern.
- [ ] Test 2 (AC-10): GIVEN `betaBuildLocalizations` eines Kandidaten antwortet 500 oder ist leer WHEN `pick_build` THEN Bau übersprungen; GIVEN alle Kandidaten unlesbar THEN `Fatal` und null Schreibaufrufe.
- [ ] Test 3 (AC-7): GIVEN Text mit `de:`- und `en:`-Abschnitt und `ACCOUNT_BUILD=true` WHEN geschrieben THEN jede PATCH/POST-Fassung endet mit der Marke; GIVEN `ACCOUNT_BUILD=false` THEN Text unverändert.
- [ ] Test 4 (AC-3 bis AC-6): GIVEN die Workflow-Datei WHEN gelesen THEN Eingabe, bedingter Schritt zwischen „Generate project“ und Archiv in beiden Jobs, Typ- und Werteprüfung und die Berechtigungsprüfung in beiden Archivprüfungen.

## Nicht in diesem Schnitt / Folgeschnitte

- **4c-2b:** F001 (Apple-Knopf in `signingIn` sichtbar und deaktiviert statt ausgeblendet; ändert die Layout-Tabelle und AC-8 aus 4c-1) und F002 (`AccountWiring.serviceURL` nur `https`, `http` höchstens für localhost im Debug); App-Code, Stufe 2.
- **4d:** nginx öffnet genau `/auth/apple`, `/auth/logout`, `/auth/delete` mit eigener Limit-Zone (Repo `henemm-infra`); Prüfung, dass `APPLE_CLIENT_IDS` die App-ID enthält; Konto-Teil des Datenschutztextes (#625) auf henemm.com; danach TestFlight-Bau mit `konto=true` und die Geräteprobe (Anmelden, Abmelden, Löschen).
- **#795:** Abschrift hochladen mit dem Sitzungstoken.
- **Kein Store-Bau mit eingeschaltetem Schalter**, bevor der Konto-Datenschutztext auf henemm.com steht (Memory `loose-ends-615-s4-datenschutz-vorgezogen`); die Sperre in diesem Schnitt erzwingt das für die Zuordnung, nicht für die Einreichung.
- Nichts auf Hennings Geräten, nichts an `server/`, `Shared/`, am Datenschutztext.

## Abnahme

- Stufe 1 Tests: neue Fälle vorher rot, danach grün (vier Python-Läufe oben, voller `sim-unit`).
- Stufe 2 Simulator: `./scripts/sim.sh generate`, `build`, App ohne `--ui-testing` starten: die Gruppe „Claude“ ist nicht zu sehen (Berechtigung vorhanden, Schalter aus), Screenshot geöffnet und beschrieben; mit `--ui-testing` bleibt der Ablauf aus 4c-1 unverändert (`./scripts/sim.sh test-proof AccountSettingsTests` grün mit maschinellem Beleg).
- Stufe 3 Gerät: **Pflicht**, der Schnitt berührt `project.yml`, eine `*.entitlements` und eine `Info.plist` (Geräteliste in `CLAUDE.md`). Weg: normaler TestFlight-Bau **ohne** `konto` nach dem Merge, Henning nutzt seine App wie gewohnt; er braucht dafür keine Anweisung außer der Rückmeldung, ob sie normal startet und keine Gruppe „Claude“ zeigt.

## Definition of Done

- [ ] AC-1 bis AC-13 erfüllt; AC-1 bis AC-13 als Tests bzw. Bauläufe; die Dateigrenze einmalig im Validierungsprotokoll
- [ ] Python-Tests, `sim-unit`, `build`, `mac-build`, `test-proof AccountSettingsTests`, CI auf dem PR grün
- [ ] Abschluss nach Stufe 2 belegt: Simulator ohne Konto-Gruppe, Archivprüfung im Nachbau
- [ ] **Gerätepunkte (nicht als AC, laut `CLAUDE.md`):** nach dem Merge ein TestFlight-Lauf mit `konto=false` (Build mit Berechtigung): (a) die Archivprüfungen iOS und Mac zeigen `com.apple.developer.applesignin` vorhanden und `LEAccountEnabled` Typ bool, Wert `false` (Belegzeilen in der Lauf-Zusammenfassung); (b) Henning bekommt in einfachen Worten: „Starte die App wie sonst; sie muss normal laufen, und in den Einstellungen darf keine Gruppe ‚Claude‘ stehen“; seine Rückmeldung schließt den Gerätepunkt. **Begründete Entscheidung:** getrennt vom Konto-Bau nach 4d, nicht gebündelt, weil die Berechtigung in jedem Bau steckt, also auch in jedem Store-Bau, und ein Start-Problem (Klasse App-Group-Absturz) so sofort und ohne die Anmelde-Ursache sichtbar wird; ein Konto-Bau nach 4d würde zwei Fehlerklassen mischen. Das Ticket bleibt bis zu seiner Rückmeldung offen (`Refs #615`).
- [ ] Alles ist fertig gebaut und in TestFlight, bevor Henning gerufen wird; er wartet nie auf Claude
- [ ] #615 kommentiert (Stand 4c-2a: Berechtigung, Schalter, Sperre; Folge 4c-2b und 4d), Board-Karte aktuell
- [ ] Abschlussbericht ohne Git-Vokabular; benennt: Marke ist von Hand überschreibbar (Archivprüfung ist der Beleg), Mac-Profil mit `applesignin` erst im ersten Lauf belegt, Prüfbau-Kennung ohne Capability bis zum nächsten Registrierungslauf

## Changelog

- 2026-11-09: Initial spec created (Schnitt 4c-2a, Teil-Spec)

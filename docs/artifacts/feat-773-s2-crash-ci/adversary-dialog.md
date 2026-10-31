# Adversary Dialog — feat-773-s2-crash-ci
Spec: docs/specs/tooling/feat-773-schnitt-2-crash-ci.md
Datum: 2026-10-31 14:28

## Checkliste
- [x] **Eingabe:** `gh workflow run asc-crashes.yml` (nach dem Merge auf `main`).
- [x] **Ausgabe:** Gibt es Meldungen, ein Artefakt `crashes` mit der einen Datei `crashes.tar.gpg` (7 Tage); gibt es keine, nur die
- [x] **Seiteneffekte:** nur lesende Aufrufe an App Store Connect; kein Schreiben ins Repo; keine App-Datei, kein Pfad der Geräteliste.
- [x] **AC-1:** Die Kennzeile (`bundle`, `plattform`, `datum`) druckt nur `str`-Werte aus `^[A-Za-z0-9][A-Za-z0-9._:+-]{0,63}$` ohne `::`; alles andere (Zahl, Objekt, Zeilenumbruch, Leerzeichen, `::`, zu lang) wird `unbekannt`; `<id>.json` bleibt unverändert. Belegt durch `test_non_string_attribute_becomes_unbekannt`, `test_unsafe_attribute_becomes_unbekannt`, `test_only_own_error_line_starts_with_colons`.
- [x] **AC-2:** Eine Seitenfolge, die auf einen schon gesehenen Pfad zurückzeigt (auch auf den Startpfad), bricht mit Exit 1 und `::error::` ab. Belegt durch `test_pagination_loop_exits_1`.
- [x] **AC-3:** `.github/workflows/asc-crashes.yml` startet nur per `workflow_dispatch`, hat `permissions: contents: read`, reicht die drei Secrets nur über `env` durch (kein `${{ secrets.` in einem `run:`-Block), läuft mit `set -euo pipefail`, `umask 077` und `trap`, und lädt nur `crashes.tar.gpg` mit `retention-days: 7` und `if-no-files-found: error` hoch. Belegt durch `test_workflow_structure`, `test_workflow_keeps_secrets_out_of_scripts` und Diff-Durchsicht.
- [x] **AC-4:** Bei null Dateien im Ordner meldet der Workflow `::notice::` und legt kein Artefakt an (Upload-Schritt per Bedingung übersprungen). Belegt durch Diff-Durchsicht des Workflows und `test_workflow_structure` (Bedingung auf dem Upload); im echten Lauf nur beobachtbar, wenn keine Meldung vorliegt (AC-11).
- [x] **AC-5:** `.github/crash-recipient.asc` enthält genau einen öffentlichen Schlüssel (ein `pub`, kein `sec`, kein `ssb`); der geheime Teil liegt nur im Schlüsselbund dieses Macs. Belegt durch `test_recipient_file_is_one_public_key` und die Ausgabe von `gpg --show-keys .github/crash-recipient.asc` im Abschlussbericht (ohne Schlüsselmaterial; nur Typ, Länge, Kennung), dazu `git diff --stat` (keine weitere Schlüsseldatei im Diff).
- [x] **AC-6:** Der Verschlüsselungsweg ist lokal belegt: Probeordner, gepackt und mit `--recipient-file .github/crash-recipient.asc` verschlüsselt, ergibt ein Chiffrat ohne Markierungsstring im Klartext; mit dem Mac-Schlüssel entschlüsselt und entpackt sind alle Probedateien byte-gleich. Belegt durch `test_encrypt_with_recipient_file_hides_content` (auch CI) und `test_roundtrip_with_local_key` (nur auf diesem Mac, im Abschlussbericht als „gelaufen, nicht übersprungen“ vermerkt).
- [x] **AC-7:** Kein Klartext verlässt den Runner: Der Workflow lädt ausschließlich `*.gpg` hoch, `trap` löscht Schlüssel, Klartextordner und Klartext-Tar, und es gibt keinen unverschlüsselten Rückfall. Belegt durch `test_workflow_structure`, `test_workflow_keeps_secrets_out_of_scripts` und das Log des echten Laufs (AC-11).
- [x] **AC-8:** `FakeASC.close()` schließt den Socket (`server_close()`); der Testlauf mit `-W error::ResourceWarning` ist grün. Belegt durch `python3 -W error::ResourceWarning scripts/test_asc_crashes.py`.
- [x] **AC-9:** Die Doku `docs/reference/testflight.md` hat den Abschnitt „Absturzberichte abholen (#773)“ mit den sieben Punkten aus Implementation Details 5 (Lauf starten, `gh run download`, `gpg --decrypt` in einen Wegwerf-Ordner, Symbolisierung, Ticket-Regel, Schlüsselverlust und Passphrase-Hinweis, Start erst nach Merge). Belegt durch Diff-Durchsicht und `grep -n "Absturzberichte abholen" docs/reference/testflight.md`.
- [x] **AC-10:** Scope: höchstens 5 Dateien (genau die fünf des Scopes) und ±250 LoC; `scripts/asc_wait_build.py` und `.github/workflows/ci.yml` unverändert; alle vorhandenen Skripttests grün (`python3 -m unittest discover -s scripts -p 'test_*.py'`); nichts auf Hennings Geräten, kein TestFlight-Lauf. Belegt durch `git diff --stat` im Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“ und die Befehlsliste. Stufe 2 (Simulator) entfällt, die App wird nicht berührt.
- [x] **AC-11:** Deploy-Abnahme nach dem Merge. Dies ist ein eigener Abnahmeschritt der Phase Deploy/Abnahme und **kein offenes AC der Validierung**: `workflow_dispatch` lässt sich erst starten, wenn die Datei auf `main` liegt. Nach dem Merge läuft `gh workflow run asc-crashes.yml` grün, das Log zeigt nur erlaubte Zeilen (Schnitt-1-Kennzeilen, Zusammenfassung, `::notice::`; keine E-Mail, kein Kommentar, kein Berichtstext, kein Schlüssel); das Artefakt wird mit `gh run download` geholt, im Scratchpad entschlüsselt und der Inhalt gelesen. Liegt **mindestens eine Meldung mit Bericht** vor: Die Absturzstelle im Code ist benannt, der Befund steht als eigenes Ticket, der Kommentar in #773 enthält keine Personendaten. Liegt **keine oder keine mit Bericht** vor: Ticket #773 bleibt offen (Hinweis 1 der Validierung von Schnitt 1), und der Abschlussbericht sagt das so. Belegt durch Lauf-ID, Log-Auszug (ohne Personendaten), Kommentar in #773.

## Dialog

### Runde 1
**Adversary:** Tests selbst gefahren: `python3 -m unittest discover -s scripts -p 'test_*.py' -v` = 434 Tests OK; danach `python3 -W error::ResourceWarning scripts/test_asc_crashes.py -v` = 24 Tests OK. `test_roundtrip_with_local_key ... ok` (nicht übersprungen). Ausgabe: docs/artifacts/feat-773-s2-crash-ci/adversary-test-output.txt. (Im Discover-Lauf erscheinen ResourceWarnings aus test_asc_beta_invite.py; Datei unverändert gegenüber Basis, nicht Teil dieses Schnitts, Lauf bleibt OK.)
Sondenlauf safe_field (Scratchpad, Python -I): 64 Zeichen ok, 65 -> unbekannt; arabisch-indische Ziffern, `1٣`, `Ａ`, `é` -> unbekannt (explizite ASCII-Bereiche); `a\r`, `a\n` -> unbekannt (fullmatch, kein `$`-Fallstrick); `:`, `:a`, `-a` -> unbekannt; `a:`, `a:b`, `2026-10-30T08:00:00Z` bleiben; `a::b`, `a:::` -> unbekannt; True, 0, leer, None -> unbekannt. Die Kennzeile beginnt immer mit `meldung id=`, kein Weg zu einer Logzeile mit `::` am Anfang.
Schleifenbremse: seen enthält den Startpfad; next_path normalisiert absolute URL, Fragment und `//host`-Form auf Pfad plus Abfrage, daher werden Zyklen über mehrere Seiten und absolute next-URLs erkannt (Code reference: scripts/asc_crashes.py:56). Grenze: ein Zyklus mit je neuem Cursor wird nicht erkannt (nur durch timeout-minutes: 10 begrenzt); die Spec fordert nur schon gesehene Pfade.
Workflow gelesen: der EXIT-trap deckt Schlüsseldatei, Klartextordner und Klartext-Tar auch bei Fehler zwischen tar und gpg (set -e); ein halbes crashes.tar.gpg bliebe liegen, der Upload-Schritt hat kein always()/failure() und wird nach rotem Schritt übersprungen, es gibt keinen unverschlüsselten Upload-Pfad (Code reference: .github/workflows/asc-crashes.yml:28). `find` auf fehlendem Ordner ist unerreichbar, das Skript legt den Ordner per mkdir(parents=True) an. Skript-Exit 1 führt über set -e zu rotem Schritt. Kein Secret-Ausdruck in einem run-Block, Secrets nur unter env.
Schlüsseldatei: `gpg --show-keys` im Wegwerf-GNUPGHOME: ein pub ed25519 [SC] (Kennung 12B7274736C82FE794EC2E03E70D4EA560DB0DEE), uid "Loose Ends Crash Intake", ein sub cv25519 [E]; kein sec/ssb; Text enthält keinen Secret-Block (Code reference: .github/crash-recipient.asc:1). Keine Personendaten in der uid.
Doku: Abschnitt mit allen sieben Punkten vorhanden, keine Personendaten (Code reference: docs/reference/testflight.md:237).
Scope: Diffzählung gegen die Basis a2312141 ergibt scripts/test_asc_crashes.py +197/-4 (Code reference: scripts/test_asc_crashes.py:1), asc_crashes.py +14/-2, testflight.md +20, dazu neu asc-crashes.yml 50 Zeilen und crash-recipient.asc 14 Zeilen = 301 Zeilen. AC-10 fordert ±250 und schätzte 215 (Tests ca. 110, real 201). asc_wait_build.py und ci.yml: kein Diff. Fünf Dateien, wie gefordert.
**Implementierer:** (nicht beteiligt, Kontext-Isolation)

### Runde 2
**Adversary:** Nachbohren an Testwirksamkeit und Randfällen. (a) test_workflow_keeps_secrets_out_of_scripts sucht den Literal mit Leerzeichen nach den geschweiften Klammern; die Schreibweise ohne Leerzeichen in einem run-Block würde nicht erkannt (die Datei nutzt in `path:` schon `${{runner.temp}}` ohne Leerzeichen). Abgeschwächter Schutz, kein aktueller Fehler (LOW). (b) Der Job-env reicht das ASC-Schlüssel-Secret an alle Schritte durch, auch an checkout und upload-artifact; die Spec fordert dieses Muster, schmaler wäre env nur am Fetch-Schritt (LOW). (c) Verschlüsselt wird an den Schlüssel, der in der Datei steht, ohne Fingerprint-Pin; wer die Datei per Änderung austauscht, bekäme die Berichte; Schutz nur Review und Repo-Rechte (LOW). (d) workflow_dispatch läuft auch von einem Zweig mit geändertem Workflow-Text; wie bei den anderen Workflows, nicht neu. (e) Die Meldung `Pagination loop at <pfad>` druckt einen Server-Pfad; urlsplit entfernt rohe Zeilenumbrüche, Prozent-Kodierung bleibt kodiert, kein `::`-Beginn (kein Fund). (f) Leeres Secret: printf schreibt eine Leerzeile, die Anfrage scheitert als Fatal, Exit 1, kein Upload (kein Fund).
Ehrlich offen, per Texttest nicht belegbar: dass der trap auf dem Runner greift, dass retention-days wirkt, dass gpg 2.4.x auf ubuntu-latest `--recipient-file` mit dieser Datei akzeptiert, ob upload-artifact den Pfad `${{runner.temp}}/crashes.tar.gpg` findet, und die Logzeilen des echten Laufs. Das zeigt erst AC-11 nach dem Merge. Eingabe (`gh workflow run`) ist vor dem Merge nicht startbar und deshalb nicht abgehakt; AC-11 ist laut Spec Deploy-Abnahme und bleibt offen.
**Implementierer:** (nicht beteiligt)

### Runde 3
**Implementierer:** PO-Freigabe zu F001 (Henning, 2026-10-31, Auswahl "So lassen"): Die Überschreitung auf rund 301 Zeilen bleibt, weil der Mehrumfang reiner Prüfcode ist (Produktanteil rund 100 Zeilen); keine Straffung. F002 bis F004 bleiben LOW und sind bewusst nicht umgesetzt: F002 folgt der Spec (Job-env), F003 und F004 sind heute kein Verstoß.
**Adversary:** Neubewertung. AC-10: Dateien (genau fünf), Unverändertheit von asc_wait_build.py und ci.yml und grüne Tests waren schon belegt; das LoC-Limit ist jetzt durch die ausdrückliche PO-Ausnahme gedeckt, F001 gilt als entschieden und nicht mehr blockierend (Code reference: scripts/test_asc_crashes.py:1). AC-10 wird abgehakt. Testausgabe frisch neu erzeugt. Nicht abgehakt bleiben Eingabe und AC-11: Sie sind erst nach dem Merge auf main belegbar (workflow_dispatch); ebenso unbewiesen bis dahin sind trap auf dem Runner, Wirkung von retention-days, gpg 2.4.x mit der Schlüsseldatei, Pfad für upload-artifact und die Logzeilen des echten Laufs. Kein Fund in der Umsetzung; der offene Teil ist nachmerge-pflichtig und kann nicht vor dem Merge geschlossen werden, daher AMBIGUOUS.

### Runde 4
**Implementierer:** Abnahme nach dem Merge (PR #778, 28d57cb). `gh workflow run asc-crashes.yml --ref main` → Lauf 41216707696, Ergebnis success. Log: nur `meldung id=… bundle=com.henning.looseends plattform=IOS datum=… bericht=ja` (5×) und `zusammenfassung meldungen=5 mit_bericht=5 ohne_bericht=0`; Secrets als `***`; Suche nach E-Mail-Mustern im ganzen Log: 0 Treffer; kein Kommentar, kein Berichtstext. `gh run download 41216707696 -n crashes` → eine Datei `crashes.tar.gpg` (18159 Byte); `gpg --decrypt` mit dem Mac-Schlüssel (cv25519 D5BB4927B5F934DB, „Loose Ends Crash Intake“) und `tar -x` im Scratchpad → 10 Dateien (5× `.json`, 5× `.crash`). Damit belegt auf dem Runner: gpg mit `--recipient-file`, Upload-Pfad `${{runner.temp}}/crashes.tar.gpg`, nur Chiffrat hochgeladen.
Befund gelesen: 2× `closure #1 in static BackgroundRefresh.register(_:)` (Build 98, Build 126), `_swift_task_checkIsolatedSwift` → `EXC_BREAKPOINT`, Absturzstelle `LooseEnds/Notifications/BackgroundRefresh.swift` (Handler erbt `@MainActor`, `using: nil` = Hintergrund-Queue) → eigenes Ticket #780 (P0, M1). 2× `SpeechCapture.requestSpeechAuthorization` (Build 1), Funktion im aktuellen Code nicht mehr vorhanden. 1× SwiftUI-`UICollectionView` „Invalid number of items“ (Build 87), kein App-Rahmen. Kommentar in #773 (issuecomment-6545668527) ohne Personendaten. #773 bleibt offen bis #780 ausgeliefert ist.
**Adversary:** Eingabe und AC-11 sind mit Lauf-ID, Log-Auszug, Artefakt und Kommentar belegt; die in Runde 2 offen genannten Punkte (gpg 2.4.x mit der Schlüsseldatei, Upload-Pfad, Logzeilen des echten Laufs) sind damit gezeigt. Nicht direkt beobachtbar bleibt die Wirkung von `retention-days` (erst nach 7 Tagen) und das Aufräumen durch `trap` auf dem Wegwerf-Runner; beides ist durch Text und Tests belegt und kein offenes AC.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Findings

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: scripts/test_asc_crashes.py:1
  Description: Die Änderung gegen die Basis a2312141 umfasst 301 Zeilen (Tests +197/-4, asc_crashes.py +14/-2, Doku +20, Workflow 50, Schlüsseldatei 14). Die Tests sind rund 90 Zeilen größer als geschätzt (ca. 110).
  Spec requirement: AC-10 — höchstens ±250 LoC
  Conflict: 301 > 250; Scoping-Limit der Projektregeln ebenfalls überschritten. Die Spec-Schätzung (ca. 215) trifft nicht.
  Remediation: Tests straffen oder die Überschreitung vom Product Owner ausdrücklich freigeben lassen.

Finding:
  ID: F002
  Severity: LOW
  Category: anti_pattern
  Code reference: .github/workflows/asc-crashes.yml:19
  Description: Das ASC-Schlüssel-Secret steht im Job-env und liegt damit auch in der Umgebung von checkout und upload-artifact.
  Spec requirement: AC-3 — Secrets nur über env (erfüllt); engere Streuung nicht gefordert
  Conflict: Unnötig breite Sichtbarkeit für Drittaktionen.
  Remediation: env auf den Schritt "Fetch, pack and encrypt" verlegen.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_asc_crashes.py:415
  Description: Der Secrets-Test sucht den Literal mit Leerzeichen nach den geschweiften Klammern; die Schreibweise ohne Leerzeichen in einem run-Block bliebe unentdeckt.
  Spec requirement: AC-3 — kein Secret-Ausdruck in einem run-Block
  Conflict: Schutz per Schreibweise umgehbar; heute kein Verstoß.
  Remediation: Regex mit optionalem Leerraum statt Literal.

Finding:
  ID: F004
  Severity: LOW
  Category: security
  Code reference: .github/crash-recipient.asc:1
  Description: Kein Fingerprint-Pin; der Workflow verschlüsselt an den Schlüssel, der in der Datei steht.
  Spec requirement: AC-5/AC-7 — nur Chiffrat verlässt den Runner
  Conflict: Ein Austausch der Datei (Review nötig) machte Berichte für Dritte lesbar; die Doku nennt es nicht.
  Remediation: Kennung 12B7274736C82FE794EC2E03E70D4EA560DB0DEE in Doku nennen und im Test prüfen.

Confirmation:
  AC: AC-1
  Code reference: scripts/asc_crashes.py:105
  Evidence: safe_field mit ASCII-fullmatch; Sondenlauf und 3 Tests grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/asc_crashes.py:56
  Evidence: seen-Menge mit Startpfad, Fatal bei Wiederholung; test_pagination_loop_exits_1 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3, AC-4, AC-7
  Code reference: .github/workflows/asc-crashes.yml:28
  Evidence: nur workflow_dispatch, contents: read, trap, Upload nur bei encrypted=true und nur *.gpg, kein Klartext-Rückfall; Form per Text belegt, Laufverhalten erst AC-11.
  Status: CONFIRMED

Confirmation:
  AC: AC-5, AC-6
  Code reference: .github/crash-recipient.asc:1
  Evidence: ein pub, ein sub, kein sec/ssb; Verschlüsselungs- und Roundtrip-Test laufen, Roundtrip nicht übersprungen.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/test_asc_crashes.py:1
  Evidence: Lauf mit `-W error::ResourceWarning`: 24 Tests OK.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: docs/reference/testflight.md:237
  Evidence: Abschnitt mit sieben Punkten, keine Personendaten.
  Status: CONFIRMED

## Verdict
VERDICT: VERIFIED
Proven points: alle ACs inklusive Eingabe und AC-11 (Lauf 41216707696 nach dem Merge). F001 per PO-Ausnahme entschieden (2026-10-31). F002 bis F004 LOW, bewusst nicht umgesetzt.
Tests: 434 bestanden (Discover), 24 bestanden (-W error::ResourceWarning), 0 fehlgeschlagen, 0 übersprungen in test_asc_crashes.

## Geprüfte Dateien

- sha256:caa0b90e0b485be2bf7f8a32c59e22253688e4263786655d00c7ef25c2cff7a0  .github/crash-recipient.asc
- sha256:1880cbc56d2ff8124d49eec1502fe87afdf5bef6be8e2129f19ffeec22a2a30d  .github/workflows/asc-crashes.yml
- sha256:9e58e0cbba9cd8a740ec91381656ac5eff3365115e941eeb2f475d08d6922abd  docs/reference/testflight.md
- sha256:6c078a10f86b8afe9c66238c166b3a23b68a23f4d223656909aca81a3773a213  scripts/asc_crashes.py
- sha256:4ec991a3b84928f7fb7684a3610f7e0e081f7aa7fc84bd50a625fb5fce276f5d  scripts/test_asc_crashes.py

## Prüfbasis

- base: a23121411718e003968988fde019de1bfb1ba869
- blob:99eda3118a19daaebca8664f933f531eb1a61741  .github/crash-recipient.asc
- blob:cdc3477dff529436ab27888afcd6d6ae8d5ada9c  .github/workflows/asc-crashes.yml
- blob:bc68da66997e6bcc0ae35832418afb91c3ee9aad  docs/reference/testflight.md
- blob:944e064d0eaccb9d45b5afa610cd35192aba1c45  scripts/asc_crashes.py
- blob:75305cbd82f3ed7046a3e0c1a04d9942f5c3421d  scripts/test_asc_crashes.py

## Geprüfte Dateien

- sha256:caa0b90e0b485be2bf7f8a32c59e22253688e4263786655d00c7ef25c2cff7a0  .github/crash-recipient.asc
- sha256:1880cbc56d2ff8124d49eec1502fe87afdf5bef6be8e2129f19ffeec22a2a30d  .github/workflows/asc-crashes.yml
- sha256:9e58e0cbba9cd8a740ec91381656ac5eff3365115e941eeb2f475d08d6922abd  docs/reference/testflight.md
- sha256:6c078a10f86b8afe9c66238c166b3a23b68a23f4d223656909aca81a3773a213  scripts/asc_crashes.py
- sha256:4ec991a3b84928f7fb7684a3610f7e0e081f7aa7fc84bd50a625fb5fce276f5d  scripts/test_asc_crashes.py

## Prüfbasis

- base: a23121411718e003968988fde019de1bfb1ba869
- blob:99eda3118a19daaebca8664f933f531eb1a61741  .github/crash-recipient.asc
- blob:cdc3477dff529436ab27888afcd6d6ae8d5ada9c  .github/workflows/asc-crashes.yml
- blob:bc68da66997e6bcc0ae35832418afb91c3ee9aad  docs/reference/testflight.md
- blob:944e064d0eaccb9d45b5afa610cd35192aba1c45  scripts/asc_crashes.py
- blob:75305cbd82f3ed7046a3e0c1a04d9942f5c3421d  scripts/test_asc_crashes.py

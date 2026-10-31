---
entity_id: feat-773-schnitt-2-crash-ci
type: feature
created: 2026-10-31
updated: 2026-10-31
status: draft
workflow: feat-773-s2-crash-ci
---

# Spec: #773 Schnitt 2 „Crash-CI“: Absturzmeldungen per Handlauf verschlüsselt ablegen und auswerten

## Approval

- [ ] Approved

## Purpose

Schnitt 1 (PR #775) hat `scripts/asc_crashes.py` geliefert: Es holt die TestFlight-Absturzmeldungen samt Bericht von Apple und
schreibt sie in einen Zielordner. Es läuft aber nur gegen einen Nachbau; auf diesem Mac gibt es bewusst keinen App-Store-Connect-
Schlüssel. Schnitt 2 baut den Weg, auf dem Claude die Meldungen wirklich bekommt: ein Handlauf in der CI (`workflow_dispatch`),
der das Skript mit den vorhandenen Secrets ausführt, den Ordner **verschlüsselt** als Artefakt ablegt, und ein öffentlicher
Schlüssel im Repo, dessen geheimes Gegenstück nur in diesem Mac liegt. Claude lädt das Chiffrat mit `gh run download`, entschlüsselt
es in einen Wegwerf-Ordner und wertet aus. Dazu kommen zwei Härtungen aus der Validierung von Schnitt 1 (Kennzeile, Schleifenbremse),
die vor dem ersten echten Lauf sitzen müssen, und die Doku.

Das Repo ist öffentlich: Lauf-Logs und Artefakte sind für jeden mit GitHub-Konto lesbar, die Meldungen enthalten E-Mail, Kommentar,
Gerätemodell und Zeitzone der Tester. Darum gilt: **Kein Klartext verlässt den Runner.** Hochgeladen wird nur `crashes.tar.gpg`,
der Klartext wird per `trap` gelöscht, die Aufbewahrung beträgt 7 Tage, das Log trägt nur die Zeilen aus Schnitt 1.

Ohne Modell: Abruf, Packen und Verschlüsseln sind Handwerk, kein Sprachverstehen. Ob ein Absturz auszuwerten ist, liest Claude
danach selbst im Bericht.

**Alternativen** (Analyse `docs/context/feat-773-testflight-crashes.md`, Regel „In Alternativen denken“):

- **B: privates Repo als Ablage.** Datenschutz gut, aber die Testerdaten lägen dauerhaft in der Git-Historie, dazu ein neues Repo,
  ein neuer Schlüssel und eine Löschregel. Gekippt würde nichts, es wäre nur mehr Aufwand für denselben Zweck.
- **C: lokaler ASC-Schlüssel auf diesem Mac.** Einfachster Weg (Skript direkt lokal), kippt aber die bewusste Entscheidung „kein
  lokaler ASC-Schlüssel“ (Memory `loose-ends-testflight-belege-abrufbar`). Bei Bedarf ist das Skript unabhängig davon lokal nutzbar.
- **D: Henning lädt die ZIP aus App Store Connect herunter.** Handarbeit je Absturz, sein Ausschluss im Ticket.
- **E: Xcode Organizer.** Unzuverlässig: meine `xcodebuild`-Läufe melden sein Xcode-Konto ab, und der Organizer zeigt nicht alles
  (Apple-Forum, Thread 742210).
- **`openssl` hybrid (RSA plus AES) statt `gpg`.** Kein neuer Schlüsselbund nötig, aber Eigenbau von Schlüsselaustausch und Format
  ohne Gewinn; `gpg --recipient-file` ist erprobt und auf Runner und Mac vorhanden (Mac 2.5.24, ubuntu-latest 2.4.x).

Gewählt ist **A: GPG-verschlüsseltes Artefakt**. Gekippt wird keine ADR.

## Source

- **File:** `.github/workflows/asc-crashes.yml` (neu), `.github/crash-recipient.asc` (neu), `scripts/asc_crashes.py` (Härtung)
- **Identifier:** `store(target, entries)` (Kennzeile), `fetch_all(config, app_id)` (Schleifenbremse); Muster für Schlüssel-Handling:
  `.github/workflows/asc-beta.yml`. Analyse: `docs/context/feat-773-s2-crash-ci.md`; Schnitt 1:
  `docs/specs/tooling/feat-773-schnitt-1-crash-skript.md`.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `scripts/asc_crashes.py` | Skript | Schnitt 1; wird gehärtet und vom Workflow aufgerufen |
| `scripts/asc_wait_build.py` | Skript | `get_json`, `read_config`; bleibt **unverändert** |
| `.github/workflows/ci.yml` | Workflow | Zeile 33 `unittest discover -s scripts -p 'test_*.py'` nimmt die erweiterten Tests mit; bleibt **unverändert** |
| Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` | GitHub Secrets | gibt es schon; der Workflow reicht sie nur über `env` durch |
| `gpg` | Werkzeug | auf `ubuntu-latest` vorinstalliert, auf diesem Mac unter `/opt/homebrew/bin/gpg` |
| `actions/upload-artifact`, `actions/checkout` | Actions | in derselben Hauptversion wie die übrigen Workflows des Repos |
| `docs/reference/testflight.md` | Doku | bekommt den neuen Abschnitt |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| .github/workflows/asc-crashes.yml | CREATE | Handlauf: Skript ausführen, packen, an den öffentlichen Schlüssel verschlüsseln, nur das Chiffrat hochladen |
| .github/crash-recipient.asc | CREATE | nur der öffentliche Schlüssel (ed25519/cv25519, ohne Passphrase, kein Ablauf) |
| scripts/asc_crashes.py | MODIFY | Kennzeile nimmt nur sichere `str`-Werte; Schleifenbremse in `fetch_all` |
| scripts/test_asc_crashes.py | MODIFY | neue Tests für Härtung, Schlüsseldatei, Verschlüsselungsweg, Workflow-Text; `FakeASC.close()` mit `server_close()` |
| docs/reference/testflight.md | MODIFY | Abschnitt „Absturzberichte abholen (#773)“ |

### Estimated Changes
- Files: 5, kein Produktcode, kein Pfad der Geräteliste
- LoC: ca. +215/-3 (Workflow ca. 45, Skript ca. 14, Tests ca. 110, Doku ca. 30, Schlüsselblock ca. 15 Zeilen Text)

## Implementation Details

### 1. `.github/workflows/asc-crashes.yml`

Nur `on: workflow_dispatch` (ohne Eingaben), `permissions: contents: read`, ein Job `crashes` auf `ubuntu-latest`,
`timeout-minutes: 10`. Läuft nie automatisch.

`env` des Jobs: `ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}`, `ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}`,
`ASC_PRIVATE_KEY: ${{ secrets.ASC_PRIVATE_KEY }}`, `ASC_POLL_SECONDS: "5"`. **Kein** `${{ secrets.* }}` im Skripttext eines
`run:`-Blocks (anders als in `asc-beta.yml`): Ein Secret im Skripttext wird vor der Shell eingesetzt; über `env` bleibt es
eine Umgebungsvariable und kann nie als Shell-Syntax gelesen werden.

Schritte:

1. `actions/checkout`.
2. Schritt „Fetch, pack and encrypt“ mit **einem** `run:`-Block (`shell: bash`):
   - `set -euo pipefail` und `umask 077`;
   - `trap 'rm -rf "$RUNNER_TEMP/asc_key.p8" "$RUNNER_TEMP/crashes" "$RUNNER_TEMP/crashes.tar"' EXIT`;
   - Schlüssel schreiben: `printf '%s\n' "$ASC_PRIVATE_KEY" > "$RUNNER_TEMP/asc_key.p8"`;
   - `ASC_KEY_FILE="$RUNNER_TEMP/asc_key.p8" python3 scripts/asc_crashes.py "$RUNNER_TEMP/crashes"`;
   - sind im Ordner keine Dateien (`find "$RUNNER_TEMP/crashes" -type f` leer): `echo "::notice::Keine Absturzmeldungen, es wird kein Artefakt angelegt"`,
     in `$GITHUB_OUTPUT` `encrypted=false` und Ende ohne Fehler;
   - sonst `tar -C "$RUNNER_TEMP/crashes" -cf "$RUNNER_TEMP/crashes.tar" .`, danach
     `gpg --batch --trust-model always --recipient-file .github/crash-recipient.asc --output "$RUNNER_TEMP/crashes.tar.gpg" --encrypt "$RUNNER_TEMP/crashes.tar"`,
     dann das Klartext-Tar sofort löschen (`rm -f`), `encrypted=true` in `$GITHUB_OUTPUT`. Jeder Fehlschlag von `tar` oder `gpg`
     beendet den Schritt rot (`set -e`); es wird nie ersatzweise unverschlüsselt hochgeladen.
3. Schritt „Upload“ nur `if: steps.<id>.outputs.encrypted == 'true'`: `actions/upload-artifact` mit `name: crashes`,
   `path: ${{ runner.temp }}/crashes.tar.gpg`, `retention-days: 7`, `if-no-files-found: error`.

Das Chiffrat bleibt als Datei im `RUNNER_TEMP` liegen (wird mit dem Runner verworfen); gelöscht werden Schlüssel, Klartextordner
und Klartext-Tar durch den `trap`.

### 2. `.github/crash-recipient.asc`

Ein ASCII-gepanzerter **öffentlicher** Schlüsselblock (`gpg --armor --export`), Schlüsseltyp ed25519 (Signatur) mit cv25519
(Verschlüsselung), ohne Passphrase, ohne Ablaufdatum. Der geheime Teil liegt nur im GnuPG-Schlüsselbund dieses Macs und kommt
nie ins Repo, in ein Secret oder in einen Chat.

Erzeugung: `gpg --batch --gen-key <parameterdatei>` mit einer Parameterdatei im Scratchpad (`%no-protection`, `Key-Type: eddsa`,
`Key-Curve: ed25519`, `Subkey-Type: ecdh`, `Subkey-Curve: cv25519`, `Name-Real: Loose Ends Crash Intake`, `Expire-Date: 0`).
Blockt der Secrets-Guard diesen Aufruf (er sperrt Befehle mit Schlüsselbegriffen, auch rein lesende), wird der Guard **gezielt für
diesen gpg-Aufruf** angepasst; die Arbeit geht nicht an Henning. Vor dem Commit belegt `gpg --show-keys .github/crash-recipient.asc`,
dass genau ein Block mit `pub` und `sub` drinsteht und kein `sec`/`ssb`; die Parameterdatei wird nicht eingecheckt.

### 3. `scripts/asc_crashes.py` (Härtung)

**Kennzeile.** In `store` wird jeder der drei Werte (`buildBundleId`, `appPlatform`, `createdDate`) durch eine Prüffunktion
`safe_field(value)` geleitet: Nur ein `str`, der `^[A-Za-z0-9][A-Za-z0-9._:+-]{0,63}$` voll erfüllt und die Folge `::` nicht
enthält, wird gedruckt; jeder andere Wert (Zahl, Objekt, Liste, `None`, Text mit Zeilenumbruch, Leerzeichen, Steuerzeichen,
`::` oder über 64 Zeichen) wird zu `unbekannt`. Der erste Buchstabe ist alphanumerisch, ein einzelner Doppelpunkt bleibt erlaubt
(Zeitangaben wie `2026-10-30T08:00:00Z`). Die Id ist durch `SAFE_ID` schon geprüft. Grund: GitHub wertet jede Logzeile, die mit
`::` beginnt, als Workflow-Befehl; ein Attribut mit Zeilenumbruch plus `::add-mask::` oder `::error::` würde sonst Log und Lauf
beeinflussen (Log-Injection). Die Datei `<id>.json` bleibt **unverändert** (Attribute wie geliefert); nur die Kennzeile wird
gehärtet.

**Schleifenbremse.** `fetch_all` führt eine Menge der schon angefragten Pfade, der Startpfad zählt mit. Liefert `links.next` einen
Pfad, der schon in der Menge ist, wirft `fetch_all` `Fatal("Pagination loop at <pfad ohne Abfrage>")`; `main` macht daraus
`::error::` und Exit 1. Eine Endlosschleife gegen die API entfällt.

### 4. `scripts/test_asc_crashes.py`

`FakeASC.close()` ruft nach `shutdown()` zusätzlich `server_close()` (keine ResourceWarning). Für den Schleifentest bekommt
`FakeASC` einen Parameter `loop=True`, bei dem `links.next` der letzten Seite auf die erste Seite zeigt. Die Konstante `REPO` zeigt
auf die Wurzel des Repos (zwei Ebenen über der Testdatei). Die neuen Tests stehen unten im Testplan. Der Verschlüsselungsweg wird
in dieser Datei geprüft (kein sechster Datei-Eintrag): ein CI-tauglicher Test (nur öffentlicher Schlüssel, Wegwerf-`GNUPGHOME`) und
ein Test, der nur läuft, wenn der geheime Schlüssel im Schlüsselbund liegt (also auf diesem Mac, nicht in der CI).

### 5. `docs/reference/testflight.md`

Neuer Abschnitt „Absturzberichte abholen (#773)“ nach „Einladung: Apple-Seite (#705)“ und vor „Wenn es hakt“. Inhalt:

1. Lauf starten: `gh workflow run asc-crashes.yml`, Lauf finden (`gh run list --workflow asc-crashes.yml`), Ergebnis abwarten
   (`gh run watch`).
2. Holen: `gh run download <id> --name crashes --dir <wegwerf-ordner>`.
3. Entschlüsseln: `gpg --decrypt --output crashes.tar crashes.tar.gpg`, `tar -xf` in einen Wegwerf-Ordner im Scratchpad, nie ins
   Repo; danach den Ordner löschen.
4. Auswerten: `<id>.json` (Attribute), `<id>.crash` (Bericht). Symbolisierung erst, wenn ein Bericht sie braucht (`atos` gegen das
   dSYM aus dem Archiv); ob der Bericht symbolisiert ankommt, ist offen.
5. Was ins Ticket darf: Absturzstelle, Version, Plattform; nie E-Mail, Kommentar, Gerätedaten, Zeitzone.
6. Schlüssel: ohne Passphrase, wer den Mac hat, liest die Artefakte; das Artefakt lebt 7 Tage. Verlust des Schlüssels: neuen
   Schlüssel erzeugen, öffentlichen Teil in `.github/crash-recipient.asc` ersetzen, neuen Lauf starten (Apple hält die Meldungen
   120 Tage, nichts geht verloren).
7. Der Lauf startet erst, wenn die Workflow-Datei auf `main` liegt.

## Expected Behavior

- **Eingabe:** `gh workflow run asc-crashes.yml` (nach dem Merge auf `main`).
- **Ausgabe:** Gibt es Meldungen, ein Artefakt `crashes` mit der einen Datei `crashes.tar.gpg` (7 Tage); gibt es keine, nur die
  Zeile `::notice::` und kein Artefakt. Das Log trägt höchstens die Zeilen aus Schnitt 1 (Id, Bundle, Plattform, Datum,
  Zusammenfassung) sowie die `::notice::`/`::error::` des Workflows und des Skripts.
- **Seiteneffekte:** nur lesende Aufrufe an App Store Connect; kein Schreiben ins Repo; keine App-Datei, kein Pfad der Geräteliste.

## Known Limitations

- Der **Texttest** des Workflows prüft die Form der Datei, nicht das Verhalten von GitHub (ob `trap` auf dem Runner greift, ob die
  Aufbewahrung gesetzt wird). Das zeigen der echte Lauf und sein Log.
- Der **lokale Verschlüsselungstest** belegt `gpg --recipient-file` mit demselben Schlüssel und denselben Schaltern wie im
  Workflow; er läuft aber mit gpg des Macs (2.5.24), der Runner hat 2.4.x. Die Schalter sind in beiden Versionen gleich; der echte
  Lauf belegt es auf dem Runner.
- **Ein Lauf ohne Meldung belegt den Pfad `crashLog` nicht** (Hinweis 1 der Validierung von Schnitt 1: Jede 404 auf `crashLog`
  zählt als „ohne Bericht“, ein falscher Pfad bliebe unentdeckt). Ebenso offen: ob Berichte symbolisiert kommen.
- Schlüssel ohne Passphrase: Wer Zugriff auf diesen Mac hat, kann die Artefakte lesen. Bewusst akzeptiert (Henning arbeitet allein
  an diesem Mac, das Artefakt lebt 7 Tage); in der Doku genannt.
- `workflow_dispatch` ist erst nach dem Merge startbar; vorher gibt es nur den lokalen Beleg.
- Wiederholungen des Skripts bei 408/429/Netz sind weiter nur im Code belegt (Hinweis 6), siehe Out of Scope.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_crashes.py` (bestehende 15 Tests bleiben; 9 neue, zusammen 24). Zuerst geschrieben; ohne Härtung bzw.
ohne Workflow und Schlüsseldatei schlagen sie fehl.

- [ ] `test_non_string_attribute_becomes_unbekannt`: GIVEN Meldung, deren `buildBundleId` eine Zahl, `appPlatform` ein Objekt und `createdDate` eine Liste ist WHEN das Skript läuft THEN Exit 0, die Zeile lautet `… bundle=unbekannt plattform=unbekannt datum=unbekannt …`, `<id>.json` enthält die Werte unverändert.
- [ ] `test_unsafe_attribute_becomes_unbekannt`: GIVEN Meldung mit `buildBundleId = "a\n::add-mask::x"`, `appPlatform = "::error::boom"` und `createdDate = "2026 10 30"` (Leerzeichen) WHEN das Skript läuft THEN je Wert `unbekannt`, keine Zeile in stdout beginnt mit `::`, und ein sicherer Wert wie `2026-10-30T08:00:00Z` bleibt unverändert.
- [ ] `test_only_own_error_line_starts_with_colons`: GIVEN eine Meldung mit Zeilenumbruch und `::error::` im Attribut, danach eine zweite Anfrage mit Statuscode 403 WHEN das Skript jeweils läuft THEN im ersten Lauf beginnt keine stdout-Zeile mit `::`, im zweiten genau eine, und sie ist die eigene `::error::`-Zeile.
- [ ] `test_pagination_loop_exits_1`: GIVEN `FakeASC(loop=True)`, `links.next` der letzten Seite zeigt auf die erste WHEN das Skript läuft THEN Exit 1, stdout enthält `::error::` und `Pagination loop`, der Nachbau hat die Liste höchstens so oft empfangen, wie es Seiten gibt, und im Zielordner liegt keine Datei.
- [ ] `test_recipient_file_is_one_public_key`: GIVEN `.github/crash-recipient.asc` WHEN `gpg --show-keys --with-colons` (Wegwerf-`GNUPGHOME`) sie liest THEN genau ein `pub`-Eintrag, kein `sec` und kein `ssb`, und die Datei enthält `BEGIN PGP PUBLIC KEY BLOCK` und nicht `PRIVATE KEY`.
- [ ] `test_encrypt_with_recipient_file_hides_content`: GIVEN ein Ordner mit Probedateien (`P1.json`, `P1.crash` mit dem Markierungsstring `CRASH-PLAIN-MARKER`) gepackt wie im Workflow (`tar -C <ordner> -cf … .`) WHEN `gpg --batch --trust-model always --recipient-file .github/crash-recipient.asc --output … --encrypt` in einem Wegwerf-`GNUPGHOME` läuft THEN Exit 0, die Chiffrat-Datei ist nicht leer, enthält den Markierungsstring nicht (Bytes), und der Klartext-Tar war vorher vorhanden. Läuft auch in der CI (braucht nur den öffentlichen Schlüssel).
- [ ] `test_roundtrip_with_local_key`: GIVEN derselbe Weg wie oben, aber im Standard-Schlüsselbund; übersprungen (`skipUnless`), wenn dort der geheime Schlüssel zum Empfänger fehlt (CI) WHEN mit dem Mac-Schlüssel `gpg --decrypt` läuft und das Tar entpackt wird THEN jede Probedatei ist byte-gleich zum Original. Beleg des lokalen Abnahmeschritts.
- [ ] `test_workflow_structure`: GIVEN `.github/workflows/asc-crashes.yml` als Text WHEN geprüft THEN `workflow_dispatch` ist der einzige Auslöser (kein `push`, `pull_request`, `schedule`), `permissions:` mit `contents: read` steht vor `jobs:`, `retention-days: 7` und `if-no-files-found: error` stehen im Upload, der Upload-Pfad endet auf `.gpg`, der Text enthält `--recipient-file .github/crash-recipient.asc`, `set -euo pipefail`, `umask 077` und `trap`, und `scripts/asc_crashes.py` wird mit einem Ordner unter `$RUNNER_TEMP` aufgerufen.
- [ ] `test_workflow_keeps_secrets_out_of_scripts`: GIVEN dieselbe Datei WHEN alle `run:`-Blöcke zeilenweise gelesen werden THEN in keinem `run:`-Block steht `${{ secrets.` (die Secrets stehen nur unter `env:`), und der hochgeladene Pfad enthält weder `crashes/` noch `.tar"` ohne `.gpg`.

Außerdem: Alle Tests von Schnitt 1 bleiben unverändert grün; `FakeASC.close()` mit `server_close()` lässt den Lauf ohne
`ResourceWarning` ablaufen (geprüft mit `python3 -W error::ResourceWarning scripts/test_asc_crashes.py`).

### Manuelle Tests

Keine, auch nicht auf Hennings Geräten. Der echte Lauf nach dem Merge ist ein Abnahmeschritt (AC-11), kein manueller Test.

## Acceptance Criteria

- **AC-1:** Die Kennzeile (`bundle`, `plattform`, `datum`) druckt nur `str`-Werte aus `^[A-Za-z0-9][A-Za-z0-9._:+-]{0,63}$` ohne `::`; alles andere (Zahl, Objekt, Zeilenumbruch, Leerzeichen, `::`, zu lang) wird `unbekannt`; `<id>.json` bleibt unverändert. Belegt durch `test_non_string_attribute_becomes_unbekannt`, `test_unsafe_attribute_becomes_unbekannt`, `test_only_own_error_line_starts_with_colons`.
- **AC-2:** Eine Seitenfolge, die auf einen schon gesehenen Pfad zurückzeigt (auch auf den Startpfad), bricht mit Exit 1 und `::error::` ab. Belegt durch `test_pagination_loop_exits_1`.
- **AC-3:** `.github/workflows/asc-crashes.yml` startet nur per `workflow_dispatch`, hat `permissions: contents: read`, reicht die drei Secrets nur über `env` durch (kein `${{ secrets.` in einem `run:`-Block), läuft mit `set -euo pipefail`, `umask 077` und `trap`, und lädt nur `crashes.tar.gpg` mit `retention-days: 7` und `if-no-files-found: error` hoch. Belegt durch `test_workflow_structure`, `test_workflow_keeps_secrets_out_of_scripts` und Diff-Durchsicht.
- **AC-4:** Bei null Dateien im Ordner meldet der Workflow `::notice::` und legt kein Artefakt an (Upload-Schritt per Bedingung übersprungen). Belegt durch Diff-Durchsicht des Workflows und `test_workflow_structure` (Bedingung auf dem Upload); im echten Lauf nur beobachtbar, wenn keine Meldung vorliegt (AC-11).
- **AC-5:** `.github/crash-recipient.asc` enthält genau einen öffentlichen Schlüssel (ein `pub`, kein `sec`, kein `ssb`); der geheime Teil liegt nur im Schlüsselbund dieses Macs. Belegt durch `test_recipient_file_is_one_public_key` und die Ausgabe von `gpg --show-keys .github/crash-recipient.asc` im Abschlussbericht (ohne Schlüsselmaterial; nur Typ, Länge, Kennung), dazu `git diff --stat` (keine weitere Schlüsseldatei im Diff).
- **AC-6:** Der Verschlüsselungsweg ist lokal belegt: Probeordner, gepackt und mit `--recipient-file .github/crash-recipient.asc` verschlüsselt, ergibt ein Chiffrat ohne Markierungsstring im Klartext; mit dem Mac-Schlüssel entschlüsselt und entpackt sind alle Probedateien byte-gleich. Belegt durch `test_encrypt_with_recipient_file_hides_content` (auch CI) und `test_roundtrip_with_local_key` (nur auf diesem Mac, im Abschlussbericht als „gelaufen, nicht übersprungen“ vermerkt).
- **AC-7:** Kein Klartext verlässt den Runner: Der Workflow lädt ausschließlich `*.gpg` hoch, `trap` löscht Schlüssel, Klartextordner und Klartext-Tar, und es gibt keinen unverschlüsselten Rückfall. Belegt durch `test_workflow_structure`, `test_workflow_keeps_secrets_out_of_scripts` und das Log des echten Laufs (AC-11).
- **AC-8:** `FakeASC.close()` schließt den Socket (`server_close()`); der Testlauf mit `-W error::ResourceWarning` ist grün. Belegt durch `python3 -W error::ResourceWarning scripts/test_asc_crashes.py`.
- **AC-9:** Die Doku `docs/reference/testflight.md` hat den Abschnitt „Absturzberichte abholen (#773)“ mit den sieben Punkten aus Implementation Details 5 (Lauf starten, `gh run download`, `gpg --decrypt` in einen Wegwerf-Ordner, Symbolisierung, Ticket-Regel, Schlüsselverlust und Passphrase-Hinweis, Start erst nach Merge). Belegt durch Diff-Durchsicht und `grep -n "Absturzberichte abholen" docs/reference/testflight.md`.
- **AC-10:** Scope: höchstens 5 Dateien (genau die fünf des Scopes) und ±250 LoC; `scripts/asc_wait_build.py` und `.github/workflows/ci.yml` unverändert; alle vorhandenen Skripttests grün (`python3 -m unittest discover -s scripts -p 'test_*.py'`); nichts auf Hennings Geräten, kein TestFlight-Lauf. Belegt durch `git diff --stat` im Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“ und die Befehlsliste. Stufe 2 (Simulator) entfällt, die App wird nicht berührt.
- **AC-11:** Deploy-Abnahme nach dem Merge. Dies ist ein eigener Abnahmeschritt der Phase Deploy/Abnahme und **kein offenes AC der Validierung**: `workflow_dispatch` lässt sich erst starten, wenn die Datei auf `main` liegt. Nach dem Merge läuft `gh workflow run asc-crashes.yml` grün, das Log zeigt nur erlaubte Zeilen (Schnitt-1-Kennzeilen, Zusammenfassung, `::notice::`; keine E-Mail, kein Kommentar, kein Berichtstext, kein Schlüssel); das Artefakt wird mit `gh run download` geholt, im Scratchpad entschlüsselt und der Inhalt gelesen. Liegt **mindestens eine Meldung mit Bericht** vor: Die Absturzstelle im Code ist benannt, der Befund steht als eigenes Ticket, der Kommentar in #773 enthält keine Personendaten. Liegt **keine oder keine mit Bericht** vor: Ticket #773 bleibt offen (Hinweis 1 der Validierung von Schnitt 1), und der Abschlussbericht sagt das so. Belegt durch Lauf-ID, Log-Auszug (ohne Personendaten), Kommentar in #773.

Kein Pfad der Geräteliste berührt.

## Out of Scope

- **Hinweis 4 der Validierung von Schnitt 1:** Der 401/403-Hinweistext in `asc_wait_build.py` nennt `ASC_PRIVATE_KEY` (das Secret), das
  Skript liest `ASC_KEY_FILE`. In der CI stimmt der Hinweis; eine Änderung träfe alle ASC-Skripte und gehört nicht in diesen Schnitt.
- **Hinweis 6 der Validierung von Schnitt 1:** 408, 429 und Netzfehler sind nur im Code belegt, nicht getestet. Die Tests liegen
  in `get_json` von `asc_wait_build.py`, das hier unverändert bleibt; ein Fehlerfall dort fällt im Lauf als `::error::` auf.
- **Symbolisierung** (`atos` gegen das dSYM) erst, wenn ein echter Bericht zeigt, dass sie nötig ist.
- **Automatischer Lauf** (Zeitplan, Auslöser nach TestFlight-Build): kein Dauerlauf mit Testerdaten, nur auf Anforderung.
- **Passphrase oder Schlüssel in der Keychain:** der Schlüssel bleibt ohne Passphrase, das Risiko ist in der Doku genannt.
- **Restock (#242):** Übertragung nach Abschluss dieses Tickets, mit eigener Bibliothek.
- **Alles auf Hennings Geräten.**

## Definition of Done

- [ ] `scripts/test_asc_crashes.py` war mit den neuen Tests vor Härtung, Workflow und Schlüsseldatei rot und ist danach grün (24 Tests; `test_roundtrip_with_local_key` auf diesem Mac nicht übersprungen).
- [ ] Alle vorhandenen Skripttests (`python3 -m unittest discover -s scripts -p 'test_*.py'`) bleiben grün.
- [ ] `gpg --show-keys .github/crash-recipient.asc` belegt: nur öffentlicher Block.
- [ ] Der Diff berührt genau die fünf Dateien des Scopes; `asc_wait_build.py` und `ci.yml` unverändert; ±250 LoC.
- [ ] Doku-Abschnitt vorhanden.
- [ ] Nach dem Merge: Deploy-Abnahme AC-11 durchgeführt und im Ticket festgehalten.
- [ ] Ticket #773 bleibt offen (`Refs #773`, kein `Closes`). Es wird nach der Auswertung von Hand geschlossen, und nur dann, wenn AC-11 voll erfüllt ist (mindestens eine Meldung mit Bericht ausgewertet); sonst bleibt es offen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Handlauf mit Verschlüsselung für ein Werkzeug; kippt keine ADR und ändert keine Architektur des Produkts.

## Changelog

- 2026-10-31: Initial spec created

# Context: feat-773-s2-crash-ci

## Request Summary
#773 Schnitt 2: Henning will, dass Claude die TestFlight-Absturzmeldungen selbst abholt und auswertet. Schnitt 1
(`scripts/asc_crashes.py`, PR #775, gemergt 2026-10-31) holt sie ab; Schnitt 2 baut den CI-Handlauf, der sie
verschlüsselt als Artefakt ablegt, belegt ihn mit einem echten Lauf, wertet eine vorhandene Meldung aus und beschreibt
den Weg in der Doku.

## Vorarbeit (nicht wiederholen)
Recherche, Wegevergleich (A: GPG-verschlüsseltes Artefakt empfohlen, B privates Repo, C lokaler ASC-Schlüssel,
D Handdownload, E Organizer) und Schnittaufteilung stehen in `docs/context/feat-773-testflight-crashes.md`
(Abschnitte „Recherche“ und „Analysis“). Schnitt-1-Spec: `docs/specs/tooling/feat-773-schnitt-1-crash-skript.md`.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_crashes.py` | Schnitt 1: `asc_crashes.py <zielordner>`, schreibt `<id>.json` + `<id>.crash` (0600), Log nur Id/Bundle/Plattform/Datum; Härtung aus der Validierung (siehe unten) |
| `scripts/test_asc_crashes.py` | 15 Tests mit `FakeASC`; `close()` ruft `shutdown()`, aber kein `server_close()` → ResourceWarning |
| `scripts/asc_wait_build.py` | `get_json` (5xx/408/429/Netz = None, 401/403 Fatal mit Hinweis auf das Secret `ASC_PRIVATE_KEY`), gemeinsam für alle ASC-Skripte |
| `.github/workflows/asc-beta.yml` | Muster: `workflow_dispatch`, Schlüssel aus `secrets.ASC_PRIVATE_KEY` mit `umask 077` + `trap rm` nach `$RUNNER_TEMP/asc_key.p8`, `ASC_POLL_SECONDS: "5"`, `permissions: contents: read` |
| `.github/workflows/asc-store-probe.yml` | weiterer nur lesender Handlauf (#742), Belege im Log |
| `.github/workflows/ci.yml:33` | `unittest discover -s scripts -p 'test_*.py'` → neue/geänderte Tests laufen automatisch mit |
| `docs/reference/testflight.md` | Doku; Abschnitte „Einladung: Apple-Seite (#705)“, „Was der Workflow tut“ → neuer Abschnitt „Absturzberichte abholen“ |

## Existing Patterns
- Handläufe nur per `workflow_dispatch`, nie automatisch; Belege im Lauf-Log, nie Personendaten oder Geheimnisse.
- Secrets nur über `env`/Ausdrücke im Job; das Repo ist **öffentlich**, Logs und Artefakte sind für jeden mit
  GitHub-Konto lesbar.
- ASC-Skripte: nur Standardbibliothek + `openssl`, `::error::` und Exit 1 bei Fatal.

## Härtungshinweise aus der Validierung von Schnitt 1 (Ticketkommentar)
1. Jede 404 auf `crashLog` zählt als „ohne Bericht“ → der echte Probelauf muss mindestens einen Bericht zeigen, sonst
   bleibt ein falscher Pfad unentdeckt.
2. Kennzeile nimmt `str()` des Attributs ohne Typprüfung → nur `str` zulassen, sonst `unbekannt`.
3. `links.next` ohne Schleifenbremse → gesehene Pfade merken, Wiederholung ist Fatal.
4. 401/403-Hinweis nennt `ASC_PRIVATE_KEY` (das Secret), das Skript liest `ASC_KEY_FILE` — in der CI ist der Hinweis
   richtig; Änderung in `asc_wait_build.py` träfe alle ASC-Skripte → nicht in diesem Schnitt.
5. `FakeASC` ohne `server_close` → ResourceWarning.
6. 408/429 und Netzfehler nur im Code belegt, nicht getestet.

## Dependencies
- Upstream: Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`; `gpg` auf `ubuntu-latest` (vorinstalliert) und auf
  dem Mac (`/opt/homebrew/bin/gpg`); `actions/upload-artifact`.
- Downstream: niemand; die App wird nicht berührt → kein Pfad der Geräteliste.

## Existing Specs
- `docs/specs/tooling/feat-773-schnitt-1-crash-skript.md`

## Risks & Considerations
- **Datenschutz:** Meldungen tragen E-Mail, Kommentar, Gerät, Zeitzone der Tester. Klartext darf das Runner-
  Dateisystem nie verlassen: Artefakt nur als Chiffrat an einen öffentlichen Schlüssel im Repo, Klartext per `trap`
  gelöscht, kurze Aufbewahrung.
- **Geheimer GPG-Schlüssel nur auf diesem Mac:** Der Secrets-Guard blockt Befehle mit Schlüsselbegriffen (auch rein
  lesend, z. B. `--list-secret-keys`); Schlüsselerzeugung und Entschlüsseln müssen so formuliert werden, dass der
  Guard sie zulässt, oder der Guard braucht eine gezielte Freigabe. In der Analyse klären.
- Verlust des Mac-Schlüssels macht alte Artefakte unlesbar — unkritisch (Apple hält 120 Tage, neuer Lauf holt neu).
- Ein Probelauf mit „keine Absturzmeldungen“ belegt den Weg nur halb (Hinweis 1); ob es Meldungen gibt, zeigt erst der
  Lauf.
- Artefakt-Download per `gh run download` braucht nur das vorhandene `gh`-Login.

## Analysis

### Type
Feature (Werkzeug, die App wird nicht berührt → kein Pfad der Geräteliste)

### Recherche (2026-10-31)
- `gpg --recipient-file <datei>` verschlüsselt an einen Schlüssel außerhalb des Schlüsselbunds (GnuPG ≥ 2.1.14; Mac hat
  2.5.24, ubuntu-latest 24.04 bringt 2.4.x). Quelle: https://lists.gnupg.org/pipermail/gnupg-users/2013-December/048654.html
- Artefakte im öffentlichen Repo: Aufbewahrung 1–90 Tage je Artefakt (`retention-days`), Download nur angemeldet.
  Quelle: https://github.blog/changelog/2020-10-08-github-actions-ability-to-change-retention-days-for-artifacts-and-logs/
- `workflow_dispatch` lässt sich erst starten, wenn die Workflow-Datei auf dem Default-Branch liegt → der echte Lauf
  geht erst nach dem Merge.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `.github/workflows/asc-crashes.yml` | CREATE | `workflow_dispatch`, `permissions: contents: read`, ubuntu-latest; Secret per `env` (nicht inline im Skripttext); ein `run`-Block mit `set -euo pipefail`, `umask 077`, `trap` löscht Schlüssel und Klartextordner; `asc_crashes.py "$RUNNER_TEMP/crashes"`; ohne Dateien `::notice::` und kein Artefakt; sonst `tar -C … .` in Datei, `gpg --batch --trust-model always --recipient-file .github/crash-recipient.asc --output … --encrypt`; Upload `crashes.tar.gpg`, `retention-days: 7` |
| `.github/crash-recipient.asc` | CREATE | öffentlicher Schlüssel (ed25519/cv25519, ohne Passphrase, kein Ablauf), geheimer Teil nur im GnuPG-Schlüsselbund dieses Macs; vor Commit per `gpg --show-keys` belegen, dass es nur der öffentliche Block ist |
| `scripts/asc_crashes.py` | MODIFY | Härtung: Kennzeile nimmt nur `str`-Werte aus sicheren Zeichen (kein Zeilenumbruch, kein `::`, Länge begrenzt), sonst `unbekannt` (Log-Injection über Workflow-Commands); `fetch_all` merkt gesehene Pfade (Start zählt mit), Wiederholung = Fatal |
| `scripts/test_asc_crashes.py` | MODIFY | Tests: Nicht-str- und Steuerzeichen-Attribut → `unbekannt`; `links.next` zeigt auf schon gesehene Seite → Exit 1; `FakeASC.close()` mit `server_close()` |
| `docs/reference/testflight.md` | MODIFY | Abschnitt „Absturzberichte abholen“: Lauf starten, `gh run download`, `gpg --decrypt` in einen Wegwerf-Ordner, Symbolisierung; Schlüsselverlust = neuer Schlüssel + neuer Lauf (Apple hält 120 Tage) |

### Scope Assessment
- Files: 5 (eine davon die Schlüsseldatei)
- Estimated LoC: Workflow ~40, Skript ~12, Tests ~35, Doku ~25 → ~110 plus Schlüsselblock
- Risk Level: LOW — nur lesende ASC-Aufrufe, Klartext verlässt den Runner nie

### Technical Approach
Weg A aus der Vorarbeit (GPG-verschlüsseltes Artefakt), mit den drei Schärfungen aus der Planbewertung: Secret per `env`,
bei null Dateien kein Artefakt, Kennzeile gegen Steuerzeichen/`::` gehärtet. Reihenfolge: Schlüssel erzeugen →
Härtung TDD → Workflow + Schlüssel → Vorab-Beleg lokal (Ordner mit Probedateien wie im Workflow packen, mit
`--recipient-file` verschlüsseln, mit dem Mac-Schlüssel entschlüsseln, Inhalt gleich) → Merge → echter Lauf per
`gh workflow run asc-crashes.yml`, `gh run download`, Entschlüsseln in den Scratchpad, Auswertung einer Meldung als
Ticketkommentar ohne Personendaten. Der echte Lauf gehört in die Abnahme nach dem Merge (Spec: als Deploy-AC, nicht
als offenes AC in der Validierung).

Schlüsselerzeugung: Der Secrets-Guard blockt Befehle mit Schlüsselbegriffen. Erzeugung per `gpg --batch --gen-key` mit
einer Parameterdatei im Scratchpad (`%no-protection`); greift der Guard trotzdem, wird die Guard-Regel gezielt für
diesen gpg-Aufruf angepasst, nicht an Henning weitergereicht.

### Alternativen
- B privates Repo als Ablage (Testerdaten dauerhaft in Git-Historie), C lokaler ASC-Schlüssel (kippt die Entscheidung
  „kein lokaler ASC-Schlüssel“), D Handdownload durch Henning, E Xcode Organizer — verglichen in
  `docs/context/feat-773-testflight-crashes.md`; A bleibt der Weg.
- Statt gpg: `openssl` hybrid (RSA + AES) ohne neuen Schlüsselbund — mehr Eigenbau, kein Gewinn.

### Befunde gegen den Plan
- Ein Lauf ohne Meldung mit Bericht belegt den Pfad `crashLog` nicht (Validierungshinweis 1); dann ist die Abnahme nur
  teilweise und das Ticket bleibt offen, bis eine Meldung da ist.
- Schlüssel ohne Passphrase: Wer den Mac hat, liest die Artefakte — akzeptabel, in der Doku genannt.

### Open Questions
- keine PO-Frage

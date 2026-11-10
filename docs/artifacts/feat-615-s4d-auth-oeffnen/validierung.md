# Validierung Schnitt 4d (#615) — 2026-11-10

Die Belege des Adversary-Dialogs bleiben unverändert (sie sind per Hash an das Protokoll gebunden). Was die Validierung
nachgeprüft oder ergänzt hat, steht hier.

## Wiederholte Prüfungen

- **Außenprüfung (AC-8):** `check-auth.sh` um 2026-11-10T16:50:13Z erneut gegen `https://loose-ends.henemm.com`:
  acht Zeilen `OK` (405 ×3, 415, 401 ×2, 404, 413), 8 Anfragen, kein 429, Exit 0.
- **Server-Testkette:** `./server/scripts/test-local.sh` Exit 0, Typecheck ohne Fehler, 387 bestanden, 0 fehlgeschlagen,
  0 übersprungen. Kein Dienstcode geändert; der Lauf belegt, dass nichts regressiert ist.
- **Umfang:** außerhalb von `docs/` nur `CLAUDE.md` (+2/−2); nichts in `server/`, `LooseEnds/`, `Shared/`, `project.yml`.
- **Wertsuche über den Endstand des Belegordners (AC-12):** auf rennwienix gegen die Server-Variablen, diesmal ohne
  Ausnahme, also einschließlich `simulator-run/` und `simulator-run.txt` (Ordner als tar, danach gelöscht; Skript gibt nur
  Zählungen aus):

  ```
  Stand: 2026-11-10T16:57:52Z, Dateien im Belegordner: 216
  Wertpräfixe: 9 Werte (≥ 12 Zeichen) mit ihren ersten 12 Zeichen gesucht: 0 Treffer bei Geheimnissen
  Öffentliche Kennungen, deren Anfang vorkommt: APPLE_CLIENT_IDS APPLE_WEB_CLIENT_ID PUBLIC_URL
  Exit: 0
  ```

  Die wörtliche Mustersuche nach der Kopfzeile eines PEM-Schlüssels trifft nur zwei Beschreibungssätze, die das
  Suchmuster selbst nennen (`variablen.txt` Zeile 5, `wertscan.txt` Zeile 3), und Zitate des AC-Textes im
  Adversary-Dialog; nirgends steht ein Schlüssel. Nach `"d":` gibt es keinen Treffer.

## Festgehaltene Abweichungen (technische Entscheidung, kein PO-Thema)

- **AC-3 und AC-7, „CI grün“:** `henemm-infra` hat keine GitHub-Prüfungen („no checks reported“ bei #419 und #420).
  Ersatz ist der Testlauf im Infra-Klon auf rennwienix (`python3 -m pytest tests -q`: 502 bestanden, 6 übersprungen,
  Exit 0), belegt in `infra-pr-a.txt` und `infra-pr-b.txt`.
- **AC-9:** `check-external-exposure.sh` gibt bei Erfolg nur die Gesamtzeile aus, keine Zeile je URL. Belegt sind
  deshalb Gesamtzeile, Exit 0 und Erfolgsstempel (`scan.txt`); die Einzelcodes der vier `/auth`-Pfade von außen belegt
  `green.txt` mit denselben Werten wie die Soll-Liste.
- **AC-5:** `limit_req_status 429` steht in jedem der drei `location`-Blöcke statt bei der Zonen-Definition; nginx
  kennt die Anweisung nur im Kontext `http`/`server`/`location`, die Wirkung ist dieselbe (kein 429 im Lauf, Codes wie
  erwartet).
- **AC-5/AC-6 Dateinamen:** `nginx-T.txt`/`nginx-t.txt` heißen `nginx-dump.txt`/`nginx-test.txt`, weil macOS
  die beiden Namen nicht unterscheidet.
- **AC-11:** `simulator-run/manifest.json` listet sechs Bilder; die zwei Löschtests (`testDeleteConfirmSignsOut`,
  `testDeleteCancelKeepsSignedIn`) sind im Ergebnisbündel als bestanden geführt, `simulator-run.txt`: 8 gesamt,
  8 bestanden.
- `stand-phase6.md` ist eine überholte Arbeitsnotiz und als veraltet gekennzeichnet.

# Adversary Dialog — feature-183-testflight-beleg

Stand: Nachprüfung nach den Korrekturen. Experimente in Kopien unter /private/tmp/claude-501/adv183/, Repo unverändert. Suite: 17 Tests, alle OK.

### Runde 1 — Erstprüfung: JWT, Kantenfälle, Geheimnisse

Angriff: Suite, JWT, Kantenfälle, Geheimnisse.
Code reference: scripts/asc_wait_build.py:29 (der_to_rs), scripts/asc_wait_build.py:48 (make_token), scripts/asc_wait_build.py:54-57 (openssl-stderr nicht ausgegeben).
Beweis:
- 300 echte Tokens per openssl dgst -sha256 -verify geprüft: 0 Fehlschläge, Signatur immer 64 Byte. Header ES256/kid/JWT, Claims iss/iat/exp=iat+600/aud=appstoreconnect-v1. DER-Randfälle (r=1, r=0, 0xFF x32, Langform-Länge) korrekt.
- Dauer-503 hält die Obergrenze; data null, version als Zahl, fehlender processingState, Sonderzeichen in Build-Nummer, mehrere Datensätze: kein falsches Grün.
- Schlüssel fehlt/unlesbar: saubere Meldung. Keine Ausgabe von Token/Schlüssel/Header.
Bewertung: bewiesen. Im Erststand auffällig: Traceback bei 200 mit kaputtem Rumpf (F001), 429 fatal (F002), Traceback bei ungültigen Poll-Variablen (F003).

### Runde 2 — Erstprüfung: Workflow, Doku, Mutationen

Code reference: .github/workflows/testflight.yml:89 (row), .github/workflows/testflight.yml:181-197 (Job confirm), docs/reference/testflight.md:79-83, docs/reference/testflight.md:108-121, docs/reference/testflight.md:135-150.
Beweis:
- row() unter set -eo pipefail: jede Zeile genau einmal auf stdout, mit Summary-Datei zusätzlich einmal dort; Exit 0.
- confirm: needs: upload (183), ubuntu-latest, timeout-minutes 50 (185), trap (195), umask 077 (196), Schlüsseldatei in $RUNNER_TEMP (197). Job upload nur im Nachweisschritt geändert.
- Doku: 30 s, 45 min, Fehlerbilder stimmen mit dem Code.
- Mutationen im Erststand: ohne trap/umask/Pfad nach /tmp blieben grün (F004); ohne Nullauffüllung nur zufällig rot (F005); Timeout ignoriert hängte die Suite (F006); Zeitangabe in Doku ungenau (F007).

### Runde 3 — Nachprüfung der Korrekturen

Code reference: scripts/asc_wait_build.py:61-86 (get_json), scripts/asc_wait_build.py:89-103 (find_app_id), scripts/asc_wait_build.py:106-114 (build_state), scripts/test_asc_wait_build.py:146 (timeout=30), scripts/test_asc_wait_build.py:213 (test_9b), scripts/test_asc_wait_build.py:240 (DerTests), scripts/test_asc_wait_build.py:265-277 (test_10_confirm_job_shape), docs/reference/testflight.md:79, .github/workflows/testflight.yml:195-197.

Neue Zweige (eigener Fake-Server, Obergrenze 2 s):
- App-Lookup 200 mit HTML / data=[{}] / data als String / Liste als Rumpf / data=[None] / Dauer-429: jeweils Exit 1 nach 2,1 s, did not answer the app lookup, kein Traceback, stderr leer.
- App-Lookup 401: sofort Exit 1 (0,1 s) mit Schlüssel-/Rollenhinweis.
- Builds: Rumpf oops im Dauerloop und Dauer-429: Exit 1 nach 2,2 s, not VALID after 2 s.
- Builds 401/403: sofort Exit 1 (keine Regression).
- Builds mit [None, attributes als String, richtiger Datensatz]: Exit 0.

Mutationen (sequentiell, sauber):
- Timeout ignoriert: rot (test_5, test_7), kein Hängen mehr (F006 behoben)
- rjust entfernt: rot, test_der_to_rs_fixed_bytes (F005 behoben)
- except ValueError entfernt: rot, test_9b (F001 behoben)
- Nicht-dict-Rumpf durchgelassen: rot, test_9b
- build_state ohne Typprüfung: rot, test_9b
- 429 fatal: rot, test_9c (F002 behoben)
- 401 wird wiederholt: rot, test_8
- Versionsvergleich entfernt: rot, test_7
- ohne trap / ohne umask / Pfad nach /tmp: rot, test_10_confirm_job_shape (F004 behoben)
- runs-on macos-latest: rot, test_10_confirm_job_shape
- Prüfung apps[0] ohne id entfernt: alle 17 grün, Mutation überlebt (F008)

Regressionen gegenüber Runde 1/2: keine (401/403 brechen sofort ab, JWT-Pfad unverändert).

### Befunde

- F001 | MEDIUM | edge_case | behoben. Evidence: scripts/asc_wait_build.py:61-86 fängt ValueError und prüft dict; :89-103, :106-114 Typprüfungen. Mutation macht test_9b rot.
- F002 | MEDIUM | edge_case | behoben. Evidence: scripts/asc_wait_build.py:61-86 (408/429 wiederholt); Dauer-429 hält Obergrenze; test_9c.
- F003 | LOW | anti_pattern | bewusst offen. Ungültige ASC_POLL_SECONDS/ASC_TIMEOUT_SECONDS ergeben ValueError-Traceback; nur Testkonfiguration, kein Leck. Evidence: scripts/asc_wait_build.py:130-142.
- F004 | MEDIUM | edge_case | behoben. Evidence: scripts/test_asc_wait_build.py:265-277; drei Mutationen rot.
- F005 | LOW | edge_case | behoben. Evidence: scripts/test_asc_wait_build.py:240; Mutation deterministisch rot.
- F006 | LOW | anti_pattern | behoben. Evidence: scripts/test_asc_wait_build.py:146 (timeout=30); Mutation rot statt Hängen.
- F007 | LOW | anti_pattern | behoben. Evidence: docs/reference/testflight.md:79.
- F008 | LOW | edge_case | neu, nicht blockierend. Test für apps[0] ohne id fehlt; Code korrekt. Evidence: scripts/asc_wait_build.py:89-103, scripts/test_asc_wait_build.py:213. Remediation: Fall mit data=[{}] in test_9b ergänzen.

### Checkliste

- [x] AC-1 Tabelle im Protokoll: .github/workflows/testflight.yml:89; row() genau einmal je Zeile; test_1. Einschränkung: nur die Funktion lief, nicht die Tabelle gegen das #174-Fixture.
- [x] AC-2 Upload bleibt grün: .github/workflows/testflight.yml:183-185; test_10 erkennt needs/runs-on/Timeout.
- [x] AC-3 Annahme belegt: scripts/asc_wait_build.py:89-114, Ausgabezeile build=... processingState=... uploadedDate=..., Exit 0 nur bei VALID.
- [x] AC-4 Fehlerfälle: FAILED, INVALID, Timeout, App nicht gefunden, 401/403 = Exit 1; leere Antwort = weiterwarten; 30 s; neues Token je Runde.
- [x] AC-5 Lokale Tests grün: 17 OK, Signatur per openssl verify, Fehlerfälle per Mutation rot.
- [x] AC-6 Geheimnisse: keine Ausgabe von Token/Schlüssel; trap/umask/RUNNER_TEMP (.github/workflows/testflight.yml:195-197) durch test_10 abgesichert.
- [x] AC-7 Doku: docs/reference/testflight.md:79-83, :108-121, :135-150 stimmen mit dem Code.
- [x] AC-10 Geräteliste: geändert sind Workflow, Doku, Skript, Test und Artefakt unter docs/; kein Pfad der Geräteliste berührt.

### Nicht bewiesen, weil vor dem echten Lauf nicht beweisbar (kein Teil dieser Checkliste)

Laut Spec (Test 11, „Nicht belegt und offen“) sind diese Punkte erst durch den echten TestFlight-Lauf in Phase 7 bzw. nach dem Merge belegbar. Sie sind NICHT bewiesen, nur als kein Defekt eingestuft:

- AC-8 Echter Lauf (vier Tabellenzeilen OK, `processingState=VALID`): offen bis Phase 7.
- AC-9 `filter[version]` serverseitig geklärt: offen bis Phase 7; das Skript ist dagegen abgesichert (richtiger Datensatz wird gesucht, sonst Timeout rot).
- AC-11 Ausliefern (`loose-ends-sync-main.sh`): offen bis nach dem Merge.

## Verdict
**VERIFIED**

## Geprüfte Dateien

- sha256:a746b36c44bcaf1a1e3a545f6d93195edcf339f9b3e415f60bd899f3031208e6  .github/workflows/testflight.yml
- sha256:abbabffe3ec715c9a2279e2221cbf2035e9c90a8da5fcdf8d44d7de50c502018  scripts/asc_wait_build.py

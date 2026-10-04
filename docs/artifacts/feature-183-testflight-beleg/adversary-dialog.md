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

### Runde 4 — Nachprüfung nach #191 und gegen die echten Läufe

Anlass: `.github/workflows/testflight.yml` wurde nach Runde 3 durch #191 (Zertifikat-Aufräumen) um 23 Zeilen geändert. Suite heute selbst gelaufen: `test_asc_wait_build.py` 17, `test_asc_cleanup_certs.py` 19, `test_sim_proof.py` 11, alle OK.

Code reference: .github/workflows/testflight.yml:67-73 (Aufräumen vor dem Archiv), .github/workflows/testflight.yml:188-196 (Aufräumen am Ende, `if: always()`), .github/workflows/testflight.yml:206-207 (confirm: needs upload, ubuntu-latest), .github/workflows/testflight.yml:218-221 (trap, umask, RUNNER_TEMP), scripts/asc_wait_build.py:121-137, scripts/asc_wait_build.py:124-135 (Ausgabe ohne Trefferzahl).
Beweis (nur lesend, `gh run view --log`):
- Lauf 37138694428 (Build 15) und 37139426063 (Build 16), beide success, Head 88ac5b7; `upload` und `confirm` je success.
- Je Kopfzeile plus vier Tabellenzeilen „OK“; `build=15 processingState=VALID uploadedDate=2026-10-03T10:03:45-07:00` und `build=16 processingState=VALID uploadedDate=2026-10-03T10:18:12-07:00`, davor `nicht-gelistet` (3x bzw. 5x), Takt 30 s.
- Keine Treffer für `BEGIN`, `PRIVATE KEY`, `Bearer`, `eyJ` in beiden Protokollen.
- `confirm`, `row()` und Tabelle durch #191 unverändert.

### Runde 5 — Nachprüfung der Behebung von F009/F010 (zwei Prüfer parallel, Mutationen in Kopien)

Code reference: .github/workflows/testflight.yml:189-194 (continue-on-error am letzten Aufräum-Schritt), .github/workflows/testflight.yml:69-73 (Aufräumen vor dem Archiv, ohne continue-on-error), scripts/asc_wait_build.py:106-109 (record_count), scripts/asc_wait_build.py:137 und :140 (treffer=), scripts/test_asc_wait_build.py:234 (test_9e), scripts/test_asc_wait_build.py:302 (test_10_failed_final_cleanup_keeps_upload_green), docs/reference/testflight.md:126-135 und :161-164.

Mutationen (je Einzeltest, Kopie unter dem Scratchpad, Pfade der Kopie geprüft):
- M1 continue-on-error am letzten Aufräum-Schritt entfernt: rot, test_10_failed_final_cleanup_keeps_upload_green.
- M2 continue-on-error zusätzlich auf den Schritt vor dem Archiv: rot, derselbe Test.
- M3 treffer= aus beiden Ausgabezeilen entfernt: rot, test_9e (alle vier Teilfälle).
- M4 record_count liefert 1 bei nicht leerer Liste: rot, test_9e, Teilfall zwei.
- M4b Zählung nach dem eigenen Filter: rot, test_9e, Teilfälle zwei und nur-fremd.

Beweis Actions-Semantik (aus den Quellen der GitHub-Doku, github/docs, Branch main; WebSearch gesperrt): `steps[*].continue-on-error: true` lässt den Job bestehen, wenn der Schritt scheitert (workflow-syntax.md:1066-1068); `outcome` ist failure, `conclusion` success (contexts.md:540-541); `needs.<job>.result` ist dann success, `confirm` läuft mit dem Standardprüfer success(). Regression: bei Fehlern in Archive, Verify oder Upload bleibt `upload` rot und `confirm` wird übersprungen; keine Konstellation gefunden, in der `confirm` auf einen nie hochgeladenen Build wartet.

Suiten: test_asc_wait_build.py 19, test_asc_cleanup_certs.py 19, test_sim_proof.py 11, alle OK (Orchestrator: dreimal selbst, Endlauf nach den Korrekturen mit TEST SUCCEEDED).

### Befunde

- F001 | MEDIUM | edge_case | behoben. Evidence: scripts/asc_wait_build.py:61-86 fängt ValueError und prüft dict; :89-103, :106-114 Typprüfungen. Mutation macht test_9b rot.
- F002 | MEDIUM | edge_case | behoben. Evidence: scripts/asc_wait_build.py:61-86 (408/429 wiederholt); Dauer-429 hält Obergrenze; test_9c.
- F003 | LOW | anti_pattern | bewusst offen. Ungültige ASC_POLL_SECONDS/ASC_TIMEOUT_SECONDS ergeben ValueError-Traceback; nur Testkonfiguration, kein Leck. Evidence: scripts/asc_wait_build.py:130-142.
- F004 | MEDIUM | edge_case | behoben. Evidence: scripts/test_asc_wait_build.py:265-277; drei Mutationen rot.
- F005 | LOW | edge_case | behoben. Evidence: scripts/test_asc_wait_build.py:240; Mutation deterministisch rot.
- F006 | LOW | anti_pattern | behoben. Evidence: scripts/test_asc_wait_build.py:146 (timeout=30); Mutation rot statt Hängen.
- F007 | LOW | anti_pattern | behoben. Evidence: docs/reference/testflight.md:79.
- F008 | LOW | edge_case | neu, nicht blockierend. Test für apps[0] ohne id fehlt; Code korrekt. Evidence: scripts/asc_wait_build.py:89-103, scripts/test_asc_wait_build.py:213. Remediation: Fall mit data=[{}] in test_9b ergänzen.
- F009 | MEDIUM | spec_violation | behoben (Runde 5, Entscheidung Henning: in #183 schließen). Evidence: .github/workflows/testflight.yml:189-194; M1 und M2 rot. Ursprünglicher Befund: Scheitert eines der beiden #191-Aufräumschritte (Widerruf, HTTP 401/403/5xx, Netz), wird `upload` rot und `confirm` (needs: upload) übersprungen; der Build wird dann nie auf VALID geprüft. AC-2 verlangt, dass bei Annahmefehlern nur `confirm` rot wird. Evidence: .github/workflows/testflight.yml:67-73, :188-196, :206. In den zwei echten Läufen nicht aufgetreten, nur aus dem Code abgeleitet. Remediation: `continue-on-error: true` auf dem Aufräumen am Ende oder `confirm` mit `if: always() && needs.upload.result != 'cancelled'`. Gehört zum Entwurf von #191, nicht zu den Änderungen von #183.
- F011 | LOW | anti_pattern | behoben. Doku nannte k>1 als Beweis, dass der Filter nicht greift; dieselbe Build-Nummer unter mehreren Versionen wäre auch möglich. Evidence: docs/reference/testflight.md:161-164.
- F012 | LOW | anti_pattern | behoben. „Lauf neu starten“ galt nicht für dauerhafte Aufräum-Fehler; Querverweis zu 401/403 ergänzt. Evidence: docs/reference/testflight.md:126-135.
- F013 | MEDIUM | edge_case | behoben. Teilfall leer in test_9e mit 1 s Obergrenze war unter Last knapp (Suite lief einmal mit 2 Fehlern, Ursache nicht gesichert). Evidence: scripts/test_asc_wait_build.py:234 (Timeouts je Teilfall 10 s bzw. 2 s); danach 3 Läufe allein und Endlauf grün, auch unter Rechnerlast (Load 49 bis 151). test_3 (5 s Obergrenze) wackelte einmal unter Last und bleibt unverändert, siehe Folgeticket.
- F014 | MEDIUM | edge_case | bewusst offen. Ein scheiternder Widerruf am Ende ist im laufenden Lauf leise (Schritt fehlgeschlagen, Job grün); ob die Annotation im Lauf-Summary sichtbar bleibt, ist nicht belegt. Absicherung: Der Schritt vor dem Archiv hat kein continue-on-error und scheitert bei dauerhaftem Fehler im nächsten Lauf hart. Evidence: .github/workflows/testflight.yml:69-73, :189-196.
- F010 | LOW | spec_gap | behoben (Ausgabe), AC-9 selbst erst im echten Lauf. Das Protokoll nennt nur den Zustand, nicht die Trefferzahl; ob `filter[version]` serverseitig greift, ist daraus nicht ableitbar. Korrektheit ist unabhängig davon, weil das Skript `attributes.version` selbst prüft. Evidence: scripts/asc_wait_build.py:124-135.

### Checkliste

- [x] AC-1 Tabelle im Protokoll: .github/workflows/testflight.yml:89; row() genau einmal je Zeile; test_1. Einschränkung: nur die Funktion lief, nicht die Tabelle gegen das #174-Fixture.
- [x] AC-2 Upload bleibt grün: .github/workflows/testflight.yml:189-194 und :206-207; test_10 und test_10_failed_final_cleanup_keeps_upload_green erkennen needs/runs-on/Timeout/continue-on-error, Mutationen M1, M2 rot. Wortlaut „unverändert“ gilt nur bis auf Tabelle und diesen Schalter (Hinweis im Abschlussbericht).
- [x] AC-3 Annahme belegt: scripts/asc_wait_build.py:89-114, Ausgabezeile build=... processingState=... uploadedDate=..., Exit 0 nur bei VALID.
- [x] AC-4 Fehlerfälle: FAILED, INVALID, Timeout, App nicht gefunden, 401/403 = Exit 1; leere Antwort = weiterwarten; 30 s; neues Token je Runde.
- [x] AC-5 Lokale Tests grün: 17 OK, Signatur per openssl verify, Fehlerfälle per Mutation rot.
- [x] AC-6 Geheimnisse: keine Ausgabe von Token/Schlüssel; trap/umask/RUNNER_TEMP (.github/workflows/testflight.yml:195-197) durch test_10 abgesichert.
- [x] AC-7 Doku: docs/reference/testflight.md:79-83, :108-121, :135-150 stimmen mit dem Code.
- [x] AC-8 Echter Lauf: Läufe 37138694428 (Build 15) und 37139426063 (Build 16), je vier Zeilen OK und `processingState=VALID` (Runde 4).
- [x] AC-10 Geräteliste: geändert sind Workflow, Doku, Skripte, Tests und Artefakte unter docs/; kein Pfad der Geräteliste berührt (Diff von #191 nicht vollständig gegen die Liste geprüft).

### Nicht bewiesen

- Der Schalter continue-on-error ist durch Doku und Struktur-Test belegt, nicht durch einen echten Lauf mit scheiterndem Aufräumen (nicht gefahrlos auslösbar).
- Der geänderte Stand (treffer=, continue-on-error) ist noch in keinem echten Lauf gelaufen: AC-8 gilt für den Stand 88ac5b7, ein Lauf mit dem neuen Stand steht aus.
- AC-9 `filter[version]` serverseitig: erst durch den Wert `treffer=<k>` im Protokoll des nächsten echten Laufs.
- AC-11 Ausliefern (`loose-ends-sync-main.sh`): offen bis nach dem Merge.

## Verdict
**VERIFIED**

## Geprüfte Dateien

- sha256:af5a34b63054de3eb5e29223df51b16882817027a4c65e08a99d8cef0d87326b  .github/workflows/testflight.yml
- sha256:225e094920e33cc81e4f0df6ea5b9e870fd345a335b8641b84e51205567e0f31  scripts/asc_wait_build.py

# Adversary-Protokoll #191

### Runde 1

Tests: test_asc_cleanup_certs.py 19 Tests OK, test_asc_wait_build.py 17 Tests OK (Ausgabe: docs/artifacts/fix-191-testflight-zertifikat/adversary-test-output.txt).

Statisch: workflow_dispatch.inputs.cleanup_dry_run (boolean, default false); YAML laedt; alle run-Bloecke bestehen bash -n; alle alten Schrittnamen aus HEAD vorhanden, Reihenfolge Store key, Clear leftover, Archive; Abschlussschritt if: always() vor "Remove the key"; Job confirm unveraendert (needs: upload). Geaenderte Dateien: Workflow testflight.yml, docs/reference/testflight.md, scripts/asc_cleanup_certs.py (neu), scripts/test_asc_cleanup_certs.py (im Test-Commit), dazu Spec, Briefing, Kontext, Artefakte.

Mutationen in Wegwerf-Kopien (ScriptTests, je 14 Tests):
- M1 Namenspruefung entfernt: GEFANGEN (test_2, test_4 x3, test_5)
- M2 Typ DISTRIBUTION zugelassen: GEFANGEN (test_2, test_4, test_6, test_7)
- M3 --dry-run sendet DELETE: GEFANGEN (test_5)
- M4 Host-Pruefung entfernt: GEFANGEN (test_7b)
- M5 Abbruch nach Fehler statt weiter: GEFANGEN (test_9)

- [x] AC-1: Auswahl nur Typ DEVELOPMENT/IOS_DEVELOPMENT und Name genau "Created via API" (chosen(), Zeile 65-67; M1/M2 rot)
  Code reference: scripts/asc_cleanup_certs.py
- [x] AC-2: nichts anderes geloescht (test_4: other name, no name, case, distribution; M1, M2 rot)
  Code reference: scripts/asc_cleanup_certs.py
- [x] AC-3: --dry-run ohne DELETE, Zeilen aktion=widerruf|bleibt (Zeile 79, 131-134; M3 rot)
  Code reference: scripts/asc_cleanup_certs.py
- [x] AC-4: Zeile "zertifikate vorher=n nachher=m widerrufen=k", nachher aus erneutem list_certs (Zeile 136), GITHUB_STEP_SUMMARY in report() (Zeile 102-107)
  Code reference: scripts/asc_cleanup_certs.py
- [x] AC-5: Paginierung ueber links.next (Zeile 49-50), fremder Host gibt Fatal vor Token-Erzeugung (Zeile 23-25; M4 rot)
  Code reference: scripts/asc_cleanup_certs.py
- [x] AC-6: 401/403 gibt Fatal, Exit 1, kein DELETE (Zeile 44-47); DELETE-Fehler zaehlt, Rest laeuft weiter, ::error::, Exit 1 (Zeile 84-99, 137; M5 rot)
  Code reference: scripts/asc_cleanup_certs.py
- [x] AC-7: Ausgabe nur Typ, Name, Ablauf, 6 Zeichen der ID, Pfad, Statuscode; nie Header, Token, Key (Zeilen 24, 34, 36, 47, 98; test_11)
  Code reference: scripts/asc_cleanup_certs.py
- [x] AC-8: Reihenfolge, if: always(), Confirm unveraendert (YAML-Pruefung)
  Code reference: .github/workflows/testflight.yml
- [x] AC-9: Eingabe cleanup_dry_run boolean default false, an beide Schritte als --dry-run weitergereicht (Variable DRY)
  Code reference: .github/workflows/testflight.yml
- [x] AC-10: Doku beschreibt Fehlerbild, Schritte, Auswahlregel, Schalter, Protokollzeile
  Code reference: docs/reference/testflight.md
- [x] AC-11: Tests gruen und alle 5 Fehlerfaelle gezielt rot gesehen
  Code reference: scripts/test_asc_cleanup_certs.py
- [x] AC-15: Diff beruehrt nur die vier Dateien (Workflow, Doku, Skript, Testskript) plus Spec, Briefing, Kontext, Artefakte
  Code reference: scripts/asc_cleanup_certs.py

Offen, Phase 7 (echte Laeufe): AC-12, AC-13, AC-14, AC-16.

### Runde 2

Nachfragen aus Runde 1 und Belege:
- Praefix-Trick: Basis http://127.0.0.1:5000, Link http://127.0.0.1:50001/... Geprueft wird startswith(base + "/") mit Schraegstrich; 50001 passt nicht. Ohne die Pruefung (M4) wird der Test rot, sie ist tragend.
- Leere Liste: show([]) druckt nichts, wanted leer, Zeile vorher=0 nachher=0 widerrufen=0, Exit 0; Zeile 75 ist gegen leere Liste geschuetzt.
- Name mit Leerzeichen: display_name() strippt, " Created via API " wird gewaehlt (leichte Nachsicht, siehe F001). Name "" faellt nicht auf displayName zurueck und bleibt.
- Fehlende id: bool(cert.get("id")) verhindert Auswahl.
- Fehlermeldungen: nur Pfad und Statuscode, kein Header, kein Token; Fremdhost-Meldung nennt nur den Host.
- Abschlussschritt ohne Schluesseldatei: exit 0 mit Hinweis. Tag-Push: cleanup_dry_run leer, Vergleich mit true falsch, DRY leer, es wird widerrufen.
- In den Mutationskopien nur ScriptTests (Workflow-Tests brauchen das Repo); die Workflow-Tests liefen im vollen Lauf gruen.

Befunde:
- F001 LOW edge_case, Code reference scripts/asc_cleanup_certs.py:62: strip() macht " Created via API " zum Treffer; unkritisch.
- F002 (vom Orchestrator widerlegt): Die Behauptung "keine concurrency-Sperre" ist falsch. `testflight.yml` Zeile 20-22 hat `concurrency: group: testflight, cancel-in-progress: false`, unveraendert gegenueber HEAD (`git show HEAD:... | grep -c concurrency` = 1). Parallele Laeufe sind serialisiert, der Abschlussschritt kann kein Zertifikat eines gleichzeitigen Laufs treffen. Kein Befund.
- F001 ist spec-konform: Die Spec verlangt "getrimmt".

Kein Befund verletzt eine geforderte AC.

### Runde 3

Anlass: Probelauf 37136927454 zeigte den echten Namen `Apple Development: Created via API`; Nachbesserung in Commit 7ab1dd7 (Spec-Override durch Henning).

Tests: test_asc_cleanup_certs.py 19 OK, test_asc_wait_build.py 17 OK.

Mutationen in Wegwerf-Kopien:
- M6 NAME zurueck auf "Created via API": GEFANGEN (9 rot: test_2, 3, 3b, 4 Fall "name without Apple prefix", 5, 6, 7, 9, 10b)
- M7 endswith("Created via API"): GEFANGEN (test_4, Fall "name without Apple prefix")
- M8 Namenspruefung entfernt: GEFANGEN (8 rot, darunter die Faelle eigenes Zertifikat und andere Person aus dem Probelauf)

Echte Kontodaten (Beleg probelauf-37136927454.txt) durch chosen(): [True, True, True, True, False, False, False]; die vier Aufraeum-Zertifikate werden gewaehlt, die drei eigenen nie.

- [x] AC-13: Auswahl an echten Daten bestaetigt (Felder certificateType, name, displayName; Trennung sauber)
  Code reference: scripts/asc_cleanup_certs.py
- [x] AC-1: Auswahl nur Typ DEVELOPMENT/IOS_DEVELOPMENT und Name genau "Apple Development: Created via API"
  Code reference: scripts/asc_cleanup_certs.py

Befund F3 LOW (Spec-Konsistenz): Testfaelle der Spec nennen teils die Kurzform "Created via API"; Kurzschreibweise, Regel und Pruefung unberuehrt. Kein Code-Befund.

## Verdict
**VERIFIED**

## Geprüfte Dateien

- sha256:be61a9eef5ab446b9fc1a3ed66d2fb6c470df4747dffb21c5d11684e54b006d6  .github/workflows/testflight.yml
- sha256:7f1f3d03128ad5f505541f619ecce5e5d775191b13755aa0d6bc621efe40dacb  docs/reference/testflight.md
- sha256:291dafac5e3c5afd8402ee5d94f10837ecd56d0cbcfc28d1ba4a2255d19aae11  scripts/asc_cleanup_certs.py
- sha256:fb22e98d100653a09abec5e2f56c9459b7af8cdcb86f15550e5d2cee0bb4ea89  scripts/test_asc_cleanup_certs.py

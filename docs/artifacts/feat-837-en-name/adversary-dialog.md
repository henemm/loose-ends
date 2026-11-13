# Adversary Dialog — feat-837-en-name
Spec: docs/specs/feat-837-schnitt-3-en-name.md
Datum: 2026-11-06 09:19

## Checkliste
- [x] **AC-1:** Given die Textdatei, When `wanted_texts` sie liest, Then ist der en-US-Name `Loose Ends: Voice Tasks`, ≤ 30 Zeichen, und der de-DE-Name unverändert. Belegt durch `test_repo_text_file_parses_and_fits_limit`.
- [x] **AC-2:** Given der Merge auf `main`, When `asc-app-info aktion=untertitel` läuft, Then legt Apple en-US mit Name und Untertitel an (kein 409), oder das Protokoll nennt Apples Fehlercode erneut. Belegt durch den Lauf-Link. (belegt durch Lauf 42208957863)
- [x] **AC-3:** Given AC-2 gelungen, When `asc-app-info aktion=lesen` läuft, Then zeigt es en-US mit Name `Loose Ends: Voice Tasks` und Untertitel „Say it. Clear your head.“. Belegt durch den Lauf-Link. (belegt durch Lauf 42209069974)
- [x] **AC-4:** Given AC-2 mit erneutem 409, Then wird kein weiterer Name blind versucht; der Abschlussbericht nennt Code und Befund, und Henning entscheidet über den nächsten Schritt. (Bedingung nicht eingetreten: kein 409, nichts zu entscheiden)

## Dialog

### Runde 1
**Adversary:** Beweis für AC-1 verlangt. Ich habe alle 13 Dateien `scripts/test_asc_*.py` selbst einzeln ausgeführt: 16+27+19+14+18+19+24+10+16+9+21+13+15 = 221 Tests, 0 Fehler, 0 übersprungen (siehe docs/artifacts/feat-837-en-name/adversary-test-output.txt). Zweiter-Doppelpunkt-Parsing: `line.partition(":")` teilt nur am ersten Doppelpunkt, der Wert behält „: Voice Tasks“. Eigene Probe mit der echten Datei: en-US name = 'Loose Ends: Voice Tasks', subtitle 'Say it. Clear your head.', de-DE subtitle 'Einfach sagen. Kopf frei.'; Längen 23/24/25, alle ≤ 30. Diff-Umfang: der Arbeitsstand ändert genau eine Zeile in docs/reference/app-store-untertitel.md (Name: Loose Ends wird Name: Loose Ends: Voice Tasks); der Test kam mit Commit 9bb2803 (3 Zeilen, neue Konstante EN_NAME).
**Implementierer:** Test `wanted["en-US"]["name"] == EN_NAME` (scripts/test_asc_app_info.py:319) war laut test-red-output.txt vor der Dateiänderung rot, jetzt grün.

### Runde 2
**Adversary:** Nachbohren. (a) Leerzeichen: Probe mit `Name:   Loose Ends: Voice Tasks  ` liefert getrimmten Wert, kein Abschneiden am zweiten Doppelpunkt. (b) 30-Zeichen-Grenze: 23 Zeichen, 7 Reserve; Prüfung läuft in wanted_texts vor jeder Anfrage (scripts/asc_app_info.py:40-42). (c) de-DE unverändert: die Datei enthält für de-DE keinen Namen, der Untertitel ist unverändert; der deutsche Name wird nicht geschrieben und bleibt bei Apple „Loose Ends“. (d) Altlasten: Suche nach „Loose Ends“ in scripts/asc_*.py, .github/workflows/asc-app-info.yml, docs/store, docs/reference/beta-beschreibung.md, docs/reference/app-store-untertitel.md findet keinen weiteren Ort, der den en-Namen festlegt (beta-beschreibung nennt die Marke nur im Fließtext; asc_app_info.py liest den Namen nur aus der Datei, Zeilen 112-117). (e) Der Vergleich mit origin/main zeigt zusätzlich docs/artifacts/fix-837-asc-fehlercode/adversary-dialog.md sowie Briefing und Red-Output: Stand-Unterschiede (origin/main hat Commit 2f54cda mit AC-5-Beleg, der Zweig noch nicht) bzw. Workflow-Artefakte, keine Codeänderung. (f) Die Spec verlangt nur zwei berührte Dateien: erfüllt (Textdatei plus Test).
**Implementierer:** Keine offenen Einwände. AC-2 bis AC-4 hängen am CI-Lauf von `asc-app-info` nach dem Merge und sind hier nicht belegbar; nichts abgehakt, kein Beleg erfunden.

### Runde 3 (nach Merge von PR #852)
**Adversary:** Belege aus echten Läufen. AC-2: `asc-app-info aktion=untertitel`, Lauf https://github.com/henemm/loose-ends/actions/runs/42208957863, Ergebnis success, App-Info 039b3fba in PREPARE_FOR_SUBMISSION, „en-US untertitel gesetzt: Say it. Clear your head.“, „de-DE untertitel gesetzt: Einfach sagen. Kopf frei.“, `gegenprobe gleich=ja`, kein 409. AC-3: `aktion=lesen`, Lauf https://github.com/henemm/loose-ends/actions/runs/42209069974, zeigt „en-US name=Loose Ends: Voice Tasks untertitel=Say it. Clear your head.“; de-DE-Name der Version bleibt „Loose Ends“. AC-4 ist bedingt auf einen erneuten 409; der trat nicht ein.
**Implementierer:** Keine Dateiänderung seit Runde 2; Hashes unverändert.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

Code reference: docs/reference/app-store-untertitel.md:14
Code reference: scripts/test_asc_app_info.py:319
Code reference: scripts/asc_app_info.py:32

Confirmation:
  AC: AC-1
  Code reference: docs/reference/app-store-untertitel.md:14
  Evidence: Zeile `Name: Loose Ends: Voice Tasks` (23 Zeichen); wanted_texts liefert den vollen Wert (scripts/asc_app_info.py:32, partition am ersten Doppelpunkt), Test scripts/test_asc_app_info.py:319 grün, 221/221 Tests grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: docs/reference/app-store-untertitel.md:14
  Evidence: Lauf 42208957863 success, en-US Name und Untertitel gesetzt, gegenprobe gleich=ja, kein 409.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: docs/reference/app-store-untertitel.md:14
  Evidence: Lauf 42209069974 zeigt en-US name=Loose Ends: Voice Tasks, untertitel=Say it. Clear your head.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: docs/reference/app-store-untertitel.md:14
  Evidence: Bedingung (erneuter 409) nicht eingetreten; Lauf 42208957863 ohne Fehler, kein weiterer Name versucht.
  Status: CONFIRMED

Keine Findings.

VERDICT: VERIFIED
Tests: 221 passed, 0 failed, 0 übersprungen

## Geprüfte Dateien

- sha256:4c130b486119edfd97aaf75a9bcf814005a1ec594a0e0877b32f8302f280471f  docs/reference/app-store-untertitel.md
- sha256:4bd6730dab1c1445193c0e6d77d81e50ed69056cadf7ec33084b4024a68400bb  scripts/asc_app_info.py
- sha256:9bb85c3f1a6e9f4f798a0db5fcaabd6fcf56906a70e6a3605139093907436100  scripts/test_asc_app_info.py

## Prüfbasis

- base: b99722caef8273510454f3a58f968df70492e219
- blob:6377b58bf2924a7a234becef3c484945c768c1a1  docs/reference/app-store-untertitel.md
- blob:167ac5c60af91bb822fc05b02e4d43cc4899d241  scripts/asc_app_info.py
- blob:230caf9398cfce6f29f8ff53ec58d4727e484491  scripts/test_asc_app_info.py

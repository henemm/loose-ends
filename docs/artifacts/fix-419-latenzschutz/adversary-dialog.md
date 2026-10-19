# Adversary Dialog — fix-419-latenzschutz
Spec: docs/specs/fix-419-latenzschutz.md
Datum: 2026-10-19 09:37

## Checkliste
- [x] **AC-1:** Enthält das Log für beide Messtests `was cancelled … "<Grund>"`, nennt `measurement_status.py --latency-log` beide Tests einzeln als „NICHT gemessen“ mit dem Grund aus dem Log; eine Gesamtzahl allein genügt nicht.
- [x] **AC-2:** Enthält das Log `passed after N seconds` für einen Messtest, steht er als „gemessen“ in der Ausgabe; ein `failed` steht als „FEHLGESCHLAGEN“. Gemischte Zustände (ein Test gemessen, einer nicht) werden je Test richtig ausgegeben.
- [x] **AC-3:** Fehlt ein Messtest im Log ganz (z. B. umbenannt, gefiltert), steht er als „NICHT gemessen: nicht im Log“, nie als gemessen und nie schweigend.
- [x] **AC-4:** Die Abbruchmeldung „Sprache de_DE wird hier nicht unterstützt“ enthält `isAvailable`, Anzahl `supportedLocales` und Anzahl `installedLocales`; die Zeile erscheint im Latenzschutz-Bericht des CI-Laufs (sichtbar in der Job-Zusammenfassung).
- [x] **AC-5:** Der CI-Schritt schreibt bei Ausfall eine Annotation `::warning::` und die Markdown-Tabelle in `GITHUB_STEP_SUMMARY`; der Lauf bleibt grün (der Ausfall ist Umgebung, kein Fehler), meldet aber „nicht gemessen, nicht bestanden“.
- [x] **AC-6:** `sim.sh sim-unit`/`unit` gibt nach dem Lauf die Latenzschutz-Zeile aus (Quelle: Rohlog des Laufs); fehlt das Log, steht ein ausdrücklicher Hinweis statt Schweigen.
- [x] **AC-7:** Skripttests (`scripts/test_measurement_status.py`) decken AC-1 bis AC-3 gegen echte Auszüge (der Auszug aus Lauf 39167072947 als Fixture) ab und laufen grün; die bestehenden Tests zu den Messstrecken bleiben grün.
- [x] **AC-8:** Ehrlichkeit: Die Spec und der Abschlussbericht nennen, dass die Gegenprobe „ohne `.fastResults` rot“ im CI nicht erfüllt wird und welcher Teil des Schutzes (Konstantentest) trotzdem in jedem Lauf läuft.

## Dialog

### Runde 1
**Adversary:** Beweis für AC-1 bis AC-8 verlangt; selbstgebaute Logs gegen `latency_status` (gemischt, beide failed, Test mehrfach, cancelled UND failed, leeres Log, Windows-Zeilenenden, ANSI-Farbcodes, Sonderzeichen im Grund, Namenszusatz). Nachfragen: Q1 letzte Zeile je Test gewinnt (failed kann von späterem cancelled überdeckt werden); Q2 cancelled ohne Grund / leerer Grund; Q3 `--latency-warning` ohne `--latency-log` schweigt.
**Implementierer:** `python3 scripts/test_measurement_status.py` 19 Tests OK, Skriptsuite 173 OK, `bash -n scripts/sim.sh` sauber, ci.yml per `yaml.safe_load` ladbar. Das echte Rohlog des Simulatorlaufs (`docs/artifacts/fix-419-latenzschutz/sim-unit-latency.txt`) ergibt beide Tests einzeln „NICHT gemessen“ mit `isAvailable false, supportedLocales.count 0, installedLocales.count 0`.
Code reference: scripts/measurement_status.py:91
Code reference: scripts/sim.sh:273
Code reference: .github/workflows/ci.yml:62
Code reference: LooseEndsTests/SpeechLatencyTests.swift:50

### Runde 2
**Adversary:** Gegenprobe der Nachfragen selbst ausgeführt. Q1: failed danach passed nur bei Wiederholung, dann korrekt; failed danach cancelled ergibt „NICHT gemessen“, nie „gemessen“, kein Verstoß. Q2: beide Fälle landen in not_measured, nie schweigend „gemessen“; Swift liefert immer einen nichtleeren Grund. Q3: der CI-Schritt übergibt immer `--latency-log`, die Lücke trifft nur einen Handaufruf. Fehlendes Log: `::warning::… kein Log`, Exit 0.
**Implementierer:** Keine Änderung nötig; AC-1 bis AC-8 AKZEPTIERT. AC-4 und AC-5 zeigt am echten CI-Lauf erst der Lauf nach dem Merge (die Spec nennt das; Beleg bis dahin: Simulator-Rohlog und Skripttests). AC-8: Der Spec-Abschnitt „Offen benannt“ nennt die nicht erfüllte Gegenprobe „ohne `.fastResults` rot“ und den weiter laufenden Konstantentest.
Code reference: scripts/measurement_status.py:99

## Findings (alle LOW, kein Blocker, nicht behoben)
- F001 LOW edge_case: letzte Zeile je Test gewinnt, ein früherer failed kann überdeckt werden.
- F002 LOW edge_case: cancelled-Zeile ohne Grund ergibt „nicht im Log“; leerer Grund ergibt „NICHT gemessen: “ ohne Text.
- F003 LOW anti_pattern: `--latency-warning` ohne `--latency-log` schweigt mit Exit 0 (nur Handaufruf).

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:1491d12caee0c36246d3f7c376b00489f6bd2252bbd2d83151b44cbd0a6bb39b  .github/workflows/ci.yml
- sha256:a9c1942deeaf92f0c7d58f4a49af7d31a4217fccf5b19ac652131f589fbda944  LooseEndsTests/SpeechLatencyTests.swift
- sha256:11aadb064d3bc65d83f0e36a1257859e80c7d9819c44f72aaa440e30776f9e7c  scripts/measurement_status.py
- sha256:3ddbee33a1ec4e77a9ac2792eb01c5acfa0437146f5693755c6f0cb1ea354f10  scripts/sim.sh

## Prüfbasis

- base: be925253cbf5e7a71e0dc4916bcb5bb4960b03ca
- blob:11856e8899129e43cbc9c5c8124206b3e02bc33e  .github/workflows/ci.yml
- blob:15ce742e92a6fcf9a3a5845153fcd4fdf791c9d3  LooseEndsTests/SpeechLatencyTests.swift
- blob:48cfbcd3b63da3b93b13e1f6337a3d1a4a57579c  scripts/measurement_status.py
- blob:901f8ce319d0119e61501ab17f9bc75b8611a927  scripts/sim.sh

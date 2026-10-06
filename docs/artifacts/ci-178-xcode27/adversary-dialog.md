# Adversary Dialog — ci-178-xcode27
Spec: docs/specs/tooling/fix-178-ci-xcode27.md
Datum: 2026-10-06

## Checkliste

- [x] AC-1 Xcode-Version 27.0 aus xcodebuild -version: Quelltext + Attrappe (27.0 ok, 26.6/27.2/27.0.1 Exit 1) belegt — offen: echte Protokollzeile je Job im PR-Lauf vor dem Merge
- [x] AC-2 Abbruch mit ::error::Expected Xcode 27.0 und Exit 1 bei anderer Version (Test 5, Attrappe)
- [x] AC-3 Keine Absenkung: 0 Treffer für sed -i, 26.0, macos-26, project.yml im Workflow-Ordner
- [x] AC-4 Strenge Simulatorwahl iPhone 17 / iOS-27-0, sonst ::error:: + Geräteliste, kein Rückfall (Quelltext + 4 Attrappenfälle je Schritt) — offen: Protokollzeile im PR-Lauf
- [x] AC-5 Diagnoseschritt: Version, Laufzeiten, Gerät, Modellverfügbarkeit mit --info (F002 behoben), "nicht erhebbar"-Zeile, bricht nie ab (continue-on-error + || true) — offen: echte Zeilen im PR-Lauf vor dem Merge
- [x] AC-6 Check-Namen unverändert (Quelltext, Test) — offen: gh pr checks im PR
- [x] AC-7 Deployment-Ziel 27.0, kein Schritt ändert die Projektdatei (Quelltext, AC-3) — offen: Build-Protokollzeile im PR-Lauf
- [x] AC-11 Compiler-Schalter entfernt (0 Treffer, #if/#endif balanciert, unit-green.txt) — offen: CI-Übersetzung im PR-Lauf
- [x] AC-12 CLAUDE.md-CI-Abschnitt nachgezogen (Test grün)
- [x] AC-13 Kein Pfad der Geräteliste berührt

## Abnahme im PR-Lauf (NICHT belegt — Pflicht in Phase 7/8 vor dem Merge)

Diese Punkte setzen einen hochgeladenen Stand voraus; Commit und Push sind bis zum Verdict gesperrt.
Sie sind hier bewusst nicht abgehakt und bleiben Abnahmekriterien der Spec, die `/60-validate`
mit Lauf-ID belegt. Ohne sie wird nicht gemergt.

- offen: AC-8 Alle drei CI-Jobs grün ohne Wiederholung
- offen: AC-9 speech-stress per workflow_dispatch (Iterations 3) grün
- offen: AC-10 Zeiten gegen Ausgangswerte in der PR-Beschreibung
- offen: AC-14 Ausliefern nach dem Merge (Phase 8)
- offen: echte Protokollzeilen zu AC-1, AC-4, AC-5, AC-6, AC-7, AC-11

## Dialog

### Runde 1
**Adversary:** Korrekturen selbst geprüft. scripts/test_ci_xcode27.py: 11/11 ok. log help show lokal: "only default level messages unless --info and/or --debug" — das --info im Schritt "Diagnose model availability" (ci.yml:124) ist also nötig und jetzt gesetzt; Prädikat passt zu Logger(subsystem com.henning.looseends, category Enrichment) in EnrichmentCoordinator.swift:24, "Enriched" ist info (:74), "Model unavailable" notice (:41). Diagnose-Attrappe: xcrun, das nur bei --info "Enriched ABC: 3 fields" liefert -> Ausgabe "Enriched: 1 lines", also erhebbar (F002 behoben). Leere Ausgabe, fehlschlagender spawn und leere SIM_UDID -> "Modellverfügbarkeit nicht erhebbar", Exit 0. Pick-Schritte (ci.yml:90 und speech-stress.yml:44), je 4 Fälle mit nachgebautem xcrun unter bash -e -o pipefail: leeres Objekt -> ::error:: + Geräteliste, Exit 1 (F003 behoben); iPhone 17 nur unter iOS-27-1 -> ::error::, Exit 1, kein Rückfall; korrekter Treffer -> Exit 0, SIM_UDID=GOOD; kaputtes JSON -> Traceback, Exit 1, ohne ::error::-Zeile (Rest von F003, Schritt bleibt rot, kein stiller Durchlauf). Greps: keine Absenkung, kein Compiler-Schalter. MeasurementRun.swift: #if/#endif balanciert.
**Implementierer:** F002 und F003 korrigiert (--info; .get("devices", {})). Quelltext und Attrappen decken AC-2/3/4/5(Logik)/6/7/11/12/13 vor dem Push; AC-1/5/8/9/10/14 nur im PR-Lauf beweisbar.

### Runde 2
**Adversary:** Frühe-Einigkeit-Skepsis: Ich habe die Begründungen nicht übernommen, sondern geprüft. F001 (exakter Vergleich "Xcode 27.0"): Die Begründung trägt. Henning baut mit genau 27.0; ein Image mit 27.0.1 ist eine andere Toolchain als seine, und bei testflight.yml gilt dieselbe Logik (#174). Rot statt still abweichend ist die sichere Richtung, der Fehlertext nennt Soll und Ist. Der Spec-Satz "damit ein Image-Update auf 27.0.x nicht bricht" widerspricht dem eigenen Codeblock der Spec (Vergleich der ganzen Zeile); er ist als Widerspruch im Abschlussbericht zu benennen, der Codeblock ist maßgeblich. Kosten: ein Patch-Update des Labels färbt alle Jobs rot, bis jemand die Prüfung bewusst anpasst — gewollt und laut. Kein offener Defekt. F004 (speech-stress ohne Auslöser bei Änderung der Action): Die Begründung trägt. Die Action läuft bei jeder PR in allen drei CI-Jobs (ci.yml hat pull_request ohne Pfadfilter), ein Fehler in ihr wird dort sofort sichtbar; der Stress-Lauf ist auf Spracherfassung gezielt, AC-9 verlangt nur den workflow_dispatch-Lauf, kein Spec-Punkt verlangt einen weiteren Auslöser. Gegenprobe zu den Korrekturen: der Diagnose-Schritt kann nach --info "Model unavailable" und "Enriched" trennen; ob die Log-Persistenz im echten Simulator Info-Zeilen hält, ist lokal nicht belegbar und bleibt PR-Lauf-Punkt (AC-5), die Rückfallzeile "nicht erhebbar" ist spezifiziert. Kein neuer Befund oberhalb LOW.
**Implementierer:** Keine weitere Nachbesserung. Offen sind nur die Beweise, die einen echten Lauf brauchen (AC-1/5 Zeilen, AC-8, AC-9, AC-10, AC-14); CI muss vor dem Merge grün sein.

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: spec_violation
  Code reference: .github/actions/select-xcode-27/action.yml:13
  Description: Vergleich der ganzen Zeile mit "Xcode 27.0"; "Xcode 27.0.1" bricht. Bewusst unverändert (Tech-Lead-Entscheidung, gleiche Logik wie testflight.yml aus #174; Henning baut mit genau 27.0).
  Spec requirement: Spec Änderung 1 — Satz "damit ein Image-Update auf 27.0.x nicht bricht" widerspricht dem Codeblock der Spec.
  Conflict: Widerspruch liegt in der Spec, nicht im Code; Verhalten ist fail-safe und laut. Im Abschlussbericht zu benennen.
  Remediation: Keine Codeänderung; Spec-Satz bei Gelegenheit streichen. Status: akzeptiert.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: .github/workflows/ci.yml:124
  Description: Ursprünglich fehlte --info, "Enriched" (info) war unsichtbar. Behoben: log show --info; Attrappenprobe zeigt "Enriched: 1 lines".
  Spec requirement: AC-5 — Modellverfügbarkeit oder Zeile "nicht erhebbar".
  Conflict: keiner mehr.
  Remediation: erledigt. Status: BEHOBEN.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: .github/workflows/speech-stress.yml:44
  Description: .get("devices", {}) in beiden Pick-Schritten (auch ci.yml:90); leeres Objekt ergibt ::error:: + Geräteliste. Kaputtes JSON bricht weiter mit Traceback (Exit 1), ohne ::error::-Zeile; praktisch irrelevant, da simctl gültiges JSON liefert.
  Spec requirement: AC-4 — Abbruch mit ::error::.
  Conflict: nur Meldungsqualität im Extremfall; Abbruch ist gegeben.
  Remediation: erledigt für den realistischen Fall. Status: BEHOBEN.

Finding:
  ID: F004
  Severity: LOW
  Category: anti_pattern
  Code reference: .github/workflows/speech-stress.yml:20
  Description: paths-Filter enthält nicht die Action-Datei. Bewusst unverändert: die Action läuft bei jeder PR in allen drei CI-Jobs; der Stress-Lauf ist auf Spracherfassung gezielt.
  Spec requirement: keine (Befund)
  Conflict: keiner.
  Remediation: keine. Status: akzeptiert.

## Bestätigungen

Confirmation:
  AC: AC-1, AC-2
  Code reference: .github/actions/select-xcode-27/action.yml:12
  Evidence: xcode-select auf Xcode_27.app, Vergleich der Zeile 1 von xcodebuild -version mit "Xcode 27.0"; Falsch -> ::error::Expected Xcode 27.0, exit 1 (Tests test_rejects_other_version, test_accepts_xcode_27_0). Echte Zeile im PR-Lauf offen.
  Status: CONFIRMED

Confirmation:
  AC: AC-3, AC-6, AC-7, AC-5, AC-4
  Code reference: .github/workflows/ci.yml:124
  Evidence: Drei Jobs xcode-27 mit Action, Namen unverändert, keine Absenkung; Pick-Schritt Z. 90 strikt; Diagnose-Schritt mit --info, continue-on-error, nicht-erhebbar-Zeile (Attrappenläufe in adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: .github/workflows/speech-stress.yml:44
  Evidence: Nur Laufzeit iOS-27-0 und Name iPhone 17; leer, falsche Laufzeit -> ::error::, Exit 1; Treffer -> SIM_UDID gesetzt.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: Measurement/MeasurementRun.swift:226
  Evidence: Schalter weg, LanguageModelError-Zweig unbedingt, #if/#endif balanciert (2/4, 211/238), unit-green.txt grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-12, AC-13
  Code reference: scripts/test_ci_xcode27.py:147
  Evidence: test_claude_md_describes_the_new_ci und alle 11 Tests grün; required-files nennt nur Measurement/MeasurementRun.swift, Diff nur in erlaubter Dateimenge.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED — alles vor dem Push Belegbare ist belegt (11/11 Tests, Gegenproben beider Pick-Schritte und des Diagnose-Schritts, Korrekturen F002/F003 wirksam), keine offenen CRITICAL/HIGH/MEDIUM-Defekte; F001/F004 sind begründet akzeptiert (LOW). Offen: Beleg im PR-Lauf vor dem Merge für AC-8, AC-9, AC-10 (und echte Protokollzeilen zu AC-1/4/5/6/7/11), AC-14 nach dem Merge.

## Geprüfte Dateien

- sha256:2464bd2f3a0b4502f5a351fdd7c2103b610b0b73318da2741412cf82c27e4d9f  .github/actions/select-xcode-27/action.yml
- sha256:dccd8a7e762bd78eb233c088fe0bf0d787707287149b0a0200911159be16b0bb  .github/workflows/ci.yml
- sha256:2c5a78e5cd384a6ec5598572d2d5f62d5ede9766e2238a80b99321782f68ac35  .github/workflows/speech-stress.yml
- sha256:63d7b8e6d9f8f5faa9119d56cf6e8789b6aadb1c838a727dfae5a8ec12f8ec50  Measurement/MeasurementRun.swift
- sha256:529cf492624c203d92877458f3ec47d8a783abea8fe237857342d73afd32b22d  scripts/test_ci_xcode27.py

## Prüfbasis

- base: 54f6ef1e276e9a8729e7d3a50ae34f8e8d96b205
- blob:a27cbc67317a136303d901cc15e45c116636f73b  .github/actions/select-xcode-27/action.yml
- blob:78c4727718603310aaeefcad97f8f1fa4a4cfed5  .github/workflows/ci.yml
- blob:7ac87a791e8bee3b519477be68942771a7ad84dd  .github/workflows/speech-stress.yml
- blob:0ac2ef2625589a73e90e620450320b7f8d6ada3b  Measurement/MeasurementRun.swift
- blob:02afbb14d565cf7d5f93a1017a828c38b010a673  scripts/test_ci_xcode27.py

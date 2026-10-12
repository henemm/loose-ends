# Adversary Dialog — fix-336-wiedererkennung-wackler
Spec: docs/specs/tooling/fix-336-wiedererkennung-wackler.md
Datum: 2026-10-12 07:39

<!-- Hinweis Orchestrator: Die Spec führt ihre ACs als `- [ ] AC-N …` statt `- **AC-N:** …`; `adversary_dialog.py parse`
erkennt sie deshalb nicht und das Gerüst kam mit leerer Checkliste. Die Punkte unten sind wörtlich aus der Spec übernommen. -->

## Checkliste

- [x] AC-1 `waitForLabel` in `LooseEndsUITests/RecognitionWalkthroughTests.swift` hat den Standardwert `timeout: TimeInterval = 60`; ein Kommentar nennt die Ursache (Schnappschüsse auf dem Hauptthread der App, bis zu 29 s, XCTest-Grenze 30 s je Schnappschuss) und #336.
- [x] AC-2 Alle Zusicherungen und alle Aufrufer von `waitForLabel` sind unverändert; das Diff berührt in der Datei nur die Funktion und ihren Kommentar.
- [x] AC-3 Ein lokaler Lauf im iOS-27-Simulator unter Zusatzlast liegt vor der Änderung und nach der Änderung vor; die Blockaden sind per `correlate.py` den Abfragen zugeordnet, die Ausgaben im Bericht zitiert.
- [x] AC-4 `./scripts/sim.sh test-proof RecognitionWalkthroughTests` ist ohne Last grün (maschineller Beleg, Screenshots geöffnet und beschrieben).
- [x] AC-6 Kein Produktcode geändert und `.github/workflows/ci.yml` unverändert: Das Diff berührt genau die eine Datei aus dem Scope (ohne Dokumente unter `docs/`).
- [x] AC-7 Geräteliste: Kein Pfad der Geräteliste berührt. Keine sichtbare UI-Änderung, daher keine Entwurfsvorschau.

- Offen bis nach dem Push bzw. Merge (bewusst ohne Kästchen, wie bei #172, damit das Gate sie nicht als bewiesen liest; Nachweis in /60-validate und /70-deploy): AC-5 Drei CI-Läufe in Folge sind grün, geprüft am Protokoll der Läufe (nicht am Endstatus allein); die Erfolgsprüfung steht im Ticket #336. · AC-8 Ausliefern: Nach dem Merge ist `bash ~/.claude/scripts/loose-ends-sync-main.sh` gelaufen.

## Dialog

### Runde 1
**Adversary:** Beweis je Punkt gefordert.
- AC-1: Diff zeigt `timeout: TimeInterval = 60` und Kommentar mit Hauptthread, 29 s, 30 s, #336.
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:134
- AC-2: Diff = +5/-1, nur Kommentarzeilen 129-132 und Signaturzeile 134; die sechs Aufrufer (171, 186, 211, 232, 238, 244) stehen unverändert ohne eigene Frist.
- AC-3: load-vorher (8x yes, Blockaden 5,1 s Sitzungsaufbau, 9,9 s nach Tap/Synthesize event) und load-nachher (3,8 s Sitzungsaufbau) per correlate-output.txt zugeordnet; Zeitzonen konsistent (UTC im Watchdog, Ortszeit +2 h im Lauf). Beide Läufe grün (88,7 s / 67,2 s).
- AC-4: test-green-output.txt "Executed 1 test, with 0 failures", simulator-run.txt "1 bestanden, 0 fehlgeschlagen, 0 übersprungen". Screenshots geöffnet: 2-werte-von-hand-gesetzt zeigt "Zaun streichen", Duration 30 min, Contexts Garden ohne Vermerk; 4-zweite-aufgabe zeigt "Streichen Zaun" (Titel geglättet, Rohtext unverändert), Duration 30 min »«, Contexts Garden »« (Regelvermerk).
- AC-6: Änderungen außerhalb docs/ nur RecognitionWalkthroughTests.swift und LooseEnds/LooseEnds.entitlements (fremd, siehe F001); `.github` unverändert.
- AC-7: Gerätelisten-Pfad nur durch die fremde entitlements-Änderung berührt, nicht durch das Ticket; Ticket selbst ist Testcode.
Kritik: Die Wegwerf-Prüfung (SlowLabel, Thread.sleep im KVC-Getter) belegt den Mechanismus von XCTNSPredicateExpectation/XCTWaiter (eine blockierende Auswertung verbraucht die Frist; 10 s -> genau 1 Auswertung, 10 s und 30 s rot, 60 s grün, 30-s-Gegenprobe trennt den 29-s-Fall), nicht aber den Hänger eines echten XCUIElement-Snapshots; das ist ein Analogon. Die Lastläufe erzeugten keine Blockade über 10 s und wären auch vorher grün gewesen (vorher-Lauf grün): sie belegen die Zuordnung, nicht die Wirkung der Frist.
**Implementierer:** Spec benennt beides: RED nicht deterministisch erzwingbar; Ersatz = Läufe unter Last plus Wegwerf-Prüfung.

### Runde 2
**Adversary:** Gezielte Angriffe.
- 60 s begründet? Zwei Auswertungen à 29,1 s = 58,2 s, Reserve 1,8 s; eine zweite bis zur 30-s-Grenze (59,1 s) passt knapp. Die Wegwerf-Prüfung lässt die zweite Auswertung sofort laufen, deckt Doppel-Hänger also nicht ab (F002).
- Verdeckt die Frist echte Hänger? test4-falscher-wert.txt: falscher Erwartungswert scheitert nach ca. 60 s an Zeile 171 (18,9 -> 78,9 s, ~60 Auswertungen im 1-s-Takt); Zusicherung bleibt scharf, Watchdog protokolliert weiter. Kosten im Fehlerfall: bis 60 s, wegen continueAfterFailure=false nur einmal je Lauf.
- correlate.py: Blockade-Start = Ende minus Dauer, letzte drei Aktivitäten <= Start+0,3 s. Die 9,9-s-Blockade ordnet sich "Check for interrupting elements"/"Synthesize event" (Tap) zu, 5,1/3,8 s dem Sitzungsaufbau. Zuordnung stimmt zur Ausgabe, belegt aber Blockade bei Test-Aktivität, nicht speziell eine Label-Abfrage. Im nachher-Ordner fehlt UITestResults.xcresult, correlate-output liegt vor.
- Regression: Standardwert wirkt nur auf waitForLabel; waitForExistence-Fristen unberührt.
**Implementierer:** keine Änderung nötig; F002/F003 sind Hinweise, keine Spec-Verletzung.

Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEnds/LooseEnds.entitlements:15
  Description: Arbeitsordner enthält fremde Änderung (ubiquity-kvstore-identifier entfernt, -2 Zeilen), nicht Teil des Tickets; ebenso docs/reference/context-word-learning.md.
  Spec requirement: AC-6 / AC-7 — nur eine Datei, kein Pfad der Geräteliste.
  Conflict: Würde sie mit eingecheckt, wäre AC-6 verletzt und Stufe 3 (entitlements) ausgelöst.
  Remediation: Nicht stagen; nur RecognitionWalkthroughTests.swift und docs/artifacts aufnehmen.
Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:134
  Description: 60 s lassen zwei 29-s-Hänger nur mit 1,8 s Reserve zu; Wegwerf-Prüfung testet nur einen Hänger.
  Spec requirement: AC-1 — Frist fasst zwei langsame Auswertungen.
  Conflict: Knapp, Spec-Aussage trifft aber zu; AC-5 (CI) ist das Korrektiv.
  Remediation: Keine; bei erneutem Wackler Messung bzw. Wartehilfe-Ticket gemäß Spec-Alternativen.
Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:171
  Description: Beide Lastläufe erreichten keine Blockade über 10 s; kein Lauf belegt kausal, dass die Änderung einen echten Ausfall verhindert. Wirkung stützt sich auf das Analogon.
  Spec requirement: AC-3 — Läufe vor/nach der Änderung mit zugeordneten Blockaden.
  Conflict: Formal erfüllt (Spec erlaubt "besteht trotz Blockade"); Wirkungsnachweis erst über AC-5.
  Remediation: AC-5 am Protokoll prüfen.

Confirmation:
  AC: AC-1
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:134
  Evidence: Standardwert 60, Kommentar Zeilen 129-132 nennt Ursache und #336.
  Status: CONFIRMED
Confirmation:
  AC: AC-2
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:171
  Evidence: Diff +5/-1 nur an Funktion und Kommentar, Aufrufer unverändert.
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:134
  Evidence: load-vorher/nachher correlate-output.txt, beide Läufe grün.
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:244
  Evidence: test-green-output.txt 0 failures, 4 Screenshots, zwei geöffnet.
  Status: CONFIRMED
Confirmation:
  AC: AC-6
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:137
  Evidence: Ticket-Diff nur diese Datei, .github unverändert; fremde entitlements siehe F001.
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:128
  Evidence: Nur Testcode, keine UI, kein Geräteliste-Pfad durch das Ticket.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:488f02c5fb63be161b34bd2dfc17ee33def7fa134c32e4e95382461a85add1c8  LooseEnds/LooseEnds.entitlements
- sha256:b42d61551e4c4fba228b7c1151f06b06655b09a46d38e7d069b7f615a8570aff  LooseEndsUITests/RecognitionWalkthroughTests.swift

## Prüfbasis

- base: c16cd5ad396b5afe88ece991a4f382e67fc0005b
- blob:73fde7d6ecd4236d4ce15850a4b06d7b92de109d  LooseEnds/LooseEnds.entitlements
- blob:5139a593df2470d80287fa88d3a680322fb6ea9c  LooseEndsUITests/RecognitionWalkthroughTests.swift

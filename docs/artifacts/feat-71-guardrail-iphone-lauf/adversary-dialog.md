# Adversary Dialog — feat-71-guardrail-iphone-lauf
Spec: docs/specs/spike-71-schnitt-2b-iphone-lauf.md
Datum: 2026-10-28 21:24

## Checkliste
- [x] **AC-1:** `GuardrailProbe.probes(from:corpus:runsPerEntry:)` übersetzt je Eintrag × Durchlauf ein Ergebnis in eine Probe: `menge` `alltag` bei Id-Präfix `alltag-`, sonst `heikel`; `sprache` = `lang`; `gruppe` = `form`; `text` = Satz; `durchlauf` = `runIndex + 1`; `fehlerart` `nil` bei Erfolg, `guardrail` und `refusal` aus `errorKind` übernommen.
- [x] **AC-2:** `rateLimited`, `timeout`, `assetsUnavailable` und `contextWindow` bleiben Proben mit ihrer Fehlerart und gelten über `isExcluded` nicht als Ablehnung (`isRefused == false`); ein Fehler ohne `errorKind` wird zu `andere`.
- [x] **AC-3:** Fehlt für Eintrag × Durchlauf ein Ergebnis, entsteht keine Probe und `Translation.missing` zählt ihn (Soll = Einträge × `runsPerEntry` minus vorhandene). Ein Ergebnis zu unbekannter `entryID` oder mit `runIndex ≥ runsPerEntry` steht in `Translation.unknown`. Bei mehreren Ergebnissen desselben Eintrags und Durchlaufs zählt das letzte.
- [x] **AC-4:** `GuardrailProbe.withoutEverydayWording(_:)` setzt `text = nil` für jede Probe mit `menge != "heikel"` und lässt die heiklen Proben unverändert; `RealModelGuardrailTests.writeRaw` benutzt sie, ohne Verhaltensänderung für die Mac-Rohdaten.
- [x] **AC-5:** Kette ohne Gerät: Ein Test baut aus einem Korpus (100 heikle, 287 Alltag mit erfundenen Sätzen und einem Erkennungswort) und gestellten Ergebnissen (774 Aufrufe, eine Ablehnung in der Alltagsmenge) die Proben, den `RawFile`-JSON-Text und die lokale Zusammenfassung: Der Rohtext enthält weder ein Alltagswort noch das Erkennungswort, aber `alltag-<Index>` des Treffers; die Zusammenfassung enthält den Wortlaut des Treffers; `missing == 0`; Zahlen stimmen (1/387 Texte, 0 ausgenommen).
- [x] **AC-6:** Der Berichttest läuft nur, wenn `LOOSEENDS_GUARDRAIL_IPHONE_RESULT` und `LOOSEENDS_GUARDRAIL_CORPUS` auf vorhandene Dateien zeigen, sonst wird er übersprungen; mit ihnen schlägt er fehl, wenn `missing > 0` oder `unknown > 0`; er schreibt die Rohdaten nur nach `LOOSEENDS_GUARDRAIL_OUT` und die lokale Zusammenfassung nur nach `LOOSEENDS_GUARDRAIL_LOCAL`, ohne die Variablen nichts. Gerät und System im Kopf stammen aus `Conditions` der Ergebnisdatei.
- [x] **AC-7:** `summary` und `line` existieren genau einmal im Quelltext (in `RealModelGuardrailTests`, `internal`); `GuardrailReportTests` ruft sie auf (Prüfung: `grep -c "func summary"` über `LooseEndsTests/` ergibt 1).
- [x] **AC-8:** Der Code-PR enthält genau die drei Dateien der Scope-Tabelle (Dateiliste des PR) und läuft auf keinem Gerät: kein `devicectl`, kein `lab-guardrail`.

## Dialog

### Runde 1
**Adversary:** Alle acht Punkte mit Beleg geprüft, nichts auf einem Gerät, nichts auf dem Mac-Host.
- AC-1 akzeptiert: `menge` über Präfix `alltag-`, Felder aus dem Korpuseintrag, `durchlauf = runIndex + 1`. Code reference: Measurement/GuardrailReport.swift:171
- AC-2 akzeptiert: Fehler ohne `errorKind` wird `andere`; Drosselung, Zeitüberschreitung, fehlende Modell-Daten und Kontextfenster sind ausgenommen, nicht abgelehnt. Code reference: Measurement/GuardrailReport.swift:172
- AC-3 akzeptiert: fremde Id und `runIndex` außerhalb `0..<runsPerEntry` (auch negativ) zählen als `unknown`; beim Doppel gewinnt das letzte in Reihenfolge der Datei, wie die Spec es festlegt. Code reference: Measurement/GuardrailReport.swift:146
- AC-4 akzeptiert: `withoutEverydayWording` setzt `text = nil` für alles außer `heikel`; der Mac-Test ruft sie auf, gleiche Logik wie vorher. Code reference: Measurement/GuardrailReport.swift:178 und Code reference: LooseEndsTests/RealModelGuardrailTests.swift:116
- AC-5 akzeptiert: 774 Ergebnisse, `missing`/`unknown` 0, 387 Texte, ein Treffer, kein Alltagswort in den Rohdaten, Wortlaut nur in der Zusammenfassung. Code reference: LooseEndsTests/GuardrailReportTests.swift:303
- AC-6 akzeptiert: ohne Variablen "0 tests", nichts geschrieben; Schreiben nur bei gesetztem, nicht leerem OUT bzw. LOCAL; kein `try?`. Zusätzlich liegt der Kettenlauf mit Wegwerf-Dateien im Simulator vor (`simulator-kettenlauf.txt`: 0 Treffer für das Alltagswort in den Rohdaten, Treffer samt Wortlaut in der lokalen Zusammenfassung). Code reference: LooseEndsTests/GuardrailReportTests.swift:178
- AC-7 akzeptiert: `grep -rn "func summary(" LooseEndsTests/` ergibt genau eine Stelle (`RealModelGuardrailTests.swift:138`). Das Muster `func summary` ohne Klammer trifft zusätzlich `SyncStatusTests.swift:65` (`summaryPerState`) — Ungenauigkeit der Spec, kein Defekt. Code reference: LooseEndsTests/RealModelGuardrailTests.swift:138
- AC-8 akzeptiert: genau drei Dateien (+254/−7), weder `devicectl` noch `lab-guardrail` im Diff, Funktionen unter 50 Zeilen.
- Tests: `GuardrailReportTests` 16 grün im Prüferlauf; volle Unit-Suite im Simulator grün (1070 Zeilen mit Haken, keine mit Kreuz).
- Nachfrage N1 (niedrig): doppelte Ids im Korpus teilen sich ein Ergebnis, `missing` bleibt 0.
- Nachfrage N2 (mittel, Datenschutz, außerhalb der Spec): jede Id ohne Präfix `alltag-` gilt als `heikel`, ihr Text bliebe in den Rohdaten.
Code reference: Measurement/GuardrailReport.swift:146
Code reference: Measurement/GuardrailReport.swift:172
Code reference: Measurement/GuardrailReport.swift:178
Code reference: LooseEndsTests/GuardrailReportTests.swift:303
Code reference: LooseEndsTests/RealModelGuardrailTests.swift:116
**Implementierer:** N1 und N2 gehören zu 2b-2, nicht zu 2b-1: Die Spec ist nach der Freigabe eingefroren, und in 2b-1 gelangt nichts ins Repo (der Korpus liegt außerhalb, geschrieben wird nur dorthin, wohin der Aufrufer die Variablen lenkt). Der Korpusbau von 2b-2 erzwingt eindeutige Ids und das Präfix `gr-`/`alltag-` und bricht bei jeder anderen Id ab; beides ist in `docs/context/feat-71-guardrail-iphone-lauf.md` unter "Aus dem Prüfdialog von 2b-1" eingetragen.

### Runde 2
**Adversary:** Bestätigt. (a) In 2b-1 gibt es keinen Weg, auf dem Rohdaten ins Repo geschrieben werden, außer über einen Pfad, den der Aufrufer selbst per `LOOSEENDS_GUARDRAIL_OUT` setzt; es gibt keinen Standardpfad, der Kettentest baut den Rohtext nur im Speicher. (b) Doppelte Ids führen zu keinem Absturz (kein Force-Unwrap, kein `fatalError`, kein `Dictionary(uniqueKeysWithValues:)`); Folge ist nur Datenqualität, die N1 beschreibt. Code reference: Measurement/GuardrailReport.swift:146 und Code reference: LooseEndsTests/GuardrailReportTests.swift:355
Code reference: Measurement/GuardrailReport.swift:171
**Implementierer:** Kein Code geändert nach dem Prüferlauf. N1 und N2 sind für 2b-2 vermerkt.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Der Schnitt schreibt keinen Zustand, auf den ein Produktpfad wartet: reine Übersetzung in der Messstrecke, keine Schreibstelle im Produktpfad.

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:c04c6c9c1e7e4ee41f173a8bd27c3376972af5ecb4f837c5e09ebc187ff4aa6b  LooseEndsTests/GuardrailReportTests.swift
- sha256:abb655e10a6c6bea91f14a69e75e4c39d499de498409eaf147f268195fd435a7  LooseEndsTests/RealModelGuardrailTests.swift
- sha256:8c3a7c16246a6302164bf8d6e36a75eeb6b1da38633c4a5da0ebc2835db3aafb  Measurement/GuardrailReport.swift

## Prüfbasis

- base: 793fcf6da25bb6b29e62adba4d9b2935ef1114a2
- blob:8d97fd8b285bf5bd6f0d95d6fb3e2213abb7552e  LooseEndsTests/GuardrailReportTests.swift
- blob:7148277fc0d18d1523736e4120b8f904abfb3d93  LooseEndsTests/RealModelGuardrailTests.swift
- blob:4e6248d6c0cef0e66d95c3984318ca5a5bf6a62d  Measurement/GuardrailReport.swift

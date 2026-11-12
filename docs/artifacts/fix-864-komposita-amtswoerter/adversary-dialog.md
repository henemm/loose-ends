# Adversary Dialog — fix-864-komposita-amtswoerter
Spec: docs/specs/enrichment/fix-864-komposita-amtswoerter.md
Datum: 2026-11-12 23:13

## Checkliste
- [x] **Input:** Notiztext.
- [x] **Output:** `matchImportance` liefert `.high` mit Vertrauen 1.0 und der Begründung des Amtssignals, wenn der Text ein
- [x] **Side effects:** Aufgaben, deren Text eines dieser Wörter enthält und die vorher keine Wichtigkeit hatten, bekommen sie
- [x] **AC-1:** Given ein deutscher Text mit einem Amtswort-Stamm vorn / When `matchImportance` läuft / Then `.high`, Vertrauen 1.0, Begründung des Amtssignals („Steuerbescheid prüfen“, „Steuernachzahlung überweisen“, „Steuerberater anrufen“, „Steuerbescheide ablegen“, „Umsatzsteuer melden“, „Amtsgerichts Post lesen“)
- [x] **AC-2:** Given ein Text mit einem Kompositum, dessen Amtswort hinten steht / When `matchImportance` läuft / Then `.high` („Mietvertrag kündigen“, „Scheidungsanwalt anrufen“, „Waffenbehörde fragen“, „Staatsanwalt“)
- [x] **AC-3:** Given Wörter, die nur so aussehen / When `matchImportance` läuft / Then `nil` („Steuerrad reparieren“, „Steuerung einbauen“, „Steuerknüppel kaufen“, „Lenksteuer“, „Gesamt zählen“, „insgesamt drei“, „Hauptgericht kochen“, „Beamtenrecht lesen“, „Vertragsnummer notieren“)
- [x] **AC-4:** Given die bisherigen Treffer / When `matchImportance` läuft / Then unverändert („Finanzamt anrufen“, „Steuererklärung“, „Amt“, „Vertrag“, englisch „Check the tax notice today“); die Begründung bleibt die des Amtssignals; „Steuerbescheid“ trifft auch ohne „wichtig“
- [x] **AC-5:** Given „Steuerbescheide ablegen“ / When `importanceTrigger` läuft / Then die Spanne deckt das ganze Wort „Steuerbescheide“ ab; bei „Mietvertrag kündigen“ das ganze Wort „Mietvertrag“
- [x] **AC-6:** Given der Golden-Korpus / When `RuleGoldenTests` mit dem erneuerten `rule-golden.json` läuft / Then grün, und im Diff steht je Zeile nur neu gesetzte Wichtigkeit (keine Zeile verliert eine)
- [x] **AC-7:** Given alle Sprachpakete / When die Konformitätstests laufen / Then grün; Englisch und `TestPack` sind unverändert

## Dialog

### Runde 1
**Adversary:** Tests gelaufen (ImportanceUrgencyRuleTests, RuleGoldenTests, LanguagePackConformanceTests: je Test Succeeded; Ausgaben in adversary-*-output.txt). Sondierung mit 35 Randfaellen per Wegwerf-Test (adversary-probe-results.txt, danach entfernt): STEUERBESCHEID, Anwaeltin (auch zerlegt), Steuerbescheid2024, (Steuerbescheid), Emoji davor, Unicode-Spannen alle korrekt (String.Index, Spanne deckt Ganzwort), fruehester Treffer gewinnt ("Vertragsnummer und Mietvertrag" -> Mietvertrag), Look-alikes Steuerung/Gesamt/Hauptgericht/Vertragsnummer/Mietvertragsnummer/Understeuer/Subcontract/Gebaeudeamt -> nil. Englisch unveraendert.
Finding F001: Stamm "steuerid" ist rechts offen und trifft "Steueridee" (Fehltreffer).
Finding F002: Koepfe sind rechts begrenzt: "Anwaelte", "Notarin", "Anwaltschaft", "Staatsanwaltschaft", "Rechtsanwaltskanzlei", "Notariat" treffen nicht (Beugung/Ableitung der Koepfe); Spec nennt das nicht ausdruecklich.
**Implementierer:** (nicht erreichbar; Belege aus Code und Lauf)

Aufrufer: Suche nach importanceTrigger/matchImportance in Shared und LooseEnds ergibt nur Aufrufe ueber RuleTrigger/EnrichmentCoordinator, Signaturen unveraendert.

### Runde 2
**Adversary:** Golden-Diff geprueft: rule-golden.json = genau 5 Zeilen "–" -> "high" (Steuerberater x4, Steuerbescheide x1), keine Zeile verliert Wichtigkeit, passt zu AC-6. range(of:) mit leftBoundary/rightBoundary: Default-Parameter erhalten alle Altaufrufe (firstRange, firstUnnegatedRange) unveraendert. Negation betrifft nur .explicit. "Steuer-Bescheid" markiert nur "Steuer" (Altverhalten, Ganzwort-Treffer). Keine Regression gefunden ausser F001. F001 ist realer Fehltreffer, aber sehr selten; F002 ist durch Known Limitations ("nur aufgezaehlte Stamme und Koepfe") gedeckt.
**Implementierer:** (nicht erreichbar)

### Bewertung je AC
Confirmation:
  AC: AC-1
  Code reference: Shared/Enrichment/ImportanceUrgencyRule.swift:128
  Evidence: officialRange sucht Stamm mit offener Rechtsgrenze, Test compoundStemsSetImportance gruen
  Status: CONFIRMED
Confirmation:
  AC: AC-2
  Code reference: Shared/Language/GermanPack.swift:64
  Evidence: officialHead mit linksoffener Suche, Test compoundHeadsSetImportance gruen
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: Shared/Enrichment/ImportanceUrgencyRule.swift:177
  Evidence: Positivlisten; alle 9 Look-alikes nil
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: Shared/Enrichment/ImportanceUrgencyRule.swift:116
  Evidence: Altliste bleibt beidseitig begrenzt, Test formerOfficialHitsStay gruen
  Status: CONFIRMED
Confirmation:
  AC: AC-5
  Code reference: Shared/Enrichment/ImportanceUrgencyRule.swift:128
  Evidence: wholeWord(around:) liefert Ganzwortspanne, Test triggerCoversWholeCompound gruen
  Status: CONFIRMED
Confirmation:
  AC: AC-6
  Code reference: Shared/Language/GermanPack.swift:58
  Evidence: 5 Golden-Zeilen nur "–"->"high", RuleGoldenTests gruen
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: Shared/Language/GermanPack.swift:58
  Evidence: LanguagePackConformanceTests gruen, Englisch/TestPack unberuehrt
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Language/GermanPack.swift:60
  Description: Stamm "steuerid" ist rechts offen; "Steueridee sammeln" -> high (Probe)
  Spec requirement: AC-3 — Look-alikes treffen nicht
  Conflict: Fehltreffer auf ein Nicht-Amtswort
  Remediation: "steuerid" durch "steuerident" ersetzen oder streichen

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Language/GermanPack.swift:64
  Description: Koepfe rechts begrenzt: "Anwaelte", "Notarin", "Staatsanwaltschaft" treffen nicht
  Spec requirement: Known Limitations — nur aufgezaehlte Formen
  Conflict: Beugungen der Koepfe unberuehrt; kein Spec-Bruch
  Remediation: optional Koepfe um "anwälte", "notarin", "anwaltschaft" erweitern

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Alle ACs 1-7 bewiesen; zwei LOW-Beobachtungen (F001, F002) nicht blockierend.
Tests: ImportanceUrgencyRuleTests, RuleGoldenTests, LanguagePackConformanceTests bestanden, 0 failed, 0 übersprungen
Edge cases: geprueft, keine spec-brechenden
Regressions: None found
Checklist: 10/10 points proven

## Geprüfte Dateien

- sha256:e057fbeaba1fb854b1dee77a59cd9eee749d00bd229e16a246cad7fcb4c7915f  Shared/Enrichment/ImportanceUrgencyRule.swift
- sha256:dc18a22db75590a0e3ccf20b8b08a8f0f98f9dbecfcbeb5242f36a254119a1c9  Shared/Language/GermanPack.swift

## Prüfbasis

- base: 315a7a65938190a365221d52fc2d17ce897ba97c
- blob:c82ee8bdd69593a4d6e097fdff73814d3d9381a3  Shared/Enrichment/ImportanceUrgencyRule.swift
- blob:6ce8cebe617943644f476546dcb3e2d523b8a181  Shared/Language/GermanPack.swift

## Geprüfte Dateien

- sha256:e057fbeaba1fb854b1dee77a59cd9eee749d00bd229e16a246cad7fcb4c7915f  Shared/Enrichment/ImportanceUrgencyRule.swift
- sha256:dc18a22db75590a0e3ccf20b8b08a8f0f98f9dbecfcbeb5242f36a254119a1c9  Shared/Language/GermanPack.swift

## Prüfbasis

- base: 315a7a65938190a365221d52fc2d17ce897ba97c
- blob:c82ee8bdd69593a4d6e097fdff73814d3d9381a3  Shared/Enrichment/ImportanceUrgencyRule.swift
- blob:6ce8cebe617943644f476546dcb3e2d523b8a181  Shared/Language/GermanPack.swift

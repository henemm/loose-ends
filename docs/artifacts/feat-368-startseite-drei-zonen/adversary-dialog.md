# Adversary Dialog — feat-368-startseite-drei-zonen
Spec: docs/specs/feat-368-schnitt-1-regel-jetzt.md
Datum: 2026-10-12 19:15

## Checkliste
- [x] **AC-1:** now(...).all enthält genau die Vereinigung aus dueToday und tasks(for: .next), jede Aufgabe einmal; blockierte, Unter-, erledigte und geparkte Aufgaben fehlen. Beleg: Code reference: Shared/Models/ViewRules.swift:94 (Vereinigung, Dedupe per seen-Set); Tests NowRuleTests.swift:164 und :119 grün.
- [x] **AC-2:** Reihenfolge überfällig (älteste zuerst), heute fällig (früheste Uhrzeit zuerst), übrige vorgemerkte nach nextRank; vorgemerkt und fällig steht in der Zeitdruck-Gruppe. Beleg: Code reference: Shared/Models/ViewRules.swift:98 (Gruppen), :102-115 (Sortierung); Tests NowRuleTests.swift:36, :52, :85, :108 grün.
- [x] **AC-3:** dueToday, badgeCount, tasks(for:) unverändert. Beleg: Diff von ViewRules.swift enthält nur Hinzufügungen (0 entfernte Zeilen); dueToday (Zeile 66), badgeCount (75), tasks(for:) (118) unberührt; NowRuleTests.swift:181 grün; voller Lauf 0 Fehler.
- [x] **AC-4:** PR #340 CLOSED, mergedAt null (PR-Abfrage); pr-body.md enthält Closes #339; Regel steht im Abschnitt Jetzt von docs/project/02-datenmodell-und-ansichten.md.

## Dialog

### Runde 1
**Adversary:** Behauptung: all ist nicht exakt die Vereinigung; Duplikate, Unteraufgaben, blockierte, erledigte, geparkte rutschen durch. Angriffe: vorgemerkt UND heute fällig (Dublette?), vorgemerkt UND überfällig, vorgemerkt mit Fälligkeit morgen (darf nicht in Zeitdruck), Unteraufgabe mit vorgemerktem Elternteil, Fälligkeit morgen ohne Rang (darf fehlen).
**Implementierer:** Code reference: Shared/Models/ViewRules.swift:94-95 filtert die Summe beider Quellen per seen.insert(id); Unteraufgaben und Blockierte fallen schon in den Quellen heraus (ViewRules.swift:69 und :122: parent == nil, !isBlocked, isOpen). Unteraufgabe mit vorgemerktem Elternteil: der Elternteil ist Kandidat, die Unteraufgabe nie, korrekt. Tests: Code reference: LooseEndsTests/NowRuleTests.swift:52 (lineEachTaskOnce), :64 (überfällig+vorgemerkt), :119 (blockiert/Unter/erledigt/geparkt), :139 (morgen ohne Rang), :148 (morgen mit Rang -> lined), :164 (Mengengleichheit + badgeCount). Alle 13 grün im vollen Simulatorlauf.

### Runde 2
**Adversary:** Behauptung: Reihenfolge und Tagesgrenze sind falsch. Angriffe: 23:59/00:00-Grenze, Zeitzone, gleiche Fälligkeit, nextRank nil, Stabilität, AC-3-Regression.
**Implementierer:** Code reference: Shared/Models/ViewRules.swift:96-99 verwendet dieselbe Tagesgrenze (startOfDay, +1 Tag per Calendar) wie dueToday (:67-68); weil dueToday alles < end liefert, ist jede Aufgabe daraus entweder < today oder in [today,end), keine Lücke, in der eine fällige Aufgabe in lined landet. Eine Aufgabe >= end kann nur aus .next kommen und gehört korrekt in lined (Test :148). Gleiche Fälligkeit: ViewRules.swift:107-115 Tie-Break nextRank (nil zuletzt), dann capturedAt. Zeitzone: Calendar wird durchgereicht (NowRuleTests nutzt Europe/Berlin). Befund (nicht blockierend): keine Tests für die exakte 23:59/00:00-Grenze und den Tie-Break (F001, LOW). AC-3: Code reference: LooseEndsTests/NowRuleTests.swift:181. Voller Lauf: 560 bestanden (Haken-Zeilen), 0 fehlgeschlagen, Test Succeeded; NowRuleTests 13/13. Eine Messstrecke (SelfConsistencyReportTests, Datei fehlt) übersprungen, nicht dieser Schnitt.

### Findings
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsTests/NowRuleTests.swift:85
  Description: Tests decken Sortierung nach Uhrzeit, aber weder Tagesgrenze 23:59/00:00 noch den Tie-Break bei gleicher Fälligkeit (ViewRules.swift:107-115).
  Spec requirement: AC-2 — Reihenfolge
  Conflict: Kein Verstoß; nur Testlücke, Logik durch Lesen korrekt.
  Remediation: Optional zwei Tests ergänzen.


Confirmation:
  ID: C001
  AC: AC-1
  Status: CONFIRMED
  Code reference: Shared/Models/ViewRules.swift:94
  Description: AC-1 - Vereinigung aus dueToday und tasks(for: .next), Dubletten per seen-Set entfernt; Unter-, blockierte, erledigte, geparkte Aufgaben fallen in den Quellen heraus.

Confirmation:
  ID: C002
  AC: AC-2
  Status: CONFIRMED
  Code reference: Shared/Models/ViewRules.swift:98
  Description: AC-2 - Gruppen überfällig, heute, vorgemerkt (Zeitdruck gewinnt), Sortierung in byDueThenRank und byRank (Zeilen 107-115).

Confirmation:
  ID: C003
  AC: AC-3
  Status: CONFIRMED
  Code reference: Shared/Models/ViewRules.swift:66
  Description: AC-3 - dueToday (66), badgeCount (75), tasks(for:) (118) im Diff unverändert, nur Hinzufügungen.

Confirmation:
  ID: C004
  AC: AC-4
  Status: CONFIRMED
  Code reference: LooseEndsTests/NowRuleTests.swift:181
  Description: AC-4 - PR #340 CLOSED und nicht gemergt, pr-body.md mit Closes #339, Regel in docs/project/02-datenmodell-und-ansichten.md; Regressionstest für Abzeichen und Heute fällig grün.

## Herkunft der Vorbedingungen
kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: VERIFIED
Tests: 560 bestanden, 0 fehlgeschlagen; NowRuleTests 13/13; 1 Messstrecke übersprungen (nicht dieser Schnitt).

## Geprüfte Dateien

- sha256:f6f06d3f74ccbb9d44d85b6b9e27e570361887b13a153498d1de9f75b273ffc6  LooseEndsTests/NowRuleTests.swift
- sha256:edaa04debc69028befe5674e3342b1296b84855eded2616a78bdc9e8f2bca382  Shared/Models/ViewRules.swift

## Prüfbasis

- base: 3b061d1c7d89189b56dd435fc586ab1734992d4a
- blob:a2735f8f953b248abfba55922d00def807a50289  LooseEndsTests/NowRuleTests.swift
- blob:b5a1994c561700068653a7a0c98ef88c873c4480  Shared/Models/ViewRules.swift

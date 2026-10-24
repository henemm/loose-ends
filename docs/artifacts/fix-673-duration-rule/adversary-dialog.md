# Adversary Dialog — fix-673-duration-rule
Spec: docs/specs/fix-673-dauer-regel-anschliessen.md
Datum: 2026-10-24 20:00

## Checkliste
- [x] **AC-1:** Ein Erfassungstext mit genannter Länge setzt beim ersten Regellauf die Dauer des Eimers, den `DurationRule.match(in:)` liefert („Steuerbescheid prüfen 20 Minuten“ → „30 min“). Das Feld steht danach mit Herkunft `rule` und Konfidenz 1.0; es gibt genau eine `Revision` des Feldes `duration` mit Autor `rule` und der Begründung der Regel.
- [x] **AC-2:** Ein Wert, den der Nutzer gesetzt oder geleert hat (`userHasTouched`), wird im ersten Lauf nicht überschrieben; es entsteht keine Revision. Trifft die Regel dann trotzdem, zählt das Feld als „von der Regel getroffen“ und bleibt vom Modell unberührt.
- [x] **AC-3:** „Neu analysieren“ ersetzt einen Regelwert oder Modellwert durch den Regeltreffer, einen Nutzerwert nie (`EnrichmentWriter.mayWrite`, wie bei Wichtig und Dringend).
- [x] **AC-4:** Reihenfolge wie bei den Kontexten (#232): Hat die Erkennung (früherer gleicher Rohtext, Nutzerwert, #136) die Dauer schon getroffen, läuft `DurationRule` nicht. Die Erkennung schlägt die Wortregel.
- [x] **AC-5:** Ein Regeltreffer hält das Modell von der Dauer fern (`matched` enthält `.duration`, #34): das Modell überschreibt den Regelwert weder im ersten Lauf noch bei „Neu analysieren“. Ohne Regeltreffer bleibt das Verhalten des Modells unverändert.
- [x] **AC-6:** Unteraufgaben bekommen die Dauer-Regel nicht (#565: nur Fälligkeit und Etikett-Wort).
- [x] **AC-7:** Bestand ohne Nachlauf: Aufgaben, bei denen der Regelschritt schon lief (`rulesAppliedAt` gesetzt), bekommen die Dauer nur über „Neu analysieren“.
- [x] **AC-8:** Kein Treffer (kein genannter Wert, oder „in 2 Stunden“ als Zeitpunkt) lässt das Feld leer und erzeugt keine Revision.
- [x] **AC-9:** Simulator-Durchlauf als Nutzer: Erfassen „Steuerbescheid prüfen 20 Minuten“, Detail öffnen — die Zeile `field_duration` zeigt „30 min“ mit dem Uhr-Zeichen `fieldGlyph_duration` (#344). Vor dem Fix fehlte das Zeichen (Beleg: `simulator-run.txt`).

## Dialog

### Runde 1
**Adversary:** Frage 1 (Wächter): Gibt es einen Weg, auf dem eine frische Aufgabe `rulesAppliedAt != nil` trägt, bevor `applyRules` läuft (Capture, Sync, Watch, Share)? Dann griffe AC-1 im echten Pfad nicht. Frage 2: Gibt der Wächter `if mode == .firstRun, task.rulesAppliedAt != nil { return false }` fälschlich `false` zurück, wo ein Treffer das Modell fernhalten müsste (AC-5, #34)? Frage 3: Entsteht im Nachhol-Durchgang (`processPending` bei nicht verfügbarem Modell, `processedAt` bleibt leer) eine doppelte Revision? Frage 4: Gibt die Erkennung einen Regelwert weiter (#244)? Frage 5: Treffen die Tests den Koordinator-Pfad, oder bauen sie sich ihren Ausgangszustand selbst (AC-2, AC-7)? Frage 6: Greift die Regel bei Unteraufgaben?
**Implementierer:** Beleg 1: `rulesAppliedAt` wird nur im Koordinator gesetzt, nach `applyRules`: in `processPending` (EnrichmentCoordinator.swift:93), in `reanalyze` (:173) und für Unteraufgaben (:149, :260); deklariert in `Shared/Models/TaskItem.swift:23`, Standard nil. Capture, Watch und Share legen die Aufgabe mit nil an, der erste Lauf greift. Ein von einem anderen Gerät synchronisiertes `rulesAppliedAt` heißt, dass dort der Regelschritt lief — das ist AC-7. Beleg 2: Der Wächter greift nur bei `.firstRun` und gesetztem `rulesAppliedAt`, also beim Bestand von AC-7; dort darf das Modell wie bisher schreiben. Bei frischer Aufgabe liefert die Funktion bei Treffer `true`, auch wenn `mayWrite` verneint (EnrichmentCoordinator.swift:439-443); `matched` enthält `.duration` also auch bei Nutzerwert. Das Modell ist über `task.duration == nil && !userHasTouched` (EnrichmentWriter.swift:81) gesperrt, sobald die Regel schrieb oder der Nutzer das Feld berührte. Beleg 3: Im zweiten Durchgang ist `rulesAppliedAt` gesetzt, der Wächter gibt `false` zurück; zusätzlich verneint `mayWrite(firstRun)` bei `task.duration != nil`. Keine zweite Revision. Beleg 4: `RecognitionRule` nimmt nur Quellen mit `durationSourceRaw == user` (RecognitionRule.swift:96); ein Regelwert wandert nicht weiter (#244). Beleg 5: Alle Tests laufen über `EnrichmentCoordinator.processPending` und `reanalyze` mit `TestStore` und `StubEnricher`, nicht über `DurationRule` allein. Beleg 6: `applySubtaskRules` (EnrichmentCoordinator.swift:274-281) ruft nur `applyDueDateRule` und `applyContextWordRule`. Eigenlauf des Adversary: `./scripts/sim.sh sim-unit DurationRuleCoordinatorTests` 9 von 9 bestanden.
**Bewertung Adversary:** AC-1 AKZEPTIERT (`firstRunSetsDuration` prüft Wert, Herkunft, Konfidenz, genau eine Revision mit Autor `rule`). AC-6 AKZEPTIERT (Code-Pfad und `subtaskGetsNoDuration`). AC-8 AKZEPTIERT (`noHitLeavesFieldEmpty`). AC-2, AC-3, AC-4, AC-5, AC-7 NACHFRAGE: Runde 2 zu den Rändern.

### Runde 2
**Adversary:** Rand 1: Der Test für AC-7 setzt `rulesAppliedAt` von Hand. Selbstgebauter Ausgangszustand? Rand 2: Der Test für AC-5 im ersten Lauf prüft nur eine frische Aufgabe. Was passiert beim Bestand mit verfügbarem Modell? Rand 3: AC-2 „bleibt vom Modell unberührt“ ist nur ohne Modell getestet. Rand 4: Die Erkennung meldet `.duration` auch, wenn sie wegen Nutzerberührung nichts schreibt. Läuft dann `DurationRule` fälschlich? Rand 5: Ändert die geänderte Erwartung in `differentWordBlocksAdoption` die Aussage des Tests? Rand 6: Zeigt der UI-Beleg den Pfad des Nutzers?
**Implementierer:** Antwort 1: Der Zustand (`rulesAppliedAt` gesetzt, `processedAt` leer) ist genau der des echten Bestands und entsteht nur durch den Koordinator. Der Test prüft beide Schritte: `processPending` lässt `duration == nil`, `reanalyze` setzt `.minutes30` (DurationRuleCoordinatorTests.swift:149-163). Antwort 2: Beim Bestand mit Modell darf das Modell im ersten Lauf die Dauer setzen — Verhalten wie vor der Änderung. Bei Neu analysieren sperrt `ruleFields` (EnrichmentWriter.swift:35) das Modell; getestet in `modelStaysAwayFromRuleHit` (:104-120) mit 0.99er Konfidenz und anderem Eimer. Antwort 3: Berührt der Nutzer das Feld, gibt `userHasTouched` es dem Modell nicht frei (EnrichmentWriter.swift:81, 110). Ein eigener Test „Nutzerwert plus verfügbares Modell“ fehlt: Lücke im Test, kein Fehler im Code. Antwort 4: `applyRecognitionRule` fügt `.duration` in `matched` ein, sobald `match.duration != nil`, unabhängig vom Schreiben (EnrichmentCoordinator.swift:525); der Aufruf `if !matched.contains(.duration), applyDurationRule(...)` (:231) lässt die Wortregel dann aus. `recognitionBeatsTheRule` bestätigt: `.hour1` vom früheren Nutzerwert, genau eine Revision. Antwort 5: `differentWordBlocksAdoption` prüft weiter, dass „30 Minuten Sport“ nichts von „60 Minuten Sport“ übernimmt; neu ist nur, dass die Regel `.minutes30` aus dem eigenen Text liest. Antwort 6: Screenshot `docs/artifacts/fix-673-duration-rule/simulator-run/9812350B-C83C-40AA-97CA-079191E34CF5.png` zeigt Zeile „Duration“ mit „30 min“, Uhr-Zeichen und Zeichen „aus deinen Worten“; Aufgabe unter „Not sorted yet“, also reiner Regelpfad. `FieldsSmokeTests` 5 von 5 bestanden (FieldsSmokeTests.swift:162-166).
**Bewertung Adversary:** AC-1 bis AC-9 AKZEPTIERT. AC-2: Code-Pfad doppelt gesichert, Test ohne Modell; Hinweis auf fehlenden Modell-Test, nicht blockierend. Keine offenen Findings.

Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:436
Code reference: LooseEndsTests/DurationRuleCoordinatorTests.swift:18
Code reference: LooseEndsTests/EnrichmentTests.swift:587
Code reference: LooseEndsUITests/FieldsSmokeTests.swift:162

Hinweise (keine Findings, nicht blockierend):
- Kein Test deckt „Nutzerwert plus verfügbares Modell im ersten Lauf“ ab (AC-2, zweiter Satz). Der Schutz kommt aus `userHasTouched` in `EnrichmentWriter` (EnrichmentWriter.swift:81).
- Der Test zu AC-4 prüft die Erkennung mit Nutzerwert als Quelle, nicht den Fall „Erkennung trifft, Nutzer hat das Feld auf dem Ziel berührt“.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

Tests: 9 von 9 Koordinatortests im Eigenlauf bestanden; voller Lauf 1020 Tests, 0 fehlgeschlagen, 7 übersprungen (Messstrecken ohne Messdaten); UI-Smoke 5 von 5 bestanden.
Edge cases: Wächter, Nachhol-Durchgang, Erkennung, Unteraufgabe, Zeitpunkt statt Länge geprüft, keine gebrochen.
Regressions: keine.
Checklist: 9/9 Punkte bewiesen.

## Geprüfte Dateien

- sha256:6f070636f37a838ec376fae189e3d604ec2905e8a42d8be7dc16d3358b2942b2  LooseEndsTests/DurationRuleCoordinatorTests.swift
- sha256:547d8fea38a5279fae108e09e4fb1814a2255370326d86010c08e333afc71aef  LooseEndsTests/EnrichmentTests.swift
- sha256:8d7708a57bdd9d731f0311b1122828211377dc256569535528aaa0b0c74da827  LooseEndsUITests/FieldsSmokeTests.swift
- sha256:54af401ce3f0ea58f452a095c29351040974c7d92d43edbd69909c4d4b3f87d9  Shared/Enrichment/EnrichmentCoordinator.swift

## Prüfbasis

- base: 20b8649b675a62e478f7306ad489d2ca81b7c273
- blob:d686dae042aa25c9287b3f21d1cdae92294eaf7a  LooseEndsTests/DurationRuleCoordinatorTests.swift
- blob:87cb63b1860394e3cc4e157d4536afdd752f7bbe  LooseEndsTests/EnrichmentTests.swift
- blob:915d98d1636aeed42c9ca58b4e5d9a507a819e60  LooseEndsUITests/FieldsSmokeTests.swift
- blob:e7790c8d1080dc658e469cdc07ff250acf17f420  Shared/Enrichment/EnrichmentCoordinator.swift

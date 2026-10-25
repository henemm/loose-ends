---
entity_id: feat-68-modell-verfuegbarkeit
type: feature
created: 2026-10-24
updated: 2026-10-24
status: draft
workflow: 68-modell-verfuegbarkeit
---

# Spec: Wann steht das Modell bereit? Matrix und Entscheidung (#68)

## Approval

- [ ] Approved

## GitHub Issue

#68 (Epic #370, Meilenstein M3). Annahme A4 in `docs/project/06-annahmen-und-experimente.md`. #342 Teil 5 (Start ohne Modell) hängt an dieser Entscheidung.
Grundlage: `docs/context/68-modell-verfuegbarkeit.md` (Recherche, Codebefunde, Analyse, Alternativen).
Entschieden von Henning am 2026-10-24 (Auswahl „Ja, nur in der App“): **Das Modell läuft nur in der App; kein Sperrfeld gegen Doppellauf; kein PCC-Fallback.**

## Purpose

Henning hat vier Geräte: iPhone 16 Pro, iPad mit M-Chip, ein älteres iPad ohne Gerätemodell, Apple Watch (dazu den Mac). Zwei davon können nie selbst veredeln. Das Ticket fragt, wann das
On-Device-Modell zur Veredelung bereitsteht, je Gerät, Prozess und Zustand, und wo veredelt wird. Der Code beantwortet den Großteil schon, ohne Messung:

- Nur die App ruft das Modell: `processPending` steht in `ContentView` (Vordergrund, `scenePhase == .active`), `MenuBarCapture` und `SubtasksSection`. Intent, Share-Erweiterung, Widgets und Watch rufen weder Coordinator noch Enricher.
  ADR-4 nennt „im Intent-Prozess“; gebaut ist das nicht. Die ADR wird auf den gebauten Stand berichtigt.
- „Kein Modell“ ist ein Normalzustand: Die Regeln laufen, `rulesAppliedAt` wird gesetzt, `processedAt` bleibt leer, der Nachzügler holt das Modell nach (#95, #144).
- Die „tödliche Variante“ des Tickets (Watch-Aufgabe wartet auf ein iPhone, dessen App nie geöffnet wird) heißt im Code: Die Aufgabe wartet nicht aufs Modell, sondern auf **irgendein Gerät mit geöffneter App**; auch das iPad ohne Modell genügt, weil die Regeln keines brauchen.
  Bis dahin zeigt sie Rohtext und Titel, ohne Datum, Kontext, Dringlichkeit. Das schließt ein Folgeticket (siehe Scope), nicht dieses.

**Regel-Spalte (Nulllinie):** Das Fälligkeitsdatum setzt die Regel (99,3 % exakt, 0 % erfunden; Modell 50 %, 96,5 % erfunden, #92, #95). Wichtigkeit und Dringlichkeit setzt die Stichwortregel (#117), Wiedererkennung von Kontext und Dauer die Regel (#136),
Kontext und Projekt nie das Modell (#215, #469). Dem Modell bleiben die Titelverfeinerung und Dauer/Energie ohne Wiedererkennung.

**Ohne Modell geht es nicht, weil** nur die Titelverfeinerung Sprachverstehen braucht (Beleg: #202; Dauer/Energie ohne Wiedererkennung sind ungemessen auf der Regelseite). Für alles andere gibt es hier keinen Beleg für das Modell; der Ausfall des Modells verliert also nur diese beiden Felder.
Darum ist „Regeln überall, Modell nur dort, wo eines ist“ der Vorschlag, und ein Modell in weiteren Prozessen wäre ein Neubau ohne Beleg.

Dieses Ticket liefert die Matrix (was bewiesen ist, was offen ist), die berichtigte ADR und Tests, die das Verhalten bei jedem Nichtverfügbar-Grund festhalten. Es ändert kein Verhalten.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** ADR-4 (Ergänzung, keine neue Nummer) — „Veredelung genau einmal“ wird berichtigt: Das Modell läuft nur in der App (Vordergrund und Nachzügler), nie in Intent, Share, Widget oder Watch; ein Doppellauf von iPhone und Mac wird nicht gesperrt.

Alternativen (aus der Analyse) und was sie kippen würden:

| Alternative | Wirkung | Kippt |
|---|---|---|
| Modell auch im Intent-/Share-Prozess | Neubau; Rate Limit im Erweiterungsprozess undokumentiert (Forum 789788), Wartezeit blockiert die Erfassung | ADR-9 (Erfassung ohne App-Start bliebe schnell nur ohne Modell) |
| Sperrfeld `enrichingDevice` | Kein Doppellauf, aber Schema, CloudKit-Deploy und Aufräumregel bei toten Geräten | ADR-4 „genau einmal“ würde zur harten Garantie |
| PCC-Fallback für iPad ohne Modell und Watch | Titelverfeinerung auch dort; kostet Offline und Tageslimit, Zweitquelle, Release Notes ungeprüft | ADR-1 (on-device), Datenschutztext in #342 |
| Nur Vordergrund, „wird geprüft“ sichtbar | Ehrlich, fügt aber UI hinzu | Nachzügler-Lauf im Hintergrund |
| Modell für v1 ganz streichen | Spart Rate-Limit-, Guardrail-, Latenz- und Doppellauf-Themen (#71, #534) | ADR-4 komplett, Epic #370 |

Gewählt: Modell nur in der App, kein Sperrfeld. Begründung zum Sperrfeld: Es kostet eine Schema-Änderung mit CloudKit-Deploy in Production, der Schaden eines Doppellaufs ist begrenzt (der Writer schreibt nie Kontext oder Projekt, #215/#469; Nutzerwerte sind geschützt, #244;
ein zweiter Lauf legt höchstens zusätzliche KI-Revisionen an) und wird im Test belegt. Zeigt er sich in den Messläufen, ist das Sperrfeld der Nachfolger.

## Source

| Datei | Änderung | LoC (Schätzung) |
|---|---|---|
| `docs/reference/modell-verfuegbarkeit.md` | CREATE: Matrix Gerät × Prozess × Zustand, Quellen, Regel-Spalte, offene Gerätezellen | +95 |
| `docs/project/00-entscheidungen.md` | MODIFY: ADR-4-Ergänzung (nur in der App, „im Intent-Prozess“ berichtigt, Doppellauf-Entscheidung, Alternativen) | +16 / −2 |
| `docs/project/06-annahmen-und-experimente.md` | MODIFY: A4 „entschieden (Teil Entwurf), Gerätezellen offen“ mit Verweis auf die Matrix | +3 / −1 |
| `LooseEndsTests/ModelUnavailableTests.swift` | CREATE: Coordinator bei jedem Nichtverfügbar-Grund, Nachholen, Doppellauf | +120 |

Vier Dateien, geschätzt +234 / −3 LoC. Produktcode (`FoundationModelsEnricher`, `EnrichmentCoordinator`, alle Views) bleibt unverändert.

### Inhalt der Matrix (`docs/reference/modell-verfuegbarkeit.md`)

Aufbau nach dem Vorbild `docs/reference/modell-latenz.md`: Kopf mit Stand (Datum 2026-10-24, iOS 27.0.1 laut Latenzbericht, Modellversionen 26.0–26.3, 26.4, 27.0 laut Apple) und Verweis auf Ticket und ADR.

- **Zeilen Geräte:** iPhone 16 Pro, iPad mit M-Chip, älteres iPad ohne Gerätemodell, Apple Watch, Mac.
- **Spalten Prozesse:** App vorn, App hinten (Nachzügler beim nächsten Vordergrund), Intent, Share-Erweiterung, Widget, Watch-App.
- **Zustand je Zelle:** `.available` oder `.unavailable` mit Grund (`deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady`, unbekannt).
- **Drei Zellklassen**, jede Zelle trägt genau eine:
  - (a) *aus Code bewiesen*: Prozesse ohne Modellaufruf (Intent, Share, Widget, Watch-App: Beleg `grep processPending`; `FoundationModelsEnricher` ist `#if canImport(FoundationModels) && !os(watchOS)`, die Watch hat kein Modell; Apples Plattformliste für `SystemLanguageModel` nennt watchOS nicht).
  - (b) *im Unit-Test/Simulator bewiesen*: Verhalten des Coordinators bei jedem Grund (`ModelUnavailableTests`, `EnrichmentTests`, `ModelSeamTests`); der Simulator hat unter `--ui-testing` kein Modell (`ModelOffEnricher`).
  - (c) *nur Gerät* = **offen**: tatsächliche `availability` je echtem Gerät, Verhalten bei gesperrtem Gerät, Rate Limit bei Akku und Hintergrund (Forum 789788), Verhalten des Nachzüglers im Hintergrund. Hier steht „offen“, nichts Geratenes.
- **Messfreigabe:** Die Gerätezellen werden erst gemessen, wenn Henning wörtlich „jetzt ist ein Test möglich“ schreibt, gebündelt mit #71, #70 und #88 Teil 2. Der Bericht nennt das und das Datum der Matrix.
- **Regel-Spalte** und die Zeile „Ohne Modell geht es nicht, weil …“ wie im Abschnitt Purpose.
- **Quellen** (mit Links aus dem Kontextdokument): SystemLanguageModel (Apple), Forum 789788 (Rate Limit), Forum 787736 und 793876 (Guardrail-Fehlalarm, gehört zu #71), WWDC26-Leitfaden iOS, Zusammenfassung mer.vin (PCC, Zweitquelle, Release Notes ungeprüft); „Suche ohne Treffer“ für gesperrtes Gerät und Erweiterungen außer Safari.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `TaskEnricher.unavailableReason: String?` (`Shared/Enrichment/EnrichmentDraft.swift:66`) | der Grund ist ein String (`String(describing: reason)` in `FoundationModelsEnricher`); es gibt kein Enum, das der Test setzen könnte. Die Tests setzen die vier Grundnamen als Text in `StubEnricher.unavailableReason` |
| `OnboardingFlow.modelNote(for:)` | liest dieselben Strings; unverändert, durch `OnboardingFlowTests` gedeckt |
| `StubEnricher`, `TestStore` (`LooseEndsTests/EnrichmentTests.swift`) | wiederverwendet, nicht geändert |
| `EnrichmentWriter` (#215, #244, #469) | unverändert; der Doppellauf-Test hält seine Zusagen fest |
| #71, #70, #88 Teil 2 | messen am selben Modell; teilen sich die spätere Gerätefreigabe |
| #342 Teil 5, #619 | Downstream; nutzen die Entscheidung |

### Bestehende Tests (keine Doppelung)

Schon abgedeckt, wird nicht neu verlangt: kein Modellaufruf bei `deviceNotEligible` (`EnrichmentTests.unavailableModelIsSkipped`, `calls == 0`); Regelschritt mit Datum, Wichtigkeit, Wiedererkennung und anschließendes Nachholen mit genau einer Regel-Revision
(`catchUpPassDoesNotDuplicateRuleRevision`, `catchUpPassDoesNotDuplicateImportanceOrUrgencyRevision`, `catchUpPassAddsNoSecondRevision`); `rulesAppliedAt != nil` und `processedAt == nil` ohne Modell, danach Nachholen (`ruleMarkerDoesNotHideATaskFromTheModelPass`);
mehrere Regelläufe ohne zweite Revision (`repeatedRulePassesAddNoSecondRevision`); Neuanalyse ohne Modell (`ReanalysisTests.rulesOnlyWithoutModel`); der Modellwert überschreibt keinen gesetzten Wert (`modelDoesNotOverwriteAnExistingValue`); Gründe-Texte im Onboarding (`OnboardingFlowTests.modelNote`).
Allen gemeinsam: Sie prüfen **einen** Grund (`deviceNotEligible` oder den freien Text „Kein Apple Intelligence“).

**Fehlt und wird hier ergänzt:** (1) dieselbe Zusage für **jeden** der vier Gründe in einem Test; (2) der Doppellauf zweier Geräte, die beide „fällig“ sehen.

## Acceptance Criteria

- **AC-1:** `docs/reference/modell-verfuegbarkeit.md` existiert und enthält die Matrix Gerät (iPhone 16 Pro, iPad mit M-Chip, älteres iPad, Apple Watch, Mac) × Prozess (App vorn, App hinten, Intent, Share, Widget, Watch-App) × Zustand, mit Datum 2026-10-24 und OS-/Modellständen.
  Jede Zelle trägt genau eine der Klassen (a) aus Code bewiesen, (b) in Unit/Simulator bewiesen, (c) nur Gerät = offen.
- **AC-2:** Die Belege der Klasse (a) nennen Datei und Stelle (`processPending` nur in `ContentView`, `MenuBarCapture`, `SubtasksSection`; `FoundationModelsEnricher` nicht für watchOS übersetzt); die Belege der Klasse (b) nennen den Test.
- **AC-3:** Der Bericht enthält die Regel-Spalte (Datum 99,3 % Regel gegen 50 % Modell; Kontext und Projekt nie Modell; Wichtigkeit/Dringlichkeit und Wiedererkennung Regel), die Zeile „Ohne Modell geht es nicht, weil …“ mit der Feststellung, dass nur die Titelverfeinerung Sprachverstehen braucht, und die Quellenliste mit allen Links aus dem Kontextdokument.
- **AC-4:** **Gerätezellen stehen als „offen“, nicht als gemessen**, bis Henning den Test freigibt: Jede Zelle der Klasse (c) steht auf „offen“ ohne Zahl und ohne Vermutung; der Bericht nennt die Bedingung (Hennings wörtliches „jetzt ist ein Test möglich“, gebündelt mit #71, #70, #88 Teil 2).
- **AC-5:** `docs/project/00-entscheidungen.md` ADR-4 enthält die Ergänzung: Das Modell läuft nur in der App (Vordergrund und Nachzügler); „im Intent-Prozess“ ist berichtigt (der Intent-Prozess ruft das Modell nicht); Doppellauf: kein Sperrfeld, Schaden begrenzt, Nachfolger wenn gemessen.
  Die fünf Alternativen der Analyse stehen mit der Entscheidung, die sie kippen würden; Hennings Entscheidung vom 2026-10-24 ist datiert genannt.
- **AC-6:** `docs/project/06-annahmen-und-experimente.md` A4 steht auf „entschieden (Teil Entwurf), Gerätezellen offen“ mit Verweis auf `docs/reference/modell-verfuegbarkeit.md`; die Spalten Experiment, Abbruch und Alternative bleiben erhalten.
- **AC-7:** `LooseEndsTests/ModelUnavailableTests.swift` prüft in einem parametrisierten Test für jeden der Gründe `deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady` und einen unbekannten Text: `StubEnricher.calls == 0`, `rulesAppliedAt != nil`, `processedAt == nil`,
  das Fälligkeitsdatum und die Wichtigkeit stehen aus der Regel, der Status bleibt für den Nachzügler erhalten.
- **AC-8:** Derselbe Test (oder ein zweiter in derselben Datei) lässt nach dem Regellauf das Modell verfügbar werden (`unavailableReason = nil`): Der nächste Lauf ruft das Modell genau einmal, setzt `processedAt`, und die Regel-Felder bleiben ohne zweite Regel-Revision.
- **AC-9:** Doppellauf: Eine Aufgabe, die zwei Geräte beide als „fällig“ sehen (nach dem ersten Modelllauf wird `processedAt` zurückgesetzt, wie es ein Gerät sieht, dem der Abgleich noch fehlt), wird von einem zweiten Modelllauf mit abweichender Antwort nicht beschädigt:
  ein vom Nutzer gesetzter Wert bleibt unverändert und hat genau eine Revision, Kontext und Projekt bleiben leer (nie vom Modell gesetzt), und der zweite Lauf legt keine Nutzer-Revision an. Der Test benennt in seinem Kommentar, was er nicht belegt (zwei echte Geräte, CloudKit-Abgleich).
- **AC-10:** Die Testdatei dupliziert keinen der oben genannten bestehenden Tests; sie nutzt `StubEnricher` und `TestStore` aus `EnrichmentTests.swift` und hält den Container im Test am Leben.
- **AC-11:** **Kein Gerät wird angefasst.** Weder Hennings iPhone, iPad, Watch noch Mac werden für dieses Ticket angesprochen (kein `devicectl`, kein `sim.sh device*`, kein `launch-measure`, kein `lab`, auch nicht lesend). Die Tests laufen nur im Simulator.
- **AC-12:** Keine Änderung an Produktcode, `project.yml`, Entitlements, `Info.plist`, Berechtigungen, AppStorage-Keys, SwiftData-Modell oder `cloudkit/schema.ckdb`; kein CloudKit-Deploy nötig. Das Diff berührt genau die vier Dateien der Source-Tabelle.
- **AC-13:** Abnahme: `./scripts/sim.sh sim-unit ModelUnavailableTests` grün, danach der volle Lauf `./scripts/sim.sh sim-unit`; Es gibt keinen sichtbaren Ablauf zum Durchspielen (Produktcode unverändert). Verlangt das Abschluss-Gate trotzdem den Beleg `simulator-run.txt` (`openspec.yaml`: `evidence_checks.phase8_complete`, Gate-Menge enthält die neue Testdatei), wird er mit `./scripts/sim.sh test-proof ModelUnavailableTests` erzeugt, nie von Hand gesetzt; zeigt `phase8_complete`, dass das Gate die Menge nicht erfasst, entfällt er mit dieser Begründung im Abschlussbericht. Die Gegenprobe aus dem Test Plan wird im Abschlussbericht benannt. Die Stufe 3 entfällt mit dem Satz „Kein Pfad der Geräteliste berührt.“ (weder `FoundationModelsEnricher.swift` noch `EnrichmentCoordinator.swift` werden geändert).

## Scope

**Affected Files:** vier (zwei ADR/Annahmen-Dokumente, ein Referenzbericht, eine Testdatei). Geschätzt +234 / −3 LoC, innerhalb der Limits. Risiko niedrig: Produktcode unverändert.

**Nicht Teil von #68, nur erwähnt:** Folgeticket als **ein gebündeltes GitHub-Issue** (gemeinsames Ziel „Regeln ohne App-Start“): Die Regelschritte (Datum, Wichtigkeit, Dringlichkeit, Kontextwörter) laufen in dem Prozess, der erfasst (Watch, Share, Intent), ohne Modell. Das schließt die tödliche Variante bei diesen drei Wegen.
Es hängt an #619 (Sync Schnitt 4) und #342 Teil 5 und wird beim Abschluss von #68 angelegt, nicht hier umgesetzt.

**Grenzen:** Die Matrix beweist, was der Code und der Simulator hergeben. Das Verhalten echter Geräte (gesperrt, Akku, Hintergrund, Modellversion) bleibt offen; der Rate-Limit-Befund aus dem Forum ist ein Fallbericht, keine eigene Messung.

## Test Plan

- **Charakterisierungstests, nicht RED:** AC-7, AC-8 und AC-9 laufen gegen unveränderten Produktcode und sind sofort grün. Der Code verhält sich schon so; die Tests halten es fest und schließen die Lücke „nur ein Grund geprüft“. Eine künstliche RED-Phase wird nicht erfunden.
  Verlangt ist, dass sie bei einer absichtlichen Gegenprobe rot werden (z. B. wenn der Grund `modelNotReady` den Regelschritt auslassen würde); die Gegenprobe wird im Abschlussbericht benannt, nicht committet.
- **Aufruf:** `./scripts/sim.sh sim-unit ModelUnavailableTests` (Simulator, nie der Mac-Host, nie `unit`), danach `./scripts/sim.sh sim-unit` für alle Unit-Tests. Vorher `./scripts/sim.sh generate`, weil eine neue Testdatei dazukommt.
- **Prüfung der Dokumente:** Matrix gegen die Code-Belege lesen (`grep processPending`, `#if`-Zeile des Enrichers); jede Zelle hat eine Klasse; kein Platzhalter, keine geratene Gerätezahl.
- **Kein UI-Test:** Es ändert sich nichts Sichtbares.
- **Gerät:** nichts. Die Gerätezellen werden erst nach Hennings wörtlichem „jetzt ist ein Test möglich“ und gebündelt mit #71, #70, #88 Teil 2 gemessen und dann als Nachtrag in den Bericht eingetragen.

## Definition of Done

- [ ] AC-1 bis AC-13 erfüllt
- [ ] `sim.sh sim-unit` grün (Klasse und voller Lauf)
- [ ] PR mit `Closes #68`, CI grün, gemergt, Hauptordner aktuell
- [ ] Folgeticket „Regeln ohne App-Start“ als GitHub-Issue angelegt (Board: Priority und Size), mit Verweis auf #619 und #342 Teil 5
- [ ] Gerätezellen als offen im Bericht; Messung gebündelt mit #71, #70, #88 Teil 2 vermerkt

## Changelog

- 2026-10-24: Initial

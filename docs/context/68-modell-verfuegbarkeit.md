# Context: 68-modell-verfuegbarkeit

## Request Summary
#68 (Epic #370, M3): Nachweis, wann das On-Device-Modell zur Veredelung bereitsteht — je Gerät, Prozess
und Zustand. Ergebnis ist eine Matrix in `docs/reference/` und eine Entscheidung, wo veredelt wird (ADR-Ergänzung).
Annahme A4 in `docs/project/06-annahmen-und-experimente.md`. #342 Teil 5 (Start ohne Modell) hängt daran.

## Recherche (zuerst, 2026-10-24)
| Befund | Quelle |
|---|---|
| `SystemLanguageModel.default.availability` kennt `.available` und `.unavailable(reason)`; Gründe `deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady` („lädt oder aus anderen Systemgründen“), dazu unbekannte. Plattformen laut Apple: iOS, iPadOS, macCatalyst, macOS, visionOS ab 26.0. **watchOS steht nicht in der Liste.** | [SystemLanguageModel (Apple)](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel.md) |
| Drei Modellversionen: 26.0–26.3, 26.4, 27.0. Die Modellgeneration wechselt mit dem OS. | dieselbe Seite |
| Bei Akkubetrieb **und** Hintergrundprozess greift ein Rate Limit; Apple-Ingenieur: am Netzteil nicht erwartet (bekannter Fehler 153216632). Empfehlung: `respond` statt Streaming. Der Fragesteller sah es auch am Netzteil und ohne Linderung durch `respond`. Der geworfene Fehler nennt fälschlich eine Guardrail. Rückmeldung FB18332004, keine weitere Antwort von Apple. | [Forum 789788](https://developer.apple.com/forums/thread/789788) |
| Bekannte Fehlalarme der Guardrail bei harmlosem Text; Apple: Beta-Fehler behoben, Rat: Text umformulieren. (Gehört zu #71.) | [Forum 787736](https://developer.apple.com/forums/thread/787736), [793876](https://developer.apple.com/forums/thread/793876) |
| Zum Verhalten bei **gesperrtem Gerät** und zu Erweiterungen außer Safari fand die Suche nichts Belastbares. Das muss das Gerät zeigen. | Suche ohne Treffer |
| iOS 27: Foundation Models kann auch über Private Cloud Compute und fremde Anbieter laufen; Gratisnutzung nur für kleine Entwickler. Für die Watch nur Zweitquelle, Apples Release Notes sind zu prüfen. | [WWDC26 iOS](https://developer.apple.com/wwdc26/guides/ios/) (Treffer der Suche), [Zusammenfassung](https://mer.vin/2026/06/apple-wwdc26-siri-ai-and-gemini-backed-foundation-models-on-device-and-private-cloud-compute/) |

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Enrichment/FoundationModelsEnricher.swift` | `unavailableReason` liest `SystemLanguageModel.default.availability`; Datei ist `#if canImport(FoundationModels) && !os(watchOS)` |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | `processPending` (Z. 58) und Neuanalyse (Z. 159): bei fehlendem Modell nur Regeln, `rulesAppliedAt` gesetzt, `processedAt` bleibt leer; `ModelDeadline` 25 s |
| `LooseEnds/App/LooseEndsApp.swift:34` | einzige Stelle, die den Enricher baut; Unter `--ui-testing` `ModelOffEnricher` |
| `LooseEnds/App/ContentView.swift:123,126,228` | Nachzügler-Lauf bei `scenePhase == .active` |
| `LooseEnds/Mac/MenuBarCapture.swift:18` | Lauf nach Erfassung in der Menüleiste |
| `LooseEnds/Views/OnboardingFlow.swift:50` | `modelNote(for:)`: Grund → „aus / nicht bereit / nicht geeignet“ |
| `docs/reference/modell-latenz.md` | Vorbild für Aufbau und Gerätenachweis (#534); iPhone 16 Pro, iOS 27.0.1 |
| `docs/project/00-entscheidungen.md` | ADR-4 (Veredelung genau einmal, „im Intent-Prozess“), ADR-9 (Erfassung ohne App-Start) |
| `docs/project/06-annahmen-und-experimente.md` | Annahme A4 mit Alternativen |

## Existing Patterns
- Kein Modell ist ein normaler Zustand, kein Fehler: Regeln laufen, Aufgabe bleibt ohne `processedAt`, der Nachzügler holt das Modell später nach (#95, #144).
- Der Gerätenachweis läuft über Messläufe mit Rohdaten in `docs/artifacts/<ticket>/` und Auswertung in `docs/reference/` (#534, #22). Die Labor-App `LE Labor` misst gegen Apple Intelligence, nur auf Hennings Wort.

## Dependencies / Dependents
- Upstream: Apple `FoundationModels`, Spracheinstellung unter „Apple Intelligence & Siri“, Gerät, Akku.
- Downstream: #342 Teil 5, #71 und #70 (messen am selben Modell), Onboarding-Hinweis, ADR-4/9.

## Befund aus dem Code (für die Analyse)
- **Nur die App ruft das Modell auf.** `processPending` steht in ContentView, MenuBarCapture, SubtasksSection. Intent, Share-Erweiterung, Widgets und Watch rufen weder Coordinator noch Enricher. ADR-4 nennt „im Intent-Prozess“, gebaut ist das nicht.
- Damit ist die Matrix des Tickets heute keine Mess-, sondern eine Entwurfsfrage: Prozesszeilen Intent, Share, Widget, Watch haben kein Modell zu prüfen, solange sie nur Rohtext speichern.
- Die tödliche Variante des Tickets („Watch-Aufgabe wartet auf ein iPhone, dessen App nie geöffnet wird“) heißt im Code: Aufgabe bleibt ohne `processedAt`, Regeln greifen erst beim nächsten Öffnen. Prüfen, ob `rulesAppliedAt` ebenfalls erst dann gesetzt wird.
- Doppellauf Mac/iPhone: kein Sperrfeld gefunden (`grep` nach Sperr-/Claim-Feldern in `Shared/Models` steht in der Analyse aus).

## Risks & Considerations
- Gerätteile nur nach Hennings wörtlichem „jetzt ist ein Test möglich“, gebündelt mit #71, #70, #88 Teil 2. Davor kein Zugriff auf iPhone, iPad, Watch.
- Ohne Gerät messbar: Verhalten des Coordinators bei jedem `unavailable`-Grund (Simulator/Unit), Doppellauf-Szenario im Modell, Nachzügler-Reihenfolge.
- Rate Limit ist am Gerät nur in der Labor-App mit Akkubetrieb und Hintergrund provozierbar; eine neue Prozessart (Erweiterung mit Modell) wäre ein Neubau, kein Nachweis.
- Schema/Modelländerungen sind nicht vorgesehen (kein CloudKit-Deploy), außer ein Sperrfeld wird gewählt.

## Analysis

### Type
Feature (Nachweis plus Entwurfsentscheidung; kein Fehler, kein Produktcode im Kern).

### Befunde aus dem Code (2026-10-24, gelesen, nicht vermutet)
| Frage | Befund | Stelle |
|---|---|---|
| Wer ruft das Modell? | Nur die App: `processPending` aus ContentView (Vordergrund, `scenePhase == .active`), MenuBarCapture, SubtasksSection. Intent, Share, Widget, Watch rufen weder Coordinator noch Enricher. | `grep processPending` |
| Was passiert bei Erfassung? | `CaptureService` setzt nur Rohtext und `TitleRule`-Titel. Datum, Wichtigkeit, Dringlichkeit, Kontext, Wiedererkennung entstehen erst in `processPending` (`applyRules`). | `CaptureService.swift:33`, Coordinator Z. 89 |
| Kein Modell | Normalzustand: Regeln laufen, `rulesAppliedAt` wird gesetzt, `processedAt` bleibt leer. Folge: Die Aufgabe bleibt für immer „Modell fällig“; jeder Lauf prüft sie erneut, Regeln laufen erneut (billig, deterministisch). | Coordinator Z. 56–93 |
| Tödliche Variante des Tickets | Real, aber anders als beschrieben: Eine Watch-Aufgabe wartet nicht aufs Modell, sondern auf **irgendein Gerät mit geöffneter App**. Jedes Gerät genügt (auch das iPad ohne Modell, denn die Regeln brauchen keines). Bis dahin zeigt die Aufgabe Rohtext und Titel, ohne Datum, Kontext, Dringlichkeit. | s. o. |
| Doppellauf | Kein Sperrfeld. `processedAt` reist über CloudKit, aber iPhone und Mac können beide vor dem Abgleich „fällig“ sehen. Schaden begrenzt: Der Writer schreibt nie Kontext/Projekt (#215/#469), Nutzerwerte sind geschützt (#244), ein zweiter Lauf legt höchstens zusätzliche KI-Revisionen an. | `EnrichmentWriter`, Coordinator |
| Dauerfehler | Dauerhaft scheiternde Modellaufrufe markieren `processedAt` (#535); Rate-Limit/Guardrail zählt als vorübergehend und wird beim nächsten Lauf neu versucht. | Coordinator Z. 108–114 |

### Was das Modell heute überhaupt noch setzt
Datum: Regel (99,3 %). Wichtigkeit/Dringlichkeit: Stichwortregel. Kontext und Projekt: nie das Modell. Wiedererkennung: Regel. Übrig für das Modell: Titelverfeinerung, Dauer/Energie ohne Wiedererkennung. **Ohne Modell geht es nicht, weil …**: dafür gibt es hier keinen Beleg; im Gegenteil, der Ausfall des Modells verliert nur die Titelverfeinerung. Also gilt der Regelweg als Vorschlag.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `docs/reference/modell-verfuegbarkeit.md` | CREATE | Matrix Gerät × Prozess × Zustand mit Datum und OS-Ständen; Code-Belege für „ruft kein Modell“; Gerätezellen als gemessen/offen gekennzeichnet |
| `docs/project/00-entscheidungen.md` | MODIFY | ADR-4-Ergänzung: Modell läuft nur in der App; „im Intent-Prozess“ gestrichen; Doppellauf-Entscheidung |
| `docs/project/06-annahmen-und-experimente.md` | MODIFY | A4 auf „entschieden“ mit Verweis |
| `Tests/…ModelUnavailableTests.swift` | CREATE | Coordinator bei jedem `unavailable`-Grund (notEligible, notEnabled, notReady, unbekannt): Regeln laufen, `rulesAppliedAt` gesetzt, `processedAt` leer; ein späterer Lauf mit Modell holt nach; Doppellauf-Szenario im Modell (zweiter Lauf überschreibt keinen Nutzerwert) |

### Scope Assessment
- Files: 4 (2 Doku/ADR, 1 Referenz, 1 Testdatei) — Produktcode unverändert
- Estimated LoC: +~230 / −5
- Risk Level: LOW (nur Doku und Tests)

### Technical Approach (eine Empfehlung)
1. **Entscheidung: Das Modell läuft nur in der App** (Vordergrund + Nachzügler), nie in Intent, Share, Widget, Watch. ADR-4 wird auf den gebauten Stand berichtigt. Das ist Hennings Vorgabe „genau ein Gerät veredelt“ in der schwächeren, tragfähigen Form: Jedes Gerät mit App darf, wer kein Modell hat, macht Regeln.
2. **Kein Sperrfeld in v1.** Begründung: Schema-Änderung kostet einen CloudKit-Deploy in Production (nur additiv, einmal Klick), der Schaden eines Doppellaufs ist begrenzt (s. o.) und im Test belegt. Wird er in den Messläufen sichtbar, ist das Sperrfeld der Nachfolger.
3. **Matrix ehrlich in drei Klassen:** (a) *aus Code bewiesen* (Prozesse ohne Modellaufruf), (b) *im Simulator/Unit bewiesen* (alle `unavailable`-Gründe), (c) *nur Gerät* (iPhone 16 Pro / iPad M / älteres iPad: tatsächliche `availability`, gesperrt, Akku-Rate-Limit). Klasse (c) wird nach Hennings Wort gebündelt mit #71, #70, #88 gemessen; bis dahin steht „offen“ in der Matrix, nicht geraten.
4. **Folgeticket (Bündel, gemeinsames Ziel „Regeln ohne App-Start“):** Die Regelschritte (Datum, Wichtigkeit, Dringlichkeit, Kontextwörter) in dem Prozess laufen lassen, der erfasst. Das schließt die tödliche Variante bei Watch/Share/Intent, ohne ein Modell. Nicht Teil von #68; hängt an #619 (Sync Schnitt 4) und #342 Teil 5.

### Alternativen (und welche Entscheidung sie kippen würden)
| Alternative | Wirkung | Kippt |
|---|---|---|
| Modell auch im Intent-/Share-Prozess | Neubau; Rate Limit im Erweiterungsprozess undokumentiert (Forum 789788), Wartezeit blockiert die Erfassung | ADR-9 („Erfassung ohne App-Start“ bliebe schnell nur ohne Modell) |
| Sperrfeld `enrichingDevice` | Kein Doppellauf, aber Schema + Deploy + Aufräumregel bei toten Geräten | ADR-4 „genau einmal“ würde zur harten Garantie |
| PCC-Fallback für iPad ohne Modell/Watch | Titelverfeinerung auch dort; kostet Offline und Tageslimit, Zweitquelle, Release Notes ungeprüft | ADR-1 (on-device); Datenschutztext in #342 |
| Nur Vordergrund, „wird geprüft“ sichtbar | Ehrlich, aber fügt UI hinzu | Nachzügler-Lauf bei Hintergrund |
| Modell ganz streichen für v1 | Ersparnis: Rate-Limit-, Guardrail-, Latenz- und Doppellauf-Themen (#71, #534) | ADR-4 komplett, Epic #370 |

### Dependencies
Upstream: Apple `FoundationModels`; Sprache unter „Apple Intelligence & Siri“. Downstream: #342 Teil 5, #71, #70, #88, ADR-4/9, #619.

### Open Questions
- [x] Entschieden von Henning (2026-10-24, Auswahl „Ja, nur in der App“): Modell nur in der App, kein Sperrfeld, kein PCC-Fallback.
- [ ] Geräteteil: Henning sagt „jetzt ist ein Test möglich“, wenn #71/#70/#88 gebündelt laufen (bis dahin nichts am Gerät).

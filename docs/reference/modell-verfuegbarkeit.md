# Wann steht das Modell bereit? Matrix Gerät × Prozess × Zustand (#68, Annahme A4)

Stand: **2026-10-24**. OS laut Latenzbericht (`docs/reference/modell-latenz.md`): iOS 27.0.1, macOS 27.0.1. Modellversionen laut Apple: 26.0–26.3, 26.4, 27.0
(die Modellgeneration wechselt mit dem OS). Ticket #68 (Epic #370), Entscheidung in ADR-4 (`docs/project/00-entscheidungen.md`), Annahme A4
(`docs/project/06-annahmen-und-experimente.md`). Entschieden von Henning am 2026-10-24: **Das Modell läuft nur in der App; kein Sperrfeld gegen Doppellauf; kein PCC-Fallback.**

## Kurzfassung

- Nur die App ruft das Modell. Intent, Share-Erweiterung, Widget und Watch-App rufen weder Coordinator noch Enricher.
- „Kein Modell“ ist ein Normalzustand: Die Regeln laufen, `rulesAppliedAt` wird gesetzt, `processedAt` bleibt leer, der Nachzügler holt das Modell nach.
- Verloren geht ohne Modell nur die Titelverfeinerung und Dauer/Energie ohne Wiedererkennung.
- Was echte Geräte tun (tatsächliche `availability`, gesperrt, Akku, Hintergrund), ist **offen** und nicht gemessen.

## Klassen der Zellen

| Klasse | Bedeutung |
|---|---|
| (a) | aus Code bewiesen: der Prozess ruft das Modell nicht |
| (b) | im Unit-Test oder Simulator bewiesen |
| (c) | nur Gerät: **offen**, keine Zahl, keine Vermutung |

## Belege der Klasse (a)

- `processPending` steht nur in `LooseEnds/App/ContentView.swift:123,126,228` (Vordergrund, `scenePhase == .active`, und Nachzügler), `LooseEnds/Mac/MenuBarCapture.swift:18` und
  `LooseEnds/Views/SubtasksSection.swift:131`. `LooseEndsShare/`, `LooseEndsWidgets/`, `LooseEndsWatch/`, `Shared/Intents/` enthalten keinen Aufruf (`grep processPending`).
- `Shared/Enrichment/FoundationModelsEnricher.swift:1` beginnt mit `#if canImport(FoundationModels) && !os(watchOS)`: Auf der Watch wird der Enricher nicht übersetzt.
  Apples Plattformliste für `SystemLanguageModel` nennt watchOS nicht.
- Den Enricher baut nur `LooseEnds/App/LooseEndsApp.swift`; unter `--ui-testing` steht dort `ModelOffEnricher` (kein Modell im Simulator).

## Belege der Klasse (b)

- `LooseEndsTests/ModelUnavailableTests.swift`: für jeden Grund `deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady` und einen unbekannten Text: kein Modellaufruf, Regeln laufen
  (`rulesAppliedAt` gesetzt, Datum und Dringlichkeit aus der Regel), `processedAt` bleibt leer; wird das Modell verfügbar, ruft der nächste Lauf es genau einmal, ohne zweite Regel-Revision.
- Doppellauf im selben Test: Ein zweiter Modelllauf mit abweichender Antwort überschreibt keinen Nutzerwert, setzt nie Kontext oder Projekt und legt keine Nutzer-Revision an.
  **Nicht belegt:** zwei echte Geräte und der CloudKit-Abgleich selbst.
- Bestehend: `EnrichmentTests.unavailableModelIsSkipped`, `ruleMarkerDoesNotHideATaskFromTheModelPass`, `ReanalysisTests.rulesOnlyWithoutModel`, `OnboardingFlowTests.modelNote`.

## Matrix

Zustand je Zelle: `.available`, oder `.unavailable` mit Grund. Jede Zelle trägt genau eine Klasse.

| Gerät | App vorn | App hinten (Nachzügler beim nächsten Vordergrund) | Intent | Share | Widget | Watch-App |
|---|---|---|---|---|---|---|
| iPhone 16 Pro | Modell möglich: Zustand **offen** (c) | läuft nicht im Hintergrund; holt beim Vordergrund nach (b) | ruft kein Modell (a) | ruft kein Modell (a) | ruft kein Modell (a) | — |
| iPad mit M-Chip | Zustand **offen** (c) | wie iPhone (b) | ruft kein Modell (a) | ruft kein Modell (a) | ruft kein Modell (a) | — |
| älteres iPad ohne Gerätemodell | Zustand **offen** (c); erwartet `.unavailable(deviceNotEligible)`, nicht gemessen | wie oben (b) | ruft kein Modell (a) | ruft kein Modell (a) | ruft kein Modell (a) | — |
| Apple Watch | — | — | ruft kein Modell (a) | — | ruft kein Modell (a) | Enricher nicht übersetzt (a) |
| Mac | Zustand **offen** (c) | wie iPhone (b) | ruft kein Modell (a) | — | ruft kein Modell (a) | — |

„—“ heißt: Die Kombination gibt es nicht (kein Modell auf der Watch, kein Share auf dem Mac und der Watch, keine Watch-App auf iPhone, iPad und Mac).

Offen (c), ausdrücklich nicht gemessen: tatsächliche `availability` je echtem Gerät; Verhalten bei gesperrtem Gerät; Rate Limit bei Akku und Hintergrund
(Forum 789788 ist ein Fallbericht, keine eigene Messung); Verhalten des Nachzüglers im Hintergrund; Modellversion je Gerät.
„Zuhause am Netz“ oder „Akku“ zeigt hier keine Zahl.

**Messfreigabe:** Die Gerätezellen werden erst gemessen, wenn Henning wörtlich „jetzt ist ein Test möglich“ schreibt, gebündelt mit #71, #70 und #88 Teil 2.
Das Ergebnis kommt als Nachtrag in diese Datei. Bis dahin wird kein Gerät angesprochen.

## Regel-Spalte (Nulllinie)

| Feld | Wer setzt es | Beleg |
|---|---|---|
| Fälligkeitsdatum | Regel (`DueDateRule`): 99,3 % exakt, 0 % erfunden; Modell 50 %, 96,5 % erfunden | #92, #95 |
| Wichtigkeit, Dringlichkeit | Stichwortregel (`ImportanceUrgencyRule`) | #117 |
| Kontext, Dauer wiedererkannter Texte | Regel (`RecognitionRule`) | #136 |
| Kontext und Projekt | nie das Modell | #215, #469 |
| Titel | `TitleRule` beim Erfassen; das Modell darf verfeinern | #202 |
| Dauer/Energie ohne Wiedererkennung | Modell; Regelseite ungemessen | — |

**Ohne Modell geht es nicht, weil** nur die Titelverfeinerung Sprachverstehen braucht (Beleg: #202). Für alles andere gibt es hier keinen Beleg für das Modell.
Fällt das Modell aus, verliert die Aufgabe nur die Titelverfeinerung und Dauer/Energie ohne Wiedererkennung. Darum ist „Regeln überall, Modell nur dort, wo eines ist“ der Vorschlag.

## Die „tödliche Variante“

Eine Watch-Aufgabe wartet nicht aufs Modell, sondern auf **irgendein Gerät mit geöffneter App**; auch das iPad ohne Modell genügt, weil die Regeln keines brauchen.
Bis dahin zeigt sie Rohtext und Titel, ohne Datum, Kontext, Dringlichkeit. Das schließt ein Folgeticket („Regeln ohne App-Start“, hängt an #619 und #342 Teil 5), nicht #68.

## Alternativen

Siehe ADR-4: Modell auch im Intent-/Share-Prozess, Sperrfeld `enrichingDevice`, PCC-Fallback, nur Vordergrund mit sichtbarem „wird geprüft“, Modell für v1 streichen.

## Quellen

- [SystemLanguageModel (Apple)](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel.md): `.available`/`.unavailable(reason)`, Gründe, Plattformen, drei Modellversionen
- [Forum 789788](https://developer.apple.com/forums/thread/789788): Rate Limit bei Akku und Hintergrund (bekannter Fehler 153216632, FB18332004)
- [Forum 787736](https://developer.apple.com/forums/thread/787736) und [793876](https://developer.apple.com/forums/thread/793876): Guardrail-Fehlalarme (gehört zu #71)
- [WWDC26 Leitfaden iOS](https://developer.apple.com/wwdc26/guides/ios/): Foundation Models auch über Private Cloud Compute
- [Zusammenfassung mer.vin](https://mer.vin/2026/06/apple-wwdc26-siri-ai-and-gemini-backed-foundation-models-on-device-and-private-cloud-compute/): PCC und Fremdanbieter; Zweitquelle, Apples Release Notes ungeprüft
- Suche ohne Treffer: Verhalten bei gesperrtem Gerät und in Erweiterungen außer Safari

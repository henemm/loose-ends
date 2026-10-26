---
entity_id: feat-342-texte-fuer-fremde
type: feature
created: 2026-10-26
updated: 2026-10-26
status: draft
workflow: feat-342-texte-fuer-fremde
---

# Spec: Texte für Fremde — Berechtigungstexte, Sprachen, Hinweis ohne Modell (#342, Teile 2, 4, 5)

## Approval

- [ ] Approved

## GitHub Issue

#342 „Einladung externer Tester: was noch fehlt“ (Epic #371). Dieser Workflow trägt **Teile 2, 4 und 5**. Die Apple-Seite (Teile 1 und 3) ist #705 und nicht Teil davon.
Kontext und Analyse: `docs/context/feat-342-texte-fuer-fremde.md`.

## Purpose

Eine Person außer Henning bekommt eine App, deren Texte sie versteht und die zu dem passen, was die App tut. Drei belegte Lücken:

1. **Teil 4 — Deutsch/Englisch.** Die vier String-Kataloge sind vollständig (0 fehlende deutsche Einträge). Die Lücke sind die Berechtigungstexte: `de.lproj/InfoPlist.strings` übersetzt nur Standort und Kamera. Mikrofon, Spracherkennung und Kalender erscheinen auf einem deutschen iPhone, Mac und auf der deutschen Watch auf Englisch. Kein Test hält das fest.
2. **Teil 5 — Hinweis ohne Modell.** Der Text für „Gerät ohne Apple Intelligence“ (`notEligible`) sagt nur „fällig, wichtig, dringend werden erkannt“. Er verschweigt, was seit #232/#441/#673/#136 ohne Modell per Regel läuft (Tags aus Wörtern, Dauer aus „20 Minuten“, Wiedererkennung), und was wirklich fehlt (die verfeinerte Titelformulierung). Ein Fremder ohne Modell erfährt das nicht.
3. **Teil 2 — Datenschutz.** Es gibt keinen Datenschutztext im Repo. Er wird als **Entwurf** aus dem geschrieben, was der Code beweist; Henning gibt ihn frei, die URL für Apple ist #705. Die Zeile „Kontakte“ des Tickets entfällt mit Beleg: kein `Contacts`-Import in `LooseEnds/`, `Shared/`, `LooseEndsShare/`.

**Ohne Modell:** Dieses Ticket führt kein Modell ein und berührt keines. Reine Texte, ein Dateivergleich und eine Anzeige. „Without the model this fails because …“ entfällt: kein Feld wird vorgeschlagen, das ein Modell setzt.

## Source

- **File:** `LooseEnds/Resources/de.lproj/InfoPlist.strings`, `LooseEnds/Views/OnboardingView.swift`, `LooseEnds/Resources/Localizable.xcstrings`
- **Identifier:** `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSCalendarsFullAccessUsageDescription`; `OnboardingView.modelNote(_:)`, Fall `.notEligible`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `project.yml` Z. 98–102 (App), 158–159 (Watch) | Quelle der englischen Texte | bleibt **unverändert**; `Info.plist` ist nur Abbild (#499) |
| `project.yml` Z. 131–136 | bündelt `LooseEnds/Resources/*.lproj/InfoPlist.strings` auch in `LooseEndsWatch` (#355) | dieselben drei Schlüssel übersetzen App **und** Watch |
| `scripts/test_info_plist_sync.py` | Vorbild | Aufbau des neuen Tests; CI führt alle `scripts/test_*.py` per `unittest discover` aus (`ci.yml` Z. 33) |
| `OnboardingFlow.modelNote(for:)` | bestehende Abbildung Grund → Fall | bleibt; kein neuer Fall |
| `docs/reference/modell-verfuegbarkeit.md` | Quelle der Aussage, was ohne Modell läuft/fehlt | Belegtext für den Hinweis |
| `LooseEndsUITests/OnboardingTests.swift` | Vorbild/Ort | `--ui-testing-onboarding`; Test auf `onboardingModelNote` |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Resources/de.lproj/InfoPlist.strings` | MODIFY | drei deutsche Berechtigungstexte (Mikrofon, Spracherkennung, Kalender), sinngetreu zum englischen Wortlaut |
| `scripts/test_infoplist_languages.py` | CREATE | jeder `NS*UsageDescription` aus `project.yml` (alle Ziele) hat einen deutschen Eintrag; jeder lokalisierbare Eintrag der vier `*.xcstrings` hat `de`; sonst rot |
| `LooseEnds/Views/OnboardingView.swift` | MODIFY | Text im Fall `.notEligible` (eine Zeile) |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | alter Schlüssel „This device has no Apple Intelligence. Tasks keep …“ ersetzt durch den neuen, deutsch und englisch |
| `LooseEnds/App/ContentView.swift` | MODIFY | eine Zeile (Z. 191): unter `--ui-testing` (`ModelContainerFactory.isUITesting`) übergibt der Start dem Onboarding denselben Grund wie `ModelOffEnricher` („Apple Intelligence is off under UI testing.“, fällt auf `.notEligible`) statt `FoundationModelsEnricher().unavailableReason`. Befund aus TDD RED: Der Simulator liefert das echte Systemmodell, der Hinweis erschien dort nicht; die Annahme „Simulator hat kein Modell“ war falsch, weil ContentView den UI-Test-Schalter (#228) übergeht. Ohne die Zeile ist der Hinweis nicht prüfbar. |
| `LooseEndsUITests/OnboardingTests.swift` | MODIFY | neue Tests (Englisch, Deutsch): Hinweis erscheint im Siri-Schritt und nennt Tags und Dauer |
| `docs/reference/datenschutz-entwurf.md` | CREATE | Datenschutztext-Entwurf mit Beleg je Aussage; Freigabe durch Henning |

### Estimated Changes

- Files: 7 (5 Code/Daten/Test, 1 Python-Test, 1 Dokument). `ci.yml` entfällt gegenüber der Analyse: `unittest discover` nimmt den neuen Test von selbst auf.
- LoC: ca. +130/−2 (davon ≈ 70 Dokument)
- Grenze 4–5 Dateien um zwei überschritten, offen benannt: Die Dateien gehören zu einem Ziel („Texte für Fremde“, Henning 2026-10-02: bündeln), der Umfang liegt deutlich unter ±250 LoC, ein Teil ist reiner Text.

## Implementation Details

1. **Berechtigungstexte (de).** Sinngetreue Übersetzung der englischen Werte in `project.yml`, keine neue Aussage:
   - `NSMicrophoneUsageDescription`: „Loose Ends hört zu, damit du eine Aufgabe sagen kannst, statt sie zu tippen.“
   - `NSSpeechRecognitionUsageDescription`: „Sprache wird auf deinem Gerät in Text umgewandelt, um eine Aufgabe zu erfassen.“
   - `NSCalendarsFullAccessUsageDescription`: „Nur wenn du es einschaltest, erscheint eine Aufgabe mit Fälligkeit in „Loose Ends“ oder in einem Kalender deiner Wahl. Die App ändert nur ihre eigenen Termine.“
   - Die englischen Werte bleiben (Rückfall und `en` = `project.yml`). Auf der Watch gilt derselbe deutsche Text („auf deinem Gerät“ statt englisch „auf deiner Uhr“); die englischen Watch-Texte sind kürzer (`…so you can say a task.`), der deutsche Mikrofontext nennt „statt sie zu tippen“ — beides gleichen Sinns, nicht wortgleich.
2. **Sprachtest** (`scripts/test_infoplist_languages.py`, `unittest`, `yaml` wie das Vorbild): liest alle Ziele aus `project.yml`, sammelt `info.properties`-Schlüssel mit Muster `NS*UsageDescription` und prüft jeden gegen `LooseEnds/Resources/de.lproj/InfoPlist.strings`. Zweiter Test: für `Localizable.xcstrings` (App, Widgets, Share) und `AppShortcuts.xcstrings` hat jeder Eintrag mit `shouldTranslate != false` einen `de`-Wert mit Zustand `translated` (Varianten/Plural zählen über ihre Unterfälle). Fehlt etwas, nennt die Meldung Datei und Schlüssel.
3. **Hinweis ohne Modell.** Nur der Text von `.notEligible` ändert sich. Neuer englischer Text: „This device has no Apple Intelligence. Tags, durations like “20 minutes”, due dates, importance and urgency are still found by rules, and tasks you captured before are recognised. Only the refined title is missing.“ Deutsch: „Dieses Gerät hat kein Apple Intelligence. Tags, Dauer wie „20 Minuten“, Fälligkeit, Wichtigkeit und Dringlichkeit erkennt die App trotzdem per Regeln, schon erfasste Aufgaben erkennt sie wieder. Es fehlt nur der verfeinerte Titel.“ `.turnedOff` und `.notReady` bleiben unverändert. In `ContentView.onboarding` (Z. 191) wird der Grund unter `ModelContainerFactory.isUITesting` fest auf „Apple Intelligence is off under UI testing.“ gesetzt (derselbe Text wie `ModelOffEnricher`), sonst bleibt `FoundationModelsEnricher().unavailableReason`. Der alte Schlüssel wird entfernt, kein verwaister Eintrag.
4. **Datenschutz-Entwurf.** `docs/reference/datenschutz-entwurf.md`, deutsch, mit einer Tabelle „Aussage → Beleg im Code“: was erfasst wird (Text, Sprache nur zur Umwandlung auf dem Gerät), wo es liegt (Gerät, privates iCloud/CloudKit des Nutzers, kein eigenes Backend, kein Tracking, `PrivacyInfo.xcprivacy` je Ziel), welche Rechte warum (Mikrofon, Spracherkennung, Kamera, Standort beim Verwenden, Kalender, Mitteilungen; Fotos/Dateien über die Auswahl ohne Recht), **kein** Kontakte-Recht. Offene Punkte, die der Code nicht beweist, stehen als solche da (z. B. wohin das System Diktat der Watch das Gesagte schickt — Apples Verhalten, nicht belegt). Status „Entwurf, Henning gibt frei“; die URL ist #705.

**Side-Effects, ausdrücklich:** keine neue Berechtigung, kein AppStorage-Key, keine Änderung an `project.yml`, `Info.plist`, Entitlements oder CloudKit-Schema, keine Audio-Dateien. Ein Katalogschlüssel ersetzt einen anderen. Neue Dateien: ein Python-Test, ein Dokument.

## Test Plan

### Automated Tests (TDD RED)

- [ ] `scripts/test_infoplist_languages.py` · `testUsageDescriptionsHaveGerman`: GIVEN `project.yml` mit `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSCalendarsFullAccessUsageDescription` WHEN gegen `de.lproj/InfoPlist.strings` geprüft THEN **RED heute** (drei fehlen, Meldung nennt die Schlüssel), GREEN nach dem Eintrag.
- [ ] `testCatalogsHaveGerman`: GIVEN die vier `*.xcstrings` WHEN geprüft THEN GREEN (Befund: 0 Lücken) — und rot bei einem künstlich entfernten `de`-Wert (Selbstprüfung mit einer Wegwerf-Kopie im Test).
- [ ] `OnboardingTests` (UI, `--ui-testing --ui-testing-onboarding`, Englisch): GIVEN frischer Start unter `--ui-testing` (Grund „Modell aus“ fest) WHEN der Siri-Schritt offen ist THEN existiert `onboardingModelNote`, sein Text enthält „Tags“ und „durations“ und „title“. RED heute (alter Text).
- [ ] `OnboardingTests` (Deutsch, `-AppleLanguages (de)`): derselbe Aufruf, Text enthält „Tags“, „Dauer“ und „Titel“.
- [ ] `OnboardingFlowTests.modelNote` bleibt unverändert und grün (Abbildung unberührt).
- Zuerst RED (Sprachtest, UI-Text), dann GREEN. Gesamtlauf: `./scripts/sim.sh sim-unit`; UI: `./scripts/sim.sh test-proof OnboardingTests`.

## Acceptance Criteria

- **AC-1:** `de.lproj/InfoPlist.strings` enthält `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` und `NSCalendarsFullAccessUsageDescription` mit dem Wortlaut aus „Implementation Details“ 1; `project.yml` und alle `Info.plist` sind unverändert (`git diff` leer, Schritt „Generate leaves the tree clean“ grün).
- **AC-2:** `scripts/test_infoplist_languages.py` ist rot, solange irgendein `NS*UsageDescription` aus `project.yml` (App oder Watch) in `de` fehlt, und grün danach; die Meldung nennt Schlüssel und Datei. Er läuft in der CI über `unittest discover` ohne Änderung an `ci.yml`.
- **AC-3:** Derselbe Test prüft alle Einträge der vier `*.xcstrings` auf einen übersetzten `de`-Wert und wird bei einer künstlichen Lücke rot (Selbstprüfung belegt).
- **AC-4:** Der Hinweis im Fall `.notEligible` nennt in beiden Sprachen Tags, Dauer, Fälligkeit/Wichtigkeit/Dringlichkeit, Wiedererkennung und dass nur der verfeinerte Titel fehlt; `.turnedOff` und `.notReady` sind unverändert; der alte Katalogschlüssel ist entfernt.
- **AC-5:** Die UI-Tests zum Hinweis (Englisch und Deutsch) sind GREEN; der Text erscheint im Siri-Schritt unter `onboardingModelNote`. Unter `--ui-testing` ist der Grund fest („Modell aus“ → `.notEligible`), unabhängig vom Systemmodell des Simulators; außerhalb von UI-Tests bleibt `FoundationModelsEnricher().unavailableReason` unverändert.
- **AC-6:** `docs/reference/datenschutz-entwurf.md` existiert, trägt zu jeder Aussage einen Beleg im Code oder nennt sie als unbelegt, enthält **keine** Kontakte-Zeile und den Status „Entwurf, Freigabe Henning“. Es wird nirgends als gültiger Text eingebaut oder veröffentlicht.
- **AC-7:** Stufe 2: `sim.sh sim-unit` grün (alle Tests), `sim.sh build` baut, `sim.sh test-proof OnboardingTests` liefert den Beleg; Screenshot des Hinweises in Deutsch und Englisch angesehen und beschrieben. Abschluss mit dem Satz „Kein Pfad der Geräteliste berührt.“ (es ändert sich nur `*.lproj`, kein `Info.plist`/`project.yml`).
- **AC-8:** Keine weiteren Änderungen (Scope-Liste oben).

## Alternativen

- **A. Datenschutztext als Seite in der App** (Einstellungen → „Datenschutz“) statt Dokument: der Fremde läse ihn dort ohne URL. Verworfen für diesen Schnitt: mehr Code (View, UI-Test) sprengt die Dateigrenze, und Apple verlangt für TestFlight ohnehin eine Adresse (#705). Folgeticket nach Hennings Freigabe des Entwurfs. Kippt keine ADR.
- **B. Hinweis ohne Modell gar nicht zeigen**, weil „kein Modell“ der Normalzustand ist (ADR-4/A4). Verworfen: das Ticket verlangt den ehrlichen Hinweis; ohne ihn wundern sich Fremde, warum der Titel so bleibt, wie sie ihn sagten.
- **C. Berechtigungstexte als `InfoPlist.xcstrings`** statt `.strings`. Verworfen: kippt #347/#241 (Siri-Namen als Variablen in `.strings`) und den Watch-Weg (#355) ohne Gewinn.
- **D. Den englischen Wortlaut zugleich überarbeiten** (z. B. nennen, dass die Sprache das Gerät nicht verlässt). Verworfen: berührt `project.yml` und damit die Geräteliste; Übersetzung bleibt sinngetreu. Hinweis für Henning im Briefing.
- **Gewählt:** drei Einträge, ein Test, ein Satz, ein Entwurf.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Übersetzung und Textkorrektur ohne neue Struktur, Dependency oder Datenform; ADR-4/A4 („kein Modell ist Normalzustand“) wird bestätigt, nicht gekippt.
- **Rationale:** Texte folgen dem Verhalten, das der Code und `modell-verfuegbarkeit.md` belegen.

## Definition of Done

- [ ] AC-1 bis AC-8 durch Tests und Simulator belegt
- [ ] PR mit `Refs #342` (Ticket bleibt offen: Teile 1 und 3 sind #705), CI grün, gemergt, Hauptordner aktuell
- [ ] Fortschritt als Kommentar in #342; Datenschutz-Entwurf zur Freigabe an Henning
- [ ] Beobachtbar: auf einem deutschen Gerät erscheint der Mikrofon-Dialog auf Deutsch; im Onboarding ohne Modell steht, was trotzdem läuft
- [ ] Regressionslauf grün

## Changelog

- 2026-10-26: Initial spec created
- 2026-10-26: Nachbesserung nach TDD RED (override): `ContentView.swift` Z. 191 ergänzt, siebte Datei; Annahme „Simulator hat kein Modell“ berichtigt

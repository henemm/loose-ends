---
entity_id: feat-342-schnitt-1a-hinweis-ohne-modell
type: feature
created: 2026-10-26
updated: 2026-10-26
status: draft
workflow: 342-sprache-und-start-ohne-modell
---

# Spec: Hinweis „Gerät ohne Modell“ sagt die Wahrheit und wird auf dem Bildschirm belegt (#342, Schnitt 1a)

## Approval

- [ ] Approved

## GitHub Issue

#342 „Beta-Reife“, Teil 5 „Erster Start ohne Modell“ (Epic #370/#371, M3). Kontext, Messung und Analyse: `docs/context/342-sprache-und-start-ohne-modell.md`.
Schnitt 1a umfasst nur den Hinweis im Onboarding. **Folgeschnitte, bewusst nicht hier:** 1b (Vollständigkeitsskript `scripts/test_localization_complete.py`
und das veraltete Label „Counts“ → „Perle sammeln“/„Collect bead“), Schnitt 2 (Berechtigungstexte, Komplikation „Capture“/„Opens capture.“, Geräteliste),
Schnitt 3 (Beta-Freigabe, Testgruppe).

## Purpose

Beim ersten Start auf einem Gerät ohne Apple Intelligence zeigt das Onboarding (Schritt 1) einen grauen Hinweis. Zwei Befunde (Analyse, Simulator, 2026-10-26):

1. **Der Text stimmt nur halb.** „Aufgaben behalten deine Worte; Fälligkeit, Wichtigkeit und Dringlichkeit werden trotzdem erkannt“ verschweigt die Etiketten
   (Wortliste, `ContextWordRule`) und die Dauer: ohne Modell kommt eine Dauer nur, wenn der Text sie nennt (`DurationRule`, #673) oder die Aufgabe schon
   einmal erfasst wurde (`RecognitionRule`, #136); Energie gibt es ohne Modell nie (Soll: `docs/reference/modell-verfuegbarkeit.md`).
2. **Die Kette „Grund → Text auf dem Bildschirm“ wurde nie gesehen.** Der iOS-27-Simulator hat ein Modell (`unavailableReason == nil`), also erscheint der Hinweis
   dort nie; `OnboardingFlowTests.modelNote` prüft nur Grund → Fall, kein Test prüft den Text oder die Anzeige.

Dieser Schnitt ersetzt den Wortlaut des Falls „Gerät ohne Modell“ und macht alle drei Fälle über ein Startargument im Simulator sichtbar und testbar.

**Ohne Modell geht es nicht, weil …** entfällt: reiner Text und Anzeige, kein Sprachmodell im Spiel; die Regelspalte ist die Quelle des Wortlauts.

## Source

- **File:** `LooseEnds/Views/OnboardingView.swift`, `LooseEnds/App/ContentView.swift`
- **Identifier:** `OnboardingView.modelNote(_:)`, `ContentView.onboarding` (Argument `modelUnavailableReason:`)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `OnboardingFlow.modelNote(for:)` | Upstream, unverändert | Abbildung Grund → Fall (`turnedOff`, `notReady`, `notEligible`) |
| `FoundationModelsEnricher().unavailableReason` | Upstream, nur gelesen | der echte Grund im Produkt |
| `ModelContainerFactory.isUITesting` bzw. Argument `--ui-testing` | Testmechanik | das neue Startargument gilt nur darunter |
| `docs/reference/modell-verfuegbarkeit.md` | Soll | was der Text behaupten darf |
| `LooseEndsUITests/OnboardingTests.swift` | Downstream | bestehende Tests laufen unverändert weiter |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Views/OnboardingView.swift` | MODIFY | Text im Fall `.notEligible` ersetzt (eine Zeile) |
| `LooseEnds/App/ContentView.swift` | MODIFY | `--ui-testing-model-reason=<Grund>` ersetzt unter `--ui-testing` den Grund, sonst unverändert |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | alter Schlüssel entfällt, neuer mit `de` (`translated`) |
| `LooseEndsUITests/OnboardingTests.swift` | MODIFY | drei Tests: Hinweis je Fall auf dem Bildschirm, Englisch und Deutsch; ohne Argument kein Hinweis |

### Estimated Changes

- Files: 4 (Limit 4–5, eingehalten)
- LoC: ca. +70/−3 (Tests ~55, Rest ~15)
- Risk: LOW — Text, ein Testargument, kein Datenmodell, keine Persistenz, keine Berechtigung.

## Implementation Details

1. **Wortlaut (Henning gibt ihn mit der Freigabe dieser Spec frei)** — nur der Fall „Gerät ohne Modell“:
   - EN: „This device has no Apple Intelligence. Due dates, importance, urgency and tags are still found; a duration only when you name it or the task came up before.“
   - DE: „Dieses Gerät hat kein Apple Intelligence. Fälligkeit, Wichtigkeit, Dringlichkeit und Etiketten werden trotzdem erkannt; eine Dauer nur, wenn du sie nennst oder die Aufgabe schon einmal da war.“
   - Die Fälle „aus“ und „nicht bereit“ stimmen gegen die Matrix und bleiben wörtlich. Der Satz „Aufgaben behalten deine Worte“ entfällt: er ist keine Besonderheit ohne Modell (Rohtext ist immer unveränderlich) und nahm Platz für die Etiketten weg.
   - „Etiketten“ ist das Nutzerwort für Tags (Etiketten-Seite, #428).
2. **Startargument** `--ui-testing-model-reason=<Grund>`: nur wirksam, wenn `--ui-testing` gesetzt ist; der Wert geht als Grund in `OnboardingView(modelUnavailableReason:)`.
   Grundnamen wie beim System: `appleIntelligenceNotEnabled`, `modelNotReady`, `deviceNotEligible`. Ohne Argument gilt unverändert der echte Grund (im Simulator `nil` → kein Hinweis).
   Im Produkt (ohne `--ui-testing`) ist der Pfad nicht erreichbar.
3. **Layout unverändert** (`footnote`, grau, Kennung `onboardingModelNote`): keine Neugestaltung, daher keine Vorschauseite; freigegeben wird nur der Wortlaut.
4. Der UI-Test liest das `label` von `onboardingModelNote` und vergleicht es mit dem vollen Wortlaut (EN und DE, Sprache über `-AppleLanguages`/`-AppleLocale` wie bisher).

**Side-Effects, ausdrücklich:** keine neue Berechtigung, kein AppStorage-Key, keine `Info.plist`-/`project.yml`-Änderung, keine Audio-Dateien, kein CloudKit-Feld.
Ein Text entfällt, ein Text kommt hinzu (je mit `de`); ein Startargument, das nur Tests nutzen.

## Test Plan

### Automated Tests (TDD RED)

- [ ] UI `OnboardingTests.testNoModelNoteExplainsWhatStillWorks` (EN): GIVEN `--ui-testing-model-reason=deviceNotEligible` WHEN Schritt 1 offen THEN `onboardingModelNote` hat den neuen englischen Wortlaut. RED: alter Text bzw. Argument unbekannt.
- [ ] UI (DE): GIVEN dasselbe mit `-AppleLanguages (de)` THEN der deutsche Wortlaut inkl. „Etiketten“.
- [ ] UI: GIVEN `appleIntelligenceNotEnabled` THEN der „aus“-Text; GIVEN `modelNotReady` THEN der „nicht bereit“-Text (beide EN) — schließt die Kette für alle drei Fälle.
- [ ] UI: GIVEN kein Argument WHEN Schritt 1 THEN `onboardingModelNote` existiert nicht (Simulator hat ein Modell) — die zwei bestehenden Onboarding-Tests bleiben grün.
- Gesamtlauf: `./scripts/sim.sh sim-unit` (Unit, unverändert grün) und `./scripts/sim.sh test-proof OnboardingTests`.

### Simulator (Stufe 2)

`test-proof OnboardingTests` liefert den maschinellen Beleg; zusätzlich `build` + `launch --ui-testing --ui-testing-onboarding --ui-testing-model-reason=deviceNotEligible` in Deutsch und
Englisch, Screenshots geöffnet und beschrieben (der Hinweis steht sichtbar unter der Siri-Erklärung, ohne abgeschnitten zu sein, Hell und Dunkel).

### Gerät (Stufe 3)

Entfällt: „Kein Pfad der Geräteliste berührt.“ Nichts auf Hennings Geräten.

## Acceptance Criteria

- **AC-1:** Der Fall „Gerät ohne Modell“ zeigt auf Englisch „This device has no Apple Intelligence. Due dates, importance, urgency and tags are still found; a duration only when you name it or the task came up before.“ und auf Deutsch „Dieses Gerät hat kein Apple Intelligence. Fälligkeit, Wichtigkeit, Dringlichkeit und Etiketten werden trotzdem erkannt; eine Dauer nur, wenn du sie nennst oder die Aufgabe schon einmal da war.“ — belegt durch UI-Test (`label` von `onboardingModelNote`).
- **AC-2:** Die Fälle „aus“ und „nicht bereit“ stehen unverändert auf dem Bildschirm, belegt durch UI-Test je Fall.
- **AC-3:** `--ui-testing-model-reason=<Grund>` setzt unter `--ui-testing` den Grund des Onboardings; ohne `--ui-testing` ohne Wirkung; ohne das Argument unverändert der echte Grund (im Simulator kein Hinweis, UI-Test belegt „existiert nicht“).
- **AC-4:** `Localizable.xcstrings` enthält den alten Schlüssel „This device has no Apple Intelligence. Tasks keep the words you said; …“ nicht mehr und den neuen mit `de` im Zustand `translated`.
- **AC-5:** Stufe 2: `sim-unit` ganz grün, `build` baut, `test-proof OnboardingTests` liefert den Beleg; Screenshots (DE/EN, Hell/Dunkel) angesehen und beschrieben.
- **AC-6:** Keine weiteren Änderungen: genau die vier Dateien der Tabelle, keine Berechtigung, kein Key, keine `project.yml`/`Info.plist`. Abschlussbericht enthält den Satz „Kein Pfad der Geräteliste berührt.“

## Alternativen

- **Hinweis streichen**, nur der Onboarding-Satz „Funktioniert ohne Apple Intelligence“: verworfen — Dauer fehlt spürbar, Schweigen wäre unehrlich.
- **Hinweis erst zeigen, wo etwas fehlt** (an der Aufgabe, in der die Dauer leer bleibt): ehrlicher und kontextnah, aber neue Oberfläche mit eigenem Entwurf. Als Folge-Idee ins Ticket, nicht in diesen Schnitt.
- **Wortlaut ohne Bedingung bei der Dauer** („Dauer und Energie fehlen“): kürzer, aber falsch für wiedererkannte oder benannte Dauer; verworfen.
- **Kein Testargument, sondern Protokoll-Injektion des Enrichers**: größerer Eingriff in den Produktpfad (`LooseEndsApp`) für denselben Beleg; verworfen.
- **Gewählt:** neuer Wortlaut, Startargument unter `--ui-testing`.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — reiner Text und ein Testargument; berührt keine ADR (ADR-4 „Modellverfügbarkeit“ wird gelesen, nicht verändert; „Regeln vor Modell“ wird bestätigt: Der Text benennt die Regelleistungen).
- **Rationale:** kleinster Eingriff, der Text und Anzeige belegbar macht, ohne den Produktpfad zu verzweigen.

## Definition of Done

- [ ] AC-1 bis AC-6 durch Tests und Simulator belegt
- [ ] PR mit Verweis auf #342 (**ohne** `Closes`, das Ticket hat weitere Schnitte), CI grün, gemergt, Hauptordner aktuell
- [ ] Folgeschnitte 1b, 2, 3 im Ticket #342 vermerkt
- [ ] Regressionslauf grün

## Changelog

- 2026-10-26: Initial spec created (Schnitt 1a; 1b/2/3 getrennt, Dateigrenze)

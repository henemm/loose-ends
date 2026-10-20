---
entity_id: feat-479-mac-menueleiste
type: feature
created: 2026-10-19
updated: 2026-10-19
status: draft
workflow: feat-479-mac-menueleiste
---

# Spec: #479 — Menüleisten-Panel der Mac-App im Papierstil

## Approval

- [ ] Approved (Henning)

Teil von Epic #467, Entwurf #408 (Tafel `docs/artifacts/feat-408-mac-entwurf/Menueleiste.dc.html`, freigegeben).
Analyse: `docs/context/feat-479-mac-menueleiste.md`. Vorbild für Technik und Belege: #477 (Liste, Detail), #478 (Einstellungen).

## Purpose

Das Panel unter dem Fadensymbol in der Mac-Menüleiste zeigt Papier als Grund, oben den Knoten neben „NEUE AUFGABE“ in kleinen
grauen Großbuchstaben, ein Eingabefeld in Serif ohne grauen Kasten, darunter eine Zeile mit Mikrofon, Hinweis, „Abbrechen“ und
„Fertig“ (Akzentkapsel) und unter einer Haarlinie „Loose Ends öffnen“ und „Loose Ends beenden“. **Die Funktion bleibt**:
dieselbe `CaptureView` wie im Fenster, Return speichert, das Panel schließt (#356, #400, #402, #279, #297).

**Rein regelbasiert.** Reine Darstellung; kein Modell, kein Prompt, kein Schema. „Without the model this fails because …“
entfällt, weil kein Feld abgeleitet wird.

## Source

- **Geändert:** `LooseEnds/Views/CaptureView.swift` (Panel-Zweig: nur `#if os(macOS)` und `onFinish != nil`)
- **Geändert:** `LooseEnds/Mac/MenuBarCapture.swift` (Papier, Haarlinie, Fußzeile)
- **Geändert (klein):** `LooseEnds/App/LooseEndsApp.swift` (`.preferredColorScheme(Self.uiTestColorScheme)` am Panel)
- **Geändert:** `LooseEnds/Resources/Localizable.xcstrings` (zwei neue Texte)
- **Geändert:** `LooseEndsUITests/MacGalleryTests.swift` (`testPanelLight`, `testPanelDark`)
- **Optional neu:** `LooseEndsTests/` (nur falls eine reine Regel entsteht)
- **Neu:** `docs/artifacts/feat-479-mac-menueleiste/` (Belege aus der CI-Galerie)

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEnds/Views/CaptureView.swift` | MODIFY | Zweig `#if os(macOS)` **und** `onFinish != nil`: Kopfzeile (`ThreadGlyph` + „New task“ mit `captionHead()`), Feld ohne `FieldSurface`-Kasten in Serif 22 pt, mindestens 110 pt hoch, eine Zeile Mikrofon / Hinweis-oder-Welle / Abbrechen / Fertig, Diagnosezeile darunter. iPhone, iPad und Fenster-⌘N (`onFinish == nil`) unverändert |
| `LooseEnds/Mac/MenuBarCapture.swift` | MODIFY | `Paper.ground` als Grund der ganzen Panelansicht, Haarlinie statt `Divider`, Fußzeile grau 12 pt |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY (1 Zeile) | `.preferredColorScheme(Self.uiTestColorScheme)` an `MenuBarExtra`-Inhalt |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | „New task“ / „Neue Aufgabe“; „Speak or type. Return saves.“ / „Sprich los oder tippe. Return speichert.“ |
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | `testPanelLight`, `testPanelDark`: Fadensymbol anklicken, Panel greifen, Sichtbarkeit prüfen, Fotos `mac-gallery-panel-*` |

### Estimated Changes

- Dateien: 5 (6 mit optionalem Unit-Test), innerhalb der Grenze von 5 bis 6; ohne den optionalen Test innerhalb von 5.
- LoC: ca. +170/−40, unter 250. Überschreitet die Umsetzung 250, wird gestoppt und mit Schätzung nachgefragt.

Geräteliste: **Kein Pfad der Geräteliste berührt** (`LooseEnds/Views`, `LooseEnds/Mac`, `LooseEnds/App/LooseEndsApp.swift`,
Resources, Tests; weder `Shared/Persistence` noch `project.yml`, Entitlements oder Info.plist). Keine Berechtigung, kein
AppStorage-Schlüssel, kein Modellfeld, kein CloudKit-Schema.

## Implementation Details

**Weiche.** Der Panel-Zweig gilt nur, wenn `os(macOS)` **und** `onFinish != nil` (das Panel; das Fenster-⌘N ruft `CaptureView`
ohne `onFinish`). Alle anderen Fälle laufen durch den bisherigen Code, damit iPhone, iPad und Fenster Pixel für Pixel gleich
bleiben.

**Kopf.** `ThreadGlyph` (Knoten, nur SwiftUI) neben „New task“ in `captionHead()` (SF 11 pt, grau, gesperrt, Großbuchstaben).

**Feld.** `.font(.system(size: 22, design: .serif))`, Mindesthöhe 110 pt, Platzhalter in Platzhalter-Grau, kein grauer Kasten
(`FieldSurface` entfällt im Panel, dafür ein Inset). Kennung `captureTextField` bleibt.

**Zeile.** `MicButton` (44 pt im 74-pt-Rahmen für den Pegelring #279, Ring in Akzent), im Mittelfeld entweder die Welle
(`WaveformView`, dünn) oder der Hinweis; rechts „Abbrechen“ (grau, Kennung `captureCancelButton`) und „Fertig“ als Akzentkapsel,
weiße Schrift, 30 pt hoch (Kennung `captureDoneButton`). Akzent nur für Antippbares (ADR-14).

**Verhalten (verbindlich):**
- Die **Hinweiszeile** „Speak or type. Return saves.“ (grau 13 pt) steht nur, wenn das Mikrofon **nicht** lauscht **und** das
  Feld leer ist.
- „Listening …“ (`listeningHint`, #297) und die ruhige Diagnosezeile (`speechDiagnosisLabel`, #402) werden vom Hinweis **nicht
  verdrängt** und bleiben inhaltlich und in ihren Bedingungen unverändert.
- Die **Welle** erscheint nur, solange das Mikrofon hört; sonst steht dort der Hinweis (oder, sobald Text im Feld steht, nichts).
- Das Panel behält seine **feste ideale Höhe**: `.fixedSize(horizontal: false, vertical: true)` um die Erfassung bleibt (#400),
  die Diagnosezeile hat reservierten Platz, damit das Panel nicht springt.

**Fußzeile.** Unter einer Haarlinie „Open Loose Ends“ (de „Loose Ends öffnen“) und „Quit Loose Ends“ (de „Loose Ends
beenden“), grau 12 pt, Kennungen `menuBarOpenApp` und `menuBarQuit`. Breite 440 pt.

**Dunkel.** Unter UI-Test erbt das `MenuBarExtra`-Panel das Systemschema, nicht `--ui-testing-dark`. Deshalb
`.preferredColorScheme(Self.uiTestColorScheme)` am Panel (wirkt nur unter `--ui-testing-dark`, wie bei den Einstellungen, Commit
`78f201f`).

**Lokalisierung.** Zwei neue Einträge in `Localizable.xcstrings`: „New task“ / „Neue Aufgabe“ und „Speak or type. Return
saves.“ / „Sprich los oder tippe. Return speichert.“ Vorhandene Texte („Open Loose Ends“, „Quit Loose Ends“, „Cancel“, „Done“,
„What should I remember?“) bleiben unverändert.

### Abweichungen Tafel ↔ App (ausdrücklich)

| Punkt | Tafel | App nach #479 | Grund |
|---|---|---|---|
| Rundung | 14 | Systemrundung des Fensters | `MenuBarExtra` im Stil `.window` lässt die Rundung nicht einstellen; Papier füllt den Inhalt, die Ecke schließt das System |
| Platzhalter | „Was soll ich mir merken?“ | „Was soll ich aufnehmen?“ (App-Text) | gleiches Feld wie im Fenster, Wortlaut von Henning freigegeben; Tafel ist hier Bildplatzhalter |
| Fußzeile | „Beenden“ | „Loose Ends beenden“ (App-Text) | Menüleisten-Konvention, bestehender Wortlaut |
| Mikrofon | 46 pt | 44 pt im 74-pt-Rahmen | Pegelring (#279) braucht den Rahmen; 46 pt ist Bildmaß |
| Welle | fehlt | bleibt, dünn, nur beim Hören | Teil von #279; Funktion laut Ticket „bleibt“ |
| Hinweis | „Sprich los oder tippe. Return speichert.“ | neu, nur in Ruhe (nicht hören, Feld leer) | verdrängt weder „Listening …“ noch Diagnosezeile |

### Alternativen

- **Eigenes schlankes Mac-Panel statt `CaptureView`-Zweig:** iPhone/iPad sicher, aber Sprache, Speichern und Diagnose doppelt
  gepflegt; kippt die Zusage „dasselbe `CaptureView`“ aus #356. Verworfen.
- **Eigenes `NSPanel`** (volle Kontrolle über Rundung 14, Schatten, Haarlinie, wie FluidMenuBarExtra): träfe die Tafel
  pixelgenau, baut aber Schließen bei Fokusverlust und Tastaturfokus aus #356/#400 neu und ist für reine Optik zu viel.
  Verworfen; die Rundung bleibt die des Systems.
- **Tafel wörtlich** (Platzhalter „Was soll ich mir merken?“, „Beenden“): kippt Hennings freigegebenen Wortlaut; nur auf sein
  ausdrückliches Wort.

## Test Plan

### Automated Tests (TDD RED)

Der Nachweis läuft über die Mac-Galerie (UI-Test), vor der Umsetzung rot, weil `mac-gallery-panel-*` und die Prüfung der Sichtbarkeit
fehlen:

- [ ] `MacGalleryTests.testPanelLight`: GIVEN die Mac-App läuft WHEN das Fadensymbol angeklickt wird THEN erscheint das Panel
  (Fenster mit `menuBarOpenApp`); `captureTextField`, `micButton`, `captureCancelButton`, `captureDoneButton`, `menuBarOpenApp`,
  `menuBarQuit` sind vorhanden; Abbrechen, Fertig und Fußzeile liegen **innerhalb** des Panel-Rahmens und sind sichtbar (#400);
  Foto `mac-gallery-panel-light`.
- [ ] `MacGalleryTests.testPanelDark`: dasselbe mit `--ui-testing-dark`; Foto `mac-gallery-panel-dark`.

Bestehend, grün zu halten: alle UI-Tests mit den Kennungen `captureTextField`, `captureDoneButton`, `captureCancelButton`,
`micButton`, `listeningHint`, `speechDiagnosisLabel`, `menuBarOpenApp`, `menuBarQuit` (Kennungen bleiben); iOS-UI-Smoke als
Gegenprobe für die geteilte Ansicht; `MenuBarTests` (`DockPolicy`); voller Unit-Lauf (`./scripts/sim.sh sim-unit`, nie auf dem Mac).

Optional (nur falls eine reine Regel entsteht, z. B. Hinweis/Welle/Diagnose-Vorrang als reine Funktion neben `ListeningHint`):
Unit-Test der Tabelle (hört / hört nicht × Feld leer / nicht leer × Diagnose ja / nein). Entsteht keine Regel, entfällt er.

Simulator (Stufe 2): iPhone, Erfassung (Aktionstaste/Sheet), vorher (`main`) und nachher; Bilder geöffnet und beschrieben
(unverändert). Mac: nur Bilder aus dem CI-Job „Mac Gallery (macOS)“ (Artefakt `MacGallery`), nie von Hennings Mac.

## Acceptance Criteria

- **AC-1:** Das Panel zeigt Papier als Grund (hell und dunkel) und eine Haarlinie vor der Fußzeile, kein graues Feld. Beleg:
  Galeriebilder `mac-gallery-panel-light` und `mac-gallery-panel-dark` aus dem CI-Lauf, geöffnet und beschrieben.
- **AC-2:** Der Kopf zeigt den Knoten neben „NEUE AUFGABE“ (de) bzw. „NEW TASK“ (en) in kleinen grauen gesperrten Großbuchstaben.
  Beleg: Sichtbefund im Galeriebild; die Strings „New task“ / „Neue Aufgabe“ stehen in `Localizable.xcstrings` (Diff).
- **AC-3:** Das Eingabefeld ist in Serif 22 pt, mindestens 110 pt hoch und ohne grauen Kasten; der Platzhalter bleibt der
  App-Text „Was soll ich aufnehmen?“. Beleg: Sichtbefund im Galeriebild; Diff zeigt `FieldSurface` im Panel-Zweig nicht verwendet.
- **AC-4:** Die Zeile unter dem Feld zeigt Mikrofon (Ring in Akzent), Hinweis, „Abbrechen“ (grau) und „Fertig“ als Akzentkapsel
  (weiß, 30 pt hoch). Beleg: Sichtbefund im Galeriebild; `MacGalleryTests.testPanelLight` findet `micButton`,
  `captureCancelButton`, `captureDoneButton`.
- **AC-5:** Die Hinweiszeile „Sprich los oder tippe. Return speichert.“ steht nur, wenn das Mikrofon nicht lauscht und das Feld
  leer ist; „Listening …“ (#297) und die Diagnosezeile (#402) werden nicht verdrängt. Beleg: Sichtbefund im Galeriebild
  (Ruhezustand zeigt den Hinweis); Diff lässt `ListeningHint`-Zustand und `macDiagnosisLine` unverändert; bestehende Tests zu
  `listeningHint` und `speechDiagnosisLabel` grün; ggf. Unit-Test der Vorrangtabelle.
- **AC-6:** Die Welle erscheint nur beim Hören, das Panel behält die feste ideale Höhe (`fixedSize` vertikal). Beleg: Diff
  (`fixedSize` bleibt um die Erfassung); Galeriebild zeigt im Ruhezustand ohne Welle dieselbe Panelhöhe wie die Prüfung der
  Rahmen in AC-7.
- **AC-7:** „Abbrechen“, „Fertig“ und die Fußzeile („Loose Ends öffnen“, „Loose Ends beenden“) sind sichtbar und liegen innerhalb
  des Panel-Rahmens (#400). Beleg: `MacGalleryTests.testPanelLight` und `testPanelDark` prüfen `isHittable` und
  `frame`-Enthaltensein der vier Elemente im Panel-Fenster; Galeriebild bestätigt es.
- **AC-8:** Die Fußzeile steht unter einer Haarlinie in grau 12 pt mit dem App-Wortlaut „Loose Ends öffnen“ und „Loose Ends
  beenden“; Kennungen `menuBarOpenApp`, `menuBarQuit` bleiben. Beleg: Galeriebild; Test findet beide Kennungen.
- **AC-9:** Die Funktion bleibt unverändert: Return speichert und schließt das Panel, „Abbrechen“ schließt ohne Speichern;
  Bindungen, `onFinish`-Aufruf und Anreicherung (`processPending`) im Diff ungeändert; keine neuen AppStorage-Schlüssel, kein
  Modell-, Schema- oder Rechte-Eingriff. Beleg: Diff; bestehende UI-Tests mit den Kennungen und der volle Unit-Lauf grün.
- **AC-10:** Dunkel funktioniert für das Panel unter `--ui-testing-dark` (`.preferredColorScheme(Self.uiTestColorScheme)`).
  Beleg: Foto `mac-gallery-panel-dark` zeigt dunkles Papier (`#171816`), geöffnet und beschrieben.
- **AC-11:** iPhone, iPad und Fenster-⌘N bleiben Pixel für Pixel gleich: der Panel-Zweig hängt hinter
  `#if os(macOS)` **und** `onFinish != nil`. Beleg: Diff (Modifier-Kette der übrigen Zweige unverändert); iOS-UI-Smoke grün;
  iPhone-Simulatorbild der Erfassung vorher (`main`) und nachher dasselbe (beide beschrieben); `MacGalleryTests`-Bild des
  Fensters (falls vorhanden) unverändert.
- **AC-12:** Die neuen Texte sind lokalisiert: „New task“ / „Neue Aufgabe“ und „Speak or type. Return saves.“ / „Sprich los oder
  tippe. Return speichert.“ stehen in `Localizable.xcstrings`. Beleg: Diff; deutsches Galeriebild zeigt die deutschen Texte.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `SpeechCapture`, `CaptureService.save`, `EnrichmentCoordinator.processPending()` | module | Sprache, Speichern, Regeln; unverändert |
| `MacWindows` (`closeMenuBarPanel`, `showMain`) | module | Schließen und Öffnen; unverändert |
| `Paper` (`ground`, `captionHead()`), `ThreadGlyph` | module | aus #477/#478, unverändert |
| `ListeningHint`, `SpeechDiagnosis` | module | Regeln für „Listening …“ und Diagnose; unverändert |
| `MacGalleryTests`, `MacUITestSupport`, CI-Job „Mac Gallery (macOS)“ (#511) | test | liefert die Mac-Bilder |
| Neue externe Abhängigkeit | – | keine |

## Außerhalb des Umfangs (Nicht-Ziele)

- iPhone, iPad und Fenster-⌘N (`CaptureView` ohne `onFinish`) bleiben Pixel für Pixel gleich.
- Wortlaut des App-Textes bleibt: Platzhalter „Was soll ich aufnehmen?“, „Loose Ends beenden“ (Tafel-Wortlaut nur auf Hennings Wort).
- Keine Änderung an Modell, Schema, Rechten oder AppStorage.
- Keine Rundung 14: `MenuBarExtra` im Stil `.window` lässt sie nicht zu.
- Kein eigenes `NSPanel`; #356/#400-Verhalten (Schließen bei Fokusverlust, Tastaturfokus) bleibt.
- Neue Funktionen, andere Reihenfolge der Elemente, Pegelring-Änderung (#279).

## Auslieferung

Abnahme: Stufe 1 Tests (Unit, UI Smoke iOS als Gegenprobe, `MacGalleryTests`), Stufe 2 Mac-Galerie-Bilder der CI öffnen und
beschreiben (Mac-Bilder nur von dort). Satz im Abschlussbericht: „Kein Pfad der Geräteliste berührt.“ Zusätzlich schaut Henning
nach dem Merge über TestFlight (Mac) auf das Panel; er bekommt die Buildnummer und den Prüfschritt (Fadensymbol anklicken: Papier,
Kopfzeile, Hinweis, Fußzeile), keine Befehlszeile. Kein Modell, deshalb kein `mac-schema-init`.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — Wortlaut-/Layout-Anpassung des Panels, kippt keine ADR; ADR-14 (Akzent = antippbar) wird eingehalten, ADR zu
#356 („ein Panel, dieselbe Erfassung“) bleibt gültig.

## Definition of Done

- AC-1 bis AC-12 erfüllt; Unit-Lauf (`sim-unit`) und iOS-UI-Smoke grün; `MacGalleryTests.testPanelLight/Dark` grün in der CI.
- Stufe 2: Mac-Bilder aus dem CI-Artefakt `MacGallery` geöffnet und beschrieben; iPhone-Erfassung im Simulator vorher/nachher.
- Satz im Abschlussbericht: „Kein Pfad der Geräteliste berührt.“
- PR mit `Closes #479`; Board gepflegt; Belege unter `docs/artifacts/feat-479-mac-menueleiste/`.

## Changelog

- 2026-10-19: Spec aus der Analyse `docs/context/feat-479-mac-menueleiste.md` geschrieben. Entscheidungen: App-Wortlaut
  behalten, Rundung des Systems, Welle bleibt, Hinweis nur in Ruhe.

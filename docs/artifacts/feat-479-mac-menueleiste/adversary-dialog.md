# Adversary Dialog — feat-479-mac-menueleiste
Spec: docs/specs/feat-479-mac-menueleiste.md
Datum: 2026-10-20 12:08

## Checkliste
- [ ] **AC-1:** Das Panel zeigt Papier als Grund (hell und dunkel) und eine Haarlinie vor der Fußzeile, kein graues Feld. Beleg: Galeriebilder `mac-gallery-panel-light` und `mac-gallery-panel-dark` aus dem CI-Lauf, geöffnet und beschrieben.
- [ ] **AC-2:** Der Kopf zeigt den Knoten neben „NEUE AUFGABE“ (de) bzw. „NEW TASK“ (en) in kleinen grauen gesperrten Großbuchstaben. Beleg: Sichtbefund im Galeriebild; die Strings „New task“ / „Neue Aufgabe“ stehen in `Localizable.xcstrings` (Diff).
- [ ] **AC-3:** Das Eingabefeld ist in Serif 22 pt, mindestens 110 pt hoch und ohne grauen Kasten; der Platzhalter bleibt der App-Text „Was soll ich aufnehmen?“. Beleg: Sichtbefund im Galeriebild; Diff zeigt `FieldSurface` im Panel-Zweig nicht verwendet.
- [ ] **AC-4:** Die Zeile unter dem Feld zeigt Mikrofon (Ring in Akzent), Hinweis, „Abbrechen“ (grau) und „Fertig“ als Akzentkapsel (weiß, 30 pt hoch). Beleg: Sichtbefund im Galeriebild; `MacGalleryTests.testPanelLight` findet `micButton`, `captureCancelButton`, `captureDoneButton`.
- [ ] **AC-5:** Die Hinweiszeile „Sprich los oder tippe. Return speichert.“ steht nur, wenn das Mikrofon nicht lauscht und das Feld leer ist; „Listening …“ (#297) und die Diagnosezeile (#402) werden nicht verdrängt. Beleg: Sichtbefund im Galeriebild (Ruhezustand zeigt den Hinweis); Diff lässt `ListeningHint`-Zustand und `macDiagnosisLine` unverändert; bestehende Tests zu `listeningHint` und `speechDiagnosisLabel` grün; ggf. Unit-Test der Vorrangtabelle.
- [ ] **AC-6:** Die Welle erscheint nur beim Hören, das Panel behält die feste ideale Höhe (`fixedSize` vertikal). Beleg: Diff (`fixedSize` bleibt um die Erfassung); Galeriebild zeigt im Ruhezustand ohne Welle dieselbe Panelhöhe wie die Prüfung der Rahmen in AC-7.
- [ ] **AC-7:** „Abbrechen“, „Fertig“ und die Fußzeile („Loose Ends öffnen“, „Loose Ends beenden“) sind sichtbar und liegen innerhalb des Panel-Rahmens (#400). Beleg: `MacGalleryTests.testPanelLight` und `testPanelDark` prüfen `isHittable` und `frame`-Enthaltensein der vier Elemente im Panel-Fenster; Galeriebild bestätigt es.
- [ ] **AC-8:** Die Fußzeile steht unter einer Haarlinie in grau 12 pt mit dem App-Wortlaut „Loose Ends öffnen“ und „Loose Ends beenden“; Kennungen `menuBarOpenApp`, `menuBarQuit` bleiben. Beleg: Galeriebild; Test findet beide Kennungen.
- [ ] **AC-9:** Die Funktion bleibt unverändert: Return speichert und schließt das Panel, „Abbrechen“ schließt ohne Speichern; Bindungen, `onFinish`-Aufruf und Anreicherung (`processPending`) im Diff ungeändert; keine neuen AppStorage-Schlüssel, kein Modell-, Schema- oder Rechte-Eingriff. Beleg: Diff; bestehende UI-Tests mit den Kennungen und der volle Unit-Lauf grün.
- [ ] **AC-10:** Dunkel funktioniert für das Panel unter `--ui-testing-dark` (`.preferredColorScheme(Self.uiTestColorScheme)`). Beleg: Foto `mac-gallery-panel-dark` zeigt dunkles Papier (`#171816`), geöffnet und beschrieben.
- [ ] **AC-11:** iPhone, iPad und Fenster-⌘N bleiben Pixel für Pixel gleich: der Panel-Zweig hängt hinter `#if os(macOS)` **und** `onFinish != nil`. Beleg: Diff (Modifier-Kette der übrigen Zweige unverändert); iOS-UI-Smoke grün; iPhone-Simulatorbild der Erfassung vorher (`main`) und nachher dasselbe (beide beschrieben); `MacGalleryTests`-Bild des Fensters (falls vorhanden) unverändert.
- [ ] **AC-12:** Die neuen Texte sind lokalisiert: „New task“ / „Neue Aufgabe“ und „Speak or type. Return saves.“ / „Sprich los oder tippe. Return speichert.“ stehen in `Localizable.xcstrings`. Beleg: Diff; deutsches Galeriebild zeigt die deutschen Texte.

## Dialog

### Runde 1
**Adversary:**
**Implementierer:**

### Runde 2
**Adversary:**
**Implementierer:**

## Herkunft der Vorbedingungen

<!-- vom Prüfer auszufüllen, siehe `precondition_origins.py` -->

## Verdict

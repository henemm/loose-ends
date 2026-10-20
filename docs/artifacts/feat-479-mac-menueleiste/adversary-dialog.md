# Adversary Dialog — feat-479-mac-menueleiste
Spec: docs/specs/feat-479-mac-menueleiste.md
Datum: 2026-10-20 12:08

## Checkliste
- [x] **AC-1:** Das Panel zeigt Papier als Grund (hell und dunkel) und eine Haarlinie vor der Fußzeile, kein graues Feld. Beleg: Galeriebilder `mac-gallery-panel-light` und `mac-gallery-panel-dark` aus dem CI-Lauf, geöffnet und beschrieben.
- [x] **AC-2:** Der Kopf zeigt den Knoten neben „NEUE AUFGABE“ (de) bzw. „NEW TASK“ (en) in kleinen grauen gesperrten Großbuchstaben. Beleg: Sichtbefund im Galeriebild; die Strings „New task“ / „Neue Aufgabe“ stehen in `Localizable.xcstrings` (Diff).
- [x] **AC-3:** Das Eingabefeld ist in Serif 22 pt, mindestens 110 pt hoch und ohne grauen Kasten; der Platzhalter bleibt der App-Text „Was soll ich aufnehmen?“. Beleg: Sichtbefund im Galeriebild; Diff zeigt `FieldSurface` im Panel-Zweig nicht verwendet.
- [x] **AC-4:** Die Zeile unter dem Feld zeigt Mikrofon (Ring in Akzent), Hinweis, „Abbrechen“ (grau) und „Fertig“ als Akzentkapsel (weiß, 30 pt hoch). Beleg: Sichtbefund im Galeriebild; `MacGalleryTests.testPanelLight` findet `micButton`, `captureCancelButton`, `captureDoneButton`.
- [x] **AC-5:** Die Hinweiszeile „Sprich los oder tippe. Return speichert.“ steht nur, wenn das Mikrofon nicht lauscht und das Feld leer ist; „Listening …“ (#297) und die Diagnosezeile (#402) werden nicht verdrängt. Beleg: Sichtbefund im Galeriebild (Ruhezustand zeigt den Hinweis); Diff lässt `ListeningHint`-Zustand und `macDiagnosisLine` unverändert; bestehende Tests zu `listeningHint` und `speechDiagnosisLabel` grün; ggf. Unit-Test der Vorrangtabelle.
- [x] **AC-6:** Die Welle erscheint nur beim Hören, das Panel behält die feste ideale Höhe (`fixedSize` vertikal). Beleg: Diff (`fixedSize` bleibt um die Erfassung); Galeriebild zeigt im Ruhezustand ohne Welle dieselbe Panelhöhe wie die Prüfung der Rahmen in AC-7.
- [x] **AC-7:** „Abbrechen“, „Fertig“ und die Fußzeile („Loose Ends öffnen“, „Loose Ends beenden“) sind sichtbar und liegen innerhalb des Panel-Rahmens (#400). Beleg: `MacGalleryTests.testPanelLight` und `testPanelDark` prüfen `isHittable` und `frame`-Enthaltensein der vier Elemente im Panel-Fenster; Galeriebild bestätigt es.
- [x] **AC-8:** Die Fußzeile steht unter einer Haarlinie in grau 12 pt mit dem App-Wortlaut „Loose Ends öffnen“ und „Loose Ends beenden“; Kennungen `menuBarOpenApp`, `menuBarQuit` bleiben. Beleg: Galeriebild; Test findet beide Kennungen.
- [x] **AC-9:** Die Funktion bleibt unverändert: Return speichert und schließt das Panel, „Abbrechen“ schließt ohne Speichern; Bindungen, `onFinish`-Aufruf und Anreicherung (`processPending`) im Diff ungeändert; keine neuen AppStorage-Schlüssel, kein Modell-, Schema- oder Rechte-Eingriff. Beleg: Diff; bestehende UI-Tests mit den Kennungen und der volle Unit-Lauf grün.
- [x] **AC-10:** Dunkel funktioniert für das Panel unter `--ui-testing-dark` (`.preferredColorScheme(Self.uiTestColorScheme)`). Beleg: Foto `mac-gallery-panel-dark` zeigt dunkles Papier (`#171816`), geöffnet und beschrieben.
- [x] **AC-11:** iPhone, iPad und Fenster-⌘N bleiben Pixel für Pixel gleich: der Panel-Zweig hängt hinter `#if os(macOS)` **und** `onFinish != nil`. Beleg: Diff (Modifier-Kette der übrigen Zweige unverändert); iOS-UI-Smoke grün; iPhone-Simulatorbild der Erfassung vorher (`main`) und nachher dasselbe (beide beschrieben); `MacGalleryTests`-Bild des Fensters (falls vorhanden) unverändert.
- [x] **AC-12:** Die neuen Texte sind lokalisiert: „New task“ / „Neue Aufgabe“ und „Speak or type. Return saves.“ / „Sprich los oder tippe. Return speichert.“ stehen in `Localizable.xcstrings`. Beleg: Diff; deutsches Galeriebild zeigt die deutschen Texte.

## Dialog

### Runde 1
**Adversary:** Fordert für alle 12 ACs Belege. Nach Runde 1 sind AC-1, 2, 3, 7, 8, 10, 11 bewiesen; AC-4, 5, 6, 9, 12 offen (Akzent-Mikrofon, Höhe in Hören/Diagnose, Return-Pfad, deutsches Bild).
**Implementierer:** Developer-Agent ergänzt Akzent-Mikrofon nur im Panel (`restTint`), Mindesthöhe der Sprach-Zeile, drei Galerietests (Hören, Diagnose, Deutsch mit Return).
Code reference: LooseEnds/Views/CaptureView.swift:97
Code reference: LooseEnds/Mac/MenuBarCapture.swift:47

### Runde 2
**Adversary:** Öffnet die Bilder aus CI-Lauf 39419338619 (alle grün): typed-de (Akzentring, graues Abbrechen, aktive Akzentkapsel), de (deutsche Texte, Hinweis), listening, diagnosis (jeweils 440x340 wie Ruhezustand), de-saved-in-new (Aufgabe steht nach Return in Neu). Bewertet alle 12 ACs als bewiesen. Anmerkungen LOW-1 (Statuszweig needsModel/accessDenied ohne Bild, begrenzt durch minHeight 74), LOW-2 (Alert „Could not save“ im Panel und Abbrechen ohne eigenen Test, Funktion unverändert), MEDIUM (Umfang über 250 LoC, überwiegend Tests).
**Implementierer:** AC-10 Abweichung dokumentiert: `.preferredColorScheme` allein färbt das MenuBarExtra-Fenster nicht, deshalb `UITestDarkPanel` (nur mit `--ui-testing-dark`). AC-11 Fenster-⌘N nur per Diff, iPhone vorher/nachher gleich. Umfangsüberschreitung wird im Abschlussbericht genannt.
Code reference: LooseEnds/Views/CaptureView.swift:296
Code reference: LooseEnds/Mac/MenuBarCapture.swift:54
Code reference: LooseEnds/App/LooseEndsApp.swift:132

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**

## Geprüfte Dateien

- sha256:1a2f2635a47baecb85cb8d034c54d463ed353447855c3bdb780fd831d130cfbe  LooseEnds/App/LooseEndsApp.swift
- sha256:4f26854b7b54e7b09b529b9d40cdb7fe2b1825531707c0dca64fa11d6446c905  LooseEnds/Mac/MenuBarCapture.swift
- sha256:176a8f037707aef93087ce025fd0c9aeef2ced5e641c6b1e16aca321e2515483  LooseEnds/Views/CaptureView.swift

## Prüfbasis

- base: d12358c815d444b0bff3e6476e4225e4ebf96650
- blob:2b50246f502afec1ce4d4f8b9f8ddac01efb0b42  LooseEnds/App/LooseEndsApp.swift
- blob:5272a6d368bc9c33c3bf55c8e078b6309abaf709  LooseEnds/Mac/MenuBarCapture.swift
- blob:92c57441ab611f5959676218d8442d8ea0cf281e  LooseEnds/Views/CaptureView.swift

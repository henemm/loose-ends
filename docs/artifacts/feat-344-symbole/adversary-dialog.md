# Adversary Dialog — feat-344-symbole
Spec: docs/specs/feat-344-symbole.md
Datum: 2026-10-24 16:30

## Checkliste
- [x] **AC-1:** Given Wichtigkeit Niedrig, Mittel, Hoch / When `FieldGlyph.importance` fragt / Then `exclamationmark`, `exclamationmark.2`, `exclamationmark.3`. Belegt durch Unit-Test 1 (zuerst rot).
- [x] **AC-2:** Given die Felder Dringlichkeit, Fällig, Dauer, Projekt / When `FieldGlyph.symbol(for:)` fragt / Then `flame`, `calendar`, `clock`, `folder`; alle anderen Felder `nil`, und jeder Name ist ein vorhandenes Systemsymbol. Belegt durch Unit-Tests 2 bis 4.
- [x] **AC-3:** Given eine Aufgabe mit Wichtigkeit Hoch und Dringlichkeit Hoch / When die Listenzeile erscheint / Then stehen `exclamationmark.3` und `flame` in Tinte ohne Wort und ohne Farbe vor den übrigen Merkmalen (`importanceMarker_<id>`, `urgencyMarker_<id>`, Labels „Important“/„Urgent“); `flag.fill` und `bolt.fill` gibt es nirgends mehr. Belegt durch UI-Test A und Diff-Prüfung.
- [x] **AC-4:** Given Wichtigkeit oder Dringlichkeit Niedrig/Mittel oder nicht gesetzt / When die Listenzeile erscheint / Then zeigt sie kein Zeichen dafür (unverändert „nur bei Hoch“). Belegt durch UI-Test C.
- [x] **AC-5:** Given eine Aufgabe mit gesetzten Feldern Wichtigkeit, Dringlichkeit, Fällig, Dauer, Projekt / When das Detail öffnet / Then steht in jeder dieser Registerzeilen das Zeichen hinter dem Wert (`fieldGlyph_<field>`), Wichtigkeit nach Stufe. Belegt durch UI-Test B und C.
- [x] **AC-6:** Given die Registerzeile / When sie mit Zeichen erscheint / Then bleibt die Beschriftungsspalte (`labelWidth` 92, skaliert) unverändert, VoiceOver liest Beschriftung und Wert wie bisher (Zeichen `accessibilityHidden`), und der Wert behält seine Farbe (rot bei Zeitdruck, Akzent bei KI/Regel). Belegt durch Diff-Prüfung, UI-Test B und die geöffneten Simulatorbilder.
- [x] **AC-7:** Given `docs/project/03-design-briefing.md` / When geprüft / Then beschreibt Zeile 110 Ausrufezeichen-Leiter und Flamme statt Fahne und Blitz. Belegt durch Diff-Prüfung.
- [x] **AC-8:** Given der Diff / When er geprüft wird / Then berührt er nur die genannten Dateien, kein Pfad der Geräteliste; kein `try?`, kein `print`, kein Emoji, nur SF Symbols; alle bestehenden Unit- und UI-Tests und der iOS-Bau sind grün.

## Dialog

### Runde 1
**Adversary:** Angriffe (a) bis (g) gegen Diff, Spec, Belege und die Bilder 88E8C5D7 (Detail) und A27162F0 (Liste).
- (a) `flag.fill`/`bolt.fill` übrig? Nein, nur Negativprüfung im Test und Doku. Code reference: LooseEnds/Views/TaskRow.swift:162
- (b) watchOS-Sicherheit: `FieldGlyph` nur Foundation, das Build-Log übersetzt es für Widgets, Share und Watch ohne Fehler. Code reference: Shared/Models/FieldGlyph.swift:5
- (c) Randfälle `glyph(for:)`: Importance nil gibt kein Zeichen, leere Werte haben keine Zeile. Code reference: LooseEnds/Views/TaskDetailView.swift:762
- (d) Identifier-Kollisionen: keine; Labels "Important"/"Urgent" je einmal. Code reference: LooseEnds/Views/TaskDetailView.swift:729
- (e) `labelWidth` steht nicht im Diff, die Spalte ist im Bild bündig.
- (f) kein `try?`, kein `print`, kein Emoji im Diff.
- (g) AC-4 „nur bei Hoch“: Code unverändert, aber UI-Test C fehlt. Code reference: LooseEndsUITests/FieldsSmokeTests.swift:177
- F001 (MEDIUM): Beleg für AC-4 fehlt. F002 (LOW): Niedrig und Mittel im Detail ohne UI-Beleg, kein Dunkelbild.
- Zwischenverdict: AMBIGUOUS.

**Implementierer:** UI-Test C `testLowAndMediumShowNoSignInTheRowButTheLadderInTheDetail` nachgeliefert (Wichtigkeit Medium, dann Low, Dringlichkeit Low per Editor, danach Liste ohne Zeichen). `test-proof FieldsSmokeTests` 5/5 grün, Bilder 344-3, 344-4, 344-5 geöffnet und beschrieben. Dunkel-Rest begründet (nur `.primary` und `.secondary`). Ticket für die unverdrahtete `DurationRule` wird angelegt.

### Runde 2
**Adversary:** Nachprüfung ohne Simulatorlauf.
- Die negative Prüfung ist nicht trivial: `taskRow_` ist der echte Identifier, der Test wartet auf die Zeile, die Marker-Identifier prüft Test B positiv. Code reference: LooseEnds/Views/TaskRow.swift:54
- AC-4 und AC-5 (Stufen) sind belegt durch Test C und die Bilder 344-3 („!!“), 344-4 („!“ und Flamme), 344-5 (Zeile ohne Zeichen). Code reference: LooseEndsUITests/FieldsSmokeTests.swift:187
- `choose` sucht die Option nur nach Label (Robustheitsrisiko, kein Fehlbeleg).
- Dunkel: keine festen Farben im Diff, vertretbar. Code reference: docs/project/03-design-briefing.md:110
- Dauer und Projekt nur per Unit-Test, akzeptiert, Ticket für `DurationRule` als Auflage.
- F001 behoben, F002 behoben, das fehlende Dunkelbild als LOW-Hinweis akzeptiert.

**Implementierer:** Keine Einwände.

## Belege (Code-Stellen)

Code reference: LooseEnds/Views/TaskDetailView.swift:729
Code reference: LooseEnds/Views/TaskRow.swift:162
Code reference: Shared/Models/FieldGlyph.swift:7
Code reference: LooseEndsTests/FieldGlyphTests.swift:40
Code reference: LooseEndsUITests/FieldsSmokeTests.swift:187

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). `FieldGlyph` schreibt nichts, keine Verdachtszeile.

## Verdict
VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:57d32b967c4500ae6d6c46e044c4fafa28c1351e7ff9e8ffc53f07f12a86f598  LooseEnds/Views/TaskDetailView.swift
- sha256:ba129b9279d51ba5be5c5116a4e79f9875964c782ea611a8da126e704b808462  LooseEnds/Views/TaskRow.swift
- sha256:cb2d691d2b0d8ce46dc4ecc236b5e3c9f08735eb46ebc84cc183956ed2a6ad15  LooseEndsTests/FieldGlyphTests.swift
- sha256:8dec7f1bc1a96a8d594d402c64dc38892353c74200400a63f0025e054cb801d6  LooseEndsUITests/FieldsSmokeTests.swift
- sha256:f5bf44770a7a73b4e2b3a4a9b0f9d1898884267b5945ffdf6bfb9a1662f47473  Shared/Models/FieldGlyph.swift

## Prüfbasis

- base: 4d3649538149471671f607427c2746e762ac7d22
- blob:190fafbc9db45308a71c9e2d86cf0fe6837880e9  LooseEnds/Views/TaskDetailView.swift
- blob:4a831966420e0646b357ab042be5865a35fb1105  LooseEnds/Views/TaskRow.swift
- blob:6ae6430f468a1667ed22908a995802eab05862fc  LooseEndsTests/FieldGlyphTests.swift
- blob:6f21a6f981b6797d8865da2a0e7852e94b49a6b5  LooseEndsUITests/FieldsSmokeTests.swift
- blob:c3f245e984a8d7b06bbce7b74c7d7b0157df06d6  Shared/Models/FieldGlyph.swift

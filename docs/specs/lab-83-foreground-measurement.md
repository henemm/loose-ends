# Spec: #83 — Labor-App misst nur im Vordergrund und schreibt ihren Lebenslauf mit

## Problem
Die Labor-App (#79) misst nach dem Tippen im Hintergrund weiter. Am Akku im Hintergrund drosselt
Apple das Modell (Apple DTS: Akku **und** Hintergrund, etwa vier Anfragen in 30 Sekunden, danach
Sperre für Minuten). Am 2026-09-20 ging die App 30 Sekunden nach dem Start durch die Autosperre in
den Hintergrund; der nächste Aufruf scheiterte, die App schob ohne Pause zwei weitere nach und
stand still. Die Datei enthält nur Ergebnisse, nicht den Lebenslauf der App — ein Fehler im Code
und eine Systembedingung sehen darin gleich aus. Henning: „Bist du dir sicher, ob du zwischen deinen
Fehlern und Messwerten unterscheiden kannst?"

## Acceptance Criteria

- **AC-1 Nur Vordergrund:** Given die Messung läuft / When die App den Vordergrund verlässt
  (Sperre, App-Wechsel, Kontrollzentrum) / Then hält die Messung an, der Stand bleibt erhalten, und
  in der Ergebnisdatei steht der Szenenwechsel als Ereignis mit Zeitstempel. Von selbst startet
  nichts neu; ein Tipp auf „Weitermessen" setzt fort.
- **AC-2 Bildschirm wach:** Given die Messung läuft / When der Nutzer nichts berührt / Then sperrt
  sich das Gerät nicht von selbst; nach Anhalten oder Ende gilt die normale Sperre wieder.
- **AC-3 Kein Hintergrundlauf:** Given die App / When sie gebaut wird / Then meldet sie keine
  Hintergrundmodi mehr an und enthält keinen Code für Hintergrundaufgaben.
- **AC-4 Taktung nach Fehlschlag:** Given ein Satz ist fehlgeschlagen / When der nächste ansteht /
  Then wartet die App 60 Sekunden (abbrechbar über „Anhalten"), und die Wartezeit steht als
  Ereignis in der Datei. Nach drei Fehlschlägen in Folge hält die App an und nennt den Grund.
- **AC-5 Typisierte Fehlerart:** Given ein Aufruf scheitert / When das Ergebnis gesichert wird /
  Then trägt es die Fehlerart aus dem Fehlertyp des Frameworks (rateLimited, guardrail,
  assetsUnavailable, contextWindow, decoding, unsupported, refusal, concurrent, timeout, andere),
  nicht aus einem Textvergleich der Meldung.
- **AC-6 Lebenslauf:** Given die App läuft / When etwas geschieht / Then steht es als Ereignis
  (Zeit, Art, Notiz) in derselben Datei: App gestartet (mit Startargumenten), Modellverfügbarkeit,
  Messen/Anhalten getippt oder per Startargument, Szenenwechsel, Fehlschlag mit Art, Wartezeit,
  Ende der Reihe. Jedes Ereignis wird sofort gesichert.
- **AC-7 Alte Dateien:** Given die vorhandene Ergebnisdatei vom 2026-09-20 / When sie gelesen
  wird / Then bleibt sie lesbar; Ereignisse sind leer, Fehlerart fehlt.
- **AC-8 Fernstart mit Protokoll:** Given das iPhone ist im WLAN und entsperrt / When der Mac
  `lab-run [Sekunden]` ausführt / Then startet die App mit `--measure`, der Mac schreibt Start und
  Stopp mit Zeitstempel in `Measurement/results/lab-run.log`, beendet die App nach Ablauf und holt
  die Ergebnisdatei.
- **AC-9 Bestehende Tests:** Given der Funktionsumfang / When Unit-Tests laufen / Then bleiben
  alle grün, einschließlich Bericht und Korpus-Regelwerk.

## Änderung
- `Measurement/MeasurementRun.swift`: `MeasurementEvent` (at, kind, note), `events` im Run mit
  abwärtskompatiblem Decoder, `log(_:_:at:)`, `errorKind` im Ergebnis, `MeasurementPacing`
  (Wartezeit 60 s, Abbruch nach 3), `MeasurementErrorKind.classify(_:)` über die Fälle von
  `LanguageModelSession.GenerationError` und `LanguageModelError`.
- `LooseEndsLab/MeasurementRunner.swift`: Hintergrundlauf und `BackgroundTasks` entfernen;
  `isIdleTimerDisabled` während der Messung; `scene(_:)` loggt und hält an; Schleife mit
  `MeasurementPacing` und abbrechbarem `Task.sleep`; Ereignisse für Start, Stopp, Fehlschlag,
  Wartezeit, Ende; Fehlerart je Ergebnis.
- `LooseEndsLab/LabApp.swift`: `scenePhase` an den Runner; Startargument als Ereignis; Fußtext:
  misst nur, solange die App offen ist, Bildschirm bleibt an, am besten am Strom.
- `project.yml`: `UIBackgroundModes` und `BGTaskSchedulerPermittedIdentifiers` am Lab-Target entfernen.
- `scripts/sim.sh`: `lab-run [Sekunden]` (Standard 40).

## Tests
- `LooseEndsTests/MeasurementRunTests.swift` (RED, liegt vor): alte Datei lesbar (AC-7),
  Ereignisse und Fehlerart überleben Schreiben und Lesen (AC-6, AC-5), Taktregel (AC-4),
  Fehlerklassen typisiert (AC-5).
- Nachweis ohne Tests (Labor-App hat keine UI-Tests, Simulator hat kein Modell): Simulator-Lauf
  mit `--measure` zeigt drei Fehlschläge, zwei Wartezeiten, Anhalten mit Grund, alle Ereignisse in
  der Datei (AC-1/4/6). iPhone-Lauf per `lab-run`: Sätze gemessen, Autosperre erzeugt Ereignis
  und Anhalten (AC-1/2/8). Beide Dateien werden im PR gezeigt.

## Nicht Teil dieser Änderung
Die Messreihe selbst und der Bericht (#67), der erweiterte Korpus (#82), Änderungen an der
Produkt-App.

## Umfang
6 Dateien (zwei davon je unter 15 Zeilen), etwa +190/-70 Zeilen. Über der 4–5-Dateien-Grenze,
weil Projektdefinition und Skript je wenige Zeilen mitziehen; keine Aufteilung sinnvoll.

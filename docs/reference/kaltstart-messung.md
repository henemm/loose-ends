# Kaltstart in die Erfassung (#22)

Gemessen am 2026-10-08. Spec: `docs/specs/measurement/spike-22-kaltstart.md`.

## Ergebnis

**Vom Prozessstart bis „Mikrofon hört“ vergehen im Mittel 558 ms** (Median 556 ms, Maximum 590 ms,
10 Kaltstarts). Den ersten Ton liefert das Mikrofon nach 650 ms (Maximum 682 ms). Das Budget aus ADR-9
(unter einer Sekunde) hält der App-Teil damit mit rund 440 ms Reserve.

| | |
|---|---|
| Gerät | iPhone 16 Pro (`iPhone17,1`), Näherung für das Mindestgerät iPhone 15 Pro |
| System | iOS 27.0 (24A437) |
| Bau | „LE Prüfbau“ (`com.henning.looseends.probe`), **Release**, 0.1.0 (1) |
| Weg | `./scripts/sim.sh launch-measure 11`: `devicectl … --terminate-existing … -measureLaunch` |
| Läufe | 11, davon der erste verworfen (erster Start nach der Installation) |
| Nullpunkt | Prozessstart (`kp_proc.p_starttime`), alle Läufe `zeroPoint: processStart` |
| Rohdaten | `docs/artifacts/spike-22-kaltstart/reihe1-launch-timings.json` |

## Wohin die Zeit geht (Mittel der 10 gewerteten Läufe, ms)

| Abschnitt | Von → bis | Mittel | Median | Max |
|---|---|---|---|---|
| Prozessstart → `init` | dyld, Laufzeit | 10,6 | 10,2 | 12,5 |
| `init` gesamt | `LooseEndsApp.init` | 32,1 | 31,3 | 35,5 |
| davon Datenbank | `ModelContainerFactory.make()` (App-Gruppe + CloudKit) | 23,9 | 23,7 | 25,7 |
| `init` → Erfassung erscheint | SwiftUI-Aufbau: Hauptansicht, dann Sheet | **223,6** | 220,6 | 242,3 |
| Erfassung → `speech.start()` | Task-Start | 57,8 | 55,6 | 74,2 |
| Sprachmodell + Rechte prüfen | bis `AssetInventory` meldet bereit | 71,4 | 69,5 | 87,2 |
| Analyzer starten | `SpeechAnalyzer.start` | 13,5 | 13,5 | 15,4 |
| Mikrofon anwerfen | Audio-Sitzung + `AVAudioEngine.start` | **148,6** | 148,5 | 151,5 |
| **Gesamt** | Prozessstart → `.listening` | **558,0** | 555,7 | 589,8 |

Die zwei größten Posten sind der Aufbau der Oberfläche bis zur Erfassung (40 %) und das Anwerfen des
Mikrofons (27 %). Die Datenbank mit CloudKit, die im Ticket als Verdacht stand, kostet nur 4 %.

### Rohwerte je Lauf (ms)

| Lauf | processToInit | initialization | container | initToCapture | captureToSpeechStart | modelCheck | analyzer | engine | total | firstBuffer |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 (verworfen) | 107 | 26 | 20 | 255 | 48 | 86 | 7 | 184 | 713 | 805 |
| 2 | 9 | 30 | 22 | 238 | 58 | 71 | 14 | 151 | 571 | 663 |
| 3 | 10 | 34 | 26 | 224 | 55 | 73 | 15 | 149 | 560 | 652 |
| 4 | 11 | 36 | 26 | 217 | 56 | 68 | 13 | 148 | 549 | 641 |
| 5 | 10 | 35 | 25 | 222 | 59 | 77 | 14 | 147 | 564 | 656 |
| 6 | 12 | 31 | 24 | 214 | 74 | 73 | 14 | 149 | 567 | 659 |
| 7 | 10 | 31 | 22 | 242 | 61 | 87 | 14 | 145 | 590 | 682 |
| 8 | 12 | 32 | 23 | 221 | 53 | 68 | 13 | 151 | 551 | 643 |
| 9 | 10 | 31 | 23 | 220 | 53 | 62 | 11 | 151 | 539 | 630 |
| 10 | 10 | 30 | 24 | 220 | 54 | 68 | 14 | 147 | 542 | 635 |
| 11 | 11 | 31 | 25 | 219 | 56 | 66 | 12 | 148 | 546 | 635 |

`container` liegt innerhalb von `initialization`; die übrigen Abschnitte addieren sich zur Gesamtzeit.
Der verworfene erste Lauf zeigt den Effekt kalter Caches nach der Installation: 713 ms, davon 107 ms vor `init`.

## Was diese Messung nicht zeigt

- **Die Zeit vom Druck auf Control oder Aktionstaste bis zum Prozessstart.** Sie läuft im System,
  bevor App-Code existiert. Geplant war, sie als Differenz zu einer Reihe echter Drücke zu bestimmen
  (Spec, Reihe 2 und 3 nach Geräteneustart). **Henning hat diese Reihe am 2026-10-08 abgewählt**
  („schließe das ab, das brauche ich nicht“). Die 558 ms sind deshalb die Untergrenze ohne den
  Intent-Weg. Apples Richtwert für den Systemanteil bis zum ersten Bild liegt bei ~100 ms
  ([WWDC19 423](https://developer.apple.com/videos/play/wwdc2019/423/)), ein Forenbericht nennt
  „mehrere Sekunden“ für Intents bei nicht laufender App unter iOS 18
  ([Forum 761677](https://developer.apple.com/forums/thread/761677)). Gemessen ist das hier nicht.
- **Das Mindestgerät.** Gemessen auf dem iPhone 16 Pro (vom Ticket als Näherung erlaubt). Ein
  iPhone 15 Pro ist langsamer, um wie viel, ist nicht gemessen.
- **Warmstart** (App nur suspendiert): ohne neuen Prozess kein Nullpunkt, nicht Teil des Tickets.

## Befunde neben der Zahl (berichtet, nicht geändert)

1. **Die Erfassung ist keine eigene schlanke Szene**, sondern ein Sheet über der vollen Hauptansicht
   (`ContentView.swift`). ADR-9 verlangt „schlanke Erfassungs-Szene, kein Laden“. Der größte Posten
   (223 ms bis die Erfassung erscheint) ist genau dieser Aufbau.
2. **Das Textfeld wird bei gewollter Sprache nicht fokussiert** (`CaptureView.begin()`). ADR-9 nennt
   „Mikrofon hört, Textfeld fokussiert“. Gemessen wurde deshalb „Mikrofon hört“ (`.listening`).

## Folge

Das Budget hält im gemessenen Teil; ein Folge-Ticket zur Optimierung ist **nicht nötig** (AC-12).
Wird der Systemanteil später einmal spürbar, sind die beiden Hebel belegt: eine eigene Erfassungs-Szene
ohne Hauptansicht (bis ~220 ms) und das Mikrofon früher anwerfen (bis ~150 ms). Die Messung ist
jederzeit wiederholbar: `./scripts/sim.sh launch-measure 11`.

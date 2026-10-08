---
entity_id: spike-22-kaltstart
type: feature
created: 2026-10-08
updated: 2026-10-08
status: draft
workflow: spike-22-kaltstart
---

# Spec: Spike #22 — Kaltstart in die Erfassung unter einer Sekunde (Messung)

**Status:** draft · **Workflow:** spike-22-kaltstart · **Erstellt:** 2026-10-08 · **Aktualisiert:** 2026-10-08

## Approval

- [ ] Approved

## Purpose

ADR-9 setzt ein Budget: Die Erfassung ist nach einem Kaltstart in unter einer Sekunde eingabebereit
(Mikrofon hört, Textfeld fokussiert), Mindestgerät iPhone 15 Pro (Entscheidung #19). Ob das stimmt,
wurde nie gemessen (`docs/project/02-datenmodell-und-ansichten.md`, offener Punkt 3). Issue #22 verlangt
die Messung: ~10 Läufe, Mittelwert und Ausreißer, bei Verfehlung Ursache eingrenzen und ein Folge-Ticket
mit Optimierungsvorschlag.

Diese Spec **misst nur**. Sie baut kostenarme Messpunkte in den Startpfad (Signposts immer, eine
Zeitstempel-Datei nur im Prüfbau), einen Messbefehl in `scripts/sim.sh` und führt zwei Messreihen auf
Hennings iPhone 16 Pro (Näherung für das iPhone 15 Pro): Reihe 1 automatisiert per `devicectl` (Untergrenze
ohne Intent-Pipeline), Reihe 2 über den echten Weg (Henning drückt das Control des Prüfbaus). Das Ergebnis
geht in einen Messbericht, in offenen Punkt 3 und in `04-stand.md`. Optimierung, Umbau und Fokusänderung
sind **nicht** Teil dieser Spec; sie wären das Folge-Ticket.

**Befunde aus der Analyse, die berichtet, aber nicht geändert werden:**

- Die „Erfassungs-Szene" ist heute ein `.sheet` über der vollen Hauptansicht (`NavigationSplitView`, `@Query`),
  geöffnet in `ContentView.onAppear`/`onChange(pending)` (`ContentView.swift:55-57, 73-74, 161-165`), keine
  eigene schlanke Szene. Das widerspricht ADR-9 („schlanke Erfassungs-Szene, kein Tab, kein Laden").
- Das Textfeld wird bei gewollter Sprache **nicht** fokussiert (`CaptureView.swift:134-140`); ADR-9 sagt
  „Textfeld fokussiert". „Eingabebereit" wird deshalb als `SpeechCapture.state == .listening` gemessen
  (Zweitwert: erster Audiopuffer); die Abweichung steht im Bericht.
- Beim Start laufen parallel Seeder, `mergeDuplicateContexts`/`mergeEnglishDefaults` + `save()` auf dem
  MainActor, `processPending`, Mitteilungs-Freigabe, `reschedule`, `calendar.sync` (`ContentView.swift:107-129`).

## Source

- **File:** `LooseEnds/App/LaunchTimings.swift` (neu) — **Identifier:** `enum LaunchTimings` (Messpunkte, Signposter), reine Teile `LaunchTimings.sections(from:)`, `LaunchTimings.append(run:to:)`, `LaunchTimings.isProbeBuild(bundleID:)`
- **File:** `LooseEnds/App/LooseEndsApp.swift` — **Identifier:** `LooseEndsApp.init()`
- **File:** `LooseEnds/Views/CaptureView.swift` — **Identifier:** `onAppear` (Zeile ~73)
- **File:** `LooseEnds/Speech/SpeechCapture.swift` — **Identifier:** `start()` (Zeilen ~172-210, `state = .listening` bei ~208), Tap-Callback (~319-320)
- **File:** `scripts/sim.sh` — **Identifier:** `cmd_launch_measure`, Release-Variante von `cmd_device_build`/`device_app_path`

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `OSSignposter` (`os`) | Upstream, API | Intervalle/Events, Release-tauglich, kostenarm; Apples Standard für Startmessung ([Forum 761677](https://developer.apple.com/forums/thread/761677)) |
| `sysctl` `KERN_PROC_PID` → `kp_proc.p_starttime` | Upstream, System | Nullpunkt Prozessstart, damit die Zeit vor `main` (dyld) mitzählt |
| `OpenCaptureIntent`, `CaptureRequest.shared.pending` (`Shared/Intents/CaptureTextIntent.swift`) | Upstream | Auslöser des echten Wegs; das Startargument setzt `pending` dem Intent nachgebildet |
| `ModelContainerFactory.make()` | Upstream | Messpunkt um den Aufruf, Code unverändert |
| `SpeechCapture` (SpeechAnalyzer seit #64) | Upstream | Messpunkte im bestehenden Ablauf, Ablauf unverändert |
| Prüfkennung `com.henning.looseends.probe` (#156, ADR-18), `devicectl`-Befehle in `sim.sh` (#153, #226) | Werkzeug | Installation neben Hennings Alltags-App; Datei lesend per `devicectl device copy from` |
| ADR-9, Entscheidung #19 (`docs/project/00-entscheidungen.md`) | Downstream | Das Budget, gegen das gemessen wird; wird nicht geändert |
| `LooseEndsUITests/CaptureSmokeTests`, `SpeechListeningTests` | Downstream | Bleiben unverändert grün (Messpunkte ändern kein Verhalten) |

## Scope

### Affected Files

| File | Change Type | Beschreibung |
|---|---|---|
| `LooseEnds/App/LaunchTimings.swift` | CREATE | Signposter, Zeitstempel je Messpunkt im Speicher (Nullpunkt Prozessstart), reine Rechenteile, JSON-Datei nur im Prüfbau, genau einmal pro Prozess (~70 LoC) |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | Messpunkte `init` Anfang/Ende und um `ModelContainerFactory.make()`; Startargument `-measureLaunch` setzt `CaptureRequest.shared.pending` (~15 LoC) |
| `LooseEnds/Views/CaptureView.swift` | MODIFY | Messpunkte „Erfassung erscheint" und „`speech.start()` aufgerufen" (~5 LoC) |
| `LooseEnds/Speech/SpeechCapture.swift` | MODIFY | Messpunkte „Modell bereit", „Analyzer gestartet", „`engine.start`", „`.listening`", „erster Audiopuffer" (löst das Schreiben aus) (~10 LoC) |
| `scripts/sim.sh` | MODIFY | Release-Variante des Prüfbaus, `launch-measure <n>`, Abholen der Datei (~50 LoC) |
| `LooseEndsTests/LaunchTimingsTests.swift` | CREATE | Unit-Tests der reinen Teile (~60 LoC) |
| `LooseEndsUITests/LaunchArgumentTests.swift` | CREATE | UI-Test Startargument (~30 LoC) |
| `docs/reference/kaltstart-messung.md` | CREATE | Messbericht |
| `docs/project/02-datenmodell-und-ansichten.md`, `docs/project/04-stand.md` | MODIFY | Ergebnis in offenem Punkt 3, Stand |

### `project.yml` bleibt unberührt

Die Release-Variante braucht keine Änderung an `project.yml`: `signed_build` reicht beliebige Argumente an
`xcodebuild` durch, und `-configuration Release` überschreibt die Konfiguration auf der Kommandozeile. Die
Kennung kommt wie bisher aus `BUNDLE_ID_SUFFIX=.probe`, die Signierung aus denselben gespeicherten Profilen (#156).
Wäre dennoch eine Änderung an `project.yml` oder einer Entitlements-Datei nötig (etwa weil Release
anders signiert), stoppt die Umsetzung und fragt nach, statt sie nebenbei zu machen. Auch ohne diese Änderung
gilt die Geräteliste wegen `LooseEnds/Speech/` (siehe Test Plan).

### Scope-Prüfung

- **Code-Dateien: 5** (eine neu): `LaunchTimings.swift`, `LooseEndsApp.swift`, `CaptureView.swift`,
  `SpeechCapture.swift`, `sim.sh`. Das bleibt innerhalb von 4–5.
- **Zusätzlich** zwei Testdateien (neu) und drei Dokumentationsdateien. Tests und Docs zählen im Projekt nicht gegen
  die 4–5 Code-Dateien (so auch in #156, #145); sie sind hier offen genannt, damit die Prüfung nichts übersieht.
- **LoC:** Produktivcode ~+150/-5 (Analyse), Tests ~+90. Zusammen ~+245, an der Grenze von ±250. Wächst es darüber,
  stoppt die Umsetzung und schlägt vor, die UI-Test-Datei oder `launch-measure` abzuspalten.
- Jede Funktion ≤ 50 LoC; keine Seiteneffekte außerhalb des Tickets.

## Implementation Details

### 1. `LaunchTimings`

- **Signposts immer:** ein `OSSignposter` (Subsystem `com.henning.looseends`, Kategorie `Launch`). Die Abschnitte
  sind Intervalle (`init`, `ModelContainer`, Erfassung → hört), die übrigen Punkte Events. Kostenarm, bleibt im Produkt
  (Dauerlauf #73).
- **Nullpunkt:** `kp_proc.p_starttime` des eigenen Prozesses über `sysctl` (`CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()`).
  Schlägt der Aufruf fehl, ist der Nullpunkt der erste Messpunkt, und der Lauf trägt `zeroPoint: "firstPoint"` statt
  `"processStart"`; Fehler gehen als `Logger`-Fehler ins Protokoll (kein `try?`, das schluckt).
- **Zeitstempel je Messpunkt** im Speicher (Name → Millisekunden seit Nullpunkt, monotone Uhr; Differenz zur Wanduhr einmalig
  beim Nullpunkt gebildet). Das Setzen eines Punktes ist ein Dictionary-Eintrag unter einer Sperre: keine Datei, kein Log.
  Swift 6: der Zustand liegt in einer `Sendable`-Klasse mit `OSAllocatedUnfairLock` oder einem Actor-freien Äquivalent,
  weil die Punkte von MainActor und dem Audio-Callback kommen.
- **Datei nur im Prüfbau:** `Documents/launch-timings.json`. Geschrieben wird **genau einmal pro Prozess**, nicht pro
  Punkt (Datei-I/O im Startpfad verfälscht die Messung). Auslöser ist der erste Audiopuffer, der nach `.listening`
  eintrifft. Damit liegen beide Messpunkte schon im Speicher, bevor geschrieben wird, und das Schreiben liegt hinter
  der Messstrecke. Kommt binnen 3 s nach `.listening` kein Puffer, wird ohne ihn geschrieben (`firstBuffer: null`), und der
  Bericht nennt das. Geschrieben wird auf einer eigenen Hintergrund-Queue, nie im Audio-Callback und nie auf dem MainActor.
- **Prüfbau-Erkennung:** `isProbeBuild(bundleID:)` ist wahr, wenn die Bundle-ID auf `.probe` endet. Ohne Prüfbau gibt es
  keinerlei Datei-I/O (kein Anlegen, kein Lesen).
- **Dateiinhalt:** ein JSON-Array von Läufen. Ein Lauf: `kind` (`"automated"` bei vorhandenem Startargument, sonst `"press"`),
  `build` (Version + Build-Nummer), `os`, `device` (Modellkennung), `zeroPoint`, `points` (Name → ms) und `sections`
  (siehe 2). Läufe werden **angehängt**: die Datei sammelt alle Läufe über Prozesse hinweg. Eine beschädigte
  Bestandsdatei wird nicht überschrieben, sondern als `launch-timings.corrupt-<Zeitstempel>.json` beiseitegelegt, dann beginnt eine neue.
- **Reine Teile (testbar ohne Gerät):** `sections(from:)` (Punkte → Abschnitte), `append(run:to:)` (Daten rein, Daten raus),
  `isProbeBuild(bundleID:)`, `WriteOnce` (Schalter „bereits geschrieben" je Prozess).

### 2. Messpunkte und Abschnitte

| Messpunkt (Name) | Ort |
|---|---|
| `initStart` / `initEnd` | `LooseEndsApp.init` Anfang/Ende |
| `containerStart` / `containerEnd` | um `ModelContainerFactory.make()` |
| `captureAppeared` | `CaptureView.onAppear` |
| `speechStartCalled` | unmittelbar vor `speech.start()` |
| `modelReady` | `AssetInventory.status == .ready` festgestellt |
| `analyzerStarted` | nach `SpeechAnalyzer.start(inputSequence:)` |
| `engineStarted` | nach `engine.start()` |
| `listening` | bei `state = .listening` (Hauptwert „eingabebereit“) |
| `firstBuffer` | erster Audiopuffer im Tap (bei „Ton kommt an"), löst das Schreiben aus (sonst nach 3 s Zeitlimit) |

Abschnitte (aus Differenzen): Prozessstart → `initStart` (dyld + Laufzeit), `init` (Start → Ende), Container, `initEnd` →
`captureAppeared` (SwiftUI-Aufbau bis Erfassung), `captureAppeared` → `speechStartCalled`, Modellprüfung/Rechte
(`speechStartCalled` → `modelReady`), Analyzer, Engine, und die Gesamtzeit Prozessstart → `listening`. Fehlt ein Punkt
(etwa `modelReady`, wenn das Modell fehlt), fehlen die angrenzenden Abschnitte; sie werden nicht geraten.

### 3. Startargument

`-measureLaunch` in `LooseEndsApp.init` setzt `CaptureRequest.shared.pending` auf den Zustand, den `OpenCaptureIntent` setzt.
`ContentView` bleibt unverändert und öffnet das Erfassungs-Sheet über denselben Pfad wie beim echten Control-Druck. Ohne
das Argument ändert sich nichts. Das Argument ist in jedem Build wirksam (`devicectl` kennt keine Prüfbau-Weiche), wirkt aber nur,
wenn jemand es mitgibt.

### 4. `scripts/sim.sh`

- **Release-Prüfbau:** neues Kommando `device-build-release` (Auslieferung wie `device-build`, aber `-configuration Release`,
  Produktpfad `Release-iphoneos`); `device_app_path` bekommt einen Konfigurationsparameter, Standard bleibt Debug.
  Debug taugt nicht für „unter 1 s" (unoptimiert, Debug-Dylib) und dient nur dem Trockenlauf.
- **`launch-measure <n>`:** startet `n` Kaltstarts per `devicectl device process launch --terminate-existing` mit
  `-measureLaunch`, wartet zwischen den Läufen auf das Schreiben der Datei (Abfrage per `copy from`, Zeitlimit), holt am Ende die Datei
  nach `build/launch-timings/` und gibt die Rohwerte aus. Rückgabewerte von `devicectl` über `PIPESTATUS`, nie über `tail`
  (Lehre aus #144).
- Alles läuft unter der Prüfkennung; Hennings Alltags-App (TestFlight/Production) wird weder installiert noch beendet
  noch gestartet (#153, #156). Das Abholen der Datei ist ein lesender Zugriff (`devicectl device copy from`, wie in #226 Schnitt 2b).

### 5. Messreihen

| Reihe | Weg | Läufe | Aussage |
|---|---|---|---|
| 1a automatisiert, kalt | `devicectl --terminate-existing` + `-measureLaunch` | 10 (+1 verworfen) | Untergrenze: ohne Intent-Pipeline und ohne Systemanteil vor dem Prozess |
| 2 echter Weg, kalt | Henning drückt das Control des Prüfbaus (Aktionstaste vorübergehend umbelegt, danach zurück); danach App im App-Umschalter beenden | 10 (+1 verworfen) | die Nutzersicht ab App-Prozess; der Anteil vor dem Prozess zeigt sich als Differenz zu Reihe 1 |
| 3 nach Neustart | Gerät neu gestartet, Control gedrückt | 1–2 | Ausreißerprobe (dyld-Caches kalt) |

Regeln: Der erste Lauf nach der Installation wird verworfen (Onboarding, Rechtedialoge). Vorbedingung ist ein installiertes
Sprachmodell (sonst `.needsModel`, gemessen würde die falsche Strecke). **Kalt = Prozess beendet**. Einen Warmstart (App nur
suspendiert) misst dieser Spike nicht: Ohne neuen Prozess gibt es keinen Prozessstart als Nullpunkt, und `init` läuft nicht.
Das Ticket fragt nur nach dem Kaltstart; ein warmer Start ist der günstigere Fall und deckt die Frage nicht ab. Bei Reihe 2 sagt Claude jeden Lauf an und holt die Datei ab; Henning drückt nur.

### 6. Messbericht

`docs/reference/kaltstart-messung.md`: Rohwerte je Lauf, Mittelwert, Median, Maximum, Abschnitte je Messpunkt, Gerät
(Modell, Marketing-Name), OS, Build, Art der Reihe, Zahl der verworfenen Läufe, und die beiden Befunde (Sheet statt Szene,
Textfeld ohne Fokus). Ergebnis in `02-datenmodell-und-ansichten.md` (offener Punkt 3: Mittelwert, Läufe, Gerät) und
`04-stand.md` (Verweis, kein Backlog). Bei Verfehlung (Mittelwert Reihe 2 ≥ 1 s) entsteht ein Folge-Issue mit einem konkreten
Vorschlag aus dem größten Abschnitt. Der Bericht führt wie jeder Messbericht des Projekts die Nulllinie: die Untergrenze aus Reihe 1.

### Regeln vor Modell

Nicht einschlägig: Es wird keine abgeleitete Aufgabenfeld-Eigenschaft erzeugt und kein Sprachmodell befragt. Die Messung
ist reine Zeitnahme.

### Nicht in diesem Ticket

Jede Optimierung (`startUp` verschieben, Container verzögern, Modell vorwärmen), der Umbau zur eigenen schlanken Szene,
die Fokusänderung am Textfeld, ein Minimal-App-Target, die Video-Gegenprobe.

## Expected Behavior

- **Input:** Start des Prüfbaus (Release) per `devicectl` mit `-measureLaunch` oder per Druck auf das Control.
- **Output:** eine neue Eintragszeile in `Documents/launch-timings.json` im Container des Prüfbaus; Signposts im
  Unified Log; Produktbau (Kennung ohne `.probe`) schreibt nichts.
- **Side effects:** keine Verhaltensänderung der App ohne Startargument; ein Dateischreibvorgang pro Prüfbau-Prozess, nicht im
  heißen Pfad vor `.listening`, sondern nach dem ersten Puffer (bzw. dem 3-s-Zeitlimit) auf einer Hintergrund-Queue; keine Datei-I/O in Produktbauten.

## Test Plan

### Automated Tests (TDD RED zuerst)

`LooseEndsTests/LaunchTimingsTests.swift` (Swift Testing, wie im Projekt):

- `sections(from:)`: aus festen Punkten (z. B. `initStart` 120, `initEnd` 180, `containerStart` 130, `containerEnd` 170, …) entstehen
  exakt die erwarteten Abschnitte in Millisekunden; fehlt ein Punkt, fehlen genau die angrenzenden Abschnitte, nichts wird geraten.
- `append(run:to:)`: Anhängen an eine bestehende Datei mit zwei Läufen ergibt drei Läufe, die alten unverändert; leere
  oder fehlende Datei ergibt einen Lauf; eine beschädigte Datei wird beiseitegelegt, der neue Lauf steht in einer neuen Datei.
- Schreiben nur einmal pro Prozess: ein zweites Auslösen von `WriteOnce` schreibt nicht erneut (Zähler am Schreibaufruf bleibt 1).
- Auslöser: `listening` allein schreibt nicht; `firstBuffer` nach `listening` schreibt einen Lauf mit beiden Punkten; das
  Zeitlimit ohne Puffer schreibt einen Lauf mit `firstBuffer: null` (Zeit wird im Test injiziert, nicht abgewartet).
- Keine Datei bei Nicht-Prüfbau: `isProbeBuild(bundleID: "com.henning.looseends")` ist falsch, `…looseends.probe` wahr,
  und der Schreibpfad mit der Produktkennung legt im Zielverzeichnis keine Datei an.
- Laufart: Startargument vorhanden → `automated`, sonst `press`.

`LooseEndsUITests/LaunchArgumentTests.swift` (Simulator):

- Start mit `-measureLaunch`: das Erfassungs-Sheet ist ohne Tippen sichtbar (innerhalb 15 s).
- Start ohne das Argument: die App startet unverändert (Hauptansicht sichtbar, kein Erfassungs-Sheet).

Bestehend, unverändert grün: Unit, Build, `CaptureSmokeTests`, `SpeechListeningTests`, Speech Stress (10×, weil
`LooseEnds/Speech/**` berührt wird).

### Abnahme

- **Stufe 1:** Tests grün über `./scripts/sim.sh unit` und `test-proof <Klasse>` für die neue UI-Test-Klasse.
- **Stufe 2:** `./scripts/sim.sh build`, `launch`, `screenshot` — der geänderte Ablauf (Start mit Argument öffnet die
  Erfassung, ohne Argument nicht) wird im Simulator durchgespielt und die Screenshots werden angesehen.
- **Stufe 3 (Pflicht):** Der Schnitt berührt `LooseEnds/Speech/SpeechCapture.swift` (Geräteliste). Gemessen wird ohnehin
  auf dem iPhone 16 Pro: `./scripts/sim.sh device-status` (lesend), Release-Prüfbau installieren, Reihen 1–3. Die Gerätezeile
  für Henning entfällt für die Messung selbst, weil sie Claude per `launch-measure` fährt; für Reihe 2 und 3 braucht Claude
  Henning ausschließlich für die Drücke, mit Ansage je Lauf. `project.yml`, Entitlements und `Info.plist` bleiben unberührt
  (siehe oben).

## Acceptance Criteria

- **AC-1 Signposts im Produkt:** Given ein beliebiger Build / When die Erfassung gestartet wird / Then liegen die Messpunkte
  aus Abschnitt 2 als Signposts im Unified Log, und nichts am Verhalten ist anders (`CaptureSmokeTests`,
  `SpeechListeningTests`, Speech Stress grün).
- **AC-2 Datei nur im Prüfbau:** Given ein Build mit Kennung ohne `.probe` / When die Erfassung `.listening` und den ersten Puffer erreicht / Then entsteht
  keine `launch-timings.json` (Unit-Test belegt es auf dem Schreibpfad); Given der Prüfbau / When der erste Puffer nach `.listening`
  eintrifft (oder 3 s ohne Puffer vergehen) / Then steht ein neuer Lauf mit `listening` und `firstBuffer` (bzw. `null`) in der Datei.
- **AC-3 Genau einmal pro Prozess:** Given ein Prüfbau-Prozess / When `.listening` mehrfach erreicht wird (Erfassung erneut geöffnet)
  / Then entsteht nur ein Eintrag für diesen Prozess (Unit-Test `WriteOnce`; auf dem Gerät: Zahl der Einträge = Zahl der Starts).
- **AC-4 Läufe sammeln sich:** Given eine Datei mit n Läufen / When ein weiterer Prozess schreibt / Then hat sie n+1, die alten
  unverändert (Unit-Test).
- **AC-5 Nullpunkt:** Given ein Lauf auf dem Gerät / When er ausgewertet wird / Then ist die Gesamtzeit von Prozessstart
  (`kp_proc.p_starttime`) bis `.listening` angegeben und `zeroPoint` lautet `processStart`.
- **AC-6 Startargument:** Given der Start mit `-measureLaunch` / When die App öffnet / Then ist das Erfassungs-Sheet ohne
  Tippen sichtbar; Given der Start ohne Argument / Then ist es nicht sichtbar (UI-Test, Simulator).
- **AC-7 Reihe 1:** Given der Release-Prüfbau auf dem iPhone 16 Pro / When `launch-measure 10` läuft / Then liegen 10 gültige
  Kaltlauf-Einträge der Laufart `automated` vor (erster Lauf verworfen, getrennt gekennzeichnet).
- **AC-8 Reihe 2:** Given das Control des Prüfbaus / When Henning es zehnmal drückt (App jeweils im App-Umschalter beendet) / Then
  liegen 10 Einträge der Laufart `press` vor; Reihe 3 hat 1–2 Einträge nach Neustart.
- **AC-9 Hennings Installation unberührt:** Given Hennings Alltags-App / When die Messungen laufen / Then ist sie danach
  unverändert (gleiche Kennung, gleiche Version in `devicectl device info apps`, nur lesend geprüft).
- **AC-10 Bericht:** `docs/reference/kaltstart-messung.md` enthält Rohwerte je Lauf, Mittelwert, Median, Maximum, Abschnitte,
  Gerät, OS, Build, die Nulllinie (Reihe 1) und beide Befunde (Sheet statt Szene, Textfeld ohne Fokus).
- **AC-11 Ergebnis eingetragen:** Offener Punkt 3 in `02-datenmodell-und-ansichten.md` nennt Mittelwert, Zahl der Läufe und Gerät;
  `04-stand.md` verweist auf den Bericht.
- **AC-12 Verfehlung → Folge-Issue:** Given der Mittelwert von Reihe 2 liegt bei ≥ 1 s / Then existiert ein GitHub-Issue mit konkretem
  Optimierungsvorschlag aus dem größten Abschnitt; liegt er darunter, wird das im Bericht ausdrücklich festgehalten (kein Issue nötig).
- **AC-13 Regression:** Unit, Build, UI Smoke und Speech Stress grün; `./scripts/sim.sh generate` ändert `project.yml` nicht.

## Risiken

- **Debug statt Release:** Debug-Startzeiten taugen nicht. `launch-measure` bricht ab, wenn das Bundle im Debug-Pfad liegt
  (Konfigurationsprüfung am `Info.plist`/Pfad), statt falsche Zahlen zu liefern.
- **Echter Pfad nicht automatisierbar:** Control/Aktionstaste lassen sich nicht auslösen (keine Quelle gefunden). Deshalb Reihe 2
  von Hand; Reihe 1 ist nur Untergrenze. Der Systemanteil vor dem Prozessstart bleibt unsichtbar und erscheint nur als
  Differenz zwischen Reihe 1 und Reihe 2 (gleiche Messpunkte, anderer Startweg). Die Zeit vom Tastendruck bis zum Prozessstart misst kein App-Code; der Bericht nennt diese Lücke ausdrücklich.
- **Messung verfälscht sich selbst:** Datei-I/O im Startpfad; deshalb genau ein Schreiben bei `.listening`. Die Signposts sind
  kostenarm; ein Vergleich Lauf mit/ohne Datei ist nicht vorgesehen, der Aufwand des Schreibens liegt hinter dem Messpunkt.
- **Modell fehlt:** Ohne Sprachmodell bleibt `.needsModel`, `.listening` wird nie erreicht und es entsteht kein Eintrag. Der
  Bericht prüft vor der Reihe die Vorbedingung (Erfassung zeigt kein „Load").
- **Onboarding/Rechtedialoge** im ersten Lauf: verworfen.
- **Apple Intelligence/Gerät gesperrt:** `devicectl` lehnt den Start ab; `launch-measure` meldet das und bricht ab, nicht still.
- **Hennings Aktionstaste** wird für Reihe 2 vorübergehend umbelegt; danach zurück (Ansage im Bericht).
- **Prüfbau-Schreibort:** `Documents/` des Prüfbaus ist über `devicectl copy from` lesbar, der Weg ist in #226 Schnitt 2b bewährt.

## Alternativen

Getroffene Entscheidungen sind Arbeitsstand. Verglichen mit dem gewählten Weg (Signposts + Datei im Prüfbau, zwei Reihen):

| Alternative | Vorteil | Warum nicht jetzt | Was kippt, wenn sie gewählt wird |
|---|---|---|---|
| **Video statt Code** (zweites Gerät filmt Druck bis Mikrofon-Anzeige, 240 fps) | misst die Nutzersicht inklusive Systemanteil vor dem Prozess | grenzt keine Ursache ein, Handauswertung | die Annahme „Messpunkte im Code reichen"; sinnvoll als Gegenprobe für 3–5 Läufe, falls der Systemanteil groß aussieht |
| **Minimal-App als Systembasis** (leere App, gleiches Control; Apple DTS) | trennt Systemzeit von eigenem Code | eigenes Target (project.yml, Entitlements, Geräteliste), Aufwand außer Verhältnis | liegt die leere App schon über 1 s, lautet das Ergebnis „ADR-9-Budget anpassen" statt „optimieren". Nur wenn Reihe 2 knapp verfehlt |
| **Nur Instruments „App Launch"** | am wenigsten Code | GUI-gebunden, nicht wiederholbar (#73 Dauerlauf) | die Anforderung, dass die Messung wiederholbar bleibt |
| **Direkt umbauen** (schlanke Erfassungs-Szene, `startUp` verschieben) | ADR-9 wörtlich erfüllt | ohne Messung unbekannt, ob der Umbau nötig ist oder die Zeit im Sprachteil steckt | die Reihenfolge „erst messen" und ADR-9 selbst (Szene statt Sheet) — das wäre dann das Folge-Ticket |
| **`XCTApplicationLaunchMetric`** in einem Geräte-UI-Test | Standardmetrik, misst bis erster Frame | misst nur bis zum ersten Frame, nicht bis `.listening`; Gerätetests überschrieben Hennings Installation (#153) | die Definition „eingabebereit" (erster Frame statt Mikrofon hört) |
| **MetricKit `extendLaunchMeasurement`** | offizielles Startmaß über Nutzer | Histogramme mit bis zu 1 Tag Verzögerung, ungeeignet für 10 Einzelläufe | die Anforderung Einzelläufe |

Regelweg vor Modell: nicht berührt (siehe oben).

## ADR

**ADR-Nr.:** keine — Der Spike misst nur und ändert ADR-9 nicht. Eine Anpassung von ADR-9 (Budget oder Szene statt Sheet) wäre das Ergebnis des Folge-Tickets, nicht dieses Spikes.

## Recherche (2026-10-08)

| Frage | Befund | Quelle |
|---|---|---|
| Offizielle Startmessung | Instruments „App Launch" und `OSSignposter` sind Standard; DTS rät zu Instruments und Time Profiler | [Forum 761677](https://developer.apple.com/forums/thread/761677) |
| `XCTApplicationLaunchMetric` | misst bis zum ersten Frame bzw. `waitUntilResponsive` | [Apple-Doku](https://developer.apple.com/documentation/xctest/xctapplicationlaunchmetric.md) |
| MetricKit extended launch | `extendLaunchMeasurement(forTaskID:)` liefert Histogramme mit bis zu 1 Tag Verzögerung, für Einzelläufe ungeeignet | [Zusammenfassung](https://skills.sh/dpearson2699/swift-ios-skills/metrickit) |
| Apple-Ziel erster Frame | 400 ms (davon ~100 ms System) | [WWDC19 423](https://developer.apple.com/videos/play/wwdc2019/423/), [WWDC23 10196](https://developer.apple.com/videos/play/wwdc2023/10196) |
| Kaltstart automatisiert | `devicectl device process launch --terminate-existing` startet neu, aber über CoreDevice, nicht über die Intent-Pipeline; damit nur Untergrenze (Pfadunterschied Vermutung, durch Reihe 2 belegt) | [Forum 756393](https://developer.apple.com/forums/thread/756393) |
| Control/Aktionstaste automatisiert auslösen | nichts gefunden, bleibt manueller Schritt (offen) | — |
| Systemzeit vor erstem App-Code bei Control/Intent | keine Zahlen; Forenbericht „mehrere Sekunden" bei nicht laufender App (iOS 18); DTS: Minimal-App als Basis | [Forum 761677](https://developer.apple.com/forums/thread/761677) |
| Signposts ohne GUI | `xctrace record --device … --launch/--attach` + `xctrace export`; auf Geräten bekannte Hänger; deshalb nicht der Hauptweg | [Forum 720361](https://developer.apple.com/forums/thread/720361), [Forum 687944](https://developer.apple.com/forums/thread/687944) |
| SpeechAnalyzer-Vorlauf | `prepareToAnalyze(in:)` lädt vor; warm ~0,3–0,5 s bis zum ersten Ergebnis (Blogzahl, iPhone 16e, iOS 26.5; für iPhone 15 Pro, iOS 27, kalt keine Zahl) | [Apple-Doku](https://developer.apple.com/documentation/speech/speechanalyzer.md), [WWDC25 277](https://developer.apple.com/videos/play/wwdc2025/277/), [Blog](https://dev.to/simple_memo/ios-26s-speechanalyzer-on-a-live-mic-the-5-things-the-docs-dont-tell-you-2ng5) |
| `ModelContainer` mit CloudKit | keine Zahlen, keine Apple-Empfehlung gefunden; wird gemessen | — |

Hintergrund und Ist-Zustand des Startpfads: `docs/context/spike-22-kaltstart.md`.

## Definition of Done

- AC-1 bis AC-13 erfüllt; Unit-Tests und neuer UI-Test grün; alle bestehenden Tests grün (Unit, UI Smoke, Speech Stress).
- Stufe 2 (Simulator) mit angesehenen Screenshots; Stufe 3 (Gerät) als Messreihen 1–3 durchgeführt.
- `docs/reference/kaltstart-messung.md`, offener Punkt 3 in `docs/project/02-datenmodell-und-ansichten.md` und
  `docs/project/04-stand.md` aktualisiert.
- Bei Verfehlung des Budgets: Folge-Issue mit Optimierungsvorschlag angelegt; sonst ausdrücklich vermerkt, dass das Budget gehalten wird.
- Issue #22 mit `Closes #22` im PR; Hennings Alltags-App unverändert; Aktionstaste wieder auf ihrer ursprünglichen Belegung.

## Changelog

- 2026-10-08: Spec aus der Analyse in `docs/context/spike-22-kaltstart.md` geschrieben. Nachgeschärft: Das Schreiben
  löst der erste Audiopuffer aus (er kommt nach `.listening`, sonst wäre der Zweitwert immer leer); Warmstart-Reihe
  gestrichen (kein Prozessstart als Nullpunkt, das Ticket fragt nur nach dem Kaltstart).

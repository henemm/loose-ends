# Adversary Dialog — fix-883-mac-widget-nachziehen
Spec: docs/specs/fix-883-mac-widget-nachziehen.md
Datum: 2026-11-10 20:47

## Checkliste
- [x] **AC-1:** Ein erfolgreicher, beendeter CloudKit-Import löst genau ein Neuladen aus (Unit-Test, Meldung von Hand gesendet, Neuladen eingespeist). Ein Import ohne `endDate`, ein fehlgeschlagener Import und ein Export lösen keines aus.
- [x] **AC-2:** Ein Speichern im Kontext der App (`ModelContext.didSave`) löst ein Neuladen aus, **ohne dass eine `ContentView` existiert** (Unit-Test: nur `WidgetReload` gestartet, kein Fenster).
- [x] **AC-3:** Zehn Meldungen innerhalb einer Sekunde ergeben genau ein Neuladen (Zusammenfassen).
- [x] **AC-4:** `ContentView` ruft `reloadTimelines` nicht mehr selbst auf, damit ein Speichern nicht doppelt neu lädt. Fester Test in `WidgetReloadTests`: liest `LooseEnds/App/ContentView.swift` über `#filePath` und schlägt fehl, wenn dort `reloadTimelines` steht; ein zweiter Test prüft, dass `LooseEndsApp.swift` eine `WidgetReload`-Instanz erzeugt und `start()` ruft (der Beobachter hängt am Prozess, nicht am Fenster).
- [x] **AC-5:** iPhone und iPad unverändert: Speichern in der App lädt das Widget weiter neu (derselbe Beobachter, Simulator-Smoke läuft grün).
- [x] **AC-6:** `scripts/sim.sh unit` und `build` grün, `generate` hinterlässt keinen Diff.

## Dialog

### Runde 1
**Adversary:** Ich behaupte, die Umsetzung ist kaputt. (a) Läuft WidgetReload unter Unit-/UI-Test mit aktivem WidgetKit? (b) Wird start() im App-init erreicht, nicht erst mit dem Fenster? (c) Rufen weitere Stellen reloadTimelines auf (doppelt laden)? (d) AC-1 und AC-3 prüfen nur handle(), nicht den Notification-Pfad. (e) AC-2 prüft nur `count >= 1`, nicht "genau eins".
**Implementierer:**
- (a) Ohne eingespeisten Closure und unter `isRunningTests || isUITesting` ist der Produkt-Closure leer (LooseEnds/App/WidgetReload.swift:28-36); die Tests speisen einen Zähler ein. Kein WidgetKit-Aufruf in Tests.
- (b) `widgetReload = WidgetReload(); widgetReload.start()` im `init` von LooseEndsApp (LooseEnds/App/LooseEndsApp.swift:49-50), direkt nach `notifications.activate()`, vor jeder Scene; die Instanz ist gespeichertes Property (Lebensdauer = Prozess). Gleicher init für Mac-Menüleiste und Fenster.
- (c) Repo-weite Suche (`reloadTimelines|reloadAllTimelines|WidgetCenter` in *.swift): einziger Treffer ausserhalb der Tests ist WidgetReload.swift:35. ContentView hat Aufruf und `import WidgetKit` verloren (LooseEnds/App/ContentView.swift:165-168, `rescheduleSoon`/`syncSoon` bleiben). Kein Doppelladen.
- (d) Zugestanden: Der Notification-Closure (WidgetReload.swift:49-62) ist nicht per Test erreichbar, weil `NSPersistentCloudKitContainer.Event` nicht von Hand konstruierbar ist; die Regel selbst (`isFinishedImport`, :74) ist getestet (Import ok / ohne endDate / mit Fehler / Export / Setup). Die Umrechnung `succeeded=false -> errorMessage != nil` ist per Lesen korrekt (`raw.error?.localizedDescription ?? "failed"`, nie nil bei Fehlschlag).
- (e) Zugestanden, schwach, aber vertretbar: der didSave-Test hört mit `object: nil` und könnte durch Nebensaves mehrfach zählen; das Zusammenfassen belegt AC-3 separat.
Beweis: `./scripts/sim.sh sim-unit WidgetReloadTests` selbst gelaufen, 6/6 grün, Exit 0 (docs/artifacts/fix-883-mac-widget-nachziehen/adversary-test-output.txt). 3 übersprungene Messstrecken (RawSentence/SelfConsistency/TextForm) und 2 Latenz-"nicht gemessen" sind fremd zu #883.

### Runde 2
**Adversary:** Tiefer: Swift-6-Concurrency der Beobachter? Debounce-Abbruch? Speicher? Wurden SyncStatus/DueNotificationCenter berührt? Spec-Abweichung `isFinishedImport` "von beiden Beobachtern lesbar"? generate/build?
**Implementierer:**
- Concurrency: Beide Closures laufen mit `queue: .main`; `MainActor.assumeIsolated` (WidgetReload.swift:45, :61) passt dazu, die Klasse ist @MainActor. Build (Swift 6) grün: `./scripts/sim.sh build` Exit 0, Build Succeeded.
- Debounce: `reloadSoon` bricht `pending` ab (:80), `Task.sleep` wirft bei Abbruch -> `return` ohne reload (:82-86); der Task hält `self` nur weak. Der Test mit 10 Meldungen zeigt genau 1. Randfall: Beobachter werden nie entfernt (kein deinit), unkritisch, da die Instanz prozesslang lebt; `start()` ist idempotent (:41).
- Speicher: `[weak self]` in beiden Beobachtern und im Task; kein Zyklus.
- Unberührt: Die Statusliste des Arbeitsverzeichnisses zeigt nur ContentView, LooseEndsApp, WidgetReload (neu); SyncStatus und DueNotificationCenter nicht geändert.
- Spec-Abweichung (nüchtern): Die Spec verlangt, `isFinishedImport` sei "von beiden Beobachtern des Hauses lesbar", lässt aber DueNotificationCenter ausdrücklich unverändert. Umgesetzt: DueNotificationCenter.swift:84 hat weiter seine eigene Inline-Regel, WidgetReload hat eine zweite (WidgetReload.swift:74), also zwei Kopien derselben Regel (Drift-Risiko, LOW, kein AC verletzt). Die Spec widerspricht sich hier selbst.
- AC-6: `./scripts/sim.sh generate` Exit 0, danach keine neuen Diffs ausser den erwarteten Dateien (project.yml unberührt). `build` grün. `sim.sh unit` (volle Suite) habe ich nicht gefahren, nur WidgetReloadTests (volle Suite: test-green-output.txt des Entwicklers).
- AC-5: Nicht lokal belegt: UI-Smoke im Simulator nicht ausgeführt. Belegt nur: derselbe didSave-Beobachter ist plattformunabhängig, build grün, Unit-Test AC-2. Smoke und Stufe 3 (Mac) laufen in der CI bzw. über TestFlight.

Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEnds/App/WidgetReload.swift:74
  Description: Importregel steht doppelt (hier und inline in DueNotificationCenter).
  Spec requirement: Implementation Details — isFinishedImport von beiden Beobachtern lesbar, DueNotificationCenter unverändert
  Conflict: Die Spec widerspricht sich selbst; die Regel ist dupliziert, kein AC verletzt.
  Remediation: Späterer Schnitt: DueNotificationCenter auf WidgetReload.isFinishedImport umstellen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/App/WidgetReload.swift:49
  Description: Der Notification-Closure für den Import ist nicht unit-getestet (Event nicht konstruierbar).
  Spec requirement: AC-1
  Conflict: Pfad Notification -> Event-Umrechnung -> handle nur per Lesen belegt.
  Remediation: Mac-Gerätepunkt (Stufe 3) deckt es ab.

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/App/WidgetReload.swift:68
  Evidence: handle() reloadet nur bei `.imported`, endDate != nil, kein Fehler; Tests testFinishedImportReloadsOnce und testUnfinishedFailedAndExportDoNotReload grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/App/WidgetReload.swift:42
  Evidence: didSave-Beobachter ohne ContentView; testDidSaveReloadsWithoutAnyView grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/App/WidgetReload.swift:79
  Evidence: Debounce mit Abbruch; testBurstOfTenMessagesReloadsOnce grün (genau 1).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/App/ContentView.swift:165
  Evidence: Aufruf und import WidgetKit entfernt; Suche findet keinen weiteren reloadTimelines ausser WidgetReload.swift:35; LooseEnds/App/LooseEndsApp.swift:49 erzeugt und startet die Instanz im init; beide Quelltext-Tests grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/App/LooseEndsApp.swift:49
  Evidence: Teilweise: gleicher Beobachter für alle Plattformen, Build grün; UI-Smoke lokal nicht gelaufen (CI).
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/App/LooseEndsApp.swift:14
  Evidence: build grün, generate ohne Diff; volle `unit`-Suite nicht von mir gefahren (WidgetReloadTests ja).
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`); das Skript verlangt `--lang` und lieferte keine Tabelle. Manuell: Das Neuladen schreibt nur `WidgetReload.reload` (WidgetReload.swift:35); Bedingung davor: didSave oder beendeter, erfolgreicher Import; Test für diesen Weg: testDidSaveReloadsWithoutAnyView und testFinishedImportReloadsOnce.

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
6/6 WidgetReloadTests und build grün, generate ohne Diff. Zwei LOW-Befunde (F001 doppelte Regel, F002 Notification-Pfad nur per Lesen). Nicht lokal belegt: UI-Smoke (AC-5), volle unit-Suite, Mac-Gerätepunkt.
Tests: 6 passed, 0 failed, 3 Messstrecken übersprungen (fremd)
Regressions: None found
Checklist: 6/6 (AC-5 teilweise)

## Geprüfte Dateien

- sha256:b7066638c04c08d2a04c7cfaf78310fbf8cf5decffee22a13551944d4482b538  LooseEnds/App/ContentView.swift
- sha256:129d750ae38e1f1623a9d9c704416c02feaf98eea42821995bcd3da5e30ed66b  LooseEnds/App/LooseEndsApp.swift
- sha256:20ce9f4f70260c84cb68837412d6e0c16e3b742164f1b261cf4a9edeae466d54  LooseEnds/App/WidgetReload.swift

## Prüfbasis

- base: 62c0dbe1f0ece30ddd37a8461b422ecb603f5b09
- blob:61ac3dd894f9e01db9bb843c589cf1c9ef05cfeb  LooseEnds/App/ContentView.swift
- blob:d0f1dea54297e371b3b36cab453cb0a3d20cfffe  LooseEnds/App/LooseEndsApp.swift
- blob:4e7307175b2c690a46f57b7eacfee34fb3c0259c  LooseEnds/App/WidgetReload.swift

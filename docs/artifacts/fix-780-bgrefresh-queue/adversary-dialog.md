# Adversary Dialog — fix-780-bgrefresh-queue
Spec: docs/specs/fix-780-bgrefresh-queue.md
Datum: 2026-10-31 18:30

## Checkliste
- [x] **Input:** iOS startet die Hintergrund-Auffrischung auf einer Hintergrund-Queue. Beleg: launchHandler ist nonisolated und @Sendable, Test ruft ihn von DispatchQueue.global() (BackgroundRefresh.swift:35-46, Tests:16).
- [x] **Output:** Kein Absturz. Der Mitteilungsplan wird erneuert (`reschedule()`), die nächste Auffrischung wird angefragt, success: true. Beleg: Reihenfolge reschedule, schedule(), setTaskCompleted(true) (BackgroundRefresh.swift:20-23, 41-44); Test grün.
- [x] **Ablauf des Zeitfensters:** expirationHandler endet mit `success: false`, ohne Absturz. Beleg: BackgroundRefresh.swift:40, Test testExpiration... grün.
- [x] **Planung:** submitTaskRequest-Handler @Sendable, Fehler nur ins Log. Beleg: BackgroundRefresh.swift:56-60.
- [x] **Side effects:** keine neuen. Beleg: git diff --stat, nur 3 Dateien.
- [x] **AC-1:** Beleg: adversary-test-output.txt "Executed 2 tests, with 0 failures"; Test Zeile 9-21 (reschedule genau 1, completions == [true]).
- [x] **AC-2:** Beleg: Test Zeile 23-45, completions.first == false, grün.
- [x] **AC-3:** Beleg: @Sendable an Zeilen 25, 40, 56; `using: nil` Zeile 25; Bau erfolgreich ohne Fehler (scratchpad build.txt, kein Treffer auf BackgroundRefresh in Warnungen).
- [x] **AC-4:** Beleg: run.sh jetzt: Fall 1 exit=133, Fall A exit=0, Fall B exit=0.
- [x] **AC-5:** Beleg: Signaturen register/schedule unverändert (Diff), Guards Zeilen 19 und 50 unverändert, Simulator: build, launch, Wechsel zu Preferences, kein LooseEnds-Absturzbericht in ~/Library/Logs/DiagnosticReports, Screenshot adversary-screenshot.png zeigt laufende App (Startseite). Voller Lauf test-green-full-output.txt: Executed 12 tests, 0 failures (Anmerkung: nur XCTest-Zeilen gezählt, Lauf vor kleiner Teständerung; Einzellauf jetzt erneut grün).
- [x] **AC-6:** Beleg: git diff --stat: CLAUDE.md, BackgroundRefresh.swift, BackgroundRefreshTests.swift; kein project.yml, Info.plist, Entitlements, DueNotificationCenter.
- [ ] **AC-7:** nachgelagert: TestFlight + Absturz-Abruf nach dem Merge, vor dem Merge nicht belegbar.

## Dialog

### Runde 1
**Adversary:** Behauptung: Fix macht alle drei Closures sicher. Ich prüfe Quelltext, Tests, Nachbau, Simulator. Frage: Läuft der Test den heutigen Fehler überhaupt nach? Ist `using: nil` wirklich noch drin? Erbt die Closure in `register` (innerhalb @MainActor enum) nicht doch Isolation, obwohl @Sendable?
**Implementierer:** Test: `sim-unit BackgroundRefreshTests` -> "Executed 2 tests, with 0 failures" (adversary-test-output.txt). Den Laufzeitcrash löst der Swift-Test laut Spec nicht aus; dafür run.sh: Fall 1 exit=133 (Trace/BPT trap), Fall A und B exit 0 (selbst gefahren). Code: BackgroundRefresh.swift:25 `register(forTaskWithIdentifier: identifier, using: nil) { @Sendable task in handler(task) }`; `handler` ist eine @Sendable-Closure, vorab durch die nonisolated static Funktion (Zeile 35) erzeugt; `notifications` wird nur in der @MainActor-@Sendable-Closure (Zeile 20-23) benutzt. Bau fehlerfrei in Swift 6. Simulator: kein Absturzbericht, App läuft (Screenshot). Die Kennung/earliest unverändert (Zeilen 13-15). Einschränkung: der Scheduler fehlt im Simulator, der echte Pfad bleibt bis AC-7 unbelegt.

### Runde 2
**Adversary:** Edge Cases: (a) setTaskCompleted doppelt bei Ablauf und späterem Erfolg? (b) Reihenfolge reschedule vor schedule vor completed? (c) RefreshHandle @unchecked Sendable, Retain? (d) unter Tests/--ui-testing sofortige Rückkehr? (e) Im Ablauftest: bleibt die Arbeit hängen, Leak?
**Implementierer:** (a) Ja, möglich: nach Ablauf (Zeile 40, success:false) läuft der Task in Zeile 41-44 weiter und meldet später success:true. Der Test macht das nicht sichtbar (onComplete = nil vor gate.open(), Tests:43-44). Das war im alten Code ebenso (Task nicht abgebrochen), kein neues Verhalten; Finding F001 LOW. (b) Zeile 20-23: `await notifications.reschedule(); schedule()` im reschedule-Closure, danach erst Zeile 43 completed(true): Reihenfolge erhalten. (c) RefreshHandle (Zeile 73-76) ist final class mit unveränderlichem `let`, hält Task stark bis beide Closures freigegeben sind; BGTask ist ohnehin Referenztyp, kein Zyklus, da der Task den Handler hält und der Handler das Handle (gleichzeitig Zyklus task -> expirationHandler -> handle -> task, vom System nach Completion gelöst; wie im alten Code, der task direkt einfing). (d) Zeile 19 und 50 Guards unverändert, im Diff nicht berührt. (e) Gate.open() am Testende gibt die Arbeit frei, kein hängender Task.

## Findings und Bestätigungen

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Notifications/BackgroundRefresh.swift:40
  Description: Nach Ablauf meldet der expirationHandler success:false; der Task in Zeile 41-44 läuft weiter und ruft später setTaskCompleted(success: true) ein zweites Mal.
  Spec requirement: AC-2 — Ablauf endet mit success:false ohne Absturz
  Conflict: Doppelte Completion möglich; kein Absturz belegt (BGTask ignoriert sie dokumentationsgemäß nicht ausdrücklich). Vorbestehend, nicht vom Fix eingeführt.
  Remediation: Optional später: Abbruchmarke im RefreshHandle, nur einmal completen. Nicht Teil dieses Tickets.

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Notifications/BackgroundRefresh.swift:35
  Evidence: nonisolated static launchHandler liefert @Sendable-Handler; Test von global queue grün (2 Tests, 0 Fehler).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEndsTests/BackgroundRefreshTests.swift:23
  Evidence: expirationHandler von global queue gerufen, completions.first == false.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Notifications/BackgroundRefresh.swift:25
  Evidence: @Sendable an Zeilen 25, 40, 56; using: nil.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Notifications/BackgroundRefresh.swift:56
  Evidence: run.sh Fall 1 exit 133, A und B exit 0 (eigener Lauf).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Notifications/BackgroundRefresh.swift:19
  Evidence: Guards unverändert; Simulator ohne Absturz, Screenshot zeigt laufende App.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: CLAUDE.md:415
  Evidence: git diff --stat nur 3 erlaubte Dateien; Halbsatz zu #780 in CLAUDE.md.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

### Verdict: VERIFIED

AC-1 bis AC-6 belegt, AC-7 nachgelagert (TestFlight + Absturz-Abruf nach dem Merge), F001 LOW vorbestehend.

## Geprüfte Dateien

- sha256:0872f9fe2ef938bd02af9795b878b6d0224f9792bb86c97ada739fb7be3ca8a4  CLAUDE.md
- sha256:48352848d289b95435062862b764db4b6f8236f6e558d65039030c695e58d99d  LooseEnds/Notifications/BackgroundRefresh.swift
- sha256:66d7099f16ae62180414e338ed556266049aca0f98613b21e0a73a6b70f8269e  LooseEndsTests/BackgroundRefreshTests.swift

## Prüfbasis

- base: 28d57cb1195be22b8c1567e85dc7be61be3f1ab2
- blob:c30b5e82feddbf834bea30be60617d46575a1bc1  CLAUDE.md
- blob:6c9ec5717f81ca52ff84c322668d9fe472998302  LooseEnds/Notifications/BackgroundRefresh.swift
- blob:f5159fbc9689b2624b4367005ca09abc85b6c170  LooseEndsTests/BackgroundRefreshTests.swift

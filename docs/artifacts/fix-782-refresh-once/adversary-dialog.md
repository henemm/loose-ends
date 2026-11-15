# Adversary Dialog — fix-782-refresh-once
Spec: docs/specs/fast/fix-782-refresh-once.md
Datum: 2026-11-15 09:29

## Checkliste
- P1: Ablauf von Hintergrund-Queue, Arbeit läuft danach zu Ende: genau ein setTaskCompleted(false) — PROVEN
- P2: Ohne Ablauf: reschedule einmal, genau ein Abschluss mit true — PROVEN
- P3: Abschluss von jeder Queue sicher (Marke unter Mutex), genau ein Abschluss auch bei Gleichzeitigkeit — PROVEN
- P4: Kennung, earliest, schedule(), Registrierung unverändert; kein geerbter Actor — PROVEN

## Dialog

### Runde 1
**Adversary:** Tests selbst gelaufen (adversary-test-output.txt): BackgroundRefreshTests 2 Tests, 0 Failures, 0 übersprungen. Diff gegen c82871d geprüft: nur Import Synchronization, `RefreshHandle.finish` und die zwei Aufrufstellen in launchHandler; register(), schedule(), identifier, earliest unberührt (P4).
Angriff 1, Rennen Ablauf gegen Arbeitsende: `finish` liest und setzt die Marke in einem einzigen `withLock` (`defer { done = true }` läuft im Lock, Rückgabewert `!done` wird vorher ausgewertet). Zwei Queues können nicht beide `first == true` sehen. `setTaskCompleted` läuft außerhalb des Locks, aber nur im Gewinnerpfad, also höchstens einmal.
Angriff 2, zweimaliger Ablauf: der Handler ruft `finish(false)` zweimal, der zweite Aufruf ist ein No-op. Doppelaufruf von launchHandler-Closure pro Task: jede Task bekommt ein eigenes RefreshHandle, keine geteilte Marke zwischen Tasks.
Angriff 3, Ablauf vor Start der Arbeit: expirationHandler wird vor `Task { @MainActor }` gesetzt; läuft er früher ab, meldet er false, die Arbeit meldet danach nichts. Gut.
Angriff 4, Actor-Vererbung: launchHandler ist `nonisolated`, Closure `@Sendable`, `finish` nicht actor-gebunden; `Mutex` ist Sendable, Klasse `@unchecked Sendable` mit nur `let`-Eigenschaften. Kein Main-Actor-Hop nötig für den Abschluss (P3/P4).
Angriff 5, Testschwäche: der Test erzeugt das echte Gleichzeitigkeitsfenster nicht (Ablauf und Arbeitsende parallel), er prüft die Sequenz Ablauf, dann Arbeitsende. Die Atomarität belegt der Code, nicht der Test. Nur LOW.
**Implementierer:** (Code-Pfad bestätigt, siehe Confirmations)

### Runde 2
**Adversary:** Regression: Aufrufer von launchHandler/RefreshHandle per Grep. Der einzige Produktaufrufer ist `register`; `RefreshHandle` ist `private`. Das Protokoll `RefreshTask` ist unverändert. Reference-Cycle task → expirationHandler → handle → task bleibt wie vorher (Systemhalter löst ihn auf), keine Verschlechterung. Fehlerpropagation: `reschedule` kann nicht werfen (Signatur `async -> Void`); bleibt die Arbeit hängen, beendet der Ablauf die Aufgabe mit false, was gewünscht ist. Ohne Ablauf und ohne Arbeitsende (Hänger) kein Abschluss, aber das war vorher gleich und ist Systemsache (der Ablauf kommt).
Early-Agreement-Skepsis: alle vier Punkte einzeln an Code und Testlauf belegt, nicht nur am grünen Test; Befund F001 (LOW) offen gehalten.
**Implementierer:** F001 betrifft die Testtiefe, nicht das Verhalten; kein Blocker.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Notifications/BackgroundRefresh.swift:80
  Description: `finish` ist per Mutex korrekt atomar, aber kein Test lässt Ablauf und Arbeitsende wirklich gleichzeitig laufen (nur nacheinander).
  Spec requirement: P3 — genau ein Abschluss auch bei gleichzeitigem Ablauf und Arbeitsende
  Conflict: Die Zusicherung stützt sich auf Code-Lektüre, nicht auf einen Rennen-Test; kein Fehlverhalten gefunden.
  Remediation: Optional ein Test, der finish(true) und finish(false) von zwei Queues in einer Schleife feuert und `completions.count == 1` prüft.

Confirmation:
  AC: P1
  Code reference: LooseEnds/Notifications/BackgroundRefresh.swift:41
  Evidence: expirationHandler ruft handle.finish(success: false); Arbeitsende (Zeile 44) ruft finish(true), das zum No-op wird; Test testExpirationHandlerCalledFromBackgroundQueueCompletesOnceWithoutSuccess grün, completions == [false].
  Status: CONFIRMED

Confirmation:
  AC: P2
  Code reference: LooseEnds/Notifications/BackgroundRefresh.swift:44
  Evidence: Ohne Ablauf meldet der innere Task nach reschedule() einmal finish(true); Test testLaunchHandlerCalledFromBackgroundQueue... grün, count == 1, completions == [true].
  Status: CONFIRMED

Confirmation:
  AC: P3
  Code reference: LooseEnds/Notifications/BackgroundRefresh.swift:81
  Evidence: Lesen und Setzen der Marke in einem einzigen Mutex.withLock; setTaskCompleted nur im Gewinnerpfad (Zeile 85).
  Status: CONFIRMED

Confirmation:
  AC: P4
  Code reference: LooseEnds/Notifications/BackgroundRefresh.swift:14
  Evidence: identifier, earliest (Zeile 16), register (19-32), schedule (50-62) im Diff unverändert; launchHandler bleibt nonisolated (Zeile 36).
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: VERIFIED
Tests: 2 passed, 0 failed, 0 übersprungen
Checklist: 4/4 points proven

## Geprüfte Dateien

- sha256:f50720021d0c87ea8849cf12d8a6228a0b4f672ae7a8a7626f71075980add861  LooseEnds/Notifications/BackgroundRefresh.swift

## Prüfbasis

- base: c82871d5383cbe225c827dae5768a9750e41166a
- blob:be35ad7a704eb28c69534f71cee8a73a436b608c  LooseEnds/Notifications/BackgroundRefresh.swift

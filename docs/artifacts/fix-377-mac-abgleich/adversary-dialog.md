# Adversary-Dialog: fix-377-mac-abgleich (#377 Schnitt 1)

Prüfer: implementation-validator (read-only). Orchestrator: Hauptkontext. Stand: Arbeitsbaum mit vorgemerktem Index, Beweise unter `docs/artifacts/fix-377-mac-abgleich/`.

Verlauf: Runde 1 und 2 gegen die Spec mit neun Punkten (Verdict AMBIGUOUS: AC-7 offen, AC-8 nachgelagert). Danach hat Henning die Spec per Override und Freigabe geändert: AC-7 (im Simulator nicht beantwortbar, App-Gruppe fehlt, Beleg `ac7-ergebnis.md`) und AC-8 stehen im Abschnitt „Nachgelagert“ als G-0 und G-1, beide verbindlich, #377 bleibt offen. Runde 3 prüft die geänderte, freigegebene Spec.

### Runde 1

Prüfung gegen Spec, Diff, Testläufe und Screenshots.

- [x] AC-1: Auswertungsregel `reduce`, Zustände alive/failed/waiting; Unit-Tests zuerst rot (test-red-output.txt), dann grün (test-green-output.txt, EXIT=0, Suite „SyncStatus (#377)“ passed).
  Code reference: Shared/Persistence/SyncStatus.swift:78
  Code reference: LooseEndsTests/SyncStatusTests.swift:21
- [x] AC-2: `localOnly` ist endgültig, beide Gründe getrennt getestet.
  Code reference: Shared/Persistence/SyncStatus.swift:79
- [x] AC-3: Beide stillen Rückfälle melden den Zustand, Logger bleibt, `make()` liefert immer einen Container; `syncs: false` und In-Memory-Container setzen den Zustand nicht; Test der Meldefunktion `reportFallBack` vorhanden. Im echten Produktpfad bestätigt: Der Rückfall löst aus und wird geloggt (`ac7-ergebnis.md`).
  Code reference: Shared/Persistence/ModelContainerFactory.swift:100
  Code reference: Shared/Persistence/ModelContainerFactory.swift:116
- [x] AC-4: Abschnitt „iCloud“ mit Zeile `iCloudSyncRow`; Screenshots hell und dunkel geöffnet und beschrieben (Überschrift links als graue Abschnittsüberschrift, Umriss-Wolke grau, „Waiting for iCloud“). Ein erster Screenshot zeigte die Überschrift mittig in der Zeile (Section in TimelineView); behoben und am selben Ablauf neu belegt. Nur der Zustand `waiting` ist als Bild belegt, failed/localOnly über Unit-Tests.
  Code reference: LooseEnds/Views/SettingsView.swift:74
  Code reference: LooseEndsUITests/SettingsSmokeTests.swift:26
  Code reference: LooseEnds/Resources/Localizable.xcstrings:1
- [x] AC-5: Rollen nur accent/secondary, kein Rot, nur SF Symbols; Test `noRedAnywhere`.
  Code reference: Shared/Persistence/SyncStatus.swift:98
- [x] AC-6: `project.yml` +2 Zeilen (`sdk: CloudKit.framework`, `destinationFilters: [macOS]`), erzeugte Projektdatei enthält 4 Treffer (vorher 0), keine Entitlements, kein Team, kein anderes Ziel.
  Code reference: project.yml:1
- [x] AC-9: Sechs Spec-Dateien plus Zeichenkatalog, rund +200/−3 LoC, kein Datenmodell, keine Entitlements, keine Info.plist; `.claude/`, `simulator-run/` und `context-word-learning.md` stehen nicht im Index.

Findings:
- F001 LOW edge_case: Zustand wird in TimelineView und Footer gelesen; sofortige Neuzeichnung bei Ereignis nicht belegt, spätestens beim 60-s-Tick. Evidence: LooseEnds/Views/SettingsView.swift:81. Remediation: beim Mac-Lauf (G-1) beobachten.
- F002 LOW anti_pattern: Test setzt das Singleton `shared` dauerhaft auf localOnly; kein anderer Test liest es. Evidence: LooseEndsTests/SyncStatusTests.swift:57.
- F003 MEDIUM Beleglücke (jetzt in der Spec aufgefangen): Bleibt die Ereignismeldung aus, zeigt die Zeile dauerhaft „Wartet auf iCloud“ und täuscht Hypothese 2 vor. Remediation: Nachgelagert G-0 mit signiertem Bau.

### Runde 2

Nachbohren: Nebenläufigkeit (Swift 6), Zukunftszeit, Event ohne Ende, Lokalisierung, Dateigrenze.

- [x] Swift-6-Nebenläufigkeit: `@MainActor @Observable`, Beobachter auf Main-Queue mit `MainActor.assumeIsolated`, Build grün.
  Code reference: Shared/Persistence/SyncStatus.swift:118
- [x] Event ohne `endDate` ändert nichts; Zukunftszeit ergibt 0 Minuten (beide getestet).
- [x] Lokalisierung: 14 neue Schlüssel mit de und en, positionale Platzhalter.
  Code reference: LooseEnds/Resources/Localizable.xcstrings:1
- [x] Footer-Text ist nicht zeitabhängig.
  Code reference: LooseEnds/Views/SettingsView.swift:88

### Runde 3

Schlussrunde gegen die geänderte, freigegebene Spec (AC-Liste: AC-1 bis AC-6 und AC-9).

- [x] Die Spec enthält nur noch AC-1 bis AC-6 und AC-9; „Nachgelagert“ führt G-0 (früher AC-7) und G-1 (früher AC-8) und nennt beide verbindlich; `Refs #377`, nicht `Closes`.
- [x] Der Code ist seit Runde 2 unverändert: SHA-256 aller sieben Code- und Testdateien stimmt mit dem gestempelten Block überein.
  Code reference: Shared/Persistence/SyncStatus.swift:64
  Code reference: Shared/Persistence/ModelContainerFactory.swift:100
  Code reference: LooseEnds/Views/SettingsView.swift:74
  Code reference: LooseEnds/Resources/Localizable.xcstrings:1
  Code reference: project.yml:1
  Code reference: LooseEndsTests/SyncStatusTests.swift:60
  Code reference: LooseEndsUITests/SettingsSmokeTests.swift:26
- [x] F003 ist ausreichend aufgefangen: Eine Zeile „Wartet auf iCloud“ trotz Netz und Anmeldung gilt erst als Befund für Hypothese 2, wenn G-0 zeigt, dass die Meldung ankommt; sonst ist die Quelle zu wechseln, die Regel bleibt.
- Nachgelagert G-0 und G-1: kein Prüfpunkt dieses Gates, bleiben verbindlich.

Hinweis F-L1 LOW edge_case, kein Defekt: Das Abhören von `eventChangedNotification` ist bis G-0 eine unbelegte Annahme (Spec dokumentiert das). Schnitt 1 ist kein Diagnoseergebnis zu Hypothese 2.
Code reference: Shared/Persistence/SyncStatus.swift:106

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:a0d2b7a6c7be74c255600a5d1e839e5c9b802360c311569905def5b55007cd9f  LooseEnds/Resources/Localizable.xcstrings
- sha256:703f485cad117f54aeafca5da5722c95cb34356f17b9971598575682a31f73f6  LooseEnds/Views/SettingsView.swift
- sha256:1bf8956afd2544e1cfc3975977b6744842b1d9214435e76c968e5c39cfad37bd  LooseEndsTests/SyncStatusTests.swift
- sha256:9501a70b9d8fce9ccff633e2e2d75daa88ee2852612075f1b60f025b005c2395  LooseEndsUITests/SettingsSmokeTests.swift
- sha256:e1dce282fb119c180d62d53c033614d67b4fec332d89c492c045bdda8bec3fb9  Shared/Persistence/ModelContainerFactory.swift
- sha256:5b6cb118a9b5445847017ae83227519f1b6502888b2802789656a9845ce4d6f0  Shared/Persistence/SyncStatus.swift
- sha256:0722bfce76333eabcb2eb081d2edf561580073043ab4a93279b037d2f4978dec  project.yml

## Prüfbasis

- base: 507e06b2b8228cf6165e28aac8e36a1fcd4d957e
- blob:a4b4a8c17b6b4bdf0e0101bfa7c491f172869236  LooseEnds/Resources/Localizable.xcstrings
- blob:92c1965007176fe9b8c92b48d120f33ed318fce4  LooseEnds/Views/SettingsView.swift
- blob:81a5549076adcc1d78b8654384ad01b7326a39a3  LooseEndsTests/SyncStatusTests.swift
- blob:2a546f585ca2f3034850a664bc9c4438ec08f073  LooseEndsUITests/SettingsSmokeTests.swift
- blob:76b9a4c160f541a9713e2f17f8fd71e0ebd300ac  Shared/Persistence/ModelContainerFactory.swift
- blob:f90100b06304087098e690d6af93da3435ea934a  Shared/Persistence/SyncStatus.swift
- blob:d71f252a2dcb86759fbff4eb77c63d0bd1e8a19d  project.yml

## Geprüfte Dateien

- sha256:a0d2b7a6c7be74c255600a5d1e839e5c9b802360c311569905def5b55007cd9f  LooseEnds/Resources/Localizable.xcstrings
- sha256:703f485cad117f54aeafca5da5722c95cb34356f17b9971598575682a31f73f6  LooseEnds/Views/SettingsView.swift
- sha256:1bf8956afd2544e1cfc3975977b6744842b1d9214435e76c968e5c39cfad37bd  LooseEndsTests/SyncStatusTests.swift
- sha256:9501a70b9d8fce9ccff633e2e2d75daa88ee2852612075f1b60f025b005c2395  LooseEndsUITests/SettingsSmokeTests.swift
- sha256:e1dce282fb119c180d62d53c033614d67b4fec332d89c492c045bdda8bec3fb9  Shared/Persistence/ModelContainerFactory.swift
- sha256:5b6cb118a9b5445847017ae83227519f1b6502888b2802789656a9845ce4d6f0  Shared/Persistence/SyncStatus.swift
- sha256:0722bfce76333eabcb2eb081d2edf561580073043ab4a93279b037d2f4978dec  project.yml

## Prüfbasis

- base: 507e06b2b8228cf6165e28aac8e36a1fcd4d957e
- blob:a4b4a8c17b6b4bdf0e0101bfa7c491f172869236  LooseEnds/Resources/Localizable.xcstrings
- blob:92c1965007176fe9b8c92b48d120f33ed318fce4  LooseEnds/Views/SettingsView.swift
- blob:81a5549076adcc1d78b8654384ad01b7326a39a3  LooseEndsTests/SyncStatusTests.swift
- blob:2a546f585ca2f3034850a664bc9c4438ec08f073  LooseEndsUITests/SettingsSmokeTests.swift
- blob:76b9a4c160f541a9713e2f17f8fd71e0ebd300ac  Shared/Persistence/ModelContainerFactory.swift
- blob:f90100b06304087098e690d6af93da3435ea934a  Shared/Persistence/SyncStatus.swift
- blob:d71f252a2dcb86759fbff4eb77c63d0bd1e8a19d  project.yml

# Adversary Dialog — feat-342-texte-fuer-fremde
Spec: docs/specs/feat-342-texte-fuer-fremde.md
Datum: 2026-10-26 13:16

## Checkliste
- [x] **AC-1:** `de.lproj/InfoPlist.strings` enthält `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` und `NSCalendarsFullAccessUsageDescription` mit dem Wortlaut aus „Implementation Details“ 1; `project.yml` und alle `Info.plist` sind unverändert (`git diff` leer, Schritt „Generate leaves the tree clean“ grün).
- [x] **AC-2:** `scripts/test_infoplist_languages.py` ist rot, solange irgendein `NS*UsageDescription` aus `project.yml` (App oder Watch) in `de` fehlt, und grün danach; die Meldung nennt Schlüssel und Datei. Er läuft in der CI über `unittest discover` ohne Änderung an `ci.yml`.
- [x] **AC-3:** Derselbe Test prüft alle Einträge der vier `*.xcstrings` auf einen übersetzten `de`-Wert und wird bei einer künstlichen Lücke rot (Selbstprüfung belegt).
- [x] **AC-4:** Der Hinweis im Fall `.notEligible` nennt in beiden Sprachen Tags, Dauer, Fälligkeit/Wichtigkeit/Dringlichkeit, Wiedererkennung und dass nur der verfeinerte Titel fehlt; `.turnedOff` und `.notReady` sind unverändert; der alte Katalogschlüssel ist entfernt.
- [x] **AC-5:** Die UI-Tests zum Hinweis (Englisch und Deutsch) sind GREEN; der Text erscheint im Siri-Schritt unter `onboardingModelNote`. Unter `--ui-testing` ist der Grund fest („Modell aus“ → `.notEligible`), unabhängig vom Systemmodell des Simulators; außerhalb von UI-Tests bleibt `FoundationModelsEnricher().unavailableReason` unverändert.
- [x] **AC-6:** `docs/reference/datenschutz-entwurf.md` existiert, trägt zu jeder Aussage einen Beleg im Code oder nennt sie als unbelegt, enthält **keine** Kontakte-Zeile und den Status „Entwurf, Freigabe Henning“. Es wird nirgends als gültiger Text eingebaut oder veröffentlicht.
- [x] **AC-7:** Stufe 2: `sim.sh sim-unit` grün (alle Tests), `sim.sh build` baut, `sim.sh test-proof OnboardingTests` liefert den Beleg; Screenshot des Hinweises in Deutsch und Englisch angesehen und beschrieben. Abschluss mit dem Satz „Kein Pfad der Geräteliste berührt.“ (es ändert sich nur `*.lproj`, kein `Info.plist`/`project.yml`).
- [x] **AC-8:** Keine weiteren Änderungen (Scope-Liste oben).

## Dialog

### Runde 1
**Adversary:** Alles zuerst als falsch angenommen, Belege selbst erhoben.
- Wortlaut: `git diff origin/main` der drei Einträge in de.lproj/InfoPlist.strings gegen Implementation Details 1 Zeichen für Zeichen verglichen: identisch. `plutil -lint`: OK. Escaped `\"` im Wert wird vom Parser gelesen (Probe in Temp-Kopie), leerer Wert zählt nicht.
- Sprachtest: `python3 -I scripts/test_infoplist_languages.py -v`: 4 Tests OK. Probe in einer Wegwerf-Kopie (Temp-Ordner, Original unberührt): ohne Mikrofon-Zeile fehlt der Schlüssel (Test würde rot, Meldung nennt Datei und Schlüssel, Zeile 96); Katalogkopie ohne `de` bei „Show subtasks“ wird als Lücke gefunden. `project.yml` liefert App: Kalender, Kamera, Standort, Mikrofon, Sprache; Watch: Mikrofon, Sprache. Alle drei neuen Schlüssel liegen in der einen Datei, die auch die Watch bündelt.
- Gegenbeispiel Parser: ein Schlüssel in einem mehrzeiligen Block-Kommentar `/* ... */` auf eigener Zeile zählt fälschlich als vorhanden (Zeilenkommentar `//` zählt korrekt nicht). Nur latent: die echte Datei enthält so etwas nicht. Finding F001 (LOW).
- Katalog: neuer Schlüssel in OnboardingView.swift und Localizable.xcstrings buchstabengleich (typografische “ ”); alter Schlüssel „Tasks keep the words you said“ per grep in LooseEnds/ und Shared/ nicht mehr vorhanden; `.turnedOff`/`.notReady` im Diff unverändert.
- ContentView: Diff ist eine Zeile (Ternär) unter `ModelContainerFactory.isUITesting`; Text „Apple Intelligence is off under UI testing.“ identisch mit ModelOffEnricher (LooseEndsApp.swift:193). Außerhalb von UI-Tests bleibt `FoundationModelsEnricher().unavailableReason`, kein Produktionsverhalten geändert.
- `git diff origin/main --stat -- project.yml '*.plist' '*.entitlements' .github`: leer.
**Implementierer:** (keine Rückmeldung nötig, Belege liegen im Code)

### Runde 2
**Adversary:** Tiefer gegraben.
- Datenschutz-Entwurf: Stichprobe von 7 Aussagen gegen den Code: `requestWhenInUseAuthorization` (CurrentLocation.swift:119, kein `requestAlways`), `requestFullAccessToEvents` (CalendarBridge.swift:313), `.private(cloudContainer)` (ModelContainerFactory.swift:111), kein `URLSession`, kein `packages:` in project.yml, „nothing leaves the device“ (SpeechCapture.swift:8), `VNDocumentCameraViewController` (DocumentScanner.swift), `requestAuthorization` (DueNotificationCenter.swift:171), `NSPrivacyTracking` false (PrivacyInfo.xcprivacy:5-6): alle stimmen. Kontakte-Gegenprobe `grep -rnE "import Contacts|CNContact"` über alle Ziele: kein Treffer; das Dokument enthält keine Kontakte-Zeile, nur die Aussage „fragt nicht nach Kontakten“. Status „Entwurf, Freigabe Henning“ steht in Zeile 3; grep nach „datenschutz-entwurf“ außerhalb Spec/Context/Briefing/Artefakte: keine Einbindung. Offenes ist als „nicht belegt“ markiert (u. a. Watch-Diktat, Spracherkennungs-Recht).
- UI-Beleg: ui-green-run.txt: 4 Tests, 0 Fehler (beide neuen grün). simulator-run.txt: 4/4 bestanden, 0 übersprungen, iPhone 17 iOS 27.0; die Hashes der Geprüften Dateien stimmen mit der Platte überein (ContentView, OnboardingView, OnboardingTests). Hinweis: `head` im Beleg ist der RED-Commit 1ab4226, die Änderungen sind noch nicht committet; die Hashes decken den Arbeitsstand ab. Screenshot EN (926BA45E…png): Siri-Schritt, oben grauer Fußnotentext „This device has no Apple Intelligence. Tags, durations like “20 minutes”, due dates, importance and urgency are still found by rules, and tasks you captured before are recognised. Only the refined title is missing.“, darunter Mikrofon-Symbol, „Capture without opening the app“, Schaltfläche „Continue“. Screenshot DE (80C00C74…png): gleiche Ansicht, „Dieses Gerät hat kein Apple Intelligence. Tags, Dauer wie „20 Minuten“, Fälligkeit, Wichtigkeit und Dringlichkeit erkennt die App trotzdem per Regeln, schon erfasste Aufgaben erkennt sie wieder. Es fehlt nur der verfeinerte Titel.“, „Erfassen, ohne die App zu öffnen“, „Weiter“. Text ist vollständig, nicht abgeschnitten.
- Tests prüfen Wörter: beide lesen `note.label` und prüfen „Tags“/„durations“/„title“ bzw. „Tags“/„Dauer“/„Titel“, nicht bloß Existenz. Schwäche: Fälligkeit, Wiedererkennung nicht geprüft (Spec verlangt nur Tags, Dauer, Titel). Zeitgleich belegen die Screenshots den vollen Wortlaut.
- Unit-Beleg unit-green-run.txt: „Test Succeeded“. Hinweis: laut Lauf sind zwei Messstrecken (SelfConsistencyReport, TextFormModelReport) und Sprach-Latenztests in de_DE mangels Rohdaten/Sprachmodell „nicht gemessen“; das ist vorbestehend und keine Testfehlschlag, gehört nicht zu #342.
- Scope: `git diff origin/main --stat`: Code nur ContentView, Localizable.xcstrings, InfoPlist.strings, OnboardingView, OnboardingTests, scripts/test_infoplist_languages.py; dazu Spec/Context/Briefing/Artefakte; Datenschutz-Entwurf untracked (7. Datei der Spec). Nichts darüber hinaus. Die Änderung an docs/artifacts/fix-580-.../adversary-dialog.md ist vorbestehend und ausgenommen.
**Implementierer:** (keine Rückmeldung)

### Findings und Bestätigungen
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_infoplist_languages.py:29
  Description: STRINGS_LINE liest zeilenweise; ein auskommentierter Eintrag in einem mehrzeiligen /* */-Block zählt als vorhanden.
  Spec requirement: AC-2 — Test rot, solange ein Schlüssel in de fehlt
  Conflict: Falsch-grün nur bei absichtlich auskommentiertem Schlüssel; die echte Datei hat so etwas nicht. Kein Blocker.
  Remediation: Block-Kommentare vor dem Parsen entfernen (optional).

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Resources/de.lproj/InfoPlist.strings:12
  Evidence: drei Einträge wortgleich zur Spec, plutil OK, project.yml/plist/entitlements unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/test_infoplist_languages.py:91
  Evidence: Test grün, Probe in Kopie rot, Meldung mit Datei und Schlüssel (Z. 96), unittest discover ohne ci.yml-Änderung.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/test_infoplist_languages.py:100
  Evidence: vier Kataloge geprüft, Selbstprüfung Z. 105, eigene Probe findet Lücke.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Views/OnboardingView.swift:90
  Evidence: neuer Text, alter Schlüssel entfernt, übrige Fälle im Diff unberührt; Katalog LooseEnds/Resources/Localizable.xcstrings:392 trägt EN und DE.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/App/ContentView.swift:191
  Evidence: Grund fest unter isUITesting, sonst unverändert; UI-Tests in LooseEndsUITests/OnboardingTests.swift:61 und :78 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: docs/reference/datenschutz-entwurf.md:3
  Evidence: Entwurfsstatus, Belegtabelle stichprobenartig bestätigt, keine Kontakte-Zeile, nirgends eingebunden.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEndsUITests/OnboardingTests.swift:61
  Evidence: Simulator-Beleg 4/4, beide Screenshots angesehen und beschrieben; Geräteliste nicht berührt (nur *.lproj/Katalog, Views).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Resources/Localizable.xcstrings:392
  Evidence: Diffstat zeigt nur Scope-Dateien.
  Status: CONFIRMED


## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:375a2f268367f5ac265b12b1dfa0adc96ecf5ca294413f19e3d53685acead7cd  LooseEnds/App/ContentView.swift
- sha256:cf8e0d1f2268b28f66e35581fc6cc5449b71d27ce8543974ce053e6921d2239a  LooseEnds/Resources/Localizable.xcstrings
- sha256:187664c5c672144df7f1bf7641c407c7660ac630c709dd591d1736e7da879d14  LooseEnds/Resources/de.lproj/InfoPlist.strings
- sha256:96643afa44745b8a535281adcdf7aa6a77b5de5b8b1d6c3612543b96f67ef90f  LooseEnds/Views/OnboardingView.swift
- sha256:14a9ffb620bb3154794f516607b276bdfdb74628bdf70120f598d33ae55b35d7  LooseEndsUITests/OnboardingTests.swift
- sha256:e8facadee42c5c1b776175a6b43340300ba4a8113f1cd8298816c07b02d1652e  docs/reference/datenschutz-entwurf.md
- sha256:d46349edea2944eedc798fbe4e1794ddff7eb63bbc31acae9db5f2d5ff517322  scripts/test_infoplist_languages.py

## Prüfbasis

- base: f0e84ffbc92e3b5d6cb9be6eb6b118c8ba1d9799
- blob:889907dacfc4a16361bb577a16b800a3ee9b445f  LooseEnds/App/ContentView.swift
- blob:ea49112976fa84de8b2c5389f67e451743741cb5  LooseEnds/Resources/Localizable.xcstrings
- blob:bbbe4449c918978a925a3253b2b7b1b99b89e535  LooseEnds/Resources/de.lproj/InfoPlist.strings
- blob:0c30e7de83c87f11f032b6d39ff4cbc8d81a9fe3  LooseEnds/Views/OnboardingView.swift
- blob:f78828008a1d0e67896ab9703581c62a0cfa4842  LooseEndsUITests/OnboardingTests.swift
- blob:28785ef4f34eaf307f5547ed77d93108115d2fe9  docs/reference/datenschutz-entwurf.md
- blob:6467e7d0c3cebc5993b430f30ff7a99627a409ec  scripts/test_infoplist_languages.py

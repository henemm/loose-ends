# Adversary Dialog — 342-sprache-und-start-ohne-modell
Spec: docs/specs/feat-342-schnitt-1a-hinweis-ohne-modell.md
Datum: 2026-10-26 09:10

## Checkliste
- [x] **AC-1:** Der Fall „Gerät ohne Modell“ zeigt auf Englisch „This device has no Apple Intelligence. Due dates, importance, urgency and tags are still found; a duration only when you name it or the task came up before.“ und auf Deutsch „Dieses Gerät hat kein Apple Intelligence. Fälligkeit, Wichtigkeit, Dringlichkeit und Etiketten werden trotzdem erkannt; eine Dauer nur, wenn du sie nennst oder die Aufgabe schon einmal da war.“ — belegt durch UI-Test (`label` von `onboardingModelNote`).
- [x] **AC-2:** Die Fälle „aus“ und „nicht bereit“ stehen unverändert auf dem Bildschirm, belegt durch UI-Test je Fall.
- [x] **AC-3:** `--ui-testing-model-reason=<Grund>` setzt unter `--ui-testing` den Grund des Onboardings; ohne `--ui-testing` ohne Wirkung; ohne das Argument unverändert der echte Grund (im Simulator kein Hinweis, UI-Test belegt „existiert nicht“).
- [x] **AC-4:** `Localizable.xcstrings` enthält den alten Schlüssel „This device has no Apple Intelligence. Tasks keep the words you said; …“ nicht mehr und den neuen mit `de` im Zustand `translated`.
- [x] **AC-5:** Stufe 2: `sim-unit` ganz grün, `build` baut, `test-proof OnboardingTests` liefert den Beleg; Screenshots (DE/EN, Hell/Dunkel) angesehen und beschrieben.
- [x] **AC-6:** Keine weiteren Änderungen: genau die vier Dateien der Tabelle, keine Berechtigung, kein Key, keine `project.yml`/`Info.plist`. Abschlussbericht enthält den Satz „Kein Pfad der Geräteliste berührt.“

## Dialog

### Runde 1
**Adversary:** Gegen den Quelltext geprüft, nicht gegen Behauptungen.
- AC-1: Wortlaut in OnboardingView und xcstrings (EN-Schlüssel, DE-Wert) stimmt Zeichen für Zeichen mit der Spec überein. Die UI-Tests vergleichen `note.label` mit XCTAssertEqual auf den vollen Satz (EN und DE), kein Teilstring: ein falscher Text wird rot. Screenshots EN (1515F787) und DE (62E8408B) geöffnet: grauer Hinweis über der Siri-Erklärung, vollständig, nicht abgeschnitten, Hell.
  Code reference: LooseEnds/Views/OnboardingView.swift:90
- AC-2: Der Diff ändert in modelNote nur die Zeile `.notEligible`; `.turnedOff` und `.notReady` bleiben. Beide Fälle haben UI-Tests mit vollem Wortlaut. OnboardingFlow.modelNote(for:) bildet per contains appleIntelligenceNotEnabled auf .turnedOff, modelNotReady auf .notReady, alles andere (deviceNotEligible) auf .notEligible ab (LooseEnds/Views/OnboardingFlow.swift:52-57).
- AC-3: Das Argument wirkt nur, wenn ModelContainerFactory.isUITesting (Argument --ui-testing) gilt, sonst gilt der echte Grund. grep: das Argument kommt im Produktcode nur an dieser Stelle vor. testNoNoteWhileTheModelIsThere belegt "existiert nicht". Randfall: leerer Wert ergibt "" und damit .notEligible, nur unter --ui-testing, folgenlos (LOW, kein Produktpfad).
  Code reference: LooseEnds/App/ContentView.swift:33
- AC-4: Alter Schlüssel in LooseEnds/, Shared/, Watch*, Widgets, Share nicht mehr vorhanden (grep leer, Treffer nur als Zitat in der Spec). xcstrings ist gültiges JSON (json.load ok), neuer Schlüssel hat de mit state translated.
- AC-5: test-proof OnboardingTests 7/7 grün, 0 übersprungen, Beleg simulator-run.txt (head fc5c408); sim-unit "Unit-Tests bestanden" (1 von 4 Messstrecken und Latenzschutz nicht gemessen, vorbestehend). Dunkel-Screenshots fehlen: docs/artifacts/342-sprache-und-start-ohne-modell/ac5-*.png existieren nicht, die fünf Beleg-Bilder sind Hell. Die Spec verlangt Hell und Dunkel. Offen.
- AC-6: Produkt-/Testdiff genau ContentView.swift, OnboardingView.swift, Localizable.xcstrings, OnboardingTests.swift; keine project.yml, Info.plist, entitlements; sonst nur Artefakte. Keiner der Pfade steht in der Geräteliste. Der Pflichtsatz gehört in den Abschlussbericht, der noch aussteht.
  Code reference: LooseEnds/App/ContentView.swift:202
**Implementierer:** Belege liegen in test-green-output.txt, test-green-unit-output.txt und simulator-run.txt.

### Runde 2
**Adversary:** Alle sechs ac5-Bilder geöffnet. de-light und de-dark: DE-Hinweis exakt wie Spec, vier Zeilen, nicht abgeschnitten, im Dunkel grau auf Nahezu-Schwarz gut lesbar. en-light und en-dark: EN-Hinweis exakt wie Spec, drei Zeilen, vollständig, dunkel lesbar. off-en: "Apple Intelligence is off. Turn it on in Settings so new tasks get a title and a duration." unverändert, zwei Zeilen. notready-en: "Apple Intelligence is still getting ready. Tasks captured meanwhile are sorted once it is." unverändert. AC-5 damit bewiesen (Tests grün, Bilder Hell und Dunkel, DE und EN). Der Satz "Kein Pfad der Geräteliste berührt." ist Pflicht des Abschlussberichts, kein Defekt der Umsetzung. Kein Defekt gefunden.
**Implementierer:** Bilder per sim.sh build und launch mit --ui-testing-model-reason aufgenommen.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Einziger Schreibweg: ContentView.modelUnavailableReason liefert den Testgrund nur unter `--ui-testing`, sonst FoundationModelsEnricher().unavailableReason. Bedingung davor: `--ui-testing` gesetzt. Test für diesen Weg: OnboardingTests.testNoModelNoteSaysWhatStillWorksInEnglish samt den drei weiteren Fallbildern.

## Verdict
VERDICT: VERIFIED

AC-1 bis AC-6 bewiesen (Pflichtsatz im Abschlussbericht ist Berichtspflicht). Tests: 7 UI-Tests bestanden, Unit-Lauf grün, 0 fehlgeschlagen, 0 übersprungen in OnboardingTests. Kein Defekt gefunden.

## Geprüfte Dateien

- sha256:ba7afe517df606a5eb63fb575cd7cba7c85a59c4c86aedf7d8164af3ecf9528d  LooseEnds/App/ContentView.swift
- sha256:5d6afeda7ff74cdffee0952a201e04b5c2bfe0c786a8f2b57de5e5c7a56b5934  LooseEnds/Views/OnboardingView.swift

## Prüfbasis

- base: c4790a534e0bd827548a4991a4d0e3163560c7bb
- blob:f2e18fc131abc6c7152eec8c9b4078f01d19c699  LooseEnds/App/ContentView.swift
- blob:3f60029d4032f508ad1d3c5f0c6deec7cb1d26de  LooseEnds/Views/OnboardingView.swift

## Geprüfte Dateien

- sha256:ba7afe517df606a5eb63fb575cd7cba7c85a59c4c86aedf7d8164af3ecf9528d  LooseEnds/App/ContentView.swift
- sha256:5d6afeda7ff74cdffee0952a201e04b5c2bfe0c786a8f2b57de5e5c7a56b5934  LooseEnds/Views/OnboardingView.swift

## Prüfbasis

- base: c4790a534e0bd827548a4991a4d0e3163560c7bb
- blob:f2e18fc131abc6c7152eec8c9b4078f01d19c699  LooseEnds/App/ContentView.swift
- blob:3f60029d4032f508ad1d3c5f0c6deec7cb1d26de  LooseEnds/Views/OnboardingView.swift

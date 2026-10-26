# Context: feat-342-texte-fuer-fremde

Ticket #342 (Teile 2, 4, 5), Epic #371. Die Apple-Seite (Teile 1 und 3) ist #705 und nicht Teil dieses Workflows.

## Request Summary
Eine Person außer Henning bekommt eine App, deren Texte sie versteht und die zu dem passen, was die App tut:
Berechtigungstexte und Datenschutztext (Teil 2), Deutsch/Englisch vollständig (Teil 4), ehrlicher Hinweis beim
ersten Start ohne Apple Intelligence (Teil 5).

## Befunde (belegt, Stand 2026-10-26)

### Teil 4 — Deutsch/Englisch
- `Localizable.xcstrings` (481 Einträge), `AppShortcuts.xcstrings` (5), `LooseEndsWidgets/Localizable.xcstrings` (25),
  `LooseEndsShare/Localizable.xcstrings` (10): Quellsprache `en`, **null** fehlende deutsche Einträge
  (Zählung mit `shouldTranslate`-Filter, Varianten ausgenommen). Die Lücke liegt nicht hier.
- **Echte Lücke: Berechtigungstexte.** `LooseEnds/Resources/de.lproj/InfoPlist.strings` übersetzt nur
  `NSLocationWhenInUseUsageDescription` und `NSCameraUsageDescription`. **Es fehlen auf Deutsch:**
  `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSCalendarsFullAccessUsageDescription`
  (`project.yml:98-102`). Ein deutsches iPhone zeigt diese drei Abfragen auf Englisch (Rückfall auf den
  Info.plist-Wert, bestätigt durch die Suche: lokalisierte Werte stehen nur in `InfoPlist.strings`, fehlt der Schlüssel,
  gilt der englische Wert in `Info.plist`).
- **Watch:** `LooseEndsWatch` hat Mikrofon- und Spracherkennungstext (`project.yml:158-159`), aber keine
  `InfoPlist.strings` (`find`: keine Datei außer den zwei der App). Auf der deutschen Watch also Englisch.
- Kein Test prüft die `InfoPlist.strings`-Vollständigkeit. `scripts/test_info_plist_sync.py` vergleicht `Info.plist`
  mit `project.yml`, nicht die Sprachen.

### Teil 2 — Datenschutz und Berechtigungstexte
- Die App fragt nach: Mikrofon, Spracherkennung, Kamera (`DocumentScanner`, VisionKit), Standort (nur „beim Verwenden“),
  Kalender (`CalendarBridge`), Mitteilungen (Systemdialog, kein Info.plist-Schlüssel nötig). Fotos über `PhotosPicker`
  (kein Schlüssel nötig), Dateien über `fileImporter`.
- **Kontakte: nicht nötig.** Kein `import Contacts` / `CNContact` in `LooseEnds/`, `Shared/`, `LooseEndsShare/`.
  Die Zeile im Ticket („Kontakte“) streicht damit, mit diesem Beleg. (Ein Berechtigungstext ohne Zugriff wäre eine
  falsche Angabe an Apple.)
- Texte sind kurz und sachlich; Kalender und Standort sind die ehrlichsten (Bedingung steht drin). Mikrofon- und
  Sprachtext sagen nicht, **wohin das Gesagte geht**: Apple prüft statisch, ob ein Zweck steht (ITMS-90683), nicht den
  Wortlaut; Prüfer sind uneinheitlich bei vagen Texten.
- `PrivacyInfo.xcprivacy` je Target (App, Widgets, Watch, WatchWidgets, Share): kein Tracking, keine gesammelten Datentypen,
  nur `UserDefaults` mit Grund `CA92.1`. Das stimmt für die App selbst (CloudKit privat, kein eigenes Backend);
  das Mac-App-Sandbox-Recht `files.user-selected.read-only` und `network.client` sind in `project.yml:54-61`.
- **Es gibt keinen Datenschutztext im Repo** (`docs/` enthält keinen). Für externe TestFlight-Tester verlangt Apple
  laut App Store Connect Help nur die Beta-App-Beschreibung ausdrücklich (Pflichtfeld); Rückmelde-E-Mail,
  Datenschutz-URL und Kontaktangaben nennt die Apple-Seite nicht als Pflicht, Drittquellen nennen die URL
  als Feld der Beta-App-Informationen. **Das gehört zu #705** (Apple-Seite), der Text selbst zu #342.

### Teil 5 — Erster Start ohne Modell
- `OnboardingFlow.modelNote(for:)` (`LooseEnds/Views/OnboardingFlow.swift:52`) bildet den Grund des Systems auf drei Fälle ab,
  `OnboardingView.modelNote` (`OnboardingView.swift:82`) zeigt sie unter dem Siri-Schritt.
- Texte heute: `turnedOff` („…so new tasks get a title and a duration“), `notReady` („…sorted once it is“),
  `notEligible` („Tasks keep the words you said; due dates, importance and urgency are still found.“).
- `notEligible` nennt **nicht**, was seit #232/#441/#673/#136 auch ohne Modell per Regel läuft: Tags aus Wörtern,
  Dauer aus „20 Minuten“, Wiedererkennung früherer Aufgaben. Und er sagt nicht, was fehlt: Titelverfeinerung und
  Dauer/Energie ohne Wiedererkennung (`docs/reference/modell-verfuegbarkeit.md`, Kurzfassung).
- Test heute: `OnboardingFlowTests.modelNote` prüft nur die Abbildung Grund → Fall, **nicht den Text** und nicht, dass die
  Anzeige erscheint. Kein UI-Test auf `onboardingModelNote` (`grep` in `LooseEndsUITests`: leer). Unter `--ui-testing`
  ist das Modell ohnehin aus (`ModelOffEnricher`), der Grund also vorhanden — das trägt einen Test.

## Related Files
| Datei | Relevanz |
|-------|----------|
| `LooseEnds/Resources/de.lproj/InfoPlist.strings`, `en.lproj/InfoPlist.strings` | drei deutsche Berechtigungstexte fehlen |
| `project.yml` (Zeilen 98–102 App, 158–159 Watch) | Quelle der englischen Texte; Info.plist ist nur Abbild (#499) |
| `LooseEndsWatch/` (keine `InfoPlist.strings`) | Watch-Texte nur Englisch |
| `LooseEnds/Views/OnboardingFlow.swift`, `OnboardingView.swift` | Hinweis ohne Modell |
| `LooseEndsTests/OnboardingFlowTests.swift` | Test der Abbildung |
| `LooseEnds/Resources/Localizable.xcstrings` | Hinweistexte, deutsch vorhanden |
| `scripts/test_info_plist_sync.py` | Vorbild für einen Sprachvollständigkeits-Test |
| `docs/reference/modell-verfuegbarkeit.md` | Quelle der Aussage, was ohne Modell fehlt |

## Existing Patterns
- Berechtigungstexte: Quelle `project.yml` (englisch), Übersetzung je `<lang>.lproj/InfoPlist.strings` (#347 für Siri-Namen, #241/#442 für Standort/Kamera).
- Sprachwerkzeuge in Python unter `scripts/test_*.py`, in der CI als Schritt.
- Reine Regeln in `OnboardingFlow` (testbar ohne UI), Anzeige in `OnboardingView`.

## Dependencies
- Upstream: `project.yml` → `generate` → `Info.plist`; Xcode bündelt `*.lproj/InfoPlist.strings` (`project.yml:135`).
- Downstream: Systemdialoge der App und der Watch; Apples statische Prüfung beim TestFlight-Upload (Zweck-Text vorhanden).

## Existing Specs / Entscheidungen
- ADR-4 und Annahme A4 (Modell nur in der App, „kein Modell“ ist Normalzustand), `docs/reference/modell-verfuegbarkeit.md`.
- CLAUDE.md: `project.yml` und `Info.plist` stehen auf der Geräteliste → Stufe 3 über TestFlight, nur nach Hennings „jetzt ist ein Test möglich“.

## Risks & Considerations
- **Stufe 3 greift** (`project.yml`/`Info.plist`/Watch-Dateien berührt). Ob ein Gerätelauf nötig ist, wenn nur `InfoPlist.strings`
  und kein Eintrag in `project.yml` geändert wird, entscheidet die Spec; die Geräteliste nennt `Info.plist`, nicht `*.lproj`.
- Neue `InfoPlist.strings` für die Watch: Target-Quelle in `project.yml` ergänzen (`sources`/Ressourcen), sonst wird sie nicht gebündelt; Mac und iOS teilen die App-Ressourcen.
- Datenschutztext ist **Produkt- und Rechtsinhalt**: Henning gibt ihn frei (steht im Ticket); ich schreibe nur einen Entwurf aus dem, was der Code beweist.
- Scoping: Texte (≈4 Dateien) + Test + Hinweis (≈3 Dateien) liegen an der Grenze von 4–5 Dateien. Der Datenschutztext als Dokument zählt mit.
- Hinweistexte ändern: zwei Sprachen in `Localizable.xcstrings`, sonst fällt der Sprachtest.

## Korrektur zu den Befunden (Analyse 2026-10-26)
- **Watch:** `project.yml:131-136` bündelt `LooseEnds/Resources/*.lproj/InfoPlist.strings` auch in `LooseEndsWatch` (#355).
  Es braucht also **keine** neue Datei und keinen `project.yml`-Eintrag: dieselben drei Schlüssel in `de.lproj/InfoPlist.strings`
  übersetzen App **und** Watch (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` heißen dort gleich).
  Der Watch-Text sagt „auf deiner Uhr“, der der App „auf deinem Gerät“; ein gemeinsamer deutscher Text sagt „auf deinem Gerät“.
- Damit entfällt die Sorge „`project.yml` berührt → Stufe 3“: Es ändert sich nur `*.lproj/InfoPlist.strings` (nicht auf der Geräteliste).
  Ob die Stufe trotzdem greift, entscheidet die Spec; Vorschlag: Kein Pfad der Geräteliste berührt.

## Analysis

### Type
Feature (Texte und eine Anzeige; kein Fehler, der nachzustellen wäre).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Resources/de.lproj/InfoPlist.strings` | MODIFY | drei fehlende deutsche Berechtigungstexte (Mikrofon, Sprache, Kalender); Mikrofon/Sprache sagen, dass es auf dem Gerät bleibt |
| `scripts/test_infoplist_languages.py` | CREATE | Test: jeder `NS*UsageDescription` aus `project.yml` hat in `de` und `en` einen Eintrag; sonst rot (CI-Schritt) |
| `.github/workflows/ci.yml` | MODIFY | Schritt für den Sprachtest |
| `LooseEnds/Views/OnboardingView.swift` | MODIFY | Text `.notEligible` nennt, was ohne Modell läuft und was fehlt |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | alter Schlüssel ersetzt, neuer deutsch/englisch |
| `LooseEndsTests/OnboardingFlowTests.swift` | MODIFY | Test: Text je Fall nicht leer, nennt Tags/Dauer; Anzeige erscheint |
| `docs/reference/datenschutz-entwurf.md` | CREATE | Entwurf des Datenschutztextes aus dem, was der Code beweist; Henning gibt frei |

### Scope Assessment
- Files: 7 (davon 1 Dokument, 1 Workflow-Zeile) — an der Grenze, Code-Anteil ≈ 4 Dateien
- Estimated LoC: ca. +150/−5
- Risk Level: LOW (Texte; kein Modell, keine Persistenz, keine Berechtigung ändert sich)

### Technical Approach
Regelweg, ohne Modell: reine Texte, Datei-Vergleich, eine Regel-Abbildung, die es schon gibt.
1. Teil 4: drei fehlende `InfoPlist.strings`-Einträge + ein Python-Test, der Lücken künftig rot macht (Vorbild `test_info_plist_sync.py`).
   Die vier `xcstrings` haben nachweislich null Lücken; der Test deckt sie mit ab (nur `shouldTranslate`, Varianten ausgenommen).
2. Teil 5: nur der Text für `notEligible` ändert sich: sagt, dass Tags aus Wörtern, Dauer aus „20 Minuten“, Fälligkeit und
   Wiedererkennung weiterlaufen, und was fehlt (Titelverfeinerung). Kein neuer Fall in `modelNote(for:)`.
   Quelle der Aussage: `docs/reference/modell-verfuegbarkeit.md`. Anzeige per UI-Smoke-Test (`onboardingModelNote`), weil unter `--ui-testing` das Modell aus ist.
3. Teil 2: **Kontakte streicht** (kein `Contacts`-Import). Datenschutztext als Entwurf im Repo; Henning gibt ihn frei, die URL gehört zu #705.

### Alternativen (Pflicht)
- **A. Datenschutztext als Seite in der App** (Einstellungen → „Datenschutz“) statt Dokument im Repo: der Fremde liest ihn dort,
  braucht keine URL. Kippt: Entscheidung „Texte nur in `docs/`“ gibt es nicht, aber #705 (URL) würde entfallen oder zweitrangig; mehr Code (View, UI-Test), Scoping-Grenze gesprengt → eigenes Ticket.
- **B. Hinweis ohne Modell gar nicht zeigen**, weil „kein Modell“ der Normalzustand ist (ADR-4/A4): kein Fall, kein Text.
  Gegen B: Das Ticket verlangt den ehrlichen Hinweis; ohne ihn wundern sich Fremde, warum Titel und Dauer unveränderlich bleiben.
- **C. Berechtigungstexte per Xcode-String-Katalog** (`InfoPlist.xcstrings`) statt `.strings`: modern, ein Katalog. Kippt #347/#241 (`.strings` mit Variablen für Siri-Namen) und den Watch-Weg; kein Gewinn für diesen Schnitt.
- Empfehlung: Plan wie oben (Dateien + Test + Text), A als Folgeticket nach Hennings Freigabe des Entwurfs.

### Dependencies
`project.yml` bleibt unverändert; `generate` schreibt keinen Diff. Downstream: Systemdialoge App und Watch; Apples statische Prüfung (Zweck vorhanden).

### Entwurf vor Spec
Sichtbar ändert sich nur ein Satz im Onboarding (kein Umbau von Layout). Die Vorher/Nachher-Texte zeigt die Zusammenfassung unten; eine Artefakt-Seite ist dafür nicht nötig, Henning kann sonst in der Freigabe widersprechen.

### Open Questions
- [ ] Datenschutztext: Henning gibt den Entwurf frei (Inhalt, nicht Technik).
- [ ] Abnahme: Mit Vorschlag „Kein Pfad der Geräteliste berührt“ endet sie nach Simulator (zwei Sprachen im Simulator durchspielen).

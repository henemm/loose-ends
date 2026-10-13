---
entity_id: feat-355-s1-siri-saetze-watch
type: feature
created: 2026-10-13
updated: 2026-10-13
status: draft
workflow: feat-355-s1-siri-saetze-watch
---

# Spec: #355 Schnitt 1 — Deutsche Siri-Sätze auf der Apple Watch

## Approval

- [ ] Approved

## Purpose

Auf der Apple Watch soll eine deutsche Siri „Erfasse in Loose Ends“ (und die übrigen deutschen Sätze) verstehen,
nach dem Text fragen und ohne App-Start speichern. Heute kann sie das nicht: Das Watch-Paket enthält keinen einzigen
deutschen Satz, keine deutschen Dialoge und keine Ersatznamen der App. Schnitt 1 bringt Sätze, Dialoge und
App-Namen-Varianten auf Deutsch ins Watch-Bundle und ergänzt den neuen Satz „Erfasse in Loose Ends“ für alle
Plattformen. Der Regelweg genügt: Es gibt nichts zu verstehen, nur Ressourcen einem weiteren Target zuzuordnen.

## Source

- **Dateien:** `Shared/Intents/CaptureTextIntent.swift` (`struct LooseEndsShortcuts: AppShortcutsProvider`),
  `LooseEnds/Resources/AppShortcuts.xcstrings`, `project.yml` (Target `LooseEndsWatch`),
  `.github/workflows/testflight.yml` (Archivprüfung), `scripts/test_siri_phrases.py` (neu)
- **Ticket:** #355, Schnitt 1 von 3 (Henning, 2026-10-13)

## Ist-Befund (am gebauten Paket belegt, 2026-10-13)

Watch-Bau `Debug-watchsimulator/LooseEndsWatch.app`:

- kein einziger `*.lproj`-Ordner, kein `Metadata.appintents/root.ssu.yaml`; `extract.actionsdata` registriert
  `CaptureTextIntent` mit nur vier englischen Sätzen
- `Info.plist` ohne `INAlternativeAppNames` und ohne `CFBundleSpokenName`
- zum Vergleich der iPhone-Bau: `de.lproj/AppShortcuts.strings`, `de.lproj/nlu.appintents`,
  `de.lproj/InfoPlist.strings`, `root.ssu.yaml` mit `de`

Dialog („What should I remember?“) und Intent-Titel sind auf der Watch deshalb ebenfalls englisch.

## Recherche (Quellen)

- WWDC23 10102 „Spotlight your app with App Shortcuts“ (https://developer.apple.com/videos/play/wwdc2023/10102/):
  Watch-Kurzbefehle müssen aus einer auf der Uhr installierten watchOS-App kommen; flexibles Matching gibt es auf der
  Watch nicht, Sätze müssen wörtlich gesprochen werden; jeder Satz braucht den App-Namen oder ein Synonym.
- Apple-Forum 831639 (Apple-Ingenieur): Der Provider in der Watch-App macht die Kurzbefehle für Siri auf der Watch
  verfügbar; watchOS erkennt Sätze strenger, eher mehr und einfachere Sätze.
- Apple-Forum 843538: Ein String Catalog darf in mehreren Targets liegen.
- SiriKit „Specifying synonyms for your app name“: watchOS-Apps erben Ersatznamen nicht von der iOS-App, sie müssen
  im Watch-`Info.plist` stehen. Forum 832258: `INAlternativeAppNames` gilt auch für App Shortcuts.
- Siri-Berechtigung (`com.apple.developer.siri`): Apples Doku („Configuring Siri support“) bindet sie an
  Intents-Extensions; keine Quelle verlangt sie für App Shortcuts. Gegenbefund intern: #347, Build 43 (iPhone)
  ignorierte die Ersatznamen ohne Berechtigung.
- Größtes Risiko: Forum 720108 — ein String-`@Parameter` mit `requestValueDialog` führte auf watchOS 9.2/10 beta zu
  einem Siri-Fehler, `perform()` wurde nie aufgerufen; ungelöst. Ob das unter watchOS 27 noch gilt, zeigt nur die
  echte Watch.

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `AppShortcutsProvider` / `CaptureTextIntent` | Framework / Intent | Quelle der Siri-Sätze; `Shared` kompiliert bereits in die Watch |
| `LooseEnds/Resources/AppShortcuts.xcstrings` | Ressource | Deutsche Sätze; künftig auch im Watch-Target (eine Datei, keine Kopie) |
| `LooseEnds/Resources/Localizable.xcstrings` | Ressource | Intent-Titel, Kurztitel, Dialoge auf Deutsch; künftig auch im Watch-Target |
| `LooseEnds/Resources/{de,en}.lproj/InfoPlist.strings` (#347) | Ressource | Siri-Name der App (`CFBundleSpokenName`, `LE_ALT_NAME_1…3`) |
| `project.yml` (XcodeGen) | Build | Target `LooseEndsWatch`: Quellen, `Info.plist`-Eigenschaften |
| `.github/workflows/testflight.yml` | CI | Archivprüfung je Bundle (#323, #326, #347) |
| `scripts/test_entitlements_sync.py`, `scripts/test_ci_xcode27.py` | Skripttests | dürfen nicht brechen |
| `CaptureService.save(_, via:in:)`, `ModelContainerFactory.make()` | Nachbar | speichern auf der Watch, unverändert |

## Scope

### Affected Files

| Datei | Änderungsart | Beschreibung |
|---|---|---|
| `project.yml` | MODIFY | Watch-Target: `path: LooseEnds/Resources` mit `includes: [AppShortcuts.xcstrings, Localizable.xcstrings, "*.lproj/InfoPlist.strings"]` (Assets bleiben draußen); Watch-`Info.plist`: `CFBundleSpokenName` und `INAlternativeAppNames` mit denselben `LE_ALT_*`-Variablen wie iOS. Keine Siri-Berechtigung. |
| `Shared/Intents/CaptureTextIntent.swift` | MODIFY | 5. Satz `"Capture with \(.applicationName)"` (wirkt auf iPhone, Mac und Watch) |
| `LooseEnds/Resources/AppShortcuts.xcstrings` | MODIFY | Schlüssel `Capture with ${applicationName}` → de `Erfasse in ${applicationName}`, `state: translated` |
| `.github/workflows/testflight.yml` | MODIFY | Sprach-/Siri-Prüfung als Funktion je Bundle; Watch: `de.lproj` vorhanden, alle 5 deutschen Sätze, Siri-Namen in `InfoPlist.strings` (de/en); neuer Satz auch in der iPhone-Prüfung. Keine Siri-Berechtigungsprüfung für die Watch. |
| `scripts/test_siri_phrases.py` | CREATE | Jeder Satz in `CaptureTextIntent.swift` hat genau einen Katalogschlüssel mit deutscher Übersetzung, kein veralteter Schlüssel; Watch-Target in `project.yml` führt Katalog und `InfoPlist.strings` |

### Estimated Changes

- Files: 5 (Grenze 4–5 eingehalten)
- LoC: ca. +140/−15 (unter 250)

### Nicht Teil dieser Spec

- Schnitt 2: `WatchCaptureView` deutsch, wieder bereit nach „Gespeichert“.
- Schnitt 3: Komplikation und Einstellungshinweis; ebenso der Onboarding-Text („In Loose Ends erfassen“, an den
  neuen Satz angleichen).
- Quelle `.watch`: `CaptureTextIntent` speichert weiter `via: .siri`, auch auf der Watch (das Ticket akzeptiert
  „Siri oder Watch“).
- Siri-Berechtigung für die Watch-Kennung (Variante B, siehe Alternativen).

## Implementation Details

Die Kataloge und `InfoPlist.strings` der iOS-App werden zusätzlich ins Watch-Target eingebunden (dieselbe Datei,
keine Kopie). Das Watch-`Info.plist` bekommt `CFBundleSpokenName` und `INAlternativeAppNames` mit den Variablen
`LE_ALT_NAME_1…3`, deren Werte je Sprache aus `InfoPlist.strings` kommen. Der neue Satz steht 1:1 als englischer
Schlüssel im Katalog und im Provider; die deutsche Fassung ist „Erfasse in ${applicationName}“. Er hat die Form
„Verb + in + App-Name“, die der Wunsch von Henning ist.

Reihenfolge (TDD): `test_siri_phrases.py` schreiben und rot sehen, Satz und Katalogeintrag, `project.yml`,
`./scripts/sim.sh generate`, watchOS-Simulatorbau mit Paketinspektion, danach `testflight.yml`, zuletzt die
bestehenden Skripttests.

Der deutsche Siri-Dialog bleibt „Was soll ich aufnehmen?“ (bestehende Übersetzung auf dem iPhone). Das Ticket nennt
„Was soll ich mir merken?“; das ist eine bewusste Abweichung vom Ticketwortlaut zugunsten gleicher Texte auf allen
Geräten und wird hier offen benannt.

Die Archivprüfung in `testflight.yml` wird von einer Prüfung nur für `com.henning.looseends` zu einer Funktion je
Bundle umgebaut. Für die Watch prüft sie `de.lproj`, alle fünf deutschen Sätze und die Siri-Namen in
`InfoPlist.strings`; die Siri-Berechtigung wird dort nicht verlangt. Details stehen in der Datei, nicht hier.

## Test Plan

### Automated Tests (TDD RED)

Neues Skript `scripts/test_siri_phrases.py` (erst rot, dann grün):

- [ ] Test 1: GIVEN `CaptureTextIntent.swift` listet 5 Sätze / WHEN das Skript jeden Satz gegen `AppShortcuts.xcstrings`
  prüft / THEN hat jeder Satz genau einen Schlüssel mit `de`-Übersetzung im Zustand `translated`. Rot vor der
  Änderung, weil „Capture with ${applicationName}“ fehlt.
- [ ] Test 2: GIVEN der Katalog enthält einen Schlüssel ohne passenden Satz im Code / WHEN das Skript läuft / THEN
  schlägt es fehl (kein veralteter Schlüssel).
- [ ] Test 3: GIVEN `project.yml` / WHEN das Skript das Target `LooseEndsWatch` liest / THEN führt es
  `AppShortcuts.xcstrings`, `Localizable.xcstrings` und `*.lproj/InfoPlist.strings` unter `sources`, und das
  Info.plist enthält `INAlternativeAppNames` und `CFBundleSpokenName`. Rot vor der Änderung.
- [ ] Test 4: GIVEN die Satzliste / WHEN das Skript sie auswertet / THEN enthält sie deutsche und englische Sätze
  (Ticketforderung „Siri-Satzliste enthält DE und EN“).

Bestehende Läufe: `scripts/test_entitlements_sync.py`, `scripts/test_ci_xcode27.py` und `./scripts/sim.sh unit`
bleiben grün.

**Kein neuer UI-Test, begründet:** Es entsteht keine View und kein sichtbarer App-Ablauf; der Simulator kann keine
Siri-Sätze sprechen. Der Bundle-Inhalt wird in Stufe 2 geprüft, das Verhalten in Stufe 3.

## Abnahme

- **Stufe 1:** `test_siri_phrases.py` erst rot, dann grün; `test_entitlements_sync.py`, `test_ci_xcode27.py`;
  `./scripts/sim.sh unit`.
- **Stufe 2:** `./scripts/sim.sh generate`, watchOS-Simulatorbau und Paketinspektion des Watch-Bundles
  (`de.lproj/AppShortcuts.strings`, `de.lproj/Localizable.strings`, `de.lproj/InfoPlist.strings`,
  `Metadata.appintents` mit `de/root.ssu.yaml`, `Info.plist` mit `INAlternativeAppNames`) sowie des iPhone-Bundles
  (neuer Satz auf Deutsch). **Der Simulator kann Siri nicht sprechen:** Stufe 2 belegt Paketinhalt und Bau, nicht die
  Erkennung.
- **Stufe 3 greift** (`project.yml`, Watch): über TestFlight und Hennings Rückmeldung (Buildnummer und Prüfschritte,
  keine Befehlszeile). Nichts auf seinen Geräten ohne sein ausdrückliches „jetzt ist ein Test möglich“.

## Acceptance Criteria

- **AC-1:** Neuer Satz im Code — `LooseEndsShortcuts` enthält fünf Sätze, darunter `"Capture with \(.applicationName)"`.
  Nachweis: `scripts/test_siri_phrases.py` (Test 1) und Diff.
- **AC-2:** Katalog vollständig — `AppShortcuts.xcstrings` hat für jeden der fünf Sätze genau einen Schlüssel mit
  deutscher Übersetzung (`translated`), der neue lautet „Erfasse in ${applicationName}“, und es gibt keinen
  veralteten Schlüssel. Nachweis: `test_siri_phrases.py` grün, davor nachweislich rot.
- **AC-3:** Watch-Target führt die Ressourcen — `LooseEndsWatch` bindet `AppShortcuts.xcstrings`,
  `Localizable.xcstrings` und `*.lproj/InfoPlist.strings` aus `LooseEnds/Resources` ein (ohne Kopie, ohne Assets).
  Nachweis: `test_siri_phrases.py` (Test 3).
- **AC-4:** Ersatznamen im Watch-Info.plist — Das Watch-`Info.plist` enthält `CFBundleSpokenName` und
  `INAlternativeAppNames` mit denselben `LE_ALT_*`-Variablen wie iOS; keine Siri-Berechtigung wird hinzugefügt.
  Nachweis: `test_siri_phrases.py`, `test_entitlements_sync.py` grün, Diff von `project.yml`.
- **AC-5:** Watch-Bundle enthält Deutsch (Stufe 2) — Das gebaute Watch-Paket enthält `de.lproj/AppShortcuts.strings`
  mit allen fünf deutschen Sätzen, `de.lproj/Localizable.strings`, `de.lproj/InfoPlist.strings` und
  `Metadata.appintents` mit `de/root.ssu.yaml`; die gebaute `Info.plist` enthält `INAlternativeAppNames`. Nachweis:
  Paketinspektion nach watchOS-Simulatorbau, Befund im Abschlussbericht.
- **AC-6:** iPhone-Bundle trägt den neuen Satz (Stufe 2) — Das gebaute iPhone-Paket enthält „Erfasse in
  ${applicationName}“ in `de.lproj/AppShortcuts.strings`. Nachweis: Paketinspektion.
- **AC-7:** CI sichert das Watch-Bundle ab — Die Archivprüfung in `testflight.yml` prüft je Bundle, und für die Watch
  `de.lproj`, die fünf deutschen Sätze und die Siri-Namen in `InfoPlist.strings` (de/en); der neue Satz steht auch in
  der iPhone-Prüfung; für die Watch wird keine Siri-Berechtigung verlangt. Nachweis: Diff und
  `scripts/test_ci_xcode27.py` grün; der Archivlauf selbst ist der Beleg im TestFlight-Bau.
- **AC-8:** Bestehendes bleibt grün — `./scripts/sim.sh unit`, `test_entitlements_sync.py`, `test_ci_xcode27.py`
  bestehen. Nachweis: Lauf-Ausgaben.
- **AC-9:** Gerät, TestFlight: Satz wird verstanden — Eine deutsche Siri auf Hennings Watch versteht „Erfasse in Loose
  Ends“ und die übrigen vier deutschen Sätze und startet den Erfassungsablauf. Nachweis: Hennings Rückmeldung zum
  TestFlight-Bau.
- **AC-10:** Gerät, TestFlight: Rückfrage und Speichern — Siri fragt auf der Watch nach dem Text und speichert ihn
  ohne App-Start als Aufgabe, die auf dem iPhone ankommt. Nachweis: Hennings Rückmeldung. Scheitert die
  Rückfrage (Risiko 1), wird Variante D als neues Ticket angelegt; AC-10 gilt dann als offen und nicht erfüllt.
- **AC-11:** Gerät, TestFlight: Ersatznamen — Siri erkennt „Loose End“, „LooseEnds“ oder „Lose Enden“ als App-Name auf
  der Watch, oder der Befund „Ersatznamen ohne Siri-Berechtigung ignoriert“ wird ausdrücklich festgehalten und als
  Folgeticket (Variante B) angelegt. Nachweis: Hennings Rückmeldung.

## Known Risks

1. **Siri-Rückfrage nach dem Text auf der Watch (Forum 720108).** Auf älteren watchOS-Versionen rief Siri `perform()`
   mit einem String-Parameter und `requestValueDialog` nie auf. Nur die echte Watch zeigt, ob das unter watchOS 27
   noch so ist. Rückfall: Variante D (Kurzbefehl öffnet die App) als neues Ticket.
2. **Satzform und Rückfrage „Notizen oder Loose Ends?“.** „Erfasse in Loose Ends“ hat die Form, die bei #367
   („Merk dir in …“) eine Rückfrage auslöste. Henning will den Satz ausdrücklich; die übrigen vier Sätze bleiben.
3. **Wörtliches Sprechen.** Auf der Watch gibt es kein flexibles Matching; die Sätze müssen genau so gesprochen
   werden.
4. **Dialogtext.** Der deutsche Dialog bleibt „Was soll ich aufnehmen?“ (wie auf dem iPhone); das Ticket nennt „Was
   soll ich mir merken?“. Abweichung offen benannt, keine Änderung in diesem Schnitt.
5. **Ersatznamen ohne Siri-Berechtigung.** Auf dem iPhone wurden sie in Build 43 ohne Berechtigung ignoriert; für
   watchOS ist das unbelegt. Der Hauptname „Loose Ends“ bleibt in jedem Fall nutzbar.

## Alternativen

- **A (gewählt):** geteilte Kataloge und `InfoPlist.strings`, Ersatznamen im Watch-Info.plist, keine
  Siri-Berechtigung. Klein, signiert wie heute.
- **B: A plus `com.apple.developer.siri` für `…watchkitapp`.** Macht Ersatznamen sicherer, aber der CI-Schlüssel kann
  die Fähigkeit eventuell nicht anlegen (#307: Widget und iCloud), und der ganze TestFlight-Bau scheitert. Erst nach
  Gerätebefund und Prüfung der App-ID. Kippt keine ADR, nur die Annahme „Watch ohne Siri-Berechtigung“.
- **C: eigene Katalogkopie im Watch-Ordner.** Unabhängig, aber eine Dublette, die driftet, und mehr LoC. Kippt die
  Regel aus #323 „eine Quelle je Text“ nicht, widerspricht aber ihrem Geist.
- **D: Watch-Kurzbefehl öffnet die App statt Siri-Rückfrage.** Umgeht Risiko 1, verfehlt aber „ohne App-Start“. Würde
  Hennings Entscheidung vom 2026-10-12 kippen; Rückfallweg, falls die Watch die Rückfrage nicht kann.
- **E: „Erfasse in …“ nur auf Deutsch (eigene Satzliste je Sprache), kein englischer Zwilling.** Kein künstlicher
  englischer Satz, aber die Unterstützung zusätzlicher Sätze je Sprache auf watchOS ist unbelegt (für iOS 17
  belegt). Kippt keine ADR; verworfen wegen fehlenden Belegs.

## Definition of Done

- [ ] AC-1 bis AC-8 erfüllt und belegt (Stufen 1 und 2); AC-9 bis AC-11 über Hennings Rückmeldung zu TestFlight
- [ ] `./scripts/sim.sh unit` grün, Build erfolgreich, jeder Commit kompiliert
- [ ] CI grün; TestFlight-Bau mit „Was testen“-Text auf Deutsch (Satz sprechen, Rückfrage, Speichern)
- [ ] Nach dem Zusammenführen: Hennings Hauptordner nachgezogen und Projekt neu erzeugt
- [ ] #355 bleibt offen bis Schnitt 3; Schnitte 2 und 3 als Folgearbeit im Ticket vermerkt

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — die Änderung nutzt vorhandene Mechanismen (String Catalogs, `INAlternativeAppNames`, Archivprüfung je Bundle) und führt keine neue Schicht ein.

- **Rationale:** Dieselben Ressourcen werden einem weiteren Target zugeordnet; die Regel „Regeln vor Modell“ ist
  erfüllt, weil nichts zu verstehen, nur zuzuordnen ist. Die Entscheidung gegen die Siri-Berechtigung für die Watch
  ist begründet (Recherche: für App Shortcuts nicht verlangt) und mit Rückfall (Variante B) benannt.

## Changelog

- 2026-10-13: Initial spec created (Variante A aus der Analyse).

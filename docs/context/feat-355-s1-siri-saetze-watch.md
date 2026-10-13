# Context: feat-355-s1-siri-saetze-watch

Ticket #355, Schnitt 1 von 3 (Henning, 2026-10-13: drei Schnitte, Schnitt 1 zuerst).
Schnitt 2 = `WatchCaptureView` deutsch + wieder bereit nach „Gespeichert“; Schnitt 3 = Komplikation + Einstellungshinweis.

## Request Summary
Auf der Apple Watch soll eine deutsche Siri „Erfasse in Loose Ends“ (und die übrigen deutschen Sätze) verstehen,
nach dem Text fragen und ohne App-Start speichern. Schnitt 1 liefert genau das: Siri-Sätze, Siri-Dialoge und
App-Namen-Varianten auf Deutsch im Watch-Bundle, plus den neuen Satz „Erfasse in Loose Ends“ für alle Plattformen.

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Intents/CaptureTextIntent.swift` | `CaptureTextIntent` (Dialog „What should I remember?“, „Saved: …“) und `LooseEndsShortcuts` (4 englische Sätze). Kompiliert in App **und** Watch (Watch-Target hat `Shared` ohne Ausschluss). Neuer Satz kommt hier dazu. |
| `LooseEnds/Resources/AppShortcuts.xcstrings` | Deutsche Siri-Sätze. Liegt nur im Target `LooseEnds` (iOS/Mac) – Watch sieht ihn nicht. |
| `LooseEnds/Resources/Localizable.xcstrings` | Deutsche Texte inkl. Intent-Titel „Aufgabe erfassen“, Kurztitel „Erfassen“, Dialoge. Nur iOS/Mac. |
| `LooseEnds/Resources/{de,en}.lproj/InfoPlist.strings` | Siri-Name der App (`CFBundleSpokenName`, `LE_ALT_NAME_1…3` „Loose End“, „LooseEnds“, „Lose Enden“, #347). Nur iOS/Mac. |
| `project.yml` | Target `LooseEndsWatch`: sources `LooseEndsWatch` + `Shared`; Info.plist ohne `INAlternativeAppNames`/`CFBundleSpokenName`; Berechtigungen ohne `com.apple.developer.siri`. iOS-Target hat beides (#347). |
| `LooseEndsWatch/` | `WatchCaptureView`, `LooseEndsWatchApp`, `Info.plist`, Entitlements, kein `.lproj`, kein String Catalog. |
| `.github/workflows/testflight.yml` (Z. ~155–250) | Archivprüfung: Siri-Sätze DE, Siri-Berechtigung, InfoPlist.strings – **nur für `com.henning.looseends`**. Watch wird nur auf SDK/Version/Datenschutztexte geprüft. Muss für die Watch erweitert werden (sonst merkt niemand, wenn das Watch-Bundle die deutschen Sätze verliert). |
| `scripts/test_entitlements_sync.py` | Prüft, dass Berechtigungen aus `project.yml` stammen (#311) – relevant, falls die Watch die Siri-Berechtigung bekommt. |
| `LooseEnds/Views/OnboardingView.swift` | Nennt den Siri-Satz „In Loose Ends erfassen“ (seit #367). Ggf. an „Erfasse in Loose Ends“ angleichen – eher Schnitt 3 (Einstellungshinweis). |

## Existing Patterns
- **Sprachdateien je Bundle (#323):** Widget und Share haben eigene `Localizable.xcstrings` im eigenen Ordner; die
  CI verlangt `de.lproj` in jedem Bundle mit String Catalog. Für die Watch gibt es das noch nicht.
- **Ressourcen mehrfach nutzen:** XcodeGen erlaubt dieselbe Datei in mehreren Targets (Pfad in `sources` des
  Watch-Targets aufnehmen) – keine Kopie nötig. Alternative: eigene Datei im Watch-Ordner (Dublette, driftet).
- **Siri-Name per Variablen (#347):** `INAlternativeAppNames` mit Platzhaltern im Info.plist, Werte je Sprache aus
  `InfoPlist.strings`; ohne `com.apple.developer.siri` ignoriert Siri die Ersatznamen (Build 43).
- **Satz mit App-Namen vorn (#367):** Siri fragte bei „Neue Aufgabe in …“ nach Notizen; Sätze wurden umgestellt.
- **CI als Gate für Bundle-Inhalt:** Jede Siri-/Sprach-Lücke wurde im Archivschritt nachgerüstet (#323, #326, #347).
- Kein Unit-Test über die Satzliste; das Ticket fordert einen („Siri-Satzliste enthält DE und EN“).

## Dependencies
- Upstream: AppIntents (`AppShortcutsProvider`), `CaptureService.save(_, via:in:)`, `ModelContainerFactory.make()`
  (App-Gruppe + CloudKit auf der Watch).
- Downstream: Siri und Kurzbefehle-App auf iPhone, Mac **und** Watch lesen `LooseEndsShortcuts` – ein neuer Satz
  wirkt überall. Archivprüfung in `testflight.yml` listet die deutschen Sätze wörtlich (muss mitwachsen).

## Existing Specs
- `docs/specs/intents/feat-225-siri-link-flag-tags.md` – Siri-Felder (Reminders-Schema), nicht der Kurzbefehl.
- Keine Spec zur Watch.

## Risks & Considerations
- **Quelle `.siri` vs. `.watch`:** `CaptureTextIntent` speichert immer `via: .siri`, auch auf der Watch. Das Ticket
  akzeptiert „Quelle Watch bzw. Siri“ – Analyse muss entscheiden, ob die Watch-Herkunft unterscheidbar sein soll.
- **Siri-Berechtigung für die Watch-Kennung:** `com.henning.looseends.watchkitapp` wurde vom Build angelegt, nicht von
  Hand; ob die Siri-Fähigkeit dort aktiv ist, ist unbekannt. #307: Der CI-Schlüssel konnte dem Widget keine
  iCloud-Fähigkeit hinzufügen → TestFlight-Bau scheiterte. Gleiche Gefahr hier. Ob App Shortcuts auf watchOS die
  Berechtigung überhaupt brauchen (oder nur die Ersatznamen), ist zu recherchieren.
- **Läuft der Intent auf der Watch im Watch-Prozess?** `WKRunsIndependentlyOfCompanionApp: true`; Store öffnet mit
  CloudKit. Ob Siri auf der Watch den Watch-Intent oder den des iPhones ausführt, ist zu recherchieren (Apple-Doku
  „App Shortcuts on watchOS“).
- **Gerätestufe greift** (`project.yml`, `LooseEndsWatch/`): Nachweis nur über TestFlight und Hennings Rückmeldung,
  nichts auf seinen Geräten ohne „jetzt ist ein Test möglich“. Der Simulator kann Siri-Sätze nicht sprechen;
  Stufe 2 belegt nur Bundle-Inhalt (de.lproj/AppShortcuts.strings im Watch-Bundle) und Build.
- **Grenzen:** max. 4–5 Dateien / ±250 LoC. Kandidaten: `project.yml`, `CaptureTextIntent.swift`,
  `AppShortcuts.xcstrings`, `testflight.yml`, ein Unit-Test. Onboarding-Text eher Schnitt 3.
- Parallele Arbeit: #368 (Startseite) und #331 laufen in anderen Sitzungen; keine Überschneidung mit Watch/Intents
  erwartet, aber `Localizable.xcstrings` ist ein gemeinsamer Konfliktherd.

## Analysis

### Type
Feature (Schnitt 1 von 3, #355)

### Ist-Zustand, am gebauten Paket belegt (2026-10-13)
Watch-Bau `DerivedData/LooseEnds-session-377-impl/.../Debug-watchsimulator/LooseEndsWatch.app` (13.10., 08:15):
- **kein einziger `*.lproj`-Ordner**, kein `Metadata.appintents/root.ssu.yaml`; `extract.actionsdata` registriert
  `CaptureTextIntent` mit nur den vier englischen Sätzen („Add to / ${applicationName} new task / Capture in / Task with“).
- iPhone-Bau daneben: `de.lproj/AppShortcuts.strings`, `de.lproj/nlu.appintents`, `de.lproj/InfoPlist.strings`, `root.ssu.yaml` mit de.
- Watch-`Info.plist`: kein `INAlternativeAppNames`, kein `CFBundleSpokenName`.
→ Eine deutsche Siri auf der Watch kennt heute keinen einzigen deutschen Satz und keinen Ersatznamen; auch Dialog
  („What should I remember?“) und Intent-Titel sind dort englisch.

### Recherche (Quellen)
- WWDC23 10102 „Spotlight your app with App Shortcuts“ (https://developer.apple.com/videos/play/wwdc2023/10102/):
  „App Shortcuts on Apple Watch must come from a watchOS app installed on the device itself“; „Flexible matching with
  Siri is not available on Apple Watch, so phrases must be spoken exactly“; jeder Satz braucht App-Namen oder Synonym;
  mit String Catalog darf eine Sprache mehr Sätze haben als Englisch (für iOS 17 belegt, für watchOS nicht).
- Apple-Forum 831639 (Apple-Ingenieur): Provider in der Watch-App macht die Kurzbefehle für Siri auf der Watch verfügbar;
  watchOS erkennt Sätze „pickier“, eher mehr und einfachere Sätze.
- Apple-Forum 843538: ein String Catalog darf in mehreren Targets liegen.
- SiriKit „Specifying synonyms for your app name“: watchOS-Apps erben die Ersatznamen der iOS-App nicht, sie müssen
  identisch im Watch-Info.plist stehen. Forum 832258: `INAlternativeAppNames` gilt auch für App Shortcuts.
- Siri-Berechtigung: Apple-Doku („Configuring Siri support“) bindet `com.apple.developer.siri` an Intents-Extensions;
  keine Quelle verlangt sie für App Shortcuts. Gegenbefund intern: #347 Build 43 (iPhone) ignorierte die Ersatznamen
  ohne Berechtigung.
- **Größtes Risiko:** Forum 720108 — String-`@Parameter` mit `requestValueDialog` auf watchOS 9.2/10 beta: Siri meldet
  einen Fehler, `perform()` wird nie aufgerufen; ungelöst. Nur die echte Watch zeigt, ob das unter watchOS 27 noch so ist.
- Simulator spricht keine Siri-Sätze; Stufe 2 belegt Paketinhalt und Bau, nicht die Erkennung.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `project.yml` | MODIFY | Watch-Target: `path: LooseEnds/Resources` mit `includes: [AppShortcuts.xcstrings, Localizable.xcstrings, "*.lproj/InfoPlist.strings"]` (Assets bleiben weg); Watch-Info.plist `CFBundleSpokenName` + `INAlternativeAppNames` mit denselben `LE_ALT_*`-Variablen. Keine Siri-Berechtigung. |
| `Shared/Intents/CaptureTextIntent.swift` | MODIFY | 5. Satz `"Capture with \(.applicationName)"` (wirkt auf iPhone, Mac, Watch). |
| `LooseEnds/Resources/AppShortcuts.xcstrings` | MODIFY | Eintrag `Capture with ${applicationName}` → de `Erfasse in ${applicationName}`, `state: translated`. |
| `.github/workflows/testflight.yml` | MODIFY | Sprach-/Siri-Prüfung als Funktion je Bundle; Watch-Bundle: `de.lproj` vorhanden, alle 5 deutschen Sätze, Siri-Namen in `InfoPlist.strings` (de/en); neuer Satz auch in der iPhone-Prüfung. Keine Siri-Berechtigungsprüfung für die Watch. |
| `scripts/test_siri_phrases.py` | CREATE | Jeder Satz in `CaptureTextIntent.swift` hat genau einen Schlüssel mit deutscher Übersetzung im Katalog (kein veralteter Schlüssel), und das Watch-Target in `project.yml` führt Katalog und `InfoPlist.strings`. |

### Scope Assessment
- Files: 5
- Estimated LoC: ca. +140 / −15
- Risk Level: MEDIUM — Bau und Paketinhalt sind sicher prüfbar; ob Siri auf der Watch den Text abfragt (Forum 720108)
  und die Ersatznamen ohne Siri-Berechtigung nimmt, zeigt nur die echte Watch.

### Technical Approach (Empfehlung: Variante A)
Kataloge und `InfoPlist.strings` der iOS-App zusätzlich ins Watch-Target (kein Duplikat), Ersatznamen ins Watch-Info.plist,
neuer Satz 1:1 mit englischem Schlüssel. `via: .siri` bleibt auf der Watch (Ticket akzeptiert Siri oder Watch).
Reihenfolge: Skripttest rot → Satz + Katalog → `project.yml` → `generate` + watchOS-Simulatorbau + Paketinspektion
(`de.lproj/AppShortcuts.strings`, `Localizable.strings`, `InfoPlist.strings`, `root.ssu.yaml` mit de) → `testflight.yml`
→ bestehende Skripttests (`test_entitlements_sync.py`, `test_ci_xcode27.py`).

| Variante | Änderung | Für | Gegen |
|---|---|---|---|
| **A (Empfehlung)** | geteilte Kataloge + lproj, Ersatznamen, keine Siri-Berechtigung | klein, signiert wie heute | Ersatznamen evtl. ignoriert (Hauptname „Loose Ends“ bleibt) |
| B | A + `com.apple.developer.siri` für `…watchkitapp` | Ersatznamen sicherer | CI-Schlüssel kann Fähigkeit evtl. nicht anlegen (#307) → ganzer TestFlight-Bau scheitert; erst nach Gerätebefund, nach Prüfung der App-ID |
| C | eigene Katalog-Kopie im Watch-Ordner | unabhängig | Dublette driftet, mehr LoC |
| D | Watch-Kurzbefehl öffnet die App statt Siri-Rückfrage | umgeht Risiko 720108 | verfehlt „ohne App-Start“; Rückfallweg, falls die Watch die Rückfrage nicht kann (kippt Hennings Entscheidung vom 2026-10-12) |
| E | „Erfasse in …“ nur deutsch (stringSet), kein englischer Zwilling | kein künstlicher EN-Satz | Watch-Unterstützung für Zusatzsätze unbelegt |

### Dependencies
AppIntents (`AppShortcutsProvider` je Bundle), `CaptureService.save`, `ModelContainerFactory.make()` auf der Watch;
Archivprüfung in `testflight.yml` listet Sätze wörtlich (wächst mit). Onboarding-Text („In Loose Ends erfassen“) → Schnitt 3.

### Known Risks (offen benennen, nicht lösbar in Stufe 2)
1. Siri-Rückfrage nach dem Text auf der Watch (Forum 720108) — Gerätetest entscheidet; Rückfall Variante D als neues Ticket.
2. „Erfasse in Loose Ends“ hat die Form, die bei #367 („Merk dir in …“) eine Rückfrage „Notizen oder Loose Ends?“ auslöste.
   Henning will den Satz ausdrücklich; die vier übrigen Sätze bleiben.
3. Auf der Watch müssen Sätze wörtlich gesprochen werden.
4. Deutscher Siri-Dialog lautet „Was soll ich aufnehmen?“ (bestehende Übersetzung, iPhone), das Ticket nennt „Was soll ich
   mir merken?“ — bleibt unverändert, keine Abweichung zum iPhone.

### Open Questions
- keine PO-Frage offen; Gerätenachweis über TestFlight (Stufe 3 greift: `project.yml`).

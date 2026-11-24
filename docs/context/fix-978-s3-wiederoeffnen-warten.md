# Context: fix-978-s3-wiederoeffnen-warten (#978 Schnitt 3)

## Request Summary
Die Wiederöffnungstests des Menüleisten-Panels klicken das Symbol erst, wenn der App-Wechsel nach dem Schließen
abgeklungen ist, und prüfen das Panel nach einer Ruhezeit. Danach fällt `XCTExpectFailure` weg, der Test ist hart.

## Befund aus S2 (Issue-Kommentare 2026-11-24)
- 1 Fall in 420 Wiederöffnungen (Wiederholungsläufe), früher ~13 % im Pflicht-Job; nur Arm open-app (⌘W-Weg).
- Fall 45334299531: Klick +0 s, Loose Ends aktiv +0,02 s, **Finder aktiv +0,409 s** (Nachlauf der Deaktivierung nach ⌘W:
  letztes Fenster zu, Dock-Richtlinie → accessory), `panel key` +0,445 s, **leftMouseUp außerhalb der App +1,156 s**,
  `panel resign` +1,176 s durch `_endExpandedInterfaceSession` des Statusobjekt-Hosts → SwiftUI blendet aus.
- Deutung: XCUITest-Klicksynthese stellt das Loslassen verspätet zu, während die Aktivierung wechselt; der Host wertet es
  als zweiten Klick (Zuklappen). Ursache: Prüfwerkzeug plus Zeitpunkt, kein App-Eingriff (Alternative C verworfen).

## Related Files
| File | Relevance |
|------|-----------|
| LooseEndsUITests/MacGalleryTests.swift:446-551 | die drei Wiederöffnungstests und `assertSymbolOpensPanelWithOneClick` (einzige Änderungsstelle) |
| LooseEndsUITests/MacUITestSupport.swift | `macLaunch`, `macMainWindow` (nur gelesen) |
| LooseEnds/Mac/MenuBarCapture.swift | Panel, `DockPolicy`, Panel-Protokoll (unverändert) |
| .github/workflows/ci.yml (Job Mac Gallery), mac-panel-repeat.yml | Nachweis: drei grüne Pflichtläufe, Wiederholungslauf ≥ 40 je Arm |

## Existing Patterns
- Warten per `expectation(for: NSPredicate…)` + `XCTWaiter.wait`; Anhänge `XCTAttachment` mit `keepAlways`.
- Der Testläufer ist ein macOS-Prozess: `NSWorkspace.shared.frontmostApplication` ist dort lesbar (AppKit).

## Recherche
- `XCUIApplication.State.runningForeground` sagt nicht eindeutig „vorderste App“; `NSRunningApplication.isActive` /
  `NSWorkspace.frontmostApplication` schon (https://developer.apple.com/documentation/appkit/nsrunningapplication).
- macOS 27: Statusobjekt klappt über eine „expanded interface session“, ein Klick bei offenem Fenster beendet sie
  (https://developer.apple.com/forums/thread/836113) — passt zum Stapel `_endExpandedInterfaceSession`.
- Xcode-14-Bericht: Loslassen beim Klick-Automatisieren schließt Menüs (https://developer.apple.com/forums/thread/714649).

## Dependencies / Dependents
- Upstream: XCUIAutomation, AppKit im Testläufer. Downstream: Pflicht-Check „Mac Gallery (macOS)“, `mac-panel-repeat.yml`.

## Risks & Considerations
- Return-Arm: nach Return bleibt die App evtl. aktiv → Bedingung nicht „App nicht aktiv“, sondern „vorderste App seit
  1 s unverändert“, Obergrenze 10 s, danach trotzdem klicken und den Verlauf anhängen.
- Ruhezeit nach dem Öffnen (Panel nach 3 s noch da) fängt „geht auf, geht zu“ hart; ohne sie wäre der Test weicher
  als der Fehlerfall.
- Grenze: Die Wartezeit verdeckt einen App-Fehler nur für Klicks genau während des Fensterwechsels; Nutzerbetroffenheit
  ist im Issue als nicht belegt vermerkt.

## Analysis v1 (widerlegt durch Galerie-Versuch 3, 2026-11-24)

### Type
Bug (Testwerkzeug): der Pflicht-Check „Mac Gallery (macOS)“ trägt seit #978 S1 ein `XCTExpectFailure` am ⌘W-Arm.
Ursache aus S2 belegt (Fall 45334299531): der Klick aufs Symbol fällt in den Nachlauf des App-Wechsels nach ⌘W, das
verspätete Loslassen der XCUITest-Klicksynthese beendet die „expanded interface session“ und klappt das Panel wieder zu.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| LooseEndsUITests/MacGalleryTests.swift | MODIFY | `import AppKit`; neue Hilfe `waitForFrontmostSettled` (vorderste App per `NSWorkspace.shared.frontmostApplication`, alle 0,1 s gelesen, „seit 1 s unverändert“, Obergrenze 10 s, Verlauf als Zeilen zurück); `assertSymbolOpensPanelWithOneClick` wartet davor, prüft nach dem Öffnen eine Ruhezeit von 3 s (Panel noch da) und schreibt Verlauf + Haltezustand in den Klick-Anhang; ⌘W-Arm ohne `XCTExpectFailure`/`continueAfterFailure` |

Unverändert: `MenuBarCapture.swift` (kein App-Eingriff), `mac-panel-repeat.yml`, `scripts/mac_panel_repeat_summary.py`.
Bedingung dafür: die letzte Zeile des Anhangs bleibt `… panel open|not open`, und „open“ heißt künftig „offen und nach
3 s noch offen“ — so zählt das Skript ein „geht auf, geht zu“ als Fehlschlag, ohne geändert zu werden. Der Verlauf der
vordersten App steht in eigenen Zeilen vor dieser Zeile.

### Scope Assessment
- Files: 1 (nur Testcode, App-Code 0 LoC)
- Estimated LoC: +45/-12
- Risk Level: LOW — nur der Test ändert sich; Risiko ist ein weicherer Test, abgefangen durch die 3-s-Haltezeit.

### Technical Approach
Alle drei Arme (Return, ⌘W, Kontrollarm) laufen durch dieselbe Hilfe, damit die Raten im Wiederholungslauf
vergleichbar bleiben. Reihenfolge im Helfer: Symbol existiert → vorderste App ruhig (≥ 1 s gleich, max. 10 s; nach
Ablauf trotzdem klicken, Ablauf im Anhang vermerkt) → ein Klick → Panel binnen 10 s → 3 s später noch vorhanden →
Anhang → harte Assertions. Der ⌘W-Arm wird wieder hart. Nachweis: drei grüne Pflichtläufe „Mac Gallery“ und ein
Wiederholungslauf mit ≥ 40 Iterationen je Arm ohne Fehlschlag.

### Alternativen
- **Feste Pause (z. B. 2 s) vor dem Klick:** einfacher, aber zeitgeraten; bei langsamem Runner zu kurz, sonst Leerlauf. Verworfen zugunsten der beobachteten Bedingung.
- **Zweiter Klick / Wiederholung bei Fehlschlag:** verdeckt einen echten „geht nicht auf“-Fehler. Verworfen.
- **App-Eingriff (Panel ignoriert Loslassen während Aktivierungswechsel):** in S2 als Alternative C verworfen — Nutzerbetroffenheit nicht belegt, Eingriff in Systemverhalten des Statusobjekts. Keine ADR betroffen.
- **Test als `XCTExpectFailure` belassen:** hält CI grün, prüft aber nichts; widerspricht dem Ziel von #978.

### Dependencies
XCUIAutomation, AppKit im Testläufer (macOS-Prozess, `NSWorkspace` lesbar). Abnehmer: Pflicht-Check „Mac Gallery (macOS)“, `mac-panel-repeat.yml` + Zusammenfassungsskript (Format der letzten Anhangzeile).

### Open Questions
- keine (reine Testwerkzeug-Arbeit, kein Produktthema; kein Pfad der Geräteliste berührt)

## Phase 5 (2026-11-24)

RED-Tests in `scripts/test_mac_reopen_settle.py` (Gegenprobe am Quelltext für AC-1 bis AC-4, neues Anhangformat durch das unveränderte Skript): 5 von 10 rot, Beleg `docs/artifacts/fix-978-s3-wiederoeffnen-warten/test-red-output.txt`. Die Datei ist Testcode und steht nicht in der Spec-Dateiliste (Spec unverändert freigegeben); AC-7 meint den Produkt- und UI-Testcode.

## Analysis

Neuansatz nach Galerie-Versuch 3 (Befund `docs/artifacts/fix-978-s3-wiederoeffnen-warten/befund-galerie-versuch3.md`).

### Type
Bug (Testwerkzeug). Die Aktivierung der Ziel-App passiert **in** `statusItem.click()` („Open/Activate
com.henning.looseends“), nicht davor; danach holt sich Finder die Aktivierung zurück, die Klicksynthese zieht sich
(5,6 s), das Maus-hoch kommt 0,897 s nach `panel key` (sonst 0,10–0,23 s, 231/231 offen) und der Statusobjekt-Host
beendet die Sitzung. Warten vor dem Klick (v1) kann das nicht verhindern. Nur der ⌘W-Arm ist betroffen, weil nur dort
die App beim Klick nicht vorn ist (`.accessory`, Finder vorn).

### Recherche
- Kein offizieller Weg, dem `xctrunner` auf gehosteten Runnern das Recht `kTCCServicePostEvent` zu geben; System-TCC.db
  per sqlite ist codesign- und image-abhängig (https://developer.apple.com/forums/thread/834560,
  https://circleci.com/docs/guides/test/testing-macos/index.md, https://github.com/DevExpress/testcafe/issues/6789,
  actions/runner-images#7269). Der Kontrollarm fällt deshalb auf `XCUICoordinate` zurück (`CGPreflightPostEventAccess` false).
- XCUITest klickt Statusobjekte über `menuBars.statusItems`, Agent-Apps verhalten sich dabei anders
  (https://developer.apple.com/forums/thread/773715). Keine Quelle zum Aktivieren einer fremden Wurzel-App.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| LooseEndsUITests/MacGalleryTests.swift | MODIFY | neuer Klick `frontmostRootClick`: Wurzel ist `XCUIApplication(bundleIdentifier:)` der vordersten App (nach `waitForFrontmostSettled`), Klick per `coordinate(withNormalizedOffset: .zero).withOffset(statusItem.frame.mid − Wurzelrahmen.origin)`; ⌘W-Arm (und Return-Arm, gleiche Hilfe) nutzt ihn; Anhang nennt `how: user: frontmost root <bundle id>` und die Dauer von `click()`; ⌘W-Arm hart |
| scripts/test_menubar_panel_log.py | MODIFY | bereits im Arbeitsbaum: `TestOpenAppArmIsHard` statt `XCTExpectFailure`-Erwartung (Versuch-3-Befund) |
| scripts/test_mac_reopen_settle.py | MODIFY | Gegenprobe am Quelltext für den neuen Klickweg |

Unverändert: `MenuBarCapture.swift` (kein App-Eingriff), `mac-panel-repeat.yml`, `scripts/mac_panel_repeat_summary.py`
(letzte Anhangzeile bleibt `… panel open|not open`).

### Scope Assessment
- Files: 1 App-Testdatei + 2 Skripttests; App-Code 0 LoC
- Estimated LoC: +35/-10 im UI-Test
- Risk Level: MEDIUM — ob XCTest beim Klick über eine fremde Wurzel ebenfalls aktiviert, ist unbelegt; deshalb wird der
  Mechanismus belegt, nicht nur die Rate.

### Technical Approach (Empfehlung A)
Klick über die vorderste App als Koordinatenwurzel: Die vorderste App ist schon aktiv, XCTest muss nichts aktivieren,
der Nutzerzustand „Finder vorn, Loose Ends accessory“ bleibt beim Klick erhalten (#862 bleibt sichtbar: zeigt der erste
Klick nichts, ist der Test rot). Haltezeit 3 s bleibt. Fällt die Wurzel weg (keine vorderste App lesbar), klickt der
Test wie bisher und vermerkt es im Anhang.

**Nachweis über den Mechanismus statt nur über die Rate** (Basisrate im Wiederholungslauf ~0,5 %, 0 Fälle in N belegt nur
< 3/N): im Testprotokoll des Klicks kein „Activate com.henning.looseends“, Dauer von `click()` im Normalbereich
(< 1 s), Abstand `panel key` → Maus hoch < 0,3 s im Panel-Protokoll; dazu Wiederholungslauf ≥ 100 je Arm ohne Fall
und drei grüne Pflichtläufe „Mac Gallery“. Taucht die Aktivierung trotz fremder Wurzel auf, ist A widerlegt → Rückfall D.

### Alternativen
| | Ursache weg | #862 sichtbar | Umfang | Urteil |
|---|---|---|---|---|
| A Wurzel = vorderste App | ja, falls keine Aktivierung | ja, nutzertreu | ~35 LoC, 1 Datei | **empfohlen** |
| B `app.activate()` vor dem Klick | teils (Finder holt zurück) | schwächer (anderer Ausgangszustand) | ~10 LoC | verworfen |
| C CGEvent + TCC-Eintrag im Job | ja | am besten | Workflow + Skript + Test, image-abhängig | fragil, verworfen |
| D Erkennen „auf und vom Host zu im Klick“ + eine Wiederholung | nein, nur Meldung | mittel | ~50 LoC + Protokoll-Schnittstelle der App | Rückfall |
| E App-Eingriff | ja | ja | App-Code | verworfen (S2, Nutzer nicht betroffen: 231/231) |
Keine ADR betroffen.

### Dependencies
XCUIAutomation, AppKit im Testläufer; Abnehmer Pflicht-Check „Mac Gallery (macOS)“, `mac-panel-repeat.yml`.
Zeitlimit der Galerie (40 min) ist #974 und kann die drei Pflichtläufe abbrechen; dann zählt der Lauf nicht, wird
neu gestartet, das Ticket wartet nicht darauf.

### Open Questions
- keine (Testwerkzeug, kein Produktthema; kein Pfad der Geräteliste berührt)

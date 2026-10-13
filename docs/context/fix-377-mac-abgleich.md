# Context: fix-377-mac-abgleich

## Request Summary
#377: Die Mac-App zeigt andere Aufgaben als iPhone und iPad (die untereinander stimmen). Henning
(2026-10-12): „ein Teil der Aufgaben ist gleich“ — der Abgleich hat also **früher zumindest teilweise
funktioniert**. Die Mac-App läuft nicht aus TestFlight (gibt es für den Mac nicht), sondern als Bau
außerhalb von Xcode (`~/Applications`, #287) bzw. aus Xcode.

## Stand der Erkenntnis (vor der Analyse)
- **Verworfen:** Development-vs-Production als Ursache (Henning: „Daran liegt es nicht“; #175 hat
  gemessen, dass seine Daten in der TestFlight-Fassung ankamen). Siehe Kommentar 1 in #377, zurückgenommen.
- **Nicht gemessen:** ob die Mac-App überhaupt mit CloudKit spricht. Es gibt keine Anzeige und keine
  Auswertung der Spiegelungs-Ereignisse (`grep eventChangedNotification|import CloudKit` in `Shared/`
  und `LooseEnds/`: kein Treffer).
- **Beantwortet (Henning, 2026-10-12, Intake):** „Hat es bisher funktioniert?“ → teilweise ja.
  Ein Teil der Aufgaben ist auf dem Mac gleich. Der Zeitpunkt des Bruchs ist unbekannt.

## Related Files
| Datei | Relevanz |
|-------|----------|
| `Shared/Persistence/ModelContainerFactory.swift` | Öffnet den Speicher. **Zwei stille Rückfälle auf einen lokalen Speicher ohne Abgleich:** Z. 98–102 (App-Gruppe nicht verfügbar) und Z. 111–115 (Container-Anlage mit CloudKit wirft). Beide nur als `logger.error`, nichts in der Oberfläche. `groupContainer: .none` legt einen *anderen* Speicherort an als der App-Gruppen-Speicher. |
| `project.yml` (Ziel `LooseEnds`, `supportedDestinations: [iOS, macOS]`) | Entitlements gelten für iOS und macOS gleich; kein explizit gebundenes `CloudKit.framework`; `aps-environment: development` auch für den Mac; Mac-Profil/-Fähigkeiten nirgends gesondert. |
| `LooseEnds/App/LooseEndsApp.swift` | Z. 24–30: `ModelContainerFactory.make()`; Fehler wird dort gefangen (zu prüfen: was passiert dann). `MacAppDelegate` nur für Mac. |
| `Shared/Persistence/CloudKitSchemaInitializer.swift` | Debug-Only, schreibt Schema nach Development, öffnet nie den App-Gruppen-Speicher. Kein Produktpfad. |
| `scripts/sim.sh` (`mac`, `mac-schema-init`) | Wie die Mac-App entsteht (Prüfkennung `.probe`, `~/Applications`). Hennings „normale“ Mac-App wird *nicht* von hier gebaut. |
| `docs/reference/testflight.md` Z. 221 | „Die Mac-App kommt in einem späteren Schritt dazu“ — es gibt keinen Mac-Verteilweg außer Xcode. |
| `docs/artifacts/feature-175-cloudkit-produktion/messprotokoll.md` | Messung: iPhone + iPad (TestFlight) gleichen ab. Der Mac war nie Gegenstand der Abgleichmessung. |

## Existing Patterns
- Rückfälle in `ModelContainerFactory` sind bewusst stumm (App startet statt abzustürzen, #55) — damit
  kann die App einen **leeren oder veralteten lokalen Speicher zeigen, ohne dass der Nutzer es erfährt**.
  Das passt zum Befund „teilweise gleich“ (alter Stand bis zu einem Zeitpunkt, danach nichts mehr).
- Entitlement-Drift ist bei diesem Projekt schon zweimal die Ursache gewesen: #311 (iCloud-Schlüssel
  fehlte in `project.yml`, TestFlight-Bauten seit 29), App-Group-Absturz (Gerätelistenklasse).
  Schutz heute: `scripts/test_entitlements_sync.py`, Archivprüfung `entitled` — nur für das **iOS-Archiv**.
- Messen vor Fixen (CLAUDE.md „Regeln vor Modell“, Analysis-First): erst sichtbar machen, was die App tut.

## Dependencies
- Upstream: SwiftData `ModelConfiguration(... cloudKitDatabase: .private(...))`, Entitlements/Provisioning
  des Mac-Baus, iCloud-Anmeldung auf dem Mac.
- Downstream: alle Views (`.modelContainer(container)`), `EnrichmentCoordinator`, `DueNotificationCenter`,
  `CalendarBridge`, `MenuBarCapture` (#356) — alle teilen *denselben* Container; ein stiller Rückfall betrifft
  also auch die Menüleisten-Erfassung: dort erfasste Aufgaben landen dann in einem Speicher, den kein anderes
  Gerät sieht.

## Offene Hypothesen (Analyse muss entscheiden, keine ist bewiesen)
1. **Stiller Rückfall auf lokalen Speicher** (App-Gruppe/Entitlement/Profil des Mac-Baus). Erklärt „teilweise
   gleich“, wenn der lokale Speicher aus einer Zeit stammt, in der der Abgleich lief.
2. **Spiegelung startet nie / bricht ab** (CloudKit.framework nicht gebunden, Sandbox verweigert `cloudd`
   außerhalb von Xcode; Quellen im Ticketkommentar 2).
3. **Spiegelung läuft, aber Mac bekommt keine Pushes** (nicht TestFlight/Store) → nur Verzögerung bis zum
   nächsten Start; erklärt *fehlende neuere* Aufgaben, aber nicht dauerhaft verschiedene.
4. **Schema-Lücke**: neue Felder seit dem letzten guten Stand, die der Mac-Speicher nicht kennt.
   (Gegenhypothese zu 1–3: Mac zeigt dann Aufgaben, aber fehlerhaft, nicht „andere“.)

## Risks & Considerations
- **Reproduktion braucht Hennings Mac** (normale Mac-App, außerhalb von Xcode). Das ist sein Gerät:
  nichts davon, auch nichts Lesendes, ohne sein wörtliches „jetzt ist ein Test möglich“.
  Vorher möglich: Simulator/eigene Rechner-Ressourcen — z. B. ein signierter, aber nicht aus Xcode
  gestarteter Mac-Bau auf dem Entwicklungsrechner ist *der Mac des Users*, also ebenfalls gesperrt.
  Prüfen in der Analyse: ob ein Nachstellen ohne sein Gerät überhaupt möglich ist.
- Stufe 3 greift (`Shared/Persistence`, `project.yml`); Abnahme über TestFlight setzt einen Mac-Verteilweg
  voraus, den es nicht gibt (Schnitt 2 im Ticket).
- Production-Schema ist ab dem ersten Deploy nur additiv; jede Modelländerung braucht `mac-schema-init`
  + Deploy. Dieses Ticket plant *keine* Modelländerung.
- Scoping: Ticketvorschlag hat zwei Schnitte (Sichtbar machen; Mac über TestFlight). Mac-TestFlight-Archiv
  allein sprengt vermutlich 4–5 Dateien → eigene Teil-Spec (siehe Memory „Mehrere Schnitte = Teil-Specs“).

## Existing Specs
- Keine Entity-Spec zum Mac-Abgleich. Entscheidungen: `docs/project/00-entscheidungen.md` (ADR-2 App-Gruppe +
  private CloudKit-Datenbank).

## Alternativen zum bisherigen Weg (Pflicht laut Henning, 2026-09-19)
- Statt Anzeige in den Einstellungen: **stiller Rückfall verbieten** — wirft die Container-Anlage mit CloudKit,
  zeigt die App einen Hinweis statt eines lokalen Speichers (kippt die Entscheidung aus #55, „App startet
  immer“).
- Statt Mac-TestFlight: Mac-App nur als „Prüfbau“ behalten und den Mac aus dem Alltag nehmen (Variante C
  im Ticket) — kippt das Ziel „Mac ist eine gleichwertige Plattform“ (Ground rules: eine Multiplattform-App).

## Analysis

### Type
Bug (Verschlechterung/Teilausfall: „teilweise gleich“, Zeitpunkt des Bruchs unbekannt).

### Recherche (zuerst, 2026-10-13)
- Macs binden CloudKit.framework nicht automatisch; ohne explizite Bindung kompiliert alles, die Spiegelung
  startet aber nicht ([Forum 784215](https://developer.apple.com/forums/thread/784215),
  [fatbobman](https://fatbobman.com/en/snippet/fix-synchronization-issues-for-macos-apps-using-core-dataswiftdata/)).
- Mac empfängt Pushes/Änderungen nur eingeschränkt außerhalb von Xcode/TestFlight
  ([Forum 759074](https://developer.apple.com/forums/thread/759074)).
- Sync-Zustand ist über `NSPersistentCloudKitContainer.eventChangedNotification` abfragbar
  ([TN3164](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer.md),
  [Forum 652607](https://developer.apple.com/forums/thread/652607)).

### Befunde im Code (ohne Gerät)
- `CloudKit.framework`: **0 Treffer** in der erzeugten Projektdatei, kein `import CloudKit` im Code → passt zu Hypothese 2.
- `network.client`, App-Sandbox, iCloud-Container und CloudKit-Dienst stehen in den Entitlements (ok).
- `ModelContainerFactory` hat zwei stille Rückfälle auf einen lokalen Speicher (nur `logger.error`). Passt zu Hypothese 1.
- **Nicht gemessen:** ob die Mac-App überhaupt spiegelt. Beide Hypothesen sind plausibel, keine bewiesen.
  Reproduktion verlangt Hennings Mac → gesperrt bis zu seinem „jetzt ist ein Test möglich“.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Persistence/SyncStatus.swift` | CREATE | Hört auf `eventChangedNotification`, hält letztes Ereignis/Zeit/Fehler; Auswertung als reine Regel (testbar) |
| `Shared/Persistence/ModelContainerFactory.swift` | MODIFY | Rückfall auf lokalen Speicher wird als Zustand festgehalten statt nur geloggt |
| `LooseEnds/Views/SettingsView.swift` | MODIFY | Zeile „iCloud-Abgleich“ |
| `project.yml` | MODIFY | `CloudKit.framework` explizit für das App-Target (macOS) |
| `LooseEndsTests/SyncStatusTests.swift` | CREATE | Unit-Tests der Auswertung |

### Scope Assessment
- Schnitt 1: 5 Dateien, ca. +180/−5 LoC, Risiko MEDIUM (Stufe 3: `Shared/Persistence`, `project.yml`).
- Schnitt 2 (Mac-TestFlight-Archiv in `testflight.yml`): eigene Teil-Spec, nicht Teil dieses Schnitts.

### Technical Approach
Regelweg, kein Modell. Schnitt 1 macht den Zustand sichtbar (Alternative: Rückfall verbieten, kippt #55) und
bindet das Framework. Die Anzeige liefert danach den Beleg, welche Hypothese stimmt; erst dann Schnitt 2.
Alternative zum bisherigen Weg: Mac nur als Prüfbau behalten (kippt „Mac ist gleichwertige Plattform“).

### Dependencies
Alle Views teilen denselben Container; Menüleisten-Erfassung (#356) betroffen, falls Rückfall greift.

### Open Questions
- [ ] Mess-Termin auf Hennings Mac (nur nach „jetzt ist ein Test möglich“).
- [ ] Entwurf der Zeile „iCloud-Abgleich“ (Artefakt, Heute/Entwurf, Dunkel+Hell, mit Alternative) vor `/30-write-spec`.

### Entwurf
Artefakt: https://claude.ai/artifact/YFd6gtgAFi7FAgE2MXV8Ek (Datei `docs/artifacts/fix-377-mac-abgleich/entwurf.html`). Empfehlung A (Abschnitt „iCloud“), Alternative B (Hinweis auf der Startseite). Freigabe: Henning wählte A (2026-10-13).

---
entity_id: feat-795-schnitt-5c2a-weckruf-delegates
type: feature
created: 2026-11-19
updated: 2026-11-19
status: draft
workflow: feat-795-s5c2a-weckruf-delegates
---

# Spec: App hört auf den stillen Weckruf, Schnitt S5c-2a (#795, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#795 (Epic #612). Schnitt S5c-2a; das Issue bleibt offen (`Refs #795`, nie `Closes #795`).
Analyse: `docs/context/feat-795-s5c2a-weckruf-delegates.md` (verbindlich). Plan: `docs/context/feat-795-s5c-weckruf-app.md` (Abschnitt „S5c-2a“).
Vorgänger: `docs/specs/feat-795-schnitt-5c1-weckruf-kern.md` (Registrierer, `wake()`), `docs/specs/feat-795-schnitt-5c2b-aps-umgebung.md` (Umgebungsmarke).
Dienst-Seite: `docs/specs/feat-795-schnitt-5b-weckruf-betrieb.md`.

## Für den PO

Wenn Claude einen Auftrag an Loose Ends schickt, weckt der Dienst dein Gerät künftig mit einem stillen Anstoß, und die App holt den Auftrag sofort, auch wenn sie im Hintergrund liegt. Bisher holt sie ihn erst beim Öffnen. Dafür meldet die App dem Dienst ihre Adresse bei Apple, aber nur, wenn ein Konto verbunden ist.

Sichtbar ändert sich nichts: kein Banner, kein Ton. Im Store-Bau ist der Konto-Schalter aus, dort meldet sich nichts. Du musst nichts entscheiden. Ausprobieren kann es später der TestFlight-Bau mit Konto.

## Purpose

Seit S5b sendet der Dienst nach jedem neuen Auftrag einen stillen Weckruf (`{ aps: { "content-available": 1 }, looseends: { v: 1 } }`), und seit S5c-1 gibt es `DeviceRegistration` und `ClaudeSyncTrigger.wake()`. Nichts in der App empfängt den Token oder den Weckruf: iOS hat keinen App-Delegate, `registerForRemoteNotifications` ruft nur der CloudKit-Container selbst. Dieser Schnitt verdrahtet beides:

1. `LooseEnds/Claude/PushWakeUp.swift` (neu, `@MainActor`): ein Knoten, einmal aus `LooseEndsApp.init` gesetzt, nil ohne Konto und unter Tests. Er enthält die testbaren Regeln: `isWake(userInfo)` (Schlüssel `looseends`, nur synchron geprüft), `handle(isWake:)` mit 20-s-Frist gegen `wake()`, `didReceive(token:)` und die Anmeldebeobachtung.
2. `LooseEnds/Notifications/IOSAppDelegate.swift` (neu, nur iOS): Durchreiche für Token, Fehler und die async-Variante von `didReceiveRemoteNotification`.
3. `MacAppDelegate` (in `MenuBarCapture.swift`): dieselben Token-Rückrufe und `didReceiveRemoteNotification` (AppKit, ohne Completion-Handler).
4. `LooseEndsApp.swift`: `@UIApplicationDelegateAdaptor` (iOS) und Installation des Knotens nach `claudeSync`.

Festlegungen (technisch, Claude): Frist 20 s. Ergebnis geweckt → `.newData`, Frist → `.noData`, fremde Mitteilung (ohne Schlüssel `looseends`) → `.noData` sofort; nie `.failed`, weil das künftige Weckrufe drosselt. Der Abschluss geschieht genau einmal: ein Mutex-Einmalkasten entscheidet zwischen `wake()` und Frist, ein später fertiges `wake()` schließt nicht doppelt ab (Muster `RefreshHandle`, #780/#782). `userInfo` wird nur synchron geprüft und nie in eine Task getragen (Swift 6: nicht `Sendable`). Registrierung nur bei `account.status == signedIn`, über `Observations { account.status }` (das erste Element deckt den Start ab, auch eine spätere Anmeldung löst aus). Unter `--ui-testing` und Unit-Tests ist alles still. `project.yml` bleibt unverändert (`aps-environment`, `LEApsEnvironment`, `UIBackgroundModes` stehen seit S5b/S5c-2b).

Regeln vor Modell: reine Verdrahtung ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue ADR; Bezug ADR-21-Addendum Weckruf (Entscheidung A, PO 2026-11-13), das hier seinen Empfänger bekommt.
- **Rationale:** Kein neues Schema, keine neue Abhängigkeit, keine neue Berechtigung; die Verdrahtung folgt bestehenden Mustern (Einmal-Abschluss aus `BackgroundRefresh`, Prozessdienste in `LooseEndsApp.init`).

## Source

- **File:** `LooseEnds/Claude/PushWakeUp.swift`, `LooseEnds/Notifications/IOSAppDelegate.swift`, `LooseEnds/Mac/MenuBarCapture.swift`, `LooseEnds/App/LooseEndsApp.swift`, `LooseEndsTests/PushWakeUpTests.swift`
- **Identifier:** `PushWakeUp` (Knoten, `isWake`, `handle`, `didReceive(token:)`), `IOSAppDelegate`, `MacAppDelegate`

**Unberührt:** `project.yml`, `*.entitlements`, `Info.plist`, `server/`, `DeviceRegistration`, `ClaudeSyncTrigger`, `DueNotificationCenter` (einziger `UNUserNotificationCenterDelegate`, getrennter Kanal), Watch und Widgets.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `DeviceRegistration.register(token:)`, `PushEnvironment.current` (S5c-1, S5c-2b) | module | meldet das Token, nur mit Sitzung |
| `ClaudeSyncTrigger.wake()` (S5c-1) | module | sendet, dann holt; kehrt nach einem Holen zurück, das nach dem Aufruf begann |
| `AccountState.status` | module | Anlass zur Registrierung, auch bei späterer Anmeldung |
| `BackgroundRefresh.RefreshHandle` (Muster) | pattern | Mutex-Einmalabschluss |
| `UIApplicationDelegateAdaptor` / `NSApplicationDelegate` | framework | Token- und Mitteilungsrückrufe |
| Dienst `POST /app/device`, `server/src/apns.ts` | module | live seit S5b; Mac-Empfang erst mit S5c-2b2 (PR #957, andere Sitzung, keine gemeinsame Datei) |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/PushWakeUp.swift` | CREATE | Knoten, `isWake`, `handle` mit Frist und Einmalkasten, `didReceive(token:)`, Anmeldebeobachtung; ≈ +90 |
| `LooseEnds/Notifications/IOSAppDelegate.swift` | CREATE | `#if os(iOS)`, `@MainActor`, Token, Fehler (nur Log), async `didReceiveRemoteNotification`; ≈ +35 |
| `LooseEnds/Mac/MenuBarCapture.swift` | MODIFY | `MacAppDelegate`: Token-Rückrufe, `didReceiveRemoteNotification`; ≈ +20 |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | `@UIApplicationDelegateAdaptor`, Knoten installieren; ≈ +8 |
| `LooseEndsTests/PushWakeUpTests.swift` | CREATE | Regeln und Fristen, Einmal-Abschluss, Token, Anmeldung; ≈ +150 |
| `CLAUDE.md` | MODIFY | eine Zeile im Absatz `LooseEnds/Claude` (zählt nicht zum Dateilimit) |

### Estimated Changes

- **Dateien: 5** plus eine `CLAUDE.md`-Zeile; Limit 4–5 eingehalten.
- **LoC: ≈ +150 Code / +150 Tests, gesamt ≈ 300.** Das liegt über dem Limit von ±250. Der Überhang liegt bei den Tests (Frist, Einmal-Abschluss und Anmeldung brauchen je einen eigenen Fall); der Code allein bleibt unter 250. Nach RED ist die Meldeschwelle zu beachten, gegebenenfalls per `AskUserQuestion`. Keine Funktion über 50 Zeilen.
- Keine neuen Berechtigungen, keine AppStorage-Keys, kein CloudKit-Schema, keine Audio-Dateien, keine Oberfläche.
- Parallele Arbeit: `CLAUDE.md` ist ein Hotspot (S5c-2b2); vor dem PR gegen `origin/main` und offene PRs abgleichen.

## Implementation Details

- Der Delegate ist nur Durchreiche. `account` und `claudeSync` entstehen in `LooseEndsApp.init`; sie erreichen den Delegate über den statischen Haken des Knotens, den `init` füllt (nil ohne Konto und unter `--ui-testing`/Unit-Tests).
- `isWake(userInfo)` wertet im Rückruf synchron aus und gibt nur ein `Bool` weiter. `handle(isWake:)`: nicht Weckruf → `.notOurs` sofort; sonst läuft `wake()` gegen einen 20-s-Zeitgeber. `wake()` ist nicht abbrechbar (`ModelDeadline` daher unbrauchbar); beide Seiten melden an den `Mutex`-Einmalkasten, nur die erste setzt das Ergebnis, der Zeitgeber wird bei Sieg des Holens abgebrochen.
- iOS: `.newData`, wenn das Holen etwas ergab oder lief, `.noData` bei Frist und bei Fremdem; ohne Knoten `.noData`. Mac: `Task`, kein Ergebnis zurück.
- Fremde Mitteilungen (CloudKit) werden sofort mit `.noData` beantwortet; der Container bearbeitet seine eigenen selbst.
- Anmeldebeobachtung: bei `signedIn` ruft der Knoten `registerForRemoteNotifications` über eine einsetzbare Closure (testbar); der Token-Rückruf reicht an `DeviceRegistration.register` weiter, das je Paar und Prozess dedupliziert.
- Fehler-Rückruf loggt nur den Fallnamen, nie Token oder Fehlertext mit Inhalt.

## Test Plan

### Automated Tests (TDD RED)

Unit-Tests in `LooseEndsTests/PushWakeUpTests.swift` (Lauf: `./scripts/sim.sh sim-unit PushWakeUpTests`; vorher RED, weil der Knoten fehlt). Keine UI-Tests: keine Oberfläche; der Bedienablauf ist ein Simulator-Beleg.

- [ ] Test 1: GIVEN `userInfo` mit und ohne Schlüssel `looseends` WHEN `isWake` THEN wahr nur mit Schlüssel.
- [ ] Test 2: GIVEN ein `wake()`, das zurückkehrt WHEN `handle(isWake: true)` THEN Ergebnis geweckt (`.newData`).
- [ ] Test 3: GIVEN ein `wake()`, das hängt WHEN die 20-s-Frist (im Test verkürzt) abläuft THEN Ergebnis Frist (`.noData`).
- [ ] Test 4: GIVEN die Frist hat gewonnen WHEN `wake()` später doch endet THEN wird nicht ein zweites Mal abgeschlossen.
- [ ] Test 5: GIVEN eine fremde Mitteilung WHEN `handle(isWake: false)` THEN `.notOurs` ohne `wake()`-Aufruf.
- [ ] Test 6: GIVEN ein Token WHEN `didReceive(token:)` THEN geht es an `DeviceRegistration`; ohne Sitzung wird nichts gesendet.
- [ ] Test 7: GIVEN `account.status` wechselt auf `signedIn` (auch später) WHEN beobachtet THEN genau ein `registerForRemoteNotifications`; ohne Konto keines.

## Acceptance Criteria

Belegt durch `PushWakeUpTests` und den Simulator-Beleg.

- **AC-1:** GIVEN `userInfo` WHEN `PushWakeUp.isWake` prüft THEN ist es wahr nur bei vorhandenem Schlüssel `looseends` und läuft synchron im Rückruf (Test `isWakeOnlyWithLooseendsKey`).
- **AC-2:** GIVEN ein Weckruf WHEN `wake()` innerhalb der Frist zurückkehrt THEN meldet `handle` geweckt, der iOS-Delegate `.newData` (Test `wakeWinsMapsToNewData`).
- **AC-3:** GIVEN ein Weckruf WHEN `wake()` die 20-s-Frist überschreitet THEN meldet `handle` Frist, der iOS-Delegate `.noData`, nie `.failed` (Test `deadlineWinsMapsToNoData`).
- **AC-4:** GIVEN die Frist hat gewonnen WHEN `wake()` später endet THEN wird der Abschluss nicht ein zweites Mal ausgelöst (Mutex-Einmalkasten; Test `lateWakeDoesNotCompleteTwice`).
- **AC-5:** GIVEN eine Mitteilung ohne Schlüssel `looseends` WHEN sie eintrifft THEN antwortet der Knoten sofort `.noData` und ruft `wake()` nicht auf (Test `foreignNotificationReturnsImmediately`).
- **AC-6:** GIVEN ein Gerätetoken WHEN der Token-Rückruf kommt THEN geht es über `DeviceRegistration.register` an den Dienst, nur mit Sitzung, und nichts ohne (Test `tokenForwardedOnlyWithSession`).
- **AC-7:** GIVEN `account.status` WHEN er `signedIn` wird (beim Start oder später) THEN wird `registerForRemoteNotifications` genau einmal ausgelöst, ohne Konto nie (Test `signInTriggersOneRegistration`).
- **AC-8:** GIVEN `--ui-testing` oder Unit-Tests WHEN die App startet THEN ist der Knoten nicht installiert und es wird nichts registriert (Test `silentUnderTests`).
- **AC-9:** GIVEN der Mac WHEN `MacAppDelegate` Token oder Mitteilung erhält THEN reicht er an denselben Knoten durch, ohne Completion-Handler (Beleg: Mac-Bau `./scripts/sim.sh mac-build` grün und Diff).
- **AC-10:** GIVEN der Diff WHEN gelesen THEN bleiben `project.yml`, Entitlements, `Info.plist` und `server/` unverändert, und es entsteht keine zweite Stelle für `registerForRemoteNotifications` außerhalb des Knotens.
- **AC-11:** GIVEN die ganze Suite WHEN sie läuft THEN sind `./scripts/sim.sh unit` und die CI grün, und der Simulator-Bau gelingt (`./scripts/sim.sh build`).
- **AC-12:** GIVEN der Simulator-Bau mit `LOOSEENDS_SIM_SIGN=1` und Debug-Weg (`local-service.sh`) WHEN `xcrun simctl push` einen Weckruf mit Schlüssel `looseends` sendet THEN wird der Auftrag geholt (Ergebnis in der Datenbank belegt), und ein Inhalt ohne den Schlüssel löst kein Holen aus (Beleg unter `docs/artifacts/feat-795-s5c2a-weckruf-delegates/`; der Simulator-Rückruf gilt laut Forum 725200 als unzuverlässig, Abweichung wird im Beleg benannt).

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): App-Delegate und Knoten, Weckruf holt sofort** | stiller Weckruf, 20-s-Frist | zeitnah, testbar, setzt PO-Entscheidung A um | Gerätepfad, CloudKit-Koexistenz nur am Gerät belegbar | nichts; keine ADR |
| **B: kein App-Teil, nur Holen bei Start und Vordergrund (heute)** | nichts bauen | kein Risiko | Weckruf des Dienstes ohne Empfänger, Auftrag erst beim Öffnen | ADR-21-Addendum Weckruf bliebe ohne Wirkung; fällt hinter die PO-Entscheidung A |
| **C: nur `BGAppRefreshTask` (Muster #553)** | System wählt den Zeitpunkt | keine Push-Verdrahtung | kein zeitnahes Holen, Stunden Verzug | Zweck des Weckrufs |
| **D: sichtbare Mitteilung mit Notification Service Extension** | Banner plus Extension | übliche Praxis | Extension läuft nur bei sichtbaren Mitteilungen, der Nutzer sähe Banner; verworfen | Entscheidung „still“ im Addendum |

## Out of Scope / Folgeschnitte

- Datenschutz-Absatz zum Push-Token (laut CLAUDE.md „Weckruf-Absatz folgt mit #795 S5c-2“): eigener Schnitt; Rechtstext erst nach Hennings Freigabe live. Der Konto-Schalter ist im Store aus, also meldet kein Store-Bau ein Token.
- Mac-Push-Schlüssel: S5c-2b2 (PR #957); bis dahin empfängt der Mac keinen Weckruf.
- Watch: kein Konto, nicht betroffen.

## Abnahme

Pfad der Geräteliste berührt: `LooseEnds/Notifications/` (neue Datei). Stufe 1 sind die Unit-Tests, Stufe 2 der Simulator-Durchlauf (AC-12). Stufe 3 läuft über TestFlight (Konto-Bau), PR mit `Refs #795`. Die Gerätepunkte stehen in der Definition of Done, nicht als AC (das QA-Gate kennt keinen Aufschub).

## Definition of Done

- [ ] AC-1 bis AC-12 erfüllt, Tests vor dem Code geschrieben (RED belegt)
- [ ] Abnahme Stufe 1 und 2 belegt, Beleg mit Abweichungen benannt
- [ ] Stufe 3 (TestFlight, Konto-Bau, Rückmeldung Henning): Weckruf holt einen Auftrag, während die App im Hintergrund liegt
- [ ] Stufe 3: iCloud-Abgleich im Hintergrund unverändert (CloudKit-Koexistenz)
- [ ] `CLAUDE.md`-Zeile aktualisiert
- [ ] PR mit `Refs #795`, CI grün, Merge durch Claude; #795 kommentiert, Board aktuell, Memory geschrieben

## Known Limitations

- Hintergrund-Mitteilungen werden vom System gedrosselt und nicht garantiert zugestellt (Apple, „Pushing background updates“); der Start und der Wechsel in den Vordergrund holen weiterhin.
- Eine kurz vor dem Mac-Start eingetroffene Mitteilung ruft den AppKit-Rückruf nicht auf; unkritisch, weil der Start ohnehin sendet und holt.
- Der Simulator-Rückruf ist unzuverlässig; der Gerätebeweis steht in der Definition of Done.

## Changelog

- 2026-11-19: Initial spec created (Schnitt S5c-2a)

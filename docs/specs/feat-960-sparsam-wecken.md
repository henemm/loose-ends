---
entity_id: feat-960-sparsam-wecken
type: feature
created: 2026-11-20
updated: 2026-11-20
status: draft
workflow: feat-960-sparsam-wecken
---

# Spec: Sparsam wecken, Weckruf-Drossel je Gerät im Dienst (#960 Schnitt 2, Teil von #795)

## Approval

- [ ] Approved

## GitHub Issue

#960 (Teil von #795, Epic #612). Analyse: `docs/context/feat-960-sparsam-wecken.md` (Abschnitte „Analysis“, „Entwurf (Empfehlung)“, „Alternativen“; verbindlich).
Vorgänger: Schnitt 1 (`docs/specs/feat-960-weckruf-sendeergebnis.md`, Sendeergebnis im Dienstlog), S5a-2a/b (Sender, Verdrahtung), S5c-2a (App-Empfang).
Dieser Schnitt ändert nur den Dienst; keine App-Änderung.

## Für den PO

Dein Wunsch vom 2026-11-20: Der Dienst stupst dein Gerät höchstens einmal je Viertelstunde an, weil iOS zu häufige stille Anstöße ohnehin ausbremst. Eine Auftragsserie von Claude löste bisher neun Anstöße in fünf Sekunden aus. Künftig kommt der erste sofort, alles Weitere binnen 15 Minuten wird mit einem einzigen späteren Anstoß am Ende der Viertelstunde nachgeholt, damit kein Auftrag liegen bleibt. In der App ändert sich nichts Sichtbares, auf deinen Geräten läuft nichts.

## Purpose

`createWaker().wake` in `server/src/apns.ts` sendet bei jedem neu gespeicherten Auftrag sofort an jedes Gerät des Kontos. iOS gibt stillen Hintergrund-Pushes nur ein kleines Budget (Apple: nicht mehr als zwei bis drei je Stunde), und der Gerätelog vom 2026-11-20 zeigt, dass ein Gerät auf Akku Weckrufe nach einer Serie nicht mehr abholt. Der Schnitt führt eine Drossel je Gerät ein: höchstens ein Weckruf je Gerät je 15 Minuten, mit genau einem Nachzügler am Fensterende, damit Aufträge, die der erste Abruf nicht erfasst hat, nicht bis zum Öffnen der App liegen bleiben.

**Regeln vor Modell:** reine Zeit- und Zählregel, kein Sprachverstehen; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Zustand im Speicher des einen Wakers je Prozess (Festlegung aus #795 S5a-2b) bleibt; kein neues Verfahren, keine Migration, keine Abhängigkeit. Die Variante mit Zeitpunkt in Postgres (C) würde diese Festlegung berühren und wird nur bei mehreren Prozessen nötig (siehe Alternativen).

## Source

- **File:** `server/src/apns.ts`
- **Identifier:** `createWaker` (`wake`, neue Drossel je Gerät), `WakerOptions` (neu: `minGapMs`, `schedule`)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `server/src/devices.ts` `listTokens`, `dropToken` | module | Geräteliste (auch vom Nachzügler neu gelesen) und Löschregel, unverändert |
| `server/src/apns.ts` `sendHttp2` | module | Sendeweg, unverändert |
| `server/src/mcp.ts` `storeOrder` | module | ruft `wake(owner)` losgelöst nach neu gespeichertem Auftrag, unverändert |
| `server/src/main.ts` `wakeFor` | module | ein Waker je Prozess, unverändert |
| `setTimeout` (Node) | extern | Standardplaner des Nachzüglers, mit `unref` |

## Schnittstelle und Festlegungen

**Optionen** (beide optional, nur für Tests und Feinsteuerung): `minGapMs` (Standard 15 Minuten = 900000 ms), `schedule(fn, delayMs)` (Standard `setTimeout` mit `unref`, damit ein geplanter Nachzügler das Beenden des Prozesses nicht aufhält). Die Schnittstelle `wake(account): Promise<void>` bleibt gleich.

**Schlüssel der Drossel:** `ENV:token` je Gerät (Umgebung und Token), im Speicher des Wakers. Dasselbe Token in `sandbox` und `production` sind zwei Geräte.

**Ablauf je Gerät beim Aufruf `wake(account)`** (Zeit `t` aus der injizierten Uhr `now`):
1. Kein Eintrag oder letzter Weckruf liegt mindestens `minGapMs` zurück: sofort senden (Sendeweg und Logzeilen wie in Schnitt 1), letzten Weckruf auf `t` setzen.
2. Sonst, kein Nachzügler geplant: genau einen Nachzügler für `letzter Weckruf + minGapMs` planen, Log `apns wake later ENV`.
3. Sonst (Nachzügler bereits geplant): nichts senden, nichts planen, Log `apns wake throttled ENV`.

**Nachzügler:** liest beim Auslösen die Geräte des Kontos mit `listTokens` neu; nur ein dann noch vorhandenes Gerät (gleicher Schlüssel) wird geweckt, ein inzwischen gelöschtes nicht. Das Wecken folgt Schritt 1 (sendet, setzt den letzten Weckruf auf die dann aktuelle Zeit, eröffnet damit ein neues Fenster) und löscht den geplanten Nachzügler aus dem Zustand. Damit gilt streng: höchstens ein Weckruf je Gerät je 15 Minuten, bei Dauerfeuer höchstens vier je Stunde.

**Zusätzliche Logzeilen (fest, nie Token oder Konto):** `apns wake later ENV` und `apns wake throttled ENV` mit `ENV` = `sandbox|production`. Die Sendezeile des Nachzüglers ist die gewohnte `apns sent STATUS ENV …`. Der Gesamt-Regex aus Schnitt 1 wird in den Tests um `wake (later|throttled) (sandbox|production)` erweitert.

**Fehlerverhalten:** `wake` wirft weiterhin nie, auch nicht im Nachzügler (Datenbankfehler beim Neulesen, Sendefehler, kaputter `log`-Callback werden wie bisher geschluckt; Neulesefehler loggt `apns send failed list`). Ein Neustart des Dienstes verliert Zustand und Plan; der nächste Auftrag weckt dann sofort (unkritisch).

**Unverändert:** Anfrage (Kopfzeilen, Priorität 5, `background`, Payload), JWT-Cache und -Erneuerung, ein Wiederholversuch bei `ExpiredProviderToken`, Löschregel, `mcp.ts`, `main.ts`, `devices.ts`.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/apns.ts` | MODIFY | Drossel je Gerät in `createWaker`, Optionen `minGapMs`, `schedule`, Nachzügler, zwei Logzeilen; ≈ +50/−5 |
| `server/test/apns.test.ts` | MODIFY | neue Drossel-Tests mit `send`-Stub, `now`, `schedule`; bestehende JWT-Tests mit `minGapMs: 0`; Logzeilen-Regex erweitert; ≈ +70/−5 |
| `CLAUDE.md` | MODIFY | Absatz `src/apns.ts`: ein Halbsatz zu Drossel und Logzeilen; +1 |

### Estimated Changes

- Dateien: 3
- LoC: ≈ +130 (Test-Anteil überwiegt), innerhalb der Limits; Funktionen ≤ 50 LoC
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neue Abhängigkeit, keine Migration.
- Seiteneffekt nach außen: weniger Weckrufe an Apple, zwei neue Logzeilen im Dienstlog; Risiko nur „zu wenig wecken“ (Auftrag wartet bis zum Öffnen, wie vor #795 S5), nie Datenverlust.

## Implementation Details

1. Zustand im Waker: `Map<string, { last: number; later: boolean }>` je Schlüssel `ENV:token`.
2. `wake` listet die Geräte (Schnitt 1: Zeile `apns wake devices=N`), entscheidet je Gerät nach den drei Fällen oben und ruft für Fall 1 die bestehende `deliver`.
3. Der Nachzügler ist eine Funktion, die `schedule` mit `last + minGapMs - now()` (mindestens 0) aufruft; im Aufruf `listTokens(account)`, Gerät per Schlüssel suchen, bei Fund Fall 1, sonst Zustand des Schlüssels entfernen. Alles in `try/catch`.
4. Aufräumen: Einträge, deren Fenster abgelaufen und ohne Nachzügler sind, werden beim nächsten Aufruf überschrieben; kein eigener Timer nötig. Die Zahl der Einträge ist durch `MAX_DEVICES` je Konto begrenzt.
5. Die zwei bestehenden Tests „jwt cache und erneuerung“ und „expiredprovidertoken …“ wecken dasselbe Gerät mehrfach binnen 15 Minuten, testen aber den JWT-Cache; sie bekommen `minGapMs: 0`.

## Test Plan

### Automated Tests (TDD RED)

Server-Tests im bestehenden Stil (`node --test`, `send` injiziert, `now` und `schedule` injiziert, `log` abgefangen, Postgres über `./server/scripts/test-local.sh`). Die neuen Tests sind vor der Umsetzung rot.

- [ ] Test 1: GIVEN ein Gerät und ein frischer Waker WHEN der erste `wake` läuft THEN sendet `send` genau einmal sofort und es wird kein Nachzügler geplant.
- [ ] Test 2: GIVEN das Gerät wurde eben geweckt WHEN ein zweiter `wake` binnen 15 min läuft THEN wird nicht gesendet, `schedule` genau einmal mit Verzögerung bis zum Fensterende aufgerufen und `apns wake later ENV` geloggt.
- [ ] Test 3: GIVEN ein Nachzügler ist geplant WHEN ein dritter und vierter `wake` binnen des Fensters laufen THEN wird weder gesendet noch ein zweiter Nachzügler geplant, es steht `apns wake throttled ENV` im Log.
- [ ] Test 4: GIVEN die Uhr steht 15 min nach dem ersten Weckruf und kein Nachzügler lief WHEN `wake` läuft THEN wird sofort wieder gesendet.
- [ ] Test 5: GIVEN ein geplanter Nachzügler und das Gerät besteht noch WHEN der Plan ausgelöst wird THEN sendet `send` genau einmal, `apns sent …` steht im Log, und ein weiterer `wake` direkt danach plant einen neuen Nachzügler statt zu senden (neues Fenster).
- [ ] Test 6: GIVEN ein geplanter Nachzügler und das Token wurde inzwischen gelöscht WHEN der Plan ausgelöst wird THEN wird nicht gesendet.
- [ ] Test 7: GIVEN zwei Geräte desselben Kontos, eines eben geweckt, eines neu WHEN `wake` läuft THEN wird nur das neue sofort geweckt, das andere gedrosselt.
- [ ] Test 8: GIVEN dasselbe Token als `sandbox` und als `production` WHEN beide nacheinander `wake` erhalten THEN werden beide sofort geweckt (getrennte Schlüssel).
- [ ] Test 9: GIVEN Drossel, Nachzügler, Neulesefehler und Löschfall WHEN alle Logzeilen gesammelt werden THEN passt jede auf den erweiterten Regex, ohne Token, Konto-Kennung, JWT oder Fehlertext.
- [ ] Test 10: GIVEN `listTokens` oder `send` wirft im Nachzügler WHEN der Plan ausgelöst wird THEN wirft nichts nach außen und der Zustand bleibt nutzbar (der nächste `wake` plant wieder).
- [ ] Test 11: GIVEN die bestehenden Tests zu Anfrage, JWT-Cache, Wiederholversuch, Löschregel, „wake wirft nie“ und Logformat WHEN sie laufen THEN sind sie grün (JWT-Tests mit `minGapMs: 0`).

## Acceptance Criteria

- **AC-1:** GIVEN ein Gerät ohne früheren Weckruf WHEN `wake` läuft THEN wird sofort genau einmal gesendet und kein Nachzügler geplant (Test 1).
- **AC-2:** GIVEN ein Weckruf liegt weniger als `minGapMs` zurück WHEN ein weiterer `wake` läuft THEN wird nicht gesendet, genau ein Nachzügler für das Fensterende geplant und `apns wake later ENV` geloggt (Test 2).
- **AC-3:** GIVEN ein Nachzügler ist geplant WHEN weitere `wake` binnen des Fensters laufen THEN wird kein zweiter geplant und nichts gesendet; jeder dieser Aufrufe loggt `apns wake throttled ENV` (Test 3).
- **AC-4:** GIVEN der letzte Weckruf liegt mindestens `minGapMs` zurück und kein Nachzügler ist geplant WHEN `wake` läuft THEN wird wieder sofort gesendet (Test 4).
- **AC-5:** GIVEN der Nachzügler löst aus WHEN das Gerät noch existiert THEN sendet er einmal und eröffnet ein neues Fenster, sodass höchstens ein Weckruf je Gerät je 15 min entsteht (Test 5).
- **AC-6:** GIVEN der Nachzügler löst aus WHEN das Token inzwischen gelöscht ist THEN wird nicht gesendet (Test 6).
- **AC-7:** GIVEN mehrere Geräte oder dasselbe Token in `sandbox` und `production` WHEN `wake` läuft THEN wird je Schlüssel `Umgebung:Token` unabhängig gedrosselt (Tests 7, 8).
- **AC-8:** GIVEN beliebige Drossel- und Nachzüglerausgänge WHEN die Logzeilen gesammelt werden THEN passt jede auf den erweiterten Regex und enthält weder Token noch Konto-Kennung noch Fehlertext (Test 9).
- **AC-9:** GIVEN ein Fehler beim Neulesen oder Senden im Nachzügler WHEN er auslöst THEN wirft nichts nach außen; `wake` wirft weiterhin nie (Test 10).
- **AC-10:** GIVEN die Änderung WHEN `./server/scripts/test-local.sh` läuft THEN sind `npm run typecheck` und `npm test` grün, einschließlich der bestehenden Tests zu Anfrage, JWT, Wiederholversuch und Löschregel; Sendeweg, Payload und Priorität sind unverändert (Test 11, Diff-Durchsicht).
- **AC-11:** GIVEN der Dienst ist auf `rennwienix` ausgerollt WHEN eine Auftragsserie von Claude läuft THEN zeigt das Dienstlog je Gerät höchstens eine Sendezeile `apns sent …` binnen 15 min, dazu `apns wake throttled`-Zeilen und höchstens ein `apns wake later`; der Beleg liegt unter `docs/artifacts/feat-960-sparsam-wecken/` (nur diese Zeilen, ohne Fremdzeilen). Gerätetest und App-Änderung entfallen. Eine Probe-Serie in Hennings Daten nur nach seinem Ja, sonst der nächste natürliche Fall; der Stand steht bis dahin im Issue.

## Abgrenzung (Out of Scope)

- Änderungen an der App, `mcp.ts`, `main.ts`, `devices.ts`, Migrationen: keine.
- Sichtbare Mitteilungen oder eine Notification Service Extension (Entscheidung „still“ aus #795 S5 bleibt).
- Zeitpunkt über Neustarts hinweg oder über mehrere Prozesse (Alternative C).

## Alternativen

| Weg | Was | Warum nicht jetzt / was gekippt würde |
|---|---|---|
| **B: Sammelpause vorne** (z. B. 10 s nach dem ersten Auftrag wecken) | fängt eine Serie mit einem Weckruf | kostet jedem Einzelauftrag 10 s Verzögerung, macht `wake` zeitversetzt, alle Tests müssten umgebaut werden; kann folgen, wenn der Log häufige Nachzügler zeigt |
| **C: Zeitpunkt in Postgres (`device_tokens.woken_at`)** | übersteht Neustart und mehrere Prozesse | Migration und Schemaänderung für einen Vorteil, den ein Prozess nicht braucht; würde die Festlegung „ein Waker je Prozess“ (#795 S5a-2b) ersetzen |
| **D: Nachzügler nur, wenn noch Aufträge warten** | spart einen Weckruf, wenn die App inzwischen geöffnet war | braucht eine neue Abfrage in `orders.ts` (vierte Datei); später möglich, wenn der Log unnötige Nachzügler zeigt |
| **E: Schlüssel Konto statt Gerät** | einfacher | ein Gerät mit frischem Budget (Mac) würde mitgedrosselt; der PO hat „je Gerät“ entschieden |
| **`apns-collapse-id` allein** | Apple fasst nicht zugestellte Pushes zusammen | spart kein Budget beim Senden, keine Alternative |

## Abnahme

Der Schnitt berührt keinen Pfad der Geräteliste (`server/` ohne App, kein `project.yml`, keine Entitlements, keine `Info.plist`). Stufe 1 sind die Server-Tests, Stufe 2 die Dienst-Tests samt Typprüfung (`./server/scripts/test-local.sh`); ein Simulatorlauf der App entfällt, weil die App nicht geändert wird. Der Abschlussbericht sagt: „Kein Pfad der Geräteliste berührt.“ Gerätepunkte gibt es nicht.

## Definition of Done

- [ ] AC-1 bis AC-11 erfüllt, Server-Tests und Typprüfung grün
- [ ] PR mit `Refs #960` gemergt (Issue bleibt offen, bis der Betriebsbeleg und die Gerätewirkung geklärt sind)
- [ ] Deploy auf `rennwienix` (`bash scripts/deploy-loose-ends.sh` mit `LE_COMMIT` des Merge-Stands; `/health` 200, im Log kein `apns config invalid`)
- [ ] Betriebsbeleg nach AC-11 unter `docs/artifacts/feat-960-sparsam-wecken/`
- [ ] Issue #960 kommentiert, Board-Karte aktuell, Memory geschrieben

## Changelog

- 2026-11-20: Initial spec created

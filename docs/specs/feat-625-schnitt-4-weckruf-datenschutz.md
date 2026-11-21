---
entity_id: feat-625-schnitt-4-weckruf-datenschutz
type: feature
created: 2026-11-21
updated: 2026-11-21
status: draft
workflow: feat-625-weckruf-datenschutz
---

# Spec: Weckruf (Push-Token) im Datenschutztext, Schnitt 4 (#625)

## Approval

- [ ] Approved

## GitHub Issue

#625 (Store-Datenschutzangaben, Store-Schalter, Einreichung). Dieser Schnitt ist der Nachtrag, den Schnitt 1 auf „mit #795 S5c“ verschoben hat; das Issue bleibt offen (`Refs #625`, nie `Closes #625`).
Analyse: `docs/context/feat-625-weckruf-datenschutz.md`. Vorbild in Aufbau und Strenge: `docs/specs/feat-625-schnitt-1-datenschutztext.md`.
Reiner Textschnitt: **kein App-Code, kein Dienstcode, kein Pfad der Geräteliste.** Zwei Repos (`loose-ends`, `henemm/henemm-website`), je ein PR.

## Für den PO

Seit dem Bau von #795 S5c meldet die App, sobald du angemeldet bist, ein Gerätetoken von Apple an unseren Dienst. Das ist eine Adresse, über die der Dienst deine App still wecken kann, wenn Claude einen Auftrag hinterlegt. Das steht noch nirgends im Datenschutztext. Dieser Schnitt schreibt es in einfachen Worten hinein, deutsch und englisch, und veröffentlicht den Text danach auf henemm.com.

Der Text sagt ehrlich, was gespeichert wird (das Gerätetoken, die Art des Systems, die Kennung dieser Installation), was die stille Mitteilung enthält (nichts aus deinen Aufgaben, nichts Sichtbares, höchstens eine je Gerät in 15 Minuten) und wann das Token verschwindet. Dabei steht auch eine unbequeme Tatsache: **„Abmelden“ löscht das Gerätetoken nicht.** Dein Gerät kann danach weiter still geweckt werden, holt aber nichts ab. Gelöscht wird es durch „Konto löschen“. Wer das nicht will, müsste Dienst und App ändern; das ist die Alternative unten und nicht empfohlen, solange der Store-Schalter aus ist.

Mit deiner Freigabe dieser Spezifikation gibst du den Wortlaut unten frei. Nichts davon ändert etwas in den Stores oder auf deinem Gerät; der Schalter, der das Konto im Store sichtbar macht, bleibt aus.

## Purpose

Der Datenschutztext (`docs/reference/datenschutz-entwurf.md`, Quelle; öffentlich `https://www.henemm.com/legal/loose-ends/privacy-policy/` de und `…/privacy-policy-en/` en) beschreibt Abschrift und Kennung der Installation, aber nicht den **Weckruf**: Seit #795 S5c fragt die App nach der Anmeldung ein Gerätetoken an (`PushWakeUp`), meldet es mit `POST /app/device` (`DeviceRegistration`, `ServiceClient.putDevice`), und der Dienst weckt damit die App still über Apples Push-Dienst nach jedem neu gespeicherten Auftrag (`storeOrder`, `apns.ts`). Weil das in TestFlight-Bauten mit Konto läuft, muss der Text es nachziehen, unabhängig vom Store-Schalter.

**Ablauf (feste Reihenfolge):**

1. Wortlaut (unten) durch Henning freigeben lassen (die Spec-Freigabe ist die Wortlaut-Freigabe).
2. Prüfskript `scripts/test_datenschutz_text.py` ergänzen, RED-Beleg gegen den unveränderten Entwurf.
3. Entwurf und `CLAUDE.md` ändern (de und en), Skript GREEN; PR in `loose-ends` (`Refs #625`).
4. PR in `henemm-website` mit beiden Seiten; nach Merge und Auslieferung Live-Prüfung (`DATENSCHUTZ_LIVE=1`).

**Regeln vor Modell:** reiner Text, Prüfung per Regex; die Zeile „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue ADR — setzt ADR-21 fort (der Text beschreibt, was der Dienst hält) und die Beleg-Regel des Datenschutztextes; kein neues Verfahren, keine neue Abhängigkeit, kein Schema, kein Code.
- **Rationale:** Eine Seite für App und Dienst (Entscheidung #705); der Nachtrag steht im bestehenden Konto-Abschnitt. Jede Aussage hat einen Beleg im Code (Tabelle unten). Der Text beschreibt das heutige Verhalten, auch das unbequeme zum Abmelden; die Gegenentscheidung „Abmelden löscht das Token“ wäre eine Code-Änderung und kippt keine ADR.

## Source

**Dateien (loose-ends):** `docs/reference/datenschutz-entwurf.md`, `scripts/test_datenschutz_text.py`, `CLAUDE.md` (ein Satz im Datenschutz-Absatz unter „Build“).
**Dateien (`henemm/henemm-website`, nur über `gh api` les- und änderbar):** `content/legal/loose-ends/privacy-policy/_index.md`, `content/legal/loose-ends/privacy-policy-en/_index.md`.
**Nicht berührt:** `project.yml` (`LEAccountEnabled` bleibt `false`), jede `Info.plist`, `LooseEnds/PrivacyInfo.xcprivacy`, `docs/reference/app-store-datenschutzangaben.md` (nennt das APNs-Token schon unter Device ID; nur Abgleich, kein Diff), App- und Dienstcode.

**Gegen den Code geprüft (2026-11-21), Befund:**

- **Anfrage nach dem Token:** `PushWakeUp.observeSignIn` beobachtet `AccountState.status` und ruft `registerForRemote` (`registerForRemoteNotifications`), sobald der Status auf `signedIn` wechselt; die Beobachtung beginnt mit „nicht angemeldet“, also auch beim Start einer schon angemeldeten App. Beim Abmelden passiert nichts (kein `unregisterForRemoteNotifications`).
- **Meldung an den Dienst:** `DeviceRegistration.register(token:)` geht nur über `AccountState.withSession` (ohne Sitzung nichts), dasselbe Paar aus Token und Umgebung nur einmal je Prozess. `ServiceClient.putDevice` sendet `POST /app/device` mit genau `token` (Hex) und `environment` (`sandbox`/`production`) und der Kopfzeile `X-Device` (Kennung dieser Installation).
- **Speicher:** `server/migrations/008_device_tokens.sql`: `account_id`, `device`, `token`, `environment`, `updated_at`; ein Token gehört genau einem Konto und Gerät (`UNIQUE (token)`, Primärschlüssel `(account_id, device)`); `ON DELETE CASCADE` auf `accounts`. `server/src/devices.ts` `putDevice`: ein Token, das bei anderem Konto/Gerät gemeldet wird, verlässt den alten Besitzer; höchstens `MAX_DEVICES` = 10 Geräte je Konto, die ältesten fallen weg, nie die gerade geschriebene Zeile.
- **Wofür und was gesendet wird:** `server/src/mcp.ts` `storeOrder` weckt die Geräte des Kontos abgekoppelt nach jedem **neu** gespeicherten Auftrag; `server/src/apns.ts` sendet an APNs den festen Inhalt `{"aps":{"content-available":1},"looseends":{"v":1}}` mit `apns-push-type: background`, Priorität 5: kein Aufgabeninhalt, keine sichtbare Mitteilung; höchstens ein Push je Gerät in `MIN_GAP` = 15 Minuten (ein weiterer innerhalb des Fensters plant genau einen späteren).
- **Löschen:** `dropToken` löscht die Zeile bei Apples Antwort 410 `Unregistered`, 400 `BadDeviceToken` oder 400 `DeviceTokenNotForTopic` (`DROP` in `apns.ts`); „Konto löschen“ per Kaskade; `POST /auth/logout` ruft nur `endSession` und lässt `device_tokens` stehen.
- **Protokolle:** Das Dienstprotokoll nennt nie Token oder Konto (#960); der Webserver schreibt für `/app/device` wie für jeden Pfad IP, Adresse, Zeit, Code (14 Tage, steht schon im Text unter „Server-Protokolle“).
- **Nach dem Abmelden:** Das Gerät kann weiter geweckt werden (Zeile bleibt); `wake()` läuft dann über `withSession` ohne Sitzung und holt nichts ab. Das folgt dem Muster der Abschrift („Abmelden hält das Senden an; die Abschrift bleibt“).
- **Hinweis, kein Teil dieser Spec:** Der Kommentar „Nothing calls it yet.“ in `LooseEnds/Claude/DeviceRegistration.swift` ist überholt (`PushWakeUp.forApp` ruft es). App-Code wird hier nicht angefasst; Folgearbeit im Epic #795.

### Wortlaut (Entwurf, deutsch)

**Neuer Absatz im Abschnitt „Wenn du die Verbindung zu Claude nutzt“**, nach „Kennung dieser Installation.“ und vor „Wo.“:

> **Weckruf.** Damit deine App Aufträge aus Claude zügig abholt, ohne dass du sie öffnen musst, kann der Dienst sie still wecken. Dafür fragt die App nach der Anmeldung und bei jedem Start, solange du angemeldet bist, bei Apple ein Gerätetoken an und schickt es an den Dienst, zusammen mit der Art des Systems (Test oder Produktion) und der Kennung dieser Installation. Das Gerätetoken ist eine Adresse, die Apple für diese App auf diesem Gerät vergibt; es enthält weder deinen Namen noch etwas aus deinen Aufgaben. Der Dienst speichert je Gerät eines, mit dem Zeitpunkt der letzten Meldung, höchstens zehn Geräte je Konto; kommt ein elftes dazu, fällt das älteste weg. Hinterlegt Claude einen neuen Auftrag, schickt der Dienst über den Push-Dienst von Apple (APNs) eine stille Mitteilung an deine Geräte. Sie hat einen festen Inhalt, enthält nichts aus deinen Aufgaben und zeigt nichts an; die App holt daraufhin den Auftrag ab. Der Dienst schickt je Gerät höchstens eine solche Mitteilung in 15 Minuten. Das Gerätetoken bleibt gespeichert, bis du dein Konto löschst, bis Apple es als ungültig meldet, bis dasselbe Token bei einem anderen Konto oder Gerät gemeldet wird oder bis es als ältestes von mehr als zehn Geräten wegfällt. „Abmelden“ löscht es nicht: Dein Gerät kann danach weiter still geweckt werden, holt aber nichts ab, solange du nicht angemeldet bist.

**Absatz „Kennung dieser Installation.“**, am Ende ein Satz angefügt (alle bisherigen Sätze bleiben wörtlich):

> Dieselbe Kennung schickt die App auch mit, wenn sie sich für den Weckruf meldet; sie wird dann zusammen mit dem Gerätetoken gespeichert (siehe „Weckruf.“).

**Absatz „Löschen.“**, zweiter Satz geändert (ersetzt „…darunter die Abschrift deiner Aufgaben, Aufträge und Ergebnisse, und widerruft die Anmeldung bei Apple.“):

> Das entfernt dein Konto und alle Daten, die der Dienst zu diesem Konto gespeichert hat, darunter die Abschrift deiner Aufgaben, Aufträge und Ergebnisse und das Gerätetoken für den Weckruf, und widerruft die Anmeldung bei Apple.

**Abschnitt „Was Apple dabei übernimmt“:** „An vier Stellen“ wird „An fünf Stellen“; neuer Punkt nach „Diktat auf der Watch“:

> - **Push-Mitteilungen:** Die stille Mitteilung für den Weckruf stellt Apples Push-Dienst zu; dort gilt Apples Datenschutz.

Alle übrigen Absätze bleiben unverändert.

### Wortlaut (Entwurf, englisch, wortgetreu)

Änderungen im Abschnitt „### 4. If you use the connection to Claude“ und „### 6. What Apple takes over“; die Nummerierung ändert sich nicht. „Last updated“ wird auf das Veröffentlichungsdatum gesetzt.

**New paragraph**, after “Identifier of this installation.” and before “Where.”:

> **Wake-up.** So that your app collects orders from Claude promptly without you having to open it, the service can wake it silently. For this, after sign-in and at every start while you are signed in, the app asks Apple for a device token and sends it to the service, together with the kind of system (test or production) and the identifier of this installation. The device token is an address that Apple assigns to this app on this device; it contains neither your name nor anything from your tasks. The service stores one per device, with the time of the last report, at most ten devices per account; when an eleventh is added, the oldest drops out. When Claude places a new order, the service sends a silent notification to your devices through Apple's push service (APNs). It has a fixed content, contains nothing from your tasks and shows nothing; the app then collects the order. The service sends at most one such notification per device in 15 minutes. The device token stays stored until you delete your account, until Apple reports it as invalid, until the same token is reported for another account or device, or until it drops out as the oldest of more than ten devices. "Sign out" does not delete it: your device can still be woken silently afterwards, but collects nothing as long as you are not signed in.

**Paragraph “Identifier of this installation.”**, one sentence appended at the end (all existing sentences stay verbatim):

> The app also sends the same identifier when it registers for the wake-up; it is then stored together with the device token (see "Wake-up.").

**Paragraph “Deleting.”**, second sentence changed (replaces “…including the transcript of your tasks, orders and results, and revokes the sign-in with Apple.”):

> This removes your account and all data the service has stored for that account, including the transcript of your tasks, orders and results and the device token for the wake-up, and revokes the sign-in with Apple.

**Section 6:** “In four places” becomes “In five places”; new bullet after “Dictation on the Watch”:

> - **Push notifications:** The silent notification for the wake-up is delivered by Apple's push service; there Apple's privacy rules apply.

### Beleg-Tabelle (kommt in den Entwurf unter „Beleg im Code“, nach der Zeile „Auftrag, Ergebnis und Kennung werden mit dem Konto gelöscht“)

| Aussage | Beleg |
|---|---|
| App fragt das Gerätetoken nach der Anmeldung und bei jedem Start (angemeldet) an | `LooseEnds/Claude/PushWakeUp.swift` (`observeSignIn`: `registerForRemote` beim Wechsel auf `signedIn`, `requestDeviceToken`) |
| Meldung nur mit Sitzung; Inhalt: Token, Art des Systems, Kennung dieser Installation | `LooseEnds/Claude/DeviceRegistration.swift` (`register`, `AccountState.withSession`, `PushEnvironment`); `LooseEnds/Claude/ServiceClient.swift` (`putDevice`: Körper `token`, `environment`; Kopf `X-Device`) |
| Gespeichert je Gerät mit Zeitpunkt, ein Token gehört einem Konto und Gerät | `server/migrations/008_device_tokens.sql` (`device_tokens`, `UNIQUE (token)`, `updated_at`); `server/src/devices.ts` (`putDevice`) |
| Höchstens zehn Geräte je Konto, ältestes fällt weg; umgezogenes Token verlässt den alten Besitzer | `server/src/devices.ts` (`MAX_DEVICES` = 10, `DELETE … OFFSET`, `DELETE … WHERE token`) |
| Weckruf nach jedem neu gespeicherten Auftrag | `server/src/mcp.ts` (`storeOrder`: `stored === "stored"` → `wake(owner)`) |
| Fester Inhalt, nichts Sichtbares, über APNs | `server/src/apns.ts` (`BODY`, `apns-push-type: background`, `apns-priority: 5`) |
| Höchstens eine Mitteilung je Gerät in 15 Minuten | `server/src/apns.ts` (`MIN_GAP`, `minGapMs`-Fenster, ein späterer Weckruf) |
| Token fällt bei Apples Ungültig-Meldung weg | `server/src/apns.ts` (`DROP`: 410 `Unregistered`, 400 `BadDeviceToken`, 400 `DeviceTokenNotForTopic`), `server/src/devices.ts` (`dropToken`) |
| „Konto löschen“ entfernt das Token | `server/migrations/008_device_tokens.sql` (`ON DELETE CASCADE`), `server/src/accounts.ts` (`deleteAccount` löscht das Konto) |
| „Abmelden“ löscht das Token nicht, Gerät holt danach nichts ab | `server/src/auth.ts` (`POST /auth/logout` ruft nur `endSession`); `LooseEnds/Claude/PushWakeUp.swift` (nichts beim Abmelden); `AccountState.withSession` (ohne Sitzung nichts) |
| Dienstprotokoll ohne Token und Konto | #960, `server/src/apns.ts` (Logzeilen nur mit Status, Umgebung, Kennungen Apples) |

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| #795 S5c-1, S5c-2a, S5c-2b (`PushWakeUp`, `DeviceRegistration`, `putDevice`) | Code, gebaut | belegt, was die App meldet und wann |
| #795 S5a-1, S5a-2a/b (Migration 008, `devices.ts`, `apns.ts`) | Code, ausgerollt | belegt, was der Dienst speichert und sendet |
| #960 (Drossel 15 min, Logform ohne Token und Konto) | Code, ausgerollt | belegt die 15 Minuten und das Protokoll |
| `docs/specs/feat-625-schnitt-1-datenschutztext.md` und der veröffentlichte Konto-Teil | Voraussetzung, besteht | Nachtrag im selben Abschnitt |
| Website-Repo `henemm/henemm-website`, Seiten `privacy-policy` und `privacy-policy-en` | zweiter PR über `gh api` | öffentliche Fassung |
| `scripts/test_datenschutz_text.py`, CI-Befehl `python -m unittest discover -s scripts -p 'test_*.py'` | wird geändert | Anker und veralteter Satz |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/reference/datenschutz-entwurf.md` | MODIFY | Absatz „Weckruf.“/„Wake-up.“, Zusatzsatz „Kennung“, Löschsatz, „Was Apple dabei übernimmt“ (de und en), elf Beleg-Zeilen, „Offen“-Punkt Weckruf entfernt, „vier“ → „fünf Apple-Punkte“, Statuskopf de und en; ≈ +40/−8 |
| `scripts/test_datenschutz_text.py` | MODIFY | neue Anker, `STALE`, `WAKE`-Prüfung mit Gegenprobe; ≈ +15 |
| `CLAUDE.md` | MODIFY | Satz „der Weckruf-Absatz (Push-Token) folgt mit #795 S5c-2“ ersetzt; ≈ +1/−1 |
| `henemm-website: content/legal/loose-ends/privacy-policy/_index.md` | MODIFY | öffentliche deutsche Fassung, zweiter PR; ≈ +6/−3 |
| `henemm-website: content/legal/loose-ends/privacy-policy-en/_index.md` | MODIFY | öffentliche englische Fassung, zweiter PR; ≈ +6/−3 |
| `docs/artifacts/feat-625-weckruf-datenschutz/` | CREATE | Belege (Text, zwei Bilder); zählt nicht zum Dateilimit |

### Estimated Changes

- Dateien: 5 Pfade (3 in `loose-ends`, 2 im zweiten Repo). **App-Code: 0 LoC.** Text ca. +30/−6 je Repo-Teil, Prüfskript ca. +15.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, kein `generate`, keine Migration, keine neue Abhängigkeit.
- **Seiteneffekt nach außen (explizit):** Zwei öffentliche Rechtsseiten ändern ihren Inhalt; sonst keine.
- Vor jedem PR `origin/main` und offene PRs in beiden Repos prüfen (Hotspots: `CLAUDE.md`, Entwurf).

## Implementation Details

Der Text beschreibt das heutige Verhalten ehrlich, im Muster des Abschrift-Absatzes: wann (nach der Anmeldung, bei jedem Start), was (Gerätetoken, Art des Systems, Kennung), wofür (stille Mitteilung über APNs nach neuem Auftrag), was nicht (kein Aufgabeninhalt, nichts Sichtbares), wie oft (höchstens eine je Gerät in 15 Minuten), wie lange (vier Löschwege, Abmelden gehört nicht dazu). Die Rechtsgrundlage steht nicht im Absatz; wie bei den übrigen Konto-Daten gilt die freiwillige Nutzung der Verbindung (Abschnittseinleitung). Auf der Website stehen dieselben Änderungen an denselben Stellen; „Beleg im Code“ und „Offen, nicht belegt“ bleiben nur im Entwurf.

## Test Plan

### Automated Tests (TDD RED)

Kein App- oder Dienstcode, also keine Unit- oder UI-Tests der App. Geprüft wird der Text mit dem Prüfskript (`unittest`).

**Neue Anker in `ANCHORS` (wörtlich, de und en; damit auch in der Live-Prüfung):**

- de: „Dafür fragt die App nach der Anmeldung und bei jedem Start, solange du angemeldet bist, bei Apple ein Gerätetoken an und schickt es an den Dienst“; „Sie hat einen festen Inhalt, enthält nichts aus deinen Aufgaben und zeigt nichts an“; „Der Dienst schickt je Gerät höchstens eine solche Mitteilung in 15 Minuten.“; „„Abmelden“ löscht es nicht: Dein Gerät kann danach weiter still geweckt werden, holt aber nichts ab, solange du nicht angemeldet bist.“; „darunter die Abschrift deiner Aufgaben, Aufträge und Ergebnisse und das Gerätetoken für den Weckruf, und widerruft die Anmeldung bei Apple.“ (ersetzt den alten Löschanker); „Dieselbe Kennung schickt die App auch mit, wenn sie sich für den Weckruf meldet“; „**Push-Mitteilungen:**“ ohne Sternchen als „Push-Mitteilungen: Die stille Mitteilung für den Weckruf stellt Apples Push-Dienst zu“.
- en: “the app asks Apple for a device token and sends it to the service”; “It has a fixed content, contains nothing from your tasks and shows nothing”; “The service sends at most one such notification per device in 15 minutes.”; “"Sign out" does not delete it: your device can still be woken silently afterwards, but collects nothing as long as you are not signed in.”; “including the transcript of your tasks, orders and results and the device token for the wake-up, and revokes the sign-in with Apple.” (ersetzt den alten Löschanker); “The app also sends the same identifier when it registers for the wake-up”; “Push notifications: The silent notification for the wake-up is delivered by Apple's push service”.

**`STALE`:** „Im Text ist der Weckruf deshalb nicht beschrieben“ (der Satz aus „Offen, nicht belegt“) kommt hinzu; er darf weder im Entwurf noch auf den Seiten stehen.

**`WAKE`-Prüfung:** der Konto-Abschnitt nennt je Sprache de „Weckruf“, „Gerätetoken“, „Abmelden“ / en „wake-up“, „device token“, „Sign out“ (Muster `TRANSCRIPT`/`missing_transcript`).

- [ ] Test 1: GIVEN der unveränderte Entwurf WHEN `python3 scripts/test_datenschutz_text.py` läuft THEN ist es rot (fehlende Anker, `WAKE`-Wörter fehlen, STALE-Satz vorhanden); GIVEN der geänderte Entwurf THEN grün.
- [ ] Test 2: GIVEN ein Konto-Abschnitt ohne „Gerätetoken“ WHEN die Prüfung läuft THEN meldet sie „Gerätetoken“ als fehlend; GIVEN einer mit allen drei Wörtern THEN meldet sie nichts.
- [ ] Test 3: GIVEN der Satz „Offen: Im Text ist der Weckruf deshalb nicht beschrieben.“ WHEN `stale_phrases` läuft THEN wird er gefangen.
- [ ] Test 4: GIVEN die ausgelieferten Seiten WHEN das Skript mit `DATENSCHUTZ_LIVE=1` läuft THEN ist es grün; ohne die Variable werden die Live-Tests übersprungen und im Beleg einzeln benannt.

**Ehrlich zur Belegkraft:** Das Skript belegt, dass der Text die Kernsätze enthält und den veralteten nicht; ob die Aussagen wahr sind, belegen die Beleg-Tabelle und `aussagen.txt` gegen den Code. Eine rechtliche Prüfung ersetzt keines von beiden.

## Acceptance Criteria

Belege liegen unter `docs/artifacts/feat-625-weckruf-datenschutz/`. Kein Beleg enthält Tokens, `sub`-Werte, Zugangsdaten oder IP-Adressen von Nutzern.

- **AC-1:** GIVEN `docs/reference/datenschutz-entwurf.md` WHEN der deutsche Abschnitt „Wenn du die Verbindung zu Claude nutzt“ gelesen wird THEN steht der Absatz „Weckruf.“ nach „Kennung dieser Installation.“ und vor „Wo.“ im freigegebenen Wortlaut, mit den Aussagen: Gerätetoken nach Anmeldung und bei Start, Inhalt der Meldung (Token, Art des Systems, Kennung), höchstens zehn Geräte, stille Mitteilung über APNs nach neuem Auftrag, fester Inhalt ohne Aufgabeninhalt und nichts Sichtbares, höchstens eine je Gerät in 15 Minuten, vier Löschwege, „Abmelden“ löscht es nicht und das Gerät kann weiter still geweckt werden.
- **AC-2:** GIVEN der Absatz aus AC-1 WHEN er mit `PushWakeUp.swift`, `DeviceRegistration.swift`, `ServiceClient.swift` (`putDevice`), `008_device_tokens.sql`, `devices.ts`, `apns.ts`, `mcp.ts` (`storeOrder`) und `auth.ts` (`logout`) verglichen wird THEN hat jede Aussage einen Beleg und keine einen Gegenbeleg (Beleg `aussagen.txt`: je Aussage Datei und Fundstelle).
- **AC-3:** GIVEN der Entwurf WHEN „Kennung dieser Installation.“, „Löschen.“ und „Was Apple dabei übernimmt“ gelesen werden THEN trägt der Kennungs-Absatz den angefügten Satz zum Weckruf (alle übrigen Sätze unverändert), der Löschsatz nennt das Gerätetoken, und „Was Apple dabei übernimmt“ steht auf „fünf Stellen“ mit dem Punkt „Push-Mitteilungen“, jeweils im freigegebenen Wortlaut.
- **AC-4:** GIVEN der Abschnitt „English“ im Entwurf WHEN er mit dem deutschen verglichen wird THEN enthält er den Absatz „Wake-up.“, den angefügten Kennungs-Satz, den geänderten Löschsatz und den neuen Punkt in Abschnitt 6 („In five places“) im englischen Wortlaut oben, ohne Zusätze und Kürzungen und ohne Änderung der Nummerierung; „Last updated“ trägt das Veröffentlichungsdatum.
- **AC-5:** GIVEN der Entwurf WHEN „Beleg im Code“ gelesen wird THEN stehen nach der Zeile „Auftrag, Ergebnis und Kennung werden mit dem Konto gelöscht“ die elf Zeilen der Beleg-Tabelle oben, und jede Dateiangabe nennt eine Datei, die im Repo existiert (Beleg `belege-pfade.txt`: Pfadliste mit Existenzprüfung).
- **AC-6:** GIVEN der Entwurf WHEN „Offen, nicht belegt“ und der Statuskopf gelesen werden THEN fehlt der Punkt „Weckruf (Push-Token)“ samt dem Satz „Im Text ist der Weckruf deshalb nicht beschrieben“, der Punkt „Die vier Apple-Punkte“ heißt „Die fünf Apple-Punkte“, und beide Statuskopf-Abschnitte (de, en) nennen die Freigabe des Nachtrags (Datum der Spec-Freigabe) und die Veröffentlichung (Datum und Website-PR, nach dem Merge eingetragen).
- **AC-7:** GIVEN `scripts/test_datenschutz_text.py` WHEN `python3 scripts/test_datenschutz_text.py` und der CI-Befehl `python -m unittest discover -s scripts -p 'test_*.py'` laufen THEN sind sie grün; die Anker aus dem Testplan stehen in `ANCHORS` (de und en), der alte Löschanker ist durch den neuen ersetzt, `STALE` enthält „Im Text ist der Weckruf deshalb nicht beschrieben“, und die `WAKE`-Prüfung samt Gegenprobe ist vorhanden.
- **AC-8:** GIVEN das ergänzte Skript und der unveränderte Entwurf WHEN es läuft THEN ist es rot, und `red.txt` zeigt die fehlenden Anker und den vorhandenen STALE-Satz; nach der Änderung zeigt `green.txt` den grünen Lauf des CI-Befehls.
- **AC-9:** GIVEN `CLAUDE.md` WHEN der Datenschutz-Absatz unter „Build“ gelesen wird THEN ersetzt ein Satz „Seit [Datum der Veröffentlichung] beschreibt der Text auch den Weckruf (Gerätetoken, stille Mitteilung; Verweis auf diese Spec)“, mit dem tatsächlichen Datum eingesetzt, den Satz „der Weckruf-Absatz (Push-Token) folgt mit #795 S5c-2“; alle übrigen Sätze des Absatzes bleiben unverändert (Diff), `LEAccountEnabled` bleibt bis #625 aus.
- **AC-10:** GIVEN die Freigabe des Wortlauts und der gemergte `loose-ends`-PR WHEN der PR in `henemm/henemm-website` die Seiten `content/legal/loose-ends/privacy-policy/_index.md` und `…/privacy-policy-en/_index.md` ändert THEN enthalten beide die Änderungen aus AC-1, AC-3 bzw. AC-4 im freigegebenen Wortlaut, „Stand“ bzw. „Last updated“ ist das Veröffentlichungsdatum, und die Seiten enthalten nicht „Beleg im Code“ und „Offen, nicht belegt“; erst danach wird der Website-PR gemergt.
- **AC-11:** GIVEN der gemergte und ausgelieferte Website-PR WHEN `curl -sS -o seite.html -w '%{http_code}'` beide Seiten abruft THEN ist der Code je 200, und `DATENSCHUTZ_LIVE=1 python3 scripts/test_datenschutz_text.py` ist grün (Kernaussagen, alle Anker, Abschnittstitel, keine veralteten Sätze, keine internen Abschnitte); Beleg `live.txt` mit Codes und Treffern. Die bei Apple gesetzte Datenschutz-URL bleibt unverändert.
- **AC-12:** GIVEN die veröffentlichten Seiten und der Entwurf WHEN die Abschnitte verglichen werden THEN stimmen die Kernsätze der neuen und geänderten Absätze nach Normalisierung der Anführungszeichen wörtlich überein (Beleg `vergleich.txt`).
- **AC-13:** GIVEN der Diff beider PRs WHEN er geprüft wird THEN enthält er weder `project.yml` noch eine `Info.plist` noch `PrivacyInfo.xcprivacy` noch Dateien unter `LooseEnds/`, `Shared/`, `server/`, und `LEAccountEnabled` ist weiterhin `false` (Beleg `schalter.txt`: Dateiliste und Zeile aus `project.yml`).

Abnahme: „Kein Pfad der Geräteliste berührt. Reiner Text, keine App-Änderung; Stufe 2 an den Live-Seiten belegt“ (Öffnen beider Live-Seiten im Browser, Screenshot je Sprache, geöffnet und beschrieben). Keine Gerätepunkte.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): Text beschreibt das heutige Verhalten, auch „Abmelden löscht das Token nicht“** | siehe Wortlaut | schließt die Lücke sofort, kein Code, kein Bau, ehrlich | der Text enthält einen Satz, der unbequem klingt | — |
| **B Abmelden löscht das Gerätetoken** | Dienst: `/auth/logout` nimmt `X-Device` und löscht die Zeile dieses Geräts; App: `unregisterForRemoteNotifications` beim Abmelden; Text sagt „Abmelden entfernt es“ | nach dem Abmelden wird nichts mehr geweckt; kürzerer Text | App- und Dienstcode, TestFlight-Bau, Rollout auf `rennwienix`; weicht vom Muster „Abmelden = nur Sitzung beenden“ ab; der Store-Schalter ist aus und nur Henning hat ein Konto; die stille Mitteilung trägt keinen Inhalt | keine ADR; das Muster der Abschrift (Abmelden lässt sie stehen) würde für das Token anders gelten |

**Nicht empfohlen für jetzt.** Wer B will, bekommt ein eigenes Issue (App, Dienst, danach Textänderung in beiden Sprachen); der Wortlaut hier ändert sich dann in einem Satz. Keine ADR fällt; ADR-21 bleibt.

## Risiken

- **Rechtsaussage ohne Beleg:** jede Aussage hat eine Belegzeile (AC-2, AC-5). Der Text ist der Entwurf eines Tech Leads, keine Rechtsberatung; Hennings Freigabe liegt darauf.
- **Text läuft dem Code hinterher:** ändert sich das Verhalten (Abmelden löscht, andere Drossel, weitere Inhalte), ist der Text erneut zu ändern; das Skript prüft nur die Sätze, nicht die Wahrheit.
- **Website und Entwurf laufen auseinander:** Gegenmittel AC-10 bis AC-12.
- **Wortlaut-Änderung nach Freigabe:** korrigiert Henning den Wortlaut, wird die Spec geändert und erneut freigegeben, bevor der Entwurf angefasst wird. Der Wortlaut geht nie nur auf die Auto-Ampel live.

## Out of Scope

- Löschen des Tokens beim Abmelden (Alternative B).
- Store-Schalter `LEAccountEnabled` und Einreichung (zweiter Teil von #625).
- Überholter Kommentar in `DeviceRegistration.swift` (Folgearbeit im Epic #795).

## Definition of Done

- [ ] AC-1 bis AC-13 erfüllt, Belege im Belegordner
- [ ] Wortlaut von Henning freigegeben (Spec-Freigabe), Datum im Entwurf vermerkt
- [ ] PR in `loose-ends` (`Refs #625`) und PR in `henemm-website` gemergt, CI grün; beide Seiten live (200)
- [ ] #625 kommentiert (Stand Schnitt 4), Board-Karte aktuell, Memory geschrieben

Keine Gerätepunkte („Kein Pfad der Geräteliste berührt.“).

## Changelog

- 2026-11-21: Initial spec created (Schnitt 4 von #625, Datenschutztext: Weckruf/Push-Token)

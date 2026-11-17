---
entity_id: feat-625-schnitt-1-datenschutztext
type: feature
created: 2026-11-17
updated: 2026-11-17
status: draft
workflow: feat-625-store-datenschutz
---

# Spec: Datenschutztext um Abschrift und Geräte-Kennung ergänzen, Schnitt 1 (#625)

## Approval

- [ ] Approved

## GitHub Issue

#625 (Store-Datenschutzangaben, Store-Schalter, Einreichung). Schnitt 1 von 4; das Issue bleibt offen (`Refs #625`, nie `Closes #625`).
Analyse: `docs/context/feat-625-store-datenschutz.md` (Abschnitt „Analysis“, Schnitt 1; PO-Entscheidung 2026-11-17: jetzt nur vorbereiten, Schalter und Einreichung erst, wenn #795, #796 und #624 geschlossen sind).
Vorbild in Aufbau und Strenge: `docs/specs/feat-615-schnitt-4e-datenschutz.md` (dort der Konto-Teil des Textes, hier der Nachtrag, den 4e ausdrücklich auf „mit #795“ verschoben hat).
Es ist ein reiner Textschnitt: **kein App-Code, kein Dienstcode, kein Pfad der Geräteliste.** Zwei Repos (`loose-ends`, `henemm/henemm-website`), je ein PR.

**Folgt in späteren Schnitten (nicht Teil dieser Spec):** Schnitt 2 Datenschutz-Manifest `LooseEnds/PrivacyInfo.xcprivacy` samt Test; Schnitt 3 Vorlage für den App-Store-Fragebogen; Schnitt 4 Auftragsverarbeitung mit Hetzner (Beleg); der Store-Schalter `LEAccountEnabled` und die Einreichung (zweiter Teil von #625, erst nach #795, #796, #624); der Absatz zum Weckruf (Push-Token) mit #795 S5c-2.

## Für den PO

Der Datenschutztext ist heute für alle, die in TestFlight mit Konto angemeldet sind, unvollständig: Die App schickt dem Dienst eine Abschrift deiner offenen Aufgaben, und das steht noch nirgends. Dieser Schnitt schreibt es in einfachen Worten in den Text, deutsch und englisch, und veröffentlicht ihn danach auf deiner Seite henemm.com.

Der Text sagt ehrlich, was in der Abschrift steht (Titel, Fälligkeit, Tags, Projekt und ein paar Markierungen) und was nicht (dein gesprochener oder getippter Text, Notizen, Anhänge, Orte, erledigte Aufgaben). Er sagt auch, dass der Titel aus deinem Text entsteht und dessen Anfang enthalten kann, weil das sonst wie eine Beschönigung wirken würde. Dazu steht im Text, dass die App eine zufällige Kennung dieser Installation mitschickt, wenn sie Aufträge von Claude abholt, und dass „Konto löschen“ die Abschrift mit entfernt.

Mit deiner Freigabe dieser Spezifikation gibst du den Wortlaut unten frei. Nichts davon ändert etwas in den Stores oder auf deinem Gerät, und der Schalter, der das Konto im Store sichtbar macht, bleibt aus. Was noch nicht im Text steht, ist der Weckruf, mit dem der Dienst die App aufwecken soll; die App sendet dafür heute noch nichts, der Text dazu kommt mit dem Schnitt, der es einbaut.

## Purpose

Der Datenschutztext (`docs/reference/datenschutz-entwurf.md`, Quelle; öffentlich `https://www.henemm.com/legal/loose-ends/privacy-policy/` de und `…/privacy-policy-en/` en) beschreibt seit #615 S4e den Konto-Teil, nennt aber die **Abschrift** der offenen Aufgaben nicht, die die App seit #795 S3b-1 an den Dienst sendet, sobald jemand angemeldet ist, und nicht die **Geräte-Kennung** (`X-Device`) für Aufträge. Die 4e-Spec hat beides bewusst ausgespart („kommt mit #795“). Weil beides in TestFlight-Bauten mit Konto schon läuft, muss der Text es nachziehen, unabhängig vom Store-Schalter.

**Ablauf (feste Reihenfolge):**

1. Wortlaut (unten) durch Henning freigeben lassen (Spec-Freigabe).
2. Prüfskript `scripts/test_datenschutz_text.py` umbauen, RED-Beleg gegen den unveränderten Entwurf.
3. Entwurf und `CLAUDE.md` ändern (DE + EN), Skript GREEN; PR in `loose-ends` (`Refs #625`).
4. Danach PR in `henemm-website` mit beiden Seiten; nach Merge und Auslieferung Live-Prüfung.

**Regeln vor Modell:** reiner Text, Textprüfung per Regex; die Zeile „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt ADR-21 fort (Dienst hält nur Abschrift und Aufträge; der Text beschreibt, was der Dienst hält) und die Beleg-Regel des Datenschutztextes; kein neues Verfahren, keine neue Abhängigkeit, kein Schema, kein Code.
- **Rationale:** Eine Seite für App und Dienst (Entscheidung #705), der Nachtrag steht im bestehenden Konto-Abschnitt. Jede Aussage hat einen Beleg im Code (Tabelle unten); was der Code nicht belegt, steht nicht im Text, sondern unter „Offen, nicht belegt“.

## Source

**Dateien (loose-ends):** `docs/reference/datenschutz-entwurf.md`, `scripts/test_datenschutz_text.py`, `CLAUDE.md` (ein Satz im Datenschutz-Absatz unter „Build“).
**Dateien (`henemm/henemm-website`, nur über `gh api` les- und änderbar, nicht lokal):** `content/legal/loose-ends/privacy-policy/_index.md`, `content/legal/loose-ends/privacy-policy-en/_index.md`.
**Nicht berührt:** `project.yml` (`LEAccountEnabled` bleibt `false`), `LooseEnds/Info.plist`, `LooseEnds/PrivacyInfo.xcprivacy` (Schnitt 2), `scripts/test_asc_what_to_test.py`, App- und Dienstcode, Store-Datenschutz-URL.

**Gegen den Code geprüft (Spec-Phase), Abweichungen vom Briefing und Stand der Fakten:**

- Die Abschrift enthält je Aufgabe genau: `id`, `title`, `status`, `dueDate`, `dueHasTime`, `contexts` (Tag-Namen, sortiert), `project` (Name), `nextRank`, `isKnaeuel` (`Shared/Services/TranscriptCodec.swift`, `Entry`); oben `version`, `generatedAt`, `nowCount`, `now` (Knäuel, heute, vorgemerkt, wartend, nur als Kennungen) und `views` (Fällig, Als nächstes, Lose Enden, nur Kennungen). Der Dienst weist jede andere Form ab (`server/src/transcripts.ts` `shape`, `privacy`; Datenbank-CHECKs in `server/migrations/001_claude_schema.sql` und `006_transcript_views.sql`).
- „Offen“ heißt: jede Aufgabe, die weder erledigt noch entfernt ist (`TranscriptCodec.transcript`: `status != .done && != .removed`), also **auch geparkte** und **Unterpunkte** (`TaskItem.parent`; der Codec filtert sie nicht). Das steht so im Text.
- Der **Titel** ist aus dem Rohtext abgeleitet (`TitleRule`: bereinigter Rohtext, höchstens 12 Wörter, `CLAUDE.md`). Der Rohtext selbst geht nicht mit, der Titel kann aber dessen Anfang enthalten. Der Text sagt das, statt „kein Rohtext“ allein zu behaupten.
- Die Gruppe „Tags“ heißt in der deutschen Oberfläche „Etiketten“ (`Localizable.xcstrings`, „Tags“ → „Etiketten“); der bestehende Datenschutztext sagt „Tags“, der Wortlaut bleibt dabei. „Als nächstes“ schreibt die Oberfläche klein.
- Auslöser: `ClaudeSyncTrigger` sendet bei Start und bei `didBecomeActive` (dann folgt das Abholen von Aufträgen), nach `ModelContext.didSave` und nach einem beendeten CloudKit-Import (beides 2 s entprellt). Es gibt keinen weiteren Auslöser; `wake()` (Weckruf) wird noch von niemandem gerufen. Gesendet wird **unabhängig davon, ob Claude schon verbunden ist**, sobald die Anmeldung besteht (`ClaudeSync.sendTranscript` über `AccountState.withSession`, ohne Sitzung nichts). Der Text sagt das.
- Der Dienst hält eine Zeile je Konto und überschreibt sie durch eine neuere (`server/src/transcripts.ts` `putTranscript`: `ON CONFLICT (account_id) DO UPDATE … WHERE older`; `transcripts.account_id` Primärschlüssel).
- **Abmelden lässt die Abschrift stehen:** `POST /auth/logout` ruft nur `endSession` (löscht die Sitzungszeile); `AccountState.signOut` leert nur den lokalen Speicher und ruft `logout`. Nach dem Abmelden sendet dieses Gerät nichts mehr (`withSession` ohne Sitzung gibt `nil`). Die zuletzt gesendete Abschrift bleibt beim Dienst bis zum Löschen des Kontos. Der Text sagt das.
- **Konto löschen** entfernt die Abschrift: `deleteAccount` löscht `order_results`, `orders`, `transcripts` und das Konto (`server/src/accounts.ts` Z. 116–124); `device_tokens` fällt per Kaskade (`008_device_tokens.sql`).
- **Geräte-Kennung:** `DeviceIdentity.current()` erzeugt einmal eine zufällige UUID (`UUID()`), legt sie im Schlüsselbund ab (`AfterFirstUnlockThisDeviceOnly`, kein Abgleich, eigener Eintrag `com.henning.looseends.device`) und liest sie danach nur. Sie geht als Kopfzeile `X-Device` an **Auftrag abholen** und **Ergebnis melden**, nicht an die Abschrift („`transcript` braucht kein Gerät“, `docs/reference/claude-abschrift-vertrag.md`; `ServiceClient` setzt `X-Device` nur in `claimOrder` und `putResult`). Der Dienst schreibt sie in `orders.claimed_by` (nur am Auftrag, den dieses Gerät übernimmt) und `order_results.reported_by`; ein Ergebnis nimmt er nur von dem Gerät, das den Auftrag hält (`server/src/orders.ts` `claimOrder`, `putResult`). Beides wird mit dem Konto gelöscht.
- **Abweichung vom Briefing 1:** Das Briefing nennt „Tags“; die App sagt „Etiketten“ (siehe oben, Wortlaut bleibt „Tags“ wie im übrigen Text).
- **Abweichung vom Briefing 2:** Auch geparkte Aufgaben und Unterpunkte sind in der Abschrift (siehe oben); das Briefing sprach nur von „offenen“.
- **Hinweis, kein Teil dieser Spec:** Die Kommentare „Nothing in the app calls it yet“ in `LooseEnds/Claude/DeviceIdentity.swift` und „Nothing in the app calls it yet (S3b)“ in `LooseEnds/Claude/ClaudeSync.swift` sind überholt (`ClaudeSyncTrigger.forApp` ruft beides, `LooseEndsApp` baut den Trigger). App-Code wird in diesem Schnitt nicht angefasst; es kommt in die Folgearbeit des Epics #795.

### Wortlaut (Entwurf, deutsch)

Die öffentliche Seite führt dieselben Änderungen an denselben Stellen; der Entwurf trägt zusätzlich die Beleg-Tabelle.

**Neuer Absatz im Abschnitt „Wenn du die Verbindung zu Claude nutzt“**, nach „Was unser Dienst speichert.“ und vor „Aufträge aus Claude.“:

> **Deine offenen Aufgaben für Claude.** Solange du angemeldet bist, schickt die App eine Abschrift deiner offenen Aufgaben an den Dienst, auch wenn du Claude noch nicht verbunden hast. Offen heißt: alle Aufgaben, die nicht erledigt sind, auch geparkte und Unterpunkte. Je Aufgabe sind das der Titel, der Status, die Fälligkeit, deine Tags, das Projekt, ihre Stellung unter „Als nächstes“ und ob sie das Knäuel ist. Dazu kommt, welche Aufgaben in „Jetzt“ stehen und in welcher Reihenfolge „Fällig“, „Als nächstes“ und „Lose Enden“ sie zeigen, nur als Kennungen. Außerdem steht darin, wann die Abschrift erstellt wurde. Der Titel entsteht aus deinem Text und kann dessen Anfang enthalten. Nicht dabei sind der Text, den du gesagt oder getippt hast (der Rohtext), deine Notizen, Anhänge, Orte, erledigte Aufgaben und der Verlauf der Änderungen. Die App sendet beim Start, wenn du zur App zurückkehrst und kurz nach Änderungen an deinen Aufgaben. Der Dienst behält nur die jeweils neueste Abschrift; jede neuere überschreibt die vorige. Sie dient dazu, dass Claude deine Aufgaben lesen kann, wenn du Claude verbindest. „Abmelden“ hält das Senden von diesem Gerät an; die zuletzt gesendete Abschrift bleibt beim Dienst, bis du dein Konto löschst.

**Neuer Absatz**, nach „Aufträge aus Claude.“:

> **Kennung dieser Installation.** Wenn die App Aufträge von Claude abholt und deren Ergebnis meldet, schickt sie eine zufällige Kennung dieser Installation mit. Die App erzeugt sie einmal selbst und legt sie im Schlüsselbund dieses Geräts ab; sie wird nicht über iCloud abgeglichen und ist kein Merkmal des Geräts wie Seriennummer oder Werbekennung. Der Dienst vermerkt sie an dem Auftrag, den dieses Gerät übernimmt, und am Ergebnis, damit ein Auftrag jeweils an ein Gerät geht und nur dieses das Ergebnis melden kann. Sie bleibt mit dem Auftrag gespeichert, bis du dein Konto löschst.

**Absatz „Löschen.“**, zweiter Satz geändert (ersetzt „Das entfernt dein Konto und alle Daten, die der Dienst zu diesem Konto gespeichert hat, und widerruft die Anmeldung bei Apple.“):

> Das entfernt dein Konto und alle Daten, die der Dienst zu diesem Konto gespeichert hat, darunter die Abschrift deiner Aufgaben, Aufträge und Ergebnisse, und widerruft die Anmeldung bei Apple.

Alle übrigen Absätze des Konto-Abschnitts, Kurzfassung, „Wo es liegt“ und der Löschsatz unter „Verantwortlicher und Kontakt“ bleiben unverändert.

### Wortlaut (Entwurf, englisch, wortgetreu)

Die Änderungen stehen im englischen Abschnitt „### 4. If you use the connection to Claude“; die Nummerierung ändert sich nicht. „Last updated“ wird auf das Veröffentlichungsdatum gesetzt.

**New paragraph**, after “What our service stores.” and before “Orders from Claude.”:

> **Your open tasks for Claude.** As long as you are signed in, the app sends a transcript of your open tasks to the service, even if you have not connected Claude yet. Open means: every task that is not completed, including parked tasks and subtasks. For each task this is the title, the status, the due date, your tags, the project, its position under "Next up" and whether it is the Tangle. In addition it says which tasks are in "Now" and in which order "Due", "Next up" and "All open" show them, as identifiers only. It also states when the transcript was created. The title is derived from your text and can contain its beginning. Not included are the text you said or typed (the raw text), your notes, attachments, places, completed tasks and the history of changes. The app sends at start, when you return to the app, and shortly after changes to your tasks. The service keeps only the newest transcript; each newer one overwrites the previous one. It exists so that Claude can read your tasks if you connect Claude. "Sign out" stops sending from this device; the transcript last sent stays with the service until you delete your account.

**New paragraph**, after “Orders from Claude.”:

> **Identifier of this installation.** When the app collects orders from Claude and reports their result, it sends a random identifier of this installation. The app creates it once itself and keeps it in this device's keychain; it is not synced through iCloud and is not a feature of the device such as a serial number or an advertising identifier. The service notes it on the order this device takes over and on the result, so that an order goes to one device at a time and only that device can report the result. It stays stored with the order until you delete your account.

**Paragraph “Deleting.”**, second sentence changed (replaces “This removes your account and all data the service has stored for that account, and revokes the sign-in with Apple.”):

> This removes your account and all data the service has stored for that account, including the transcript of your tasks, orders and results, and revokes the sign-in with Apple.

Die Bezeichnungen „Next up“, „Now“, „Due“, „All open“, „Tangle“ (en) und „Als nächstes“, „Jetzt“, „Fällig“, „Lose Enden“, „Knäuel“ (de) sind gegen `LooseEnds/Resources/Localizable.xcstrings` und `CLAUDE.md` („Knäuel“ = „the Tangle“ in der englischen Oberfläche, #758) gelesen.

### Beleg-Tabelle (kommt in den Entwurf unter „Beleg im Code“, nach der Zeile „Aufträge aus Claude …“)

| Aussage | Beleg |
|---|---|
| Abschrift offener Aufgaben, genau diese Felder; sonst nichts | `Shared/Services/TranscriptCodec.swift` (`Transcript`, `Entry`); `docs/reference/claude-abschrift-vertrag.md` (Abschnitt „Abschrift“: „keinen Rohtext, keine Notiz, keine Anhänge und keine Revisionen“); `server/src/transcripts.ts` (`shape` nimmt nur diese Schlüssel, `privacy` weist `rawText` und `note` ab); `server/migrations/001_claude_schema.sql` und `006_transcript_views.sql` (CHECK auf erlaubte Schlüssel) |
| „Offen“ = nicht erledigt, auch geparkt und Unterpunkte | `TranscriptCodec.transcript` (`status != .done && != .removed`), `server/src/transcripts.ts` (`statuses`: unprocessed, unverified, active, parked) |
| Titel entsteht aus dem Rohtext | `Shared/Services/TitleRule.swift` (bereinigter Rohtext, höchstens 12 Wörter, #202) |
| Senden nur mit Anmeldung, auch ohne verbundenes Claude | `LooseEnds/Claude/ClaudeSync.swift` (`sendTranscript` über `AccountState.withSession`, ohne Sitzung `notSignedIn`); `LooseEnds/Claude/ClaudeSyncTrigger.swift` (`forApp` nur mit Konto) |
| Auslöser: Start, Rückkehr, nach Änderungen | `LooseEnds/Claude/ClaudeSyncTrigger.swift` (`start`: `didBecomeActive`, `ModelContext.didSave`, CloudKit-Import, 2 s Entprellung); `LooseEnds/App/LooseEndsApp.swift` (`ClaudeSyncTrigger.forApp`) |
| Dienst hält nur die neueste Abschrift je Konto | `server/migrations/001_claude_schema.sql` (`transcripts`, `account_id` Primärschlüssel, keine Historie); `server/src/transcripts.ts` (`putTranscript`) |
| Zweck: Claude liest die Abschrift | `server/src/mcp.ts` (Lesewerkzeuge `get_now`, `list_tasks`, `get_view` über `getTranscript`); `server/src/anleitung.ts` |
| Abmelden lässt die Abschrift stehen | `server/src/auth.ts` (`POST /auth/logout` ruft nur `endSession`), `server/src/accounts.ts` (`endSession` löscht nur die Sitzungszeile); `LooseEnds/Claude/AccountState.swift` (`signOut`) |
| „Konto löschen“ entfernt die Abschrift | `server/src/accounts.ts` (`deleteAccount`: `DELETE FROM transcripts WHERE account_id`) |
| Zufällige Kennung dieser Installation, nur dieses Gerät, kein Hardware-Merkmal | `LooseEnds/Claude/DeviceIdentity.swift` (`UUID()`, Schlüsselbund, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, kein `kSecAttrSynchronizable`) |
| Kennung geht an Auftrag abholen und Ergebnis melden, nicht an die Abschrift | `LooseEnds/Claude/ServiceClient.swift` (`X-Device` in `claimOrder`, `putResult`); `LooseEnds/Claude/ClaudeSync.swift` (`pullOrders`); `docs/reference/claude-abschrift-vertrag.md` („`transcript` braucht kein Gerät“) |
| Dienst vermerkt sie an Auftrag und Ergebnis, ein Gerät zur Zeit | `server/src/orders.ts` (`claimOrder` setzt `claimed_by`, `putResult` nur vom haltenden Gerät), `server/migrations/001_claude_schema.sql` (`orders.claimed_by`, `order_results.reported_by`) |
| Auftrag, Ergebnis und Kennung werden mit dem Konto gelöscht | `server/src/accounts.ts` (`deleteAccount` löscht `order_results`, `orders`) |

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `docs/specs/feat-615-schnitt-4e-datenschutz.md` und der dort veröffentlichte Konto-Teil (Website-PR henemm/henemm-website#79) | Voraussetzung, besteht |
| #795 S3a/S3b-1 (Abschrift senden, Trigger), S2b (`DeviceIdentity`) | belegen, was die App sendet; bestehen |
| Website-Repo `henemm/henemm-website`, Seiten `privacy-policy` und `privacy-policy-en` | zweiter PR, über `gh api` |
| `scripts/test_datenschutz_text.py`, CI-Befehl `python -m unittest discover -s scripts -p 'test_*.py'` | wird geändert |
| #795 S5c-2 (Weckruf in der App) | nur als Verweis unter „Offen, nicht belegt“; Text folgt dort |
| Downstream | Schnitte 2 bis 4 von #625, Store-Schalter |

## Acceptance Criteria

Belege liegen unter `docs/artifacts/feat-625-store-datenschutz/schnitt-1/` („Belegordner“). Kein Beleg enthält Zugangsdaten, `sub`-Werte, Tokens oder IP-Adressen von Nutzern.

- **AC-1:** GIVEN `docs/reference/datenschutz-entwurf.md` WHEN der deutsche Abschnitt „Wenn du die Verbindung zu Claude nutzt“ gelesen wird THEN steht der Absatz „Deine offenen Aufgaben für Claude.“ nach „Was unser Dienst speichert.“ und vor „Aufträge aus Claude.“ im oben freigegebenen Wortlaut, und er enthält die Aussagen: Abschrift der offenen Aufgaben, Senden nur bei Anmeldung (auch ohne verbundenes Claude), die genannten Felder, der Titel kann den Anfang des Textes enthalten, nicht dabei Rohtext, Notizen, Anhänge, Orte, erledigte Aufgaben und Änderungsverlauf, Auslöser Start, Rückkehr und Änderungen, nur die neueste Abschrift wird behalten, Zweck Claude, Abmelden lässt die Abschrift stehen.
- **AC-2:** GIVEN der Absatz aus AC-1 WHEN er mit `Shared/Services/TranscriptCodec.swift` (`Entry`, `Transcript`) und `server/src/transcripts.ts` (`shape`, `privacy`) verglichen wird THEN nennt er kein Feld, das dort fehlt, und verschweigt keines, das dort steht; die Aussage „nicht dabei: Text, Notizen, Anhänge, Orte, erledigte Aufgaben, Verlauf“ hat im Code jeweils keinen Gegenbeleg (Beleg `aussagen.txt`: je Aussage Datei und Fundstelle).
- **AC-3:** GIVEN der Entwurf WHEN der Absatz „Kennung dieser Installation.“ gelesen wird THEN steht er nach „Aufträge aus Claude.“ im freigegebenen Wortlaut und nennt: zufällige Kennung, einmal von der App erzeugt, im Schlüsselbund dieses Geräts, nicht über iCloud abgeglichen, kein Hardware-Merkmal, mitgeschickt beim Abholen von Aufträgen und Melden des Ergebnisses, vom Dienst an Auftrag und Ergebnis vermerkt, bleibt bis zur Kontolöschung.
- **AC-4:** GIVEN der Absatz „Löschen.“ im Entwurf WHEN er gelesen wird THEN nennt er, dass „Konto löschen“ auch die Abschrift der Aufgaben, Aufträge und Ergebnisse entfernt (Wortlaut oben), und alle übrigen Sätze des Absatzes („Konto löschen“, „Vorhandene Sicherungen laufen innerhalb von 30 Tagen aus“, „Abmelden“) sind unverändert.
- **AC-5:** GIVEN der Abschnitt „English“ im Entwurf WHEN er mit dem deutschen verglichen wird THEN enthält Abschnitt 4 die zwei neuen Absätze und den geänderten Löschsatz im oben angegebenen englischen Wortlaut, ohne Zusätze und Kürzungen und ohne die Nummerierung zu ändern; die Statuszeile des englischen Abschnitts nennt die Freigabe des Nachtrags und die Veröffentlichung; „Last updated“ trägt das Veröffentlichungsdatum.
- **AC-6:** GIVEN der Entwurf WHEN „Beleg im Code“ gelesen wird THEN stehen nach der Zeile „Aufträge aus Claude …“ die dreizehn Zeilen der Beleg-Tabelle oben (Felder, offen = nicht erledigt, Titel aus Rohtext, Senden nur mit Anmeldung, Auslöser, nur neueste, Zweck, Abmelden, Löschen, Kennung, Kennung nur bei Aufträgen, Vermerk am Auftrag, Löschung mit dem Konto), und jede Dateiangabe nennt eine Datei, die im Repo existiert (Beleg `belege-pfade.txt`: Pfadliste mit Existenzprüfung).
- **AC-7:** GIVEN der Entwurf WHEN „Offen, nicht belegt“ und der Statuskopf gelesen werden THEN ist der Punkt „Aufgabenübertragung zum Dienst: nicht beschrieben, weil sie nicht gebaut ist …“ ersetzt durch einen Punkt „Weckruf (Push-Token)“: der Dienst kann je Gerät einen Push-Token speichern (Migration 008, `server/src/devices.ts`), die App hat den Kern (`DeviceRegistration`), ruft ihn aber noch nicht auf, im Text nicht beschrieben, der Absatz dazu kommt mit #795 S5c-2 und ändert Text und Seite erneut; der Statuskopf nennt die Freigabe des Nachtrags (Datum der Spec-Freigabe, beim Umsetzen eingetragen) und die Veröffentlichung (Datum und Website-PR, nach dem Merge eingetragen).
- **AC-8:** GIVEN `scripts/test_datenschutz_text.py` (weiterhin ein `unittest.TestCase`) WHEN der CI-Befehl `python -m unittest discover -s scripts -p 'test_*.py'` läuft THEN ist es grün, und das Verbot `test_no_transcript_in_account_section` ist umgedreht: der Konto-Abschnitt muss je Sprache die Abschrift nennen (de „Abschrift“, en „transcript“) und die Negativ-Aussagen enthalten (de „Rohtext“ und „Notizen“, en „raw text“ und „notes“); die neuen Kernsätze beider Absätze und des Löschsatzes stehen als wörtliche Anker in `ANCHORS` (und damit auch in der Live-Prüfung), und `STALE` enthält zusätzlich „weil sie nicht gebaut ist“, damit der überholte „Offen“-Punkt nicht zurückkehrt.
- **AC-9:** GIVEN das umgebaute Prüfskript und der unveränderte Entwurf WHEN es läuft THEN ist es rot, und der Beleg `red.txt` zeigt die fehlenden Aussagen (Abschrift im Konto-Abschnitt de und en, „Rohtext“/„raw text“, die neuen Anker, den vorhandenen „nicht gebaut“-Punkt); nach der Änderung des Entwurfs zeigt `green.txt` den grünen Lauf des CI-Befehls.
- **AC-10:** GIVEN die Gegenprobe-Tests in `CheckerTests` WHEN sie laufen THEN sind sie grün und belegen: ein Konto-Abschnitt ohne „Abschrift“ wird als unvollständig gefangen, einer mit „Abschrift“ aber ohne „Rohtext“ ebenfalls, einer mit beidem nicht, und der Satz „weil sie nicht gebaut ist“ wird als veraltet gefangen; der bisherige Test `test_transcript_found_in_section` bleibt als Hilfsprobe der Abschnittssuche erhalten.
- **AC-11:** GIVEN `CLAUDE.md` WHEN der Datenschutz-Absatz unter „Build“ gelesen wird THEN nennt er zusätzlich, dass der Text seit dem Veröffentlichungsdatum die Abschrift der offenen Aufgaben und die Kennung dieser Installation beschreibt (Verweis auf diese Spec), dass der Weckruf-Absatz mit #795 S5c-2 folgt und `LEAccountEnabled` bis #625 aus bleibt; die übrigen Sätze des Absatzes bleiben unverändert (Diff).
- **AC-12:** GIVEN die Freigabe des Wortlauts und der gemergte `loose-ends`-PR WHEN der PR im Repo `henemm/henemm-website` die Seiten `content/legal/loose-ends/privacy-policy/_index.md` und `…/privacy-policy-en/_index.md` ändert THEN enthalten beide die Änderungen aus AC-1, AC-3, AC-4 bzw. AC-5 im freigegebenen Wortlaut, das Datum „Stand“ bzw. „Last updated“ ist das Veröffentlichungsdatum, und die Seiten enthalten nicht die Abschnitte „Beleg im Code“ und „Offen, nicht belegt“; erst danach wird der Website-PR gemergt.
- **AC-13:** GIVEN der gemergte und ausgelieferte Website-PR WHEN `curl -sS -o seite.html -w '%{http_code}'` die URLs `https://www.henemm.com/legal/loose-ends/privacy-policy/` und `https://www.henemm.com/legal/loose-ends/privacy-policy-en/` abruft THEN ist der Code je 200, und das Prüfskript (Aufruf mit `DATENSCHUTZ_LIVE=1`) ist grün: Kernaussagen, alle Anker aus AC-8, Abschnittstitel, keine veralteten Sätze, keine internen Abschnitte; Beleg `live.txt` mit Codes und Treffern. Die bei Apple gesetzte Datenschutz-URL bleibt unverändert (Repo-Variable `ASC_PRIVACY_POLICY_URL` und `PRIVACY_URL_EN` ohne Diff).
- **AC-14:** GIVEN die veröffentlichten Seiten (beide Sprachen) und der Entwurf WHEN die Abschnitte verglichen werden THEN stimmen die Kernsätze der neuen und geänderten Absätze nach Normalisierung der Anführungszeichen wörtlich überein (Beleg `vergleich.txt`).
- **AC-15:** GIVEN der Diff beider PRs WHEN er geprüft wird THEN enthält er weder `project.yml` noch `LooseEnds/Info.plist` noch `LooseEnds/PrivacyInfo.xcprivacy` noch `scripts/test_asc_what_to_test.py` noch Dateien unter `LooseEnds/`, `Shared/`, `server/`, und `LEAccountEnabled` ist in `project.yml` weiterhin `false` (Beleg `schalter.txt`: Diff-Dateiliste und Zeile aus `project.yml`).
- **AC-16:** GIVEN der Schnitt ändert nur `docs/`, `scripts/`, `CLAUDE.md` und das Website-Repo WHEN die Abnahme begründet wird THEN lautet der Satz im Bericht „Kein Pfad der Geräteliste berührt. Reiner Text, keine App-Änderung; Stufe 2 an den Live-Seiten belegt.“, und Stufe 2 ist das Öffnen beider Live-Seiten im Browser samt Screenshot je Sprache (`live-de.png`, `live-en.png`), geöffnet und beschrieben. Es gibt keinen App-Lauf und nichts auf Hennings Geräten.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/reference/datenschutz-entwurf.md` | MODIFY | zwei neue Absätze und geänderter Löschsatz (DE, EN), 13 Beleg-Zeilen, „Offen“-Punkt ersetzt, Statuskopf DE und EN; ≈ +62/−6 |
| `scripts/test_datenschutz_text.py` | MODIFY | Verbot umgedreht, neue Anker, `STALE` erweitert, drei Gegenproben; ≈ +34/−10 |
| `CLAUDE.md` | MODIFY | Datenschutz-Absatz unter „Build“: Abschrift und Kennung im Text, Weckruf folgt; ≈ +2/−1 |
| `henemm-website: content/legal/loose-ends/privacy-policy/_index.md` | MODIFY | öffentliche deutsche Fassung, zweiter PR; ≈ +11/−3 |
| `henemm-website: content/legal/loose-ends/privacy-policy-en/_index.md` | MODIFY | öffentliche englische Fassung, zweiter PR; ≈ +11/−3 |
| `docs/artifacts/feat-625-store-datenschutz/schnitt-1/` | CREATE | Belege (Text, zwei Bilder); zählt nicht zum Dateilimit |

### Estimated Changes

- **Dateien: 5 Pfade**, davon 2 im zweiten Repo (`henemm-website`, eigener PR), 3 in `loose-ends`; der Belegordner zählt nicht mit (wie in 4e). Am Rand des Limits von 4 bis 5.
- **LoC: ≈ +120/−23, zusammen ≈ 145**, davon rund 75 Prozent Rechtstext in zwei Sprachen und zwei Repos. Innerhalb von ±250 LoC.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, kein `generate`, keine Migration, keine neue Abhängigkeit, kein App- oder Dienstcode.
- **Seiteneffekte nach außen (explizit):** Zwei öffentliche Rechtsseiten ändern ihren Inhalt; sonst keine.
- **Parallele Arbeit:** vor jedem PR `origin/main` und offene PRs in beiden Repos erneut prüfen; `CLAUDE.md` und der Entwurf sind Hotspots (der Weckruf-Absatz aus #795 S5c-2 und die Datenschutzangaben aus #625 Schnitt 2 berühren denselben Text).

## Risiken

- **Rechtsaussage ohne Beleg.** Jede Aussage hat eine Zeile in der Beleg-Tabelle, AC-2 und AC-6 prüfen sie gegen den Code. Was nicht belegbar ist, steht unter „Offen“ (Weckruf) oder gar nicht im Text. Rechtlich ist der Text der Entwurf eines Tech Leads, keine Rechtsberatung; Hennings Freigabe liegt darauf.
- **Titel und Rohtext.** „Kein Rohtext“ allein wäre irreführend, weil der Titel aus dem Rohtext entsteht (bis zu 12 Wörter). Der Text sagt es offen; ein Nutzer, der das nicht will, nutzt die Verbindung nicht (Freiwilligkeit steht im Abschnitt).
- **Text läuft der App voraus oder hinterher.** Sendet die App künftig mehr (Version 2 der Abschrift, Weckruf), ist der Text wieder zu ergänzen; das Prüfskript zwingt dazu nicht, nur Review und die Beleg-Regel. Gegenmittel: der Weckruf ist als „Offen“ vermerkt.
- **Website und Entwurf laufen auseinander.** Gegenmittel AC-12 bis AC-14.
- **Schalter.** Der Text beschreibt Funktionen, die nur TestFlight-Bauten mit Konto zeigen; das ist gewollt (4e). Gegenmittel AC-15.
- **Wortlaut-Änderung nach Freigabe.** Korrigiert Henning den Wortlaut, wird die Spec geändert und erneut freigegeben, bevor der Entwurf angefasst wird.

## Test Plan

### Automated Tests (TDD RED)

Kein App- oder Dienstcode, also keine Unit- oder UI-Tests der App. Geprüft wird der Text maschinell mit dem Prüfskript, `unittest`, CI-Befehl `python -m unittest discover -s scripts -p 'test_*.py'`.

- [ ] Test 1 (AC-8, AC-9): GIVEN der unveränderte Entwurf WHEN `scripts/test_datenschutz_text.py` läuft THEN ist es rot (fehlende Abschrift im Konto-Abschnitt de und en, fehlende neue Anker, vorhandener Satz „weil sie nicht gebaut ist“); GIVEN der geänderte Entwurf THEN grün.
- [ ] Test 2 (AC-10): GIVEN ein Konto-Abschnitt ohne „Abschrift“ WHEN die Prüfung läuft THEN meldet sie „Abschrift“ als fehlend; GIVEN einer mit „Abschrift“, aber ohne „Rohtext“ THEN meldet sie „Rohtext“ als fehlend; GIVEN einer mit beidem THEN meldet sie nichts.
- [ ] Test 3 (AC-10): GIVEN der Satz „Offen: weil sie nicht gebaut ist“ WHEN `stale_phrases` läuft THEN wird er gefangen (Gegenprobe, dass der überholte Punkt nicht zurückkehrt).
- [ ] Test 4 (AC-13): GIVEN die ausgelieferten Seiten WHEN das Skript mit `DATENSCHUTZ_LIVE=1` läuft THEN ist es grün; ohne die Umgebungsvariable werden die Live-Tests übersprungen und im Beleg einzeln benannt.

| Prüfung | Beleg | AC |
|---|---|---|
| Prüfskript rot vor, grün nach der Änderung | `red.txt`, `green.txt`, CI | AC-8, AC-9, AC-10 |
| Aussagen gegen Code | `aussagen.txt` | AC-2 |
| Pfade der Beleg-Tabelle existieren | `belege-pfade.txt` | AC-6 |
| `CLAUDE.md` | Diff | AC-11 |
| Live-Seiten (curl, Skript mit `DATENSCHUTZ_LIVE=1`), Sichtprüfung | `live.txt`, `live-de.png`, `live-en.png` | AC-13, AC-16 |
| Vergleich Entwurf und Seiten | `vergleich.txt` | AC-12, AC-14 |
| Dateiliste der PRs, Schalter | `schalter.txt` | AC-15 |

**Ehrlich zur Belegkraft:** Das Skript belegt, dass der Text die Kernsätze enthält und die veralteten nicht; ob die Aussagen wahr sind, belegen die Beleg-Tabelle und `aussagen.txt` gegen den Code. Eine rechtliche Prüfung ersetzt keines von beiden.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): Nachtrag jetzt in den bestehenden Konto-Abschnitt, unabhängig vom Schalter** | siehe Purpose | schließt die Lücke für TestFlight-Bauten mit Konto sofort; eine Seite bleibt eine; Freigabe nur über den Wortlaut | zwei Freigaberunden insgesamt, weil der Weckruf später noch einmal Text braucht | — |
| **B Text erst mit dem Store-Schalter ändern** | Nachtrag zusammen mit `LEAccountEnabled` und Datenschutzangaben | eine Freigabe, ein Veröffentlichungstermin | der Text bleibt für Konto-Bauten in TestFlight falsch, solange der Schalter aus ist; verletzt die Beleg-Regel („Text sagt, was der Code tut“); kein Grund zu warten, da der Wortlaut feststeht | die 4e-Entscheidung, dass der Text unabhängig vom Schalter korrekt sein muss |
| **C Weckruf-Token gleich mitnehmen** | ein Absatz zu `device_tokens` und Push-Token schon jetzt | eine Freigaberunde weniger | die App sendet den Token noch nicht (`DeviceRegistration` ungerufen); der Absatz beschriebe etwas, das nicht läuft, und bricht die Beleg-Regel; der Wortlaut hängt an der Gestaltung in #795 S5c-2 | die Regel „nur Belegtes“; verworfen |
| **D Nur „Abschrift ohne Rohtext“, Titel nicht erwähnen** | kürzerer Absatz | liest sich glatter | der Titel enthält den Textanfang; ein Text, der „kein Rohtext“ sagt und das verschweigt, wäre irreführend | die Beleg-Regel; verworfen |

Keine ADR fällt; ADR-21 bleibt.

## Out of Scope / Folgeschnitte

- **#625 Schnitt 2:** `LooseEnds/PrivacyInfo.xcprivacy` (User ID, Device ID, Other User Content) und `scripts/test_privacy_manifest.py`.
- **#625 Schnitt 3:** `docs/reference/app-store-datenschutzangaben.md` (Vorlage für den App-Store-Fragebogen); das Eintragen in App Store Connect erst mit der Version, die den Schalter an hat.
- **#625 Schnitt 4:** Auftragsverarbeitung mit Hetzner (Beleg).
- **#625 zweiter Teil:** Store-Schalter `LEAccountEnabled`, Einreichung, erst nach #795, #796, #624.
- **#795 S5c-2:** Weckruf-Absatz (Push-Token) im Text; der „Offen“-Punkt in diesem Schnitt trägt den Vermerk.
- Überholte Kommentare in `DeviceIdentity.swift` und `ClaudeSync.swift`: Folgearbeit im Epic #795, kein App-Code in diesem Schnitt.

## Definition of Done

- [ ] AC-1 bis AC-16 erfüllt, Belege im Belegordner
- [ ] Wortlaut von Henning freigegeben (Spec-Freigabe), Datum im Entwurf vermerkt
- [ ] PR in `loose-ends` (Entwurf, Prüfskript, `CLAUDE.md`, `Refs #625`) und PR in `henemm-website` gemergt, CI grün; beide Seiten live (200)
- [ ] #625 kommentiert (Stand Schnitt 1, Folgen Schnitt 2 bis 4 und Schalter), Board-Karte aktuell, Memory geschrieben

Keine Gerätepunkte (Stufe 3 greift nicht).

## Changelog

- 2026-11-17: Initial spec created (Schnitt 1 von #625, Datenschutztext: Abschrift und Kennung der Installation)
- 2026-11-17: Englischer Wortlaut korrigiert: die Liste heißt in der englischen Oberfläche „All open“ (`Shared/Models/Enums.swift`, `.open`; „Lose Enden“ nur de), nicht „Loose ends“ (dort eine Einstellungsgruppe). Befund aus Phase 6, Sachkorrektur ohne Änderung der Aussage.
- 2026-11-17: Henning gibt den Wortlaut frei (AskUserQuestion in /60-validate) und lässt den Zeitpunkt der Abschrift (`generatedAt`, Befund zu AC-2) ergänzen: DE „Außerdem steht darin, wann die Abschrift erstellt wurde.“, EN “It also states when the transcript was created.”; Entwurf und beide Website-Seiten werden erneut angepasst.

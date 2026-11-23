---
entity_id: feat-625-schnitt-5a-offene-tuer
type: feature
created: 2026-11-22
updated: 2026-11-22
status: draft
workflow: feat-625-konto-schalter
---

# Spec: Die offene Tür mit Tagesgrenze, Server (Schnitt 5a, #625)

## Approval

- [ ] Approved

## GitHub Issue

#625 (Store-Schalter, Einreichung). Schnitt 5a; das Issue bleibt offen (`Refs #625`, nie `Closes #625`).
Analyse: `docs/context/feat-625-konto-schalter.md`, Abschnitte „Analysis“ und „PO-Entscheidung 2026-11-22“.
Vorgänger: `docs/specs/feat-621-schnitt-6a-tuer.md` (baute `admit` mit Liste und „erstes Konto“; dort steht „die Regel geht mit #625“).

**Nicht in diesem Schnitt (Folgeschnitte von #625):**

- **S5b:** Schalter an der Quelle (`LEAccountEnabled` in `project.yml`, `Info.plist`, `PrivacyInfo.xcprivacy`).
- **S5c:** Konto-Mechanik in CI und Skripten zurückbauen (Eingang `konto`, Marke „KONTO-BAU“, Store-Sperre markierter Bauten).
- **S5d:** Store: datiertes Ja zur Fragebogen-Vorlage, Etikett im ASC-Web, Version, Texte, Review-Notizen, Einreichen. **Auch das Umstellen der Betriebs-Umgebung auf „offen“ (`ALLOWED_APPLE_SUBS=*`) gehört zu S5d**, nicht hierher.

## Für den PO

Apples Prüfer meldet sich mit seiner eigenen Apple-ID an. Heute weist der Dienst jede fremde Apple-ID ab; der Prüfer sähe „nicht freigeschaltet“ und lehnte die App ab. Du hast am 2026-11-22 entschieden: Der Dienst steht jedem mit einem Apple-Konto offen, mit einer Grenze für neue Konten je Tag. Dieser Schnitt baut die Tür dafür im Dienst.

Was sich ändert: Der Dienst kann künftig „offen“ laufen. Dann bekommt jede Apple-ID ein Konto, aber es entstehen höchstens 20 neue Konten innerhalb von 24 Stunden (der Wert ist eine Einstellung am Server, kein Code). Wer schon ein Konto hat, kommt immer herein, auch wenn die Grenze erreicht ist. Ist sie erreicht, sieht ein neuer Nutzer dasselbe wie heute bei einer Abweisung.

Was sich jetzt nicht ändert: Der Dienst wird mit seiner bisherigen Einstellung ausgerollt, die Tür bleibt also zu und nur dein Konto kommt herein. Geöffnet wird erst im Store-Schnitt, kurz vor dem Einreichen. Auf deinen Geräten und in der App ändert sich nichts, du musst nichts entscheiden.

## Purpose

`admit(pool, appleSub, allowed?)` in `server/src/accounts.ts` kennt heute zwei Zweige: eine Liste (`ALLOWED_APPLE_SUBS`) oder „nur das erste Konto“. Es gibt keinen offenen Modus. Der Schnitt ergänzt einen dritten Zweig, **offen mit Tagesgrenze neuer Konten**, und die Umgebungsregel, die ihn einschaltet. Die Grenze ist ein Betriebswert (`NEW_ACCOUNTS_PER_DAY`, Vorgabe 20), keine Konstante im Code. Bestandskonten werden nie von der Grenze abgewiesen. Liste und „erstes Konto“ bleiben wie heute, damit der Rollout mit unveränderter Betriebs-Umgebung nichts am Verhalten ändert.

**Regeln vor Modell:** Datenbank- und Zugangsregel ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** ADR-21 (Ergänzung, keine neue Nummer)
- **Rationale:** `docs/project/00-entscheidungen.md` führt die Tür unter ADR-21 („Claude bekommt ein Fenster …“, dort die Passage, dass vor einem externen Nutzer die Regeln zu ändern sind, #625); S6a hat sie als Liste umgesetzt und die Regel „geht mit #625“ vermerkt. Die PO-Entscheidung vom 2026-11-22 (offen mit Tagesgrenze) ändert nur die Zugangsregel, nicht die Datenhaltung. Der Ergänzungs-Absatz in ADR-21 wird im Zuge der Umsetzung nachgezogen (eine Zeile in `docs/project/00-entscheidungen.md`, zählt nicht als Produktdatei).

## Source

**Dateien (Produkt, 4):** `server/src/accounts.ts`, `server/src/main.ts`, `server/src/auth.ts`, `server/src/oauth-return.ts`.
**Identifier:** `admit`, `Door` (neu), `admitOpen` (neu), `doorFromEnv` (neu, ersetzt `allowedSubsFromEnv`), `allowedSubsOrExit` in `main.ts`, `AuthDeps.allowedSubs`, `AppleReturnDeps.allowedSubs`, `StartOptions.auth.allowedSubs`.

### Schnittstelle

- **Typ** `export type Door = ReadonlySet<string> | { open: true; perDay: number };`
- **`admit(pool, appleSub, door?: Door)`:** Set → Verhalten wie heute (Liste ist die Wahrheit, auch für Vorhandene); `undefined` → wie heute `admitFirst`; `{ open: true, perDay }` → `admitOpen`.
- **`admitOpen`:** eine Transaktion unter `pg_advisory_xact_lock(ACCOUNT_LOCK_ID)` (derselbe Schlüssel wie `admitFirst`). Ist die `sub` schon vorhanden, wird ihr Konto zurückgegeben, auch über der Grenze. Sonst zählt `SELECT count(*)::int FROM accounts WHERE created_at > now() - interval '24 hours'` (Datenbankzeit, gleitendes Fenster); bei Zähler `< perDay` wird angelegt (`INSERT … RETURNING id`), sonst `ROLLBACK` und `null`, nichts geschrieben. Jeder Fehler: `ROLLBACK`, Client freigeben, Wurf weiter. Jede Funktion höchstens 50 Zeilen.
- **Ein gelöschtes Konto zählt nicht mehr** (seine Zeile ist weg, `deleteAccount` entfernt sie). Das ist akzeptiert: Wer anlegt und löscht, kann das Fenster nicht über das Löschen hinaus belasten, und die Grenze ist ein Mindestschutz, kein Zähler für Abrechnung. So in der Code-Kommentarzeile und in `CLAUDE.md` vermerkt.
- **`doorFromEnv(env): Door | undefined`** ersetzt `allowedSubsFromEnv` (Aufrufer: `main.ts` und die Tests):
  - `ALLOWED_APPLE_SUBS` fehlt oder ist nur Leerraum → `undefined` (Zweig „erstes Konto“), außer `NEW_ACCOUNTS_PER_DAY` ist gesetzt (dann Fehler, siehe unten).
  - genau `*` (getrimmt) → `{ open: true, perDay }` mit `perDay` aus `NEW_ACCOUNTS_PER_DAY`: fehlt oder leer → 20; sonst nur Ziffern, Ganzzahl von 1 bis 10000, sonst Fehler `NEW_ACCOUNTS_PER_DAY`.
  - `*` zusammen mit anderen Einträgen (`*,a`, `a,*`) → Fehler `ALLOWED_APPLE_SUBS`.
  - sonst Liste wie heute (Komma-getrennt, getrimmt, leere Einträge verboten, Fehler `ALLOWED_APPLE_SUBS`).
  - `NEW_ACCOUNTS_PER_DAY` gesetzt (nicht leer) ohne `*` → Fehler `NEW_ACCOUNTS_PER_DAY` (verhindert falsches Vertrauen: wer eine Grenze einträgt, aber keine offene Tür hat, soll es merken).
  - Jeder Fehler nennt nur den Variablennamen, nie den Wert.
- **`main.ts`:** der Start liest `doorFromEnv(process.env)`; bei Wurf schreibt er `door invalid: <VARIABLE>` (der Name aus der Fehlermeldung) und beendet sich mit Exit 1 vor Pool und Port. Die Meldung ersetzt `allowed subs invalid: ALLOWED_APPLE_SUBS`; `server/test/main.test.ts` (Test „start: ungueltige ALLOWED_APPLE_SUBS stoppt vor pool und port …“, Zeile 559) prüft die alte Zeichenkette und wird angepasst.
- **`auth.ts`, `oauth-return.ts`:** der Typ von `allowedSubs` wird `Door`. Der Feldname bleibt `allowedSubs` (ein Umbenennen in `door` berührte zusätzlich `main.ts`-Optionen und die Testaufbauten und bringt keinen Nutzen).
- **Abweisung an der Grenze** ist von einer Listen-Abweisung nicht zu unterscheiden: App `POST /auth/apple` → bares 401; claude.ai-Weg → Ticket `access_denied`; Log nur die feste Zeile `account refused`. **Keine neue Logzeile** (verworfene Alternative: eigene Zeile „cap reached“, sie verriete Außenstehenden nichts, brächte aber einen zweiten Betriebs-Alarmpfad ohne Bedarf; wer die Grenze beobachten will, zählt `account refused` und Konten in der Datenbank).
- **Unverändert:** alle Migrationen (`accounts.created_at` besteht seit Migration 002), `server/package.json`, nginx, Compose, `.env` im Betrieb.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `pg` (`Pool.connect`, `pg_advisory_xact_lock`), Tabelle `accounts` mit `created_at` | module | Zählung im Fenster, Anlegen unter Sperre |
| `ACCOUNT_LOCK_ID` in `server/src/accounts.ts` | konstante | dieselbe Sperre für `admitFirst` und `admitOpen` |
| `docs/specs/feat-621-schnitt-6a-tuer.md` | spec | Vorgänger, Liste und „erstes Konto“ |
| Tests: `freshPool`, `migrate`, `rig`/`appleOk` (`auth.test.ts`), `service`/`withApple`/`through`/`ticketOf` (`oauth-return.test.ts`), Prozessstart-Muster (`main.test.ts`) | test | bestehende Hilfen |
| `scripts/deploy-loose-ends.sh` (henemm-infra) | skript | Rollout auf rennwienix |
| Downstream | schnitte | S5d (Betriebs-Umgebung auf `*` stellen, Store) |

## Acceptance Criteria

Wenn nicht anders genannt, läuft jeder Test gegen ein Wegwerf-Schema mit allen Migrationen. Belege liegen unter `docs/artifacts/feat-625-s5a-offene-tuer/`. Kein Beleg enthält Zugangsdaten, Tokens oder `sub`-Werte.

- **AC-1:** Offen legt neue Konten an: GIVEN die Tür `{ open: true, perDay: 3 }` und leere Tabelle WHEN `admit` für drei verschiedene `sub`s nacheinander läuft THEN ergibt jeder eine Konto-ID und `accounts` hat genau drei Zeilen. Test: `server/test/accounts.test.ts` „tuer offen: neue konten bis zur grenze“.
- **AC-2:** Bestandskonten kommen immer herein: GIVEN drei Konten, Tür `{ open: true, perDay: 3 }` (Grenze erreicht) WHEN `admit` für eine vorhandene `sub` läuft THEN ergibt es deren ID, ohne zweite Zeile; WHEN `admit` für eine vierte, neue `sub` läuft THEN `null`. Test: „tuer offen: bestandskonto ueber der grenze kommt herein“.
- **AC-3:** Ablehnung schreibt nichts: GIVEN Grenze erreicht WHEN `admit` für eine neue `sub` `null` ergibt THEN sind `accounts` unverändert (gleiche Zeilenzahl, keine Zeile für die `sub`), und derselbe Client bleibt für den nächsten Aufruf nutzbar (kein hängendes `BEGIN`, Pool nach dem Lauf vollständig frei). Test: „tuer offen: ablehnung schreibt nichts und gibt die verbindung frei“.
- **AC-4:** Gleitendes 24-Stunden-Fenster nach Datenbankzeit: GIVEN Tür `{ open: true, perDay: 2 }` und zwei Konten, deren `created_at` per `UPDATE` auf 25 Stunden zurückliegt WHEN eine neue `sub` kommt THEN wird sie angelegt (alte Konten zählen nicht); GIVEN danach zwei Konten innerhalb der letzten 23 Stunden WHEN eine weitere neue `sub` kommt THEN `null`; WHEN die beiden Konten auf 25 Stunden zurückdatiert werden THEN wird die nächste neue `sub` wieder angelegt. Test: „tuer offen: gleitendes fenster von 24 stunden“.
- **AC-5:** Nebenläufigkeit hält die Grenze genau: GIVEN Tür `{ open: true, perDay: 5 }` und leere Tabelle WHEN zwölf `admit`-Aufrufe mit zwölf verschiedenen neuen `sub`s gleichzeitig laufen (`Promise.all`, Pool mit mindestens zwölf Verbindungen) THEN sind genau fünf Ergebnisse eine ID, sieben `null`, und `accounts` hat genau fünf Zeilen; WHEN dieselbe neue `sub` achtmal gleichzeitig kommt THEN ergeben alle dieselbe ID, eine Zeile. Test: „tuer offen: gleichzeitige neue konten ergeben genau die grenze“.
- **AC-6:** Liste und „erstes Konto“ bleiben unverändert: GIVEN die bestehenden Tests von S6a (`admit` mit Liste, `admit` ohne Tür, `findOrCreate`-Helfer) WHEN der Gesamtlauf läuft THEN sind sie in Aussage und Prüfungen unverändert grün (angepasst wird nur der Name der Lesefunktion `allowedSubsFromEnv` zu `doorFromEnv` und die Meldung in `main.test.ts`). Test: Gesamtlauf `./server/scripts/test-local.sh`.
- **AC-7:** `doorFromEnv` liest streng und nennt nie den Wert: GIVEN die Fälle WHEN `doorFromEnv` läuft THEN gilt: beide Variablen fehlen oder leer → `undefined`; `ALLOWED_APPLE_SUBS="a, b ,c"` → Menge `{a, b, c}`; `"*"` und `" * "` ohne Grenze → `{ open: true, perDay: 20 }`; `"*"` mit `NEW_ACCOUNTS_PER_DAY=7` → `perDay: 7`; `NEW_ACCOUNTS_PER_DAY` leer → 20; Fehler `NEW_ACCOUNTS_PER_DAY` bei `0`, `-1`, `1.5`, `abc`, `10001`, `1e2`, `" 5x"`; Fehler `ALLOWED_APPLE_SUBS` bei `"*,a"`, `"a,*"`, `"a,,b"`, `"a,"`, `","`; Fehler `NEW_ACCOUNTS_PER_DAY` bei gesetzter Grenze ohne `*` (leere Liste, Liste oder `*` fehlt); jede Fehlermeldung ist genau der Variablenname und enthält keinen Teil des Werts. Test: „tuer: doorFromEnv liest streng und nennt nie den wert“.
- **AC-8:** Ein ungültiger Wert stoppt den Prozess vor Pool und Port: GIVEN der gestartete Prozess (`main.ts`, Muster der Start-Tests) mit `ALLOWED_APPLE_SUBS=sub-a,,sub-geheim-4711` WHEN er startet THEN Exit 1, die Ausgabe enthält `door invalid: ALLOWED_APPLE_SUBS`, weder `sub-geheim-4711` noch `sub-a`, und keinen offenen Port; GIVEN `ALLOWED_APPLE_SUBS=*` und `NEW_ACCOUNTS_PER_DAY=zwanzig` THEN Exit 1 mit `door invalid: NEW_ACCOUNTS_PER_DAY` ohne den Wert. Test: `server/test/main.test.ts` „start: ungueltige tuer stoppt vor pool und port, ohne den wert zu nennen“ (ersetzt den Test mit der alten Meldung).
- **AC-9:** Die offene Tür gilt für die App über `POST /auth/apple`: GIVEN `authRoutes` mit Fake-Apple und der Tür `{ open: true, perDay: 1 }` WHEN eine fremde `sub` anmeldet THEN 200 mit Sitzungstoken und ein Konto; WHEN eine zweite, andere `sub` anmeldet (Grenze erreicht) THEN ein bares 401 (leerer Körper, `no-store`), keine Zeile in `accounts`, `sessions` und `apple_tokens` für sie, das Protokoll genau `["account refused"]`, die `sub` in keiner Antwort und keiner Zeile; WHEN die erste `sub` nochmals anmeldet THEN 200. Test: `server/test/auth.test.ts` „auth: offene tuer, fremde sub kommt herein, an der grenze 401“.
- **AC-10:** Die offene Tür gilt für den claude.ai-Rückweg: GIVEN der Rückweg (`service` über `start`, Fake-Apple, `through`) mit der Tür `{ open: true, perDay: 1 }` WHEN eine erste `sub` den Weg durchläuft THEN trägt das Ticket eine Konto-ID und das Web-Token ist abgelegt; WHEN eine zweite `sub` ihn durchläuft THEN antwortet er 303 auf `finish`, das Ticket ist `{ uid, error: "access_denied" }` mit `account_id` NULL, es gibt kein zweites Konto, kein abgelegtes Web-Token für sie, das Protokoll enthält genau `account refused` ohne `sub` oder Konto-ID. Test: `server/test/oauth-return.test.ts` „rueckweg: offene tuer, grenze ergibt access_denied ohne konto und ohne token“.
- **AC-11:** Gesamtlauf: GIVEN der fertige Schnitt WHEN `./server/scripts/test-local.sh` (typecheck + alle Tests) läuft THEN ist er grün und räumt auf, ohne neue Abhängigkeit in `server/package.json` und ohne neue Migration; die CI `server.yml` ist auf dem PR grün (Beleg `green.txt`). Funktionslänge (höchstens 50 Zeilen) und Dateiliste belegt `/60-validate`, nicht ein Test.
- **AC-12:** Ausgerollt mit unveränderter Betriebs-Tür: GIVEN der Merge-Commit WHEN `scripts/deploy-loose-ends.sh` (henemm-infra) auf rennwienix an genau diesem Commit läuft, die `.env` unverändert (Liste bleibt gesetzt, `NEW_ACCOUNTS_PER_DAY` nicht gesetzt) THEN antwortet `/health` mit 200, und Hennings Konto kommt weiter herein, belegt durch einen Aufruf von `get_now` über den claude.ai-Konnektor, der eine Antwort mit `nowCount` liefert. Der Beleg (`rollout.txt`: Commit-Kennung, `/health`-Status, Satz zur `get_now`-Antwort ohne `sub`, Token oder Listeninhalt) liegt im Belegordner.
- **AC-13:** Dokumentation: GIVEN `CLAUDE.md` WHEN der `server/`-Abschnitt, Absatz `src/accounts.ts`, gelesen wird THEN beschreibt er `admit` mit den drei Zweigen (Liste, erstes Konto, offen mit Tagesgrenze), `doorFromEnv` mit `*` und `NEW_ACCOUNTS_PER_DAY` (Vorgabe 20, 24 Stunden gleitend, Bestandskonten nie abgewiesen, gelöschtes Konto zählt nicht mehr), die Meldung `door invalid: <VARIABLE>`, und der Satz „the rule goes with #625“ ist durch den Stand ersetzt; die Grundregel „The service is open to every Apple account …“ steht weiter im Abschnitt „Ground rules“ (Beleg: Lesen, Diff).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/accounts.ts` | MODIFY | `Door`, `admitOpen`, `admit` mit drittem Zweig, `doorFromEnv` statt `allowedSubsFromEnv`; ca. +40/−8 |
| `server/src/main.ts` | MODIFY | `doorFromEnv`, Meldung `door invalid: <VARIABLE>`, Typ `Door` in `StartOptions`; ca. +8/−6 |
| `server/src/auth.ts` | MODIFY | Typ `Door` in `AuthDeps.allowedSubs`; ca. +2/−2 |
| `server/src/oauth-return.ts` | MODIFY | Typ `Door` in `AppleReturnDeps.allowedSubs`; ca. +2/−2 |
| `server/test/accounts.test.ts` | MODIFY | AC-1 bis AC-5, AC-7; ca. +110/−10 |
| `server/test/auth.test.ts` | MODIFY | AC-9; ca. +30 |
| `server/test/oauth-return.test.ts` | MODIFY | AC-10; ca. +35 |
| `server/test/main.test.ts` | MODIFY | AC-8 (alter Test ersetzt); ca. +20/−8 |
| `CLAUDE.md` | MODIFY | `server/`-Abschnitt (AC-13); die lokal bereits geänderte Grundregel gehört in denselben PR; ca. +4/−2 |
| `docs/project/00-entscheidungen.md` | MODIFY | ADR-21-Ergänzung, eine Zeile |
| `docs/artifacts/feat-625-s5a-offene-tuer/` | CREATE | Belege (`red.txt`, `green.txt`, `rollout.txt`); zählt nicht zum Dateilimit |

### Estimated Changes

- Files: 4 Produktdateien (Limit 4 bis 5 eingehalten); dazu Tests und Doku, die laut Regel nicht zählen (Testcode zählt nicht, Doku ist eine Zeile bis wenige Zeilen).
- LoC: App-Code (Dienstcode) grob +52/−18, Tests grob +195/−18, Doku +5/−2. Unter ±250 für Produktcode.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, kein `generate`, keine neue Abhängigkeit, keine Migration.
- **Seiteneffekte (explizit):** (1) die Fehlermeldung beim ungültigen Start ändert sich zu `door invalid: <VARIABLE>`; geprüft 2026-11-22: die Zeichenkette `allowed subs invalid` steht in keinem Repo von henemm außer in `server/src/main.ts` und dessen Test (Codesuche), keine Überwachung sucht danach. (2) `NEW_ACCOUNTS_PER_DAY` ohne `*` stoppt den Start; die Betriebs-`.env` setzt sie heute nicht. (3) Mit unveränderter `.env` ist das Verhalten im Betrieb gleich dem heutigen.
- **Parallele Arbeit:** Hotspot `CLAUDE.md`; vor dem PR `origin/main` und offene PRs prüfen.
- **Abnahme:** Kein Pfad der Geräteliste berührt. Nur `server/`, Doku und `CLAUDE.md`; Stufe 3 entfällt, die Abnahme endet nach Tests und Rollout-Beleg. Ein Simulator-Durchlauf entfällt, weil reiner Dienstcode ohne Oberfläche; beide Anmeldewege werden in AC-9 und AC-10 mit echter Datenbank und Fake-Apple durchgespielt.

## Implementation Details

Reihenfolge (TDD): erst die Tests (AC-1 bis AC-5, AC-7 bis AC-10) schreiben und rot belegen (`red.txt`: `Door`, `admitOpen`, `doorFromEnv` fehlen), dann `accounts.ts`, dann die Typen in `auth.ts` und `oauth-return.ts`, dann `main.ts`, grün belegen (`green.txt`), dann `CLAUDE.md` und ADR-21-Zeile. Danach PR mit `Refs #625`, CI `server.yml` grün, Merge, Rollout am Merge-Commit mit `scripts/deploy-loose-ends.sh` (Aufruf über `ssh rennwienix bash -s < skript`, Befehle mit „.env“ nicht direkt), `/health` und `get_now` prüfen (`rollout.txt`). Die Zählung nutzt `now()` der Datenbank; Tests datieren `created_at` per `UPDATE` zurück, nie über die Systemuhr. Kommentare knapp auf Englisch; Tests `node:test` + `node:assert/strict`.

## Test Plan

### Automated Tests (TDD RED)

- [ ] Test 1 (AC-1): GIVEN Tür offen mit Grenze 3 WHEN drei neue `sub`s THEN drei Konten.
- [ ] Test 2 (AC-2): GIVEN Grenze erreicht WHEN vorhandene `sub` THEN ihr Konto; WHEN neue `sub` THEN `null`.
- [ ] Test 3 (AC-3): GIVEN Grenze erreicht WHEN neue `sub` abgewiesen THEN nichts geschrieben, Verbindung frei.
- [ ] Test 4 (AC-4): GIVEN Konten zurückdatiert auf 25 Stunden WHEN neue `sub` THEN angelegt; bei 23 Stunden THEN `null`.
- [ ] Test 5 (AC-5): GIVEN Grenze 5 WHEN zwölf gleichzeitige neue `sub`s THEN genau fünf Konten.
- [ ] Test 6 (AC-7): GIVEN Umgebungswerte WHEN `doorFromEnv` THEN `undefined`, Menge, offen oder Fehler mit nur dem Variablennamen.
- [ ] Test 7 (AC-8): GIVEN ungültige Werte WHEN Prozessstart THEN Exit 1, `door invalid: <VARIABLE>`, kein Wert, kein Port.
- [ ] Test 8 (AC-9): GIVEN offene Tür mit Grenze 1 WHEN zwei fremde `sub`s an `/auth/apple` THEN 200, dann 401 ohne Spur.
- [ ] Test 9 (AC-10): GIVEN offene Tür mit Grenze 1 WHEN zwei `sub`s im Rückweg THEN Konto, dann `access_denied` ohne Token.
- [ ] Test 10 (AC-6, AC-11): GIVEN Gesamtlauf WHEN `./server/scripts/test-local.sh` THEN grün.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **Gewählt: offen mit gleitender Tagesgrenze, Wert in der Umgebung** | `*` und `NEW_ACCOUNTS_PER_DAY` | löst die 2.1-Lage ohne App-Änderung; Grenze änderbar ohne Code; Bestandskonten sicher; Rollout ohne Betriebsänderung möglich | neue Konten sind nach Erreichen der Grenze bis zu 24 Stunden gesperrt, auch ein Prüfer; Löschen und Neuanlegen entlastet das Fenster | Teile von ADR-21 („nur Henning bis #625“), als Ergänzung |
| **A Einladungscode** | Prüfer bekommt einen Code in den Review-Notizen | engere Kontrolle | braucht ein App-Feld, Serverprüfung, Übersetzungen, mindestens zwei Schnitte; Apple-Akzeptanz nur aus Fallberichten belegt | keine ADR, schiebt #625 um zwei Schnitte |
| **B Tür zu lassen** | Liste bleibt | kein Code | Definition of Done von #625 (Schalter im Store an) unerfüllt; Gruppe „Claude“ im Store ohne Zugang führt zur Ablehnung nach Guideline 2.1 | die PO-Entscheidung vom 2026-11-22 |
| **C Feste Kalendertag-Grenze** | Zählung ab 00:00 | einfach erklärbar | Zeitzonenfrage, Sprung um Mitternacht (zweimal die Grenze in kurzer Zeit), Fensterlogik mit Datumsvergleich statt `interval` | keine ADR; verworfen zugunsten des gleitenden Fensters |
| **D Grenze als Konstante im Code** | `20` im Quelltext | kein Zusatz-Variablenparsing | jede Anpassung braucht Build und Rollout, nicht nur eine Zeile am Server; widerspricht der PO-Vorgabe „Betriebswert“ | die PO-Vorgabe |
| **E Eigene Logzeile „cap reached“** | eigene Zeile bei Abweisung an der Grenze | Betrieb sähe die Ursache direkt | zweite Alarmart ohne Bedarf; die Abweisung soll außen und im Log nicht von einer Listen-Abweisung zu unterscheiden sein; Zählen von `account refused` und Konten genügt | keine ADR; verworfen |

## Risiken

- **Grenze erreicht, ein Prüfer oder echter Nutzer wird abgewiesen.** Gegenmittel: großzügiger Vorgabewert 20, Betriebswert ohne Code änderbar; im Store-Schnitt wird der Stand vor dem Einreichen geprüft.
- **Bestandskonto fälschlich abgewiesen.** Gegenmittel: AC-2 (Bestandskonto über der Grenze).
- **Zwei neue Konten gleichzeitig überschreiten die Grenze.** Gegenmittel: dieselbe Transaktionssperre wie bei `admitFirst`, AC-5 mit zwölf Läufern.
- **Tür geht versehentlich auf.** `*` wird nur als genau dieser Wert (getrimmt) erkannt, gemischt mit Einträgen ist es ein Fehler, eine gesetzte Grenze ohne `*` stoppt den Start; ein fehlender oder ungültiger Wert öffnet nie (AC-7, AC-8).
- **Meldung beim Start ändert sich.** Geprüft 2026-11-22: kein Betriebsskript und keine Überwachung sucht nach der alten Zeichenkette (Seiteneffekt 1).
- **Löschen und Neuanlegen umgeht die Grenze.** Akzeptiert und dokumentiert: die Grenze ist ein Mindestschutz gegen Massenanlage, kein Missbrauchsschutz gegen einzelne Nutzer; dazu bleiben nginx-Zonen, fail2ban und `MAX_DEVICES`.

## Out of Scope / Folgeschnitte

- S5b, S5c, S5d (siehe oben), insbesondere das Umstellen der Betriebs-Umgebung auf `ALLOWED_APPLE_SUBS=*`.
- Widerruf eingelöster Apple-Tokens für Abgewiesene (Rest aus S6a, bleibt offen).
- Beschränkungen je Konto für Abschrift und Aufträge über die vorhandenen Größengrenzen hinaus.

## Definition of Done

- [ ] AC-1 bis AC-13 erfüllt, Belege im Belegordner
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] PR mit `Refs #625` (nie `Closes`), gemergt; Rollout mit unveränderter `.env`, `/health` 200, `get_now` antwortet
- [ ] `CLAUDE.md` und ADR-21-Ergänzung aktualisiert
- [ ] #625 kommentiert (Stand Schnitt 5a; Folgen S5b bis S5d), Board-Karte aktuell, Memory geschrieben

Keine Gerätepunkte (Stufe 3 greift nicht).

## Changelog

- 2026-11-22: Initial spec created (Schnitt 5a von #625, offene Tür mit Tagesgrenze)

---
entity_id: feat-621-schnitt-6a-tuer
type: feature
created: 2026-11-08
updated: 2026-11-08
status: draft
workflow: feat-621-s6-betrieb
---

# Spec: Die Tür, nur Hennings Apple-Konto legt ein Konto an (Schnitt 6a, #621, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#621 (Epic #612). Schnitt 6a; das Issue bleibt offen (`Refs #621`, nie `Closes #621`, Größe L, mehrere Schnitte).
Analyse: `docs/context/feat-621-s6-betrieb.md`, Abschnitt „Analysis“ (Kernbefund, Varianten, Empfehlung (a)+(b), Schnitt S6a). Vorgänger: `docs/specs/feat-621-schnitt-4c2-web-token-ablegen.md` (der Rückweg legt Konto und Web-Token an), `docs/specs/feat-621-schnitt-4c1-ablage-je-client.md`. Geplant war die Erlaubnisliste im Schnittplan `docs/context/feat-621-mcp-anmeldung.md` (S5: „nur Henning bis #625“); gebaut wurde sie nicht. Folge: S6b (Betrieb), eigener Workflow.

## Für den PO

Sobald der Dienst im Netz steht (S6b), kann sich jede Person mit einer Apple-ID über claude.ai anmelden, und der Dienst legt für sie ein Konto an und merkt sich ihre Apple-Berechtigung. Das wollen wir vor der Veröffentlichung (#625: Datenschutz, Verzeichnis) nicht. Der Plan war immer „bis dahin nur Henning“ (ADR-21); die Sperre dafür fehlt im Code. Dieser Schnitt baut sie.

Die Regel in Alltagssprache: **Es entsteht nie ein Konto für eine fremde Person.** Solange keine Liste hinterlegt ist, kann sich genau eine Person anmelden, nämlich die erste; mit ihrem Konto ist die Tür zu. Danach trägt Claude Hennings Apple-Kennung auf dem Server in eine Liste ein (nur dort, nie im Repo oder im Protokoll); ab dann zählt die Liste. Wer nicht auf der Liste steht, wird bei der Anmeldung abgewiesen: in der App ohne Begründung, im Browser mit „Zugriff verweigert“. Es wird nichts gespeichert und kein Token abgelegt.

Für dich ändert sich **nichts Sichtbares**: Der Dienst ist von außen noch nicht erreichbar, die App und deine Daten sind nicht berührt, es gibt keine Datenbankänderung. **Du musst nichts entscheiden.** Der Umfang liegt über der üblichen Grenze (siehe Scope), das klärt der Tech Lead vor dem Bau.

## Purpose

`findOrCreate(pool, appleSub)` in `server/src/accounts.ts` legt per `INSERT … ON CONFLICT` für jede gültige Apple-`sub` ein Konto an. Seine beiden Produktaufrufer sind `signIn` in `auth.ts` (`POST /auth/apple`, App) und `outcome` in `oauth-return.ts` (Web-Rückweg). Es gibt keine Erlaubnisliste, obwohl ADR-21 „nur Henning bis #625“ lautet. Öffnet S6b nginx, wäre die Konto-Anlage offen.

Änderung: eine neue Funktion `admit(pool, appleSub, allowed)` in `accounts.ts`, Rückgabe `string | null` (Konto-ID oder abgewiesen). **Beide Produktaufrufer benutzen nur noch sie; `findOrCreate` bleibt als Testhelfer in `accounts.ts` bestehen und wird in `src` von keiner anderen Datei mehr benutzt** (ein Test sichert das ab, AC-8).

Die Regel (eindeutig, zwei Zweige, nie offen):

1. **Liste gesetzt** (`ALLOWED_APPLE_SUBS`, nach dem Lesen eine nicht leere Menge): ist die `sub` in der Liste, ergibt `admit` ihr Konto (angelegt, falls neu); sonst `null`. **Die Liste gilt für alle, auch für ein bereits vorhandenes Konto**: Steht dessen `sub` nicht (mehr) darin, wird abgewiesen. Das ist die sicherere und einfachere Regel („die Liste ist die Wahrheit“): Wer von der Liste genommen wird, kommt nicht mehr hinein; ein Tippfehler in der Liste sperrt aus, ist aber am Server in einer Zeile behoben und öffnet nie. Bereits ausgegebene Sitzungen und Tokens bleiben unberührt (die Tür steht nur an der Anmeldung); sie sind nicht Teil dieses Schnitts.
2. **Liste fehlt** (Variable nicht gesetzt oder nur Leerraum): eine vorhandene `sub` ergibt ihr Konto; eine neue `sub` nur, solange die Tabelle `accounts` leer ist (das erste Konto schließt die Tür). Prüfen und Anlegen laufen in einer Transaktion unter `pg_advisory_xact_lock` (fester Schlüssel `ACCOUNT_LOCK_ID`, verschieden von `MIGRATE_LOCK_ID`), damit zwei gleichzeitige Erstanmeldungen nie zwei Konten ergeben.

Warum die Liste auch Vorhandene prüft: Zweig 2 ist nur die Brücke bis Hennings erstem Verbinden (er hat auf dem Server noch kein Konto, seine `sub` ist vorher unbekannt). Danach trägt Claude seine `sub` aus der Datenbank in die Liste ein, und Zweig 1 gilt. Wäre ein zufällig im Zeitfenster angelegtes fremdes Konto in Zweig 1 weiter zugelassen, bliebe es für immer nutzbar; so lässt sich die Tür durch die Liste schließen. (Die Kontrolle „`accounts` = 1“ nach dem ersten Verbinden bleibt Teil von S6b.)

Plumbing: `allowedSubsFromEnv(env)` in `accounts.ts` liest `ALLOWED_APPLE_SUBS`: nicht gesetzt oder nur Leerraum ergibt `undefined`; sonst Komma-getrennt, jeder Eintrag getrimmt, **leere Einträge sind verboten** (`a,,b`, `a,`, `,a`, ` , ` werfen), das Ergebnis ist ein `Set`. Der Wurf nennt nur den Variablennamen, nie den Wert. `main()` ruft es neben den anderen Konfigurationen auf; bei einem Wurf schreibt es `allowed subs invalid: ALLOWED_APPLE_SUBS` und beendet sich mit Exit 1 **vor Pool und Port** (Muster `apple config invalid: <variable>`). Das Ergebnis reist als `StartOptions.auth.allowedSubs` zu `mountAuth` (→ `AuthDeps.allowedSubs`) und `returnFor` (→ `AppleReturnDeps.allowedSubs`). Ein nicht übergebener Wert heißt Zweig 2, also geschlossen, nie offen: wer die Option vergisst, öffnet nichts.

Ablehnung:

- `auth.ts`: `admit` ergibt `null` → bare 401 wie jede Ablehnung, kein `storeRefreshToken`, keine Sitzung; Protokoll nur die feste Zeile `account refused` über `deps.log`.
- `oauth-return.ts`: `null` → Ticket `{ uid, error: "access_denied" }` ohne Konto-ID, kein `storeRefreshToken`; Protokoll dieselbe feste Zeile `account refused` (nicht `oauth return refused`, damit der Betrieb „fremde Anmeldung abgewiesen“ von „kaputter Rückweg“ unterscheiden kann). Der Rückweg antwortet wie bei jedem Ticket mit der 303 auf `finish`.
- **Die `sub` steht nie in Protokoll, Antwort, Ticket oder Fehlertext.**

**Regeln vor Modell:** Datenbank-, Protokoll- und Sicherheitsablauf ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — löst ADR-21 („nur Henning bis #625“) ein, ohne sie zu ändern oder zu kippen; kein neues Verfahren, keine neue Abhängigkeit, keine Migration. Die Regel wird mit #625 entfernt (Variable und Zweig 2 entfallen).

- **Rationale:** Die Tür ist die technische Umsetzung der bereits getroffenen Entscheidung, dass bis zur Veröffentlichung kein Externer ein Konto bekommt. Sie benutzt Postgres-Bordmittel (Transaktion, Advisory Lock) und ist mit Testdatenbank und Fake-Apple vollständig belegbar.

## Source

**Files:** `server/src/accounts.ts`, `server/src/auth.ts`, `server/src/oauth-return.ts`, `server/src/main.ts`, `server/test/accounts.test.ts`, `server/test/auth.test.ts`, `server/test/oauth-return.test.ts`, `server/test/main.test.ts`, `CLAUDE.md` (alle ändern).
**Identifier:** `findOrCreate`, `admit` (neu), `allowedSubsFromEnv` (neu), `ACCOUNT_LOCK_ID` (neu), `signIn`, `AuthDeps`, `authRoutes`, `outcome`, `AppleReturnDeps`, `StartOptions`, `mountAuth`, `returnFor`, `main`

### Schnittstelle

- **`accounts.ts`**:
  - `export const ACCOUNT_LOCK_ID = 7_960_613_002;`
  - `export async function admit(pool: pg.Pool, appleSub: string, allowed?: ReadonlySet<string>): Promise<string | null>`: Zweig 1 (`allowed` gesetzt, auch wenn leer wäre er unmöglich, `allowedSubsFromEnv` liefert nie eine leere Menge): `allowed.has(appleSub)` sonst `null`, dann dasselbe Statement wie `findOrCreate`. Zweig 2: eigener Client, `BEGIN`, `SELECT pg_advisory_xact_lock($1)`, `SELECT id FROM accounts WHERE apple_sub = $1` → Treffer: `COMMIT`, ID; sonst `SELECT count(*)`; 0 → `INSERT … RETURNING id`, sonst `ROLLBACK` und `null`; jeder Fehler `ROLLBACK`, Client freigeben, Wurf weiter. Funktion höchstens 50 Zeilen (Zweig 2 bei Bedarf in eine Hilfsfunktion `admitFirst`).
  - `export function allowedSubsFromEnv(env: NodeJS.ProcessEnv): ReadonlySet<string> | undefined`: wie oben, Wurf `new Error("ALLOWED_APPLE_SUBS")`.
  - `findOrCreate` bleibt unverändert; Kommentar: „Test helper; the product goes through admit.“
- **`auth.ts`**: `AuthDeps` bekommt `allowedSubs?: ReadonlySet<string>`; in `signIn` ersetzt `admit(deps.pool, verdict.sub, deps.allowedSubs)` den Aufruf von `findOrCreate`; `null` → `deps.log?.("account refused")`, `return status(401)`. Import angepasst.
- **`oauth-return.ts`**: `AppleReturnDeps` bekommt `allowedSubs?: ReadonlySet<string>`; in `outcome` ersetzt `admit(...)` den Aufruf; `null` → `deps.log("account refused")`, `return { uid, error: "access_denied" }` vor Verschlüsseln und Ablegen. `outcome` bleibt unter 50 Zeilen (ist heute ≈ 20).
- **`main.ts`**: `StartOptions.auth` bekommt `allowedSubs?: ReadonlySet<string>`; `mountAuth` reicht es in `authRoutes(…)` weiter, `returnFor` in `appleReturn(…)`; `main()` liest `allowedSubsFromEnv(process.env)` in einem `try`, bei Wurf `logError("allowed subs invalid: ALLOWED_APPLE_SUBS")` und `process.exit(1)` (vor `start`), und gibt `auth: { config, allowedSubs }` weiter.
- **Unverändert:** `apple-vault.ts`, `apple-client.ts`, `apple.ts`, `oauth-interaction.ts`, `oauth-provider.ts`, `oauth-consent.ts`, alle Migrationen, `server/package.json`.

### Festlegungen

- **Kein Produktaufrufer legt an der Tür vorbei ein Konto an.** Jede künftige Stelle in `src`, die `findOrCreate` aufruft, lässt AC-8 rot werden.
- **Fail closed:** fehlende Option, fehlende Variable, leere Variable, ungültiger Wert: nie offen (fehlend/leer ergibt Zweig 2; ungültig stoppt den Start).
- **Kein Wert im Protokoll:** weder `sub` noch Listeninhalt noch Variablenwert; Protokoll nur `account refused` und `allowed subs invalid: ALLOWED_APPLE_SUBS`.
- **Alles Bestehende bleibt grün,** soweit es mehrere verschiedene `sub`s über die Produktwege anmeldet, reichen die Tests dafür eine Liste ein (siehe Scope, Testanpassungen); Testhelfer, die Konten mit `findOrCreate` herstellen, bleiben unverändert.
- **Stil:** Kommentare knapp auf Englisch; Tests `node:test` + `node:assert/strict`, eingereichtes `fetch`, kein Netz, Wegwerf-Schema je Test. Kein Test benutzt `git diff origin/main`.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `pg` (`Pool.connect`, `pg_advisory_xact_lock`), Tabelle `accounts` (`apple_sub` UNIQUE, Migration 002) | bestehend, ungeändert |
| `verifyIdentityToken` (liefert `sub` im App- und im Web-Pfad) | bestehend, ungeändert |
| `MIGRATE_LOCK_ID` (`migrate.ts`, anderer Schlüssel als `ACCOUNT_LOCK_ID`) | bestehend, ungeändert |
| Tests: `freshPool`, `migrate`, `rig`/`appleOk`/`login` (`auth.test.ts`), `service`/`withApple`/`through`/`ticketOf`/`ticketRow`/`countOf`/`fakeApple`/`assertQuiet` (`oauth-return.test.ts`), `A_ENV`, Prozessstart-Muster und `member` (`main.test.ts`) | bestehend |
| Downstream | S6b (Betrieb: Variable in der Server-Umgebung, `accounts = 1` prüfen, Hennings `sub` eintragen), #625 (Regel entfällt) |

## Acceptance Criteria

Wenn nicht anders genannt, läuft jeder Test gegen ein Wegwerf-Schema mit allen Migrationen.

- **AC-1:** Erstes Konto schließt die Tür (Zweig 2): GIVEN `accounts` ist leer und keine Liste WHEN `admit(pool, "sub-a", undefined)` läuft THEN gibt es die ID des neuen Kontos, genau eine Zeile in `accounts`; WHEN danach `admit(pool, "sub-b", undefined)` THEN `null`, weiterhin genau eine Zeile; WHEN `admit(pool, "sub-a", undefined)` nochmals THEN dieselbe ID wie zuvor, weiterhin eine Zeile. Test: server/test/accounts.test.ts „tuer: erstes konto schliesst die tuer, vorhandenes bleibt nutzbar“.
- **AC-2:** Gleichzeitige Erstanmeldungen ergeben genau ein Konto: GIVEN `accounts` ist leer und keine Liste WHEN acht `admit`-Aufrufe mit acht verschiedenen `sub`s gleichzeitig laufen (`Promise.all`, aus einem Pool mit mindestens acht Verbindungen) THEN ist genau ein Ergebnis eine ID, sieben sind `null`, und `accounts` hat genau eine Zeile; WHEN dieselbe `sub` achtmal gleichzeitig kommt THEN ergeben alle dieselbe ID, eine Zeile. Test: server/test/accounts.test.ts „tuer: gleichzeitige erstanmeldungen ergeben genau ein konto“.
- **AC-3:** Die Liste ist die Wahrheit (Zweig 1): GIVEN die Liste `{"sub-a"}` WHEN `admit(pool, "sub-a", liste)` läuft THEN gibt es ein Konto (auch bei leerer Tabelle); WHEN `admit(pool, "sub-x", liste)` bei leerer Tabelle THEN `null` und keine Zeile (die Liste schlägt die Regel „erstes Konto“); WHEN ein Konto zu `sub-b` schon besteht (hergestellt mit `findOrCreate`) und `admit(pool, "sub-b", liste)` läuft THEN `null` (vorhandenes Konto zählt nicht, wenn es nicht auf der Liste steht), die Zeile bleibt unberührt; WHEN die Liste `{"sub-a", "sub-b"}` ist THEN ergibt `admit(pool, "sub-b", …)` die ID des vorhandenen Kontos, ohne zweites. Test: server/test/accounts.test.ts „tuer: liste entscheidet, auch ueber vorhandene konten“.
- **AC-4:** Die Variable wird streng gelesen: GIVEN `allowedSubsFromEnv` WHEN die Variable fehlt, leer oder nur Leerraum ist THEN `undefined`; WHEN sie `"a, b ,c"` ist THEN die Menge `{a, b, c}` (getrimmt); WHEN sie `"a"` ist THEN `{a}`; WHEN sie `"a,,b"`, `"a,"`, `",a"`, `" , "` oder `","` ist THEN wirft jede mit der Meldung genau `ALLOWED_APPLE_SUBS` (der Wert, auch ein Teil davon, steht nicht in der Meldung). Test: server/test/accounts.test.ts „tuer: allowedSubsFromEnv liest streng und nennt nie den wert“.
- **AC-5:** Ein ungültiger Wert stoppt den Prozess vor Pool und Port: GIVEN der gestartete Prozess (`main.ts`, Muster der bestehenden Start-Tests) mit `ALLOWED_APPLE_SUBS=sub-a,,sub-geheim-4711` WHEN er startet THEN endet er mit Exit 1, seine Ausgabe enthält `allowed subs invalid: ALLOWED_APPLE_SUBS`, aber weder `sub-geheim-4711` noch `sub-a`, und er hat keinen Port geöffnet (keine „listening“-Zeile; das Muster der bestehenden Tests zu `oauth config invalid` zeigt, wie das geprüft wird). Test: server/test/main.test.ts „start: ungueltige ALLOWED_APPLE_SUBS stoppt vor pool und port, ohne den wert zu nennen“.
- **AC-6:** `POST /auth/apple` weist Fremde ab: GIVEN `authRoutes` mit Fake-Apple, ohne Liste, und ein Erstkonto, das sich anmeldet WHEN danach eine zweite, fremde `sub` mit gültigem Token und Code anmeldet THEN ist die Antwort ein bares 401 (leerer Körper, `no-store`), `accounts` hat weiter genau eine Zeile, `sessions` und `apple_tokens` haben keine Zeile für die zweite `sub`, das Protokoll ist genau `["account refused"]`, und die `sub` steht in keiner Antwort und keiner Protokollzeile; WHEN dieselbe fremde `sub` in der Liste steht (`allowedSubs` mit beiden) THEN antwortet derselbe Weg 200 mit Sitzungstoken, ein zweites Konto. Das Erstkonto selbst: 200 wie bisher. Test: server/test/auth.test.ts „auth: fremde sub wird abgewiesen, kein konto, keine sitzung, kein token“.
- **AC-7:** Der Web-Rückweg weist Fremde ab: GIVEN der Rückweg (`service` über `start`, Fake-Apple, `through`) ohne Liste, ein Erstkonto hat sich über den Rückweg angemeldet WHEN eine zweite, fremde `sub` (`apple.sub = "apple-sub-2"`) denselben Weg durchläuft THEN antwortet er 303 auf `finish`, die Ablage des Tickets ist `{ uid, error: "access_denied" }` mit `account_id` NULL, es gibt kein zweites Konto, keine Zeile in `apple_tokens` für die zweite `sub` (das Web-Token wird nicht abgelegt) und keinen Widerruf an Apple, das Protokoll enthält genau `account refused` (und keine Zeile mit der `sub` oder der Konto-ID), der `state` ist verbraucht; WHEN `allowedSubs` die zweite `sub` enthält THEN läuft derselbe Weg bis zum Ticket mit Konto-ID und abgelegtem Web-Token. Test: server/test/oauth-return.test.ts „rueckweg: fremde sub ergibt access_denied ohne konto und ohne token“.
- **AC-8:** Kein Produktweg umgeht die Tür: GIVEN die Quelldateien in `server/src` WHEN ein Test sie liest (Dateisystem, kein `git diff`) THEN kommt der Name `findOrCreate` außer in `accounts.ts` in keiner Datei vor; GIVEN `start()` ohne `allowedSubs` mit Apple-Konfiguration WHEN über `POST /auth/apple` zwei verschiedene `sub`s anmelden THEN wird nur die erste angenommen (200), die zweite bekommt 401 und es gibt ein Konto (belegt, dass `main.ts` die Tür auch ohne Option geschlossen verdrahtet); WHEN `start()` mit `allowedSubs` beider läuft THEN werden beide angenommen (belegt, dass die Option durch `mountAuth` und `returnFor` zu den Routen kommt). Test: server/test/main.test.ts „tuer: kein aufrufer in src umgeht admit, start verdrahtet die liste“ (Dateiliste-Teil mit `readdirSync`/`readFileSync` über `src`).
- **AC-9:** Gesamtlauf und Rest unverändert: GIVEN der fertige Schnitt WHEN `./server/scripts/test-local.sh` (typecheck + alle Tests) läuft THEN ist er grün und räumt auf; die bestehenden Tests, die über `authRoutes`, `appleReturn` oder `start` mehrere verschiedene `sub`s anmelden (`auth.test.ts` „app-id“-Schleife und der Löschfall, `oauth-return.test.ts` Test mit `apple-sub-2`, `main.test.ts` Löschfälle mit `member(…, .a/.b)`), reichen dafür ausdrücklich `allowedSubs` ein und bleiben sonst in Aussage und Prüfungen unverändert; es gibt keinen neuen Eintrag in `server/package.json` und keine neue Migration. Funktionslänge (jede Funktion höchstens 50 Zeilen) und Dateiliste belegt `/60-validate`, **nicht** als Test (ein Diff-Test gegen `main` bricht in der CI und nach dem Merge). Test: Gesamtlauf `./server/scripts/test-local.sh` und CI `server.yml`.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/accounts.ts` | MODIFY | `ACCOUNT_LOCK_ID`, `admit` (Zweig 1 und 2), `allowedSubsFromEnv`, Kommentar an `findOrCreate`; ≈ +40 |
| `server/src/auth.ts` | MODIFY | `AuthDeps.allowedSubs`, `signIn` über `admit`, 401 und `account refused` bei `null`; ≈ +5/−2 |
| `server/src/oauth-return.ts` | MODIFY | `AppleReturnDeps.allowedSubs`, `outcome` über `admit`, `access_denied` bei `null`; ≈ +6/−2 |
| `server/src/main.ts` | MODIFY | `StartOptions.auth.allowedSubs`, Durchreichen in `mountAuth` und `returnFor`, Lesen der Variable und Exit 1 in `main()`; ≈ +14/−2 |
| `server/test/accounts.test.ts` | MODIFY | AC-1 bis AC-4; ≈ +85 |
| `server/test/auth.test.ts` | MODIFY | AC-6; Liste in den Mehrfach-`sub`-Tests; ≈ +35/−3 |
| `server/test/oauth-return.test.ts` | MODIFY | AC-7; Liste im Test mit `apple-sub-2`; ≈ +40/−2 |
| `server/test/main.test.ts` | MODIFY | AC-5, AC-8; Liste in den Löschfällen; ≈ +50/−3 |
| `CLAUDE.md` | MODIFY | `server/`-Abschnitt, Absatz `accounts.ts`: ein Satz zur Tür; ≈ +2/−1 |

### Estimated Changes

- **Files: 9** (Code: 4, Tests: 4, Doku: 1). **Das liegt über dem Limit von 4 bis 5 Dateien.** Die Dateizahl entsteht aus der Natur des Schnitts: eine Regel (`accounts.ts`), zwei Produktaufrufer (`auth.ts`, `oauth-return.ts`) und die Verdrahtung (`main.ts`) lassen sich nicht auf weniger Code-Dateien legen, ohne dass ein Weg an der Tür vorbeiführt; jeder Weg hat seinen eigenen Testaufbau (`auth.test.ts`, `oauth-return.test.ts`, `main.test.ts`, `accounts.test.ts`). Die Code-Dateien sind jeweils nur wenige Zeilen groß.
- **Code ≈ 67 LoC, Tests ≈ 213 LoC, Doku ≈ 3 LoC, insgesamt ≈ 283 LoC** (Zeilen hinzugefügt, geändert und gelöscht) und damit **über dem Limit von ±250 LoC**. Die Last liegt in den Tests (Faustwert Sicherheitstests ≈ 2,5× Code; hier ≈ 3×, weil Gleichzeitigkeit, strenge Variable, beide Produktwege und der Bypass-Test einzeln stehen). **Vor dem Bau ist laut Regel zu entscheiden:** (1) annehmen als Sicherheitsschnitt (Präzedenz: #615 S2a, 334 LoC), oder (2) AC-5 (Prozess-Exit-Test, ≈ 30 LoC) und AC-8 (Bypass-Test, ≈ 25 LoC) streichen. Davon rät die Spec ab, weil beide die zwei Lücken schließen, durch die die Tür still aufgehen könnte (ungültige Variable → offener Start, vergessene Verdrahtung); ein Aufteilen in zwei Schnitte ist nicht sinnvoll, weil eine Tür, die nur an einem der beiden Wege steht, keine ist. Meldeschwelle beim Bauen: wächst die Summe über 300 LoC, wird das vor dem Weiterbauen gemeldet.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, kein `generate`, keine neue Abhängigkeit, keine Migration.
- Doku als Teil des Schnitts, `CLAUDE.md`, `server/`-Abschnitt, Absatz zu `src/accounts.ts`: ein Satz ergänzt: Produktaufrufer legen Konten nur über `admit` an (#621 S6a): Liste `ALLOWED_APPLE_SUBS` gesetzt gilt für alle; sonst nur das erste Konto, danach zu; ungültiger Wert stoppt den Start mit `allowed subs invalid: ALLOWED_APPLE_SUBS`; `findOrCreate` ist Testhelfer; die Regel entfällt mit #625.
- Seiteneffekte nach außen: keine. Der Dienst ist nicht erreichbar (nginx bis S6b); in Produktion ist `APPLE_*` nicht gesetzt, die Anmeldewege laufen dort nicht.
- **Parallele Arbeit:** Berührt werden die Hotspots `CLAUDE.md` und, falls offen, Tests in `oauth-return.test.ts` und `main.test.ts`; vor dem Bau `origin/main` und offene PRs prüfen.

## Risiken

- **Tür vergessen an einem Weg.** Ein dritter Aufrufer von `findOrCreate` öffnete sie. Gegenmittel: AC-8 (Quelltext-Prüfung) und AC-6/AC-7 je Weg.
- **Zwei Erstanmeldungen gleichzeitig.** Ohne Sperre könnten zwei Fremde im selben Augenblick ein Konto bekommen. Gegenmittel: `pg_advisory_xact_lock` in einer Transaktion, AC-2 mit acht Läufern.
- **Ungültige oder abgeschnittene Liste öffnet still.** Ein leerer Eintrag (`a,`) könnte als „jede `sub`“ missverstanden werden. Gegenmittel: leere Einträge werfen, Exit 1 vor dem Port (AC-4, AC-5); ein nicht übergebener Wert ist geschlossen, nie offen.
- **Sperrt sich der Betreiber aus.** Ein Tippfehler in der Liste weist Henning selbst ab. Folge nur: Anmeldung scheitert; Behebung am Server in einer Zeile, nichts ist offen. Bewusst in Kauf genommen (fail closed).
- **Wert im Protokoll.** Die `sub` ist eine Personenkennung. Gegenmittel: nur feste Zeilen, Tests suchen die `sub` in Protokoll und Antworten (AC-4 bis AC-7).
- **Restgrant bei Apple für einen Abgewiesenen.** Der Dienst hat Apples `code` schon eingelöst, bevor er die Tür prüft; bei Abweisung wird das Token weder abgelegt noch widerrufen. Folge: eine Autorisierung der Services ID bei Apple für eine fremde Person, ohne Spur bei uns; harmlos, aber nicht aufgeräumt. Nicht Teil dieses Schnitts (siehe unten).
- **Zeitfenster zwischen Öffnen und Hennings erster Anmeldung** (Zweig 2): ein Fremder könnte als Erster ankommen. Gegenmittel liegt in S6b: sofort nach dem Öffnen verbinden, `accounts = 1` und `apple_sub` prüfen, Liste setzen. Wer vorher keinen Zeitdruck will, trägt Hennings `sub` nach einem Probelauf in der App (`/auth/apple`) vorab ein.

## Test Plan

### Automated Tests (TDD RED)

RED: `admit` und `allowedSubsFromEnv` gibt es noch nicht, AC-1 bis AC-4 schlagen schon beim Import fehl. AC-6 und AC-7 schlagen fehl, weil die Produktwege jede `sub` annehmen (zweites Konto entsteht, Token wird abgelegt). AC-5 schlägt fehl, weil der Prozess den Wert ignoriert und weiterläuft. AC-8 schlägt fehl, weil `auth.ts` und `oauth-return.ts` `findOrCreate` benutzen.

| Testname | AC |
|---|---|
| „tuer: erstes konto schliesst die tuer, vorhandenes bleibt nutzbar“ | AC-1 |
| „tuer: gleichzeitige erstanmeldungen ergeben genau ein konto“ | AC-2 |
| „tuer: liste entscheidet, auch ueber vorhandene konten“ | AC-3 |
| „tuer: allowedSubsFromEnv liest streng und nennt nie den wert“ | AC-4 |
| „start: ungueltige ALLOWED_APPLE_SUBS stoppt vor pool und port, ohne den wert zu nennen“ | AC-5 |
| „auth: fremde sub wird abgewiesen, kein konto, keine sitzung, kein token“ | AC-6 |
| „rueckweg: fremde sub ergibt access_denied ohne konto und ohne token“ | AC-7 |
| „tuer: kein aufrufer in src umgeht admit, start verdrahtet die liste“ | AC-8 |
| `./server/scripts/test-local.sh`, `/60-validate` (Dateiliste und Funktionslänge per `git diff`) | AC-9 |

- [ ] Test 1 (AC-1): GIVEN leere Tabelle, keine Liste WHEN zwei verschiedene `sub`s nacheinander THEN erste ID, zweite `null`, wieder erste: dieselbe ID.
- [ ] Test 2 (AC-2): GIVEN leere Tabelle WHEN acht gleichzeitig THEN genau ein Konto, sieben `null`.
- [ ] Test 3 (AC-3): GIVEN Liste WHEN `sub` drin, draußen, vorhandenes Konto draußen THEN Konto, `null`, `null`.
- [ ] Test 4 (AC-4): GIVEN Variablenwerte WHEN gelesen THEN `undefined`, Menge oder Wurf `ALLOWED_APPLE_SUBS` ohne Wert.
- [ ] Test 5 (AC-5): GIVEN ungültiger Wert WHEN Prozessstart THEN Exit 1, feste Zeile, kein Wert, kein Port.
- [ ] Test 6 (AC-6): GIVEN Erstkonto WHEN fremde `sub` an `/auth/apple` THEN 401, kein Konto, keine Sitzung, kein Token, `account refused`.
- [ ] Test 7 (AC-7): GIVEN Erstkonto WHEN fremde `sub` im Rückweg THEN Ticket `access_denied` ohne Konto-ID, kein Token abgelegt, `account refused`.
- [ ] Test 8 (AC-8): GIVEN `src` und `start()` WHEN gelesen bzw. zwei `sub`s mit und ohne Liste THEN kein `findOrCreate` außerhalb `accounts.ts`; ohne Liste nur die erste, mit Liste beide.
- [ ] Test 9 (AC-9): GIVEN Gesamtlauf WHEN `./server/scripts/test-local.sh` THEN grün, keine neue Abhängigkeit.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): Liste (a) plus „erstes Konto“ (b) in einer Funktion `admit`, geschlossen als Standard** | siehe Purpose | schützt die Konto-Anlage an beiden Wegen; braucht Hennings `sub` nicht vorab (b löst die Henne-Ei-Lage); danach schließt die Liste die Tür dauerhaft und entfernbar mit #625; nie offen | zwei Zweige; Zeitfenster zwischen Öffnen und erster Anmeldung (durch S6b-Ablauf beherrscht) | — |
| **B Variante (a) allein: feste Liste, `sub` vorab** | nur `ALLOWED_APPLE_SUBS`, ohne Zweig 2 | ein Zweig, kein Zeitfenster | Hennings `sub` ist vor seiner ersten Anmeldung unbekannt (Apple vergibt sie je Team); sie müsste aus einem Probelauf stammen, also selbst erst ein Konto anlegen; ohne Liste wäre der Dienst entweder offen oder unbenutzbar | Variante (a)+(b) der Analyse; nicht gewählt, weil (b) die Henne-Ei-Lage ohne Zusatzschritt löst |
| **C (c) keine Beschränkung** | wie heute | kein Code | jede Person mit Apple-ID legt über claude.ai ein Konto an und hinterlegt ein Apple-Token, bevor Datenschutz und Veröffentlichung (#625) stehen; widerspricht ADR-21 „nur Henning bis #625“ und dem Plan „kein Externer vor #625“ | ADR-21; verworfen |
| **D (d) nginx-Beschränkung auf Anthropics Adressbereich (`160.79.104.0/21`)** | Zugriff auf `/mcp` und `/oauth/token` nur von Anthropic | nützliche Zusatzschranke gegen Scans | schützt die Konto-Anlage nicht: das Konto entsteht im Browser-Rückweg (`/oauth/apple/return`, Aufruf aus Apples Formular über den Browser der Person) und in `/auth/apple`, beide nicht aus Anthropics Netz; hielte also keinen Fremden ab, der sich anmeldet | der Dienstschutz; für S6b als Ergänzung für `/mcp` zu prüfen, ersetzt die Tür nicht |
| **E Tür an einer Stelle in `findOrCreate`** | die bestehende Funktion bekommt die Regel; Rückgabe „Konto-ID oder null“ | kein neuer Name, keine Verdrahtungsänderung an den Aufrufern außer `null` | ändert die Signatur für rund 46 Fundstellen, viele davon Testhelfer, die beliebige `sub`s brauchen; ein Aufrufer, der `null` vergisst, hätte eine Konto-ID `null` | die gewählte Trennung „Produkt über `admit`, Tests über `findOrCreate`“; verworfen |

Alternative zu A bleibt offen: Hält Henning das Zeitfenster-Risiko für zu hoch, kann S6b `ALLOWED_APPLE_SUBS` schon vor dem Öffnen aus einem Probelauf der App füllen und Zweig 2 so nie nutzen; kein Ticket nötig. Mit #625 (Veröffentlichung) entfällt die ganze Regel.

## Out of Scope / Folgeschnitte

- **S6b (Betrieb, eigener Workflow, `henemm-infra` und Server):** nginx öffnet `/mcp`, `/.well-known/oauth-protected-resource/mcp`, die beiden Discovery-Pfade und `/oauth/*` (Streaming-Einstellungen, Limit-Zonen), `/auth/*` und `/` bleiben 404; `LE_COMMIT` heben; `security/expected-exposure.json`; Services ID im Apple-Portal; Geheimnisse und Variablen in `server.env` (auch `ALLOWED_APPLE_SUBS`); Prüfung von außen; Verbinden in claude.ai (CIMD-URL ablesen); `accounts = 1` prüfen, Hennings `sub` eintragen, Dienst neu starten. Braucht eine neue Server-Schreibfreigabe von Henning.
- **Aufräumen für Abgewiesene:** Widerruf des bei Apple eingelösten Tokens, wenn die Tür abweist, und Entfernen bereits ausgegebener Sitzungen und Tokens von Konten, die von der Liste genommen werden. Nicht nötig, solange Henning das einzige Konto ist; bei Bedarf eigenes Ticket, sonst erledigt es #625 durch das Ende der Regel.
- **Die Regel entfernen:** mit #625.
- Änderungen an `apple-vault.ts`, Migrationen, `/auth/delete`, dem Aussteller: keine.

## Abnahme

Kein Pfad der Geräteliste berührt. (Nur `server/` und `CLAUDE.md`, keine App, kein `project.yml`.) Die Abnahme endet nach den Tests: `./server/scripts/test-local.sh` (typecheck + `node --test` gegen ein Wegwerf-Postgres) grün und die CI `server.yml` auf dem PR grün. Ein Simulator-Durchlauf entfällt, weil es reiner Dienstcode ohne Oberfläche ist und der Dienst von außen nicht erreichbar ist; beide Anmeldewege werden in AC-6, AC-7 und AC-8 mit echter Datenbank, echtem Vault und Fake-Apple durchgespielt. Stufe 3 entfällt.

## Definition of Done

- [ ] AC-1 bis AC-9 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] In `server/src` ruft außer `accounts.ts` nichts `findOrCreate` auf (AC-8)
- [ ] Umfang vor dem Bau vom Tech Lead entschieden (9 Dateien, ≈ 283 LoC, siehe Scope)
- [ ] `CLAUDE.md` (`server/`-Abschnitt) aktualisiert
- [ ] #621 kommentiert (Stand Schnitt 6a; Folge: S6b Betrieb), Board-Karte aktuell

## Changelog

- 2026-11-08: Initial spec created (Schnitt 6a)

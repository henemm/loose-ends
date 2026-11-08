---
entity_id: feat-615-schnitt-4a-sitzungsablauf
type: feature
created: 2026-11-08
updated: 2026-11-08
status: draft
workflow: feat-615-s4-app-anmeldung
---

# Spec: Sitzungen laufen gleitend ab, Schnitt 4a (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Schnitt 4a; das Issue bleibt offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-s4-app-anmeldung.md` (Abschnitte „Analysis“ und „Technical Approach“, 4a). Vorgänger: Schnitt 1 (`docs/specs/feat-615-schnitt-1-konten-sitzungen.md`, AC-4/AC-5 zu `resolveSession` und `endSession`), Schnitt 3b (`docs/specs/feat-615-schnitt-3b-anmelden-abmelden.md`) und Schnitt 3c-2 (`docs/specs/feat-615-schnitt-3c2-einhaengen.md`, Merkposten „Sitzungsablauf“ in den Folgeschnitten).

## Für den PO

Dieser Schnitt sorgt dafür, dass eine Anmeldung am Dienst nicht ewig gilt: Wer sich 90 Tage lang nicht gemeldet hat, muss sich in der App einmal neu mit Apple anmelden. Wer die App regelmäßig benutzt, merkt nichts, denn jede Benutzung verlängert die Frist wieder um 90 Tage. Das schützt dich, falls ein altes Telefon verloren geht oder verkauft wird, ohne dass du daran denkst. Von außen ändert sich noch nichts: Die App ruft den Dienst noch nicht auf, und der Server vor dem Dienst lässt die Anmelde-Türen noch nicht durch. Es ist der erste von vier kleinen Schritten zur Anmeldung in den Einstellungen.

## Purpose

`resolveSession` in `server/src/accounts.ts` löst eine Sitzung nur noch auf, wenn ihr `last_used_at` jünger als 90 Tage ist (Zeitpunkt: Datenbankzeit `now()`), und schiebt sie bei Erfolg wie bisher weiter. Eine abgelaufene Sitzung liefert `null` und wird nicht wiederbelebt. Keine Migration (die Spalte `last_used_at` besteht seit `server/migrations/002_accounts.sql`). **Regeln vor Modell:** Protokoll- und Betriebsarbeit, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Quelle (Recherche 2026-11-08): Das OWASP Session Management Cheat Sheet unterscheidet den Leerlauf-Ablauf (idle timeout: die Sitzung endet nach Nichtbenutzung und wird bei Benutzung verlängert) vom absoluten Ablauf (absolute timeout: feste Lebensdauer ab Anmeldung, unabhängig von der Benutzung) und empfiehlt, je nach Risiko beide oder einen zu setzen; für Anwendungen mit geringem Risiko seien lange Leerlauf-Fristen vertretbar (https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html, Abschnitt „Session Expiration“). Der Dienst hält nur Aufgaben des einen Nutzers und kennt keine Zahlung; 90 Tage Leerlauf sind dafür die lange, handyübliche Frist.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue — Ausgestaltung von ADR-21 (Weg B: Dienst für Claude, Anmeldung nur mit Apple, Sitzungstoken als Hash gespeichert); keine neue Abhängigkeit, kein neues Muster.
- **Rationale:** (1) Gleitend, weil das Telefon selten, aber regelmäßig benutzt wird: Ein fester Ablauf ab Anmeldung (z. B. 90 Tage absolut) würde auch den täglichen Nutzer alle drei Monate abmelden, ohne dass dem Schutz etwas nützt; die Anmeldung mit Apple ist am Handy ein Fingertipp, aber unnötige Abmeldungen kosten Vertrauen. (2) Die Grenze steht im SQL und nutzt `now()` der Datenbank: eine Uhr, kein Abgleich zwischen Node und Postgres, und die Prüfung und die Verlängerung sind eine einzige Anweisung (kein Zeitfenster dazwischen). (3) Eine abgelaufene Zeile wird beim Auflösen weder verlängert noch gelöscht: ein `UPDATE` und ein `DELETE` derselben Zeile in einer Anweisung (CTE) hätte in Postgres kein definiertes Ergebnis, und zwei Anweisungen wären der zusätzliche Schritt, den ein reiner Leseweg nicht braucht. (4) Aufräumen entfällt in 4a: abgelaufene Zeilen sind für jede Funktion unsichtbar, enthalten nur den SHA-256 eines Tokens und gehen mit dem Konto per Fremdschlüssel (`ON DELETE CASCADE`, `deleteAccount`) weg; bei einem Konto und wenigen Geräten wächst die Tabelle nicht spürbar.
- **Alternative (verworfen):** fester Ablauf ab `created_at` (absolute timeout), allein oder zusätzlich zum gleitenden. Er bräuchte keine neue Spalte, wäre aber für die App (4b) die häufigere Abmeldung ohne Sicherheitsgewinn bei einem Ein-Nutzer-Dienst. Gekippt würde nichts Bestehendes; kommt später ein zweiter Nutzer oder ein höheres Risiko hinzu, ist die Kombination (gleitend 90 Tage, absolut z. B. 365 Tage) ein reiner Zusatz in derselben `WHERE`-Bedingung, ohne Migration. Der Merkposten „fest oder gleitend“ aus #615 und #621 ist damit entschieden.

## Source

**Files:** `server/src/accounts.ts` (ändern), `server/test/accounts.test.ts` (neue Tests, ein bestehender Test minimal angepasst, siehe AC-8), `CLAUDE.md`
**Identifier:** `SESSION_IDLE_DAYS`, `resolveSession`, `endSession`

### Schnittstelle

- **`export const SESSION_IDLE_DAYS = 90;`** in `accounts.ts`, die einzige Stelle der Frist.
- **`resolveSession(pool, token)`** (Signatur unverändert): eine Anweisung

  `UPDATE sessions SET last_used_at = now() WHERE token_hash = $1 AND last_used_at > now() - make_interval(days => $2) RETURNING account_id`

  mit `$2 = SESSION_IDLE_DAYS`. Trifft die Bedingung nicht, ist `rows[0]` leer und die Funktion liefert `null`; die Zeile bleibt unverändert (`last_used_at` bleibt alt).
- **Grenze:** Eine Sitzung gilt, solange `last_used_at` **echt jünger** als 90 Tage ist (`>`). Eine Sitzung, deren `last_used_at` genau 90 Tage zurückliegt, gilt als abgelaufen. Weil `now()` im Test erst nach dem Setzen von `last_used_at = now() - interval '90 days'` ausgewertet wird, liegt dieser Zeitpunkt bei der Prüfung immer ein kleines Stück mehr als 90 Tage zurück: der Test ist deterministisch.
- **`endSession`:** unverändert, ohne Fristprüfung. Eine abgelaufene Sitzung wird gelöscht und gibt `true` zurück (die Zeile gab es noch); so räumt der Abmeldeversuch einer alten App die Zeile weg. `POST /auth/logout` antwortet in jedem Fall 204 (`auth.ts` ruft `endSession` und wertet das Ergebnis nicht aus).
- **Aufrufer, unverändert:** `POST /auth/delete` löst per `resolveSession` auf; eine abgelaufene Sitzung ergibt `null` und damit die bekannte nackte 401. Die App (4b) behandelt 401 auf jedem Aufruf mit „lokale Sitzung verwerfen, neu anmelden“.

### Festlegungen

- **Nicht betroffen:** OAuth-Tokens von claude.ai (`oauth_records`, eigene Laufzeiten, Spec #621 S3) und `/mcp` (App-Sitzungstoken werden dort ohnehin abgelehnt, `providerVerifier`/`rejectAll`); `createSession`, `deleteAccount`, `admit`.
- **Stille:** keine neue Logzeile, keine Konsolenausgabe (S1-AC-12 bleibt gültig).
- **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Kommentare knapp auf Englisch; keine neuen Pakete.
- **Unberührt:** `auth.ts` und alle anderen `src/`-Dateien, Migrationen, `server/test/db.ts`, jede Swift-Datei, `project.yml`, `.github/`.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `sessions.last_used_at` (`server/migrations/002_accounts.sql`) | bestehend, unverändert, keine Migration |
| `resolveSession`, `endSession`, `createSession` (`accounts.ts`) | bestehend, `resolveSession` wird enger |
| `POST /auth/delete`, `POST /auth/logout` (`auth.ts`) | bestehend, unverändert |
| `node:test`, `pg`, `server/test/db.ts` (`freshPool`) | bestehend, **keine neuen Pakete** |
| Downstream | 4b (App-Kern: 401 verwirft die lokale Sitzung), 4d (Freigabe nach außen erst mit Ablauf), #621 (kein Einfluss) |

## Acceptance Criteria

Alle neuen Tests mit `node:test` und `node:assert/strict` in `server/test/accounts.test.ts`, mit dem vorhandenen Aufbau `migrated(t)` gegen das Wegwerf-Postgres aus `server/test/db.ts`. Die Tests setzen `last_used_at` per SQL (`UPDATE sessions SET last_used_at = now() - interval '…'`); kein Uhr-Parameter aus Node. Ablehnungsfälle tabellengetrieben, ein Fall je Zeile.

- **AC-1:** Innerhalb der Frist: Eine Sitzung mit `last_used_at = now() - interval '89 days'` und eine mit `now() - interval '90 days' + interval '1 minute'` liefern per `resolveSession` die Kontokennung. Test: „sitzungsablauf: innerhalb der frist gilt“.
- **AC-2:** Außerhalb der Frist: Sitzungen mit `last_used_at = now() - interval '91 days'` und `now() - interval '400 days'` liefern `null`. Test: „sitzungsablauf: abgelaufen ist null“.
- **AC-3:** Genau an der Grenze: Eine Sitzung mit `last_used_at = now() - interval '90 days'` liefert `null` (genau 90 Tage gelten als abgelaufen); eine Minute jünger (`now() - interval '90 days' + interval '1 minute'`) liefert die Kennung (eine Minute statt einer Sekunde, damit der Test auch unter Last nicht von der Zeit zwischen Setzen und Prüfen abhängt). Test: „sitzungsablauf: grenze genau 90 tage“.
- **AC-4:** Gleitend: Eine Sitzung mit `last_used_at = now() - interval '89 days'` wird aufgelöst und danach auf rund jetzt gesetzt (`last_used_at > now() - interval '1 minute'`); setzt der Test sie danach erneut auf `now() - interval '89 days'`, gilt sie wieder: die Frist beginnt nach jeder Benutzung neu. Test: „sitzungsablauf: benutzung verlaengert“.
- **AC-5:** Nicht wiederbelebt: Nach einem Aufruf mit einer abgelaufenen Sitzung (`null`) ist `last_used_at` der Zeile unverändert (Wert vor und nach dem Aufruf gleich) und die Zeile ist nicht gelöscht (`count(*)` bleibt 1); ein zweiter Aufruf liefert wieder `null`. Test: „sitzungsablauf: abgelaufene wird nicht belebt“.
- **AC-6:** Je Sitzung, nicht je Konto: Hat ein Konto zwei Sitzungen, eine abgelaufen (91 Tage), eine frisch, liefert der Aufruf mit dem Token der abgelaufenen Sitzung `null` und der Aufruf mit dem Token der frischen die Kennung des Kontos; der Aufruf mit der abgelaufenen lässt die frische unverändert gültig. Test: „sitzungsablauf: je sitzung“.
- **AC-7:** `endSession` auf eine abgelaufene Sitzung gibt `true` zurück und löscht die Zeile (`resolveSession` danach weiter `null`, keine Zeile mehr für diesen Token); ein zweiter Aufruf gibt `false`, ohne Ausnahme. Das Konto besteht weiter. Getestet wird nur diese Ebene (`accounts.ts`); für die Routen folgt daraus, ohne eigenen Routentest in diesem Schnitt (Ableitung): `POST /auth/logout` bleibt 204 (die Route wertet das Ergebnis von `endSession` nicht aus, bestehender Logout-Test aus 3b), `POST /auth/delete` mit abgelaufener Sitzung bekommt von `resolveSession` `null` und antwortet damit 401 (bestehender 401-Test aus 3c-1 für unbekannte Sitzung). Test: „sitzungsablauf: logout und delete mit abgelaufener sitzung“.
- **AC-8:** Regression: Der einzige bestehende Test, der eine feste Vergangenheit setzt (`AC-4/AC-5: resolveSession finds a valid session …`, `'2026-01-01T00:00:00Z'`, heute 311 Tage alt und damit abgelaufen), wird in genau zwei Zeilen angepasst: das Setzen auf `now() - interval '10 days'` und der Vergleich auf `last_used_at > now() - interval '1 minute'`; seine Aussage (Auflösen verlängert, andere Sitzung bleibt gültig, unbekannte Token `null`) bleibt unverändert. Alle anderen bestehenden Tests in `accounts.test.ts`, `auth.test.ts`, `main.test.ts` und allen weiteren Dateien bleiben unverändert grün; `git diff --numstat` zeigt in `server/test/` nur `accounts.test.ts` und dort außer den zwei angepassten Zeilen keine gelöschten Zeilen. `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf. Beleg: `./server/scripts/test-local.sh` grün; die Zeilenzahl der Anpassung belegt `/60-validate` einmalig per `git diff --numstat` im Validierungsprotokoll, nie als dauerhafter Test (ein Test gegen `origin/main` wäre im flachen CI-Checkout und nach dem Merge rot).
- **AC-9:** Keine Migration, keine Nebenwirkung: `server/migrations/` und das Schema sind unverändert (der Test `AC-1` aus S1 für die Migrationsliste bleibt grün); `resolveSession` schreibt nichts in die Konsole (S1-AC-12 grün). Test: der bestehende S1-AC-1 und S1-AC-12.
- **AC-10:** Grenze, Länge, Doku: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/accounts.ts`, `server/test/accounts.test.ts` und `CLAUDE.md`; `auth.ts` und alle weiteren `src/`-Dateien sind unverändert; jede Funktion in `accounts.ts` hat höchstens 50 Zeilen. Der `server/`-Absatz in `CLAUDE.md` nennt zu `src/accounts.ts` in einem Halbsatz: Sitzungen laufen gleitend ab (`SESSION_IDLE_DAYS` = 90 Tage ohne Nutzung, Grenze `>`, Zeit der Datenbank, abgelaufene Zeile unsichtbar und nicht belebt, kein Aufräumen, `endSession` ohne Fristprüfung). Beleg: einmalig in `/60-validate` im Validierungsprotokoll: `git diff --name-only` (Dateigrenze), Funktionslängen per Zählung der Zeilen von `export async function`/`function` bis zur zugehörigen schließenden `}` in Spalte 1 in `server/src/accounts.ts` (jede ≤ 50), `grep -n 'SESSION_IDLE_DAYS' CLAUDE.md` (genau ein Treffer, im `server/`-Absatz); kein dauerhafter Test.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/accounts.ts` | MODIFY | Konstante `SESSION_IDLE_DAYS`, `WHERE`-Bedingung in `resolveSession`, ≈ +5 |
| `server/test/accounts.test.ts` | MODIFY | neue Tests AC-1 bis AC-7, zwei angepasste Zeilen im bestehenden Test (AC-8), ≈ +70 |
| `CLAUDE.md` | MODIFY | ein Halbsatz im `server/`-Absatz zu `src/accounts.ts`, ≈ +2 |

### Estimated Changes

- **Files: 3** (Spec und Kontext zählen nicht). **LoC ≈ +80** (Code ≈ 5, Tests ≈ 70, Doku ≈ 2, davon 2 geänderte Testzeilen) und damit innerhalb des Limits von ±250.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, keine Migration, kein `generate`. Seiteneffekt: Im Betrieb gibt es heute keine App-Sitzung (die App ruft den Dienst nicht auf, nginx lässt `/auth/*` nicht durch), also meldet die Änderung niemanden ab.

## Risiken

- **Fester Zeitpunkt in einem bestehenden Test:** `'2026-01-01'` liegt in der Wirklichkeit längst jenseits der Frist; der Test würde mit der Änderung rot. Deshalb die ausdrückliche, kleine Anpassung in AC-8 (relativ statt fest); sie ändert die Aussage des Tests nicht und wird im Beleg benannt.
- **Zeitverhalten im Test:** `now()` ist die Transaktionszeit; die Tests rufen jede Anweisung einzeln auf (kein gemeinsames `BEGIN`), also liegt die Prüfung immer nach dem Setzen. Randfälle (AC-3) nutzen deshalb „genau 90 Tage“ für abgelaufen und „90 Tage minus eine Minute“ für gültig, nie einen Wert, der von Sekunden oder Millisekunden abhängt.
- **Tabelle wächst:** abgelaufene Zeilen bleiben stehen. Bei einem Konto und wenigen Geräten ohne Wirkung; ein späteres `DELETE … WHERE last_used_at <= now() - 90 days` (z. B. in `createSession`) ist ein Zusatz ohne Migration, wenn es je nötig wird.
- **Abmeldung ohne Vorwarnung:** Wer 90 Tage nicht die App öffnet, wird abgemeldet. Gewollt; die App (4b) verwirft die lokale Sitzung bei 401 und zeigt „Anmelden“.
- **Wechselwirkung mit 4d:** Erst mit Freigabe nach außen (nginx) entstehen echte Sitzungen; bis dahin ist die Änderung unsichtbar.

## Test Plan

### Automated Tests (TDD RED)

RED: Die neuen Tests AC-2, AC-3, AC-5 und AC-6 schlagen fehl, weil `resolveSession` heute jede Sitzung auflöst (abgelaufene liefern die Kennung statt `null`); AC-1, AC-4 und AC-7 sind schon grün und halten die Gegenrichtung fest (AC-7: `endSession` prüft keine Frist und bleibt so).

| Testname | AC |
|---|---|
| „sitzungsablauf: innerhalb der frist gilt“ | AC-1 |
| „sitzungsablauf: abgelaufen ist null“ | AC-2 |
| „sitzungsablauf: grenze genau 90 tage“ | AC-3 |
| „sitzungsablauf: benutzung verlaengert“ | AC-4 |
| „sitzungsablauf: abgelaufene wird nicht belebt“ | AC-5 |
| „sitzungsablauf: je sitzung“ | AC-6 |
| „sitzungsablauf: logout und delete mit abgelaufener sitzung“ | AC-7 |
| bestehende Tests (S1-AC-1, S1-AC-12 und alle übrigen) über `test-local.sh` | AC-8, AC-9 |
| kein Test: Validierungsbeleg in `/60-validate` (`git diff --name-only`, `git diff --numstat`, `grep` auf `CLAUDE.md`) | AC-8, AC-10 |

- [ ] Test 1 (AC-1, AC-2, AC-3): GIVEN Sitzungen mit `last_used_at` per SQL auf 89, 90 minus 1 Minute, genau 90, 91 und 400 Tage zurück WHEN `resolveSession` THEN Kennung bzw. `null`, genau 90 Tage ist `null`.
- [ ] Test 2 (AC-4, AC-5, AC-6): GIVEN eine Sitzung bei 89 Tagen, eine abgelaufene, eine frische desselben Kontos WHEN `resolveSession` THEN die Benutzung verlängert, die abgelaufene bleibt unverändert und stehen, die frische bleibt gültig.
- [ ] Test 3 (AC-7): GIVEN eine abgelaufene Sitzung WHEN `endSession` und `resolveSession` THEN `true`, Zeile weg, zweiter Aufruf `false`; das Konto besteht, `resolveSession` ist `null` (die Voraussetzung für 401 an `/auth/delete`).
- [ ] Test 4 (AC-8, AC-9): GIVEN die Gesamtläufe WHEN `./server/scripts/test-local.sh` THEN grün. Dateigrenze, zwei geänderte Testzeilen und `CLAUDE.md` (AC-8, AC-10) belegt `/60-validate` einmalig im Protokoll, nicht als Test.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **A (gewählt): gleitend 90 Tage in derselben `UPDATE`-Anweisung, Datenbankzeit, kein Aufräumen.** Kleinste Änderung, atomar, keine Migration; die Frist steht an einer Stelle.
- **B: fester Ablauf ab `created_at` (absolute timeout):** häufigere Abmeldung ohne Sicherheitsgewinn für einen Nutzer; verworfen, als spätere Ergänzung offen (siehe ADR).
- **C: Kombination gleitend und absolut:** mehr Regeln und mehr Tests ohne heutigen Nutzen; verworfen.
- **D: Frist im Node-Code mit `Date.now()` prüfen:** zwei Uhren, zwei Anweisungen, ein Zeitfenster zwischen Prüfung und Verlängerung; verworfen.
- **E: Abgelaufene Zeile beim Auflösen löschen (CTE oder zweite Anweisung):** CTE mit `UPDATE` und `DELETE` derselben Zeile ist in Postgres nicht definiert, eine zweite Anweisung macht den Leseweg zum Schreibweg; verworfen, kein Nutzen bei wenigen Zeilen.
- **F: Ablauf per Datenbank-Job (Cron) aufräumen:** neue Betriebsstelle für ein Problem, das es nicht gibt; verworfen.
- Befunde gegen den Plan: ein Befund, in AC-8 behandelt (fester Zeitpunkt im bestehenden Test).

## Nicht in diesem Schnitt / Folgeschnitte

- **4b App-Kern ohne Oberfläche:** `AccountState`, Nonce, `ServiceClient`, `SessionStore` (Keychain), Tests inkl. „ohne Anmeldung null Netzaufrufe“; 401 verwirft die lokale Sitzung. Kein `project.yml`, keine Stufe 3.
- **4c Einstellungen:** Gruppe „Konto“ mit Anmelden, Abmelden, Konto löschen (Bestätigung), Berechtigung „Mit Apple anmelden“ in `project.yml`, Texte de/en, UI-Test gegen Ersatz, hinter `LEAccountEnabled`; Entwurf der Gruppe vor der Spec (PO-Regel 2026-09-22); Stufe 3 über TestFlight.
- **4d Freigabe nach außen:** nginx genau `/auth/apple`, `/auth/logout`, `/auth/delete` mit eigener Limit-Zone, `APPLE_CLIENT_IDS` mit App- und Prüfbau-Kennung, Datenschutztext (Konto-Teil, Wortlaut Henning) auf der Website, dann `LEAccountEnabled` im Store-Bau an.
- Aufräumen abgelaufener Sitzungszeilen und ein absoluter Ablauf bleiben offen, bis sie einen Anlass haben.

## Abnahme

- Reine Dienständerung, keine Oberfläche, kein Simulator nötig. Nachweis: Server-Kette `./server/scripts/test-local.sh` (typecheck + `npm test` gegen ein Wegwerf-Postgres) grün und `server.yml` auf dem PR grün.
- Stufe 3 entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-10 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Absatz zu `src/accounts.ts`) nennt den gleitenden Ablauf
- [ ] #615 kommentiert (Stand Schnitt 4a, Merkposten „Sitzungsablauf“ entschieden: gleitend 90 Tage; Folge 4b), Board-Karte aktuell

## Changelog

- 2026-11-08: Initial spec created (Schnitt 4a)

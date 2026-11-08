# Adversary Dialog — feat-615-s4-app-anmeldung
Spec: docs/specs/feat-615-schnitt-4a-sitzungsablauf.md
Datum: 2026-11-08 20:37

## Checkliste
- [x] **AC-1:** Innerhalb der Frist: Eine Sitzung mit `last_used_at = now() - interval '89 days'` und eine mit `now() - interval '90 days' + interval '1 minute'` liefern per `resolveSession` die Kontokennung. Test: „sitzungsablauf: innerhalb der frist gilt“.
- [x] **AC-2:** Außerhalb der Frist: Sitzungen mit `last_used_at = now() - interval '91 days'` und `now() - interval '400 days'` liefern `null`. Test: „sitzungsablauf: abgelaufen ist null“.
- [x] **AC-3:** Genau an der Grenze: Eine Sitzung mit `last_used_at = now() - interval '90 days'` liefert `null` (genau 90 Tage gelten als abgelaufen); eine Minute jünger (`now() - interval '90 days' + interval '1 minute'`) liefert die Kennung (eine Minute statt einer Sekunde, damit der Test auch unter Last nicht von der Zeit zwischen Setzen und Prüfen abhängt). Test: „sitzungsablauf: grenze genau 90 tage“.
- [x] **AC-4:** Gleitend: Eine Sitzung mit `last_used_at = now() - interval '89 days'` wird aufgelöst und danach auf rund jetzt gesetzt (`last_used_at > now() - interval '1 minute'`); setzt der Test sie danach erneut auf `now() - interval '89 days'`, gilt sie wieder: die Frist beginnt nach jeder Benutzung neu. Test: „sitzungsablauf: benutzung verlaengert“.
- [x] **AC-5:** Nicht wiederbelebt: Nach einem Aufruf mit einer abgelaufenen Sitzung (`null`) ist `last_used_at` der Zeile unverändert (Wert vor und nach dem Aufruf gleich) und die Zeile ist nicht gelöscht (`count(*)` bleibt 1); ein zweiter Aufruf liefert wieder `null`. Test: „sitzungsablauf: abgelaufene wird nicht belebt“.
- [x] **AC-6:** Je Sitzung, nicht je Konto: Hat ein Konto zwei Sitzungen, eine abgelaufen (91 Tage), eine frisch, liefert der Aufruf mit dem Token der abgelaufenen Sitzung `null` und der Aufruf mit dem Token der frischen die Kennung des Kontos; der Aufruf mit der abgelaufenen lässt die frische unverändert gültig. Test: „sitzungsablauf: je sitzung“.
- [x] **AC-7:** `endSession` auf eine abgelaufene Sitzung gibt `true` zurück und löscht die Zeile (`resolveSession` danach weiter `null`, keine Zeile mehr für diesen Token); ein zweiter Aufruf gibt `false`, ohne Ausnahme. Das Konto besteht weiter. Getestet wird nur diese Ebene (`accounts.ts`); für die Routen folgt daraus, ohne eigenen Routentest in diesem Schnitt (Ableitung): `POST /auth/logout` bleibt 204 (die Route wertet das Ergebnis von `endSession` nicht aus, bestehender Logout-Test aus 3b), `POST /auth/delete` mit abgelaufener Sitzung bekommt von `resolveSession` `null` und antwortet damit 401 (bestehender 401-Test aus 3c-1 für unbekannte Sitzung). Test: „sitzungsablauf: logout und delete mit abgelaufener sitzung“.
- [x] **AC-8:** Regression: Der einzige bestehende Test, der eine feste Vergangenheit setzt (`AC-4/AC-5: resolveSession finds a valid session …`, `'2026-01-01T00:00:00Z'`, heute 311 Tage alt und damit abgelaufen), wird in genau zwei Zeilen angepasst: das Setzen auf `now() - interval '10 days'` und der Vergleich auf `last_used_at > now() - interval '1 minute'`; seine Aussage (Auflösen verlängert, andere Sitzung bleibt gültig, unbekannte Token `null`) bleibt unverändert. Alle anderen bestehenden Tests in `accounts.test.ts`, `auth.test.ts`, `main.test.ts` und allen weiteren Dateien bleiben unverändert grün; `git diff --numstat` zeigt in `server/test/` nur `accounts.test.ts` und dort außer den zwei angepassten Zeilen keine gelöschten Zeilen. `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf. Beleg: `./server/scripts/test-local.sh` grün; die Zeilenzahl der Anpassung belegt `/60-validate` einmalig per `git diff --numstat` im Validierungsprotokoll, nie als dauerhafter Test (ein Test gegen `origin/main` wäre im flachen CI-Checkout und nach dem Merge rot).
- [x] **AC-9:** Keine Migration, keine Nebenwirkung: `server/migrations/` und das Schema sind unverändert (der Test `AC-1` aus S1 für die Migrationsliste bleibt grün); `resolveSession` schreibt nichts in die Konsole (S1-AC-12 grün). Test: der bestehende S1-AC-1 und S1-AC-12.
- [x] **AC-10:** Grenze, Länge, Doku: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/accounts.ts`, `server/test/accounts.test.ts` und `CLAUDE.md`; `auth.ts` und alle weiteren `src/`-Dateien sind unverändert; jede Funktion in `accounts.ts` hat höchstens 50 Zeilen. Der `server/`-Absatz in `CLAUDE.md` nennt zu `src/accounts.ts` in einem Halbsatz: Sitzungen laufen gleitend ab (`SESSION_IDLE_DAYS` = 90 Tage ohne Nutzung, Grenze `>`, Zeit der Datenbank, abgelaufene Zeile unsichtbar und nicht belebt, kein Aufräumen, `endSession` ohne Fristprüfung). Beleg: einmalig in `/60-validate` im Validierungsprotokoll: `git diff --name-only` (Dateigrenze), Funktionslängen per Zählung der Zeilen von `export async function`/`function` bis zur zugehörigen schließenden `}` in Spalte 1 in `server/src/accounts.ts` (jede ≤ 50), `grep -n 'SESSION_IDLE_DAYS' CLAUDE.md` (genau ein Treffer, im `server/`-Absatz); kein dauerhafter Test.

## Dialog

### Runde 1
**Adversary:** Test-Suite selbst gefahren: `./server/scripts/test-local.sh` Exit 0, 387 pass, 0 fail, 0 skipped (adversary-test-output.txt). Angriffe:
- Parametertyp: `make_interval(days => $2)` mit JS-Zahl 90, pg sendet Text, Postgres leitet int ab; Tests laufen grün, kein Typfehler. Code reference: server/src/accounts.ts:83
- Leerer/Unsinns-Token: Guard `typeof token !== "string" || token === ""` bleibt vor der Query, unbekannter Hash trifft keine Zeile, `null`. Code reference: server/src/accounts.ts:81
- NULL: `last_used_at` ist `NOT NULL DEFAULT now()` (migrations/002_accounts.sql:17), NULL unmöglich. Zukünftiges last_used_at gilt als gültig (`>`) und wird auf now() gesetzt; nur per Handeingriff erreichbar, harmlos.
- Aufrufer: einziger Aufrufer außerhalb ist auth.ts:133 (/auth/delete), `null` ergibt dort die bekannte 401; endSession unverändert (accounts.ts:90-94). Code reference: server/test/accounts.test.ts:393
- AC-8 Hinweis 3: numstat gegen origin/main für server/test/ = `89 2 accounts.test.ts`; die gelöschten Zeilen sind genau die zwei geforderten (Setzen auf `now() - interval '10 days'`, Vergleich auf `now() - interval '1 minute'`). Code reference: server/test/accounts.test.ts:108
- AC-10: Dateigrenze genau CLAUDE.md, server/src/accounts.ts, server/test/accounts.test.ts; `grep -c SESSION_IDLE_DAYS CLAUDE.md` = 1 (server/-Absatz); längste Funktion deleteAccount 101-133 = 33 Zeilen.
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Gezielte Brüche:
- Hinweis 1 (aged-Klammer): ohne Klammer wäre `now() - interval '90 days' - interval '1 minute'` = 90d+1min (falsch-rot). Die Klammer `now() - (${age})` ist korrekt; der Test "grenze" prüft "90 days - 1 minute" = gültig und "90 days" = null. Code reference: server/test/accounts.test.ts:320. Der Helfer interpoliert nur Testkonstanten, keine Injektionsfläche.
- Hinweis 2 (`>` vs `>=`): Setzen und Prüfen sind getrennte Anweisungen mit getrenntem now(); bei der Prüfung liegt der Wert immer mikrosekundenweit mehr als 90 Tage zurück, daher unterscheidet kein Test `>` von `>=`. Die Spec beschreibt diesen Effekt im Abschnitt "Grenze" selbst; AC-3 verlangt "zuvor auf genau 90 Tage gesetzt = null" und "eine Minute jünger = gültig", beides erfüllt. Hinzunehmende Grenze, LOW (F001), kein Blocker.
- Nicht belebt: Zeile und Zeitstempel unverändert (before/after deepEqual). Code reference: server/test/accounts.test.ts:372
- Je Sitzung: nur token_hash in der WHERE-Bedingung, kein Konto-Bezug. Code reference: server/src/accounts.ts:83
- Race: Prüfung und Verlängerung sind eine UPDATE-Anweisung, kein Zeitfenster; parallele Aufrufe serialisiert die Zeilensperre.
- Stille: keine Konsolenausgabe; S1-AC-12 im Lauf grün.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: server/src/accounts.ts:83
  Description: Bedingung `last_used_at > now() - make_interval(days => $2)`; die Mutation `>` zu `>=` bleibt in allen Tests grün.
  Spec requirement: AC-3 — genau 90 Tage gelten als abgelaufen
  Conflict: Nur Testbarkeit (getrenntes now(), von der Spec selbst beschrieben); das Codeverhalten entspricht der Spec.
  Remediation: Keine nötig; optional später ein Test in einer Transaktion mit gemeinsamem now().

Confirmation:
  AC: AC-1
  Code reference: server/src/accounts.ts:83
  Evidence: 89 Tage und 90 Tage minus 1 Minute lösen auf; Test "innerhalb der frist gilt" grün (server/test/accounts.test.ts:339).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/test/accounts.test.ts:347
  Evidence: 91 und 400 Tage ergeben null; Mutation ohne Fristbedingung wurde rot (Orchestrator).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/test/accounts.test.ts:355
  Evidence: genau 90 Tage null, 90 Tage minus 1 Minute gültig; Grenze `>` im SQL; siehe F001.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/test/accounts.test.ts:365
  Evidence: nach Auflösen jünger als 1 Minute; nach erneutem Altern auf 89 Tage gilt sie wieder.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: server/test/accounts.test.ts:372
  Evidence: Zeile und Zeitstempel unverändert, zweiter Aufruf null.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/test/accounts.test.ts:382
  Evidence: alte null, frische gültig, ohne gegenseitigen Einfluss.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/test/accounts.test.ts:393
  Evidence: endSession true, Zeile weg, resolve null, zweiter Aufruf false, Konto besteht; endSession ohne Fristprüfung (accounts.ts:90-94).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/test/accounts.test.ts:108
  Evidence: numstat 89/2, nur die zwei geforderten Zeilen gelöscht; Testlauf Exit 0, 387 pass, 0 fail, 0 skipped.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: server/src/accounts.ts:80
  Evidence: keine Migration in der Änderungsliste, keine Konsolenausgabe; S1-AC-1 und S1-AC-12 im Lauf grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: server/src/accounts.ts:75
  Evidence: Dateigrenze exakt drei Dateien; ein Treffer SESSION_IDLE_DAYS in CLAUDE.md mit allen geforderten Stichworten; längste Funktion 33 Zeilen.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: 387 passed, 0 failed, 0 übersprungen (Exit 0)
Edge cases: geprüft, keine gebrochen (F001 LOW, Hinweis)
Regressions: keine
Checklist: 10/10 points proven

## Geprüfte Dateien

- sha256:b59036c16af390ce5989f8c96ed59e0920a67a5f2e230966b9e8de2277fa2c4a  server/src/accounts.ts
- sha256:d8cd5a26eaedc93a90ef53fe25ff6c066689bddf911f434b2a7e468e39d753af  server/test/accounts.test.ts

## Prüfbasis

- base: 472ac7edaffc87c5c890b59237de2b0b5a1a6568
- blob:f9021c555938739c3e82db44da2dbe87476941f7  server/src/accounts.ts
- blob:86fa7bf861cb33d230965a8813c941a30393ada8  server/test/accounts.test.ts

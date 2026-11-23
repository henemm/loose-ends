# Adversary Dialog — feat-625-konto-schalter
Spec: docs/specs/feat-625-schnitt-5a-offene-tuer.md
Datum: 2026-11-22 07:49

## Checkliste
- [x] **AC-1:** Offen legt neue Konten an: GIVEN die Tür `{ open: true, perDay: 3 }` und leere Tabelle WHEN `admit` für drei verschiedene `sub`s nacheinander läuft THEN ergibt jeder eine Konto-ID und `accounts` hat genau drei Zeilen. Test: `server/test/accounts.test.ts` „tuer offen: neue konten bis zur grenze“.
- [x] **AC-2:** Bestandskonten kommen immer herein: GIVEN drei Konten, Tür `{ open: true, perDay: 3 }` (Grenze erreicht) WHEN `admit` für eine vorhandene `sub` läuft THEN ergibt es deren ID, ohne zweite Zeile; WHEN `admit` für eine vierte, neue `sub` läuft THEN `null`. Test: „tuer offen: bestandskonto ueber der grenze kommt herein“.
- [x] **AC-3:** Ablehnung schreibt nichts: GIVEN Grenze erreicht WHEN `admit` für eine neue `sub` `null` ergibt THEN sind `accounts` unverändert (gleiche Zeilenzahl, keine Zeile für die `sub`), und derselbe Client bleibt für den nächsten Aufruf nutzbar (kein hängendes `BEGIN`, Pool nach dem Lauf vollständig frei). Test: „tuer offen: ablehnung schreibt nichts und gibt die verbindung frei“.
- [x] **AC-4:** Gleitendes 24-Stunden-Fenster nach Datenbankzeit: GIVEN Tür `{ open: true, perDay: 2 }` und zwei Konten, deren `created_at` per `UPDATE` auf 25 Stunden zurückliegt WHEN eine neue `sub` kommt THEN wird sie angelegt (alte Konten zählen nicht); GIVEN danach zwei Konten innerhalb der letzten 23 Stunden WHEN eine weitere neue `sub` kommt THEN `null`; WHEN die beiden Konten auf 25 Stunden zurückdatiert werden THEN wird die nächste neue `sub` wieder angelegt. Test: „tuer offen: gleitendes fenster von 24 stunden“.
- [x] **AC-5:** Nebenläufigkeit hält die Grenze genau: GIVEN Tür `{ open: true, perDay: 5 }` und leere Tabelle WHEN zwölf `admit`-Aufrufe mit zwölf verschiedenen neuen `sub`s gleichzeitig laufen (`Promise.all`, Pool mit mindestens zwölf Verbindungen) THEN sind genau fünf Ergebnisse eine ID, sieben `null`, und `accounts` hat genau fünf Zeilen; WHEN dieselbe neue `sub` achtmal gleichzeitig kommt THEN ergeben alle dieselbe ID, eine Zeile. Test: „tuer offen: gleichzeitige neue konten ergeben genau die grenze“.
- [x] **AC-6:** Liste und „erstes Konto“ bleiben unverändert: GIVEN die bestehenden Tests von S6a (`admit` mit Liste, `admit` ohne Tür, `findOrCreate`-Helfer) WHEN der Gesamtlauf läuft THEN sind sie in Aussage und Prüfungen unverändert grün (angepasst wird nur der Name der Lesefunktion `allowedSubsFromEnv` zu `doorFromEnv` und die Meldung in `main.test.ts`). Test: Gesamtlauf `./server/scripts/test-local.sh`.
- [x] **AC-7:** `doorFromEnv` liest streng und nennt nie den Wert: GIVEN die Fälle WHEN `doorFromEnv` läuft THEN gilt: beide Variablen fehlen oder leer → `undefined`; `ALLOWED_APPLE_SUBS="a, b ,c"` → Menge `{a, b, c}`; `"*"` und `" * "` ohne Grenze → `{ open: true, perDay: 20 }`; `"*"` mit `NEW_ACCOUNTS_PER_DAY=7` → `perDay: 7`; `NEW_ACCOUNTS_PER_DAY` leer → 20; Fehler `NEW_ACCOUNTS_PER_DAY` bei `0`, `-1`, `1.5`, `abc`, `10001`, `1e2`, `" 5x"`; Fehler `ALLOWED_APPLE_SUBS` bei `"*,a"`, `"a,*"`, `"a,,b"`, `"a,"`, `","`; Fehler `NEW_ACCOUNTS_PER_DAY` bei gesetzter Grenze ohne `*` (leere Liste, Liste oder `*` fehlt); jede Fehlermeldung ist genau der Variablenname und enthält keinen Teil des Werts. Test: „tuer: doorFromEnv liest streng und nennt nie den wert“.
- [x] **AC-8:** Ein ungültiger Wert stoppt den Prozess vor Pool und Port: GIVEN der gestartete Prozess (`main.ts`, Muster der Start-Tests) mit `ALLOWED_APPLE_SUBS=sub-a,,sub-geheim-4711` WHEN er startet THEN Exit 1, die Ausgabe enthält `door invalid: ALLOWED_APPLE_SUBS`, weder `sub-geheim-4711` noch `sub-a`, und keinen offenen Port; GIVEN `ALLOWED_APPLE_SUBS=*` und `NEW_ACCOUNTS_PER_DAY=zwanzig` THEN Exit 1 mit `door invalid: NEW_ACCOUNTS_PER_DAY` ohne den Wert. Test: `server/test/main.test.ts` „start: ungueltige tuer stoppt vor pool und port, ohne den wert zu nennen“ (ersetzt den Test mit der alten Meldung).
- [x] **AC-9:** Die offene Tür gilt für die App über `POST /auth/apple`: GIVEN `authRoutes` mit Fake-Apple und der Tür `{ open: true, perDay: 1 }` WHEN eine fremde `sub` anmeldet THEN 200 mit Sitzungstoken und ein Konto; WHEN eine zweite, andere `sub` anmeldet (Grenze erreicht) THEN ein bares 401 (leerer Körper, `no-store`), keine Zeile in `accounts`, `sessions` und `apple_tokens` für sie, das Protokoll genau `["account refused"]`, die `sub` in keiner Antwort und keiner Zeile; WHEN die erste `sub` nochmals anmeldet THEN 200. Test: `server/test/auth.test.ts` „auth: offene tuer, fremde sub kommt herein, an der grenze 401“.
- [x] **AC-10:** Die offene Tür gilt für den claude.ai-Rückweg: GIVEN der Rückweg (`service` über `start`, Fake-Apple, `through`) mit der Tür `{ open: true, perDay: 1 }` WHEN eine erste `sub` den Weg durchläuft THEN trägt das Ticket eine Konto-ID und das Web-Token ist abgelegt; WHEN eine zweite `sub` ihn durchläuft THEN antwortet er 303 auf `finish`, das Ticket ist `{ uid, error: "access_denied" }` mit `account_id` NULL, es gibt kein zweites Konto, kein abgelegtes Web-Token für sie, das Protokoll enthält genau `account refused` ohne `sub` oder Konto-ID. Test: `server/test/oauth-return.test.ts` „rueckweg: offene tuer, grenze ergibt access_denied ohne konto und ohne token“.
- [x] **AC-11:** Gesamtlauf: GIVEN der fertige Schnitt WHEN `./server/scripts/test-local.sh` (typecheck + alle Tests) läuft THEN ist er grün und räumt auf, ohne neue Abhängigkeit in `server/package.json` und ohne neue Migration; die CI `server.yml` ist auf dem PR grün (Beleg `green.txt`). Funktionslänge (höchstens 50 Zeilen) und Dateiliste belegt `/60-validate`, nicht ein Test.
- [x] **AC-12:** Ausgerollt mit unveränderter Betriebs-Tür: GIVEN der Merge-Commit WHEN `scripts/deploy-loose-ends.sh` (henemm-infra) auf rennwienix an genau diesem Commit läuft, die `.env` unverändert (Liste bleibt gesetzt, `NEW_ACCOUNTS_PER_DAY` nicht gesetzt) THEN antwortet `/health` mit 200, und Hennings Konto kommt weiter herein, belegt durch einen Aufruf von `get_now` über den claude.ai-Konnektor, der eine Antwort mit `nowCount` liefert. Der Beleg (`rollout.txt`: Commit-Kennung, `/health`-Status, Satz zur `get_now`-Antwort ohne `sub`, Token oder Listeninhalt) liegt im Belegordner.
- [x] **AC-13:** Dokumentation: GIVEN `CLAUDE.md` WHEN der `server/`-Abschnitt, Absatz `src/accounts.ts`, gelesen wird THEN beschreibt er `admit` mit den drei Zweigen (Liste, erstes Konto, offen mit Tagesgrenze), `doorFromEnv` mit `*` und `NEW_ACCOUNTS_PER_DAY` (Vorgabe 20, 24 Stunden gleitend, Bestandskonten nie abgewiesen, gelöschtes Konto zählt nicht mehr), die Meldung `door invalid: <VARIABLE>`, und der Satz „the rule goes with #625“ ist durch den Stand ersetzt; die Grundregel „The service is open to every Apple account …“ steht weiter im Abschnitt „Ground rules“ (Beleg: Lesen, Diff).

## Dialog

### Runde 1
**Adversary:** Gesamtlauf `./server/scripts/test-local.sh` (Beleg `adversary-test-output-run1-flake.txt`): Exit 1, 511 bestanden, 1 fehlgeschlagen: `einhaengen: allein gesetzte web-id bricht start ab` (main.test.ts:514, Prozess beendet sich nicht innerhalb 5 s, `'late' !== 1`). Das ist ein Test zu `APPLE_WEB_CLIENT_ID`, nicht zur Tür. Einzellauf nicht möglich (braucht DATABASE_URL). Zwei weitere Gesamtläufe: Exit 0, 512 bestanden, 0 fehlgeschlagen, 0 übersprungen (Beleg `adversary-test-output.txt`). Einstufung: Zeitüberschreitung beim Prozessstart, nicht reproduzierbar. Trotzdem Finding F001.
Code gelesen: `admitOpen` (BEGIN, Advisory-Lock, SELECT vorhanden, Zählung `created_at > now() - interval '24 hours'`, ROLLBACK bei Grenze, INSERT, COMMIT; catch: ROLLBACK + Wurf; finally release). Sperre ist dieselbe `ACCOUNT_LOCK_ID` wie `admitFirst`; unter ihr ist Zählen+Anlegen atomar, AC-5 belegt zwölf Läufer. `"open" in door` auf einem Set ist false, korrekt. Liste und „erstes Konto“ unverändert (Diff nur Umbenennung und Typ). Der Kommentar nennt, dass ein gelöschtes Konto nicht mehr zählt.
Fragen: (a) Was, wenn ROLLBACK selbst wirft (tote Verbindung)? (b) Leerraum-Werte der Grenze?
**Implementierer:** (a) Gleiches Muster wie vorhandenes `admitFirst`; ein Wurf im catch maskiert den Urfehler. Kein neuer Defekt, Finding F002 LOW. (b) Strenge Ziffernprüfung.

### Runde 2
**Adversary:** `doorFromEnv` direkt mit Grenzfällen gefahren: `*`+`" 5 "` → Fehler `NEW_ACCOUNTS_PER_DAY` (Spec: „nur Ziffern“, also streng, schlägt zu, öffnet nie); `"007"` → 7; 400 Neunen → Fehler; Zeilenumbruch+5 → Fehler; `" * "` und `*`+`" "` → 20; `*,a` → `ALLOWED_APPLE_SUBS`; leer+`5` und `a`+`5` → `NEW_ACCOUNTS_PER_DAY`; 10000 ok, 10001 Fehler. Jede Fehlermeldung ist genau der Variablenname, `error.stack` ist `Error: <NAME>` ohne Frames (Helfer `invalid`). `main.ts` schreibt `door invalid: ${message}`; Test (main.test.ts:550) prüft beide Fälle, kein Wert, kein Pool, kein Port; im Gesamtlauf grün. Beide Anmeldewege: auth.test.ts:152 (200, dann 401, Protokoll `["account refused"]`, erneut 200) und oauth-return.test.ts:577 (`access_denied`, kein Konto, kein Token) im Gesamtlauf grün. CLAUDE.md-Absatz nennt drei Zweige, `*`, `NEW_ACCOUNTS_PER_DAY` (20, 1–10000, 24 h gleitend, Bestand nie abgewiesen, gelöscht zählt nicht), `door invalid: <VARIABLE>`; „the rule goes with #625“ kommt nicht mehr vor; Grundregel in „Ground rules“ (Zeile 73) steht. ADR-21-Nachtrag eine Zeile vorhanden. Keine Änderung an package.json und Migrationen. Offen: AC-11 (CI `server.yml`, Beleg heißt `test-green-output.txt`, nicht `green.txt`) und AC-12 (Rollout) sind vor dem Commit nicht belegbar.
**Implementierer:** Beides ist nachgelagert (PR, CI, Rollout); lokal nichts offen.

### Runde 3
**Adversary:** AC-11: `gh pr view 983` liefert Kopf `da010c3fd979beedebb1d25a1529a4be7e2a8852`, Check „Server (Node 26, Postgres 18)“ SUCCESS (auch „Image (Docker, Postgres 18)“ und alle weiteren Checks in `green.txt` SUCCESS, `green.txt` nennt denselben Kopf). `git diff da010c3 bf1fccf -- server` ist leer, der Squash-Commit `bf1fccf` trägt also denselben Server-Stand wie der geprüfte PR-Kopf (der Rest des Gesamtdiffs ist Drift von `main`, Merge-Basis 47a0273). `git diff bf1fccf^ bf1fccf -- server/package.json server/migrations` leer: keine neue Abhängigkeit, keine Migration. F001 (ein roter Lokallauf von drei): die CI auf dem PR-Kopf war grün, der Fehler trat nicht wieder auf; er hängt nicht an der Tür, F001 bleibt als Hinweis ohne Blockade. AC-12: `rollout.txt` nennt `bf1fccf03ac88993752cb1aabf7db645728af7f0`, Deploy Exit 0, Betriebs-Umgebung unverändert (Liste, kein `*`, Grenze nicht gesetzt), `/health` intern und öffentlich 200, `get_now`-Satz. Selbst geprüft: `curl https://loose-ends.henemm.com/health` ergibt 200 `{"status":"ok","db":"up","migrated":true,...}`; `docker inspect loose-ends-server` ergibt `loose-ends-server:bf1fccf running`. Die Umgebungsdatei des Servers habe ich nicht gelesen. `rollout.txt` enthält weder `sub` noch Token noch Listeninhalt (Durchsicht und Mustersuche ohne Treffer). `get_now` über den claude.ai-Konnektor (Orchestrator, nach dem Rollout): Antwort mit `nowCount` 1, `generatedAt` 2026-11-22T15:47:43Z; das belegt, dass die Bearer-Prüfung auf dem neuen Image Hennings Konto weiter durchlässt. Einschränkung: den Aufruf selbst konnte ich nicht wiederholen, ich stütze mich auf die Angabe des Orchestrators; Image, Gesundheit und Beleg sind unabhängig geprüft.
**Implementierer:** Nichts offen.

## Findings

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: server/src/main.ts:264
  Description: Beim ersten Gesamtlauf schlug der Prozessstart-Test `einhaengen: allein gesetzte web-id bricht start ab` mit Zeitüberschreitung (5 s) fehl; zwei Wiederholungen grün. Der Test startet `main.ts` als Kindprozess; der Code um `allowedSubsOrExit` läuft dabei vor der Apple-Konfiguration.
  Spec requirement: AC-11 — Gesamtlauf grün
  Conflict: Ein roter Lauf zählt; Ursache am Schnitt nicht nachgewiesen (vermutlich Start-Latenz), aber die CI muss grün sein.
  Remediation: In der CI beobachten; bei Wiederholung die 5-s-Grenze des Tests prüfen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: server/src/accounts.ts:55
  Description: Der catch-Zweig von `admitOpen` ruft `ROLLBACK` ohne eigenen Schutz; wirft dieses, geht der Urfehler verloren. Gleiches Muster wie `admitFirst`.
  Spec requirement: AC-3 — Jeder Fehler: ROLLBACK, Client freigeben, Wurf weiter
  Conflict: Nur bei toter Verbindung; Ergebnis bleibt ein Wurf, die Tür öffnet nie.
  Remediation: Optional ROLLBACK mit abgefangenem Fehler in beiden Funktionen, außerhalb dieses Schnitts.

## Confirmations

Confirmation:
  AC: AC-1, AC-2, AC-3, AC-4, AC-5
  Code reference: server/src/accounts.ts:37
  Evidence: `admitOpen` unter Advisory-Lock: vorhandene sub zuerst, dann Zählung im 24-h-Fenster nach DB-Zeit, ROLLBACK ohne Schreiben an der Grenze; Tests „tuer offen: …“ (accounts.test.ts:326-381) im Gesamtlauf grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-6, AC-7
  Code reference: server/src/accounts.ts:100
  Evidence: `doorFromEnv` per Direktaufruf mit allen Grenzfällen geprüft, Fehler nennen nur den Variablennamen, Stack ohne Frames; S6a-Tests unverändert grün (512/512).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/src/main.ts:264
  Evidence: `door invalid: <VARIABLE>` aus `error.message`, Exit 1 vor Pool und Port; Test main.test.ts:550 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: server/src/auth.ts:12
  Evidence: `AuthDeps.allowedSubs?: Door` reicht die offene Tür an `admit`; Test auth.test.ts:152 grün (200, 401, `["account refused"]`, 200).
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: server/src/oauth-return.ts:15
  Evidence: `AppleReturnDeps.allowedSubs?: Door`; Test oauth-return.test.ts:577 grün (`access_denied`, kein Konto, kein Token).
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: server/src/accounts.ts:20
  Evidence: CLAUDE.md-Absatz und ADR-21-Nachtrag im Diff gelesen, alle geforderten Inhalte vorhanden, Satz „the rule goes with #625“ entfernt, Grundregel Zeile 73 erhalten.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: server/src/main.ts:264
  Evidence: CI-Check „Server (Node 26, Postgres 18)“ SUCCESS auf PR-Kopf da010c3 (gh pr view, green.txt); `git diff da010c3 bf1fccf -- server` leer, `server/package.json` und `server/migrations/` im Merge-Commit unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: server/src/accounts.ts:100
  Evidence: `/health` öffentlich 200 ok migrated, Container `loose-ends-server:bf1fccf running`, rollout.txt ohne sub/Token/Listeninhalt, Betriebs-Umgebung unverändert laut Beleg; `get_now` über den Konnektor lieferte nowCount (Angabe des Orchestrators).
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Alle 13 Punkte belegt; AC-11 (CI grün auf dem PR-Kopf, Server-Stand im Merge identisch, keine neue Abhängigkeit oder Migration) und AC-12 (Rollout bf1fccf, /health 200, Image läuft, get_now über den Konnektor) in Runde 3 ergänzt. F001 war ein einmaliger Lokal-Flake, die CI blieb grün.
Tests: 512 bestanden, 0 fehlgeschlagen, 0 übersprungen (Läufe 2 und 3); Lauf 1: 511 bestanden, 1 fehlgeschlagen.

## Geprüfte Dateien

- sha256:13716c2c141125a114c807c75f43aed71a81e5e98cf4ae7414e2ae66822aa92b  server/src/accounts.ts
- sha256:03256ec7a50a1ca52cbd591a1aa8d11b627f38b101dded6b8a9acaaab2765581  server/src/auth.ts
- sha256:50daaaf94a8ad2d59e6d14314d87d90fb0affd95ea6de9a50b823694ab709bdc  server/src/main.ts
- sha256:7da0438f6ccfcdd2767ab0b6f4da1bc8f9d9f0ea9b6624432178472b8cb5ee2a  server/src/oauth-return.ts

## Prüfbasis

- base: bf1fccf03ac88993752cb1aabf7db645728af7f0
- blob:2b2fc88c6853ee3cfd397985417733b14f15cb55  server/src/accounts.ts
- blob:7f59a02216e48a1e1cd89c63288e881bac0d1b0f  server/src/auth.ts
- blob:6650a6fc22ef0131ed3545a3c573270c43769a56  server/src/main.ts
- blob:fed831ee766eb36c8ae803a7d817091bc239343a  server/src/oauth-return.ts

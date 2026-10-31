# Adversary Dialog — spike-613-c1-server-geruest
Spec: docs/specs/spike-613-schnitt-c1a-server-geruest.md
Datum: 2026-10-31 19:34

## Checkliste
- [x] **AC-1:** `migrate` wendet die Migrationen eines Ordners in Nummernfolge an (nicht in Dateisystem- oder Einfügereihenfolge) und liefert die angewandten Namen in dieser Folge zurück. Belegt durch `server/test/migrate.test.ts` (Fixture-Ordner mit drei Dateien, Namen werden bewusst unsortiert angelegt; Ergebnis `001`, `002`, `003`; die von Migration 002 angelegte Tabelle sieht die Migration 003).
- [x] **AC-2:** Ein zweiter Lauf auf derselben Datenbank wendet nichts an (leere Rückgabe) und ändert nichts; `schema_migrations` hat danach genau eine Zeile je Datei. Kommt eine neue Datei hinzu, wird nur sie angewandt. Belegt durch `migrate.test.ts` (zweiter Lauf, dann Ordner mit zusätzlicher vierter Datei).
- [x] **AC-3:** Eine kaputte Migration (SQL-Fehler nach einer gültigen Anweisung in derselben Datei) rollt vollständig zurück: die gültige Anweisung hinterlässt keine Tabelle, die Migration steht nicht in `schema_migrations`, frühere gültige Migrationen bleiben angewandt, und `migrate` wirft den ursprünglichen Postgres-Fehler weiter (Test prüft Fehlercode bzw. Meldung, nicht nur „wirft“). Belegt durch `migrate.test.ts`.
- [x] **AC-4:** Eine Lücke in der Nummernfolge (`001`, `003`) und eine doppelte Nummer (`002_a.sql`, `002_b.sql`) werden mit eindeutiger Fehlermeldung abgelehnt, bevor irgendeine Migration angewandt wird (Tabelle `schema_migrations` bleibt leer bzw. unverändert). Belegt durch `migrate.test.ts` (zwei Fälle).
- [x] **AC-5:** Die Tests laufen gegen echtes Postgres über `DATABASE_URL`. Fehlt die Variable, **schlägt** der Test fehl (mit Meldung, die `DATABASE_URL` nennt); er wird nie übersprungen (`skip`/`todo` kommen im Test nicht vor). Jeder Test nutzt ein eigenes frisches Schema oder eine frische Datenbank, so dass Läufe sich nicht beeinflussen. Belegt durch `migrate.test.ts` (ein Test, der den Fall ohne Variable in einem Kindprozess ausführt, erwartet Exit-Code ≠ 0) und durch Durchsicht auf `skip`.
- [x] **AC-6:** `npm run typecheck` (`tsc --noEmit` mit `strict`, `erasableSyntaxOnly`, `verbatimModuleSyntax`, `allowImportingTsExtensions`) läuft in `server/` ohne Fehler; der Code verwendet nur Syntax, die Node 26 per Typ-Entfernung ausführt (kein `enum`, kein `namespace`, keine Parameter-Properties), kein `any` ohne Begründung, kein `catch`, der den Fehler verschluckt. Belegt durch den Typprüflauf und `npm test` (Node führt die `.ts`-Dateien direkt aus, ohne Build-Schritt).
- [x] **AC-7:** `./server/scripts/test-local.sh` startet ein Wegwerf-Postgres (temporärer Datenordner, freier Port, kein Eingriff in vorhandene Postgres-Dienste), setzt `DATABASE_URL`, führt Typprüfung und Tests aus, gibt deren Exit-Code zurück und räumt in jedem Fall auf (Server gestoppt, Datenordner gelöscht, auch bei roten Tests). Belegt durch einen Lauf grün und einen Lauf mit absichtlich rotem Test, jeweils danach `pg_ctl`-Prozess und Ordner weg.
- [ ] **AC-8:** `.github/workflows/server.yml` läuft auf `ubuntu-latest` mit Dienstcontainer `postgres:18` (`pg_isready`-Healthcheck, `DATABASE_URL` auf `127.0.0.1:5432`), `actions/setup-node` mit Node 26, `npm ci`, `npm run typecheck`, `npm test`. Pfadfilter `server/**` und der Workflow selbst; `main` hat keinen Branchschutz, ein nicht gestarteter Lauf blockiert also keinen PR. Belegt durch einen grünen Lauf des Workflows auf dem PR und `python3 -m unittest discover -s scripts` (insbesondere `test_ci_xcode27.py` bleibt grün, es prüft nur `ci.yml` und `speech-stress.yml`).
- [x] **AC-9:** `server/package-lock.json` ist eingecheckt und passt zu `package.json` (`npm ci` läuft ohne Änderung); `package.json` hat `"type": "module"`, `engines.node` `>=26` und exakt die Abhängigkeiten aus der Tabelle oben. `.gitignore` enthält `node_modules/`; `git status` zeigt nach `npm ci` keine unversionierten Dateien in `server/`. Belegt durch `npm ci`, `git status` und Durchsicht der `package.json`.
- [x] **AC-10:** `CLAUDE.md` nennt `server/` unter „Where things live“ (Zweck, Läufer, Regel „Schema nur als nummerierte Migrationen, ab dem Betrieb nur ergänzen“) und die Befehle (`./server/scripts/test-local.sh`, `npm run typecheck`, `npm test`) unter „Build“. Die App, das Xcode-Projekt (`project.yml`) und die bestehenden CI-Jobs sind unverändert. Belegt durch Diff-Durchsicht: Die Dateiliste des PR enthält außer den unter Scope genannten nichts.

## Dialog

### Runde 1
**Adversary:**
- Gesamtkette `./server/scripts/test-local.sh` selbst gefahren (Ausgabe: docs/artifacts/spike-613-c1-server-geruest/adversary-test-output.txt): Exit 0, typecheck ohne Fehler, 6 Tests bestanden, 0 fehlgeschlagen, 0 skipped, 0 todo. Danach kein Postgres-Prozess (vorher auch keiner, also kein fremder Dienst berührt).
- AC-1: 
Code reference: server/src/migrate.ts:20 (Sortierung nach Nummer), server/test/migrate.test.ts:50 (Fixture bewusst unsortiert, 003 benutzt Tabelle aus 002) und :56. PROVEN.
- AC-2: 
Code reference: server/src/migrate.ts:55 (done-Menge aus schema_migrations, Zeile 59 überspringt), server/test/migrate.test.ts:67. PROVEN.
- AC-3: 
Code reference: server/src/migrate.ts:41 (catch mit ROLLBACK und throw error, Fehler unverändert). Test prüft Code 42P01 und Meldung (server/test/migrate.test.ts:81), Rollback der gültigen ersten Anweisung (kept_out fehlt), 001 bleibt. PROVEN.
- AC-4: 
Code reference: server/src/migrate.ts:21 (Prüfung in loadMigrations vor jedem DB-Zugriff; Zeile 52 legt die Tabelle erst danach an). Test server/test/migrate.test.ts:100 und :113 prüft sogar, dass schema_migrations nicht existiert. PROVEN.
- AC-5 Kontrollversuch: ohne `delete env.NODE_TEST_CONTEXT` (Zeile 131) liefert `NODE_TEST_CONTEXT=child-v8 node --test test/migrate.test.ts` ohne DATABASE_URL Exit 0 und nur die Warnung "run() is being called recursively ... skipping running files": der Fehlfall würde also nicht erkannt. Mit der Zeile liefert das Kind Exit 1 (Direktlauf ohne Variable: Exit 1). Die Zeile ist notwendig und korrekt; der Test prüft zusätzlich `/DATABASE_URL/` in der Ausgabe (Zeile 135), also kein Falsch-Positiv durch andere Ursachen. 
Code reference: server/test/migrate.test.ts:131
Durchsicht auf skip/todo: keine Treffer in Test und Quelle. Frisches Schema je Test: server/test/migrate.test.ts:18. PROVEN.
- AC-6: 
Code reference: server/package.json:9 (`tsc --noEmit`) und server/tsconfig.json:6-10 (alle fünf Optionen). Typprüfung grün; grep auf enum/namespace/any/skip ohne Code-Treffer; Tests laufen direkt als .ts. PROVEN.
- AC-7: 
Code reference: server/scripts/test-local.sh:10-14 (trap EXIT, pg_ctl stop, rm -rf), :8 (freier Port per bind auf 0), :18-19 (nur TCP, listen_addresses=127.0.0.1), :22 (DATABASE_URL), :25-26 (set -e gibt Exit-Code weiter). Eigener grüner Lauf: danach keine Postgres-Prozesse. Beleg des Implementierers für den roten Lauf (test-local-red-cleanup.txt: Exit 1, Prozess und Ordner weg) geprüft und schlüssig. PROVEN.
- AC-8 (Teilbeleg): 
Code reference: .github/workflows/server.yml:18 (ubuntu-latest), :21 (postgres:18), :27 (pg_isready), :38 (Node 26), :41-43 (npm ci, typecheck, test), :45 (127.0.0.1:5432), :6-13 (Pfadfilter server/** und Workflow selbst). YAML lädt fehlerfrei. Skript-Tests: Beleg scripts-unittest.txt endet mit OK; mein eigener Lauf überschritt das Zeitfenster der Sitzung und wurde nicht zu Ende abgewartet. OFFEN: grüner Lauf auf dem PR (vor dem Commit nicht möglich); Aktionsversionen `actions/checkout@v7` und `setup-node@v7` sind nicht vor Ort prüfbar, erst der Lauf zeigt, ob es sie gibt. Nicht belegt, daher Haken offen.
- AC-9: 
Code reference: server/package.json:4 (type module), :6 (node >=26), :13-20 (exakt pg 8.23.1, typescript 7.0.2, @types/pg 8.23.1, @types/node 26.6.6); `npm ls` bestätigt die Versionen; Lockfile im Diff gegen die Basis vorhanden; .gitignore enthält `node_modules/`; keine unversionierten Dateien in server/. PROVEN.
- AC-10: 
Code reference: CLAUDE.md:76 (Build-Absatz mit Befehl test-local.sh, typecheck, test) und CLAUDE.md:442 (Where-things-live-Eintrag mit Regel "only ever added"). Dateiliste im Diff gegen die Basis: nur Spec-Dateien, server/, Workflow, CLAUDE.md, .gitignore, Artefakte; `project.yml` und `ci.yml` nicht berührt. PROVEN.
**Implementierer:**

### Runde 2
**Adversary:** Gezielte Angriffe mit Wegwerf-Skript (Scratchpad, eigenes Postgres auf Port 55432, danach gestoppt und gelöscht):
- Leerer Ordner: Rückgabe [], kein Fehler (korrekt). Datei ohne Inhalt: wird angewandt und eingetragen (korrekt).
- F001: Dateien, die nicht auf `^\d{3}_.+\.sql$` passen (`1_b.sql`, `01_x.sql`, `002_b.SQL`, README.md), werden stillschweigend ignoriert. Eine falsch benannte Migration wird nie angewandt und nirgends gemeldet. 
Code reference: server/src/migrate.ts:7
- F002: Nummer 000 wird als "Migrationsnummer doppelt" gemeldet, obwohl nichts doppelt ist (irreführende Meldung, Ablehnung selbst korrekt). 
Code reference: server/src/migrate.ts:23
- F003: Schlägt ROLLBACK selbst fehl (Verbindung weg), ersetzt dessen Fehler den ursprünglichen und die Ursache geht verloren; AC-3 verlangt unveränderte Weitergabe nur für den Normalfall. Nicht per Test auslösbar ohne Verbindungsabbruch, aus dem Code ersichtlich. 
Code reference: server/src/migrate.ts:42
- F004: Zwei gleichzeitige `migrate`-Läufe: der zweite scheitert mit rohem Postgres-Fehler (pg_type_typname_nsp_index), kein Advisory-Lock. Für C7 (Start auf dem Server) relevant, in C1a nicht gefordert. 
Code reference: server/src/migrate.ts:52
- F005: Enthält eine Datei selbst COMMIT und danach einen Fehler, bleibt der Teil vor dem COMMIT bestehen (Postgres-Semantik; Skript mit eigener Transaktionssteuerung hebelt die Einzel-Transaktion aus). 
Code reference: server/src/migrate.ts:38
- Test-local-Abbruch: trap auf EXIT deckt rote Tests und set -e ab; SIGKILL des Skripts würde Postgres übrig lassen (nicht abfangbar, hinnehmbar). Code reference: server/scripts/test-local.sh:14
Code reference: server/scripts/test-local.sh:14
- Bei Tests: Der AC-5-Kindprozess erbt kein NODE_TEST_CONTEXT mehr (siehe Runde 1), sonst Scheinerfolg. Code reference: server/test/migrate.test.ts:132
Code reference: server/test/migrate.test.ts:132
**Implementierer:**

### Runde 3
**Adversary:** Nachprüfung der Korrekturen F001, F002, F003, F005. Eigener Lauf `./server/scripts/test-local.sh` (docs/artifacts/spike-613-c1-server-geruest/adversary-test-output.txt überschrieben): Exit 0, Typprüfung fehlerfrei, 9 Tests bestanden, 0 fehlgeschlagen, 0 skipped, 0 todo; danach kein Postgres-Prozess.
- F001 behoben: eine .sql-Datei, die nicht auf NNN_name.sql passt, wird vor jedem DB-Zugriff abgelehnt, README.md bleibt ignoriert. Randfälle im Wegwerf-Lauf: `002_b.SQL` und `001_a.Sql` werden als "falsch benannt" abgelehnt (Großbuchstaben-Endung wird also nicht stillschweigend übergangen), `001_.sql` ebenfalls, ein Ordner nur mit README.md liefert []. Tests: server/test/migrate.test.ts:127 (falsch benannt, mit Prüfung, dass nichts angelegt wurde) und :141 (README stört nicht).
Code reference: server/src/migrate.ts:16
Code reference: server/test/migrate.test.ts:127
- F002 behoben: 000 allein und 000 zusammen mit 001 liefern "Migrationsnummer 000 ungültig, die Folge beginnt bei 001", nicht mehr "doppelt". Test server/test/migrate.test.ts:148.
Code reference: server/src/migrate.ts:29
Code reference: server/test/migrate.test.ts:148
- F003 behoben: Migration, die ihr eigenes Backend beendet (`pg_terminate_backend(pg_backend_pid())`), lässt ROLLBACK scheitern. Geworfen wird der ursprüngliche Fehler 57P01, nicht der ROLLBACK-Fehler. Der Pool (max 1) bleibt danach benutzbar, die kaputte Verbindung wird verworfen (`client.release(broken)`). `release` steht nur im `finally` und läuft damit genau einmal je Aufruf. Dafür gibt es keinen Test im Repo, ich habe es nur im Wegwerf-Skript belegt.
Code reference: server/src/migrate.ts:55
Code reference: server/src/migrate.ts:61
- F005: nur als Kommentar dokumentiert ("no BEGIN or COMMIT inside the file"), nicht erzwungen; das genügt als Hinweis, bleibt aber eine Konvention. F004 ist laut Auftraggeber für C7 vorgemerkt.
Code reference: server/src/migrate.ts:43
- F006 (neu, LOW): Wird die Verbindung während einer Migration vom Server beendet, löst pg auf dem ausgeliehenen Client ein 'error'-Ereignis aus. Ohne Listener (weder in applyOne noch am Pool für ausgeliehene Clients) ist das ein ungefangener Fehler und beendet den Prozess (im Wegwerf-Skript sichtbar als uncaughtException, neben dem korrekt geworfenen 57P01). Betrifft nur das Abbrechen der Verbindung mitten in der Migration (Neustart der Datenbank), nicht die Spec-Kriterien; Abhilfe: `client.on("error", ...)` in applyOne oder im Dienst von C7 behandeln.
Code reference: server/src/migrate.ts:45
**Implementierer:**

Hinweis: Die Zeilenangaben in Runde 1 und 2 beziehen sich auf die Fassung vor den Korrekturen; maßgeblich sind die Angaben in Runde 3.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
AMBIGUOUS

Begründung: AC-1 bis AC-7, AC-9, AC-10 belegt, F001, F002, F003 behoben und nachgeprüft, F005 dokumentiert. AC-8 bleibt offen, weil der grüne Lauf von server.yml auf dem PR vor dem Commit nicht existieren kann. Offene Hinweise ohne Spec-Verstoß: F004 (kein Advisory-Lock, C7), F006 (LOW, kein 'error'-Listener am ausgeliehenen Client). Tests: 9 bestanden, 0 fehlgeschlagen, 0 übersprungen.

## Geprüfte Dateien

- sha256:77d9afee60b4d1ecd6d06a1fc24077e1fe5c4670adef74e6544dd827871681b6  .github/workflows/server.yml
- sha256:a46cfea65782bf2b52d587829b742344124b893b50934e7248076698243f58a1  CLAUDE.md
- sha256:5778cb00678f4799e558d6e253eeb88c0b9618d2ff971691c9630ee719378745  server/package.json
- sha256:f8fcd4e694bb038c2df4a67b81b25ecc2638555c1f35d9e38a4566980089cea7  server/scripts/test-local.sh
- sha256:5fa29a35716a7d6ea4805cca5ff5ab64c5b659f736797dee417e04068a922319  server/src/migrate.ts
- sha256:64a7899eb0615132edd5719c9fb9daf74da6aa91464775462cbefb603b48ef19  server/test/migrate.test.ts

## Prüfbasis

- base: f0f44506bb6e49e460512e0afc6369c39e539897
- blob:f05059f94d1aa18f1048be48b4c408f0340f1fb2  .github/workflows/server.yml
- blob:79ac4b6bcc391f164a18197599c3c48eee5012d2  CLAUDE.md
- blob:30271772cb9ee24cc09a384b9ec08f5a0a3f5fb3  server/package.json
- blob:801b9e49ce7d6cf3387f7386c8cd062015f529b5  server/scripts/test-local.sh
- blob:b52ed72d6d761789c174ccea38d99bed40d7c9a3  server/src/migrate.ts
- blob:68da87917940e6d9d8ecafc9ce49ffdfa9277826  server/test/migrate.test.ts

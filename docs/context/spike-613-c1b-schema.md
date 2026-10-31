# Context: spike-613-c1b-schema (#613 Schnitt C1b, Weg B)

## Request Summary
Die erste echte Migration des Dienstes für Claude: Tabellen für Abschrift, Aufträge und Ergebnisse nach Vertrag v1
(`docs/reference/claude-abschrift-vertrag.md`), mit Tests, die die Vertragsbeispiele gegen das Schema in echtem Postgres prüfen.
Keine Dienstlogik, kein HTTP, keine Anmeldung; in der App ändert sich nichts.

## Related Files
| File | Relevance |
|------|-----------|
| `docs/reference/claude-abschrift-vertrag.md` | Vertrag v1: drei ```json-Beispiele (Abschrift, Auftrag `complete`, Ergebnis `rejected/stale`), Felder, Arten, Gründe |
| `server/src/migrate.ts` | Läufer aus C1a: `migrate(pool, dir)` wendet `NNN_name.sql` in Nummernfolge an; Lücke/Doppelnummer abgelehnt; `schema_migrations` |
| `server/test/migrate.test.ts` | Testmuster: `DATABASE_URL` Pflicht (fehlt = Fehlschlag), je Test eigenes Schema per `search_path` (`freshPool`, liegt bisher nur in dieser Datei) |
| `server/scripts/test-local.sh` | Wegwerf-Postgres 18, Typprüfung, `npm test`, Aufräumen |
| `.github/workflows/server.yml` | Pfadfilter nur `server/**` und der Workflow selbst; der Vertrag unter `docs/reference/` löst die CI bisher nicht aus |
| `Shared/Services/TranscriptCodec.swift`, `Shared/Services/OrderExecutor.swift` | App-Seite des Vertrags (Schnitt 1, PR #779); `LooseEndsTests/TranscriptCodecTests.swift`/`OrderExecutorTests.swift` halten die Beispiele wörtlich |
| `docs/context/spike-613-c1-server-geruest.md` | Abschnitt „Für C1b vorgemerkt“: Schema-Entscheidungen aus C1a |

## Existing Patterns
- Schema nur als nummerierte Migration in `server/migrations/`, ab dem Betrieb (C7) nur ergänzen (CLAUDE.md, „Where things live“).
- Tests immer gegen echtes Postgres, nie übersprungen, je Test eigenes Schema.
- App-Seite: Vertrag ist Quelle; die Swift-Tests prüfen, dass der Vertragstext die Beispiele wörtlich enthält. Server-Seite analog:
  die Beispiele werden aus dem Vertragstext gelesen (```json-Blöcke), nicht in den Test abgeschrieben — weicht der Vertrag ab, schlägt
  der Servertest fehl.
- Kennungen im Vertrag: UUIDs in Großbuchstaben. Postgres `uuid` gibt Kleinbuchstaben aus; das Dokument (`jsonb`) behält die Schreibweise.

## Vorgemerkte Schema-Entscheidungen (aus C1a, hier zu prüfen)
- **Abschrift:** `jsonb`-Dokument je Konto und Gerät, `generated_at`, `received_at`; Claude liest die jüngste. Eine Zeile je
  (Konto, Gerät), überschrieben bei jeder neuen Abschrift — keine Historie (Datenschutz: so wenig wie möglich, Vertrag: der Dienst
  rechnet nichts nach).
- **Aufträge:** `id` (UUID aus dem Auftrag), `account_id`, `kind` per CHECK auf `capture`/`complete`/`setDue`, Dokument `jsonb`,
  CHECK `version = 1` (Vertrag: „Der Dienst prüft `version` schon beim Annehmen“), `created_at`, Vergabespalten `claimed_by`,
  `claimed_at` (Vergabe selbst ist C3, `FOR UPDATE SKIP LOCKED`).
- **Ergebnisse:** je Auftrag höchstens eins; `outcome` ∈ {`done`, `rejected`}, `reason` ∈ {`invalid`, `missing`, `stale`} genau dann,
  wenn `rejected`; `task_id` optional; `reported_by`, `reported_at`.
- `account_id` überall Pflicht, ohne Fremdschlüssel bis C6 (dort additiv).

## Dependencies
- Upstream: Vertrag v1, Läufer `migrate` (C1a), Postgres 18 (Schema nutzt nichts nach PG 13; rennwienix-Version in C7 prüfen).
- Downstream: C3 Dienstkern (Annehmen, Vergabe, Ergebnis), C4 MCP-Werkzeuge (lesen Abschrift), C7 Betrieb (`migrate` beim Start).

## Existing Specs
- `docs/specs/spike-613-schnitt-1-abschrift-auftraege.md` (App-Seite, Vertrag v1)
- `docs/specs/spike-613-schnitt-c1a-server-geruest.md` (Gerüst, Läufer, Testkette)

## Risks & Considerations
- **Nur ergänzen ab C7:** Was jetzt angelegt wird, bleibt. Lieber wenige, sicher gebrauchte Spalten als vorsorgliche. Bis C7 läuft
  der Dienst nirgends, `001` darf bis dahin noch geändert werden (keine Datenbank außer den Testläufen hat sie).
- **Doppelte Wahrheit:** `kind`/`version`/`id` stehen in Spalten und im Dokument. CHECKs, die Spalte und Dokument aneinander binden,
  verhindern Abweichung; sonst entscheidet C3, was gilt.
- **Datenschutz:** Die Abschrift darf keinen Rohtext, keine Notiz, keine Anhänge tragen. Option: CHECK auf erlaubte Schlüssel je
  Aufgabe im `jsonb` (streng, aber Version 2 bräuchte dann eine Migration — das ist gewollt: neue Felder nur mit Freigabe, #625).
- **CI-Auslöser:** Liest der Servertest den Vertragstext, muss `server.yml` auch bei Änderungen an
  `docs/reference/claude-abschrift-vertrag.md` laufen (Pfadfilter ergänzen).
- **Testhilfe:** `freshPool` liegt in `migrate.test.ts`; ein zweiter Test braucht sie ebenfalls → in eine gemeinsame Hilfsdatei
  verschieben (kleiner Umbau, keine Verhaltensänderung) statt kopieren.
- **Scope:** Migration ~60–80 Zeilen SQL, Vertragstests ~100–130, Testhilfe ~25, Pfadfilter 2, Doku wenige Zeilen. Knapp an 250;
  Testfälle bündeln (eine Tabelle von Abweichungen statt je ein Test).
- Kein Pfad der Geräteliste berührt; `phase8_complete` verlangt dennoch den `test-proof`-Beleg (CaptureSmokeTests).

## Alternativen
- **Keine Abschrift-Tabelle, nur Aufträge** (Claude liest die Abschrift aus einem Objektspeicher/Datei). Verworfen-Kandidat: zweite
  Speicherart, kein Gewinn; Postgres `jsonb` reicht.
- **Abschrift mit Historie** (jede Lieferung eine Zeile). Hilft beim Nachvollziehen von `stale`, kostet Speicher und Datenschutz;
  Alternative für die Analyse.
- **Aufträge und Ergebnisse in einer Tabelle** (Ergebnisspalten am Auftrag). Weniger Tabellen, aber Ergebnis-CHECKs werden
  bedingter; Alternative für die Analyse.
- **Vollständige JSON-Schema-Prüfung in Postgres** statt einzelner CHECKs. Kein eingebautes JSON-Schema in PG 18; bräuchte eine
  Erweiterung (`pg_jsonschema`) — neue Abhängigkeit, verworfen; Formprüfung des Auftrags gehört in C3 (Annehmen).

## Analysis

### Type
Feature (Spike-Schnitt C1b, Weg B): erste Migration des Dienstes, keine Dienstlogik.

### Befunde (Recherche + Probe in Wegwerf-Postgres 18.6, 2026-10-31)
Probe: `initdb` im Temp-Ordner, nur TCP, Skript im Scratchpad; Ergebnisse wörtlich:
1. **Unterabfrage im CHECK** → „Unteranfragen können nicht in Check-Constraints verwendet werden“. Schlüssel zählen per
   `jsonb_object_keys` im CHECK geht also nicht.
2. **Erlaubte Schlüssel per jsonpath** geht: `NOT jsonb_path_exists(doc, '$.tasks[*].keyvalue() ? (!(@.key like_regex "^(id|…)$"))')`
   weist `rawText`/`note` je Aufgabe ab, dieselbe Form auf `$` weist fremde Schlüssel oben ab (`revisions`). Ist eine Aufgabe kein
   Objekt (`"tasks":["Text"]`), bricht `keyvalue()` mit Fehler ab (SQLSTATE 2203x statt 23514) — abgewiesen wird trotzdem.
3. **Erzeugte Spalten aus dem Dokument** (`GENERATED ALWAYS AS (...) STORED`): `id uuid` aus `(doc->>'id')::uuid` als PRIMARY KEY,
   `kind` aus `doc->>'kind'` mit CHECK — beides geht; doppelte id → 23505, fehlende id → 23502, `kind:"delete"` → 23514.
   Damit gibt es keine doppelte Wahrheit zwischen Spalte und Dokument.
4. **`timestamptz` aus Text ist nicht immutable** → „Generierungsausdruck ist nicht »immutable«“. `generated_at` deshalb als
   normale Spalte, per CHECK `generated_at = (doc->>'generatedAt')::timestamptz` ans Dokument gebunden (Abweichung → 23514).
5. **UUID-Schreibweise:** Spalte `uuid` gibt klein aus, das Dokument behält GROSS; ungültige id → 22P02.
6. **Version:** `doc @> '{"version":1}'` weist fehlend und `"1"` ab, nimmt aber `1.0` an (jsonb-Zahlen vergleichen numerisch).
   Harmlos (die App dekodiert `1.0` als 1), im Test als bekannte Grenze festhalten.
- PG 18 (Quelle: postgresql.org Release-Ankündigung 18): `uuidv7()`, virtuelle erzeugte Spalten als Standard (wir schreiben
  `STORED` ausdrücklich, PK und Index brauchen es), `NOT ENFORCED` — nichts davon nötig; das Schema bleibt PG-13-tauglich.

### Varianten
| Frage | A (Empfehlung) | B | Bewertung |
|---|---|---|---|
| Abschrift-Schlüssel | eine Zeile je Konto | eine je (Konto, Gerät) | Die Abschrift trägt keine Gerätekennung, die Quelle gäbe es erst mit der Anmeldung (C6). Alle Geräte rechnen aus demselben iCloud-Stand; Claude nähme ohnehin die jüngste. B bringt eine Spalte ohne Quelle. A, Überschreiben nur bei neuerem `generatedAt` (C3). |
| Abschrift-Historie | keine | jede Lieferung eine Zeile | Datenschutz (so wenig wie möglich), Vertrag: der Dienst rechnet nichts nach. `stale` erklärt die App selbst. A. |
| Spalten vs. Dokument | erzeugte Spalten aus `doc` (`id`, `kind`, Ergebnisfelder) | Spalten vom Dienst gesetzt + CHECKs, die sie binden | A hat genau eine Wahrheit (Befund 3); B braucht je Feld einen Bindungs-CHECK. Nur `generated_at` geht den B-Weg (Befund 4). |
| Ergebnis | eigene Tabelle `order_results`, PK = FK auf `orders.id` | Ergebnisspalten an `orders` | A erzwingt „höchstens eins je Auftrag“ und „nur zu einem bestehenden Auftrag“ ohne bedingte CHECKs. A. |
| Datenschutz der Abschrift | jsonpath-CHECK: erlaubte Schlüssel oben und je Aufgabe | keine Prüfung, App vertrauen | Version 2 braucht dann eine Migration — gewollt (#625: neue Felder nur mit Freigabe). A. |
| Formprüfung Auftrag | nur `version`, `kind`, `id`; Rest in C3 | volle JSON-Schema-Prüfung | Ohne Erweiterung (`pg_jsonschema`) nicht möglich, neue Abhängigkeit. A. |

Echte Alternative zum ganzen Weg: **kein eigenes Schema für Ergebnisse** — Claude liest Ergebnisse nur aus der nächsten Abschrift
(die Aufgabe ist erledigt oder nicht). Spart eine Tabelle, verliert aber `stale`/`missing`/`invalid` als Antwort an Claude, und der
Vertrag v1 legt das Ergebnis fest. Keine ADR betroffen (Weg B steht in #612, Datenschutz in #625).

### Schema (Entwurf für die Spec)
- `transcripts`: `account_id text PRIMARY KEY`, `doc jsonb NOT NULL`, `generated_at timestamptz NOT NULL` (CHECK an `doc`),
  `received_at timestamptz NOT NULL DEFAULT now()`; CHECKs: `version = 1`, Schlüssel oben ∈ {version, generatedAt, nowCount,
  now, tasks}, je Aufgabe ∈ {id, title, status, dueDate, dueHasTime, contexts, project, nextRank, isKnaeuel}.
- `orders`: `doc jsonb NOT NULL`, `id uuid` erzeugt, PRIMARY KEY; `kind text` erzeugt, CHECK ∈ {capture, complete, setDue};
  `account_id text NOT NULL`; CHECK `version = 1`; `created_at DEFAULT now()`; `claimed_by text`, `claimed_at timestamptz`,
  CHECK beide oder keins.
- `order_results`: `doc jsonb NOT NULL`, `order_id uuid` erzeugt, PRIMARY KEY, REFERENCES `orders(id)`; `outcome` erzeugt,
  CHECK ∈ {done, rejected}; `reason` erzeugt, CHECK ∈ {invalid, missing, stale} und `(outcome = 'rejected') = (reason IS NOT NULL)`;
  `task_id uuid` erzeugt, optional; `reported_by text NOT NULL`, `reported_at DEFAULT now()`. Konto über den Auftrag
  (keine eigene `account_id`-Spalte; „überall Pflicht“ gilt für Tabellen ohne Elternzeile).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/migrations/001_claude_schema.sql` | CREATE | drei Tabellen wie oben, ~60 Zeilen |
| `server/test/schema.test.ts` | CREATE | `migrate` auf den echten Ordner; die drei ```json-Blöcke aus dem Vertrag gelesen und angenommen; eine Tabelle von Abweichungen je Tabelle mit erwartetem SQLSTATE, ~110 Zeilen |
| `server/test/db.ts` | CREATE | `freshPool` + `DATABASE_URL`-Pflicht aus `migrate.test.ts` herausgezogen, ~25 |
| `server/test/migrate.test.ts` | MODIFY | importiert `freshPool`, −20 |
| `.github/workflows/server.yml` | MODIFY | Pfadfilter + `docs/reference/claude-abschrift-vertrag.md` (beide Auslöser), +2 |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | Satz „Beispiele stehen wörtlich auch in …“ nennt den Servertest, +1 |

Achtung `node --test test/`: findet `db.ts` mit; ohne `test(...)` darin meldet es nichts — in RED prüfen, sonst Muster
`test/*.test.ts` in `package.json` (dann 7. Datei, eine Zeile).

### Scope Assessment
- Files: 6 (4 mit Inhalt, 2 Einzeiler)
- Estimated LoC: +~200/−~20
- Risk Level: LOW — nichts läuft irgendwo, keine App-Datei, `001` darf bis C7 noch geändert werden.
- Kein Pfad der Geräteliste berührt; `phase8_complete` verlangt den `test-proof`-Beleg (`CaptureSmokeTests`).

### Technical Approach
Variante A in allen Zeilen der Tabelle: Dokument ist die Quelle, Spalten werden daraus erzeugt, nur `generated_at` per CHECK gebunden;
Datenschutz als jsonpath-Liste erlaubter Schlüssel. Tests lesen die Vertragsbeispiele aus dem Markdown (Reihenfolge: Abschrift,
Auftrag, Ergebnis), damit Vertrag und Schema nicht auseinanderlaufen; Abweichungen als eine Tabelle (Schutz vor Testaufblähung).

### Dependencies
- Upstream: `migrate` (C1a), Vertrag v1. Downstream: C3 (Annehmen mit `version`-Vorprüfung, Vergabe `FOR UPDATE SKIP LOCKED`,
  Abschrift nur bei neuerem `generatedAt` überschreiben), C4 (liest `transcripts`), C6 (Konto-Tabelle, FK additiv), C7 (Start-`migrate`).

### Open Questions
- keine an Henning (reine Schemafragen; Datenschutzgrenze folgt aus #625, Weg B aus seiner Wahl in #612)

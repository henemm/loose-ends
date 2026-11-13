# Context: feat-615-s4f-abnahme

## Request Summary
#615 (Konto und Anmeldung) ist in S1–S4e gebaut und ausgeliefert. Offen ist allein die Definition of Done des Tickets:
(1) Anmelden, Abmelden, Konto löschen **im Simulator gegen den lokalen Dienst** belegt, nach dem Löschen keine Zeile des
Kontos mehr, Apple-Widerruf ausgelöst; (2) Stufe 3 über TestFlight (echte Anmeldung mit Apple-Konto auf Hennings Gerät).
Dieser Schnitt ist der Abnahme-Schnitt, der beides liefert und das Ticket schließt.

## Stand aus dem Ticket (Kommentare bis 2026-11-11)
- S4c-1: Gruppe „Claude“ nur gegen den Stellvertreter-Transport `UITestTransport` belegt (`AccountSettingsTests`, 8/8).
- S4c-2a: TestFlight mit `konto=false` auf Hennings Gerät bestätigt („kein Claude in den Einstellungen“).
- S4d: `/auth/apple|logout|delete` live offen; Löschen echt nur lokal per Aufruf gegen Wegwerf-Postgres belegt, live nur Abweisung.
- Offen laut Kommentar S4d: „Gerätelauf über TestFlight (echte Anmeldung mit Apple-Konto)“ — bisher kein `konto=true`-Lauf.
- F004 (Sicherungsfrist, ab 2026-12-04) bleibt als Merkposten im Ticket; gehört nicht zur DoD.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Claude/AccountWiring.swift` | `forApp`, `debugService` (`-LEDebugService`/`-LEDebugSession`, Debug-Bau): Gruppe sichtbar, Sitzung im Speicher, echter `ServiceClient` |
| `LooseEnds/Claude/AccountState.swift` | `signOut` (→ `/auth/logout`), `deleteAccount` (→ `/auth/delete`), Status-Übergänge |
| `LooseEnds/Claude/ServiceClient.swift` | Aufrufe der Auth-Wege |
| `LooseEnds/Views/AccountSection.swift` | Gruppe „Claude“ in den Einstellungen |
| `LooseEndsUITests/AccountSettingsTests.swift` | bestehende UI-Tests gegen Stellvertreter |
| `server/scripts/local-service.sh`, `server/scripts/local-fixture.ts` | Wegwerf-Dienst + Hilfsbefehle (`session`, `transcript`, `order`, `result`, `due`); kein Befehl „Zeilen des Kontos zählen“ |
| `server/src/auth.ts` | `/auth/delete`: Löschen, dann Widerruf je `apple_tokens`-Zeile; ohne Zeile/Config `apple revoke skipped` |
| `server/src/accounts.ts` | `deleteAccount` (Transaktion über Abschrift, Aufträge, Ergebnisse, OAuth-Zeilen, Geräte-Tokens per Cascade) |
| `.github/workflows/testflight.yml` | Eingabe `konto` schaltet `LEAccountEnabled` im Archiv ein, markiert den Bau |
| `docs/artifacts/feat-795-s3b2-debug-weg/` | Vorbild für A/B-Lauf Simulator ↔ lokaler Dienst |

## Existing Patterns
- Debug-Weg (#795 S3b-2): `local-service.sh` → `STATE=<pfad>`; App mit `-LEDebugService http://localhost:<port> -LEDebugSession <token>`;
  Beleg als Protokoll + Screenshots im Artefaktordner.
- Stufe 3 über TestFlight: Merge, Lauf mit `what_to_test`, Henning bekommt Schritte in einfachen Worten; Ticket bleibt bis zu seiner Rückmeldung offen (`Refs #615`).
- Konto-Bau (`konto=true`) wird nie einer Store-Version zugeordnet (`asc_store_version.py`).

## Dependencies
- Upstream: lokaler Dienst (Node 26, Postgres 18), Simulator-Debug-Bau, TestFlight-Pipeline, Live-Dienst `loose-ends.henemm.com`.
- Downstream: #621 (claude.ai-Connector hängt am selben Konto), #795 (App-Sitzung für Abschrift/Aufträge).

## Existing Specs
- `docs/specs/feat-615-schnitt-4c1-konto-gruppe.md`, `…-4c2a-freischalten.md`, `…-4d-auth-oeffnen.md`
- `docs/specs/feat-795-schnitt-3b2-debug-weg.md`

## Risks & Considerations
- **Anmelden mit Apple ist im Simulator gegen den lokalen Dienst nicht echt möglich** (lokal keine `APPLE_*`, kein Apple-Token
  für die eigene Kennung). Lokal belegbar: Abmelden und Löschen mit einer per Fixture angelegten Sitzung; Anmelden nur über TestFlight.
- **Apple-Widerruf lokal nicht auslösbar** (keine `apple_tokens`-Zeile, kein Apple) → lokal `apple revoke skipped`; echter Widerruf nur live.
- **Live-Löschen trifft Hennings einziges Konto**: die Tür ist zu (`ALLOWED_APPLE_SUBS` = sein `sub`). Löschen entfernt Abschrift,
  Aufträge, OAuth-Zeilen (claude.ai-Verbindung) und Gerätetokens; danach neu anmelden legt ein frisches Konto an, claude.ai muss neu
  verbunden werden. Produktfrage, ob und wann der Lösch-Teil live auf seinem Gerät laufen soll.
- Nachweis „keine Zeile mehr“ braucht einen lesenden Zählbefehl gegen die Wegwerf-Datenbank (Fixture-Erweiterung).
- Gerätelauf nur nach Hennings „jetzt ist ein Test möglich“ — über TestFlight bedient er selbst, kein Fernstart.

## Analysis

### Type
Feature (Abnahme-Schnitt: Nachweise der DoD von #615, kleine Testwerkzeuge, kein neues Produktverhalten)

### Befund
- DoD (Issue-Text wörtlich): „Anmelden, Abmelden, Konto löschen im Simulator gegen den lokalen Dienst belegt; nach dem Löschen
  keine Zeile des Kontos mehr im Dienst, Apple-Widerruf ausgelöst“ + „Stufe 3 über TestFlight“.
- Lokal gibt es keine Apple-Anmeldung: `local-service.sh` entfernt alle `APPLE_*`, `/auth/apple` antwortet 503; der Simulator
  bekäme ohnehin kein Identity-Token für einen Dienst ohne Apple-Schlüssel. „Angemeldet“ lokal = Sitzung per Fixture + Debug-Weg
  (`-LEDebugService`/`-LEDebugSession`, `AccountState` mit `InMemorySessionStore(token:)`, Gruppe zeigt „verbunden“).
- Abmelden (`AccountState.signOut` → `/auth/logout`) und Löschen (`deleteAccount` → `/auth/delete`) laufen lokal echt.
- Widerruf lokal: `revokeAfterDelete` loggt ohne `apple_tokens`-Zeile oder ohne Config `apple revoke skipped` — lokal also
  nie ein echter Widerruf. Echter Widerruf nur live (Konto mit App-Token und Web-Token von claude.ai); Erfolg ist im Log still,
  Fehlschlag `apple revoke failed`/`skipped`.
- Zählnachweis „keine Zeile mehr“: kein Fixture-Befehl vorhanden.
- Taps in den Einstellungen brauchen eine UI-Automatisierung; `--ui-testing` schlägt den Debug-Weg (Stellvertreter-Transport).
  Muster für Umgebungsdurchreiche vorhanden (`TEST_RUNNER_LOOSEENDS_*` in `sim.sh`).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/scripts/local-fixture.ts` | MODIFY | Unterbefehl `rows`: Zeilen des Fixture-Kontos je Tabelle (accounts, sessions, transcripts, orders/results, apple_tokens, oauth_records, device_tokens), nur lesend; Unterbefehl `apple-token`: eine verschlüsselte `apple_tokens`-Zeile anlegen, damit das Löschen auch sie nachweislich entfernt |
| `LooseEndsUITests/AccountLocalServiceTests.swift` | CREATE | startet die App ohne `--ui-testing`, mit Debug-Weg aus `TEST_RUNNER_LOOSEENDS_DEBUG_SERVICE/SESSION`; Abmelden, dann (neue Sitzung) Konto löschen samt Bestätigung; ohne Umgebung `XCTSkip` (CI) |
| `scripts/sim.sh` | MODIFY | Durchreiche der zwei Variablen an `test-proof` |
| `scripts/ui_smoke_shards.py` o. Ä. | MODIFY (falls nötig) | Klasse aus den CI-Teilen nehmen statt Skip |
| `docs/artifacts/feat-615-s4f-abnahme/` | CREATE | Protokoll A (lokal: rows vorher/nachher, Log `apple revoke skipped`, Screenshots), Protokoll B (TestFlight) |

### Scope Assessment
- Dateien: 3–4 Code + Belege
- Estimated LoC: +150/-0
- Risk Level: LOW (kein Produktpfad geändert; nur Testwerkzeug und Debug-Bau). Stufe 3 trotzdem Pflicht laut DoD.

### Technical Approach (Empfehlung)
Teil A — Simulator gegen lokalen Dienst (Claude allein): Dienst starten, `session` + `apple-token` + `order`/`transcript`
erzeugen Zeilen in allen Tabellen; `rows` vorher. UI-Test: Gruppe „verbunden“ → Abmelden → `rows` zeigt Sitzung weg, Konto
bleibt. Neue Sitzung → Konto löschen → Bestätigung → `rows` = 0 überall; Dienstlog `apple revoke skipped` (Widerruf
versucht, lokal ohne Apple übersprungen — so ehrlich benannt).
Teil B — Stufe 3 über TestFlight (`konto=true`, nie einer Store-Version zugeordnet): Henning meldet sich mit Apple an,
meldet sich ab, meldet sich wieder an; das belegt die echte Anmeldung. Konto löschen live nur nach seiner Entscheidung (Frage
unten); bei Ja prüft Claude per ssh auf rennwienix: keine Zeile seines Kontos, kein `apple revoke failed/skipped` im Log =
Widerruf bei Apple angenommen; danach neu anmelden und claude.ai neu verbinden.

### Alternativen
- **Lokaler Apple-Stellvertreter im Dienst** (Umgebungsschalter, der Apple-Adressen auf einen lokalen Stub lenkt): würde
  Anmelden und Widerruf lokal „echt“ zeigen, ist aber neuer Produktcode nur für den Nachweis und belegt Apple selbst nicht. Verworfen.
- **Kein Live-Löschen**, Widerruf nur über die bestehenden Server-Tests (gefälschtes Apple) belegt: schont Hennings Konto,
  erfüllt „Apple-Widerruf ausgelöst“ aber nur gegen Attrappe.
- **Zweites Apple-Konto als Testkonto** (Tür kurz öffnen via `ALLOWED_APPLE_SUBS`): belegt Löschen live ohne sein Konto,
  braucht aber ein zweites Apple-Konto auf seinem Gerät und eine Änderung der Live-Konfiguration. Keine ADR fällt bei einer der Alternativen.

### Dependencies
Lokaler Dienst (Node 26, Postgres 18), Debug-Weg #795 S3b-2, TestFlight-Eingabe `konto` (#615 S4c-2a), Live-Dienst und ssh rennwienix.

### Open Questions
- [ ] PO: Soll im TestFlight-Lauf das Konto live gelöscht werden (danach neu anmelden, claude.ai neu verbinden)?

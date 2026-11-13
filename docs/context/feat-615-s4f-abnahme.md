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

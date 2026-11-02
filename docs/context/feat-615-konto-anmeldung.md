# Context: feat-615-konto-anmeldung

## Request Summary
#615 (Epic #612, M4): Wer Loose Ends mit Claude verbindet, bekommt ein Konto im eigenen Dienst — „Mit Apple anmelden“, Abmelden,
Konto löschen in der App; dasselbe Konto meldet ihn später im Claude-Connector an (#621). DoD: Anmelden, Abmelden, Löschen im
Simulator belegt; Watch und Widgets sehen die Sitzung (Stufe 3, weil `project.yml` berührt).

## Wichtigste Erkenntnis: Ticket-Text stammt aus der Zeit vor Weg B
- Der Ticket-Text („Jeder Nutzer hat ein Konto im Backend“, „Erststart ohne Konto … Produktfrage“) ist von 2026-10-22 (Weg A,
  Backend ersetzt CloudKit). Seit Weg B (Henning 2026-10-31, ADR-21) bleibt iCloud die Datenhaltung; der Dienst hält nur Abschrift
  und Aufträge für Claude. Folge: **Ein Konto braucht nur, wer Claude verbindet.** Erstart ohne Konto ist der Normalfall, nicht
  eine offene Frage. #795 verlangt ausdrücklich: „Ohne Konto passiert nichts: kein Netzverkehr.“
- ADR-21: Bis der Datenschutztext geändert ist (#625, #615), ruft die App den Dienst nirgends auf. Heute steht dort „kein eigener
  Server, kein Konto bei uns“ (`docs/reference/datenschutz-entwurf.md` Z. 16 und 139, öffentlich auf henemm.com).
- E-Mail-Anmeldung „für Nutzer ohne Apple-ID“: Auf iPhone/iPad/Mac ohne Apple-ID gibt es kein iCloud und damit kaum Loose Ends;
  ob E-Mail überhaupt gebraucht wird, ist eine Produktfrage für /20-analyse (Alternative: nur Apple, E-Mail erst mit Web/Nicht-Apple).

## Related Files
| File | Relevance |
|------|-----------|
| `server/migrations/001_claude_schema.sql` | `account_id text` in `transcripts`/`orders` ohne Fremdschlüssel — Kommentar: „until the account table arrives (C6)“. Kontentabelle kommt als neue Migration `002_*` (nur hinzufügen). |
| `server/src/mcp.ts` | Konto kommt nur aus `authInfo.extra.account` („C6 fills it from a real token“); kein Port, keine Anmeldung bisher. |
| `server/src/transcripts.ts`, `server/src/orders.ts` | Alle Abfragen nach `account_id`; Konto löschen muss Abschrift, Aufträge, Ergebnisse mitnehmen. |
| `server/src/migrate.ts` | Migrationsläufer: nummerierte SQL-Dateien, je eine Transaktion. |
| `server/package.json` | Abhängigkeiten: `@modelcontextprotocol/server` 2.4.0, `pg`, `zod`. Keine HTTP-/JWT-/OAuth-Bibliothek bisher. |
| `server/test/*.test.ts`, `server/scripts/test-local.sh` | Testmuster: Wegwerf-Postgres, `node --test`. |
| `project.yml` | Fähigkeit „Sign in with Apple“ (`com.apple.developer.applesignin`) fehlt; App-Gruppe vorhanden (Z. 54, 143, 221, 254); Keychain-Sharing fehlt. Berührt → Stufe 3. |
| `LooseEnds/Views/SettingsView.swift` (372 Z.) | Ort für „Mit Claude verbinden / Konto“; gemeinsame Stelle mit Epic #794. Gruppen-Muster `group(_:hint:)`, iCloud-Abschnitt `syncSection`. |
| `LooseEnds/App/FieldSettingsStore.swift`, `LooseEnds/Places/SavedPlacesStore.swift` | Muster für gespeicherte Einstellungen (Defaults + iCloud-KV) — für Sitzungs-Token NICHT geeignet (Geheimnis → Keychain). |
| `docs/reference/claude-abschrift-vertrag.md` | Vertrag v1 Abschrift/Aufträge; Konto ist dort implizit. |
| `docs/project/00-entscheidungen.md` ADR-2, ADR-21 | Weg B, Make-or-Buy: OAuth-Server nie selbst schreiben, Rückfall Supabase Pro. |
| `docs/reference/datenschutz-entwurf.md` | Muss vor dem ersten externen Nutzer geändert werden (zusammen mit Website-Seite). |
| `LooseEnds/Resources/*.xcstrings`, `de.lproj/InfoPlist.strings` | Neue Texte in allen ausgelieferten Sprachen (`LanguagePacks.shipped`, Katalogwächter). |

## Existing Patterns
- Dienst: reine Funktionen über `pg.Pool`, ein SQL-Statement je Vorgang, Konto als Parameter; MCP-Handler zustandslos.
- Schema nur über nummerierte Migrationen, ausschließlich hinzufügend.
- App: Gemeinsame Werte über App-Gruppe (`ModelContainerFactory` liest `LEAppGroup` aus `Info.plist`); Prüfkennung `.probe` mit eigener Gruppe (ADR-18) — eine Keychain-Zugriffsgruppe müsste ebenso das Suffix tragen.
- Systemanbindung im Test abgeschaltet (`--ui-testing`), feste Ergebnisse statt echter Systemdialoge (z. B. `PlaceSearch`, `CurrentLocation`).
- `Logger` statt `print`, kein `try?`, Swift 6 strict concurrency.

## Dependencies
- Upstream: Apple „Sign in with Apple“ (AuthenticationServices in der App; im Dienst Prüfung des Identity-Token gegen Apples JWKS; beim Löschen Token-Widerruf über Apples REST-Endpunkt `auth/revoke` — App-Store-Regel 5.1.1(v)). Dienst-Betrieb #796 (noch offen: kein öffentlicher Endpunkt, kein TLS).
- Downstream: #795 (App-Seite Abschrift/Aufträge, blocked by #615), #621 (Claude-Connector-Anmeldung über OAuth mit demselben Konto), #616 (blocking, aber als Weg A geschlossen — Verweis prüfen), #625 (Datenschutz).

## Existing Specs
- `docs/specs/spike-613-*.md`, `docs/specs/feat-613-c4b2-mcp-complete-setdue.md` — Dienstkern, Konto als Parameter.
- Keine Spec zu Konto/Anmeldung.

## Risks & Considerations
- **Umfang**: Dienst (Kontentabelle, Apple-Token prüfen, Sitzungstoken, Löschen mit Widerruf) + App (Fähigkeit, Anmeldeknopf, Keychain mit App-Gruppe, Abmelden, Löschen) + Watch/Widgets-Sicht sprengt 250 Zeilen deutlich → Schnitte nötig (Dienst zuerst, dann App).
- **Make or Buy**: Sitzungs-/OAuth-Logik nicht selbst erfinden; Bibliothek für JWT/JWKS-Prüfung (z. B. `jose`) wäre neue Abhängigkeit → Freigabe nötig. Verhältnis zu #621: der Connector braucht später einen OAuth-Server mit Web-Anmeldung (Apple im Browser: Services-ID + Domain) — Konto-Modell jetzt so schneiden, dass #621 es übernimmt.
- **Kein Netzverkehr ohne Konto und vor Datenschutzänderung** (ADR-21): Anmeldeknopf erst sichtbar, wenn #625 bzw. der Text steht — oder hinter Schalter. Produktfrage.
- **Gerätestufe**: `project.yml` + Entitlement → Stufe 3 über TestFlight; neue Fähigkeit erfordert ggf. Profil-Neuregistrierung (Cloud-managed signing in CI).
- **Simulator**: Sign in with Apple braucht im Simulator eine angemeldete Apple-ID; UI-Tests brauchen einen Testpfad ohne echten Systemdialog.
- **Gemeinsame Stellen** mit Epic #794: `project.yml`, `SettingsView`, `*.xcstrings` — vor Änderung offene PRs/Zweige von #794 prüfen.
- **Dienst noch nicht erreichbar** (#796 offen): Ende-zu-Ende-Anmeldung aus dem Simulator gegen einen laufenden Dienst braucht lokalen Dienst oder #796 zuerst.
- Datenschutztext + Website-Seite nur gemeinsam ändern.

## Analysis

### Type
Feature (Dienst + später App). Neu geschnitten auf Weg B (ADR-21): Konto nur für wer Claude verbindet.

### Recherche (2026-11-02, Quellen)
- Apple TN3194 (2025-10-03): Bei Kontoerstellung Identity-Token und Authorization-Code an den Server; Token prüfen, Code bei
  `/auth/token` einlösen, Refresh-Token sicher speichern. Löschen: erst Daten löschen, dann `/auth/revoke` (braucht Refresh- oder
  Access-Token). Ohne Token muss die Löschung trotzdem gelingen (Nutzer widerruft dann in den Apple-ID-Einstellungen).
  Pflicht seit 2022-06-30 (Regel 5.1.1(v)). https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple
- Identity-Token: JWKS von Apple, `iss`, `aud`, `exp`, `nonce` prüfen; kein Schlüssel nötig. client_secret für `/auth/token` und
  `/auth/revoke` = ES256-JWT aus dem .p8-Schlüssel (Team-ID, Key-ID). node:crypto kann JWK importieren, RS256 prüfen, ES256 signieren
  → keine neue Abhängigkeit.
- Apple-`sub` ist je primärer App-ID stabil; eine Web-Services-ID (für #621) unter derselben primären App-ID liefert denselben Nutzer
  (Forum https://developer.apple.com/forums/thread/834970, vor #621 zu belegen).
- MCP/Claude-Connector: OAuth 2.1 bleibt bei #621 (node-oidc-provider, siehe spike-613-backend-weg-b.md); #615 baut keinen OAuth-Server.

### Befunde
- Dienst hat keinen HTTP-Port, keine Kontotabelle; `transcripts.account_id` (PK) und `orders.account_id` ohne FK, `order_results`
  hängt über `order_id` (NO ACTION) an `orders`. Löschen muss alle drei leeren.
- App: 0 Treffer für URLSession, Keychain, AuthenticationServices; kein `applesignin` in `project.yml`.
- Watch, Widgets, Share sprechen nie mit dem Dienst (nur SwiftData/CloudKit bzw. App-Gruppe). Unter Weg B sendet nur die App (#795)
  → **„Watch und Widgets sehen die Sitzung“ entfällt**, Keychain nur in der App, keine Keychain-Gruppe.
- ADR-21: bis der Datenschutztext geändert ist (#625), ruft die App den Dienst nirgends auf → App-Seite erst nach #625.

### Alternativen (Plan-Bewertung)
| | A: nativ „Mit Apple anmelden“, eigenes Sitzungs-Token | B: App als OAuth-Client des #621-Servers | C: kein App-Konto |
|---|---|---|---|
| Für | klein, offline testbar, unabhängig von #796/#621; Apple-sub als Schlüssel, #621 übernimmt Tabelle | ein Token-Weg | nichts zu bauen |
| Gegen | zweiter Token-Weg neben #621 (Hash, Ablauf, Widerruf selbst) | blockiert auf #621+#796, Browser-Blatt statt Face-ID-Blatt, größter Umfang | App hat keine Berechtigung für #795, Löschen in der App unmöglich (5.1.1(v)) |
| ADR-21 | verträglich: kein OAuth-Server, nur Bearer für die eigene App | konform | konform, löst nichts |
Gekippt würde mit B: nichts; mit A: keine ADR, aber ADR-21 bekommt den Zusatz „App-Sitzung ≠ OAuth“.

### Affected Files (with changes) — Schnitt 1 (dieser Workflow)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/migrations/002_accounts.sql` | CREATE | `accounts(id uuid, apple_sub unique, created_at)`, `sessions(token_hash, account_id, created_at, last_used_at)`, `apple_tokens` (Refresh-Token verschlüsselt); FKs von `transcripts`/`orders` auf `accounts` mit ON DELETE CASCADE, `order_results` CASCADE über `orders` (nur hinzufügend) |
| `server/src/accounts.ts` | CREATE | `findOrCreate(sub)`, `createSession` (32 Byte Zufall, nur SHA-256 gespeichert), `resolveSession`, `endSession`, `deleteAccount` (eine Transaktion, gibt das Apple-Token für den Widerruf zurück) |
| `server/test/accounts.test.ts` | CREATE | inkl. „nach Löschen alle drei Tabellen leer“, fremdes Konto unberührt, Token nie im Klartext |
| `server/test/schema.test.ts` | MODIFY | ggf. FK-Erwartungen (Konto muss existieren) |

### Weitere Schnitte (gleiches Ticket, je eigener Workflow)
- **S2 Apple-Anbindung** (`server/src/apple.ts` + Test, ~150+220): Identity-Token prüfen (JWKS injizierbar), client_secret ES256,
  Code einlösen, widerrufen; Tests gegen eigenes RSA/EC-Schlüsselpaar und lokalen Stub.
- **S3 HTTP-Rand** (`server/src/http.ts` + Test, node:http): `POST /auth/apple`, `POST /auth/logout`, `DELETE /account`, Bearer-Prüfung,
  Größen-/Ratenlimit; Widerruf nach dem Löschen, Fehlschlag blockiert die Löschung nicht.
- **S4 App** (nach #625): Entitlement in `project.yml` (Stufe 3), Keychain + Dienstclient, Abschnitt in den Einstellungen,
  `*.xcstrings`, Fake unter `--ui-testing`, Dienst lokal als Gegenstelle. Sichtbare Änderung → **Entwurf vor Spec** (Artefakt) in der
  Analyse von S4. Vermutlich 4a/4b.
- Apple-Developer-Einrichtung (Fähigkeit an App-ID und Probe-ID, .p8-Schlüssel) vor S3-Ende; ich mache das selbst im Browser, Henning
  meldet sich nur an.

### Scope Assessment (Schnitt 1)
- Files: 3–4
- Estimated LoC: +~100 Code / +~150 Test
- Risk Level: LOW für S1 (nur Dienst, keine Produktwirkung, kein Netz); Gesamtticket MEDIUM (erster Port, Geheimnisse, Stufe 3 in S4)

### Technical Approach
Ansatz A, nur Apple, `apple_sub` als einziger Kontoschlüssel (E-Mail nie Schlüssel: privates Relay). Technische Festlegungen:
node:crypto statt `jose` (keine neue Abhängigkeit), node:http statt Framework, Apple-Refresh-Token AES-256-GCM verschlüsselt
(Schlüssel aus Umgebung), Sitzungs-Token undurchsichtig und nur gehasht. Reihenfolge: S1 → S2 → S3 (offline), #625 → S4, #796 vor
dem echten Gerätelauf, dann #795/#621.

### Dependencies
- Upstream: Migrationsläufer `server/src/migrate.ts`, Testmuster `server/test/db.ts` (Schema je Test), `test-local.sh`.
- Downstream: #795 (Sitzung der App), #621 (übernimmt `accounts` über `apple_sub`), #625 (Datenschutz vor S4), #796 (Betrieb).

### Open Questions
- [x] PO (Henning, 2026-11-02): nur „Mit Apple anmelden“, keine E-Mail-Anmeldung.
- [x] Watch/Widgets-Sitzung: entfällt (technisch, Weg B).
- [x] Erststart ohne Konto: Normalfall (ADR-21, #795).

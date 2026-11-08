# Context: feat-615-s4-app-anmeldung (#615 Schnitt 4)

## Request Summary
In den Einstellungen der App (iPhone, iPad, Mac) mit Apple anmelden, abmelden und das Konto löschen, gegen die fertigen
Dienst-Routen `/auth/apple`, `/auth/logout`, `/auth/delete`. Vorbedingung laut Ticket: Der Anmeldeknopf erscheint erst,
wenn der Datenschutztext ein Konto beim eigenen Dienst nennt (#625); Entwurf der Einstellungszeile vor der Spec (PO-Regel
„Entwurf vor Spec bei UI-Änderungen“). Zweck: Ohne App-Sitzung kann #795 keine Abschrift senden, deshalb sieht claude.ai
seit S6b nur „noch keine Abschrift“.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Views/SettingsView.swift` (372 Z.) | Ort der neuen Gruppe; Muster `group(title, hint:)`, iOS `Section`, Mac Papierzeilen; Reihenfolge Notifications → Loose ends → iCloud (iOS) → Kalender → Task → Menu bar (Mac) → About |
| `project.yml` (App-Target, `entitlements.properties` Z. 49ff.) | neue Berechtigung `com.apple.developer.applesignin: [Default]`; nie nur in der `.entitlements`-Datei (#311); Mac-Sandbox braucht `com.apple.security.network.client` für den Netzaufruf |
| `LooseEnds/LooseEnds.entitlements`, Mac-Entitlements | erzeugtes Abbild, durch `generate` |
| `server/src/auth.ts` | Vertrag `POST /auth/apple` JSON `{identityToken, nonce, code}` → 200 `{sessionToken}`; jede Ablehnung nackte 401, nur Apple unerreichbar 503; `POST /auth/logout` und `/auth/delete` mit `Authorization: Bearer`, 204 |
| `server/src/apple.ts` | `aud` muss in `APPLE_CLIENT_IDS` stehen: die App-Kennung, für den Prüfbau `com.henning.looseends.probe` zusätzlich; Nonce als SHA-256 im Token, roh im Body |
| `server/src/accounts.ts` (`admit`) | Tür: nur Subs aus `ALLOWED_APPLE_SUBS`; Hennings Sub ist dort (aus der Web-Anmeldung S6b). App-Sub = Web-Sub, solange Services ID und App-ID im selben Team gruppiert sind (zu belegen) |
| `server/migrations/002_accounts.sql` | `sessions` ohne Ablauf (`last_used_at` gepflegt); Merkposten „Sitzungsablauf fest oder gleitend“ gehört laut #615-Kommentar in S4 |
| `docs/reference/datenschutz-entwurf.md` (+ Website `henemm/henemm-website`, `content/legal/loose-ends/`) | heute „kein eigener Server, kein Konto bei uns“, de und en; muss vor dem Knopf ergänzt und auf der Website gespiegelt werden; App-Store-Datenschutzangaben (#625) |
| `docs/project/00-entscheidungen.md` ADR-21 | „bis dahin ruft die App den Dienst nirgends auf“; Datenschutztext vor externem Nutzer |
| `LooseEnds/Resources/*.xcstrings`, `de.lproj/InfoPlist.strings` | neue Texte de/en (`scripts/test_catalog_languages.py`) |
| henemm-infra `nginx/loose-ends.henemm.com.conf` | `/auth/*` ist heute 404 (Allowlist S6b); muss für die App geöffnet werden, mit Rate-Limit-Zone |

## Existing Patterns
- Kein Netzcode in der App: kein `URLSession`, kein `AuthenticationServices`, kein Keychain-Zugriff (grep über `LooseEnds/`, `Shared/`). Alles neu; Ort laut Epic-Gebiet `LooseEnds/Claude/`.
- Reine Regeln getrennt von Systemverdrahtung (`SyncStatus.summary`, `ListeningHint`, `PlaceEditing`): Zustandslogik der Kontozeile als reiner, unit-getesteter Typ; Systemteile unter `--ui-testing` stummgeschaltet bzw. mit festen Antworten (`PlaceSearch`, `CurrentLocation`).
- Einstellungen in defaults + iCloud-KV (`FieldSettingsStore`) — für ein Sitzungstoken falsch: gehört in die Keychain, gerätelokal, nicht synchronisiert.
- Feste Kennungen per `Info.plist`-Schlüssel mit Prüfbau-Suffix (`LEAppGroup`, `LECloudContainer`): Dienstadresse analog als `LEServiceURL` denkbar.

## Dependencies
- Upstream: `AuthenticationServices` (`SignInWithAppleButton` / `ASAuthorizationAppleIDProvider`, Nonce, `authorizationCode`), `URLSession`, Keychain (`SecItem`), Dienst-Routen aus S3, nginx (infra), Apple-Konfiguration auf dem Server (`APPLE_CLIENT_IDS` mit App- und Prüfbau-Kennung).
- Downstream: #795 (Abschrift senden, Aufträge holen) liest die Sitzung; #625 (Datenschutz, Store-Angaben); Apple-Review-Regel 5.1.1(v): wer ein Konto anlegen lässt, muss das Löschen in der App anbieten (hier vorgesehen).

## Existing Specs
- `docs/specs/feat-615-schnitt-1-…` bis `…-3c1-konto-loeschen.md` (Dienstseite); keine App-Spec.

## Risks & Considerations
- **Größe:** Einstellungszeile + Anmelde-Ablauf + Netzclient + Keychain + Löschen mit Bestätigung + Berechtigung + Texte de/en + UI-Tests sprengt ±250 LoC → in Schnitte teilen (z. B. 4a Datenschutztext und Website, 4b Kontozeile + Anmelden/Abmelden, 4c Löschen).
- **Stufe 3 Pflicht:** `project.yml`/Entitlements berührt → TestFlight-Durchgang durch Henning; neue Fähigkeit am App-ID (Sign in with Apple ist am App-ID seit S6b eingeschaltet), Prüfbau-Kennung braucht sie ggf. auch (`LOOSEENDS_REGISTER=1`); CI-Schlüssel und Cloud-Signierung müssen die Fähigkeit tragen (#307-Klasse).
- **Simulator:** Sign in with Apple braucht eine angemeldete Apple-ID im Simulator; UI-Tests brauchen einen festen Ersatzweg unter `--ui-testing`. Echter Ende-zu-Ende-Beleg gegen den lokalen Dienst braucht echte `APPLE_*`-Werte lokal oder läuft gegen den Live-Dienst — in der Analyse entscheiden.
- **Tür:** App-Sub muss gleich dem Web-Sub sein, sonst lehnt `admit` ab (Gruppierung Services ID ↔ App-ID prüfen, Apple-Doku).
- **Mac:** gleicher Ablauf, Sandbox `network.client`; Mac-UI-Tests in der CI laufen in der echten Sandbox (#544).
- **Versprechen:** Ohne Anmeldung kein einziger Netzaufruf (ADR-21); ein Test hält das fest.
- **Sitzungsablauf:** Merkposten aus #615 (fest oder gleitend) entscheiden oder bewusst vertagen.
- **Datenschutztext ist PO-Text:** Henning gibt den Wortlaut frei; Website-Repo separat.

## Analysis

### Type
Feature (App-Seite von #615; die Dienstseite S1–S3 ist fertig).

### Recherche (2026-11-08)
- Apple DTS: Sign in with Apple liefert für alle Apps und Services IDs eines Teams denselben `sub`
  (https://developer.apple.com/forums/thread/834970); ein Gegenbericht ohne Auflösung
  (https://developer.apple.com/forums/thread/762023). Folge: App-`sub` = Web-`sub` ist wahrscheinlich, aber am ersten echten
  Lauf zu belegen; sonst lehnt `admit` ab (401).
- Sign in with Apple im Simulator unzuverlässig (AuthorizationError 1000, https://developer.apple.com/forums/thread/837902;
  Serverpod-Troubleshooting). Folge: UI-Tests nur gegen festen Ersatz unter `--ui-testing`; echter Ablauf nur Stufe 3 (TestFlight).

### Affected Files (gesamt, über alle Schnitte)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/AccountState.swift` | CREATE | reiner Zustand der Kontozeile (abgemeldet, meldet an, angemeldet, Fehler: nicht zugelassen / später nochmal, löscht) |
| `LooseEnds/Claude/SignInNonce.swift` | CREATE | 32 Byte Zufall roh, SHA-256 hex für den Apple-Request (wie `apple.ts`) |
| `LooseEnds/Claude/ServiceClient.swift` | CREATE | `URLSession`, drei Aufrufe; Protokoll + fester Ersatz unter `--ui-testing`; einzige `URLSession`-Stelle |
| `LooseEnds/Claude/SessionStore.swift` | CREATE | Keychain, `AfterFirstUnlockThisDeviceOnly`, nicht synchronisiert; In-Memory unter `--ui-testing` (Mac-Sandbox #544) |
| `LooseEnds/Views/SettingsView.swift` (+ eigene View-Datei für die Gruppe) | MODIFY/CREATE | Gruppe „Konto“: Anmelden, Abmelden, Konto löschen mit Bestätigung |
| `project.yml` | MODIFY | `com.apple.developer.applesignin: [Default]`; Info-Schlüssel `LEServiceURL`, `LEAccountEnabled` (Freischalter) |
| `LooseEnds/Resources/*.xcstrings` | MODIFY | Texte de/en |
| `LooseEndsTests/Claude/*`, `LooseEndsUITests/AccountSettingsTests.swift` | CREATE | Zustand, Nonce, Client gegen URLProtocol-Attrappe, „kein Netzaufruf ohne Anmeldung“, UI-Smoke |
| `server/src/accounts.ts` (+ Test) | MODIFY | Sitzungsablauf gleitend: `resolveSession` nur bei `last_used_at > now() - 90 days`; keine Migration |
| `docs/reference/datenschutz-entwurf.md` + Website `henemm/henemm-website` | MODIFY | Konto-Teil (Apple-Anmeldung, Abschrift, Löschen), de/en, Wortlaut Henning |
| henemm-infra `nginx/loose-ends.henemm.com.conf` | MODIFY | genau `/auth/apple`, `/auth/logout`, `/auth/delete` öffnen, eigene Limit-Zone; nicht `/auth/*` |
| Server-Konfiguration `APPLE_CLIENT_IDS` (rennwienix) | CONFIG | App-Kennung `com.henning.looseends` (und `.probe`) als `aud` zulassen |

### Scope Assessment
- Gesamt deutlich über 250 LoC (≈ 700–800 inkl. Tests) → Schnitte.
- Risk Level: MEDIUM — neue Berechtigung und Signierung (Klasse #311/#307), erster Netzcode der App, öffentlich geprüfte 1.0 im Store.

### Technical Approach (Empfehlung)
Natives „Mit Apple anmelden“ gegen die fertigen Routen, Schnitte in dieser Reihenfolge:
- **4a Server:** Sitzungsablauf gleitend 90 Tage ohne Nutzung (über das vorhandene `last_used_at`, keine Migration). Löst den Merkposten aus #615/#621.
- **4b App-Kern ohne UI:** `AccountState`, Nonce, `ServiceClient`, `SessionStore`, Tests inkl. „ohne Anmeldung null Netzaufrufe“. Kein `project.yml` → keine Stufe 3.
- **4c Einstellungen:** Gruppe „Konto“ mit Anmelden, Abmelden, Konto löschen (Bestätigung; App-Review 5.1.1(v) verlangt Löschen in der App), Berechtigung in `project.yml`, Texte, UI-Test gegen Ersatz. Hinter `LEAccountEnabled`: im Store-Bau aus, im TestFlight-Bau für Henning an. Stufe 3 über TestFlight; dort zugleich Beleg App-`sub` = Web-`sub`.
- **4d Freigabe nach außen:** nginx drei Pfade, `APPLE_CLIENT_IDS`, Datenschutztext (Konto-Teil) auf der Website, dann `LEAccountEnabled` an im Store-Bau.
Abmelden: lokal zuerst die Sitzung löschen, dann der Dienst (Abmelden darf nie an Netz scheitern). Konto löschen: lokal erst nach 204; sonst „später nochmal“, Sitzung bleibt. 401 auf jedem Aufruf: lokale Sitzung verwerfen. Abbruch durch den Nutzer ist kein Fehler.

### Alternativen
- **A: Anmeldung über den Web-Weg** (`ASWebAuthenticationSession` gegen die schon offene `/oauth`-Anmeldung, App bekommt ein Gerätetoken). Spart Berechtigung und Signierung, `sub`-Frage entfällt, simulatortauglich. Kostet neue Serverseite (Rückleitung, Gerätetoken) und macht `/auth/apple` aus S3 überflüssig. Kippt: Vertrag S3 „App meldet sich nativ an“.
- **B: keine Anmeldung in der App.** Datenschutztext bliebe „kein Konto bei uns“ für App-Nutzer; aber #795 hätte keine Zuordnung Gerät ↔ Konto, Weg B (ADR-21) wäre nur halb. Verworfen.
- Freischalten vom Dienst aus (Schalter per Abfrage) verworfen: wäre selbst ein Netzaufruf ohne Anmeldung (bricht ADR-21).

### Dependencies
- 4a vor 4d (nginx erst mit Ablauf). 4b vor 4c. Datenschutz-Konto-Teil und 4c vor 4d. #795 hängt an 4d.
- Zirkel: #615 S4 wartet laut Ticket auf #625, #625 wartet auf #795, #795 auf #615. Auflösung: aus #625 den Konto-Teil des Datenschutztextes herauslösen (PO-Entscheidung).

### Open Questions
- [x] PO (Henning, 2026-11-08): Konto-Teil des Datenschutztextes wird vorgezogen (aus #625 gelöst, Wortlaut gibt Henning frei). Knopf im Store-Bau erst danach (`LEAccountEnabled` aus), im TestFlight-Bau schon vorher sichtbar.
- [ ] Entwurf der Gruppe „Konto“ (Heute/Entwurf/Alternative, hell und dunkel) vor der Spec von 4c — PO-Regel 2026-09-22. 4a und 4b haben keine sichtbare Änderung.

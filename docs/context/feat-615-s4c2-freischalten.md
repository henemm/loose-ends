# Context: feat-615-s4c2-freischalten (#615 Schnitt 4c-2)

## Request Summary
Die in 4c-1 gebaute Gruppe „Claude“ (Anmelden, Abmelden, Konto löschen) soll in einem TestFlight-Bau echt gegen den
Dienst laufen: Berechtigung „Mit Apple anmelden“, Schalter `LEAccountEnabled` nur für ausgewählte TestFlight-Bauten,
Sperre gegen einen solchen Bau im App Store, Dienst-Seite `/auth/*` öffentlich (4d), dann Stufe 3 bei Henning.

## Related Files
| File | Relevance |
|------|-----------|
| `project.yml` (Z. 49–67, 70–85) | Berechtigungen der App (`entitlements.properties`) und Info-Werte; hier fehlt `com.apple.developer.applesignin` und `LEAccountEnabled`/`LEServiceURL` |
| `LooseEnds/LooseEnds.entitlements`, `LooseEnds/Info.plist` | generierte Abbilder; `scripts/test_entitlements_sync.py`, `scripts/test_info_plist_sync.py` vergleichen |
| `LooseEnds/Claude/AccountWiring.swift` | `isEnabled` verlangt ein echtes Bool (CFBoolean), String „YES“ zählt als aus; `serviceURL` lässt `http` zu (F002) |
| `LooseEnds/Views/AccountSection.swift` (Z. 18–22, 143) | `layout(.signingIn)` blendet den `SignInWithAppleButton` aus, während Apples Dialog läuft (F001) |
| `.github/workflows/testflight.yml` | Eingaben `what_to_test`, `cleanup_dry_run`; Archiv mit Cloud-Signierung (`-allowProvisioningUpdates`, ASC-Schlüssel); Archivprüfung (Z. 142–240) prüft Info-Schlüssel je Target |
| `scripts/asc_store_version.py` (`pick_build`, Z. 119) | ordnet den höchsten gültigen Bau einer Store-Version zu; kennt keinen Konto-Bau |
| `.github/workflows/asc-store-version.yml` | ruft das Skript auf (`lesen`/`anlegen`) |
| `docs/reference/testflight.md` | Ablauf, Fähigkeiten, Archivprüfung `entitled` |
| `server/src/auth.ts`, `server/src/main.ts` | `/auth/apple` braucht `APPLE_*` inkl. `APPLE_CLIENT_IDS` mit `com.henning.looseends` |
| `henemm-infra`: `nginx/loose-ends.henemm.com.conf`, `loose-ends/` Compose | `/auth/*` heute 404 (live geprüft 2026-11-09: `POST /auth/apple` → 404, `/health` 200) |

## Existing Patterns
- Berechtigungen und Info nur über `project.yml` (#311, #499); CI-Schritt „Generate leaves the tree clean“.
- Cloud-Signierung legt Fähigkeiten am App-ID an, wenn die Berechtigung im Archiv steht (#311 iCloud-KV-Schlüssel kam so).
- Services ID `com.henning.looseends.web` (#621) ist an die primäre App-ID gebunden: „Sign in with Apple“ ist an
  `com.henning.looseends` vermutlich schon aktiv — in der Analyse belegen.
- Schalter per Workflow-Eingabe: `what_to_test`, `cleanup_dry_run` in `testflight.yml`; Freigabe-Text per `asc_what_to_test.py`.
- Server-Rollout per Hand auf `rennwienix` mit `scripts/deploy-loose-ends.sh` (henemm-infra), Claude allein.

## Dependencies
- Upstream: Apple-Fähigkeit am App-ID, Cloud-Signierprofil, Dienst `/auth/apple|logout|delete` öffentlich, `APPLE_CLIENT_IDS`.
- Downstream: `asc-store-version.yml` (Store-Zuordnung), Mac-Archiv im selben Lauf (derselbe Target, dieselbe Berechtigung),
  Datenschutztext (Konto-Teil, #625) vor jedem Store-Bau mit Schalter an.

## Existing Specs
- `docs/specs/feat-615-schnitt-4c1-konto-gruppe.md` — Gruppe, Layout-Tabelle, AC-8 (signingIn)
- `docs/specs/feat-615-schnitt-4b3-schluesselbund.md`, `-4b1-dienst-client.md`
- Entwurf: `docs/artifacts/feat-615-s4c-konto/entwurf.html` (Entwurf A freigegeben)

## Risks & Considerations
- Info-Wert aus einer Build-Einstellung wird ein String, `isEnabled` verlangt Bool → Weg festlegen (Info.plist vor dem Archiv
  setzen vs. Lesen von „YES“ erlauben).
- Store-Sperre: Apple-API zeigt keinen Info-Wert eines Baus → Merkmal nötig (Buildnummern-Liste im Repo/Variable,
  „Was testen“-Marke o. Ä.).
- Berechtigung `applesignin` berührt `project.yml` + `.entitlements` → Stufe 3 Pflicht (Geräteliste).
- F001 auf echtem Gerät erst in Stufe 3 sichtbar; Abhilfe vorher bauen (Knopf sichtbar, deaktiviert, oder Zeitlimit).
- Mac-Archiv: Sandbox + `applesignin` nötig, Mac-Profil muss die Fähigkeit tragen.
- App Review: ein Store-Bau mit verborgenem, aber berechtigtem Anmelden ist zulässig; Berechtigung allein zeigt nichts.
- Scoping: App-Repo (project.yml, testflight.yml, asc_store_version.py, AccountSection) plus infra-Repo → ggf. 4c-2 und 4d getrennt.

## Analysis

### Type
Feature (Freischalten der in 4c-1 gebauten Gruppe „Claude“ für ausgewählte TestFlight-Bauten).

### Befunde (2026-11-09)
- „Sign in with Apple“ ist am App-ID `com.henning.looseends` seit #621 S6b eingeschaltet (Memory `loose-ends-621-s6b-geoeffnet`);
  die Cloud-Signierung im TestFlight-Lauf übernimmt die Fähigkeit ins Profil, sobald die Berechtigung im Archiv steht (Muster #311).
- Dienst: `APPLE_CLIENT_IDS` ist gesetzt (Beleg `docs/artifacts/feat-621-s6b-betrieb/secrets-namen.txt`), der Wert selbst ist
  hier nicht gelesen (Secrets-Guard); dass er `com.henning.looseends` enthält, prüft 4d per Skript, das nur „enthalten ja/nein“ ausgibt.
- nginx (`henemm-infra`, `nginx/loose-ends.henemm.com.conf`): `location ^~ /auth/ { return 404; }` „bleibt zu bis #615 S4“.
- `AccountWiring.isEnabled` verlangt ein echtes Bool. Ein Build-Setting würde in der Info.plist ein String → Weg: nach `xcodegen
  generate` im TestFlight-Lauf `plutil -replace LEAccountEnabled -bool YES LooseEnds/Info.plist` (nur bei Eingabe `konto`), Archiv-
  prüfung belegt Typ und Wert für iOS und Mac. `isEnabled` bleibt unverändert.
- Store-Sperre: Die ASC-API kennt kein freies Merkmal am Bau. Lesbar ist je Bau `GET /v1/builds/{id}/betaBuildLocalizations`
  (`whatToTest`), Quellen: developer.apple.com/documentation/appstoreconnectapi/builds, …/beta-build-localizations.
  → testflight.yml hängt bei `konto` eine feste Zeile („Konto-Bau – nie für den App Store“) an „Was testen“ an; `pick_build`
  überspringt jeden Bau mit dieser Zeile und jeden Bau, dessen Lokalisierungen nicht lesbar sind (fail-closed).
- F001 Recherche: Apple-Foren berichten, dass `onCompletion` ausbleibt bzw. die Präsentation scheitert, wenn der Knopf (oder sein
  Container) während der Autorisierung aus der Hierarchie fällt (developer.apple.com/forums/thread/710183, /698652). Fix: Knopf in
  `signingIn` sichtbar und deaktiviert lassen (Layout-Tabelle und AC-8 von 4c-1 ändern sich).
- F002: `serviceURL` nur `https` (localhost-`http` nur im Debug).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `project.yml` | MODIFY | `com.apple.developer.applesignin: [Default]` in den App-Berechtigungen; `LEAccountEnabled: false` sichtbar als Info-Wert |
| `LooseEnds/LooseEnds.entitlements`, `LooseEnds/Info.plist` | MODIFY (generiert) | Abbild nach `generate` |
| `.github/workflows/testflight.yml` | MODIFY | Eingabe `konto` (bool, Standard aus); plutil vor iOS- und Mac-Archiv; Marke in „Was testen“; Archivprüfung `LEAccountEnabled` |
| `scripts/asc_store_version.py` + Test | MODIFY/CREATE | `pick_build` überspringt Konto-Bauten und unlesbare (fail-closed) |
| `LooseEnds/Views/AccountSection.swift` + UI-/Unit-Test | MODIFY | F001: Knopf in `signingIn` sichtbar, deaktiviert |
| `LooseEnds/Claude/AccountWiring.swift` + Test | MODIFY | F002: nur https außer Debug-localhost |
| `henemm-infra`: nginx | MODIFY (4d) | `/auth/apple`, `/auth/logout`, `/auth/delete` öffnen, eigene Limit-Zone, Rest 404 |

### Scope Assessment
- Gesamt über den Grenzen (≈ 8 Dateien, ≈ 260 LoC + Infra) → drei Schnitte:
  - **4c-2a** Berechtigung + Schalter + Store-Sperre (project.yml, testflight.yml, asc_store_version.py, Test; ≈ 150 LoC). Berührt
    `project.yml`/`.entitlements` → Stufe 3 (Geräteliste).
  - **4c-2b** F001 + F002 in der App (AccountSection, AccountWiring, Tests; ≈ 80 LoC), Stufe 2.
  - **4d** Dienst: nginx `/auth/*` öffnen, `APPLE_CLIENT_IDS` enthält App-ID prüfen (henemm-infra), dann TestFlight-Bau mit `konto`
    und Stufe 3 bei Henning (Anmelden, Abmelden, Löschen; Beleg App-sub = Web-sub).
- Risk Level: MEDIUM — Signierung/Berechtigung (Klasse App-Group-Absturz), Store-Schutz; Produkt im Store unverändert (Schalter aus).

### Technical Approach
Empfehlung: Schalter per TestFlight-Eingabe mit plutil (Bool bleibt Bool), Sperre über die Marke in „Was testen“, fail-closed in
`pick_build`. Reihenfolge 4c-2a → 4c-2b → 4d → TestFlight-Bau → Stufe 3. Kein Store-Bau mit Schalter an, bevor der Konto-Text
auf henemm.com steht (Memory `loose-ends-615-s4-datenschutz-vorgezogen`).

### Alternativen
- **Eigene Versionsschiene** für Konto-Bauten (z. B. MARKETING_VERSION 1.1 nur bei `konto`): Apple selbst verbietet dann die
  Zuordnung zu 1.0.1 — stärker als jede Skriptprüfung, aber die Sperre fällt, sobald eine Store-Version 1.1 entsteht, und TestFlight
  zeigt zwei Versionsnummern. Kippt keine ADR, nur die Entscheidung aus 4c (Entwurf A: „asc-store-version ordnet nie zu“).
- **Buildnummer mit Suffix** (`<run>.1`) als Merkmal: ohne zusätzlichen API-Aufruf, aber für Henning im Store-Dialog nicht sprechend.
- **Laufzeit-Erkennung** (AppTransaction/Sandbox-Beleg) statt Schalter: in 4c verworfen, weil App Review in derselben Umgebung läuft.

### Open Questions
- [ ] keine Produktfrage offen (Entwurf A und Datenschutz-Reihenfolge sind entschieden); Werte von `APPLE_CLIENT_IDS` prüft 4d.

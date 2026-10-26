# Context: feat-705-apple-seite-einladung

## Request Summary
#705 (aus #342, Epic #371): Die Apple-Seite der ersten externen Einladung. Teil 1: Beta-App-Review, Exportnachweis,
Kontaktangaben. Teil 3: Testgruppe (intern `Familie`, extern für die Einladung), „Was testen“ je Build (läuft seit #347),
Rückmeldeweg. Zuerst feststellen, was die ASC-API aus der CI erlaubt und was nur die Oberfläche kann.
DoD: jeder Teil erledigt oder mit Begründung gestrichen; Prüfliste in `docs/reference/testflight.md` abgehakt, Beleg je Haken;
eine Person außer Henning kann die App über den Einladungslink installieren.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_wait_build.py` | ASC-Grundbausteine: JWT (`make_token`, openssl), `get_json` (Wiederholung bei 5xx/429), `find_app_id`, `read_config` (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_FILE`, `ASC_BUNDLE_ID`, `ASC_PLATFORM`, `ASC_API_BASE`) |
| `scripts/asc_what_to_test.py` | Vorbild für ein neues Skript: `send_json` (PATCH/POST mit Wiederholung), `get_data`, `find_build_id`; schreibt `betaBuildLocalizations` |
| `scripts/test_asc_what_to_test.py` | Vorbild für den Test: `FakeASC` (lokaler HTTP-Nachbau der ASC-API), prüft zusätzlich Schritte in `testflight.yml` |
| `.github/workflows/testflight.yml` | Jobs `schema-check` → `upload` → `upload-mac` → `confirm`/`confirm-mac`; `asc_wait_build.py` + `asc_what_to_test.py` laufen in `confirm` (Z. 536–537) und `confirm-mac` (Z. 558–559); Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` |
| `docs/reference/testflight.md` | Schritt 6 „Auf dem iPhone installieren“ (Gruppe `Familie`, verweist auf #342 Teil 3 → jetzt #705); Prüfliste vor der Einladung (#176); Z. ~212 Verify-Schritt prüft `ITSAppUsesNonExemptEncryption` = `false`. Hier kommen die Prüfliste und Stolpersteine hin |
| `docs/reference/datenschutz-entwurf.md` | Entwurf, Freigabe Henning; Kopf: „Die öffentliche Adresse, die Apple für TestFlight verlangt, ist #705“ |
| `docs/reference/abnahme-testflight.md` | Prüfliste für #176 (nicht Teil von #705, nur Bezug) |
| `project.yml` Z. 92 | `ITSAppUsesNonExemptEncryption: false` – Exportnachweis ist im Build schon beantwortet |

## Existing Patterns
- ASC-Zugriff ausschließlich per Python-Standardbibliothek plus `openssl`, kein Fremdpaket; Fehler als `Fatal` → `::error::`-Zeile, Exit 1.
- Jedes ASC-Skript hat einen Test gegen einen lokalen Nachbau der API; Apples echte Antworten zeigt nur der echte Lauf.
- Schlüssel, Token, Signatur werden nie ausgegeben.
- Ein Bau je Plattform trägt dieselbe Nummer (iOS und macOS, #389): `ASC_PLATFORM` trennt sie.
- Rollen des API-Schlüssels: App Manager oder Admin reichen für „Was testen“ (#347); Admin für das Zertifikat-Aufräumen (#191).

## Recherche (Stand 2026-10-26, Quellen)
- Per ASC-API lässt sich „Submitting your build for external beta testing“ automatisieren; Gruppen, öffentliche Links und Builds sind verwaltbar:
  [Prerelease Versions and Beta Testers](https://developer.apple.com/documentation/appstoreconnectapi/prerelease-versions-and-beta-testers.md).
- `POST /v1/betaAppReviewSubmissions` („Submit an app for beta review“): vorher muss **für alle `betaAppLocalizations` eine Beschreibung** gesetzt sein (`PATCH /v1/betaAppLocalizations/{id}`):
  [Submit an app for beta review](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-betaappreviewsubmissions.md).
- `betaAppReviewDetails` (Kontakt, Demo-Zugang): lesen und `PATCH /v1/betaAppReviewDetails/{id}`; Vor- und Nachname, Telefon, E-Mail lassen sich im Hauptsprachbereich nach dem Setzen nicht mehr leeren (Drittquelle, nicht von Apple bestätigt):
  [Beta App Review Detail](https://developer.apple.com/documentation/appstoreconnectapi/beta-app-review-detail.md).
- `betaAppLocalizations` trägt `feedbackEmail` und `privacyPolicyUrl` (Drittquelle: [fastlane Spaceship](https://rubydoc.info/gems/fastlane/Spaceship/ConnectAPI/BetaAppLocalization)).
- `POST /v1/betaGroups` (App-Beziehung, optional öffentlicher Link): Attribute `isInternalGroup`, `publicLinkEnabled`, `publicLinkLimit` (1–10 000), `feedbackEnabled`; `hasAccessToAllBuilds` gilt nur für interne Gruppen:
  [Beta Groups](https://developer.apple.com/documentation/appstoreconnectapi/beta-groups.md), [fastlane PR 21478](https://redirect.github.com/fastlane/fastlane/pull/21478/files).
- Apple-Hilfe: Vor einer externen Gruppe muss eine interne bestehen; der erste Build einer Version geht beim Zuordnen zu einer externen Gruppe in die Beta-Prüfung, spätere Builds derselben Version brauchen sie womöglich nicht; bis zu 10 000 externe Tester, 90 Tage je Build:
  [Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers).
- Hilfe zum Exportnachweis: bei `ITSAppUsesNonExemptEncryption = false` stellt Apple die Frage nicht (steht schon in `project.yml` und wird im Archiv geprüft).

## Offene Punkte für /20-analyse (noch nicht belegt)
1. Genauer Pfad zum Zuordnen eines Builds zu einer Gruppe (vermutlich `POST /v1/betaGroups/{id}/relationships/builds`) und ob der Schlüssel das darf – Apples Seite dazu nicht abgerufen.
2. Welche Felder Apple für die Beta-Prüfung **tatsächlich verlangt** (Beschreibung, Feedback-E-Mail, Datenschutz-URL, Kontaktdaten) – Drittquellen widersprechen sich bzw. schweigen.
3. Rolle und Rechte des vorhandenen API-Schlüssels (App Manager/Admin?) für Gruppen, Review-Einreichung und Tester; nicht aus der CI lesbar ohne Lauf.
4. Öffentliche Datenschutz-Adresse: Entwurf liegt vor, es gibt noch **keine URL** (Hosting-Entscheidung, Freigabe Henning). Ob Apple sie für TestFlight zwingend braucht, ist offen.
5. iOS und macOS tragen dieselbe Buildnummer, aber getrennte Builds: Beta-Prüfung und Gruppenzuordnung für beide?

## Dependencies
- Upstream: ASC-Secrets im Repository, `asc_wait_build.py` (Build ist `VALID`), Datenschutz-Entwurf (#342), `ITSAppUsesNonExemptEncryption`.
- Downstream: #176 (Abnahme als Nutzer) und die Einladung selbst; #40 N-1/N-2 hängen am selben TestFlight-Lauf.

## Existing Specs
- Keine für ASC-Skripte; die Spezifikationen zu #347 liegen unter `docs/specs/` bzw. in `docs/artifacts/` des Tickets (in `/20-analyse` nachsehen).

## Risks & Considerations
- **Nach außen gerichtet, schwer rückgängig:** Eine Beta-Einreichung geht an Apple; Beschreibung und Kontaktdaten sind öffentlich-nah. Nichts wird ohne Hennings Freigabe des Wortlauts eingereicht.
- Ein Skript in der CI, das bei jedem Build einreicht, wäre falsch: Einreichung nur auf ausdrücklichen Lauf (Eingabe), nicht automatisch.
- Pipeline-Eingriff (`testflight.yml`) darf den Upload nicht gefährden: neue Schritte laufen nach `confirm` und scheitern hart nur für sich.
- Kontaktangaben (Name, Telefon, E-Mail) sind persönliche Daten Hennings – Wert kommt von ihm, nicht aus dem Repo geraten.
- Stufe 3 (Geräteliste): `project.yml`/`Info.plist` werden nicht berührt; Apple-Seite braucht kein Gerät. Nichts auf Hennings Geräten.
- Datenschutz-URL und Rückmeldeweg sind Produktentscheidungen (Henning), nicht technische.

## Analysis

### Type
Feature (Pipeline + Prüfliste, kein sichtbarer App-Teil; kein Pfad der Geräteliste berührt).

### Recherche-Ergebnis zu den offenen Punkten (Stand 2026-10-26)
| # | Frage | Befund | Beleg |
|---|-------|--------|-------|
| 1 | Build einer Gruppe zuordnen | `POST /v1/betaGroups/{id}/relationships/builds` existiert („Add builds to a beta group“); Gruppe anlegen `POST /v1/betaGroups` „optionally enabling TestFlight public links“ | [Add builds](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-betagroups-_id_-relationships-builds.md), [Create group](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-betagroups.md) |
| 2 | Pflichtfelder der Beta-Prüfung | Apple: **Beta App Description Pflicht**, Feedback-E-Mail und Kontaktangaben nötig; Datenschutz-URL: Apple sagt nichts Verbindliches, alter Forenbeitrag „nicht nötig“. Vor `POST /v1/betaAppReviewSubmissions` muss jede `betaAppLocalization` eine Beschreibung tragen. Attributnamen der Detail-Objekte konnte ich bei Apple nicht abrufen (404) | [Provide test info](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information), [Submit](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-betaappreviewsubmissions.md), [Forum](https://developer.apple.com/forums/thread/706282) |
| 3 | Rolle des Schlüssels | Admin (testflight.md Schritt 3) – deckt Gruppen, Einreichung, Details. Nicht belegt, bis ein echter Lauf es zeigt | `docs/reference/testflight.md` |
| 4 | Datenschutz-URL | Repo ist öffentlich → GitHub Pages ohne Kosten und ohne neue Dependency möglich; Pages ist noch nicht eingeschaltet (API 404) | `gh repo view`, `gh api …/pages` |
| 5 | iOS + macOS | Je Plattform ein eigener Build (`ASC_PLATFORM`); Gruppenzuordnung und Einreichung je Build | `asc_what_to_test.py`, `testflight.yml` |
| – | Review-Regeln | Erster Build einer Version: volle Prüfung, spätere derselben Version evtl. nicht; nur ein Build je Version gleichzeitig in Prüfung; max. 6 Einreichungen/24 h; Einreichung per API nicht zurückziehbar (kein DELETE) | [Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers), [Forum 841564](https://developer.apple.com/forums/thread/841564) |
| – | Exportnachweis | `ITSAppUsesNonExemptEncryption=false` steht in `project.yml` und wird im Archiv geprüft → Teil erledigt, nur dokumentieren | `project.yml`, testflight.md Z. 212 |

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_beta_probe.py` | CREATE | Schnitt 1: nur lesen – Rolle, bestehende Gruppen, Beschreibungs-/Kontaktfelder, Builds beider Plattformen |
| `scripts/test_asc_beta_probe.py` | CREATE | Test gegen `FakeASC` |
| `.github/workflows/asc-beta.yml` | CREATE | Handlauf (`workflow_dispatch`), kein Teil von `testflight.yml` |
| `docs/reference/testflight.md` | MODIFY | Prüfliste mit Beleg je Haken, Stolpersteine |
| Schnitt 2: `scripts/asc_beta_release.py` + Test | CREATE | Beschreibung/Feedback-Mail/Kontakt setzen, externe Gruppe + öffentlicher Link, Build zuordnen, einreichen – idempotent, nur auf ausdrücklichen Lauf |

### Scope Assessment
- Zwei Schnitte, je ≤ 4 Dateien. Schnitt 1 ≈ +180 LoC, Schnitt 2 ≈ +250 LoC inkl. Test (an der Grenze; sonst Veröffentlichung des Links als Schnitt 3).
- Risk Level: MEDIUM – nach außen gerichtet, Einreichung nicht rücknehmbar; die Pipeline `testflight.yml` bleibt unberührt.

### Technical Approach
**Ohne Modell, ohne App-Code: reine ASC-API, Standardbibliothek wie `asc_what_to_test.py`.**
1. **Schnitt 1 „Sondieren“** (nur GET): Der echte Lauf sagt, was Apple in Antworten liefert – Rolle, Feldnamen, ob Beschreibung/Kontakt leer sind, ob eine Gruppe existiert. Das ersetzt die Drittquellen durch Belege, bevor irgendetwas geschrieben wird.
2. **Schnitt 2 „Einrichten und einreichen“**: Eingaben (Beschreibung, Feedback-E-Mail, Kontakt, Datenschutz-URL) kommen von Henning als Workflow-Eingaben bzw. Secrets, nie aus dem Repo geraten. Ein Schalter `submit` (Standard aus) trennt Einrichten von Einreichen.
3. **Datenschutz-URL:** GitHub Pages aus `docs/` (öffentliches Repo) – Entwurf wird erst nach Hennings Freigabe veröffentlicht.
4. **Rückmeldeweg:** TestFlight-Feedback (`feedbackEnabled` an der Gruppe, Feedback-E-Mail), kein eigener Kanal.

### Alternativen (Pflicht laut Global-Regeln)
- **A (empfohlen): Skript + Handlauf in der CI.** Wiederholbar je Build/Plattform, Beleg im Lauf-Protokoll.
- **B: einmal in der App-Store-Connect-Oberfläche klicken** (Henning oder ich per Browser). Weniger Code, aber nicht wiederholbar, kein Beleg, und Henning bekäme Klickarbeit – gegen seine Regel „ich übernehme“. Bleibt Rückfall für alles, was die API nicht kann.
- **C: Einladung ohne öffentlichen Link, nur namentliche Tester.** Kein Link-Hosting nötig, aber die DoD („Person über den Einladungslink installieren“) und #371 verlangen den Link. Würde die Einladungs-Entscheidung kippen.
- Gekippte frühere Entscheidung: keine ADR; der Satz in CLAUDE.md „TestFlight stays dormant until people other than Henning test“ ist mit der Einladung überholt und wird dort angepasst.

### Dependencies
- Upstream: #342 (Texte, Datenschutz-Entwurf; PR #709 offen, berührt keine Datei dieses Tickets), ein `VALID`-Build.
- Downstream: #176, die Einladung selbst. #40 (Icon) kommt vor der Einladung, nicht vor diesem Ticket.

### Open Questions (Produkt, Henning)
- [ ] Beschreibung für Beta-Review und Wortlaut freigeben.
- [ ] Kontaktdaten (Name, Telefon, E-Mail) und Feedback-E-Mail – von ihm.
- [ ] Datenschutz-URL: GitHub Pages ok?
- [ ] Soll die Einladung auch den Mac-Bau umfassen (zweiter Review)?

### Entscheidungen Henning (2026-10-26, nach der Analyse)
- Datenschutz-Adresse: **GitHub Pages** aus dem öffentlichen Repo; veröffentlicht erst nach seiner Freigabe des Entwurfs.
- Einladung umfasst **iPhone, iPad und Mac** → beide Builds (`ASC_PLATFORM` iOS und MAC_OS) in Gruppenzuordnung und Beta-Review; Schnitt 2 läuft je Plattform.
- Noch offen für `/30-write-spec`: Wortlaut der Beta-Beschreibung, Kontaktdaten, Feedback-E-Mail (kommen von Henning).

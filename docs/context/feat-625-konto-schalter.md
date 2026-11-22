# Context: feat-625-konto-schalter (#625, Schalter-Schnitt)

## Request Summary
Letzter Teil von #625: Henning gibt die Antworten für Apples Datenschutz-Etikett frei (Vorlage aus S3), danach wird die
Verbindung zu Claude (`LEAccountEnabled`) in Store-Bauten eingeschaltet, das Etikett im ASC-Web eingetragen und das
Update (1.0.2, iOS und Mac) eingereicht. Vorbedingungen erfüllt: #795, #796, #623, #624 geschlossen; Datenschutztext
inkl. Abschrift, Kennung, Weckruf live (S1, S4); AV-Vertrag Hetzner geschlossen (2026-11-22).

## Related Files
| File | Relevance |
|------|-----------|
| `docs/reference/app-store-datenschutzangaben.md` | Vorlage des Etiketts (User ID, Device ID, Other User Content; verknüpft, kein Tracking, App Functionality; „bewusst nicht angegeben“ mit Gründen). Henning muss den Wortlaut freigeben |
| `project.yml:84-86`, `LooseEnds/Info.plist:63` | `LEAccountEnabled: false` – der Schalter an der Quelle (Info.plist ist nur Abbild, `generate`) |
| `LooseEnds/PrivacyInfo.xcprivacy` | heute leer; CI schreibt bei `konto` die drei Typen per `scripts/privacy_manifest.py apply` |
| `scripts/privacy_manifest.py` | `ACCOUNT_TYPES`, eine Quelle für Manifest und Vorlage; `check --account true|false` |
| `.github/workflows/testflight.yml:21-38,120-124,231-274,457-461,538-571` | Eingang `konto` (Vorgabe an), `ACCOUNT_BUILD`, plutil-Schalter nach `generate`, Archivprüfungen (Bool, Manifest) für iOS und Mac |
| `scripts/asc_what_to_test.py:28-40,154` | `ACCOUNT_BUILD_MARK` „KONTO-BAU – nie für den App Store“ in „Was testen“ |
| `scripts/asc_store_version.py:121-150` | `build_lock`: ordnet einen markierten (oder unlesbaren) Bau nie einer Store-Version zu – sperrt heute jeden Konto-Bau für den Store |
| `scripts/test_asc_what_to_test.py:240-286,326-343,434`, `scripts/test_privacy_manifest.py`, `scripts/test_aps_environment.py:131`, `scripts/test_asc_store_version.py` | halten heute „Schalter aus“, „Manifest leer“, zwei plutil-Zeilen, Sperre markierter Bauten |
| `LooseEnds/Claude/AccountWiring.swift:10-15` | `isEnabled`: nur echtes Bool `true` schaltet ein; Rückfall aus |
| `LooseEnds/Views/AccountSection.swift:59` | Hinweis `.notAllowed` „This Apple account is not yet cleared for Claude.“ – was Store-Nutzer heute sähen |
| `server/src/accounts.ts:21-64` | `admit`: mit `ALLOWED_APPLE_SUBS` nur die Liste (heute: Hennings Konto); ohne Liste nur das erste Konto, dann zu. **Es gibt keinen offenen Modus.** Gilt für `/auth/apple` (App) und den OAuth-Weg (claude.ai) |
| henemm-infra `loose-ends/` (Compose, `.env` mit `ALLOWED_APPLE_SUBS`) | Tür im Betrieb; Rollout per `scripts/deploy-loose-ends.sh` |
| `.github/workflows/asc-store-version.yml`, `asc-version-texts.yml`, `asc-review-notes.yml`, `asc-store-submit.yml` + `scripts/asc_*.py` | vorhandener Weg: Version anlegen + Bau zuordnen, „Neu in dieser Version“, Review-Notizen (`docs/reference/app-review-notizen.md`), Vorprüfung + Einreichen (Bestätigung = Versionsnummer) |
| `docs/reference/app-store-texte.md` | Store-Texte; nennen Claude bisher nicht |
| `project.yml:24` | `MARKETING_VERSION: "1.0.2"` (1.0.1 ist von Apple freigegeben) |

## Existing Patterns
- Schalter an der Quelle in `project.yml`, Info.plist generiert, Sync-Tests (`test_info_plist_sync.py`).
- Rechtsaussagen erst nach Hennings ausdrücklichem, datiertem Ja (Memory „Rechtstext erst nach Freigabe live“); Auto-Ampel reicht nicht.
- ASC-Web ohne API (Etikett): Claude öffnet die Seite in Hennings Chrome, Henning meldet sich nur an, Claude trägt ein und prüft gegen die Vorlage (Muster CloudKit-Console, Hetzner-AVV).
- Store-Einreichung über `asc-store-submit.yml` (#893), Version per `asc-store-version.yml anlegen`.

## Dependencies
- Upstream: Dienst auf rennwienix (Tür `ALLOWED_APPLE_SUBS`), Apple Sign in (Services ID, Schlüssel), nginx-Allowlist (`/auth/*`, `/app/*`, `/oauth/*`, `/mcp` sind öffentlich).
- Downstream: jeder Store-Nutzer sieht die Gruppe „Claude“ in den Einstellungen; Apples Prüfer ebenso.

## Existing Specs
- `docs/specs/feat-625-schnitt-2-privacy-manifest.md`, `feat-625-schnitt-3-fragebogen.md`, `feat-615-schnitt-4c2a-freischalten.md` (Konto-Bau-Mechanik), `feat-621-schnitt-6a-*` (Tür, „Regel geht mit #625“)

## Risks & Considerations
- **Die Tür ist zu.** Mit Schalter an und heutiger Tür bekommt jeder Store-Nutzer und Apples Prüfer nach „Mit Apple anmelden“ den Hinweis „nicht freigeschaltet“ → sicheres Review-Risiko (Guideline 2.1, Funktion nicht nutzbar) und schlechte Erfahrung. Vorab-Freischalten des Prüfers geht nicht: seine Apple-Kennung (`sub`) ist vorher unbekannt. Öffnen heißt: neuer offener Modus in `admit` (Server-Code + Test) und Änderung der Betriebs-Umgebung (henemm-infra). Das ist eine Produktentscheidung (wer darf den Dienst nutzen) → Henning.
- Öffnen für alle verändert Last und Kosten auf rennwienix (Henning 2026-11-21: Dienst bleibt dort). Missbrauchsschutz heute: nginx-Zonen + fail2ban; keine Kontogrenze je Tag.
- Etikett gilt app-weit und sofort, auch für die laufende 1.0.1 ohne Konto (Überdeklaration bis zur Freigabe von 1.0.2 – zulässig, aber kurz halten: eintragen direkt vor dem Einreichen).
- Mechanik-Umbau: Konto-Bauten sind heute für den Store gesperrt (Marke + `build_lock`). Wird der Schalter an der Quelle gesetzt, entfällt die Unterscheidung; Marke, Sperre, `konto`-Eingang und mehrere Tests müssen mit umgestellt werden, sonst ordnet `asc_store_version.py` keinen Bau zu. Risiko: > 5 Dateien → Schnitte teilen.
- Geräteliste: `project.yml` und `Info.plist` stehen darauf → Stufe 3 über TestFlight. Inhaltlich hat Henning Konto-Bauten seit Wochen in TestFlight; neu ist nur, dass der Store-Bau dasselbe trägt.
- Apple-Review: Notizen müssen die Funktion erklären (Anmeldung mit Apple, Verbindung in claude.ai als eigener Connector, Konto löschen in der App, 5.1.1(v)). Store-Texte erwähnen Claude nicht – Produktfrage, ob „Neu in dieser Version“/Beschreibung es nennen.
- Mac: dieselbe App, dieselbe Mechanik (`testflight.yml` Mac-Job), Einreichung beider Plattformen gemeinsam.

## Analysis

### Type
Feature (Freischaltung im Store; Server-Tür + Store-Schalter + Store-Schritte)

### Recherche
- App Review Guidelines 2.1: Konto-gebundene Funktionen brauchen ein aktives Demo-Konto oder einen vollwertigen Demo-Modus; Backend-Dienste müssen während der Prüfung erreichbar sein (https://developer.apple.com/app-store/review/guidelines/, https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review).
- Mit „Mit Apple anmelden“ benutzt der Prüfer seine eigene Apple-Kennung; deren `sub` ist vorher unbekannt, Vorab-Freischalten per Liste geht nicht. Fallberichte: Ablehnungen 2.1(a) „konnte nicht auf die App zugreifen“; Umweg anderer Entwickler: Einladungscode in den Review-Notizen (https://developer.apple.com/forums/thread/849775, https://developer.apple.com/forums/thread/719326).

### Befund Tür (verifiziert in `server/src/accounts.ts:20-28`)
`admit` lässt mit Liste nur deren subs ein, ohne Liste nur das erste Konto. Kein offener Modus. Heute gibt es keine Grenze für die Zahl der Konten, nur Körpergrößen, `MAX_DEVICES` = 10 je Konto, nginx-Zonen und fail2ban.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/accounts.ts` | MODIFY | offener Modus (`ALLOWED_APPLE_SUBS=*`), Tagesgrenze neuer Konten unter `ACCOUNT_LOCK_ID` (env, z. B. `MAX_NEW_ACCOUNTS_PER_DAY`) |
| `server/test/accounts.test.ts` | MODIFY | offen, Bestandskonto unter Grenze, Ablehnung an der Grenze, Nebenläufigkeit |
| `project.yml`, `LooseEnds/Info.plist` | MODIFY | `LEAccountEnabled: true` an der Quelle |
| `LooseEnds/PrivacyInfo.xcprivacy` | MODIFY | drei Typen aus `ACCOUNT_TYPES` statisch |
| `.github/workflows/testflight.yml` | MODIFY | Eingang `konto`, `ACCOUNT_BUILD`, plutil-Schalter entfernen; Archivprüfungen fest auf an |
| `scripts/asc_what_to_test.py`, `scripts/asc_store_version.py` | MODIFY | Marke „KONTO-BAU“ und Store-Sperre markierter Bauten entfernen (Sperre unlesbarer Texte bleibt) |
| `scripts/test_privacy_manifest.py`, `test_asc_what_to_test.py`, `test_asc_store_version.py`, `test_aps_environment.py` | MODIFY | auf „Schalter an der Quelle“ umstellen |
| `docs/reference/app-review-notizen.md`, `app-store-texte.md`, CLAUDE.md | MODIFY | Review-Notizen (Anmeldung, Verbindung in claude.ai, Konto löschen 5.1.1(v)), „Neu in 1.0.2“ |
| henemm-infra `loose-ends/.env` | MODIFY (Betrieb) | `ALLOWED_APPLE_SUBS=*`, Grenze; Rollout `deploy-loose-ends.sh` |

### Scope Assessment
- Dateien gesamt > 5 → drei Code-Schnitte:
  - S5a Server-Tür: 2 Dateien, ~+20 LoC App + ~40 Test. Ausrollen harmlos vor dem Store (1.0.1 hat keine Konto-Gruppe).
  - S5b Schalter an der Quelle: `project.yml`, `Info.plist`, `PrivacyInfo.xcprivacy`, `test_privacy_manifest.py` (~35 LoC).
  - S5c Konto-Mechanik zurückbauen: `testflight.yml`, `asc_what_to_test.py`, `asc_store_version.py` + Tests (~60 LoC, überwiegend Löschungen). S5b und S5c müssen zusammen vor dem nächsten TestFlight-Lauf gemergt sein (sonst widersprechen sich Quelle und CI-Prüfung) → ggf. ein PR mit zwei Commits.
  - S5d Store: Etikett nach Hennings datiertem Ja im ASC-Web (direkt vor dem Einreichen), Version anlegen, Texte, Review-Notizen, Einreichen iOS+Mac 1.0.2.
- Risk Level: MEDIUM (Server-Zugang öffnet sich für alle; Store-Bau ändert Fähigkeiten; Review-Risiko)

### Technical Approach
Variante A (Plan-Bewertung): Schalter an der Quelle statt CI-Eingang. Variante B (Konto-Bauten für den Store zulassen) verworfen: Tag-Läufe sind nie `konto`, der Store-Bau hinge an CI-Zustand, die Marke „nie für den App Store“ bliebe irreführend. Server: `*` als offener Modus, Tagesgrenze neuer Konten (Bestandskonten nie betroffen).

### Alternativen
- Einladungscode statt offen: Prüfer bekommt den Code in den Review-Notizen; braucht App-Feld + Server-Prüfung + Übersetzungen, sprengt einen Schnitt, und Apple-Akzeptanz nur aus Fallberichten. Kippt keine ADR, aber verschiebt #625 um mindestens zwei Schnitte.
- Tür zu lassen und Schalter nicht in den Store: #625-DoD („Store-Schalter an“) unerfüllt; erst mit #625-Nachfolger.
- Gruppe im Store an, Tür zu: sichere 2.1-Ablehnung → verworfen.

### Dependencies
Dienst rennwienix (henemm-infra), Apple Sign in, nginx-Allowlist (offen), Vorlage Etikett (S3), Store-Workflows (#893).

### Befunde gegen den Plan
- Offene Tür = Last/Kosten auf rennwienix ohne Kontingent je Konto für Abschrift/Aufträge (nur Körpergrenzen) → Tagesgrenze als Mindestschutz; ist sie erreicht, sieht auch ein Prüfer „nicht freigeschaltet“ → großzügig wählen.
- Ohne Marke/Sperre sind die Archivprüfungen (fest „an“) die einzige Wache.
- Etikett gilt sofort app-weit, auch für 1.0.1 → erst unmittelbar vor dem Einreichen eintragen.

### Open Questions
- [ ] PO: Wer darf den Dienst nutzen (offen mit Tagesgrenze / offen ohne Grenze / Einladungscode / Tür zu)?
- [ ] PO: datiertes Ja zur Fragebogen-Vorlage (`docs/reference/app-store-datenschutzangaben.md`) — spätestens vor S5d.

### PO-Entscheidung 2026-11-22 (AskUserQuestion)
Zugang: **alle mit Apple-Konto, mit Tagesgrenze neuer Konten** (Bestandskonten nie betroffen). Grenze als Betriebswert, Vorgabe 20 neue Konten je 24 h (Tech-Lead-Festlegung, änderbar ohne Code). Offen bleibt das datierte Ja zur Fragebogen-Vorlage vor dem Store-Schnitt.

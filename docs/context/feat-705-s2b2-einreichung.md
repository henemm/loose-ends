# Context: feat-705-s2b2-einreichung

## Request Summary
#705 Schnitt 2b-2: den der Gruppe `Tester` zugeordneten Build je Plattform zum Beta-App-Review einreichen und nach
Apples Freigabe den öffentlichen TestFlight-Link der Gruppe einschalten, begrenzt auf 50 Personen (Henning 2026-10-27).
Ziel der DoD: eine Person außer Henning installiert die App über den Link.

## Stand bei Apple (Läufe 2026-10-27)
- 2a: `betaAppLocalizations` de-DE mit Beschreibung und Feedback-E-Mail gesetzt; Review-Kontakt gesetzt;
  **`privacyPolicyUrl` leer**.
- 2b-1: externe Gruppe `Tester` (Link aus, Feedback an); je Plattform neuester VALID-Build zugeordnet,
  `externalBuildState=READY_FOR_BETA_SUBMISSION`, keine Einreichung.
- Repo-Variable `ASC_PRIVACY_POLICY_URL` existiert nicht (`gh variable list` leer). GitHub Pages ist für das Repo
  nicht eingerichtet (`GET repos/henemm/loose-ends/pages` → 404).
- Datenschutztext: `docs/reference/datenschutz-entwurf.md`, Inhalt von Henning freigegeben (PR #714), nicht veröffentlicht.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_beta_invite.py` | 2b-1: Gruppe + Zuordnung; Docstring verbietet heute Einreichung, Link und PATCH — wird erweitert oder bekommt ein Schwesterskript |
| `scripts/test_asc_beta_invite.py` | `FakeASC`-Nachbau (Lese-/Schreibrouten), `test_never_submits_and_never_enables_link` muss für die neue Aktion umgedeutet, für `zuordnen` erhalten bleiben |
| `.github/workflows/asc-beta.yml` | Handlauf mit `aktion` (probe/einrichten/zuordnen); neue Aktion(en) als eigener Job, Probe danach als Beleg |
| `scripts/asc_beta_probe.py` | liest Gruppe (`link=`, `url=`), Lokalisierung (`datenschutzUrl=`), Build (`extern=`, `einreichung=`), Einreichungen (`betaReviewState`) — Beleg für 2b-2 ohne Änderung |
| `scripts/asc_beta_setup.py` | setzt `privacyPolicyUrl` nur, wenn `ASC_PRIVACY_POLICY_URL` gesetzt ist — der Weg für die Datenschutz-URL existiert schon |
| `scripts/asc_wait_build.py`, `scripts/asc_what_to_test.py` | geteilte Helfer `read_config`, `find_app_id`, `get_json`, `get_data`, `send_json`, `Fatal` |
| `docs/reference/testflight.md` | Prüfliste (Zeilen „Datenschutz-URL“, „Öffentlicher Link“, „Beta-Review (Einreichung)“ offen) und Handlauf-Beschreibung |
| `docs/reference/datenschutz-entwurf.md` | Datenschutztext, der öffentlich erreichbar werden muss |
| `docs/specs/feat-705-schnitt-2b1-gruppe-zuordnung.md` | Muster für Spec, ACs und Belege |

## Existing Patterns
- Lesen vor Schreiben, nur Abweichungen schreiben, zweiter Lauf `geschrieben=0` (idempotent).
- Ausgabe nur Zustandswörter, IDs und Werte maskiert (`message`, `Masked`); Repo ist öffentlich.
- Kontaktdaten nur als Secrets, nie als `workflow_dispatch`-Eingabe.
- Unwiderrufliches nur per ausdrücklichem Handlauf (`workflow_dispatch`), nie automatisch.
- `FakeASC` bildet Apples Routen nach; Lehre aus #721: Routen gegen Apples Doku-Liste je Ressource prüfen
  (`GET /v1/builds/{id}/betaGroups` gibt es nicht → 403).

## Apple-Schnittstellen (Recherche 2026-10-27)
- Einreichung: `POST /v1/betaAppReviewSubmissions` mit Beziehung `build`. Apple-Doku: vorher braucht jede
  `betaAppLocalization` eine Beschreibung (erfüllt). Einreichung ist per API nicht zurückziehbar; max. 6 Einreichungen
  je 24 h; Rolle Account Holder/Admin/App Manager.
- Bekannte Fehler: HTTP 422 `ENTITY_UNPROCESSABLE.BETA_CONTRACT_MISSING` (viele Forenberichte 2026, teils trotz aktiver
  Verträge, nur über Apple-Support lösbar); 422 `ENTITY_UNPROCESSABLE.MISSING_REQUIRED_DATA` bei fehlenden Testinformationen;
  409 bei falschem Rumpf.
- Datenschutz-URL: Apple-Checkliste für externe Tests nennt sie; Apples API-Doku zur Einreichung nennt nur die
  Beschreibung; ein Forenbeitrag von 2022 sagt „nicht nötig“. Nicht abschließend belegt → in der Analyse klären,
  Rückfall: die Einreichung selbst meldet `MISSING_REQUIRED_DATA`.
- Link: `PATCH /v1/betaGroups/{id}` mit `publicLinkEnabled`, `publicLinkLimitEnabled`, `publicLinkLimit` (Attributnamen aus
  Fremdschema und MCP-Wrappern; Apples Doku-Seite rendert die Attributliste nicht → in der Analyse gegen echte
  Probe-Antwort prüfen, die `publicLinkEnabled`/`publicLink` schon liest). Der Link funktioniert für Externe erst, wenn
  ein Build der Gruppe die Beta-Review-Freigabe hat (`externalBuildState=BETA_APPROVED`/`IN_BETA_TESTING`).

## Dependencies
- Upstream: Apples App Store Connect API, Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`; Gruppe und Zuordnung aus 2b-1.
- Downstream: Prüfliste in `testflight.md`; Folgeticket #724 (Zuordnung in `testflight.yml`); später automatische
  Einreichung neuer Builds (nicht Teil dieses Schnitts).

## Existing Specs
- `docs/specs/feat-705-schnitt-1-sondieren.md`, `…-2a-texte-kontakt.md`, `…-2b1-gruppe-zuordnung.md`

## Risks & Considerations
- **Unwiderruflich:** Einreichung kann nicht zurückgenommen werden; nur auf Hennings ausdrückliche Freigabe des echten Laufs.
- **Reihenfolge:** Link erst nach Freigabe durch Apple einschalten; Freigabe dauert Stunden bis Tage → zwei getrennte
  Handläufe (einreichen; Link einschalten), der zweite prüft den Build-Zustand und verweigert vor der Freigabe.
- **Datenschutz-URL fehlt:** Veröffentlichungsort ist eine Produktentscheidung (GitHub Pages des öffentlichen Repos,
  eigene Domain henemm.com, anderer Dienst). Ohne URL droht `MISSING_REQUIRED_DATA` und ein verbrauchter Versuch nicht
  (422 legt nichts an), aber ein verlorener Lauf.
- **BETA_CONTRACT_MISSING:** kann trotz allem auftreten; dann ist der Rückfall die Oberfläche bzw. Apple-Support — klare Meldung nötig.
- **Mac und iPhone:** Einreichung je Build, also je Plattform; Mac-Build kann eigene Anforderungen haben.
- **Öffentliche Ausgabe:** Link-URL ist ein Einladungsschlüssel → im Log nie im Klartext (Probe druckt heute `url=` — prüfen!).
- Scoping: Skript + Test + Workflow + Doku ≈ 4 Dateien; Datenschutz-Veröffentlichung evtl. eigener Schnitt.

## Analysis

### Type
Feature (CI-Handlauf gegen App Store Connect, kein App-Code, keine UI → keine Entwurfsvorschau, kein Pfad der Geräteliste)

### Belege aus Apples OpenAPI-Spezifikation (Version 4.5.1, geladen 2026-10-27)
- `BetaAppReviewSubmissionCreateRequest`: nur `type=betaAppReviewSubmissions` + `relationships.build` (Pflicht), keine Attribute.
- Pfade: `/v1/betaAppReviewSubmissions` kennt nur GET und POST, `/v1/betaAppReviewSubmissions/{id}` nur GET →
  **kein DELETE, Einreichung ist per API unwiderruflich** (bestätigt).
- `BetaReviewState`: `WAITING_FOR_REVIEW`, `IN_REVIEW`, `REJECTED`, `APPROVED`.
- `ExternalBetaState`: u. a. `READY_FOR_BETA_SUBMISSION`, `WAITING_FOR_BETA_REVIEW`, `IN_BETA_REVIEW`, `BETA_REJECTED`,
  `BETA_APPROVED`, `IN_BETA_TESTING`, `MISSING_EXPORT_COMPLIANCE`.
- `BetaGroupUpdateRequest.attributes`: `publicLinkEnabled`, `publicLinkLimitEnabled`, `publicLinkLimit` (int), `feedbackEnabled`,
  `name` (+ zwei Plattform-Schalter) → die Attributnamen aus der Recherche stimmen. `BetaGroup` liefert `publicLink`, `publicLinkId`.
- `BetaAppLocalization.attributes` enthält `privacyPolicyUrl`; der Weg zum Setzen existiert in `asc_beta_setup.py`.

### Datenschutz-URL: verlangt Apple sie?
- Apples Hilfe „Provide test information“ markiert nur die Beta-Beschreibung als Pflicht; die API-Einreichung verlangt
  laut Doku nur die Beschreibung. → **Technisch nicht nachweislich Pflicht.**
- Apples Hilfe „App privacy“ nennt die Datenschutz-URL Pflicht für alle Apps; Richtlinie 5.1.1(i) verlangt den Link in den
  Metadaten. Beta-Review prüft nach den App-Review-Richtlinien. Forenberichte: Ablehnung im Beta-Review wegen fehlender
  Datenschutzangabe (HealthKit-Fall). → **Ablehnungsrisiko**, und jede Ablehnung kostet einen Review-Zyklus (Stunden bis Tage).
- Gebraucht wird sie ohnehin vor dem App Store (#342). Text ist freigegeben, nur nicht veröffentlicht.

### Weitere Befunde
- `send_json` wirft bei 4xx nur „HTTP 422 for POST …“ ohne Apples Fehlercode → `BETA_CONTRACT_MISSING` und
  `MISSING_REQUIRED_DATA` wären im Log nicht unterscheidbar. Für die Einreichung muss der `errors[].code` aus dem Rumpf
  gelesen werden (eigener POST oder `send_json` gibt den Rumpf in `Fatal` mit; Rumpf enthält keine Kontaktdaten, nur Codes).
- `asc_beta_probe.py:103-106` druckt `url=<publicLink>` **im Klartext**, sobald der Link an ist. Repo und Actions-Logs sind
  öffentlich → jeder könnte die 50 Plätze belegen. Muss vor dem Einschalten auf `url=gesetzt/-` umgestellt werden.
  Henning findet den Link in App Store Connect unter TestFlight → Gruppe „Tester“.
- Der Link wirkt für Externe erst, wenn ein Build der Gruppe `BETA_APPROVED` ist → Link-Lauf ist ein eigener, späterer Handlauf.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_beta_review.py` | CREATE | `einreichen`: je Plattform Gruppen-Build lesen, Zustand prüfen, nur bei `READY_FOR_BETA_SUBMISSION` POST; Vorprüfung Beschreibung (+ Datenschutz-URL); Apples Fehlercode lesbar. `link`: nur bei `BETA_APPROVED`/`IN_BETA_TESTING` PATCH Link an, Limit 50 |
| `scripts/test_asc_beta_review.py` | CREATE | `FakeASC`-Muster aus `test_asc_beta_invite.py`, Routen gegen OpenAPI-Pfadliste |
| `.github/workflows/asc-beta.yml` | MODIFY | Aktionen `einreichen`, `link` als eigene Jobs, Probe danach |
| `scripts/asc_beta_probe.py` | MODIFY | `url=` maskieren, Limit ausgeben (`limit=50`) |
| `docs/reference/testflight.md` | MODIFY | Prüfliste, Handlauf-Beschreibung |
| Datenschutzseite (Ort je nach Entscheidung) | CREATE | öffentliche Fassung aus `datenschutz-entwurf.md` ohne Code-Belege; Repo-Variable `ASC_PRIVACY_POLICY_URL` |

### Scope Assessment
- Gesamt ≈ 6–7 Dateien, ≈ +350 LoC → **sprengt die Limits**, daher drei Schnitte:
  - **2b-2a Datenschutzseite:** Seite veröffentlichen, Variable setzen, `aktion=einrichten` setzt die URL (Weg existiert). ~2–3 Dateien.
  - **2b-2b Einreichen:** Skript `einreichen` + Test + Workflow + Prüfliste. ~4 Dateien, ~+220 LoC.
  - **2b-2c Link:** `link` + Probe-Maskierung + Prüfliste, erst nach Apples Freigabe. ~4 Dateien, ~+120 LoC.
- Risk Level: MEDIUM (unwiderruflicher Schritt bei Apple, öffentliche Logs; kein App-Code)

### Technical Approach (Empfehlung)
Erst die Datenschutzseite (2b-2a), dann einreichen (2b-2b), dann Link (2b-2c). Begründung: die Einreichung ist
unwiderruflich und eine Ablehnung kostet Tage; die URL ist ohnehin vor dem App Store nötig, der Text liegt freigegeben vor,
und der Setz-Weg existiert. Einreichen-Skript: Lesen vor Schreiben, nur `READY_FOR_BETA_SUBMISSION` wird eingereicht,
alle späteren Zustände = `vorhanden` (idempotent), `BETA_REJECTED`/`MISSING_EXPORT_COMPLIANCE` = Abbruch mit Zustandswort;
Vorprüfung verweigert ohne Beschreibung/URL, bevor ein POST rausgeht. Echter Lauf nur auf Hennings ausdrückliche Freigabe.

**Alternative 1:** Ohne Datenschutz-URL sofort einreichen (2b-2b vor 2b-2a). Spart einen Schnitt, riskiert eine Ablehnung
und Tage Wartezeit; kippt keine ADR.
**Alternative 2:** Einreichung und Link einmalig in der App-Store-Connect-Oberfläche statt per Skript. Weniger Code, aber
Arbeit bei Henning (gegen „nichts an Henning weiterreichen“) und für jeden neuen Build wieder Handarbeit; die
automatische Einreichung neuer Builds (Folgeticket) bräuchte das Skript ohnehin.

### Dependencies
- Geteilte Helfer `read_config`, `find_app_id`, `get_json`, `get_data`, `send_json`, `Fatal`, `message`/`Masked`.
- 2b-1-Zustand bei Apple (Gruppe `Tester`, beide Builds `READY_FOR_BETA_SUBMISSION`).

### Entscheidung Datenschutzseite (Henning, 2026-10-27)
„Du hast Zugriff auf meinen Webspace. du kannst auch eine andere Claude Code Instanz fragen, aber das macht es nur
komplizierter." → **Seite auf henemm.com, ich selbst, ohne die Website-Instanz.** Damit auch: erst Datenschutzseite,
dann einreichen.
- henemm.com = Hugo-Site, Repo `henemm/henemm-website` (privat, `main`), Live-Stand `/var/www/henemm` auf rennwienix,
  Auto-Deploy alle 5 min (git pull + `hugo --minify`). Nie direkt in `/var/www/henemm/` editieren.
- Laut dessen CLAUDE.md: `content/` frei editierbar ohne Spec-Zwang; Build-Check `hugo --gc --minify --quiet`;
  nach Deploy `./scripts/verify-live.sh <pfad>`.
- Vorbild: `content/legal/gregor-zwanzig/_index.md` + `privacy-policy/_index.md` (live,
  `https://www.henemm.com/legal/gregor-zwanzig/privacy-policy/`, Verantwortlicher dort HENEMM GmbH mit Anschrift,
  Verweis aufs Impressum).
- Ziel-URL: `https://www.henemm.com/legal/loose-ends/privacy-policy/` → Repo-Variable `ASC_PRIVACY_POLICY_URL`,
  dann `aktion=einrichten` (setzt nur die URL, Rest `unverändert`).

### Entscheidung Verantwortlicher (Henning, 2026-10-27, Auswahl „HENEMM GmbH“)
Wie Gregor Zwanzig: HENEMM GmbH, Eichenaue 14, 48157 Münster, vertreten durch den Geschäftsführer Henning Emmrich,
E-Mail henning@henemm.com, Verweis aufs Impressum (`/footer-information/imprint/`). `datenschutz-entwurf.md` im selben
Schnitt nachziehen.

### Zuschnitt dieses Workflows
Dieser Workflow (`feat-705-s2b2-einreichung`) wird **2b-2a Datenschutzseite**: Seite in `henemm/henemm-website`
(`content/legal/loose-ends/_index.md`, `…/privacy-policy/_index.md`, öffentliche Fassung des Entwurfs ohne Code-Belege),
Live-Prüfung, Repo-Variable `ASC_PRIVACY_POLICY_URL`, Handlauf `einrichten`, Probe zeigt `datenschutzUrl=gesetzt`;
im Loose-Ends-Repo nur `datenschutz-entwurf.md` (Verantwortlicher, Status „veröffentlicht“) und Prüfliste `testflight.md`.
2b-2b (einreichen) und 2b-2c (Link) folgen als eigene Workflows.

### Open Questions
- keine
- Mac-Build: wird mit eingereicht (wie 2b-1 beide zugeordnet hat); eigene Ablehnung des Mac-Builds blockiert iOS nicht.

# Context: feat-705-s2b2b-einreichung (#705 Schnitt 2b-2b)

## Request Summary
Die der externen Gruppe `Tester` zugeordneten Builds (iOS und macOS) einmal zum Beta-App-Review bei Apple einreichen,
als eigener Handlauf in `asc-beta.yml`. Die Einreichung ist per API nicht zurückziehbar und läuft nur auf Hennings
ausdrückliche Freigabe. Der öffentliche Link (Limit 50) ist Schnitt 2b-2c, nicht dieser.

## Stand vor diesem Schnitt (aus #705, Memory `loose-ends-705-s2-entscheidungen`)
- 2a: Beta-Beschreibung, Feedback-E-Mail, Review-Kontakt gesetzt (Läufe 40466472742, 40466601395).
- 2b-1: externe Gruppe `Tester` (Link aus, Feedback an), je Plattform neuester VALID-Build zugeordnet, beide
  `extern=READY_FOR_BETA_SUBMISSION`, Exportnachweis hält (Läufe 40534641955, 40535068594).
- 2b-2a: Datenschutz-URL gesetzt (Läufe 40583033733, 40583443351, PR #728).
- Probe zeigt `einreichung keine`.
- Folgeticket #724 (offen): neue Builds automatisch der Gruppe zuordnen. Bis dahin liegt in `Tester` evtl. nicht der
  neueste Build.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_beta_invite.py` | Gruppe + Zuordnung (2b-1); Muster für plan/apply, `message()`-Maskierung, `Masked`-stdout, FORBIDDEN-Text. Kandidat für die Einreichung oder Vorlage für ein eigenes Skript |
| `scripts/test_asc_beta_invite.py` | `FakeASC` mit Zustand (GET liest, POST schreibt, Anfragen gemerkt); `test_never_submits_and_never_enables_link` muss für `zuordnen` weiter gelten |
| `scripts/asc_beta_probe.py` | Liest schon `GET /v1/builds/{id}/betaAppReviewSubmission` und `GET /v1/betaAppReviewSubmissions?filter[build]=…` → Beleg nach der Einreichung. Druckt `url=` des öffentlichen Links unmaskiert (Thema 2b-2c) |
| `scripts/asc_beta_setup.py` | Muster 2a (Lokalisierung, Review-Detail) |
| `scripts/asc_wait_build.py`, `scripts/asc_what_to_test.py` | geteilte Helfer: `read_config`, `find_app_id`, `get_json`, `platform_filter`, `get_data`, `send_json`, `Fatal` |
| `.github/workflows/asc-beta.yml` | `workflow_dispatch` mit `aktion` (probe/einrichten/zuordnen); Jobs setup/assign/probe; neue Wahl + Job nötig; Probe hängt per `needs` an allen Jobs |
| `docs/reference/testflight.md` | Prüfliste vor der Einladung (Zeile „Beta-Review (Einreichung) | offen“), Abschnitt Schnitt 2 (Z. 211) |
| `CLAUDE.md` | nennt `asc-beta.yml aktion=einrichten`; ggf. neue Aktion ergänzen |

## Existing Patterns
- Handläufe lesen zuerst, schreiben nur Abweichungen (idempotent); Ausgabe nur Zustandswörter, nie IDs, Buildnummern
  der Builds im invite-Skript nicht, Links nie; `::error::` je Plattform, eine Plattform verdeckt die andere nicht.
- Secrets nur als Repo-Secrets/Variablen, nie als Dispatch-Eingabe (Repo öffentlich).
- Tests gegen lokalen Nachbau `FakeASC`; Lehre aus 2b-1: Nachbau-Routen gegen Apples Doku-Liste je Ressource prüfen
  (GET builds→betaGroups gab real 403).
- Echter Lauf als Beleg in #705 und Prüfliste, Lauf-Links mit Zeilenauszug.

## Apple-Schnittstelle (Recherche 2026-10-28)
- `POST /v1/betaAppReviewSubmissions`, Rumpf `{"data":{"type":"betaAppReviewSubmissions","relationships":{"build":
  {"data":{"type":"builds","id":…}}}}}`, keine Attribute. Antwort 201 mit `betaReviewState`
  (`WAITING_FOR_REVIEW`, `IN_REVIEW`, `APPROVED`, `REJECTED`).
  Quelle: https://developer.apple.com/documentation/appstoreconnectapi/post-v1-betaappreviewsubmissions (Seiteninhalt
  per Abruf nicht lesbar; Rumpf bestätigt durch Forenbeitrag https://developer.apple.com/forums/thread/852029).
- Lesen: `GET /v1/betaAppReviewSubmissions?filter[build]=…` (Probe nutzt das schon).
- Fehlerbilder aus Foren: 422 `ENTITY_UNPROCESSABLE.BETA_CONTRACT_MISSING` (Vereinbarung fehlt, ungelöst,
  thread/852029); 409 bei schon bestehender Einreichung bzw. Zustandskonflikt (thread/849771, 841564); 403 bei fehlender
  Rolle.
- Apple: Review ist nur für den ersten Build einer Version Pflicht, spätere „may not require a full review“
  (https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/). Je Plattform ein
  eigener Build, also je Plattform eine Einreichung.

## Dependencies
- Upstream: Apples API, Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`; Zustand aus 2a/2b-1/2b-2a.
- Downstream: 2b-2c (Link erst nach `APPROVED`), #724 (Zuordnung je neuem Build; später evtl. auch Einreichung je
  neuer Version), DoD #705 „eine Person außer Henning installiert über den Link“.

## Existing Specs
- `docs/specs/feat-705-schnitt-2b1-gruppe-zuordnung.md` — Vorlage für Aufbau, ACs und Tests
- `docs/specs/feat-705-schnitt-2b2a-datenschutzseite.md`, `…-2a-texte-kontakt.md`, `…-1-sondieren.md`

## Risks & Considerations
- **Unumkehrbar:** Einreichung nicht zurückziehbar → Skript darf nur auf ausdrückliche Aktion einreichen, nie
  nebenbei (`zuordnen`, `probe`, `einrichten` bleiben ohne POST auf `betaAppReviewSubmissions`). Echter Lauf nur nach
  Hennings Freigabe.
- **Welcher Build:** der der Gruppe `Tester` zugeordnete mit `extern=READY_FOR_BETA_SUBMISSION`, nicht blind der
  neueste (seit 2b-1 können neuere Builds hochgeladen sein, #724 offen). Offen für die Analyse: vorher `zuordnen`
  erzwingen oder nur einreichen, was zugeordnet ist.
- **Beide Plattformen oder nur iOS:** Mac-Einreichung prüft Apple eigens; Ablehnung einer Plattform darf die andere
  nicht blockieren. Produktfrage für Henning, falls nicht klar.
- **Idempotenz:** bestehende Einreichung (jeder Zustand) → kein zweiter POST; 409 als Zustand melden, nicht als Absturz.
- **422 BETA_CONTRACT_MISSING:** Vereinbarung bei Apple fehlt → klare Meldung, Aktion liegt bei Henning (Konto-Inhaber).
- **Gate-Kreis aus 2b-2a:** AC „echter Lauf“ in 6b sperrt Commit → echten Lauf in die DoD/Abnahme legen, nicht als AC.
- **Öffentliches Repo:** keine IDs/Links in Ausgaben; Probe-`url=` erst in 2b-2c maskieren (dort wird der Link an).
- Kein Pfad der Geräteliste berührt (nur `scripts/`, Workflow-Datei, Doku).

## Analysis

### Type
Feature (Handlauf, keine App-Änderung)

### Ergänzende Recherche (2026-10-28)
- `POST /v1/betaAppReviewSubmissions` ist Apples dokumentierter Weg, einen Build für externe Tests einzureichen; die
  Beziehung nimmt nur `builds` an (https://developer.apple.com/forums/thread/841564,
  https://developer.apple.com/documentation/appstoreconnectapi/betaappreviewsubmissionresponse.md).
- Ob „Was testen“ vor der Einreichung Pflicht ist, steht in keiner gefundenen Quelle. Unkritisch: `testflight.yml`
  schreibt es für jeden Build (#347), und Apples eigener Bereitschaftszustand `externalBuildState=
  READY_FOR_BETA_SUBMISSION` ist die Vorbedingung, an der das Skript festmacht.

### Entscheidungen (technisch, Claude)
- **Welcher Build:** `einreichen` ordnet zuerst zu (bestehender Ablauf aus 2b-1: neuester VALID-Build je Plattform in
  `Tester`) und reicht genau diesen Build ein. So bekommen Tester den aktuellen Stand, und #724 ist für diesen einen
  Lauf überbrückt. Nicht „was gerade in der Gruppe liegt“: die Gruppen-Buildliste trägt keine Plattform und kann alte
  Builds enthalten.
- **Vorbedingung je Plattform:** nur POST, wenn (a) `GET /v1/betaAppReviewSubmissions?filter[build]=…` leer ist und
  (b) `externalBuildState == READY_FOR_BETA_SUBMISSION`. Sonst Zustandszeile ohne Schreiben
  (`einreichung plattform=… zustand=vorhanden|nicht-bereit extern=…`).
- **Fehler:** 409 → `zustand=konflikt` (kein Absturz, Exit 0, Probe zeigt Apples Zustand); 422 mit
  `BETA_CONTRACT_MISSING` → `::error::` „Vereinbarung bei Apple fehlt, Konto-Inhaber muss sie annehmen“; 403 →
  bestehender FORBIDDEN-Text. Eine Plattform verdeckt die andere nicht.
- **Ort:** Erweiterung von `asc_beta_invite.py` um den Schalter `--einreichen` statt eines eigenen Skripts —
  Gruppe, Build-Wahl, `message()`/`Masked` und FakeASC werden wiederverwendet. Ohne Schalter bleibt jede Einreichung
  ausgeschlossen (`test_never_submits_and_never_enables_link` gilt unverändert für den Aufruf ohne Schalter).
- **Handlauf:** neue Wahl `einreichen` in `asc-beta.yml`, eigener Job `submit` (`asc_beta_invite.py --einreichen`),
  Probe hängt per `needs` auch an ihm. Die yml selbst nennt weiter kein `betaAppReviewSubmissions`.
- **Echter Lauf:** nicht als AC (Gate-Kreis aus 2b-2a), sondern Abnahme nach dem Merge, und nur nach Hennings
  ausdrücklicher Freigabe, weil unumkehrbar.

### Alternative
Eigenes Skript `asc_beta_submit.py`, das nur einreicht, was schon in `Tester` liegt (Plattform per
`GET /v1/builds/{id}?include=preReleaseVersion`). Vorteil: strikte Trennung „kann nie einreichen“ / „reicht ein“.
Nachteil: ~300 LoC (über dem Limit, also zwei Schnitte), Build-Wahl doppelt, und es reicht womöglich einen
veralteten Build ein. Verworfen zugunsten des Schalters; die Trennung sichert dort ein Test statt eine Datei.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_beta_invite.py` | MODIFY | `--einreichen`: Vorbedingung lesen, je Plattform höchstens ein POST, Fehlerwörter |
| `scripts/test_asc_beta_invite.py` | MODIFY | FakeASC um Einreichungs-Routen (GET-Liste, POST, 409/422); Tests: ohne Schalter nie, mit Schalter je Plattform einmal, zweiter Lauf schreibt nicht, nicht-bereit, Vertrag fehlt, eine Plattform verdeckt nicht, Ausgabe ohne IDs; Workflow-Test um `einreichen` |
| `.github/workflows/asc-beta.yml` | MODIFY | Wahl `einreichen`, Job `submit`, Probe-`needs` |
| `docs/reference/testflight.md` | MODIFY | Prüfliste „Beta-Review (Einreichung)“, Abschnitt Schnitt 2 |
| `CLAUDE.md` | MODIFY | ein Halbsatz: `aktion=einreichen` |

### Scope Assessment
- Files: 5
- Estimated LoC: ~+220/-5 (Skript ~60, Tests ~120, yml ~25, Doku ~15) — knapp unter 250
- Risk Level: MEDIUM — Code klein und isoliert, aber der echte Lauf ist bei Apple nicht zurückzunehmen

### Dependencies
- Upstream: 2a, 2b-1, 2b-2a erledigt; Secrets vorhanden; Apple-Vereinbarung für Beta (sonst 422).
- Downstream: 2b-2c Link erst nach `APPROVED`; #724.

### Open Questions
- [x] Beide Plattformen oder nur iOS einreichen? → Henning 2026-10-28: „iPhone/iPad und Mac und Apple Watch“.
  Die Watch-App steckt im iOS-Build (`project.yml` Z. 42–43: `LooseEndsWatch` mit `platformFilter: iOS` eingebettet;
  `testflight.yml` prüft `com.henning.looseends.watchkitapp` im iOS-Archiv). Die iOS-Einreichung deckt die Watch also
  mit ab; es gibt keine eigene watchOS-Einreichung. Die Spec nennt das ausdrücklich, und die Prüfliste führt die Watch
  als Teil des iOS-Builds.

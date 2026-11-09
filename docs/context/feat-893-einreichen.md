# Context: feat-893-einreichen

## Request Summary
Version 1.0.1 für iPhone/iPad (IOS) und Mac (MAC_OS) per Werkzeug bei Apple zur Prüfung einreichen. Henning hat das
Einreichen am 2026-11-09 per Auswahl freigegeben (Folge aus #842). Es fehlt ein Schreibweg `einreichen`; das bestehende
Werkzeug liest und legt an, reicht aber nie ein.

## Recherche (Apple-Schnittstelle, Stand 2026-11-09)
- Einreichen läuft nur noch über die Reviews-Submission-API, drei Schritte, keine atomare Variante:
  1. `POST /v1/reviewSubmissions` (Beziehung `app`; Attribut `platform` optional, beim Anlegen nicht mehr Pflicht)
  2. `POST /v1/reviewSubmissionItems` (Beziehungen `reviewSubmission` + `appStoreVersion`)
  3. `PATCH /v1/reviewSubmissions/{id}` mit `attributes.submitted = true`
  Ein PATCH ohne Item liefert 422. Das ältere `appStoreVersionSubmissions` ist nicht mehr der empfohlene Weg (404-Berichte).
- **Je Plattform eine eigene Einreichung**: „App versions for each platform are submitted separately“; Items
  verschiedener Plattformen teilen keine Einreichung; je Plattform höchstens eine Einreichung mit App-Version in Prüfung.
  → „zusammen einreichen“ heißt: zwei Einreichungen (IOS, MAC_OS) im selben Lauf, nicht eine gemeinsame.
- Quellen: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review ,
  https://developer.apple.com/documentation/appstoreconnectapi/reviewsubmissioncreaterequest ,
  https://dev.to/snake_sun/the-asc-apis-3-step-review-submission-flow-and-why-appstoreversionsubmissions-is-gone-24ld ,
  https://developer.apple.com/forums/thread/802281
- Zustände der Einreichung (Apple-Enum `ReviewSubmissionState`): READY_FOR_REVIEW, WAITING_FOR_REVIEW, IN_REVIEW,
  UNRESOLVED_ISSUES, CANCELING, COMPLETING, COMPLETE. Version nach Einreichen: `appStoreState` WAITING_FOR_REVIEW.
  Offene Einreichungen lesbar über `GET /v1/apps/{id}/reviewSubmissions` bzw. `GET /v1/reviewSubmissions?filter[app]=…&filter[platform]=…&filter[state]=…`
  (im echten Lauf gegenprüfen; im Nachbau nur Apples Pfade/Formen abbilden).

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_store_version.py` (226 Z.) | `lesen`/`anlegen`; hier kommt `einreichen` dazu (oder eigenes Skript, s. Risiken) |
| `scripts/test_asc_store_version.py` (430 Z.) | Nachbau `FakeASC` mit Zustand (Versionen, Bauten, Zuordnung); erweitern um reviewSubmissions/Items |
| `.github/workflows/asc-store-version.yml` | Handlauf, Auswahl `aktion`; neue Option `einreichen`, Eingabe-Sperre (z. B. Pflicht-Bestätigungsfeld) |
| `scripts/asc_version_texts.py` | `app_versions`, `editable_version`, `localizations`, `EDITABLE`, `PLATFORMS` |
| `scripts/asc_wait_build.py`, `asc_what_to_test.py`, `asc_beta_probe.py` | `read_config`, `find_app_id`, `get_json`, `get_data`, `send_json` (liefert keinen Rumpf!), `records`, `attributes` |
| `scripts/asc_beta_invite.py` | Vorbild für einen nicht rücknehmbaren Einreich-POST: genau ein POST, nie wiederholt, eigener urllib-Aufruf mit Rumpf, 409/403/422-Meldungen, `Masked`-Ausgabe ohne IDs |
| `scripts/asc_store_probe.py` | Beleg „Store-Probe“ für die DoD (WAITING_FOR_REVIEW) |
| `CLAUDE.md` (Build-Abschnitt, Zeile `asc-store-version.yml`) | Doku der Aktionen; „nie einreichen“ wird angepasst |
| `docs/specs/feat-842-schnitt-5a-1-mac-version-anlegen.md` | Vorgänger-Spec, gleicher Stil/Format |

## Existing Patterns
- Plan nur mit GET, jede Abweichung → `Fatal` bevor geschrieben wird („nichts geschrieben“); dann schreiben; dann
  Gegenprobe im selben Lauf; Ausgabe `zusammenfassung geschrieben=N`.
- Idempotenz: Vorhandenes wird übersprungen („schon vorhanden, übersprungen“), nie umgehängt, nie gelöscht.
- Fehlermeldungen ohne Apples Rohantwort (403/409 eigene Sätze), keine IDs in Logs bei Einreich-Werkzeugen (`Masked`).
- Workflow: `pull_request` führt nur Tests aus; Handlauf per `workflow_dispatch` mit Auswahl.
- Nicht rücknehmbare Schritte (Beta-Einreichung) laufen nur nach Hennings Wort und werden nie automatisch wiederholt.

## Dependencies
- Upstream: App Store Connect API (JWT mit ASC-Schlüssel in Secrets), geteilte Helfer oben.
- Downstream: nur der Handlauf; kein App-Code, kein Gerätepfad berührt (keine Stufe 3).

## Existing Specs
- `docs/specs/feat-842-schnitt-5a-1-mac-version-anlegen.md`, `feat-842-schnitt-5a-2-texte.md`, `feat-842-schnitt-5b-mac-bilder.md`

## Ist-Stand bei Apple (Store-Probe 2026-11-09, Lauf 42689844126)
iOS und Mac 1.0.1 PREPARE_FOR_SUBMISSION, Bau 133 VALID und zugeordnet, de-DE und en-US mit Texten und Bildern,
Review-Detail vorhanden.

## Risks & Considerations
- **Nicht rücknehmbar**: einmal eingereicht, ist die Version in Apples Prüfung (zurückziehen nur über Abbrechen der
  Einreichung). Handlauf nur nach ausdrücklichem Wort; Eingabe-Sperre im Workflow.
- **Halbe Läufe**: Schritt 1 angelegt, Schritt 2/3 gescheitert → zweiter Lauf muss eine offene READY_FOR_REVIEW-Einreichung
  der Plattform wiederverwenden statt eine zweite anzulegen; ein schon vorhandenes Item nicht doppelt anlegen.
- **Plattformen getrennt**: scheitert Mac nach erfolgreichem iOS, steht iOS schon in Prüfung. Daher Vorprüfung für
  beide Plattformen vollständig vor dem ersten Schreiben.
- `send_json` gibt keinen Rumpf zurück → neue Einreichungs-ID per erneutem GET oder eigenem POST mit Rumpf (wie
  `post_submission` in `asc_beta_invite.py`).
- Vorprüfung „Texte vollständig“: welche Felder Pflicht sind (description, keywords, supportUrl, whatsNew bei Update;
  promotionalText optional) und Bilder je Locale > 0; Apple prüft zusätzlich selbst und antwortet ggf. 409/422 beim PATCH.
- Umfang: Skript wächst um ~80–120 Z., Tests um ~150 Z., Workflow + CLAUDE.md wenige Zeilen → nahe ±250 LoC; Tests
  zählen erfahrungsgemäß über das Limit (vgl. LoC-Überhang durch Sicherheitstests).
- Alternative: eigenes Skript `asc_store_submit.py` statt Erweiterung von `asc_store_version.py` (trennt den einzigen
  nicht rücknehmbaren Weg vom Lese-/Anlegewerkzeug, eigener Workflow mit eigener Sperre).

## Analysis

### Type
Feature (Werkzeug, kein App-Code; kein Pfad der Geräteliste berührt)

### Entscheidung: eigenes Skript statt Erweiterung
`asc_store_version.py` garantiert heute „nie einreichen“ (Dateikopf, Workflow-Kommentar, CLAUDE.md und der Test
`test_never_deletes_submits_or_writes_texts` mit `assertNotIn("ubmission", path)`). Diese Garantie bleibt stehen; der
einzige nicht rücknehmbare Weg bekommt eine eigene Datei, eigenen Workflow, eigene `concurrency`-Gruppe und eigene Sperre.
Helfer werden importiert (`get_one`, `current_build`, `report_version` aus `asc_store_version`; `app_versions`,
`editable_version`, `localizations`, `EDITABLE`, `PLATFORMS` aus `asc_version_texts`; `Masked`/`message` aus
`asc_beta_invite`), der Nachbau `FakeASC` wird aus `test_asc_store_version` importiert und im neuen Test um
reviewSubmissions/Items erweitert (Unterklasse, bestehende Testdatei unverändert).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_store_submit.py` | CREATE | `pruefen` (nur GET, Vorprüfung beider Plattformen) und `einreichen` (Schnitt B) |
| `scripts/test_asc_store_submit.py` | CREATE | FakeASC-Unterklasse mit reviewSubmissions, Items, Zuständen |
| `.github/workflows/asc-store-submit.yml` | CREATE | `pull_request` = nur Tests; `workflow_dispatch` mit `aktion` und (Schnitt B) Sperrwort |
| `CLAUDE.md` | MODIFY | eine Zeile im Build-Abschnitt |

### Schnitte (±250 LoC je Schnitt)
- **Schnitt A `pruefen`** (~200 LoC): Vorprüfung nur lesend, Ausgabe je Plattform „bereit“ oder Grund; liest die
  offenen Einreichungen (`GET /v1/reviewSubmissions?filter[app]=…&filter[platform]=…`) und belegt im echten Lauf die
  Listenform von Apple, bevor ein Schreibweg gebaut wird. Nutzen für sich: Stand vor dem Einreichen ohne Risiko.
- **Schnitt B `einreichen`** (~220 LoC): Sperrwort `EINREICHEN 1.0.1` (Eingabe `bestaetigung`, im Skript geprüft über
  env), je Plattform: READY_FOR_REVIEW-Einreichung wiederverwenden oder genau ein POST `/v1/reviewSubmissions`
  (eigener Aufruf mit Rumpf, nie wiederholt; ID aus Rumpf, Rückfall erneutes GET, 0 oder >1 → Abbruch), Item nur wenn
  die Version noch nicht drin ist (`GET /v1/reviewSubmissions/{id}/items`), PATCH `submitted=true` als ein Versuch
  (bei 5xx erst Zustand lesen, nie blind wiederholen). Reihenfolge IOS, dann MAC_OS. Gegenprobe: `appStoreState`
  WAITING_FOR_REVIEW je Plattform. `zusammenfassung geschrieben=N` (≤ 6). Ausgabe über `Masked`, nie Apples Rohantwort.

### Vorprüfung (beide Plattformen vollständig, vor dem ersten Schreiben; sonst Fatal „nichts geschrieben“)
- genau eine Version PREPARE_FOR_SUBMISSION je Plattform, beide mit derselben `versionString`
- Bau zugeordnet, `processingState=VALID`, nicht abgelaufen, Vorabversion = Zielversion
- de-DE und en-US vorhanden; `description`, `keywords`, `supportUrl`, `whatsNew` (Update-Version) nicht leer;
  `promotionalText` optional; je Locale mindestens ein Bild
- Review-Detail vorhanden
- keine Einreichung der Plattform in WAITING_FOR_REVIEW, IN_REVIEW, UNRESOLVED_ISSUES, CANCELING, COMPLETING;
  READY_FOR_REVIEW (höchstens eine) wird in Schnitt B wiederverwendet; ein unbekannter Zustand gilt als belegt (Abbruch)

### Scope Assessment
- Files: 4 je Schnitt (Skript, Test, Workflow, CLAUDE.md)
- Estimated LoC: A ~+200, B ~+220
- Risk Level: MEDIUM (Schnitt A niedrig, nur lesen; Schnitt B nicht rücknehmbar, aber nur nach Hennings Wort und
  Sperrwort)

### Risiken / Befunde gegen den Plan
- Apple-Formen (Filter der Liste, Items-Pfad, `platform` beim POST) nur aus Doku bekannt; der Nachbau beweist sie nicht →
  deshalb Schnitt A zuerst mit echtem Lauf.
- Apple kann beim PATCH mehr verlangen, als per API vorab prüfbar ist (Exportangaben, Altersfreigabe, Datenschutz);
  dann steht eine READY_FOR_REVIEW-Einreichung mit Item, und der zweite Lauf verwendet sie wieder.
- Plattformen nicht atomar: scheitert Mac nach iOS, ist iOS schon in Prüfung; nur durch die vollständige Vorprüfung
  klein zu halten.

### Alternativen
- Erweiterung von `asc_store_version.py` um `einreichen` (weniger Dateien, kippt aber dessen „nie einreichen“-Zusage
  und den Wächtertest).
- Einreichen per Hand in App Store Connect, Werkzeug nur `pruefen` + Gegenprobe: verworfen, weil das Arbeit an den PO
  weiterreicht (Regel: Werkzeug reparieren statt weiterreichen) und #893 das Werkzeug verlangt.
- Ein Schnitt statt zwei: ~420 LoC, über dem Limit; außerdem fehlte der echte Lesebeleg vor dem ersten Schreiben.

### Technical Approach
Eigenes Skript + Workflow in zwei Schnitten, A `pruefen` → echter Lauf → B `einreichen` → Lauf nach Hennings
vorliegendem Wort (Freigabe 2026-11-09 per Auswahl im Ticket) → Store-Probe als Beleg.

### Open Questions
- keine an den PO (Freigabe zum Einreichen liegt vor; alles Weitere ist technisch)

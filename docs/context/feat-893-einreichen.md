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

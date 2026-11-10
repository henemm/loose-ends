# Context: feat-893-d-datenschutz

## Request Summary
Der echte Lauf `asc-store-submit.yml aktion=einreichen` (Lauf 42840824572, 2026-11-10) endet mit
`HTTP 409 POST /v1/reviewSubmissionItems (STATE_ERROR.ENTITY_STATE_INVALID); gründe: /v1/appInfoLocalizations/<id>=ENTITY_ERROR.ATTRIBUTE.REQUIRED`.
Apple verlangt bei einer App-Info-Lokalisierung ein Pflichtfeld, das fehlt. Schnitt D belegt, welches, setzt es und reicht erneut ein.

## Befund
- Die Meldung nennt nur den Pfad der Lokalisierung, nicht das Feld. Die Lokalisierungen der bearbeitbaren App-Info (Probe 2026-11-10, Lauf 42841208652):
  en-US (Name „Loose Ends: Voice Tasks“, Untertitel) und de-DE; beide tragen Name und Untertitel.
- Pflichtfeld bei Apple für iOS: `privacyPolicyUrl` je Sprache (Fallberichte unten). Hypothese, nicht belegt: Die en-US-Lokalisierung wurde
  von `asc_app_info.py` (`write_subtitles`, POST) nur mit `locale`, `name`, `subtitle` angelegt, ohne `privacyPolicyUrl`.
- Nichts in `asc_app_info.py lesen` oder im Store-Probe zeigt `privacyPolicyUrl`: das Feld ist bisher unsichtbar.

## Recherche (Quellen)
- Forum „The Items Below are Required?“ https://developer.apple.com/forums/thread/826478 : Privacy Policy URL je Lokalisierung als Pflicht, blockiert den Review-Start.
- https://rxliuli.com/blog/app-store-connect-new-required-fields : neu verlangte Felder, 409 am Submission-Item (Einzelbericht).
- https://developer.apple.com/forums/thread/749254 (409 „Unable to add for review“).
- Kein Treffer zur wörtlichen Kombination `ENTITY_ERROR.ATTRIBUTE.REQUIRED` + `appInfoLocalizations`; deshalb erst lesen, dann schreiben.

## Related Files
| File | Relevance |
|------|-----------|
| scripts/asc_app_info.py | `lesen` zeigt `privacyPolicyUrl` nicht; `write_subtitles` legt en-US ohne ihn an; Platz für neue Aktion `datenschutz` (PATCH, Gegenprobe wie `verify`) |
| scripts/test_asc_app_info.py | nachgestellte API (343 Zeilen), Muster für die neuen Tests |
| .github/workflows/asc-app-info.yml | Aktionsliste (`lesen`, `untertitel`) und Umgebung; braucht `datenschutz` und die URL-Variable |
| scripts/asc_beta_setup.py | `PRIVACY_URL_EN` (Konstante), `ASC_PRIVACY_POLICY_URL` (de, Repo-Variable) sind die Quellen der Adressen |
| scripts/asc_store_submit.py | gibt seit Schnitt C die Gründe aus; bleibt unverändert |

## Existing Patterns
- Schreibaufruf nur bei Abweichung, nur in die App-Info `PREPARE_FOR_SUBMISSION`, Gegenprobe im selben Lauf (`write_subtitles`/`verify`).
- Öffentliche Werte dürfen im Log stehen; die Datenschutz-Adresse ist öffentlich.
- Adressen: de `ASC_PRIVACY_POLICY_URL` (Variable), en `…/privacy-policy-en/` (#763).

## Dependencies
- Upstream: ASC-API `GET/PATCH /v1/appInfoLocalizations`, Repo-Variable `ASC_PRIVACY_POLICY_URL`.
- Downstream: `asc-store-submit.yml einreichen` (nach erfolgreichem Setzen erneut), #842 (Schließen nach WAITING_FOR_REVIEW).

## Existing Specs
- docs/specs/feat-893-schnitt-c-gruende.md (Regeln AC-10: Ausgabe ohne Kennungen)

## Risks & Considerations
- Es ist eine Hypothese; Schritt 1 ist rein lesend (`lesen` mit Datenschutz-Angabe), erst dann schreiben. Ist `privacyPolicyUrl` gesetzt, sind andere Felder (`privacyChoicesUrl`, Name) zu prüfen.
- Schreibt öffentliche Store-Daten: nur die bereits veröffentlichte Datenschutzseite, nur in die bearbeitbare App-Info, nie löschen.
- Datenschutztext ist freigegeben; die Website-Seite ist live (seit 2026-10-27).
- Alternative zum Werkzeug: Eintrag in App Store Connect im Browser; verworfen (Werkzeuge reparieren, nicht weiterreichen).

## Analysis

### Type
Feature (Werkzeug-Reparatur, Schnitt D von #893). Kein Produktcode der App, kein Pfad der Geräteliste.

### Belegstand der Ursache
Nur Hypothese: `privacyPolicyUrl` fehlt je Lokalisierung der App-Info (Apple: Pflicht je Sprache). Nicht belegt, weil `asc_app_info.py lesen` das Feld nicht ausgibt. Deshalb Schritt 1 rein lesend, erst danach schreiben. Hinweis: `asc_beta_setup.py` setzt die Adresse nur an der TestFlight-Beschreibung (`betaAppLocalizations`), nicht an `appInfoLocalizations`; das erklärt die Lücke.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_app_info.py | MODIFY | `lesen` zeigt `privacyPolicyUrl` je Sprache; neue Aktion `datenschutz` (PATCH nur bei Abweichung, nur editierbare App-Info, Gegenprobe über `verify`); en = `PRIVACY_URL_EN`, de = Variable `ASC_PRIVACY_POLICY_URL` |
| scripts/test_asc_app_info.py | MODIFY | Tests mit nachgestellter API: Lesen zeigt Feld, PATCH nur bei Abweichung, gesperrte Info, leere de-Adresse bricht ab, Gegenprobe |
| .github/workflows/asc-app-info.yml | MODIFY | Aktion `datenschutz` in der Auswahl, `ASC_PRIVACY_POLICY_URL` in die Umgebung |

### Scope Assessment
- Files: 3 (+ Beleg unter docs/artifacts/feat-893-d-datenschutz/)
- Estimated LoC: +110/-5
- Risk Level: LOW. Schreibt nur eine bereits öffentliche Adresse in die bearbeitbare App-Info, nie löschen, nie einreichen.

### Technical Approach (Regelweg, kein Modell)
1. `lesen` erweitern, echter Lauf (nur GET): zeigt, welche Sprache `privacyPolicyUrl` nicht trägt. Das bestätigt oder widerlegt die Hypothese.
2. Aktion `datenschutz` setzt fehlende oder abweichende Adressen per PATCH, Gegenprobe im selben Lauf.
3. Danach `asc-store-submit.yml einreichen -f bestaetigung=1.0.1` erneut (verwendet die leere READY_FOR_REVIEW-Einreichung wieder, Schnitt B AC-5). Nennt Apple weiter Gründe, gibt Schnitt C sie aus; dann neuer Befund statt Raten.
4. Zusätzliche Gründe (`privacyChoicesUrl`, Name) erst nach Lesebefund.

### Alternativen
- A: Eintrag im Browser in App Store Connect: verworfen (Werkzeug reparieren, nichts an Henning weiterreichen; keine ADR betroffen).
- B: `lesen` nur erweitern und das Setzen in `untertitel` einbauen: verworfen, vermischt zwei Ziele und schreibt bei jedem Untertitel-Lauf mehr.
- C: Adresse in der Spec fest verdrahten statt Variable: verworfen, Doppelpflege (Quelle ist `ASC_PRIVACY_POLICY_URL`).

### Dependencies
Upstream: ASC-API `appInfoLocalizations`, Repo-Variable `ASC_PRIVACY_POLICY_URL` (gesetzt, 2026-10-27). Downstream: Wiederholung `einreichen`, Schließen von #893/#842 erst nach `WAITING_FOR_REVIEW`.

### Open Questions
- [ ] Keine Produktfrage. Technisch offen bis zum Lesebefund: Ist `privacyPolicyUrl` wirklich das fehlende Feld?

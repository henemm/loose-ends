# Context: feat-893-b-einreichen (#893 Schnitt B)

## Request Summary
Version 1.0.1 für iOS (iPhone/iPad) und macOS per Werkzeug bei Apple zur Prüfung einreichen. Henning hat das am
2026-11-09 per Auswahl ausdrücklich freigegeben (#893). Schnitt A (`pruefen`, nur GET) ist gemergt und lief echt grün
(Run 42717307403): beide Plattformen bereit. Schnitt B ergänzt den einzigen nicht rücknehmbaren Schreibweg `einreichen`.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_store_submit.py` (240 Z.) | wird erweitert: `ACTIONS` ist der vorgesehene Erweiterungspunkt; `pruefen`, `check_submissions`, `submissions`, `editable_for`, Konstanten `BUSY`, `REUSABLE`, `DONE`, `SHORT` |
| `scripts/test_asc_store_submit.py` (330 Z.) | `SubmitFakeASC` (Unterklasse von `FakeASC` aus `test_asc_store_version.py`) kann `GET /v1/reviewSubmissions`; braucht POST `reviewSubmissions`, POST `reviewSubmissionItems`, PATCH `reviewSubmissions/{id}` und Zustandswechsel der Version. `WorkflowTests` erzwingt heute „nur `pruefen`“ und muss mitwachsen; `test_bad_usage_makes_no_call` nennt `einreichen` heute als unbekannt |
| `.github/workflows/asc-store-submit.yml` (50 Z.) | `workflow_dispatch` mit `aktion` (nur `pruefen`), `concurrency` ohne Abbruch, Schlüssel per `umask 077` + `trap`; braucht `einreichen` als Option und eine Eingabe-Sperre (Bestätigungswort) |
| `scripts/asc_store_version.py` | `send()` (403/409 → klare Meldung, Codes ohne Rohantwort), `get_one`, `current_build`, `count`; Wächtertest „nie einreichen“ dort bleibt unverändert |
| `scripts/asc_what_to_test.py` | `send_json` (wiederholt bei 5xx/408/429 und Netzfehlern!) und `get_data`; `error_codes` |
| `scripts/asc_beta_invite.py` | `post_submission`: Muster „genau ein POST, nie wiederholt“ für nicht rücknehmbare Einreichung (eigener urlopen, 409 → None) ; `Masked`, `message` |
| `scripts/asc_version_texts.py` | `app_versions`, `localizations`, `PLATFORMS`, `EDITABLE` |
| `scripts/asc_wait_build.py` | `Fatal`, `read_config`, `find_app_id`, `make_token`, `get_json` |
| `CLAUDE.md` (Build-Abschnitt) | Zeile `gh workflow run asc-store-submit.yml -f aktion=pruefen … Schnitt B ergänzt einreichen (#893)` ist anzupassen |
| `docs/artifacts/feat-893-einreichen/echter-lauf-pruefen.md` | Beleg Schnitt A: Listenform belegt, Zustand `COMPLETE` belegt; `READY_FOR_REVIEW`/`WAITING_FOR_REVIEW` noch nie echt gesehen |

## Existing Patterns
- Plan nur mit GET, dann schreiben, dann Gegenprobe im selben Lauf (`asc_store_version.anlegen` → `verify`).
- Nicht rücknehmbare POSTs werden **nie** wiederholt (`asc_beta_invite.post_submission`), im Gegensatz zu
  `send_json`, das bei 5xx/Netzfehler bis zu `ATTEMPTS` mal wiederholt. Für `reviewSubmissions` POST und vor allem den
  PATCH `submitted=true` ist das zu klären: ein wiederholter POST kann eine zweite Einreichung anlegen.
- Ausgabe nur Zustandswörter und Zahlen, nie IDs, Token, Apples Rohantwort oder Store-Wortlaut (`Masked`, Tests mit `IDS`-Regex).
- Idempotenz: Vorhandenes wird erkannt und übersprungen (`asc_store_images`, `asc_store_version`), zweiter Lauf schreibt nichts.
- Schreibende Workflows: Aktion per `choice`; heikle Schritte nur nach Hennings Wort (vgl. `asc-beta.yml aktion=einreichen`).

## Apple-Schnittstelle (Recherche 2026-11-10)
- Ablauf in drei Schritten: `POST /v1/reviewSubmissions` (`attributes.platform`, `relationships.app`) →
  `POST /v1/reviewSubmissionItems` (`relationships.reviewSubmission` + `relationships.appStoreVersion`, Typ
  `appStoreVersions`) → `PATCH /v1/reviewSubmissions/{id}` mit `attributes.submitted=true`. PATCH vor dem Item → 422.
  `appStoreVersionSubmissions` ist abgelöst.
- **Je Plattform eine eigene Einreichung:** „Items associated with different platforms can't be added to the same
  submission.“ Je Plattform höchstens eine Einreichung mit App-Version in Prüfung. iOS deckt iPhone und iPad ab.
- Zustände `ReviewSubmissionState`: READY_FOR_REVIEW, WAITING_FOR_REVIEW, IN_REVIEW, UNRESOLVED_ISSUES, CANCELING,
  COMPLETING, COMPLETE. Nach dem Einreichen: Einreichung WAITING_FOR_REVIEW, Version `appStoreState` WAITING_FOR_REVIEW.
- Bekannte Fehler: 409 bei nicht einreichbarem Zustand bzw. vorhandener offener Einreichung,
  CONCURRENT_REVIEW_SUBMISSION_LIMIT_EXCEEDED, 422 bei leerer Einreichung.
- Quellen: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review ,
  https://developer.apple.com/forums/thread/802281 ,
  https://dev.to/snake_sun/the-asc-apis-3-step-review-submission-flow-and-why-appstoreversionsubmissions-is-gone-24ld ,
  https://developer.apple.com/forums/thread/844351

## Dependencies
- Upstream: `asc_wait_build` (Konfig, Token, App-ID), `asc_what_to_test` (`send_json`, `get_data`), `asc_beta_probe`
  (`attributes`, `records`), `asc_store_version` (`get_one`, `current_build`, `count`, `send`), `asc_version_texts`.
- Downstream: nur der Handlauf `asc-store-submit.yml` und die CLAUDE.md-Zeile. Kein Produktcode, kein Pfad der Geräteliste.

## Existing Specs
- `docs/specs/feat-893-schnitt-a-pruefen.md` — Vorprüfung, legt die Regeln für Wiederverwendung (genau eine
  READY_FOR_REVIEW) und „belegt“ fest; Schnitt B baut darauf auf.
- `docs/specs/feat-842-schnitt-5a-1-mac-version-anlegen.md` — Muster Plan/Schreiben/Gegenprobe.

## Risks & Considerations
- **Nicht atomar über Plattformen:** iOS kann eingereicht sein, wenn Mac scheitert. Gegenmaßnahme: volle Vorprüfung
  beider Plattformen vor dem ersten Schreiben; Reihenfolge und Wiederaufnahme so, dass ein zweiter Lauf die fertige
  Plattform erkennt (WAITING_FOR_REVIEW) und nur die fehlende nachholt.
- **Doppelte Einreichung durch Wiederholung:** POST nie automatisch wiederholen; eine bei Abbruch liegengebliebene
  READY_FOR_REVIEW-Einreichung (ohne oder mit Item) im nächsten Lauf wiederverwenden statt neu anlegen.
- **READY_FOR_REVIEW mit fremdem Inhalt** (z. B. In-App-Event) oder schon mit Item: Items lesen
  (`GET /v1/reviewSubmissions/{id}/items`), bevor ein Item hinzugefügt wird; fremdes Item → Abbruch, nie löschen.
- **Ungesehene Formen:** Apples Antworten auf POST/PATCH und die Zustände READY_FOR_REVIEW/WAITING_FOR_REVIEW sind echt
  noch nie gesehen; Nachbau beweist sie nicht. Der echte Lauf ist zugleich der Beleg und ist nicht wiederholbar.
- **Sperre im Workflow:** `einreichen` nur mit zusätzlichem Bestätigungswort (Eingabe), damit ein versehentlicher
  Handlauf nichts einreicht; Hennings Freigabe vom 2026-11-09 liegt vor.
- **Rückweg:** Eine Einreichung lässt sich in App Store Connect zurückziehen („Remove from review“); das Werkzeug löscht
  oder storniert nie.
- **Testumfang vs. 250 LoC:** Sicherheitsregeln einzeln testen treibt Testzeilen (Muster aus Schnitt A: ~560 LoC mit
  Tests angenommen). Meldeschwelle in der Spec festlegen.

## Analysis

### Type
Feature (Betriebswerkzeug, kein Produktcode, kein Pfad der Geräteliste)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_store_submit.py` | MODIFY | Aktion `einreichen`: Plan (nur GET) → je Plattform schreiben → Gegenprobe; eigener Einmal-POST/PATCH mit Rückgabe des Rumpfs |
| `scripts/test_asc_store_submit.py` | MODIFY | `SubmitFakeASC` um POST `reviewSubmissions`, POST `reviewSubmissionItems`, GET `…/items`, PATCH `submitted` mit Zustandswechsel; Tests je Regel; `WorkflowTests` und `test_bad_usage_makes_no_call` mitziehen |
| `.github/workflows/asc-store-submit.yml` | MODIFY | Option `einreichen`, Eingabe `bestaetigung` (Versionsnummer), Kommentarkopf |
| `CLAUDE.md` | MODIFY | Build-Zeile `asc-store-submit.yml`: `einreichen` beschreiben |

### Befunde aus dem Code
- `send_json` (über `asc_store_version.send`) **wiederholt** POST/PATCH bei 5xx/408/429/Netzfehler und **gibt keinen Rumpf zurück**.
  Für `reviewSubmissions` brauchen wir die neue ID, und eine Wiederholung kann eine zweite Einreichung anlegen →
  eigener Einmal-Aufruf nach dem Muster `asc_beta_invite.post_submission` (genau ein Versuch, Rumpf zurück, 409 klar gemeldet).
- `pruefen` wertet eine schon eingereichte Plattform als „nicht bereit“ (keine bearbeitbare Version, Einreichung belegt).
  Für die Wiederaufnahme braucht `einreichen` einen eigenen Plan je Plattform mit drei Ausgängen:
  `eingereicht` (Version mit Zielnummer im Zustand WAITING_FOR_REVIEW/IN_REVIEW und passende Einreichung) → überspringen,
  `bereit` (alle Prüfungen von `pruefen` ohne Grund) → schreiben, sonst `nicht-bereit` → Abbruch **beider** ohne Schreiben.
- Versionsgleichheit (`same_number`) muss die schon eingereichte Plattform mitzählen (deren Version ist nicht mehr bearbeitbar).

### Technical Approach (Empfehlung)
1. **Sperre:** Workflow-Eingabe `bestaetigung` muss gleich der Nummer der bearbeitbaren Version sein (`1.0.1`); sonst
   Abbruch vor jedem Schreiben. Bindet die Freigabe an den Inhalt, nicht an ein beliebiges Wort.
2. **Plan nur GET**, beide Plattformen vollständig, Wiederverwendung der Prüfungen aus Schnitt A. Ein einziger Grund
   bei einer nicht eingereichten Plattform → Ausgang 1, kein Schreibaufruf.
3. **Schreiben je Plattform, iOS zuerst, dann Mac:** genau eine READY_FOR_REVIEW-Einreichung wiederverwenden, sonst
   `POST /v1/reviewSubmissions`; deren Items lesen: leer → `POST /v1/reviewSubmissionItems` (Version), genau unsere
   Version → überspringen, Fremdes → Abbruch ohne Löschen; dann `PATCH /v1/reviewSubmissions/{id}` `submitted=true`.
   Jeder Schreibaufruf genau einmal, nie wiederholt.
4. **Gegenprobe im selben Lauf:** Einreichung WAITING_FOR_REVIEW (oder weiter: IN_REVIEW) und Version WAITING_FOR_REVIEW
   je Plattform, mit kurzem Nachlesen (Apple setzt den Zustand ggf. verzögert).
5. **Ausgabe** nur Zustandswörter und Zahlen; die Freigabeart der Version (`releaseType`) wird gelesen und genannt, nie geändert.
6. Nie löschen, nie stornieren, nie Texte/Bilder/Bau ändern.

### Alternativen
- **Einreichen per Hand in App Store Connect** (Henning oder Claude im Browser): kein Code, aber nicht wiederholbar,
  nicht getestet, widerspricht „Werkzeug reparieren statt weiterreichen“. Verworfen.
- **fastlane `deliver submit_for_review`:** neue Abhängigkeit (Ruby), eigener Schlüsselumgang; kippt die Linie „eigene
  ASC-Skripte ohne Fremdwerkzeug“ (#742/#842). Verworfen.
- **Altes `appStoreVersionSubmissions`:** von Apple abgelöst. Verworfen.
- **Zwei Schnitte (B1 anlegen+Item, B2 submitted):** kleiner je Schnitt, aber B1 allein hinterlässt nur einen Entwurf
  ohne Nutzen und verdoppelt den Ablauf. Nicht empfohlen.
- Keine ADR wird gekippt.

### Scope Assessment
- Files: 4
- Estimated LoC: Skript ≈ +140, Workflow ≈ +20, CLAUDE.md 1, Tests ≈ +380 (≈ 13 ACs × 30 Zeilen Attrappe/Fall,
  Erfahrung #842 S4c-1/S5a-1) → **≈ 540 gesamt**, über der 250er-Grenze; Überhang fast ganz Sicherheitstests.
- Risk Level: MEDIUM-HIGH — der Lauf ist nach außen gerichtet und nicht rücknehmbar (nur in App Store Connect
  zurückziehbar); Apples Antworten auf POST/PATCH sind echt noch nie gesehen.

### Open Questions
- [x] Umfang ≈ 540 Zeilen in einem Schnitt: Henning 2026-11-10 „Ja, in einem Stück“ (Meldeschwelle für die Spec: 650)

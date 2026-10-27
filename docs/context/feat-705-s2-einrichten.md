# Context: feat-705-s2-einrichten (#705 Schnitt 2: Einrichten und Einreichen)

## Request Summary

Apples Seite der ersten externen Einladung einrichten: Beta-Beschreibung, Feedback-E-Mail, Kontaktangaben für den
Beta-Review, externe Gruppe mit öffentlichem Link, iOS- und macOS-Builds zuordnen, Beta-Review einreichen. Henning hat
am 2026-10-27 gewählt: „Ich entwerfe, du korrigierst“ — Claude entwirft die Texte auf Deutsch, Henning gibt sie frei und
liefert Feedback-E-Mail und Kontaktdaten. DoD des Tickets: eine Person außer Henning installiert die App über den Link.

## Ausgangslage (Beleg: Lauf 40387004899, Kommentar in #705)

- Schlüssel liest alle Beta-Pfade (200). Schreibrechte sind **nicht** erprobt.
- Gruppen: nur `Familie` (intern, Link aus, Feedback an). Keine externe Gruppe.
- `betaAppLocalizations` leer: keine Beschreibung, keine Feedback-E-Mail, keine Datenschutz-URL.
- `betaAppReviewDetail` vorhanden, alle Felder leer (`contactFirstName`, `contactLastName`, `contactPhone`,
  `contactEmail`, `demoAccountName`, `demoAccountPassword`, `demoAccountRequired`, `notes`).
- Builds 117–121 je Plattform `VALID`, intern `IN_BETA_TESTING`, extern `READY_FOR_BETA_SUBMISSION`, keine Einreichung.
- Exportnachweis erledigt (`ITSAppUsesNonExemptEncryption=false`, `project.yml`).

## Related Files

| File | Relevance |
|------|-----------|
| `scripts/asc_beta_probe.py` | Schnitt 1, nur lesend; Muster für Abfragen und Belegzeilen; läuft nach Schnitt 2 als Nachweis erneut |
| `scripts/asc_what_to_test.py` | Vorhandenes Schreibmuster: `send_json` (PATCH/POST, Wiederholung bei 5xx/408/429, 4xx = Fatal), Sprachfassung `de-DE` anlegen, wenn sie fehlt |
| `scripts/asc_wait_build.py` | `read_config`, `make_token` (JWT per `openssl`), `get_json`, `find_app_id`, `platform_filter` — gemeinsame Basis |
| `.github/workflows/asc-beta.yml` | Handlauf (`workflow_dispatch`), Matrix `IOS`/`MAC_OS`, Schlüssel aus Secrets in `$RUNNER_TEMP`; Ort für den Schreib-Lauf |
| `scripts/test_asc_beta_probe.py`, `scripts/test_asc_what_to_test.py` | Testmuster: Nachbau der ASC-API lokal, Python-Unit-Tests |
| `docs/reference/testflight.md` (Abschnitt „Einladung: Apple-Seite (#705)“) | Prüfliste mit zehn Teilen, Status `offen`; wird mit Belegen abgehakt |
| `docs/reference/datenschutz-entwurf.md` | Datenschutztext, Entwurf, nicht veröffentlicht; die öffentliche Adresse ist ausdrücklich #705 zugeordnet |
| `docs/specs/feat-705-schnitt-1-sondieren.md` | Spec von Schnitt 1, Out-of-Scope-Liste = Inhalt von Schnitt 2 |

## Apple-Schnittstelle (Recherche 2026-10-27, Apple-Doku-JSON)

- `POST /v1/betaGroups`: `name` (Pflicht), `publicLinkEnabled`, `publicLinkLimit`, `publicLinkLimitEnabled`,
  `feedbackEnabled`, `hasAccessToAllBuilds`, `isInternalGroup`; Beziehung `app`.
- `PATCH /v1/betaGroups/{id}`: zusätzlich `iosBuildsAvailableForAppleSiliconMac`, `iosBuildsAvailableForAppleVision`.
- `POST /v1/betaGroups/{id}/relationships/builds`: Builds zuordnen (204 bei Erfolg).
- `POST /v1/betaAppLocalizations`: `locale` (Pflicht), `description`, `feedbackEmail`, `marketingUrl`,
  `privacyPolicyUrl`, `tvOsPrivacyPolicy`; `PATCH /v1/betaAppLocalizations/{id}` zum Ändern.
- `PATCH /v1/betaAppReviewDetails/{id}`: die acht Felder oben. **Vorname, Nachname, Telefon, E-Mail sind nach dem
  ersten Setzen nicht mehr leerbar** (Apple-Doku).
- `POST /v1/betaAppReviewSubmissions`: nur Beziehung `build` (Pflicht). **Kein DELETE-/Abbruch-Endpunkt** in der
  Doku: Einreichen ist per API nicht rücknehmbar.

Regeln aus Apples Hilfe:
- Externe Gruppe setzt eine interne voraus (`Familie` existiert).
- Beta-App-Beschreibung ist Pflicht; Feedback-E-Mail ist Antwortadresse für Einladungen und TestFlight-Feedback.
- Öffentlicher Link: „Open to Anyone“ oder „Filter by Criteria“, Limit 1–10 000; wer per Link beitritt, erscheint anonym;
  der Link ist weitergebbar.
- Höchstens sechs Builds je 24 h in den Beta-Review, je Version nur ein Build gleichzeitig im Review.
- Telefonnummer im internationalen Format mit `+`.
- Datenschutz-URL: Apples eigene Seiten nennen sie für TestFlight nicht als Pflicht, Drittquellen (aso.dev, Appcircle)
  schon. **Ungeklärt** — klärt erst die Einreichung (422) oder die Oberfläche.

Bekannte Stolpersteine (Apple-Foren): 422 `BETA_CONTRACT_MISSING` bei der Einreichung trotz aktiver Verträge
(Kontoseite, nicht Payload); 422 bei fehlender Beschreibung.

## Existing Patterns

- Handlauf über `workflow_dispatch`, nie automatisch; Schlüssel nur in `$RUNNER_TEMP`, `trap` räumt auf.
- Ausgabe nur `gesetzt/leer`, nie Kontaktwerte, Schlüssel oder Token.
- Idempotenz bei `asc_what_to_test.py`: vorhandene Sprachfassung patchen, fehlende anlegen.
- Tests gegen einen lokalen Nachbau der API (`ASC_API_BASE`), keine echten Aufrufe in der CI.

## Dependencies

- Upstream: App-Store-Connect-API, Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`; Rolle des Schlüssels (Admin
  laut Memory) — Schreibrecht für Beta-Ressourcen ungeprüft.
- Eingaben von Henning: Freigabe der Beschreibung, Feedback-E-Mail, Kontakt (Vorname, Nachname, Telefon mit `+`, E-Mail).
  Kontaktdaten gehören nicht ins Repo: als Workflow-Eingaben oder Secrets.
- Datenschutz-URL hängt an Hennings Freigabe des Entwurfs und an einem öffentlichen Ort (z. B. GitHub Pages).

## Dependents

- #342 (Schwester, Texte für Fremde) liefert den Datenschutz-Entwurf; Board-Status „In progress“ — nicht anfassen.
- #371 (Epic Einladung), #176 (Prüfliste vor der Einladung) warten auf die Gruppe und den Link.

## Risks & Considerations

- **Unumkehrbar:** Einreichung (kein Abbruch per API) und Kontaktfelder (nicht leerbar). Schalter `submit` aus als
  Standard; Einreichung nur auf ausdrücklichen Lauf.
- **Öffentlicher Link ist weitergebbar** — Limit setzen (z. B. kleine Zahl) statt offen ohne Grenze; Produktfrage an
  Henning.
- **Kontaktdaten sind persönlich:** nie im Log, nie im Repo; nur Workflow-Eingabe/Secret.
- **Schreibrecht des Schlüssels unbekannt:** erster Schreibaufruf kann 403 liefern — dann als Befund melden.
- **macOS:** Builds beider Plattformen liegen unter derselben App; Einreichung je Build, also je Plattform.
- **Datenschutz-URL ungeklärt** — Analyse muss entscheiden: vorher veröffentlichen oder erst auf 422 reagieren.
- Scoping: Skript + Test + Workflow + Doku ≈ 4–5 Dateien; ±250 LoC eng — ggf. Schnitt 2a (Einrichten) und 2b (Einreichen).

## Alternativen (zur Analyse)

- **A — Skript aus der CI** (Muster von Schnitt 1 und #347): wiederholbar, belegt, Henning muss nichts klicken.
- **B — Einmal in der App-Store-Connect-Oberfläche** (Henning oder Claude per Chrome mit Hennings Anmeldung): kein Code,
  aber kein wiederholbarer Beleg; die Einrichtung geschieht nur einmal, das spricht für B bei Gruppe/Link.
- **C — Gemischt:** Texte und Kontakt per Skript (ändern sich), Gruppe/Link einmal in der Oberfläche.

## Analysis

### Type
Feature (Einrichtung bei Apple, kein App-Code)

### Recherche (2026-10-27)
- Beta-App-Beschreibung ist Pflicht ([Apple: Provide test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information)).
  Feedback-E-Mail ist Antwortadresse der Einladung; Pflichtstatus dort nicht genannt.
- Datenschutz-URL: Apples Hilfe nennt sie für TestFlight nicht; Drittquellen ([aso.dev](https://aso.dev/developer/beta-information),
  [Appcircle](https://docs.appcircle.io/publish-to-stores-module/publish-information/testflight-beta-information)) führen sie als Feld;
  [Apple-Forum 706282](https://developer.apple.com/forums/thread/706282): „not required“. Bleibt ungeklärt → optionaler Wert.
- Öffentlicher Link: Apple ordnet die Einladung nach der Prüfung ein („Once you have builds available to test, and you've
  added them to a group, you can invite testers“, [Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers));
  ob die API den Link vor der Freigabe annimmt, belegt keine Quelle → Link erst nach Freigabe einschalten.
- fastlane `create_beta_group` nutzt dieselben Felder (`public_link_enabled`, `public_link_limit`, `public_link_limit_enabled`).

### Neuer Befund: Repo ist öffentlich
`henemm/loose-ends` ist PUBLIC. Eingaben eines `workflow_dispatch`-Laufs sind in der Laufansicht für alle sichtbar.
**Kontaktdaten (Name, Telefon, E-Mail) daher nur als Repo-Secrets** (`ASC_REVIEW_FIRST_NAME`, `…_LAST_NAME`, `…_PHONE`,
`…_EMAIL`, `ASC_FEEDBACK_EMAIL`), gesetzt von Claude per `gh secret set` aus Hennings Angaben, nie als Eingabe, nie im Log.
Die Beta-Beschreibung sehen Tester ohnehin: sie darf als Datei im Repo liegen (`docs/reference/beta-beschreibung.md`).

### Wiederkehrend vs. einmalig
- Einmalig: Sprachfassung (Beschreibung, Feedback-E-Mail), Kontaktangaben, externe Gruppe.
- Wiederkehrend: jeder neue Build muss der externen Gruppe zugeordnet und eingereicht werden. Das spricht gegen „nur einmal
  in der Oberfläche“ (Alternative B) und für ein Skript, das sich später an `testflight.yml` hängen lässt.

### Ansatz (Empfehlung): A, in zwei Teilschnitten
- **2a — Texte und Kontakt** (umkehrbar bis auf die Kontaktfelder): `scripts/asc_beta_setup.py` legt `betaAppLocalizations`
  `de-DE` an oder patcht sie (Beschreibung aus Datei, Feedback-E-Mail, Datenschutz-URL nur wenn gesetzt) und patcht
  `betaAppReviewDetails` (vier Kontaktfelder, `demoAccountRequired=false`). Idempotent: zweiter Lauf ändert nichts Sichtbares.
  Ausgabe nur `gesetzt/leer`. Neuer Job in `asc-beta.yml` mit Eingabe `aktion` (`probe` Standard, `einrichten`); danach der
  Probe-Lauf als Beleg.
- **2b — Gruppe, Builds, Einreichung, Link**: externe Gruppe anlegen (Name z. B. „Tester“, `feedbackEnabled`, Link aus),
  neuesten `VALID`-Build je Plattform zuordnen, `submit` nur auf ausdrückliche Eingabe; nach Freigabe Link einschalten mit
  Limit. Danach DoD: eine Person installiert über den Link.

### Affected Files (2a)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_beta_setup.py` | CREATE | Sprachfassung + Review-Kontakt setzen, idempotent, ohne Werte im Log |
| `scripts/test_asc_beta_setup.py` | CREATE | Tests gegen lokalen API-Nachbau (Muster `test_asc_beta_probe.py`) |
| `.github/workflows/asc-beta.yml` | MODIFY | Eingabe `aktion`, Secrets für Kontakt/Feedback, Schreibjob |
| `docs/reference/beta-beschreibung.md` | CREATE | freigegebener Wortlaut der Beta-Beschreibung |
| `docs/reference/testflight.md` | MODIFY | Prüfliste: Beschreibung, Feedback-E-Mail, Kontakt mit Beleg |

### Scope Assessment
- 2a: 5 Dateien, ca. +230 LoC (Skript ~90, Test ~110, Workflow ~20, Doku ~15). 2b eigener Workflow-Lauf, ähnlich groß.
- Gesamt in einem Schnitt ~450 LoC → sprengt ±250, daher Teilung.
- Risk Level: MEDIUM — kein App-Code, aber Schreiben bei Apple; Kontaktfelder nach Setzen nicht mehr leerbar,
  Einreichung (2b) nicht rücknehmbar.

### Risiken
- Schlüssel hat evtl. kein Schreibrecht (403) → Befund melden, nicht umgehen.
- `send_json` aus `asc_what_to_test.py` wiederverwenden (gleiche Wiederholregeln); kein neuer HTTP-Code.
- Falscher Kontaktwert ist nur überschreibbar, nicht löschbar → Werte vor dem Lauf mit Henning bestätigen.

### Alternativen
- **B — einmalig per Chrome in App Store Connect** (Henning angemeldet), Beleg danach per Probe-Lauf: kein Code für den
  einmaligen Teil. Verworfen für 2a nicht aus Prinzip, sondern weil 2b ohnehin ein Skript braucht und Texte sich ändern.
  Bleibt Rückfall, falls der Schlüssel 403 liefert.
- **C — gemischt**: Gruppe/Link in der Oberfläche, Rest per Skript. Möglich für den Link in 2b, falls die API ihn ablehnt.
- Kein ADR berührt.

### Dependencies
`asc_wait_build.py` (`read_config`, `find_app_id`, `get_json`), `asc_what_to_test.py` (`send_json`), Secrets `ASC_*`.

### Open Questions (PO)
- [x] Wortlaut der Beta-Beschreibung (übernommen)
- [x] Feedback-E-Mail und Kontakt → Secrets gesetzt
- [x] Limit des öffentlichen Links: 50
- [ ] Datenschutz-URL: gehört zu #342 (Freigabe Entwurf); 2a setzt sie nur, wenn vorhanden

### PO-Entscheidungen (Henning, 2026-10-27)
- Beta-Beschreibung: Entwurf **unverändert übernommen**:
  > Loose Ends nimmt auf, was dir durch den Kopf geht: tippen oder sprechen, ein Satz genügt. Die App macht daraus eine Aufgabe mit Titel, Fälligkeit und Tags. Das passiert auf dem Gerät, ohne Konto und ohne eigenen Server. Deine Aufgaben liegen in deinem privaten iCloud und sind auf iPhone, iPad, Mac und Apple Watch gleich.
  >
  > Was du ausprobieren kannst: Aufgaben erfassen (auch per Sprache), die Liste „Jetzt“, wiederkehrende Aufgaben, Erinnerungen zur Fälligkeit und an Orten, Teilen aus anderen Apps.
  >
  > Rückmeldungen gehen direkt aus TestFlight: Bildschirmfoto machen oder „Feedback senden“ antippen.
- Feedback-E-Mail = Kontakt-E-Mail (ein Secret genügt, `ASC_REVIEW_EMAIL`).
- Link-Limit: **50 Personen** (`publicLinkLimit=50`, `publicLinkLimitEnabled=true`), gilt für 2b.
- Vorname, Nachname, Telefon, E-Mail: geliefert am 2026-10-27, von Claude als Repo-Secrets `ASC_REVIEW_FIRST_NAME`,
  `ASC_REVIEW_LAST_NAME`, `ASC_REVIEW_PHONE`, `ASC_REVIEW_EMAIL` gesetzt (Werte nicht im Repo). `ASC_REVIEW_EMAIL` dient auch als Feedback-E-Mail.

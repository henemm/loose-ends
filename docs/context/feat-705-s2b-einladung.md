# Context: feat-705-s2b-einladung (#705 Schnitt 2b: externe Gruppe, Builds, Beta-Review, öffentlicher Link)

## Request Summary

Den Rest der Apple-Seite der ersten externen Einladung einrichten: eine externe TestFlight-Gruppe mit TestFlight-Feedback,
den neuesten gültigen Build je Plattform (iOS, macOS) zuordnen, diese Builds zum Beta-Review einreichen und nach Apples
Freigabe den öffentlichen Link (Limit 50) einschalten. DoD des Tickets: eine Person außer Henning installiert über den Link.

## Ausgangslage

- **2a erledigt** (PR #716, gemergt als `3763e57`): Sprachfassung `de-DE` mit Beschreibung und Feedback-E-Mail, vier
  Kontaktfelder des Review-Details, `demoAccountRequired=false`. Belege: Läufe 40466472742 (`geschrieben=2`) und
  40466601395 (`geschrieben=0`). Der API-Schlüssel **darf Beta-Ressourcen schreiben** (kein 403).
- Schnitt 1 (Lauf 40387004899): nur Gruppe `Familie` (intern, Link aus, Feedback an); Builds je Plattform `VALID`,
  intern `IN_BETA_TESTING`, extern `READY_FOR_BETA_SUBMISSION`; keine Einreichung.
- Datenschutz-URL: **nicht gesetzt**, keine Repo-Variable `ASC_PRIVACY_POLICY_URL` vorhanden (`gh variable list` leer);
  gehört zu #342 (offen, Board „In progress“, nicht anfassen).

## Related Files

| File | Relevance |
|------|-----------|
| `scripts/asc_beta_setup.py` (2a) | Muster: Werte prüfen vor jeder Anfrage, Ist-Zustand lesen, reine `plan_*`-Funktionen, `apply_plan` über `send_json`, 403 → „Schlüssel ohne Schreibrecht“, Ausgabe nur Zustandswörter, `zusammenfassung geschrieben=<n>` |
| `scripts/asc_beta_probe.py` (S1) | Liest Gruppen (`gruppe name=… intern=… link=… url=… feedback=…`), Builds mit `buildBetaDetail` und Einreichungen; ist der Beleg nach jedem Schreiblauf; druckt die öffentliche Link-URL schon (`url=`) |
| `scripts/asc_wait_build.py` | `read_config`, `make_token`, `get_json`, `find_app_id`, `platform_filter`, `Fatal` |
| `scripts/asc_what_to_test.py` | `send_json(config, method, path, payload)` (Wiederholung bei 5xx/408/429, sonst 4xx = `Fatal` mit Methode und Pfad), `get_data`, `ATTEMPTS` |
| `.github/workflows/asc-beta.yml` | Handlauf `workflow_dispatch`, Eingabe `aktion` (`probe`, `einrichten`), Job `setup` → Job `probe` (Matrix `IOS`/`MAC_OS`) als Beleg; Ort für die neue Aktion |
| `scripts/test_asc_beta_setup.py`, `scripts/test_asc_beta_probe.py` | Testmuster: Wegwerf-Schlüssel per `openssl`, `FakeASC` (lokaler `HTTPServer`, merkt Methode und Rumpf), Skript als Unterprozess mit `ASC_API_BASE`, plus Prüfung der Workflow-Datei |
| `.github/workflows/testflight.yml` | Lädt iOS und macOS unter derselben Buildnummer (Laufnummer) hoch, wartet je Plattform (`asc_wait_build.py`) und setzt „Was testen“; ordnet **keiner** Gruppe zu. Bleibt in 2b unberührt |
| `docs/reference/testflight.md` (Abschnitt „Einladung: Apple-Seite (#705)“) | Prüfliste; offen: Datenschutz-URL, interne Gruppe `Familie` (existiert, Beleg fehlt), externe Gruppe mit Link, Build-Zuordnung iOS/macOS, Beta-Review, Rückmeldeweg TestFlight-Feedback |
| `docs/specs/feat-705-schnitt-2a-texte-kontakt.md` | Out-of-Scope-Liste = Inhalt von 2b |
| `docs/context/feat-705-s2-einrichten.md` | Apple-Recherche vom 2026-10-27 (Endpunkte, Regeln, Stolpersteine), PO-Entscheidungen (Limit 50) |

## Apple-Schnittstelle (aus der Recherche 2026-10-27, in `/20-analyse` gegenzuprüfen)

- `POST /v1/betaGroups`: `name` (Pflicht), `isInternalGroup`, `publicLinkEnabled`, `publicLinkLimit`,
  `publicLinkLimitEnabled`, `feedbackEnabled`; Beziehung `app`. `PATCH /v1/betaGroups/{id}` zum Ändern (z. B. Link an).
- `POST /v1/betaGroups/{id}/relationships/builds`: Builds zuordnen (204).
- `POST /v1/betaAppReviewSubmissions`: Beziehung `build`. **Kein Abbruch per API** — nicht rücknehmbar.
- Regeln: externe Gruppe setzt interne voraus (`Familie` existiert); höchstens sechs Einreichungen je 24 h, je Version nur
  ein Build gleichzeitig im Review; erster Build einer Version volle Prüfung, spätere evtl. nicht; Build läuft 90 Tage.
- Stolpersteine: 422 `BETA_CONTRACT_MISSING` (Kontoseite), 422 bei fehlender Beschreibung (erledigt durch 2a).

## Noch offene Fragen für die Analyse

1. Reihenfolge Zuordnen ↔ Einreichen: Verlangt Apple die Gruppenzuordnung vor der Einreichung, oder reicht die Einreichung
   allein, und die Zuordnung danach löst nichts mehr aus?
2. Nimmt die API `publicLinkEnabled=true` an, solange kein Build freigegeben ist? (Recherche: keine Quelle; Annahme
   bisher „Link erst nach Freigabe“.)
3. macOS: eigener Build mit eigener Einreichung, oder genügt `iosBuildsAvailableForAppleSiliconMac`? Die App hat ein
   echtes macOS-Ziel, also eigener Build — Prüfung, ob Mac-Builds überhaupt externe Gruppen erlauben.
4. Verlangt Apple die Datenschutz-URL bei der externen Einreichung (422)? Wenn ja, hängt 2b an #342.
5. Wie wird „neuester gültiger Build“ bestimmt (`sort=-uploadedDate` statt `-version`, `processingState=VALID`,
   `expired=false`), und was passiert, wenn der neueste Build schon eingereicht oder freigegeben ist (Idempotenz)?
6. Feste Folgearbeit: jeder spätere Build braucht Zuordnung (und ggf. Einreichung). Gehört das an `testflight.yml`
   (eigenes Ticket) oder bleibt es ein Handlauf?

## Existing Patterns

- Handlauf über `workflow_dispatch`, nie automatisch; Eingaben sind im öffentlichen Repo sichtbar → keine persönlichen
  Daten als Eingabe.
- Schlüssel nur in `$RUNNER_TEMP` mit `umask 077` und `trap rm -f`.
- Erst alles prüfen, dann lesen, dann planen (reine Funktionen), dann schreiben; zweiter Lauf schreibt nichts.
- Ausgabe nur Zustandswörter; nach dem Schreiben läuft die Probe als Beleg.
- Unumkehrbares hinter einem eigenen, standardmäßig ausgeschalteten Schalter (in 2a-Doku angekündigt: `submit`).

## Dependencies

- Upstream: App-Store-Connect-API, Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`; 2a-Zustand bei Apple
  (Beschreibung, Kontakt) als Voraussetzung der Einreichung; interne Gruppe `Familie`.
- Downstream: #371 (Epic Einladung) und #176 (Prüfliste vor der Einladung) warten auf Gruppe und Link; der öffentliche
  Link ist das, was Henning an Tester gibt.

## Existing Specs

- `docs/specs/feat-705-schnitt-1-sondieren.md`, `docs/specs/feat-705-schnitt-2a-texte-kontakt.md`

## Risks & Considerations

- **Nicht rücknehmbar:** Einreichung zum Beta-Review. Läuft nur auf ausdrückliche Aktion und erst nach Hennings Freigabe.
- **Öffentlich:** Der Link ist weitergebbar; Limit 50 (Henning, 2026-10-27). Eine externe Gruppe ohne Link ist harmlos.
- **Kontingent:** sechs Einreichungen je 24 h; ein fehlerhafter Lauf darf nicht mehrfach einreichen (Idempotenz: Build mit
  bestehender Einreichung wird übersprungen).
- **Zwei Plattformen:** Fehler auf einer Plattform darf die andere nicht halb eingereicht zurücklassen, ohne dass der Log es
  zeigt.
- **Datenschutz-URL** kann die Einreichung blockieren (Frage 4); dann ist #342 der Weg, nicht ein Platzhalter.
- **Apple-Review dauert** (Stunden bis Tage); der Link-Schritt ist ein zweiter Lauf nach der Freigabe.
- Scoping: neues Skript + Test + Workflow + Doku ≈ 4 Dateien; ±250 LoC eng (2a lag bei ~230 + Tests). Gegebenenfalls
  Link-Schritt als eigener kleiner Schnitt.
- Kein App-Code, kein Pfad der Geräteliste (`.github/workflows`, `scripts/`, `docs/` stehen nicht darauf).

## Alternativen (zur Analyse)

- **A — Skript aus der CI** (Muster 2a): wiederholbar, belegt; passt zur wiederkehrenden Zuordnung je Build.
- **B — einmal in der App-Store-Connect-Oberfläche** (per Chrome mit Hennings Anmeldung): Gruppe, Zuordnung, Einreichung,
  Link per Klick; kein Code, Beleg danach per Probe. Für die einmalige Gruppe und den Link attraktiv, für jeden neuen Build
  nicht.
- **C — gemischt:** Gruppe und Link einmal in der Oberfläche, Zuordnung und Einreichung je Build per Skript.

## Analysis

### Type
Feature (Einrichtung bei Apple, kein App-Code)

### Recherche (2026-10-27)
- **Reihenfolge:** Apples Oberfläche fügt den Build erst der Gruppe hinzu, dann „Submit Review“
  ([Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)).
  Per API lässt die Zuordnung allein den Build auf „Ready to Submit“; erst `POST /v1/betaAppReviewSubmissions` schickt ihn
  in den Review ([Apple-Forum 693864](https://developer.apple.com/forums/thread/693864)). → zuordnen, dann einreichen.
  Die Zuordnung ist damit umkehrbar und löst keinen Review aus.
- **Link vor Freigabe:** keine Quelle; Apple: „Once you have builds available to test, and you've added them to a group,
  you can invite testers.“ Forum [109085](https://developer.apple.com/forums/thread/109085): Link zeigt „No Builds available“
  ohne freigegebenen Build. → Link erst nach Freigabe.
- **Freigegeben** heißt `externalBuildState` ∈ {`BETA_APPROVED`, `READY_FOR_BETA_TESTING`, `IN_BETA_TESTING`} (Enum aus Apples
  Doku-JSON `externalbetastate`; weitere Werte: `READY_FOR_BETA_SUBMISSION`, `WAITING_FOR_BETA_REVIEW`, `IN_BETA_REVIEW`,
  `BETA_REJECTED`, `EXPIRED`, `MISSING_EXPORT_COMPLIANCE`, `IN_EXPORT_COMPLIANCE_REVIEW`, `PROCESSING`, `PROCESSING_EXCEPTION`,
  `NOT_APPLICABLE`).
- **Exportnachweis:** Builds stehen extern auf `READY_FOR_BETA_SUBMISSION`, nicht `MISSING_EXPORT_COMPLIANCE` → der
  Exportnachweis (Ticket-Teil 1) ist bei Apple erledigt; die Prüfliste bekommt den Haken mit dem Probe-Beleg.
- **Mac:** TestFlight für Mac nimmt externe Tester und den öffentlichen Link
  ([TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/overview-of-testflight/));
  je Plattform eigener Build, also eigene Zuordnung und eigene Einreichung.
- **Datenschutz-URL:** Apple nennt nur die Beschreibung als Pflicht
  ([Provide test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information));
  Drittquellen ([aso.dev](https://aso.dev/developer/beta-information),
  [codegenes](https://www.codegenes.net/blog/testflight-complete-test-information-is-required-to-submit-a-build-for-external-testing/))
  nennen sie als Pflicht fürs externe Testen; [Forum 706282](https://developer.apple.com/forums/thread/706282): „not required“.
  Ungeklärt. Keine öffentliche Seite vorhanden (GitHub Pages: 404). Entscheidet sich erst bei der Einreichung (2b-2).

### Schnittführung: 2b in zwei Teile (entlang „umkehrbar / unumkehrbar“)
- **2b-1 (dieser Workflow): Gruppe und Zuordnung** — umkehrbar, kein Review.
- **2b-2 (eigener Workflow danach): Einreichung und Link** — Einreichung hinter eigener Aktion, nur nach Hennings Freigabe;
  Link nur, wenn ein Build der Gruppe freigegeben ist, sonst Zustandswort `link=wartet`. `BETA_REJECTED` nie automatisch neu.
- Grund: Skript + Test für alles ≈ 300 LoC + Workflow + Doku sprengt ±250; zudem soll die Probe nach 2b-1 zeigen, was Apple
  aus der Zuordnung macht (kein Auto-Submit, Exportstatus), bevor das Unumkehrbare läuft.
- Spätere Builds brauchen wieder Zuordnung (+ ggf. Einreichung): eigenes Folgeticket an `testflight.yml`, nicht 2b.

### Affected Files (2b-1)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_beta_invite.py` | CREATE | externe Gruppe `Tester` (`isInternalGroup=false`, `feedbackEnabled=true`, Link aus) anlegen falls fehlt; je Plattform (`IOS`, `MAC_OS`, nacheinander) neuesten Build `processingState=VALID`, `expired=false`, `sort=-uploadedDate`, `limit=1` suchen und zuordnen, falls `GET /v1/builds/{id}/betaGroups` die Gruppe nicht nennt (`POST /v1/betaGroups/{id}/relationships/builds`); reine `plan_*`-Funktionen; Zustandswörter (`gruppe=angelegt/vorhanden`, `zuordnung=gesetzt/vorhanden`, `extern=<state>`); Fehler einer Plattform verdeckt die andere nicht, Exit 1 am Ende; 403 → Schreibrecht-Meldung; zwei externe Gruppen gleichen Namens → Fatal |
| `scripts/test_asc_beta_invite.py` | CREATE | FakeASC-Tests (Muster `test_asc_beta_setup.py`): erster Lauf legt an und ordnet zu, zweiter schreibt nichts, Plattform ohne gültigen Build, doppelte Gruppe, 403, nie eine Einreichung gesendet |
| `.github/workflows/asc-beta.yml` | MODIFY | neue Wahl `zuordnen` (Standard bleibt `probe`), Job vor der Probe, Probe als Beleg |
| `docs/reference/testflight.md` | MODIFY | Prüfliste: externe Gruppe, Zuordnung iOS/macOS, Exportnachweis mit Beleg; Hinweis 2b-2 |

### Scope Assessment
- 4 Dateien, ca. +230 LoC (Skript ~100, Test ~100, Workflow ~15, Doku ~15).
- Risk Level: LOW–MEDIUM — kein App-Code, kein Pfad der Geräteliste; Schreiben bei Apple, aber umkehrbar (Gruppe löschbar,
  Zuordnung entfernbar), keine Einreichung.

### Technical Approach
Alternative A (Skript aus der CI, Muster 2a): prüfen → lesen → planen (rein) → schreiben → Probe als Beleg; idempotent,
zweiter Lauf `geschrieben=0`. Wiederverwendung: `read_config`, `find_app_id`, `get_json`, `platform_filter`, `Fatal`
(`asc_wait_build.py`), `send_json`, `get_data` (`asc_what_to_test.py`). Nach dem Merge ein Handlauf `aktion=zuordnen`, dann
die Probe lesen; Folgerungen für 2b-2 im Ticket festhalten.

### Alternativen
| Alternative | Vorteil | Nachteil |
|---|---|---|
| **A Skript (Empfehlung)** | wiederholbar, belegt, Grundlage für die Zuordnung jedes späteren Builds | zwei Schnitte, Apple-Verhalten erst im Lauf sichtbar |
| B einmal per Oberfläche (Chrome, Hennings Anmeldung) | schnell, kein Code | nicht wiederholbar, jeder neue Build wieder per Hand |
| C gemischt (Gruppe/Link per Klick, Zuordnung/Einreichung per Skript) | wenig Code für das Einmalige | Zustand teils unversioniert; die Gruppe ist im Skript billig |

B bleibt Notausgang, falls Apple die Einreichung an die Oberfläche bindet (2b-2). Kein ADR berührt.

### Dependencies
Upstream: die drei ASC-Secrets (Schreibrecht belegt in 2a), interne Gruppe `Familie` (Voraussetzung externer Gruppe),
2a-Texte. Downstream: 2b-2, #371, #176.

### Open Questions
- [x] Reihenfolge Zuordnen ↔ Einreichen → zuordnen, dann einreichen (Recherche)
- [x] Link vor Freigabe → nein, erst nach Freigabe (2b-2)
- [x] macOS → eigener Build, eigene Zuordnung und Einreichung
- [ ] Datenschutz-URL Pflicht? → entscheidet die Einreichung in 2b-2; bei 422 öffentliche Seite (Entwurf liegt freigegeben vor)
- [x] Neuester Build → `VALID`, `expired=false`, `sort=-uploadedDate`
- [x] Folgearbeit je Build → eigenes Ticket an `testflight.yml` (nach 2b anlegen)
- Keine PO-Frage offen: Link-Limit 50 entschieden; der Gruppenname ist für Tester nicht sichtbar.

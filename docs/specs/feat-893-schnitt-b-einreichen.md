---
entity_id: feat-893-schnitt-b-einreichen
type: feature
created: 2026-11-10
updated: 2026-11-10
status: draft
workflow: feat-893-b-einreichen
---

# Spec: #893 Schnitt B — Einreichwerkzeug, Aktion `einreichen`

## Approval

- [ ] Approved

Henning hat am 2026-11-09 per Auswahl freigegeben, dass Version 1.0.1 für iPhone/iPad und Mac per Werkzeug bei Apple zur Prüfung eingereicht wird. Schnitt A (`pruefen`, nur lesen) ist gemergt und lief am echten Konto grün (beide Plattformen bereit). Diese Spec deckt Schnitt B ab: die Aktion `einreichen`, den einzigen nicht rücknehmbaren Schreibweg. Henning hat am 2026-11-10 zugestimmt, dass Schnitt B in einem Stück (ca. 540 LoC) gebaut wird. `approved` gibt die Umsetzung frei. Der echte Lauf reicht ein und ist nur in App Store Connect zurückziehbar („Remove from review“); das Werkzeug löscht und storniert nie.

## Purpose

Das Werkzeug `scripts/asc_store_submit.py` prüft heute nur (`pruefen`). Es reicht nichts ein. Ohne `einreichen` bliebe das Einreichen von 1.0.1 Handarbeit in App Store Connect, nicht wiederholbar und nicht getestet; die Regel lautet, das Werkzeug zu bauen und nicht Arbeit weiterzureichen.

Schnitt B ergänzt `einreichen`: nach einer vollständigen Vorprüfung beider Plattformen (nur GET) wird je Plattform, iOS zuerst, dann macOS, eine Einreichung angelegt oder eine vorhandene wiederverwendet, die Version als Item hinzugefügt und die Einreichung abgeschickt. Danach prüft das Werkzeug im selben Lauf, dass Apple den Zustand `WAITING_FOR_REVIEW` zeigt. Weil die Plattformen nicht atomar eingereicht werden, ist der Ablauf so gebaut, dass ein zweiter Lauf eine fertige Plattform erkennt und nur die fehlende nachholt.

Für Henning ändert sich: Nach dem Merge reicht Claude 1.0.1 für beide Plattformen ein. Er muss nichts tun. Danach steht die Version bei Apple in der Prüfung.

Nicht in diesem Schnitt (Out of Scope):

- Jede Änderung an Texten, Bildern, Review-Detail, Versionen, Bau-Zuordnung oder Freigabeart (`releaseType` wird gelesen und genannt, nie geändert).
- Löschen oder Stornieren von Einreichungen oder Items; Zurückziehen geschieht nur in App Store Connect.
- Änderungen an `asc_store_version.py` und dessen Wächtertest „nie einreichen“.
- **Produktcode:** keiner.

Ohne Modell geht es nicht: nicht relevant. Betriebsskript gegen die ASC-API, Regelweg.

## Source

- **File:** `scripts/asc_store_submit.py` (erweitert), `scripts/test_asc_store_submit.py` (erweitert), `.github/workflows/asc-store-submit.yml` (erweitert), `CLAUDE.md` (eine Zeile); gelesen und wiederverwendet: `scripts/asc_store_version.py`, `scripts/asc_version_texts.py`, `scripts/asc_beta_invite.py`, `scripts/asc_wait_build.py`, `scripts/asc_what_to_test.py`, `scripts/asc_beta_probe.py`, `scripts/test_asc_store_version.py` (nur importiert)
- **Identifier:** neue Funktionen `plan_platform`, `send_once`, `write_platform`, `verify_platform`, `einreichen` und Eintrag in `ACTIONS` in `asc_store_submit.py`; `SubmitFakeASC` (erweitert) und `WorkflowTests` im Test; Option `einreichen` und Eingabe `bestaetigung` im Workflow
- **Beleg Schnitt A:** `docs/artifacts/feat-893-einreichen/echter-lauf-pruefen.md` (Listenform der `reviewSubmissions` belegt, Zustand `COMPLETE` belegt; `READY_FOR_REVIEW` und `WAITING_FOR_REVIEW` bisher nie echt gesehen)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `check_platform`, `editable_for`, `submissions`, `same_number`, Konstanten `BUSY`, `REUSABLE`, `DONE`, `SHORT` (`scripts/asc_store_submit.py`) | Modul | Prüfungen aus Schnitt A werden im Plan wiederverwendet, nicht kopiert; `pruefen` bleibt im Verhalten unverändert |
| `get_one`, `current_build`, `count` (`scripts/asc_store_version.py`) | Modul | wie in Schnitt A; `send` wird bewusst nicht benutzt (wiederholt bei 5xx, gibt keinen Rumpf zurück); Datei bleibt unverändert |
| `app_versions`, `EDITABLE`, `PLATFORMS` (`scripts/asc_version_texts.py`) | Modul | Versionen, Zustandswort `PREPARE_FOR_SUBMISSION`, Plattformen `IOS`, `MAC_OS` |
| `Masked`, `message`, Muster `post_submission` (`scripts/asc_beta_invite.py`) | Modul / Muster | stdout-Filter; Vorbild für den Einmal-Aufruf: genau ein Versuch, nie wiederholt, 409 klar gemeldet. Es wird ein eigener `send_once` gebaut, der den Rumpf zurückgibt |
| `Fatal`, `find_app_id`, `read_config`, `make_token` (`scripts/asc_wait_build.py`) | Modul | Fehlerklasse, App-Suche, Konfiguration, JWT |
| `get_data` (`scripts/asc_what_to_test.py`) | Modul | GET einer Liste; `send_json` wird hier NICHT für POST/PATCH benutzt, weil es bei 5xx/408/429 und Netzfehlern wiederholt und eine zweite Einreichung anlegen könnte |
| `records`, `attributes` (`scripts/asc_beta_probe.py`) | Modul | Datensätze und Attribute aus Antworten |
| `FakeASC`, `version`, `build`, `loc` (`scripts/test_asc_store_version.py`) | Test-Modul | Nachbau mit Zustand; Datei bleibt unverändert |
| `POST /v1/reviewSubmissions` (`attributes.platform`, `relationships.app`) | API | legt eine Einreichung an (Zustand `READY_FOR_REVIEW`) |
| `GET /v1/reviewSubmissions/{id}/items` | API | Items der Einreichung lesen, bevor eines hinzugefügt wird |
| `POST /v1/reviewSubmissionItems` (`relationships.reviewSubmission`, `relationships.appStoreVersion`) | API | die Version als Item der Einreichung |
| `PATCH /v1/reviewSubmissions/{id}` (`attributes.submitted=true`) | API | schickt die Einreichung ab; vor dem Item liefert Apple 422 |
| Apple: Überblick Einreichen, Foren (https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review, https://developer.apple.com/forums/thread/802281, https://developer.apple.com/forums/thread/844351, https://dev.to/snake_sun/the-asc-apis-3-step-review-submission-flow-and-why-appstoreversionsubmissions-is-gone-24ld), Recherche 2026-11-10 | Quelle | Drei-Schritt-Ablauf; je Plattform eine eigene Einreichung („Items associated with different platforms can't be added to the same submission“); `appStoreVersionSubmissions` ist abgelöst; bekannte Fehler: 409 bei nicht einreichbarem Zustand oder vorhandener offener Einreichung, `CONCURRENT_REVIEW_SUBMISSION_LIMIT_EXCEEDED`, 422 bei leerer Einreichung |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_store_submit.py | MODIFY | Aktion `einreichen`: Sperrwort, Plan (nur GET), Schreiben je Plattform, Gegenprobe; `send_once`; Eintrag in `ACTIONS` (ca. +140 LoC) |
| scripts/test_asc_store_submit.py | MODIFY | `SubmitFakeASC` um POST `reviewSubmissions`, POST `reviewSubmissionItems`, GET `…/items`, PATCH `submitted` mit Zustandswechsel und Fehlerschalter; Tests je Regel; `WorkflowTests` und `test_bad_usage_makes_no_call` wachsen mit (ca. +380 LoC) |
| .github/workflows/asc-store-submit.yml | MODIFY | Option `einreichen`, Eingabe `bestaetigung`, Kopfkommentar (ca. +20 LoC) |
| CLAUDE.md | MODIFY | die Build-Zeile zu `asc-store-submit.yml` beschreibt `einreichen` statt „Schnitt B ergänzt `einreichen`“ (ca. +1 LoC) |

Nicht betroffen (geprüft): `scripts/asc_store_version.py` und `scripts/test_asc_store_version.py` (unverändert, einschließlich des Wächtertests „nie einreichen“), `scripts/asc_version_texts.py`, `scripts/asc_beta_invite.py`, `scripts/asc_what_to_test.py`, Produktcode, `project.yml`, `ci.yml`.

### Estimated Changes
- Dateien: **4** (Grenze 4–5 eingehalten), dazu die Belege unter `docs/artifacts/feat-893-einreichen/`.
- LoC: ca. **+540** (Skript ca. 140, Tests ca. 380, Workflow ca. 20, CLAUDE.md 1). Ohne Tests liegt der Schnitt bei ca. 160 und damit unter der 250er-Grenze; die Tests liegen darüber, weil jede Sicherheitsregel eines nicht rücknehmbaren Weges einzeln bewiesen wird (Muster #842 5a-1, #893 Schnitt A). Henning hat am 2026-11-10 „Ja, in einem Stück“ zugestimmt. **Meldeschwelle: 650 LoC**; nach dem RED-Schritt werden die Testzeilen gezählt; darüber wird vor dem Weiterbauen gefragt.
- Produktcode: keiner. Keine Berechtigung, keine `Info.plist`, kein Schema.
- „Kein Pfad der Geräteliste berührt.“

## Implementation Details

**1. Aufruf und Sperre.** `asc_store_submit.py einreichen <nummer>`; `<nummer>` ist die Versionsnummer der Zielversion (`1.0.1`). `ACTIONS` erhält den Eintrag `einreichen`. Fehlt `<nummer>` oder weicht sie von der Nummer der bearbeitbaren Version ab (bei einer schon eingereichten Plattform: von der Nummer ihrer Version), endet der Lauf mit `::error::` und Ausgang 1, ohne jeden Schreibaufruf. Das Skript prüft das selbst, nicht nur der Workflow. `pruefen` bleibt bei genau einem Argument; die Aufrufzeile bei falscher Benutzung nennt beide Aktionen (`::error::Aufruf: asc_store_submit.py pruefen|einreichen <nummer>`). Umgebung wie bisher (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_FILE`, `ASC_BUNDLE_ID`, `ASC_API_BASE`, `ASC_POLL_SECONDS`). Die Ausgabe läuft über `Masked`.

**2. Plan, nur GET, beide Plattformen vollständig.** Vor dem ersten Schreibaufruf wertet `plan_platform` beide Plattformen aus und nutzt dafür die Prüfungen aus Schnitt A (`check_platform`, `same_number`). Je Plattform gibt es drei Ausgänge:
- `eingereicht`: es gibt eine Version mit der Zielnummer im `appStoreState` `WAITING_FOR_REVIEW` oder `IN_REVIEW` und eine dazu passende Einreichung der Plattform im Zustand `WAITING_FOR_REVIEW` oder `IN_REVIEW`. Die Plattform wird übersprungen.
- `bereit`: alle Prüfungen von `pruefen` ohne Grund → wird geschrieben.
- `nicht-bereit`: sonst. Ein einziger Grund bei einer nicht eingereichten Plattform bricht **beide** Plattformen ab, ohne jeden Schreibaufruf; Ausgang 1, die Gründe stehen im Protokoll.

Die Versionsgleichheit (`same_number`) zählt eine schon eingereichte Plattform mit (deren Version ist nicht mehr bearbeitbar); Plattformen, die schon `eingereicht` sind, werden von den Prüfungen der bearbeitbaren Version (Bau, Texte, Bilder) ausgenommen. Eine zweite Lage `eingereicht` auf beiden Plattformen endet mit Ausgang 0 ohne Schreibaufruf (idempotent).

**3. Schreiben je Plattform, iOS zuerst, dann MAC_OS** (`write_platform`, nur für Plattformen im Ausgang `bereit`):
1. Einreichung bestimmen: genau eine `READY_FOR_REVIEW`-Einreichung der Plattform wird wiederverwendet, sonst `POST /v1/reviewSubmissions` mit `platform` und `app`.
2. Items lesen (`GET /v1/reviewSubmissions/{id}/items`): leer → `POST /v1/reviewSubmissionItems` mit der Version; genau unsere Version → überspringen; jedes fremde Item (anderer Typ oder andere Version) → Abbruch mit klarer Meldung, ohne zu löschen.
3. `PATCH /v1/reviewSubmissions/{id}` mit `submitted=true`.

Jeder Schreibaufruf läuft genau einmal. `send_once` ist ein eigener Einmal-Aufruf nach dem Muster `post_submission`: ein `urllib`-Aufruf, kein Wiederholen bei 5xx, 408, 429 oder Netzfehlern, Rückgabe des Rumpfs (für die neue Einreichungskennung), `Fatal` mit kurzer Meldung. 409 und 422 werden als klare Meldung mit den Fehlercodes aus Apples Antwort (`errors[].code`) gemeldet, nie als Rohantwort. Scheitert ein Schreibaufruf, endet der Lauf sofort mit Ausgang 1; die andere Plattform wird dann nicht versucht (scheitert iOS, wird Mac nicht angefasst). Eine dabei liegengebliebene `READY_FOR_REVIEW`-Einreichung (ohne oder mit Item) wird im nächsten Lauf wiederverwendet, nie neu angelegt.

**4. Gegenprobe im selben Lauf** (`verify_platform`, je geschriebener und je schon eingereichter Plattform): die Einreichung steht auf `WAITING_FOR_REVIEW` (oder weiter: `IN_REVIEW`) und die Version auf `appStoreState` `WAITING_FOR_REVIEW` (oder weiter). Apple setzt den Zustand ggf. verzögert, daher begrenztes Nachlesen (wenige Versuche im Abstand `ASC_POLL_SECONDS`). Stimmt es danach nicht, endet der Lauf mit Ausgang 1 und nennt die Zustandswörter; die Einreichung wird nie zurückgenommen.

**5. Ausgabe.** Nur Zustandswörter, Zahlen und die Freigabeart `releaseType` (gelesen und genannt, nie geändert); nie Kennungen, Schlüssel, Token, Apples Rohantwort oder Store-Wortlaut (`Masked`). Zeilen je Plattform: `<Plattform> eingereicht|bereit|nicht-bereit: <Grund>`, je Schreibschritt `<Plattform> schritt einreichung angelegt|wiederverwendet`, `item hinzugefügt|vorhanden`, `abgeschickt`, danach `<Plattform> gegenprobe einreichung=<Zustand> version=<Zustand>`; zuletzt `zusammenfassung eingereicht=<ios,mac|Teilmenge|keine>`. Ausgang 0 nur, wenn beide Plattformen nach der Gegenprobe eingereicht sind.

**6. Nie.** Kein DELETE, kein Stornieren, keine Änderung an Texten, Bildern, Review-Detail, Bau, Versionen oder Freigabeart. Das Skript hat außer den drei genannten Schreibwegen (POST reviewSubmissions, POST reviewSubmissionItems, PATCH reviewSubmissions) keinen Schreibpfad. `asc_store_version.py` bleibt unverändert.

**7. Workflow `asc-store-submit.yml`.** `aktion` erhält die Option `einreichen` (Standard bleibt `pruefen`), neue Eingabe `bestaetigung` (string, Beschreibung: Versionsnummer der Zielversion, z. B. `1.0.1`; nur für `einreichen`). Der Handlaufschritt ruft `pruefen` ohne Zusatz und `einreichen` mit `"$BESTAETIGUNG"` als zweitem Argument; ist die Aktion `einreichen` und `bestaetigung` leer, bricht der Schritt vor dem Schreiben des Schlüssels ab. `concurrency` (Gruppe `asc-store-submit`, `cancel-in-progress: false`), `permissions: contents: read`, Tests als erster Schritt und der Schlüsselumgang (`umask 077`, `trap`) bleiben unverändert. Der Kopfkommentar nennt: `pruefen` liest nur; `einreichen` reicht nach Hennings Freigabe vom 2026-11-09 ein und braucht die Versionsnummer als Bestätigung.

**8. CLAUDE.md.** Die Build-Zeile zu `asc-store-submit.yml` beschreibt `einreichen` (Bestätigung durch die Versionsnummer, je Plattform iOS zuerst, Einmal-Aufrufe, Gegenprobe, nie löschen oder stornieren) statt „Schnitt B ergänzt `einreichen`“. Die Zusage „nie einreichen“ der Zeile zu `asc-store-version.yml` bleibt wahr und unverändert.

**9. Ablauf am echten Konto (Nachweis, Teil der Definition of Done).** Nach dem Merge läuft zuerst ein erneuter `pruefen`-Lauf (der Stand kann sich seit Schnitt A geändert haben), dann `einreichen` mit `bestaetigung=1.0.1` per `workflow_dispatch`. Das Protokoll belegt Apples Antworten auf POST und PATCH und die Zustände `READY_FOR_REVIEW`/`WAITING_FOR_REVIEW`, die bisher nur aus der Dokumentation bekannt sind. Weicht eine Form ab, wird das Skript korrigiert, nie der Nachbau angepasst, um grün zu werden. Dieser Lauf ist nicht wiederholbar; das ist ein Punkt der Definition of Done, kein AC, weil er erst nach dem Merge erfüllbar ist.

### Alternativen

| Weg | trägt? | Haken |
|---|---|---|
| **`einreichen` im vorhandenen Skript, Plan mit GET, Einmal-Aufrufe, Gegenprobe (gewählt)** | ja | baut auf dem belegten Lesebeleg von Schnitt A auf; Idempotenz und Wiederaufnahme sind eingebaut |
| A Einreichen per Hand in App Store Connect (Henning oder Claude im Browser) | ja | kein Code, aber nicht wiederholbar und nicht getestet; widerspricht „Werkzeug reparieren statt weiterreichen“; verworfen |
| B fastlane `deliver submit_for_review` | ja | neue Abhängigkeit (Ruby) und eigener Schlüsselumgang; kippt die Linie „eigene ASC-Skripte ohne Fremdwerkzeug“ (#742, #842); verworfen |
| C Altes `appStoreVersionSubmissions` | nein | von Apple abgelöst; verworfen |
| D Zwei Schnitte (B1 anlegen und Item, B2 `submitted`) | ja | kleiner je Schnitt, aber B1 allein hinterlässt nur einen Entwurf ohne Nutzen und verdoppelt den Ablauf; nicht empfohlen |

Gekippt wird keine ADR.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_store_submit.py` (`unittest`, ohne Netz). `SubmitFakeASC` (erbt von `FakeASC`, lokaler HTTP-Server, `ASC_API_BASE` zeigt darauf) wird erweitert um: `POST /v1/reviewSubmissions` (legt eine Einreichung `READY_FOR_REVIEW` an), `POST /v1/reviewSubmissionItems` (hängt die Version an), `GET /v1/reviewSubmissions/{id}/items`, `PATCH /v1/reviewSubmissions/{id}` mit `submitted=true` (Zustandswechsel der Einreichung und der Version auf `WAITING_FOR_REVIEW`, optional verzögert), ein Aufrufprotokoll (Methode, Pfad), Schalter für Fehler je Aufruf (5xx, Netzabbruch, 409, 422 mit Geheimwert im Rohtext), für ein fremdes Item und für eine vorhandene Einreichung. Fixtures: beide Plattformen vollständig bereit wie in Schnitt A. RED: `einreichen` existiert noch nicht.

- [ ] `test_einreichen_success_both_platforms_ios_first`: GIVEN beide Plattformen bereit und `einreichen 1.0.1` WHEN der Lauf startet THEN je Plattform die Aufrufe POST Einreichung, POST Item, PATCH `submitted` in dieser Reihenfolge, iOS vollständig vor MAC_OS, Gegenprobe `WAITING_FOR_REVIEW` auf beiden, `zusammenfassung eingereicht=ios,mac`, Ausgang 0.
- [ ] `test_confirmation_must_equal_version_number`: GIVEN keine Nummer, eine falsche Nummer (`1.0.2`) oder eine leere Nummer WHEN `einreichen` läuft THEN Ausgang 1 mit `::error::` und es kam kein Schreibaufruf an (Aufrufprotokoll ohne POST/PATCH/DELETE).
- [ ] `test_one_platform_not_ready_writes_nothing_on_both`: GIVEN iOS bereit und Mac nicht bereit (und umgekehrt) WHEN `einreichen` läuft THEN stehen die Gründe der nicht bereiten Plattform im Protokoll, Ausgang 1 und es kam bei keiner der beiden Plattformen ein Schreibaufruf an.
- [ ] `test_resume_ios_already_submitted_only_mac`: GIVEN iOS-Version `WAITING_FOR_REVIEW` mit passender Einreichung und Mac bereit WHEN `einreichen` läuft THEN iOS wird übersprungen (`eingereicht`, kein Schreibaufruf für iOS), nur Mac wird geschrieben, Gegenprobe beider, Ausgang 0.
- [ ] `test_reuses_single_ready_for_review_submission`: GIVEN genau eine `READY_FOR_REVIEW`-Einreichung ohne Item, bzw. mit genau unserem Item WHEN `einreichen` läuft THEN kein POST auf `reviewSubmissions`; im ersten Fall ein POST Item, im zweiten keiner; in beiden Fällen ein PATCH `submitted`; Ausgang 0.
- [ ] `test_foreign_item_aborts_without_delete`: GIVEN eine `READY_FOR_REVIEW`-Einreichung mit einem fremden Item (anderer Typ bzw. andere Version) WHEN `einreichen` läuft THEN Abbruch mit klarer Meldung, Ausgang 1, kein POST Item, kein PATCH, kein DELETE.
- [ ] `test_no_retry_on_5xx_or_network_error`: GIVEN der Nachbau antwortet beim POST Einreichung, beim POST Item bzw. beim PATCH mit 500 oder bricht die Verbindung ab WHEN `einreichen` läuft THEN kam der betroffene Schreibaufruf genau einmal an, Ausgang 1 mit klarer Meldung, und nach einem iOS-Fehler wurde Mac nicht versucht.
- [ ] `test_409_and_422_clear_message_without_raw_answer`: GIVEN 409 bzw. 422 mit Fehlercode und Geheimwert im Rohtext WHEN `einreichen` läuft THEN nennt die Meldung die Fehlercodes und den Aufruf, nie die Rohantwort oder den Geheimwert, Ausgang 1, kein weiterer Schreibaufruf.
- [ ] `test_counter_check_failure_exit_one`: GIVEN der PATCH gelingt, aber Einreichung oder Version bleiben nach den begrenzten Versuchen in einem anderen Zustand als `WAITING_FOR_REVIEW`/`IN_REVIEW` WHEN `einreichen` läuft THEN Ausgang 1 mit den Zustandswörtern, und ein verzögerter Wechsel innerhalb der Versuche gilt als bestanden.
- [ ] `test_output_has_no_ids_raw_answers_or_wording`: GIVEN ein erfolgreicher und ein fehlgeschlagener Lauf, Kennungen im Nachbau, Store-Wortlaut und Geheimwert in Fehlerantworten WHEN `einreichen` läuft THEN enthält die Ausgabe weder Kennungen noch Rohantwort noch Wortlaut noch Schlüssel; `releaseType` erscheint als Wort.
- [ ] `test_never_deletes_or_touches_other_resources`: GIVEN jeder Lauf von `einreichen` (Erfolg, Wiederaufnahme, Wiederverwendung, Fehlerfälle) WHEN das Aufrufprotokoll geprüft wird THEN enthält es nur GET sowie POST `/v1/reviewSubmissions`, POST `/v1/reviewSubmissionItems` und PATCH `/v1/reviewSubmissions/{id}`; nie DELETE, nie eine Änderung an Versionen, Lokalisierungen, Bildern, Review-Detail oder Bau.
- [ ] `test_second_run_writes_nothing`: GIVEN ein erfolgreicher Lauf WHEN `einreichen 1.0.1` ein zweites Mal läuft THEN beide Plattformen `eingereicht`, kein Schreibaufruf, Ausgang 0.
- [ ] `test_pruefen_unchanged`: GIVEN die bestehenden Prüfungen aus Schnitt A WHEN `pruefen` mit dem erweiterten Nachbau läuft THEN verhält sich `pruefen` wie zuvor (Ausgabe, Ausgang, nie Nicht-GET) und alle Tests aus Schnitt A bleiben grün.
- [ ] `test_bad_usage_makes_no_call`: GIVEN keine, eine unbekannte Aktion oder `pruefen` mit Zusatzargument WHEN das Skript startet THEN Ausgang 1 mit `::error::Aufruf: asc_store_submit.py pruefen|einreichen <nummer>` und ohne Anfrage.
- [ ] `test_workflow_offers_einreichen_with_confirmation_and_hides_the_key`: GIVEN die Workflow-Datei THEN bietet `aktion` `pruefen` und `einreichen`, die Eingabe `bestaetigung` existiert, `concurrency` hat die Gruppe `asc-store-submit` mit `cancel-in-progress: false`, die Python-Tests laufen als erster Schritt, der Handlaufschritt hängt an `workflow_dispatch`, der Schlüssel wird nie ausgegeben (Muster `WorkflowTests`).
- [ ] `test_store_version_script_untouched`: GIVEN `scripts/asc_store_version.py` THEN enthält es weiterhin keinen Pfad mit `ubmission`, und `scripts/test_asc_store_version.py` ist mit seinem Wächtertest `test_never_deletes_submits_or_writes_texts` unverändert grün (Lauf der bestehenden Testdatei als Unterprozess).

## Acceptance Criteria

- **AC-1:** Given beide Plattformen bereit und `einreichen 1.0.1`, When der Lauf startet, Then laufen je Plattform POST Einreichung, POST Item und PATCH `submitted` in dieser Reihenfolge, iOS vollständig vor MAC_OS, die Gegenprobe zeigt `WAITING_FOR_REVIEW` und der Ausgang ist 0. Belegt durch `test_einreichen_success_both_platforms_ios_first`.
- **AC-2:** Given eine fehlende, leere oder von der Zielversion abweichende Nummer, When `einreichen` läuft, Then endet der Lauf mit Ausgang 1 ohne jeden Schreibaufruf. Belegt durch `test_confirmation_must_equal_version_number`.
- **AC-3:** Given eine Plattform ist nicht bereit, When `einreichen` läuft, Then werden die Gründe genannt, der Ausgang ist 1 und es gibt bei beiden Plattformen keinen Schreibaufruf. Belegt durch `test_one_platform_not_ready_writes_nothing_on_both`.
- **AC-4:** Given iOS ist schon eingereicht (Version und Einreichung `WAITING_FOR_REVIEW`) und Mac ist bereit, When `einreichen` läuft, Then wird iOS übersprungen, nur Mac geschrieben und der Ausgang ist 0. Belegt durch `test_resume_ios_already_submitted_only_mac`.
- **AC-5:** Given genau eine `READY_FOR_REVIEW`-Einreichung ohne Item oder mit genau unserem Item, When `einreichen` läuft, Then wird sie wiederverwendet (kein neuer POST Einreichung, POST Item nur bei leerer Einreichung) und abgeschickt. Belegt durch `test_reuses_single_ready_for_review_submission`.
- **AC-6:** Given eine Einreichung mit einem fremden Item, When `einreichen` läuft, Then bricht der Lauf mit klarer Meldung und Ausgang 1 ab, ohne Item hinzuzufügen, abzuschicken oder zu löschen. Belegt durch `test_foreign_item_aborts_without_delete`.
- **AC-7:** Given 5xx oder Netzfehler bei POST Einreichung, POST Item oder PATCH, When `einreichen` läuft, Then wird der betroffene Aufruf genau einmal versucht, nie wiederholt, der Ausgang ist 1 mit klarer Meldung, und Mac wird nach einem iOS-Fehler nicht versucht. Belegt durch `test_no_retry_on_5xx_or_network_error`.
- **AC-8:** Given 409 oder 422 von Apple, When `einreichen` läuft, Then nennt die Meldung Aufruf und Fehlercodes, nie die Rohantwort, der Ausgang ist 1 und es folgt kein weiterer Schreibaufruf. Belegt durch `test_409_and_422_clear_message_without_raw_answer`.
- **AC-9:** Given der PATCH gelingt, die Zustände erreichen aber nicht `WAITING_FOR_REVIEW` oder weiter, When die Gegenprobe ausgewertet ist, Then ist der Ausgang 1 mit den Zustandswörtern; ein verzögerter Wechsel innerhalb der begrenzten Versuche genügt. Belegt durch `test_counter_check_failure_exit_one`.
- **AC-10:** Given ein Lauf mit oder ohne Fehler, When die Ausgabe geprüft wird, Then enthält sie nur Zustandswörter, Zahlen und `releaseType`, nie Kennungen, Rohantwort, Store-Wortlaut oder Schlüssel. Belegt durch `test_output_has_no_ids_raw_answers_or_wording`.
- **AC-11:** Given jeder Lauf von `einreichen`, When das Aufrufprotokoll geprüft wird, Then enthält es nur GET, POST `reviewSubmissions`, POST `reviewSubmissionItems` und PATCH `reviewSubmissions/{id}`, nie DELETE und nie eine Änderung an Versionen, Texten, Bildern, Review-Detail oder Bau. Belegt durch `test_never_deletes_or_touches_other_resources`.
- **AC-12:** Given ein erfolgreicher Lauf, When `einreichen 1.0.1` erneut läuft, Then sind beide Plattformen `eingereicht`, es gibt keinen Schreibaufruf und der Ausgang ist 0. Belegt durch `test_second_run_writes_nothing`.
- **AC-13:** Given die Änderung, When `pruefen` und eine falsche Benutzung geprüft werden, Then verhält sich `pruefen` unverändert (alle Tests aus Schnitt A grün), und keine, eine unbekannte Aktion oder `pruefen` mit Zusatzargument enden mit `::error::Aufruf: asc_store_submit.py pruefen|einreichen <nummer>` und Ausgang 1 ohne Anfrage. Belegt durch `test_pruefen_unchanged` und `test_bad_usage_makes_no_call`.
- **AC-14:** Given die Workflow-Datei, When sie geprüft wird, Then bietet `aktion` `pruefen` und `einreichen`, die Eingabe `bestaetigung` existiert, `concurrency` nutzt die Gruppe `asc-store-submit` ohne Abbruch laufender Läufe, die Python-Tests laufen als erster Schritt, der Handlaufschritt hängt an `workflow_dispatch` und der Schlüssel wird nie ausgegeben. Belegt durch `test_workflow_offers_einreichen_with_confirmation_and_hides_the_key`.
- **AC-15:** Given die Änderung, When `asc_store_version.py` und sein Test geprüft werden, Then sind beide unverändert, der Wächtertest „nie einreichen“ ist grün, und die Abnahme endet nach Stufe 2 mit dem Satz „Kein Pfad der Geräteliste berührt.“ Belegt durch `test_store_version_script_untouched` und die Läufe von `python3 scripts/test_asc_store_submit.py`, `python3 scripts/test_asc_store_version.py` und `python3 scripts/test_asc_version_texts.py`.

**Abnahmeweg.** Stufe 1: Python-Tests (AC-1 bis AC-15). Stufe 2: der echte Werkzeuglauf gegen Apple nach dem Merge (erneut `pruefen`, dann `einreichen`; siehe Definition of Done, kein AC, weil erst nach dem Merge erfüllbar). Die Dateigrenze (der Diff berührt nur `scripts/`, `.github/workflows/`, `CLAUDE.md` und `docs/`) ist ein Validierungsbeleg in `/60-validate`, kein Test. Stufe 3 greift nicht. Auf Hennings Geräten läuft nichts.

## Definition of Done

- [ ] Die Tests waren vor dem Skript vorhanden (RED) und sind danach grün; die übrigen Skript-Tests bleiben grün.
- [ ] Der Umfang blieb unter der Meldeschwelle von 650 LoC, sonst wurde vor dem Weiterbauen gefragt.
- [ ] PR gemergt, CI grün.
- [ ] Nach dem Merge lief `asc-store-submit.yml` erneut mit `aktion=pruefen` und danach mit `aktion=einreichen`, `bestaetigung=1.0.1` per `workflow_dispatch` gegen das echte Konto; Run-IDs und zitierte Protokollzeilen stehen unter `docs/artifacts/feat-893-einreichen/`. Das Protokoll belegt je Plattform die Gegenprobe (Einreichung und Version `WAITING_FOR_REVIEW`) und Apples Antworten auf POST und PATCH. Weicht eine Form ab, ist das Skript korrigiert, bevor weiter eingereicht wird.
- [ ] #893 ist nach dem echten Beleg kommentiert und geschlossen (end-to-end erledigt: beide Plattformen bei Apple in der Prüfung).

## Seiteneffekte

- Geänderte Dateien: die vier oben; dazu die Belege unter `docs/artifacts/feat-893-einreichen/`.
- Bei Apple: der echte Lauf legt je Plattform eine Einreichung mit der Version als Item an und schickt sie ab; Version 1.0.1 steht danach in der Prüfung. Das ist nur in App Store Connect zurückziehbar. Das Werkzeug ändert, löscht und storniert sonst nichts.
- Keine neuen Berechtigungen, keine `Info.plist`, keine `project.yml`-Änderung, keine AppStorage-Schlüssel, keine Audio-Dateien, keine neuen Dependencies, kein Produktcode.

## Risiken

- **Nicht atomar über Plattformen.** iOS kann eingereicht sein, wenn Mac scheitert. Gegenmaßnahme: volle Vorprüfung beider Plattformen vor dem ersten Schreiben; iOS zuerst; ein zweiter Lauf erkennt die fertige Plattform und holt nur die fehlende nach.
- **Doppelte Einreichung durch Wiederholung.** Gegenmaßnahme: eigene Einmal-Aufrufe ohne Wiederholen (nicht `send_json`); eine liegengebliebene `READY_FOR_REVIEW`-Einreichung wird im nächsten Lauf wiederverwendet.
- **Einreichung mit fremdem Inhalt.** Items werden vor dem Hinzufügen gelesen; Fremdes bricht ab, nie wird gelöscht.
- **Apples Formen nur aus Dokumentation und Foren bekannt.** Antworten auf POST/PATCH und die Zustände `READY_FOR_REVIEW`/`WAITING_FOR_REVIEW` sind echt noch nie gesehen; der Nachbau beweist sie nicht. Gegenmaßnahme: Auswertung je Zeile und fail-closed bei unbekannten Zuständen; der echte Lauf ist zugleich der Beleg und nicht wiederholbar, deshalb vorher ein erneuter `pruefen`-Lauf.
- **Versehentlicher Handlauf.** Gegenmaßnahme: die Bestätigung durch die Versionsnummer, im Skript und im Workflow geprüft.
- **Apple prüft beim Abschicken zusätzlich selbst** (Exportangaben, Altersfreigabe, Datenschutz); 409/422 werden als klare Meldung ausgegeben, der Lauf endet mit Ausgang 1.
- **Umfang.** Ca. 540 LoC, davon ca. 380 Tests; Meldeschwelle 650.

## Known Limitations

- Eine einmal abgeschickte Einreichung nimmt das Werkzeug nie zurück; Zurückziehen geht nur in App Store Connect.
- `pruefen` und `einreichen` sind Momentaufnahmen; `einreichen` plant deshalb vor dem ersten Schreiben selbst neu.
- Die Freigabeart (`releaseType`) wird nur gelesen und genannt.
- Die Liste der Einreichungen wird mit `limit=50` gelesen (wie in Schnitt A).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Betriebswerkzeug ohne Produktcode nach dem Muster der bestehenden ASC-Werkzeuge (`asc_store_version`, `asc_beta_invite`); es wird keine bestehende ADR gekippt (keine der Alternativen berührt eine ADR).
- **Rationale:** Der einzige nicht rücknehmbare Schreibweg liegt im eigenen Skript mit eigenem Workflow und eigener Sperre; die Einmal-Aufrufe nach dem Muster `post_submission`, der Plan nur mit GET und die Gegenprobe im selben Lauf setzen das Muster „erst GET, dann Schreiben, dann Gegenprobe“ fort. Das ist eine technische Frage ohne Produktauswirkung.

## Changelog

- 2026-11-10: Initial spec created (Schnitt B von #893: Aktion `einreichen` in `asc_store_submit.py` mit Bestätigung durch die Versionsnummer, Plan nur GET über beide Plattformen, Schreiben je Plattform iOS zuerst mit Einmal-Aufrufen, Gegenprobe im selben Lauf; Workflow-Option und Eingabe `bestaetigung`; CLAUDE.md-Zeile)

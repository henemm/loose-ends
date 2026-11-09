---
entity_id: feat-893-schnitt-a-pruefen
type: feature
created: 2026-11-09
updated: 2026-11-09
status: draft
workflow: feat-893-einreichen
---

# Spec: #893 Schnitt A — Einreichwerkzeug, Aktion `pruefen` (nur lesen)

## Approval

- [ ] Approved

Henning hat am 2026-11-09 per Auswahl freigegeben, dass Version 1.0.1 für iPhone/iPad und Mac per Werkzeug bei Apple zur Prüfung eingereicht wird (Folge aus #842). Die Gesamtarbeit ist in zwei Schnitte geteilt. Diese Spec deckt nur Schnitt A ab: eine reine Lese-Aktion, die den Stand vor dem Einreichen prüft. Schnitt B (`einreichen`, der einzige nicht rücknehmbare Schreibweg) bekommt eine eigene Spec und einen eigenen Workflow. Es wird in diesem Schnitt nichts eingereicht, nichts geschrieben. `approved` gibt die Umsetzung frei.

## Purpose

Es gibt kein Werkzeug, das vor dem Einreichen belegt, ob beide Plattformen (iPhone/iPad und Mac) wirklich einreichbar sind: genau eine bearbeitbare Version, Bau zugeordnet und gültig, Texte und Bilder je Sprache vollständig, Review-Detail vorhanden, keine Einreichung blockiert. Außerdem ist Apples Listenform der `reviewSubmissions` (Filter, Zustandswerte) bisher nur aus der Dokumentation bekannt. Reicht man auf dieser Grundlage ein, scheitert der zweite Teil womöglich, nachdem der erste (iOS) schon in Apples Prüfung steht.

Schnitt A liefert ein neues Skript `scripts/asc_store_submit.py` mit der einen Aktion `pruefen` (ausschließlich GET). Es wertet beide Plattformen vollständig aus und meldet je Plattform „bereit“ oder alle Gründe, warum nicht. Es belegt im echten Lauf Apples Listenform der Einreichungen, bevor ein Schreibweg gebaut wird. Der Eintritt ist so gebaut, dass Schnitt B die Aktion `einreichen` ergänzen kann; in diesem Schnitt gibt es sie nicht und der Aufruf wird mit klarer Meldung abgelehnt.

Für Henning ändert sich: Nichts Sichtbares. Er muss nichts tun. Danach ist belegt, ob die Einreichung von 1.0.1 an Apples Voraussetzungen scheitern würde.

Nicht in diesem Schnitt (Out of Scope, Folgeschnitt B, eigene Spec):

- **`einreichen`:** Anlegen einer Einreichung, Item, `submitted=true`, Sperrwort, Wiederverwendung einer READY_FOR_REVIEW-Einreichung, Gegenprobe.
- Jede Änderung an Texten, Bildern, Review-Detail, Versionen oder Bau-Zuordnung; `asc_store_version.py` und sein Wächtertest „nie einreichen“ bleiben unverändert.
- **Produktcode:** keiner.

Ohne Modell geht es nicht: nicht relevant. Betriebsskript gegen die ASC-API, Regelweg.

## Source

- **File:** `scripts/asc_store_submit.py` (neu), `scripts/test_asc_store_submit.py` (neu), `.github/workflows/asc-store-submit.yml` (neu); gelesen und wiederverwendet: `scripts/asc_store_version.py`, `scripts/asc_version_texts.py`, `scripts/asc_beta_invite.py`, `scripts/asc_wait_build.py`, `scripts/asc_what_to_test.py`, `scripts/asc_beta_probe.py`, `scripts/test_asc_store_version.py` (nur importiert)
- **Identifier:** neue Funktionen `editable_for`, `check_texts`, `check_images`, `check_build`, `check_submissions`, `check_platform`, `pruefen`, `main` in `asc_store_submit.py`; Tabelle `ACTIONS` als Erweiterungspunkt für Schnitt B; Klasse `SubmitFakeASC` (Unterklasse von `FakeASC`) im Test; Eingabe `aktion` und Block `concurrency` im neuen Workflow

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `get_one`, `current_build`, `count`, `failed` (`scripts/asc_store_version.py`) | Modul | Einzelobjekt (Bau, Review-Detail), Bau samt Vorabversion, Zähl-Abfrage mit `fehler HTTP <status>`; importiert, nicht kopiert; Datei bleibt unverändert |
| `app_versions`, `localizations`, `EDITABLE`, `PLATFORMS` (`scripts/asc_version_texts.py`) | Modul | Versionen der App, Lokalisierungen, Zustandswort `PREPARE_FOR_SUBMISSION`, Plattformen `IOS`, `MAC_OS`. `editable_version` wird bewusst nicht benutzt: es gibt Kennungen (`id=…`) aus; `pruefen` wählt die bearbeitbare Version selbst |
| `Masked`, `message` (`scripts/asc_beta_invite.py`) | Modul | stdout-Filter, der Kennungen in Pfaden und Abfragewerten maskiert; gilt auch für Wiederholungszeilen der geteilten Helfer |
| `Fatal`, `find_app_id`, `read_config` (`scripts/asc_wait_build.py`) | Modul | Fehlerklasse, App-Suche, Konfiguration aus der Umgebung |
| `get_data` (`scripts/asc_what_to_test.py`) | Modul | GET einer Liste (kein Schreibaufruf wird importiert oder benutzt) |
| `records`, `attributes` (`scripts/asc_beta_probe.py`) | Modul | Datensätze und Attribute aus Antworten |
| `FakeASC`, `version`, `build`, `loc` (`scripts/test_asc_store_version.py`) | Test-Modul | Nachbau mit Zustand; im neuen Test per Unterklasse um `reviewSubmissions` erweitert, die bestehende Testdatei bleibt unverändert |
| `GET /v1/reviewSubmissions?filter[app]=<id>&filter[platform]=<Plattform>&limit=50` | API | offene und frühere Einreichungen je Plattform; Zustand (`state`) und Plattform werden zusätzlich je Zeile geprüft, nicht dem Filter blind vertraut |
| Apple: Überblick Einreichen, Reviews-Submission-API (https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review, https://developer.apple.com/documentation/appstoreconnectapi/reviewsubmissioncreaterequest, https://developer.apple.com/forums/thread/802281), Recherche 2026-11-09 | Quelle | je Plattform eine eigene Einreichung; Zustände `ReviewSubmissionState`: `READY_FOR_REVIEW`, `WAITING_FOR_REVIEW`, `IN_REVIEW`, `UNRESOLVED_ISSUES`, `CANCELING`, `COMPLETING`, `COMPLETE`; je Plattform höchstens eine Einreichung mit App-Version in Prüfung |
| Store-Probe 2026-11-09, Lauf 42689844126 | Beleg | Ist-Stand: iOS und Mac 1.0.1 `PREPARE_FOR_SUBMISSION`, Bau 133 `VALID` und zugeordnet, de-DE und en-US mit Texten und Bildern, Review-Detail vorhanden |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_store_submit.py | CREATE | Aktion `pruefen`: Vorprüfung beider Plattformen, nur GET, Ausgabe je Plattform, Exitcode, Tabelle `ACTIONS` (ca. 190 LoC) |
| scripts/test_asc_store_submit.py | CREATE | `SubmitFakeASC` (Unterklasse von `FakeASC`) mit Einreichungen und Zuständen, eine Prüfung je AC (ca. 330 LoC) |
| .github/workflows/asc-store-submit.yml | CREATE | `pull_request` nur Tests, `workflow_dispatch` mit `aktion` (nur `pruefen`), eigene `concurrency`-Gruppe (ca. 40 LoC) |
| CLAUDE.md | MODIFY | eine Zeile im Build-Abschnitt nach der Zeile zu `asc-store-version.yml` (ca. +1 LoC) |

Nicht betroffen (geprüft): `scripts/asc_store_version.py` und `scripts/test_asc_store_version.py` (unverändert, einschließlich des Wächtertests „nie einreichen“), `scripts/asc_version_texts.py`, `scripts/asc_beta_invite.py`, Produktcode, `project.yml`, `ci.yml`.

### Estimated Changes
- Dateien: **4** (Grenze 4–5 eingehalten), dazu die Belege unter `docs/artifacts/feat-893-einreichen/`.
- LoC: ca. **+560** (Skript ca. 190, Tests ca. 330, Workflow ca. 40, CLAUDE.md 1). Ohne Tests liegt der Schnitt bei ca. 230 und damit unter der 250er-Grenze; die Tests liegen darüber, weil jede Regel der Vorprüfung und die Sicherheitsregeln (nur GET, keine Kennungen, keine Rohantwort) einzeln bewiesen werden, dasselbe Muster wie bei #842 5a-1. Der Auftrag ist bereits in zwei Schnitte geteilt. **Meldeschwelle: ca. 620 LoC**; nach dem RED-Schritt werden die Testzeilen gezählt; darüber wird vor dem Weiterbauen gefragt.
- Produktcode: keiner. Keine Berechtigung, keine `Info.plist`, kein Schema.
- „Kein Pfad der Geräteliste berührt.“

## Implementation Details

**1. Aufruf.** `asc_store_submit.py pruefen`. Der Eintritt ist eine Tabelle `ACTIONS = {"pruefen": pruefen}`; Schnitt B ergänzt einen Eintrag. Jede andere Eingabe, auch `einreichen`, endet mit `::error::Aufruf: asc_store_submit.py pruefen`, Ausgang 1, ohne Aufruf gegen Apple. Umgebung wie `asc_version_texts.py` (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_FILE`, `ASC_BUNDLE_ID`, `ASC_API_BASE`, `ASC_POLL_SECONDS`). Ausgabe läuft über `Masked`; es erscheinen nie Schlüssel, Token, Kennungen, Apples Rohantwort oder Store-Wortlaut (nur Zeichenzahlen und Zustandswörter).

**2. Nur GET.** Das Skript importiert `send_json` nicht und hat keinen Pfad für POST, PATCH oder DELETE. Ein Test macht den Nachbau so, dass jede Nicht-GET-Anfrage mit 405 scheitert und hält zusätzlich fest, dass keine solche Anfrage ankam.

**3. Je Plattform (`IOS`, `MAC_OS`) werden alle Prüfungen ausgewertet.** Jede Plattform wird vollständig bis zum Ende geprüft, auch wenn die andere schon Gründe hat. Ein Lesefehler (HTTP-Status, `Fatal`) einer Teilprüfung wird zu einem Grund dieser Plattform (`nicht lesbar HTTP <status>`), bricht den Lauf nicht ab und gibt nie Apples Rohantwort aus. Nur ein Fehler vor der Plattformschleife (Schlüssel, App nicht gefunden) ist `::error::` mit Ausgang 1.

Prüfungen je Plattform:
- **Version.** `app_versions` lesen; Versionen der Plattform im Zustand `PREPARE_FOR_SUBMISSION` zählen (`editable_for`, gibt nichts aus). Genau eine → weiter; keine oder mehrere → Grund mit Zahl und den vorhandenen Zuständen. Zusätzlich plattformübergreifend: `versionString` der bearbeitbaren iOS- und Mac-Version müssen gleich sein; sonst Grund bei beiden Plattformen mit beiden Nummern.
- **Bau.** `current_build`: Bau zugeordnet, `processingState` `VALID`, `expired` nicht wahr, Vorabversion gleich `versionString` der Version. Jede Abweichung ein eigener Grund (kein Bau, Zustand, abgelaufen, Vorabversion Soll/Ist).
- **Texte.** Lokalisierungen `de-DE` und `en-US` müssen existieren; je Locale `description`, `keywords`, `supportUrl`, `whatsNew` nicht leer (nach Entfernen von Leerraum); `promotionalText` ist optional und wird nur als Zeichenzahl genannt. Fehlt eine Locale oder ein Feld: Grund mit Locale und Feldname (nie Wortlaut).
- **Bilder.** Je Locale mindestens ein Bild: Summe der Bilder in den klassischen Bildsätzen (`count` über `appScreenshotSets`/`appScreenshots`) oder mindestens eine Bibliotheksplatzierung (`placements`, so liegen die Mac-Bilder seit 5b). Nichts davon → Grund je Locale; eine gescheiterte Zählung → `nicht lesbar`.
- **Review-Detail.** `get_one` auf `appStoreReviewDetail` mit `missing_ok_404`; keines → Grund.
- **Einreichungen der Plattform.** `GET /v1/reviewSubmissions?filter[app]=<id>&filter[platform]=<Plattform>&limit=50`; je Zeile wird die Plattform geprüft (andere Plattform wird ignoriert) und der Zustand bewertet:
  - `COMPLETE`: ignoriert (abgeschlossene Vergangenheit).
  - `READY_FOR_REVIEW`: genau eine → Hinweis `einreichung READY_FOR_REVIEW wiederverwendbar`, die Plattform bleibt bereit; mehr als eine → Grund (mehrdeutig, Schnitt B müsste raten).
  - `WAITING_FOR_REVIEW`, `IN_REVIEW`, `UNRESOLVED_ISSUES`, `CANCELING`, `COMPLETING`: Grund „belegt“ mit Zustandswort.
  - Jeder andere, auch fehlende Zustand: Grund „belegt, unbekannter Zustand <Wort>“ (fail-closed, damit Apple später ergänzte Zustände nie als frei gelten).

**4. Ausgabe und Exitcode.** Je Plattform eine Zeile `<Plattform> bereit` oder je Grund eine Zeile `<Plattform> nicht-bereit: <Grund>`, dazu Zeilen `<Plattform> hinweis: …` (wiederverwendbare Einreichung) und kurze Befundzeilen (Version, Bau, Zeichenzahlen je Locale und Feld, Bilder, Review-Detail ja/nein). Zuletzt `zusammenfassung bereit=<ios,mac|Teilmenge|keine> nicht-bereit=<Rest|keine>`. Ausgang **0 nur, wenn beide Plattformen bereit sind**; sonst Ausgang 1 mit einer `::error::`-Zeile `nicht bereit: <Plattformen>`. Begründung: Schnitt B soll nie an einer halb bereiten Lage starten (die Plattformen werden nicht atomar eingereicht, scheitert Mac nach iOS, steht iOS schon in Prüfung); ein Handlauf mit rotem Ergebnis sagt das eindeutig, die Gründe stehen im Protokoll.

**5. Workflow `asc-store-submit.yml`.** Auslöser `pull_request` (Pfade: Skript, Test, Workflow, `asc_store_version.py`, `asc_version_texts.py`, `asc_beta_invite.py`) führt nur die Tests aus; `workflow_dispatch` mit Eingabe `aktion` (choice, nur `pruefen`, Standard `pruefen`); `permissions: contents: read`; `concurrency: { group: asc-store-submit, cancel-in-progress: false }` (eigene Gruppe, nicht die von `asc-store-version`). Erster Schritt `python3 scripts/test_asc_store_submit.py`; zweiter Schritt (nur Handlauf) schreibt den Schlüssel nach `$RUNNER_TEMP` mit `umask 077` und `trap` zum Löschen und ruft `python3 scripts/asc_store_submit.py "$AKTION"`. Kopfkommentar nennt: Schnitt A liest nur, schreibt und reicht nichts ein.

**6. CLAUDE.md.** Eine Zeile im Build-Abschnitt nach der Zeile zu `asc-store-version.yml`: `gh workflow run asc-store-submit.yml -f aktion=pruefen` mit Kurzbeschreibung (nur GET, beide Plattformen, Ausgang 0 nur wenn beide bereit; Schnitt B ergänzt `einreichen`, #893). Die Zusage „nie einreichen“ der Zeile zu `asc-store-version.yml` bleibt wahr und unverändert.

**7. Ablauf am echten Konto (Nachweis, Teil der Definition of Done).** Nach dem Merge läuft `asc-store-submit.yml` mit `aktion=pruefen` per `workflow_dispatch` (der Workflow muss auf `main` liegen); das Protokoll belegt Apples Listenform der `reviewSubmissions` (Filter akzeptiert, Zustandswörter, Plattformfeld) und den Ist-Stand. Weicht die Form ab, wird das Skript korrigiert und der Lauf wiederholt, nie der Nachbau angepasst, um grün zu werden. Das ist ein Punkt der Definition of Done, kein AC, weil er erst nach dem Merge erfüllbar ist.

### Alternativen

| Weg | trägt? | Haken |
|---|---|---|
| **Eigenes Skript und Workflow, Schnitt A nur lesend (gewählt)** | ja | trennt den späteren nicht rücknehmbaren Weg vom Lese-/Anlegewerkzeug; echter Lesebeleg vor dem ersten Schreiben |
| A Erweiterung von `asc_store_version.py` um `pruefen`/`einreichen` | ja | weniger Dateien, kippt aber dessen „nie einreichen“-Zusage (Dateikopf, Workflow-Kommentar, CLAUDE.md) und den Wächtertest `test_never_deletes_submits_or_writes_texts`; verworfen |
| B Einreichen von Hand in App Store Connect, Werkzeug nur Prüfung und Gegenprobe | ja | reicht Arbeit an den Product Owner weiter (Regel: Werkzeug reparieren statt weiterreichen) und #893 verlangt das Werkzeug; verworfen |
| C Ein Schnitt statt zwei (Prüfen und Einreichen zusammen) | ja | ca. 420 LoC über dem Limit; außerdem fehlte der echte Lesebeleg vor dem ersten Schreiben; verworfen |

Gekippt wird keine ADR.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_store_submit.py` (`unittest`, ohne Netz). `SubmitFakeASC` erbt von `FakeASC` (lokaler HTTP-Server, `ASC_API_BASE` zeigt darauf) und ergänzt: Einreichungen je Plattform mit Zuständen, `GET /v1/reviewSubmissions` mit Auswertung von `filter[app]` und `filter[platform]`, Schalter für 405 auf jede Nicht-GET-Anfrage und für Lesefehler (403/500 mit Geheimwert im Rohtext). Fixtures: beide Plattformen vollständig bereit (Versionen 1.0.1 `PREPARE_FOR_SUBMISSION`, Bau 133 `VALID`, de-DE und en-US mit Texten und Bildern, Review-Detail), davon werden Abweichungen abgeleitet. RED: das Skript existiert noch nicht.

- [ ] `test_ready_on_both_platforms_exit_zero`: GIVEN beide Plattformen vollständig bereit WHEN `pruefen` läuft THEN je Plattform die Zeile „bereit“, Gesamtzeile `zusammenfassung bereit=ios,mac nicht-bereit=keine`, Ausgang 0.
- [ ] `test_version_rules`: GIVEN eine Plattform ohne bearbeitbare Version, bzw. mit zwei, bzw. iOS 1.0.1 und Mac 1.0.2 WHEN `pruefen` läuft THEN Ausgang 1 mit Grund (Zahl/Zustände bzw. beide Nummern, bei beiden Plattformen).
- [ ] `test_build_rules`: GIVEN kein Bau, Bau `PROCESSING`, abgelaufener Bau, Vorabversion 1.0 statt 1.0.1 WHEN `pruefen` läuft THEN je Fall ein eigener Grund und Ausgang 1.
- [ ] `test_text_rules`: GIVEN fehlende Locale en-US, leeres `whatsNew`, nur Leerraum in `description`, leeres `keywords`/`supportUrl`; und GIVEN fehlendes `promotionalText` WHEN `pruefen` läuft THEN Grund mit Locale und Feldname für die ersten Fälle, nie Wortlaut; fehlender Werbetext allein macht nicht unbereit.
- [ ] `test_image_and_review_detail_rules`: GIVEN eine Locale ohne Bildsatz und ohne Platzierung, eine mit nur Platzierungen (Mac), eine mit nur Bildsätzen, und eine Version ohne Review-Detail WHEN `pruefen` läuft THEN fehlende Bilder bzw. fehlendes Review-Detail sind Gründe; Platzierungen allein oder Bildsätze allein genügen.
- [ ] `test_submission_states`: GIVEN Einreichungen in den Zuständen WAITING_FOR_REVIEW, IN_REVIEW, UNRESOLVED_ISSUES, CANCELING, COMPLETING, ein unbekanntes Wort und ein fehlender Zustand WHEN `pruefen` läuft THEN je Fall Grund „belegt“ mit Zustandswort und Ausgang 1; GIVEN nur COMPLETE oder eine Einreichung der anderen Plattform THEN die Plattform ist bereit.
- [ ] `test_ready_for_review_is_reusable_but_two_are_not`: GIVEN genau eine READY_FOR_REVIEW-Einreichung WHEN `pruefen` läuft THEN Hinweis „wiederverwendbar“, Plattform bereit, Ausgang 0; GIVEN zwei THEN Grund „mehrdeutig“, Ausgang 1.
- [ ] `test_both_platforms_fully_evaluated`: GIVEN beide Plattformen mit je eigenen Gründen WHEN `pruefen` läuft THEN stehen die Gründe beider Plattformen im Protokoll, die Gesamtzeile nennt beide als nicht bereit und der Ausgang ist 1.
- [ ] `test_never_sends_non_get`: GIVEN ein Nachbau, der jede Nicht-GET-Anfrage mit 405 scheitern lässt WHEN `pruefen` mit bereitem und mit nicht bereitem Stand läuft THEN kam keine Nicht-GET-Anfrage an und das Ergebnis ist unverändert.
- [ ] `test_output_has_no_ids_raw_answers_or_wording`: GIVEN Lesefehler 403 und 500 mit Geheimwert im Rohtext, Texte mit Wortlaut-Marker, bekannte Kennungen im Nachbau WHEN `pruefen` läuft THEN enthält die Ausgabe weder Kennungen noch Geheimwert noch Wortlaut; der Lesefehler erscheint als Grund `nicht lesbar HTTP <status>` und die Auswertung der anderen Plattform läuft weiter.
- [ ] `test_bad_usage_makes_no_call`: GIVEN keine, unbekannte oder die Aktion `einreichen` WHEN das Skript startet THEN Ausgang 1 mit `::error::Aufruf: asc_store_submit.py pruefen` und ohne Anfrage.
- [ ] `test_workflow_offers_only_pruefen_and_hides_the_key`: GIVEN die Workflow-Datei THEN enthält `aktion` nur `pruefen`, `concurrency` hat die Gruppe `asc-store-submit` mit `cancel-in-progress: false`, die Python-Tests laufen als erster Schritt, der Handlaufschritt hängt an `workflow_dispatch`, der Schlüssel wird nie ausgegeben (Muster `WorkflowTests` in `test_asc_store_version.py`).
- [ ] `test_store_version_script_untouched`: GIVEN `scripts/asc_store_version.py` THEN enthält es weiterhin keinen Pfad mit `ubmission` und `scripts/test_asc_store_version.py` ist mit seinem Wächtertest unverändert grün (Lauf der bestehenden Testdatei als Unterprozess).

## Acceptance Criteria

- **AC-1:** Given beide Plattformen vollständig bereit, When `pruefen` läuft, Then meldet die Ausgabe je Plattform „bereit“, die Gesamtzeile `zusammenfassung bereit=ios,mac nicht-bereit=keine` und der Ausgang ist 0. Belegt durch `test_ready_on_both_platforms_exit_zero`.
- **AC-2:** Given eine Plattform hat keine, mehrere oder eine bearbeitbare Version mit anderer Nummer als die andere Plattform, When `pruefen` läuft, Then ist sie nicht bereit mit nennendem Grund (Zahl und Zustände bzw. beide Nummern) und der Ausgang ist 1. Belegt durch `test_version_rules`.
- **AC-3:** Given kein Bau, ein Bau nicht im Zustand `VALID`, ein abgelaufener Bau oder eine Vorabversion ungleich der Zielversion, When `pruefen` läuft, Then ist die Plattform nicht bereit mit je eigenem Grund. Belegt durch `test_build_rules`.
- **AC-4:** Given `de-DE` oder `en-US` fehlt, oder `description`, `keywords`, `supportUrl` oder `whatsNew` ist leer oder nur Leerraum, When `pruefen` läuft, Then ist die Plattform nicht bereit mit Locale und Feldname (nie Wortlaut); ein fehlender `promotionalText` allein macht sie nicht unbereit. Belegt durch `test_text_rules`.
- **AC-5:** Given eine Locale ohne Bild (weder Bildsatz mit Bildern noch Bibliotheksplatzierung) oder eine Version ohne Review-Detail, When `pruefen` läuft, Then ist die Plattform nicht bereit mit Grund; Bildsätze allein oder Platzierungen allein genügen. Belegt durch `test_image_and_review_detail_rules`.
- **AC-6:** Given Einreichungen der Plattform in WAITING_FOR_REVIEW, IN_REVIEW, UNRESOLVED_ISSUES, CANCELING, COMPLETING oder einem unbekannten oder fehlenden Zustand, When `pruefen` läuft, Then ist die Plattform nicht bereit („belegt“ mit Zustandswort); COMPLETE und Einreichungen der anderen Plattform werden ignoriert. Belegt durch `test_submission_states`.
- **AC-7:** Given genau eine Einreichung in READY_FOR_REVIEW, When `pruefen` läuft, Then bleibt die Plattform bereit und die Ausgabe nennt sie „wiederverwendbar“; bei mehr als einer ist die Plattform nicht bereit („mehrdeutig“). Belegt durch `test_ready_for_review_is_reusable_but_two_are_not`.
- **AC-8:** Given beide Plattformen haben Gründe, When `pruefen` läuft, Then werden beide vollständig ausgewertet und alle Gründe beider Plattformen stehen im Protokoll; die Gesamtzeile nennt beide als nicht bereit und der Ausgang ist 1. Belegt durch `test_both_platforms_fully_evaluated`.
- **AC-9:** Given jeder Lauf von `pruefen`, When die Anfragen am Nachbau geprüft werden, Then kam nie ein POST, PATCH oder DELETE an, und ein Nachbau, der jede Nicht-GET-Anfrage mit 405 scheitern lässt, ändert das Ergebnis nicht. Belegt durch `test_never_sends_non_get`.
- **AC-10:** Given Lesefehler (403, 500) mit Geheimwert in Apples Rohantwort, Kennungen im Nachbau und Store-Wortlaut, When `pruefen` läuft, Then enthält die Ausgabe weder Kennungen noch Rohantwort noch Wortlaut; der Lesefehler wird zum Grund `nicht lesbar HTTP <status>` der Plattform und die andere Plattform wird weiter ausgewertet. Belegt durch `test_output_has_no_ids_raw_answers_or_wording`.
- **AC-11:** Given keine, eine unbekannte oder die Aktion `einreichen`, When das Skript startet, Then endet es mit Ausgang 1 und `::error::Aufruf: asc_store_submit.py pruefen` ohne Anfrage gegen Apple. Belegt durch `test_bad_usage_makes_no_call`.
- **AC-12:** Given die Workflow-Datei, When sie geprüft wird, Then bietet `aktion` nur `pruefen`, `concurrency` nutzt die eigene Gruppe `asc-store-submit` ohne Abbruch laufender Läufe, die Python-Tests laufen als erster Schritt, der Handlaufschritt hängt an `workflow_dispatch`, und der Schlüssel wird nie ausgegeben. Belegt durch `test_workflow_offers_only_pruefen_and_hides_the_key`.
- **AC-13:** Given die Änderung, When der Diff und die Tests geprüft werden, Then sind `scripts/asc_store_version.py` und `scripts/test_asc_store_version.py` unverändert und dessen Tests (einschließlich „nie einreichen“) grün, die Zeile in `CLAUDE.md` steht nach der Zeile zu `asc-store-version.yml`, und der Diff berührt nur `scripts/`, `.github/workflows/`, `CLAUDE.md` und `docs/`; die Abnahme endet nach Stufe 2 mit dem Satz „Kein Pfad der Geräteliste berührt.“ Belegt durch `test_store_version_script_untouched`, die Dateiliste des Diffs gegen die Geräteliste und die Läufe von `python3 scripts/test_asc_store_submit.py`, `python3 scripts/test_asc_store_version.py` und `python3 scripts/test_asc_version_texts.py`.

**Abnahmeweg.** Stufe 1: Python-Tests (AC-1 bis AC-13). Stufe 2: der echte Werkzeuglauf `pruefen` gegen Apple nach dem Merge (siehe Definition of Done; kein AC, weil erst nach dem Merge erfüllbar). Stufe 3 greift nicht. Auf Hennings Geräten läuft nichts.

## Definition of Done

- [ ] Die Tests waren vor dem Skript vorhanden (RED) und sind danach grün; die übrigen Skript-Tests bleiben grün.
- [ ] Der Umfang blieb unter der Meldeschwelle von ca. 620 LoC, sonst wurde vor dem Weiterbauen gefragt.
- [ ] PR gemergt, CI grün.
- [ ] Nach dem Merge lief `asc-store-submit.yml` mit `aktion=pruefen` per `workflow_dispatch` gegen das echte Konto; Run-ID und zitierte Protokollzeilen stehen unter `docs/artifacts/feat-893-einreichen/`. Das Protokoll belegt Apples Listenform der `reviewSubmissions` (Filter `app` und `platform` akzeptiert, Zustandswörter, Plattformfeld) und den Ist-Stand je Plattform. Weicht die Form ab, ist das Skript korrigiert und der Lauf wiederholt, bevor Schnitt B beginnt.
- [ ] #893 kommentiert: Schnitt A erledigt mit dem Befund aus dem echten Lauf; offen Schnitt B (`einreichen`, eigene Spec und eigener Workflow).

## Seiteneffekte

- Geänderte Dateien: die vier oben; dazu die Belege unter `docs/artifacts/feat-893-einreichen/`.
- Bei Apple: nichts. Das Skript liest nur; es wird nichts angelegt, geändert, gelöscht oder eingereicht.
- Keine neuen Berechtigungen, keine `Info.plist`, keine `project.yml`-Änderung, keine AppStorage-Schlüssel, keine Audio-Dateien, keine neuen Dependencies, kein Produktcode.

## Risiken

- **Apples Formen nur aus der Dokumentation bekannt.** Filter der Liste (`filter[app]`, `filter[platform]`), Zustandswörter und Plattformfeld der `reviewSubmissions` sind aus Apples Doku und Foren erschlossen; der Nachbau beweist sie nicht. Gegenmaßnahme: der echte Lauf nach dem Merge (Definition of Done) vor Schnitt B; Auswertung je Zeile (Plattform, Zustand) statt blindem Vertrauen auf den Filter; unbekannter Zustand gilt als belegt (fail-closed).
- **Pflichtfelder der Vorprüfung sind eine Näherung.** Apple prüft beim Einreichen zusätzlich selbst (Exportangaben, Altersfreigabe, Datenschutz); `pruefen` kann nur das per API Lesbare belegen. „Bereit“ heißt: keine bekannte Voraussetzung fehlt, nicht: Apple nimmt an. Schnitt B behandelt Apples 409/422 beim Einreichen.
- **Paginierung.** Die Liste der Einreichungen wird mit `limit=50` gelesen; bei mehr könnte eine offene fehlen (heute wenige).
- **Gleichzeitige Läufe.** `concurrency` ohne Abbruch serialisiert sie.
- **Umfang.** Ca. 560 LoC, davon ca. 330 Tests; Meldeschwelle ca. 620.

## Known Limitations

- Schnitt A reicht nichts ein; `einreichen` fehlt absichtlich und wird abgelehnt.
- Eine bereite Prüfung ist eine Momentaufnahme; zwischen `pruefen` und `einreichen` kann sich der Stand ändern, Schnitt B prüft deshalb vor dem ersten Schreiben erneut.
- `whatsNew` wird als Pflicht behandelt, weil 1.0.1 eine Update-Version ist; für eine Erstversion wäre es nicht Pflicht (hier nicht relevant).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Betriebswerkzeug ohne Produktcode nach dem Muster der bestehenden ASC-Werkzeuge (`asc_store_version`, `asc_beta_invite`); es wird keine bestehende ADR gekippt (keine der Alternativen berührt eine ADR).
- **Rationale:** Die Trennung in ein eigenes Skript mit eigenem Workflow bewahrt die Zusage „nie einreichen“ von `asc_store_version.py` und isoliert den einzigen nicht rücknehmbaren Weg; ein reiner Lesebeleg vor dem Schreibweg setzt das Muster „erst GET, dann Schreiben, dann Gegenprobe“ fort. Das ist eine technische Frage ohne Produktauswirkung.

## Changelog

- 2026-11-09: Initial spec created (Schnitt A von #893: Skript `asc_store_submit.py` mit der Aktion `pruefen`, nur GET, Vorprüfung beider Plattformen mit Gründen, Exitcode 0 nur bei beiden bereit, eigener Workflow mit eigener Sperre; `einreichen` als Folgeschnitt B ausgeklammert)

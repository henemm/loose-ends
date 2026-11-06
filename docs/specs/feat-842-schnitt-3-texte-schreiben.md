---
entity_id: feat-842-schnitt-3-texte-schreiben
type: feature
created: 2026-11-06
updated: 2026-11-06
status: draft
workflow: feat-842-s3-texte-schreiben
---

# Spec: #842 Schnitt 3 — Englische Store-Texte per Handlauf nach App Store Connect schreiben

## Approval

- [ ] Approved

Mit dem getippten `approved` gibt Henning zugleich frei (oder ändert vorher) den Abschnitt **Wortlaut zur Freigabe** und bestätigt, dass die Änderung über der 250-Zeilen-Grenze liegt (siehe Scope, Schätzung).

## Purpose

Die englische Seite des App Store hat heute keine Texte: Der Datensatz der Version iOS 1.0.1 für Englisch (en-US) existiert bei Apple, ist aber vollständig leer (Beschreibung 0 Zeichen, Schlüsselwörter 0, keine Support-Adresse, Werbetext 0; Probelauf 42270571558 vom 2026-11-06). Ohne diese Texte kann 1.0.1 nicht eingereicht werden, weil Apple verlangt, dass Version und App-Informationen dieselben Sprachen führen. Schnitt 3 schreibt den englischen Wortlaut aus einer Textdatei im Repo in einem Handlauf nach App Store Connect und prüft danach bei Apple nach, dass er dort steht. Der deutsche Wortlaut wird nie angefasst, gesperrte (verkaufte) Versionen ebenfalls nicht, und es wird nichts eingereicht. Bilder sind Schnitt 4.

Für Henning ändert sich: Er liest den vorgeschlagenen englischen Wortlaut unten und gibt ihn frei oder ändert ihn; danach steht er im App Store, ohne dass er etwas eintippen oder einfügen muss.

Ohne Modell geht es nicht: nicht relevant, Betriebsskript gegen die ASC-API (Regeln vor Modell gilt trivial).

## Source

- **File:** `scripts/asc_version_texts.py` (neu), `docs/reference/app-store-texte.md` (neu)
- **Identifier:** `wanted_texts(text)`, `editable_version(versions, platform)`, `write_texts(config, version_id, wanted)`, `verify(...)`, `main(argv)`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `read_config`, `find_app_id`, `Fatal` (`scripts/asc_wait_build.py`) | module | Konfiguration, App-Kennung, Fehlerklasse |
| `send_json`, `get_data` (`scripts/asc_what_to_test.py`) | module | PATCH/POST mit Wiederholung bei 5xx/408/429, GET der Listen |
| `records`, `attributes` (`scripts/asc_beta_probe.py`) | module | Datensätze und Attribute lesen |
| `scripts/asc_app_info.py` | Vorbild | Aufbau (Abschnittsdatei, Prüfung vor der ersten Anfrage, `send` mit 403/409-Meldung, Gegenprobe); wird nicht verändert und nicht importiert (die Meldungen unterscheiden sich) |
| `.github/workflows/asc-app-info.yml` | Vorbild | Handlauf mit Eingabe `aktion` |
| ASC-API `GET /v1/apps/{id}/appStoreVersions` | extern | Attribute `platform` (`IOS`, `MAC_OS`), `versionString`, `appStoreState`; die Namen sind die, die `scripts/asc_store_probe.py` im echten Lauf liest (`appStoreState`, nicht `appVersionState`) |
| ASC-API `GET /v1/appStoreVersions/{id}/appStoreVersionLocalizations` | extern | Attribute `locale`, `description`, `keywords`, `supportUrl`, `promotionalText` |
| ASC-API `PATCH /v1/appStoreVersionLocalizations/{id}`, `POST /v1/appStoreVersionLocalizations` | extern | [Apple: App Store Version Localizations](https://developer.apple.com/documentation/appstoreconnectapi/app-store-version-localizations.md); POST mit Relationship `appStoreVersion` |
| ASC-Schlüssel mit Recht für Versionen | Secret | schrieb schon App-Info-Texte in #837; ein 403 zeigt es sofort |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| docs/reference/app-store-texte.md | CREATE | Wortlaut je Locale (zunächst nur `## en-US`), Inhalt zur Freigabe durch Henning |
| scripts/asc_version_texts.py | CREATE | Aktionen `lesen` und `texte` |
| scripts/test_asc_version_texts.py | CREATE | Tests mit Nachbau der API, nur echte Pfade und Formen |
| .github/workflows/asc-version-texts.yml | CREATE | Handlauf, Eingabe `aktion` (lesen, texte) |

### Estimated Changes
- Files: 4 (alle neu), keine bestehende Datei geändert
- LoC ehrlich geschätzt: Skript ca. 130, Tests ca. 150, Workflow ca. 35, zusammen **ca. 315 Code-Zeilen**; dazu die Textdatei mit ca. 70 Zeilen Inhalt (Wortlaut, kein Code, in dieser Summe nicht enthalten)
- **Über der 250-LoC-Grenze (ca. +65).** Entscheidung: keine Teilung. Ein Skript, das nur liest und prüft, ohne zu schreiben, beweist nichts (Lehre #136); ein Schreibskript ohne Tests und Workflow ist nicht lauffähig. Eine Teilung würde ein Zwischenergebnis ausliefern, das nichts bei Apple verändert. Die Freigabe (`approved`) bestätigt die Überschreitung ausdrücklich mit. Fällt die tatsächliche Summe aus Code, Tests und Workflow unter 250, entfällt der Hinweis ohne Folgen.
- Reine Betriebs-Tooling-Änderung, kein App-Code, kein Gerät.

## Implementation Details

**Textdatei `docs/reference/app-store-texte.md`.** Ein Abschnitt je Locale, Überschrift `## <Locale>` (zunächst `## en-US`). Eindeutig lesbar, damit der Parser nicht rät:

- Einzeilige Felder als Zeile `Feldname:` mit Wert nach dem ersten Doppelpunkt: `Schlüsselwörter:`, `Support-URL:`, `Werbetext:` (optional).
- Die mehrzeilige Beschreibung: Zeile `Beschreibung:`, direkt darunter eine Zeile mit drei Backticks, dann der Text, dann eine Zeile mit drei Backticks. Alles dazwischen ist die Beschreibung, nur Leerzeilen am Rand werden abgeschnitten. Fehlt der öffnende oder schließende Marker, ist die Datei ungültig.
- Text außerhalb der Abschnitte und Zeilen mit anderen Feldnamen werden ignoriert (Vorspann, Erklärung).

**1. Prüfung vor der ersten Anfrage (`wanted_texts`).** Die Datei wird gelesen und geprüft, bevor `read_config` oder eine Anfrage läuft (Pfad aus `VERSION_TEXTS_FILE`, Standard `docs/reference/app-store-texte.md`). Pflicht je Abschnitt: Beschreibung, Schlüsselwörter, Support-URL (nicht leer). Grenzen: Beschreibung höchstens 4000 Zeichen, Werbetext höchstens 170 Zeichen, Schlüsselwörter höchstens 100 **Bytes** (UTF-8), ohne Leerzeichen nach Kommas. Die Support-URL muss mit `https://` beginnen. Verstoß: Fatal mit Locale, Feld, Ist- und Soll-Zahl. Die Grenzen sind Vorprüfung aus Drittquellen; Apples eigene Doku nennt die Zahlen nicht, bei Überschreitung meldet Apple 409. Ein Abschnitt in der Datei ohne Pflichtfelder bricht ab (nicht stillschweigend überspringen). Eine Datei ohne jeden Abschnitt bricht ab.

**2. Versionswahl (`editable_version`).** `GET /v1/apps/{id}/appStoreVersions` (alle Versionen, `limit=50`). Je Plattform (`IOS`, `MAC_OS`) wird genau eine Version mit `appStoreState == PREPARE_FOR_SUBMISSION` gewählt, nie die erste beste und nie nach Versionsnummer:

- genau eine → diese;
- keine → Meldung `keine bearbeitbare Version <Plattform> (Zustände <Liste>), nichts geschrieben`, **kein Fehler**, Plattform wird übersprungen; gibt es auf keiner Plattform eine bearbeitbare Version, endet der Lauf mit Rückgabecode 0 und der Zusammenfassung `geschrieben=0`;
- mehrere → Fatal `mehrdeutig`, nichts geschrieben.

Stand 2026-11-06: iOS 1.0.1 ist bearbeitbar; iOS 1.0 und macOS 1.0 sind `READY_FOR_SALE` und werden damit nie berührt. Eine Mac-Version in Bearbeitung gibt es heute nicht, die Mac-Seite meldet „keine bearbeitbare Version“.

**3. Schreiben (`write_texts`).** Je gewählter Version werden die Lokalisierungen geholt (`{Locale: Datensatz}`). Angefasst werden nur Locales, die in der Textdatei stehen; deutsch (`de-DE`) steht nicht darin und wird nie geschrieben oder verglichen. Je Locale:

- Datensatz vorhanden und alle Felder gleich → `unverändert`, kein Aufruf;
- Datensatz vorhanden, Abweichung → `PATCH /v1/appStoreVersionLocalizations/{id}` mit `type`, `id` und **nur den abweichenden Feldern** unter `attributes`;
- Datensatz fehlt → `POST /v1/appStoreVersionLocalizations` mit `attributes` (`locale` plus alle Felder aus der Datei) und `relationships.appStoreVersion.data = {type: appStoreVersions, id}`.

Felder: `description`, `keywords`, `supportUrl` (Pflicht), `promotionalText` nur, wenn die Datei einen Werbetext enthält. Fehlt `Werbetext:` in der Datei, bleibt der Werbetext bei Apple unverändert (nicht leeren).

**4. Fehlermeldungen (`send`).** Wie `asc_app_info.send`: 403 → klare Meldung „Schlüssel ohne Recht oder Version gesperrt“, 409 → „Konflikt: Wert oder Zustand nicht zulässig“ mit den Fehlercodes (nicht dem Rohrumpf); Apples Rohantwort steht nie in der Ausgabe. Wiederholung bei 5xx/408/429 übernimmt `send_json`.

**5. Gegenprobe (`verify`).** Nach dem Schreiben werden die Lokalisierungen neu gelesen; jedes geschriebene Feld muss bei Apple exakt dem Wunschtext entsprechen, sonst Fatal `Gegenprobe: <Locale> weicht ab`. Bei Erfolg `gegenprobe gleich=ja`. Wurde nichts geschrieben, entfällt die Gegenprobe.

**6. Aktionen.** `lesen`: schreibt nie, druckt je Plattform die Versionen mit Zustand und für die bearbeitbare (falls vorhanden) je Locale die Zeichenzahlen und den Wortlaut (öffentlich) der Felder; braucht die Textdatei nicht. `texte`: wie oben. Eine unbekannte Aktion bricht vor der ersten Anfrage ab. Der Lauf endet mit `zusammenfassung geschrieben=<Zahl>`. Das Skript reicht nichts ein und ruft keinen anderen Schreibpfad als `/v1/appStoreVersionLocalizations` auf.

**7. Workflow `asc-version-texts.yml`.** Aufbau wie `asc-app-info.yml`: nur `workflow_dispatch`, Eingabe `aktion` (choice: `lesen`, `texte`, Standard `lesen`), `contents: read`, `timeout-minutes`, erst Unit-Tests (`python3 scripts/test_asc_version_texts.py`), dann das Skript; Schlüssel nur im Lauf (`umask 077`, `trap … rm -f`), Eingabe nur über `inputs.aktion`.

**Alternativen:**
- **A (gewählt):** neues Skript nach dem Muster `asc_app_info.py`, Wortlaut in einer Textdatei im Repo. Wiederholbar, mit Gegenprobe, ohne Handarbeit; App-Info (Untertitel) und Version (Beschreibung) haben verschiedene Zustände und Pfade und bleiben getrennt.
- **B:** `asc_app_info.py` um die Version erweitern. Weniger Dateien, aber vermischt zwei Zustandsmodelle; verworfen, außer eine gemeinsame Hilfsfunktion fällt heraus (bisher nicht: die Meldungen sind verschieden).
- **C:** Henning fügt die Texte in App Store Connect ein. Schneller beim ersten Mal, aber Handarbeit für ihn, ohne Beleg und nicht wiederholbar; verworfen.
- **D:** Deutsche Texte ins Repo holen und beide Sprachen aus einer Datei pflegen. Sinnvoll, weil der deutsche Wortlaut nur bei Apple liegt, erweitert aber den Schnitt und birgt die Gefahr, dass das Werkzeug Deutsch überschreibt. Als Folge-Ticket vorgeschlagen, nicht Teil dieses Schnitts; das Skript schreibt nur Locales aus der Datei.
- **E:** Werbetext weglassen. Pflicht ist er nicht, aber er lässt sich ohne neue Version ändern und kostet nichts; Empfehlung: setzen (im Entwurf enthalten, im Skript optional).

Keine ADR wird gekippt.

## Wortlaut zur Freigabe

Das ist der vorgeschlagene englische Wortlaut für die Seite der englischen App-Store-Version von 1.0.1. Er entspricht inhaltlich dem deutschen Text (gleiche Gliederung), nutzt aber die echten englischen Begriffe der englischen App (Now, New, Due, Quick, Old, Waiting, Parked, Completed; Tags wie „Garden“, „Computer“). Die Schlüsselwörter sind eigenständig gewählt, nicht übersetzt, und wiederholen keine Wörter aus Name und Untertitel (Loose Ends, Voice, Tasks, Say it, Clear your head). Henning gibt ihn mit `approved` frei oder nennt Änderungen; erst der freigegebene Text kommt in die Textdatei und damit zu Apple.

**Beschreibung** (1493 Zeichen, 1531 Bytes; Grenze 4000 Zeichen):

```
Say it in one sentence – Loose Ends takes care of the rest.

Tasks show up on the go: on a walk, at the checkout, while reading an email. Loose Ends captures them in a single sentence, without a form to fill in. The app then works out what is in your sentence and later shows you just what fits your situation right now.

CAPTURE IN ONE SENTENCE
• Type or dictate – in the app, on Apple Watch, with widgets, the Action button and Shortcuts
• Share sheet: turn text, links, emails, photos and files straight into a task
• Your original sentence is always kept unchanged

THE APP SORTS IT FOR YOU
• Due date, duration, importance and context are recognized from your sentence
• Fixed rules first, Apple Intelligence on your device only where language understanding is needed
• Learns from your choices: tag a sentence once, and it knows next time

YOU HAVE THE LAST WORD
• Every change is visible on the task
• Every field can be reset on its own

VIEWS THAT FIT THE MOMENT
• Now, New, Due, Quick, Old, Waiting, Parked, Completed
• By tag ("Garden", "Computer") and by project
• Repeating tasks and subtasks

REMINDS YOU AT THE RIGHT TIME – AND PLACE
• Notification on the due day with Complete, Next up, Tomorrow
• Reminder on arriving at a place (iPhone, iPad)
• Optionally add dates to your calendar

EVERYWHERE YOU ARE
• iPhone, iPad, Mac and Apple Watch
• Sync through your private iCloud

PRIVATE
Analysis runs on your device. Your tasks live in your iCloud, not on someone else's servers.
```

**Schlüsselwörter** (94 Zeichen, 94 Bytes; Grenze 100 Bytes):

`to-do,todo,reminders,dictation,list,GTD,context,notes,planner,inbox,watch,projects,due,capture`

**Werbetext** (125 Zeichen; Grenze 170; optional, Empfehlung: setzen):

`Say it in one sentence. Loose Ends recognizes date, duration and tag right on your device and later shows you just what fits.`

**Support-Adresse:** `https://www.henemm.com/footer-information/contact/` (dieselbe Seite wie deutsch; eine englische Kontaktseite gibt es nicht, `/en/footer-information/contact/` und `/en/contact/` liefern 404).

Hinweis zur Zählung: Die Zahlen sind mit `python3` am Entwurfstext nachgezählt (Zeichen als Python-Zeichen, Bytes als UTF-8). Bei der Beschreibung zählt für Apple die Zeichengrenze, bei den Schlüsselwörtern die Byte-Grenze.

## Test Plan

### Automated Tests (TDD RED)

`unittest`, lokaler HTTP-Nachbau mit veränderlichem Zustand wie in `scripts/test_asc_app_info.py`; Aufruf `python3 scripts/test_asc_version_texts.py`. Das Skript läuft als Unterprozess gegen den Nachbau (`ASC_API_BASE`), die Textdatei kommt über `VERSION_TEXTS_FILE`.

**Nachbau-Regel (Lehre #136 und Schnitt 2):** Der Nachbau bildet nur Apples echte Pfade und Formen ab, damit er den Fehler nicht mitbaut: `GET /v1/apps`, `GET /v1/apps/{id}/appStoreVersions` mit den Attributen `platform` (`IOS`/`MAC_OS`), `versionString`, `appStoreState` (die Namen aus `asc_store_probe.py`; `appVersionState` kommt im Nachbau nicht vor), `GET /v1/appStoreVersions/{id}/appStoreVersionLocalizations` mit den Attributen `locale`, `description`, `keywords`, `supportUrl`, `promotionalText`, sowie `PATCH /v1/appStoreVersionLocalizations/{id}` und `POST /v1/appStoreVersionLocalizations` (Relationship `appStoreVersion`). Jeder andere Pfad antwortet 404; der Nachbau merkt jede Anfrage.

In `scripts/test_asc_version_texts.py`:

- [ ] `test_invalid_text_file_aborts_before_any_request`: GIVEN Textdatei mit fehlendem Pflichtfeld (je eines von Beschreibung, Schlüsselwörter, Support-URL), Beschreibung mit 4001 Zeichen, Werbetext mit 171 Zeichen, Schlüsselwörtern mit 101 Bytes (aus Zwei-Byte-Zeichen, weniger als 100 Zeichen), Schlüsselwörtern mit Leerzeichen nach Komma, Support-URL ohne `https://`, fehlendem schließendem Marker oder ohne Abschnitt THEN Rückgabecode ungleich 0, `::error::` mit Locale/Feld/Zahl, `requests == []`.
- [ ] `test_text_file_parses_description_block_and_fields`: GIVEN Datei mit Vorspann, Beschreibung im Markerblock mit Leerzeilen und Sonderzeichen (Gedankenstrich, Punkt-Aufzählung) THEN Beschreibung exakt wie im Block (nur Randleerzeilen abgeschnitten), Schlüsselwörter, Support-URL und Werbetext korrekt, Vorspann ignoriert.
- [ ] `test_repo_text_file_parses_and_fits_limits`: GIVEN `docs/reference/app-store-texte.md` THEN `wanted_texts` liefert `en-US` mit allen Pflichtfeldern, Beschreibung ≤ 4000 Zeichen, Schlüsselwörter ≤ 100 Bytes ohne Leerzeichen nach Komma, Werbetext (falls gesetzt) ≤ 170, Support-URL mit `https://`, kein Abschnitt für `de-DE`.
- [ ] `test_selects_only_editable_version_per_platform`: GIVEN iOS 1.0 `READY_FOR_SALE`, iOS 1.0.1 `PREPARE_FOR_SUBMISSION`, macOS 1.0 `READY_FOR_SALE` THEN die Schreibaufrufe gehen ausschließlich auf die Lokalisierung von iOS 1.0.1; die Lokalisierungen der anderen Versionen werden nie gelesen oder geschrieben.
- [ ] `test_no_editable_version_prints_message_and_exits_zero`: GIVEN nur gesperrte Versionen THEN Rückgabecode 0, Meldung `keine bearbeitbare Version` mit den Zuständen, `zusammenfassung geschrieben=0`, keine Schreibaufrufe; GIVEN iOS bearbeitbar und Mac gesperrt THEN iOS wird geschrieben und die Mac-Plattform meldet `keine bearbeitbare Version MAC_OS`.
- [ ] `test_several_editable_versions_of_one_platform_abort`: GIVEN zwei iOS-Versionen `PREPARE_FOR_SUBMISSION` THEN Rückgabecode ungleich 0, `mehrdeutig`, keine Schreibaufrufe.
- [ ] `test_different_text_patches_once_with_changed_fields_only`: GIVEN en-US-Datensatz mit gleicher Beschreibung, aber anderen Schlüsselwörtern und leerer Support-URL THEN genau ein `PATCH /v1/appStoreVersionLocalizations/<id>` mit `type`, `id` und `attributes` nur aus `keywords` und `supportUrl`.
- [ ] `test_empty_en_us_record_gets_all_fields_by_patch`: GIVEN der Zustand von heute (en-US vorhanden, alle Felder leer) THEN genau ein PATCH mit `description`, `keywords`, `supportUrl`, `promotionalText`, danach `gegenprobe gleich=ja`.
- [ ] `test_missing_record_posts_with_locale_fields_and_relationship`: GIVEN bearbeitbare Version ohne en-US-Datensatz THEN genau ein `POST /v1/appStoreVersionLocalizations` mit `attributes.locale == en-US` plus allen Feldern und `relationships.appStoreVersion.data == {type: appStoreVersions, id: <Version>}`, danach Gegenprobe.
- [ ] `test_equal_values_write_nothing`: GIVEN alle Felder bei Apple gleich dem Wunschtext THEN keine Schreibaufrufe, `zusammenfassung geschrieben=0`, keine Gegenprobe-Zeile.
- [ ] `test_only_locales_from_file_are_touched`: GIVEN de-DE-Datensatz mit anderem Wortlaut neben en-US THEN de-DE bleibt unverändert, kein Schreibaufruf auf dessen Kennung.
- [ ] `test_promotional_text_is_optional`: GIVEN Datei ohne `Werbetext:` und bei Apple vorhandenem Werbetext THEN `promotionalText` kommt in keinem Schreibaufruf vor und bleibt bei Apple unverändert; GIVEN Datei mit Werbetext THEN er wird geschrieben.
- [ ] `test_verification_mismatch_is_error`: GIVEN der Nachbau ignoriert Schreibaufrufe (`ignore_writes`) THEN Rückgabecode ungleich 0 und `Gegenprobe`; genau ein Schreibaufruf.
- [ ] `test_403_and_409_give_clear_message`: GIVEN Schreibaufruf antwortet 403 bzw. 409 (mit Code) THEN `::error::` mit klarer Meldung (409 mit Fehlercode), Rohrumpf nicht in stdout/stderr, keine Zusammenfassung.
- [ ] `test_lesen_never_writes_and_prints_values`: GIVEN beliebiger Zustand, `lesen` THEN nur GET, Ausgabe mit Versionszuständen und Zeichenzahlen/Wortlaut der en-US-Felder, Rückgabecode 0, `zusammenfassung geschrieben=0`; eine kaputte Textdatei stört `lesen` nicht.
- [ ] `test_writes_only_localization_paths_and_submits_nothing`: GIVEN jeder schreibende Lauf THEN alle Nicht-GET-Anfragen gehen an `/v1/appStoreVersionLocalizations` (PATCH mit Kennung oder POST), keine an Einreichungs-, Versions- oder Bildpfade.
- [ ] `test_unknown_action_aborts_before_any_request`: GIVEN Aktion `einreichen` THEN Rückgabecode ungleich 0, `requests == []`.
- [ ] `test_output_has_no_secrets`: GIVEN Läufe mit Erfolg, 403, 409 und Gegenprobenfehler THEN die Ausgabe enthält weder Schlüsseltext noch Kopfzeilen des Schlüssels, `Bearer`, `eyJ` noch den Rohrumpf.
- [ ] `test_workflow_has_choice_unit_tests_and_secrets`: GIVEN `.github/workflows/asc-version-texts.yml` THEN nur `workflow_dispatch`, kein `push`/`schedule`/`workflow_run`/`pull_request`, Eingabe `aktion` als `choice` mit `lesen` und `texte`, `umask 077`, `trap`, `rm -f`, `timeout-minutes`, `contents: read`, die drei Secrets, Unit-Tests vor dem Skriptaufruf, `inputs.` nur als `inputs.aktion`.

## Acceptance Criteria

- **AC-1:** Given eine Textdatei mit fehlendem Pflichtfeld (Beschreibung, Schlüsselwörter, Support-URL), Beschreibung über 4000 Zeichen, Werbetext über 170 Zeichen, Schlüsselwörtern über 100 Bytes oder mit Leerzeichen nach Kommas, Support-URL ohne `https://` oder ungültigem Beschreibungsblock, When `texte` läuft, Then bricht der Lauf mit klarer Meldung (Locale, Feld, Zahl) ab, bevor die erste Anfrage hinausgeht. Belegt durch `test_invalid_text_file_aborts_before_any_request`.
- **AC-2:** Given eine gültige Textdatei mit mehrzeiliger Beschreibung, When sie gelesen wird, Then entspricht die Beschreibung exakt dem Markerblock und die Einzelfelder stimmen; die im Repo liegende Datei ist gültig, hält alle Grenzen ein und enthält keinen deutschen Abschnitt. Belegt durch `test_text_file_parses_description_block_and_fields`, `test_repo_text_file_parses_and_fits_limits`.
- **AC-3:** Given Versionen verschiedener Plattformen und Zustände, When `texte` läuft, Then wird je Plattform nur die eine Version im Zustand `PREPARE_FOR_SUBMISSION` gewählt (Attribute `platform`, `appStoreState`) und gesperrte Versionen werden nie gelesen oder geschrieben. Belegt durch `test_selects_only_editable_version_per_platform`.
- **AC-4:** Given eine Plattform ohne bearbeitbare Version, When `texte` läuft, Then meldet der Lauf `keine bearbeitbare Version <Plattform>` mit den Zuständen, schreibt dort nichts und endet ohne Fehler (Rückgabecode 0); gibt es auf keiner Plattform eine, steht `geschrieben=0`. Belegt durch `test_no_editable_version_prints_message_and_exits_zero`.
- **AC-5:** Given zwei bearbeitbare Versionen derselben Plattform, When `texte` läuft, Then bricht der Lauf mit `mehrdeutig` ab und schreibt nichts. Belegt durch `test_several_editable_versions_of_one_platform_abort`.
- **AC-6:** Given ein vorhandener Datensatz mit abweichenden Feldern, When `texte` läuft, Then geht genau ein `PATCH /v1/appStoreVersionLocalizations/{id}` mit nur den abweichenden Feldern hinaus, auch wenn alle Felder leer sind (heutiger Zustand von iOS 1.0.1 en-US). Belegt durch `test_different_text_patches_once_with_changed_fields_only`, `test_empty_en_us_record_gets_all_fields_by_patch`.
- **AC-7:** Given eine bearbeitbare Version ohne Datensatz für die Locale aus der Datei, When `texte` läuft, Then geht genau ein `POST /v1/appStoreVersionLocalizations` mit Locale, allen Feldern und der Relationship `appStoreVersion` auf diese Version hinaus. Belegt durch `test_missing_record_posts_with_locale_fields_and_relationship`.
- **AC-8:** Given alle Felder bei Apple gleich dem Wunschtext, When `texte` läuft, Then geht kein Schreibaufruf hinaus und es steht `geschrieben=0`. Belegt durch `test_equal_values_write_nothing`.
- **AC-9:** Given Datensätze weiterer Sprachen bei Apple (deutsch), When `texte` läuft, Then werden nur Locales aus der Textdatei angefasst; der deutsche Datensatz bleibt unverändert und nie Ziel eines Aufrufs. Belegt durch `test_only_locales_from_file_are_touched`.
- **AC-10:** Given eine Textdatei ohne Werbetext, When `texte` läuft, Then wird `promotionalText` weder geschrieben noch geleert; mit Werbetext in der Datei wird er geschrieben. Belegt durch `test_promotional_text_is_optional`.
- **AC-11:** Given geschriebene Felder, When Apple sie nach dem Schreiben nicht exakt zurückgibt, Then endet der Lauf mit Fehler `Gegenprobe`; bei Übereinstimmung steht `gegenprobe gleich=ja`. Belegt durch `test_verification_mismatch_is_error`, `test_empty_en_us_record_gets_all_fields_by_patch`.
- **AC-12:** Given Apple antwortet auf einen Schreibaufruf mit 403 oder 409, When `texte` läuft, Then endet der Lauf mit klarer Meldung (409 mit Fehlercode) ohne Apples Rohantwort. Belegt durch `test_403_and_409_give_clear_message`.
- **AC-13:** Given `lesen`, When der Lauf endet, Then wurde nichts geschrieben und die Ausgabe nennt Versionszustände sowie Zeichenzahlen und Wortlaut der Felder; eine kaputte Textdatei stört `lesen` nicht. Belegt durch `test_lesen_never_writes_and_prints_values`.
- **AC-14:** Given jeder schreibende Lauf, When er Anfragen sendet, Then gehen alle Schreibaufrufe nur an `/v1/appStoreVersionLocalizations` (nichts wird eingereicht), eine unbekannte Aktion bricht vor der ersten Anfrage ab, und die Ausgabe enthält keine Zugangsdaten. Belegt durch `test_writes_only_localization_paths_and_submits_nothing`, `test_unknown_action_aborts_before_any_request`, `test_output_has_no_secrets`.
- **AC-15:** Given der Handlauf-Workflow, When er geprüft wird, Then ist er nur manuell auslösbar mit der Auswahl `lesen`/`texte`, führt die Unit-Tests vor dem Skript aus und hält den Schlüssel nur im Lauf. Belegt durch `test_workflow_has_choice_unit_tests_and_secrets`.

**Nach dem Merge (Definition of Done, kein AC):** Handlauf `asc-version-texts.yml` mit `lesen` (Stand vorher: en-US leer), dann `texte`, dann `lesen` zur Gegenprobe; auf der Mac-Seite erscheint die Meldung „keine bearbeitbare Version“. Der echte Lauf belegt auch, ob Apple den PATCH-Umschlag und die Feldgrenzen annimmt, was der Nachbau nicht zeigen kann; das QA-Gate kann ihn nicht belegen, deshalb steht er hier und nicht bei den Acceptance Criteria.

**Abnahmeweg.** Kein Pfad der Geräteliste berührt. Stufe 1 (Tests) läuft vollständig. Stufe 2 entfällt mit Begründung: Die Änderung ist ein Betriebsskript gegen die ASC-API samt Textdatei und kein App-Code, also nichts, was ein Simulator zeigen könnte; der Beleg ist der echte Handlauf nach dem Merge. Der Abschlussbericht enthält den Satz „Kein Pfad der Geräteliste berührt.“ #842 bleibt bis Schnitt 4 (Bilder) und der Einreichung offen.

## Definition of Done

- [ ] Die neuen Tests waren vor der Umsetzung rot und sind danach grün; alle bestehenden Python-Tests der `asc_*`-Skripte bleiben grün.
- [ ] Der Diff berührt nur die vier genannten Dateien.
- [ ] Henning hat den Wortlaut freigegeben oder geändert; die Textdatei trägt genau den freigegebenen Text.
- [ ] Nach dem Merge: Handlauf `lesen` (vorher), `texte`, `lesen` (Gegenprobe) mit Link im Abschlussbericht; die englische Version von iOS 1.0.1 zeigt Beschreibung, Schlüsselwörter, Support-Adresse und Werbetext; Mac meldet „keine bearbeitbare Version“. Die Mac-Prüfung „nächste Mac-Version“ ist erst belegbar, wenn eine Mac-Version in Bearbeitung existiert, und wird in #842 als offen vermerkt.
- [ ] #842 kommentiert: Schnitt 3 erledigt, offen Schnitt 4 (Bilder) und die Einreichung von 1.0.1; Folge-Ticket für „deutsche Texte ins Repo holen“ angelegt oder bewusst verworfen.

## Seiteneffekte

- Schreibt bei Apple (nur im Handlauf `texte`, nie in Tests) Beschreibung, Schlüsselwörter, Support-URL und optional Werbetext der englischen Version von iOS 1.0.1; deutsche Texte, gesperrte Versionen und Einreichung bleiben unberührt.
- Keine neuen Berechtigungen, keine `Info.plist`, keine AppStorage-Schlüssel, keine Audio-Dateien, kein App-Code, keine neuen Secrets (vorhandene `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`), keine Abhängigkeit.
- Der öffentliche Wortlaut steht in der Ausgabe des Handlaufs (Store-Texte sind öffentlich), Schlüssel und Rohantworten nie.
- Neue Datei `docs/reference/app-store-texte.md` wird Quelle für künftige Store-Texte weiterer Sprachen.

## Risiken

- **Wortlaut ist ein Produktthema.** Das Skript schreibt erst, wenn die freigegebene Datei im Repo steht; der Entwurf geht deshalb mit dieser Spec zur Freigabe.
- **Grenzen aus Drittquellen.** 4000/170/100 Bytes sind nur Vorprüfung; lehnt Apple ab, meldet der Lauf den 409 mit Code, und die Grenze wird in der Datei nachgezogen.
- **Mehrere bearbeitbare Versionen später.** Das Skript bricht je Plattform bei Mehrdeutigkeit ab, statt zu raten.
- **Mac heute nicht prüfbar.** Es gibt keine Mac-Version in Bearbeitung; der Pfad „keine bearbeitbare Version“ ist durch Tests belegt, das Schreiben auf Mac erst, wenn es eine gibt (gleiche Funktion wie iOS).
- **Nachbau ist nicht Apple.** Ob Apple Umschlag und Feldwerte annimmt, zeigt nur der echte Handlauf (Definition of Done); der Nachbau bildet deshalb nur echte Pfade und Attributnamen ab.
- **Umfang über 250 LoC.** Siehe Scope; die Freigabe bestätigt die Überschreitung.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Betriebsskript nach dem Muster der bestehenden ASC-Skripte, kippt keine ADR.

## Changelog

- 2026-11-06: Initial spec created (Schnitt 3 von #842: englische Versions-Texte aus Textdatei per Handlauf nach App Store Connect, Wortlaut zur Freigabe, Handlauf nach dem Merge als Definition of Done, nicht als AC)

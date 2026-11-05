---
entity_id: feat-837-schnitt-2-schreibweg
type: feature
created: 2026-11-05
updated: 2026-11-05
status: draft
workflow: feat-837-s2-schreibweg
---

# Spec: #837 Schnitt 2 — Schreibweg für den App-Store-Untertitel (de-DE ändern, en-US anlegen)

## Approval

- [ ] Approved

## Purpose

Der App-Store-Untertitel soll de-DE „Einfach sagen. Kopf frei.“ (ersetzt „Gesagt. Sortiert.“) und en-US „Say it. Clear your head.“ mit dem Namen „Loose Ends“ lauten (Wortlaut von Henning am 2026-11-04 freigegeben). Dieser Schnitt baut den Weg dorthin: Der Wunschtext liegt im Repo, ein Skript setzt ihn in App Store Connect (ASC) über einen CI-Handlauf, und der Wert, den ASC danach zurückmeldet, ist der Beleg. Heute lässt sich nichts schreiben: Es gibt keine App-Info im Zustand `PREPARE_FOR_SUBMISSION`, weil macOS 1.0 in Prüfung ist und iOS und Mac sich die App-Informationen teilen (Store-Probe 2026-11-05). Der Weg bricht dann mit klarer Meldung ab und schreibt nichts; geschrieben wird erst, wenn Apple eine App-Info freigibt.

Ohne Modell geht es nicht: nicht relevant, Betriebsskript gegen die ASC-API (Regeln vor Modell gilt trivial).

## Source

- **File:** `scripts/asc_app_info.py` (neu)
- **Identifier:** `main()` mit den Aktionen `lesen` und `untertitel`; Bausteine aus `asc_wait_build.py` (`read_config`, `find_app_id`, `get_json`, `Fatal`), `asc_what_to_test.py` (`get_data`, `send_json`, `ATTEMPTS`), `asc_beta_probe.py` (`records`, `attributes`), `asc_locales.py`.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `scripts/asc_wait_build.py` (`read_config`, `find_app_id`, `get_json`, `Fatal`) | module | Zugang, App-Kennung, GET, Abbruchart |
| `scripts/asc_what_to_test.py` (`get_data`, `send_json`, `ATTEMPTS`) | module | GET mit Wiederholung, POST/PATCH |
| `scripts/asc_beta_probe.py` (`records`, `attributes`) | module | Datensätze und Attribute aus der Antwort |
| `scripts/asc_locales.py` | module | Sprachcodes de/en auf de-DE/en-US |
| `scripts/asc_review_notes.py`, `scripts/test_asc_review_notes.py`, `.github/workflows/asc-review-notes.yml` | Vorlage | Muster „Text im Repo, lesen/setzen, Gegenprobe“ |
| `docs/reference/beta-beschreibung.md` | Vorlage | Muster einer Repo-Datei mit je einem Abschnitt `## de-DE` / `## en-US` |
| ASC-API `GET /v1/apps/{id}/appInfos`, `GET /v1/appInfos/{id}/appInfoLocalizations` | extern | Zustand und vorhandene Sprachen |
| ASC-API `PATCH /v1/appInfoLocalizations/{id}`, `POST /v1/appInfoLocalizations` | extern | [Anlegen](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-appinfolocalizations), Ändern nur in editierbarem Zustand ([Forum](https://developer.apple.com/forums/thread/747116)) |
| CI-Geheimnisse der ASC-API (wie `asc-review-notes.yml`) | Betrieb | Anmeldung am Handlauf |
| Ende der Mac-Prüfung (Apple) | extern | Voraussetzung für den echten Schreiblauf |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| docs/reference/app-store-untertitel.md | CREATE | Wunschtext: Abschnitt `## de-DE` (Untertitel „Einfach sagen. Kopf frei.“) und `## en-US` (Name „Loose Ends“, Untertitel „Say it. Clear your head.“) |
| scripts/asc_app_info.py | CREATE | Aktionen `lesen` und `untertitel` (Details unten) |
| scripts/test_asc_app_info.py | CREATE | Tests gegen lokalen Nachbau-Server |
| .github/workflows/asc-app-info.yml | CREATE | Handlauf `aktion=lesen\|untertitel`, Tests vor dem Schreiben |

### Estimated Changes
- Files: 4 (alle neu)
- LoC: ca. +370/−0 (Skript ca. 110, Test ca. 210, Workflow ca. 37, Text ca. 15)
- **Ausnahme von der 250-LoC-Grenze:** vom PO freigegeben (Henning, 2026-11-05: Deutsch und Englisch in einem Schritt, keine Teilung). Der Überhang kommt aus den Tests (Sicherheitsfälle um das Schreiben), nicht aus dem Code.

## Implementation Details

**Wunschtext.** `docs/reference/app-store-untertitel.md` hat je Sprache einen Abschnitt `## de-DE` / `## en-US` (Muster `beta-beschreibung.md`). Der Abschnitt nennt Zeilen `Name:` (nur en-US nötig) und `Untertitel:`. Die Sprachen kommen aus `asc_locales`; ein Abschnitt für eine ausgelieferte Sprache fehlt → Abbruch vor jeder Anfrage.

**Grenze vor der ersten Anfrage.** Name und Untertitel dürfen höchstens 30 Zeichen haben (Apple-Grenze). Eine Überschreitung bricht ab, bevor die erste Anfrage geht (Muster `asc_review_notes`).

**Aktion `lesen`.** Nur GET. Je App-Info eine Zeile mit Nummer und Zustand, je Sprache Name und Untertitel (öffentlich, darf in der Ausgabe stehen). Schreibt nichts, Zusammenfassung `zusammenfassung geschrieben=0`.

**Aktion `untertitel`.**
1. Wunschtext lesen und Grenze prüfen.
2. Editierbare App-Info bestimmen: genau eine mit `state == PREPARE_FOR_SUBMISSION`. Keine → Abbruch „App-Informationen gesperrt (Zustände …)“ mit allen gefundenen Zuständen; mehrere → Abbruch „mehrdeutig“. Es wird nie „die erste“ genommen. In beiden Fällen ist nichts geschrieben.
3. Je Sprache aus dem Wunschtext: Lokalisierung der App-Info suchen.
   - vorhanden und Untertitel gleich → nichts tun;
   - vorhanden und abweichend → ein `PATCH /v1/appInfoLocalizations/{id}` mit Umschlag `{"data": {"type": "appInfoLocalizations", "id": …, "attributes": {"subtitle": …}}}`, nur `subtitle`;
   - fehlt (en-US) → ein `POST /v1/appInfoLocalizations` mit `attributes` `locale`, `name`, `subtitle` und `relationships.appInfo` auf die gewählte App-Info.
4. Gegenprobe: App-Info-Lokalisierungen neu lesen; weicht ein Wert vom Wunsch ab → Fehler (Exit ≠ 0).
5. 403 und 409 von Apple werden in eine klare Meldung übersetzt (Zustand gesperrt bzw. Konflikt), ohne Rohantwort mit Zugangsdaten.
6. Letzte Zeile: `zusammenfassung geschrieben=N` (Anzahl der PATCH/POST).

**Workflow.** `.github/workflows/asc-app-info.yml`: `workflow_dispatch` mit `aktion` (`lesen` oder `untertitel`); vor dem Schreiben läuft `python3 scripts/test_asc_app_info.py`; Geheimnisse wie `asc-review-notes.yml`. Schreibwege laufen nie lokal.

**Nicht Teil dieses Schnitts.** Apple verlangt für Version und App-Info dieselben Lokalisierungen ([Apple](https://developer.apple.com/documentation/appstoreconnectapi/app-info-localizations)). Eine englische Store-Seite für iOS 1.0.1 (Beschreibung, Schlüsselwörter, Support-URL, Bilder) gibt es nicht; sie ist **#842** und muss vor der Einreichung von 1.0.1 stehen. Schnitt 3 (Aussage in `CLAUDE.md`/`README.md`) folgt danach.

**Offene Prüfung des PATCH-Rumpfs.** Der Umschlag stützt sich auf Apples POST-Beispiel und Gemeinschafts-Implementierungen, nicht auf einen verifizierten PATCH-Lauf. Belegt erst der echte Lauf (AC-9).

**Alternative.** Kein Skript: Henning trägt Untertitel (und Name für en-US) einmal in der ASC-Weboberfläche ein. Das wäre ein Handgriff und sofort möglich, sobald die App-Info frei ist. Verworfen, weil es das Muster „Store-Text im Repo, Skript setzt ihn“ (#788, #760) kippt, der Text im Repo nicht mehr der Wahrheit entspräche und Henning keine Einstellungen einträgt. Eine zweite Alternative, nur de-DE jetzt und en-US später, wurde von Henning verworfen (ein Schritt).

Keine ADR wird gekippt.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_app_info.py` (`unittest`, lokaler HTTP-Nachbau wie in `test_asc_review_notes.py`, protokolliert Methode, Pfad und Rumpf jeder Anfrage; Aufruf `python3 scripts/test_asc_app_info.py`).

- [ ] `test_locked_appinfos_abort_with_zero_writes`: GIVEN zwei App-Infos (`READY_FOR_DISTRIBUTION`, `IN_REVIEW`) WHEN `untertitel` läuft THEN Abbruch mit „gesperrt“ und beiden Zuständen in der Meldung, 0 POST/PATCH.
- [ ] `test_several_editable_appinfos_abort`: GIVEN zwei App-Infos mit `PREPARE_FOR_SUBMISSION` THEN Abbruch „mehrdeutig“, 0 Schreibaufrufe.
- [ ] `test_equal_values_write_nothing`: GIVEN eine editierbare App-Info mit de-DE und en-US gleich dem Wunsch THEN 0 Schreibaufrufe, `zusammenfassung geschrieben=0`.
- [ ] `test_different_subtitle_patches_once_with_subtitle_only`: GIVEN de-DE „Gesagt. Sortiert.“ THEN genau 1 PATCH auf die Lokalisierung, Rumpf `attributes` enthält nur `subtitle`, `zusammenfassung geschrieben=1`.
- [ ] `test_missing_en_us_posts_once_with_locale_name_subtitle_and_appinfo`: GIVEN nur de-DE (gleich) vorhanden THEN genau 1 POST mit `locale=en-US`, `name=Loose Ends`, `subtitle`, `relationships.appInfo` auf die gewählte App-Info.
- [ ] `test_too_long_text_aborts_before_any_request`: GIVEN Wunschtext mit 31 Zeichen THEN Abbruch, der Nachbau hat 0 Anfragen gesehen.
- [ ] `test_missing_section_aborts_before_any_request`: GIVEN Textdatei ohne Abschnitt `## en-US` THEN Abbruch vor jeder Anfrage.
- [ ] `test_403_and_409_give_clear_message`: GIVEN der Nachbau antwortet auf PATCH mit 403 bzw. 409 THEN klare Meldung (gesperrt bzw. Konflikt), Exit ≠ 0, keine Rohantwort in der Ausgabe.
- [ ] `test_verification_mismatch_is_error`: GIVEN der Nachbau übernimmt den PATCH nicht (Gegenprobe liest den alten Wert) THEN Fehler.
- [ ] `test_lesen_never_writes_and_prints_values`: GIVEN beliebiger Stand THEN `lesen` sendet nur GET, nennt Zustand, Name und Untertitel je Sprache und endet mit `zusammenfassung geschrieben=0`.
- [ ] `test_output_has_no_secrets`: GIVEN ein Lauf mit Fehlerfall THEN die Ausgabe enthält weder Schlüsselinhalt noch Token.
- [ ] `test_repo_text_file_parses_and_fits_limit`: GIVEN die echte Datei `docs/reference/app-store-untertitel.md` THEN beide Abschnitte werden gelesen, jeder Name und Untertitel hat ≤ 30 Zeichen und entspricht dem freigegebenen Wortlaut.

## Acceptance Criteria

- **AC-1:** Given nur App-Infos ohne `PREPARE_FOR_SUBMISSION` (wie heute), When `untertitel` läuft, Then bricht der Lauf mit „App-Informationen gesperrt“ samt Zuständen ab und es gibt 0 Schreibaufrufe. Belegt durch `test_locked_appinfos_abort_with_zero_writes`.
- **AC-2:** Given mehr als eine App-Info im Zustand `PREPARE_FOR_SUBMISSION`, When `untertitel` läuft, Then Abbruch ohne Schreiben (es wird nie geraten, welche gemeint ist). Belegt durch `test_several_editable_appinfos_abort`.
- **AC-3:** Given Name und Untertitel in ASC schon gleich dem Wunsch, When `untertitel` läuft, Then wird nichts geschrieben und die Ausgabe endet mit `zusammenfassung geschrieben=0`. Belegt durch `test_equal_values_write_nothing`.
- **AC-4:** Given de-DE hat einen abweichenden Untertitel, When `untertitel` läuft, Then geht genau ein PATCH hinaus, der nur `subtitle` trägt. Belegt durch `test_different_subtitle_patches_once_with_subtitle_only`.
- **AC-5:** Given en-US fehlt an der App-Info, When `untertitel` läuft, Then geht genau ein POST mit `locale`, `name`, `subtitle` und `relationships.appInfo` hinaus. Belegt durch `test_missing_en_us_posts_once_with_locale_name_subtitle_and_appinfo`.
- **AC-6:** Given Name oder Untertitel länger als 30 Zeichen oder ein fehlender Sprachabschnitt, When `untertitel` läuft, Then bricht der Lauf ab, bevor die erste Anfrage hinausgeht. Belegt durch `test_too_long_text_aborts_before_any_request`, `test_missing_section_aborts_before_any_request`.
- **AC-7:** Given Apple antwortet mit 403 oder 409, oder die Gegenprobe zeigt einen abweichenden Wert, When `untertitel` läuft, Then endet der Lauf mit klarer Meldung und Exit ≠ 0; nie bleibt ein stiller Erfolg. Belegt durch `test_403_and_409_give_clear_message`, `test_verification_mismatch_is_error`.
- **AC-8:** Given die Aktion `lesen` und jeder Fehlerfall, When der Lauf Ausgabe erzeugt, Then wird nur gelesen, Zustand, Name und Untertitel stehen sichtbar und Zugangsdaten nie. Belegt durch `test_lesen_never_writes_and_prints_values`, `test_output_has_no_secrets`, `test_repo_text_file_parses_and_fits_limit`.
- **AC-9:** (offen, später zu belegen) Given die Mac-Prüfung von macOS 1.0 ist beendet und genau eine App-Info steht auf `PREPARE_FOR_SUBMISSION`, When der Handlauf `asc-app-info` mit `aktion=untertitel` läuft, Then meldet ASC danach in der Gegenprobe de-DE „Einfach sagen. Kopf frei.“ und en-US „Say it. Clear your head.“ mit Name „Loose Ends“ (Lauf-Link, Wert aus ASC; das belegt zugleich den PATCH-Rumpf). **Heute** bricht derselbe Lauf mit „gesperrt“ ab; dieser Abbruchlauf (`aktion=untertitel` nach dem Merge, 0 geschrieben, Zustände im Protokoll) ist der heutige Beleg für den Abbruchzweig, nicht für das Schreiben. Der Schreibbeleg bleibt offen und wird später in #837 nachgetragen.

**Abnahmeweg.** Kein Pfad der Geräteliste berührt. Es wird kein App-Code geändert; Stufe 2 im Simulator entfällt sinngemäß. Heutiger Beleg: grüne Skript-Tests (AC-1 bis AC-8) und der Abbruchlauf nach dem Merge. Der Schreibbeleg (AC-9) hängt am Ende der Mac-Prüfung bei Apple; Henning hat entschieden zu warten und die Mac-Prüfung nicht zurückzuziehen. Bis AC-9 belegt ist, bleibt #837 offen; Schnitt 3 und #842 folgen als eigene Aufgaben.

## Definition of Done

- [ ] Die Tests in `scripts/test_asc_app_info.py` waren vor der Umsetzung rot und sind danach grün; die bestehenden Python-Tests der `asc_*`-Skripte bleiben grün.
- [ ] Der Diff berührt nur die vier genannten Dateien.
- [ ] Der Handlauf `aktion=lesen` und `aktion=untertitel` nach dem Merge liegt als Link im Abschlussbericht (heute: Abbruch „gesperrt“, 0 geschrieben).
- [ ] AC-9 ist als offener Punkt in #837 vermerkt, mit dem genauen Schritt (Lauf `aktion=untertitel`, sobald eine App-Info `PREPARE_FOR_SUBMISSION` zeigt; zu prüfen per `aktion=lesen`).

## Seiteneffekte

- Schreibt erst, wenn genau eine App-Info editierbar ist; sonst nichts in ASC verändert. Der Weg ändert nur Untertitel (und Name bei neuem en-US), keine anderen Felder.
- Eine neue en-US-App-Info zieht eine englische Versions-Lokalisierung nach sich (Apple); sie fehlt noch (#842) und blockiert sonst die Einreichung von iOS 1.0.1. Darum erst schreiben, wenn #842 absehbar ist, oder bewusst vorher, mit dem Wissen um diese Folge.
- Keine neuen Berechtigungen, keine `Info.plist`, keine AppStorage-Schlüssel, keine Audio-Dateien, kein App-Code, keine neuen Geheimnisse, keine Abhängigkeit.
- Untertitel und Name sind öffentlich und dürfen in der Ausgabe stehen; sonst nur Zustände.

## Risiken

- **PATCH-Rumpf unbelegt:** erst der echte Lauf (AC-9) bestätigt ihn. Lehnt Apple den Umschlag ab, ist die Meldung klar (AC-7) und der Rumpf wird nachgezogen.
- **Mac-Prüfung dauert:** Der Schreibweg liegt bis dahin ungenutzt, kostet aber nichts und bricht sicher ab.
- **Auswahl der App-Info:** gelöst über den Zustand, nie über die Reihenfolge; bei Mehrdeutigkeit Abbruch.
- **Scoping:** ca. 370 LoC über der 250-Grenze, durch den PO freigegeben.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Betriebsskript nach dem Muster der bestehenden ASC-Schreibwege (`asc_review_notes`, `asc_what_to_test`), kippt keine ADR.

## Changelog

- 2026-11-05: Initial spec created (Schnitt 2 von 3; Schnitt 1 = Befund, gemergt PR #840; Schnitt 3 = Wortlaut in `CLAUDE.md`/`README.md`)

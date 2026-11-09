---
entity_id: feat-842-schnitt-5a-2-texte
type: feature
created: 2026-11-09
updated: 2026-11-09
status: draft
workflow: feat-842-s5a2-texte
---

# Spec: #842 Schnitt 5a-2 — Texte der Versionen 1.0.1 (iOS und Mac) setzen: Mac en-US, deutscher Werbetext, „Neu in dieser Version“

## Approval

- [ ] Approved

Auftrag von Henning am 2026-11-09 (Auswahl „Ja, zusammen“, Schnitt 5a-1): iPhone und Mac bekommen Version 1.0.1 zusammen; die Arbeit geht bis vor das Einreichen. Diese Spec deckt nur 5a-2 ab. Die Versionen sind nicht eingereicht, also nicht öffentlich. **Die beiden „Neu in dieser Version“-Texte unten (Abschnitt Implementation Details, Punkt 4) sind Produkttext und werden mit `approved` freigegeben; zu ändern sind sie bis dahin in dieser Spec.** `approved` gibt die Umsetzung frei.

## Purpose

Der Lauf `lesen` vom 2026-11-09 (Schnitt 5a-1) zeigt, was in den beiden Versionen 1.0.1 noch fehlt:

| Version | Sprache | Werbetext | Neu in dieser Version | sonst |
|---|---|---|---|---|
| iOS 1.0.1 | de-DE | **fehlt** | **fehlt** | Beschreibung, Schlüsselwörter, Support-URL vorhanden |
| iOS 1.0.1 | en-US | vorhanden | **fehlt** | alles andere vorhanden |
| Mac 1.0.1 | de-DE | **fehlt** | **fehlt** | Beschreibung, Schlüsselwörter, Support-URL vorhanden |
| Mac 1.0.1 | en-US | **Sprache fehlt ganz** | | |

Ohne diese Texte ist keine der beiden Versionen einreichbar (Apple verlangt „Neu in dieser Version“ für ein Update) und die Mac-Seite hätte keine englische Fassung.

Schnitt 5a-2 erweitert das bestehende Schreibwerkzeug `scripts/asc_version_texts.py` um drei Dinge:

1. **Feld „Neu in dieser Version“ (`whatsNew`)**, mit der Zeile `Neu in dieser Version:` im Textabschnitt, Grenze 4000 Zeichen, in den Gegenproben und der Ausgabe.
2. **Abschnitt ohne Pflichtfelder für eine Sprache, die es bei Apple schon gibt.** Ein `## de-DE`-Abschnitt darf nur Werbetext und „Neu in dieser Version“ tragen; Beschreibung, Schlüsselwörter und Support-URL bleiben dann unangetastet bei Apple (kein Wortlaut im Repo, nichts wird überschrieben). Fehlt die Sprache bei Apple, verlangt das Werkzeug weiterhin alle drei Pflichtfelder (Mac en-US).
3. **`lesen` zeigt zusätzlich die zuletzt veröffentlichte Version** (Zustand `READY_FOR_SALE`, nur GET), damit der deutsche Werbetext von 1.0 unverändert ins Repo übernommen werden kann. Er steht heute nirgends im Repo, nur bei Apple in der unsichtbaren Version 1.0.

Danach schreibt der Handlauf `texte` (Workflow `asc-version-texts.yml`, unverändert) alles in beide bearbeitbaren Versionen, nur bei Abweichung, mit Gegenprobe im selben Lauf; ein Lauf `lesen` belegt den Endstand.

Für Henning ändert sich: Nichts Sichtbares. Bei Apple liegen danach beide Versionen 1.0.1 mit vollständigen deutschen und englischen Texten, nicht eingereicht. Er entscheidet nur über den Wortlaut der „Neu in dieser Version“-Texte (mit `approved`) und später über die Einreichung.

Nicht in diesem Schnitt:

- **5b:** Mac-Bilder en-US (Bibliothek, Platzieren).
- **Einreichen, Löschen**, Review-Detail (existiert bei beiden Versionen), Beschreibungen, Schlüsselwörter und Support-URL der deutschen Sprache.
- **Produktcode:** keiner.

Ohne Modell geht es nicht: nicht relevant. Betriebsskript gegen die ASC-API, Regelweg.

## Source

- **File:** `scripts/asc_version_texts.py` (ändern), `scripts/test_asc_version_texts.py` (ändern), `docs/reference/app-store-texte.md` (ändern); gelesen: `.github/workflows/asc-version-texts.yml` (unverändert), `scripts/asc_store_version.py` (`lesen` belegt den Endstand)
- **Identifier:** `LINE_FIELDS`, `LABELS`, `check_section`, `wanted_texts`, `write_texts`, `write_locale`, `read_state` in `asc_version_texts.py`; Abschnitte `## de-DE` und `Neu in dieser Version:` in der Textdatei

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `parse_sections`, `check_section`, `wanted_texts`, `write_locale`, `write_texts`, `verify`, `read_state` (`scripts/asc_version_texts.py`) | Modul | werden erweitert, nicht kopiert |
| `Fatal`, `find_app_id`, `read_config` (`scripts/asc_wait_build.py`), `get_data`, `send_json` (`scripts/asc_what_to_test.py`), `records`, `attributes` (`scripts/asc_beta_probe.py`) | Modul | wie bisher |
| `PATCH /v1/appStoreVersionLocalizations/{id}`, `POST /v1/appStoreVersionLocalizations` | API | Schreibwege existieren (Schnitt 3); `whatsNew` ist ein Attribut derselben Lokalisierung (Apple: AppStoreVersionLocalization, https://developer.apple.com/documentation/appstoreconnectapi/appstoreversionlocalization) |
| Runway-Artikel (https://www.runway.team/blog/apply-promotional-text-and-whats-new-notes-to-new-versions-in-swift-using-the-app-store-connect-api) | Quelle | `promotionalText` und `whatsNew` werden pro Version und Sprache per `PATCH` gesetzt; `whatsNew` gilt nur für Updates |
| Lauf `lesen` 2026-11-09 10:52Z (`docs/artifacts/feat-842-s5-mac-version/run-42604409575-lesen2.log`) | Beleg | Ist-Stand der vier Lokalisierungen (Tabelle oben) |
| `docs/reference/app-store-texte.md` Abschnitt `## en-US` | Quelle | fertiger englischer Wortlaut für die Mac-Sprache en-US |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_version_texts.py | MODIFY | Feld `whatsNew`; Pflichtfelder nur bei Abschnitt mit `Beschreibung:` oder fehlender Sprache bei Apple; `lesen` zeigt veröffentlichte Version (ca. +45/−10 LoC) |
| scripts/test_asc_version_texts.py | MODIFY | Tests je AC (ca. +130 LoC) |
| docs/reference/app-store-texte.md | MODIFY | `Neu in dieser Version:` in `## en-US`, neuer Abschnitt `## de-DE` (Werbetext, Neu-Text), Kopfsatz angepasst (ca. +14 LoC) |

Nicht betroffen (geprüft): `.github/workflows/asc-version-texts.yml` (Aktionen `lesen`/`texte` bleiben), `scripts/asc_store_version.py`, `scripts/asc_review_notes.py`, Bilder, Produktcode, `project.yml`, `CLAUDE.md`.

### Estimated Changes
- Dateien: **3** (Grenze 4–5 eingehalten), dazu die Belege unter `docs/artifacts/feat-842-s5a2-texte/`.
- LoC: ca. **+190** (Skript ca. 55, Tests ca. 130, Text ca. 14, abzüglich ersetzter Zeilen), unter der 250er-Grenze. Nach dem RED-Schritt werden die Testzeilen gezählt; reißt die Hochrechnung 250, wird vor dem Weiterbauen gefragt.
- Produktcode: keiner. Keine Berechtigung, keine `Info.plist`, kein Schema.
- „Kein Pfad der Geräteliste berührt.“

## Implementation Details

**1. Feld `whatsNew`.** `LINE_FIELDS` bekommt `"Neu in dieser Version": "whatsNew"`, `LABELS` bekommt `"whatsNew": "Neu in dieser Version"`. Die Zeile steht im Abschnitt wie `Werbetext:` (eine Zeile, Rest nach dem ersten Doppelpunkt). Grenze: 4000 Zeichen (`check_section`, Meldung wie bei den anderen Grenzen: Locale, Feld, Ist- und Soll-Zahl). `lesen` gibt es mit Zeichenzahl und Wortlaut aus (wie die anderen Felder, durch `LABELS`).

**2. Pflichtfelder.** `check_section` verlangt `description`, `keywords`, `supportUrl` nur, wenn der Abschnitt eine `Beschreibung:` enthält. Ein Abschnitt ohne Beschreibung muss mindestens eines von `promotionalText`, `whatsNew` tragen und darf `keywords`/`supportUrl` nicht tragen (sonst Fehler „<Locale>: Schlüsselwörter/Support-URL ohne Beschreibung“, damit ein halber Abschnitt nicht still etwas überschreibt). Die Grenz- und Formatprüfungen (4000/170 Zeichen, 100 Bytes, `https://`) laufen für jedes vorhandene Feld.
`write_texts` prüft vor dem ersten Schreibaufruf je Version: Ein Abschnitt ohne Beschreibung, dessen Sprache bei Apple in dieser Version nicht existiert, wirft `Fatal` („<Locale> fehlt bei Apple, Abschnitt braucht Beschreibung, Schlüsselwörter, Support-URL“), nichts geschrieben.

**3. `lesen` zeigt die veröffentlichte Version.** Für jede Plattform die Version im Zustand `READY_FOR_SALE` (falls vorhanden): je Locale Werbetext mit Zeichenzahl und Wortlaut, Zeilen mit Präfix `veröffentlicht <Plattform> <Versionsnummer> <Locale> Werbetext zeichen=N: …`. Nur GET, nie ein Schreibaufruf.

**4. Wortlaut.**

- `## de-DE` (neu): `Werbetext:` = der Werbetext der veröffentlichten Version 1.0, **unverändert** aus dem `lesen`-Lauf übernommen (iOS und Mac sind bei 1.0 gleich; weichen sie ab, gilt der iOS-Text und der Befund steht im Beleg). Ist er leer, länger als 170 Zeichen oder nicht lesbar, bricht die Umsetzung an dieser Stelle ab und fragt Henning, statt einen Text zu erfinden.
- `Neu in dieser Version:` de-DE (Entwurf zur Freigabe): *Loose Ends gibt es jetzt auch auf Englisch: die App und die Store-Seite. Dazu kleine Verbesserungen und Korrekturen.*
- `Neu in dieser Version:` en-US (Entwurf zur Freigabe): *Loose Ends now also speaks English: the app and this store page. Plus small improvements and fixes.*
- `## en-US` bleibt sonst wie es ist; sein Wortlaut geht auch auf die Mac-Sprache en-US (die Beschreibung nennt „Reminder on arriving at a place (iPhone, iPad)“: stimmt für den Mac, kein eigener Mac-Text).
- Der Kopfsatz der Textdatei („Der deutsche Wortlaut liegt nur bei Apple …“) wird ersetzt durch: Beschreibung, Schlüsselwörter und Support-URL der deutschen Sprache liegen nur bei Apple; im Repo steht für `de-DE` nur, was dieses Werkzeug dort setzt (Werbetext, Neu in dieser Version).

**5. Ablauf am echten Konto (Nachweis vor dem Merge).** Vom Zweig aus (`gh workflow run asc-version-texts.yml --ref <zweig>`), Protokolle unter `docs/artifacts/feat-842-s5a2-texte/`: (a) `aktion=lesen` vorher (liefert den deutschen Werbetext von 1.0), (b) `aktion=texte`, (c) `aktion=texte` ein zweites Mal (Idempotenz: alles „unverändert“, keine Schreibaufrufe), (d) `aktion=lesen` nachher und `asc-store-version.yml` mit `aktion=lesen` (Zeichenzahlen je Feld, vier Lokalisierungen vollständig). Erst danach Merge. Scheitert der Lauf vom Zweig, gilt der Rückfall wie in 5a-1 (REST-Aufruf `dispatches` mit `ref`); ein Aufschub der Belege auf die Zeit nach dem Merge ist ausgeschlossen.

### Alternativen

| Weg | trägt? | Haken |
|---|---|---|
| **Gelockerte Pflichtfelder, deutscher Abschnitt nur mit Werbetext/Neu-Text (gewählt)** | ja | nichts wird überschrieben, was nur bei Apple liegt; das Repo trägt nur, was das Werkzeug setzt |
| A de-DE vollständig ins Repo (Beschreibung, Schlüsselwörter, Support-URL aus Apple lesen und einchecken) | ja | ein Wahrheitsort, aber ca. 1600 Zeichen Kopie und das Risiko, dass eine veraltete Kopie Apples Text überschreibt; verwirft die Zeile „Der deutsche Wortlaut liegt nur bei Apple“. Keine ADR fällt |
| B Werbetext und Neu-Text von Hand in App Store Connect eintragen | nein | ausgeschlossen: nie Handarbeit für Henning, nicht wiederholbar, nicht gegengeprüft |
| C Eigenes Skript nur für `whatsNew` | ja | doppelter Schreibweg zu `asc_version_texts.py`; verworfen |

Gekippt wird keine ADR.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_version_texts.py` (`unittest`, ohne Netz; bestehender nachgebauter ASC-Dienst `FakeASC` mit lokalem HTTP-Server, `ASC_API_BASE` zeigt darauf; wird um Lokalisierungen einer `READY_FOR_SALE`-Version erweitert). RED: die neuen Prüfungen scheitern, weil `whatsNew`, der gelockerte Abschnitt und die Ausgabe der veröffentlichten Version fehlen.

- [ ] `test_whats_new_line_is_parsed_and_limited`: GIVEN Abschnitt mit `Neu in dieser Version:` WHEN die Datei gelesen wird THEN steht der Wert als `whatsNew` im Abschnitt; GIVEN 4001 Zeichen THEN `Fatal` mit Locale, Feld, Ist- und Soll-Zahl.
- [ ] `test_section_without_description_may_carry_only_promo_and_whats_new`: GIVEN `## de-DE` nur mit `Werbetext:` und `Neu in dieser Version:` WHEN die Datei geprüft wird THEN kein Fehler; GIVEN `## de-DE` ohne Beschreibung, aber mit `Schlüsselwörter:` bzw. `Support-URL:`, oder ganz leer THEN `Fatal` mit Locale und Grund, vor jeder Anfrage.
- [ ] `test_section_with_description_still_requires_all_three`: GIVEN Abschnitt mit `Beschreibung:` aber ohne Schlüsselwörter bzw. Support-URL THEN `Fatal` wie bisher.
- [ ] `test_section_without_description_for_missing_locale_is_fatal_and_writes_nothing`: GIVEN `## de-DE` ohne Beschreibung, bei Apple existiert die Sprache in der Version nicht THEN `Fatal` mit Locale, und die Anfragen enthalten kein Nicht-GET.
- [ ] `test_de_section_patches_only_promo_and_whats_new`: GIVEN bearbeitbare Versionen iOS und Mac mit de-DE-Lokalisierung (Beschreibung vorhanden) WHEN `texte` mit `## de-DE` (Werbetext, Neu-Text) läuft THEN je Plattform genau ein PATCH, dessen Attribute nur `promotionalText` und `whatsNew` enthalten (nie `description`, `keywords`, `supportUrl`), und die Gegenprobe ist gleich.
- [ ] `test_missing_mac_en_us_is_posted_with_all_fields_including_whats_new`: GIVEN Mac-Version ohne en-US WHEN `texte` läuft THEN ein POST mit Locale `en-US`, Beschreibung, Schlüsselwörter, Support-URL, Werbetext, `whatsNew` und der Relation zur Version.
- [ ] `test_second_run_writes_nothing`: GIVEN die Texte stehen bei Apple wie in der Datei WHEN `texte` ein zweites Mal läuft THEN „unverändert“ je Sprache und kein Nicht-GET.
- [ ] `test_lesen_shows_published_promotional_text_and_never_writes`: GIVEN je Plattform eine `READY_FOR_SALE`-Version mit Werbetext und eine bearbeitbare WHEN `lesen` läuft THEN steht je Plattform und Sprache eine Zeile `veröffentlicht … Werbetext zeichen=N: <Wortlaut>`, und alle Anfragen sind GET.
- [ ] `test_repo_text_file_parses_and_fits_limits` (bestehender Test, wird erweitert; RED, solange `## de-DE` und die Neu-Texte fehlen): GIVEN die echte Textdatei THEN enthält sie `en-US` (vollständig, mit Neu-Text) und `de-DE` (Werbetext, Neu-Text), `wanted_texts` besteht, Werbetext ≤ 170 Zeichen, Neu-Texte ≤ 4000 Zeichen und nicht leer.
- [ ] `test_writes_only_localization_paths_and_submits_nothing`: (bestehend, bleibt) GIVEN ein voller Lauf `texte` THEN gibt es kein `DELETE`, keine Einreichung, nur Lokalisierungspfade.

## Acceptance Criteria

- **AC-1:** Given ein Abschnitt mit der Zeile `Neu in dieser Version:`, When die Textdatei gelesen wird, Then steht der Wert als `whatsNew`, 4000 Zeichen sind erlaubt, 4001 sind `Fatal` mit Locale, Feld, Ist- und Soll-Zahl. Belegt durch `test_whats_new_line_is_parsed_and_limited`.
- **AC-2:** Given ein Abschnitt ohne `Beschreibung:` mit mindestens einem von Werbetext und Neu-Text und ohne Schlüsselwörter/Support-URL, When die Datei geprüft wird, Then ist sie gültig; ein Abschnitt ohne Beschreibung mit Schlüsselwörtern oder Support-URL, oder ohne eines der zwei erlaubten Felder, ist `Fatal` vor jeder Anfrage. Belegt durch `test_section_without_description_may_carry_only_promo_and_whats_new`.
- **AC-3:** Given ein Abschnitt mit `Beschreibung:`, When Schlüsselwörter oder Support-URL fehlen, Then bleibt es `Fatal` wie bisher. Belegt durch `test_section_with_description_still_requires_all_three`.
- **AC-4:** Given ein Abschnitt ohne Beschreibung, dessen Sprache bei Apple in der Zielversion nicht existiert, When `texte` läuft, Then `Fatal` mit Locale und es wird nichts geschrieben. Belegt durch `test_section_without_description_for_missing_locale_is_fatal_and_writes_nothing`.
- **AC-5:** Given de-DE existiert in beiden bearbeitbaren Versionen, When `texte` mit einem Abschnitt `## de-DE` (Werbetext, Neu-Text) läuft, Then setzt je Plattform genau ein PATCH nur `promotionalText` und `whatsNew`, und die Gegenprobe ist gleich. Belegt durch `test_de_section_patches_only_promo_and_whats_new`.
- **AC-6:** Given die Mac-Version hat keine Sprache en-US, When `texte` läuft, Then entsteht ein POST mit allen Pflichtfeldern, Werbetext und Neu-Text. Belegt durch `test_missing_mac_en_us_is_posted_with_all_fields_including_whats_new`.
- **AC-7:** Given die Texte stehen bei Apple wie in der Datei, When `texte` erneut läuft, Then wird nichts geschrieben. Belegt durch `test_second_run_writes_nothing`.
- **AC-8:** Given eine `READY_FOR_SALE`-Version, When `lesen` läuft, Then zeigt es ihren Werbetext je Plattform und Sprache (Zeichenzahl und Wortlaut) und schreibt nie. Belegt durch `test_lesen_shows_published_promotional_text_and_never_writes`.
- **AC-9:** Given die echte Textdatei, When sie geprüft wird, Then enthält sie `## en-US` mit Neu-Text und `## de-DE` mit dem unveränderten Werbetext von Version 1.0 und einem Neu-Text, alle innerhalb der Grenzen. Belegt durch `test_repo_text_file_parses_and_fits_limits`.
- **AC-10:** Given die Handläufe am echten Konto vom Zweig aus, When `texte` zweimal und danach `lesen` bzw. `asc_store_version lesen` laufen, Then schreibt der erste Lauf, der zweite nichts, und der Endstand zeigt für iOS und Mac je de-DE und en-US mit Beschreibung, Schlüsselwörtern, Support-URL, Werbetext und Neu-Text vorhanden (Zeichenzahl > 0 je Feld) und keine Einreichung. Beleg: Protokolle unter `docs/artifacts/feat-842-s5a2-texte/`: `lesen-vorher.log` (Werbetext von 1.0), `texte-1.log` (schreibt, Gegenprobe gleich), `texte-2.log` (alles unverändert), `lesen-nachher.log` und `store-version-lesen.log` (Endstand).

## Test Plan Summary

Neun Skript-Tests, eine Prüfung je AC 1–9, alle vor der Umsetzung rot (RED), danach grün; AC-10 durch die Handläufe vom Zweig aus, die zugleich der Beleg sind, weil das Ergebnis bei Apple liegt. Stufe 3 greift nicht; es gibt keine Nach-Merge-Punkte.

## Definition of Done

- [ ] Die Tests waren vor der Änderung vorhanden (RED) und sind danach grün; die übrigen Skript-Tests bleiben grün.
- [ ] Die Handläufe `lesen` vorher, `texte`, `texte` (zweites Mal), `lesen` nachher und `asc_store_version lesen` liefen vom Zweig aus; Run-IDs und zitierte Protokollzeilen stehen unter `docs/artifacts/feat-842-s5a2-texte/`.
- [ ] Beide Versionen 1.0.1 haben je de-DE und en-US vollständig; nichts wurde eingereicht.
- [ ] Der Umfang blieb unter ca. 250 LoC, sonst wurde vor dem Weiterbauen gefragt.
- [ ] PR gemergt, CI grün; #842 kommentiert: Schnitt 5a-2 erledigt; offen 5b (Mac-Bilder en-US) und Hennings Entscheidung zur Einreichung beider Versionen.

## Seiteneffekte

- Geänderte Dateien: die drei oben; dazu die Belege unter `docs/artifacts/feat-842-s5a2-texte/`.
- Bei Apple: in den zwei nicht eingereichten Versionen 1.0.1 Werbetext (de-DE), „Neu in dieser Version“ (de-DE, en-US) und die neue Sprache en-US der Mac-Version. Alles vor dem Einreichen jederzeit änderbar. Keine Einreichung, keine Bild- oder Review-Änderung.
- Keine neuen Berechtigungen, keine `Info.plist`, keine `project.yml`-Änderung, keine AppStorage-Schlüssel, keine Audio-Dateien, keine neuen Dependencies, kein Produktcode.

## Risiken

- **Öffentlicher Text.** Die Texte sind öffentlich, sobald eingereicht. Gegenmaßnahmen: Freigabe des Wortlauts mit `approved`, Einreichung nur auf Hennings Wort, deutscher Werbetext unverändert von 1.0.
- **`lesen` der veröffentlichten Version.** Dass Apple die Lokalisierungen einer `READY_FOR_SALE`-Version über denselben Pfad liefert, ist aus Apples Referenz erschlossen. Scheitert der Pfad im echten Lauf, wird das Skript korrigiert und der Lauf wiederholt, nie der Nachbau angepasst, um grün zu werden.
- **Mac en-US per POST.** Der Schreibweg `POST` ist seit Schnitt 3 getestet, am echten Konto aber für die Mac-Version noch nicht gelaufen; Apples 409 kommt mit Code in der Meldung.
- **Unvollständige Abschnitte.** Die Lockerung der Pflichtfelder ist begrenzt (nur ohne `Beschreibung:`, dann nur Werbetext/Neu-Text), damit kein halber Abschnitt still etwas überschreibt.

## Known Limitations

- Beschreibung, Schlüsselwörter und Support-URL der deutschen Sprache bleiben bei Apple; das Werkzeug ändert sie nicht und belegt sie nur über Zeichenzahlen.
- Mac-Bilder en-US folgen in 5b; Einreichen ist kein Teil dieses Schnitts.
- Ein Werbetext, der in 1.0 fehlt oder über 170 Zeichen liegt, hält die Umsetzung an (Rückfrage an Henning).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Betriebswerkzeug ohne Produktcode nach dem Muster der bestehenden ASC-Schreibwege (`asc_version_texts`); es wird keine bestehende ADR gekippt (keine der Alternativen A bis C berührt eine ADR).
- **Rationale:** Der Abschnitt ohne Pflichtfelder hält das Muster „Wortlaut im Repo, nur bei Abweichung schreiben, Gegenprobe im selben Lauf“ aus Schnitt 3 und überschreibt nichts, was nur bei Apple liegt.

## Changelog

- 2026-11-09: Initial spec created (Schnitt 5a-2 von #842: Feld `whatsNew`, Abschnitt ohne Pflichtfelder für vorhandene Sprachen, `lesen` zeigt Werbetext der veröffentlichten Version; Mac en-US per POST; Handläufe vom Zweig aus vor dem Merge)

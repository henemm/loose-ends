---
entity_id: feat-893-schnitt-c-gruende
type: feature
created: 2026-11-10
updated: 2026-11-10
status: draft
workflow: feat-893-c-gruende
---

# Spec: #893 Schnitt C — Gründe der Ablehnung im Einreichwerkzeug

## Approval

- [ ] Approved

Schnitt B (`einreichen`) ist gemergt. Der erste echte Lauf (2026-11-10) endete bei iOS mit 409 `STATE_ERROR.ENTITY_STATE_INVALID` („This resource cannot be reviewed“) am Aufruf, der die Version der Einreichung hinzufügt. Den Grund nennt Apple nur im Block `meta.associatedErrors` der Antwort; das Werkzeug gibt bisher nur die Hauptcodes aus. Schnitt C macht die Gründe sichtbar. `approved` gibt die Umsetzung frei. Ein erneuter Lauf gegen Apple folgt erst nach Hennings Wort.

## Purpose

Ohne die Gründe lässt sich die Ablehnung nicht beheben: Fallberichte nennen mehrere mögliche Ursachen (neues Pflichtfeld der Altersfreigabe, altes Item in einer anderen aktiven Einreichung, hängender Review-Zustand), das Werkzeug kann keine davon belegen oder ausschließen. Raten ist ausgeschlossen, und ein zweiter Schreibversuch ohne neue Erkenntnis bringt nichts.

Schnitt C erweitert nur den Fehlerzweig von `send_once`: bei einer 4xx-Antwort liest ein eigener, tolerant gebauter Leser `errors[].meta.associatedErrors` und hängt die Codes samt bereinigtem Pfad an die Fehlermeldung. Ist die Form unbekannt, nennt er stattdessen die Schlüsselnamen von `meta`, damit der nächste Lauf die Form sichtbar macht.

Für Henning ändert sich nichts Sichtbares; die Einreichung von 1.0.1 kommt damit einen Schritt näher, weil Claude die Ursache der Ablehnung dann benennen und beheben kann.

Nicht in diesem Schnitt (Out of Scope):

- Vorab-Prüfung per GET in `pruefen` (Altersfreigabe, Datenschutz, Fremd-Einreichung). Wird nur dann ein Folgeticket, wenn die Gründe eine prüfbare Angabe nennen.
- Jede Änderung am Schreibablauf (Reihenfolge, Wiederverwendung, Gegenprobe) und jeder zusätzliche Schreibaufruf.
- Änderungen an `error_codes` in `asc_what_to_test.py` (von mehreren Skripten geteilt).
- **Produktcode:** keiner.

Ohne Modell geht es nicht: nicht relevant. Betriebsskript, Regel- und Regex-Weg.

## Source

- **File:** `scripts/asc_store_submit.py` (erweitert), `scripts/test_asc_store_submit.py` (erweitert)
- **Identifier:** neue Funktion `associated_reasons` und Anpassung des Fehlerzweigs in `send_once` (`asc_store_submit.py`); `SubmitFakeASC.refuse` (erweitert um einen Schalter für `meta`) und neue Tests im Test
- **Beleg:** `docs/artifacts/feat-893-c-gruende/` (Beleg des echten Laufs, Strukturschema der Antwort ohne Kennungen)
- **Recherche 2026-11-10:** Das Muster ist bekannt (Apple-Forum https://developer.apple.com/forums/thread/820511, https://rxliuli.com/blog/app-store-connect-new-required-fields). **Die JSON-Form von `meta.associatedErrors` ist nirgends dokumentiert** (Apples Seiten zu ErrorResponse erwähnen sie nicht, kein Fallbericht zitiert den Block). Der Leser deckt deshalb zwei plausible Formen ab (Objekt Pfad → Liste, und Liste) und gibt bei jeder anderen Form die Schlüsselnamen aus; die tatsächliche Form belegt erst der echte Lauf.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `send_once`, `Fatal`, `Masked` (`scripts/asc_store_submit.py`, `asc_wait_build.py`, `asc_beta_invite.py`) | Modul | Fehlerzweig wird erweitert; Einmal-Aufruf und Maskierung bleiben |
| `error_codes` (`scripts/asc_what_to_test.py`) | Modul | liest weiter die Hauptcodes; bleibt unverändert. Weil es den Rumpf per `error.read()` verbraucht, liest Schnitt C den Rumpf einmal selbst und reicht ihn an beide Leser |
| `SubmitFakeASC`, `RAW_SECRET` (`scripts/test_asc_store_submit.py`) | Test-Modul | Nachbau und Geheimwert für Fehlerantworten |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_store_submit.py | MODIFY | `associated_reasons(body)`; Fehlerzweig von `send_once` liest den Rumpf einmal und hängt `gründe:` an (ca. +45 LoC) |
| scripts/test_asc_store_submit.py | MODIFY | `refuse` mit optionalem `meta`; Tests je Regel (ca. +70 LoC) |

Beleg unter `docs/artifacts/feat-893-c-gruende/` kommt mit dem echten Lauf.

Nicht betroffen (geprüft): `asc_what_to_test.py`, `asc_store_version.py`, Workflow `asc-store-submit.yml`, `CLAUDE.md`, Produktcode, `project.yml`.

### Estimated Changes
- Dateien: **2** (Grenze 4–5 eingehalten). LoC: ca. **+115** (Skript ca. 45, Tests ca. 70), unter der 250er-Grenze.
- Produktcode: keiner. „Kein Pfad der Geräteliste berührt.“

## Implementation Details

**1. Rumpf einmal lesen.** Im `except urllib.error.HTTPError` liest `send_once` den Rumpf einmal (`error.read(8192)`), parst ihn mit `json.loads` (Störung → leeres Dict) und leitet daraus die Hauptcodes (gleiche Regel wie `error_codes`: Whitelist `[A-Z0-9_.]+`, höchstens 5) und die Gründe ab. `error_codes` aus `asc_what_to_test.py` wird für diesen Zweig nicht mehr aufgerufen und nicht geändert.

**2. Leser `associated_reasons(body)`.** Je Eintrag in `errors` wird `meta.associatedErrors` ausgewertet:
- Form Objekt: Schlüssel = Pfad, Wert = Liste von Fehlerobjekten → je Fehler ein Paar (Pfad, `code`).
- Form Liste: je Fehlerobjekt ein Paar (Pfad aus `source.pointer` oder `source.parameter`, falls vorhanden, sonst `?`, `code`).
- `code` nur bei Whitelist `[A-Z0-9_.]+` (höchstens 80 Zeichen), sonst `?`. `title` und `detail` werden nie gelesen.
- Pfad: jede Kennung (UUID oder Ziffernfolge ab 4 Stellen) wird durch `<id>` ersetzt, danach nur Zeichen `[A-Za-z0-9/_.<>-]`, höchstens 60 Zeichen; sonst `?`.
- Höchstens 8 Paare insgesamt; Dubletten entfallen.
- Jede Störung (falscher Typ, fehlende Schlüssel) ergibt keine Paare, nie eine Ausnahme.
- Ergibt `associatedErrors` keine Paare, nennt der Leser stattdessen die Schlüsselnamen von `meta` (Whitelist `[A-Za-z0-9_]+`, höchstens 8) als `meta: <namen>`; fehlt `meta`, nichts.

**3. Ausgabe.** Die Fehlermeldung bleibt `ASC antwortet HTTP <n> für <METHOD> <pfad> (codes: …), nicht wiederholt` und erhält, falls Paare vorhanden sind, den Zusatz `; gründe: <pfad>=<code>, …`, sonst bei unbekannter Form `; meta: <namen>`. Der Aufrufpfad in der Meldung (`/v1/reviewSubmissions…`) enthält wie bisher die Kennung der Einreichung nur, soweit `Masked` sie nicht schon ausblendet; daran ändert Schnitt C nichts. Nie Rohantwort, `title`, `detail`, Kennung, Schlüssel oder Token (AC-8 und AC-10 aus Schnitt B bleiben bindend).

**4. Nie.** Kein neuer Schreibaufruf, keine Wiederholung, keine Änderung an Plan, Gegenprobe, Reihenfolge oder Ausgang (4xx bleibt `Fatal`, Ausgang 1). 5xx- und Netzzweige bleiben unverändert.

**5. Echter Lauf (Nachweis, Teil der Definition of Done).** Nach dem Merge läuft `asc-store-submit.yml` mit `aktion=einreichen`, `bestaetigung=1.0.1` erneut, **nur nach Hennings ausdrücklichem Wort**. Er kostet genau einen Schreibaufruf (die wiederverwendete leere iOS-Einreichung bekommt das Item), Mac wird nicht angefasst, solange iOS scheitert. Die ausgegebenen Gründe und die tatsächliche Form von `associatedErrors` (als Strukturschema) stehen danach unter `docs/artifacts/feat-893-c-gruende/`. Weicht die Form von beiden Annahmen ab, wird der Leser korrigiert, nie der Nachbau angepasst, um grün zu werden.

### Alternativen

| Weg | trägt? | Haken |
|---|---|---|
| **Gründe aus `associatedErrors` ausgeben, Form tolerant, bei Unklarheit Schlüsselnamen (gewählt)** | ja | liefert die tatsächliche Ursache; kostet einen weiteren echten Schreibaufruf |
| A Vorab-Prüfung per GET in `pruefen` | ja | rät die Ursachen aus Fallberichten; Apple bietet keinen Endpunkt „darf eingereicht werden“; jede neue Pflichtangabe läge außerhalb der Liste; Folgeticket nur, wenn die Gründe eine prüfbare Angabe nennen |
| B Rohantwort ins Protokoll | ja | bricht AC-10 (Kennungen, Wortlaut, ggf. Geheimnisse im Protokoll); verworfen |
| C Ursache in App Store Connect im Browser nachsehen | ja | nicht wiederholbar, Arbeit weitergereicht; für Mac/iOS-Einreichung zudem Hennings Anmeldung nötig; verworfen |

Gekippt wird keine ADR.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_store_submit.py` (`unittest`, ohne Netz). `SubmitFakeASC.refuse` erhält einen optionalen Parameter `meta`, den der Nachbau unter `errors[0].meta` ausliefert. RED: der Fehlerzweig kennt `meta` noch nicht.

- [ ] `test_reasons_from_associated_errors_object_form`: GIVEN 409 mit `meta.associatedErrors` als Objekt (Pfad → Liste mit `code`) WHEN `einreichen` läuft THEN steht in der Meldung `gründe: <pfad>=<code>` je Eintrag, Ausgang 1.
- [ ] `test_reasons_from_associated_errors_list_form`: GIVEN `associatedErrors` als Liste mit `code` und `source.pointer` WHEN `einreichen` läuft THEN stehen dieselben Paare in der Meldung.
- [ ] `test_unknown_form_shows_meta_key_names_only`: GIVEN `meta` mit unbekannter Form (andere Schlüssel, verschachtelt, Werte mit Geheimwert) WHEN `einreichen` läuft THEN steht `meta: <schlüsselnamen>` ohne Werte.
- [ ] `test_broken_or_missing_meta_changes_nothing`: GIVEN `meta` fehlt, ist kein Objekt, `associatedErrors` ist Zahl, Text, leer oder enthält Nicht-Objekte, bzw. der Rumpf ist kein JSON WHEN `einreichen` läuft THEN bleibt die Meldung wie bisher (Aufruf und `codes`), keine Ausnahme, Ausgang 1.
- [ ] `test_reasons_sanitize_ids_wording_and_limit`: GIVEN Pfade mit UUID und Zahlen, Codes mit Sonderzeichen, `title`/`detail` mit Geheimwert, mehr als 8 Einträge WHEN `einreichen` läuft THEN stehen Kennungen als `<id>`, unzulässige Codes als `?`, höchstens 8 Paare, nie `title`, `detail` oder Geheimwert.
- [ ] `test_reasons_keep_single_write_and_exit_one`: GIVEN 409 mit Gründen WHEN `einreichen` läuft THEN kam der betroffene Schreibaufruf genau einmal an, Mac wurde nach einem iOS-Fehler nicht versucht, und die Aufrufe bleiben auf die drei erlaubten Schreibwege beschränkt (Muster der Tests aus Schnitt B).
- Kein eigener Test für AC-7: die bestehenden Tests aus Schnitt A und B laufen unverändert mit (insbesondere AC-8 und AC-10 aus Schnitt B).

Eine Datei ist unverändert und wird nicht getestet: `asc_what_to_test.py` (ein Diff-Test gegen `main` entfällt, die Dateigrenze belegt `/60-validate`).

## Acceptance Criteria

- **AC-1:** Given 409 oder 422 von Apple mit `meta.associatedErrors` als Objekt, When `einreichen` läuft, Then nennt die Meldung je Eintrag Pfad und Code (`gründe: <pfad>=<code>`). Belegt durch `test_reasons_from_associated_errors_object_form`.
- **AC-2:** Given `associatedErrors` als Liste, When `einreichen` läuft, Then nennt die Meldung Pfad (aus `source.pointer`, sonst `?`) und Code. Belegt durch `test_reasons_from_associated_errors_list_form`.
- **AC-3:** Given eine unbekannte Form von `meta`, When `einreichen` läuft, Then nennt die Meldung nur die Schlüsselnamen von `meta`, nie Werte. Belegt durch `test_unknown_form_shows_meta_key_names_only`.
- **AC-4:** Given fehlendes, kaputtes oder nicht lesbares `meta` bzw. kein JSON, When `einreichen` läuft, Then bleibt die Meldung wie vor Schnitt C, es gibt keine Ausnahme, Ausgang 1. Belegt durch `test_broken_or_missing_meta_changes_nothing`.
- **AC-5:** Given Kennungen, Wortlaut, Sonderzeichen oder mehr als 8 Einträge in den Gründen, When die Meldung entsteht, Then stehen Kennungen als `<id>`, unzulässige Codes als `?`, höchstens 8 Paare, nie `title`, `detail`, Rohantwort oder Geheimwert. Belegt durch `test_reasons_sanitize_ids_wording_and_limit`.
- **AC-6:** Given 4xx mit Gründen, When `einreichen` läuft, Then bleibt es bei genau einem Schreibaufruf des betroffenen Schritts, Ausgang 1, kein weiterer Schreibaufruf und kein anderer Schreibweg als die drei aus Schnitt B. Belegt durch `test_reasons_keep_single_write_and_exit_one`.
- **AC-7:** Given die Tests aus Schnitt A und B, When der Skripttest läuft, Then bleiben alle grün (AC-8 und AC-10 aus Schnitt B gelten weiter). Belegt durch den Lauf von `python3 scripts/test_asc_store_submit.py`.

**Abnahmeweg.** Stufe 1: Python-Tests (AC-1 bis AC-7). Stufe 2: der echte Werkzeuglauf nach dem Merge, nur nach Hennings Wort (siehe Definition of Done, kein AC, weil erst nach dem Merge erfüllbar). Stufe 3 greift nicht; auf Hennings Geräten läuft nichts. Die Dateigrenze (der Diff berührt nur `scripts/` und `docs/`) ist ein Validierungsbeleg in `/60-validate`, kein Test.

## Definition of Done

- [ ] Die Tests waren vor dem Skript vorhanden (RED) und sind danach grün; die übrigen Skript-Tests bleiben grün.
- [ ] PR gemergt, CI grün.
- [ ] Nach dem Merge und nach Hennings Wort lief `einreichen` mit `bestaetigung=1.0.1` einmal; die Gründe und die Form von `associatedErrors` (Strukturschema ohne Kennungen) stehen unter `docs/artifacts/feat-893-c-gruende/`; #893 ist kommentiert.
- [ ] Nennen die Gründe eine behebbare Ursache, ist sie behoben (oder als Folgeticket mit Ziel angelegt), bevor erneut eingereicht wird; #893 bleibt bis zur Einreichung beider Plattformen offen.

## Seiteneffekte

- Geänderte Dateien: die zwei oben; Beleg unter `docs/artifacts/feat-893-c-gruende/`.
- Bei Apple: nichts durch Schnitt C selbst. Der spätere echte Lauf macht genau einen Schreibaufruf auf die vorhandene leere iOS-Einreichung (AC-5 aus Schnitt B), Mac bleibt unberührt.
- Keine neuen Berechtigungen, keine `Info.plist`, keine `project.yml`-Änderung, keine AppStorage-Schlüssel, keine Audio-Dateien, keine neuen Dependencies, kein Produktcode.

## Risiken

- **Form von `associatedErrors` unbekannt.** Gegenmaßnahme: zwei Formen tolerant, sonst Schlüsselnamen von `meta`; schlimmstenfalls zeigt der Lauf nur die Struktur, und ein weiterer Schnitt korrigiert den Leser. Das kostet dann einen weiteren Schreibaufruf (Wiederverwendung der leeren Einreichung, kein Schaden).
- **Geheimnisse oder Kennungen im Protokoll.** Gegenmaßnahme: Whitelist für Code, Schlüsselnamen und Pfad, Kennungen als `<id>`, `title`/`detail` nie gelesen, Obergrenze; zusätzlich `Masked`.
- **Rumpf nur einmal lesbar.** Gegenmaßnahme: Der Fehlerzweig liest ihn einmal und reicht ihn beiden Auswertungen.

## Known Limitations

- Die Gründe erscheinen erst nach einem echten Schreibaufruf, der abgelehnt wird; `pruefen` sagt sie nicht voraus.
- Die Form wird nur geraten (zwei Varianten); bei einer dritten zeigt das Werkzeug nur Schlüsselnamen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Diagnoseausgabe im Fehlerzweig eines Betriebsskripts, ohne Produktcode; es wird keine bestehende ADR gekippt.
- **Rationale:** Die tatsächliche Ursache der Ablehnung liefert nur Apples eigene Antwort; sie auszugeben ist kleiner, genauer und weniger spekulativ als eine Vorab-Prüfung nach Fallberichten. Eine technische Frage ohne Produktauswirkung.

## Changelog

- 2026-11-10: Initial spec created (Schnitt C von #893: Gründe aus `meta.associatedErrors` in der Fehlermeldung von `send_once`, tolerant, bereinigt, begrenzt; bei unbekannter Form die Schlüsselnamen von `meta`)

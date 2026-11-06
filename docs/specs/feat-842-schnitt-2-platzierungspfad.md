---
entity_id: feat-842-schnitt-2-platzierungspfad
type: feature
created: 2026-11-06
updated: 2026-11-06
status: draft
workflow: feat-842-s2-platzierungspfad
---

# Spec: #842 Schnitt 2 — Platzierungspfad der Store-Probe korrigieren und Fehlergrund sichtbar machen

## Approval

- [ ] Approved

## Purpose

Der Handlauf der Store-Probe vom 2026-11-06 (Lauf 42238055521) zeigte bei allen drei App-Store-Versionen „platzierung fehler“ und bei den Referenzdaten „refdaten keine“. Ursache (Code gelesen, Apple-Dokumentation verglichen): Die Probe fragt einen Pfad, den es nicht gibt (`…/appAssetLibraryPlacements` unter der Versions-Lokalisierung; Apple: `…/placements`), sie erwartet die Referenzdaten in einer falschen Form (je Datensatz ein `placementGroup`; Apple liefert einen Datensatz mit Listen in `attributes`), und sie wirft den Fehlerrumpf von Apple bei jeder 4xx-Antwort weg, sodass das Protokoll nie sagt, warum Apple ablehnt. Der lokale Nachbau der Tests bildete den falschen Pfad mit ab, deshalb waren alle Tests grün (gleiche Lehre wie #136: ein Nachbau darf den Fehler nicht mitbauen). Schnitt 2 korrigiert Pfad und Form, macht den Fehlergrund in jeder Zugriffszeile sichtbar und druckt die Attribut-Schlüssel der Platzierungen, damit der nächste Handlauf die Antwortform belegt, statt dass sie geraten wird. Schnitt 3 und 4 von #842 (Schreibweg für Texte und Bilder) bauen auf Pfad und Gruppennamen auf. Die Probe bleibt reines GET.

Ohne Modell geht es nicht: nicht relevant, Betriebsskript gegen die ASC-API (Regeln vor Modell gilt trivial).

## Source

- **File:** `scripts/asc_store_probe.py` (Änderung), `scripts/asc_beta_probe.py` (Änderung)
- **Identifier:** `report_placements(run, label, locale_name, locale_id)`, `report_refdata(run)`; in `asc_beta_probe.py` neu `fetch(config, path)`, `probe(config, path)` bleibt als Hülle, `Probe.ask`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `probe`, `Probe.ask`, `records`, `attributes` (`scripts/asc_beta_probe.py`) | module | GET mit Zählung; `probe()` wird auch von den Beta-Tests benutzt, sein Vertrag `(status, body\|None)` bleibt |
| `scripts/test_asc_store_probe.py`, `scripts/test_asc_beta_probe.py` | test | lokaler HTTP-Nachbau (`ProbeCase.run_probe(extra=routes)`), wird angepasst |
| `.github/workflows/asc-store-probe.yml` | workflow | Handlauf (`workflow_dispatch`), unverändert |
| ASC-API `GET /v1/appStoreVersionLocalizations/{id}/placements` | extern | [List related placements](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-appstoreversionlocalizations-_id_-placements.md) (API 4.5.0+); `appAssetLibraryPlacements` ist nur die Wurzel für `POST` und `GET/DELETE /{id}` |
| ASC-API `GET /v1/appAssetLibraryRefData` | extern | [Discovering asset specifications](https://developer.apple.com/documentation/appstoreconnectapi/discovering-asset-specifications.md): ein Datensatz mit sechs Listen in `attributes` (`features`, `placementProfileGroups`, `imageSpecs`, `videoSpecs`, `placementTypes`, `displayClasses`); Filter `fields[appAssetLibraryRefData]=placementProfileGroups` |
| Apples JSON-API-Fehlerform `{"errors":[{"status","code","title","detail"}]}` | extern | Quelle des Fehlergrunds; nur `code` und `title` |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_beta_probe.py | MODIFY | `fetch()` liefert `(status, body, error_body)`; `probe()` bleibt Hülle mit altem Vertrag; `Probe.ask` hängt bei 4xx `grund=<code>/<title>` an die Zugriffszeile |
| scripts/asc_store_probe.py | MODIFY | `report_placements` auf Pfad `/placements`, druckt `felder=` mit den Attribut-Schlüsseln; `report_refdata` liest `attributes.placementProfileGroups` mit Filter |
| scripts/test_asc_store_probe.py | MODIFY | `store_routes` auf echten Pfad und echte Refdata-Form; neue und angepasste Tests |
| scripts/test_asc_beta_probe.py | MODIFY | ein Test für Fehlergrund in der Zugriffszeile und unveränderten Vertrag von `probe()` |

### Estimated Changes
- Files: 4 (alle geändert)
- LoC: ca. +110/−25 (Skripte ca. 40/−15, Tests ca. 70/−10)
- Reines GET, kein App-Code, kein Gerät.

## Implementation Details

**1. Fehlergrund sichtbar (`asc_beta_probe.py`).** `fetch(config, path)` enthält die bisherige Schleife von `probe()` und liefert zusätzlich den Fehlerrumpf: `(status, body, error_body)`. Bei 2xx ist `error_body` `None`; bei einer 4xx-Antwort, die nicht erneut versucht wird, ist es der als JSON gelesene Rumpf (`None`, wenn er sich nicht als Dict lesen lässt); ohne Antwort nach allen Versuchen `(None, None, None)`. `probe(config, path)` ruft `fetch` und gibt wie bisher `(status, body)` zurück (`(4xx, None)` bei Ablehnung): die Beta-Tests und alle Aufrufer bleiben unberührt. `Probe.ask` ruft `fetch` und hängt bei einer Antwort außerhalb 2xx an die Zugriffszeile ` grund=<code>/<title>`, aus dem ersten Eintrag von `errors`; nur `code` und `title`, Zeilenumbrüche und Anführungszeichen entfernt, auf 80 Zeichen gekürzt. **Nie `detail`:** er kann IDs nennen. Ohne lesbaren Rumpf, ohne `errors`-Liste oder ohne `code` und `title` steht keine `grund`-Angabe (keine Raterei). Das gilt für alle Abfragen der Probe, auch die künftigen.

Beispiel: `zugriff abfrage=placements http=404 befund="Schlüssel hat keinen Zugriff oder Pfad unbekannt" grund=NOT_FOUND/The specified resource does not exist`

**2. Platzierungspfad (`asc_store_probe.py`).** `report_placements` fragt `/v1/appStoreVersionLocalizations/{id}/placements`, Abfragename `placements`. Je Platzierung bleibt die Zeile `platzierung version=… sprache=… gruppe=… typ=… zustand=…` und bekommt zusätzlich `felder=<sortierte Attribut-Schlüssel, kommagetrennt>` (`-` ohne Attribute). Die Antwortform von `/placements` ist nur aus der Dokumentation bekannt; die Schlüssel in der Zeile sind der Beleg aus dem Handlauf, auf dem Schnitt 3 und 4 aufbauen. `keine` und `fehler` bleiben wie in Schnitt 1; ein Fehler bricht den Lauf nicht ab.

**3. Referenzdaten.** `report_refdata` fragt `/v1/appAssetLibraryRefData?fields[appAssetLibraryRefData]=placementProfileGroups` (Name `appAssetLibraryRefData`). Die Antwort ist ein Datensatz; die Gruppen stehen in `attributes.placementProfileGroups` (Liste). Die Probe druckt `refdaten gruppen=<Anzahl> namen=<sortierte Namen, kommagetrennt>`. Die genaue Form der Listeneinträge ist unbestätigt, deshalb liest die Probe Namen defensiv: ein Eintrag ist entweder ein String (Name) oder ein Dict mit erkennbarem Namensfeld (`name`, dann `identifier`, dann `id`; das erste nichtleere String-Feld zählt). Lässt sich aus keinem Eintrag ein Name lesen, steht statt `namen=` die Zeile `felder=<sortierte Schlüssel aller Dict-Einträge, kommagetrennt>`. Ist die Liste leer oder fehlt, steht `refdaten keine`; antwortet Apple nicht, `refdaten fehler` (jetzt mit dem Grund in der Zugriffszeile davor).

**Keine Schreibaufrufe.** Die Probe bleibt reines GET; die Zeilen `text`, `beschreibung`, `schluesselwoerter`, `werbetext`, `bildsatz`, `bild` und die Zusammenfassung bleiben unverändert.

**Alternativen:**
- **A (gewählt):** Asset-Library-Pfad korrigieren und den Fehlergrund ausgeben. Die Doku nennt den Pfad eindeutig; der Grund bleibt für alle künftigen Abfragen.
- **B:** nur die veralteten `appScreenshotSets` prüfen. Liefert „Bildsätze sichtbar“ schon heute, taugt aber nicht zum Schreiben, weil Schnitt 4 die Asset Library braucht (Apple ersetzt die Set-Ressourcen durch sie); schiebt die Unsicherheit nur auf.
- **C:** nur den Fehlergrund, ohne Pfadkorrektur. Ein Handlauf mehr ohne Gewinn, da die Doku den richtigen Pfad nennt.

Keine ADR wird gekippt.

## Test Plan

### Automated Tests (TDD RED)

`unittest`, lokaler HTTP-Nachbau wie bisher; Aufruf `python3 scripts/test_asc_store_probe.py` und `python3 scripts/test_asc_beta_probe.py`.

**Nachbau-Regel (Lehre #136):** `store_routes` bildet nur Apples echte Pfade und Formen ab: `/v1/appStoreVersionLocalizations/{id}/placements` und `/v1/appAssetLibraryRefData` mit einem Datensatz, dessen `attributes.placementProfileGroups` eine Liste ist. Der alte Pfad `…/appAssetLibraryPlacements` ist dort nicht definiert und antwortet 404 mit einem Apple-Fehlerrumpf.

In `scripts/test_asc_beta_probe.py`:

- [ ] `test_ask_prints_error_reason_and_never_detail`: GIVEN der Nachbau antwortet 404 mit `{"errors":[{"code":"NOT_FOUND","title":"Not found","detail":"Resource 123-SECRET-ID"}]}` THEN die Zugriffszeile enthält `http=404` und `grund=NOT_FOUND/Not found`, das Protokoll enthält `detail` und die ID nicht; WHEN der Rumpf kein JSON ist oder keine `errors` hat THEN keine `grund`-Angabe; `probe()` liefert weiter `(404, None)` bei Ablehnung und `(200, dict)` bei Erfolg.

In `scripts/test_asc_store_probe.py`:

- [ ] `test_placement_path_is_placements_and_old_path_is_404`: GIVEN der Nachbau THEN die Probe fragt `/placements` (Abfragename `placements`) und nie den alten Pfad; ein direkter Aufruf des alten Pfads im Nachbau liefert 404.
- [ ] `test_placement_lines_per_localization`: GIVEN de-DE mit zwei Platzierungen, en-US ohne THEN zwei Zeilen `platzierung … gruppe=… typ=… zustand=…` und `platzierung keine … sprache=en-US`.
- [ ] `test_placement_line_prints_attribute_keys`: GIVEN eine Platzierung mit den Attributen `placementType`, `state`, `locale` THEN `felder=locale,placementType,state` (sortiert); ohne Attribute `felder=-`.
- [ ] `test_placement_error_shows_reason_and_does_not_abort`: GIVEN `/placements` antwortet 400 mit `errors[0].code=PARAMETER_ERROR.INVALID` und `errors[0].title=Invalid parameter` THEN `platzierung fehler …`, davor die Zugriffszeile mit `grund=PARAMETER_ERROR.INVALID/Invalid parameter`, Rückgabecode 0, restliche Zeilen und Zusammenfassung vorhanden.
- [ ] `test_refdata_groups_from_placement_profile_groups`: GIVEN ein Datensatz mit `placementProfileGroups` aus drei Namen in ungeordneter Reihenfolge THEN `refdaten gruppen=3 namen=<sortiert>`; der Aufruf trägt `fields[appAssetLibraryRefData]=placementProfileGroups`.
- [ ] `test_refdata_group_entries_read_defensively`: GIVEN Einträge als Dicts mit `name` bzw. `identifier` und ein String-Eintrag THEN alle Namen erscheinen; GIVEN Dict-Einträge ohne erkennbares Namensfeld THEN `felder=<sortierte Schlüssel>` statt `namen=`.
- [ ] `test_refdata_none_and_error`: GIVEN leere oder fehlende Liste THEN `refdaten keine`; GIVEN 404 THEN `refdaten fehler` und `grund=` in der Zugriffszeile.
- [ ] `test_probe_never_writes_and_keeps_old_lines`: GIVEN beliebiger Lauf THEN nur GET, die Zeilen `text`, `bildsatz`/`bild` und `zusammenfassung antworten=… von=… befunde=…` bleiben.

## Acceptance Criteria

- **AC-1:** Given Apple antwortet auf eine Abfrage mit 4xx und einem JSON-API-Fehlerrumpf, When `Probe.ask` die Zugriffszeile druckt, Then steht dort `grund=<code>/<title>` des ersten Fehlers, nie der `detail`-Text, und ohne lesbaren Rumpf keine `grund`-Angabe. Belegt durch `test_ask_prints_error_reason_and_never_detail`.
- **AC-2:** Given bestehende Aufrufer von `probe()`, When Apple 2xx oder 4xx antwortet, Then liefert `probe()` weiter `(status, body)` bzw. `(4xx, None)`. Belegt durch `test_ask_prints_error_reason_and_never_detail`.
- **AC-3:** Given der Nachbau kennt nur Apples echte Pfade, When die Store-Probe die Platzierungen einer Versions-Lokalisierung abfragt, Then fragt sie `/v1/appStoreVersionLocalizations/{id}/placements` und nie den alten Pfad `…/appAssetLibraryPlacements`, der im Nachbau 404 liefert. Belegt durch `test_placement_path_is_placements_and_old_path_is_404`, `test_placement_lines_per_localization`.
- **AC-4:** Given eine Platzierung mit Attributen, When die Probe sie druckt, Then enthält die Zeile `felder=<sortierte Attribut-Schlüssel>` (`-` ohne Attribute). Belegt durch `test_placement_line_prints_attribute_keys`.
- **AC-5:** Given die Platzierungs-Abfrage scheitert, When die Probe läuft, Then steht `platzierung fehler` mit dem Grund in der Zugriffszeile davor, der Lauf bricht nicht ab (Rückgabecode 0, Zusammenfassung vorhanden). Belegt durch `test_placement_error_shows_reason_and_does_not_abort`.
- **AC-6:** Given der Referenzdaten-Datensatz mit `attributes.placementProfileGroups`, When die Probe läuft, Then steht einmal `refdaten gruppen=<Anzahl> namen=<sortiert>` (Namen aus Strings oder Dicts mit `name`/`identifier`/`id`, sonst `felder=<Schlüssel>`), und der Abruf trägt den Filter `fields[appAssetLibraryRefData]=placementProfileGroups`. Belegt durch `test_refdata_groups_from_placement_profile_groups`, `test_refdata_group_entries_read_defensively`.
- **AC-7:** Given leere oder fehlende Gruppenliste bzw. eine abgelehnte Abfrage, When die Probe läuft, Then steht `refdaten keine` bzw. `refdaten fehler`. Belegt durch `test_refdata_none_and_error`.
- **AC-8:** Given jeder Lauf, Then nur GET-Aufrufe, die Zeilen `text`, `bildsatz`/`bild` und die Zusammenfassung bleiben. Belegt durch `test_probe_never_writes_and_keeps_old_lines`.

**Nach dem Merge (Definition of Done, kein AC):** Der Handlauf `asc-store-probe.yml` zeigt für alle drei Versionen die Platzierungen mit `felder=` oder nennt den Fehler samt `grund=`, und die `refdaten`-Zeile mit den Gruppennamen. Das QA-Gate kann ihn nicht belegen, deshalb steht er hier und nicht bei den Acceptance Criteria.

**Abnahmeweg.** Kein Pfad der Geräteliste berührt. Stufe 1 (Tests) läuft vollständig. Stufe 2 hat hier keinen Simulator-Ablauf, weil die Änderung ein reines GET-Skript gegen die ASC-API ist und kein App-Code, also nichts, was ein Simulator zeigen könnte; die Abweichung von der Projektregel ist damit begründet, der Beleg ist der echte CI-Lauf nach dem Merge. Der Abschlussbericht enthält den Satz „Kein Pfad der Geräteliste berührt.“ Schnitt 3 und 4 von #842 folgen als eigene Specs; #842 bleibt bis dahin offen.

## Definition of Done

- [ ] Die neuen und angepassten Tests waren vor der Umsetzung rot und sind danach grün; alle bestehenden Python-Tests der `asc_*`-Skripte bleiben grün (insbesondere `test_asc_beta_probe.py`).
- [ ] Der Diff berührt nur die vier genannten Dateien.
- [ ] Der Handlauf `asc-store-probe.yml` nach dem Merge liegt als Link im Abschlussbericht; die gelesenen Attribut-Schlüssel der Platzierungen und die Gruppennamen stehen im Ticket #842 als Grundlage für Schnitt 3 und 4.

## Seiteneffekte

- Keine Schreibaufrufe nach App Store Connect, nichts an Apple verändert.
- Keine neuen Berechtigungen, keine `Info.plist`, keine AppStorage-Schlüssel, keine Audio-Dateien, kein App-Code, keine neuen Secrets, keine Abhängigkeit.
- `Probe.ask` druckt für alle Abfragen beider Proben (Beta- und Store-Probe) bei 4xx zusätzlich `grund=…`; die Zugriffszeilen der Beta-Probe werden dadurch länger, ihr Rückgabevertrag bleibt.
- Das Protokoll wächst um `felder=…`, `grund=…` und die Gruppennamen (öffentliche Schnittstellenbezeichnungen, keine Schlüssel, keine Nutzerdaten).

## Risiken

- **Antwortform von `/placements` ist nur aus der Doku bekannt.** Die Zeile druckt die Schlüssel mit; der Handlauf nach dem Merge ist die erste Bestätigung. Weicht die Form ab, ist das ein Befund für Schnitt 3 und 4, kein Fehler dieses Schnitts.
- **Form der Listeneinträge in `placementProfileGroups` ist unbestätigt.** Die defensive Namenslese plus `felder=` als Rückfall verhindert, dass die Probe rät oder bricht.
- **Fehlerrumpf könnte Kennungen enthalten.** Deshalb nur `code` und `title`, nie `detail`; ein Test belegt es.
- **Geteilter Code `probe()`:** die Änderung ist eine Aufspaltung in `fetch` und Hülle; der Vertragstest und die bestehenden Beta-Tests fangen eine Abweichung.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Korrektur eines Betriebsskripts nach dem Muster der bestehenden ASC-Proben, kippt keine ADR.

## Changelog

- 2026-11-06: Initial spec created (Schnitt 2 von #842: Platzierungspfad korrigieren, Fehlergrund sichtbar machen, Refdata-Form; Handlauf nach dem Merge als Definition of Done, nicht als AC)

---
entity_id: feat-837-schnitt-1-app-info-befund
type: feature
created: 2026-11-04
updated: 2026-11-04
status: draft
workflow: feat-837-store-untertitel
---

# Spec: #837 Schnitt 1 — Store-Probe zeigt, welche App-Info beschreibbar ist

## Approval

- [ ] Approved

## Purpose

Der App-Store-Untertitel soll de-DE „Einfach sagen. Kopf frei.“ und en-US „Say it. Clear your head.“ lauten (Wortlaut von Henning am 2026-11-04 freigegeben). Bevor ein Schreibweg gebaut wird (Schnitt 2), muss feststehen, ob es für die iOS-Fassung überhaupt eine App-Info gibt, die Apple ändern lässt. Der Lauf 41868615757 zeigte nur zwei App-Infos (eine `READY_FOR_DISTRIBUTION`, eine `IN_REVIEW`) und weder Plattform noch Zustandsfelder getrennt; iOS 1.0.1 steht auf `PREPARE_FOR_SUBMISSION`. Schnitt 1 erweitert die bestehende Store-Probe (nur GET) so, dass der nächste Handlauf diese Frage beantwortet. Er schreibt nichts in App Store Connect.

Ohne Modell geht es nicht: nicht relevant, Betriebsskript gegen die ASC-API (Regeln vor Modell gilt trivial).

## Source

- **File:** `scripts/asc_store_probe.py` (Änderung; Name und Untertitel je Sprache sind seit Commit 374bb16 drin)
- **Identifier:** `report_subtitles(run, app_id)`; neu `report_app_infos` ist nicht nötig, die Zeilen bleiben in `report_subtitles`.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Probe.ask`, `records`, `attributes` (`scripts/asc_beta_probe.py`) | module | GET mit Zählung, Datensätze, Attribute |
| `scripts/test_asc_beta_probe.py` | test | Vorbild für den lokalen HTTP-Nachbau |
| `.github/workflows/asc-store-probe.yml` | workflow | bestehender Handlauf, unverändert |
| ASC-API `GET /v1/apps/{id}/appInfos` | extern | Attribute `state`, `appStoreState`, Relationen je App-Info; [AppInfo](https://developer.apple.com/documentation/appstoreconnectapi/appinfo) |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_store_probe.py | MODIFY | je App-Info eine Zeile `appinfo` mit `state`, `appStoreState`, Attributnamen und Relationsnamen; Untertitelzeilen tragen die App-Info-Kennung statt eines gemischten Zustands |
| scripts/test_asc_store_probe.py | CREATE | Tests gegen lokalen Nachbau |

### Estimated Changes
- Files: 2 (1 neu, 1 geändert)
- LoC: ca. +90/−6 (Skript ca. 20, Tests ca. 70)

## Implementation Details

Je App-Info (`GET /v1/apps/{id}/appInfos`) eine Zeile, nur Zustandswörter und Namen, nie Werte:

`appinfo nr=<1..n> state=<Wert|?> appStoreState=<Wert|?> felder=<sortierte Attributnamen> relationen=<sortierte Relationsnamen>`

Die Untertitelzeilen werden zu `untertitel appinfo=<nr> sprache=… name=… untertitel=… zeichen=…`. Bisher stand dort `info=<state oder appStoreState>`; das vermischt die beiden Felder und ist der Grund, warum der Lauf vom 2026-11-04 die Frage nicht beantwortete. Hat eine App-Info keine Lokalisierung, steht `untertitel appinfo=<nr> keine`.

**Warum Felder- und Relationsnamen:** Apples Referenz zeigt nicht verlässlich, über welches Feld eine App-Info zur iOS- oder Mac-Fassung gehört. Statt zu raten, druckt die Probe die Namen aus der echten Antwort; Schnitt 2 wird nach dem Befund gebaut. Ein Namenswort ist kein Geheimnis und enthält keinen Nutzertext.

**Keine Schreibaufrufe.** Die Probe bleibt reines GET, der Zähler `run.asked` zählt unverändert.

**Alternativen:**
- Gleich den Schreibweg bauen und die Auswahl der App-Info raten (erste mit `PREPARE_FOR_SUBMISSION`): verworfen, es riskiert, die App-Info der Mac-Fassung in Prüfung zu treffen.
- Ergebnis in der ASC-Weboberfläche per Claude in Chrome ablesen: kein Repo-Beleg, nicht wiederholbar, und die Erweiterung war bei #742 nicht verbunden. Rückfall, falls die API nichts hergibt.

Keine ADR wird gekippt.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_store_probe.py` (`unittest`, lokaler HTTP-Nachbau wie in `test_asc_beta_probe.py`, echter `openssl`-Schlüssel im Testordner; Aufruf `python3 scripts/test_asc_store_probe.py`).

- [ ] `test_appinfo_line_has_both_states_separately`: GIVEN Nachbau mit zwei App-Infos (`state=READY_FOR_DISTRIBUTION`, `appStoreState` fehlt; `appStoreState=IN_REVIEW`, `state` fehlt) WHEN die Probe läuft THEN zwei Zeilen `appinfo nr=1 …` und `nr=2 …`, `state` und `appStoreState` je getrennt, fehlendes Feld als `?`.
- [ ] `test_appinfo_line_lists_attribute_and_relationship_names_sorted`: GIVEN App-Info mit mehreren Attributen und Relationen THEN die Zeile enthält die Namen sortiert, keine Werte.
- [ ] `test_subtitle_lines_carry_appinfo_number`: GIVEN zwei App-Infos mit je de-DE Untertitel THEN `untertitel appinfo=1 …` und `appinfo=2 …`, `zeichen` gleich der Länge, kein `info=`.
- [ ] `test_appinfo_without_localization_says_keine`: GIVEN App-Info ohne Lokalisierung THEN `untertitel appinfo=<nr> keine`.
- [ ] `test_probe_never_writes`: GIVEN der Nachbau protokolliert Methoden THEN nur GET.
- [ ] `test_summary_line_still_present`: GIVEN beliebiger Lauf THEN `zusammenfassung antworten=… von=… befunde=…` kommt zum Schluss.

## Acceptance Criteria

- **AC-1:** Given zwei App-Infos mit verschiedenen Zustandsfeldern, When die Store-Probe läuft, Then steht je App-Info eine Zeile `appinfo` mit `state` und `appStoreState` getrennt (fehlend = `?`). Belegt durch `test_appinfo_line_has_both_states_separately`.
- **AC-2:** Given eine App-Info, When die Probe läuft, Then nennt die Zeile die Attribut- und Relationsnamen sortiert und keine Werte. Belegt durch `test_appinfo_line_lists_attribute_and_relationship_names_sorted`.
- **AC-3:** Given Untertitel in mehreren App-Infos, When die Probe läuft, Then trägt jede Untertitelzeile die Nummer ihrer App-Info; eine App-Info ohne Lokalisierung meldet `keine`. Belegt durch `test_subtitle_lines_carry_appinfo_number`, `test_appinfo_without_localization_says_keine`.
- **AC-4:** Given jeder Lauf, Then nur GET-Aufrufe und die Zusammenfassungszeile bleibt. Belegt durch `test_probe_never_writes`, `test_summary_line_still_present`.
- **AC-5:** Given der Merge auf `main`, When der Handlauf `asc-store-probe` startet, Then zeigt das Protokoll für beide echten App-Infos Zustände und Relationsnamen, und der Abschlussbericht benennt daraus, welche App-Info zur iOS-Fassung 1.0.1 gehört und ob sie beschreibbar ist (Befund für Schnitt 2). Belegt durch den Lauf-Link (Abnahme ohne Gerät, siehe unten).

**Abnahmeweg.** Kein Pfad der Geräteliste berührt, es wird kein App-Code geändert; Stufe 2 im Simulator entfällt sinngemäß. Der Beleg ist der echte CI-Lauf nach dem Merge. Schnitt 2 (Schreibweg) und Schnitt 3 (`CLAUDE.md`/`README.md`) folgen als eigene Specs; #837 bleibt bis dahin offen.

## Definition of Done

- [ ] Die Tests in `scripts/test_asc_store_probe.py` waren vor der Umsetzung rot und sind danach grün; die bestehenden Python-Tests der `asc_*`-Skripte bleiben grün.
- [ ] Der Diff berührt nur die zwei genannten Dateien.
- [ ] Der Handlauf nach dem Merge liegt als Link im Abschlussbericht, der Befund (iOS-App-Info, beschreibbar ja/nein) steht im Ticket #837.

## Seiteneffekte

- Keine Schreibaufrufe nach App Store Connect, nichts an Apple verändert.
- Keine neuen Berechtigungen, keine `Info.plist`, keine AppStorage-Schlüssel, keine Audio-Dateien, kein App-Code, keine neuen Secrets, keine Abhängigkeit.
- Das Protokollformat der Untertitelzeilen ändert sich (`info=` wird `appinfo=`); die Zeilen sind erst seit 374bb16 drin und nirgends ausgewertet.

## Risiken

- **Keine Plattform-Angabe an der App-Info:** Zeigen auch die Relationsnamen keine Zuordnung zur iOS-Fassung, bleibt die Frage offen. Dann ist der nächste Schritt eine gezielte Abfrage der Relation, die der Befund nennt, oder der Rückfall über die Weboberfläche; Schnitt 2 wird nicht auf Verdacht gebaut.
- **Es gibt keine beschreibbare App-Info für iOS:** Dann muss das Schreiben warten, bis Apple sie anlegt (oder die Mac-Prüfung durch ist). Das ist ein gültiger Befund, kein Fehler.
- **Folgeschnitt en-US:** Apple verlangt gleiche Lokalisierungen an App-Info und Version; ein neues en-US an der App-Info braucht dann auch die Versions-Lokalisierung (Beschreibung, Keywords, Support-URL, Bilder). Das entscheidet sich vor Schnitt 2 und ist hier nicht enthalten.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Betriebsskript nach dem Muster der bestehenden ASC-Proben, kippt keine ADR.

## Changelog

- 2026-11-04: Initial spec created (Schnitt 1 von 3; Schnitt 2 = Schreibweg, Schnitt 3 = Wortlaut-Docs)

---
entity_id: feat-842-schnitt-1-probe-texte
type: feature
created: 2026-11-06
updated: 2026-11-06
status: draft
workflow: feat-842-en-store
---

# Spec: #842 Schnitt 1 — Store-Probe liest Texte und Bildplatzierungen der Versions-Lokalisierung

## Approval

- [ ] Approved

## Purpose

Die englische Store-Seite (#842) braucht einen Wortlaut, der zum deutschen passt und nicht mehr verspricht, als die App hält. Der deutsche Text steht nirgends im Repo; Henning hat ihn von Hand in App Store Connect gesetzt. Die Store-Probe liest von der Versions-Lokalisierung heute nur Sprache und Bildsätze, also weiß niemand, was dort (de wie en) in Beschreibung, Schlüsselwörtern, Support-URL und Werbetext steht, und ob die en-US-Lokalisierung der Version leer ist. Schnitt 1 erweitert die Probe (nur GET) so, dass der nächste Handlauf das zeigt, und liest zusätzlich, wie Hennings Bilder über die neue Asset-Library-Schnittstelle platziert sind (Vorbereitung für den Bild-Upload, Schnitt 4). Er schreibt nichts in App Store Connect.

Ohne Modell geht es nicht: nicht relevant, Betriebsskript gegen die ASC-API (Regeln vor Modell gilt trivial).

## Source

- **File:** `scripts/asc_store_probe.py` (Änderung)
- **Identifier:** `main()`; neu `report_version_texts(run, label, locale_name, record)` und `report_placements(run, label, locale_name, locale_id)`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Probe.ask`, `records`, `attributes` (`scripts/asc_beta_probe.py`) | module | GET mit Zählung, Datensätze, Attribute |
| `scripts/test_asc_store_probe.py` | test | bestehender lokaler HTTP-Nachbau, wird erweitert |
| `.github/workflows/asc-store-probe.yml` | workflow | bestehender Handlauf, unverändert |
| ASC-API `GET /v1/appStoreVersions/{id}/appStoreVersionLocalizations` | extern | Attribute `description`, `keywords`, `supportUrl`, `promotionalText`, `marketingUrl`; [AppStoreVersionLocalization](https://developer.apple.com/documentation/appstoreconnectapi/appstoreversionlocalization) |
| ASC-API Platzierungen (`appAssetLibraryPlacements`) | extern, **Pfad nicht bestätigt** | Recherche 2026-11-06: [Placing assets on your App Store surfaces](https://developer.apple.com/documentation/appstoreconnectapi/placing-assets-on-your-app-store-surfaces) |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_store_probe.py | MODIFY | je Versions-Lokalisierung eine Zeile `text` und Zeilen `platzierung`; die Textfelder kommen aus der schon geholten Lokalisierungsliste, kein zusätzlicher Aufruf |
| scripts/test_asc_store_probe.py | MODIFY | Tests gegen den lokalen Nachbau |

### Estimated Changes
- Files: 2 (beide geändert)
- LoC: ca. +110/−2 (Skript ca. 40, Tests ca. 70)

## Implementation Details

**Textzeile** je Versions-Lokalisierung, aus den Attributen der bereits abgefragten Liste:

`text version=<label> sprache=<Locale> beschreibung=<Zeichen> schluesselwoerter=<Zeichen> supporturl=<Wert|keine> werbetext=<Zeichen> marketingurl=<Wert|keine>`

Die Textfelder selbst stehen in eigenen Zeilen, damit der Wortlaut ablesbar wird: `beschreibung version=… sprache=… text=<JSON-String>`, ebenso `schluesselwoerter …` und `werbetext …`. Der JSON-String schreibt Zeilenumbrüche als `\n` und Umlaute unmaskiert, damit jede Angabe eine Logzeile bleibt. Ein leeres oder fehlendes Feld steht als `text=keiner` mit `zeichen=0`.

**Warum die Werte gedruckt werden dürfen:** Beschreibung, Schlüsselwörter, Support-URL und Werbetext sind öffentliche Store-Texte, keine Schlüssel und keine Nutzerdaten. Sie sind genau der Beleg „Werte aus ASC“, den #842 verlangt, und die Tonvorlage für den englischen Entwurf. Die Probe druckt weiter keine Schlüssel.

**Platzierungszeilen.** Zu jeder Versions-Lokalisierung fragt die Probe die Platzierungen ab (Pfad `/v1/appStoreVersionLocalizations/{id}/appAssetLibraryPlacements`, Name `appAssetLibraryPlacements`) und druckt je Platzierung `platzierung version=… sprache=… gruppe=<placementGroup|?> typ=<placementType|?> zustand=<Wert|?>`, ohne Platzierung `platzierung keine version=… sprache=…`. Antwortet die Abfrage nicht (`ask` liefert `None`), steht `platzierung fehler version=… sprache=…`; die Probe bricht deshalb nicht ab, der Fehler zählt wie bei den anderen Abfragen als Befund. **Der Pfad ist aus der Recherche, nicht erprobt**; der Handlauf nach dem Merge ist die erste Bestätigung. Zeigt er `fehler`, ist das ein Befund für Schnitt 4, kein Fehler dieses Schnitts, und der Abschlussbericht nennt Statuscode und Meldung aus dem Protokoll.

**Gruppen-Referenzdaten.** Einmal pro Lauf `GET /v1/appAssetLibraryRefData` (Name `appAssetLibraryRefData`), gedruckt als eine Zeile `refdaten gruppen=<sortierte placementGroup-Namen, kommagetrennt>` bzw. `refdaten fehler`. Daraus liest Schnitt 4 die Gruppen für iPad 13″ und Watch, statt sie zu raten. Die Form der Antwort ist unbestätigt; die Probe sammelt Gruppennamen aus den Attributen `placementGroup` aller Datensätze und druckt `refdaten keine`, wenn keine zu finden sind.

**Keine Schreibaufrufe.** Die Probe bleibt reines GET. Die alten Zeilen `bildsatz …` und `bild …` bleiben unverändert (sie zeigen die alten Bildsätze von #742 und sind der Gegenbeleg zu den Platzierungen).

**Alternativen:**
- Den deutschen Text in der ASC-Weboberfläche per Claude in Chrome ablesen: kein Repo-Beleg, nicht wiederholbar; nur Rückfall.
- Henning nach dem Wortlaut fragen: verstößt gegen „keine Arbeit für ihn“, und er hat den Text nirgends gesichert.
- Die Platzierungen weglassen und erst in Schnitt 4 lesen: verworfen, weil der unbestätigte Pfad dann erst im Schreib-Schnitt auffiele; ein Lesen jetzt kostet ca. 15 LoC und klärt vorher.

Keine ADR wird gekippt.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_store_probe.py` (`unittest`, lokaler HTTP-Nachbau wie bisher, Aufruf `python3 scripts/test_asc_store_probe.py`).

- [ ] `test_text_line_counts_each_field`: GIVEN eine Versions-Lokalisierung mit Beschreibung (120 Zeichen), Schlüsselwörtern (60), Support-URL und ohne Werbetext THEN `text …`-Zeile mit `beschreibung=120 schluesselwoerter=60 supporturl=<Wert> werbetext=0`.
- [ ] `test_description_printed_on_one_line_with_umlauts`: GIVEN Beschreibung mit Zeilenumbruch und „ä“ THEN genau eine Zeile `beschreibung …`, `\n` maskiert, „ä“ unmaskiert.
- [ ] `test_empty_en_us_localization_says_keiner`: GIVEN en-US ohne Textfelder THEN `beschreibung … text=keiner`, `supporturl=keine`, alle Zähler 0.
- [ ] `test_placement_lines_per_localization`: GIVEN Nachbau liefert für de-DE zwei Platzierungen und für en-US keine THEN zwei Zeilen `platzierung … gruppe=…` und `platzierung keine … sprache=en-US`.
- [ ] `test_placement_error_does_not_abort`: GIVEN der Platzierungspfad antwortet 404 THEN `platzierung fehler …`, Rückgabecode 0, restliche Zeilen und Zusammenfassung vorhanden.
- [ ] `test_refdata_group_names_sorted`: GIVEN Referenzdaten mit drei `placementGroup`-Werten THEN `refdaten gruppen=` sortiert; ohne Treffer `refdaten keine`; bei 404 `refdaten fehler`.
- [ ] `test_probe_never_writes_and_keeps_old_lines`: GIVEN beliebiger Lauf THEN nur GET, die Zeilen `bildsatz`/`bild` und `zusammenfassung antworten=… von=… befunde=…` bleiben.

## Acceptance Criteria

- **AC-1:** Given eine Versions-Lokalisierung mit Textfeldern, When die Store-Probe läuft, Then steht eine `text`-Zeile mit den Zeichenzahlen und je Feld eine einzeilige Textzeile; leere Felder sind `keiner`/`keine`. Belegt durch `test_text_line_counts_each_field`, `test_description_printed_on_one_line_with_umlauts`, `test_empty_en_us_localization_says_keiner`.
- **AC-2:** Given Versions-Lokalisierungen mit und ohne Platzierungen, When die Probe läuft, Then steht je Lokalisierung `platzierung` (mit Gruppe und Typ), `platzierung keine` oder `platzierung fehler`, und ein Fehler bricht den Lauf nicht ab. Belegt durch `test_placement_lines_per_localization`, `test_placement_error_does_not_abort`.
- **AC-3:** Given die Referenzdaten der Asset Library, When die Probe läuft, Then steht eine `refdaten`-Zeile mit sortierten Gruppennamen, `keine` oder `fehler`. Belegt durch `test_refdata_group_names_sorted`.
- **AC-4:** Given jeder Lauf, Then nur GET-Aufrufe, die alten Bildzeilen und die Zusammenfassung bleiben. Belegt durch `test_probe_never_writes_and_keeps_old_lines`.
- **AC-5:** Given der Merge auf `main`, When der Handlauf `asc-store-probe` startet, Then zeigt das Protokoll für iOS 1.0.1 die Texte von de-DE (Tonvorlage) und en-US (leer oder nicht), die Platzierungen von de-DE und die Gruppennamen, oder nennt den Fehler je Abfrage mit Statuscode. Der Abschlussbericht fasst das zusammen und legt den Lauf-Link ins Ticket #842. Belegt durch den Lauf-Link.

**Abnahmeweg.** Kein Pfad der Geräteliste berührt, kein App-Code; Stufe 2 im Simulator entfällt sinngemäß. Beleg ist der echte CI-Lauf nach dem Merge. Schnitt 2 (Texte en-US schreiben, Wortlaut von Henning freigegeben), 3 (englische Bilder) und 4 (Bild-Upload) folgen als eigene Specs; #842 bleibt bis dahin offen.

## Definition of Done

- [ ] Die neuen Tests waren vor der Umsetzung rot und sind danach grün; alle bestehenden Python-Tests der `asc_*`-Skripte bleiben grün.
- [ ] Der Diff berührt nur die zwei genannten Dateien.
- [ ] Der Handlauf nach dem Merge liegt als Link im Abschlussbericht; die gelesenen Texte stehen im Ticket #842 als Grundlage für Schnitt 2.

## Seiteneffekte

- Keine Schreibaufrufe nach App Store Connect, nichts an Apple verändert.
- Keine neuen Berechtigungen, keine `Info.plist`, keine AppStorage-Schlüssel, keine Audio-Dateien, kein App-Code, keine neuen Secrets, keine Abhängigkeit.
- Das Protokoll wächst um die Texte der Store-Seite (öffentlich) und ein paar Zeilen je Lokalisierung; zwei bis drei zusätzliche GET-Aufrufe je Lokalisierung bzw. Lauf.

## Risiken

- **Pfade für Platzierungen und Referenzdaten sind unbestätigt.** Apple hat die Schnittstelle neu eingeführt; die Probe fängt Fehler je Abfrage ab und meldet sie, statt zu raten. Ein `fehler` ist ein gültiger Befund für Schnitt 4, dann folgt eine gezielte Nachfrage (Doku erneut lesen, andere Beziehung).
- **Lange Beschreibung im Log:** bis 4000 Zeichen in einer Zeile; akzeptabel, der Text ist öffentlich.
- **Apple-Matrix der Pflichtfelder bleibt unbelegt** (Beschreibung, Schlüsselwörter, Support-URL); die Probe zeigt nur, was gesetzt ist, und beantwortet nicht, was Apple zur Einreichung verlangt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Betriebsskript nach dem Muster der bestehenden ASC-Proben, kippt keine ADR.

## Changelog

- 2026-11-06: Initial spec created (Schnitt 1 von 4; Schnitt 2 = Texte en-US, 3 = englische Bilder, 4 = Bild-Upload)

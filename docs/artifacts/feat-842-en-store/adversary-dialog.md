# Adversary Dialog — feat-842-en-store
Spec: docs/specs/feat-842-schnitt-1-probe-texte.md
Datum: 2026-11-06 13:52

## Checkliste
- [x] **AC-1:** Given eine Versions-Lokalisierung mit Textfeldern, When die Store-Probe läuft, Then steht eine `text`-Zeile mit den Zeichenzahlen und je Feld eine einzeilige Textzeile; leere Felder sind `keiner`/`keine`. Belegt durch `test_text_line_counts_each_field`, `test_description_printed_on_one_line_with_umlauts`, `test_empty_en_us_localization_says_keiner`.
- [x] **AC-2:** Given Versions-Lokalisierungen mit und ohne Platzierungen, When die Probe läuft, Then steht je Lokalisierung `platzierung` (mit Gruppe und Typ), `platzierung keine` oder `platzierung fehler`, und ein Fehler bricht den Lauf nicht ab. Belegt durch `test_placement_lines_per_localization`, `test_placement_error_does_not_abort`.
- [x] **AC-3:** Given die Referenzdaten der Asset Library und mindestens eine App-Store-Version, When die Probe läuft, Then steht einmal pro Lauf eine `refdaten`-Zeile mit sortierten Gruppennamen, `keine` oder `fehler`. Belegt durch `test_refdata_group_names_sorted`.
- [x] **AC-4:** Given jeder Lauf, Then nur GET-Aufrufe, die alten Bildzeilen und die Zusammenfassung bleiben. Belegt durch `test_probe_never_writes_and_keeps_old_lines`.

## Dialog

### Runde 1
**Adversary:** Tests selbst ausgefuehrt: `python3 scripts/test_asc_store_probe.py` = 16 Tests OK; `python3 -m unittest discover -s scripts -p "test_asc_*.py"` = 228 Tests OK, 0 Fehler, 0 uebersprungen (Ausgabe in adversary-test-output.txt). Code gelesen: Textzeile und drei Feldzeilen aus der schon geholten Liste, kein Zusatzaufruf; leere Felder `keiner`/`keine`; json.dumps mit ensure_ascii=False maskiert \n, laesst Umlaute. Platzierungen: ask() liefert None bei Nicht-2xx -> `platzierung fehler`, Lauf geht weiter; Zusammenfassung bleibt. Refdaten nur im else-Zweig von `if not versions` (Spec AC-3 nennt jetzt ausdruecklich mindestens eine Version, deckungsgleich). Alle Aufrufe laufen ueber Probe.ask/probe (GET); Test prueft Methodenmenge == {GET}.
**Implementierer:** Aenderung nur in scripts/asc_store_probe.py und Tests, keine Schreibaufrufe, alte Zeilen bildsatz/bild unveraendert.

### Runde 2
**Adversary:** Nachgebohrt mit direkten Aufrufen: description=123 -> TypeError (len(int)); description=["a"] -> len 1, Ausgabe `["a"]` (keine Abstuerze); supportUrl=5 gedruckt; placementGroup gemischt int/str -> TypeError in sorted(); data=None -> `refdaten keine`; Datensatz ohne attributes -> kein Absturz. Neu bewertet F001: Die ASC-API typisiert diese Attribute als String oder null (Doku AppStoreVersionLocalization); `or ''` deckt null ab. Dasselbe Muster (len(a.get('subtitle') or '')) steht seit #837 unveraendert im Bestand (Zeile 103). Eine Haertung gegen Fremdtypen waere spekulativ und nach Regel Drive-by ohne Anlass; sie wuerde zudem eine Abweichung vom Bestandsmuster einfuehren. Folge im Ernstfall: Traceback im Handlauf, sichtbar, nichts wird geschrieben (nur GET). Ergebnis: tragbar, kein Merge-Blocker. Placement-Wert mit Zeilenumbruch wuerde die Zeile brechen, aber die Werte sind Apple-Enums, keine Freitexte; nicht gemeldet. F002 (refdaten nur bei Version) ist durch die Spec-Nachbesserung aufgeloest.
**Implementierer:** Kein Codeaenderungsbedarf; F001 bleibt LOW, dokumentiert.

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_store_probe.py:38
  Description: len(a.get(key) or '') und Zeile 74 sorted() setzen String-Werte voraus; Nicht-String-Werte (int) werfen TypeError, der nicht als Fatal gefangen wird.
  Spec requirement: AC-1 — Textzeile mit Zeichenzahlen; AC-3 — sortierte Gruppennamen
  Conflict: Nur bei von der dokumentierten API abweichenden Typen; Spec fordert keine Typhaertung. Bestandsmuster (Zeile 103) identisch.
  Remediation: Keine vor dem Merge. Falls je beobachtet: str()-Normalisierung in eigenem Ticket.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: scripts/asc_store_probe.py:30
  Evidence: report_version_texts druckt text-Zeile plus je Feld eine JSON-Zeile, keiner/keine bei leer; test_text_line_counts_each_field, test_description_printed_on_one_line_with_umlauts, test_empty_en_us_localization_says_keiner gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/asc_store_probe.py:48
  Evidence: report_placements: None -> fehler und return, leer -> keine, sonst je Platzierung gruppe/typ/zustand; Lauf bricht nicht ab (test_placement_error_does_not_abort gruen).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/asc_store_probe.py:68
  Evidence: report_refdata einmal pro Lauf (main, Zeile 116, nur mit Version), sorted-Gruppen, keine/fehler; test_refdata_group_names_sorted gruen, manuell geprueft (A,B; data=None -> keine).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/test_asc_store_probe.py:217
  Evidence: Test prueft Methoden == {GET}, alte bildsatz/bild- und Zusammenfassungszeilen vorhanden; Code nutzt nur Probe.ask.
  Status: CONFIRMED

### Runde 2
**Adversary:**
**Implementierer:**

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:34a3c1da3ad776fde34359ea930577f2341ba7d37141ecd30df6fc447e872d47  scripts/asc_store_probe.py
- sha256:b5b226e22830192b3027b795061e34e674480b6011e714b1ebc0756efcbe9a7c  scripts/test_asc_store_probe.py

## Prüfbasis

- base: 0690402eaa5531b95ce1ba224958483e685191ea
- blob:7e83db9ab0da31d5202bc2ad4b14f469e7ee05bf  scripts/asc_store_probe.py
- blob:f00b036f916158b0eeb92de425a467832b62dd85  scripts/test_asc_store_probe.py

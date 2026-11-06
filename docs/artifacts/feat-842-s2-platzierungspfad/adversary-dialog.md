# Adversary Dialog — feat-842-s2-platzierungspfad
Spec: docs/specs/feat-842-schnitt-2-platzierungspfad.md
Datum: 2026-11-06

## Checkliste
- [x] **AC-1:** `grund=<code>/<title>` nur aus `errors[0]`, nie `detail`, ohne lesbaren Rumpf keine Angabe.
- [x] **AC-2:** `probe()` liefert weiter `(status, body)` bzw. `(4xx, None)`, auch bei unlesbarem Fehlerrumpf.
- [x] **AC-3:** Pfad `/placements`, der alte Pfad `appAssetLibraryPlacements` wird im Produktcode nie gefragt.
- [x] **AC-4:** `felder=<sortierte Attribut-Schlüssel>`, `-` ohne Attribute.
- [x] **AC-5:** `platzierung fehler` mit `grund=` in der Zugriffszeile davor, der Lauf bricht nicht ab.
- [x] **AC-6:** `refdaten gruppen=N namen=…` mit Filter `fields[appAssetLibraryRefData]=placementProfileGroups`, defensive Namenslese bis `felder=`.
- [x] **AC-7:** `refdaten keine` bzw. `refdaten fehler`.
- [x] **AC-8:** Nur GET, die Zeilen `text`, `bildsatz`/`bild` und die Zusammenfassung bleiben.

## Dialog

### Runde 1
**Adversary:** Erster Prüfdurchgang gegen den Stand nach dem Developer-Lauf (Tests 20 + 15 grün). Alle acht ACs im Normalfall belegt. Beim Nachbohren im Fehlerpfad von `fetch` fand der Prüfer Finding F001 (HIGH): `error.read()` stand ungeschützt im `except HTTPError`-Zweig. Wirft das Lesen `IncompleteRead`, `ConnectionResetError` oder `TimeoutError`, stürzt `probe()` und damit der ganze Lauf ab, statt `(4xx, None)` zu liefern. Reproduziert mit einem gemockten `HTTPError`. Dazu F002 (LOW): `reason()` entfernte nur `\r`, `\n` und Anführungszeichen, andere Steuerzeichen blieben. Die Zeile in `store_routes` (`(200, PLACEMENTS) if placements is None else placements`) wurde bewertet: sie repariert eine doppelte Einpackung im RED-Test und höhlt keine Assertion aus. Verdict dieser Runde: BROKEN.
Code reference: scripts/asc_beta_probe.py:44
Code reference: scripts/test_asc_store_probe.py:166
**Implementierer:** F001 war an der Zeile sichtbar und reproduzierbar. Developer-Agent erst Test (rot vor dem Fix: 4 Fehler, einer je Ausnahme), dann Fix: `error.read()` in `try/except (OSError, http.client.HTTPException)`, bei Fehlschlag Fehlerrumpf `None`. F002 mit behoben: `reason()` übernimmt nur druckbare Zeichen.

### Runde 2
**Adversary:** Zweiter Durchgang gegen den neuen Stand (Tests 20 + 17 grün, alle weiteren `test_asc_*.py` grün, keine Regression). `IncompleteRead`, `ConnectionResetError`, `TimeoutError`, `OSError`, Nicht-UTF8-Bytes, `fp=None` und ein JSON-Array als Rumpf ergeben je `(404, None, None)` ohne Absturz. Die Wiederholungszweige für 5xx, 408, 429 und Netzfehler sind unverändert. `reason()` nimmt nie `detail` und kürzt auf 80 Zeichen. Der neue Test löst den Fehler mit einem echten `HTTPError` aus. Runde 2 an der Store-Probe (Platzierungen, Referenzdaten): kein Befund. Zwei LOW-Randfälle ohne Spec-Verletzung: F003 (eine direkt aus `read()` geworfene `ValueError` wäre nicht abgefangen, bei urllib praktisch nicht erreichbar) und F004 (bestehen `code` und `title` nur aus Steuerzeichen, entsteht ` grund=/`, kosmetisch). Beide nicht blockierend.
Code reference: scripts/asc_beta_probe.py:44
Code reference: scripts/asc_store_probe.py:56
Code reference: scripts/test_asc_beta_probe.py:308
Code reference: scripts/test_asc_store_probe.py:207
**Implementierer:** Bestätigt. Die beiden Randfälle sind kosmetisch beziehungsweise im realen Pfad nicht erreichbar und bleiben stehen.

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Einzige verdächtige Schreibstelle: der Fehlerrumpf in `fetch`. Bedingung davor: nur im 4xx-Zweig ohne Wiederholung (nicht 5xx, 408, 429). Test für diesen Weg: `test_unreadable_error_body_stays_a_finding` und `test_ask_prints_error_reason_and_never_detail`.

## Verdict

VERDICT: VERIFIED

Begründung: Alle acht ACs sind belegt. Tests: 20 (Store-Probe) und 17 (Beta-Probe) bestanden, alle weiteren `test_asc_*.py` bestanden, 0 fehlgeschlagen, 0 übersprungen. Der in Runde 1 gefundene Defekt F001 ist behoben und durch einen Test abgesichert. Offen bleiben nur F003 und F004 (LOW, kosmetisch, keine Spec-Verletzung).

## Geprüfte Dateien

- sha256:af3e0fed8650ff77bfae92218b509ad64619c03968629fcb8288c8fbe6494419  scripts/asc_beta_probe.py
- sha256:5d3cbfbf0b51c1a6f6f0547b176c34695261352617165110819165e8ed74b1ae  scripts/asc_store_probe.py
- sha256:d0b37a7f957170dd2d4257ba4da2abc00feaf37fa25e9d78de677809f919aa1f  scripts/test_asc_beta_probe.py
- sha256:4ba421ca6eb47bed9a763a1db3153e7b6e733048c9019be9495c1d79c2c2b0e8  scripts/test_asc_store_probe.py

## Prüfbasis

- base: f867cfee909049fe29e203c2a5cfc9e4cbde95fa
- blob:e6128a0040508c283d22cae57622f6d8c498ab11  scripts/asc_beta_probe.py
- blob:769623567e3d9f713fcdd0d9ef22e841cbb11584  scripts/asc_store_probe.py
- blob:ac390f8490614fdf8ef25307b54a7cc55ab47018  scripts/test_asc_beta_probe.py
- blob:4e13755a7173e71b2ce9342d2e4d29b654ceca48  scripts/test_asc_store_probe.py

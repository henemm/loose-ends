# Adversary Dialog — feat-837-store-untertitel
Spec: docs/specs/feat-837-schnitt-1-app-info-befund.md
Datum: 2026-11-04 19:43

## Checkliste
- [x] **AC-1:** Je App-Info eine Zeile `appinfo` mit `state` und `appStoreState` getrennt, fehlend = `?`. Bewiesen: Code und Test, Mutationen `merge_state` und `start0` gefangen.
- [x] **AC-2:** Attribut- und Relationsnamen sortiert, keine Werte. Bewiesen: Mutationen `nosort_attrs`, `nosort_rel` gefangen; fehlende Schlüssel liefern `felder= relationen=` ohne Absturz.
- [x] **AC-3:** Untertitelzeilen tragen `appinfo=<nr>`, App-Info ohne Lokalisierung meldet `keine`. Bewiesen (Mutation `keine_dropped` gefangen). Einschränkung F001: bei fehlgeschlagener Abfrage erscheint ebenfalls `keine`.
- [x] **AC-4:** Nur GET (Nachbau protokolliert alle Methoden, Test vergleicht die Menge), Zusammenfassung zuletzt. Einschränkung F002: der Zählerwert `von=` ist ungeprüft.
- [x] **AC-5:** Bewiesen vor dem Merge durch Handlauf asc-store-probe vom Branch, Lauf 41894624249 (siehe Runde 4).

## Dialog

### Runde 1
**Adversary:** `python3 scripts/test_asc_store_probe.py` ergibt 6 Tests OK (Ausgabe in adversary-test-output.txt). Sonderfälle gegen den Nachbau: (a) HTTP 500 auf appInfoLocalizations der App-Info 2: Probe druckt `zugriff ... http=keine`, danach `untertitel appinfo=2 keine`, Exit 0 (F001). (b) HTTP 500 auf appInfos: keine appinfo-Zeile, nichts Falsches, Exit 0. (c) appInfos leer: gar keine Zeile zu App-Infos, auch kein `appinfo keine` (F003). (d) fehlende `attributes`/`relationships`, `attributes: null`, `relationships` als Liste: `state=? appStoreState=? felder= relationen=`, kein Absturz. (e) Zeilenumbruch in Name oder Untertitel erzeugt eine gefälschte Zeile `appinfo nr=9 state=FAKE ...` im Log (F004; die appinfo-Zeile selbst druckt keine Werte).
**Implementierer:** (a) `records(None)` ist `[]`, daher der `keine`-Zweig; das `zugriff`-Protokoll zeigt den Fehler davor. (e) Name und Untertitel sind laut Spec Werte der Untertitelzeile.

### Runde 2
**Adversary:** Mutationen auf Kopien im Scratchpad (Original unverändert, Diffstat zeigt nur asc_store_probe.py). Überlebt haben: `summary_asked` (`von=999`), `keiner_label` (`keiner` ersetzt durch `x`), `locale_default`. Kein Test prüft also den Wert von `von=`, den Platzhalter `keiner` für leeren Untertitel (Kern der Probe ist zu sehen, ob einer gesetzt ist) und `?` bei fehlender Sprache. Gefangen: nosort_attrs, nosort_rel, zeichen_zero, merge_state, start0, keine_dropped. Sortierung durch Test 2, Nummerierung ab 1 durch Test 1 abgesichert. Zustandswerte werden roh gedruckt.
**Implementierer:** AC-1..AC-4 sind durch Tests belegt; die überlebenden Mutanten betreffen Nebenzusagen aus Implementation Details (Zähler run.asked zählt unverändert).

### Runde 3
**Adversary:** Diff gelesen und `python3 scripts/test_asc_store_probe.py` gelaufen: 9 Tests OK (Ausgabe in adversary-test-output.txt). Prüfung der Fixes, Code reference: scripts/asc_store_probe.py:39-45 (F001: `answer is None` gibt `untertitel appinfo=<nr> fehler` und `continue`; leere Antwort gibt `keine`), scripts/asc_store_probe.py:31-33 (F003: `appinfo keine` nur bei `body is not None` und leerer Liste; gescheiterter appInfos-Abruf druckt es nicht und stürzt nicht ab, `records(None)` ist leer), scripts/test_asc_store_probe.py:91 (fehler-Test mit Status 500), :96 (leerer Untertitel `keiner zeichen=0`), :101 (`appinfo keine`), :111-116 (festes `antworten=4 von=4 befunde=0`, letzte Zeile). Zähler `von=` bleibt `run.asked`, Zählpfad unverändert; der Schreibaufruf-Test (:106) vergleicht weiterhin die Methodenmenge, grün. Mutanten auf Kopien im Scratchpad: `von=999` gefangen, `keiner` zu `x` gefangen, `if answer is None` deaktiviert gefangen, `appinfo keine` entfernt gefangen. Damit sind die drei früher überlebenden Mutanten (summary_asked, keiner_label, Fehlerfall) gefangen. Überlebt: Platzhalter `?` für fehlende Sprache (locale-Default), kosmetisch, LOW, nicht Teil von AC-1..AC-4.
**Implementierer:** F001, F002, F003 behoben; F004 bewusst nicht.
**Ergebnis:** F001, F002, F003 geschlossen. F004 akzeptiert (LOW, Quelle ist der Eigentümer selbst). Keine neuen Fehler. AC-5 nach Merge per Handlauf zu vermerken.

### Runde 4
**Adversary:** AC-5 vor dem Merge belegt: Handlauf asc-store-probe vom Branch (Commit 4e51b0f), Lauf https://github.com/henemm/loose-ends/actions/runs/41894624249, Exit 0, antworten=17 von=17 befunde=0.
**Implementierer:** appinfo nr=1 state=READY_FOR_DISTRIBUTION appStoreState=READY_FOR_SALE; nr=2 state=IN_REVIEW appStoreState=IN_REVIEW; gleiche acht Feld- und neun Relationsnamen, kein Plattform- oder Versionsfeld; beide Untertitel noch „Gesagt. Sortiert.“. Befund für Schnitt 2: keine App-Info ist beschreibbar, Zuordnung zur iOS-Fassung 1.0.1 aus der App-Info allein nicht ablesbar.
Code reference: scripts/asc_store_probe.py:30

## Findings

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/asc_store_probe.py:37
  Description: Schlägt die Abfrage appInfoLocalizations fehl, liefert `ask` None, `records` ergibt eine leere Liste, und die Probe druckt `untertitel appinfo=<nr> keine`.
  Spec requirement: AC-3 — `keine` bedeutet "App-Info ohne Lokalisierung".
  Conflict: Ein Abfragefehler wird als Befund "keine Lokalisierung" ausgegeben; Schnitt 2 könnte darauf bauen. Das `zugriff`-Protokoll steht nur davor. Kein Test deckt den Fehlerfall.
  Remediation: Bei Antwort None `untertitel appinfo=<nr> fehler` drucken, Test mit Status 500.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: spec_violation
  Code reference: scripts/test_asc_store_probe.py:94
  Description: test_summary_line_still_present prüft nur Präfix und Einmaligkeit. Mutation von=run.asked zu von=999 überlebt; ebenso `keiner` zu `x` (Untertitel-Tests nutzen nur gefüllte Untertitel).
  Spec requirement: AC-4 / Implementation Details — Zähler run.asked zählt unverändert; `untertitel=keiner` bei leerem Untertitel.
  Conflict: Zwei Zusagen bleiben ungeprüft.
  Remediation: Test mit festem Wert `antworten=4 von=4 befunde=0` und ein Fall mit leerem Untertitel (`untertitel=keiner zeichen=0`).

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_store_probe.py:30
  Description: Leere appInfos-Liste erzeugt keine Zeile; vom Abfragefehler nur über `zugriff` unterscheidbar.
  Spec requirement: AC-5 — Befund für Schnitt 2.
  Conflict: Mehrdeutiges Protokoll, ungetestet.
  Remediation: `appinfo keine` drucken.

Finding:
  ID: F004
  Severity: LOW
  Category: security
  Code reference: scripts/asc_store_probe.py:42
  Description: Name und Untertitel werden roh gedruckt; ein Zeilenumbruch im Wert fälscht Protokollzeilen.
  Spec requirement: Werte nur in Untertitelzeilen.
  Conflict: Kein Schutz; Quelle ist Henning selbst, daher gering.
  Remediation: Zeilenumbrüche ersetzen oder repr() nutzen.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: scripts/asc_store_probe.py:33
  Evidence: `state` und `appStoreState` je eigener Zugriff mit Rückfall `?`; Test scripts/test_asc_store_probe.py:61 prüft beide Seiten.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/test_asc_store_probe.py:68
  Evidence: sorted(attrs), sorted(relations); Mutationen ohne sorted fallen durch; Werte werden nicht gedruckt.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/asc_store_probe.py:38
  Evidence: `appinfo=<number>` in Zeile 42, `keine` in Zeile 38; Tests scripts/test_asc_store_probe.py:75 und :85.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/test_asc_store_probe.py:89
  Evidence: Nachbau erfasst Methoden, Test verlangt nur GET; Zusammenfassung in scripts/asc_store_probe.py:70 letzte Zeile (Test :94).
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

**VERIFIED**

## Geprüfte Dateien

- sha256:c8a9af52a68c7d1ce84c8c2bbc3532cd559bd8ba8dac5cbbb87787d6e815f63f  scripts/asc_store_probe.py
- sha256:622e305fa0e7effd6fca66eac265fa635ebb0ac924c02aae33d412484bf94192  scripts/test_asc_store_probe.py

## Prüfbasis

- base: 1d0ad24192c2cf550d9d8589bb9bf756d918f461
- blob:b9b14c4c73155088345b53c36b472146b0dec824  scripts/asc_store_probe.py
- blob:5dcfedf34422a15e4a66a9b64e8faf8178d77f35  scripts/test_asc_store_probe.py

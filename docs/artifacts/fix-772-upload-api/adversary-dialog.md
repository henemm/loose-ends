# Adversary Dialog — fix-772-upload-api
Spec: docs/specs/fix-772-upload-api.md
Datum: 2026-11-02 20:10

## Checkliste
- [x] **Input:** `lesen` oder `hochladen`, ASC-Secrets, `docs/store/header/manifest.json`. (main: scripts/asc_header_upload.py:192-207)
- [x] **Output `lesen`:** rohe Spec-Daten und Bibliothekszustand, keine Schreibaufrufe. (eigener Lauf: Ausgabe zeigt refdata-Felder, specs, Platzierungstypen, Bibliothek; client.writes()==[])
- [x] **Output `hochladen`:** je zulässigem Bild ein Bild im Zustand `PREPARE_FOR_SUBMISSION`, Meldung für jedes nicht zulässige Bild.
- [x] **Side effects:** Bilder im Konto bei Apple (nicht öffentlich). Version 1.0 und ihre Prüfung bleiben unberührt. (einzige Schreibstellen: POST/PUT/PATCH auf appAssetLibraryImages, Zeilen 72-101)
- [x] **AC-1:** Referenzdaten per `GET /v1/appAssetLibraryRefData/1` (REFDATA, Zeile 22/79/123)
- [x] **AC-2:** Spannen inklusive, Platzierungstyp, Kategorie aus placementTypes (Zeilen 33-51)
- [x] **AC-3:** Abbruch vor erstem Schreiben, nennt Specs (Zeilen 80-84)
- [x] **AC-4:** Teilpassung: Warnung mit Name und Maß, nie angelegt (Zeilen 85-91)
- [x] **AC-5:** Bibliothek-id, Unterpfad, Beziehung `assetLibrary` (Zeilen 88-90, 97)
- [x] **AC-6:** gleiche `referenceName` wird nicht neu angelegt (Zeilen 89, 93-95)
- [x] **AC-7:** nie Platzierung/Einreichung (Skript enthält keinen Schreibpfad außer IMAGES)
- [x] **AC-8:** Warten endet bei READY, bricht bei FAILED sofort mit stateDetails (Zeilen 54-63)
- [x] **AC-9:** Zustandscheck „bereit“ nur ohne Platzierung und mit READY (Zeilen 107-118)
- [x] **AC-10:** `lesen` gibt Specs, Kategorien, Bilder mit Zustand, Platzierungszahl aus, nur GET (Zeilen 121-136)

## Dialog

### Runde 1
**Adversary:** Voller Testlauf: 10 Tests, OK (adversary-test-output.txt). Eigene Sonden (nicht die Repo-Tests):
(a) grep über das Skript: Schreibaufrufe nur `client.post/put/patch` in `upload` (Z. 72-101); `lesen` und `check_state` rufen nur `get`. `Client` kennt kein DELETE. Vor dem Spec-Abgleich (Z. 79-84) nur GET REFDATA. Kein Schreibpfad bei `lesen`.
(b) Grenzen: Spanne 10-20 x 5-8: (10,5) und (20,8) passen; (9,5), (21,8), (10,4), (10,9) nicht. Fehlende Felder: `{}`, leere Liste, fehlende `dimensions`, `dimensions: None`, `placementTypes: None`, `acceptsAssetCategories: []` ergeben alle "keine Treffer", kein Absturz. Keine akzeptierte Kategorie: Fatal ohne Schreibaufruf (writes == []). Die Meldung lautet dann aber "Keine Spec ...; vorhanden: S169 ...", obwohl die Spec passt; die wahre Ursache (Platzierungstyp ohne Kategorie) wird nicht genannt (F002, LOW).
(c) Teilpassung: Test und Logik: nicht passende Datei wird in `fitting` nicht aufgenommen (Z. 91), also nie POSTed; Warnung mit Name und `5244x2950`.
(e) FAILED ohne stateDetails: Meldung "Bild A ist FAILED: ?", sauber.
(f) Ausgaben: print-Stellen (grep) geben nur Namen, Maße, Zustände aus; Token nur im Authorization-Header (Z. 161-162), HTTP-Fehler zeigen Methode und URL ohne Query.
(g) Platzierungen: nur GET `.../placements`; der String `appAssetLibraryPlacements` kommt nicht vor.
(h) Attrappe: Pfade (RefData/1, apps/{id}/assetLibrary, appAssetLibraries/{id}/images, appAssetLibraryImages/{id}/placements), dimensions-Spannen, placementTypes, FAILED+stateDetails entsprechen der Tabelle in docs/context/fix-772-upload-api.md; unbekannte Pfade lösen AssertionError aus. Es ist nicht mehr die alte Form. Schwäche: die Attrappe ersetzt den gesamten `Client`, die JSON:API-Hülle (type/attributes/relationships, flat) wird von keinem Test geprüft (F003, LOW). Ich habe sie von Hand geprüft: POST sendet type=appAssetLibraryImages mit attributes und relationships, PATCH sendet type, id, attributes; korrekt.
**Implementierer:** (keiner, Prüfauftrag)

### Runde 2
**Adversary:** Nachgebohrt bei (d), dem knappsten Punkt. Ein vorhandenes Bild mit gleicher referenceName im Zustand AWAITING_UPLOAD (z. B. nach Abbruch zwischen POST und PATCH) wird übersprungen ("schon vorhanden") und nicht fertig hochgeladen oder abgewartet; `check_state` bricht dann mit Fatal "ist AWAITING_UPLOAD" ab (Probe: writes == []). Es wird also nichts übersehen (laut Fehler), aber der Lauf kommt nie zum Ziel, solange das Bild so hängt; ein erneuter Lauf heilt nichts (F001, MEDIUM, über die Spec hinaus). Ebenso UPLOAD_COMPLETE: sofortiger Fatal, statt kurz zu warten. Das ist kein Verstoß gegen AC-6 (nicht neu anlegen), widerspricht aber dem Ziel "je zulässigem Bild PREPARE_FOR_SUBMISSION" im Wiederholungsfall. Weiter: Bilderliste ohne Seitenbehandlung (Z. 89, 109): bei mehr Bildern als die Standard-Seitengröße würde eine vorhandene referenceName übersehen und doppelt angelegt (F004, LOW; bei 4 Bildern praktisch irrelevant). `lesen` ruft bei fehlender Bibliothek-id `/appAssetLibraries/None/images` (nur GET, F005, LOW). Tests nochmal bewusst anders gelesen: `test_wait...` prüft "<5 Aufrufe nach FAILED" (schwach, aber der Code bricht bei Z. 60 sofort ab, belegt durch Lesen). Keine Spezifikationsverletzung gefunden.
**Implementierer:** (keiner, Prüfauftrag)

## Findings
Finding F001: Severity MEDIUM, Category edge_case. 
  Code reference: scripts/asc_header_upload.py:93 Beim Überspringen eines vorhandenen Bildes wird dessen Zustand nicht beachtet; ein halbfertiges Bild (AWAITING_UPLOAD/UPLOAD_COMPLETE) wird nicht fortgesetzt oder abgewartet, check_state (Z. 113) bricht mit Fatal ab. Spec requirement: AC-6 / Expected Behavior (nur nicht neu anlegen; Ziel PREPARE_FOR_SUBMISSION). Remediation: bei UPLOAD_COMPLETE wait_ready aufrufen; bei AWAITING_UPLOAD mit klarer Meldung (manuell löschen) oder Bytes erneut senden.
Finding F002: LOW, edge_case. 
  Code reference: scripts/asc_header_upload.py:47 Ohne akzeptierte Kategorie gilt die Datei als "keine Spec"; Meldung nennt Kategorie-Mangel nicht. Remediation: eigene Meldung.
Finding F003: LOW, anti_pattern. Code reference: scripts/test_asc_header_upload.py:42 FakeClient ersetzt Client vollständig; JSON:API-Hülle, flat und PUT-Header ungetestet. Remediation: ein Test mit gepatchtem Client.api/send.
Finding F004: LOW, edge_case. 
  Code reference: scripts/asc_header_upload.py:89 Keine Seitenbehandlung bei Bilderliste.
Finding F005: LOW, edge_case. 
  Code reference: scripts/asc_header_upload.py:132 `lesen` fragt bei fehlender Bibliothek-id den Pfad mit "None".

## Confirmations
Confirmation:
  AC: AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8, AC-9, AC-10
  Code reference: scripts/asc_header_upload.py:79
  Evidence: REFDATA-Einzeldatensatz, Spannen-Abgleich, Abbruch vor Schreiben, Bibliothek-id, Zustandscheck, lesen nur GET (eigene Sonden, Runde 1 und 2)
  Status: CONFIRMED
Confirmation:
  AC: AC-1 bis AC-10 (Tests)
  Code reference: scripts/test_asc_header_upload.py:54
  Evidence: Attrappe in Apples dokumentierter Form, 10/10 Tests grün im eigenen Lauf
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

Tests: 10 passed, 0 failed, 0 übersprungen (adversary-test-output.txt). AC-1 bis AC-10 und Expected Behavior: 14/14 bewiesen. Offene Befunde ohne Spec-Verstoß: F001 (MEDIUM, empfohlen vor dem echten Lauf zu beheben), F002 bis F005 (LOW).

## Geprüfte Dateien

- sha256:fb00e154de079cdffd03d07e6c1e0e015dcd636cb6b7072bfaf3e6f1d75d1db3  scripts/asc_header_upload.py
- sha256:897c1ff59a1c197a2740ed5c0d42b9fe0b9a827b2de337b874efa7f205b8ac78  scripts/test_asc_header_upload.py

## Prüfbasis

- base: 32cc83654f32443e6baadc40e4360263cced6902
- blob:834a792c134539993ad1a537f96e7dd3e86547f8  scripts/asc_header_upload.py
- blob:c5d1a99f57ed464fd0c3602e27ef726e3f5bc28d  scripts/test_asc_header_upload.py

---
entity_id: feat-772-kopfbild
type: module
created: 2026-11-02
updated: 2026-11-02
status: draft
version: "1.0"
tags: [store, app-store-connect, kopfbild]
---

# Kopfbild für den App Store (#772)

## Approval

- [ ] Approved

## Purpose

Für Apples Hervorhebung auf der Produktseite wird ein Kopfbild gebraucht: Logo mit Faden, Slogan, Startseite der App,
in Hell und Dunkel, in beiden Apple-Größen. Es wird deterministisch gezeichnet, im Repo abgelegt und in die Asset-Bibliothek
bei Apple hochgeladen, **ohne** es zu platzieren oder zur Prüfung einzureichen (das braucht Hennings Wort).

## Source

- **File:** `scripts/store_header.py` (Zeichnen), `scripts/asc_header_upload.py` (Upload)
- **Identifier:** `draw(variant, size)`, `upload(...)`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `docs/design/logo/` | Quelle | Faden-Trochoide (a = 90, b = 230, t −3,5…3,0), Petrol `#0F6E73` / `#5FC4C9` |
| `docs/store/screenshots/de/iphone/01-start.png` | Quelle | echte Startseite der App für die rechte Bildhälfte |
| `docs/artifacts/772-kopfbild/vorschau.html` | Entwurf | von Henning am 2026-11-02 freigegebene Variante C |
| `scripts/asc_store_probe.py` | Muster | ASC-Client (JWT, `find_app_id`) |
| `.github/workflows/asc-store-probe.yml` | Muster | Hand-Workflow mit ASC-Secrets |
| Pillow | Werkzeug | Rastern der Kurve und der Schrift (nur Zeichenskript, kein App-Code) |

## Scope

- **Affected Files:** `scripts/store_header.py`, `scripts/test_store_header.py`, `docs/store/header/*.png` + `manifest.json`,
  `scripts/asc_header_upload.py` + `scripts/test_asc_header_upload.py`, `.github/workflows/asc-header-upload.yml`
- **Estimated Changes:** ~+250 LoC ohne Bilder (Zeichnen ~90, Upload ~90, Tests ~70). Wird das Limit überschritten,
  wird der Upload (Teil B) ein zweiter Schnitt.
- Kein App-Code, kein Pfad der Geräteliste, keine gemeinsame Stelle (`project.yml`, `*.xcstrings`, `CLAUDE.md`, Schema).

## Implementation Details

**Teil A — Bilder**

- Variante C „Petrol mit App-Ansicht“: links Faden und „Loose Ends“ mit dem Slogan **„Sag es, und es ist sortiert.“**,
  rechts die Startseite aus `01-start.png` in einem leicht abgesetzten Rahmen.
- Hell: Fläche `#0F6E73`, Faden und Schrift `#F4F3EE`. Dunkel: Fläche `#101819`, Faden `#5FC4C9`, Schrift `#F4F3EE`.
  Die App-Ansicht bleibt in beiden dieselbe (es gibt nur das helle Store-Bild).
- Zwei Größen je Aussehen: universell 16:9 = 5244 × 2950 (PNG) und Kopfzeile 21:9 = 3840 × 1646 (PNG). Vier Dateien
  `docs/store/header/{hell,dunkel}-{16x9,21x9}.png`, dazu `manifest.json` (Datei, Maße, SHA-256).
- Die Kurve folgt der Logo-Formel, kein Eigenbild. Ausgabe als RGB, **kein Alphakanal**.
- Zuschnitt: Logo, Slogan und App-Ansicht liegen im mittleren Bereich, der in beiden Formaten und in der 3:2-Suchkarte
  sichtbar bleibt (Rand ≥ 12 % je Seite, Apple nennt keine Sicherheitsränder). 21:9 ist dasselbe Motiv mit eigener Anordnung,
  kein Beschnitt des 16:9-Bildes.

**Teil B — Upload (nur Asset-Bibliothek)**

1. Referenzdaten lesen: `GET /v1/apps/{id}/assetLibrary`, `GET /v1/appAssetLibraryRefData`. Aus `imageSpecs` kommen
   `category` und Maße für Kopfbilder; passt keine Spec zu den vier Dateien, bricht der Lauf mit der Liste ab, ohne zu schreiben.
2. Je Datei `POST /v1/appAssetLibraryImages` (`fileName`, `fileSize`, `category`, `referenceName`), Bytes hochladen,
   `PATCH` mit `uploaded: true`, warten bis `PREPARE_FOR_SUBMISSION`.
3. **Nie** `appAssetLibraryPlacements`, nie eine Einreichung. Das Skript enthält diese Aufrufe nicht.
4. Lauf als Hand-Workflow (`workflow_dispatch`) mit den ASC-Secrets, Eingabe `aktion` = `lesen` (nur Referenzdaten) oder
   `hochladen`. Bereits hochgeladene Bilder (gleiche `referenceName`) werden nicht doppelt angelegt.

## Expected Behavior

- **Input:** Logo-Formel, Startseiten-Bild, Slogan.
- **Output:** vier PNG im Repo, nach `aktion=hochladen` vier Bilder in der Asset-Bibliothek im Zustand `PREPARE_FOR_SUBMISSION`.
- **Side effects:** Inhalt liegt im Konto bei Apple (nicht öffentlich). Version 1.0 und ihre Prüfung bleiben unberührt.

## Known Limitations

- Ob die Kategorie für Kopfbilder eine eigene ist, zeigt erst `appAssetLibraryRefData`; Teil B beginnt daher mit `aktion=lesen`.
- Das dunkle Bild zeigt die helle App-Ansicht (kein dunkles Store-Bild vorhanden).
- Ob Apple das Bild sichtbar anzeigt, entscheidet sich erst bei der Hervorhebung; das lässt sich nicht automatisch prüfen.
- Platzieren und Einreichen: ausdrücklich nicht Teil dieses Tickets.

## Definition of Done

Fertig ist diese Änderung, wenn:

- [ ] Jede Acceptance Criterion unten ist durch einen automatischen Test belegt
- [ ] Vier Kopfbilder in den Apple-Maßen liegen unter `docs/store/header/`, hell und dunkel, ohne Alphakanal
- [ ] Die gezeichneten Bilder wurden geöffnet und angesehen (Faden, Slogan, App-Ansicht lesbar, Mitte frei)
- [ ] Die vier Bilder stehen in Apples Asset-Bibliothek im Zustand „bereit zur Einreichung“, nichts ist platziert oder eingereicht
- [ ] Keine bestehende Funktion ist dabei kaputtgegangen (Regressionslauf grün)

## Acceptance Criteria

- **AC-1:** Given das Zeichenskript / When es läuft / Then liegen vier PNG mit exakt 5244 × 2950 und 3840 × 1646 je in Hell und Dunkel unter `docs/store/header/`, und das Manifest nennt Datei, Maße und SHA-256 jeder Datei
  - Test: `scripts/test_store_header.py::test_sizes_and_manifest`
- **AC-2:** Given ein erzeugtes Kopfbild / When es geöffnet wird / Then hat es keinen Alphakanal (Modus RGB, keine Transparenz)
  - Test: `scripts/test_store_header.py::test_no_alpha`
- **AC-3:** Given das helle und das dunkle Bild / When die Randpixel und der Faden gelesen werden / Then ist die Fläche hell `#0F6E73`, dunkel `#101819` und der Faden hell `#F4F3EE`, dunkel `#5FC4C9`
  - Test: `scripts/test_store_header.py::test_colors_light_and_dark`
- **AC-4:** Given beide Formate / When die Ränder geprüft werden / Then bleiben die äußeren 12 % je Seite reine Flächenfarbe (Logo, Slogan und App-Ansicht liegen innerhalb)
  - Test: `scripts/test_store_header.py::test_safe_margin_is_empty`
- **AC-5:** Given zweimal derselbe Lauf / When die Bilder verglichen werden / Then sind sie byte-gleich (deterministisch, kein Modell, keine Zeit im Bild)
  - Test: `scripts/test_store_header.py::test_deterministic`
- **AC-6:** Given Referenzdaten ohne passende Spec für eine Datei / When `upload` läuft / Then bricht es vor dem ersten Schreibaufruf ab und nennt die vorhandenen Specs
  - Test: `scripts/test_asc_header_upload.py::test_stops_without_matching_spec`
- **AC-7:** Given ein vollständiger Lauf gegen einen Attrappen-Client / When `upload` endet / Then gab es je Datei Anlegen, Hochladen und `uploaded: true`, aber **keinen** Aufruf an `appAssetLibraryPlacements` und keine Einreichung
  - Test: `scripts/test_asc_header_upload.py::test_never_places_or_submits`
- **AC-8:** Given ein Bild mit gleicher `referenceName` ist schon in der Bibliothek / When `upload` läuft / Then wird es nicht noch einmal angelegt
  - Test: `scripts/test_asc_header_upload.py::test_skips_existing_reference_name`
- **AC-9:** Given die Antwort der Asset-Bibliothek mit den vier Bildern / When der Zustandscheck des Skripts sie auswertet / Then meldet er „bereit“ nur, wenn alle vier `PREPARE_FOR_SUBMISSION` tragen und keine Platzierung existiert; ein Bild in `AWAITING_UPLOAD` oder eine vorhandene Platzierung meldet er als Fehler
  - Test: `scripts/test_asc_header_upload.py::test_state_check_reads_ready_state`
  - Der echte Lauf `aktion=hochladen` ruft denselben Check auf und steht als zusätzlicher Beleg im Workflow-Protokoll (einmalig, nach Hennings Freigabe der Bilder).

## Test Plan

Automatische Tests (jeweils an eine AC oben gebunden):
- `python3 -m unittest scripts/test_store_header.py` (AC-1 bis AC-5)
- `python3 -m unittest scripts/test_asc_header_upload.py` (AC-6 bis AC-9)

Abnahme: Stufe 2 heißt hier: Bilder öffnen und beschreiben, dann Lauf `lesen`, dann `hochladen`. Kein App-Lauf nötig:
„Kein Pfad der Geräteliste berührt.“ Henning bekommt nichts zu tun.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Store-Asset ohne Änderung der App-Architektur; Regelweg (deterministisch gezeichnet), kein Modell.
- **Rationale:** Store-Asset ohne Änderung der App-Architektur; deterministisch gezeichnet, kein Modell.
- **Alternative geprüft:** Verzicht bis zur Bewerbung um Hervorhebung (kippt keine ADR, verschiebt nur den Entwurf). Gewählt wird das Bild jetzt, weil Henning Variante C freigegeben hat.

## Changelog

- 2026-11-02: Initial spec created

# Adversary Dialog — feat-772-kopfbild
Spec: docs/specs/feat-772-kopfbild.md
Datum: 2026-11-02 17:09

## Checkliste
- [x] **Input:** Logo-Formel, Startseiten-Bild, Slogan.
- [x] **Output:** vier PNG im Repo, nach `aktion=hochladen` vier Bilder in der Asset-Bibliothek im Zustand `PREPARE_FOR_SUBMISSION`.
- [x] **Side effects:** Inhalt liegt im Konto bei Apple (nicht öffentlich). Version 1.0 und ihre Prüfung bleiben unberührt.
- [x] **AC-1:** Given das Zeichenskript / When es läuft / Then liegen vier PNG mit exakt 5244 × 2950 und 3840 × 1646 je in Hell und Dunkel unter `docs/store/header/`, und das Manifest nennt Datei, Maße und SHA-256 jeder Datei
- [x] **AC-2:** Given ein erzeugtes Kopfbild / When es geöffnet wird / Then hat es keinen Alphakanal (Modus RGB, keine Transparenz)
- [x] **AC-3:** Given das helle und das dunkle Bild / When die Randpixel und der Faden gelesen werden / Then ist die Fläche hell `#0F6E73`, dunkel `#101819` und der Faden hell `#F4F3EE`, dunkel `#5FC4C9`
- [x] **AC-4:** Given beide Formate / When die Ränder geprüft werden / Then bleiben die äußeren 12 % je Seite reine Flächenfarbe (Logo, Slogan und App-Ansicht liegen innerhalb)
- [x] **AC-5:** Given zweimal derselbe Lauf / When die Bilder verglichen werden / Then sind sie byte-gleich (deterministisch, kein Modell, keine Zeit im Bild)
- [x] **AC-6:** Given Referenzdaten ohne passende Spec für eine Datei / When `upload` läuft / Then bricht es vor dem ersten Schreibaufruf ab und nennt die vorhandenen Specs
- [x] **AC-7:** Given ein vollständiger Lauf gegen einen Attrappen-Client / When `upload` endet / Then gab es je Datei Anlegen, Hochladen und `uploaded: true`, aber **keinen** Aufruf an `appAssetLibraryPlacements` und keine Einreichung
- [x] **AC-8:** Given ein Bild mit gleicher `referenceName` ist schon in der Bibliothek / When `upload` läuft / Then wird es nicht noch einmal angelegt
- [x] **AC-9:** Given die Antwort der Asset-Bibliothek mit den vier Bildern / When der Zustandscheck des Skripts sie auswertet / Then meldet er „bereit“ nur, wenn alle vier `PREPARE_FOR_SUBMISSION` tragen und keine Platzierung existiert; ein Bild in `AWAITING_UPLOAD` oder eine vorhandene Platzierung meldet er als Fehler

## Dialog

### Runde 1
**Adversary:** Beweise gesammelt. Tests: `python3 -m unittest scripts/test_store_header.py scripts/test_asc_header_upload.py -v` = 9 Tests OK; Vollsuite `discover -s scripts` = 484 Tests OK (Ausgabe in docs/artifacts/feat-772-kopfbild/adversary-test-output.txt). Eigene Proben ausserhalb der Tests:
- (a) Eingecheckte Bilder gegen manifest.json: SHA-256 aller 4 stimmt, Modus RGB, kein Alpha, keine PNG-Metadaten, Masse 5244x2950 / 3840x1646 exakt.
- (b) Aeussere 12 % je Seite der eingecheckten Bilder: 0 abweichende Pixel in allen 4 (Inhalt x 0.227 bis 0.85, y 0.16 bis 0.854).
- (g) Skript in Temp-Ordner laufen lassen: alle 4 SHA-256 identisch mit manifest.json.
- Bild hell-21x9.png geoeffnet: Faden, Name, Slogan lesbar links, App-Startseite gekippt rechts, Raender und Mitte frei.
- (c) Grep nach placement/submission: nur Lese-/Pruefstellen (check_state, Client.get, lesen-Ausgabe) und der Zustandsname PREPARE_FOR_SUBMISSION; kein Schreibaufruf an Platzierungen, keine reviewSubmissions oder appStoreVersionSubmissions, im Workflow nichts davon.
- (e) Workflow: nur workflow_dispatch, Standard lesen, Secrets exakt wie asc-store-probe.yml (env, printf in 0600-Datei, trap rm), permissions contents read, kein Echo von Secrets.
- (f) Upload-Operationen: Ausschnitt data[offset:offset+length], requestHeaders als Dict, kein Authorization-Header an die Upload-URL; Fehler werden zu Fatal (HTTPError, URLError, OSError), kein blankes except.
- (d) Vor dem ersten Schreibaufruf nur GET assetLibrary, GET refData und match_specs (Fatal mit Spec-Liste); erst danach POST.
Schwachstellen: (1) Teil-Zustand: ein Bild in AWAITING_UPLOAD wird wegen gleicher referenceName uebersprungen, am Ende meldet check_state Fatal. (2) Eine fehlende PNG-Datei faellt erst im Schreibloop auf (FileNotFoundError); manifest-SHA wird vor Upload nicht gegen die Datei geprueft.
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Nachgebohrt auf (1) und (2).
- (1) Spec-konform: AC-8 verlangt Nicht-Doppelanlegen, AC-9 Fehler bei AWAITING_UPLOAD; beides geschieht, kein stilles bereit, keine Doppelanlage. Nachteil: ein abgebrochenes Bild wird nicht fortgesetzt, Aufraeumen von Hand in ASC. Fuer eine Hand-Aktion akzeptabel.
- (2) Alle Dateien sind eingecheckt und per Probe konsistent; Fehlerfall nur bei kaputtem Repo-Stand; schreibt nie ausserhalb der Asset-Bibliothek.
- wait_ready bricht nach 40 Abfragen mit Fatal ab; Ausgaben enthalten weder Token noch Schluessel; ci.yml installiert pillow im Wegwerf-Venv.
- Nicht automatisch pruefbar: reale ASC-Antwortform der Asset-Bibliothek (Endpunkte stammen aus der Spec); das klaert der Lauf lesen, deshalb ist lesen Standard.

### Findings
Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/asc_header_upload.py:55
  Description: Vorhandene referenceName wird uebersprungen, auch wenn das Bild in AWAITING_UPLOAD haengt.
  Spec requirement: AC-8/AC-9
  Conflict: Kein Verstoss; Wiederholungslauf kann ein abgebrochenes Bild nicht fortsetzen.
  Remediation: Optional bei AWAITING_UPLOAD nachhochladen oder Fehlermeldung mit Aufraeum-Hinweis.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_header_upload.py:58
  Description: Bytes werden erst im Schreibloop gelesen; manifest-SHA wird nicht gegen die Datei geprueft.
  Spec requirement: Expected Behavior (Side effects)
  Conflict: Fehlende Datei fuehrt nach ersten Schreibaufrufen zu FileNotFoundError.
  Remediation: Dateien und SHA vor dem ersten Schreibaufruf pruefen.

### Confirmations
Confirmation:
  AC: AC-1
  Code reference: scripts/store_header.py:143
  Evidence: build() schreibt 4 PNG und manifest.json; Masse und SHA der eingecheckten Dateien stimmen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/store_header.py:104
  Evidence: Image.new mit RGB; Probe: Modus RGB, info leer.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/store_header.py:20
  Evidence: VARIANTS-Farben exakt; test_colors_light_and_dark gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/store_header.py:25
  Evidence: inset 14 %; Probe: 0 abweichende Pixel im 12-%-Rand der eingecheckten Bilder.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/store_header.py:150
  Evidence: feste PNG-Parameter; Neulauf liefert identische SHA-256 wie manifest.json.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/asc_header_upload.py:26
  Evidence: match_specs wirft Fatal mit Spec-Liste, in upload() Zeile 52 vor jedem POST; Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/asc_header_upload.py:48
  Evidence: upload() ruft nur Bild-Endpunkte auf; kein Platzierungs- oder Einreichungsaufruf; Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/asc_header_upload.py:53
  Evidence: existing-Menge aus referenceName, Skip in Zeile 55; Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/asc_header_upload.py:75
  Evidence: check_state: Fatal bei Platzierung, fehlendem Bild oder Zustand ungleich PREPARE_FOR_SUBMISSION; Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: Workflow
  Code reference: .github/workflows/asc-header-upload.yml:5
  Evidence: nur workflow_dispatch, Standard lesen, Secrets wie Muster.
  Status: CONFIRMED

Confirmation:
  AC: CI
  Code reference: .github/workflows/ci.yml:33
  Evidence: pillow~=12.0 im Wegwerf-Venv.
  Status: CONFIRMED

Confirmation:
  AC: Manifest
  Code reference: docs/store/header/manifest.json:1
  Evidence: SHA und Masse stimmen mit den Dateien.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: 9 passed (Ziel), 484 passed (Vollsuite), 0 failed, 0 uebersprungen

## Geprüfte Dateien

- sha256:023d789fb11dd5167c071a8bba667bbd0d922eedbae4e7621c271f4785c36aee  .github/workflows/asc-header-upload.yml
- sha256:421de6bca7199f6d611fe5c4f59876983c782b11e185723157ac6107ebfbbe87  .github/workflows/ci.yml
- sha256:324c9a88acd143bec85b69b8e4b80b49648327c3ae06fea6ddf72952bec39fba  docs/store/header/manifest.json
- sha256:00da1c68e4b44000ad03395519a388a9a5a214790b8fad8b8a29e2416a873db9  scripts/asc_header_upload.py
- sha256:9ca002e523af079391bdb9de35e95caa6de6cedaab149bbbff2820818b4d1242  scripts/store_header.py

## Prüfbasis

- base: 88ff20aabf2189977f5a2d8a2f50821cae1b0a1e
- blob:0d0eb09c13ba09417546e766f4357fbacc9bf00a  .github/workflows/asc-header-upload.yml
- blob:ece02fd1dea8bda7dbf4ae797b0426ecfaa102fa  .github/workflows/ci.yml
- blob:0c1ca06883c3621c24587de0a1499c3a4c44ec92  docs/store/header/manifest.json
- blob:6a4a42509cead1db49651e7a669efdcb3512f3db  scripts/asc_header_upload.py
- blob:dd36288fc6214c58321a14bbc57fb42db713c736  scripts/store_header.py

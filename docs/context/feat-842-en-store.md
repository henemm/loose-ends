# Context: feat-842-en-store

## Request Summary
Ticket #842 (Folge aus #837): Die englische Store-Seite in App Store Connect (ASC) fehlt. Apple lässt eine Version nur einreichen,
wenn App-Info und Version dieselben Lokalisierungen haben; die App-Info hat seit #837 en-US, die Version 1.0.1 noch nichts
Gefülltes. Gebraucht: englische Beschreibung, eigene Schlüsselwörter (≤ 100 Zeichen), Support-URL, optional Werbetext, englische
Store-Bilder (iPhone, iPad, Watch, Mac); Schreibweg wie #742/#837, Beleg = Werte aus ASC; Henning gibt den Wortlaut frei.

## Stand in App Store Connect (Lese-Probe `asc-store-probe.yml`, Lauf 42217843959, 2026-11-06 12:27Z)
- App-Info 1 (`READY_FOR_DISTRIBUTION`): de-DE, „Gesagt. Sortiert.“ (alt).
- App-Info 2 (`PREPARE_FOR_SUBMISSION`, **jetzt bearbeitbar**, Mac 1.0 ist `READY_FOR_SALE`): en-US „Loose Ends: Voice Tasks“ /
  „Say it. Clear your head.“ (#837 hat den Namen mit Zusatz durchgebracht), de-DE „Einfach sagen. Kopf frei.“.
- Version iOS 1.0.1 (`PREPARE_FOR_SUBMISSION`): Versions-Lokalisierung **en-US existiert bereits, ohne Bildsätze**
  (`bildsatz keine … sprache=en-US`); de-DE hat iPad 5, iPhone 5, Watch 2.
- Version macOS 1.0 (`READY_FOR_SALE`): nur de-DE, `APP_DESKTOP` 4 Bilder. Eine „nächste Mac-Version“ gibt es noch nicht (DoD-Punkt 1
  hängt daran, bis sie existiert).
- Die Probe liest von der Versions-Lokalisierung nur Sprache und Bildsätze, **nicht** Beschreibung, Schlüsselwörter, Support-URL,
  Werbetext. Was dort heute steht (de wie en), ist unbekannt und muss vor der Analyse gelesen werden.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_store_probe.py` | Nur-GET-Probe; muss um Beschreibung/Schlüsselwörter/Support-URL/Werbetext erweitert werden, damit der Beleg „Werte aus ASC“ möglich ist |
| `.github/workflows/asc-store-probe.yml` | Handlauf der Probe (Secrets nur in der CI; lokal gesperrt) |
| `scripts/asc_app_info.py` + `test_asc_app_info.py` | Vorbild für den Schreibweg: `wanted_texts` aus einer Markdown-Datei, `asc_locales()` für die Sprachen, schreibt nur bei Abweichung, Gegenprobe, `Fatal` bei Sperre |
| `.github/workflows/asc-app-info.yml` | Vorbild für den Handlauf (`aktion=lesen|…`, Unit-Tests vor dem Lauf) |
| `docs/reference/app-store-untertitel.md` | Vorbild für die Textdatei je Sprache (`## de-DE`, `## en-US`); der neue Text braucht eine eigene Datei, Henning gibt den Wortlaut frei |
| `scripts/asc_locales.py` | Sprachcode → ASC-Locale (`de`→`de-DE`, `en`→`en-US`); Quelle `LanguagePacks.shipped` |
| `scripts/asc_beta_setup.py` | Hat schon `PRIVACY_URL_EN` (`…/privacy-policy-en/`) und schreibt Beta-Lokalisierungen; Muster für Locale-Anlegen |
| `scripts/asc_wait_build.py`, `asc_what_to_test.py`, `asc_beta_probe.py` | Gemeinsame Bausteine: `read_config`, `find_app_id`, `get_data`, `send_json`, `Fatal`, `records`, `attributes` |
| `scripts/asc_header_upload.py` | Einziger Bild-Upload-Code (Kopfbilder, Asset-Bibliothek: reserve → PUT → commit); Bausteine für `appScreenshots` nutzbar, aber `appScreenshots` werden bisher nirgends per Skript geschrieben (Henning lud die de-Bilder per Claude Desktop hoch, #742) |
| `scripts/store_screenshots.py`, `sim.sh` (`cmd_store_screenshots`, `cmd_store_watch`) | Bilder-Erzeugung, fest auf `docs/store/screenshots/de` und `de`; `manifest.json` trägt `"sprache": "de-DE"` |
| `LooseEndsUITests/StoreScreenshotsTests.swift` | iPhone/iPad-Bilder: Startargumente fest `-AppleLanguages (de)`, erfundene deutsche Aufgaben („Steuerbescheid heute prüfen“ …) |
| `LooseEndsUITests/MacStoreScreenshotsTests.swift`, `.github/workflows/store-mac.yml` | Mac-Bilder nur im CI-Lauf (Fenster 1280×800), nie auf Hennings Mac |
| `LooseEndsWatchUITests` (`WatchCaptureUITests/testPhotographStoreScreens`) | Watch-Bilder, Beispielaufgaben im Testmodus (`--ui-testing-store-sample`) |
| `LooseEndsUITests/LaunchLanguage.swift` | Sprachsteuerung der UI-Tests über `LOOSEENDS_UI_LANG` (Standard en); Bilder-Tests nutzen sie noch nicht |
| `docs/store/screenshots/de/` (README, manifest, iphone/ipad/watch/mac) | Ablage der de-Bilder; en-Gegenstück `docs/store/screenshots/en/` fehlt |
| `docs/reference/beta-beschreibung.md` | Englische TestFlight-Beschreibung — **kein** Store-Text, aber Tonvorlage; deutsche Store-Beschreibung steht nirgends im Repo (Henning hat sie in ASC von Hand gesetzt) |
| `docs/reference/neue-sprache.md` | Acht-Punkte-Liste für eine neue Sprache; Store-Seite sollte dort stehen |

## Existing Patterns
- **Schreibweg über CI-Handlauf:** Python-Skript (nur Standardbibliothek) + `workflow_dispatch` + Unit-Tests vor dem Lauf; Schlüssel
  nur als Secret, lokal sperrt ein Guard jede ASC-Abfrage. Lesen und Schreiben sind getrennte Aktionen, geschrieben wird nur bei
  Abweichung, danach Gegenprobe, Ausgabe nennt nur öffentliche Werte.
- **Texte im Repo je Sprache** in Markdown mit `## <Locale>`-Abschnitten und `Schlüssel: Wert`-Zeilen, Grenzen vor der ersten Anfrage geprüft.
- **Bilder nur aus der App erzeugt** (`sim.sh store-*`, CI für Mac), nie von Hand; Manifest nennt Größe, Dateien, Commit.
- **Beleg = Lese-Probe** (`asc-store-probe.yml`), nicht „hochgeladen“ (siehe Memory „Hochgeladen heißt sichtbar“).
- ASC-Anzeigetypen aus #742: `APP_IPHONE_61`, `APP_IPAD_PRO_3GEN_129`, `APP_WATCH_SERIES_10`, `APP_DESKTOP`.

## Dependencies
- Upstream: ASC-API (`appStoreVersionLocalizations` PATCH/POST: description, keywords, supportUrl, promotionalText; `appScreenshotSets` /
  `appScreenshots`: reserve, Upload-Operationen, Commit mit MD5), `ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_PRIVATE_KEY` in der CI; App muss in
  Englisch durchspielbar sein (`LanguagePacks.shipped = [.english, .german]`, englische UI-Kataloge vorhanden, #750–#761).
- Downstream: Einreichung von iOS 1.0.1 (scheitert sonst an fehlender Lokalisierung); #837 (Untertitel/Name en-US, AC-9-Schreiblauf noch offen,
  Workflow `feat-837-s2-schreibweg` in phase7); `asc-beta.yml aktion=einreichen`.

## Existing Specs
Keine unter `docs/specs/` zu Store/ASC. Maßgeblich: `docs/reference/testflight.md`, `docs/reference/neue-sprache.md`,
`docs/store/screenshots/de/README.md`, Memory #742/#837.

## Risks & Considerations
- **Umfang:** Texte + Probe-Erweiterung + Schreibweg + englische Bilder für vier Geräteklassen sprengen die Limits (4–5 Dateien, ±250 LoC);
  Schnitte nötig, z. B. (1) Probe liest Textfelder, (2) Schreibweg Texte, (3) Bilder en (iPhone/iPad/Watch), (4) Mac-Bilder + Upload.
- **Bild-Upload ist neu:** Es gibt keinen Skriptweg für `appScreenshots`; entweder neu bauen (reserve → PUT → commit, Reihenfolge, Ersetzen) oder
  Henning lädt per Claude Desktop hoch (wie #742) — dann bleibt die Probe der Beleg. Alternative zu bewerten in `/20-analyse`.
- **Mac:** Es gibt keine „nächste Mac-Version“ in ASC; Mac-Bilder en erst möglich, wenn sie angelegt ist (oder die Mac-1.0-Seite, `READY_FOR_SALE`,
  ist nicht bearbeitbar). DoD-Punkt 1 teilweise nicht erfüllbar bis dahin.
- **Wortlaut, Schlüsselwörter:** eigene, nicht übersetzte englische Schlüsselwörter (≤ 100 Zeichen, nichts doppelt zu Name/Untertitel); Henning gibt frei.
  Tabu: „Aufgabe“/„task“-Sprache nach Memory #837 prüfen (englischer Name enthält „Voice Tasks“, bereits freigegeben).
- **Honest copy:** Claim „Say it, it's sorted“ trägt nicht (Memory #837); Beschreibung darf nicht mehr versprechen als die App hält. Keine Cloud-/KI-Versprechen
  entgegen Datenschutztext.
- **Bilder englisch:** `StoreScreenshotsTests` hat deutsche Startargumente und deutsche Beispielaufgaben fest verdrahtet; en braucht Sprach-Parameter
  und englische Beispielaufgaben, Ausgabepfad `en/`, Manifest-Sprache `en-US`.
- **Secrets-Guard:** ASC nur über CI-Handlauf; neue Workflow-Dateien sind erst nach Merge auf `main` startbar.
- **Gerätestufe:** Kein Pfad der Geräteliste berührt (Skripte, Tests, Docs); Abnahme endet nach Stufe 2 — außer Änderungen an `project.yml`/Info.plist (nicht erwartet).
- **Parallele Arbeit:** #837 AC-9 (Schreiblauf Untertitel) ist mit der jetzt bearbeitbaren App-Info fällig; berührt dieselbe App-Info, nicht dieselben Dateien.

## Analysis

### Type
Feature (Vertrieb/Store-Seite, kein Produktcode der App). Kein Modell nötig: Texte stehen im Repo, Schreibweg ist ein Python-Skript, Bilder kommen aus den vorhandenen UI-Tests.

### Recherche (2026-11-06, vor allem anderen)
- **Bilder-Schnittstelle ist ersetzt.** Apple führt Bilder jetzt über die *App Asset Library* (`POST /v1/appAssetLibraryImages` → PUT auf `uploadOperations` → `PATCH uploaded:true`, **ohne** Prüfsumme) und *Platzierungen* (`POST /v1/appAssetLibraryPlacements` mit `placementType=APP_SCREENSHOT`, `placementGroup`, Bezug auf `appStoreVersionLocalization`; Reihenfolge per `appAssetLibraryPlacementOrderingRequests`; Ersetzen = Platzierung löschen und neu anlegen). Die alten `appScreenshotSets`/`appScreenshots` sind als veraltet gekennzeichnet. Quellen: developer.apple.com/documentation/appstoreconnectapi/uploading-and-managing-image-assets, …/placing-assets-on-your-app-store-surfaces, …/app-store-version-localizations. Der Kontext nahm noch den alten Weg (reserve → PUT → commit mit MD5) an: das ist überholt.
- **Gruppenkennungen sind Referenzdaten, keine feste Liste** (`GET /v1/appAssetLibraryRefData`, `placementGroup` z. B. `IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE`, `MAC_PROFILE`); Grenze 10 Bilder je Gruppe. Die Gruppen für iPad 13″ und Watch müssen aus den Referenzdaten gelesen werden, nicht geraten.
- **Pflichtfelder je Version-Lokalisierung:** Beschreibung, Schlüsselwörter, Support-URL; Werbetext ist jederzeit änderbar und kein Pflichtfeld; Marketing-URL optional. (Apples Matrix-Seite war nicht sauber auslesbar; Pflicht von Beschreibung/Schlüsselwörtern/Support-URL ist aus Erfahrungswissen, nicht belegt.)
- **Nicht belegt:** ob Apple für die Einreichung Bilder in *jeder* Lokalisierung verlangt. Apples Hilfe kennt „abgeleitete“ Bilder (aus der Hauptsprache übernommen); die Regel „Version und App-Info müssen dieselben Sprachen haben“ steht in der App-Info-Dokumentation, die Bildpflicht je Sprache ist nirgends bestätigt. Prüfen ohne echte Einreichung geht nicht.
- Secrets/Guard: ASC nur über CI-Handlauf; die Probe liest heute von der Version-Lokalisierung nur Sprache und Bildsätze, **nicht** Texte und nicht Platzierungen.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_store_probe.py` + Test | MODIFY | liest je Version-Lokalisierung Beschreibung (Länge + Anfang), Schlüsselwörter, Support-URL, Werbetext und Platzierungen (neuer Weg) neben den alten Bildsätzen |
| `docs/reference/app-store-beschreibung.md` | CREATE | `## de-DE` (aus ASC gelesen) und `## en-US` (Wortlaut von Henning freigegeben) |
| `scripts/asc_store_text.py` + Test | CREATE | Schreibweg Texte, Muster `asc_app_info.py` (nur bei Abweichung, Gegenprobe, `Fatal` bei Sperre) |
| `.github/workflows/asc-store-text.yml` | CREATE | Handlauf `aktion=lesen|schreiben`, Unit-Tests vorher |
| `LooseEndsUITests/StoreScreenshotsTests.swift`, `scripts/store_screenshots.py`, `sim.sh` | MODIFY | Sprache als Parameter (`LaunchLanguage`), englische Beispielaufgaben, Ausgabe `docs/store/screenshots/en/`, Manifest `en-US` |
| `scripts/asc_store_images.py` + Test | CREATE | Bild-Upload über Asset Library + Platzierungen (neu) |
| `docs/reference/neue-sprache.md` | MODIFY | Store-Seite als Punkt der Liste |

### Scope Assessment
- Gesamt weit über dem Limit (≈ 12–14 Dateien, ≈ 700+ LoC mit Tests) → **vier Teil-Specs**, je eigenes Limit, im selben Ticket (Memory: Mehrere Schnitte = Teil-Specs):
  1. **S1 Probe liest Texte + Platzierungen** (2 Dateien, ≈ +90 LoC). Liefert, was heute unbekannt ist: den deutschen Wortlaut als Tonvorlage und ob en-US schon Text trägt.
  2. **S2 Texte en-US schreiben** (Textdatei, Skript, Workflow, Tests; ≈ 230 LoC). Henning gibt den Wortlaut frei. Hier erledigt sich vermutlich der Kern von „Einreichung scheitert nicht an fehlender Lokalisierung“.
  3. **S3 englische Bilder erzeugen** iPhone/iPad/Watch (≈ 150 LoC); Mac erst wieder im CI-Lauf.
  4. **S4 Bild-Upload per Skript** (neuer Weg, ≈ 250 LoC inkl. Tests; ggf. weiter teilen).
- Mac: Mac 1.0 ist `READY_FOR_SALE`, nicht bearbeitbar; DoD-Punkt „nächste Mac-Version“ bleibt offen, bis sie angelegt ist (eigenes Folgeticket erst dann).
- Risiko: **MITTEL**. Kein App-Code, aber Außenwirkung (öffentliche Store-Seite) und ein neuer, nirgends erprobter Apple-Weg für Bilder.
- Gerätestufe: „Kein Pfad der Geräteliste berührt.“ (nur Skripte, UI-Tests, Docs).
- Entwurf vor Spec (UI-Regel): entfällt, die App-Oberfläche ändert sich nicht; die Store-Bilder sind Aufnahmen der bestehenden Oberfläche.

### Technical Approach (Empfehlung)
Reihenfolge S1 → S2 → S3 → S4, jeweils eigener Merge. Nach S2 die Probe als Beleg lesen; damit ist die offene Frage „reicht Text ohne en-Bilder zur Einreichung?“ nur durch Apple selbst zu klären, daher S3/S4 trotzdem bauen: eine englische Seite mit deutschen Bildern wäre unehrlich gegenüber englischen Nutzern.
Bild-Upload: neuer Asset-Library-Weg in einem Skript mit Handlauf (Bilder liegen im Repo, kein Henning-Schritt). Vor dem Schreiben zuerst nur lesen: `appAssetLibraryRefData` für die Gruppen, `placements` der de-Lokalisierung, um zu sehen, wie Hennings Claude-Desktop-Upload (#742) aussieht.

### Alternativen (und was sie kippen würden)
- **A. Nur Texte, Bilder von Apple aus der Hauptsprache ableiten lassen.** Billigster Weg (S1+S2), erfüllt Einreichbarkeit vermutlich, zeigt englischen Nutzern aber deutsche Bilder. Kippt: DoD-Punkt „Bildern“. Als Zwischenstand tragfähig, nicht als Ziel.
- **B. Bilder weiter von Henning per Claude Desktop hochladen lassen (Vorbild #742).** Spart S4, widerspricht aber „Henning hat nichts zu tun“ und der Regel „Hochgeladen heißt sichtbar“ (Beleg nur über die Probe). Kippt nichts, kostet ihn Arbeit.
- **C. en-US wieder aus dem Store nehmen (App-Info-Lokalisierung entfernen).** Einreichung wäre sofort unproblematisch, aber #837 (englischer Name/Untertitel, freigegeben 2026-11-05) fiele, und die App hat englische Oberfläche. Nicht empfohlen.
- Regel vor Modell: trifft nicht zu, kein Sprachmodell im Spiel.

### Dependencies
- Upstream: ASC-API (Version-Lokalisierung PATCH, Asset Library, Platzierungen), CI-Secrets, englische UI-Kataloge (vorhanden, #750–#761).
- Downstream: Einreichung iOS 1.0.1; #837 AC-9 (Schreiblauf Untertitel, anderer Workflow, andere Dateien); nächste Mac-Version.

### Open Questions
- [ ] **Wortlaut en-US** (Beschreibung, Schlüsselwörter ≤ 100 Zeichen, Werbetext optional): Entwurf kommt in S2 nach Lesen des deutschen Textes; Henning gibt frei. „Task“-Sprache nur wie im freigegebenen Namen („Voice Tasks“).
- [ ] **Support-URL en-US:** vermutlich dieselbe wie de; nach S1 klären.
- [ ] Verlangt Apple Bilder je Sprache zur Einreichung? Nur durch Versuch zu klären; kein Versuch ohne Hennings Wort (Einreichung ist nach außen wirksam).

# Context: feat-772-kopfbild

## Request Summary
#772: Für den App Store ein Kopfbild gestalten (Logo mit dem Faden, Slogan, Hell und Dunkel), in beiden
Apple-Größen erzeugen, unter `docs/store/` ablegen und hochladen. Nicht zur Prüfung einreichen ohne Hennings Wort.
Das Bild zählt erst, wenn die App bei Apple für Hervorhebungen eingereicht wird, für 1.0 ist es nicht nötig.

## Recherche (2026-11-02, zuerst gemacht)
- **Maße** ([Apple: Creative assets specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications)):
  Kopfzeile 21:9 = 3840 × 1646 (`.jpeg/.jpg/.png`); universell 16:9 = 5244 × 2950 (nur `.png`), gilt für Kopfzeile und
  Suchergebnisse. Suchergebnisse allein 3:2, 1920 × 1280 bis 3840 × 2560. **Keine Alpha-Kanäle, keine Transparenz.**
  Keine Dateigrößengrenze genannt; Sicherheitsränder und Textregeln stehen dort nicht.
- **Weg in der Oberfläche** ([Apple: Manage your App Store assets](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-store-assets)):
  Version → Produktseiteninformationen → „Kopfzeile und Suchergebnisse“. Bilder gelten für iOS und iPadOS 27 und neuer, sind
  optional und getrennt von Screenshots. **Standalone-Einreichung über die Asset-Bibliothek ist möglich**, ohne die
  Version zu ändern; geprüft wird gegen die neueste Version. Rollen: Account Holder, Admin, App Manager, Marketing.
- **Weg per API** (Apple: App Asset Library, `developer.apple.com/documentation/appstoreconnectapi/app-asset-library`):
  1. `GET /v1/apps/{id}/assetLibrary` → Bibliothek-Id. `GET /v1/appAssetLibraryRefData` → `imageSpecs` (Maße, Endungen, Größen).
  2. `POST /v1/appAssetLibraryImages` (`fileName`, `fileSize`, `category`, optional `referenceName`, Beziehung `assetLibrary`)
     → `AWAITING_UPLOAD` + `uploadOperations`.
  3. Bytes je Operation hochladen (ohne JWT), dann `PATCH /v1/appAssetLibraryImages/{id}` mit `uploaded: true`
     (keine Prüfsumme, nur `fileSize`). Zustände: `UPLOAD_COMPLETE` → `PREPARE_FOR_SUBMISSION` (bereit) → `APPROVED`.
  4. Platzieren: `POST /v1/appAssetLibraryPlacements` mit `placementType` `PRODUCT_PAGE_HEADER_ASSET`. Das **legt nichts zur
     Prüfung vor**; Prüfung geschieht mit der Oberfläche (Version, Custom Product Page …).
  - **Folge für das Ticket:** „Hochgeladen, nicht eingereicht“ heißt: Bild in die Asset-Bibliothek legen (Zustand
    `PREPARE_FOR_SUBMISSION`), **keine** Platzierung. Version 1.0 steht auf `WAITING_FOR_REVIEW`, eine Platzierung an ihr wäre
    ohnehin `STATE_ERROR.INVALID_STATE`.
  - Offen: welche `category` für Kopfbilder gilt und welche Spec-Id passt. Beides liefert `appAssetLibraryRefData`
    (nur lesend, vorab zu prüfen). Der Wert `APP_SCREENSHOTS_AND_PREVIEWS` aus Apples Beispiel gilt für Screenshots.

## Related Files
| File | Relevance |
|------|-----------|
| `docs/design/logo/README.md`, `generate.py.txt`, `loose-ends-icon.svg` | Logo: Faden-Trochoide (a = 90, b = 230, t −3,5…3,0), Petrol `#0F6E73` hell / `#5FC4C9` dunkel, Grund `#F4F3EE`; Quelle für das Motiv |
| `LooseEnds/Resources/Assets.xcassets/{AccentColor,Paper,Quiet}.colorset` | App-Farben hell/dunkel: Paper `#F4F3EE` / `#171816`, Quiet (Grau) `#777876` / `#8E8F88` |
| `LooseEnds/Views/Thread.swift` | `ThreadShape`: dieselbe Kurve in der App; Zeichnung des Kopfbilds folgt der Formel, kein Eigenbild |
| `scripts/asc_store_probe.py`, `scripts/asc_beta_probe.py`, `scripts/asc_wait_build.py` | ASC-Client (`Probe`, `read_config`, `find_app_id`, JWT) für Lesen; Muster für ein Upload-Skript |
| `.github/workflows/asc-store-probe.yml` | Handlauf mit ASC-Secrets (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`); Vorlage für einen Hand-Workflow zum Upload |
| `scripts/store_screenshots.py`, `docs/store/screenshots/` | Ablage- und Manifestmuster der Store-Bilder (`docs/store/`) |

## Existing Patterns
- Store-Bilder liegen unter `docs/store/…` mit Manifest; Skripte nur Standardbibliothek (+ `sips`). Pillow 12.3 ist auf dem Mac da,
  `rsvg-convert`/`magick` nicht. Ein Zeichenskript müsste die Kurve selbst rastern (Pillow) oder Pillow als Hilfswerkzeug nehmen.
- ASC-Zugriffe laufen über GitHub-Workflows mit Secrets, nie lokal mit Hennings Anmeldung (`asc-*.yml`).
- Entwürfe sichtbarer Gestaltung: veröffentlichte Artefakt-Seite mit Hell/Dunkel und mindestens einer Alternative, abgelegt unter
  `docs/artifacts/<workflow>/`, vor der Spec (Hennings Regel vom 2026-09-22).

## Dependencies
- Upstream: Logo-Quellen (`docs/design/logo`), ASC-API-Schlüssel (Secrets im Repo), Asset-Bibliothek des Kontos.
- Downstream: nichts im App-Code. Kein Pfad der Geräteliste, keine gemeinsame Stelle (`project.yml`, `*.xcstrings`,
  `CLAUDE.md`, Schema, `Shared/Models`), kein Gebiet von #612.

## Existing Specs
- Keine. `docs/specs/` kennt kein Store-Thema; #742 (Store-Bilder) ist geschlossen, Belege dort.

## Risks & Considerations
- **Pflicht „nicht einreichen ohne Hennings Wort“:** Der Upload darf nichts auslösen, was nach Prüfung aussieht. Nur
  Asset-Bibliothek, keine Platzierung, keine Einreichung. Der Upload selbst „veröffentlicht“ Inhalt bei Apple (Konto, nicht
  öffentlich), er braucht Hennings Freigabe des Entwurfs vorher.
- **Kategorie/Spec unbekannt** bis die Referenzdaten gelesen sind; falsche Kategorie → Bild nicht platzierbar. Erst lesen.
- **Zuschnitt:** Kopfzeile und Suchkarte beschneiden das Bild verschieden (21:9 vs. 3:2/16:9); Logo und Slogan müssen in der
  Mitte stehen. Apples Sicherheitsränder sind nicht dokumentiert, daher mit großem Rand arbeiten.
- **Nur iOS/iPadOS 27+** zeigen das Bild; die App hat Zielversion 27, passt.
- **Kein Alpha:** PNG ohne Alphakanal erzwingen (Pillow: RGB speichern).
- **Slogan:** CLAUDE.md nennt „Say it, it's sorted.“; ein deutscher Store-Text ist im Repo nicht gefunden. Wortlaut klärt der
  Entwurf mit Henning (Produktthema).
- **Alternativen zum Bild selbst:** (a) nur Logo ohne Slogan, (b) Bild aus App-Ansicht (Start mit Faden), (c) Verzicht, bis
  Hervorhebung beantragt wird. (c) kippt keine ADR, spart Aufwand, verschiebt aber den Entwurf.

## Analysis

### Type
Feature (Store-Asset, kein App-Code)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/store_header.py` | CREATE | zeichnet die Kurve (Pillow, RGB, kein Alpha) in 3840×1646 und 5244×2950, hell und dunkel |
| `docs/store/header/*.png` + `manifest.json` | CREATE | die erzeugten Bilder nach Hennings Freigabe des Entwurfs |
| `scripts/asc_header_upload.py` + `.github/workflows/asc-header-upload.yml` | CREATE | Upload in die Asset-Bibliothek (nur Bibliothek, keine Platzierung) |
| `docs/artifacts/772-kopfbild/vorschau.html` | CREATE | Entwurf Heute/A/B/C, hell und dunkel (veröffentlicht: https://claude.ai/artifact/DFZo9hCYT5FrFTVQMFFgtG) |

### Scope Assessment
- Files: 4–5, Estimated LoC: +220, Risk Level: LOW (kein App-Pfad, kein Gerätepfad)

### Technical Approach
1. Entwurf von Henning freigeben lassen (Variante, Slogan-Sprache). Empfehlung: A, deutscher Slogan.
2. Referenzdaten zuerst lesen (`appAssetLibraryRefData`, nur lesend, per Hand-Workflow): Kategorie und Spec-Id für Kopfbilder.
3. Zeichenskript, Bilder ablegen, Test auf Maße, kein Alpha, Mitte frei.
4. Upload per Workflow bis `PREPARE_FOR_SUBMISSION`; keine Platzierung, keine Einreichung ohne Hennings Wort.
Alternative: Verzicht bis zur Bewerbung um Hervorhebung (kippt keine ADR, verschiebt nur den Entwurf).
Regelweg: Das Bild wird deterministisch gezeichnet, kein Modell beteiligt.

### Dependencies
ASC-Secrets im Repo, Logo-Formel aus `docs/design/logo`.

### Open Questions
- [x] Variante: **C (Petrol mit App-Ansicht)**, von Henning am 2026-11-02 gewählt; Slogan im Entwurf deutsch („Sag es, und es ist sortiert.“), in der Spec festhalten. Hinweis für die Spec: C zeigt die App-Startseite aus `docs/store/screenshots/de/iphone/01-start.png`; Zuschnitt 16:9 mit der Mitte freihalten.
- [ ] Kategorie/Spec-Id der Asset-Bibliothek — aus Referenzdaten, nach Freigabe

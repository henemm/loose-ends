# Context: fix-772-upload-api

## Request Summary
Der Upload der vier Kopfbilder in Apples Asset-Bibliothek (#772 Teil B, gemergt in PR #808) scheiterte im echten Lauf
(Run 41497087136: „Keine Spec für hell-16x9 (5244x2950); vorhanden: keine“). Das Skript hat die Schnittstelle geraten.
Es soll nach Apples Dokumentation korrigiert werden, ohne zu platzieren oder einzureichen.

## Befund aus dem echten Lauf
- `lesen` (Run 41496975945): Bibliothek erreichbar, `felder=id`, 0 Platzierungen. Keine Spec-Zeile.
- `hochladen` bricht vor jedem Schreiben ab (AC-6 hält): nichts bei Apple angelegt.

## Was Apple tatsächlich vorgibt (Quellen: developer.apple.com, App Store Connect API 4.5.0)
| Punkt | Apple | Mein Skript heute |
|---|---|---|
| Referenzdaten | `GET /v1/appAssetLibraryRefData/1?fields[appAssetLibraryRefData]=imageSpecs` (Einzeldatensatz, id `1`) | Listenpfad ohne id; `client.get` macht daraus `{"items": …}`, `imageSpecs` fehlt |
| Spec-Maße | `dimensions.minWidth/maxWidth/minHeight/maxHeight`, `specId`, `compatiblePlacementTypes`, `alphaAllowed`, `fileExtensions` | `width`/`height`, `category` |
| Kategorie | `CREATIVE_ASSETS` für Kopfbild (`PRODUCT_PAGE_HEADER_ASSET`); je Platzierungstyp in `placementTypes[].acceptsAssetCategories` | aus der Spec gelesen (gibt es dort nicht) |
| Bibliothek | `GET /v1/apps/{id}/assetLibrary` liefert die Bibliothek mit eigener `id` | `app_id` als Bibliothek behandelt |
| Bilder lesen | `GET /v1/appAssetLibraries/{libraryId}/images` (`state`, `referenceName`, `specId`, `fileName`) | als `included` der Bibliothek erwartet |
| Anlegen | `POST /v1/appAssetLibraryImages`, Beziehung `assetLibrary` (`type: appAssetLibraries`, id der Bibliothek) | Beziehung `app` |
| Upload | `uploadOperations` in den Attributen (`method`, `url`, `offset`, `length`, `requestHeaders`) | passt (flat) |
| Zustände | `AWAITING_UPLOAD` → `UPLOAD_COMPLETE` → `PREPARE_FOR_SUBMISSION`; auch `FAILED` mit `stateDetails` | `FAILED` wird nicht erkannt |
| Spec-Zuordnung | Apple ordnet beim Verarbeiten selbst zu und meldet `specId` | wir prüfen vorab über Maße (sinnvoll) |
| Platzierungen | je Bild `GET /v1/appAssetLibraryImages/{id}/placements` | `library["placements"]` |

Praxisbericht (kein Apple, ObjectGraph): Kopfbild 3840 × 1646 (21:9), Suchbild 3840 × 2560 (3:2). Ob Apple 5244 × 2950
für `PRODUCT_PAGE_HEADER_ASSET` annimmt, zeigt nur der Spec-Abgleich im echten `lesen`.

## Related Files
| File | Relevance |
|------|-----------|
| scripts/asc_header_upload.py | `REFDATA`, `match_specs`, `upload`, `check_state`, `Client.get/post`, `main(lesen)` |
| scripts/test_asc_header_upload.py | Attrappe `FakeClient` mit erfundener Form; muss die echte Form von Apple nachbilden |
| .github/workflows/asc-header-upload.yml | unverändert |
| docs/store/header/manifest.json | Maße der vier Bilder (unverändert) |

## Existing Patterns
- `Client.get` flacht JSON:API-Datensätze (id + Attribute), Listen kommen als `{"items": [...]}`.
- Fatal-Abbruch vor jedem Schreiben, wenn eine Spec fehlt (AC-6).

## Dependencies / Dependents
- Upstream: `asc_wait_build` (Token, Config, `find_app_id`). Downstream: nur der Hand-Workflow.

## Risks & Considerations
- Das Antwortformat ist nur aus der Doku bekannt; `lesen` muss deshalb die rohen Spec-Daten (shortName, Maße,
  Platzierungstypen) ausgeben, damit der nächste Lauf nicht wieder blind ist.
- Ist 16:9 für den Kopf-Platzierungstyp nicht zulässig, werden nur die passenden Bilder hochgeladen und die übrigen
  ausdrücklich gemeldet (kein stilles Weglassen).
- Alternative zum Vorab-Abgleich: hochladen und Apples `specId` lesen. Verworfen: legt dann unpassende Bilder an.
- Nichts auf Hennings Geräten betroffen, kein App-Code, kein Pfad der Geräteliste.

## Analysis

### Type
Bug. `hochladen` scheitert im echten Lauf (Run 41497087136), weil das Skript die Schnittstelle geraten hat. Reproduziert:
echter Lauf bricht mit „Keine Spec für hell-16x9 (5244x2950); vorhanden: keine“ ab; `lesen` (Run 41496975945) zeigt
dieselbe Lücke (keine Spec-Zeile). „Hat es bisher funktioniert?“ — nein, der Upload lief nie; erster echter Lauf.

### Root Cause
Fünf Abweichungen von Apples Schnittstelle (Tabelle oben): Referenzdaten sind ein Einzeldatensatz (`/…/appAssetLibraryRefData/1`),
Maße stehen in `dimensions.min/max…`, die Bibliothek hat eine eigene id (`/v1/apps/{id}/assetLibrary`), Bilder und
Platzierungen sind eigene Unterpfade, Anlegen hängt an der Beziehung `assetLibrary`, `FAILED` ist ein eigener Zustand.
Die Attrappe `FakeClient` bildet dieselbe erfundene Form nach, deshalb waren die Tests grün.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_header_upload.py | MODIFY | Refdaten per id 1, Spec-Abgleich über `dimensions` (Maß liegt in min/max), Bibliothek-id, Bilder/Platzierungen über Unterpfade, POST mit `assetLibrary`, `FAILED` erkennen, `lesen` gibt rohe Specs (specId, Maße, Platzierungstypen) aus |
| scripts/test_asc_header_upload.py | MODIFY | Attrappe liefert Apples dokumentierte Antwortform (inkl. Einzeldatensatz, Unterpfade, `FAILED`) |

### Scope Assessment
- Files: 2
- Estimated LoC: +70/-50 (Skript), Tests ±90 → insgesamt ≈ ±210 (unter 250)
- Risk Level: LOW — Hand-Workflow, kein App-Code, schreibt erst nach erfolgreichem Spec-Abgleich; AC-6 (Abbruch vor jedem Schreiben) bleibt.

### Technical Approach
Skript an Apples dokumentierte Form anpassen, nichts raten: Spec-Treffer, wenn Breite und Höhe in `[min,max]` liegen und der
Platzierungstyp `PRODUCT_PAGE_HEADER_ASSET` kompatibel ist; die Kategorie kommt aus `placementTypes[].acceptsAssetCategories`
(`CREATIVE_ASSETS`). Passt ein Bild nicht (z. B. 16:9, falls Apple für den Kopf nur 21:9 kennt), wird es ausdrücklich gemeldet
und nicht hochgeladen; die passenden gehen durch. `lesen` druckt die rohen Spec-Daten, damit der nächste Lauf nicht wieder blind ist.
Zuerst `lesen` im echten Lauf (nur GET), danach `hochladen`.

### Alternatives
- **Hochladen und Apples `specId` lesen** statt Vorab-Abgleich: einfacher, legt aber unpassende Bilder in Hennings Bibliothek an. Verworfen.
- **Händisch im App-Store-Connect-Web hochladen**: kein Skript, aber Henning müsste es tun (nicht sein Thema) und der Beleg ist nicht automatisiert. Verworfen.
- **Bilder auf Apples Praxismaße umstellen** (3840 × 1646 / 3840 × 2560, ObjectGraph-Bericht): würde #772 Teil A (Entwurf, Maße aus der Issue) kippen; nur nötig, wenn `lesen` zeigt, dass 5244 × 2950 nicht zulässig ist. Dann eigene Entscheidung, nicht in diesem Schnitt.
- Ohne Modell: reine Schnittstellenarbeit, kein Sprachverstehen beteiligt.

### Befunde gegen den Plan
Antwortform nur aus Doku bekannt, nicht aus einem echten Lauf; Maßzulässigkeit von 5244 × 2950 für den Kopf ungeklärt.
Gegenmittel: rohe Ausgabe in `lesen`, Fatal mit allen Specs bei Nichtpassen, kein stilles Weglassen.

### Dependencies
Upstream `asc_wait_build` (Token, Config, `find_app_id`); Downstream nur `.github/workflows/asc-header-upload.yml` (unverändert).
Kein Pfad der Geräteliste berührt.

### Open Questions
- [ ] Ist 16:9 (5244 × 2950) für den Kopf zulässig? Klärt der echte `lesen`-Lauf nach dem Fix; kein PO-Input jetzt nötig.

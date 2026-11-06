# Context: feat-842-s2-platzierungspfad

## Request Summary
#842 (englische Store-Seite), Schnitt 2: Der Platzierungs-Abruf der Store-Probe wird von Apple abgelehnt
(Handlauf 2026-11-06, Lauf 42238055521: bei allen drei Versionen „platzierung fehler", Referenzdaten „keine").
Ziel: den richtigen Endpunkt finden, den Fehlergrund sichtbar machen, die Probe liest Platzierungen und Referenzdaten richtig.

## Recherche (2026-11-06, Apple-Dokumentation)
- Platzierungen einer Versions-Lokalisierung: `GET /v1/appStoreVersionLocalizations/{id}/placements`
  („List related placements", API 4.5.0+). Ein Pfad `.../appAssetLibraryPlacements` unter der Lokalisierung gibt es nicht;
  `appAssetLibraryPlacements` ist nur die Wurzel für `POST`, `GET/DELETE /{id}`.
  Quelle: https://developer.apple.com/documentation/appstoreconnectapi/get-v1-appstoreversionlocalizations-_id_-placements.md
- Referenzdaten: `GET /v1/appAssetLibraryRefData` liefert **einen** Datensatz mit sechs parallelen Listen
  (`features`, `placementProfileGroups`, `imageSpecs`, `videoSpecs`, `placementTypes`, `displayClasses`) in `attributes`;
  Gruppennamen stehen in `placementProfileGroups` (Plattform, Anzeigeklasse), nicht je Datensatz als `placementGroup`.
  Filter `fields[appAssetLibraryRefData]=placementProfileGroups`.
  Quelle: https://developer.apple.com/documentation/appstoreconnectapi/discovering-asset-specifications.md
- Die Set-Ressourcen (`appScreenshotSets`, `appScreenshots`) sind als veraltet markiert, die Asset Library ersetzt sie
  (https://developer.apple.com/documentation/appstoreconnectapi/migrating-to-the-app-asset-library.md). Platzierungen nur
  bei einer Version in `PREPARE_FOR_SUBMISSION` anlegbar. Löschen: erst Platzierungen, dann Asset.
- Bildbibliothek der App: `GET /v1/apps/{id}/assetLibrary`; Platzierung anlegen: `POST /v1/appAssetLibraryPlacements`.

## Related Files
| File | Relevance |
|------|-----------|
| scripts/asc_store_probe.py | `report_placements` (falscher Pfad, `placementGroup`-Annahme), `report_refdata` (falsche Form), `main()` |
| scripts/test_asc_store_probe.py | `store_routes` bildet den falschen Pfad und die falsche Refdata-Form nach; Tests `test_placement_*`, `test_refdata_*` |
| scripts/asc_beta_probe.py | `probe()` wirft den Fehlerrumpf bei 4xx weg (`return error.code, None`); `Probe.ask` druckt nur Status und Befundtext |
| docs/specs/feat-842-schnitt-1-probe-texte.md | Vorgänger-Spec; nennt den Pfad ausdrücklich „unerprobt" |
| .github/workflows/asc-store-probe.yml | Handlauf (workflow_dispatch), unverändert |

## Existing Patterns
- Probe druckt je Abfrage eine Zeile `zugriff abfrage=… http=…`, je Befund eine deutsche Schlüssel=Wert-Zeile; nur GET.
- Lokaler HTTP-Nachbau in `test_asc_beta_probe.py`/`test_asc_store_probe.py` (`ProbeCase.run_probe(extra=routes)`).
- Fehlerrumpf von Apple: JSON-API `{"errors":[{"status","code","title","detail"}]}`; Codes und Titel sind keine Geheimnisse.

## Dependencies
- Upstream: `asc_wait_build` (Konfiguration, Token), `asc_beta_probe` (`Probe`, `records`, `attributes`).
- Downstream: Handlauf `asc-store-probe.yml`; Schnitt 3/4 von #842 (Schreibweg für Texte und Bilder) bauen auf den
  Platzierungsgruppen und dem Pfad auf. `probe()` wird auch von `asc_beta_probe` benutzt: Änderung am Rückgabevertrag
  trifft dessen Tests.

## Existing Specs
- `docs/specs/feat-842-schnitt-1-probe-texte.md`

## Risks & Considerations
- Die Antwortform von `/placements` ist nur aus der Doku bekannt (Attribute `placementType`, `placementGroup`, `state`?);
  Handlauf nach dem Merge ist die erste Bestätigung.
- Fehlergrund ausgeben berührt `probe()` in `asc_beta_probe.py` (geteilt): kleinster Weg ist, den Fehlerrumpf zusätzlich
  zu liefern, ohne den bestehenden (Status, None)-Vertrag zu brechen, oder den Grund auf dem `Probe`-Objekt zu merken.
- Alternative zur Asset-Library-Auslese: nur die alten Bildsätze prüfen; reicht für „Bildsätze sichtbar", nicht für das Schreiben (Schnitt 4).
- Handlauf im Aktionsfenster nur nach Merge; kein Gerät beteiligt (Kein Pfad der Geräteliste berührt).

## Analysis

### Type
Feature (Probe-Korrektur; Bug der Probe selbst: falscher Pfad, falsche Antwortform, Fehlergrund verschluckt)

### Ursache (Code gelesen, Apple-Doku verglichen)
1. `report_placements` fragt `/v1/appStoreVersionLocalizations/{id}/appAssetLibraryPlacements`; diesen Pfad gibt es nicht
   (Apple: `.../placements`). Apple antwortet mit 4xx → `probe()` wirft den Fehlerrumpf weg → Zeile nennt nur „platzierung fehler".
2. `report_refdata` erwartet je Datensatz `placementGroup`; Apple liefert einen Datensatz mit sechs Listen in `attributes`
   (Gruppen in `placementProfileGroups`). Selbst bei HTTP 200 stünde „refdaten keine".
3. `Probe.ask` kennt den Fehlerrumpf nie (`probe()` gibt bei 4xx `(code, None)`).
   Reproduktion: Handlauf 42238055521 (Apple lehnt ab, bei allen drei Versionen). Der lokale Nachbau bildet den falschen Pfad
   mit ab, deshalb waren die Tests grün — gleiche Lehre wie #136.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_beta_probe.py | MODIFY | `fetch()` liefert zusätzlich den Fehlerrumpf; `probe()` bleibt als Hülle mit altem Vertrag; `Probe.ask` hängt `grund=<code>/<title>` an die Zeile (kein `detail`) |
| scripts/asc_store_probe.py | MODIFY | Pfad `/placements`; Platzierungsattribute lesen (Antwort-Schlüssel ausgeben, solange unbestätigt); Refdata aus `placementProfileGroups` |
| scripts/test_asc_store_probe.py | MODIFY | `store_routes` auf echten Pfad/echte Form; Tests für Grund, Pfad, Gruppen |
| scripts/test_asc_beta_probe.py | MODIFY | ein Test: Fehlergrund in der Zugriffszeile, alter Vertrag von `probe()` unverändert |

### Scope Assessment
- Files: 4
- Estimated LoC: +~110/-~25 (Tests ≈ 2/3)
- Risk Level: LOW (nur GET, nur Probe-Skripte, kein App-Code; Handlauf danach ist die erste echte Bestätigung)

### Technical Approach (Regelweg, kein Modell)
- Fehlergrund: Apples JSON-API-Fehler `{"errors":[{"code","title"}]}` auslesen, nur `code` und `title` drucken (kein `detail`, kann IDs nennen).
  Gilt für alle Abfragen der Probe, also auch künftig.
- Pfad auf `/placements`. Antwortform unbestätigt → die Zeile druckt die Attribut-Schlüssel (`felder=…`) mit, damit ein
  Handlauf die Form belegt, statt zu raten (Schnitt 3/4 bauen darauf).
- Refdata: `attributes.placementProfileGroups` lesen und Zahl/Namen je Liste ausgeben; Filter `fields[appAssetLibraryRefData]=placementProfileGroups`.
- Abnahme: Tests grün, dann Handlauf `asc-store-probe.yml` nach Merge. Gerät nicht beteiligt: „Kein Pfad der Geräteliste berührt."

### Alternativen
- A (empfohlen): Asset-Library-Pfad korrigieren + Grund ausgeben.
- B: nur die veralteten `appScreenshotSets` prüfen — liefert „Bildsätze sichtbar" schon heute, taugt aber nicht zum Schreiben
  (Schnitt 4 braucht die Asset Library); kippt nichts, schiebt nur die Unsicherheit.
- C: Fehlergrund allein, ohne Pfadkorrektur — ein Handlauf mehr ohne Gewinn, da die Doku den Pfad eindeutig nennt.

### Dependencies
Upstream `asc_wait_build`, `asc_beta_probe` (`probe` auch von dessen Tests benutzt → Vertrag bleibt). Downstream Schnitte 3/4 von #842.

### Open Questions
- [ ] Keine, die Henning entscheiden müsste. Offen nur technisch: genaue Attributnamen von `/placements` (klärt der Handlauf).

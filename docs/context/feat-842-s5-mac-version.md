# Context: feat-842-s5-mac-version (#842 Schnitt 5)

## Request Summary
Henning, 2026-11-09 (Auswahl „Ja, zusammen“): Die Mac-App bekommt 1.0.1 zusammen mit dem iPhone, damit auch der Mac eine
englische Store-Seite hat. Mac-Version 1.0.1 bei App Store Connect anlegen, Mac-Bau zuordnen, de-DE und en-US Texte, Mac-Bilder
(de und en) platzieren; bis vor das Einreichen. Mitgenommen: deutsche Werbezeile der iOS-Version 1.0.1 fehlt.

## Ist-Stand bei Apple (Belege)
- Store-Probe 42578684646 (2026-11-09): iOS 1.0.1 `PREPARE_FOR_SUBMISSION`, de-DE und en-US mit Texten und 12 Bildern je Sprache;
  de-DE Werbetext 0 Zeichen (1.0: 139). Mac nur 1.0 `READY_FOR_SALE`, de-DE, 4 Bilder `MAC_PROFILE` (`APP_DESKTOP`), Werbetext 139.
  App-Info 2 (`PREPARE_FOR_SUBMISSION`) hat de-DE und en-US — gilt für iOS und Mac gemeinsam.
- Beta-Probe 42591946393 (2026-11-09): Build 133 je Plattform `MAC_OS` und `IOS` `VALID` (1.0.1, TestFlight).
- Bibliothek (Lesen-Log 4c-2): deutsche iOS-Bilder `0x-*.png` mit je **2** Platzierungen (1.0 und 1.0.1) → beim Anlegen von iOS
  1.0.1 hat Apple die Bilder der Vorversion übernommen; Mac-Bilder `0x-*.png (6..9)` je 1 Platzierung (Mac 1.0). Die
  en-Mac-Bilder sind noch **nicht** in der Bibliothek (4c-1 ließ den Mac ohne bearbeitbare Version aus).

## Recherche (2026-11-09)
- Apple-Hilfe „Create a new version“: Beim Anlegen in App Store Connect werden die Metadaten der aktuellen Version übernommen
  (https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version) — beschreibt die Web-Oberfläche.
- Runway: per API (`POST /v1/appStoreVersions`, Pflicht nur `platform`, `versionString`, Relation `app`) wird der Werbetext
  **nicht** übernommen (https://www.runway.team/blog/apply-promotional-text-and-whats-new-notes-to-new-versions-in-swift-using-the-app-store-connect-api)
  — passt zum fehlenden deutschen Werbetext von iOS 1.0.1.
- Ob die API Bilder übernimmt: nicht belegt → nach dem Anlegen lesen, nicht annehmen.
- Bau zuordnen: `PATCH /v1/appStoreVersions/{id}/relationships/build` (204); 409 `ENTITY_ERROR.RELATIONSHIP.INVALID` bekannt
  (https://developer.apple.com/forums/thread/826885), Bau muss `VALID` sein.

## Related Files
| File | Relevance |
|------|-----------|
| scripts/asc_version_texts.py | `lesen`/`texte`; schreibt en-US je Plattform in die bearbeitbare Version (`PLATFORMS = IOS, MAC_OS`); kein Anlegen einer Version, kein de-DE (nicht im Repo) |
| docs/reference/app-store-texte.md | nur `## en-US`; deutscher Wortlaut nicht im Repo |
| scripts/asc_store_images.py | Bibliothek hochladen und en-US platzieren; nur iOS (`GROUPS` ohne Mac, `preflight` nur `IOS`, `warn_mac`); `platzieren` nur `en`, de-DE nie beschrieben |
| docs/store/screenshots/{de,en}/manifest.json | Mac-Eintrag 1280x800, 4 Dateien (01, 03, 04, 05) |
| scripts/asc_store_probe.py | Beleg: Versionen, Texte, Platzierungen, Bildsätze je Version |
| scripts/asc_wait_build.py, asc_beta_probe.py | Bau-Abfrage mit `platform_filter` |
| .github/workflows/asc-version-texts.yml, asc-store-images.yml | Handläufe per `workflow_dispatch` |
| scripts/test_asc_version_texts.py, test_asc_store_images.py | FakeClient-Tests |

## Existing Patterns
- Handlauf je Aktion in CI (Secrets nur dort), erst nur GET prüfen, dann schreiben, dann Gegenprobe im selben Lauf; nie löschen, nie einreichen.
- Schreiben nur in die eine Version `PREPARE_FOR_SUBMISSION` je Plattform; gesperrte Versionen nie.
- Platzieren über `appAssetLibraryPlacements` + Ordnungsauftrag je Gruppe (4c-2).

## Dependencies
- Upstream: ASC-API (Versions, Lokalisierungen, Builds, Asset-Bibliothek, Platzierungen), `Client` aus `asc_header_upload.py`.
- Downstream: Einreichung 1.0.1 (Hennings Wort), Store-Probe.

## Risks & Considerations
- Anlegen einer Version ist ein Schreibzugriff bei Apple; eine leere `PREPARE_FOR_SUBMISSION`-Version lässt sich wieder löschen, ist aber unschön → einmalig, idempotent (nur wenn keine bearbeitbare Mac-Version existiert).
- Unklar, ob API-Anlegen de-DE Texte und Bilder übernimmt; de-DE muss ggf. aus Mac 1.0 kopiert werden (lesen → schreiben), deutsche Texte stehen nicht im Repo.
- `MAC_PROFILE` maxCount aus Referenzdaten prüfen; Bildmaß 1280x800 zulässig (Mac 1.0 hatte es).
- Umfang: zwei Skripte plus Tests → wahrscheinlich über 250 LoC, Schnitt teilen (Version/Texte vs. Bilder).
- Kein Pfad der Geräteliste berührt; kein Produktcode.

## Analysis

### Type
Feature (Werkzeug/Handlauf gegen App Store Connect, kein Produktcode)

### Befund aus dem Code (2026-11-09)
- Kein Skript legt eine App-Store-Version an; `asc_version_texts.py` schreibt nur in eine bestehende `PREPARE_FOR_SUBMISSION`-Version
  und nur die Felder `description`, `keywords`, `supportUrl`, `promotionalText` (kein `whatsNew`), nur Locales der Datei (nur en-US).
- `asc_store_images.py`: `GROUPS` ohne Mac, `preflight` fest auf `IOS`, `platzieren` nur en und nur die iOS-Version; `plan()` lässt den
  Mac-Eintrag des Manifests aus. Mac 1.0 nutzt die Gruppe `MAC_PROFILE` (Bildsatz `APP_DESKTOP`).
- Store-Probe zeigt weder `whatsNew` noch den zugeordneten Bau einer Version → Lücke: ob iOS 1.0.1 schon einen Bau und einen
  „Neu in dieser Version“-Text hat, ist nicht belegt.
- Prüfnotizen (`asc_review_notes.py`) fest auf iOS 1.0; eine per API angelegte Mac-Version hat vermutlich kein Review-Detail.

### Recherche (Ergänzung)
- `whatsNew` gibt es nur bei Updates, je Lokalisierung (Apple-Doku App Store Version Localizations,
  https://developer.apple.com/documentation/appstoreconnectapi/app-store-version-localizations.md; Runway-Artikel oben). Für 1.0.1
  ist es auf beiden Plattformen und in beiden Sprachen zu füllen; Wortlaut ist öffentlicher Produkttext → PO-Freigabe in der Spec.
- Zu Pflicht-Bildgrößen des Mac in der API nichts Belastbares gefunden → nach dem Anlegen aus Referenzdaten (`maxCount` `MAC_PROFILE`)
  und dem Bestand von Mac 1.0 lesen, nicht annehmen.

### Technical Approach (Empfehlung)
API-Weg, alles im Handlauf, je Schritt erst GET, dann Schreiben, dann Gegenprobe im selben Lauf; nie einreichen, nie löschen.
- **5a-1 Mac-Version anlegen und Bau zuordnen:** neue Aktion (eigener kleiner Handlauf `asc-store-version`): nur wenn keine
  Mac-Version `PREPARE_FOR_SUBMISSION` existiert, `POST /v1/appStoreVersions` (platform `MAC_OS`, versionString = die der bearbeitbaren
  iOS-Version, also 1.0.1); danach Bau 1.0.1 (133) je Plattform zuordnen, falls keiner zugeordnet ist (`VALID` Pflicht). Lesen zeigt
  danach Lokalisierungen, Bildsätze, Review-Detail und Bau der neuen Version — damit ist belegt, was Apple beim API-Anlegen übernimmt.
- **5a-2 Texte:** de-DE der Mac-Version: fehlende Felder aus Mac 1.0 de-DE kopieren (lesen → schreiben, Wortlaut bleibt bei Apple);
  en-US aus `docs/reference/app-store-texte.md` (vorhandener `texte`-Lauf greift für `MAC_OS` schon); `whatsNew` de/en für iOS und Mac
  aus der Textdatei (neues Feld `Neu in dieser Version:`); deutscher Werbetext iOS 1.0.1 aus iOS 1.0 kopieren; Review-Detail der
  Mac-Version aus Mac 1.0 bzw. den Prüfnotizen.
- **5b Mac-Bilder:** `asc_store_images.py` um Gerät `mac` → `MAC_PROFILE` und Plattformwahl erweitern; en-Mac-Bilder hochladen und auf
  en-US der Mac-Version platzieren; de-DE der Mac-Version nur, wenn dort leer, mit den vorhandenen deutschen Mac-Bildern der Bibliothek
  (bewusste, eng begrenzte Ausnahme von „de-DE nie beschreiben“, PO-Auftrag 2026-11-09).
- Store-Probe um `whatsNew` und zugeordneten Bau ergänzen (Beleg für „einreichfertig“).

### Alternative
**Mac-Version in der Web-Oberfläche anlegen** (Claude in Hennings Browser, Henning meldet sich nur an, wie beim CloudKit-Deploy):
Apple übernimmt laut Hilfe dort die Metadaten der Vorversion inklusive deutscher Texte und Bilder; 5a-2 schrumpft auf en-US und
`whatsNew`. Dagegen: braucht Hennings Anmeldung, ist nicht wiederholbar/prüfbar im Handlauf, und der iOS-Befund (deutscher Werbetext
fehlt trotz Anlegen) zeigt, dass „übernimmt alles“ nicht verlässlich ist. Keine ADR fiele; es kippte nur das Muster „alles per Handlauf“.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_store_version.py | CREATE | 5a-1: Mac-Version anlegen (idempotent), Bau je Plattform zuordnen, lesen |
| scripts/test_asc_store_version.py | CREATE | FakeClient-Tests 5a-1 |
| .github/workflows/asc-store-version.yml | CREATE | Handlauf lesen/anlegen |
| scripts/asc_version_texts.py, test_asc_version_texts.py | MODIFY | 5a-2: whatsNew, Kopieren de-DE aus Vorversion |
| docs/reference/app-store-texte.md | MODIFY | 5a-2: `Neu in dieser Version:` de-DE und en-US |
| scripts/asc_store_images.py, test_asc_store_images.py, asc-store-images.yml | MODIFY | 5b: Mac-Gruppe, Plattformwahl |
| scripts/asc_store_probe.py | MODIFY | whatsNew und Bau je Version zeigen |

### Scope Assessment
- Gesamt ~12 Dateien, geschätzt +900 LoC (davon gut die Hälfte Tests) → drei Schnitte 5a-1, 5a-2, 5b; je Schnitt 3–5 Dateien,
  5a-1 ~300 LoC, 5a-2 ~300, 5b ~300 (Überhang wie bei 4c durch FakeClient-Tests zu erwarten).
- Risk Level: MEDIUM — Schreibzugriffe bei Apple auf die öffentliche Store-Seite (nur bearbeitbare Versionen, nie einreichen);
  kein Produktcode, kein Pfad der Geräteliste berührt.

### Dependencies
- Reihenfolge zwingend: 5a-1 (Version existiert) → 5a-2 (Texte) und 5b (Bilder, braucht die Mac-Lokalisierungen) → Einreichung nur
  auf Hennings Wort. `Client` aus `asc_header_upload.py`, `editable_version`/`localizations` aus `asc_version_texts.py`.
- Bau 1.0.1 (133) `VALID` für `MAC_OS` und `IOS` (Beta-Probe 42591946393).

### Open Questions
- [ ] (PO, in der Spec 5a-2) Wortlaut „Neu in dieser Version“ für 1.0.1, deutsch und englisch — Claude legt einen Entwurf vor.
- [ ] (technisch, nach 5a-1 gelesen) Übernimmt Apple beim API-Anlegen de-DE Texte/Bilder/Review-Detail? Entscheidet, wie viel 5a-2/5b kopieren.

### Spec dieses Workflows
Spec für Schnitt 5a-1 (Anlegen + Bau zuordnen + Lesen); 5a-2 und 5b als eigene Teil-Specs danach.

## Umfangsfreigabe (Henning, 2026-11-09)
Auswahl „Ja, so bauen (Empfohlen)“ zu Schnitt 5a-1 mit ca. 535 LoC (Skript ~150, Tests ~350, Workflow ~35); Meldeschwelle ca. 620 LoC,
nach RED Testzeilen zählen. In /60-validate nicht erneut fragen, solange der Endstand unter der Schwelle bleibt.

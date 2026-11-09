---
entity_id: feat-842-schnitt-5a-1-mac-version-anlegen
type: feature
created: 2026-11-09
updated: 2026-11-09
status: draft
workflow: feat-842-s5-mac-version
---

# Spec: #842 Schnitt 5a-1 — Mac-Version 1.0.1 bei App Store Connect anlegen, Bau je Plattform zuordnen, Zustand belegen

## Approval

- [ ] Approved

Auftrag von Henning am 2026-11-09 (Auswahl „Ja, zusammen“): Die Mac-App bekommt Version 1.0.1 zusammen mit dem iPhone, damit auch der Mac eine englische Store-Seite hat; die Arbeit geht bis vor das Einreichen. Die Gesamtarbeit ist in drei Schnitte geteilt (5a-1, 5a-2, 5b). Diese Spec deckt nur 5a-1 ab. Die Version ist nicht eingereicht, also nicht öffentlich. `approved` gibt die Umsetzung frei.

## Purpose

Es gibt keine bearbeitbare Mac-Version bei Apple (nur 1.0, `READY_FOR_SALE`), und kein Skript legt eine App-Store-Version an. Ohne sie lassen sich weder Mac-Texte noch Mac-Bilder setzen. Außerdem hat bisher niemand belegt, ob iOS 1.0.1 und eine neue Mac-Version schon einen Bau (Build 133, `VALID` für `IOS` und `MAC_OS`) zugeordnet haben; ohne zugeordneten Bau ist eine Version nicht einreichbar.

Schnitt 5a-1 liefert ein neues Skript `scripts/asc_store_version.py` mit zwei Aktionen:

- `lesen` (nur GET): zeigt je Plattform alle Versionen mit Zustand und für jede bearbeitbare Version den zugeordneten Bau, die Lokalisierungen mit Zeichenzahlen je Feld, die Zahl der Bildsätze und Platzierungen je Lokalisierung und ob ein Review-Detail existiert. Es belegt, was Apple beim Anlegen per API von der Vorversion übernimmt (offene Frage der Analyse), und ist die Grundlage für 5a-2 und 5b.
- `anlegen`: legt die Mac-Version mit der Versionsnummer der bearbeitbaren iOS-Version an (1.0.1), nur wenn noch keine bearbeitbare Mac-Version existiert, ordnet je Plattform den passenden gültigen Bau zu, wenn die Version noch keinen hat, prüft im selben Lauf gegen und gibt danach dieselbe Ausgabe wie `lesen` als Beleg aus.

Für Henning ändert sich: Nichts Sichtbares. Bei Apple liegt danach eine nicht eingereichte Mac-Version 1.0.1 mit zugeordnetem Bau; Texte und Bilder folgen in den nächsten Schnitten. Er muss nichts tun.

Nicht in diesem Schnitt:

- **5a-2:** Texte de-DE/en-US für die Mac-Version, „Neu in dieser Version“ (`whatsNew`) für iOS und Mac, deutscher Werbetext der iOS-Version 1.0.1, Review-Detail der Mac-Version.
- **5b:** Mac-Bilder (Bibliothek, Gruppe `MAC_PROFILE`, Platzieren).
- **Einreichen, Löschen**, jede Änderung an Texten, Bildern oder am Review-Detail: dieses Skript schreibt nur die Mac-Version und die Bau-Zuordnung.
- **Produktcode:** keiner.

Ohne Modell geht es nicht: nicht relevant. Betriebsskript gegen die ASC-API, Regelweg.

## Source

- **File:** `scripts/asc_store_version.py` (neu), `scripts/test_asc_store_version.py` (neu), `.github/workflows/asc-store-version.yml` (neu); gelesen und wiederverwendet: `scripts/asc_version_texts.py`, `scripts/asc_wait_build.py`, `scripts/asc_what_to_test.py`, `scripts/asc_beta_probe.py`, `scripts/asc_store_probe.py`, `scripts/asc_review_notes.py`
- **Identifier:** neue Funktionen `read_state`, `plan_mac_version`, `pick_build`, `assign_build`, `anlegen`, `main` in `asc_store_version.py`; Eingabe `aktion` und Block `concurrency` im neuen Workflow

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `app_versions`, `editable_version`, `localizations`, `EDITABLE`, `PLATFORMS` (`scripts/asc_version_texts.py`) | Modul | Versionen der App, genau eine bearbeitbare je Plattform, Lokalisierungen; werden wiederverwendet, nicht kopiert |
| `Fatal`, `find_app_id`, `read_config`, `get_json` (`scripts/asc_wait_build.py`) | Modul | Fehlerklasse, App-Suche, Konfiguration aus der Umgebung, einzelner GET mit Wiederholung |
| `get_data`, `send_json` (`scripts/asc_what_to_test.py`) | Modul | GET einer Liste, Schreibaufruf (hängt `errors[].code` an die Fehlermeldung); wie `asc_version_texts.py` |
| `records`, `attributes` (`scripts/asc_beta_probe.py`) | Modul | Datensätze und Attribute aus Antworten |
| `GET /v1/builds` mit `filter[app]`, `filter[preReleaseVersion.platform]`, `filter[preReleaseVersion.version]`, `filter[processingState]=VALID`, `filter[expired]=false` | API | Bau je Plattform und Version; Plattformfilter wie `platform_filter` in `asc_wait_build.py`, `processingState`/`expired` wie `BUILD_QUERY` in `asc_beta_invite.py` |
| Apple: App Store Connect API, Anlegen einer Version `POST /v1/appStoreVersions` (Pflicht: `platform`, `versionString`, Relation `app`), Recherche 2026-11-09, Runway-Artikel (https://www.runway.team/blog/apply-promotional-text-and-whats-new-notes-to-new-versions-in-swift-using-the-app-store-connect-api) | Quelle | Form des Anlegens; per API wird der Werbetext nicht von der Vorversion übernommen |
| Apple: Zuordnen eines Baus `PATCH /v1/appStoreVersions/{id}/relationships/build` (204), 409 `ENTITY_ERROR.RELATIONSHIP.INVALID` (https://developer.apple.com/forums/thread/826885) | Quelle | Bau muss `VALID` sein, sonst Konflikt |
| Apple-Hilfe „Create a new version“ (https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version) | Quelle | Beschreibt die Web-Oberfläche (übernimmt Metadaten der Vorversion); für die API nicht belegt, daher `lesen` nach dem Anlegen |
| Beta-Probe 42591946393 (2026-11-09) | Beleg | Build 133 für `MAC_OS` und `IOS`, `VALID`, Version 1.0.1 |
| Store-Probe 42578684646 (2026-11-09) | Beleg | Ist-Stand: iOS 1.0.1 `PREPARE_FOR_SUBMISSION`; Mac nur 1.0 `READY_FOR_SALE` |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_store_version.py | CREATE | `lesen` und `anlegen` (Mac-Version, Bau-Zuordnung, Gegenprobe, Beleg) (ca. 150 LoC) |
| scripts/test_asc_store_version.py | CREATE | Tests mit nachgebautem ASC-Dienst mit Zustand (Muster `FakeASC` aus `test_asc_version_texts.py`), eine Prüfung je AC (ca. 350 LoC) |
| .github/workflows/asc-store-version.yml | CREATE | Handlauf `workflow_dispatch`, Eingabe `aktion` lesen\|anlegen (Standard lesen), Tests zuerst, `concurrency` (ca. 35 LoC) |

Nicht betroffen (geprüft): `scripts/asc_version_texts.py`, `scripts/asc_store_images.py`, `scripts/asc_store_probe.py` und ihre Tests, `docs/reference/app-store-texte.md`, `docs/store/screenshots/`, `ci.yml`, Produktcode, `project.yml`, `CLAUDE.md`.

### Estimated Changes
- Dateien: **3** (Grenze 4–5 eingehalten), dazu die Belege unter `docs/artifacts/feat-842-s5-mac-version/`.
- LoC: ca. **+535** (Skript ca. 150, Tests ca. 350, Workflow ca. 35; Tests nach der Lehre aus 4c-1 mit ≈ 20–30 Zeilen je AC plus ≈ 80 Zeilen Attrappe geschätzt, 4c-1 endete bei 611 statt geschätzt 235), über der 250er-Grenze, ehrlich benannt: Das Skript ist klein, die Tests tragen die Last, weil jede Sicherheitsregel eines Schreibzugriffs auf die Store-Seite (keine zweite Version, keine Umhängung, nichts bei Abweichung schreiben) einzeln bewiesen wird. Dasselbe Muster hatten die Vorgänger 4c-1 und 4c-2. Der Gesamtauftrag wurde bereits in drei Schnitte geteilt; eine weitere Teilung (Lesen / Anlegen) trüge den Nutzen nicht, weil der Beleg erst im Zusammenspiel entsteht. **Meldeschwelle: ca. 620 LoC**; nach dem RED-Schritt werden die Testzeilen gezählt; darüber wird vor dem Weiterbauen gefragt.
- Produktcode: keiner. Keine Berechtigung, keine `Info.plist`, kein Schema.
- „Kein Pfad der Geräteliste berührt.“

## Implementation Details

**1. Aufruf.** `asc_store_version.py lesen|anlegen`; jede andere Eingabe → `::error::`, Ausgang 1, ohne Aufruf gegen Apple. Umgebung wie `asc_version_texts.py` (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_FILE`, `ASC_BUNDLE_ID`, `ASC_API_BASE`, `ASC_POLL_SECONDS`). Ausgabe ohne Schlüssel, Token und Apples Rohantwort. Store-Texte sind öffentlich und dürfen stehen.

**2. `lesen` (nur GET).** Je Version `version <Plattform> <Nummer> state=<Zustand>`. Für die bearbeitbare Version je Plattform (`editable_version`, Plattformen `IOS`, `MAC_OS`; keine → Zeile „keine bearbeitbare Version“):
- Bau: `GET /v1/appStoreVersions/{id}/build` (Einzelobjekt); Ausgabe `bau <Plattform> <Version> (<Nummer>) processingState=<…>` oder `bau <Plattform> kein Bau`. Die Preprelease-Version des Baus kommt aus `GET /v1/builds/{buildId}/preReleaseVersion`.
- Lokalisierungen (`localizations`): je Locale und Feld `description`, `keywords`, `promotionalText`, `whatsNew`, `supportUrl` die Zeichenzahl (`feld zeichen=N`, nie der Wortlaut; die Texte lesen schon `asc_version_texts.py lesen` und die Store-Probe).
- Je Lokalisierung die Zahl der klassischen Bildsätze (`/appStoreVersionLocalizations/{id}/appScreenshotSets`, mit Bildzahl je Satz über `/appScreenshotSets/{id}/appScreenshots`) und der Bibliotheksplatzierungen (`/appStoreVersionLocalizations/{id}/placements`) als `bildsaetze=N bilder=M platzierungen=P`.
- Review-Detail: `GET /v1/appStoreVersions/{id}/appStoreReviewDetail` (Form wie in `asc_review_notes.py`); Ausgabe `review-detail vorhanden` oder `review-detail keines` (kein Wortlaut, keine Kontaktdaten).

**3. `anlegen`, Plan zuerst (nur GET), dann Schreiben.**
1. Zielversion = `versionString` der einen bearbeitbaren iOS-Version. Keine oder mehrere (`editable_version` wirft bei mehreren) → `Fatal`, nichts geschrieben.
2. Mac-Version: `editable_version(versions, "MAC_OS")`.
   - Existiert eine, deren `versionString` von der Zielversion abweicht → `Fatal` mit beiden Nummern, nichts geschrieben (keine Umbenennung, kein Anlegen einer zweiten).
   - Existiert eine mit gleicher Nummer → nicht anlegen, Zeile `version MAC_OS <Nummer> schon vorhanden, übersprungen`.
   - Sonst `POST /v1/appStoreVersions`, Rumpf Typ `appStoreVersions`, Attribute `platform` `MAC_OS` und `versionString` = Zielversion, Relation `app` (Typ `apps`, ID der App). Genau einmal je Lauf; nie eine zweite, weil die Plan-Prüfung vorher und die Gegenprobe nachher genau eine bearbeitbare Mac-Version verlangen.
3. Bau je Plattform (`IOS`, `MAC_OS`), nur wenn die bearbeitbare Version noch keinen Bau hat (`GET …/build` ohne Datensatz):
   - Suche `GET /v1/builds?filter[app]=<id>&filter[preReleaseVersion.platform]=<Plattform>&filter[preReleaseVersion.version]=<Zielversion>&filter[processingState]=VALID&filter[expired]=false&limit=50`. Die Filter tragen Plattform, Version, Gültigkeit und „nicht abgelaufen“ schon bei Apple; zusätzlich prüft das Skript jede Antwortzeile (`processingState` `VALID`, `expired` nicht wahr), statt dem Filter blind zu trauen.
   - Mehrere Treffer → der mit der **höchsten Buildnummer** (numerischer Vergleich der `version`-Zeichenkette, nicht Apples Textsortierung, bei der „99“ vor „133“ stünde); die Wahl steht im Log (`bau <Plattform> gewählt: <Nummer> von <Anzahl> gültigen`). Begründung: Ein neuerer gültiger Bau derselben Version ist der aktuelle Stand; ein Abbruch bei jedem Zweitbau würde den Lauf ohne Nutzen blockieren, und das Zuordnen ist vor dem Einreichen jederzeit durch einen späteren Lauf korrigierbar (Zuordnung ist keine Einreichung).
   - Kein Treffer → `Fatal` für diese Plattform mit Plattform und Zielversion („kein gültiger Bau <Version> für <Plattform>“); für diese Plattform wird nichts zugeordnet. Der Plan aller Plattformen entsteht vor dem ersten Schreiben; ein fehlender Bau bricht deshalb den Lauf ab, bevor die Mac-Version angelegt wird. Ausnahme ist nur die Mac-Version selbst: Existiert sie noch nicht, entsteht sie erst nach der Plan-Prüfung beider Bau-Suchen.
   - Zuordnung `PATCH /v1/appStoreVersions/{versionId}/relationships/build`, Rumpf `{"data": {"type": "builds", "id": <buildId>}}` (Antwort 204).
   - Hat die Version schon einen Bau: unverändert lassen und nennen (`bau <Plattform> schon zugeordnet: <Nummer>, unverändert`), auch wenn ein neuerer gültiger Bau existiert. Es wird nie umgehängt.
4. Schreibfehler: 403 → „Apple lehnt … ab (HTTP 403): Schlüssel ohne Recht oder Version gesperrt“; 409 → „Apple meldet einen Konflikt (HTTP 409) …“ samt `errors[].code`, für die Bau-Zuordnung mit dem Hinweis, dass der Bau gültig, nicht abgelaufen und zur Plattform und Version passend sein muss (`ENTITY_ERROR.RELATIONSHIP.INVALID`). Muster `send` in `asc_version_texts.py`; Apples Rohantwort wird nie ausgegeben.
5. **Gegenprobe im selben Lauf.** Versionen neu lesen: genau eine bearbeitbare `MAC_OS`-Version mit der Zielversion; beide bearbeitbaren Versionen (`IOS`, `MAC_OS`) haben einen Bau, dessen Vorabversion die Zielversion ist. Abweichung → `Fatal` mit Plattform, Soll und Ist. Danach dieselbe Ausgabe wie `lesen` (Punkt 2) als Beleg und `zusammenfassung geschrieben=<N>`.

**4. Nie.** Das Skript hat keinen Pfad für `DELETE`, keine Einreichung (`appStoreVersionSubmissions`, `reviewSubmissions`), keinen Schreibaufruf auf Lokalisierungen, Bildsätze, Platzierungen oder das Review-Detail und legt keine iOS-Version an. Die einzigen Schreibaufrufe sind `POST /v1/appStoreVersions` (nur `MAC_OS`) und `PATCH …/relationships/build`.

**5. Workflow `asc-store-version.yml`.** `workflow_dispatch` mit Eingabe `aktion` (choice `lesen`, `anlegen`; Standard `lesen`), `permissions: contents: read`, `concurrency: { group: asc-store-version, cancel-in-progress: false }`, Schlüssel und Variablen wie in `asc-version-texts.yml`. Erster Schritt: `python3 scripts/test_asc_store_version.py`. Zweiter Schritt: Schlüssel nach `$RUNNER_TEMP` mit `trap` zum Löschen, `umask 077`, dann `python3 scripts/asc_store_version.py "$AKTION"`. Ausgabe nie den Schlüssel. Kopfkommentar nennt: schreibt nur die Mac-Version und die Bau-Zuordnung, nie einreichen, nie löschen. Zusätzlich ein Auslöser `pull_request` (`paths`: `scripts/asc_store_version.py`, `scripts/test_asc_store_version.py`, `.github/workflows/asc-store-version.yml`), der nur die Tests ausführt und die Datei für den Handlauf vom Zweig (`--ref`) registriert; der Apple-Schritt läuft nur bei `if: github.event_name == 'workflow_dispatch'`, Schlüssel und `AKTION` stehen nur in dessen `env` (Muster `asc-store-images.yml`).

**6. Ablauf am echten Konto (Nachweis vor dem Merge).** Vom Zweig aus (`--ref <zweig>`), Protokolle unter `docs/artifacts/feat-842-s5-mac-version/`: (a) `aktion=lesen` vorher, (b) `aktion=anlegen`, (c) `aktion=anlegen` ein zweites Mal (Idempotenz: nichts angelegt, nichts zugeordnet), (d) `aktion=lesen` nachher, (e) Workflow „ASC Store Probe“ (`asc-store-probe.yml`). Erst danach Merge. Scheitert der Lauf vom Zweig, gilt der Rückfall wie in 4c (REST-Aufruf `POST /repos/{owner}/{repo}/actions/workflows/{datei}/dispatches` mit `ref`); ein Aufschub der Belege auf die Zeit nach dem Merge ist ausgeschlossen.

### Alternativen

| Weg | trägt? | Haken |
|---|---|---|
| **API-Weg im Handlauf (gewählt)** | ja | wiederholbar, geprüft, Gegenprobe im Lauf, ohne Hennings Anmeldung; Apple übernimmt per API weniger als in der Web-Oberfläche (Werbetext fehlt, Bilder unklar) — das belegt `lesen` danach und 5a-2/5b füllen auf |
| A Mac-Version in der Web-Oberfläche anlegen (Claude im Browser, Henning meldet sich nur an wie beim CloudKit-Deploy) | ja, aber nicht empfohlen | Apple übernimmt dort laut Hilfe Metadaten der Vorversion samt deutscher Texte und Bilder; 5a-2 schrumpfte dann auf en-US und `whatsNew`. Dagegen: braucht Hennings Anmeldung, im Handlauf weder wiederholbar noch gegenprüfbar, und der iOS-Befund (deutscher Werbetext fehlt trotz Anlegen) zeigt, dass „übernimmt alles“ nicht verlässlich ist. Fällt: das Muster „alles per Handlauf“ (keine ADR-Nummer) |
| B Mehrere Bauten bei Treffer → Abbruch statt höchster Nummer | ja | sicherer gegen Fehlzuordnung, aber blockiert den Lauf bei jedem Zweitbau; verworfen, weil die Zuordnung vor dem Einreichen korrigierbar ist |
| C Bau-Zuordnung in eigenem Schnitt | ja | trennt zusammengehörigen Nutzen („Version einreichbar machen“); verworfen |

Gekippt wird keine ADR.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_store_version.py` (`unittest`, ohne Netz). Nachgebauter ASC-Dienst mit Zustand nach dem Muster `FakeASC` aus `scripts/test_asc_version_texts.py` (lokaler HTTP-Server, `ASC_API_BASE` zeigt darauf): Versionen je Plattform, Bau je Version, Bauliste mit `filter[…]`-Auswertung, `POST /v1/appStoreVersions` (legt eine Version an), `PATCH …/relationships/build` (setzt den Bau, 204), Lokalisierungen, Bildsätze, Platzierungen, Review-Detail; jede Anfrage wird gemerkt, Schreibfehler per Schalter (403, 409 mit Code und einem Geheimwert im Rohtext). RED: das Skript existiert noch nicht.

- [ ] `test_anlegen_creates_mac_version_with_ios_number`: GIVEN iOS 1.0.1 `PREPARE_FOR_SUBMISSION`, Mac nur 1.0 `READY_FOR_SALE` WHEN `anlegen` läuft THEN genau ein `POST /v1/appStoreVersions` mit Typ `appStoreVersions`, `platform` `MAC_OS`, `versionString` `1.0.1`, Relation `app`; danach genau eine bearbeitbare Mac-Version 1.0.1.
- [ ] `test_anlegen_does_not_create_second_mac_version`: GIVEN eine bearbeitbare Mac-Version 1.0.1 existiert WHEN `anlegen` läuft (auch zweimal) THEN kein `POST /v1/appStoreVersions`, Zeile „schon vorhanden, übersprungen“.
- [ ] `test_anlegen_fails_on_mac_version_mismatch`: GIVEN bearbeitbare Mac-Version 1.0.2, iOS 1.0.1 WHEN `anlegen` läuft THEN `Fatal` mit beiden Nummern und die Anfragen enthalten kein Nicht-GET.
- [ ] `test_anlegen_fails_without_or_with_several_ios_versions`: GIVEN keine bearbeitbare iOS-Version bzw. zwei WHEN `anlegen` läuft THEN `Fatal` und kein Nicht-GET.
- [ ] `test_build_is_picked_by_platform_version_and_valid`: GIVEN Bauten verschiedener Plattform, Version (1.0, 1.0.1), Zustand (`VALID`, `PROCESSING`, `FAILED`) und abgelaufen WHEN `anlegen` läuft THEN wird je Plattform nur ein passender gültiger Bau zugeordnet (PATCH-Rumpf trägt dessen ID); die Bauliste wurde mit Plattform-, Versions-, `VALID`- und `expired`-Filter abgefragt.
- [ ] `test_build_highest_number_wins_and_is_logged`: GIVEN mehrere gültige Bauten derselben Version mit den Nummern 99 und 133 WHEN `anlegen` läuft THEN wird 133 gewählt (numerisch, nicht textlich) und das Log nennt Wahl und Anzahl.
- [ ] `test_existing_build_is_left_alone`: GIVEN eine Version hat schon Bau 130, ein gültiger Bau 133 existiert WHEN `anlegen` läuft THEN kein PATCH auf diese Version, Zeile „schon zugeordnet: 130, unverändert“.
- [ ] `test_no_matching_build_is_fatal_and_writes_nothing`: GIVEN für `MAC_OS` kein gültiger Bau 1.0.1 WHEN `anlegen` läuft THEN `Fatal` mit Plattform und Version, kein `POST /v1/appStoreVersions` und kein PATCH (Plan vor dem Schreiben).
- [ ] `test_write_errors_are_clear_without_raw_answer`: GIVEN der Dienst antwortet auf POST bzw. PATCH mit 403 und 409 (mit Code `ENTITY_ERROR.RELATIONSHIP.INVALID`) THEN `Fatal` mit klarer Meldung (und Code), ohne den Geheimwert aus Apples Rohtext.
- [ ] `test_verification_fails_on_deviation`: GIVEN der Dienst ignoriert die Zuordnung (Version bleibt ohne Bau) bzw. liefert zwei bearbeitbare Mac-Versionen THEN die Gegenprobe wirft `Fatal` mit Plattform, Soll und Ist; bei richtigem Stand gibt der Lauf danach die Beleg-Ausgabe aus.
- [ ] `test_lesen_reports_state_and_never_writes`: GIVEN beide bearbeitbaren Versionen mit Bau, Lokalisierungen, Bildsätzen, Platzierungen und Review-Detail (bzw. ohne) WHEN `lesen` läuft THEN zeigt die Ausgabe je Version den Bau (oder „kein Bau“), Zeichenzahlen je Feld (nie den Wortlaut), Bildsätze/Bilder/Platzierungen je Lokalisierung und „review-detail vorhanden/keines“, und die Anfragen bestehen nur aus GET.
- [ ] `test_never_deletes_submits_or_writes_texts`: GIVEN ein voller Lauf `anlegen` (mit Anlegen, ohne Anlegen, mit Wiederholung) WHEN die Anfragen geprüft werden THEN gibt es kein `DELETE`, keinen Pfad mit Einreichung/`submission`, keinen Schreibaufruf auf Lokalisierungen, Bildsätze, Platzierungen oder Review-Detail; nur `POST /v1/appStoreVersions` (mit `MAC_OS`) und `PATCH …/relationships/build`.
- [ ] `test_bad_usage_makes_no_call`: GIVEN keine oder unbekannte Aktion WHEN das Skript startet THEN Ausgang 1 mit `::error::`, ohne Anfrage.
- [ ] `test_workflow_offers_both_actions_and_hides_the_key`: GIVEN die Workflow-Datei THEN enthält `aktion` die Optionen `lesen` (Standard) und `anlegen`, es gibt `concurrency` mit `cancel-in-progress: false`, die Python-Tests laufen als erster Schritt, und der Schlüssel wird nie ausgegeben (Muster `WorkflowTests` in `test_asc_version_texts.py`).

## Acceptance Criteria

- **AC-1:** Given iOS 1.0.1 im Zustand `PREPARE_FOR_SUBMISSION` und keine bearbeitbare Mac-Version, When `anlegen` läuft, Then entsteht genau ein `POST /v1/appStoreVersions` mit `platform` `MAC_OS`, `versionString` gleich der iOS-Zielversion (1.0.1) und Relation `app`, und danach gibt es genau eine bearbeitbare Mac-Version dieser Nummer. Belegt durch `test_anlegen_creates_mac_version_with_ios_number`.
- **AC-2:** Given eine bearbeitbare Mac-Version mit der Zielversion existiert schon, When `anlegen` läuft (auch wiederholt), Then wird keine zweite angelegt und die Zeile „schon vorhanden, übersprungen“ erscheint. Belegt durch `test_anlegen_does_not_create_second_mac_version`.
- **AC-3:** Given eine bearbeitbare Mac-Version mit anderer Nummer als iOS, oder keine oder mehrere bearbeitbare iOS-Versionen, When `anlegen` läuft, Then bricht es mit `::error::` und nennender Meldung ab, ohne einen Nicht-GET-Aufruf. Belegt durch `test_anlegen_fails_on_mac_version_mismatch` und `test_anlegen_fails_without_or_with_several_ios_versions`.
- **AC-4:** Given Bauten verschiedener Plattform, Version, Zustand und Ablauf, When `anlegen` einer Version ohne Bau einen zuordnet, Then ist es ein Bau der passenden Plattform mit Vorabversion gleich der Zielversion, `processingState` `VALID` und nicht abgelaufen; bei mehreren gilt die höchste Buildnummer (numerisch), und die Wahl steht im Log. Zugeordnet wird per `PATCH /v1/appStoreVersions/{id}/relationships/build`. Belegt durch `test_build_is_picked_by_platform_version_and_valid` und `test_build_highest_number_wins_and_is_logged`.
- **AC-5:** Given eine Version hat schon einen Bau, When `anlegen` läuft, Then bleibt dieser unverändert (kein PATCH auf diese Version, auch wenn ein neuerer gültiger Bau existiert) und das Log nennt ihn. Belegt durch `test_existing_build_is_left_alone`.
- **AC-6:** Given für eine Plattform existiert kein passender gültiger Bau der Zielversion, When `anlegen` läuft, Then bricht es mit `::error::` ab, nennt Plattform und Version und hat vorher weder eine Mac-Version angelegt noch einen Bau zugeordnet. Belegt durch `test_no_matching_build_is_fatal_and_writes_nothing`.
- **AC-7:** Given Apple antwortet auf einen Schreibaufruf mit 403 oder 409, When das Skript scheitert, Then nennt die Meldung den Grund (und bei 409 `errors[].code`), nie Apples Rohantwort. Belegt durch `test_write_errors_are_clear_without_raw_answer`.
- **AC-8:** Given der Lauf hat angelegt und zugeordnet, When die Gegenprobe läuft, Then existiert die Mac-Version genau einmal bearbeitbar mit der Zielversion und beide bearbeitbaren Versionen haben einen Bau der Zielversion, sonst `Fatal` mit Plattform, Soll und Ist; danach folgt dieselbe Ausgabe wie `lesen`. Belegt durch `test_verification_fails_on_deviation`.
- **AC-9:** Given `lesen`, When es läuft, Then zeigt die Ausgabe je Version Zustand und Bau (oder „kein Bau“), je Lokalisierung Zeichenzahlen der Felder `description`, `keywords`, `promotionalText`, `whatsNew`, `supportUrl` (nie den Wortlaut), Zahl der Bildsätze, Bilder und Platzierungen und ob ein Review-Detail existiert, und die Anfragen bestehen nur aus GET. Belegt durch `test_lesen_reports_state_and_never_writes`.
- **AC-10:** Given jeder Lauf von `anlegen` und `lesen`, When die Anfragen geprüft werden, Then enthalten sie nie `DELETE`, nie eine Einreichung und keinen Schreibaufruf auf Texte, Bilder, Platzierungen oder das Review-Detail; die einzigen Schreibaufrufe sind `POST /v1/appStoreVersions` (nur `MAC_OS`) und `PATCH …/relationships/build`. Eine unbekannte Aufrufform endet mit Ausgang 1 ohne Anfrage. Belegt durch `test_never_deletes_submits_or_writes_texts` und `test_bad_usage_makes_no_call`.
- **AC-11:** Given die Workflow-Datei, When sie geprüft wird, Then bietet `aktion` `lesen` (Standard) und `anlegen`, es gibt `concurrency` ohne `cancel-in-progress`, die Python-Tests laufen als erster Schritt, ein pull_request-Auslöser führt nur die Tests aus, der Apple-Schritt nur bei workflow_dispatch, und der Schlüssel wird nie ausgegeben. Belegt durch `test_workflow_offers_both_actions_and_hides_the_key`.
- **AC-12:** Given der Zweig ist im Remote und die Läufe aus Punkt 6 gehören zu dieser Fassung, When vom Zweig `lesen`, `anlegen`, `anlegen` (zweites Mal), `lesen` und die Store-Probe laufen, Then besteht jeder Lauf; das erste `anlegen` legt die Mac-Version 1.0.1 an und ordnet fehlende Bauten zu, das zweite legt und ordnet nichts, das `lesen` danach zeigt beide bearbeitbaren Versionen 1.0.1 mit Bau 133 (oder dem gewählten Bau der Zielversion) samt Lokalisierungen, Bildsätzen und Review-Detail-Stand, und die Store-Probe zeigt Mac 1.0.1 `PREPARE_FOR_SUBMISSION`. Belegt durch Run-IDs und zitierte Protokollzeilen unter `docs/artifacts/feat-842-s5-mac-version/`; erst danach der Merge.
- **AC-13:** Given die Änderung berührt nur `scripts/` und `.github/workflows/`, When der Schnitt abgenommen wird, Then endet die Abnahme nach Stufe 2 mit dem Satz „Kein Pfad der Geräteliste berührt.“; der „Benutzen“-Beleg sind die echten Handläufe aus AC-12 gegen Apple. Auf Hennings Geräten läuft nichts. `python3 scripts/test_asc_store_version.py` und die übrigen Skript-Tests (`scripts/test_asc_version_texts.py`, `scripts/test_asc_store_images.py`, `scripts/test_asc_store_probe.py`) sind grün. Belegt durch Dateiliste des Diffs gegen die Geräteliste und die Testläufe.

**Abnahmeweg.** Stufe 1: Python-Tests (AC-1 bis AC-11, AC-13). Stufe 2: die Handläufe vom Zweig aus (AC-12); sie sind zugleich der Beleg, weil das Ergebnis bei Apple liegt. Stufe 3 greift nicht; es gibt keine Nach-Merge-Punkte.

## Definition of Done

- [ ] Die Tests waren vor dem Skript vorhanden (RED) und sind danach grün; die übrigen Skript-Tests bleiben grün.
- [ ] Die Handläufe `lesen` vorher, `anlegen`, `anlegen` (zweites Mal), `lesen` nachher und Store-Probe liefen vom Zweig aus; Run-IDs und zitierte Protokollzeilen stehen unter `docs/artifacts/feat-842-s5-mac-version/`.
- [ ] Die Store-Probe zeigt Mac 1.0.1 `PREPARE_FOR_SUBMISSION`; beide Versionen haben einen zugeordneten Bau 1.0.1.
- [ ] Der Umfang blieb unter der Meldeschwelle von ca. 620 LoC, sonst wurde vor dem Weiterbauen gefragt.
- [ ] PR gemergt, CI grün; #842 kommentiert: Schnitt 5a-1 erledigt mit dem Befund, was Apple beim Anlegen übernommen hat; offen 5a-2 (Texte, `whatsNew`, Werbetext iOS, Review-Detail), 5b (Mac-Bilder) und Hennings Entscheidung zur Einreichung.

## Seiteneffekte

- Geänderte Dateien: die drei oben; dazu die Belege unter `docs/artifacts/feat-842-s5-mac-version/`.
- Bei Apple: eine neue, nicht eingereichte Mac-Version 1.0.1 (Zustand `PREPARE_FOR_SUBMISSION`) und je Plattform, wo nötig, ein zugeordneter Bau. Eine leere Version lässt sich bei Apple wieder löschen (hier nie vom Skript). Keine Einreichung, keine Textänderung, keine Bildänderung.
- Keine neuen Berechtigungen, keine `Info.plist`, keine `project.yml`-Änderung, keine AppStorage-Schlüssel, keine Audio-Dateien, keine neuen Dependencies, kein Produktcode.

## Risiken

- **Schreibzugriff auf die Store-Seite.** Gegenmaßnahmen: Plan vor dem Schreiben (alle Voraussetzungen per GET), `lesen` vorab, Idempotenz (nie eine zweite Version), nie Löschen, nie Einreichen; die Version ist nicht eingereicht, also nicht öffentlich.
- **Antwortformen.** Anlegen und Bau-Zuordnung sind aus Apples Dokumentation erschlossen, nicht aus einem Lauf dieses Skripts; ebenso `GET /v1/appStoreVersions/{id}/build` (Einzelobjekt, kein Treffer = `data: null`). Recherche 2026-11-09: `filter[preReleaseVersion.version]` auf `/v1/builds` ist in Fremdcode belegt (fastlane Spaceship, https://rdoc.info/gems/fastlane/2.137.0/Spaceship/ConnectAPI/Build), `GET /v1/builds/{id}/preReleaseVersion` in Apples Doku (https://developer.apple.com/documentation/appstoreconnectapi/builds.md), `filter[preReleaseVersion.platform]` im Repo (`asc_wait_build.py`); `GET /v1/appStoreVersions/{id}/build` nur aus Apples Referenz erschlossen. Gegenmaßnahme: Fehlercode in der Meldung; scheitert die Form im echten Lauf, wird das Skript korrigiert und der Lauf wiederholt, nie der Nachbau angepasst, um grün zu werden.
- **Bau-Sortierung.** Apples `sort=-version` ist textlich; das Skript wählt numerisch selbst.
- **Gleichzeitige Läufe.** `concurrency` ohne Abbruch serialisiert sie.
- **Umfang.** Ca. 535 LoC; Meldeschwelle ca. 620 LoC.

## Known Limitations

- **Was Apple beim API-Anlegen übernimmt, ist offen:** ob de-DE Texte, Bilder und Review-Detail von Mac 1.0 in die neue Version kommen, belegt erst `lesen` nach dem Anlegen. Die Runway-Quelle spricht dafür, dass der Werbetext fehlt; Bilder sind nicht belegt. 5a-2 und 5b richten sich nach diesem Befund.
- Review-Detail, `whatsNew`, deutscher Werbetext der iOS-Version und alle Texte folgen in 5a-2; Mac-Bilder in 5b.
- Eine Korrektur eines falsch zugeordneten Baus ist nur durch einen anderen Lauf oder von Hand möglich; das Skript hängt nie um.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Betriebswerkzeug ohne Produktcode nach dem Muster der bestehenden ASC-Schreibwege (`asc_version_texts`, `asc_store_images`); es wird keine bestehende ADR gekippt (keine der Alternativen A bis C berührt eine ADR).
- **Rationale:** Der API-Weg im Handlauf setzt das Muster „erst GET, dann Schreiben, dann Gegenprobe im selben Lauf“ aus 3 und 4c fort; die Wahl „höchste Buildnummer bei mehreren gültigen Bauten“ ist eine technische Frage ohne Produktauswirkung.

## Changelog

- 2026-11-09: Initial spec created (Schnitt 5a-1 von #842: Skript `asc_store_version.py` mit `lesen` und `anlegen`; Mac-Version 1.0.1 idempotent anlegen, Bau je Plattform zuordnen (höchste Nummer, vorhandenen nie umhängen), Gegenprobe und Beleg; Handlauf-Workflow; Belege vom Zweig vor dem Merge)
- 2026-11-09: pull_request-Auslöser nur für Tests ergänzt, weil GitHub eine neue Workflow-Datei sonst nicht vom Zweig starten lässt (HTTP 404 not found on the default branch); Muster asc-store-images.yml

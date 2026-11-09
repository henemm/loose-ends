---
entity_id: feat-842-schnitt-5b-mac-bilder
type: feature
created: 2026-11-09
updated: 2026-11-09
status: draft
workflow: feat-842-s5b-mac-bilder
---

# Spec: #842 Schnitt 5b — Englische Mac-Store-Bilder in die Bibliothek legen und auf Mac 1.0.1 (en-US) platzieren

## Approval

- [ ] Approved

Henning hat am 2026-11-09 entschieden, dass der Mac die Version 1.0.1 zusammen mit iPhone und iPad bekommt (Schnitt 5a-1 legte die Mac-Version an, 5a-2 schrieb die Texte). Die vier englischen Mac-Bilder hat er in Schnitt 4b-2 freigegeben. Dieser Schnitt setzt sie auf die englische Seite der Mac-Version. Die Version ist nicht eingereicht, also nicht öffentlich. `approved` gibt die Umsetzung frei.

## Purpose

Die Mac-Version 1.0.1 hat englische Texte, aber keine englischen Bilder (Store-Lesen 2026-11-09: Mac en-US `bildsaetze=0 bilder=0 platzierungen=0`; Mac de-DE trägt vier von Apple übernommene deutsche Bilder). Schnitt 5b erweitert `scripts/asc_store_images.py` um eine Plattform-Angabe: `lesen`, `hochladen` und `platzieren` laufen mit dem optionalen dritten Argument `mac` gegen die bearbeitbare Mac-Version; ohne drittes Argument (oder mit `ios`) bleibt jeder Lauf wie heute. Der Mac-Lauf legt die vier Bilder `en-mac-01-start`, `en-mac-03-neu`, `en-mac-04-detail`, `en-mac-05-erledigt` (1280×800) in die Bibliothek, platziert sie in Manifest-Reihenfolge auf en-US der Mac-Version (Gruppe `MAC_PROFILE`, Typ `APP_SCREENSHOT`), wartet, ordnet nur bei Abweichung und prüft im selben Lauf gegen.

Für Henning ändert sich: Die englische Seite der Mac-Version 1.0.1 zeigt vier Bilder in der gewohnten Reihenfolge, die deutsche Seite bleibt unverändert, nichts wird eingereicht. Er muss nichts tun.

Nicht in diesem Schnitt: Einreichung (nur auf Hennings Wort), Löschen oder Austauschen von Platzierungen, Schreiben auf de-DE, Produktcode.

Ohne Modell geht es nicht: nicht relevant. Betriebsskript gegen die ASC-API, Regelweg.

## Source

- **File:** `scripts/asc_store_images.py`, `scripts/test_asc_store_images.py`, `.github/workflows/asc-store-images.yml` (alle bestehend)
- **Identifier:** `plan`, `preflight`, `upload`, `lesen`, `platzieren`, `german_counts`, `warn_mac`, `main`, `GROUPS`; Eingabe `plattform` im Workflow

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `editable_version`, `app_versions`, `localizations` (`scripts/asc_version_texts.py`) | Modul | `editable_version(versions, "MAC_OS")` liefert die eine bearbeitbare Mac-Version; unverändert |
| `Client`, `REFDATA`, `IMAGES`, `wait_ready` (`scripts/asc_header_upload.py`) | Modul | Lesen und Schreiben gegen die ASC-API; unverändert |
| `docs/store/screenshots/en/manifest.json` | Quelle | Gerät `mac`, `1280x800`, vier Dateien (PR #879); nur gelesen |
| Protokoll `docs/artifacts/feat-842-s5a2-texte/store-version-lesen.log` | Beleg | Ist-Stand Mac 1.0.1: de-DE 1 Bildsatz, 4 Bilder, 4 Platzierungen; en-US 0/0/0 |
| Protokoll der Store-Probe (Lauf 42604414929) | Beleg | Platzierungsgruppe des Mac: `MAC_PROFILE`, Typ `APP_SCREENSHOT` |
| Spec 4c-2 (`docs/specs/feat-842-schnitt-4c-2-en-platzieren.md`) | Vorlage | Ablauf Vorabprüfung → Anlegen → Warten → Ordnen → Gegenprobe; wird unverändert wiederverwendet |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_store_images.py | MODIFY | `GROUPS`-Zuordnung je Plattform, `plan` und `german_counts` nach Plattform gefiltert, Plattform durch `preflight`/`upload`/`lesen`/`platzieren`, drittes Argument in `main` (ca. +40 LoC) |
| scripts/test_asc_store_images.py | MODIFY | Mac-Fälle im `FakeClient` und Tests je AC (ca. +130 LoC) |
| .github/workflows/asc-store-images.yml | MODIFY | Eingabe `plattform` (ios, mac; Standard ios), dritter Parameter im Aufruf, Kopfkommentar (ca. +10 LoC) |
| docs/specs/feat-842-schnitt-5b-mac-bilder.md | NEW | diese Spec |
| docs/artifacts/feat-842-s5b-mac-bilder/ | NEW | Protokolle der Handläufe (Run-IDs, Auszüge) |

Nicht betroffen (geprüft): `asc_header_upload.py`, `asc_version_texts.py`, `asc_store_probe.py`, `docs/store/screenshots/`, Produktcode, `project.yml`, `CLAUDE.md`.

### Estimated Changes
- Dateien: **5** (Grenze 4–5 eingehalten).
- LoC: ca. **+180** (Skript ca. 40, Tests ca. 130, Workflow ca. 10), unter der 250er-Grenze.
- Produktcode: keiner. Keine Berechtigung, keine `Info.plist`, kein Schema.
- „Kein Pfad der Geräteliste berührt.“

## Implementation Details

**1. Plattform.** `PLATTFORMEN = {"ios": {"iphone", "ipad", "watch"}, "mac": {"mac"}}`; `GROUPS` bekommt `"mac": "MAC_PROFILE"`. `main` akzeptiert `<aktion> <sprache>` (iOS, wie heute) und `<aktion> <sprache> ios|mac`; jede andere Plattform → Aufrufhinweis, Ausgang 2, ohne Aufruf gegen Apple. `platzieren de …` bleibt mit `::error::` und Ausgang 1 abgewiesen (für beide Plattformen), ohne Aufruf.

**2. Plan nach Plattform.** `plan(sprache, root, plattform="ios")` nimmt nur Geräte der Plattform; der iOS-Plan ist byte-gleich zu heute (kein `mac`), der Mac-Plan enthält genau die vier Mac-Bilder mit Gruppe `MAC_PROFILE` und Maß 1280×800.

**3. Version je Plattform.** `preflight`, `upload`, `lesen` und `platzieren` suchen `editable_version(versions, "IOS")` bzw. `"MAC_OS"`. Keine oder mehrere bearbeitbare Versionen der Plattform → `Fatal` mit „keine bearbeitbare Version MAC_OS, nichts geschrieben“.

**4. Vorabprüfung unverändert streng, nur GET.** Datei vorhanden, Pixelmaß = Manifest, Gruppe `MAC_PROFILE` und `maxCount` ≥ 4 in den Referenzdaten, Kategorie für `APP_SCREENSHOT`, Lokalisierung en-US an der Mac-Version, alle vier Bilder in der Bibliothek im Zustand `PREPARE_FOR_SUBMISSION` (bei `platzieren`), en-US-Bestand nur aus Plan-Bildern und jedes höchstens einmal. Führen die echten Referenzdaten `MAC_PROFILE` nicht oder mit zu kleinem `maxCount`, endet der Lauf vor jedem Schreiben mit `::error::`; das klärt der erste Lauf `lesen en mac` (Gruppe wird ausgegeben).

**5. Trennung der Plattformen.** Ein Lauf liest und beschreibt nur die Gruppen seiner Plattform. Im Mac-Lauf werden die iOS-Gruppen nie gelesen oder angefasst, im iOS-Lauf nie `MAC_PROFILE`. Der Fremd-Check gilt je Gruppe der Plattform; Mac-Bilder in der Bibliothek (`en-mac-…`) sind für den iOS-Lauf keine „fremden“ Platzierungen, weil dessen Gruppen sie nicht enthalten. Die Bilder-Namen sind plattformeindeutig (`en-mac-…` / `en-iphone-…`).

**6. Gegenprobe.** Wie 4c-2: je Gruppe Namen und Reihenfolge = Manifest (vier Mac-Bilder), de-DE der **Mac-Version** nur gelesen und unverändert gemeldet (`german_counts` zählt die Gruppen der Plattform: Mac vorher `4`, nachher `4`). de-DE wird nie beschrieben.

**7. `warn_mac`.** Im iOS-Lauf bleibt der Hinweis wie heute (er nennt, ob eine bearbeitbare Mac-Version existiert und dass der Mac nicht Teil des Laufs ist); der Text zeigt im iOS-Lauf auf `… mac`. Im Mac-Lauf entfällt er.

**8. `lesen en mac`.** Gibt Version, Lokalisierung, Gruppe `MAC_PROFILE` mit `maxCount`, Kategorie, Bestand der Bibliothek, Plan vorhanden/fehlt und die en-US-Platzierungen der Mac-Version aus; nur GET.

**9. Workflow.** Neue Eingabe `plattform` (Auswahl `ios`/`mac`, Standard `ios`); der Schritt gegen Apple ruft `scripts/asc_store_images.py "$AKTION" "$SPRACHE" "$PLATTFORM"`. Der Schlüssel wird weiter nie ausgegeben, die Python-Tests bleiben erster Schritt, `concurrency` bleibt.

**10. Ablauf am echten Konto (Nachweis vor dem Merge).** Vom Zweig aus, Protokolle unter `docs/artifacts/feat-842-s5b-mac-bilder/`: (a) `lesen` `en` `mac` (Bestand, Gruppe, maxCount), (b) `hochladen` `en` `mac` (vier Bilder), (c) `platzieren` `en` `mac`, (d) `platzieren` `en` `mac` ein zweites Mal (nichts angelegt), (e) `lesen` `en` `ios` bzw. `platzieren` `en` iOS unverändert (nichts angelegt, iOS-Seite unberührt), (f) Workflow „ASC Store Version“ `lesen` (Mac en-US: ein Bildsatz mit vier Bildern, Mac de-DE unverändert 4). Erst danach Merge. Scheitert der Lauf vom Zweig, gilt der Rückfall aus 4c-1 (Workflow per REST-Aufruf mit `ref`); ein Aufschub der Belege auf nach dem Merge ist ausgeschlossen.

### Alternativen

| Weg | trägt? | Haken |
|---|---|---|
| **Plattform-Argument, ein Mechanismus (gewählt)** | ja | kleine Änderung (ca. 180 LoC), jeder Lauf bedient genau eine Plattform, Fehler einer Seite berührt die andere nie |
| A Ein Lauf bedient iOS und Mac (`platzieren en` legt beide an) | ja, nicht empfohlen | ein Fehler auf einer Plattform bricht die andere ab; die schon bewiesene, abgeschlossene iOS-Seite würde im selben Lauf erneut berührt. Fällt: Spec 4c-2 „eine bearbeitbare iOS-Version“ (keine ADR-Nummer) |
| B Von Apple aus de-DE übernehmen lassen (wie beim Anlegen) | nein | es wären deutsche Bilder auf der englischen Seite; de-DE darf nie geschrieben werden |
| C Mac ohne en-US-Bilder einreichen (Fallback auf Deutsch) | nein | lässt das Ziel von #842 (englische Seite vollständig) für den Mac offen |
| D Henning platziert in App Store Connect selbst | nein | widerspricht „nie Arbeit an den PO“ |

Gekippt wird keine ADR.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_store_images.py` (`unittest`, ohne Netz). Der bestehende `FakeClient` bekommt eine bearbeitbare Mac-Version mit Lokalisierungen en-US (leer) und de-DE (4 Platzierungen in `MAC_PROFILE`) und Referenzdaten mit `MAC_PROFILE` `maxCount: 10`; die vier `en-mac-…`-Bilder liegen als `PREPARE_FOR_SUBMISSION` in der Bibliothek. RED: das Plattform-Argument existiert noch nicht.

- [ ] `test_mac_plan_is_only_mac_and_ios_plan_unchanged`: GIVEN das echte Manifest WHEN `plan("en", root, "mac")` und `plan("en", root)` THEN enthält der Mac-Plan genau vier Bilder `en-mac-01-start`, `-03-neu`, `-04-detail`, `-05-erledigt` mit Gruppe `MAC_PROFILE`, 1280×800; der iOS-Plan enthält kein `en-mac-…` und gleicht dem bisherigen (12 Bilder).
- [ ] `test_mac_place_creates_four_on_mac_localization_only`: GIVEN die Mac-Version bearbeitbar, en-US ohne Platzierung WHEN `platzieren en mac` THEN vier `POST appAssetLibraryPlacements` (`APP_SCREENSHOT`, `MAC_PROFILE`, richtiges Bild, Lokalisierung en-US **der Mac-Version**), Manifest-Reihenfolge, Gegenprobe grün, Ausgabe nennt de-DE `4` unverändert; kein Aufruf auf eine iOS-Lokalisierung oder iOS-Gruppe.
- [ ] `test_mac_second_run_places_nothing`: GIVEN die vier Platzierungen WHEN `platzieren en mac` erneut THEN kein POST, vier Zeilen „schon platziert, übersprungen“.
- [ ] `test_mac_orders_only_on_difference`: GIVEN die Platzierungen liegen in falscher Reihenfolge WHEN `platzieren en mac` THEN genau ein Ordnungsauftrag der Gruppe `MAC_PROFILE` mit den IDs in Manifest-Reihenfolge; stimmt sie, keiner.
- [ ] `test_mac_foreign_or_duplicate_aborts_without_write`: GIVEN en-US-Mac trägt eine Platzierung eines Nicht-Plan-Bildes oder dasselbe Bild doppelt WHEN `platzieren en mac` THEN `Fatal` ohne Nicht-GET.
- [ ] `test_mac_preflight_aborts_before_any_write`: GIVEN je einer der Fälle (keine bearbeitbare Mac-Version; zwei bearbeitbare; keine en-US-Lokalisierung der Mac-Version; ein Mac-Bild fehlt oder ist `AWAITING_UPLOAD`; `MAC_PROFILE` fehlt in den Referenzdaten; `maxCount` 3 bei 4 Bildern; Datei hat falsches Maß) WHEN `platzieren en mac` THEN `Fatal` mit nennender Meldung ohne Nicht-GET.
- [ ] `test_mac_upload_creates_only_missing_mac_images`: GIVEN die Bibliothek ohne Mac-Bilder WHEN `hochladen en mac` THEN vier Bilder (`en-mac-…`, Kategorie aus den Referenzdaten) angelegt, hochgeladen, bereit, keine iOS-Bilder angefasst; ein zweiter Lauf legt nichts an.
- [ ] `test_ios_run_untouched_by_mac_images`: GIVEN die vier Mac-Bilder liegen in der Bibliothek und auf Mac en-US platziert WHEN `platzieren en` (iOS) THEN gleicher Verlauf wie bisher (12 Plan-Bilder, kein Fatal wegen Mac-Bildern, keine Aufrufe auf die Mac-Version); der Hinweis zum Mac erscheint weiter.
- [ ] `test_never_deletes_submits_or_writes_german_on_mac`: GIVEN ein voller Lauf `platzieren en mac` (mit und ohne Ordnen, mit Wiederholung) THEN kein `DELETE`, kein Pfad mit Einreichung, jeder Schreibaufruf nennt die en-US-Lokalisierung der Mac-Version, nie de-DE; de-DE Mac danach unverändert 4.
- [ ] `test_mac_lesen_shows_group_and_placements_and_never_writes`: GIVEN `lesen en mac` THEN Ausgabe zeigt Lokalisierung, Gruppe `MAC_PROFILE` mit `maxCount`, Plan vorhanden/fehlt und die en-US-Platzierungen (oder `keine`); Aufrufliste nur GET.
- [ ] `test_main_platform_argument`: GIVEN `main` mit `platzieren en mac`, `lesen en ios`, `lesen en` THEN laufen alle (die ersten beiden mit der jeweiligen Plattform); GIVEN `lesen en tv` oder fünf Argumente THEN Ausgang 2 ohne Aufruf; GIVEN `platzieren de mac` THEN Ausgang 1 mit `::error::` ohne Aufruf.
- [ ] `test_workflow_offers_plattform`: GIVEN die Workflow-Datei THEN hat `plattform` die Optionen `ios` und `mac` (Standard `ios`), der Aufruf übergibt `"$PLATTFORM"`, die Python-Tests laufen als erster Schritt, der Schlüssel wird nie ausgegeben, `concurrency` ohne `cancel-in-progress` bleibt (Erweiterung des bestehenden Workflow-Tests).

## Acceptance Criteria

- **AC-1:** Given das echte Manifest, When der Plan für Mac und der Plan ohne Plattform gebildet werden, Then enthält der Mac-Plan genau die vier Bilder `en-mac-01-start`, `en-mac-03-neu`, `en-mac-04-detail`, `en-mac-05-erledigt` (Gruppe `MAC_PROFILE`, 1280×800) und der iOS-Plan unverändert die zwölf iPhone-, iPad- und Watch-Bilder ohne Mac. Belegt durch `test_mac_plan_is_only_mac_and_ios_plan_unchanged`.
- **AC-2:** Given eine bearbeitbare Mac-Version mit en-US ohne Platzierung und vier bereiten Bibliotheksbildern, When `platzieren en mac` läuft, Then entstehen genau vier Platzierungen (`APP_SCREENSHOT`, `MAC_PROFILE`, richtiges Bild, Ziel en-US der Mac-Version) in Manifest-Reihenfolge, die Gegenprobe ist grün, und es gibt keinen Aufruf auf iOS-Lokalisierungen oder iOS-Gruppen. Belegt durch `test_mac_place_creates_four_on_mac_localization_only`.
- **AC-3:** Given die vier Platzierungen, When `platzieren en mac` erneut läuft, Then entsteht kein POST und jede Zeile meldet „schon platziert, übersprungen“; bei abweichender Reihenfolge entsteht genau ein Ordnungsauftrag der Gruppe `MAC_PROFILE`, bei richtiger keiner. Belegt durch `test_mac_second_run_places_nothing` und `test_mac_orders_only_on_difference`.
- **AC-4:** Given eine fremde Platzierung oder eine Doppelplatzierung in en-US der Mac-Version oder eine fehlende Voraussetzung (keine oder mehrere bearbeitbare Mac-Versionen, keine en-US-Lokalisierung, Bild fehlt oder nicht `PREPARE_FOR_SUBMISSION`, `MAC_PROFILE` fehlt, `maxCount` zu klein, falsches Dateimaß), When `platzieren en mac` läuft, Then bricht es mit `::error::` und benennendem Grund ab, bevor ein Nicht-GET-Aufruf geschieht. Belegt durch `test_mac_foreign_or_duplicate_aborts_without_write` und `test_mac_preflight_aborts_before_any_write`.
- **AC-5:** Given die Bibliothek ohne Mac-Bilder, When `hochladen en mac` läuft, Then legt es genau die vier fehlenden `en-mac-…`-Bilder an (Bytes, `uploaded: true`, Zustand `PREPARE_FOR_SUBMISSION`) und fasst keine iOS-Bilder an; ein zweiter Lauf legt nichts an. Belegt durch `test_mac_upload_creates_only_missing_mac_images`.
- **AC-6:** Given Mac-Bilder in Bibliothek und auf Mac en-US, When der iOS-Lauf `platzieren en` läuft, Then verhält er sich wie vor diesem Schnitt (zwölf Plan-Bilder, keine Aufrufe auf die Mac-Version, kein Fehler wegen Mac-Bildern). Belegt durch `test_ios_run_untouched_by_mac_images`.
- **AC-7:** Given jeder Lauf von `platzieren en mac`, When die Aufrufliste geprüft wird, Then enthält sie nie `DELETE`, nie eine Einreichung und keinen Schreibaufruf auf de-DE; de-DE der Mac-Version bleibt unverändert (4 Platzierungen) und wird in der Gegenprobe nur gelesen gemeldet. Belegt durch `test_never_deletes_submits_or_writes_german_on_mac`.
- **AC-8:** Given `lesen en mac`, When es läuft, Then zeigt die Ausgabe Lokalisierung, Gruppe `MAC_PROFILE` mit `maxCount`, Kategorie, Plan vorhanden/fehlt und die en-US-Platzierungen der Mac-Version (ohne `keine`), und die Aufrufliste besteht nur aus GET. Belegt durch `test_mac_lesen_shows_group_and_placements_and_never_writes`.
- **AC-9:** Given der Aufruf von `main`, When ein drittes Argument `ios` oder `mac` fehlt, `ios` oder `mac` lautet, unbekannt ist, oder `platzieren de` lautet, Then läuft ohne Argument und mit `ios` der bisherige iOS-Weg, mit `mac` der Mac-Weg, eine unbekannte Plattform oder zu viele Argumente enden mit Ausgang 2 und `platzieren de` mit Ausgang 1 und `::error::`, jeweils ohne Aufruf gegen Apple. Belegt durch `test_main_platform_argument`.
- **AC-10:** Given die Workflow-Datei, When sie geprüft wird, Then bietet sie die Eingabe `plattform` (`ios`, `mac`; Standard `ios`), übergibt sie dem Skript, führt die Python-Tests als ersten Schritt aus, gibt den Schlüssel nie aus und trägt `concurrency` ohne `cancel-in-progress`. Belegt durch `test_workflow_offers_plattform`.
- **AC-11:** Given der Zweig ist im Remote und die Läufe aus Punkt 10 gehören zu dieser Fassung, When vom Zweig `lesen en mac`, `hochladen en mac`, `platzieren en mac`, `platzieren en mac` (zweites Mal), der iOS-Lauf `platzieren en` und „ASC Store Version“ `lesen` laufen, Then besteht jeder Lauf; `hochladen` legt vier Bilder an, das erste `platzieren` vier Platzierungen, das zweite und der iOS-Lauf nichts, und „ASC Store Version“ zeigt für Mac en-US vier Bilder in Manifest-Reihenfolge und für Mac de-DE unverändert vier. Belegt durch die Run-IDs und die zitierten Protokollzeilen unter `docs/artifacts/feat-842-s5b-mac-bilder/`; erst danach der Merge.
- **AC-12:** Given die Änderung berührt nur `scripts/`, `.github/workflows/` und `docs/`, When der Schnitt abgenommen wird, Then endet die Abnahme nach Stufe 2 mit dem Satz „Kein Pfad der Geräteliste berührt.“; der „Benutzen“-Beleg sind die echten Handläufe aus AC-11 gegen Apple. Auf Hennings Geräten läuft nichts. `python3 -m unittest scripts/test_asc_store_images.py` und die übrigen Skript-Tests (`test_asc_header_upload.py`, `test_asc_version_texts.py`, `test_asc_store_probe.py`) sind grün. Belegt durch Dateiliste des Diffs und die Testläufe.

**AC-11 und AC-12 sind Abnahme-Nachweise außerhalb des Test Plans** (wie AC-13 und AC-14 in Schnitt 4c-2): Ihr Beleg sind die echten Handläufe, die Dateiliste des Diffs und die Testläufe, kein eigener Python-Test.

**Abnahmeweg.** Stufe 1: Python-Tests (AC-1 bis AC-10, AC-12). Stufe 2: die Handläufe vom Zweig aus (AC-11); sie sind zugleich der Beleg, weil das Ergebnis bei Apple liegt. Stufe 3 greift nicht.

## Definition of Done

- [ ] Die Tests waren vor dem Skript vorhanden (RED) und sind danach grün; die übrigen Skript-Tests bleiben grün.
- [ ] Die Handläufe aus Punkt 10 liefen vom Zweig aus; Run-IDs und zitierte Protokollzeilen stehen unter `docs/artifacts/feat-842-s5b-mac-bilder/`.
- [ ] „ASC Store Version“ `lesen` zeigt Mac en-US mit vier Bildern in Manifest-Reihenfolge, Mac de-DE unverändert.
- [ ] Nebenbefund Evidence-Gate-Override: vor Phase 8 geprüft, ob für diesen Workflow ein Override-Token vorliegt, und im Abschlussbericht genannt.
- [ ] PR gemergt, CI grün; #842 kommentiert: Schnitt 5b erledigt, offen nur Hennings Entscheidung zur Einreichung von 1.0.1 (iOS und Mac).

## Seiteneffekte

- Geänderte Dateien: die fünf oben.
- Bei Apple: vier Bilder in der Asset-Bibliothek der App und vier Platzierungen auf en-US der Mac-Version 1.0.1 (noch nicht eingereicht); eventuell legt Apple einen klassischen Bildsatz mit an (bei de-DE geschah das; die Store-Version-Lesung hält es fest). Keine Einreichung, keine Löschung, de-DE unberührt.
- Platzierungen sind unveränderlich; eine Korrektur wäre nur Löschen und Neuanlegen, das dieser Schnitt nie ausführt.
- Keine neuen Berechtigungen, keine `Info.plist`, keine `project.yml`-Änderung, keine AppStorage-Schlüssel, keine Audio-Dateien, keine neuen Dependencies, kein Produktcode.

## Risiken

- **Schreibzugriff auf die Mac-Store-Seite.** Gegenmaßnahmen: Vorabprüfung ohne Schreiben, `lesen en mac` vorab, Wiederholbarkeit ohne Doppelanlage, nie Löschen. Die Version ist nicht eingereicht.
- **Referenzdaten für den Mac unbekannt.** `MAC_PROFILE` mit `maxCount` und die Kategorie für 1280×800 sind erst durch `lesen en mac` belegt. Fehlt etwas, endet der Lauf vor dem Schreiben; das Skript wird dann korrigiert, nie die Attrappe angepasst, um grün zu werden.
- **Antwortformen am Mac.** Die Mac-Lokalisierung nutzt dieselben Endpunkte wie iOS; weicht Apple ab, zeigt es der Fehlercode im Client, und der Lauf wird nach Korrektur wiederholt.
- **Gleichzeitige Läufe.** `concurrency` ohne Abbruch serialisiert sie.
- **Umfang.** Ca. 180 LoC; über 250 LoC wird vor dem Weiterbauen gefragt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Betriebswerkzeug ohne Produktcode; es wird keine bestehende ADR gekippt (keine der Alternativen berührt eine ADR).
- **Rationale:** Das Plattform-Argument setzt den Weg aus 4c-2 („Bibliothek vor Platzierung“, eine Plattform je Lauf) unverändert fort und vermeidet einen zweiten Mechanismus; die Schnittentscheidung ist eine technische Frage.

## Changelog

- 2026-11-09: Initial spec created (Schnitt 5b von #842: Plattform-Argument `mac` für `lesen`/`hochladen`/`platzieren`, vier englische Mac-Bilder auf en-US der Mac-Version 1.0.1, Gegenprobe mit de-DE nur gelesen, Handläufe vom Zweig vor dem Merge).

# Context: feat-842-s5b-mac-bilder

## Request Summary
#842 Schnitt 5b (Henning, 2026-11-09: Mac bekommt 1.0.1 zusammen mit iPhone): die vier englischen Mac-Store-Bilder
(1280×800) in Apples Asset-Bibliothek legen und auf die en-US-Seite der bearbeitbaren Mac-Version 1.0.1 platzieren.
Nichts einreichen, nichts löschen, de-DE nie schreiben.

## Ausgangslage (Belege)
- Mac 1.0.1 (PREPARE_FOR_SUBMISSION) existiert seit 5a-1, Bau 133 zugeordnet (`docs/artifacts/feat-842-s5-mac-version/`).
- Store-Version-Lesen vom 2026-11-09 (`docs/artifacts/feat-842-s5a2-texte/store-version-lesen.log`): Mac de-DE hat Texte,
  Bildsatz 1 / 4 Bilder / 4 Platzierungen (von Apple beim Anlegen übernommen); Mac en-US hat Texte (5a-2), aber
  `bildsaetze=0 bilder=0 platzierungen=0`. Das ist die Lücke dieses Schnitts.
- Platzierungsgruppe des Mac laut Store-Probe: `MAC_PROFILE`, Typ `APP_SCREENSHOT`; Bildsatz-Typ in der alten API `APP_DESKTOP`.
- Englische Mac-Bilder liegen im Repo: `docs/store/screenshots/en/manifest.json`, Gerät `mac`, 1280x800, 4 Dateien (PR #879).
- Die Bibliothek enthält heute 12 en-Bilder (iPhone 5, iPad 5, Watch 2), keine Mac-Bilder (4c-1: damals keine bearbeitbare Mac-Version).

## Related Files
| Datei | Relevanz |
|-------|----------|
| `scripts/asc_store_images.py` | `GROUPS` kennt nur iphone/ipad/watch; `plan()` lässt Mac aus; `preflight`/`upload`/`platzieren`/`lesen` nehmen nur `editable_version(versions, "IOS")`; `warn_mac` meldet „Mac-Bilder sind nicht Teil dieses Laufs“ |
| `scripts/test_asc_store_images.py` | FakeClient mit Gruppen inkl. `MAC_PROFILE`; `MacTests` (Mac ohne Version = Warnung; falsche Größe bricht ab) und `PlaceTests` zeigen das Muster |
| `.github/workflows/asc-store-images.yml` | Handlauf `lesen|hochladen|platzieren`; PR-Auslöser nur Tests; ggf. Beschreibungstexte anpassen |
| `scripts/asc_version_texts.py` | `editable_version`, `localizations`, `app_versions` (Plattform `MAC_OS`) |
| `scripts/asc_store_probe.py` / `asc_store_version.py` | Gegenprobe (Bildsätze/Platzierungen je Plattform) |
| `docs/store/screenshots/en/manifest.json` | Quelle der Mac-Bilder |

## Existing Patterns
- 4c-1/4c-2: preflight (nur GET) → upload nach Bibliothek → `platzieren` mit Bestandsprüfung (`check_existing`), Anlegen, Warten,
  Ordnen nur bei Abweichung, Gegenprobe, de-DE nur gelesen und unverändert.
- Bildname `<sprache>-<gerät>-<datei ohne .png>`; Mac wäre `en-mac-01-start` usw.
- Fatal-Meldungen enden mit „nichts geschrieben“; nie löschen, nie einreichen.

## Dependencies
- Upstream: Apple-Referenzdaten (`REFDATA`: maxCount je Gruppe, Kategorie für `APP_SCREENSHOT`) – für `MAC_PROFILE` und Maß 1280x800 zu prüfen.
- Downstream: spätere Einreichung von iOS+Mac 1.0.1 (nur auf Hennings Wort); DoD von #842 („Store-Probe zeigt en-US mit Bildsätzen“).

## Offene Fragen für die Analyse
1. Verhalten bei der Mac-Seite: `lookup` muss die Lokalisierungen der Mac-Version lesen (eigene Version-ID, eigene en-US-Lokalisierung).
2. Zuordnung `plan()`/`grouped()` ist eine Sprache über alle Geräte; Plattformwechsel iOS→Mac braucht entweder eine Plattform-Dimension
   (`platzieren en` iOS, `platzieren en mac`) oder einen Lauf, der beide Versionen bedient. Idempotenz: iOS-Bild-Platzierungen dürfen nicht
   angefasst werden und umgekehrt.
3. de-DE Mac hat bereits 4 von Apple übernommene Platzierungen: die Gegenprobe „de-DE unverändert“ muss die Mac-de-DE-Seite einschließen.
4. Reicht der Bibliothekstyp (Kategorie) für Mac-Bilder, oder braucht Mac eine eigene Kategorie/Policy in den Referenzdaten?
5. Umfang: Schätzung 4–5 Dateien (Skript, Test, Workflow, Belege, Spec), Skript-Änderung < 150 LoC; Tests ca. dieselbe Menge.

## Risks & Considerations
- Schreibt in Apples Store-Daten (kein Einreichen, kein Löschen); Gegenprobe im selben Lauf ist Pflicht.
- Nach Platzierung auf einer anderen Plattform darf die iOS-Gegenprobe nicht plötzlich scheitern (gleiche Bildnamen-Präfixe).
- Kein Gerät von Henning betroffen: reiner Apple-API-Weg über CI, Stufe 3 greift nicht („Kein Pfad der Geräteliste berührt.“).
- Hook-Meldung „Evidence-Gate per override umgangen“ (letzte Sitzung): kommt aus `evidence_gate.py` `has_valid_token(name)`, also einem
  vorhandenen Override-Token; Nebenbefund, nicht Teil dieses Schnitts, vor Phase 8 prüfen, ob ein Token für diesen Workflow existiert.

## Analysis

### Type
Feature (Werkzeug/CI, kein Produktcode). Kein Pfad der Geräteliste berührt.

### Befund (am Code gelesen, `scripts/asc_store_images.py`)
- `plan()` lässt Geräte ohne Eintrag in `GROUPS` aus; `GROUPS` kennt kein `mac`. Das Manifest hat `mac`, 1280x800, 4 Dateien (01-start, 03-neu, 04-detail, 05-erledigt).
- `preflight`, `lesen`, `platzieren` nehmen fest `editable_version(versions, "IOS")`; `warn_mac` sagt ausdrücklich „Mac nicht Teil dieses Laufs“.
- `german_counts` zählt über `GROUPS.values()`; eine Mac-Gruppe darf dort nicht stillschweigend in den iOS-Lauf rutschen.
- Mac-Platzierungsgruppe laut Store-Probe (Lauf 42604414929): `MAC_PROFILE`, Typ `APP_SCREENSHOT`, de-DE hat 4 von Apple übernommene Platzierungen, en-US keine.
- Die Test-Hilfe `refdata()` kennt `MAC_PROFILE` bereits; ob die echten Referenzdaten `maxCount` für `MAC_PROFILE` führen, belegt erst ein Lesen-Lauf (Teil des Schnitts, Preflight bricht sonst mit „Gruppe fehlt“ ab, nichts geschrieben).

### Technischer Ansatz (Empfehlung)
Eine Plattform-Dimension, kein zweiter Mechanismus:
- `GROUPS["mac"] = "MAC_PROFILE"`; `plan(sprache, root, geraete)` filtert nach Plattform: iOS-Lauf = iphone/ipad/watch (wie heute), Mac-Lauf = nur mac.
- Aufruf `platzieren en mac` (und `hochladen en mac`, `lesen en mac`); ohne drittes Argument bleibt alles byte-gleich wie heute (iOS). `editable_version(versions, plattform)` und `german_counts(..., gruppen)` bekommen die Plattform durchgereicht.
- Idempotenz ohne Seiteneffekt: Bestandsprüfung läuft je Gruppe, iOS-Gruppen werden im Mac-Lauf nie gelesen oder angefasst, umgekehrt ebenso. Bildnamen `en-mac-01-start` … sind eindeutig.
- Gegenprobe im selben Lauf wie bisher; de-DE der Mac-Version nur gelesen (4/… unverändert).
- `warn_mac` entfällt im Mac-Lauf; im iOS-Lauf bleibt der Hinweis.
- Workflow `asc-store-images.yml`: Eingabe `plattform` (ios|mac), Standard ios.
- Ablauf: Tests (RED/GREEN) → CI `lesen en mac` → `hochladen en mac` → `platzieren en mac` → Store-Probe als Beleg.

### Scope
- Dateien: 5 (Skript, Test, Workflow, Spec, Belege-Ordner)
- LoC: ca. +90 Skript, +120 Tests (innerhalb ±250)
- Risiko: MITTEL — schreibt in Apples Store-Daten (nur Mac-en-US-Bilder, kein Löschen, kein Einreichen), Gegenprobe Pflicht.

### Alternativen
1. **Ein Lauf bedient iOS und Mac** (`platzieren en` legt beide an). Weniger Aufrufe, aber ein Fehler auf einer Plattform bricht den anderen ab; ADR/Spec 4c-2 („eine bearbeitbare iOS-Version“) würde gekippt. Verworfen.
2. **Mac-Bilder von Apple aus de-DE übernehmen lassen** (wie bei de). Geht nicht: es wären deutsche Bilder, en-US wäre falsch; de-DE darf nie geschrieben werden.
3. **Mac ohne en-US-Bilder einreichen** (Fallback auf de). Würde das Ziel von #842 (englische Seite vollständig) für Mac offenlassen.

### Dependencies
`asc_header_upload` (Client, REFDATA), `asc_version_texts` (`editable_version`, `localizations`), `asc_locales`; nachgelagert nur die spätere Einreichung (nur auf Hennings Wort).

### Open Questions
- [ ] Führen die echten Referenzdaten `MAC_PROFILE` mit maxCount ≥ 4 und akzeptieren sie 1280x800? (klärt `lesen en mac` vor jedem Schreiben; kein PO-Thema)
- [ ] Nebenbefund Evidence-Gate-Override: vor Phase 8 prüfen, ob ein Token für diesen Workflow existiert.

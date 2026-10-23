# Adversary Dialog — feat-241-ort-3b
Spec: docs/specs/feat-241-schnitt-3b-aktueller-ort-zuhause-arbeit.md
Datum: 2026-10-23 13:19

## Checkliste
- [x] **AC-1:** Aktueller Ort. Given ein offenes Suchblatt mit erteilter Berechtigung / When „Aktueller Ort“ getippt wird / Then trägt die Aufgabe einen Ort mit dem Standort als Koordinate und Ankommen, es gibt genau eine Revision vom Nutzer, und das Blatt schließt.
- [x] **AC-2:** Erstfrage. Given die Berechtigung ist offen / When „Aktueller Ort“ getippt wird / Then fragt das System einmal „Beim Verwenden“; bei Zusage folgt AC-1, bei Ablehnung bleibt das Blatt offen und die Zeile nennt „Standort ist in den Einstellungen aus“, ohne Dialog und ohne Ort zu setzen.
- [x] **AC-3:** Zuhause/Arbeit festlegen. Given „Zuhause“ ist nicht festgelegt / When die Zeile getippt und ein Treffer gewählt wird / Then zeigt die Zeile den Namen, die Aufgabe bekommt dadurch keinen Ort, und ein zweites Gerät übernimmt den Wert über den Schlüsselspeicher.
- [x] **AC-4:** Zuhause/Arbeit nutzen. Given „Zuhause“ ist festgelegt / When die Zeile getippt wird / Then trägt die Aufgabe diesen Ort, eine Revision. „Ändern“ und „Entfernen“ wirken nur auf den Platz, nie auf Aufgaben, die ihn schon tragen.
- [x] **AC-5:** Standort aus. Given eine Aufgabe mit Ort und verweigerter Berechtigung / Then steht unter der Ortszeile „Standort ist in den Einstellungen aus …“ (grau); bei offener oder erteilter Berechtigung nicht; am Mac nie; hinter „nicht überwacht“.
- [x] **AC-6:** Schon dort. Given eine Aufgabe mit Ort und Ankommen, erteilter Berechtigung, Standort innerhalb Radius plus Genauigkeit (Genauigkeit ≤ 100 m) / Then steht „Du bist schon hier. Erinnert beim nächsten Ankommen.“; bei Verlassen, fernem, unbekanntem oder fehlendem Standort steht er nicht.
- [x] **AC-7:** Mac. Am Mac fehlt die Zeile „Aktueller Ort“; Zuhause/Arbeit gibt es dort und gleichen über den Schlüsselspeicher ab.
- [x] **AC-8:** Echter Weg belegt. Der Durchlauf mit vorgetäuschtem Standort im Simulator ohne feste Ersatzumsetzung zeigt AC-1, AC-2 und AC-6 im Bild (`sim.sh test-proof` plus Standortlauf).
- [x] **AC-9:** Regression. Unit, Build und UI Smoke grün; `generate` hinterlässt keinen Diff.

## Dialog

### Runde 1
**Adversary:** Gelesen: Diff PlaceEditing/PlaceSection/SavedPlaces/Store/CurrentLocation, TaskDetailView-Callback, Spec, Belege. Selbst ausgefuehrt: `./scripts/sim.sh sim-unit PlaceEditingTests` (Test Succeeded, exit 0), `./scripts/sim.sh generate` (exit 0, Arbeitsbaum-Status danach identisch zu vorher: kein Diff), Screenshots 03 und 06 des Standortlaufs geoeffnet und beschrieben (03: Ortszeile "Bahrenfelder Strasse 234A, Hamburg", Ankommen, grau "Du bist schon hier. Erinnert beim naechsten Ankommen."; 06: Blatt offen, "Aktueller Ort" mit grauem "Standort ist in den Einstellungen aus", Zuhause/Arbeit "Noch nicht festgelegt"). Mac-Build-Log endet mit Build Succeeded.

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Views/PlaceSection.swift:298
  Evidence: useCurrentLocation -> CurrentLocationLookup.run -> choose(PlaceHit) -> dismiss; TaskDetailView.swift:291-294 ruft `PlaceEditing.set` (genau eine User-Revision, gleiche Eingabe schreibt nichts, PlaceEditingTests Zeile 18). Event bleibt: `task.place?.event ?? .arrive`. Standortlauf Bild 03.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Places/CurrentLocation.swift:59
  Evidence: run() fragt nur bei notDetermined, refused -> .refused ohne Fix; Sheet bleibt offen, graue Zeile (PlaceSection.swift:218). Unit "Undecided asks exactly once", Standortlauf Bild 05-07.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Views/PlaceSection.swift:283
  Evidence: pick() im defining-Modus ruft nur saved.set, nie choose; Zeile zeigt Namen. Store spiegelt per iCloud-KVS und uebernimmt via takeCloud (SavedPlacesStore.swift:62).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Shared/Models/SavedPlaces.swift:64
  Evidence: place(slot,event) liefert TaskPlace, Aenderung/Entfernen nur ueber Store.set (SavedPlacesStore.swift:50), beruehrt keine TaskItem; Unit "Changing or clearing a slot does not touch a task".
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Services/PlaceEditing.swift:40
  Evidence: Reihenfolge notWatched > Mac > locationOff(refused). Spec "am Mac nie" Standort aus und "hinter nicht ueberwacht": Mac liefert .macOnly, also nie locationOff: vereinbar. Unit-Tests 138-182.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: Shared/Services/PlaceEditing.swift:65
  Evidence: accuracy<0 oder >100 -> nil (NaN faellt ebenfalls durch `>= 0`), 100 m exakt erlaubt, Distanz <= radius+accuracy; showsAlreadyThere nur arrive + whenInUse/always + Fix. Fern: Standortlauf Bild 04.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Places/SavedPlacesStore.swift:11
  Evidence: Store plattformneutral; CurrentLocation.current ist am Mac nil (CurrentLocation.swift:31) und offersCurrentLocation(isMac:) false; Mac-Build erfolgreich.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Places/CurrentLocation.swift:101
  Evidence: SystemCurrentLocation ohne --ui-testing im Lauf benutzt (Bericht + Bilder 01-07), echte Systemfrage, Reverse-Geocoding-Name.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: Shared/Models/SavedPlaces.swift:1
  Evidence: test-green-output.txt "Test Succeeded", simulator-run 7 Tests, generate ohne Diff (selbst geprueft). Hinweis: Mess-/Latenztests laufen in Sim nie (bekannt, #419).
  Status: CONFIRMED

Pruefpunkt 1 (umgedrehte Assertion): berechtigt. FixedCurrentLocation liefert `elsewhere` und der Ort wird aus genau diesem Fix gebaut (PlaceSection.swift:298-306), Abstand 0, Genauigkeit 10 -> AC-6 verlangt "schon hier". Die alte Assertion widersprach AC-6; kein versteckter Fehler. Die Fern-Gegenprobe liefert der echte Standortlauf (Bild 04) und der Unit-Test.

Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: Shared/Services/PlaceEditing.swift:50
  Description: setCurrent laeuft im Produkt nie; der echte Weg nimmt PlaceHit -> PlaceEditing.set (TaskDetailView.swift:293). Die Unit-Tests zu setCurrent (PlaceEditingTests:190, 207) beweisen daher den echten Weg nur indirekt (gleiche Revisionsregel in set).
  Spec requirement: AC-1 — genau eine Revision vom Nutzer
  Conflict: AC-1 ist auf dem echten Weg erfuellt (set -> eine Revision), aber toter Code mit Test erzeugt falsche Sicherheit.
  Remediation: setCurrent entfernen oder im Callback benutzen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Places/SavedPlacesStore.swift:62
  Description: takeCloud ersetzt lokal gueltige Werte durch .empty, wenn der Cloud-Wert beschaedigt ist (decode liefert .empty, next != places), und schreibt die Beschaedigung in die Defaults. Ein beschaedigter Spot macht beide Plaetze unlesbar.
  Spec requirement: AC-3 — Wert ueber Schluesselspeicher
  Conflict: Datenverlust lokaler Plaetze durch fremden Muell; Spec nennt den Fall nicht.
  Remediation: Bei Decodierfehler lokalen Wert behalten.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Views/PlaceSection.swift:60
  Description: Berechtigung und Fix werden nur bei Aenderung von task.place gelesen (`.task(id: task.place)`); Aenderung in den Einstellungen waehrend das Detail offen bleibt zeigt den Hinweis erst nach Neuoeffnen. Schnelles Doppeltippen: `locating` wird erst im Task gesetzt (PlaceSection.swift:299), zwei Laeufe moeglich, zweites set ist No-Op (keine zweite Revision).
  Spec requirement: AC-5/AC-6
  Conflict: Randfall, kein Spec-Verstoss.
  Remediation: locating synchron im Button setzen; bei scenePhase active neu lesen.

### Runde 2
**Adversary:** Nachfragen bewertet. (a) Revision auf dem echten Weg: TaskDetailView.swift:293 `PlaceEditing.set` -> RevisionService.set, eine Revision, No-Op bei gleichem Wert; Beleg PlaceEditingTests Zeile 18 plus Standortlauf. Ausreichend. (b) AC-4 "nie auf Aufgaben": Store.set und SavedPlaces.setting haben keinen Zugriff auf TaskItem; Unit-Test belegt es. (c) Mac-Reihenfolge: .macOnly vor .locationOff ist mit "am Mac nie" vereinbar (Test 162). (d) Randfaelle: Genauigkeit 100 exakt -> ja moeglich, 100.01 und negativ -> nil (Tests 114/119); Spot ohne gueltige Koordinate wird nicht erzeugt, hit.place liefert nil und der Callback bricht per guard ab; Zeile Zuhause ohne Berechtigung unabhaengig vom Standort (Suche braucht keine Berechtigung). (e) Early-Agreement-Skepsis: F001-F003 sind LOW, keiner bricht ein AC. Offen bleibt nur der Geraetetest (Stufe 3, erst auf Hennings Wort), nicht Teil dieses Laufs; nichts auf Geraeten gestartet, Testsperre nicht angefasst.
**Implementierer:** Keine Rueckmeldung noetig; LOW-Befunde optional.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:8e2c8212aa95ae0e04cd7557ddcfafbcdf2f3e96f8c43e07b3a74c816993e163  LooseEnds/Places/CurrentLocation.swift
- sha256:f6474b0150d1d8f14a302f196a2cad20117d5370e39072066c0bfe9d6bdc382e  LooseEnds/Places/SavedPlacesStore.swift
- sha256:65c00a453d8a395af4e579d6f9fe226664aceb87005ee6549a709cb2cbd19387  LooseEnds/Views/PlaceSection.swift
- sha256:5a8c9fee8ac8edac3134043587fb18a423bb58f28ea4735da838ec84fb5e408f  Shared/Models/SavedPlaces.swift
- sha256:5caa38f69e83847038a3108efa96af9bd130c58352b4e6728053a4c81bd14d66  Shared/Services/PlaceEditing.swift

## Prüfbasis

- base: 68a1e65d377d9fcd12592006dc05bdb05e7864ee
- blob:2494a16736c86da570aaea1e3f8a850fd221d342  LooseEnds/Places/CurrentLocation.swift
- blob:8bd62978ed3c5dfa007830957a799fa73a29780e  LooseEnds/Places/SavedPlacesStore.swift
- blob:1d0c85d52c9765c07aaadbb778b1a307b1140ac3  LooseEnds/Views/PlaceSection.swift
- blob:95c9b3c753929f1e18122a640d3d6a5770d5ed2b  Shared/Models/SavedPlaces.swift
- blob:2b12cc720c69e1734af87cb4a4367f5a8cf88fb8  Shared/Services/PlaceEditing.swift

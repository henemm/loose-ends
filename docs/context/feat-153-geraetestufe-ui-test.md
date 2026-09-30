# Context: feat-153 — Gerätestufe fährt den Bedien-Ablauf auf dem iPhone

Issue: [#153](https://github.com/henemm/loose-ends/issues/153) · erhoben 2026-09-28 · Phase 1

## Request Summary

Die dritte Abnahmestufe soll den Bedien-Ablauf auf Hennings iPhone 16 Pro **fahren**, nicht nur
belegen, dass die App startet. Konkret: `scripts/sim.sh` bekommt einen Befehl, der einen benannten
UI-Test (`RecognitionWalkthroughTests`) auf dem angeschlossenen Gerät ausführt, mit klarer Meldung
bei gesperrtem Telefon, mit Screenshots als Artefakt, und `docs/project/04-stand.md` beschreibt die
Stufe neu.

## Related Files

| Datei | Relevanz |
|---|---|
| `scripts/sim.sh` | Die eine Anlaufstelle. `cmd_device_build` (Z. 271–292) hat den signierten Pfad, `cmd_test` (Z. 216–223) den UI-Test-Pfad — der neue Befehl ist die Kreuzung aus beiden. `cmd_lab_run` (Z. 391–420) enthält die einzige empirisch belegte Sperr-Erkennung. |
| `LooseEndsUITests/RecognitionWalkthroughTests.swift` | Der Ablauf, der gefahren werden soll (#144, AC-9). Setzt im Kommentar ausdrücklich voraus: Simulator, also **kein** Apple Intelligence. |
| `project.yml` (Z. 222–245) | UI-Test-Target `LooseEndsUITests`, Bundle-Id `com.henning.looseends.uitests`, Schema `LooseEnds` testet beide Test-Targets. `DEVELOPMENT_TEAM: XK87E2B3VR` steht global (Z. 23), gilt also auch für den Test-Runner. Deployment Target iOS 27.0, Gerät läuft iOS 27.0. |
| `docs/project/04-stand.md` (Z. 142–165) | Abschnitt „Abnahme in drei Stufen“ — Stufe 3 steht dort heute als `./scripts/sim.sh device` und begründet ihre Existenz mit `device-console`. Genau diese Begründung fällt. |
| `Shared/Enrichment/EnrichmentCoordinator.swift` (Z. 25–98) | Reihenfolge Regel → Modell, jedes Feld nur solange leer. Entscheidet, wie sich der Ablauf auf einem Gerät **mit** Apple Intelligence verhält. |
| `Shared/Enrichment/FoundationModelsEnricher.swift` (Z. 64–115) | Das Modell setzt `duration` und `contexts` — dieselben zwei Felder, die der Walkthrough von Hand setzt. |
| `docs/artifacts/fix-144-recognition-pool-empty/screenshots/` | Die vier Screenshots des Simulator-Durchlaufs — von Hand aus dem `.xcresult` geholt, es gibt kein Skript dafür. |
| Plugin `core/hooks/workflow.py` (Z. 268–271, 1283–1304) | `VALID_ARTIFACT_TYPES` und `add-artifact`. Der letzte DoD-Punkt („Prüfpunkt nimmt diesen Lauf als Nachweis an“) hängt hier — anderes Repo. |

## Existing Patterns

- **Signierter Gerätepfad:** `xcodebuild … -destination "id=$id" -derivedDataPath "$(device_derived_data)" -allowProvisioningUpdates DEVELOPMENT_TEAM=$TEAM_ID`. Eigenes DerivedData je Session, getrennt vom Simulator-Pfad.
- **`run_xcodebuild` ist für das Gerät unbrauchbar:** es setzt hart `CODE_SIGNING_ALLOWED=NO` (Z. 129/131). Der neue Befehl braucht wie `cmd_device_build` seine eigene Aufrufstelle.
- **Rückgabewert über `PIPESTATUS`, nie über die Pipe** — die Lehre aus #151: `| xcbeautify` bzw. `| tail -3` lieferten den Status des letzten Glieds, der Fehlerzweig war unerreichbar und die Stufe meldete Erfolg bei „Unable to find a destination“.
- **Sperr-Erkennung heute:** `cmd_lab_run` greppt die Startausgabe nach `BSErrorCodeDescription = Locked` (Z. 408). Das ist die einzige Stelle im Repo, die „gesperrt“ von „fehlgeschlagen“ unterscheidet.
- **Ausgang wird protokolliert, wie er war:** `cmd_lab_run` schreibt Start/Stopp/Abbruch mit Zeitstempel in `Measurement/results/lab-run.log` und unterscheidet Exit 124 (planmäßiges Zeitende) von echten Fehlern.
- **Berichte aus dem Log schneiden:** `extract_reports` holt Blöcke zwischen `<<<REPORT:name>>>`-Markern aus dem Build-Log — der Weg, wie Ergebnisse vom Gerät ins Repo kommen, weil ein Test dort nicht schreiben kann.
- **Lock:** `acquire_lock`/`release_lock` serialisieren Simulator-Läufe. Für das Gerät gibt es das heute nicht, obwohl das Gerät die knappere Ressource ist.

## Recherche (vor der Analyse, Quellen unten)

1. **UI-Tests auf einem physischen Gerät brauchen mehr als einen entsperrten Bildschirm.** Seit iOS 15 verlangt XCUITest auf echter Hardware den Schalter „Enable UI Automation“ in den Entwickler-Einstellungen; beim ersten Lauf fragt das Gerät den Code **am Gerät** ab. Das ist eine Vorbedingung, die kein Skript herbeiführen kann — sie muss erkannt und benannt werden, sonst sieht sie wie ein Fehlschlag des Features aus.
2. **Es gibt keinen belastbaren Sperr-Zustand über `devicectl`.** `devicectl device info lockState` lieferte in einem dokumentierten Fall `passcodeRequired: false`, während das Telefon sichtbar gesperrt war. Auf Hennings Gerät liefert es jetzt `passcodeRequired: true`, `unlockedSinceBoot: true` — ohne kontrollierte Gegenprobe (einmal entsperrt, einmal gesperrt lesen) ist unbekannt, was das Feld hier tatsächlich anzeigt. `device info details` zeigt „Device State: connected“ — das ist der **Verbindungs**zustand, nicht der Sperrzustand; genau diese Verwechslung war die 62-fache Installationsschleife vom 2026-09-28.
3. **`-allowProvisioningUpdates` gilt auch für `xcodebuild test`** und ist der übliche Weg, den Test-Runner auf einem Gerät mitzusignieren.

## Dependencies

- **Upstream:** `xcodebuild test -destination "id=<UDID>"`, `xcrun devicectl` (Geräteermittlung, Start, Sperrzustand), `xcodegen` (Projekt wird erzeugt), Provisioning über Team `XK87E2B3VR`, Gerät im selben WLAN oder am Kabel (jetzt: wired, iOS 27.0, UDID `00008140-00111D582681801C`).
- **Downstream:** `docs/project/04-stand.md` (Stufe 3), die globale und die Projekt-`CLAUDE.md` (dreistufige Abnahme), jeder künftige Ticket-Abschluss.

## Verhältnis zu anderen Tickets

- **#145** (Simulator-Durchlauf erzwingen) ist **offen**. Der dort beschriebene Mechanismus — Artefakttyp `simulator_run`, Prüfsumme, Gate vor `phase8_complete` im Plugin — existiert noch nicht. Der letzte DoD-Punkt von #153 („Der Prüfpunkt nimmt diesen Lauf als Nachweis an“) setzt genau diesen Mechanismus voraus und liegt im Repo `henemm/agent-os-openspec`.
- **#143** (Unified Log des iPhones mitlesen) bleibt offen und wird nicht ersetzt.
- **#151** ist gemergt: die Gerätestufe verschluckt keine Fehlschläge mehr. Auf diesem Stand wird aufgebaut.

## Existing Specs

Es gibt keine Spec für die Abnahmekette — `docs/specs/` enthält nur Produktentitäten (enrichment, measurement, fast). Diese Änderung betrifft Werkzeug und Prozess, also neue Spec-Datei ohne bestehende Verwandtschaft.

## Risks & Considerations

1. **Der Walkthrough kann auf dem Gerät aus einem echten Grund rot werden — und zwar genau wegen Apple Intelligence.** Schritt 3 des Tests tippt den Kontext „Garden“ im Editor an. Hat das Modell ihn vorher schon gesetzt, ist das Antippen ein **Abwählen**, und die folgende Zusicherung scheitert. Der Test ist gegen einen Simulator **ohne** Modell geschrieben (so steht es in seinem Kopfkommentar). Das ist die zentrale Frage für `/20-analyse`: derselbe Test auf dem Gerät, oder ein Ablauf, der modellfest ist.
2. **„Enable UI Automation“ ist eine Handbewegung am Gerät.** Ist sie nicht gesetzt, bricht der Lauf ab. Der Befehl muss diesen Fall vom Feature-Fehlschlag trennen — sonst ist die neue Stufe genauso aussagelos wie die alte, nur langsamer.
3. **Kein verlässlicher Sperr-Zustand.** Die Abbruchmeldung darf nicht auf einem Feld beruhen, das nachweislich lügt. Belegbarer Weg: Probestart über `devicectl` und `BSErrorCodeDescription = Locked` auswerten, wie in `cmd_lab_run`. Das kostet einen zusätzlichen Start und muss gegen die Gegenprobe (gesperrt/entsperrt) gemessen werden, nicht vermutet.
4. **Screenshots „wie beim Simulator-Durchlauf“ gibt es heute nicht.** Bei #144 wurden sie von Hand aus dem `.xcresult` geholt. Entweder wird der Export für beide Läufe gebaut (dann wächst der Schnitt) oder der DoD-Punkt meint ausdrücklich den `.xcresult`-Pfad. Entscheidung gehört in die Analyse.
5. **Das Gerät ist Hennings Telefon.** Ein UI-Testlauf belegt es am Stück und entsperrt. Kein Hintergrund-Polling, kein Warteschleifen-Konstrukt — die Stufe läuft am Ende eines Tickets, einmal, vom Vordergrund aus. Ein Gerätelock analog zum Simulator-Lock wäre folgerichtig.
6. **Scope:** Der letzte DoD-Punkt liegt im Plugin-Repo und gehört zu #145. Wird er hier mitgenommen, sprengt das die 250-LoC-Grenze und die Zwei-Repo-Grenze. Vorschlag für die Analyse: #153 liefert Befehl, Meldung, Screenshots, Doku und den belegten grünen Lauf; der Prüfpunkt wird als Schnitt in #145 geführt.
7. **Der Worktree ist einen Stand hinter `origin/main`** (der Merge-Commit von #151 fehlt) und der Zweigname des vorigen Tickets steht noch. Beides vor dem Implementieren geradeziehen, eigener Zweigname für #153.
8. **Laufzeit.** Ein Gerätelauf ist ein signierter Build plus Installation plus Testlauf. Das ist deutlich länger als `sim.sh device` und wird bei jedem Ticket fällig.

## Analysis

Erhoben 2026-09-29, Phase 2. **Alle Befunde unten sind gemessen, nicht erschlossen** — zwei Läufe
auf Hennings iPhone 16 Pro (UDID `00008140-00111D582681801C`, iOS 27.0, kabelgebunden), Belege in
`docs/artifacts/feat-153-geraetestufe-ui-test/`.

### Type

Feature (Werkzeug und Prozess), mit einem im Gerätelauf reproduzierten Fehlschlag als Kern.

### Befund 1 — Der Walkthrough wird auf dem Gerät rot, und zwar aus einem falschen Grund

Der unveränderte `RecognitionWalkthroughTests` läuft auf dem Gerät an und scheitert nach 42 s in
Schritt 3:

```
RecognitionWalkthroughTests.swift:133: XCTAssertTrue failed -
Der Kontext steht nicht in der Detailansicht, Beschriftung war Contexts
```

**Ursache, visuell belegt** (`geraet-garden-schon-gesetzt.png`, Einzelbild aus der Aufzeichnung
bei t = 28,3 s, unmittelbar vor dem Tippen): Der Kontext „Garden" trägt **bereits einen Haken**,
und der Editor zeigt unten den Abschnitt „Set by AI". Apple Intelligence hat den Kontext gesetzt,
während der Test noch bei der Dauer war — im ersten Screenshot bei t = 17 s stand die Zeile noch
kursiv und ohne Merkmale, die Veredelung lief also asynchron dazwischen.

`FieldEditorView.swift:120–138` ist ein **Umschalter** (`toggle(context)`), kein Setzer. Der Test
tippt „Garden" also nicht an, sondern **ab**. Danach ist die Liste leer, die Beschriftung bleibt
„Contexts", die Zusicherung fällt.

Das ist das Gegenstück zum falschen Grün aus #151: ein **falsches Rot**. Eine Stufe, die bei
funktionierendem Feature rot meldet, ist genauso wertlos wie eine, die bei kaputtem grün meldet.

**Zwei weitere Bruchstellen derselben Art liegen dahinter** und werden erst sichtbar, wenn Schritt 3
steht — aus dem Code belegt, im Lauf noch nicht erreicht:

| Stelle | Warum sie auf dem Gerät bricht |
|---|---|
| `RecognitionWalkthroughTests.swift:141` | Die Zeile wird über den Rohtext gesucht, die Liste zeigt aber `displayTitle` (`TaskItem.swift:118`) — mit Modell also den **Titel**. Der zweite Rohtext „mähen Rasen" wird vom Modell mit hoher Wahrscheinlichkeit zu „Rasen mähen" geglättet; dann ist er nicht mehr auffindbar, und beide Zeilen tragen denselben Text. |
| `RecognitionWalkthroughTests.swift:139` | Nach dem Öffnen der Detailansicht markiert `TaskDetailView.swift:98` die KI-Vermerke als gesehen. Mit Modell-Titel steht die Aufgabe auf `.active`; `ViewRules.swift:16` hält sie dann nur noch über `hasUnseenAIRevisions` in „Neu" — der Filter greift nicht mehr, die Zeile verlässt die Liste. |

Die Dauer (Schritt 2) ist **nicht** betroffen: `durationPicker` ist ein `Picker`, kein Umschalter —
das Antippen von „30 min" setzt den Wert, egal was vorher dastand. Im Lauf ist Schritt 2 grün
durchgelaufen.

### Befund 2 — Bei gesperrtem iPhone wartet `xcodebuild` endlos

Der erste Lauf traf das gesperrte Telefon. Gemessen (`gesperrt-auszug.log`):

```
[MT] Run Destination Preflight: The destination is not ready.
Error Domain=com.apple.dt.deviceprep Code=-3 "Unlock Hennings iPhone 16 Pro to Continue"
  ... because the device is locked.
[MT] Run Destination Preflight: Waiting for the destination to become ready.
```

Drei Dinge daraus:

1. **Der Diskriminator ist belastbar und kommt aus dem richtigen Werkzeug.** `com.apple.dt.deviceprep
   Code=-3` stammt von dem Programm, das das entsperrte Gerät tatsächlich braucht — anders als
   `devicectl … lockState`, das laut Recherche nachweislich falsch meldet. Der in Risiko 3 erwogene
   Probestart über `devicectl` wird dadurch **überflüssig**: er kostet einen zusätzlichen Start und
   misst nicht besser.
2. **Nachträgliches Greppen reicht nicht.** `xcodebuild` bricht nicht ab, es *wartet* — unbegrenzt.
   Ohne Zeitschranke hängt der Befehl, bis jemand ihn bemerkt. Genau diese Bauart erzeugte am
   2026-09-28 die 62-fache Installationsschleife.
3. **Die Prüfung gehört vor den Bau.** Der Fehlschlag kam erst nach ~3 Minuten Bauzeit, weil
   `xcodebuild` erst baut und dann die Destination prüft. Ein Vorab-Start über `devicectl`
   (`BSErrorCodeDescription = Locked`, der in `cmd_lab_run` bereits bewährte Weg) meldet dasselbe in
   Sekunden — nicht als Ersatz für Punkt 1, sondern davor, um die Bauzeit zu sparen.

### Befund 3 — „Enable UI Automation" ist auf dem Gerät bereits gesetzt

Risiko 2 aus Phase 1 ist damit erledigt: Der zweite Lauf startete den Test-Runner ohne Rückfrage am
Gerät (`Test Suite 'RecognitionWalkthroughTests' started`). Es braucht keinen Handgriff und keine
eigene Erkennung dafür. Sollte der Fall doch je auftreten, trägt er dieselbe
`deviceprep`-Fehlerdomäne wie Befund 2 und fällt in dieselbe Meldung.

### Befund 4 — Screenshots gibt es geskriptet, für beide Stufen

`xcrun xcresulttool export attachments --path <xcresult> --output-path <dir>` existiert, erzeugt eine
`manifest.json` mit den im Test vergebenen Namen und liefert zusätzlich eine
**Bildschirmaufzeichnung** des ganzen Laufs (hier 6,5 MB MP4) — aus der das Beweisbild oben stammt.
Das Handauslesen aus #144 entfällt damit für Simulator **und** Gerät. Risiko 4 ist entschieden:
Export wird gebaut, nicht auf den `.xcresult`-Pfad verwiesen.

### Technical Approach (Empfehlung)

**Der Walkthrough wird modellfest, statt das Modell auszuschalten.**

Die Zusicherungen prüfen künftig *das Ergebnis* („der Kontext steht dran"), nicht *den Weg dorthin*
(„ich habe ihn angetippt"). Konkret drei Eingriffe im Test, keiner davon im Produktpfad:

1. **Schritt 3 wird bedingt.** Der Auswahlzustand liegt bereits als Merkmal vor
   (`FieldEditorView.swift:136`, `.isSelected`). Nur antippen, wenn nicht gesetzt. Damit prüft der
   Schritt weiterhin „am Ende trägt die Aufgabe Garden" — mit und ohne Modell.
2. **Zeilen werden nicht mehr über den Rohtext gesucht.** „Neu" sortiert nach Erfassungszeit
   absteigend (`ViewRules.swift:17`), die jüngste Erfassung ist also immer die oberste Zeile. Die
   Identität wird in der Detailansicht über `detailRawText` (`TaskDetailView.swift:47`) bestätigt —
   der Rohtext ist unveränderlich, der Titel nicht.
3. **Die Rückkehr in die Liste fordert nicht mehr die erste Zeile.** Sie prüft, dass die Liste steht,
   nicht dass eine Aufgabe darin geblieben ist, die das Modell legitimerweise weitergerückt hat.

**Warum nicht die Alternativen** (Grundregel „in Alternativen denken"):

| Weg | Warum nicht |
|---|---|
| **Modell per Startargument abschalten** (`--no-model`, `FoundationModelsEnricher` meldet „nicht verfügbar") | Deterministisch und billig — aber die Gerätestufe belegt dann genau das nicht mehr, wofür sie laut Aufgabenbeschreibung existiert („inklusive des Verhaltens bei vorhandenem Apple Intelligence"). Sie wäre ein zweiter Simulator auf teurer Hardware. **Bleibt als Rückfall**, falls der modellfeste Ablauf sich als unruhig erweist. |
| **Eigener Gerätetest, der das Modell erwartet** (z. B. „nach dem Erfassen steht ein Kontext dran") | Misst das Modell statt das Feature. Das Modell ist nicht deterministisch; der Test würde sporadisch rot und damit wertlos. Die Grundregel „Regeln vor Modell" gilt auch für Zusicherungen. |
| **Denselben Test unverändert fahren** | Gemessen rot, siehe Befund 1. Falsches Rot bei funktionierendem Feature. |

**Der Befehl** `./scripts/sim.sh device-test <Klasse[/test]>`:

- Signatur-Aufruf wie `cmd_device_build` (eigene Aufrufstelle, weil `run_xcodebuild` hart
  `CODE_SIGNING_ALLOWED=NO` setzt), Rückgabewert über `PIPESTATUS` (die Lehre aus #151).
- **Vor** dem Bau ein Probestart über `devicectl` auf `BSErrorCodeDescription = Locked` — spart die
  drei Minuten Bauzeit bei gesperrtem Telefon.
- **Während** des Laufs eine Zeitschranke plus Auswertung von `com.apple.dt.deviceprep Code=-3`, damit
  ein zwischenzeitliches Sperren nicht in eine Endlosschleife führt.
- **Danach** `xcresulttool export attachments` nach `docs/artifacts/<workflow>/screenshots/`.
- **Gerätelock** analog `acquire_lock`, weil das Gerät die knappere Ressource ist als der Simulator.

### Affected Files

| Datei | Change Type | Beschreibung |
|---|---|---|
| `scripts/sim.sh` | MODIFY | `cmd_device_test` + Sperr-Vorabprüfung + Screenshot-Export + Gerätelock + Hilfetext und Dispatch |
| `LooseEndsUITests/RecognitionWalkthroughTests.swift` | MODIFY | Die drei Eingriffe oben; Kopfkommentar von „Simulator, also kein Apple Intelligence" auf „beide Stufen, mit und ohne Modell" |
| `docs/project/04-stand.md` (Z. 142–165) | MODIFY | Stufe 3 neu: was sie belegt (der Ablauf läuft), was sie voraussetzt (entsperrt, gleiches Netz), Begründung nicht mehr `device-console` |
| `docs/artifacts/feat-153-geraetestufe-ui-test/` | CREATE | Belege dieser Analyse, später die Screenshots des grünen Laufs |

### Scope Assessment

- Dateien: **3** geändert, 1 Verzeichnis neu — innerhalb der Grenze von 4–5
- Geschätzte LoC: **+150 / −25** — innerhalb der 250er-Grenze
- Risiko: **Mittel**. Der Produktpfad wird nicht angefasst; alle Änderungen liegen in Werkzeug, Test
  und Doku. Das Mittel statt Niedrig kommt allein daher, dass der Nachweis von fremder Hardware und
  einem entsperrten Telefon abhängt.

### Entschiedene Fragen

- **Umfang:** Der letzte Punkt der Aufgabenbeschreibung („Der Prüfpunkt nimmt diesen Lauf als Nachweis
  an") liegt im Werkzeug-Projekt und gehört zu #145. Von Henning am 2026-09-29 dorthin verschoben.
  #153 liefert Befehl, Abbruchmeldung, Screenshots, Doku und den belegten grünen Lauf.
- **Modell an oder aus:** an. Der Ablauf wird modellfest gemacht (technische Entscheidung, begründet
  oben).
- **Sperr-Erkennung:** `deviceprep Code=-3` aus `xcodebuild`, davor ein schneller `devicectl`-Probestart.
  Kein `lockState`.

### Nebenbefund (gehört nicht in dieses Ticket)

Das Beweisbild zeigt die Kontextliste **doppelt**, einmal englisch und einmal deutsch (Computer/
Computer, Phone/Telefon, Home/Haus, Garden/Garten, Errands/Besorgung, Out and about/Unterwegs).
Der Lauf benutzt einen frischen In-Memory-Speicher und `-contextsSeeded NO`; trotzdem stehen die
Startkontexte zweimal da. Das ist nicht Gegenstand dieser Aufgabe und wird als eigenes Issue
angelegt, sobald es außerhalb des Testlaufs bestätigt ist — im Testaufbau könnte es an der
erzwungenen Sprache liegen.

## Analysis — Neuschnitt nach dem echten Gerätelauf (2026-09-30)

Die erste Analyse führte zu einer Spec, die umgesetzt und gefahren wurde. Der erste echte Lauf auf
Hennings iPhone hat ihre Prämisse widerlegt. Dieser Abschnitt ersetzt die Bewertung oben; die
Faktensammlung darüber bleibt gültig.

### Type

Feature — aber mit umgekehrtem Vorzeichen: **Rückbau statt Aufbau.**

### Was der echte Lauf gezeigt hat

Lauf vom 2026-09-30, 06:19–06:20, `RecognitionWalkthroughTests` auf `00008140-00111D582681801C`,
Exit 0, Test bestanden. Belege unter `docs/artifacts/feat-153-geraetestufe-ui-test/screenshots/`.

1. **Der Lauf ist invasiv.** Er überschrieb die produktive App (gleiche Kennung
   `com.henning.looseends`), installierte zusätzlich `com.henning.looseends.uitests.xctrunner`, und
   die neu gebaute Sperr-Vorprüfung startet die App im Vordergrund. Das Gerät war 5–10 Minuten
   exklusiv belegt und musste entsperrt bleiben.
2. **Er beweist nicht, wofür er gebaut wurde.** Auf `4-zweite-aufgabe-mit-uebernommenen-werten.png`
   ist das Titelfeld leer — Apple Intelligence hat im Testlauf nichts gesetzt. Der Lauf prüfte
   damit dasselbe wie der Simulator, nur invasiver. Der neue bedingte Zweig in Schritt 3 wurde nie
   betreten; der Anhang `schritt3-zweig` zeigt auch auf dem Gerät „Kontext war nicht gesetzt —
   angetippt".
3. **Er ist blind gegen sichtbare Fehler.** Auf demselben Bild steht „Garden, Garten, Garden" statt
   „Garden". Der Test prüft `label CONTAINS "Garden"` und ist grün. → #157, #158.
4. **Er verletzt eine bestehende Entscheidung.** In `scripts/sim.sh` steht als Begründung für die
   Labor-App wörtlich: „Gemessen wird in der Labor-App auf dem iPhone, nicht in einem Testlauf: ein
   Testlauf belegt das Gerät am Stück und entsperrt, bis er fertig ist. Henning benutzt sein iPhone
   den ganzen Tag." Dazu im Gedächtnis seit 2026-09-20: „kein Fernstart einer App auf seinem iPhone,
   nie." Beides wurde beim Bau übersehen, nicht gekippt.

### Geprüfte Alternative: passiv zuhören statt aktiv drücken

Naheliegender Ausweg: Die App schreibt bereits unter 11 `Logger`-Kategorien
(`com.henning.looseends`: App, Calendar, Notifications, Speech, Capture, Detail, Sidebar, List,
Share, Enrichment, Persistence). `EnrichmentCoordinator` protokolliert Modellverfügbarkeit,
Aufrufzahl, geschriebene Felder und Fehler; alle interpolierten Werte sind bereits mit
`privacy: .public` annotiert. Statt einen Ablauf nachzuspielen, könnte man mitlesen, während Henning
die App ohnehin benutzt.

**Diese Alternative trägt in der gedachten Form nicht.** Am Werkzeug nachgeprüft:

- **`devicectl` hat kein Log-Subkommando.** Die vollständige Liste von `device info` lautet
  `appIcon, appResize, appearance, apps, audio, authListing, ddiServices, details, displays, files,
  lockState, processes, voiceover`. Nichts davon liest das Systemprotokoll.
- **`--console` liest die Standardausgabe, nicht `os_log`.** Apples Hilfe: „--console bridges the
  app's stdout to devicectl's stdout." Die App schreibt aber ausschließlich über `Logger`, nie über
  `print` (Projektregel). **Damit liest `cmd_device_console` (`sim.sh:348–363`) nicht, was sein
  Kommentar behauptet** — eigener Befund, als #160 erfasst. #143 baut auf der Annahme auf, hier
  existiere ein Kanal; der existiert nicht.
- **Ein funktionierender Weg existiert woanders:** `xcrun xctrace record --template Logging
  --all-processes --device <UDID>` zeichnet über Instruments auf, ohne die App zu starten. Es gibt
  sogar ein Instrument **„Foundation Models"** (auf dieser Maschine vorhanden). Das ist im Projekt
  nie benutzt worden, schwerer zu skripten als `devicectl`, und sein Zustimmungsverhalten am Gerät
  ist ungeklärt (`--no-prompt` legt einen Dialog nahe). Gehört in einen Spike, nicht in eine
  Umsetzung.

**Drei tragende Einwände gegen den passiven Ansatz, unabhängig vom Werkzeug:**

1. **Abwesenheit ist mehrdeutig.** Fehlt eine erwartete Logzeile, ist unklar, ob das Feature kaputt
   ist, der Codepfad nie ausgelöst wurde, die Verbindung abriss oder der Wert redigiert wurde. Ein
   aktiver Test liefert Ja/Nein, ein Zuhörer bestenfalls „nicht gesehen" — strukturell schwächer und
   genau die Richtung des falschen Grüns aus #151.
2. **Kein Bezug zum geprüften Stand.** Ohne Installation reagiert die Beobachtung auf irgendeine
   früher installierte Fassung. Eine Zuordnung zum aktuellen Stand bräuchte erst eine Build-Kennung
   in einer Startzeile des Protokolls — neue Arbeit, keine Fußnote.
3. **Es ist bereits ein anderes Ticket.** #143 („sim.sh liest das Unified Log des iPhones nicht")
   deckt genau das ab, und der Abschnitt „Verhältnis zu anderen Tickets" oben hält ausdrücklich
   fest, dass #143 nicht ersetzt wird. Die Idee jetzt hierher zu ziehen wäre erneut Scope-Wachstum.

Deckung der acht Bereiche durch passives Zuhören, falls der Spike trägt: App-Gruppe/CloudKit gut
(`ModelContainerFactory` protokolliert fehlendes Entitlement und CloudKit-Rückfall bei jedem Start),
Share gut, Apple Intelligence und Mikrofon nur teilweise (protokolliert wird *dass*, nie *ob
sinnvoll*), Watch eingeschränkt (teilt sich die Kategorie „Capture" mit dem iPhone), Mitteilungen
eingeschränkt (Zustellung liegt Stunden später), **Widgets gar nicht** (kein einziger `Logger` unter
`LooseEndsWidgets/`), Signierung gar nicht (Fehler treten beim Installieren auf, nicht zur Laufzeit).

### Entscheidung

**#153 wird zum Rückbau.** Die Gerätestufe fährt keine Bedienabläufe. Der gebaute Befehl kommt
wieder heraus, und die dritte Stufe steht wieder auf dem, was unstrittig und nicht invasiv ist:
`device-status` (rein lesend) plus die Labor-App, die Henning selbst antippt.

Begründung in einem Satz: Ohne Fernstart und ohne Installation gibt es keinen Bedienablauf auf
diesem Gerät — und beides ist aus gutem Grund ausgeschlossen.

### Affected Files

| Datei | Change Type | Beschreibung |
|---|---|---|
| `scripts/sim.sh` | MODIFY | `cmd_device_test`, `device_probe_locked`, `acquire_device_lock`/`release_device_lock`, Dispatch-Zeile und Hilfetext wieder entfernen; `trap cleanup_locks EXIT` zurück auf `trap release_lock EXIT`; `MAIN_BUNDLE_ID`, `DEVICE_LOCK_DIR` entfallen |
| `scripts/tests/device-test.sh` | DELETE | Prüfstand des entfernten Befehls; die Lehre daraus (Aggregation, Selbsttest) wandert in die ADR, nicht in totes Prüfgerüst |
| `docs/project/04-stand.md` | MODIFY | Abschnitt „Abnahme in drei Stufen": Stufe 3 ist `device-status` plus Labor-App, mit dem Satz, warum kein Bedienablauf darauf läuft |
| `docs/project/00-entscheidungen.md` | MODIFY | ADR-11-Zusatz ersetzen: nicht „ein Smoke-Test läuft zusätzlich auf dem iPhone", sondern „auf Hennings Gerät läuft kein Testlauf und kein Fernstart; was nur Hardware zeigt, wird gemessen (Labor-App) oder beobachtet, nicht bedient" |
| `LooseEndsUITests/RecognitionWalkthroughTests.swift` | KEEP | Die drei Eingriffe (Endzustand statt Bedienweg) sind unabhängig richtig und bleiben — der Test läuft künftig nur im Simulator. Die Verschärfung auf Wertgleichheit ist #158. |

### Scope Assessment

- Dateien: 4 geändert, 1 gelöscht
- Geschätzte Zeilen: −165 / +35 (Netto-Rückbau)
- Risiko: **Niedrig** — es wird nur entfernt, was noch nirgends benutzt wird, und kein Produktpfad berührt

### Reihenfolge der Folgearbeit

1. **#153** (dieser Rückbau)
2. **#156** Kennungs-Trennung — durch den Vorfall dringlicher, nicht optional: `device`,
   `device-build`, `device-install` und `lab` installieren weiterhin unter der Produktivkennung.
   Aufwand höher als gedacht: App-Gruppe und iCloud-Container sind in
   `ModelContainerFactory.swift:12–13` hart verdrahtet, und `WKCompanionAppBundleIdentifier`
   (`LooseEndsWatch/Info.plist:34`, `project.yml:109`) verweist fest auf die Haupt-Kennung — ein
   Zusatz bricht die Watch-Kopplung.
3. **#160** `device-console` klären (liest die falsche Quelle)
4. **#143** Spike: trägt `xctrace record` als Beobachtungskanal? Erst danach ein Befehl.
5. **#158** Walkthrough auf Wertgleichheit verschärfen · **#157** dreifacher Kontext · **#159**
   warum das Modell im Prüfbetrieb keinen Titel setzt

### Open Questions

- Keine für diesen Schnitt. Die offenen Fragen hängen alle an Folge-Tickets und sind dort benannt.

## Quellen

- [Running XCTests from the Command Line (Tauk Blog)](https://medium.com/tauk-blog/running-xctests-from-the-command-line-f2e5ce0b4bfd) — `-destination 'platform=iOS,id=<UDID>'`
- [WebDriverAgent-Aufruf mit `-allowProvisioningUpdates`](https://www.minitap.ai/docs/mobile-use-sdk/physical-ios-quickstart) — Signierung des Test-Runners auf dem Gerät
- [iOS 15 — UI Test keeps asking pin code for „Enable UI Automation“ (Apple Developer Forums)](https://developer.apple.com/forums/thread/693273) — Vorbedingung am Gerät, physische Code-Eingabe
- [Xcode „Device Locked“ trotz entsperrtem iPhone (Repeato)](https://www.repeato.app/blog/xcode/resolving-the-device-locked-error-in-xcode-when-your-iphone-is-unlocked/) — Fehlerbild und Fehlalarme
- [`lockState` meldet `passcodeRequired: false` bei gesperrtem Telefon (callstack/agent-device #2861)](https://github.com/callstack/agent-device/issues/2861) — kein validierter Sperr-Diskriminator
- [devicectl — The Apple Wiki](https://theapplewiki.com/wiki/Devicectl) — Befehlsumfang
- [Apple DTS zu automatisiertem Testen mit Foundation Models](https://developer.apple.com/forums/thread/794408) — Apple empfiehlt ein eigenes Auswertungswerkzeug mit Datensätzen, keinen UI-Test; Drosselung nur bei Akku UND Hintergrund
- [Run Your iOS App Without Overwriting The App Store Version (Xebia)](https://xebia.com/blog/run-your-ios-app-without-overwriting-the-app-store-version/) — Kennungs-Zusatz je Build-Konfiguration
- [Build Customizations (Kodeco)](https://www.kodeco.com/books/ios-app-distribution-best-practices/v1.0.ea1/chapters/10-build-customizations) — `BUNDLE_ID_SUFFIX` als benutzerdefinierte Build-Einstellung
- [Mobile Testing Best Practices (Pie)](https://pie.inc/blog/mobile-testing-best-practices/) — „Conflicts are inevitable when your test environment is also someone's manual playground"
- [On-device smoke test: install, launch, trust, App Groups (StillMotions #44)](https://github.com/Brian-Egan/StillMotions/issues/44) — Gerätestufe prüft benannte Einzelpunkte, nicht einen nachgespielten Ablauf
- [Debug iOS Device Bugs With Xcode 27 Device Hub (The Swift Dev)](https://www.theswift.dev/posts/debug-ios-device-bugs-with-xcode-27-device-hub/) — Beobachtung ohne XCUITest: Protokolle, Absturzberichte, App-Datencontainer

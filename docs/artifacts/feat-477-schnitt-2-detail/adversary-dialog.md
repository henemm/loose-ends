# Adversary-Dialog feat-477-schnitt-2-detail

Prüfer: Agent `implementation-validator`; Orchestrator relayiert Beweise. Zwei Runden. Stand der Runde 2: Commit 4b3efe9
(Politur) auf PR #524.

## Checkliste (Gate-Format)

### Runde 1 (Verlauf, Stand Schritt 2; Kästchen erst in Runde 2 und 3)

Befunde und Nachfragen, Stand Schritt 2 (Commit-Reihe 0db3f94, d848ff1, 4e8debf):
- AKZEPTIERT: **AC-1:** `DetailLayout.titleSize(wide:)` 30/23, `columnWidth` 760.
  Code reference: LooseEnds/Views/DetailLayout.swift
  Code reference: LooseEndsTests/DetailLayoutTests.swift
  Evidence: `test-green-output-schritt2.txt` Zeilen 905, 906, 913 grün.
- AKZEPTIERT: **AC-2:** Mac-Detail als Papier mit Haarlinien ohne Karten.
  Code reference: LooseEnds/Views/TaskDetailView.swift
  Evidence: `mac-gallery-light-3-detail-schritt2.png` und dunkles Gegenstück zeigen Zeilen auf Papier. Vergleichsbild `…-schritt1-karten.png` zeigt abgerundete Karten.
- NACHFRAGE: **AC-3:** Titel groß in Serife ohne „Title“, Kopf „SAID“, Köpfe in Großbuchstaben. Am Mac-Bild fehlt „SAID“, weil die Galerie-Aufgabe keinen gesagten Satz hat.
- NACHFRAGE: **AC-4:** Spalte mittig und höchstens 760 pt. Das Mac-Fenster ist zu schmal, die Kappung greift im Mac-Bild nie.
- AKZEPTIERT: **AC-5:** iPad breit.
  Code reference: LooseEnds/Views/Paper.swift
  Evidence: `ipad-landscape-detail.png`.
- NACHFRAGE: **AC-6:** Dreipunktprüfung, Punkt 3 am Mac nicht beurteilbar.
- NACHFRAGE: **AC-7:** UI-Tests und CI offen.
- NACHFRAGE: **AC-8:** Mac-Popover nicht belegt.

### Runde 2

Beweise, selbst gesehen oder gemessen. Stand Commit 4b3efe9 (Politur).

- [x] **AC-1: AKZEPTIERT.**
  Code reference: LooseEnds/Views/DetailLayout.swift
  Code reference: LooseEndsTests/DetailLayoutTests.swift
  Code reference: LooseEnds/Views/Paper.swift
  Code reference: LooseEnds/Views/TaskDetailView.swift
  Evidence: `titleSize(wide:)` liefert 30 bzw. 23, `columnWidth` ist 760. `DetailColumn` in `Paper.swift` setzt `frame(maxWidth: DetailLayout.columnWidth)`, und die `@ScaledMetric`-Basen in `TaskDetailView` ziehen die Werte. `testTitleIsLargerOnWide`, `testColumnIsAtMost760` und `testCompactTitleSizeIsUnchanged` stehen grün in `test-green-output-schritt2.txt`. `test-green-output-politur.txt` endet mit „Test Succeeded“ und „Unit-Tests bestanden“.
  Die Zahl „817“ bzw. „823 Tests“ steht in keiner Datei und ist nur Entwickleraussage. Übersprungene Tests im Bericht einzeln nennen: `SelfConsistencyReportTests/writesReport` (Messlauf fehlt `selfconsistency-run.json`), `SpeechLatencyTests/firstWordArrivesWithinThreeSecondsOfSpeechStart`, `SpeechLatencyTests/finalTextContainsKeyWords`. Die letzten beiden stehen nur in der Entwickleraussage, die Datei nennt nur den ersten.

- [x] **AC-2: AKZEPTIERT.**
  Code reference: LooseEnds/Views/TaskDetailView.swift
  Code reference: LooseEnds/Views/Paper.swift
  Evidence: `mac-gallery-light-3-detail-politur.png` und `mac-gallery-dark-3-detail-politur.png` (je 1024x674 px) selbst geöffnet. Titel, Hinweis, „Tags“-Zeile, Wortleiste, NOTE, ATTACHMENTS, „Show in calendar“, PLACE, SUBTASKS und WAITING ON stehen als Zeilen auf Papier, getrennt durch Haarlinien. Keine abgerundeten Karten. Hell und dunkel jeweils die richtige Papierfarbe. Das helle Bild ist links und oben vom Aufnahmeweg abgeschnitten (Titel „Rasen mähen“ und Spalte sind vollständig), das dunkle ist vollständig.
  Code-Beleg: Auf breit nimmt `container` in `TaskDetailView.swift` `List { … }.listStyle(.plain)` statt `Form`, und `detailRow()` setzt `listRowBackground(Paper.ground)`.
  Auffälligkeit (LOW): Der Knopf „Add place“ und „Choose a task“ hat am Mac einen grauen, abgerundeten Knopfkörper, am iPad nicht. Das ist Knopf-Chrome, keine Karte.

- [x] **AC-3 (mit Abweichung A1): bewiesen mit Abweichung (AMBIGUOUS-Befund A1).**
  Code reference: LooseEnds/Views/TaskDetailView.swift
  Code reference: LooseEnds/Views/DetailLayout.swift
  Evidence am Mac-Bild (hell und dunkel, politur): Titel „Rasen mähen“ in einer Serife, deutlich größer als die Feldwerte, ohne vorangestelltes „Title“ (`.labelsHidden()` nur für macOS in `TaskDetailView`). Köpfe NOTE, ATTACHMENTS, PLACE, SUBTASKS, WAITING ON in kleinen Großbuchstaben.
  Abweichung: „SAID“ mit gesagtem Satz fehlt am Mac-Bild, weil die Galerie-Aufgabe „Rasen mähen“ keinen gesagten Satz hat.
  Ersatzbeleg `ipad-landscape-detail.png` (neu, 13:54, Stand Politur, selbst geöffnet): „SAID“ klein in Großbuchstaben, danach der gesagte Satz kursiv grau („Ähm also ich muss morgen unbedingt noch Anna wegen dem Steuerbescheid anrufen und nachfragen, wichtig“), darüber der Titel zweizeilig groß in Serife ohne „Title“.
  Mac und iPad nehmen denselben `List`-Zweig (`isWide`), der Ersatz ist ein Schluss und kein Mac-Bild.
  Entscheidung Henning: Changelog der Spec, 2026-10-18. Der Wortlaut der gesperrten Spec ist unverändert.
  Bewertung: Die Umsetzung ist nicht fehlerhaft, die Abweichung liegt im Beleg. Deshalb AMBIGUOUS und nicht BROKEN. Voraussetzung ist Hennings getipptes `override-ambiguous` mit dieser Begründung.

- [x] **AC-4 (mit Abweichung A1): bewiesen mit Abweichung (AMBIGUOUS-Befund A1).**
  Code reference: LooseEnds/Views/Paper.swift
  Code reference: LooseEnds/Views/DetailLayout.swift
  Evidence am iPad-Bild: Haarlinien von etwa x=710 bis 1755 in einem 2000-px-Bild (1 px ≈ 0,69 pt), also etwa 719 pt, der Hinweisstreifen 710 bis 1755 (in der Politur gleich breit wie die Linien). Die Spalte steht mittig rechts der Seitenleiste, beidseits Papier ohne Streifen. `DetailColumn` in `Paper.swift` setzt `frame(maxWidth: 760)`, dann `frame(maxWidth: .infinity)` und Papier mit `ignoresSafeArea`.
  Evidence am Mac-Bild (politur): Das Papier läuft bis zum Fensterrand ohne weiße oder graue Streifen. Das dunkle Bild (Fenster 1024 x 674 pt, aus der Menüleiste geöffnet) zeigt Linien bei x≈257 bis 1000, der Detailbereich ist rund 750 pt breit und damit knapp unter 760 pt. Das helle Bild gehört zu einem Fenster von 1200 x 674 pt (beim Start geöffnet), ist aber auf 1024 px abgeschnitten; dort ist die Spaltenbreite nicht messbar. Die Kappung greift im Mac-Bild nie sichtbar, „mittig und höchstens 760 pt“ ist dort nicht beurteilbar.
  Abweichung: Das iPad-Querformat belegt Spalte und Kappung. Entscheidung Henning: Changelog 2026-10-18.
  Korrektur zur Beleg-Inkonsistenz: Die Dateien `mac-gallery-light-window-size.txt` (1200 x 674 pt) und `mac-gallery-dark-window-size.txt` (1024 x 674 pt) sind mit dem Stand der Politur-Bilder aktualisiert und im Commit enthalten. Die 900 x 450 pt gehörten zum Lauf davor.

- [x] **AC-5: AKZEPTIERT.**
  Code reference: LooseEnds/Views/TaskDetailView.swift
  Code reference: LooseEnds/Views/Paper.swift
  Evidence: `ipad-landscape-detail.png` (Politur): Papier mit Haarlinien, keine Karten, Titel groß in Serife zweizeilig ohne „Title“, keine Linie mehr über dem Titel, Spalte mittig und begrenzt. „Not sorted yet“ ist jetzt gleich breit wie die Haarlinien (x 710–1755), Text 12 pt eingerückt.
  Das Vorher-Bild (`ipad-landscape-detail-vorher.png`) zeigt laut Beleg Karten und kleineren Titel.

- [x] **AC-6 (mit Abweichung A1): bewiesen mit Abweichung (AMBIGUOUS-Befund A1).**
  Code reference: LooseEnds/Views/TaskDetailView.swift
  Code reference: LooseEnds/Views/Paper.swift
  Evidence: Prüfung der drei Punkte am Mac-Bild:
  1. Karten: nach Schritt 1 trifft zu (`…-schritt1-karten.png`), nach Schritt 2 und Politur trifft nicht zu.
  2. Spalte „Title“: trifft nicht zu.
  3. 600-pt-Kappung: im Mac-Bild nicht beurteilbar (Detailbereich ≈ 750 pt, unter der Spaltenkappung). Strukturell trifft der Punkt nicht zu, weil auf breit `List` mit `.listStyle(.plain)` statt `Form` mit `.formStyle(.grouped)` läuft, die Kappung also gar nicht mehr aus dem grouped Form-Stil kommt.
  Der Abschlussbericht formuliert Punkt 3 so: „trifft nicht zu (Form entfällt), am Mac-Bild nicht messbar“.

- **AC-7 (Stand Runde 2: offen bis CI-UI-Smoke, Beweis in Runde 3):**
  Code reference: LooseEnds/Views/TaskDetailView.swift
  Code reference: LooseEnds/Views/Paper.swift
  Evidence:
  - Pixelvergleich selbst gemessen (`python3 -I`, PIL): `iphone-detail-vorher.png` gegen `iphone-detail-nachher.png` (neu, Politur): beide (1206, 2622), Differenz-Bounding-Box (154, 77, 292, 117) (Uhrzeit in der Statusleiste), ab y=150 leer: pixelgleich.
  - Das gescrollte Paar (`…-scrolled-…`) stammt noch aus Schritt 2; die Aufnahme nach der Politur ist beauftragt.
  - Code: kompakt bleibt `Form { sections }.formStyle(.grouped).paperGround()`, `detailColumn(wide: false)` gibt den Inhalt unverändert zurück.
  - CI-Stand PR #524, Lauf 39129201245: Build pass, Mac Gallery pass, UI Smoke und Unit Tests `pending`.
  - Der vorige Lauf 39123042622 (Stand Schritt 2) hatte genau einen Fehlschlag: `CalendarTargetTests/testDefaultCalendarIsStampedOnSwitchOn`, „Asynchronous wait failed: Exceeded timeout of 10 seconds … `label CONTAINS "Loose Ends"` for object `defaultCalendarRow`“. Der Test läuft auf dem iPhone (kompakt) und scheitert an der letzten Prüfung in den Einstellungen, nicht im breiten Zweig. Ein Zusammenhang mit diesem Schnitt ist unwahrscheinlich, aber nicht bewiesen. Ein roter Lauf auf demselben Test wäre BROKEN.
  - Die sieben UI-Testklassen lokal grün sind nur Entwickleraussage, kein Artefakt.

- [x] **AC-8 (iPad-Teil bewiesen, Mac-Popover nicht bewiesen = Befund A2): TEILWEISE (AMBIGUOUS-Befund A2 für den Mac-Popover).**
  Code reference: LooseEnds/Views/TaskDetailView.swift
  Code reference: LooseEnds/Views/Paper.swift
  Evidence (alle vier Bilder selbst geöffnet, Stand Schritt 2, nicht mit der Politur neu aufgenommen; die Politur ändert nur Einzug und Trenner):
  - `ipad-edit-field.png`: Tippen auf „Due“ öffnet den Editor als Seite in der Detailspalte. „DUE“, „Tomorrow / Monday, October 19“, Today/Tomorrow (gewählt)/Weekend/Next week, Wochenleiste, „Other date …“, Uhrzeiten, „No date“, „FROM YOUR WORDS“ mit markiertem „morgen“, Before/After, Reset.
  - `ipad-title-editing.png`: Titel angetippt, „ heute“ getippt, Cursor nach „heute“, Tastatur offen, Titel groß in Serife.
  - `ipad-title-after-return.png`: nach Return Tastatur zu, Titel „… anrufen und heute“, Detail in Ruhe.
  - `ipad-more-menu.png`: Menü offen mit Complete, Next up, Park, Analyze again. In der Leiste „Looks right“ und „…“, kein Erledigen-Haken (#435).
  - Die Kennungen `detailTitleField`, `detailRawText`, `reanalysisNote`, `revisionsButton` stehen unverändert im Diff. In den geänderten Hunks tauchen `field_*`, `detailMoreMenu`, `menuCompleteButton` und `detailConfirmButton` nicht auf, sie wurden nicht angefasst.
  - Mac-Popover (#482): kein Bild, kein Mac-UI-Test. Die Begründung (`.popover(isPresented:arrowEdge: .trailing)` hängt an der Feldzeile selbst, `editorPopover` ca. Zeile 697) ist ein Schluss aus dem Code, kein Mac-Lauf.
  Bewertung: iPad-Teil bewiesen, Mac-Popover AMBIGUOUS, zu prüfen von Henning nach dem Merge per TestFlight auf dem Mac.

## Auffälligkeiten (bewertet)

- LOW, Haarlinie über dem Titel: behoben. Das iPad-Bild nach Politur zeigt oberhalb des Titels keine Linie mehr (`.listRowSeparator(isWide ? .hidden : .automatic, edges: .top)`). Die Politur-Mac-Bilder zeigen ebenfalls keine Linie.
- LOW, „Not sorted yet“: am iPad nach Politur gleich breit wie die Haarlinien (x 710–1755). Am Mac (politur) schmaler als die Linien: Linien x≈257–1000, Fläche x≈277–980, also etwa 20 pt auf jeder Seite. Rein kosmetisch.
- LOW, Mac-Linkskante uneinheitlich: Haarlinien bei x≈257, Köpfe NOTE/ATTACHMENTS bei 265, Fläche bei 277, Inhalt (Titel, Feldzeilen) bei 285. Am iPad beginnen Linien und Inhalt bei derselben Kante. Henning sieht sich das am Mac an.
- LOW, Zeilen am Mac wirken flach (Zeilenhöhe der Feldzeile etwa 36 px).
- LOW, `.textFieldStyle(.plain)` und `.toggleStyle(.switch)` sind nur im Bild belegt: Das Mac-Bild zeigt den Titel ohne Rand und „Show in calendar“ als Schalter. Das reicht.
- LOW, am Mac fehlt „Scan“ unter ATTACHMENTS: plattformbedingt plausibel.

## Offene Punkte

1. AC-7: Ergebnis von UI Smoke und Unit Tests im Lauf 39129201245 abwarten. Bei grün: AC-7 wird akzeptiert. Wiederholt sich der Fehlschlag im `CalendarTargetTests`, ist AC-7 BROKEN, bis der Zusammenhang mit diesem Schnitt widerlegt oder der Test repariert ist.
2. AC-7: gescrolltes iPhone-Bild nach Politur (beauftragt) per PIL vergleichen; nur die Scroll-Leiste darf abweichen.
3. AC-8: Mac-Popover vom PO nach TestFlight prüfen lassen.
4. A1 (AC-3, AC-4, AC-6) und A2 (AC-8 Mac-Popover) brauchen Hennings getipptes `override-ambiguous`.
5. Der Abschlussbericht nennt die übersprungenen Tests einzeln und die Zahl „823 Tests“ nur als Entwickleraussage.

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Es wurde keine Tabelle angehängt und keine Produktionsschreibstelle eines Feldes verändert (reine Layout-Änderung, keine Modell- oder Persistenzfelder).

### Verdict: AMBIGUOUS (Zwischenstand Runde 2)

Begründung:
- Kein Defekt gefunden, der den Code oder die Spec verletzt. AC-1, AC-2 und AC-5 sind bewiesen.
- AC-3, AC-4 und AC-6 stützen sich auf die vom PO entschiedene Abweichung (Spalte ≤ 760 pt und „SAID“ am iPad-Bild statt am Mac-Bild, Changelog 2026-10-18). „Bewiesen mit Abweichung“, formal offen bis zum getippten `override-ambiguous`.
- AC-8 Mac-Popover ist nicht belegt (nur Schluss aus dem Code).
- AC-7 ist offen bis zum CI-UI-Smoke. Der vorige Lauf hatte einen Fehlschlag in `CalendarTargetTests`, ein Zusammenhang mit diesem Schnitt ist unwahrscheinlich, aber nicht widerlegt.

Was sich ändert:
- UI Smoke grün (und gescrolltes iPhone-Bild nach Politur pixelgleich): AC-7 wird akzeptiert. Es bleiben AMBIGUOUS wegen A1 und A2; mit dem getippten `override-ambiguous` für A1 und A2 wäre das Verdict VERIFIED mit Vermerk. Der Mac-Popover ist dabei Hennings Nachprüfung per TestFlight.
- UI Smoke rot auf demselben Test, ohne Widerlegung des Zusammenhangs: BROKEN (AC-7, spec_violation).

### Runde 3

- [x] **AC-7:** Das iPhone und das iPad im kompakten Fenster bleiben unverändert. AKZEPTIERT.
  Code reference: LooseEnds/Views/TaskDetailView.swift
  Code reference: LooseEnds/Views/Paper.swift
  Code reference: LooseEnds/Views/DetailLayout.swift
  Code reference: LooseEndsTests/DetailLayoutTests.swift
  Evidence:
  - Code: Auf kompakt bleibt `Form { sections }.formStyle(.grouped).paperGround()` (`container` in `TaskDetailView.swift`). `detailColumn(wide: false)` gibt den Inhalt unverändert zurück (`DetailColumn` in `Paper.swift`). `detailRow()` ist `listRowBackground(Paper.ground)`, dieselbe Wirkung wie `paperRow()`. Die Politur-Zusätze `.listRowSeparator(isWide ? .hidden : .automatic, edges: .top)`, `.listRowInsets(isWide ? Paper.wideNoteInsets : nil)` und `.padding(.horizontal, isWide ? 20 : 0)` wirken auf kompakt nicht. `titleSize(wide: false)` ist 23 (`testCompactTitleSizeIsUnchanged`, grün). Die Kennungen `detailTitleField`, `detailRawText`, `reanalysisNote`, `revisionsButton` sind im Diff unverändert. In der Leiste ist kein Erledigen-Haken hinzugekommen (#435).
  - Pixelvergleich (python3 -I, PIL ImageChops.difference): `iphone-detail-vorher.png` gegen `iphone-detail-nachher.png` (neu, Politur), beide 1206x2622: Differenz nur die Uhrzeit in der Statusleiste (Bounding-Box 154,77,292,117), ab y=150 leer, pixelgleich. `iphone-detail-scrolled-vorher.png` gegen `iphone-detail-scrolled-nachher.png` (neu, Politur): ab y=150 einzige Differenz ein 9-px-Streifen am rechten Rand (Scroll-Indikator).
  - Beide gescrollten Bilder geöffnet: NOTE, ATTACHMENTS (Photo, File, Scan), „Show in calendar“ mit Schalter, PLACE, SUBTASKS, WAITING ON, „3 from your words – Show“, ADD MORE, jeweils Papier ohne Karten und Haarlinien, identisch.
  - CI-Lauf 39129201245 (headSha 4b3efe9869270355e6f33c2f3e1568d906ca58e4): UI Smoke, Build, Mac Gallery und Unit Tests success. `testDefaultCalendarIsStampedOnSwitchOn` (233 s) steht im Log als bestanden. Im vorigen Lauf 39123042622 war genau dieser Test mit Timeout rot, ein Wackler im iPhone-Einstellungspfad, den dieser Schnitt nicht berührt; die Wiederholung auf demselben Stand ist eine Stichprobe, kein Beweis, trägt aber zusammen mit dem Code-Befund (kompakter Zweig unverändert).

### Verdict: AMBIGUOUS

Begründung: AC-1, AC-2, AC-5 und AC-7 sind bewiesen, alle Checks der CI sind grün (Lauf 39129201245). Zwei Punkte sind von Henning freizugeben:
- A1 (AC-3, AC-4, AC-6, bewiesen mit Abweichung): Die Spalte von höchstens 760 pt mittig und der Kopf „SAID“ mit dem gesagten Satz sind am iPad-Querformat-Bild `ipad-landscape-detail.png` belegt statt am Mac-Bild. Henning hat das im Changelog der Spec am 2026-10-18 entschieden. Der Wortlaut der gesperrten Spec ist unverändert.
- A2 (AC-8, Mac-Popover): kein Bild, kein Mac-UI-Test. Der Schluss, dass der Anker an der Feldzeile hängt und `Form` → `List` ihn nicht ändert, ist ein Codebefund. Prüfung durch Henning nach dem Merge per TestFlight auf dem Mac.
Mit dem getippten `override-ambiguous` für A1 und A2 gilt das Ergebnis als VERIFIED mit diesem Vermerk. Ein weiterer UI-Test-Fehlschlag oder ein Fund am Mac-Popover würde es zu BROKEN machen.

## Geprüfte Dateien

- sha256:eb150a7011638bae5bbf12d2108b248c59f746917882477842e7587c0c56bc08  LooseEnds/Views/DetailLayout.swift
- sha256:53ac292d2d622ebb5f5956b43836393705f8d33dbaa9f4537c74feaa5bdbb376  LooseEnds/Views/Paper.swift
- sha256:2753d1fabccb027fbccb2a7be03b3fd24e8a35ca159e99d4c0221c1ad4638914  LooseEnds/Views/TaskDetailView.swift
- sha256:4bc0e62e182c6cbdb4acc9f4752d018a23a49063abf49b493bd099402e321a10  LooseEndsTests/DetailLayoutTests.swift

## Prüfbasis

- base: 69cd84619719ff2bdb9a616b6ec62b33168097b6
- blob:eef9dd0619ca4bbcdd3d04961e46077aeb85f056  LooseEnds/Views/DetailLayout.swift
- blob:fd2c331fdb50a9c297ee71fa7282ca0e84c0ff2f  LooseEnds/Views/Paper.swift
- blob:129ce2c41d855f3325b175cf760924b85208cb05  LooseEnds/Views/TaskDetailView.swift
- blob:ece43d0b9d8d8b5392a58c407a8d2e2394553247  LooseEndsTests/DetailLayoutTests.swift

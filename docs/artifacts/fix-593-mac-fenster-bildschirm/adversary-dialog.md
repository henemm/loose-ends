# Adversary Dialog — fix-593-mac-fenster-bildschirm
Spec: docs/specs/fix-593-mac-fenster-bildschirm.md
Datum: 2026-10-23 15:41

## Checkliste
- [x] **AC-1:** Given `visibleRect` 1024 × 737 und gewünschte Größe 1200 × 780 / When `MainWindowPlacement` die Größe berechnet / Then ist sie 1024 × 737. Belegt durch Unit-Test (Test 1, zuerst rot).
- [x] **AC-2:** Given ein Bildschirm, größer als 1200 × 780 / When die Größe berechnet wird / Then ist sie 1200 × 780 (auf Hennings Mac unverändert). Belegt durch Unit-Test (Test 2).
- [x] **AC-3:** Given ein sichtbarer Bereich kleiner als 760 × 520 / When die Größe berechnet wird / Then ist sie 760 × 520 (Mindestgröße gewinnt), und das Fenster beginnt an der oberen linken Ecke des Bereichs. Belegt durch Unit-Tests (Test 3 und 6).
- [x] **AC-4:** Given ein `visibleRect` beliebigen Ursprungs, in das das Fenster passt / When die Lage berechnet wird / Then ist das Fenster in diesem Rechteck zentriert und liegt ganz darin. Belegt durch Unit-Tests (Test 4 und 5).
- [x] **AC-5:** Given `macAssertWindowFitsScreen` / When das Hauptfenster breiter ist als der Bildschirm (oder rechts bzw. unten hinausragt) / Then schlägt der Test mit einer Meldung an, die beide Größen nennt; `macMainWindow(of:)` ruft die Prüfung auf, so dass jeder Mac-UI-Test sie durchläuft. Belegt durch Code-Prüfung am Diff (Vergleich, Meldung, Aufruf in `macMainWindow`) und den grünen CI-Lauf, in dem sie alle drei Mac-Testklassen durchläuft.
- [x] **AC-6:** Given die Galerie `MacGalleryTests` in der CI / When sie läuft, beim Start und über die Menüleiste geöffnet / Then enthält die Notiz `mac-gallery-<hell|dunkel>-window-size` Fenster- und Bildschirmgröße, und das Fenster ist nicht breiter als der Bildschirm. Belegt durch die Artefakte `MacGallery` des grünen Laufs „Mac Gallery (macOS)“.
- [x] **AC-7:** Given `LooseEndsApp.swift` / When der Diff geprüft wird / Then trägt `WindowGroup(id: "main")` `.defaultWindowPlacement` (unter `#if os(macOS)`), `.defaultSize(width: 1200, height: 780)`, `.frame(minWidth: 760, minHeight: 520)` und `.windowResizability(.contentMinSize)` bleiben unverändert, und `MacKeyboardTests.testWindowMinimumSize` läuft im CI-Lauf weiter grün. Belegt durch Diff-Prüfung und den grünen CI-Job.
- [x] **AC-8:** Given der Diff / When er geprüft wird / Then berührt er nur die fünf genannten Dateien, kein Pfad der Geräteliste; kein `try?`, kein `print`, jede Funktion ≤ 50 LoC; alle bestehenden Unit-Tests und der iOS-Bau sind grün.

## Dialog

### Runde 1
**Adversary:**
Tests: `./scripts/sim.sh sim-unit` 0 Fehler (Suite "Main window placement (#593)" passed, 6 Tests), `./scripts/sim.sh build` exit 0, `./scripts/sim.sh mac-build` exit 0 (die macOS-Zweig-Zeile in LooseEndsApp.swift kompiliert; der iOS-Bau sieht sie nicht). Ausgabe: docs/artifacts/fix-593-mac-fenster-bildschirm/adversary-test-output.txt. Übersprungen: nur die bekannten Messstrecken (SelfConsistency, Latenzschutz Sprache), keine Test dieses Tickets.

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Mac/MainWindowPlacement.swift:19
  Evidence: width = max(760, min(1200, 1024)) = 1024, height = max(520, min(780, 737)) = 737; Test smallScreenLimitsTheSize grün (LooseEndsTests/MainWindowPlacementTests.swift:10).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Mac/MainWindowPlacement.swift:19
  Evidence: min(1200, 2056) = 1200, min(780, 1291) = 780; Test largeScreenKeepsTheWish grün (MainWindowPlacementTests.swift:17).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Mac/MainWindowPlacement.swift:21
  Evidence: je Achse `width > visible.width ? visible.minX`; Tests minimumSizeWins und oversizeStartsTopLeft (MainWindowPlacementTests.swift:24, :47) grün. Auch Einachsfall von Hand gerechnet: 700 x 900 sichtbar -> Breite 760 an minX, Höhe 780 zentriert; korrekt (nicht als Test hinterlegt, siehe F003).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Mac/MainWindowPlacement.swift:22
  Evidence: midX - width/2 / midY - height/2, Ursprung des visibleRect fließt ein; Tests centredInVisibleArea (Ursprung 80/38) und fullSizeLiesOnTheArea (Ursprung 0/31) grün (MainWindowPlacementTests.swift:31, :39). Halbpunkte: exakt in Double, keine Rundungsabweichung im Test.
  Status: CONFIRMED

Confirmation:
  AC: AC-7 (Diff-Teil)
  Code reference: LooseEnds/App/LooseEndsApp.swift:120
  Evidence: `.defaultWindowPlacement` innerhalb des bestehenden `#if os(macOS)` hinter `.defaultSize(width: 1200, height: 780)` (Zeile 119, unverändert); `.frame(minWidth: 760, minHeight: 520)` und `.windowResizability(.contentMinSize)` im Diff unberührt. mac-build kompiliert. Closure ohne Capture, nur Sendable-Werte (CGSize-Konstanten), keine Swift-6-Warnung im mac-build.
  Status: CONFIRMED (Teil "testWindowMinimumSize grün in der CI" offen)

Confirmation:
  AC: AC-8 (Diff-Teil)
  Code reference: LooseEndsUITests/MacUITestSupport.swift:95
  Evidence: Diff berührt LooseEndsApp.swift, MainWindowPlacement.swift, MacUITestSupport.swift, MacGalleryTests.swift (+ LooseEndsTests/MainWindowPlacementTests.swift im RED-Commit) = fünf Dateien, kein Geräteliste-Pfad; im Diff kein `try?`, kein `print`; längste neue Funktion ca. 12 Zeilen. sim-unit und iOS-Bau grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-5 (Code-Teil)
  Code reference: LooseEndsUITests/MacUITestSupport.swift:82
  Evidence: macMainWindow ruft macAssertWindowFitsScreen nach dem Finden (Zeile 82); Vergleich Zeile 104-106 (width, maxX, maxY gegen Bildschirm), XCTFail nennt Fenster- und Bildschirmgröße (Zeile 109-111). Alle Aufrufer von macMainWindow (macOpenDetail, MacGalleryTests:30/:86/:334, MacDetailClickTests:273/:314, MacKeyboardTests:30/:305) laufen durch. Wirkung im CI-Lauf offen.
  Status: CONFIRMED (Code), offen (CI)

Confirmation:
  AC: AC-6 (Code-Teil)
  Code reference: LooseEndsUITests/MacGalleryTests.swift:36
  Evidence: Notiz-String enthält "W x H pt on screen W x H pt; window at launch: ...". Name `mac-gallery-<label>-window-size` unverändert (Zeile 42). Inhalt aus dem CI-Artefakt offen.
  Status: CONFIRMED (Code), offen (CI)

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: LooseEndsUITests/MacGalleryTests.swift:180
  Description: Mac-UI-Tests, die nie macMainWindow aufrufen: photographSettings (MacGalleryTests.swift:177-195, testSettingsLight/Dark), die Panel-Tests über openPanel (MacGalleryTests.swift:232, testPanel*, testPanelListening/Diagnosis) und MacDetailClickTests.testFieldsOpensFromTheMiddleOfItsRow (MacDetailClickTests.swift:343-348), MacKeyboardTests.testShortcutsAndContextMenu holt sein Fenster über openList (läuft durch, falls openList macMainWindow nutzt, über openStart Zeile 30 ja). Die genannten Tests rufen nur macOpenMainWindowIfNeeded und suchen Einstellungs- oder Panelfenster.
  Spec requirement: AC-5 — "macMainWindow(of:) ruft die Prüfung auf, so dass jeder Mac-UI-Test sie durchläuft"; Purpose — "jeder Mac-UI-Test prüft das".
  Conflict: Für diese Tests gibt es keine Prüfung; eine zu breite Startseite würde dort unbemerkt bleiben. Die Zusicherung "jeder" ist zu stark.
  Remediation: Entweder macOpenMainWindowIfNeeded selbst die Prüfung rufen lassen (es kennt das Fenster) oder die Spec auf "jeder Test, der das Hauptfenster holt" abschwächen und die Ausnahme benennen.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: LooseEndsUITests/MacKeyboardTests.swift:538
  Description: testWindowMinimumSize hat sein unteres Greifen auf "2 pt unter dem Fenster, über der Dock-Leiste" ausgelegt (Kommentar Zeile 533-536, Rahmen bisher 0,31,1024,674; Dock ab ca. 708). Die neue Regel macht das Fenster so hoch wie das visibleRect. Ist das visibleRect der CI höher als 674 (Menüleiste 31, Dock-Ausschluss unbekannt, Spec-Test 1 rechnet mit 737), liegt die Unterkante bei 768 = Bildschirmrand, das Greifen bei 770 ist außerhalb und `bottom edge` zieht nichts; die Assertion "height < before.height - 100" (Zeile 566) schlägt dann fehl. Nur wenn macOS die Höhe wie bisher auf 674 kürzt bzw. das Dock im visibleRect abgezogen ist, bleibt alles wie vorher.
  Spec requirement: AC-7 — testWindowMinimumSize läuft im CI-Lauf weiter grün; Risiken: "Startgröße auf der CI bleibt 1024 x ~674".
  Conflict: Die Annahme "bleibt 674" ist für die neue Regel nicht belegt, sie hängt an visibleRect.height des CI-Bildschirms. Lokal nicht prüfbar.
  Remediation: Im CI-Lauf die Notiz `mac-gallery-480-s2-window-drag` ("screen ..., window ...") ansehen; falls Höhe > 674, Greifpunkt bzw. Bottom-Grip in Test anpassen (z. B. Fenster erst per Titelleisten-Zug nach oben verschieben) oder Erwartung auf das tatsächliche visibleRect stützen.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsUITests/MacUITestSupport.swift:92
  Description: macScreenSize nimmt NSScreen.main.frame.size. Im Testläufer-Prozess ist "main" der Bildschirm der Menüleiste/Tastaturfokus, unabhängig davon, wo das App-Fenster liegt. Auf einem Mac mit zweitem Bildschirm (Fenster rechts vom Hauptbildschirm, XCUITest-Koordinaten global, minX >= Hauptbreite) meldet `maxX <= screen.width` einen Fehlalarm; links/oberhalb angeordnete Bildschirme (negative minX/minY) werden nicht erkannt, weil minX/minY nicht geprüft werden. Auf der CI (ein Bildschirm) ohne Wirkung. Zudem fehlt für den Einachsfall der reinen Funktion ein Unit-Test (nur beide Achsen zugleich, Test 3/6).
  Spec requirement: AC-5 — schlägt an, wenn breiter oder rechts/unten hinausragend.
  Conflict: entspricht dem Wortlaut der Spec, aber mit Fehlalarm-/Lücken-Rand außerhalb der CI.
  Remediation: Optional gegen die Bildschirmfläche prüfen, die das Fenster enthält; minX >= 0 und minY >= 0 mit aufnehmen; Einachsfall-Test (700 x 900) ergänzen.

Finding:
  ID: F004
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEndsUITests/MacUITestSupport.swift:90
  Description: Rückfall `XCUIScreen.main.screenshot().image.size` misst auf Retina in Pixeln; wäre NSScreen.main nil, wäre die Prüfung wirkungslos (immer "passt"). Spec benennt das Risiko selbst (niedrig). Außerdem ist `frame.width <= screen.width` durch `maxX <= screen.width` bei minX >= 0 redundant.
  Spec requirement: AC-5.
  Conflict: kein Verstoß, nur schwache Prüfung im Randfall.
  Remediation: kein Handlungszwang.

**Offene Punkte (kein Beleg, nichts erfunden):**
- AC-5 Wirkung: CI-Lauf "Mac Gallery (macOS)" für diesen Stand (Lauf-Nummer), Logzeilen zeigen MacGalleryTests, MacDetailClickTests, MacKeyboardTests ohne "does not fit the screen"; und die Tests aus F001 benennen.
- AC-6: Artefakt MacGallery, Notizen `mac-gallery-light-window-size` und `-dark-window-size` für beide Öffnungswege, Text der Form "1024 x NNN pt on screen 1024 x 768 pt; window at launch: yes|no, opened from the menu bar", Breite <= Bildschirmbreite; Bilder geöffnet und beschrieben (Fenster vollständig, rechter Rand nicht abgeschnitten).
- AC-7: Lauf-Log "testWindowMinimumSize passed" plus Notiz `mac-gallery-480-s2-window-drag` (Rahmen vor/nach Zug, Höhe zum Klären von F002).

**Implementierer:**

### Runde 2
**Adversary:**
Tests: sim-unit auf ec3188b exit 0 (Suite Main window placement passed); CI-Lauf 39965009255 (headSha ec3188b) success in allen vier Jobs, 0 Treffer "does not fit", MacGalleryTests 13/0, MacDetailClickTests 10/0, MacKeyboardTests 18/0, testWindowMinimumSize bestanden. Uebersprungen: nur bekannte Messstrecken (SelfConsistency, Latenzschutz de_DE), keine dieses Tickets. Ausgabe in adversary-test-output.txt.

Confirmation:
  AC: AC-5
  Code reference: LooseEndsUITests/MacUITestSupport.swift:82
  Evidence: macMainWindow ruft macAssertWindowFitsScreen (Z.85); macOpenMainWindowIfNeeded ruft in beiden Zweigen macMainWindow (Z.40, Z.61); damit laufen auch Settings-, Panel- und Felder-Tests durch (F001 behoben). Meldung nennt Fenster- und Bildschirmgroesse. CI gruen auf allen drei Klassen. Die Fehlerwirkung nicht durchgespielt (Spec verbietet absichtlich roten Test), Vergleich per Code geprueft.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEndsUITests/MacGalleryTests.swift:36
  Evidence: Notizen hell/dunkel: "1024 x 674 pt on screen 1024 x 768 pt; window at launch: yes". Bilder geoeffnet: Start (hell) zeigt Fenster vollstaendig, Seitenleiste links, rechter Rand mit "+" sichtbar, runde Ecken; Detail (dunkel) zeigt "Looks right" und "Mehr" am rechten Rand, nichts abgeschnitten. Grenze: Der Menueleistenweg trat in diesem Lauf nicht auf; dort greift dieselbe Pruefung per Code (Z.61), ein Lauf dazu liegt nicht vor. Als Restgrenze akzeptiert, weil der Weg von der CI-Maschine abhaengt.
  Status: CONFIRMED (Startweg per Lauf, Menueweg per Code)

Confirmation:
  AC: AC-7
  Code reference: LooseEnds/App/LooseEndsApp.swift:123
  Evidence: .defaultWindowPlacement unter #if os(macOS), .defaultSize(1200, 780) (Z.119) und .windowResizability(.contentMinSize) (Z.116) unveraendert, frame(minWidth 760, minHeight 520) unberuehrt. testWindowMinimumSize gruen; Notiz window-drag: Rahmen 0,31,1024,674, nach Zug 760 x 572. F002 geklaert: Hoehe bleibt 674, Bottom-Grip funktioniert.
  Status: CONFIRMED

Confirmation:
  AC: AC-1 bis AC-4
  Code reference: LooseEnds/Mac/MainWindowPlacement.swift:19
  Evidence: unveraendert seit Runde 1, sim-unit erneut gruen; CI-Fenster (0,31,1024,674) passt zur Regel.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEndsUITests/MacUITestSupport.swift:95
  Evidence: fuenf Dateien, kein Geraetelistenpfad, kein try?/print; sim-unit und iOS-Bau gruen.
  Status: CONFIRMED

F001 behoben (MacUITestSupport.swift:40, :61). F002 geklaert. F003/F004 (LOW) bleiben offen; sie verletzen keinen AC und haben auf der Ein-Bildschirm-CI keine Wirkung; sie verhindern VERIFIED nicht.
**Implementierer:**

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

**VERIFIED** (Runde 2): AC-1 bis AC-8 bewiesen. Offen nur LOW F003/F004. Restgrenze: Menueleistenweg von AC-6 im CI-Lauf nicht aufgetreten (per Code in beiden Zweigen geprueft).

## Geprüfte Dateien

- sha256:33f30556b1674a80afc0a4855f91eaf8a2c3ff6e4991aa19f345eee17a50caa7  LooseEnds/App/LooseEndsApp.swift
- sha256:7382f04fe74017dcd1efcb0b4719070f6a5f519fa5262b61fb09fcaefab98b01  LooseEnds/Mac/MainWindowPlacement.swift
- sha256:6106a60d309425d7150c529c275f0a5ee37f04df23494f6478f9715df9e7d8e6  LooseEndsUITests/MacGalleryTests.swift
- sha256:2c2f3af15f8eda3008c6131dc43d03b3ba8b9f6fbcfecaa9d4643b5a93769dd1  LooseEndsUITests/MacKeyboardTests.swift
- sha256:858eccd5a88ab75163b10062911c8cab3798dfef6eba5253d4b49db9380cbc5e  LooseEndsUITests/MacUITestSupport.swift

## Prüfbasis

- base: 996b88d4a1e47903481db59a790d9900a3677c82
- blob:47202669e9845a38fef3f0604e7a3310c838cd4a  LooseEnds/App/LooseEndsApp.swift
- blob:ea6e67a212886dbbb1f8ce85f7e63cf708c1aa8f  LooseEnds/Mac/MainWindowPlacement.swift
- blob:09ad9fd5721efd44204b129a621a102ee790eb47  LooseEndsUITests/MacGalleryTests.swift
- blob:1794813d3319289c54315cdc2cc28419e012bace  LooseEndsUITests/MacKeyboardTests.swift
- blob:2cb056c6ff426234965214d6ca38565153e1d320  LooseEndsUITests/MacUITestSupport.swift

## Geprüfte Dateien

- sha256:33f30556b1674a80afc0a4855f91eaf8a2c3ff6e4991aa19f345eee17a50caa7  LooseEnds/App/LooseEndsApp.swift
- sha256:7382f04fe74017dcd1efcb0b4719070f6a5f519fa5262b61fb09fcaefab98b01  LooseEnds/Mac/MainWindowPlacement.swift
- sha256:6106a60d309425d7150c529c275f0a5ee37f04df23494f6478f9715df9e7d8e6  LooseEndsUITests/MacGalleryTests.swift
- sha256:2c2f3af15f8eda3008c6131dc43d03b3ba8b9f6fbcfecaa9d4643b5a93769dd1  LooseEndsUITests/MacKeyboardTests.swift
- sha256:96f1d570d4cd462e99d2c05edd07b1a18a7a280faa73ddc91beedad2732f0195  LooseEndsUITests/MacUITestSupport.swift

## Prüfbasis

- base: 996b88d4a1e47903481db59a790d9900a3677c82
- blob:47202669e9845a38fef3f0604e7a3310c838cd4a  LooseEnds/App/LooseEndsApp.swift
- blob:ea6e67a212886dbbb1f8ce85f7e63cf708c1aa8f  LooseEnds/Mac/MainWindowPlacement.swift
- blob:09ad9fd5721efd44204b129a621a102ee790eb47  LooseEndsUITests/MacGalleryTests.swift
- blob:1794813d3319289c54315cdc2cc28419e012bace  LooseEndsUITests/MacKeyboardTests.swift
- blob:18945aa1a0d9ece6ace9d60adb65b0e87a4dc1b3  LooseEndsUITests/MacUITestSupport.swift

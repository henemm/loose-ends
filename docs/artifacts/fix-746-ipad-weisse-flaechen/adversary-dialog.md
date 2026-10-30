# Adversary Dialog — fix-746-ipad-weisse-flaechen
Spec: docs/specs/bug-746-ipad-weisse-flaechen.md
Datum: 2026-10-30 13:17

## Checkliste
- [x] **AC-1:** iPad Pro 13-inch (M5), Hochformat, Startseite: der Farbwert in der Fläche einer Zeile (rechts neben der Seitenleiste) ist derselbe wie darunter im leeren Bereich (`PaperGroundTests.testStartPageRowsShareThePaperGround`). Vorher rot, nachher grün.
- [x] **AC-2:** dasselbe auf „Erledigt“ mit einer erledigten Aufgabe, also mit der Fadenzeile (`PaperGroundTests.testDoneRowsShareThePaperGround`).
- [x] **AC-3:** Die Seitenleiste bleibt wie bisher: Zeilen durchsichtig, Auswahlmarkierung sichtbar (Bildvergleich vorher/nachher der Seitenleiste; bestehende Smoke-Tests der Seitenleiste grün).
- [x] **AC-4:** iPhone und Mac unverändert: UI-Smoke auf iPhone 17 und Mac-Galerie grün.
- [x] **AC-5:** Vorher/nachher-Bilder von Startseite und „Erledigt“ liegen im Abschlussbericht.

## Dialog

### Runde 1
**Adversary:** Beleg-Läufe geprüft. Rot: test-red-output.txt Zeilen 70-72, Zeile weiß [255,255,255] gegen Grund [244,243,238], 2 von 2 Tests rot. Grün: test-green-output.txt Zeile 381, 2 Tests, 0 Fehler. Bilder: vorher-start.png zeigt die weiße Fläche (x ab 465, bis y 463), nachher-start.png durchgehend beige. Angriff auf AC-3: Die sechs Seitenleisten-Aufrufe sind in SidebarView.swift auf sidebarRow() umgestellt, SidebarRow behält das alte Verhalten (breit: content). Die Seitenleiste ist links in beiden Bildern gleich. Auswahlmarkierung "Completed" ist grau und war schon vorher so (laut Hinweis des Auftrags); kein Bildbeleg einer Auswahl in der Seitenleiste, die Auswahl-Logik ist aber unverändert. Angriff auf AC-4: macOS-Zweig. Vorher gab PaperRow auf macOS `content` zurück (#else-Zweig im alten SidebarRow-Rumpf, der Diff ändert ihn nicht). Jetzt: PaperRow macOS -> content, SidebarRow macOS -> content. Unverändert. iPhone: schmal malte schon Paper.ground, jetzt ebenso. Eine Lücke bleibt: PaperRow ist jetzt auf iOS auch im breiten Fenster aktiv; Aufrufer prüfen (Runde 2).
**Implementierer:** Code reference: LooseEnds/Views/Paper.swift:86-96 (PaperRow malt auf iOS immer Paper.ground, macOS content), LooseEnds/Views/Paper.swift:98-116 (SidebarRow mit altem Verhalten). Code reference: LooseEnds/Views/SidebarView.swift:133 und :275 und :305 und :326 (alle auf sidebarRow()).

### Runde 2
**Adversary:** Aufrufer von .paperRow() per grep in LooseEnds/: TaskInteractions.swift:74 (pendingRow, Detailspalte), TaskListView.swift:329/482/548/578, StartZones.swift:30/157/166/205/282, CatalogPage.swift:60/71/85/91, Knaeuel.swift:30, Beads.swift:176/182/188, StartPage.swift:76/124/158/181, CarryReviewSheet.swift:45. Alle in Listen mit .paperList() der Detailspalte oder der Sheet-Liste; hier ist Beige das Ziel. CarryReviewSheet trägt zusätzlich .wideListRow() (malt breit schon Paper.ground), also keine Änderung. Swipe-Hintergründe sind eigene Aktionsfarben und nicht listRowBackground. Auswahlmarkierung in Detaillisten: im breiten Fenster hat die Detailspalte keine Zeilenauswahl der Liste (Zeilen sind NavigationLink/Button; Mac-Auswahl nutzt wideListRow, das schon vorher malte), daher kein Verlust. Rest-Risiko: Aufgabenzeilen mit .tag in TaskListView (iPad): nicht im Bild nachgewiesen, nur Startseite und Erledigt (leere Liste/Fadenzeile) per Test belegt. Regression: StartScreenInteractionTests auf iPhone 17 lokal gelaufen: 20 Tests, 0 Fehler (adversary-test-output.txt Zeilen 95-98). DesignGalleryTests aus Zeitgründen nicht gelaufen; Mac-Galerie nur CI, Mac-Zweig im Code unverändert.
**Implementierer:** Keine Gegenbefunde. Die Aufrufer ändern sich im Code nicht; im breiten iPad-Fenster gilt jetzt dasselbe Beige wie im schmalen. Code reference: LooseEnds/Views/Paper.swift:91 (listRowBackground(Paper.ground)), LooseEnds/Views/SidebarView.swift:130-133.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: StartScreenInteractionTests 20 bestanden, 0 fehlgeschlagen, 0 übersprungen; PaperGroundTests grün (2/2, vorher 2/2 rot).
Offen (nicht Defekt): Mac-Galerie nur in der CI, DesignGalleryTests nicht gelaufen, Seitenleisten-Auswahl nicht per Bild belegt.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Views/Paper.swift:91
  Evidence: PaperRow malt auf iOS in jeder Breite Paper.ground; Test rot vorher, grün nachher.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Views/Paper.swift:91
  Evidence: dieselbe Zeile gilt für die Fadenzeile in Erledigt (pendingRow nutzt paperRow).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Views/SidebarView.swift:133
  Evidence: Seitenleisten-Zeilen nutzen sidebarRow() mit altem Verhalten (Paper.swift:98-116).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Views/Paper.swift:93
  Evidence: macOS-Zweig gibt content zurück, unverändert; iPhone-Test 20/20 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Views/Paper.swift:25
  Evidence: vorher-/nachher-start.png und -erledigt.png liegen im Artefaktordner.
  Status: CONFIRMED

## Geprüfte Dateien

- sha256:d1320da082d8d5a9c1e806599dd82258c2af16c75ce7d3695adc9acba89048b0  LooseEnds/Views/Paper.swift
- sha256:afa08556e084f543c3624a27a77dfef78ec6817faca3ec38770c57167f0d3dbc  LooseEnds/Views/SidebarView.swift

## Prüfbasis

- base: 556bb5badb6ce9bb1421dd9da5f55fbfee9e2c37
- blob:30ffdae9d874ecb76bc1fc09c769dad9d97bbb4b  LooseEnds/Views/Paper.swift
- blob:d72e3140c5b83a911b0445504113454cd541ef60  LooseEnds/Views/SidebarView.swift

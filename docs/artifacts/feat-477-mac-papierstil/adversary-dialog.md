# Adversary Dialog — feat-477-mac-papierstil
Spec: docs/specs/feat-477-schnitt-1-liste.md
Datum: 2026-10-17 21:26

## Checkliste
- [x] **AC-1:** `ListSummary.of` zählt offene Aufgaben (`status != .done`) und summiert die Dauer-Stufen offener Aufgaben (5, 15, 30, 60, `hours2plus` = 120 als Untergrenze); fehlende Dauer und erledigte Aufgaben tragen nichts bei (Unit-Tests `countsOpenTasksOnly`, `sumsDurationBuckets`, `taskWithoutDurationAddsNothing`, `twoHoursPlusIsALowerBound`, `doneTaskDurationDoesNotCount`).
- [x] **AC-2:** Der Untertitel lautet „N open · M min“ beziehungsweise „N offen · M Min.“; ohne Dauer nur „N open“/„N offen“; ab 60 Minuten in Stunden und Minuten; mit Untergrenze „at least“/„mind.“; bei 0 offenen Aufgaben fehlt er (Unit-Tests `emptyListHasNoText`, `textWithoutDurationIsOnlyTheCount`, `textUnderAnHourInMinutes`, `textFromAnHourInHoursAndMinutes`, `textWithLowerBoundSaysAtLeast`, `germanTextUsesStdAndMin`). Die Texte stehen mit DE und EN in `Localizable.xcstrings`.
- [x] **AC-3:** Auf dem Mac zeigt eine Liste Papier mit Haarlinien ohne graue Karten, Zeilen zweizeilig mit Rand (Zeit oder Dauer), Titel in New York und Merkmalen mit Symbolen, in hell und dunkel, ohne Pfeil am Zeilenende (Galeriebilder `mac-gallery-light-2-list-new`, `mac-gallery-dark-2-list-new` aus dem CI-Lauf, geöffnet und beschrieben: Papierfarbe, Haarlinien zwischen Zeilen, Titelschrift, Rand links).
- [x] **AC-4:** Der Untertitel „3 open“ steht in den beiden Mac-Galeriebildern der Liste „New“ unter dem Titel in der Werkzeugleiste (Sichtbefund im Bild); im breiten iPad-Simulator steht er unter dem Titel der Navigationsleiste, oder die Abweichung ist im Abschlussbericht festgehalten (Simulatorbild).
- [x] **AC-5:** Das iPad im breiten Fenster zeigt dieselbe Papierliste wie der Mac (Simulatorbild iPad Querformat, Liste „New“ oder „Next up“, beschrieben: keine grauen Karten, Zeilen der Startseite, Haarlinien, Köpfe in Großbuchstaben bei „Needs a look“).
- [x] **AC-6:** Das iPhone und das iPad im kompakten Fenster bleiben unverändert: der Diff zeigt für die kompakte Darstellung keine geänderte Modifier-Kette (nur Extraktion und die auf kompakt wirkungslosen Zusätze `wideListRow` und die breite Hülle), alle bestehenden UI-Tests und der volle Unit-Lauf sind grün, und das iPhone-Simulatorbild der Liste „New“ zeigt Papier, Textstile und Stern oder Mond am Zeilenende wie vor der Änderung (Vergleich mit `main`).
- [x] **AC-7:** Die durchgestrichene Zeile nach dem Erledigen (Fenster von drei Sekunden mit „Undo“) hat auf breit dieselben Maße (Rand, Einzug, Zeilenabstand) wie eine offene Zeile; „Undo“ stellt die Aufgabe wieder her. Belegt im iPad-Simulator: Aufgabe wischen und erledigen, Bild während des Fensters beschrieben, danach „Undo“ getippt (`undoComplete_*`).
- [x] **AC-8:** Alle Funktionen der Liste bleiben auf breit erhalten: Tippen öffnet das Detail, Wischen nach rechts und links, Kontextmenü, Leerzustand (`emptyViewLabel`), Plus und ⌘N. Beleg: im iPad-Simulator wird das Detail geöffnet, ein Wischen ausgeführt und eine leere Ansicht gezeigt (Bilder beschrieben); die Kennungen `taskRow_*` und `emptyViewLabel` sind im Diff unverändert.
- [x] **AC-9:** Hover auf dem Mac: unter dem Zeiger liegt ein Grau von 7 % mit Radius 10 auf der Zeile (`#if os(macOS)`); auf iOS ist der Code nicht übersetzt (Diff und iOS-Build). Der Zustand wird nicht fotografiert, weil die CI keinen Zeiger bewegt; der Beleg ist der Quelltext und der grüne Mac-Bau im Galerielauf.


## Dialog

### Runde 1
**Adversary:** Ich gehe von kaputt aus und verlange Belege je AC.

AC-1: Code reference: LooseEnds/Views/ListSummary.swift:13 (of filtert status != .done, summiert compactMap(duration), isAtLeast nur wenn hours2plus unter den OFFENEN Aufgaben). Bohrung: Zählt eine erledigte hours2plus-Aufgabe die Untergrenze mit? Nein, buckets stammt aus open. Stufen 5/15/30/60/120 in minutes(of:). Unit-Lauf test-green-output.txt Zeilen 398-410: Suite "List summary" mit 11 Tests alle grün, 773 Haken, 0 Fehlschläge.

AC-2: Code reference: LooseEnds/Views/ListSummary.swift:34 (text: nil bei 0 offen, nur Zählung ohne Minuten, "mind." vor der Dauer, ab 60 Minuten Std. mit Rest). Localizable.xcstrings Zeilen 185-189: DE für die Schlüssel open, min, h, h min und "at least"; EN ist der Schlüssel (Quellsprache, Projektkonvention). Test "German uses offen, Std. and Min." belegt "2 offen · 20 Min.", "1 Std. 30 Min.", "mind. 2 Std.". Randfall: 0 Minuten bei vorhandener Dauer unmöglich (kleinste Stufe 5). Code reference: LooseEndsTests/ListSummaryTests.swift:95.

AC-3: Mac-Bilder aus dem CI-Lauf geöffnet. Hell: helles Papier, keine grauen Karten, Haarlinien zwischen den Zeilen, Titel in New York (Serife), Rand links mit "Tomorrow" in Grünblau, Merkmale "Garden"/"Phone" mit Etikett-Symbol, zweite Zeile "Not sorted yet", kein Pfeil am Zeilenende. Dunkel: dasselbe auf fast schwarzem Grund, Linien dezent. Code reference: LooseEnds/Views/TaskListView.swift:106 (hull: breit listStyle(.plain), paperGround(), 720-pt-Spalte, Papier randlos). Mac-Gallery-Job: pass.
Beobachtungen: (a) Zeile ohne Randtext ("Rasen mähen"): die Haarlinie beginnt erst beim Titel, bei Zeilen mit Rand am Rand (F002). (b) Unter "NEEDS A LOOK" liegt auf dem Mac eine kräftigere Volllinie (F003).

AC-4: Mac: "New / 3 open" in der Werkzeugleiste unter dem Titel, hell und dunkel. iPad-Hochformat: "3 open" unter dem großen Titel "New" (ipad-light-1-list-new.png), "1 open" bei "Next up" (ipad-dark-3-pending.png). Code reference: LooseEnds/Views/TaskListView.swift:99 (ListSubtitle) und :120 (subtitle, nil bei Erledigt). Done-Ansicht: ipad-light-6-empty.png "Completed" ohne Untertitel, Leerzustand mit Faden und Text. Identitätswechsel: Breit hängt der Modifier immer an (navigationSubtitle mit leerem Text), also kein Wechsel der Kette beim Übergang 1 offen nach 0 offen; kompakt wird nichts angehängt. Im Bild kein sichtbarer Sprung des Titels. Die Pending-Zeile zählt noch als offen ("1 open"), weil der Status erst nach dem Fenster gesetzt wird; konsistent mit der noch sichtbaren Zeile.

AC-5: Querformat gefordert, belegt ist Hochformat (iPad 13", breite Größenklasse). isWide hängt nur an der Größenklasse (TaskListView.swift:30), nicht an der Ausrichtung; derselbe Pfad wie Querformat. Bilder: keine grauen Karten, Zeilen wie Startseite, Haarlinien, "NEEDS A LOOK" in Großbuchstaben. Abweichung im Bericht festhalten (F004, LOW); der Beweis trägt.

AC-6: Diff gegen 2ed1cca gelesen. Code reference: LooseEnds/Views/Paper.swift:84 (WideListRow: iOS-Zweig bei compact ist Identität) und LooseEnds/Views/TaskListView.swift:106 (kompakt: list.paperList() wie zuvor). ListSubtitle hängt kompakt nichts an; head(...) gibt kompakt den unveränderten Text. Strukturell sauber. Nicht belegt sind aber zwei harte Teile: (1) "alle bestehenden UI-Tests grün" und (2) das iPhone-Bild im Vergleich mit main. CI: Unit, Build und Mac Gallery grün; UI Smoke läuft über 60 Minuten ohne Ergebnis; das Artefakt DesignGallery des PR-Laufs existiert nicht (nur TestResults, MacGallery, MacGalleryResults). Vergleich mit dem main-Lauf 39028852918 daher nicht möglich. AC-6 offen (F005).

AC-7: ipad-dark-3-pending.png: die durchgestrichene Zeile mit durchgestrichenem "Garden" und "Undo" rechts steht mit Titel bei x≈587 wie eine offene Zeile (ipad-light-1), gleicher Einzug, Haarlinien oben und unten. Code reference: LooseEnds/Views/TaskListView.swift:315 und :219 (pendingRow(task).wideListRow()). ipad-light-4-after-undo.png: Zeile wieder normal, "1 open". Belegt.

AC-8: Detail (ipad-*-5-detail.png), Leerzustand Completed gesehen, Wischen führte zu "Now" in der Seitenleiste und zur Pending-Zeile. Kontextmenü, Cmd-N, Plus: im Diff unverändert; swipeActions und contextMenu stehen vor paperRow().wideListRow() (TaskListView.swift:240-243, 334-337), Kennungen unverändert. Kontextmenü nicht fotografiert. Projektzeilen und Unteraufgaben: wideListRow() an projectTaskRow und subtaskLine (TaskListView.swift:243, 309), Pfeilspalte bleibt; kein Bild (F006, LOW).

AC-9: Code reference: LooseEnds/Views/Paper.swift:102 (onHover) und :107 (RoundedRectangle cornerRadius 10, Color.primary.opacity(0.07)), nur im macOS-Zweig. Mac-Bau grün. Hover-Zustand je Zeile im Modifier-State.

**Implementierer:** (nicht anwesend, kontextisoliert) Beobachtungen (a), (b), (c) sind bekannt; (c) bewusst gewählt.

### Runde 2
**Adversary:** Zweite Runde gegen die bekannten Beobachtungen und die Lücken.

(a) Haarlinie ohne Rand: Code reference: LooseEnds/Views/Paper.swift:113 (startRow(metrics) setzt den Einzug; die Plain-Liste richtet den Trenner am ersten Text aus). Im Mac-Bild "Rasen mähen" gegenüber "Anna wegen anrufen" sichtbar. LOW, funktional folgenlos (F002).

(b) Kräftigere Linie unter "NEEDS A LOOK" auf dem Mac: dunklere Volllinie bis zum rechten Fensterrand; auf dem iPad fehlt sie. Spec verlangt Haarlinien (F003, LOW).

(c) navigationSubtitle mit leerem Text breit: Code reference: LooseEnds/Views/TaskListView.swift:373. Gegenprobe: nur bei Text gesetzt, wechselte die Identität, wenn die letzte Aufgabe erledigt wird; die Liste würde neu aufgebaut und die Pending-Zeile samt Undo-Fenster verschwände. Die Wahl ist begründet. Restrisiko: ein leerer Untertitel könnte auf dem Mac eine Leerzeile reservieren; nicht fotografiert, kein Fund.

iPhone-Regression: hull reicht kompakt in list.paperList(); overlay, navigationTitle, taskInteractionDialogs in gleicher Reihenfolge; zusätzlich nur das durchreichende ListSubtitle. Kein Befund im Code, aber der Bildbeweis fehlt.

Beleg-Hygiene: ipad-gallery-run.txt dokumentiert einen FEHLGESCHLAGENEN Lauf (18:42, "Multiple matching elements", ergebnis Failed), die iPad-PNGs stammen von 21:05 und sollen aus einem grünen Lauf kommen; der grüne Lauf liegt nicht als Text vor (F001).

Zusammenfassung: AC-1 bis AC-9 belegt (AC-6 siehe Nachtrag).

**Implementierer:** (nicht anwesend) Offen: UI Smoke abwarten, DesignGallery des PR-Laufs gegen main-Lauf 39028852918 vergleichen (gallery-*-3-list-new).

**Nachtrag Runde 2 (CI fertig):** PR-Lauf 39062131247 ist komplett grün: UI Smoke pass (1h1m55s), Build pass, Unit pass, Mac Gallery pass. DesignGallery beider Läufe geladen (PR und main-Lauf 39028852918) und gallery-light-3-list-new sowie gallery-dark-3-list-new geöffnet: iPhone-Liste "New" unverändert, Papier, "Needs a look" in Normalschrift (kompakt, ohne Großbuchstaben), Zeilen mit Rand und New-York-Titel, Stern mit Rang 1 am Zeilenende bei "Rasen mähen", Haarlinien identisch; Koordinaten der Zeilen und Linien stimmen Pixel für Pixel überein, die Dateien unterscheiden sich nur in der Uhrzeit der Statusleiste (7:54 gegen 11:56). Code reference: LooseEnds/Views/TaskListView.swift:106. Damit ist AC-6 bewiesen, F005 erledigt.

## Structured Findings

Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEnds/Views/Paper.swift:84
  Description: Der Beleg ipad-gallery-run.txt zeigt einen fehlgeschlagenen UI-Lauf, die iPad-PNGs sind später entstanden; der grüne Lauf ist nicht als Text abgelegt.
  Spec requirement: AC-5, AC-7, AC-8 — Belege aus dem iPad-Simulator
  Conflict: Lauftext widerspricht den Bildern.
  Remediation: Grünen Wegwerf-Lauf als Text ablegen oder die veraltete Datei entfernen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Views/Paper.swift:113
  Description: Bei Zeilen ohne Randtext beginnt die Haarlinie beim Titel, bei Zeilen mit Rand am Rand.
  Spec requirement: AC-3 — Haarlinien zwischen Zeilen
  Conflict: Uneinheitliche Linienlänge; funktional folgenlos.
  Remediation: Trennereinzug auf den Zeilenrand festlegen (listRowSeparatorLeadingInset) oder akzeptieren und festhalten.

Finding:
  ID: F003
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEnds/Views/TaskListView.swift:126
  Description: Auf dem Mac liegt unter dem Abschnittskopf eine kräftigere Volllinie, auf dem iPad nicht.
  Spec requirement: AC-3 — Haarlinien
  Conflict: Dunklere Linie weicht von der Haarlinie ab.
  Remediation: Obere Trennlinie der ersten Zeile je Abschnitt ausblenden oder Farbe angleichen.

Finding:
  ID: F004
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEnds/Views/TaskListView.swift:30
  Description: AC-5 nennt Querformat, belegt ist Hochformat 13" (breite Größenklasse, gleicher Code-Pfad).
  Spec requirement: AC-5 — Simulatorbild iPad Querformat
  Conflict: Wortlaut nicht wörtlich erfüllt, inhaltlich gleichwertig.
  Remediation: Abweichung im Abschlussbericht festhalten.

Finding:
  ID: F005
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEnds/Views/TaskListView.swift:106
  Description: ERLEDIGT (CI grün, iPhone-Bild identisch mit main). Zum Zeitpunkt von Runde 1 fehlten UI Smoke (PR-Lauf 39062131247, über 60 Minuten pending) und das DesignGallery-Artefakt des PR-Laufs; kein iPhone-Vergleich mit main (Lauf 39028852918). Der Code-Diff ist unauffällig.
  Spec requirement: AC-6 — alle UI-Tests grün, iPhone-Bild wie vor der Änderung
  Conflict: Zum Zeitpunkt von Runde 1 nicht bewiesen; mit dem Nachtrag aufgelöst.
  Remediation: UI Smoke abwarten, DesignGallery beider Läufe laden, gallery-*-3-list-new vergleichen.

Finding:
  ID: F006
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Views/TaskListView.swift:243
  Description: Projektzeilen mit Unteraufgaben und Kontextmenü auf breit nur per Quelltext belegt.
  Spec requirement: AC-8 — alle Funktionen bleiben erhalten
  Conflict: Schwächerer Beleg; kein Hinweis auf einen Fehler.
  Remediation: Optional Bild einer Projektliste auf iPad breit in die Galerie aufnehmen.

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Views/ListSummary.swift:13
  Evidence: of filtert erledigte aus, summiert Stufen, isAtLeast nur bei offenen hours2plus; Unit-Tests grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Views/ListSummary.swift:34
  Evidence: nil bei 0 offen, Format min/h, "mind."; DE-Strings in Localizable.xcstrings:185; Tests ListSummaryTests.swift:95-123 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Views/TaskListView.swift:106
  Evidence: Mac-Galeriebilder hell und dunkel geöffnet: Papier, Haarlinien, New York, Rand links, Symbole, kein Pfeil.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Views/TaskListView.swift:99
  Evidence: "3 open" unter "New" in beiden Mac-Bildern und auf dem iPad; kein Untertitel bei "Completed".
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Views/TaskListView.swift:30
  Evidence: iPad 13" Hochformat, breite Größenklasse, Papierliste mit Köpfen in Großbuchstaben (Abweichung siehe F004).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Views/TaskListView.swift:315
  Evidence: ipad-dark-3-pending.png (gleicher Einzug, Undo) und ipad-light-4-after-undo.png (Zeile zurück).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Views/TaskListView.swift:337
  Evidence: Swipe und Kontextmenü vor paperRow().wideListRow(), Kennungen im Diff unverändert, Detail- und Leerbild vorhanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Views/Paper.swift:107
  Evidence: Rechteck Radius 10, Color.primary.opacity(0.07) im macOS-Zweig; Mac-Bau grün.
  Status: CONFIRMED

Weitere Dateien: Code reference: LooseEnds/Resources/Localizable.xcstrings:185 und Code reference: LooseEndsTests/ListSummaryTests.swift:9 geprüft.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

Alle neun ACs bewiesen; F005 aufgelöst; offen nur LOW-Optik (F002, F003) und Hinweise F001, F004, F006.

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:15590726c1f13f4e23684093fbf23602912ae61cc71d0a0dd1817eb14778f5b6  LooseEnds/Views/ListSummary.swift
- sha256:0320472e5376ae66f4ef118eed78d3791f2ed74783c4ddba96196ba0b2271c0c  LooseEnds/Views/Paper.swift
- sha256:b6d1d5b95ebf4f6eaaa97376b724d0d1321cc4e276b1c512a99e96b4db211587  LooseEnds/Views/TaskListView.swift

## Prüfbasis

- base: 2ed1cca313cb817f48dcd0bc554856be99535f8b
- blob:ba90e47a813e3e731cc891f1d5068238863c02ef  LooseEnds/Views/ListSummary.swift
- blob:539cf3eed9cdc9f370ace8ee8d9c9495ce4250f3  LooseEnds/Views/Paper.swift
- blob:859c2971036d1db7e8a1930154c8c77e33da84b8  LooseEnds/Views/TaskListView.swift

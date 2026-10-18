# #477 Schnitt 2 — Stufe 2, Simulatorbelege (2026-10-18)

Weg: ein Wegwerf-UI-Test (nicht im Repo) über `./scripts/sim.sh test`, Sitzung `le477-proof`, iOS 27.0.
Start mit `--ui-testing`, Englisch, Erfassung des Satzes „Ähm also ich muss morgen unbedingt noch Anna wegen dem
Steuerbescheid anrufen und nachfragen, wichtig“. Die Regeln setzen Fällig (Tomorrow), Wichtigkeit (High) und Tag
(Phone); Dringlichkeit, Dauer, Energie, Projekt, Wiederholung bleiben leer. Der Titel (Regeltitel, 12 Wörter ohne
„morgen“) weicht vom Satz ab, deshalb steht „SAID“ darunter.

- **Nachher:** Arbeitsstand dieses Zweigs nach **Schritt 2 (Weg 2)**: auf breit `List` mit `.listStyle(.plain)` statt
  `Form` + `.formStyle(.grouped)`, auf kompakt die Form unverändert (Lauf 2026-10-18 13:00, Sitzung `le477-s2`). Die
  Bilder von Schritt 1 sind damit überschrieben.
- **Vorher:** Commit `aac08c4` (Basis des Zweigs, Stand `main` vor #477 Schnitt 2) in einem Wegwerf-Worktree, eigene
  Sitzung `le477-proof-vorher`, derselbe Test.
- iPad: „iPad Pro 13-inch (M5)“, Querformat per `XCUIDevice.orientation`. `app.screenshot()` liefert im Querformat ein
  falsch beschnittenes Bild; die iPad-Bilder sind deshalb Fensteraufnahmen (`app.windows.firstMatch.screenshot()`),
  um 90° aufgerichtet. Inhalt unverändert.

## iPad Querformat (AC-5), Schritt 2

**`ipad-landscape-detail.png` (nachher).** Links die Seitenleiste (Startseite, „New 1“ markiert), rechts das Detail
als Liste auf Papier: **keine Karten, keine abgerundeten Flächen**, jede Zeile durch eine Haarlinie getrennt. Titel in
New York medium, groß, zwei Zeilen („Ähm also ich muss unbedingt noch Anna wegen / dem Steuerbescheid anrufen und“),
ohne Beschriftung „Title“. Darunter Haarlinie, „SAID“ mit dem Satz kursiv grau. Der Hinweis „Not sorted yet“ liegt als
blassgrüne Fläche über die ganze Zeilenbreite (sein eigener Zeilenhintergrund `accentColor 0.08`, wie bisher, jetzt
eckig). Feldzeilen Due – Tomorrow, Importance – High, Tags – Phone mit Herkunftszeichen, je Haarlinie. Wortleiste
„+ Urgency + Duration + Energy + Project + Repeat“, darunter eine Haarlinie, die etwas weiter rechts beginnt (Einzug
am ersten Wort). Abschnittsköpfe „NOTE“, „ATTACHMENTS“, „PLACE“, „SUBTASKS“ klein, grau, Großbuchstaben
(`captionHead()`), auf Papier ohne eigenen Hintergrund. Notizfeld als Platzhalter „Numbers, addresses, anything else“
in New York; „Photo / File / Scan“; **„Show in calendar“ mit Schalter (aus) rechts**, sichtbar und als Schalter
dargestellt. Die Spalte steht mittig im Detailbereich: Haarlinien von etwa x 710 bis 1755 (von 2000), links und rechts
Papier bis zum Rand, keine Streifen. Auffällig, aber unkritisch: über dem Titel steht eine Haarlinie (oberer
Trenner der ersten Zeile der einfachen Liste).

**`ipad-landscape-detail-vorher.png` (vorher, zum Vergleich).** Dasselbe Detail auf `main`: jeder Abschnitt als weiße,
abgerundete Karte über die volle Breite des Detailbereichs (Titel+Satz, Feldblock, Wortleiste, Note, Attachments,
Kalender, Place, Subtasks), Titel einzeilig und kleiner (23 pt). Der Unterschied zu nachher ist eindeutig.

**`ipad-landscape-detail-scrolled.png` (nachher, gescrollt).** Feldzeilen, Wortleiste, NOTE, ATTACHMENTS,
„Show in calendar“ mit Schalter, PLACE („Add place“), SUBTASKS („Add a subtask … Add“), WAITING ON („Choose a task“),
„3 from your words – Show“, ADD MORE („Friday, one hour, call first“). Alles auf Papier mit Haarlinien, keine
Karten; rechte Kante (Schalter, „Add“, „Show“) bündig an derselben Linie. Oben unter der Statusleiste verblasst der
gescrollte Inhalt (Kanteneffekt der Leiste).

AC-5: **sichtbar erfüllt.** Zeilen auf Papier mit Haarlinien statt Karten, großer New-York-Titel ohne „Title“,
Spalte mittig und begrenzt.

## iPad Funktionen (AC-8), Schritt 2

**`ipad-edit-field.png`.** Tippen auf „Due“ öffnet den Editor als Seite in der Detailspalte (Navigation, kein Popover):
„DUE“, „Tomorrow / Monday, October 19“, Today/Tomorrow (gewählt)/Weekend/Next week, Wochenleiste, „Other date …“,
Uhrzeiten, „No date“, „FROM YOUR WORDS“ mit markiertem „morgen“, Before/After, Reset. Zurück über den Zurück-Knopf
führt ins Detail (der Test findet danach `detailTitleField`). Der Fokusrahmen um „1 to look over“ in der
Seitenleiste steht genauso auf `main` (Vergleich der Pixel an derselben Stelle im Vorher-Lauf), kein Effekt dieses
Schnitts.

**`ipad-title-editing.png`.** Titel angetippt, „ heute“ am Ende getippt, Cursor nach „heute“, Tastatur offen; Titel
groß in New York, Liste darunter unverändert.

**`ipad-title-after-return.png`.** Nach Return: Tastatur zu, Titel „… anrufen und heute“, Detail in Ruhe. Return
beendet die Bearbeitung auch in der Liste.

**`ipad-more-menu.png`.** Menü „Mehr“ (`detailMoreMenu`) offen: Complete, Next up, Park, Analyze again. In der
Leiste stehen „Looks right“ und „…“, kein Erledigen-Haken (#435).

AC-8 (Simulatorteil): **sichtbar erfüllt** — Feld öffnet den Editor, Titel ändern und mit Return beenden, Menü mit
Erledigen, „Looks right“; der Mac-Popover ist hier nicht belegbar (CI-Galerie).

## iPhone 17 vorher/nachher (AC-7), nach Schritt 2

**`iphone-detail-vorher.png` / `iphone-detail-nachher.png`.** Beide: Leiste mit Zurück, „Looks right“, „…“; Titel in
New York 23 pt über drei Zeilen, Haarlinie, „SAID“ mit Satz kursiv grau, Hinweis „Not sorted yet“, Feldzeilen Due /
Importance / Tags mit Haarlinien, Wortleiste in zwei Zeilen, „NOTE“, „ATTACHMENTS“. `iphone-detail-nachher.png` ist neu
aus dem Lauf nach Schritt 2. Pixelvergleich (PIL `ImageChops.difference`): einzige Abweichung die Uhrzeit in der
Statusleiste (x 153–291, y 77–117); ab y 150 bbox `None`, **pixelgleich**.

**`iphone-detail-scrolled-vorher.png` / `iphone-detail-scrolled-nachher.png`.** Gescrollt, neu nach Schritt 2;
unterhalb der Statusleiste einzige Abweichung ein 9 px breiter Streifen am rechten Rand (x 1188–1197), der
Scroll-Indikator — wie nach Schritt 1.

AC-7 (Bildteil): **erfüllt** — das iPhone-Detail ist vorher und nach Schritt 2 pixelgleich.

## Politur (2026-10-18, Sitzung `le477-pol`)

Zwei Mängel nur auf breit, gefunden vom Adversary: eine Haarlinie über dem Titel und auf dem Mac nur ~8 pt Einzug
mit flachen Zeilen. Änderung: auf breit bekommen alle Zeilen `Paper.wideRowInsets` (20 pt links/rechts, 10 pt
oben/unten), die Titelzeile blendet ihren oberen Trenner aus, der Hinweis „Not sorted yet“ malt seine Fläche um
20 pt eingerückt (so breit wie die Haarlinien) und setzt seinen Text 12 pt in die Fläche (`Paper.wideNoteInsets`).
Kompakt: `nil`-Einzüge und `.automatic`-Trenner, also die Voreinstellung der Form. Derselbe Wegwerf-Test wie oben,
danach wieder entfernt.

**`ipad-landscape-detail.png` (neu, überschreibt Schritt 2).** Über dem Titel **keine Linie mehr** (Pixelprüfung:
zwischen Leiste und Titel keine waagrechte Linie über 1000 px). Titel, „SAID“, Feldzeilen und Abschnittsköpfe stehen
wie vorher bei x ≈ 710 (von 2000), also ~20 pt vom Spaltenrand; die Zeilen haben etwas mehr Luft. Der Hinweis „Not
sorted yet“ ist eine blassgrüne Fläche **genau so breit wie die Haarlinien**: gemessen im Original beide von px 976
bis 2415; sein Text steht 12 pt innerhalb der Fläche. Alles übrige (Wortleiste, NOTE, ATTACHMENTS, „Show in calendar“
mit Schalter, PLACE, SUBTASKS) unverändert auf Papier mit Haarlinien.

**`iphone-detail-nachher.png` (neu).** Wie zuvor beschrieben: Titel dreizeilig in New York, Haarlinie, „SAID“,
Hinweis als abgerundete Karte, Due / Importance / Tags, Wortleiste, NOTE, ATTACHMENTS. Pixelvergleich gegen
`iphone-detail-vorher.png` (PIL `ImageChops.difference`): einzige Abweichung die Uhrzeit (bbox x 154–292,
y 77–117); **ab y 150 bbox `None`, pixelgleich**.

**iPhone gescrollt nach Politur: `iphone-detail-scrolled-nachher.png` (neu, Stand `4b3efe9`, Lauf 15:22, Sitzung
`le477-scr`, iPhone 17, derselbe Wegwerf-Test, danach entfernt).** Wie vorher: Leiste mit Zurück, „Looks right“, „…“,
darunter verblasst die Wortleiste; NOTE mit Platzhalter, ATTACHMENTS (Photo / File / Scan), „Show in calendar“ mit
Schalter (aus), PLACE („Add place“), SUBTASKS („Add a subtask … Add“), WAITING ON („Choose a task“), „3 from your
words – Show“, ADD MORE („Friday, one hour, call first“), Scroll-Indikator rechts. Pixelvergleich gegen
`iphone-detail-scrolled-vorher.png` (PIL `ImageChops.difference`): gesamt bbox (155, 77, 1197, 2427); ab y 150 bbox
**(1188, 1200, 1197, 2427)**, ein 9 px breiter Streifen am rechten Rand = Scroll-Indikator; ab y 150 ohne x ≥ 1180
bbox `None`. Die Politur ändert das kompakte Detail also nicht.

Mac: nicht lokal belegbar (Mac-Bilder nur aus der CI-Galerie `MacGallery`); dieselben Einzüge greifen dort über
`isWide` (auf dem Mac immer wahr).

Tests: `sim-unit` 823, davon 820 bestanden, 3 übersprungen (`SelfConsistencyReportTests/writesReport` – fehlt
`selfconsistency-run.json`; `SpeechLatencyTests/firstWordArrivesWithinThreeSecondsOfSpeechStart` und
`SpeechLatencyTests/finalTextContainsKeyWords` – Latenzschutz #274, läuft im Simulator nie), 0 fehlgeschlagen
(`test-green-output-politur.txt`). UI auf iPhone 17: `RecognitionWalkthroughTests` 1/1, `StartScreenInteractionTests`
16/16 grün.

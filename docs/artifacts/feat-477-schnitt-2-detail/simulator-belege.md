# #477 Schnitt 2 — Stufe 2, Simulatorbelege (2026-10-18)

Weg: ein Wegwerf-UI-Test (nicht im Repo) über `./scripts/sim.sh test`, Sitzung `le477-proof`, iOS 27.0.
Start mit `--ui-testing`, Englisch, Erfassung des Satzes „Ähm also ich muss morgen unbedingt noch Anna wegen dem
Steuerbescheid anrufen und nachfragen, wichtig“. Die Regeln setzen Fällig (Tomorrow), Wichtigkeit (High) und Tag
(Phone); Dringlichkeit, Dauer, Energie, Projekt, Wiederholung bleiben leer. Der Titel (Regeltitel, 12 Wörter ohne
„morgen“) weicht vom Satz ab, deshalb steht „SAID“ darunter.

- **Nachher:** Arbeitsstand dieses Zweigs (Diff an `DetailLayout.swift`, `Paper.swift`, `TaskDetailView.swift`).
- **Vorher:** Commit `aac08c4` (Basis des Zweigs, Stand `main` vor #477 Schnitt 2) in einem Wegwerf-Worktree, eigene
  Sitzung `le477-proof-vorher`, derselbe Test.
- iPad: „iPad Pro 13-inch (M5)“, Querformat per `XCUIDevice.orientation`. `app.screenshot()` liefert im Querformat ein
  falsch beschnittenes Bild; die iPad-Bilder sind deshalb Fensteraufnahmen (`app.windows.firstMatch.screenshot()`),
  um 90° aufgerichtet. Inhalt unverändert.

## iPad Querformat (AC-5)

**`ipad-landscape-detail.png` (nachher).** Links die Seitenleiste (Startseite, „New 1“ markiert), rechts das Detail.
Fläche durchgehend Papier (warmes Off-White), keine weißen Karten. Titel in New York medium, deutlich größer als die
Feldwerte (zwei Zeilen „Ähm also ich muss unbedingt noch Anna wegen / dem Steuerbescheid anrufen und“), keine
Beschriftung „Title“ davor. Darunter eine Haarlinie, dann kleiner Kopf „SAID“ in Großbuchstaben und der Satz kursiv grau.
Feldzeilen „Due – Tomorrow“, „Importance – High“, „Tags – Phone“: Name grau in normaler Schrift in fester Spalte, Wert in
New York Akzentfarbe mit Herkunftszeichen, getrennt durch Haarlinien. Leere Felder als Wortleiste „+ Urgency + Duration
+ Energy + Project + Repeat“ ohne Rahmen. Abschnittsköpfe „NOTE“, „ATTACHMENTS“, „PLACE“, „SUBTASKS“ klein in
Großbuchstaben. Die Spalte ist begrenzt und mittig im Detailbereich: der Hinweis „Not sorted yet“ ist etwa 720 pt breit
(1045 von 2000 Anzeigepunkten bei 1376 pt Bildschirmbreite), die Haarlinien etwa 680 pt — das passt zu einer Spalte von
760 pt abzüglich der Ränder der Form. Links (ab Kante der Seitenleiste, geschätzt) und rechts davon liegt etwa gleich viel
Papier (je rund 170 pt), ohne Streifen bis zum Rand.

**`ipad-landscape-detail-vorher.png` (vorher, zum Vergleich).** Dasselbe Detail auf `main`: jeder Abschnitt als weiße,
abgerundete Karte über die volle Breite des Detailbereichs (Titel+Satz, Feldblock, Wortleiste, Note, Attachments,
Kalender, Place, Subtasks), Titel einzeilig und kleiner (23 pt). Der Unterschied zu nachher ist eindeutig.

**`ipad-landscape-detail-scrolled.png` (nachher, gescrollt).** Unterer Teil: „Show in calendar“ mit Schalter, PLACE,
SUBTASKS („Add a subtask … Add“), WAITING ON („Choose a task“), „3 from your words – Show“, ADD MORE („Friday, one hour,
call first“). Alles auf Papier, keine Karten, rechte Kante der Spalte (Schalter, „Add“, „Show“) bündig an derselben
Linie.

AC-5: **sichtbar erfüllt.** Papier mit Haarlinien, keine Karten, großer New-York-Titel ohne „Title“, Spalte mittig und
auf 760 pt begrenzt.

## iPad Funktionen (AC-8)

**`ipad-edit-field.png`.** Tippen auf die Zeile „Due“ öffnet den Editor als Seite in der Detailspalte (Navigation, kein
Popover): Kopf „DUE“, „Tomorrow / Monday, October 19“, Knöpfe Today/Tomorrow (gewählt)/Weekend/Next week, Wochenleiste,
„Other date …“, Uhrzeiten, „No date“, „FROM YOUR WORDS“ mit markiertem „morgen“, Before/After, Reset. Der Editor
nutzt die ganze Breite der Detailspalte (nicht die 760-pt-Spalte; er ist nicht Teil dieses Schnitts). Zurück über den
Zurück-Knopf der Leiste führt ins Detail.

**`ipad-title-editing.png`.** Titel angetippt (Cursor am Ende), „ heute“ getippt, Tastatur offen; Titel steht weiter
groß in New York.

**`ipad-title-after-return.png`.** Nach Return: Tastatur geschlossen, Titel „… anrufen und heute“, Detail wieder in
Ruhe. Return beendet die Bearbeitung.

**`ipad-more-menu.png`.** Das Menü „Mehr“ (`detailMoreMenu`, die drei Punkte rechts oben) ist offen: Complete, Next up,
Park, Analyze again. In der Leiste stehen nur „Looks right“ (Bestätigen) und „…“ — kein Erledigen-Haken (#435).

AC-8 (Simulatorteil): **sichtbar erfüllt** — Feld öffnet den Editor, Titel ändern und mit Return beenden, Menü mit
Erledigen, „Looks right“ als Bestätigen; der Mac-Popover ist hier nicht belegbar (CI-Galerie).

Hinweis zum ersten Versuch: Tippt der Test mitten in den Titel, landet „\n“ nicht am Ende; `titleAfterReturn` macht dann
richtig ein Leerzeichen daraus und lässt die Bearbeitung offen. Das ist auf `main` identisch (Vergleichslauf) und kein
Fehler; der Beleg oben tippt ans Zeilenende.

## iPhone 17 vorher/nachher (AC-7)

**`iphone-detail-vorher.png` / `iphone-detail-nachher.png`.** Beide: Leiste mit Zurück, „Looks right“, „…“; Titel in
New York 23 pt über drei Zeilen, Haarlinie, „SAID“ mit Satz kursiv grau, Hinweis „Not sorted yet“, Feldzeilen Due /
Importance / Tags mit Haarlinien, Wortleiste in zwei Zeilen, „NOTE“, „ATTACHMENTS“. Papierfarbe, keine Karten.
Pixelvergleich unterhalb der Statusleiste: **keine Abweichung** (PIL `ImageChops.difference`, bbox `None`).

**`iphone-detail-scrolled-vorher.png` / `iphone-detail-scrolled-nachher.png`.** Gescrollt; Pixelvergleich: einzige
Abweichung ein 9 px breiter Streifen am rechten Rand (x 1188–1197), das ist der Scroll-Indikator.

AC-7 (Bildteil): **erfüllt** — das iPhone-Detail ist vorher und nachher pixelgleich.

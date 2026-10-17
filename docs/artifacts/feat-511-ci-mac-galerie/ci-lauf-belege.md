# CI-Belege #511 — Mac-Galerie

## Lauf 1 (rot): 39015688624, Job 117347228477, Stand 5a0dfc9
- `Enable UI automation (#511)`: „Setting up machine to allow Automation Mode without requiring user authentication... succeeded.“
- `Run Mac gallery`: beide Tests scheitern mit „No start page“ (Executed 2 tests, with 2 failures).
- Ursache aus `MacGalleryResults` (UI-Hierarchie + Bildschirmaufnahme): Die App läuft, zeigt aber **kein Fenster** — nur Menüleiste und StatusItem „Loose Ends“; „Hide Loose Ends“ ausgegraut (Richtlinie `.accessory`); Finder bleibt vorn. Bildschirm 1024 × 768.
- Folge: Test öffnet das Fenster wie ein Nutzer über das Menüleisten-Symbol → „Open Loose Ends“ (`menuBarOpenApp`), vermerkt „window at launch“; App-Frage als #513.
- Signatur ad hoc ohne Entitlements hat funktioniert (App startete) → **kein Rückfall** auf `CODE_SIGNING_ALLOWED=NO` nötig.

## Lauf 2 (grün): 39016175718, Job 117348851617, Stand 53efa03
- Alle Schritte success; Protokoll: `Xcode 27.0` (Z. 131), Automationsmodus „succeeded.“ (Z. 157),
  `✔ testGalleryDark (52.416 seconds)`, `✔ testGalleryLight (30.739 seconds)`,
  „Executed 2 tests, with 0 failures (0 unexpected)“ (Z. 719–721). Kein erneuter Versuch.
- Diagnose: „Automation Mode is disabled.“ (nach dem Lauf; testmanagerd schaltet ihn am Ende ab),
  „This device DOES NOT REQUIRE user authentication to enable Automation Mode.“
- Export: 8 Anhänge, Ordner `MacGallery` = 6 PNG + 2 TXT. Artefakte `MacGallery` und `MacGalleryResults` hochgeladen.
- Übrige Jobs: Unit Tests (macOS destination) success, Build (iOS Simulator) success, UI Smoke läuft noch (Stand dieser Notiz).

### Fenstergröße (Anhänge `window-size`)
- dunkel (lief zuerst): `900 x 450 pt; window at launch: no, opened from the menu bar`
- hell (lief danach): `900 x 450 pt; window at launch: yes`
→ ≥ 700 pt (Zusicherung erfüllt), aber < 1120 pt: rechte Spalte der Startseite fehlt → laut AC-11 eigenes Ticket für `defaultSize` (#514). Beim zweiten Start derselben Maschine war ein Fenster da: Ergänzung in #513.

### Bilder (alle 900 × 450, nur das Hauptfenster, kein ganzer Bildschirm, kein Panel)
1. **light-1-start:** Papiergrund hell. Titelleiste mit Seitenleisten-Knopf, Zahnrad, „Loose Ends“, Plus. Seitenleiste „CONTENTS“: Next up, Due, New 3, Tags 6 (Phone 1, Garden 1 in Akzentfarbe), Projects, All open 3, „Compl…“ (abgeschnitten). Rechts Faden + „SATURDAY, OCTOBER 17“, Satz „Nothing presses today.“, Feld „What should I remember?“ (leer nach drei Erfassungen), „NOW“ mit „Swipe left on any task to line it up here.“ Keine rechte Spalte (Fenster zu schmal). Die drei Aufgaben stehen nicht auf der Startseite (sie sind nicht in „Now“), sondern in „New 3“.
2. **light-2-list-new:** „New“ in der Seitenleiste markiert. Titel „New“, Abschnitt „Needs a look“, drei Zeilen: „Rasen mähen“ (Garden), „Anna wegen anrufen“ (Tomorrow, Phone), „Steuerbescheid prüfen“ (Tomorrow); je „Not sorted yet“.
3. **light-3-detail:** Detail „Rasen mähen“: Titel-Zeile, „Not sorted yet — That happens by itself once Apple Intelligence is ready.“, Tags Garden mit Herkunftszeichen, Knöpfe „+ Due … + Repeat“, NOTE mit Platzhalter, ATTACHMENTS angeschnitten; oben „Looks right“ (Akzent) und „…“-Menü, Zurück-Pfeil.
4. **dark-1-start:** wie 1, dunkel — **auch Titelleiste und Seitenleiste dunkel** (`-AppleInterfaceStyle Dark` wirkt), Akzent hellblau-türkis.
5. **dark-2-list-new:** wie 2, dunkel.
6. **dark-3-detail:** wie 3, dunkel; „Looks right“ türkis.

### Auffälligkeiten (nicht Gegenstand von #511, für die Mac-Tickets #477–#480)
- „Completed“ ist in der Seitenleiste zu „Compl…“ abgeschnitten (Fenster 900 pt).
- Hinweis „Swipe left on any task…“ ist auf dem Mac Wisch-Sprache.
- Titel ohne Datumswörter („Anna wegen anrufen“) ist gewolltes Verhalten (#217).

## Lauf 3 auf `main` (AC-12): 39024850068, Stand 99bbaeb (PR #512 eingespielt)
- Job „Mac Gallery (macOS)“: completed success. Build (iOS Simulator) success, die übrigen Jobs liefen beim Abruf noch.
- Artefakt `MacGallery`: `mac-gallery-{light,dark}-{1-start,2-list-new,3-detail}.png` (6 PNG) und `mac-gallery-{light,dark}-window-size.txt` (2 TXT).
- Fenstergröße: beide `900 x 450 pt; window at launch: no, opened from the menu bar`. Auf dieser Maschine öffnete also auch der zweite Start kein Fenster (Ergänzung in #513).
- Geöffnet: light-1-start (wie Lauf 2: Seitenleiste, „Nothing presses today.“, leeres Feld, NOW), dark-2-list-new (drei Zeilen, „New“ markiert, dunkle Seitenleiste), dark-3-detail („Rasen mähen“, „Looks right“ türkis). Inhaltlich gleich mit Lauf 2.

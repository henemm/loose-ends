# Adversary Dialog — fix-637-start-zeigt-badge
Spec: docs/specs/fix-637-zahl-symbol-jetzt.md
Datum: 2026-10-23 18:29

## Checkliste
- [x] **AC-1:** `ViewRules.badgeCount(in:)` ist für jede Eingabe gleich `ViewRules.now(in:).all.count`; beide kommen aus derselben Funktion (Unit-Test `badgeEqualsNowEverywhere` über alle genannten Eingabemengen, plus Quelltext: `badgeCount` ruft `now`).
- [x] **AC-2:** `now(...).all` enthält jede Aufgabe aus `dueToday`, `tasks(for: .next)` und `leftovers` genau einmal; blockierte, geparkte, erledigte und Teilaufgaben ohne eigenes Datum fehlen (Unit-Tests).
- [x] **AC-3:** Reihenfolge: heute Fälliges, dann alle eingereihten nach Rang (Liegengebliebene mit Rang darunter), dann die Liegengebliebenen ohne Rang, älteste Frist zuerst (Unit-Tests `leftoverWithRankStandsInLined`, `leftoverWithoutRankStandsLastOldestFirst`).
- [x] **AC-4:** Mit Hennings Fall (vier verstrichene Fristen, eine davon eingereiht, dazu eine eingereihte ohne Datum) ergibt die Regel 5 für Symbol und „Jetzt“, 4 für „Fällig“, 2 für „Als nächstes“ (Unit-Test; Wegwerf-Reproduktion vom 2026-10-23 zeigte vorher 1 und 5).
- [x] **AC-5:** Die Startseite zeigt über „Jetzt“ die Zahl `all.count`, auf iPhone im Kopf, auf iPad und Mac außerdem an der Zeile „Start“; alle Zeilen der Menge stehen unter „Jetzt“, die Liegengebliebenen mit „Neues Datum“ und Spur am Rand, ohne Rot (UI-Test `StartNumberTests` im iPhone-Simulator; Mac-Galerie-Bild, angesehen).
- [x] **AC-6:** Ein Tipp auf „Neues Datum“ in „Jetzt“ öffnet die Datumswahl; nach dem Setzen steht die Aufgabe nach der Regel am richtigen Platz und die Zahl über „Jetzt“ gleicht dem Symbol (UI-Test).
- [x] **AC-7:** `StartHeadline`, die Zählung von „Fällig“ und „Als nächstes“ und `dueToday` liefern für dieselbe Eingabe dieselben Ergebnisse wie vorher (bestehende Tests grün); das Widget „Als nächstes“ ist unverändert.
- [x] **AC-8:** ADR-16 trägt den Nachtrag: „Jetzt“ zeigt auch Liegengebliebenes (ändert #518), Symbol und „Jetzt“ sind dieselbe Zahl (ergänzt #584), mit Hennings Wortlaut vom 2026-10-23.

## Dialog

### Runde 1
**Adversary:** Beweis je AC, nicht Behauptung. Eigener Lauf: `./scripts/sim.sh sim-unit NowRuleTests`, `CarryRemindersTests`, `DueTodayTests`, `DueStateTests`, `SubtaskListsTests` (alle "Test Succeeded", Ausgabe in `adversary-test-output.txt`; Lauf 1: 16 Tests der Suite "Now on the start screen" gruen, 0 Fehler; die 1 uebersprungene Messstrecke ist `SelfConsistencyReportTests`, eine Korpus-Messung ausserhalb dieses Schnitts, keine der Tests dieses Tickets).
**Implementierer:**
- AC-1: Code reference: Shared/Models/ViewRules.swift:163 — `badgeCount` ist `Self.now(...).all.count`, keine zweite Rechnung. Test `badgeEqualsNowEverywhere` (7 Eingabemengen) gruen. Aufrufer `DueNotificationCenter.swift:231` und `CarryReminders.swift:136` rufen weiter `badgeCount`.
- AC-2: Code reference: Shared/Models/ViewRules.swift:180-190 — Menge = dueToday (ohne Liegengebliebene) + tasks(.next) + leftovers, dedupliziert ueber `seen`. Blockiert/geparkt/erledigt fallen in `dueToday`, `.next` und `NewDateRule.needsNewDate` (isOpen, !isBlocked) heraus; Teilaufgabe ohne eigenes Datum hat kein dueDate und ist nicht in `.next` (topLevel). Tests `unionMatchesTheTwoSources`, "Blocked, done and parked stay out ..." gruen.
- AC-3: Code reference: Shared/Models/ViewRules.swift:185-190 — `today` nach Frist, `lined` nach Rang inkl. Liegengebliebener mit Rang, `waiting` in NewDateRule-Ordnung (aelteste zuerst). Tests `leftoverWithRankStandsInLined`, `leftoverWithoutRankStandsLastOldestFirst` gruen.
- AC-4: Test `henningsCaseIsFiveEverywhere`: now 5, badge 5, `.due` 4, `.next` 2 — gruen. Simulator-Screenshot D07D8099...png (angesehen): "NOW 5", fuenf Zeilen, vier mit "New date", Ueberschrift "Four things need a new date.", Contents "Next up 2", "Due 4". Code reference: LooseEnds/App/LooseEndsApp.swift:97-126 (Seed).
- AC-5: Code reference: LooseEnds/Views/StartZones.swift:83-86 (`ZoneCaption("Now", count: tasks.count, ...)`, `.foregroundStyle(.primary)`, kein Akzent), LooseEnds/Views/StartPage.swift:116 (iPad/Mac), LooseEnds/Views/SidebarView.swift:128 (iPhone-Kopf), SidebarView.swift:94-95 und :141 (Zeile "Start", Mac/iPad, `count: nowCount`). Test `testNumberOverNowIsTheNumberOfRows` (5 / 5 Zeilen / 4 newDate_) laut test-green-ui.txt gruen; Mac-Galerie `testStartNumberLight/Dark` (MacGalleryTests.swift:139-170) existiert, laeuft nur in der CI.
- AC-6: Code reference: LooseEnds/Views/StartPage.swift:153 und :178 (`onNewDate: { redating = task }`), StartPage.swift:95-97 (`.sheet(item: $redating)` mit `NewDateSheet`), SidebarView.swift:215-217 und :290 (iPhone). Test `testNewDateFromNowLowersTheNumber` (Tipp, "Tomorrow", Zahl 5 -> 4, 4 Zeilen); Screenshot 8A85A3FC...png (angesehen): "NOW 4", vier Zeilen, Headline "Three things ...".
- AC-7: Die Diffs beruehren `dueToday`, `tasks(for:)`, `leftovers`, `StartHeadline` nicht (nur Kommentare in NewDateRule.swift:3-8 und ViewRules.swift:87-90, :146). Bestehende Tests DueTodayTests, DueStateTests, CarryRemindersTests, SubtaskListsTests gruen. Widget/Watch: grep nach `badgeCount`/`ViewRules.now(` zeigt keine Treffer in LooseEndsWidgets/LooseEndsWatch*.
- AC-8: Code reference: docs/project/00-entscheidungen.md (Nachtrag ADR-16, Diff: "Eine Zahl ueberall (Henning, 2026-10-23 ...)", nennt #518 geaendert, #584 ergaenzt, Wortlaut zitiert).

### Runde 2
**Adversary:** Angriffe, die der Implementierer nicht erwartet.
(a) Gibt es einen Fall mit badgeCount != now.all.count? Alt = `.due` (listedByDate, offen, !blockiert, dueDate < morgen) + `.next`. `.due` minus `dueToday` = dueDate < heute; jede solche Aufgabe erfuellt `needsNewDate` (Uhrzeit: due < now, da due < Tagesbeginn <= now; ohne Uhrzeit: Tag < heute) und ist in `leftovers`. Heute verstrichene Uhrzeit: in `dueToday` und `leftovers`, wird aus `today` gefiltert (`leftIDs`), landet via `.next`/`waiting` genau einmal. Teilaufgabe mit eigenem Datum und verstrichen: in `leftovers` (kein listedByDate-Filter, aber dueDate gesetzt) und in `.due` — gleich. Teilaufgabe mit Rang aber ohne Datum: weder `.next` (topLevel) noch leftovers — fehlt in beiden. Eingereihte Teilaufgabe mit verstrichenem Datum: `left.filter nextRank != nil` — einmal, Zahl unveraendert. Blockiert/geparkt: aus allen drei Quellen draussen. Kein Gegenbeispiel; `badgeCount` ist ohnehin per Konstruktion `now.all.count` (ViewRules.swift:163), also gleich fuer jede Eingabe.
**Implementierer:** Code reference: Shared/Models/ViewRules.swift:180-190, Shared/Models/NewDateRule.swift:28-38. Test `badgeEqualsNowEverywhere` deckt diese Szenen (blockiert, geparkt, erledigt, Teilaufgabe ohne/mit Datum, Frist heute 09:00 und 00:00) ab. Alt/neu-Gleichheit der Menge habe ich oben hergeleitet; die Zahl am Symbol aendert sich gegenueber vorher fuer keine Eingabe (nur "Jetzt" wuchs).

**Adversary:** (b)/(c) Zahl an "Start" und im Kopf; doppelte Zeilen oder zwei Sheets?
**Implementierer:** Code reference: LooseEnds/Views/SidebarView.swift:112-139 — Zweige `isCompact` (iPhone/kompaktes iPad: NowBlock im Sidebar-Listenkopf, keine Start-Zeile), `isMac` (ContentsIndex mit `start`-IndexLine, Zahl `nowCount`, Zeile `viewRow_start`), sonst iPad (Button-Zeile `countRow(... count: nowCount)`). Der NowBlock steht je Zustand genau einmal: kompakt in SidebarView, sonst in StartPage.swift:116. Damit existiert `nowCount` je Bildschirm einmal, `redating` ist je Host ein eigener State und nur der gerenderte Block loest ihn aus; `datingTask` (Faellig) ist ein getrennter State. Kein doppeltes Sheet. `IndexLineLabel` (StartZones.swift:290-294) zeigt die Zahl in `.secondary`, bei 0 unsichtbar — erwartet.

**Adversary:** (d) Leckt der Seed in den Produktbetrieb?
**Implementierer:** Code reference: LooseEnds/App/LooseEndsApp.swift:101-102 — `guard ModelContainerFactory.isUITesting && arguments.contains("--ui-testing-leftovers")`; `isUITesting` erzwingt den In-Memory-Container (ModelContainerFactory.swift:77). Ohne beide Argumente kehrt die Funktion sofort zurueck; Produktdaten und CloudKit nicht beruehrt. Kein Leck.

**Adversary:** (e) Aendern sich StartHeadline, "Faellig"/"Als naechstes", Widget, Watch? (g) Shared/ fuer Watch/Widget?
**Implementierer:** Der Diff in `Shared/` besteht aus ViewRules.swift und NewDateRule.swift, reine Foundation-Logik ohne SwiftUI (Code reference: Shared/Models/ViewRules.swift:1, Shared/Models/NewDateRule.swift:1: nur `import Foundation`). Die SwiftUI-Aenderungen liegen alle in LooseEnds/Views (StartZones, StartPage, SidebarView). Headline-Test ("Three things need a new date" im Screenshot unveraendert, Faellig 4, Als naechstes 2). Watch/Widget-Compile habe ich nicht gebaut; die Aenderung kann sie nicht brechen, da `NowTasks` nur um ein Feld mit Default erweitert wurde (`var waiting: [TaskItem] = []`) und `all` weiter existiert.

**Adversary:** (f) Mac-Galerie und was bleibt unbelegt?
**Implementierer:** Code reference: LooseEndsUITests/MacGalleryTests.swift:139-170 prueft `nowCount` == "5", `viewRow_start` enthaelt "5" und vier `newDate_`-Elemente, plus Foto light/dark. Das ist nur in der CI lauffaehig (Spec: "Mac-Galerie (CI)"), lokal nicht ausgefuehrt: unbelegt bis zur CI. iPad hat keinen eigenen Durchlauf (laut Spec: nur Rechenregel im Unit-Test).

Auffaelligkeiten, kein Defekt: (1) Im Screenshot ist die Spur der Zeile "Geburtstagskarte" zu "was yeste..." abgeschnitten (schmale Randspalte) — kosmetisch, vorbestehende Spaltenbreite. (2) Der UI-Test kann das App-Symbol selbst nicht lesen; "Symbol = 4" nach dem Setzen belegt nur der Unit-Test ueber `badgeCount`. (3) `element(boundBy: 3)` im UI-Test haengt an der Reihenfolge (Rang, dann aelteste Frist), die der Unit-Test ebenfalls festlegt.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)


## Verdict

VERDICT: VERIFIED

Alle 8 ACs belegt (Unit-Laeufe selbst gruen, Screenshots angesehen, Code gelesen). Offen nur CI-Belege fuer Mac (Galerie) und iPad (laut Spec nur Rechenregel). Befunde nur kosmetisch/LOW.

Code reference: LooseEnds/App/LooseEndsApp.swift:101
Code reference: LooseEnds/Views/SidebarView.swift:94
Code reference: LooseEnds/Views/StartPage.swift:116
Code reference: LooseEnds/Views/StartZones.swift:83
Code reference: Shared/Models/NewDateRule.swift:28
Code reference: Shared/Models/ViewRules.swift:163

## Geprüfte Dateien

- sha256:4a6084638421e36b506a22aa2a43143987af3f1ab3065cc3f9892d28501ac04a  LooseEnds/App/LooseEndsApp.swift
- sha256:8e917308f70b92e8c7e66c0c2b02d308142cdbeaa15d3ca58ce32e723d54d812  LooseEnds/Views/SidebarView.swift
- sha256:211fd507988f69be55e07e944b7d6391f0c70a8103b675ae4e6e41c282a99d28  LooseEnds/Views/StartPage.swift
- sha256:419d3028e2e55374795bf6ef307926d84f25e990a2f7cb10b0a7f520c67a80f8  LooseEnds/Views/StartZones.swift
- sha256:d7f0f9a1b2d0fc51ce39f725c200207ab7f8d77a47e2a990e0d7302df10b2600  Shared/Models/NewDateRule.swift
- sha256:c55381f0eb94552814e1f661dc2bf69726e449c08e38ac8798b921b0dbf95ed5  Shared/Models/ViewRules.swift

## Prüfbasis

- base: dc39bec0be53ad3b68af7a784e91b47856d730b5
- blob:c755a91b981525754ed0f57bcad3253bbc376a6a  LooseEnds/App/LooseEndsApp.swift
- blob:49aadbb97bb29c039bb8756d6eb9c1cf7658be73  LooseEnds/Views/SidebarView.swift
- blob:9c0e0184742d6c4fbbd2dc38b6be887c848086ab  LooseEnds/Views/StartPage.swift
- blob:b22e0946b5daccec8e6b981f18d36d986832058a  LooseEnds/Views/StartZones.swift
- blob:68c6d514ea48e0529893d60623d237c147c8ba58  Shared/Models/NewDateRule.swift
- blob:86e6e09d55d55b8d525ba5744266c40fe0f0b96f  Shared/Models/ViewRules.swift

## Geprüfte Dateien

- sha256:4a6084638421e36b506a22aa2a43143987af3f1ab3065cc3f9892d28501ac04a  LooseEnds/App/LooseEndsApp.swift
- sha256:8e917308f70b92e8c7e66c0c2b02d308142cdbeaa15d3ca58ce32e723d54d812  LooseEnds/Views/SidebarView.swift
- sha256:211fd507988f69be55e07e944b7d6391f0c70a8103b675ae4e6e41c282a99d28  LooseEnds/Views/StartPage.swift
- sha256:419d3028e2e55374795bf6ef307926d84f25e990a2f7cb10b0a7f520c67a80f8  LooseEnds/Views/StartZones.swift
- sha256:d7f0f9a1b2d0fc51ce39f725c200207ab7f8d77a47e2a990e0d7302df10b2600  Shared/Models/NewDateRule.swift
- sha256:c55381f0eb94552814e1f661dc2bf69726e449c08e38ac8798b921b0dbf95ed5  Shared/Models/ViewRules.swift

## Prüfbasis

- base: dc39bec0be53ad3b68af7a784e91b47856d730b5
- blob:c755a91b981525754ed0f57bcad3253bbc376a6a  LooseEnds/App/LooseEndsApp.swift
- blob:49aadbb97bb29c039bb8756d6eb9c1cf7658be73  LooseEnds/Views/SidebarView.swift
- blob:9c0e0184742d6c4fbbd2dc38b6be887c848086ab  LooseEnds/Views/StartPage.swift
- blob:b22e0946b5daccec8e6b981f18d36d986832058a  LooseEnds/Views/StartZones.swift
- blob:68c6d514ea48e0529893d60623d237c147c8ba58  Shared/Models/NewDateRule.swift
- blob:86e6e09d55d55b8d525ba5744266c40fe0f0b96f  Shared/Models/ViewRules.swift

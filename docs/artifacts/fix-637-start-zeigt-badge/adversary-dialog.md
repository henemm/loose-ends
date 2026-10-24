# Adversary Dialog — fix-637-start-zeigt-badge
Spec: docs/specs/fix-637-zahl-symbol-jetzt.md
Datum: 2026-10-24 09:09

## Checkliste
- [x] **AC-1:** `ViewRules.badgeCount(in:)` ist für jede Eingabe gleich `ViewRules.nowCount(in:)`, der Zahl über „Jetzt“: Zeilenzahl von `now(in:).all` plus 1, wenn das Knäuel zu „Fällig“ oder „Als nächstes“ gehört; beide kommen aus derselben Funktion (Unit-Test `badgeEqualsNowEverywhere` über alle genannten Eingabemengen, auch mit Knäuel, plus Quelltext: `badgeCount` ruft `nowCount`).
- [x] **AC-2:** `now(...).all` enthält jede Aufgabe aus `dueToday`, `tasks(for: .next)` und `leftovers` genau einmal; blockierte, geparkte, erledigte und Teilaufgaben ohne eigenes Datum fehlen (Unit-Tests).
- [x] **AC-3:** Reihenfolge: heute Fälliges, dann alle eingereihten nach Rang (Liegengebliebene mit Rang darunter), dann die Liegengebliebenen ohne Rang, älteste Frist zuerst (Unit-Tests `leftoverWithRankStandsInLined`, `leftoverWithoutRankStandsLastOldestFirst`).
- [x] **AC-4:** Mit Hennings Fall (vier verstrichene Fristen, eine davon eingereiht, dazu eine eingereihte ohne Datum) ergibt die Regel 5 für Symbol und „Jetzt“, 4 für „Fällig“, 2 für „Als nächstes“ (Unit-Test; Wegwerf-Reproduktion vom 2026-10-23 zeigte vorher 1 und 5).
- [x] **AC-5:** Die Startseite zeigt über „Jetzt“ die Zahl `nowCount`, auf iPhone im Kopf, auf iPad und Mac außerdem an der Zeile „Start“; alle Zeilen der Menge stehen unter „Jetzt“, die Liegengebliebenen mit „Neues Datum“ und Spur am Rand, ohne Rot (UI-Test `StartNumberTests` im iPhone-Simulator; Mac-Galerie-Bild, angesehen).
- [x] **AC-6:** Ein Tipp auf „Neues Datum“ in „Jetzt“ öffnet die Datumswahl; nach dem Setzen steht die Aufgabe nach der Regel am richtigen Platz und die Zahl über „Jetzt“ gleicht dem Symbol (UI-Test).
- [x] **AC-7:** `StartHeadline`, die Zählung von „Fällig“ und „Als nächstes“ und `dueToday` liefern für dieselbe Eingabe dieselben Ergebnisse wie vorher (bestehende Tests grün); das Widget „Als nächstes“ ist unverändert.
- [x] **AC-8:** ADR-16 trägt den Nachtrag: „Jetzt“ zeigt auch Liegengebliebenes (ändert #518), Symbol und „Jetzt“ sind dieselbe Zahl (ergänzt #584), mit Hennings Wortlaut vom 2026-10-23.

## Dialog

### Runde 1
**Adversary:** (a) Gibt es einen Eingabefall, in dem `badgeCount` != `nowCount` oder Zahl != Symbol? `badgeCount` koennte eine eigene Rechnung behalten haben; `now` koennte eine Aufgabe doppelt oder gar nicht fuehren; das Knaeuel (Frist heute, verstrichen, eingereiht, ohne Datum/Rang, geparkt, blockiert, zwei markiert) koennte doppelt oder falsch zaehlen.
**Implementierer:** `badgeCount` ruft nur `nowCount` auf, keine zweite Rechnung. Code reference: Shared/Models/ViewRules.swift:163. `nowCount` = `now(...).all.count` plus 1, wenn `knaeuel(in:)` in `tasks(for:.due)` oder `.next` steht. Code reference: Shared/Models/ViewRules.swift:170. Mengen nachgerechnet: `.due` (ViewRules.swift:332-338) = dueToday (Datum heute) vereinigt mit leftovers (Code reference: Shared/Models/NewDateRule.swift:28-32, needsNewDate): jede Frist vor heute ist verstrichen (mit Uhrzeit due<now, ohne Uhrzeit Tag vorbei), heute mit verstrichener Uhrzeit ebenfalls. Blockiert/geparkt/erledigt fehlen in dueToday, leftovers (isOpen, !isBlocked) und `.next` (!isBlocked) gleichermassen. Teilaufgaben: `listedByDate` laesst nur solche mit eigenem Datum zu, `.next` nimmt nur Top-Level; `now` benutzt dieselben Quellen. `now` klammert das Knaeuel aus today, left und lined aus und `seen` verhindert Doppelte (ViewRules.swift:190-200). Das Knaeuel zaehlt +1 nur, wenn es in .due/.next steht, also genau dann, wenn es sonst als Zeile stuende: ohne Datum und Rang 0, sonst 1; geparkt/erledigt ist nach `isKnaeuel` (isOpen) keins; blockiert steht in keiner Menge, kein +1. Zwei Knaeuel: nur das juengste wird ausgeklammert und mit +1 gezaehlt, das andere steht als normale Zeile in `now`; jede Aufgabe genau einmal, Rechnung konsistent. Test `badgeEqualsNowEverywhere` deckt leer, heute, gestern, blockiert/geparkt/erledigt/Teilaufgaben, morgen und vier Knaeuel-Faelle ab (Code reference: LooseEndsTests/NowRuleTests.swift:235); selbst ausgefuehrt, gruen (adversary-test-output.txt). Luecke: der Zwei-Knaeuel-Fall hat im NowRuleTests keinen eigenen Test (F001, LOW; KnaeuelTests prueft nur "latest wins").
**Adversary:** (b) Zeigen alle Oberflaechen `nowCount`, nirgends eine eigene Rechnung?
**Implementierer:** iPhone: `NowBlock(..., count: nowCount)`, Code reference: LooseEnds/Views/SidebarView.swift:131, mit `nowCount = ViewRules.nowCount(in: tasks)` (SidebarView.swift:104). iPad/Mac Zeile "Start": SidebarView.swift:97 und :145, `count: nowCount` (vorher 0). iPad/Mac Startseite: Code reference: LooseEnds/Views/StartPage.swift:75, `count: ViewRules.nowCount(in: tasks)`. Der Kopf setzt die Zahl in Tinte, nicht Akzent: Code reference: LooseEnds/Views/StartZones.swift:92 (`ZoneCaption("Now", count: count, countID: "nowCount")`, Darstellung :27-31). Symbol: DueNotificationCenter.swift:231 und CarryReminders.swift:136 rufen `badgeCount`. Suche ueber Shared, LooseEnds, Widgets, Watch: keine weitere Zaehlung. "Neues Datum" in Jetzt: StartPage.swift:137/162 und SidebarView.swift:309 reichen `onNewDate` an `NewDateSheet` weiter (:59-61 / :219-221).
**Adversary:** (c) `StartHeaderRows`: stimmt "Knaeuel + Zeilen = Zahl"?
**Implementierer:** `StartHeaderRows` zeigt `ViewRules.knaeuel(in: tasks)` immer (Code reference: LooseEnds/Views/Knaeuel.swift:39), unabhaengig von Datum und Rang. "Knaeuel + Zeilen = Zahl" gilt also nur, wenn das Knaeuel zu Faellig/Als naechstes gehoert; ein Knaeuel ohne Datum und Rang steht da, wird aber nicht gezaehlt. Das ist so spezifiziert ("gehoert zu Faellig oder Als naechstes", Test-Szene 3 mit share 0) und deckt sich mit der Zahl des Symbols (nie eine zweite Zahl), aber fuer einen Leser, der addiert, ist es ein Randfall (F002, LOW). Knaeuel.swift ist im Diff gegenueber origin/main unveraendert.

### Runde 2
**Adversary:** (d) Seed nur unter isUITesting? (e) Bleibt Shared/ Watch/Widget-tauglich? (f) Laufen die Tests? Stammt der rote Knaeuel-Test von #637? Stimmt AC-8 (ADR)?
**Implementierer:** (d) `seedLeftoversIfAsked` bricht per `guard ModelContainerFactory.isUITesting, arguments.contains("--ui-testing-leftovers")` ab, schreibt in den In-Memory-Speicher, der Speicherfehler wird mit Logger gemeldet, kein `try?`. Code reference: LooseEnds/App/LooseEndsApp.swift:101 (Aufruf :33). (e) Aenderungen in Shared/ sind reine Foundation-Regeln ohne SwiftUI (Shared/Models/ViewRules.swift, in Shared/Models/NewDateRule.swift nur Kommentar, Code reference: Shared/Models/NewDateRule.swift:6-8); ZoneCaption/NowBlock liegen in LooseEnds/Views; Widget und `tasks(for:)`, `dueToday`, `StartHeadline` unveraendert. (f) Selbst ausgefuehrt mit `./scripts/sim.sh sim-unit`: NowRuleTests gruen (16 Tests, u.a. "Henning's case ... icon and Now say 5" und "The icon number is the number over Now"), CarryRemindersTests gruen, KnaeuelTests mit EINEM roten Test (`setWords`, 5 issues); Ausgabe in docs/artifacts/fix-637-start-zeigt-badge/adversary-test-output.txt. Der rote Test: `KnaeuelSince.setWords` liefert `String(localized: "since this morning")` usw. (Code reference: LooseEnds/Views/Knaeuel.swift:322-338), die Uebersetzung "seit heute Morgen" existiert (LooseEnds/Resources/Localizable.xcstrings:465), der Test erwartet englische Woerter und setzt nur das Datumsformat auf en: die Zeichenketten folgen der Sprache des Hosts. Meine Aenderung fasst weder Knaeuel.swift noch KnaeuelTests.swift an und der Test ruft weder `badgeCount` noch `nowCount` auf: kein Zusammenhang mit #637, der Fehler gehoert zu main (#647); er bleibt trotzdem rot (F003, MEDIUM, nicht dieses Ticket). Simulator-Belege angesehen: Bild 0AAAB709: "NOW 5", fuenf Zeilen, vier mit "New date" und Spur (was Thu/Tue/Wed/yesterday) in Akzentfarbe, kein Rot, Contents: Next up 2, Due 4, Ueberschrift "Four things need a new date"; nach dem Setzen eines neuen Datums (Bild 31505433): "NOW 4", Due 3, Next up 2. UI-Lauf: 2 Tests, 0 Fehler (test-green-ui.txt:35-38). AC-8: ADR-16 Nachtrag steht (docs/project/00-entscheidungen.md:205-212) mit Hennings Wortlaut vom 2026-10-23, aendert #518, ergaenzt #584; er sagt aber noch, `badgeCount` sei "die Zeilenzahl von now" und nennt das Knaeuel nicht (F004, LOW).
**Adversary:** Regression?
**Implementierer:** Bestehende Tests (DueTodayTests, DueStateTests, SubtaskListsTests, CarryRemindersTests) wurden nur in den Zahlen nachgezogen; `dueToday` und `tasks(for:)` sind unveraendert, der Rest der Suite laut test-green-unit.txt gruen bis auf den einen fremden Test.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED — alle 8 ACs belegt; Symbol und Zahl ueber "Jetzt" kommen aus derselben Funktion, der rote KnaeuelTests-Test (Sprache des Hosts, Knaeuel.swift unveraendert) gehoert nicht zu #637.

Befunde (alle ausserhalb der ACs, kein Blocker):
- F001 LOW edge_case, Code reference: LooseEndsTests/NowRuleTests.swift:261: kein Test fuer zwei markierte Knaeuel in nowCount.
- F002 LOW edge_case, Code reference: LooseEnds/Views/Knaeuel.swift:39: Knaeuel ohne Datum/Rang wird gezeigt, aber nicht gezaehlt (laut Spec).
- F003 MEDIUM regression-fremd, Code reference: LooseEnds/Views/Knaeuel.swift:322: setWords haengt an der Hostsprache, Test rot, nicht aus #637.
- F004 LOW spec_violation(Doku), Code reference: docs/project/00-entscheidungen.md:209: ADR-Text nennt das Knaeuel in der Zahl nicht.

Confirmation:
  AC: AC-1
  Code reference: Shared/Models/ViewRules.swift:163
  Evidence: badgeCount ruft nowCount; nowCount = now(...).all.count plus Knaeuel-Anteil.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Models/NewDateRule.swift:28
  Evidence: leftovers nur offen und nicht blockiert; now vereinigt dueToday, next, leftovers einmal.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Views/SidebarView.swift:131
  Evidence: iPhone-Kopf und Start-Zeile (:97, :145) zeigen nowCount.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Views/StartPage.swift:75
  Evidence: Startseite iPad/Mac uebergibt ViewRules.nowCount.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Views/StartZones.swift:92
  Evidence: Kopf Jetzt traegt die Zahl in Tinte.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/App/LooseEndsApp.swift:101
  Evidence: Seed nur unter isUITesting und --ui-testing-leftovers; Simulatorbild zeigt NOW 5 / Due 4 / Next up 2.
  Status: CONFIRMED

## Geprüfte Dateien

- sha256:19b93c447061dffbe5c33177d31690e00d0b865e54cc4dfa99ad4c12ff58016d  LooseEnds/App/LooseEndsApp.swift
- sha256:c3eb10139afaa97c32ed589d185e49e8ff5b929458f8487a1271053f26a2db7b  LooseEnds/Views/SidebarView.swift
- sha256:a579a708761102f75f3a62edc9dda22090512d82474b666de6f94bfe4d2b2bdc  LooseEnds/Views/StartPage.swift
- sha256:e90ce7fa1d00c1e45ad63fd0d397e8d51376639fc734e52379afc1afdb8ea0dd  LooseEnds/Views/StartZones.swift
- sha256:d7f0f9a1b2d0fc51ce39f725c200207ab7f8d77a47e2a990e0d7302df10b2600  Shared/Models/NewDateRule.swift
- sha256:17afc2fba7628ae97f441280af2862c46ee455ae2c86e48576934788b758181d  Shared/Models/ViewRules.swift

## Prüfbasis

- base: 96f79e8be9c336d4bd7b17d5f82fde53582e7f4f
- blob:5ab925aa8d8ec6ac637e31eb08b791d7edfed192  LooseEnds/App/LooseEndsApp.swift
- blob:65dc10b72f8b2743d0968eff8a60468ac365219b  LooseEnds/Views/SidebarView.swift
- blob:bdd6e9a22bff0b1a4c41285425be0afa91ba579d  LooseEnds/Views/StartPage.swift
- blob:de4b3fc243a63c1bd29057b5ede967ebfafd6ebc  LooseEnds/Views/StartZones.swift
- blob:68c6d514ea48e0529893d60623d237c147c8ba58  Shared/Models/NewDateRule.swift
- blob:ac8edf3ba62f087a4e9c5d8b3e239c7a7d8c7d26  Shared/Models/ViewRules.swift

## Geprüfte Dateien

- sha256:19b93c447061dffbe5c33177d31690e00d0b865e54cc4dfa99ad4c12ff58016d  LooseEnds/App/LooseEndsApp.swift
- sha256:c3eb10139afaa97c32ed589d185e49e8ff5b929458f8487a1271053f26a2db7b  LooseEnds/Views/SidebarView.swift
- sha256:a579a708761102f75f3a62edc9dda22090512d82474b666de6f94bfe4d2b2bdc  LooseEnds/Views/StartPage.swift
- sha256:e90ce7fa1d00c1e45ad63fd0d397e8d51376639fc734e52379afc1afdb8ea0dd  LooseEnds/Views/StartZones.swift
- sha256:d7f0f9a1b2d0fc51ce39f725c200207ab7f8d77a47e2a990e0d7302df10b2600  Shared/Models/NewDateRule.swift
- sha256:17afc2fba7628ae97f441280af2862c46ee455ae2c86e48576934788b758181d  Shared/Models/ViewRules.swift

## Prüfbasis

- base: 96f79e8be9c336d4bd7b17d5f82fde53582e7f4f
- blob:5ab925aa8d8ec6ac637e31eb08b791d7edfed192  LooseEnds/App/LooseEndsApp.swift
- blob:65dc10b72f8b2743d0968eff8a60468ac365219b  LooseEnds/Views/SidebarView.swift
- blob:bdd6e9a22bff0b1a4c41285425be0afa91ba579d  LooseEnds/Views/StartPage.swift
- blob:de4b3fc243a63c1bd29057b5ede967ebfafd6ebc  LooseEnds/Views/StartZones.swift
- blob:68c6d514ea48e0529893d60623d237c147c8ba58  Shared/Models/NewDateRule.swift
- blob:ac8edf3ba62f087a4e9c5d8b3e239c7a7d8c7d26  Shared/Models/ViewRules.swift

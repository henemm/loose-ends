---
entity_id: fix-637-zahl-symbol-jetzt
type: bugfix
created: 2026-10-23
updated: 2026-10-23
status: draft
workflow: fix-637-start-zeigt-badge
---

# Spec: #637 — Die Zahl am Symbol steht in der App, überall gleich

## Approval

- [ ] Approved (Henning)

## Purpose

Heute sagen vier Stellen vier verschiedene Zahlen: das App-Symbol 5, „Fällig“ 4, „Als nächstes“ 2, „Jetzt“ auf der
Startseite 1 (Henning, Mac, 2026-10-23). Vier Aufgaben, deren Frist vorbei ist, stehen auf der Startseite nirgends, obwohl
die Überschrift „Vier Dinge brauchen ein neues Datum.“ sie nennt (#633). Ursache: `ViewRules.now` zieht diese Aufgaben ab
(#518), `ViewRules.badgeCount` zählt sie (#584). Zwei Regeln für dieselbe Frage.

**Vorgabe (Henning, 2026-10-23):** Die Zahl am Symbol muss sich in der App immer als genau eine Zahl wiederfinden, auf
iPhone, iPad und Mac dieselbe, ohne dass jemand addiert. **Entwurf A gewählt** (`docs/artifacts/fix-637-start-zeigt-badge/entwurf.html`):
„Jetzt“ zeigt alle Aufgaben, die das Symbol zählt, die liegengebliebenen unten, ruhig, mit „Neues Datum“ am Rand.

**Rein regelbasiert.** Mengen und Zählen über vorhandene Felder; kein Modell, kein Prompt, kein Schema.

**Abweichung vom Entwurf:** Die Zahl steht in Tinte (grau-schwarz), nicht in Akzentfarbe. Akzent heißt antippbar (Farbbudget),
und die Zahl ist nicht antippbar.

## Source

- **Geändert:** `Shared/Models/ViewRules.swift` — `now` nimmt die Liegengebliebenen ans Ende; `badgeCount` = `now(...).all.count`
- **Geändert:** `LooseEnds/Views/StartZones.swift` — Kopf „Jetzt“ trägt die Zahl
- **Geändert:** `LooseEnds/Views/SidebarView.swift` — „Start“ trägt dieselbe Zahl (iPad, Mac); iPhone: Kopf „Jetzt“ derselbe Block
- **Geändert:** `LooseEnds/Views/StartPage.swift` — Zeilen in „Jetzt“ bieten „Neues Datum“ (öffnet dieselbe Datumswahl)
- **Geändert:** `LooseEnds/App/LooseEndsApp.swift` — Start-Argument `--ui-testing-leftovers` legt Hennings Fall in den In-Memory-Speicher
- **Tests:** `LooseEndsTests/NowRuleTests.swift` (angepasst, neu), `DueTodayTests`, `DueStateTests`, `SubtaskListsTests`,
  `CarryRemindersTests` (Zahlen nachgezogen); neu `LooseEndsUITests/StartNumberTests.swift`
- **Doku:** `docs/project/00-entscheidungen.md` (ADR-16, Nachtrag zu #518 und #584); `CLAUDE.md` (Regel „One number, everywhere“, bereits gesetzt)

## Scope

| Datei | Änderung | Beschreibung |
|---|---|---|
| `Shared/Models/ViewRules.swift` | MODIFY | `NowTasks` bekommt `waiting` (Liegengebliebene ohne Rang); `now` nimmt sie auf; `badgeCount` rechnet aus `now` |
| `LooseEnds/Views/StartZones.swift` | MODIFY | `ZoneCaption` kann eine Zahl tragen; `NowBlock` setzt sie |
| `LooseEnds/Views/SidebarView.swift` | MODIFY | `Start`-Zeile (iPad, Mac) zählt `now`-Anzahl statt 0 |
| `LooseEnds/Views/StartPage.swift` | MODIFY | `nowRow` reicht `onNewDate` weiter |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | Seed unter `--ui-testing-leftovers` |
| Tests, Doku | MODIFY/CREATE | siehe Source |

Geschätzt 5 Quelldateien, ca. +130/−25 LoC, dazu Tests und Doku. **Kein Pfad der Geräteliste berührt.** Keine
Berechtigungen, keine AppStorage-Schlüssel, kein Modellfeld, kein CloudKit-Schema. Der Zähler im Widget „Als nächstes“ bleibt
(eigene, benannte Liste).

## Implementation Details

**Regel (`ViewRules.now`).** Grundmenge = `dueToday` ∪ `tasks(for: .next)` ∪ `leftovers`, jede Aufgabe einmal. Das ist genau die Menge,
die `badgeCount` heute zählt (`tasks(for: .due)` ∪ `tasks(for: .next)`): `.due` besteht aus heute Fälligem und aus den
Liegengebliebenen. Gruppen und Reihenfolge:

1. `today`: Frist heute (noch nicht verstrichen), früheste zuerst — wie bisher.
2. `lined`: die übrigen mit `nextRank`, nach Rang — **auch Liegengebliebene mit Rang** (dein Einreihen gilt).
3. `waiting`: Liegengebliebene ohne Rang, älteste Frist zuerst (`NewDateRule.tasks`-Ordnung).

`all = today + lined + waiting`. Eine Aufgabe, die heute um 09:00 verstrichen ist und bei 10:00 fällig war, ist Liegengebliebenes
(`NewDateRule`), nicht „heute“; sie steht in `lined` oder `waiting`, nicht in `today`.

**Symbol.** `badgeCount(in:now:calendar:)` = `now(in:now:calendar:).all.count`. Keine zweite Rechnung. Morgenmitteilung
(`CarryReminders`) und Symbol (`DueNotificationCenter`) rufen weiter `badgeCount` auf, ändern sich nicht.

**Anzeige.** Über „Jetzt“ steht die Zahl (`all.count`), grau-schwarz, tabellarische Ziffern. Mac und iPad: die Zeile „Start“ in
der Seitenleiste trägt dieselbe Zahl. iPhone: es gibt keine Zeile „Start“, die Zahl steht im Kopf „Jetzt“. Alle Zeilen stehen
unter „Jetzt“ (bestehende Regel: fünf Zeilen, ab der sechsten „N weitere“). Liegengebliebene Zeilen zeigen „Neues Datum“ mit
der Spur („war Di“) am Rand, kein Rot; der Knopf öffnet die Datumswahl, die „Fällig“ schon benutzt (`NewDateSheet`).

**Unverändert:** `dueToday`, `tasks(for:)`, `leftovers`, `StartHeadline`, die Zahlen von „Fällig“ und „Als nächstes“.

## Test Plan

Unit (Swift Testing, `TestStore`, `now` fix Donnerstag 12.03.2026 10:00 Berlin), `NowRuleTests`:
`leftoverWithRankStandsInLined` (Henning: eingereiht gilt), `leftoverWithoutRankStandsLastOldestFirst`,
`unionMatchesTheTwoSources` (jetzt mit Liegengebliebenem in der Menge), `badgeEqualsNowEverywhere` (Eingabemengen:
leer; nur heute; heute + eingereiht; Liegengebliebene mit und ohne Rang; Frist heute verstrichen mit und ohne Uhrzeit;
blockierte, geparkte, erledigte, Teilaufgabe ohne eigenes Datum, Teilaufgabe mit eigenem Datum und verstrichen;
Hennings Fall: Jetzt = Symbol = 5), `carryReminderBadgeEqualsNow`. Bestehende Tests mit alten Zahlen (`NowRuleTests`:
`unionMatchesTheTwoSources` und die Tests zu „left from yesterday“ und „Lined up and left from earlier“; `DueTodayTests.badgeCountsEachTaskOnce`) werden auf die neue Regel gezogen, nicht gelöscht.

UI (`StartNumberTests`, `sim.sh test-proof`, iPhone-Simulator, `--ui-testing-leftovers`): die Startseite zeigt über „Jetzt“ die
Zahl 5, fünf Zeilen, vier mit „Neues Datum“; ein Tipp auf einen der Knöpfe öffnet die Datumswahl; nach dem Setzen eines neuen
Datums für morgen fällt eine nicht eingereihte Aufgabe aus „Jetzt“: Die Zahl über „Jetzt“ sinkt von 5 auf 4, und das Symbol
(`badgeCount`) ist ebenfalls 4.

Mac: Mac-Galerie (CI) fotografiert die Startseite mit `--ui-testing-leftovers`; Seitenleiste „Start 5“ und „Jetzt 5“ stehen
im Bild. iPad: dieselbe Rechenregel, im Unit-Test belegt; kein eigener Durchlauf.

Simulator-Abnahme (Stufe 2): App bauen, installieren, mit `--ui-testing-leftovers` starten, Screenshot ansehen und beschreiben.
Gerät (Stufe 3): entfällt, „Kein Pfad der Geräteliste berührt.“

## Acceptance Criteria

- **AC-1:** `ViewRules.badgeCount(in:)` ist für jede Eingabe gleich `ViewRules.now(in:).all.count`; beide kommen aus derselben
  Funktion (Unit-Test `badgeEqualsNowEverywhere` über alle genannten Eingabemengen, plus Quelltext: `badgeCount` ruft `now`).
- **AC-2:** `now(...).all` enthält jede Aufgabe aus `dueToday`, `tasks(for: .next)` und `leftovers` genau einmal; blockierte,
  geparkte, erledigte und Teilaufgaben ohne eigenes Datum fehlen (Unit-Tests).
- **AC-3:** Reihenfolge: heute Fälliges, dann alle eingereihten nach Rang (Liegengebliebene mit Rang darunter), dann die
  Liegengebliebenen ohne Rang, älteste Frist zuerst (Unit-Tests `leftoverWithRankStandsInLined`,
  `leftoverWithoutRankStandsLastOldestFirst`).
- **AC-4:** Mit Hennings Fall (vier verstrichene Fristen, eine davon eingereiht, dazu eine eingereihte ohne Datum) ergibt die Regel
  5 für Symbol und „Jetzt“, 4 für „Fällig“, 2 für „Als nächstes“ (Unit-Test; Wegwerf-Reproduktion vom 2026-10-23 zeigte vorher 1 und 5).
- **AC-5:** Die Startseite zeigt über „Jetzt“ die Zahl `all.count`, auf iPhone im Kopf, auf iPad und Mac außerdem an der Zeile
  „Start“; alle Zeilen der Menge stehen unter „Jetzt“, die Liegengebliebenen mit „Neues Datum“ und Spur am Rand, ohne Rot
  (UI-Test `StartNumberTests` im iPhone-Simulator; Mac-Galerie-Bild, angesehen).
- **AC-6:** Ein Tipp auf „Neues Datum“ in „Jetzt“ öffnet die Datumswahl; nach dem Setzen steht die Aufgabe nach der Regel am
  richtigen Platz und die Zahl über „Jetzt“ gleicht dem Symbol (UI-Test).
- **AC-7:** `StartHeadline`, die Zählung von „Fällig“ und „Als nächstes“ und `dueToday` liefern für dieselbe Eingabe dieselben
  Ergebnisse wie vorher (bestehende Tests grün); das Widget „Als nächstes“ ist unverändert.
- **AC-8:** ADR-16 trägt den Nachtrag: „Jetzt“ zeigt auch Liegengebliebenes (ändert #518), Symbol und „Jetzt“ sind dieselbe Zahl
  (ergänzt #584), mit Hennings Wortlaut vom 2026-10-23.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `NewDateRule.tasks`, `ViewRules.leftovers` | module | Menge der Liegengebliebenen, unverändert |
| `ViewRules.dueToday`, `tasks(for:)` | module | Quellmengen, unverändert |
| `DueNotificationCenter`, `CarryReminders` | module | rufen `badgeCount`, keine Änderung |
| `NewDateSheet`, `TaskInteractions.datingTask` | view | Datumswahl, wiederverwendet |
| Neue Abhängigkeit | – | keine |

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue — Nachtrag zu ADR-16 (#518: Liegengebliebenes verlässt „Jetzt“; #584: Symbol zählt „Fällig“ plus „Als
  nächstes“). Kippt den Teil von #518, der Liegengebliebenes aus „Jetzt“ ausschließt; behält dessen Kern (es braucht ein neues Datum,
  Abend und Morgen fragen weiter). Alternative B (zugeklappte Zeile) steht im Entwurf (`docs/artifacts/fix-637-start-zeigt-badge/entwurf.html`, Abschnitt „Entwurf B“);
  „Symbol nur auf Jetzt kürzen“ und „eigener Block neben Jetzt“ stehen in `docs/context/fix-637-start-zeigt-badge.md`, Abschnitt „Analysis“. Alle drei verworfen.

## Definition of Done

- [ ] AC-1 bis AC-8 erfüllt; neue und alle bestehenden Unit-Tests grün (Simulator); UI-Test `StartNumberTests` grün mit Simulator-Beleg
  aus `sim.sh test-proof`, Bild angesehen; Mac-Galerie zeigt „Start 5“ und „Jetzt 5“.
- [ ] `CLAUDE.md` trägt die Regel „One number, everywhere“ (bereits gesetzt), ADR-16 nachgezogen.
- [ ] PR mit `Closes #637`, Board gepflegt. Satz „Kein Pfad der Geräteliste berührt.“

## Changelog

- 2026-10-23: Spec nach Henning-Entscheidung (Entwurf A, eine Zahl auf allen Plattformen).

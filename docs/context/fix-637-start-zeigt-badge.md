# Context: fix-637-start-zeigt-badge

## Request Summary
Die Zahl am App-Symbol (5) muss sich in der App als genau eine Zahl wiederfinden (Henning, 2026-10-23). Heute zeigt „Jetzt“ 1 Zeile, „Als nächstes“ 2, „Fällig“ 4, das Symbol 5; vier Aufgaben mit verstrichener Frist stehen auf der Startseite nirgends. Entscheidung: „Jetzt“ zeigt alle Aufgaben, die das Symbol zählt; die Zahl steht über „Jetzt“ und an „Start“ in der Seitenleiste; `badgeCount` und „Jetzt“ kommen aus derselben Regel.

## Related Files
| File | Relevance |
|------|-----------|
| Shared/Models/ViewRules.swift:162 `badgeCount` | Set(.due + .next) – wird zur Zeilenzahl von `now(...)` |
| Shared/Models/ViewRules.swift:179 `now` | schließt `leftovers` aus (#518); muss sie wieder aufnehmen, ans Ende |
| Shared/Models/ViewRules.swift:215 `tasks(for:)` | `.due` (heute + überfällig) und `.next` (Rang, offen, nicht blockiert) = Quelle des Symbols |
| LooseEnds/Views/StartZones.swift:47 `NowBlock`, `ZoneCaption("Now")` | Kopf „Jetzt“ bekommt die Zahl; Fünf-Zeilen-Grenze |
| LooseEnds/Views/StartPage.swift:111, 287 | Mac/iPad-Startseite, `rowIDs` für Tastatur (#480) |
| LooseEnds/Views/SidebarView.swift:75, 92, 122, 135 | `IndexLine` „Start page“ hat `count: 0`; iPhone-Startseite nutzt `NowBlock` |
| LooseEnds/Notifications/DueNotificationCenter.swift:231, Shared/Notifications/CarryReminders.swift:136 | rufen `badgeCount` auf (Symbol, Morgenmitteilung) |
| Shared/Models/StartHeadline.swift:78 | Überschrift „braucht ein neues Datum“ (#633), unverändert |
| Shared/Models/NewDateRule.swift | `tasks(in:)` = liegengebliebene Aufgaben, Marke „Neues Datum“ in `TaskRow` |
| LooseEndsTests: NowRuleTests (36, 64, 170, 189), DueTodayTests (58), SubtaskListsTests (48), CarryRemindersTests (242), DueStateTests (92) | pinnen heutiges Verhalten, Zahlen zum Teil neu |
| docs/project/00-entscheidungen.md ADR-16 (Zeilen 178–205) | #518, #550, #551, #584: Nachtrag nötig |

## Existing Patterns
- „Jetzt“ = fällig heute + Als nächstes, je Aufgabe einmal; heute-fällige zuerst, danach nach Rang.
- Symbol (#584) zählt „Fällig“ + „Als nächstes“ ohne Doppelte; ändert sich nur bei Bearbeitung/Tageswechsel.
- Zeile mit `MarginMark.passed` zeigt „Neues Datum“ und die Spur („war Di“) schon in Listen; `TaskRow` kennt es.

## Dependencies
- Upstream: `NewDateRule`, `ViewRules.tasks(for:)`, `dueToday`.
- Downstream: Symbol, Morgenmitteilung, iPhone/iPad/Mac-Startseite, Mac-Tasten in „Jetzt“ (`rowIDs`).

## Existing Specs
- docs/specs/feat-368-startseite-drei-zonen.md, feat-368-schnitt-1-regel-jetzt.md, feat-548-neues-datum.md, feat-414-offen-am-tagesende.md, feat-480-schnitt-2-startseite.md

## Risks & Considerations
- Kippt #518 für „Jetzt“: Die Startseite ist wieder voller. Mildern: Liegengebliebene ganz unten, ruhig (kein Rot).
- Unterschied heute: `now` nimmt nur heute Fälliges (`dueToday`), `badgeCount` alles Überfällige. Gleichheit muss ein Test über alle Fälle pinnen (eingereiht, blockiert, Teilaufgabe mit/ohne Datum, Frist heute verstrichen).
- Zahl über „Jetzt“ darf nicht auf iPhone doppelt zum Zahlzeichen der Seitenleistenzeile werden; „Start“ auf Mac/iPad trägt sie neu (bisher 0).
- Kein Pfad der Geräteliste (kein Modell, kein Persistence, keine Intents); Abnahme endet nach Simulator.

## Analysis

### Type
Bug (Anzeige widerspricht sich): Zahl am Symbol ≠ Zeilen unter „Jetzt“.

### Reproduktion (2026-10-23)
Wegwerf-Test im iOS-Simulator (`sim.sh sim-unit`, danach gelöscht) mit Hennings Daten: vier Aufgaben mit Frist gestern bis vor vier Tagen, eine davon in „Als nächstes“ eingereiht, dazu eine eingereihte ohne Datum. Ergebnis: `now.all` = 1, `badgeCount` = 5, `.due` = 4, `.next` = 2, genau Hennings Screenshot. Der bestehende Test `NowRuleTests.unionMatchesTheTwoSources` hält dieselbe Abweichung als gewollt fest (3 gegen 4).

### Ursache
`ViewRules.now` (ViewRules.swift:179) zieht `leftovers` ab (#518), `badgeCount` (:162) nicht (#584). Zwei Regeln für „was heute von dir etwas will“. Die Startseite hat sonst keinen Platz für die Liegengebliebenen, obwohl die Überschrift (#633) sie zählt.

### Alternativen (Entwürfe: docs/artifacts/fix-637-start-zeigt-badge/entwurf.html)
- A (empfohlen): alle fünf Zeilen in „Jetzt“, Liegengebliebene unten, Zahl über „Jetzt“ und an „Start“.
- B: Liegengebliebene als eine zugeklappte Zeile in „Jetzt“, Zahl wie in A.
- Verworfen: Symbol nur auf „Jetzt“ kürzen (macht #584 rückgängig, Symbol sagt weniger als „Fällig“); eigener Block neben „Jetzt“ (Zahl müsste addiert werden, gegen Hennings Vorgabe 2026-10-23).
- Ohne Modell, reine Regel. Keine ADR gekippt außer dem Teil von ADR-16/#518, der Liegengebliebenes aus „Jetzt“ ausschließt.

### Affected Files
| File | Change | Description |
|------|--------|-------------|
| Shared/Models/ViewRules.swift | MODIFY | `now` nimmt Liegengebliebene ans Ende; `badgeCount` = `now(...).all.count` |
| LooseEnds/Views/StartZones.swift | MODIFY | Kopf „Jetzt“ trägt die Zahl |
| LooseEnds/Views/SidebarView.swift | MODIFY | „Start“ trägt dieselbe Zahl (Mac/iPad `IndexLine`, iPhone Kopf) |
| LooseEndsTests/NowRuleTests.swift u. a. | MODIFY | bestehende Zahlen neu, Gleichheit Symbol = Jetzt in allen Fällen |
| docs/project/00-entscheidungen.md | MODIFY | ADR-16 Nachtrag |

### Scope Assessment
- Files: 5 (plus Tests: NowRuleTests, ggf. DueTodayTests, SubtaskListsTests, CarryRemindersTests)
- Estimated LoC: +70/-20
- Risk Level: MEDIUM (zentrale Regel, die Symbol, Morgenmitteilung und Startseite teilen)

### Open Questions
- [x] Entwurf A gewählt (Henning, 2026-10-23)
- [ ] Sortierung der Liegengebliebenen am Ende: älteste zuerst (wie `NewDateRule.tasks`)?

## Vorgabe Henning (2026-10-23): die 5 ist auf allen Plattformen gleich
Eine Quelle (`ViewRules.now(...).all.count`) für: App-Symbol (iPhone, iPad, Mac), Morgenmitteilung (`CarryReminders.badge`), Zahl über „Jetzt“ (iPhone, iPad, Mac), Zahl an „Start“ (Seitenleiste iPad/Mac; iPhone: im Kopf „Jetzt“). Kein Ort rechnet die Zahl selbst. Die Watch und die Widgets zeigen sie heute nicht; das Widget „Als nächstes“ zeigt die Liste „Als nächstes“ unter diesem Namen und bleibt (eigene Zahl, benannt). Ein Test pro Plattform-Pfad belegt Gleichheit; Simulator-Durchlauf auf iPhone und Mac-Galerie in der CI.

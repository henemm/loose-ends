# Context: fix-443-faellig-wiederkehrend

## Request Summary
#443: „Wiederkehrende Aufgaben erscheinen unter fällig, obwohl sie noch nicht fällig sind." Zwei Screenshots (Henning):
Liste „Fällig" zeigt „Fußnagel behandeln" (wöchentlich, fällig Mo 19.10.2026 19:00) und eine zweite Aufgabe mit „Mo".

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Models/ViewRules.swift:202` | `.due`: seit #455 (PR gemergt 2026-10-15 22:43 +0200) nur `dueDate < Ende heute` und nicht blockiert; vorher 7 Tage Vorlauf |
| `Shared/Services/TaskActions.swift:12` | `complete` bei Wiederholung: `CompletionRecord`, `dueDate = rule.nextDueDate(...)`, Aufgabe bleibt offen |
| `Shared/Models/RepeatRule.swift` | `nextDueDate(previousDue:completedOn:)` — setzt das nächste Datum |
| `LooseEnds/Views/TaskListView.swift:110` | Leertext „Nothing due today." |
| `LooseEnds/Views/SidebarView.swift:51,102` | Zeile `viewRow_due`, Zähler aus `ViewRules.tasks(for:)` |
| `Shared/Models/ViewRules.swift:74-82,152,169` | `dueToday`/`badgeCount`/`NowTasks` (Startseite, andere Regel, nicht Gegenstand) |
| `LooseEndsUITests/CaptureSmokeTests.swift:472-` | vorhandener Ablauf „Wiederholung setzen, abschließen" als Vorlage |
| `LooseEndsUITests/StartScreenInteractionTests.swift` | Hilfen `launch`/`element`/`firstElement` |

## Befund bisher (noch keine Nachstellung)
- Bildschirmzeit 14:43/14:44, Datum nicht sichtbar. „Mo" und 19. Okt. sind mit dem 7-Tage-Vorlauf aus der Zeit vor #455 erklärbar.
- Fälligkeit Mo 19.10. 19:00 bei Erfassung „Morgen …" ergibt sich aus Wiederholung: Erfassung So 11.10. → Mo 12.10., nach Erledigen um eine Woche vorgerollt.
- Alle TestFlight-Läufe vom 2026-10-16 (06:01, 07:56, 08:27 UTC) liegen nach dem Merge von #455.
- Hypothese (UNBEWIESEN): #443 ist durch #455 behoben. Gegenhypothese: ein eigener Wiederholungs-Pfad setzt das Datum zu früh.
- Bestehender Test `DueTodayTests` deckt „morgen nicht in Fällig" auf Modellebene ab, aber nicht den Ablauf mit Wiederholung im Simulator.

## Risks & Considerations
- Nachstellung geht nur über einen UI-Test im Simulator (Edit-Gate erlaubt Codeänderungen erst ab Phase 6; der RED-Test entsteht in `/40-tdd-red` und ist zugleich die Nachstellung auf dem aktuellen Stand). Wird er sofort grün, ist #443 durch #455 erledigt: Abbruch mit Beleg, kein Fix.
- Kein Pfad der Geräteliste berührt.

## Analysis

### Type
Bug (Verdacht: bereits durch #455 behoben, Beleg steht aus)

### Hat es bisher funktioniert?
Ja: Bis #455 (2026-10-15) war der 7-Tage-Vorlauf Absicht; „Fällig" zeigte alles bis Ende der nächsten 7 Tage. Henning hat das am 2026-10-15 als Fehler benannt, #455 hat es auf „heute und überfällig" geändert (`ViewRules.swift:202`, im Stand dieses Zweigs enthalten). Beide Screenshots zeigen ein Datum 19.10./„Mo" und sind damit mit dem alten Vorlauf vollständig erklärbar.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsUITests/…` (neue oder bestehende Klasse) | CREATE/MODIFY | UI-Test: wöchentliche Aufgabe anlegen, abschließen, Ansicht „Fällig" ist leer, „Wiederholend" zeigt sie |
| `Shared/Models/ViewRules.swift` | KEIN Change erwartet | nur falls der Test rot wird |
| `Shared/Services/TaskActions.swift` / `RepeatRule.swift` | KEIN Change erwartet | nur falls das Datum nach Abschluss zu früh gesetzt wird |

### Scope Assessment
- Files: 1 (Test), im Fehlerfall +1–2
- Estimated LoC: +60 / −0 (Test); Fix, falls nötig, <30
- Risk Level: LOW

### Technical Approach
1. Reproduktion zuerst, auf Hennings Weg: UI-Test im Simulator mit dem aktuellen Stand (Ablauf nach `CaptureSmokeTests.swift:472`: Wiederholung setzen, abschließen, Ansicht „Fällig" öffnen). Der Test ist der RED/GREEN-Schalter.
2. Wird er sofort grün: #443 ist durch #455 erledigt. Der Test bleibt als Regressionsschutz (er prüft den Ablauf mit Wiederholung, den `DueTodayTests` nur auf Modellebene abdecken); Ticket mit Beleg schließen, kein Produktcode.
3. Wird er rot: Ursache im Wiederholungs-Pfad (`nextDueDate`) belegen, dann gezielt beheben.

Ohne-Modell-Hinweis: reine Regel (Datumsvergleich), kein Modell beteiligt.

### Alternative
Nur schließen, ohne eigenen Test (Beleg: Modelltest `DueTodayTests` + Datumsvergleich). Verworfen: Der Ablauf mit Wiederholung im echten Lauf ist nirgends geprüft; genau diese Lücke ließ Fehler früher durch ([[feedback-use-the-app-not-just-build-it]]). Kein ADR wird gekippt.

### Dependencies
`ViewRules.tasks(for: .due)` speist Seitenleiste (`SidebarView`) und Liste (`TaskListView`); `dueToday`/`NowTasks` (Startseite) haben eigene Regeln und bleiben unberührt.

### Open Questions
- [ ] Keine für Henning. Gerätestufe: „Kein Pfad der Geräteliste berührt."

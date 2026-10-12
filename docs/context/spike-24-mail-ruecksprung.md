# Context: Spike #24 — Mail-Rücksprung über die Teilen-Erweiterung

## Request Summary
Klären, ob Apple Mail beim Teilen zuverlässig eine verwendbare `message:`-URL liefert, mit der eine
Aufgabe später zur Quell-Mail zurückspringen kann; Ergebnis und Fallback in die Doku, `04-stand.md` nachziehen.

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Services/SharedContent.swift` | Pure Logik: aus `.eml`-Text (Betreff, `Message-ID`) wird `message://%3C…%3E`; Vorrang: Mail > `message:`-Link > URL > Text |
| `LooseEndsShare/ShareViewController.swift` | Liest `public.email-message`, `public.url`, `public.plain-text` je Anhang; loggt nur Fehler, nicht, welche Typen Mail tatsächlich liefert |
| `LooseEndsShare/ShareCaptureView.swift` | Speichert über `CaptureService.save(..., sourceURL:)` mit Kanal `.mail` |
| `LooseEndsShare/Info.plist`, `project.yml:176` | Aktivierungsregel: Text, URL oder `public.email-message` |
| `LooseEnds/Views/TaskDetailView.swift:189` | Abschnitt „Source“, `Link("Open the source")`; kein Ausblenden, wenn die Mail fehlt |
| `LooseEndsTests/SharedContentTests.swift` | Unit-Tests der Kopfzeilen-Logik mit Beispielmail (kein echter Mail-Export) |
| `docs/project/02-datenmodell-und-ansichten.md:26,318` | Feld `sourceURL`, offene Frage 5 |
| `docs/project/04-stand.md:56` | Spike-Liste, Punkt 2 |
| `docs/project/00-entscheidungen.md:134` | ADR-9: Mail über App-Schema plus Share-Extension, speichert `message:`-URL |
| `docs/project/01-user-story.md:58,92,104` | Rücksprung ist Must; Akzeptanz „mit einem Tipp zurück zur Mail“ |

## Existing Patterns
- Rohmail wird als RFC 822 gelesen; die URL entsteht aus `Message-ID` (Klammern prozent-kodiert).
- Ein von Mail mitgelieferter `message:`-Link hat Vorrang vor der selbst gebauten.
- Siri-Weg (#25, `Shared/Services/SiriFields.swift`) setzt `sourceURL` aus der Übergabe des Systems.

## Recherche (2026-10-08)
- iOS Mail hat seit Jahren **keinen Teilen-Knopf für eine ganze Mail**. Umwege: Drucken → Teilen (PDF), markierter Text. Beides ohne Message-ID.
  Quellen: DEVONtechnologies-Forum (iOS 10), MPU Talk „Missing Share to icon in iPadOS/iOS mail“, Medium „Apple Mail's Missing Piece“.
- Öffnen von `message:`-URLs auf iOS ist verlässlich, wenn die Mail im Postfach liegt; sonst lädt Mail nach. Am Mac erscheint stattdessen ein Fehlerdialog. Quelle: NSHipster „Message-ID and Mail.app Deep Linking“.
- Nicht belegt für iOS 26/27: ob Mail inzwischen `public.email-message` oder eine URL an Teilen-Erweiterungen gibt. Das lässt sich nur auf dem Gerät zeigen.

## Dependencies
- Upstream: Mail (liefert, was sie liefert), `NSExtensionItem`/`NSItemProvider`, `Message-ID`-Kopfzeile.
- Downstream: `TaskItem.sourceURL`, Detailansicht „Source“, Abzeichen „Aus Mail“ (`03-design-briefing.md:156`), #25 (Siri-Reminders).

## Existing Specs
Keine für die Teilen-Erweiterung unter `docs/specs/` mit Mail-Bezug gesichtet; Design-Vorgabe in `03-design-briefing.md:50,94`.

## Risks & Considerations
- **Gerätegrenze:** Der Simulator hat kein eingerichtetes Mail-Konto mit echten Teilen-Daten; belastbar ist nur Hennings iPhone. Nach seiner Regel (2026-10-08) läuft nichts auf dem Gerät, bevor er wörtlich „jetzt ist ein Test möglich“ schreibt. Gerätelauf per AskUserQuestion anfragen, mit Dauer und Ablauf.
- Die Teilen-Erweiterung gehört zur Geräteliste (`LooseEndsShare/`), falls Code angefasst wird → Stufe 3 Pflicht.
- Ein reiner Doku-Nachtrag berührt keinen Pfad der Geräteliste; der Messlauf selbst bleibt trotzdem geräteabhängig.
- Der Link „Open the source“ zeigt auch bei toter Mail immer an; Fallback-Entscheidung gehört in die Spec.
- Alternativen (Pflicht laut CLAUDE.md) für die Analyse: Mail am Mac per Skript-Link, Siri-Übergabe (#25), Weiterleitung an eigene Adresse, Aufgabe ohne Rücksprung (Betreff und Absender als Text).

## Analysis

### Type
Spike (Feature-Klärung, keine Fehlerbehebung). Kein „hat es bisher funktioniert?“: Der Weg wurde noch nie auf dem Gerät belegt, nur mit einer Beispielmail in `SharedContentTests`.

### Befund (Recherche 2026-10-08, Quellen siehe oben)
- iOS Mail bietet für eine ganze Nachricht keinen Teilen-Knopf; Mail-Inhalte sind für Erweiterungen nicht freigegeben (MacStories „iOS 8, Email, and Extensions“, OmniGroup-Forum „Saving iOS mail as a task“). `public.email-message` kommt in der Praxis nie an, der Zweig in `ShareViewController` ist vermutlich toter Code.
- Teilen von markiertem Text liefert Text, keine Message-ID. Reminders zeigt zwar Quelle und Rücksprung, dafür gibt es keine öffentliche Schnittstelle (Apple-Forum 705696, ohne Antwort).
- Was dokumentiert funktioniert: Mail per Drag & Drop in eine App ziehen (OmniFocus iPad/iPhone) liefert Betreff und Rücksprung-Link.
- `message:`-URLs öffnen auf iOS verlässlich, wenn die Mail im Postfach liegt (NSHipster). Gelöschte Mail / entferntes Konto: nicht belegt.
- Im Code gibt es weder `onDrop`/`dropDestination` noch `NSUserActivity`: Drag & Drop und Siri-Bildschirminhalt sind nicht vorbereitet.
- Nicht belegt für iOS 26/27: ob Mail inzwischen etwas an Teilen-Erweiterungen gibt. Nur Messung auf dem Gerät klärt das.

### Ohne Modell
Reiner Regel- und Messweg; kein Sprachmodell beteiligt. Die Message-ID-Auswertung (`SharedContent.messageURL`) ist Regel und bleibt.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsShare/ShareViewController.swift` | MODIFY | Messpunkt: je Teilen-Vorgang Typkennungen der Anhänge ins Log (`Logger`), nur für den Spike |
| `LooseEndsTests/SharedContentTests.swift` | MODIFY | Test für Mail-Fallback-Verhalten |
| `LooseEnds/Views/TaskDetailView.swift` | MODIFY (nur falls Fallback sichtbar wird) | Abschnitt „Source“: Betreff als Text, Link-Beschriftung |
| `docs/project/02-datenmodell-und-ansichten.md` | MODIFY | Frage 5 beantworten |
| `docs/project/04-stand.md` | MODIFY | Spike-Liste |
| `docs/reference/` (neuer Bericht) | CREATE | Messergebnis je Konto |

### Scope Assessment
- Files: 4–6, ca. +60/-10 LoC Code, Rest Doku
- Risk Level: LOW im Code, MITTEL im Ablauf (Gerätelauf nötig, `LooseEndsShare/` steht auf der Geräteliste → Stufe 3 Pflicht)

### Technical Approach
Messen vor Entscheiden, in drei Teilen:
1. Messpunkt im Share-Extension-Code, der protokolliert, welche Typen Mail tatsächlich liefert (markierter Text, Drucken→Teilen, ggf. Mail-Link). Über „LE Prüfbau“ (eigene Kennung, nie Hennings Installation).
2. Rücksprung prüfen: gespeicherte `message:`-URL öffnen; Randfälle gelöschte Mail, entferntes Konto.
3. Ergebnis und Fallback dokumentieren.

Empfehlung für den Fallback (vorbehaltlich Messung): Betreff und Absender immer als Text in der Aufgabe behalten; der Link „Open the source“ bleibt nur, wenn `sourceURL` gesetzt ist, und heißt dann „In Mail öffnen“. Kein Ausblenden nach Verdacht, weil die App nicht wissen kann, ob die Mail noch existiert.

### Alternativen (zu der bisherigen Festlegung ADR-9 „Share-Extension speichert message:-URL“)
| Alternative | Kippt welche Entscheidung | Einschätzung |
|---|---|---|
| A. Drag & Drop einer Mail in die App (iPad/Mac, iPhone mit zwei Händen) | ADR-9: Share nicht mehr der Hauptweg | Belegt bei Wettbewerbern; Mail liefert Link und Betreff. Eigener Aufwand (Drop-Ziel) |
| B. Siri-Weg über #25: Bildschirminhalt von Mail als Quelle | ADR-9 Teil „App-Schema“ wird Hauptweg | Passt zum Hennings Wunsch „Siri auf einer Mail“; hängt an #25 |
| C. Mail an eigene Adresse weiterleiten / Kontakt per Mac-Skript | Rücksprung als Muss (User-Story) | Aufwendig, schwach |
| D. Kein Rücksprung, nur Betreff + Absender als Text | Entscheidung #6 „Rücksprung: ja“ | Einfachster Weg, wenn A und B nichts liefern; Muss wird zum Kann |

Nulllinie: Heute gespeichert wird nur der Betreff als Titelvorschlag. Variante D ist also schon vorhanden und bleibt der Boden.

### Dependencies
`SharedContent`, `CaptureService.save(sourceURL:)`, `TaskDetailView` Abschnitt „Source“, #25 (Siri), #226/Schema unberührt (kein Modellfeld neu).

### Open Questions
- [ ] Gerätelauf: Freigabe von Henning wörtlich „jetzt ist ein Test möglich“, mit Ablauf (Prüfbau, 3–4 Mails aus mindestens zwei Konten teilen, Rücksprung antippen, ca. 15 Min.). Noch nicht gefragt, wird nach der Spec per AskUserQuestion erbeten.
- [ ] Soll Alternative A (Drop-Ziel) in diesen Spike oder in ein eigenes Ticket? Empfehlung: eigenes Ticket, falls die Messung Teilen als unbrauchbar zeigt.

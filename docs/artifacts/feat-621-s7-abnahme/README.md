# #621 S7 — Abnahme: die vier Ansichten liefern dasselbe wie die App

DoD-Punkt aus #621: „In claude.ai als eigener Connector verbunden; die vier Ansichten liefern dasselbe wie die App für
denselben Datenstand.“ Der erste Teil ist seit S6b belegt (`docs/artifacts/feat-621-s6b-betrieb/`). Hier der zweite.

## Datenstand

Nach Hennings Anmeldung im TestFlight-Bau 1.0.2 (#615, bestätigt 2026-11-15) hat die App ihre erste Abschrift
geschickt. Live auf `rennwienix` nur gelesen, 2026-11-15:

- 1 Abschrift, `generatedAt` 2026-11-15T08:40:58Z, empfangen 08:41:10Z, Vertrag Version 1
- Schlüssel `now`, `nowCount`, `tasks`, `views`, `version`, `generatedAt`; 29 Aufgaben
- `views`: due 2, next 0, open 16; `nowCount` 2

## Warum die Abschrift „die App“ ist

Die App rechnet die Abschrift mit denselben Funktionen wie ihre Bildschirme, nichts wird nachgebaut:

- `Shared/Services/TranscriptCodec.swift`: `now` und `nowCount` aus `ViewRules.now`, `views` aus
  `ViewRules.tasks(for: .due/.next/.open)`
- Bildschirme: `LooseEnds/Views/StartZones.swift` und `StartPage.swift` (`ViewRules.now`),
  `TaskListView.swift` und `SidebarView.swift` (`ViewRules.tasks(for:)`)

Der Dienst rechnet ebenfalls nichts nach (`server/src/mcp.ts`, `nowRows`/`viewRows`): er gibt die Listen der App in
ihrer Reihenfolge zurück und ergänzt nur die Zeileninhalte aus `tasks`.

## Live-Prüfung

`check-views.mjs` lief im Container `loose-ends-server` (Stand `63de3cc`) gegen die Live-Datenbank: der echte
`mcpHandler` des Dienstes, Werkzeugaufrufe per JSON-RPC wie von claude.ai, das Konto in `authInfo` wie nach der
OAuth-Prüfung. Nur lesende Werkzeuge (`get_now`, `get_view`), Ausgabe nur Zahlen und Wahrheitswerte, keine Titel oder
Kennungen. Das Skript wurde danach aus Container und Server entfernt.

| Ansicht | Liste der App | Werkzeug | Reihenfolge gleich | fehlende Aufgaben |
|---|---|---|---|---|
| Jetzt (`now`) | 2 Zeilen, Zahl 2 | `get_view` 2, `get_now` 2, `nowCount` 2 | ja | – |
| Fällig (`due`) | 2 | 2 | ja | 0 |
| Als nächstes (`next`) | 0 | 0 | ja | 0 |
| Lose Enden (`open`) | 16 | 16 | ja | 0 |

`generatedAt` der Werkzeugantworten = `generatedAt` der Abschrift. Rohausgabe:

```json
{"generatedAt":"2026-11-15T08:40:58Z","tasks":29,"nowCountApp":2,
 "now":{"appRows":2,"getNowRows":2,"getViewRows":2,"nowCountTool":2,"sameOrder":true,"sameGeneratedAt":true},
 "due":{"appRows":2,"getViewRows":2,"missingInTasks":0,"sameOrder":true},
 "next":{"appRows":0,"getViewRows":0,"missingInTasks":0,"sameOrder":true},
 "open":{"appRows":16,"getViewRows":16,"missingInTasks":0,"sameOrder":true}}
```

## Ergebnis

Alle vier Ansichten liefern für denselben Datenstand dieselben Aufgaben in derselben Reihenfolge wie die App; die Zahl
über „Jetzt“ ist dieselbe. DoD von #621 erfüllt.

Grenze: „Als nächstes“ war im Datenstand leer, die Reihenfolge dort ist nur durch die Servertests
(`server/test/mcp-read.test.ts`) belegt, nicht live.

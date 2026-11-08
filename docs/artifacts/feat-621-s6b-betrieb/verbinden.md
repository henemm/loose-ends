# claude.ai verbindet sich echt mit Hennings Apple-Konto (AC-12, AC-15)

## Ablauf

- nginx geladen (Öffnung): 2026-11-08T13:22:38Z
- Henning bekam die Schritte direkt danach (Einstellungen → Connectors → „Add custom connector“, Name `Loose Ends`,
  URL `https://loose-ends.henemm.com/mcp`, Verbinden, Apple-Anmeldung, „Zugriff erlauben“).
- Hennings Rückmeldung (AskUserQuestion, wörtlich): **„Verbunden“**
- Browser: **Safari** (nicht von Henning genannt, sondern aus der Zugriffszeile des Apple-Rückwegs:
  `Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.0.1 Safari/605.1.15`).
  **Nur Safari geprüft**, Chrome nicht. Damit ist der in der Spec als Risiko geführte Safari-`form_post`-Rückweg belegt.

## Zugriffszeilen (nginx access.log, Query-Werte entfernt, Interaction-Kennungen als `<uid>`)

Das Zugriffsprotokoll ist für alle Hosts gemeinsam und führt keinen Hostnamen. Die Zeilen `/oauth/*` und die
`/.well-known/oauth-*` gehören nur zu loose-ends (kein anderer Host hat diese Pfade offen); `POST /mcp` mit
`Claude-User` gibt es auch auf `mcp.henemm.com` (Obsidian-Konnektor), die Zeilen 13:25–13:28 sind von dort (vor dem
ersten Token von loose-ends). Belegt für loose-ends sind die `/mcp`-Zeilen ab 13:29:06 über den Zähler des Dienstes
(siehe get_now.md).

    13:28:40 POST /mcp 401                                   python-httpx (claude.ai, ohne Token)
    13:28:41 GET  /.well-known/oauth-protected-resource/mcp 200   python-httpx
    13:28:41 GET  /.well-known/oauth-authorization-server 200     python-httpx
    13:28:50 POST /mcp 401                                   python-httpx
    13:28:50 GET  /.well-known/oauth-protected-resource/mcp 200   python-httpx
    13:28:50 GET  /.well-known/oauth-authorization-server 200     python-httpx
    13:28:51 GET  /oauth/auth 303                            Safari
    13:28:51 GET  /oauth/interaction/<uid> 303               Safari  (→ Apple)
    13:29:02 GET  /oauth/interaction/<uid> 400               Safari  (siehe Auffälligkeit)
    13:29:02 POST /oauth/apple/return 303                    Safari  (form_post von Apple)
    13:29:02 GET  /oauth/interaction/<uid>/finish 303        Safari
    13:29:02 GET  /oauth/auth/<uid> 303                      Safari
    13:29:02 GET  /oauth/interaction/<uid> 200               Safari  (Zustimmungsseite)
    13:29:05 POST /oauth/interaction/<uid>/confirm 303       Safari  („Zugriff erlauben“)
    13:29:05 GET  /oauth/auth/<uid> 303                      Safari  (→ claude.ai Callback)
    13:29:06 POST /oauth/token 200                           python-httpx
    13:29:06 POST /mcp 200                                   Claude-User
    13:29:07 POST /mcp 200                                   Claude-User
    13:29:10 POST /mcp 200 (2x)                              Claude-User

Kein 5xx im ganzen Ablauf.

**Auffälligkeit:** 13:29:02 `GET /oauth/interaction/<uid>` → 400, unmittelbar vor dem `POST /oauth/apple/return`. Eine
zweite Anfrage auf den Hinweg (Prompt `login`) nach dem Hinweg wird mit dem festen 400 abgewiesen (kein zweites
Speichern von `state`). Der Ablauf lief trotzdem durch; vermutlich ein Neuladen/Vorabruf durch Safari beim Wechsel
von Apple zurück. Kein Fehler für Henning sichtbar („Verbunden“). Beobachten; kein eigener Schnitt nötig, solange
das Verbinden gelingt.

## Ergänzung nach der Tür (AC-15)

Nach dem Neustart mit `ALLOWED_APPLE_SUBS` (13:29:54Z) rief Henning in claude.ai `get_now` auf; Antwort ohne Fehler
(get_now.md). Seine Kennung steht in der Liste, er ist nicht ausgesperrt: das Token aus dem Verbinden gilt weiter,
`/mcp` antwortet 200, der Dienst zählt nach dem Neustart Anfragen mit Fehlerquote 0.

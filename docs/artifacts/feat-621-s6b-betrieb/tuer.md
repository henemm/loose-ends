# Tür nach dem ersten Verbinden (AC-14, AC-15, AC-16)

## AC-14: genau ein Konto

- nginx-Reload (Öffnung): 2026-11-08T13:22:38Z
- `created_at` des Kontos: 2026-11-08T13:29:02Z
- Fenster der Tür (Öffnung bis Konto): **6,4 Minuten**; bis zur gesetzten Liste (13:29:49Z) 7,2 Minuten,
  bis zum Neustart mit Liste (13:29:54Z) 7,3 Minuten
- `SELECT count(*) FROM accounts` um 13:29:31Z: **1**

## AC-15: Liste gesetzt, Dienst neu, nichts ausgesperrt

- Hennings `sub` direkt aus der Datenbank in `secrets/server.env` geschrieben (Skript auf dem Server, nur nach
  `accounts` = 1, nie ausgegeben, nicht in diesem Beleg, nicht im Protokoll)
- `ALLOWED_APPLE_SUBS`: **gesetzt, ein Eintrag** (13:29:49Z)
- Neustart nur über `scripts/deploy-loose-ends.sh`: Exit 0, `/health 200`, Container gestartet 13:29:54Z
- Startlauf des Dienstes: `listening`, `migrated`; Zeilen mit `allowed subs invalid` oder `account refused`: **0**;
  die `sub` steht nicht im Log
- `accounts` danach: **1** (13:30 UTC und erneut nach allen Läufen)
- `check-outside.sh` danach wieder grün (green.txt, 13:32:17Z)
- Henning nicht ausgesperrt: `get_now` nach dem Neustart ohne Fehler (get_now.md, verbinden.md)

## AC-16: fremde Anmeldung

Ein Live-Test der Abweisung ist ohne zweites Apple-Konto **nicht prüfbar**. Die Regel ist durch die Tests von S6a mit
echter Datenbank und Fake-Apple belegt: `server/test/oauth-return.test.ts` („rueckweg: fremde sub ergibt
access_denied ohne konto und ohne token“) und `server/test/auth.test.ts`, CI grün auf `main` (`ae957ba`, PR #873).
Live prüfbar und geprüft: nach dem Neustart keine Zeile `account refused` für Hennings eigene Nutzung, `accounts` = 1.

## Nebenbefund: fail2ban sperrt bei 429 alle Hosts

Die Jail `nginx-limit-req` (maxretry 10 in 600 s, Sperre 3600 s) sperrt jede Adresse, die die Limit-Zonen mehr als
zehnmal trifft, für eine Stunde auf 80/443. Beim Test von AC-9 traf das den Prüfanschluss (sofort aufgehoben, grenzen.txt).
Für claude.ai hieße das: läuft ein Agent einmal in die Zone `loose_ends_mcp`, ist der Connector eine Stunde lang still
tot. Eigenes Ticket im Infra-Repo (Anthropic-Bereich `160.79.104.0/21` in `ignoreip` oder Zonen anheben), nicht Teil
dieses Schnitts.

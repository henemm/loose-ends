# AC-11: Konto löschen, echt nur lokal (#615 S4d)

Der Live-Dienst wurde nie mit einer gültigen Sitzung an `/auth/delete` aufgerufen; im Netz gilt nur `loeschen-live.txt`.

## Dienst-Ebene (echt), 2026-11-10 16:33Z

Befehl: `bash loeschen-lokal.sh <worktree>/server` (Skript liegt hier im Ordner). Aufbau wie `server/scripts/test-local.sh`:
Postgres 18.6 Wegwerf (eigener Datenordner, freier Port, nur `127.0.0.1`, kein Unix-Socket), Dienst per `npm start` mit
`DATABASE_URL`, `PORT`, `HOST=127.0.0.1` und sonst leerer Umgebung (kein `APPLE_*`, kein `OAUTH_*`: `/auth/delete` läuft ohne
Apple-Konfiguration, der Widerruf bei Apple wird übersprungen). Konto und Sitzung per `findOrCreate` + `createSession`
aus `server/src/accounts.ts`. Alles wird beim Ende entfernt.

```
Postgres 18 Wegwerf auf 127.0.0.1:50044, postgres (PostgreSQL) 18.6 (Homebrew)
Dienst auf 127.0.0.1:50045, /health 200
Vorher accounts/sessions für das Konto: 1 1
1. POST /auth/delete mit Bearer: 204
Nachher accounts/sessions für das Konto: 0 0
2. POST /auth/delete mit demselben Bearer: 401
Dienst-Log: listening / migrated / apple revoke skipped
Exit 0
```

## App-Seite (Simulator, Stellvertreter-Transport)

`./scripts/sim.sh test-proof AccountSettingsTests`, 2026-11-10 17:34–17:38 (MEZ), iPhone 17, iOS 27.2: 8 von 8 grün, darunter
`testDeleteCancelKeepsSignedIn` und `testDeleteConfirmSignsOut`; maschineller Beleg `simulator-run.txt`.
Screenshot `loeschen-dialog.png`: Einstellungen, Gruppe „Claude“, Bestätigung „Delete account?“ mit dem Text „Claude will no
longer see your tasks. Your tasks in the app stay as they are.“ und dem roten Knopf „Delete account“.

## Befund

Das echte Löschen ist auf Dienst-Ebene belegt: 204, Konto- und Sitzungszeile weg, dieselbe Sitzung danach 401.
Der Simulator stellt **keine echte Apple-Anmeldung** her: die App-Seite belegt Bestätigung und Abmelden mit dem
Stellvertreter-Transport aus 4c-1, nicht den Weg über das Netz. Die Anmeldung mit echtem Apple-Konto belegt erst der
Gerätelauf über TestFlight (Definition of Done).

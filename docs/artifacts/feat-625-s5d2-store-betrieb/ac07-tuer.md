# AC-7 Tür des Dienstes öffnen (`rennwienix`)

Zeit: 2026-11-24T22:08:37+01:00

Liegt nach AC-6 (21:56 Uhr MEZ) und vor AC-8. Grundlage: PO-Entscheidung 2026-11-22 (#625), Tagesgrenze 20.
Befehle per `ssh rennwienix bash -s < skript` (Skripte nur im Sitzungs-Scratchpad); ausgegeben wurden nur Variablennamen
und die Werte `*` und `20`, nie ein Wert einer anderen Variable und keine Konto-Kennung.

## lesen vorher (22:08:16 Uhr MEZ)

```
namen: ALLOWED_APPLE_SUBS APNS_KEY_ID APNS_PRIVATE_KEY APNS_TEAM_ID APNS_TOPIC APPLE_CLIENT_IDS APPLE_KEY_ID APPLE_PRIVATE_KEY APPLE_TEAM_ID APPLE_TOKEN_KEY APPLE_WEB_CLIENT_ID DATABASE_URL OAUTH_COOKIE_KEYS OAUTH_SIGNING_JWK PUBLIC_URL
datei ALLOWED_APPLE_SUBS=<Liste, 1 Eintrag/Eintraege>
image loose-ends-server:bf1fccf gestartet 2026-11-23T06:44:44.132471266Z
container ALLOWED_APPLE_SUBS=<Liste>
container NEW_ACCOUNTS_PER_DAY=<nicht gesetzt>
health intern 200
health öffentlich 200
```

`origin/main` hat seit `bf1fccf` keine Änderung unter `server/`; offene PRs berühren den Dienst nicht. Deshalb bleibt
`LE_COMMIT` im Deploy-Skript (henemm-infra) unverändert, kein Infra-PR nötig.

## Änderung

- Sicherung der Umgebungsdatei daneben (gleicher Ordner, Endung `.vor-625-s5d2`, Rechte 600) für den Rückweg.
- Zeile `ALLOWED_APPLE_SUBS` auf `*` gesetzt, Zeile `NEW_ACCOUNTS_PER_DAY=20` angehängt (15 → 16 Zeilen), sonst nichts.
- `bash ~/henemm-infra/scripts/deploy-loose-ends.sh`, 22:08:37–22:08:54 Uhr MEZ, Exit 0:
  ```
  Container loose-ends-server Recreate
  Container loose-ends-server Started
  [deploy-loose-ends] /health 200: {"status":"ok","db":"up","migrated":true,"errorRate":0,"requests":0}
  [deploy-loose-ends] fertig: loose-ends-server:bf1fccf
  ```
  Commit: `LE_COMMIT=bf1fccf03ac88993752cb1aabf7db645728af7f0`.

## Gegenprobe (22:09:04 Uhr MEZ)

```
image loose-ends-server:bf1fccf gestartet 2026-11-24T21:08:52.981964443Z status running
container ALLOWED_APPLE_SUBS=*
container NEW_ACCOUNTS_PER_DAY=20
health intern 200
startlog zeilen 2
startlog 'door invalid': 0
startlog 'config invalid': 0
startlog 'invalid' gesamt: 0
2026-11-24T21:08:53.732Z listening
2026-11-24T21:08:53.779Z migrated
```

Öffentlich: `https://loose-ends.henemm.com/health` 200 (`{"status":"ok","db":"up","migrated":true,...}`),
`/.well-known/oauth-authorization-server` 200.

Rückweg: Sicherung zurückkopieren und dasselbe Deploy-Skript aufrufen.

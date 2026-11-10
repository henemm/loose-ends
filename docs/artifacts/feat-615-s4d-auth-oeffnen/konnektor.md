# Konnektor nach dem Deploy (AC-4) — 2026-11-10

**Der claude.ai-Konnektor „Loose Ends“ ist in dieser Sitzung nicht erreichbar.** Diese Claude-Code-Sitzung hat keine
MCP-Werkzeuge des Loose-Ends-Dienstes geladen (die verfügbaren claude.ai-Konnektoren sind andere Dienste), deshalb gibt
es hier keinen echten `get_now`-Aufruf. Das Zugriffsprotokoll von nginx auf rennwienix ist ein gemeinsames
`/var/log/nginx/access.log` ohne Host-Spalte; `/mcp`-Zeilen lassen sich darin nicht sicher diesem Host zuordnen
(auch `obsidian-mcp` läuft auf dem Server). Ein Konnektorbeleg aus dem Protokoll wird deshalb nicht behauptet.

**Ersatz laut AC-4:** `docs/artifacts/feat-621-s6b-betrieb/check-outside.sh` von außen, nach dem Deploy (15:38:41Z):

```
OK    200 GET /health (soll 200)
OK    200 GET /.well-known/oauth-authorization-server (soll 200, issuer https://loose-ends.henemm.com)
OK    200   client_id_metadata_document_supported (soll true)
OK    200   token_endpoint_auth_methods_supported (soll none enthalten)
OK    200 GET /.well-known/openid-configuration (soll 200, issuer https://loose-ends.henemm.com)
OK    200 GET /.well-known/oauth-protected-resource/mcp (soll 200, resource https://loose-ends.henemm.com/mcp)
OK    401 POST /mcp ohne Token (soll 401, WWW-Authenticate mit resource_metadata)
OK    404 GET /oauth/gibt-es-nicht (soll Dienstantwort, keine nginx-Seite, kein 502/504)
OK    404 GET /auth/apple (soll 404)
OK    404 POST /auth/apple (soll 404)
OK    404 POST /auth/delete (soll 404)
OK    404 GET / (soll 404)
Stand: 2026-11-10T15:39:01Z gegen https://loose-ends.henemm.com
Exit: 0
```

Discovery und `/mcp` ohne Token (401 mit `resource_metadata`) arbeiten mit dem neuen Image `c62fbae`. Die letzten drei
`/auth/*`-Zeilen zeigen zugleich: vor der nginx-Änderung war nichts vorzeitig offen.

Der echte `get_now` über claude.ai folgt im Serverbeleg nach Hennings Gerätelauf (Definition of Done, Stufe 3).

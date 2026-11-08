# CIMD-Adresse von claude.ai (AC-13)

Gelesen 2026-11-08 ~13:31 UTC aus `oauth_records` (nur das Feld `clientId` der Modelle Grant, AccessToken, RefreshToken):

    https://claude.ai/oauth/mcp-oauth-client-metadata

- beginnt mit `https://claude.ai/` → von `allowFetch` des Ausstellers erlaubt
- der Dienst hat das Dokument ohne Fehler geladen: der Ablauf lief bis `POST /oauth/token 200` und `/mcp 200` durch
  (verbinden.md); in `oauth_records` je ein Grant, AccessToken, RefreshToken für diese `clientId`
- Die Adresse war vorher nirgends dokumentiert (bekannt war nur Claude Codes
  `https://claude.ai/oauth/claude-code-client-metadata`); jetzt ist sie belegt. Kein Dienstfix nötig.

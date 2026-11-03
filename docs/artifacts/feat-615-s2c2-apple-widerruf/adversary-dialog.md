# Adversary Dialog — feat-615-s2c2-apple-widerruf
Spec: docs/specs/feat-615-schnitt-2c2-apple-widerruf.md
Datum: 2026-11-03 20:58

## Checkliste
- [x] **AC-1:** Anfrage genau wie festgelegt (POST, Kopf, Signal, genau vier Formularfelder, gültiges Secret, beide Client-IDs). Test „revoke: anfrage“.
- [x] **AC-2:** Status 200 mit beliebigem Rumpf ergibt genau `{ ok: true }`, Rumpf wird nicht gelesen. Test „revoke: erfolg“.
- [x] **AC-3:** Apple-Fehler und Status: `apple:<error>` für die sechs bekannten Werte, sonst `apple_status`. Test „revoke: apple-fehler und status“.
- [x] **AC-4:** Netz, synchroner Wurf, Timeout, abbrechender Rumpf ergeben `unavailable`; Signal ≤ 5000 ms. Test „revoke: unavailable und zeitlimit“.
- [x] **AC-5:** Fehlbedienung wirft vor `fetch`, ohne Geheimnisse im Text. Test „revoke fehlbedienung: wirft ohne netz“.
- [x] **AC-6:** `reason` stammt aus fester Menge, keine Geheimnisse. Test „revoke reason: feste menge, keine geheimnisse“.
- [x] **AC-7:** Keine Ausgabe nach console/stdout/stderr. Test „revoke: silence“.
- [x] **AC-8:** 186/186 grün, bestehende Einlöse-Tests unverändert, Funktionen ≤ 50 Zeilen, Imports nur `node:crypto` und `./apple.ts`.
- [x] **AC-9:** Dateigrenze: genau `server/src/apple-client.ts`, `server/test/apple-client.test.ts`, `CLAUDE.md`; CLAUDE.md-Zeile nennt `revokeToken`.

## Dialog

### Runde 1
**Adversary:** Fassen die Tests wirklich? Elf Mutanten einzeln in `apple-client.ts` eingebaut, nur `apple-client.test.ts` laufen lassen, Datei danach exakt zurückgespielt (diff ohne Befund). Getötet: `token_type_hint` entfernt, Erfolg bei Status < 400, Zeitlimit 6000 ms, leeres Token nicht geprüft, `error` nicht gegen die Liste geprüft, Apples Text im `reason`, zusätzliches Formularfeld, abgebrochener Rumpf als `null`, `client_id` fest auf `clientIds[0]`, `clientId` im Fehlertext. Überlebt: „Rumpf bei 200 lesen und ignorieren“ (nicht beobachtbar, LOW).
**Implementierer:** AC-1 bis AC-7 belegt.
Code reference: server/src/apple-client.ts:62
Code reference: server/src/apple-client.ts:101
Code reference: server/src/apple-client.ts:106
Code reference: server/src/apple-client.ts:49
Code reference: server/src/apple-client.ts:26
Code reference: server/test/apple-client.test.ts:239
Code reference: server/test/apple-client.test.ts:257
Code reference: server/test/apple-client.test.ts:289
Code reference: server/test/apple-client.test.ts:302
Code reference: server/test/apple-client.test.ts:329

### Runde 2
**Adversary:** Randfälle: Wurf in `clientSecret` vor jedem Netzzugriff (Zähler 0); Rumpf bei 200 wird nicht erreicht; Redirect 302 ergibt `apple_status` (echtes `fetch` folgt Redirects, wie schon `redeemCode`, LOW); Zeitlimit 5000 ms; Umstellung von `redeemCode` behält alle Gründe inkl. `malformed_response`; längste Funktion `revokeToken` mit 13 Zeilen; keine console/process-Nutzung.
**Implementierer:** Belegt.
Code reference: server/src/apple-client.ts:1
Code reference: server/src/apple-client.ts:55
Code reference: server/src/apple-client.ts:97
Code reference: CLAUDE.md:471

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:f0747649ccb42919ecf5da524298efc9004a7b50fb0541152f0a48cc610b833d  CLAUDE.md
- sha256:13bd279c1de9d24bd6a623f8ebae1a77e5f71034b95a4eaa616df52025869d95  server/src/apple-client.ts
- sha256:c1cf6ba737cc175b7fb855a049fa1a2b756df60da3f1a84e687fd235718ec232  server/test/apple-client.test.ts

## Prüfbasis

- base: 24ec34dff1f33f7b69b3d0c1eb140b2c4dcbd374
- blob:5a2baea4ef8d8139dbd4baf83d12a304419ba8d4  CLAUDE.md
- blob:527ce0c6bdcd067c60f30b703d4db2ce8d855ffe  server/src/apple-client.ts
- blob:75597e142e911a099cab951d11bc17b20d36954d  server/test/apple-client.test.ts

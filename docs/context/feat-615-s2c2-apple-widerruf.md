# Context: feat-615-s2c2-apple-widerruf

## Request Summary
#615 Schnitt 2c-2 (Weg B, ADR-21): `revokeToken` im Dienst. Beim Löschen eines Kontos gibt der Dienst Apples Refresh-Token an Apple zurück (`POST https://appleid.apple.com/auth/revoke`). Nur Baustein, nichts ruft ihn auf (S3 verdrahtet).

## Recherche (zuerst, 2026-11-03)
- Apple: [revoke tokens](https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens.md) — POST, Formular `client_id`, `client_secret`, `token`, optional `token_type_hint` (`refresh_token`/`access_token`).
- Apple: [TN3194](https://developer.apple.com/tutorials/data/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple.md) — Widerruf bei Kontolöschung ist Pflicht und nur über diesen Endpunkt möglich.
- Forum: [Thread 707545](https://developer.apple.com/forums/thread/707545) — Endpunkt liefert teils 200 auch bei ungültigem Token/Secret; Erfolg ist also schwach belegt. Nicht offiziell bestätigt: genaues Fehlerformat (in der Spec als Annahme markieren, im Test per Stub fest).
- Client-Secret: dasselbe ES256-JWT wie beim Einlösen (`clientSecret`, aud `https://appleid.apple.com`).

## Related Files
| File | Relevance |
|------|-----------|
| server/src/apple-client.ts | `clientSecret`, `redeemCode`: Muster (fetch/now/url injiziert, Timeout 5 s, Gründe als Werte, wirft nur bei Fehlbedienung); `revokeToken` kommt hierhin |
| server/test/apple-client.test.ts | Stub-fetch-Muster für die neuen Tests |
| server/src/apple-vault.ts | `decryptToken` (null bei jedem Fehler), `encryptToken` |
| server/src/accounts.ts | `deleteAccount` gibt `{deleted, appleToken: Buffer|null}` zurück — verschlüsselter Blob, der durch `decryptToken` und dann `revokeToken` läuft (Verdrahtung = S3) |
| server/src/apple.ts | `AppleConfig`, `loadAppleConfig` |
| server/migrations/002_accounts.sql | `apple_tokens` (FK auf accounts, folgt beim Löschen) |
| docs/specs/feat-615-schnitt-2c1-apple-einloesen.md | Vorgängerspec, Festlegungen für 2c-2 |
| CLAUDE.md | Abschnitt `server/` um `revokeToken` ergänzen (PR #819 ändert CLAUDE.md ebenfalls: Überschneidung) |

## Existing Patterns
- Eine Datei je Baustein, Netz wird hereingereicht, Stub im Test.
- Ergebnisunion `{ok:true…}|{ok:false, reason}`; Gründe `apple:<error>`, `apple_status`, `unavailable`; Apples Text wird nie übernommen.
- Wirft nur bei eigener Fehlbedienung (leerer Token, `clientId` außerhalb `config.clientIds`).

## Dependencies
- Upstream: `clientSecret`, `AppleConfig`, `fetch`, `AbortSignal.timeout`.
- Downstream: S3 (HTTP-Rand „Konto löschen“): `deleteAccount` → `decryptToken` → `revokeToken`; Fehlschlag darf das Löschen nicht blockieren (Konto ist dann schon weg; Wiederholung/Protokoll Entscheidung für S3).

## Existing Specs
- `docs/specs/feat-615-schnitt-2c1-apple-einloesen.md`, `…-2b2-apple-tresor.md`, `…-2a-apple-token-pruefen.md`

## Risks & Considerations
- Apple antwortet teils 200 bei ungültigem Token → „ok“ heißt nur „Apple hat nicht abgelehnt“; Spec muss das offen benennen.
- Welche `client_id` beim Widerruf: dieselbe, mit der eingelöst wurde (Token ist an sie gebunden); Konto speichert sie nicht → Festlegung für S3 nötig (Alternative: Spalte per neuer Migration, nur additiv).
- Alternative zum eigenen Widerruf: gar nicht widerrufen (verletzt Apples Vorgabe/App-Review-Regel 5.1.1(v)) — verworfen.
- Scope klein: eine Funktion + Tests + CLAUDE.md, weit unter 250 LoC.

## Analysis

### Type
Feature (Dienst-Baustein ohne Aufrufer; kein Modell im Spiel, kein sichtbarer Teil, daher kein UI-Entwurf nötig)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| server/src/apple-client.ts | MODIFY | `revokeToken(refreshToken, clientId, opts)` + Ergebnistyp `Revoked`; der Formular-POST mit Zeitlimit wird aus `redeemCode` in eine kleine gemeinsame Funktion gezogen |
| server/test/apple-client.test.ts | MODIFY | Tests „revoke: …“ nach dem Stub-Muster von `redeemCode`; die bestehenden Einlöse-Tests laufen als Regression über den gemeinsamen Teil |
| CLAUDE.md | MODIFY | Zeile `src/apple-client.ts` um `revokeToken` ergänzen (PR #819 berührt dieselbe Datei: Merge-Konflikt-Hinweis, keine inhaltliche Überschneidung) |

### Scope Assessment
- Files: 3
- Estimated LoC: +≈ 95 / -≈ 8 (Code ≈ 25, Tests ≈ 65, Doku ≈ 2; Tests ≈ 2,5× Code, wie in 2c-1)
- Risk Level: LOW (neue Funktion, keine Migration, kein Aufrufer; einziges Risiko ist die Umstellung von `redeemCode` auf den gemeinsamen POST, abgesichert durch dessen 11 vorhandene Tests)

### Technical Approach
- `POST https://appleid.apple.com/auth/revoke`, Formular genau `client_id`, `client_secret` (derselbe `clientSecret`), `token`, `token_type_hint=refresh_token`; Zeitlimit 5 s; `url` nur für Tests.
- `Revoked = { ok: true } | { ok: false; reason: string }`; Gründe wie bei `redeemCode`: `apple:<error>` (Apples bekannte Fehlerliste), `apple_status`, `unavailable`. Kein `malformed_response`: Bei 200 gibt es nichts zu lesen.
- 200 heißt nur „Apple hat nicht abgelehnt“ (Forum 707545: auch bei ungültigem Token teils 200). Das wird in der Spec offen benannt, nicht als „widerrufen“ verkauft.
- Wirft nur bei Fehlbedienung (leerer Token, `clientId` außerhalb der Liste), nie bei Apples Antwort, Netz oder Zeitlimit; Fehlertexte ohne Token, `clientId`, Schlüssel.
- Der Widerruf blockiert das Löschen nicht: Er ist eine Funktion, die ein Ergebnis liefert; was S3 bei `ok: false` tut, ist S3.
- Ohne Modell, ohne Regelwerk: reiner Protokollaufruf.

### Alternativen
- **A (empfohlen): Funktion in `apple-client.ts`, gemeinsamer POST.** Eine Quelle für Zeitlimit und Fehlerabbildung.
- **B: Kopie des POST-Teils in `revokeToken`.** Kein Eingriff in `redeemCode`, aber zwei Stellen für dieselbe Fehlerabbildung. Fallback, falls die Umstellung Tests kippt.
- **C: gar nicht widerrufen.** Verstößt gegen Apples Vorgabe für Kontolöschung (TN3194, App-Review 5.1.1(v)); verworfen. Kippt keine ADR, würde aber die Freigabe der App gefährden.
- **D: Widerruf in der App (nativ) statt im Dienst.** Der Dienst hält den Refresh-Token verschlüsselt, die App kennt ihn nicht; hieße den Token an die App zurückzugeben und ADR-21 zu kippen. Verworfen.

### Befunde gegen den Plan
Keine blockierenden. Zwei bewusst nach S3 verlegte Punkte: (1) Welche `client_id` beim Widerruf, ist offen, solange `apple_tokens` sie nicht speichert (2c-1 hielt fest: Spalte `client_id` per additiver Migration 003 oder `clientIds[0]` bis #621). (2) Wiederholung/Protokoll bei `ok: false`. Beides ändert die Signatur von `revokeToken` nicht (`clientId` ist Parameter).

### Dependencies
Upstream: `clientSecret`, `AppleConfig`, `fetch`, `AbortSignal.timeout`. Downstream: S3 (`deleteAccount` → `decryptToken` → `revokeToken`).

### Open Questions
- [ ] Keine für den PO. Technisch entschieden: Alternative A.

# Apple-Portal #621 S6b (AC-3)

Eingerichtet am 2026-11-08 zwischen 09:45 und 11:20 UTC in Chrome (Henning angemeldet, Team HENEMM GmbH `XK87E2B3VR`).
Kein Schlüsselmaterial in diesem Beleg.

| Punkt | Wert |
|---|---|
| App ID `com.henning.looseends` | Sign In with Apple **aktiviert**, „Enable as a primary App ID“ (vorher aus; gespeichert von Henning, weil mein Filter das Speichern einer Fähigkeit am App-ID verweigerte) |
| Services ID (= `APPLE_WEB_CLIENT_ID`) | `com.henning.looseends.web` (Beschreibung „Loose Ends Web“), ungleich `com.henning.looseends` |
| Sign in with Apple an der Services ID | aktiv |
| Primäre App | `XK87E2B3VR.com.henning.looseends` |
| Domain | `loose-ends.henemm.com` |
| Return-URL | `https://loose-ends.henemm.com/oauth/apple/return` (genau eine) |
| Schlüssel (`APPLE_KEY_ID`) | `SF83PT3Q22`, Name „Loose Ends Sign in with Apple“, Dienst nur Sign in with Apple, primäre App `com.henning.looseends` |
| Domain-Verifikation verlangt | **nein** (Bestätigungsseite „Confirm your web authentication configuration“ zeigte nur Bundle und URLs, keinen Download einer Verifikationsdatei) |

## Schlüssel

- Vorher gab es im Team **keinen** Schlüssel unter Keys (Seite „Getting Started with Keys“). Die drei `.p8` unter
  `~/Developer/AuthKey_{K928C9Z9P2,T7D652RS7A,WF54BW29RL}.p8` gehören also nicht zu Sign in with Apple (App-Store-Connect-API).
- Neuer Schlüssel einmalig heruntergeladen (Hennings Zustimmung im Chat), abgelegt als `~/Developer/AuthKey_SF83PT3Q22.p8`,
  Rechte 600. Er wird nur auf den Server übertragen.

Folge: Da `nginx` keine Apple-Verifikationsdatei braucht, gibt es keine statische `location` für
`/.well-known/apple-developer-domain-association.txt`.

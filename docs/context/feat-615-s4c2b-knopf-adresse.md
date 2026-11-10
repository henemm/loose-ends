# Context: feat-615-s4c2b-knopf-adresse

## Request Summary
#615 Schnitt 4c-2b: die zwei Restbefunde aus 4c-1/4c-2a schließen, bevor 4d den Dienst für die App öffnet.
F001: Der Apple-Knopf verschwindet heute in `signingIn`, obwohl er den laufenden Apple-Dialog hält; er soll sichtbar und
deaktiviert bleiben. F002: `AccountWiring.serviceURL` nimmt heute auch `http`; künftig nur `https`, `http` höchstens für
localhost im Debug-Bau.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Views/AccountSection.swift` | `layout(status:problem:)` (Zeile 19ff): `signingIn` → `showsAppleButton: false`; `body` blendet den Knopf aus; `request` ruft `beginSignIn()` (setzt `signingIn`) innerhalb von `onRequest` des `SignInWithAppleButton` |
| `LooseEnds/Claude/AccountWiring.swift` | `serviceURL(info:)` (Zeile 20ff) akzeptiert `https` und `http` mit Host, sonst Fallback `https://loose-ends.henemm.com` |
| `LooseEnds/Claude/AccountState.swift` | `beginSignIn` (nur aus signedOut/notAllowed/retryLater, sonst `notPossibleNow`), `cancelSignIn` (nur in signingIn) |
| `LooseEndsTests/AccountSectionTests.swift` | „account: layout je status“ (Tabelle, Zeile 28ff, prüft heute `!showsAppleButton` in signingIn), „account: wiring schalter und adresse“ (Zeile 49ff) |
| `LooseEndsUITests/AccountSettingsTests.swift` | Erwartungen zum Knopf nur nach Anmeldung/Löschen (nicht während signingIn), Ersatz-Transport antwortet sofort |
| `server/src/oauth-resource.ts:38` | Vorbild der Serverseite: https-Origin oder http nur auf localhost/127.0.0.1 |

## Existing Patterns
- Reine Abbildung Status → `Layout` im Unit-Test, View bleibt dünn (4c-1).
- Fail-closed bei Info-Werten (`isEnabled`: falscher Typ = aus; `serviceURL`: ungültig = Fallback auf Live-Adresse).
- Serverseite `publicUrlFromEnv`: http nur für localhost.

## Dependencies
- Upstream: `AccountState.Status`, `SignInWithAppleButton` (AuthenticationServices), Info-Wörterbuch.
- Downstream: `SettingsView` (Gruppe „Claude“), `LooseEndsApp`/Mac-Einstellungsfenster über `AccountWiring.forApp`; 4d (Gerätelauf Anmelden mit `konto=true`).

## Existing Specs
- `docs/specs/feat-615-schnitt-4c1-konto-gruppe.md` — Layout-Tabelle und AC-8 („signingIn zeigt nie den Apple-Knopf“) werden geändert.
- `docs/specs/feat-615-schnitt-4c2a-freischalten.md` — benennt 4c-2b (F001, F002).
- Adversary-Befund F001 in `docs/artifacts/feat-615-s4c-konto/adversary-dialog.md:35`.

## Risks & Considerations
- F001 ist sichtbar (Knopf bleibt grau stehen, Fortschrittszeile darunter) → Entwurf-vor-Spec-Regel prüfen.
- Ein zweites Tippen während signingIn: `request` würde `beginSignIn` werfen lassen und den Apple-Dialog ohne Nonce öffnen → Knopf muss wirklich deaktiviert sein.
- Ob `onCompletion` bei entferntem Knopf ausfällt, ist im Simulator nicht belegbar; Recherche nötig.
- `LEServiceURL` steht heute nicht in `project.yml` (Fallback greift); F002 ändert für echte Bauten nichts Sichtbares.
- Kein Pfad der Geräteliste berührt (nur `LooseEnds/Views`, `LooseEnds/Claude`, Tests).

## Analysis

### Type
Feature (Restbefunde F001/F002 aus 4c-1/4c-2a; Verhalten, kein neues Design)

### Recherche (2026-11-10)
- Kein Beleg, dass `onCompletion` eines aus der Hierarchie entfernten `SignInWithAppleButton` zuverlässig ankommt; Fallberichte zeigen genau dort Ausfälle:
  Completion feuert nie, wenn der Knopf in einem eigenen Modal sitzt (https://developer.apple.com/forums/thread/698652, https://developer.apple.com/forums/thread/656784),
  Präsentation „from a SwiftUI view not in a hierarchy“ führt zum Absturz (https://developer.apple.com/forums/thread/710183).
- Folgerung: Der Knopf bleibt während `signingIn` in der Hierarchie und wird nur deaktiviert. Ob das Entfernen im Simulator schadet, ist nicht belegbar (Apple-Dialog läuft unter `--ui-testing` nicht); der sichere Weg braucht diesen Beleg nicht.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Views/AccountSection.swift` | MODIFY | `Layout` bekommt `appleButtonEnabled`; `signingIn` → Knopf sichtbar, deaktiviert, Fortschrittszeile darunter; `.disabled(!layout.appleButtonEnabled)` an beiden Knopf-Varianten |
| `LooseEnds/Claude/AccountWiring.swift` | MODIFY | `serviceURL(info:allowsLocalHTTP:)`: nur `https`; `http` nur für `localhost`/`127.0.0.1` und nur wenn `allowsLocalHTTP` (Standard: `#if DEBUG` true, sonst false); sonst Fallback. `UITestTransport` bekommt Ausgang „langsam“ (`--ui-testing-account-slow`, ~2 s Verzögerung vor der Antwort), damit `signingIn` im UI-Test sichtbar wird |
| `LooseEndsTests/AccountSectionTests.swift` | MODIFY | Layout-Tabelle (signingIn: Knopf ja, deaktiviert, Fortschritt ja); Adress-Fälle: http fremd → Fallback, http localhost mit/ohne Freigabe, 127.0.0.1, ftp, https ohne Host |
| `LooseEndsUITests/AccountSettingsTests.swift` | MODIFY | Neuer Test: mit `--ui-testing-account-slow` antippen → Knopf existiert, `isEnabled == false`, Fortschrittszeile sichtbar; danach angemeldet |

### Scope Assessment
- Files: 4
- Estimated LoC: +70/-10
- Risk Level: LOW (Gruppe „Claude“ ist in jedem echten Bau ausgeschaltet; nur Einstellungen)

### Technical Approach
- F001: Status → Layout bleibt die eine Quelle; neues Feld statt Sonderlogik im View. `deleting` bleibt wie heute (Knopf weg), dort gibt es keinen Apple-Dialog.
- Doppeltippen: deaktivierter Knopf ruft `onRequest` nicht auf → kein `beginSignIn` ohne Nonce.
- F002: Regel wie Serverseite `publicUrlFromEnv` (https; http nur localhost). Freigabe als Parameter, damit der Unit-Test (Debug) beide Zweige prüft. `LEServiceURL` steht in keinem echten Bau → keine sichtbare Änderung.
- Geräteliste: nicht berührt (`LooseEnds/Views`, `LooseEnds/Claude`, Tests) → Abnahme endet nach Stufe 2.
- Entwurf-vor-Spec: entfällt begründet — kein neu gestalteter Screen, kein neues Element; der freigegebene Knopf aus Entwurf A bleibt einfach während der ~1–2 s Anmeldung grau stehen statt zu verschwinden.

### Alternativen
- (a) Knopf entfernen wie bisher, aber `onCompletion` über einen eigenen `ASAuthorizationController` (Delegate außerhalb der View) führen. Robust gegen Entfernen, aber eigener Controller statt Apples SwiftUI-Knopf: mehr Code, kippt die Entscheidung aus 4c-1 („Apples eigener Knopf“). Verworfen: größer, ohne Nutzen gegenüber Deaktivieren.
- (b) Fortschritt im Knopf überlagern (ProgressView als Overlay) statt eigener Zeile. Optisch neu → bräuchte Entwurf. Verworfen für diesen Schnitt.
- F002 Alternative: `LEServiceURL` ganz streichen, nur Konstante. Kippt den lokalen Prüfweg (Debug gegen localhost-Server). Verworfen.

### Dependencies
- `AccountState.beginSignIn/cancelSignIn` unverändert. 4c-1-Spec AC-8 („signingIn zeigt nie den Apple-Knopf“) wird durch dieses AC ersetzt.

### Open Questions
- keine (technisch; PO-Frage entfällt)

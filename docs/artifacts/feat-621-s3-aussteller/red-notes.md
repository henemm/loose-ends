# RED-Notizen #621 S3 (für /50-implement)

Festlegungen, die die Tests in `server/test/oauth-provider.test.ts` treffen, wo die Spec offen ließ:

- **Schlüssel-Form:** `oauthKeysFromEnv(env)` liefert `{ cookieKeys: string[], signingJwk: JsonWebKey }` (Test (b) liest beide Felder).
  Leere Werte (nur Leerzeichen) zählen als ungesetzt.
- **Interaction-Signatur:** `StartOptions.oauth.interaction = (provider, req: IncomingMessage, res: ServerResponse) => Promise<void>`;
  `main.ts` reicht `/oauth/interaction/*` an sie (Standard `productInteraction`: 501, Text ohne Werte, auch bei POST).
- **Uhr:** `StartOptions.now` (ms) geht als `() => new Date(now())` in `PgAdapter`; AC-8 „abgelaufen“ schiebt diese Uhr 2 h vor.
- **Opake Token:** Der Test findet die AccessToken-Zeile über `id_hash = sha256(access_token)`, also Token-Wert = Kennung (opak).
- **AC-11:** `provider.configuration()` gibt es in `oidc-provider` 9.13.3 nicht öffentlich. Der Test belegt „Dev-Anmeldung aus“
  über die Wirkung: keine Warnung `devInteractions` auf der Konsole, die Interaction-URL bleibt `/oauth/interaction/…`, kein Formular,
  `/interaction/anything` nie 200.
- **AC-6:** Der Nachweis „Körper ungelesen“ ist funktional (Token-Aufruf aus AC-2 gelingt; 100 KiB an `/oauth/token` beantwortet die
  Bibliothek mit 4xx und JSON-`error`, nicht die Brücke). Fehlerfenster: `oauth_records` wird umbenannt, 20 × `/oauth/token` ≥ 500,
  danach `/health` 503.
- **AC-16:** Mitschnitt über `console.*` (das `logError` nutzt `console.error`); `process.stdout.write` wird nicht gemockt, weil der
  Test-Runner darüber berichtet. FK-Fall: Konto wird nach `grant.save()` und vor `interactionFinished` gelöscht; erwartet: kein Code,
  kein Token, keine Konto-ID und kein Postgres-`detail` in Antworten oder Log.
- **AC-17:** Pinnung als eigener Test „oauth-provider: abhaengigkeit exakt gepinnt“.
- `main.test.ts`: `child()` filtert jetzt auch `OAUTH_*` aus der Umgebung der Shell.

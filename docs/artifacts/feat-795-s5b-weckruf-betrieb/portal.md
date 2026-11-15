# APNs-Schlüssel im Apple-Portal (AC-7) — 2026-11-15

Henning hat sich im Apple-Entwicklerportal angemeldet (Passkey); alles Weitere per Chrome durch Claude.
Konto oben rechts: „HENEMM GmbH - XK87E2B3VR“ → Team `XK87E2B3VR`.

**Vorher vorhandene APNs-Schlüssel: 0.** Liste „Keys“ vor dem Anlegen: genau ein Schlüssel, `SF83PT3Q22`
„Loose Ends Sign in with Apple“, Spalten „APNs Config“/„APNs Environment“ leer (kein APNs-Schlüssel). Limit nicht erreicht.

**Angelegt:** Name „Loose Ends APNs“, Dienst „Apple Push Notifications service (APNs)“.
Seite „Configure Key“: Auswahl Environment mit den Optionen „Sandbox“ (vorbelegt), „Production“, „Sandbox & Production“;
gewählt **„Sandbox & Production“ → Fall (a)**. Key Restriction „Team Scoped (All Topics)“ (deckt das Topic
`com.henning.looseends`). Hinweis des Portals beim Wählen, wörtlich: „It's recommended to use different,
environment-specific keys …“ (Alternative (b) der Spec, bewusst nicht gewählt).

**Schlüsselkennung (`APNS_KEY_ID`): `SKU593YN3B`.** Liste danach:
`SKU593YN3B  Loose Ends APNs  2026/11/15  Team Scoped (All topics)  Sandbox & Production`.
Topic für den Dienst: `com.henning.looseends`.

**Übertragung (keine Werte):** Die .p8 (257 Byte, PKCS#8-Kopfzeile) wurde einmal geladen und sofort
per stdin auf rennwienix geschrieben: `/home/hem/henemm-infra/loose-ends/secrets/apns-SKU593YN3B.p8`, Rechte `600`,
257 Byte; SHA-256-Präfix lokal und auf dem Server gleich (`9aa2c380b23f`). Danach lokal gelöscht (16:07:14Z):

    $ ls -l ~/Downloads/AuthKey_SKU593YN3B.p8
    ls: ~/Downloads/AuthKey_SKU593YN3B.p8: No such file or directory

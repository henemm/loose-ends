# Adversary Dialog — feat-624-s2-client
Spec: docs/specs/feat-624-schnitt-2a-anzeige.md
Datum: 2026-11-16 21:13

## Checkliste
- [x] **AC-1:** Titel und jeder Nutzertext erscheinen nur HTML-escaped; kein `innerHTML` mit Rohtext (Test 1).
- [x] **AC-2:** In `now` zeigen die Zeilen die Randmarke aus `group` (Knäuel-Zeichen, „Heute“ rot, „Nächstes“, „Wartet“) (Test 2).
- [x] **AC-3:** In `due`, `next` und `open` ist die Randmarke aus `dueDate` abgeleitet: heute und überfällig rot, Vergleich Tag gegen Tag in der `timeZone` des Hosts, sonst Datum in Grau, ohne Datum keine Marke (Test 3).
- [x] **AC-4:** Der Kopf zeigt Ansichtsname, Zahl (`nowCount` bei `now`, sonst `count`) und Stand aus `generatedAt` (Test 6).
- [x] **AC-5:** Eine leere Liste und eine Fehlerantwort (`isError` oder unlesbares JSON) zeigen je eine ruhige Zeile (Test 4).
- [x] **AC-6:** Das Fenster beginnt mit `ui/initialize` (`protocolVersion` „2026-01-26“, `appInfo`, `appCapabilities` `{}`), sendet erst nach der Antwort `ui/notifications/initialized` und vorher nichts anderes (Test 5).
- [x] **AC-7:** `theme` aus dem Host-Kontext setzt `data-theme`, `host-context-changed` wird zusammengeführt, ohne `theme` greift `prefers-color-scheme`; nach dem Zeichnen geht `ui/notifications/size-changed` hinaus (Test 6, Test 8).
- [x] **AC-8:** `ui/resource-teardown` wird mit `{}` beantwortet; unbekannte Mitteilungen werden ignoriert; das Fenster sendet in diesem Schnitt kein `tools/call` und bietet keinen Knopf an (Test 7).
- [x] **AC-9:** Die Ressource enthält genau ein inline-Skript und keine Fremdquelle (kein `src=`, `http://`, `https://`, `@import`, `xmlns`); `server/src/mcp.ts`, `server/package.json` und die Textantwort von `get_view` bleiben unverändert (Tests 8, 9; Prüfung im Review).
- [ ] **AC-10:** (offen, wird nach dem Ausrollen belegt) Nach dem Ausrollen zeigt claude.ai zu `get_view` mit `now` das Fenster mit Kopf und Zeilen, in Hell und Dunkel; Belege liegen unter `docs/artifacts/feat-624-s2a-anzeige/` (Abnahme Stufe 2, Bilder geöffnet und beschrieben).

## Dialog

### Runde 1
**Adversary:** Gesamtlauf ./server/scripts/test-local.sh (Ausgabe: docs/artifacts/feat-624-s2a-anzeige/adversary-test-output.txt). app-client.test.ts (AC-1..8) und mcp-app.test.ts (AC-1..5, Textantwort von get_view) gruen. Lauf 1: 456/461, Lauf 2: 454/461 -- die roten Tests sind ausschliesslich Prozess-Start-Tests (main.test.ts, migrate.test.ts Lock) mit 5-18 s Timeout bei Rechner-Load 500-900 (andere Sitzungen); der Implementierer hatte 461/461. Nicht beruehrte Dateien, kein Bezug zur Aenderung. Eigene Proben: Titel mit script-Ende-Tag und img bleibt escaped; genau ein script, kein src=/http(s)/xmlns/@import/button/tools-call; mcp.ts und package.json ohne Diff gegen HEAD. Tageswechsel: 23:30Z am 12.3. ist in Berlin der 13., in Los Angeles der 12. (dayIn korrekt). Fremdes theme ergibt null, also prefers-color-scheme. Antwort mit falscher id vor dem Handshake: keine Ausgabe, kein Zustandswechsel. Fehlerantwort loest draw aus, damit size-changed auch bei der ruhigen Zeile hinausgeht.
**Implementierer:** (nicht anwesend; Code gelesen: app-ui.ts reduce/paint/shell.)

### Runde 2
**Adversary:** Randfaelle ohne Defekt: (a) tool-result vor der Antwort auf ui/initialize wird verworfen (reduce: !state.ready), ein fruher resource-teardown bleibt unbeantwortet; laut Spec sendet der Host das Ergebnis erst nach initialized, also kein Defekt, am echten Host in AC-10 zu beobachten. (b) Fehlendes count/title ergaebe den Text "undefined" (escaped, Server liefert beides immer). (c) Ungueltiges dueDate oder ungueltige timeZone wirft in Intl, paint faengt es und zeigt die ruhige Zeile statt der Liste, defensiv gewollt. Kein Befund mit Schweregrad. AC-10 in dieser Phase nicht belegbar: offen, wird nach dem Ausrollen belegt.
**Implementierer:** (nicht anwesend)

### Runde 3
**Adversary:** AC-10 gegen die Bilder claude-ai-hell.jpg und claude-ai-dunkel.jpg geprueft (beide geoeffnet). Gesehen: claude.ai-Chat, Tool-Karte "Loose Ends - get_view" mit Fenster. Kopf: "Jetzt 2" (Zahl fett) links, "Stand 08:36" rechts (AC-4 erfuellt). Zeilen: Randmarke "Heute" neben "Jan wegen Symphoniekonzert fragen" (Titel gross, Serif), Randmarke "Wartet" neben "Stromverbrauch uebertragen" (Titel grau, AC-2 Wartet-Teil erfuellt); Trennlinien. Hell: warmes Beige-Papier, dunkle Schrift; Dunkel: fast schwarzes Papier, helle Schrift, klar unterscheidbar (AC-7 erfuellt); Textantwort darunter stimmt mit dem Fenster ueberein (2 Aufgaben, gleiche Titel, 17.11. / 16.11.). Knaeuel-Zeichen und "Naechstes" kommen in den Daten nicht vor (nicht belegt, nur durch Unit-Test).
**Befund F001 (HIGH, spec_violation):** Die Randmarke "Heute" ist in BEIDEN Bildern grau, nicht rot (Pixelprobe: keine roten Pixel im Zeilenbereich, Marke (94,93,88) hell). AC-2 verlangt "Heute" in Rot. Ursache im Code: server/src/app-ui.ts:135 `.row > span:first-child { color: var(--quiet) }` (Spezifitaet 0,2,1) schlaegt Zeile 136 `.row .red { color: var(--red) }` (0,2,0); die Marke ist das erste span der Zeile. Das gilt auch fuer AC-3 (heute/ueberfaellig rot). Die Unit-Tests pruefen nur die Klasse `red`, nie die wirksame Farbe, und haben das nicht gefangen. Remediation: Regel `.row > span.red { color: var(--red); }` bzw. `.row > span:first-child.red`, danach neu ausrollen und beide Bilder neu aufnehmen (am besten mit einer Zeile "Heute" und einer ueberfaelligen Zeile).
**Implementierer:** (nicht anwesend)

### Runde 4
**Adversary:** F001-Fix geprueft. Code: server/src/app-ui.ts:136 `.row .red, .row > span.red` hat Spezifitaet (0,2,1) wie die graue Regel Z.135 (0,2,1) und steht spaeter, gewinnt also nach Reihenfolge; Dunkel/Hell setzen nur `--red` (Z.114, 123), keine weitere Regel faerbt die Marke (grep: `.mark` ohne CSS, `.row.waiting .t` trifft nur den Titel). Randfaelle: "Naechstes", "Wartet", Knaeuel-Zeichen tragen nur `class="mark"`, bleiben grau (Z.27, 26); Datum in der Zukunft `mark` ohne red, grau (Z.34); ueberfaellig `mark red`, rot (Z.34); ohne Datum `<span></span>` ohne Klasse, grau, leer (Z.31). Die Selektor-Regel trifft nur Spans direkt unter `.row`, der Titel `.t` hat kein red. Test server/test/app-client.test.ts:50-68 rechnet die Spezifitaet und die Reihenfolge; er ist nicht trivial (rot vor Fix laut test-red-f001-output.txt). Schwaeche: der Test prueft das Stylesheet, nicht die Rendering-Farbe; das ersetzt die Chrome-Messung (f001-chrome-farbprobe.md: hell rgb(229,50,45), dunkel rgb(255,90,82), Wartet grau) ausreichend. Tests selbst gelaufen: app-client 9/9; ./server/scripts/test-local.sh 472 pass, 0 fail, 0 skipped (adversary-test-output.txt). F001 behoben. AC-10 bleibt offen: Bilder nach dem erneuten Ausrollen stehen aus.
**Implementierer:** (nicht anwesend)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)


## Verdict

Confirmation:
  AC: AC-1
  Code reference: server/src/app-ui.ts:13
  Evidence: escape ersetzt & < > " ' ; Titel und Zahl laufen nur escaped (Z.39, 67); Probe mit Script-Titel inert.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/src/app-ui.ts:24
  Evidence: mark() in now aus row.group: Knaeuel-SVG, Heute rot, Naechstes, Wartet; Test AC-2 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/src/app-ui.ts:30
  Evidence: dayIn (Z.19) Tag gegen Tag in timeZone; heute/ueberfaellig rot, sonst grau, ohne dueDate leer; Probe Berlin/LA/UTC.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/src/app-ui.ts:66
  Evidence: Kopf Name, nowCount bei now sonst count, Stand aus generatedAt; Test gruen (10:00 Berlin).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: server/src/app-ui.ts:44
  Evidence: readView null bei isError, kaputtem JSON, unbekannter Form; paint zeigt ruhige Zeile, nie Rohtext; leere Liste Z.38.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/src/app-ui.ts:109
  Evidence: ui/initialize als einzige Nachricht vorab; reduce (Z.78-82) sendet initialized erst auf id 1 mit result.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/src/app-ui.ts:83
  Evidence: host-context-changed gemergt; theme nur light|dark (Z.57), sonst Attribut entfernt, prefers-color-scheme (Z.126); size-changed in draw (Z.100).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/src/app-ui.ts:87
  Evidence: teardown mit {} und gleicher id beantwortet, Unbekanntes ignoriert, Fremdquelle verworfen (Z.103); kein tools/call, kein Button.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: server/src/app-ui.ts:145
  Evidence: genau ein script, keine Fremdquelle; mcp.ts und package.json ohne Diff; mcp-app.test.ts:74 gruen.
  Status: CONFIRMED

Doku: Code reference: CLAUDE.md:547 ; Tests: Code reference: server/test/app-client.test.ts:16 ; Code reference: server/test/mcp-app.test.ts:74

AC-10: offen, wird nach dem Ausrollen belegt (Sichtpruefung in claude.ai).

VERDICT: AMBIGUOUS
F001 (HIGH) behoben und bestaetigt: Randmarke "Heute"/ueberfaellig wirksam rot, "Naechstes"/"Wartet"/Datum grau.
  Code reference: server/src/app-ui.ts:136
  Code reference: server/test/app-client.test.ts:50
Offen: AC-10 (Sichtpruefung in claude.ai nach dem erneuten Ausrollen) bleibt [ ] bis die neuen Bilder vorliegen.
Tests: 472 passed, 0 failed, 0 uebersprungen (adversary-test-output.txt)
Proven points: AC-1 bis AC-9 von 10; AC-10 aussteht.

## Geprüfte Dateien

- sha256:fdfae3ed41b371d865a6e16ff7d3aba986ac3a9db31033e7358fb10e338d798b  server/src/app-ui.ts

## Prüfbasis

- base: 84d5f0cad434a9bfa6f27d08c3b2f3193cd543e8
- blob:1c295018ea9f8aaa698b27a99e094c1da3b75667  server/src/app-ui.ts

## Geprüfte Dateien

- sha256:fdfae3ed41b371d865a6e16ff7d3aba986ac3a9db31033e7358fb10e338d798b  server/src/app-ui.ts

## Prüfbasis

- base: 84d5f0cad434a9bfa6f27d08c3b2f3193cd543e8
- blob:1c295018ea9f8aaa698b27a99e094c1da3b75667  server/src/app-ui.ts

## Geprüfte Dateien

- sha256:0fa4631e34e8146209162bf1a368ea2a40b78eee6faa399d6be77be58e8ecf86  server/src/app-ui.ts
- sha256:8b269899ac468ddd3bbd3833c91e0c0187e150057b8cbdb47afd74679cc93ab8  server/test/app-client.test.ts

## Prüfbasis

- base: 822a2957f48e69bf2a57d72ba1ec205db9e5c808
- blob:b6339a8239b03ae7e5c125bbce40d68a92586f6c  server/src/app-ui.ts
- blob:a2ef4018eeb26f69cafae46252c2bf154fa47090  server/test/app-client.test.ts

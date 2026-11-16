# Adversary Dialog — feat-624-mcp-app
Spec: docs/specs/feat-624-schnitt-1-ressource.md
Datum: 2026-11-16 16:03

## Checkliste
- [x] **AC-1:** Der Dienst führt genau eine Ressource `ui://loose-ends/view.html` mit MIME `text/html;profile=mcp-app` (Test 1).
- [x] **AC-2:** Das Lesen der Ressource liefert genau einen Inhalt mit dieser URI, diesem MIME und einem vollständigen HTML-Dokument mit `lang="de"` (Test 2).
- [x] **AC-3:** Das HTML enthält kein Skript und keine externe Quelle und bringt Hell und Dunkel mit (Test 3).
- [x] **AC-4:** Nur `get_view` trägt `_meta.ui.resourceUri` = `ui://loose-ends/view.html`; kein anderes Werkzeug trägt `_meta.ui` (Test 4).
- [x] **AC-5:** Die Antwort von `get_view` bleibt für alle vier Ansichten Zeichen für Zeichen wie heute: ein Textinhalt, kein `structuredContent` (Test 5).
- [x] **AC-6:** Keine neue Abhängigkeit in `server/package.json`; `anleitung.ts`, Abschrift, Migrationen und App sind unverändert; `./server/scripts/test-local.sh` ist grün (Test 6, Prüfung im Review).

## Dialog

### Runde 1
**Adversary:** Lauf `./server/scripts/test-local.sh` selbst (Ausgabe: docs/artifacts/feat-624-mcp-app/adversary-test-output.txt): Typprüfung ok, 453 bestanden, 0 fehlgeschlagen, 0 übersprungen, migrate.test.ts nicht wackelig. Alle fünf Tests AC-1..AC-5 aus mcp-app.test.ts grün. Diff gegen 837f38f: nur CLAUDE.md, app-ui.ts, mcp.ts, mcp-app.test.ts plus Spec/Artefakte/Entwurf; keine Änderung an server/package.json, anleitung.ts, migrations/, App-Ordnern (AC-6).
Fragen: (1) Ändert `_meta` die tools/call-Antwort von get_view? (2) Trägt ein anderes Werkzeug `_meta.ui`? (3) Gibt es mehr als eine Ressource oder eine Vorlage? (4) Enthält das HTML Skript/Fremdquellen (auch jenseits der vier getesteten Wörter: src=, href=, url(, <link, <img, //)?
Code reference: server/src/app-ui.ts:4 (UI_URI, UI_MIME Zeile 5), HTML ab Zeile 7.
Code reference: server/src/mcp.ts:222 (`_meta: { ui: { resourceUri: UI_URI } }` nur in registerViews/get_view; der Handler `reading(...)` Zeile 223 unverändert, Eingabeschema und Annotationen unverändert).
Code reference: server/test/mcp-app.test.ts:92 (AC-5 vergleicht Schlüssel, Reihenfolge, Zeichenfolge `text === JSON.stringify(json)` und Ids in allen vier Ansichten).
**Implementierer:** Belege: AC-4-Test (Zeile 81) prüft jedes andere Werkzeug auf fehlendes `_meta.ui`; der Diff zeigt `_meta` nur an get_view. Suche in app-ui.ts nach src=, href=, url(, <link, <img, <script, @import findet im HTML nichts (die `//`-Treffer sind Kommentare Zeile 1-3 und `ui://` in Zeile 4, nicht im HTML). Mehr als eine Ressource ausgeschlossen: AC-1 prüft `resources.length === 1`.

### Runde 2
**Adversary:** Tiefer: (a) resources/templates/list und das Lesen einer falschen URI. Die Ressource ist mit fester Zeichenkette registriert, nicht als ResourceTemplate; templates/list liefert damit leer und eine unbekannte URI einen Protokollfehler (aus dem SDK-Verhalten gelesen, nicht eigens per Test ausgeführt; kein Befund, die Spec fordert dazu nichts). (b) Bearer-Tor: die Ressource liegt hinter /mcp, nicht an einem eigenen Pfad. (c) anleitung-Test: kein neues Werkzeugwort; anleitung.ts unverändert, mcp-anleitung-Tests in der Ausgabe grün. (d) AC-5 vergleicht gegen feste Erwartung statt gegen den Stand vorher; da der get_view-Handler im Diff unberührt bleibt (nur `_meta` kommt hinzu), ist die Zeichengleichheit belegt. (e) CSP: kein `_meta.ui.csp`/`domain`, wie in der Spec. (f) Test 3 verbietet http:// und https://, nicht protokollrelative `//host`; im HTML kommt keines vor, daher kein Befund.
Code reference: server/src/mcp.ts:231 (registerUi, genau ein Inhalt `{ uri, mimeType, text }`).
Code reference: server/test/mcp-app.test.ts:52 (AC-1) und :73 (AC-3).
Code reference: server/src/app-ui.ts:16 (prefers-color-scheme: dark).
**Implementierer:** Keine Gegenrede nötig; kein Code geändert.

### Confirmations
Confirmation:
  AC: AC-1
  Code reference: server/src/mcp.ts:231
  Evidence: registerResource("view", UI_URI, mimeType UI_MIME); Test AC-1 grün, resources.length === 1
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/src/app-ui.ts:7
  Evidence: doctype, lang="de", ein Inhalt mit uri/mimeType; Test AC-2 grün
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/src/app-ui.ts:16
  Evidence: kein <script, kein http(s)://, kein @import, Dunkelmodus per Media Query; Test AC-3 grün, Suche bestätigt
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/src/mcp.ts:222
  Evidence: _meta.ui.resourceUri nur an get_view; Test AC-4 grün
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: server/test/mcp-app.test.ts:92
  Evidence: Antwort ein Textinhalt, kein structuredContent, Schlüssel und Ids in vier Ansichten; Handler unverändert
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/src/mcp.ts:8
  Evidence: Diff gegen 837f38f berührt weder server/package.json noch anleitung.ts, migrations/, App; test-local.sh: 453 bestanden, 0 fehlgeschlagen
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: 453 passed, 0 failed, 0 übersprungen
Edge cases: geprüft (templates/list und falsche URI nur aus SDK-Verhalten gelesen), keine Befunde
Regressions: None found
Checklist: 6/6 points proven

## Geprüfte Dateien

- sha256:9a23122958110e92edad0cb4b08f64145620046170f377a0d73199fb36efb5b1  server/src/app-ui.ts
- sha256:44241154457667bf5f144b2b8cfa5cc9e53be4bb8b1dc358c28c306f351fec72  server/src/mcp.ts
- sha256:5d1dbf1b881701c586f55895a7b64080a7f37a5a0e7688c883fba57b27c1fa44  server/test/mcp-app.test.ts

## Prüfbasis

- base: 837f38fc03f71449be629c9bc2e1812185b17e66
- blob:8cf6503734bd547fff7fcab424a9990789bdee1f  server/src/app-ui.ts
- blob:ebdb0f303c3c2a0c467c6839c80ea047aa721ecb  server/src/mcp.ts
- blob:5bc523b0546269a27ec072d5848ba90b0cd50911  server/test/mcp-app.test.ts

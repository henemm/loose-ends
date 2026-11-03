# Adversary Dialog — feat-615-s2b2-apple-vault
Spec: docs/specs/feat-615-schnitt-2b2-apple-tresor.md
Datum: 2026-11-03 14:56

## Checkliste
- [x] **AC-1:** Rundweg und Blobform: `decryptToken(key, id, encryptToken(key, id, token))` ergibt den Token zurück, für einen kurzen, einen langen (4 KiB) und einen Token mit Umlauten und Emoji; das erste Byte des Blobs ist `0x01`, die Länge ist `29 +` Klartextlänge in Bytes. Test: `server/test/apple-vault.test.ts`, „roundtrip: blobform“.
- [x] **AC-2:** Angriffsfälle ergeben `null`: für jede Zeile der Fallliste — Version `0x00`, `0x02` und `0xFF`; je ein gekipptes Byte in IV, Tag und Ciphertext; Tag auf 15 Byte gekürzt (Blob 1 Byte kürzer, auch mit angepasstem Rest); Blob mit 28 Byte; leerer Buffer; falscher Schlüssel; falsches Konto — ergibt `decryptToken` `null` und wirft nie. Test: `apple-vault.test.ts`, „attack: manipuliert, falsch, zu kurz“ (Fallliste).
- [x] **AC-3:** Fremde Eingabetypen: Als `blob` ergeben `null`, ein Text (auch der Hex- und Base64-Text eines gültigen Blobs), `Uint8Array` mit gültigem Inhalt, `undefined`, `null`, eine Zahl und ein Objekt jeweils `null`, ohne zu werfen. Test: `apple-vault.test.ts`, „attack: kein Buffer“ (Fallliste).
- [x] **AC-4:** Schlüssellänge beim Entschlüsseln: Ein Schlüssel mit 31 oder 33 Byte und ein leerer Schlüssel ergeben bei einem sonst gültigen Blob `null`, ohne zu werfen. Test: `apple-vault.test.ts`, „decrypt: schlüssellänge“.
- [x] **AC-5:** Kleinster Blob: Ein mit leerem Ciphertext authentisch gebildeter Blob von genau 29 Byte (Tag über einen leeren Klartext, zum Beispiel per `createCipheriv` im Test erzeugt) wird nicht wegen der Länge abgelehnt und ergibt `""`; dagegen ergibt derselbe Blob mit gekipptem Tag-Byte `null`. Test: `apple-vault.test.ts`, „decrypt: 29 Byte“.
- [x] **AC-6:** `encryptToken` wirft bei eigener Fehleingabe: Schlüssel mit 31 oder 33 Byte, leerer Token, leere `accountId`; der Fehlertext enthält weder den Schlüssel (hex und base64) noch den Token noch die `accountId` (Testwerte `GEHEIM-123` für den Token, eine erkennbare UUID für das Konto). Test: `apple-vault.test.ts`, „encrypt: wirft bei Fehleingabe“.
- [x] **AC-7:** IV-Eindeutigkeit: 1000 Verschlüsselungen desselben Klartexts mit demselben Schlüssel und Konto ergeben 1000 verschiedene IV (Bytes 1 bis 12) und 1000 verschiedene Blobs. Test: `apple-vault.test.ts`, „encrypt: iv je blob verschieden“.
- [x] **AC-8:** Kein Klartext im Blob: Der Blob enthält den Klartext-Token nicht als Byte-Folge (`blob.includes(Buffer.from(token))` ist `false`, Token von mindestens 16 Byte). Test: `apple-vault.test.ts`, „encrypt: kein klartext im blob“.
- [x] **AC-9:** Upsert überschreibt: Nach `storeRefreshToken` mit Blob A und danach mit Blob B für dasselbe Konto steht genau eine Zeile in `apple_tokens`, `refresh_token_enc` ist B, `created_at` ist nicht kleiner als zuvor und hat sich durch das Überschreiben vorwärts bewegt (Prüfung mit `pg_sleep` oder gesetztem Altwert); beide Aufrufe ergeben `true`. Test: `apple-vault.test.ts`, „store: überschreibt“.
- [x] **AC-10:** Unbekanntes Konto: `storeRefreshToken` mit einer nicht vorhandenen `accountId` ergibt `false`, wirft nicht und legt keine Zeile an; ein anderer Datenbankfehler (Aufruf auf einem Pool nach `end()`) wird weitergeworfen und nicht als `false` verschluckt. Test: `apple-vault.test.ts`, „store: unbekanntes konto“.
- [x] **AC-11:** Rundweg über `deleteAccount`: Konto per `findOrCreate`, `storeRefreshToken(pool, id, encryptToken(key, id, token))`, danach `deleteAccount`; der zurückgegebene `appleToken` ist ein Blob, den `decryptToken(key, id, appleToken)` zum Original-Token entschlüsselt; die Zeile in `apple_tokens` ist danach weg (Kaskade). Test: `apple-vault.test.ts`, „store: rundweg über deleteAccount“.
- [x] **AC-12:** Konto gebunden in der Datenbank: Der aus der Zeile von Konto 1 gelesene Blob ergibt für Konto 2 `null`, auch wenn er dort in die Tabelle geschrieben wurde. Test: `apple-vault.test.ts`, „store: blob gehört zum konto“.
- [x] **AC-13:** Stille: Während aller Aufrufe der Tests AC-1 bis AC-12 (Erfolg, `null`, Wurf) wird nichts nach `console` oder `process.stdout`/`process.stderr` geschrieben (der Test ersetzt sie vorübergehend), und `decryptToken` ergibt immer `string` oder `null`. Test: `apple-vault.test.ts`, „silence“.
- [x] **AC-14:** Regression, CI und Funktionslänge: Test: `./server/scripts/test-local.sh` (typecheck + alle Tests, einschließlich der DB-Tests) ist grün und räumt auf, `server.yml` ist auf dem PR grün, die bestehenden Testdateien bleiben unverändert; jede Funktion in `server/src/apple-vault.ts` hat höchstens 50 Zeilen (Prüfung in der Validierung: `grep -nE "function" server/src/apple-vault.ts`, Abstand zweier Funktionsanfänge und Dateiende ≤ 50).
- [x] **AC-15:** Dateigrenze: Test: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/apple-vault.ts`, `server/test/apple-vault.test.ts` und `CLAUDE.md`; `server/src/apple.ts`, `server/src/accounts.ts`, `server/migrations/`, `server/test/db.ts`, `server/test/accounts.test.ts`, `server/package.json`, `server/package-lock.json`, `server/src/main.ts`, `.github/workflows/`, `project.yml` und jede Swift-Datei bleiben unberührt.

## Dialog

### Runde 1
**Adversary:** Fordere Beweis fuer alle AC-1 bis AC-15. Volle Suite `./server/scripts/test-local.sh` ausgefuehrt (Output: docs/artifacts/feat-615-s2b2-apple-vault/adversary-test-output.txt). Pruefe Tests auf Scheinbeweise: seal() baut Blobs von Hand (server/test/apple-vault.test.ts:18), der Fall "Tag 15 Byte, echt gebildet" (server/test/apple-vault.test.ts:38) trifft DEP0182 wirklich.
**Implementierer:** Beweis: typecheck gruen, `tests 169, pass 169, fail 0, skipped 0`. Code-Pfade: Version/Laenge/Typ-Pruefung server/src/apple-vault.ts:25-26, feste Tag-Laenge server/src/apple-vault.ts:28, try/catch -> null server/src/apple-vault.ts:32-34, Upsert mit created_at = now() server/src/apple-vault.ts:41-42, 23503 -> false server/src/apple-vault.ts:47. Tests: roundtrip server/test/apple-vault.test.ts:63, Angriffe :72, Fremdtypen :76, 29 Byte :84, store :117/:131/:140/:150.

### Runde 2
**Adversary:** Eigene Sonden (Wegwerf-Skript, nichts im Projekt geaendert). (a) Gekuerzter Tag 4 und 12 Byte echt gebildet, auch mit Nullen auf 16 aufgefuellt: alle `null` (DEP0182 abgewehrt). (b) Buffer-Subarray mit Offset: korrekt "hello". (c) Schluessel als Uint8Array/String/null: `null`. (d) Unicode-accountId: Rundweg ok, abweichendes Konto und NFD-Form `null`. (e) 5-MB-Token: Rundweg ok. (f) accountId Zahl/null bei decrypt: `null`; encrypt mit Token Zahl, Schluessel null, Konto null: wirft, Texte ohne Geheimnis. (g) storeRefreshToken mit gemocktem Pool: 23503 -> false, 23502 und `throw null` werden weitergeworfen. (h) Funktionslaengen: encrypt 11-20, decrypt 24-35, store 38-50, alle <= 50. (i) AC-15: der Dateigrenzen-Diff gegen origin/main (ohne docs und .claude) nennt CLAUDE.md und server/test/apple-vault.test.ts; die dritte Datei server/src/apple-vault.ts ist untracked (steht in der Statusliste), also genau die drei Dateien; apple.ts, accounts.ts, Migrationen, package*.json unberuehrt. (j) Teststille: Pruefe, ob die Verschiebung der Mocks AC-13 abschwaecht.
**Implementierer:** Sonden-Ergebnisse wie genannt. Zu (j): in server/test/apple-vault.test.ts:164-166 laufen nur `migrated` und `findOrCreate` (DB-Setup, kein Vault-Code) vor den Mocks; die Mocks stehen ab :167-169, alle Aufrufe von decryptToken, encryptToken, storeRefreshToken (:170-175) liegen in der ueberwachten Zone, Restore erst :177. AC-13 ist nicht abgeschwaecht.

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: server/src/apple-vault.ts:26
  Description: `Buffer.isBuffer` ist fuer einen Proxy um einen Buffer wahr; `blob.length` (ausserhalb des try) wirft dann TypeError. Reproduziert mit `decryptToken(key, id, new Proxy(Buffer.alloc(40), {}))`.
  Spec requirement: AC-3 / Purpose, decryptToken wirft nie
  Conflict: Absichtlich boeswillige In-Process-Objekte (Proxy) koennen einen Wurf ausloesen; ueber Netz oder Datenbank nicht erreichbar (pg liefert echte Buffer).
  Remediation: Zeilen 25-26 in den try-Block verschieben. Nicht blockierend.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: server/src/apple-vault.ts:18
  Description: Token mit einzelnem Surrogat wird als U+FFFD verschluesselt, der Rundweg ergibt nicht den Original-String. Apples Refresh-Token sind ASCII, kein praktischer Effekt.
  Spec requirement: AC-1, Rundweg (nur fuer gueltige Texte gefordert)
  Conflict: Keine Spec-Verletzung, nur Hinweis.
  Remediation: Keine noetig.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: server/src/apple-vault.ts:19
  Evidence: Blob = Version + iv + tag + ct; Test server/test/apple-vault.test.ts:63 prueft Laenge 29 + Bytes und Rundweg, gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2, AC-3, AC-4, AC-5
  Code reference: server/src/apple-vault.ts:28
  Evidence: authTagLength 16 plus Laengen-/Versions-/Typpruefung :25-26; Sonde mit 4/12-Byte-Tags: null; Tests :72, :76, :80, :84 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-6, AC-7, AC-8
  Code reference: server/src/apple-vault.ts:12
  Evidence: Fehlertexte konstant, ohne Geheimnisse (Sonde); randomBytes(12) je Aufruf :15; Tests :91, :107, :113 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-9, AC-10, AC-11, AC-12
  Code reference: server/test/apple-vault.test.ts:117
  Evidence: Upsert-Statement server/src/apple-vault.ts:41-42, 23503 -> false :47, andere Fehler geworfen (Sonde 23502, null); DB-Tests gegen Wegwerf-Postgres gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: server/test/apple-vault.test.ts:167
  Evidence: Mocks greifen vor allen Vault-Aufrufen (:170-175), restore :177; nicht abgeschwaecht.
  Status: CONFIRMED

Confirmation:
  AC: AC-14, AC-15
  Code reference: server/src/apple-vault.ts:38
  Evidence: Funktionen 10, 12, 13 Zeilen; 169/169 Tests gruen, 0 uebersprungen; Dateigrenze genau die drei Dateien (apple-vault.ts untracked). server.yml-Lauf steht noch aus (PR).
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

**VERIFIED** — alle 15 ACs belegt, 169/169 Tests gruen, nur zwei LOW-Hinweise (Proxy-Buffer, Surrogate), AC-13 nicht abgeschwaecht.

## Geprüfte Dateien

- sha256:2cf3975b059af3f801a040ea9d72410d0506df1d34b02435304cd9b4a299dc91  server/src/apple-vault.ts
- sha256:2f1bf010dffa3c99ba3fd718e75edf08422ff2618d75c591bfe4ccee56a59377  server/test/apple-vault.test.ts

## Prüfbasis

- base: e62f0d5025bb430ade878774122fd484815c55cd
- blob:b8ec4cdd7386bdf74a9be47207ccfdc1d0e5f14b  server/src/apple-vault.ts
- blob:519bd8727d4a9be85286bdd09255558607155e26  server/test/apple-vault.test.ts

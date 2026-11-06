# Validation Report: feat-621-s3-aussteller (#621 S3, 2026-11-06)

### Test Results
- `./server/scripts/test-local.sh`: typecheck ok; 276 tests, 276 passed, 0 failed, 0 übersprungen, 0 todo (7,5 s); Wegwerf-Postgres danach entfernt. Log: `validate-test-output.txt`.
- Ein Lauf mit 0 bestanden und ≥ 1 übersprungen ist nicht grün — hier nicht der Fall.

### Spec Compliance
- Acceptance Criteria: 17/17 erfüllt, nach Nachschärfung der Tests (nur `server/test/oauth-provider.test.ts`, kein Produktcode):
  - **AC-16 (echter Befund):** Der FK-Test erreichte den FK-Fehler nie. Das Konto wurde erst *nach* `grant.save()` gelöscht, danach lehnte `findAccount` vorher ab; das Postgres-Log zeigte keinen einzigen Fehler. Jetzt löscht der Helfer (`beforeGrant`) das Konto vor dem Speichern des Grants: Postgres meldet 23503 mit der Konto-ID im `detail`, der Test prüft das über die Fehlercodes des Pools, und der Mitschnitt des Dienstes enthält weder ID noch `detail`.
  - **AC-16:** Mitschnitt jetzt auch für Text an `process.stdout`/`process.stderr`; zusätzlich ein Mitschnitt über die ganze Datei (AC-1 bis AC-15), der nur Zeilen `<ISO-Zeit> <festes Ereignis>` zulässt. Gegenversuch: eine eingeschmuggelte Zeile `geheimes-token-abc123` macht die Datei rot.
  - **AC-15:** „nach Abschluss von migrate“ jetzt an derselben Instanz: Die Datenbank existiert zunächst nicht (migrate wiederholt), wird nach den 503-Prüfungen angelegt; dieselben Aufrufe antworten danach fachlich (200, 200, 400 der Bibliothek), und der volle Durchlauf gelingt.
  - **AC-6:** „/health zählt nicht“ jetzt entscheidend: 30 `/health`-Aufrufe mit 200 **vor** der Fehlerserie; zählten sie als Erfolg, bliebe das Fenster unter 50 % Fehlern. Erster Versuch (Aufrufe nach der Serie) war wirkungslos, weil ein gezähltes 503 das Fenster selbst rot hält (Adversary Runde 3, F007); Mutationen `main.ts:75` und `main.ts:154` werden jetzt erkannt (Runde 4).
  - **AC-4:** `error_description` wird geprüft (Hinweis auf PKCE bzw. `code_challenge_method`).
- Bewusst nicht wörtlich, mit Begründung:
  - AC-3 „AccessToken-Zeilen gleich“: Der Widerruf löscht die Zeilen der Erlaubnis, die Zahl sinkt; der Test prüft „kein weiteres“ (`<=`) und „keine Zeile mit dieser `grant_id`“.
  - AC-6 „Test-Handler vor `provider.callback()`“: bräuchte einen Haken im Produktcode. Belegt durch die Wirkung: Ein vorgelesener Körper ließe den Token-Aufruf der Bibliothek scheitern; er antwortet 200.
  - AC-8 `extra.account`: belegt in AC-2 (nur die Abschrift des eigenen Kontos erscheint).
  - AC-11 `provider.configuration()`: In 9.13.3 gibt es keinen öffentlichen Zugriff (im Test kommentiert); belegt durch die Wirkung (keine Formularseite, keine Warnung `devInteractions`).

### Regression Check
- Status: keine Regressionen. Einzige geänderte Altassertion: `oauth-resource.test.ts` 404 → 503 für `/.well-known/oauth-authorization-server`, zwingend aus AC-13 (Aussteller ohne Schlüssel). `/health`, `/mcp`, `/auth/*`, Metadaten der Ressource und die 1-MiB-Grenze der Brücke unverändert.

### Scope Check
- Code: `server/src/main.ts` +47/−4, `server/src/oauth-provider.ts` +145, `server/package.json` +2 = 198 LoC (Spec ≈ 190–220).
- Tests: `oauth-provider.test.ts` (neu, nach Nachschärfung ≈ 640), `main.test.ts` +30/−1, `oauth-resource.test.ts` +2/−1. Überschreitung des 250-LoC-Limits durch Sicherheitstests, in der Spec vor dem Bauen angenommen.
- Dateien: 6 unter `server/` plus Lockfile; `oauth-resource.test.ts` nicht in der Dateiliste der Spec, aber deren Altfall-Klausel (Altfälle, die brechen).
- Funktionslänge: keine Funktion über 50 Zeilen (größte: `main()` 44, `start()` 40, `configuration()` 24).
- Doku: `CLAUDE.md` (`server/`-Abschnitt), Nachtrag zu ADR-21 in `docs/project/00-entscheidungen.md`.

### Result: PASS

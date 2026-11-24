# Context: feat-625-s5c-konto-rueckbau (#625 Schnitt 5c)

## Request Summary
Seit S5b (PR #988) steht `LEAccountEnabled = true` und das Manifest mit den drei `ACCOUNT_TYPES` an der Quelle. Die
CI-Mechanik aus #615 S4c-2a / #625 S2 (Eingabe `konto`, `ACCOUNT_BUILD`, Schritt „Set the account switch“, Marke
„KONTO-BAU – nie für den App Store“ in „Was testen“) ist damit wirkungslos und widersprüchlich: ein `v*`-Tag-Lauf
(`ACCOUNT_BUILD=false`) scheitert heute an der Archivprüfung, weil die Quelle `true` trägt. S5c baut sie zurück, damit
ein normaler Lauf (Hand oder Tag) für TestFlight und App Store ohne Sonderweg durchläuft.

## Related Files
| File | Relevance |
|------|-----------|
| `.github/workflows/testflight.yml` | Eingabe `konto` (Z. 21–24), Kopfkommentar + `env.ACCOUNT_BUILD` (Z. 34–38), Schritt „Set the account switch“ in `upload` (Z. 119–124) und `upload-mac` (Z. 456–461), `account_switch` mit `want="${ACCOUNT_BUILD:-false}"` (Z. 233/538), Manifestprüfung `--account "$ACCOUNT_BUILD"` (Z. 267–274, 566–571) |
| `scripts/asc_what_to_test.py` | `ACCOUNT_BUILD_MARK`, `mark_account_build`, `is_account_build`; `main` hängt die Marke bei `ACCOUNT_BUILD=true` an (Z. 153) |
| `scripts/asc_store_version.py` | `build_lock` sperrt Bauten mit Marke (`konto`) und mit unlesbaren Texten; liest `is_account_build` |
| `scripts/privacy_manifest.py` | `apply` (nur vom CI-Schritt benutzt), `check --account true|false` |
| `scripts/test_asc_what_to_test.py` | `AccountBuildSourceTests` (Quelle, bleibt), `AccountBuildWorkflowTests` (AC-3..5: Eingabe, Schritt, Prüfausschnitt gegen Beispiel-Plists mit beiden Eingaben) |
| `scripts/test_privacy_manifest.py` | AC-9..11: `apply` nur in den Konto-Schritten, Prüfung mit `$ACCOUNT_BUILD`, Blöcke unverändert |
| `scripts/test_aps_environment.py` | AC-7: SHA-256 der `account-switch-check`-Blöcke, Schritt-`if`, zwei `plutil -replace LEAccountEnabled` |
| `scripts/test_asc_store_version.py` | Zuordnung überspringt markierte Bauten (liest `ACCOUNT_BUILD_MARK`) |
| `docs/reference/testflight.md` Z. 356–375 | beschreibt `konto`, Marke, Sperre |
| `CLAUDE.md` Z. 295, 357 | `konto`-Satz unter Ship, „manual runs keep … `konto` on“ |

## Existing Patterns
- Archivprüfungen als markierte Shell-Blöcke (`# …-check:begin/end`), Tests führen den Ausschnitt gegen Beispiel-Plists aus.
- Workflow-Tests lesen `testflight.yml` per YAML und prüfen Schritte, `if` und Reihenfolge.
- Eine Quelle für Konstanten (`ACCOUNT_TYPES`, `ACCOUNT_BUILD_MARK`).

## Dependencies
- Upstream: `project.yml` (S5b: `LEAccountEnabled: true`), `LooseEnds/PrivacyInfo.xcprivacy` (drei Typen).
- Downstream: `asc-store-version.yml aktion=anlegen` (S5d ordnet den 1.0.2-Bau zu), jeder TestFlight-Lauf.

## Analysis

### Type
Feature (Rückbau einer Liefer-Mechanik; kein Fehler im Produkt, aber ein heute scheiternder `v*`-Tag-Lauf).

### Befund am Code (2026-11-23 gegengeprüft)
- `testflight.yml`: Eingabe `konto` (Z. 21–24, Vorgabe `true`), Kopfkommentar Z. 34–35, `env.ACCOUNT_BUILD` Z. 38,
  Schritt „Set the account switch“ Z. 119–124 (`upload`) und Z. 456–461 (`upload-mac`), `account_switch` mit
  `want="${ACCOUNT_BUILD:-false}"` Z. 233–241 / 538–546, Manifestprüfung Z. 268–274 / 567–571. Kein anderer Workflow liest `konto`.
- `asc_what_to_test.py` Z. 153: Marke nur bei `ACCOUNT_BUILD=true`; `asc_store_version.py` `build_lock` Z. 141–152 sperrt
  markierte Bauten (`konto`) und unlesbare Texte.
- Tests, die angepasst werden: `test_asc_what_to_test.py`, `test_privacy_manifest.py`, `test_aps_environment.py`
  (Hash der Prüfblöcke), `test_asc_store_version.py` (bleibt inhaltlich, liest weiter die Marke).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `.github/workflows/testflight.yml` | MODIFY | Eingabe `konto`, `ACCOUNT_BUILD`, Kommentar, beide Schalter-Schritte weg; Prüfungen fest auf Bool `true` und `--account true` |
| `scripts/asc_what_to_test.py` | MODIFY | keine Marke mehr anhängen (`mark_account_build`, Lesen von `ACCOUNT_BUILD` weg); Marke und `is_account_build` bleiben |
| `scripts/asc_store_version.py` | MODIFY | nur Docstring: Sperre gilt den alten markierten Bauten |
| `scripts/test_asc_what_to_test.py`, `test_privacy_manifest.py`, `test_aps_environment.py` | MODIFY | Erwartungen umdrehen (RED zuerst), Hash bewusst neu |
| `docs/reference/testflight.md`, `CLAUDE.md` | MODIFY | Konto-Absatz und Sitzungsregel „`konto` on“ |

### Scope Assessment
- Dateien: 3 Liefer-/Skriptdateien + Tests + 2 Doku; App-Code (Swift): keiner
- Geschätzte LoC: `testflight.yml` ~-35/+6, Skripte ~-12/+2; Tests ~60 (zählen nicht)
- Risk Level: LOW — nur Liefer-Weg; der Wächter auf den Quellwert bleibt; kein Pfad der Geräteliste → Stufe 3 entfällt

### Technical Approach
Empfehlung wie im Plan unten. Nachweis nach dem Merge: ein TestFlight-Lauf von Hand ohne `konto` (die Eingabe gibt es
dann nicht mehr) läuft durch beide Archivprüfungen, und „Was testen“ trägt keine Marke.

### Dependencies
Upstream S5b (Quelle `true`, Manifest mit drei Typen). Downstream S5d: der 1.0.2-Bau für den Store muss nach S5c gebaut sein.

### Open Questions
- keine (reine Liefer-Mechanik, keine Produktentscheidung)

### Plan (Empfehlung)
1. `testflight.yml`: Eingabe `konto`, `env.ACCOUNT_BUILD`, Kopfkommentar und beide Schritte „Set the account switch“ entfallen.
   Die Archivprüfungen bleiben als Wächter, prüfen aber fest: `LEAccountEnabled` Bool `true`, Manifest `check --account true`.
   So fängt ein versehentlich abgeschalteter Quellwert weiterhin vor dem Hochladen.
2. `asc_what_to_test.py`: keine Marke mehr anhängen (`mark_account_build` und das Lesen von `ACCOUNT_BUILD` entfallen).
   `ACCOUNT_BUILD_MARK` und `is_account_build` bleiben, weil `asc_store_version.py` sie liest.
3. `asc_store_version.py`: Sperre `konto` bleibt für die alten markierten Bauten (sie tragen in TestFlight den Text „nie für
   den App Store“; sie zuzuordnen widerspräche ihrer eigenen Beschriftung). Nur Docstring anpassen. Folge für S5d: der
   1.0.2-Bau muss ein Lauf nach S5c sein (der unmarkiert ist); ältere markierte 1.0.2-Bauten werden übersprungen.
4. Tests umdrehen (RED zuerst): keine Eingabe `konto`, kein `ACCOUNT_BUILD`, kein Schritt „Set the account switch“, kein
   `plutil -replace LEAccountEnabled` im Workflow; Prüfausschnitt akzeptiert nur Bool `true`; Manifestprüfung mit
   `--account true`; `asc_what_to_test` hängt auch bei gesetztem `ACCOUNT_BUILD=true` keine Marke an; Store-Sperre für
   markierte Bauten bleibt grün.
5. Doku: `docs/reference/testflight.md` und `CLAUDE.md` (Ship-Absatz, Sitzungsregel „`konto` on“).

### Alternativen
- **Sperre `konto` ebenfalls entfernen:** alte Konto-Bauten wären wieder zuordenbar. Inhaltlich gleich zum Store-Bau,
  aber ihr „Was testen“ sagt „nie für den App Store“; dem Prüfer läge ein so beschrifteter Bau vor. Verworfen.
- **Archivprüfung des Schalters ganz streichen:** weniger Code, aber kein Wächter mehr gegen einen abgeschalteten Quellwert
  im Store-Bau (die #625-DoD verlangt die Gruppe im Store). Verworfen; der Wächter kostet nichts.
- **`privacy_manifest.py apply` mitentfernen:** ohne CI-Aufrufer toter Pfad; bleibt hier, weil `--account false` und `apply`
  noch Werkzeug für ein Zurückdrehen sind und der Schnitt klein bleiben soll. Kippt keine ADR.

### Umfang
App-Code (Swift): keiner. `testflight.yml` ~-35/+6, `asc_what_to_test.py` ~-10, `asc_store_version.py` ~2,
Tests ~60 (zählen nicht), Doku. Im Limit. Kein Pfad der Geräteliste berührt (`testflight.yml` und `scripts/` stehen nicht darin) → Stufe 3 entfällt.

## Risks & Considerations
- Ein Tag-Lauf scheitert heute (Quelle `true` gegen `ACCOUNT_BUILD=false`); S5c behebt das, bis dahin kein Tag-Lauf.
- Marken-Sperre: nach S5c ist der nächste TestFlight-Bau der erste unmarkierte; Henning bekommt in TestFlight keinen
  „KONTO-BAU“-Hinweis mehr (gewollt).
- `test_aps_environment.py` hält einen Hash der Blöcke fest; der Hash muss bewusst auf den neuen Stand gesetzt werden.

# Context: feat-268-schema-schranke

## Request Summary
#268: Ein TestFlight-Lauf, dessen Modell Production nicht kennt, hält an, bevor er hochlädt. Teile 1 und 2 des Tickets
(Abbild im Repo, Test „Modell = Abbild“) hat #448 schon geliefert; offen ist Teil 3 (Prüfung im TestFlight-Ablauf)
und die Doku.

## Stand der Teile
| Teil | Stand |
|---|---|
| 1 Abbild | `cloudkit/schema.ckdb` und `.github/workflows/cloudkit-schema.yml` (Export/Import per `cktool`). Workflow ist auf `main` (PR #449). Die **Datei** liegt nur in PR #450 (offen, Branch `feat/442-anhaenge-modell`), nicht auf `main`. |
| 2 Test Modell = Abbild | `scripts/test_cloudkit_schema.py` (Python-Unittest, liest `@Model`-Klassen mit Regex, prüft `CD_<Klasse>.CD_<Feld>` in der Datei), ebenfalls nur in PR #450. |
| 3 Schranke im TestFlight-Lauf | offen, das ist #268. |
| Doku 5a | `docs/reference/testflight.md` beschreibt den CI-Weg seit #449; die Schranke fehlt. |

## Related Files
| File | Relevance |
|------|-----------|
| `.github/workflows/testflight.yml` | Jobs `upload` (iOS) -> `upload-mac` -> `confirm-mac`/`confirm`. Hier kommt ein Job vor `upload` (oder ein Schritt direkt nach „Check the test notes“, vor „Archive“). |
| `.github/workflows/cloudkit-schema.yml` | Vorbild: `xcrun cktool save-token --type management`, dann `export-schema --team-id XK87E2B3VR --container-id iCloud.com.henning.looseends --environment production --output-file …`. Runner `xcode-27`, Composite-Action `select-xcode-27`. |
| `cloudkit/schema.ckdb` (nur in #450) | Soll-Schema: `RECORD TYPE CD_<Klasse> ( CD_<feld> TYP …, "___…", GRANT … );` |
| `scripts/test_cloudkit_schema.py` (nur in #450) | Muster für ein Python-Prüfskript mit `unittest` und Regex-Parser (`record_fields()`). |
| `docs/reference/testflight.md` | Abschnitt 5a, 5 und „Wenn es hakt“ um die Schranke ergänzen. |
| `CLAUDE.md` („Ship“) | Absatz „CloudKit schema before every TestFlight build“ nennt die Schranke noch nicht. |

## Existing Patterns
- Exportformat (Beleg: Lauf 38754886284, `export-production`): Textdatei `DEFINE SCHEMA`, je Typ ein Block
  `RECORD TYPE <Name> ( <Feld> <TYP> <Flags>, … );`, Systemfelder in Anführungszeichen (`"___createTime"`), `GRANT`-Zeilen.
  Dieselbe Syntax wie die Repo-Datei, daher ein Parser für beide.
- Prüfskripte unter `scripts/` sind Python mit `unittest` (`test_entitlements_sync.py`, `test_cloudkit_schema.py`); CI führt sie aus.
- Der Token liegt als Secret `CLOUDKIT_MANAGEMENT_TOKEN` (gesetzt am 2026-10-15), Gültigkeit ein Jahr.
- Bestehende Schranken im Ablauf brechen mit `::error::` und Verweis auf `docs/reference/testflight.md` ab.

## Dependencies
- Upstream: `cktool` (Xcode 27 auf dem `xcode-27`-Runner), Management-Token, Soll-Datei aus #450.
- Downstream: jeder TestFlight-Lauf (`workflow_dispatch` und `v*`-Tag). Eine falsche Schranke blockiert die Auslieferung.

## Risks & Considerations
- **Reihenfolge:** Ohne `cloudkit/schema.ckdb` auf `main` hätte die Schranke nichts zum Vergleichen. Entweder wird #450 zuerst
  gemergt, oder die Schranke bricht mit klarer Meldung ab, wenn die Datei fehlt. Absprache mit der Sitzung, die #450 hält.
- **Vergleichsrichtung:** Fehlt in Production etwas, das die Datei kennt, hält der Lauf an. Zusätzliche Felder in Production
  (tote Felder nach Umbenennung, Production ist additiv) dürfen nie anhalten.
- **Fachliche Lücke:** Vergleicht man nur Namen, fällt ein Feld mit anderem Typ nicht auf. Die Spec entscheidet, ob der Typ
  mitgeprüft wird (Production ist additiv, ein Typwechsel ist dort ohnehin nicht möglich).
- **Fehlerfall Token/Netz:** Fehlt das Secret oder scheitert `cktool`, muss der Lauf anhalten (nicht still durchlaufen),
  mit eigener Meldung, die sich von „Feld fehlt“ unterscheidet. Ein nicht prüfbarer Stand ist kein grüner Stand.
- **Notausgang:** Soll es einen Weg am Prüfschritt vorbei geben (Eingabefeld)? Empfehlung: keinen. Ein Gate, das man selbst
  öffnen kann, ist keines (CLAUDE.md, „Die App wird benutzt“).
- **Prüfbarkeit der Schranke selbst:** Die Vergleichslogik gehört in ein Skript mit Unit-Test (rot bei fehlendem Feld);
  der Ablauf ruft nur das Skript. Beleg im Lauf-Protokoll: ein Lauf gegen einen Stand mit absichtlich zusätzlichem Feld.
- **Alternative zum Datei-Vergleich:** Production gegen Development vergleichen, ohne Repo-Datei. Als Vorschlag verworfen,
  weil Development lückenhaft ist und das Modell der Maßstab ist. Kippt keine ADR.
- Kein Pfad der Geräteliste berührt (`.github/`, `scripts/`, Doku).

## Analysis

### Type
Feature (CI-Schranke, kein Produktcode)

### Recherche (zuerst, Quelle)
- Apple, „Using cktool“ (https://developer.apple.com/icloud/ck-tool): `export-schema --environment production` mit Management-Token
  ist der vorgesehene Weg, das Schema als `.ckdb` zu lesen. Das Token-Verfahren steht schon im Workflow `cloudkit-schema.yml`.
- Das Exportformat von Production ist belegt (Lauf 38754886284): dieselbe `DEFINE SCHEMA`-Syntax wie `cloudkit/schema.ckdb`.
  Ein Parser reicht für beide Dateien.

### Regelweg statt Modell
Reiner Text-Vergleich zweier Dateien (Typnamen und Feldnamen als Mengen). Kein Sprachmodell, kein Netz außer dem einen `cktool`-Aufruf.

### Befund
- Die Schranke vergleicht **Abbild (`cloudkit/schema.ckdb`) gegen Production**, nicht das Swift-Modell. Der Test „Modell = Abbild“
  (#450) sichert Modell ⊆ Abbild; die Schranke sichert Abbild ⊆ Production. Zusammen gilt Modell ⊆ Production.
- **Vergleichsrichtung einseitig:** Fehlt in Production ein Typ oder Feld des Abbilds, hält der Lauf an. Zusätzliches in Production
  (tote Felder, Production ist additiv) hält nie an.
- **Nur Namen, kein Typ:** Ein Typwechsel ist in Production nicht deploybar (Apple lehnt ihn beim Deploy ab). Ein Typvergleich
  bräuchte Normalisierung der Index-Flags und bringt keinen Fall, den der Deploy nicht ohnehin abfängt. Systemfelder (`___…`),
  `GRANT`-Zeilen und Indizes zählen nicht: Der Abgleich der App braucht nur Typ und Feld.
- **Drei getrennte Fehlerfälle**, drei Meldungen: (1) Secret fehlt, (2) `cktool` scheitert oder Export leer/unlesbar, (3) Typ/Feld fehlt
  (mit Liste und Verweis auf testflight.md 5a). Nicht prüfbar ist nicht grün.
- **Kein Notausgang** (kein Eingabefeld zum Überspringen). Ein Gate, das man selbst öffnen kann, ist keines.
- **Abhängigkeit:** `cloudkit/schema.ckdb` und `scripts/test_cloudkit_schema.py` liegen nur in PR #450 (offen, Build und Unit-Tests grün,
  UI Smoke läuft). Fehlt die Datei bei Start der Schranke, bricht sie mit eigener Meldung ab. Umsetzung (TDD Rot) beginnt erst, wenn #450 auf `main` ist.

### Alternativen
| Weg | Urteil |
|---|---|
| A (Empfehlung) Abbild-Datei gegen Production, Skript + Unit-Test, eigener Job vor `upload` | trifft genau das Ticket, Datei ist der bewusste Maßstab |
| B Production gegen Development vergleichen, ohne Repo-Datei | verworfen: Development ist lückenhaft (legt Felder nur mit Wert an), das Modell wäre nicht der Maßstab. Kippt keine ADR |
| C Swift-Modell direkt gegen Production (Parser aus dem Test wiederverwenden) | möglich, aber doppelt zum Test „Modell = Abbild“; Abbild bliebe ungeprüft gegen Production, und ein Fehler im Modell-Parser träfe den Upload |
| D Nur Doku/Checkliste | der heutige Zustand, das Ticket will ihn ersetzen |

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/check_cloudkit_production.py` | CREATE | Parser für beide `.ckdb`, Mengenvergleich Abbild ⊆ Production, Exit 1 (fehlt) / 2 (nicht lesbar), Meldung mit Liste |
| `scripts/test_check_cloudkit_production.py` | CREATE | Unit-Test: grün bei gleich/mehr in Production, rot bei fehlendem Feld und fehlendem Typ, Fehlerfälle leere/fehlende Datei |
| `.github/workflows/testflight.yml` | MODIFY | Job `schema-check` (runner `xcode-27`, Token speichern, `export-schema --environment production`, Skript), `upload` bekommt `needs: schema-check`; `upload-mac` hängt über `upload` mit |
| `docs/reference/testflight.md` | MODIFY | 5a und „Wenn es hakt“: Schranke, drei Meldungen, kein Notausgang |
| `CLAUDE.md` | MODIFY | Absatz „CloudKit schema before every TestFlight build“ nennt die Schranke |

### Scope Assessment
- Files: 5
- Estimated LoC: +~130/-~2
- Risk Level: MEDIUM — eine falsche Schranke blockiert die Auslieferung; deshalb Skript mit Unit-Test, Beleg im Lauf (rot gegen absichtlich zusätzliches Feld auf Wegwerf-Zweig, hält vor dem Upload).

### Technical Approach
Vergleichslogik in einem Skript, der Workflow ruft nur das Skript. Beleg der Schranke: (1) Unit-Test rot→grün, (2) ein TestFlight-Lauf von
einem Wegwerf-Zweig mit absichtlich zusätzlichem Feld im Abbild stoppt in `schema-check` mit der Meldung, `upload` läuft nicht (Lauf-Protokoll). Ein grüner Lauf ist erst der echte Build.

### Dependencies
`cktool` (Xcode 27, Runner `xcode-27`), Secret `CLOUDKIT_MANAGEMENT_TOKEN` (gesetzt 2026-10-15), `cloudkit/schema.ckdb` aus #450. Jeder TestFlight-Lauf ist betroffen.

### Geräteliste
Kein Pfad der Geräteliste berührt (`.github/`, `scripts/`, Doku).

### Open Questions
- [ ] Keine Produktfrage. Technisch entschieden: Weg A, Namen statt Typen, kein Notausgang, Umsetzung nach Merge von #450.

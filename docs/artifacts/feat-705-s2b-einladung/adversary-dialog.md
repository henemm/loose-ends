# Adversary Dialog — feat-705-s2b-einladung
Spec: docs/specs/feat-705-schnitt-2b1-gruppe-zuordnung.md
Datum: 2026-10-27 12:14

## Checkliste
- [x] **AC-1:** `scripts/asc_beta_invite.py` legt die externe Gruppe `Tester` an, wenn sie fehlt (`isInternalGroup=false`, `feedbackEnabled=true`, `publicLinkEnabled=false`, Beziehung `app`), und ordnet je Plattform `IOS` und `MAC_OS` den Build zu. Belegt durch `test_first_run_creates_group_and_assigns_both_platforms`.
  - am echten Apple belegt: Lauf 40534641955 und 40535068594 (siehe Runde 5)
- [x] **AC-2:** Als Build gilt je Plattform der neueste mit `processingState=VALID` und `expired=false` (`sort=-uploadedDate`, `limit=1`, Plattformfilter); ist er der Gruppe schon zugeordnet, wird nur der fehlende zugeordnet. Belegt durch `test_newest_valid_build_is_chosen_per_platform`, `test_existing_group_only_assigns_missing_build`.
  - am echten Apple belegt: Lauf 40534641955 und 40535068594 (siehe Runde 5)
- [x] **AC-3:** Das Skript sendet nie eine Einreichung (`betaAppReviewSubmissions`), nie `publicLinkEnabled=true`, nie ein Link-Limit, nie DELETE oder PATCH; der Workflow nennt beides ebenfalls nicht. Belegt durch `test_never_submits_and_never_enables_link`, `test_workflow_file`; im echten Lauf zeigt die Probe `einreichung` leer und `link=aus` für `Tester`.
- [x] **AC-4:** Idempotent: stimmen Gruppe und Zuordnung bei Apple schon, sendet das Skript keinen Schreibaufruf und meldet `zusammenfassung geschrieben=0`; ein zweiter Lauf nach einem ersten ändert nichts. Belegt durch `test_second_run_sends_no_write`; am echten Apple durch den zweiten Handlauf `aktion=zuordnen` mit `geschrieben=0`.
  - am echten Apple belegt: Lauf 40534641955 und 40535068594 (siehe Runde 5)
- [x] **AC-5:** Ein Fehler bei einer Plattform verdeckt die andere nicht: die andere Plattform wird trotzdem bearbeitet, die Zusammenfassung wird gedruckt, der Lauf endet mit Exit 1 und einer Meldung mit Plattform. Belegt durch `test_one_platform_failing_does_not_hide_the_other`.
- [x] **AC-6:** Hat eine Plattform keinen gültigen Build, meldet das Skript `kein-gültiger-build`, schreibt dafür nichts und endet nicht allein deshalb mit Fehler. Belegt durch `test_platform_without_valid_build_is_reported_not_failed`.
- [x] **AC-7:** Antwortet Apple auf einen Schreibaufruf mit 403, endet das Skript mit Exit ≠ 0 und der Meldung „Schlüssel ohne Schreibrecht“. Belegt durch `test_forbidden_write_is_reported_clearly`.
- [x] **AC-8:** Gibt es zwei externe Gruppen namens `Tester`, bricht das Skript mit Exit 1 und `::error::` ab, bevor irgendein Schreibaufruf gesendet wird; eine interne Gruppe gleichen Namens zählt nicht. Belegt durch `test_duplicate_external_groups_abort_before_any_write`.
- [x] **AC-9:** Die Ausgabe enthält nur Zustandswörter und `name=Tester`, `plattform=`, `extern=` (Felder, die auch die Probe druckt), nie Gruppen- oder Build-IDs, Buildnummern, Link-URL, Schlüssel oder Token (stdout und stderr). Belegt durch `test_output_has_only_state_words`.
- [x] **AC-10:** `.github/workflows/asc-beta.yml` hat die Wahl `zuordnen` (Standard bleibt `probe`), den Job `assign` ohne zusätzliche Eingabe, entfernt die Schlüsseldatei und lässt die Probe nach erfolgreichem `assign` als Beleg laufen; `testflight.yml` ist unverändert, die Tests von Probe und 2a bleiben grün. Belegt durch `test_workflow_file`, die Regression und `git diff --stat` (`testflight.yml` nicht im Diff).
- [x] **AC-11:** `docs/reference/testflight.md` beschreibt den Handlauf `zuordnen` (kein Review, kein Link, umkehrbar, 403-Rückfall, spätere Builds brauchen einen neuen Lauf) und führt externe Gruppe, Zuordnung und Exportnachweis mit Beleg. Belegt durch Diff (`grep -n "zuordnen" docs/reference/testflight.md` mindestens ein Treffer).
- [x] **AC-12:** Der Diff berührt genau die vier Dateien des Scopes, kein `project.yml`, kein App-Code, kein `testflight.yml`, keine Änderung an `asc_beta_probe.py`, `asc_wait_build.py`, `asc_what_to_test.py`, kein Pfad der Geräteliste, höchstens ±250 LoC, jede Funktion ≤ 50 Zeilen. Belegt durch `git diff --stat` im Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“
- [x] **AC-13:** Alle Skripttests (`python3 scripts/test_*.py`) sind grün und liefen vor Skript und Workflow-Änderung rot (TDD RED). Belegt durch die Testausgabe im Abschlussbericht.
- [x] **AC-14:** Echter Lauf nach dem Merge: `aktion=zuordnen` auf `main`, danach zeigt die Probe desselben Laufs `gruppe name=Tester intern=nein link=aus` und je Plattform eine `build …`-Zeile, und das Skript meldet je Plattform `zustand=gesetzt` (ein zweiter Lauf `zustand=vorhanden`, `geschrieben=0`; die Probe selbst druckt keine Gruppenzuordnung); der Lauf-Link und der beobachtete Build-Zustand (`extern=…`) stehen in #705 und in der Prüfliste. Belegt durch Lauf-Link im Ticket #705 und die ausgefüllte Spalte „Beleg“. Vorher läuft kein schreibender Aufruf gegen App Store Connect und nichts auf Hennings Geräten.
  - belegt durch Läufe 40534641955 und 40535068594; offen bleibt nur der Kommentar in #705 (Aufgabe des Koordinators)

## Dialog

### Runde 1
**Adversary:** Ich nehme nichts als bewiesen. Gesamtlauf `for t in scripts/test_*.py` gespeichert in `docs/artifacts/feat-705-s2b-einladung/adversary-test-output.txt`: 26 Dateien, 0 FAIL, 0 übersprungen; `test_asc_beta_invite.py` Ran 11 OK, `test_asc_beta_probe.py` Ran 13 OK, `test_asc_beta_setup.py` Ran 12 OK. RED-Beleg `test-red-output.txt` endet mit `Ran 11 tests ... FAILED (failures=11)` (AC-13 Rot-Teil).

Beweise je Punkt (Code und Test gelesen):
- AC-1: `scripts/asc_beta_invite.py:59-62` sendet genau die vier Attribute plus Beziehung `app`; `scripts/test_asc_beta_invite.py:137-153` prüft Attribute exakt per assertEqual, je Plattform ein POST mit der Build-ID.
- AC-2: `scripts/asc_beta_invite.py:16-17` Abfrage mit VALID, expired=false, sort=-uploadedDate, limit=1; `:73` plus `platform_filter`; `scripts/test_asc_beta_invite.py:175-180` vergleicht die Parameter exakt (der Nachbau liefert nur bei exakt gleichen Parametern einen Treffer, also kein Scheinbeweis). `asc_beta_invite.py:30-34` `plan_assignment` None, wenn Gruppe schon genannt; Test `:167-173`.
- AC-3: im Skript gibt es nur `send_json(config, *plan)` (`:42`) mit Plänen aus `:34` und `:62`, beide POST; weder PATCH/DELETE noch Link noch Einreichung im Code. `scripts/test_asc_beta_invite.py:129-135` und `:199-207` über vier Szenarien; der Workflow enthält kein `publicLinkEnabled` (`.github/workflows/asc-beta.yml`, Test `:250-251`).
- AC-4: `asc_beta_invite.py:39-40` Plan None schreibt 0; Test `:155-165` prüft, dass der zweite Lauf nur GET sendet.
- AC-6: `asc_beta_invite.py:74-75` Rückgabe ohne Fehler; Test `:182-188` Exit 0, 2 Schreibaufrufe.
- AC-7: `asc_beta_invite.py:43-44` ersetzt "HTTP 403" durch FORBIDDEN, `:92` druckt. Ein 403 bei einem GET bekäme die Meldung nicht, aber die Spec nennt nur Schreibaufrufe.
- AC-8: `asc_beta_invite.py:23-26`, Abbruch in `ensure_group` vor dem POST (`:56` vor `:62`), `main` gibt Exit 1 (`:90-93`). Test `:209-219` inklusive interner Gruppe.
- AC-10: Workflow-Semantik durchgedacht (`.github/workflows/asc-beta.yml:48-71`). aktion=probe: setup übersprungen (`:27`), assign (`if: !cancelled() && inputs.aktion=='zuordnen'`) ist false, also übersprungen; probe hat `!cancelled()` und beide Ergebnisse `skipped`, läuft also. aktion=einrichten: setup läuft, assign übersprungen, probe läuft nach setup success. aktion=zuordnen: setup übersprungen, assign läuft dank `!cancelled()` (die Statusfunktion hebt den Skip der Abhängigkeit auf), probe nach assign success. Schlägt assign fehl, läuft die Probe nicht (laut Spec "nach erfolgreichem assign"). Schlüsseldatei: `trap ... rm -f` und `umask 077` in `:63-65`. Der Diff-Stat gegen 3763e57 zeigt `testflight.yml`, `asc_wait_build.py`, `asc_what_to_test.py`, `asc_beta_probe.py` nicht.
- AC-11: `docs/reference/testflight.md:201-209` nennt kein Review, kein Link, umkehrbar, 403-Rückfall, späterer Build braucht neuen Lauf; Prüfliste `:169-171`.
- AC-12 Umfang gemessen (Diff-Stat gegen 3763e57 für scripts, .github, docs/reference): `.github/workflows/asc-beta.yml` 29 Zeilen geändert, `docs/reference/testflight.md` 24 Zeilen im Stat (im Diff rund 34 betroffene Zeilen), `scripts/test_asc_beta_invite.py` 256 neu (schon in Commit 9b2716e); ungesichert dazu `scripts/asc_beta_invite.py` 109 Zeilen. Produktivcode (Skript+Workflow+Doku) rund 109 + 29 + 34 = 172 Zeilen, unter 250. Mit Tests 428, also über der Grenze; die Spec schätzte die Tests auf 100, es sind 256. 2a (Commit 3763e57: Skript 131, Test 253) hatte dasselbe Verhältnis, daher als Muster akzeptiert. Längste Funktion `assign_platform` 13 Zeilen. Kein Pfad der Geräteliste berührt (nur scripts/, .github/workflows/, docs/).

Randfälle, selbst nachgestellt (Wegwerf-Skript im Scratchpad, Nachbau `FakeASC`):
- 404 auf `GET /v1/builds/ID/buildBetaDetail` nach erfolgreichem Zuordnungs-POST: Ausgabe `gruppe name=Tester zustand=angelegt`, dann je Plattform `::error::platform=… ASC answered HTTP 404 for /v1/builds/…/buildBetaDetail`, `zusammenfassung geschrieben=1`, Exit 1; tatsächlich wurden 3 POSTs gesendet (Gruppe + 2 Zuordnungen). Siehe F001.
- 503 auf `GET /v1/builds/ID/betaGroups`: die Wiederholung druckt `ASC answered HTTP 503 for /v1/builds/B-91f3-IOS/betaGroups, retrying`, also die volle Build-ID im Log. Siehe F002.
- `message()`: `/v1/builds/B1/betaGroups` wird zu `/v1/builds/…/betaGroups`; ein Query-Wert wie `?filter[app]=APP1` bleibt unmaskiert (Regex `asc_beta_invite.py:50` kennt nur Pfadstücke). Heute erreicht kein Query den Fatal-Text (`asc_wait_build.py:66`, `asc_what_to_test.py:53` kürzen), daher nur Härtungshinweis F003.

**Implementierer:** (keine Antwort; beide Seiten führt der Prüfer) Die Beweise oben sind eigene Messungen.

### Runde 2
**Adversary:** Nachbohren an den Stellen, die Runde 1 offen ließ.
- 404 auf `GET /v1/builds/ID/betaGroups`: `get_json` wirft `Fatal` (`asc_wait_build.py:76`), `assign_platform` (`asc_beta_invite.py:77`) reicht sie an `main` (`:101-103`), die Plattform wird mit maskiertem Pfad als Fehler gemeldet, die andere läuft weiter, Exit 1, Summary gedruckt. Vor dem Fehler wurde für diese Plattform nichts geschrieben. Korrekt, AC-5 bleibt gewahrt.
- Fehler im Gruppenschritt nach erfolgreichem POST: `ensure_group` (`:62-66`). Schlägt das erneute Lesen nach dem POST fehl oder listet Apple die Gruppe nicht, bricht `main` ab (`:90-93`) ohne `gruppe`-Zeile, die Gruppe existiert aber. Ein erneuter Lauf findet sie als `vorhanden` und arbeitet idempotent weiter, es entsteht kein Doppel durch den Lauf selbst. Ein 5xx auf den POST selbst wird von `send_json` wiederholt (`asc_what_to_test.py:26-42`); hat Apple die Gruppe trotz 5xx angelegt, entstünde eine zweite `Tester`, und der nächste Lauf bräche mit dem Duplikat-Fatal ab (kein Datenverlust, händisch zu löschen). Unwahrscheinlich, LOW (F004).
- Falsche Bilanz nach erfolgreichem POST: `assign_platform` liest `buildBetaDetail` (`:79`) nach dem Schreiben (`:78`); wirft das, geht `written` verloren (`main:98-99`). Das ist F001, per Nachbau bestätigt. Auch die Zeile `zustand=gesetzt` fehlt, obwohl die Zuordnung steht.
- Wiederholungsausgabe der Helfer enthält Kennungen (F002); `test_output_has_only_state_words` (`scripts/test_asc_beta_invite.py:226-234`) prüft nur den Erfolgsweg.
- Workflow-Rand: bei `zuordnen` mit fehlgeschlagenem assign läuft keine Probe. Laut Spec gewollt; ein teilweise geschriebener Zustand bleibt, idempotent behebbar.
- Doku: `docs/reference/testflight.md:166` nennt `Lauf 40387004899` mit `extern=READY_FOR_BETA_SUBMISSION`; offline nicht prüfbar (keine Anfrage an Apple oder GitHub erlaubt), nicht Teil der ACs.
- AC-14 kann nicht bewiesen werden; es gibt keinen echten Lauf. Der Haken bleibt leer.

**Implementierer:** (keine Antwort; beide Seiten führt der Prüfer) Kein Gegenargument aus dem Code zu F001/F002: `apply_plan` zählt erst nach `send_json` (`asc_beta_invite.py:42-45`), die Zählung hängt am Rückgabewert statt am Zustand; die Wiederholungszeilen stammen aus den wiederverwendeten Helfern, die laut Spec nicht geändert werden dürfen.

### Runde 3
**Adversary:** Fixes für F001 bis F003 selbst geprüft; Stand auf neuestem origin/main, `asc_wait_build.py`, `asc_what_to_test.py`, `asc_beta_probe.py`, `testflight.yml` weiterhin ohne Abweichung zu origin/main. `test_asc_beta_invite.py` Ran 14 OK; Gesamtlauf neu in `adversary-test-output.txt`.
- F001 (`scripts/asc_beta_invite.py:93-97`): mein Nachbau mit 404 auf buildBetaDetail liefert jetzt Exit 0, `zuordnung plattform=IOS zustand=gesetzt extern=unbekannt` (ebenso MAC_OS) und `zusammenfassung geschrieben=3`, entsprechend den 3 gesendeten POSTs. Behoben. Nebenwirkung: ein dauerhaft unlesbarer Status ist kein Fehler mehr, nur `extern=unbekannt`; das ist die Entscheidung der Spec ("Zuordnung steht").
- F002 (`:54-64`, `:126`): `Masked` filtert stdout durch `message()`. Mein 503-Nachbau druckt jetzt `ASC answered HTTP 503 for /v1/builds/…/betaGroups, retrying`; keine Build-ID mehr. Behoben. Verfälschung geprüft: `print` schreibt Text und Zeilenende getrennt, jeder Aufruf wird einzeln maskiert, ein Pfad wird nie zerschnitten. Die Zustandszeilen (`gruppe name=Tester zustand=…`, `zuordnung plattform=… zustand=… extern=…`, `zusammenfassung geschrieben=…`) und `::error::platform=…` enthalten weder `/v1/<art>/` noch `?name=`/`&name=`, bleiben also unverändert (Nachbau-Ausgabe oben, Test `test_message_masks_query_values_only`). Die Maskierung ist nur unter `if __name__ == "__main__"` aktiv, die Tests rufen `main` ohne sie auf, prüfen aber über Subprozess den echten Aufruf.
- stderr: ungefiltert. Das Skript und die Helfer schreiben nur per `print` nach stdout; auf stderr gelangt nur ein ungefangener Traceback (Code-Zeilen und Ausnahmetext, etwa `KeyError: 'id'`) oder openssl-Ausgabe, die `make_token` abfängt (`Fatal` ohne Schlüsseltext, nur Exit-Code). Keine ID-Quelle gefunden, Restrisiko gering.
- F003 (`:48-51`): Query-Werte werden maskiert, Ausgabe `/v1/builds?filter[app]=…&a=…`. Behoben.
- F004 bleibt bewusst offen (LOW, Entscheidung des Koordinators).

**Implementierer:** (keine Antwort; beide Seiten führt der Prüfer)

### Runde 4
**Adversary:** Anlass: Lauf 40516649071 (aktion=zuordnen nach PR #720) endete mit `HTTP 403` auf `GET /v1/builds/…/betaGroups`, `geschrieben=1`, Exit 1; der Nachbau hatte die undokumentierte Route erlaubt. Fix geprüft: `scripts/asc_beta_invite.py:90-92` liest die Mitglieder jetzt über `GET /v1/betaGroups/{gid}/relationships/builds?limit=200` (dokumentiert), `plan_assignment` (`:28-33`) vergleicht Build-ID gegen die ID-Menge. `scripts/test_asc_beta_invite.py:92-95` antwortet auf die alte Route jetzt mit 403, `:88-90` kennt die neue. `test_asc_beta_invite.py` Ran 14 OK; RED-Beleg `test-red-403-output.txt` endet mit `failures=10, errors=1`, GREEN-Beleg vorhanden.

Jeder Aufruf des Skripts gegen die Apple-Doku und den echten Lauf:
- `GET /v1/apps?filter[bundleId]` (`asc_wait_build.py:93`): dokumentiert, im echten Lauf erfolgreich (App gefunden).
- `GET /v1/apps/{id}/betaGroups` (`asc_beta_invite.py:69`): dokumentiert; im echten Lauf erfolgreich (`zustand=angelegt` setzt die erneute Lesung voraus).
- `POST /v1/betaGroups` (`:76`): dokumentiert; im echten Lauf erfolgreich (`geschrieben=1`, Gruppe angelegt). AC-1 Gruppenteil damit am echten Apple belegt.
- `GET /v1/builds?filter[app]&filter[processingState]&filter[expired]&sort=-uploadedDate&limit=1&filter[preReleaseVersion.platform]` (`:87`): dokumentiert; im echten Lauf beide Plattformen bis zum nächsten Schritt durchgelaufen, also akzeptiert.
- `GET /v1/betaGroups/{gid}/relationships/builds?limit=200` (`:91`): dokumentiert (Beziehungsliste), im echten Lauf NOCH NICHT gelaufen.
- `POST /v1/betaGroups/{gid}/relationships/builds` (`:34`): dokumentiert, NOCH NICHT gelaufen; mögliche Ablehnung (409/422 für nicht zuordenbare Builds) bleibt offen.
- `GET /v1/builds/{id}/buildBetaDetail` (`:94`): dokumentiert und von `asc_beta_probe.py:136` im echten Lauf benutzt; ein Fehler wird abgefangen.
Der Nachbau kann weiterhin Pfade erlauben, die Apple ablehnt: er prüft Query-Parameter der Relationsliste nicht (Route wird vor `?` abgeschnitten, `limit` ungeprüft), kennt keine Seitenführung und akzeptiert POST auf bereits enthaltene Builds. Undokumentierte Routen antworten dort mit 404 statt 403, beides ist für das Skript ein `Fatal`, der Unterschied bleibt folgenlos. Ein Pfad, den der Nachbau erlaubt und Apple verbietet, ist nach der Durchsicht nicht mehr erkennbar; die zwei nicht gelaufenen Aufrufe sind aber nur dokumentiert, nicht erprobt.

Reicht 200? Apples Obergrenze für `limit` ist 200; das Skript liest nur `data` (`get_data` in `asc_what_to_test.py:45-53`) und folgt `links.next` nicht, die Reihenfolge der Beziehungsliste ist nicht sortierbar. Eine Gruppe, die mehr als 200 Builds enthält, könnte den neuesten Build außerhalb der ersten Seite haben: dann würde er erneut per POST gesendet (Idempotenzbruch, `geschrieben≠0`). Heute enthält die Gruppe höchstens 2 Builds und wächst nur durch Handläufe, also im Moment folgenlos, aber latent (F005, LOW).

**Implementierer:** (keine Antwort; beide Seiten führt der Prüfer)

### Runde 5
**Adversary:** Belege vom echten Apple selbst gelesen (`gh run view <id> --repo henemm/loose-ends --log`, nur lesend, nichts gestartet).
- Lauf 40516649071 (vor Fix): `gruppe name=Tester zustand=angelegt`, danach `##[error]platform=IOS|MAC_OS ASC answered HTTP 403 for /v1/builds/…/betaGroups`, `zusammenfassung geschrieben=1`, Exit 1. Bestätigt den Defekt der alten Route; die Maskierung der IDs (`…`) hat im echten Log funktioniert.
- Lauf 40534641955 (zuordnen nach #721): `gruppe name=Tester zustand=vorhanden`, `zuordnung plattform=IOS zustand=gesetzt extern=READY_FOR_BETA_SUBMISSION`, dieselbe Zeile für MAC_OS, `zusammenfassung geschrieben=2`. Probe danach je Plattform: `gruppe name=Familie intern=ja link=aus url=- feedback=an`, `gruppe name=Tester intern=nein link=aus url=- feedback=an`, `build nummer=122 plattform=IOS|MAC_OS ... extern=READY_FOR_BETA_SUBMISSION einreichung=keine`, `einreichung keine`, `antworten=19 von=19 befunde=0`. Damit sind am echten Apple belegt: AC-1 (Gruppe angelegt in 40516649071, Zuordnung je Plattform gesetzt), AC-2 (neuester gültiger Build 122 je Plattform; die positive Relationsliste und der POST laufen jetzt echt), AC-3 (`link=aus`, `einreichung keine`, kein Review ausgelöst).
- Lauf 40535068594 (zweiter Lauf): `gruppe name=Tester zustand=vorhanden`, beide Plattformen `zustand=vorhanden`, `zusammenfassung geschrieben=0`. AC-4 am echten Apple belegt (die Relationsliste erkennt die Mitglieder).
- Die Probe dieses Laufs meldet `befunde=1` je Plattform: `zugriff abfrage=buildBetaDetail build=118 http=404` (iOS) bzw. `build=121 http=404` (macOS), Zeile `intern=? extern=?`. Bewertung: Es betrifft nicht die zugeordneten Builds (122 lieferte in demselben Lauf `extern=READY_FOR_BETA_SUBMISSION`), die Probe ist unverändert, und im Lauf davor (40534641955) lieferten dieselben Builds 118 und 121 den Zustand ohne Befund. Es ist also ein nicht reproduzierbarer 404 von Apple auf einer älteren Build-Zeile, kein Einfluss auf Gruppe, Zuordnung oder Link. AC-14 verlangt Gruppe, je Plattform eine `build …`-Zeile und `zustand=gesetzt`/`vorhanden`, `geschrieben=0`: alles erfüllt. Nicht beanstandet; als Beobachtung zu vermerken.
- Prüfliste `docs/reference/testflight.md:168-173` gegen die Logs: Familie `intern=ja link=aus feedback=an` (Lauf 40387004899 und 40534641955 bestätigt), Tester angelegt/`intern=nein link=aus` (40516649071, 40534641955 bestätigt), Zuordnung `gesetzt` IOS und MAC_OS, `geschrieben=2` (bestätigt) und `vorhanden`, `geschrieben=0` (40535068594 bestätigt), `einreichung keine` (bestätigt), Öffentlicher Link und Beta-Review offen (richtig, noch nicht getan). Alle Lauf-Links und Zahlen stimmen. Einzige Anmerkung: „Rückmeldeweg erledigt auf Apples Seite“ stützt sich nur auf `feedback=an` der Gruppe, nicht auf eine Rückmeldung eines Testers; für Schnitt 2b-1 vertretbar.
- Gesamtlauf `for t in scripts/test_*.py` neu in `adversary-test-output.txt`: 27 Dateien, 27 OK, 0 FAIL.
- F005 (LOW, Seitenbegrenzung 200) bleibt offen und ohne Folge (Gruppe enthält 2 Builds).
- Voraussetzung: Der Kommentar in #705 mit den Lauf-Links fehlt noch; er ist Teil der Belegform von AC-14 (Ticket), nicht des Codes. Ich setze den Haken auf Grundlage der Läufe und der Prüfliste und verlange, dass der Kommentar folgt.

**Implementierer:** (keine Antwort; beide Seiten führt der Prüfer)

## Befunde

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/asc_beta_invite.py:77-82
  Description: `assign_platform` schreibt per `apply_plan` (Zeile 78), fragt danach `buildBetaDetail` (Zeile 79) mit `get_json`, das bei 404 und anderen 4xx `Fatal` wirft. Schreibzähler und Ausgabezeile gehen dadurch verloren (`main` summiert erst nach der Rückkehr, Zeilen 98-100).
  Spec requirement: AC-4 und Ausgabe — `zusammenfassung geschrieben=<n>` zählt die Schreibaufrufe; Zeile `zustand=gesetzt` je Plattform
  Conflict: Nachbau mit 404 auf buildBetaDetail: 3 POSTs gesendet, Zusammenfassung meldet `geschrieben=1`, keine `zuordnung`-Zeile; die Plattform gilt als Fehler, obwohl die Zuordnung steht. Der zweite Lauf bleibt korrekt (`geschrieben=0`), nur die Bilanz des ersten ist falsch.
  Remediation: das Lesen von `buildBetaDetail` in eigenes try, bei `Fatal` `extern=unbekannt` setzen und die Zuordnung als gesetzt melden; oder `written` in der Ausnahme mitführen.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: spec_violation
  Code reference: scripts/asc_beta_invite.py:42
  Description: `send_json` und `get_json` (wiederverwendet) drucken bei 5xx, 408, 429 Zeilen wie `ASC answered HTTP 503 for /v1/builds/<ID>/betaGroups, retrying` bzw. `for POST /v1/betaGroups/<ID>/relationships/builds`; `message()` (Zeilen 48-50) greift nur auf `Fatal`-Texte.
  Spec requirement: AC-9 — Ausgabe nie Gruppen- oder Build-IDs
  Conflict: per Nachbau mit 503 sichtbar: die Build-ID steht im Lauf-Log eines öffentlichen Repos. IDs sind keine Zugangsdaten, aber die Spec schließt sie ausdrücklich aus, und der Test deckt den Weg nicht ab.
  Remediation: Ausgabe der Helfer im Skript durch `message()` filtern (z. B. `contextlib.redirect_stdout`), oder die Spec auf Fatal-Meldungen begrenzen und das 5xx-Szenario in den Test aufnehmen.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_beta_invite.py:50
  Description: Der Regex maskiert nur `/v1/<art>/<id>`; Query-Werte (`filter[app]=APP1`) bleiben stehen.
  Spec requirement: AC-9
  Conflict: aktuell nicht erreichbar, weil alle Fehlertexte den Pfad ohne Query tragen; nur Härtung.
  Remediation: zusätzlich alles ab `?` abschneiden.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_beta_invite.py:62
  Description: Der POST der Gruppe läuft über `send_json` mit Wiederholung bei 5xx; legt Apple die Gruppe trotz 5xx an, entsteht eine zweite externe `Tester`.
  Spec requirement: AC-8 (Doppel führt zum Abbruch)
  Conflict: der Folgelauf bricht ab statt zu heilen; kein Datenverlust, händisches Löschen nötig.
  Remediation: vor jeder Wiederholung die Gruppenliste neu lesen, oder dokumentieren.

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_beta_invite.py:91
  Description: Die Mitgliederliste der Gruppe wird mit `limit=200` einmal gelesen; `links.next` wird nicht verfolgt, der Nachbau kennt weder Limit noch Seiten.
  Spec requirement: AC-4 — Idempotenz
  Conflict: bei über 200 Builds in der Gruppe könnte der neueste fehlen und erneut gesendet werden. Aktuell höchstens 2 Builds, daher ohne Folge.
  Remediation: `links.next` folgen oder `meta.paging.total` gegen die gelesene Zahl prüfen und bei Abweichung abbrechen.

## Bestätigungen

Confirmation:
  AC: AC-1
  Code reference: scripts/asc_beta_invite.py:59
  Evidence: Attribute und Beziehung exakt wie gefordert; test_first_run_creates_group_and_assigns_both_platforms OK.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/asc_beta_invite.py:16
  Evidence: Abfrageparameter exakt, Plan ohne Abweichung leer (Zeile 32); beide Tests OK.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/asc_beta_invite.py:34
  Evidence: nur POST-Pläne, kein Link, keine Einreichung; Workflow ohne die Begriffe.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/asc_beta_invite.py:39
  Evidence: Plan None schreibt nicht; zweiter Lauf geschrieben=0 im Test (Einschränkung F001 betrifft nur die Bilanz im Fehlerfall).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/asc_beta_invite.py:96
  Evidence: je Plattform eigenes try, failed gemerkt, Summary gedruckt, Exit 1; Test und 404-Nachbau bestätigen.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/asc_beta_invite.py:74
  Evidence: kein-gültiger-build, keine Schreibung, Exit 0.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/asc_beta_invite.py:44
  Evidence: 403 beim Schreiben wird in FORBIDDEN übersetzt; Test OK.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/asc_beta_invite.py:25
  Evidence: Fatal vor dem POST; interne Gruppe zählt nicht (Zeile 24).
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: .github/workflows/asc-beta.yml:52
  Evidence: Bedingungen für probe, einrichten und zuordnen durchgedacht (Runde 1), Probe-Bedingung Zeile 71; Regression test_asc_beta_probe und test_asc_beta_setup grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: docs/reference/testflight.md:201
  Evidence: Handlauf zuordnen beschrieben mit allen geforderten Aussagen, Prüfliste Zeilen 169-171.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: scripts/test_asc_beta_invite.py:1
  Evidence: Produktivcode rund 172 Zeilen (Skript 109, Workflow 29, Doku 34), Tests 256 Zeilen getrennt; unverändert: asc_wait_build.py, asc_what_to_test.py, asc_beta_probe.py, testflight.yml. Kein Pfad der Geräteliste berührt.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: scripts/test_asc_beta_invite.py:137
  Evidence: Gesamtlauf 26 Dateien 0 FAIL (adversary-test-output.txt); RED-Beleg 11 von 11 rot.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/asc_beta_invite.py:126
  Evidence: stdout läuft durch Masked/message(); 503-Nachbau druckt keine Build-ID mehr, test_retry_lines_carry_no_ids und test_output_has_only_state_words grün.
  Status: CONFIRMED

Runde 3: F001, F002, F003 behoben und nachgestellt, AC-9 bestätigt (Code reference: scripts/asc_beta_invite.py:54). F004 (LOW) bewusst offen. AC-14: offen bis zum echten Lauf aktion=zuordnen.

Confirmation:
  AC: AC-14
  Code reference: docs/reference/testflight.md:168
  Evidence: Läufe 40534641955 (gesetzt, geschrieben=2, Probe link=aus, einreichung keine, befunde=0) und 40535068594 (vorhanden, geschrieben=0) gelesen; Prüfliste Zeilen 168-173 stimmt mit den Logs überein; befunde=1 im zweiten Lauf betrifft ältere Builds 118/121, nicht AC-14.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/asc_beta_invite.py:91
  Evidence: am echten Apple: zweiter Lauf geschrieben=0 (Lauf 40535068594), Relationsliste erkennt die Mitglieder.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict Runde 2 (überholt durch Runde 3)

## Verdict Runde 3 (überholt durch Runde 4)

## Verdict Runde 4 (überholt durch Runde 5)

## Verdict
VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:8538db3ad5052dc58df0728543ae1ed09c99670513eafdf09c6230b16f3b1065  .github/workflows/asc-beta.yml
- sha256:47b46fc4c632ac888885936ebda6976b9a163e0203e3bdadc423a4e4ad4e828a  docs/reference/testflight.md
- sha256:d9623e4af2f5888516af3f1892269825328b551ab09e2265f92b3106362a9ea4  scripts/asc_beta_invite.py
- sha256:db75cc6a80a371ab69d76c4b80bead4537f19a0dd2d54a034b4551a2371305df  scripts/test_asc_beta_invite.py

## Prüfbasis

- base: 3c691acdf80551de881128d403ba4139419ea674
- blob:7499e6aae68b2127befd02f780ff6efd364de73a  .github/workflows/asc-beta.yml
- blob:03926bf929b7f9483ff48bbf5c82a50aab79b2c6  docs/reference/testflight.md
- blob:dbbe98ddd43d7f48d4aa76168fad443ecada144c  scripts/asc_beta_invite.py
- blob:41d664d08831ae388806d7098faca505aa060ecf  scripts/test_asc_beta_invite.py

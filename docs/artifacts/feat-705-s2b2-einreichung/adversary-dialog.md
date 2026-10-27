# Adversary Dialog — feat-705-s2b2-einreichung
Spec: docs/specs/feat-705-schnitt-2b2a-datenschutzseite.md
Datum: 2026-10-27 22:11

## Checkliste
- [x] **AC-1:** Im Website-Repo `henemm/henemm-website` liegen `content/legal/loose-ends/_index.md` und `content/legal/loose-ends/privacy-policy/_index.md` auf `main`, eingebracht per PR (kein Direktpush, kein Edit auf dem Server); `hugo --gc --minify --quiet` endet mit Exit 0. Belegt durch PR-Link, Build-Ausgabe und `git log` des Repos.
- [x] **AC-2:** Die Seite nennt als Verantwortlichen HENEMM GmbH, Eichenaue 14, 48157 Münster, vertreten durch den Geschäftsführer Henning Emmrich, E-Mail henning@henemm.com, und verweist auf das Impressum (`/footer-information/imprint/`). Belegt durch `grep` auf diese Angaben in `content/legal/loose-ends/privacy-policy/_index.md` und im ausgelieferten HTML (AC-4).
- [x] **AC-3:** Die Seite gibt den freigegebenen Inhalt von `docs/reference/datenschutz-entwurf.md` wieder (Kurzfassung, was erfasst wird, wo es liegt, Rechte-Tabelle mit allen sechs Rechten und dem Satz zu Fotos, Dateien und Kontakten, „Was Apple dabei übernimmt“ mit den vier Punkten, Kontakt und Löschung) und enthält **keine** Code-Belege: kein Dateipfad, kein Ticket, keine Abschnitte „Beleg im Code“ und „Offen, nicht belegt“. Belegt durch `grep` der Abschnittsüberschriften und der Pflichtsätze ohne Treffer auf `project.yml|xcprivacy|\.swift|#[0-9]{3}` (Ausgabe im Abschlussbericht) und Gegenlesen gegen den Entwurf Absatz für Absatz (Liste der Abweichungen im Bericht, erwartet: keine inhaltliche).
- [x] **AC-4:** Nach dem Deploy antwortet `https://www.henemm.com/legal/loose-ends/privacy-policy/` mit HTTP 200 und enthält „HENEMM GmbH“, „Eichenaue 14“ und einen Kernsatz des Texts. Belegt durch `curl`-Statuscode und `grep`-Zählungen im Bericht und durch `./scripts/verify-live.sh /legal/loose-ends/privacy-policy/` im Website-Repo.
- [x] **AC-5:** Die Repo-Variable `ASC_PRIVACY_POLICY_URL` in `henemm/loose-ends` ist genau `https://www.henemm.com/legal/loose-ends/privacy-policy/` und wurde erst nach AC-4 gesetzt. Belegt durch `gh variable get`.
- [x] **AC-6:** Der Handlauf `aktion=einrichten` auf `main` schreibt die URL bei Apple und sonst nichts: Zeile `lokalisierung locale=de-DE beschreibung=unverändert feedbackEmail=unverändert datenschutzUrl=gesetzt`, `zusammenfassung geschrieben=1`; die Probe desselben Laufs zeigt `lokalisierung locale=de-DE … datenschutzUrl=gesetzt`. Belegt durch den Lauf-Link und die zitierten Log-Zeilen.
- [x] **AC-7:** Ein zweiter Lauf `aktion=einrichten` ist idempotent: `datenschutzUrl=unverändert`, `zusammenfassung geschrieben=0`. Belegt durch den Lauf-Link und die Log-Zeile.
- [x] **AC-8:** `docs/reference/datenschutz-entwurf.md` nennt als Verantwortlichen die HENEMM GmbH (Anschrift, Geschäftsführer, E-Mail, Impressum) und den Status „veröffentlicht“ mit URL und Datum; `docs/reference/testflight.md` führt die Zeile „Datenschutz-URL“ als `erledigt` mit den Lauf-Links und der Probe-Zeile und nennt die gesetzte Variable. Belegt durch Diff (`grep -n "legal/loose-ends" docs/reference/datenschutz-entwurf.md docs/reference/testflight.md` mindestens ein Treffer je Datei).
- [x] **AC-9:** Im Loose-Ends-Repo ändert sich kein Code: kein `scripts/*.py`, kein `.github/`, kein `project.yml`, kein App-Code, kein Pfad der Geräteliste; Diff höchstens die beiden Dokumente (plus die Workflow-Artefakte unter `docs/`), ±250 LoC je Repo, im Website-Repo genau die zwei neuen Content-Dateien. Belegt durch `git diff --stat` beider Repos im Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“
- [x] **AC-10:** Alle vorhandenen Skripttests (`python3 scripts/test_*.py`) sind grün. Belegt durch die Testausgabe im Abschlussbericht.
- [x] **AC-11:** Nichts wird bei Apple eingereicht, kein öffentlicher Link eingeschaltet und nichts auf Hennings Geräten getan: die Probe nach dem Lauf zeigt `einreichung keine` und `link=aus` für `Tester`. Belegt durch die Probe-Zeilen des Laufs aus AC-6.

## Dialog

### Runde 1
**Adversary:** Alles selbst nachgeprüft (Quellen: Website-Klon auf main e05fa0e, Live-Abruf, gh, Lauf-Logs).
- AC-1: PR 75 im Website-Repo = genau `content/legal/loose-ends/_index.md` (+7) und `content/legal/loose-ends/privacy-policy/_index.md` (+79), state MERGED, mergedAt 2026-10-27T20:59:27Z, Branch `docs/loose-ends-datenschutz`, Squash-Commit e05fa0e (2 Dateien). `hugo --gc --minify --quiet` im Klon: Exit 0. statusCheckRollup leer (das Website-Repo hat keine CI-Prüfung; der Build-Beleg ist der lokale Hugo-Lauf).
- AC-2/AC-4: Live `curl` 200; Zählungen im Live-HTML: HENEMM GmbH 2, Eichenaue 14 1, 48157 1, Henning Emmrich 3, henning@henemm.com 1, /footer-information/imprint/ 2, "Es gibt keinen eigenen Server" 1, "Kein eigenes Backend" 1. `./scripts/verify-live.sh /legal/loose-ends/privacy-policy/` -> PASS HTTP 200, exit 0. Rubrikseite /legal/loose-ends/ und Impressum antworten 200. Der Text der Live-Seite ist wortgleich mit dem lokalen Hugo-Build (Textvergleich des article-Elements: identisch, 3658 Zeichen).
- AC-3 Negativprobe: Live-HTML (Entities `&#NNN;` entfernt) gegen die Muster project.yml, xcprivacy, .swift, #NNN (dreistellige Ticketnummer), "Beleg im Code", "Offen, nicht belegt", PrivacyInfo: 0 Treffer.
- AC-5: Variable = `https://www.henemm.com/legal/loose-ends/privacy-policy/` (exakt, `gh variable get`). created_at 2026-10-27T21:00:24Z; die ausgelieferte Datei hat `Last-Modified: 21:00:03 GMT` (Header der Live-Antwort), war also 21 s vorher live; Merge 20:59:27Z. Reihenfolge nach AC-4 belegt (der Abstand ist knapp, aber der Header ist ein Serverbeleg, kein Selbstzeugnis).
- AC-6: Lauf 40583033733 (main, workflow_dispatch, success): `lokalisierung locale=de-DE beschreibung=unverändert feedbackEmail=unverändert datenschutzUrl=gesetzt`, `reviewdetail kontakt=unverändert`, `zusammenfassung geschrieben=1`; Probe (IOS und MAC_OS) `lokalisierung locale=de-DE beschreibung=gesetzt feedbackEmail=gesetzt datenschutzUrl=gesetzt`.
- AC-7: Lauf 40583443351: `datenschutzUrl=unverändert`, `zusammenfassung geschrieben=0`.
- AC-11: beide Läufe: `gruppe name=Tester intern=nein link=aus url=- feedback=an`, `einreichung keine` (IOS und MAC_OS), Job `assign` skipped.
- AC-8/9/10: siehe Runde 2.
**Implementierer:** (nicht beteiligt, Kontextisolierung)

### Runde 2
**Adversary:** Gezielte Angriffe.
- AC-3 Gegenlesen Absatz für Absatz (Entwurf vs. Seite), vollständige Abweichungsliste:
  (a) Neuer Rechte-Abschnitt in Abschnitt 6 (Auskunft/Berichtigung/Löschung, Beschwerde Landesbeauftragte NRW): PO-Entscheidung 2026-10-27 "Ja, wie Gregor"; steht auch im Entwurf (Z. 27-30). Gedeckt.
  (b) Rechte-Tabelle Spracherkennung: "nur, falls das System danach fragt; ein Erklärungstext ist hinterlegt" statt "Text ist hinterlegt (siehe Offen)". PO-gedeckt (der Verweis "siehe Offen" wäre auf der Seite ein toter Verweis, da der Abschnitt nicht übernommen wird). Aber: im Entwurf (Tabelle Z. 65) steht noch die alte Formulierung, siehe F002.
  (c) Änderungssatz "Ändert sich etwas Wesentliches ..." aus dem Vorbild; steht nicht im Entwurf. PO-gedeckt.
  (d) Weitere, im Auftrag nicht genannte, rein formale Abweichungen: Kurzfassung und "Was erfasst wird" in einem Abschnitt 2 zusammengelegt; Reihenfolge Rechte(4)/Apple(5) gegenüber dem Entwurf anders; Abschnittsnummern; Satz "wir sagen nicht mehr zu, als der Code der App belegt" (Entwurf: "als der Code belegt"), nur Wortlaut; "Fragen zu deinen Daten und zur Löschung: an diese Adresse" ersetzt durch "Für alles andere genügt eine E-Mail an die Adresse oben"; Impressumlink als relativer Pfad; Entwurfszusatz "(Henning, 2026-10-27 ...)" nicht übernommen. Alle sechs Rechte, der Satz zu Fotos/Dateien, der Kontakte-Satz und die vier Apple-Punkte sind vorhanden und wortgleich. Keine inhaltliche Zusage hinzugekommen oder weggefallen, die nicht in (a)-(c) liegt. Bewertung: AC-3 nicht verletzt, (a)-(c) vom PO gedeckt.
- AC-3 Restrisiko: Der Entwurf vermerkt unter "Offen" (Z. 109-110), der Löschhinweis zum iCloud-Bereich sei "vor der Veröffentlichung auf einem Gerät gegenzulesen". Die Seite ist veröffentlicht, ohne dass das geschah (Spec: ausdrücklich Out of Scope, braucht Hennings Gerät). Siehe F003.
- AC-8: Diff der beiden Dokumente: Entwurf nennt HENEMM GmbH, Eichenaue 14, 48157 Münster, Geschäftsführer, E-Mail, Impressum, Status "Veröffentlicht am 2026-10-27 unter https://www.henemm.com/legal/loose-ends/privacy-policy/"; testflight.md Zeile Datenschutz-URL "erledigt" mit beiden Lauf-Links, Probe-Zeile, `geschrieben=1`/`0`, Variable. Beide Lauf-Zitate stimmen mit den Logs überein. `legal/loose-ends` je Datei >= 1 (green_run PASS).
- AC-9: Diff gegen HEAD: nur datenschutz-entwurf.md (+14/-4), testflight.md (+3/-2), Workflow-Artefakte; fremde Altänderungen briefings/feat-705-apple-seite-einladung.md und fix-580-*/adversary-dialog.md sind nicht Teil des Schnitts. Kein scripts/, .github/, project.yml, App-Code. Website-Repo: genau zwei neue Dateien. Kein Pfad der Geräteliste berührt.
- AC-10: green_run.sh: 14 PASS, ERGEBNIS: GRÜN, 28 Skripttests rc=0, `abnahme=0 skripttests_fail=0` (Ausgabe in adversary-test-output.txt). Hinweis: test_board.py meldet rc=0 trotz Usage-Zeile (vorbestehend, nicht Teil des Schnitts).
- Angriff auf Lauf 2: Probe IOS meldet `zusammenfassung antworten=19 von=19 befunde=1`: `zugriff abfrage=buildBetaDetail build=122 http=404`, Build 122 dort `intern=? extern=?`. In Lauf 1 war dieselbe Abfrage OK, also vermutlich vorübergehend. Berührt weder AC-7 (Setz-Job: geschrieben=0) noch AC-11 (einreichung keine), ist aber ein Befund in einem als Beleg zitierten Lauf, der in der Doku nicht genannt wird. Siehe F001.
- Angriff auf "nichts eingereicht/geschaltet": `einreichung keine` in 4 Probe-Blöcken, `link=aus` bei Tester; ich habe selbst nichts geschrieben.
**Implementierer:** (nicht beteiligt, Kontextisolierung)

### Runde 3
**Adversary:** Nachprüfung der Korrekturen am Diff von docs/reference/datenschutz-entwurf.md.
- F002 behoben: Tabellenzeile Spracherkennung (Z. 65) lautet jetzt "nur, falls das System danach fragt; ein Erklärungstext ist hinterlegt (siehe Offen)". Gleicher Inhalt wie die Seite; der Verweis "(siehe Offen)" bleibt, ist im Entwurf gültig (Abschnitt "Offen" besteht dort) und fehlt auf der Seite bewusst. Bewertung: behoben.
- F003 behoben: Z. 109-111 lauten jetzt "Die Seite ist seit 2026-10-27 veröffentlicht; das Gegenlesen des Hinweises auf einem Gerät ist weiter offen und vor dem App Store nötig, nur auf Hennings ausdrückliches Wort (#705)." Der überholte Wortlaut "vor der Veröffentlichung" ist weg, der offene Punkt bleibt sichtbar. Bewertung: behoben (der Punkt selbst bleibt Rest in #705, laut Spec Out of Scope).
- F001 bleibt bewusst nicht in der Doku, kommt in Abschlussbericht und #705-Kommentar. Zusammen mit dem Hinweis auf den vorübergehenden 404 (Build 122, Lauf 2; Setz-Job und Einreichungsstatus unberührt) ist das für ein LOW akzeptabel. Bewertung: akzeptiert, Abschlussbericht muss ihn nennen.
- Regressionsprobe: Die übrigen Änderungen des Diffs (Status, HENEMM GmbH, Rechte-Absatz) sind unverändert; keine Änderung an Code oder Skripten.
**Implementierer:** (nicht beteiligt, Kontextisolierung)

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: docs/reference/testflight.md:167
  Description: Die Doku zitiert Lauf 40583443351 als Beleg, verschweigt aber, dass dessen Probe befunde=1 meldet (404 bei buildBetaDetail Build 122, intern=? extern=?); in Lauf 1 war dieselbe Abfrage 200.
  Spec requirement: AC-7 — zweiter Lauf idempotent (erfüllt); Spec Abschnitt 3: Abweichungen werden benannt, nicht schweigend akzeptiert.
  Conflict: Der Befund ist für AC-7 irrelevant (Setz-Job geschrieben=0), wurde aber nicht benannt.
  Remediation: Im Abschlussbericht/#705-Kommentar als vermutlich vorübergehenden 404 benennen; keine Codeänderung.

Finding:
  ID: F002
  Severity: LOW
  Category: anti_pattern
  Code reference: docs/reference/datenschutz-entwurf.md:65
  Description: Tabelle im Entwurf sagt weiter "Text ist hinterlegt (siehe Offen)", die Seite "nur, falls das System danach fragt; ein Erklärungstext ist hinterlegt". Der Entwurf-Kopf (Z. 7-8) verlangt, Änderungen in beiden Stellen zu halten.
  Spec requirement: AC-3 / Entwurf Status — Entwurf bleibt Quelle, Änderungen in beide.
  Conflict: Quelle und Veröffentlichung weichen im Wortlaut auseinander (PO-gedeckt, aber nur einseitig nachgezogen).
  Remediation: Zeile 65 im Entwurf auf den Wortlaut der Seite ziehen (nur Doku).

Finding:
  ID: F003
  Severity: MEDIUM
  Category: edge_case
  Code reference: docs/reference/datenschutz-entwurf.md:109
  Description: Der Entwurf vermerkt, der Löschhinweis zum iCloud-Bereich sei "vor der Veröffentlichung auf einem Gerät gegenzulesen (#705)". Die Seite ist live, der Vermerk steht unverändert, der Status (Z. 3-8) sagt "veröffentlicht". Die Prüfung ist laut Spec Out of Scope und braucht Hennings Gerät und sein Wort.
  Spec requirement: Spec Out of Scope / AC-3 — Löschhinweis "so wie der Entwurf ihn freigab".
  Conflict: Keine Verletzung eines AC, aber ein offener Punkt, der spätestens vor dem App Store geschlossen sein muss; "vor der Veröffentlichung" ist überholt.
  Remediation: Vermerk umformulieren ("nach Veröffentlichung offen, vor App Store gegenzulesen") und in #705 als Rest führen.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: docs/specs/feat-705-schnitt-2b2a-datenschutzseite.md:1
  Evidence: PR 75 merged, genau zwei Dateien, hugo Exit 0 (Website-Klon main e05fa0e).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: docs/artifacts/feat-705-s2b2-einreichung/abnahme_check.sh:14
  Evidence: Live-HTML enthält alle Pflichtangaben und den Impressum-Link; green_run PASS.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: docs/reference/datenschutz-entwurf.md:27
  Evidence: Absatzvergleich, Abweichungen (a)-(c) PO-gedeckt, keine Code-Belege live (0 Treffer).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: docs/artifacts/feat-705-s2b2-einreichung/abnahme_check.sh:13
  Evidence: curl 200, verify-live.sh PASS, Zählungen siehe Runde 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: docs/artifacts/feat-705-s2b2-einreichung/abnahme_check.sh:19
  Evidence: Variable exakt gleich URL; created_at 21:00:24Z nach Last-Modified 21:00:03Z der Seite.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: docs/reference/testflight.md:167
  Evidence: Lauf 40583033733 Log-Zeilen geschrieben=1, datenschutzUrl=gesetzt, Probe gesetzt.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: docs/reference/testflight.md:167
  Evidence: Lauf 40583443351 unverändert, geschrieben=0 (Probe-Befund F001 unabhängig).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: docs/reference/datenschutz-entwurf.md:3
  Evidence: Diff zeigt HENEMM GmbH, Status veröffentlicht mit URL und Datum; testflight.md erledigt mit Läufen.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: docs/reference/testflight.md:196
  Evidence: Diff nur zwei Docs plus Artefakte; Website-PR genau zwei Dateien. Kein Pfad der Geräteliste berührt.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: docs/artifacts/feat-705-s2b2-einreichung/green_run.sh:1
  Evidence: 28 Skripttests rc=0, Ausgabe in docs/artifacts/feat-705-s2b2-einreichung/adversary-test-output.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: docs/artifacts/feat-705-s2b2-einreichung/test-green-output.txt:1
  Evidence: einreichung keine, link=aus für Tester in beiden Läufen.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict Runde 2 (überholt durch Runde 3)

## Verdict

**VERIFIED**

## Geprüfte Dateien

- sha256:57c4e92538fca527b2accd23289eff71999c52377d6f813fafd5303247ac7759  docs/artifacts/feat-705-s2b2-einreichung/abnahme_check.sh
- sha256:b9f7a576310ef26e5eae89b580a3068c8648392ae70a89a6431b2dcd89e2ea59  docs/artifacts/feat-705-s2b2-einreichung/green_run.sh
- sha256:0c892fbc35f0bfdb336018a23f4730a70ec61e4108e962bb0651d9ce10f994cc  docs/artifacts/feat-705-s2b2-einreichung/test-green-output.txt
- sha256:a82990573934b09f65f4b60fea3999f38a6ffb9077648fd1beb22f77eb2ef00d  docs/reference/datenschutz-entwurf.md
- sha256:5a2ad78324985883bc25f90f0eec2768d7e6e576a63dd3ba0d993bb92f28b69a  docs/reference/testflight.md
- sha256:625cdb1701c19650f3828ad44adf0f8f45352428dd3576c5970cceaba2e3c70c  docs/specs/feat-705-schnitt-2b2a-datenschutzseite.md

## Prüfbasis

- base: 8213e7312a9d916df1a1431eaaf922ebdcc140bb
- blob:f6f316879ca9f227fefc1928500bc80c74d69e09  docs/artifacts/feat-705-s2b2-einreichung/abnahme_check.sh
- blob:12159fb349140bd07d60550c036cbe6e237065fc  docs/artifacts/feat-705-s2b2-einreichung/green_run.sh
- blob:6baac540b717994bf8ab5467e3e0f461c4abd2b5  docs/artifacts/feat-705-s2b2-einreichung/test-green-output.txt
- blob:2d0f75be3a3aedb85c53b7d584500a4fc62de548  docs/reference/datenschutz-entwurf.md
- blob:57f1e18943acc51397fee3fafdc7f1b8d38e013c  docs/reference/testflight.md
- blob:fd6be3ac2cff2fdaa0a501d411bc583de351f212  docs/specs/feat-705-schnitt-2b2a-datenschutzseite.md

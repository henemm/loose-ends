---
entity_id: feat-705-schnitt-2b2a-datenschutzseite
type: feature
created: 2026-10-27
updated: 2026-10-27
status: draft
workflow: feat-705-s2b2-einreichung
---

# Spec: #705 Schnitt 2b-2a „Datenschutzseite“: die freigegebene Datenschutzerklärung auf henemm.com veröffentlichen und ihre Adresse bei Apple eintragen

## Approval

- [ ] Approved

## Purpose

Für die erste externe TestFlight-Einladung reicht #705 den Build der Gruppe `Tester` zum Beta-Review ein (Schnitt 2b-2b). Die
Einreichung ist per API nicht zurücknehmbar (Apples OpenAPI: `/v1/betaAppReviewSubmissions` kennt nur GET und POST), und eine
Ablehnung kostet einen Review-Zyklus von Stunden bis Tagen. Apples Hilfe „App privacy“ nennt die Datenschutz-URL für alle Apps
Pflicht, Richtlinie 5.1.1(i) verlangt sie in den Metadaten, und es gibt Forenberichte über Beta-Ablehnungen wegen fehlender
Datenschutzangabe. Ob die API-Einreichung sie technisch erzwingt, ist nicht belegt (Analyse: `docs/context/feat-705-s2b2-einreichung.md`).
Bei Apple ist `privacyPolicyUrl` heute leer (Probe `datenschutzUrl=leer`), und die Repo-Variable `ASC_PRIVACY_POLICY_URL` gibt es nicht.

Schnitt 2b-2a stellt deshalb vor der Einreichung her, was ohnehin gebraucht wird (spätestens vor dem App Store, #342):

1. Der von Henning am 2026-10-27 freigegebene Text (`docs/reference/datenschutz-entwurf.md`, PR #714) wird als öffentliche Seite
   auf `https://www.henemm.com/legal/loose-ends/privacy-policy/` veröffentlicht. Henning: „Du hast Zugriff auf meinen Webspace“,
   Entscheidung: Seite auf henemm.com, durch mich, ohne die Website-Instanz. Verantwortlicher ist wie bei Gregor Zwanzig die
   HENEMM GmbH (Henning, 2026-10-27, Auswahl „HENEMM GmbH“).
2. Die Adresse steht in der Repo-Variable `ASC_PRIVACY_POLICY_URL` von `henemm/loose-ends`.
3. Der vorhandene Handlauf `aktion=einrichten` schreibt sie nach Apple (`datenschutzUrl=gesetzt`); der Setz-Weg in
   `scripts/asc_beta_setup.py` existiert seit Schnitt 2a und wird nicht geändert.

Ohne Modell: Textveröffentlichung und API-Aufruf, kein Modellweg.

**Unwiderrufliches gibt es in diesem Schnitt nicht.** Die Seite entsteht per PR und ist jederzeit änderbar oder entfernbar;
die Variable und die Apple-URL sind überschreibbar. Es gibt keine Einreichung, keinen Link und nichts auf Hennings Geräten.

## Source

- **Website-Repo (privat):** `henemm/henemm-website`, Branch `main`. Neu: `content/legal/loose-ends/_index.md` und
  `content/legal/loose-ends/privacy-policy/_index.md`. Vorbild (nur gelesen): `content/legal/gregor-zwanzig/_index.md` und
  `content/legal/gregor-zwanzig/privacy-policy/_index.md` (Front Matter `title`, `date`, `draft: false`, `showDate: false`,
  `showReadingTime: false`; sechs nummerierte Abschnitte; Verweis aufs Impressum).
- **Loose-Ends-Repo:** `docs/reference/datenschutz-entwurf.md` (Quelle des Textes), `docs/reference/testflight.md`
  (Prüfliste). Wiederverwendet, nicht geändert: `scripts/asc_beta_setup.py` (setzt `privacyPolicyUrl` aus `ASC_PRIVACY_POLICY_URL`,
  leer = nicht anfassen; Ausgabe `datenschutzUrl=gesetzt|unverändert|leer`), `scripts/asc_beta_probe.py` (Ausgabe
  `lokalisierung locale=… datenschutzUrl=gesetzt|leer`), `.github/workflows/asc-beta.yml` (Job `setup` reicht
  `${{ vars.ASC_PRIVACY_POLICY_URL }}` durch).
- **Identifier:** keiner — Inhaltsseiten und Doku, kein Code-Identifier; Apple-Feld `betaAppLocalizations.privacyPolicyUrl`
  (de-DE), Repo-Variable `ASC_PRIVACY_POLICY_URL`.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `henemm/henemm-website` | privates Repo, Hugo-Site | Ort der Seite; Auto-Deploy `main` → `/var/www/henemm` alle 5 min (git pull + `hugo --minify`); nie direkt auf dem Server editieren |
| `docs/reference/datenschutz-entwurf.md` | Doku | freigegebener Text, Quelle der öffentlichen Fassung |
| Repo-Variable `ASC_PRIVACY_POLICY_URL` | GitHub-Variable (`henemm/loose-ends`) | Eingabe für `aktion=einrichten`; eine Variable, kein Secret (die URL ist öffentlich) |
| `scripts/asc_beta_setup.py`, Job `setup` in `asc-beta.yml` | Skript, Workflow | schreibt `privacyPolicyUrl` in die Lokalisierung `de-DE`; seit 2a vorhanden, Schreibrecht belegt (Lauf 40466472742) |
| `scripts/asc_beta_probe.py` | Skript | Beleg nach dem Lauf (`datenschutzUrl=gesetzt`) |
| #342 (Datenschutztext, Board „In progress“), #705, #371 | Tickets | #342 gehört dem Text selbst; hier nur die Veröffentlichung und der Apple-Eintrag |

## Scope

### Affected Files

Loose-Ends-Repo (`henemm/loose-ends`):

| File | Change Type | Description |
|------|-------------|-------------|
| docs/reference/datenschutz-entwurf.md | MODIFY | Verantwortlicher nachziehen (HENEMM GmbH statt Einzelperson), Status „veröffentlicht“ mit URL und Datum, Hinweis, dass die öffentliche Fassung ohne Code-Belege im Website-Repo liegt |
| docs/reference/testflight.md | MODIFY | Prüfliste: Zeile „Datenschutz-URL“ auf `erledigt` mit Beleg (Lauf-Link, Probe-Zeile); im Absatz „Handlauf `einrichten`“ den Satz zur Variable von „offen“ auf den gesetzten Stand ziehen |

Website-Repo (`henemm/henemm-website`, eigener PR):

| File | Change Type | Description |
|------|-------------|-------------|
| content/legal/loose-ends/_index.md | CREATE | Rubrikseite „Loose Ends — Rechtliches“, Aufbau wie Gregor Zwanzig |
| content/legal/loose-ends/privacy-policy/_index.md | CREATE | öffentliche Datenschutzerklärung (Inhalt siehe Implementation Details) |

Außerhalb von Dateien: Repo-Variable `ASC_PRIVACY_POLICY_URL` anlegen; ein Handlauf `aktion=einrichten`, ein zweiter zur
Idempotenz-Prüfung.

### Estimated Changes

- Loose-Ends-Repo: 2 Dateien (ohne die Workflow-Artefakte Spec, Kontext, Protokolle), ca. +20/−8 LoC, **kein Code**.
- Website-Repo: 2 Dateien, ca. +100 LoC Markdown (kein Hugo-Template, kein Layout, keine Konfiguration).
- Zusammen 4 Dateien in zwei Repos, je Repo unter ±250 LoC. Kein Pfad der Geräteliste.

### Code-Änderungen im Loose-Ends-Repo: keine nötig

Geprüft: `asc_beta_setup.py` liest `ASC_PRIVACY_POLICY_URL` (leer = nicht anfassen), schreibt `privacyPolicyUrl` in die
Lokalisierung `de-DE` nur bei Abweichung und druckt `datenschutzUrl=gesetzt|unverändert|leer`; der Job `setup` in
`asc-beta.yml` reicht `vars.ASC_PRIVACY_POLICY_URL` bereits an das Skript. Die Probe druckt `datenschutzUrl=` (nur
`gesetzt`/`leer`, nie den Wert). Der Setz-Weg ist also vollständig, es gibt nichts zu bauen.

### Kein neuer automatischer Test

Ein Unit-Test hätte nichts Eigenes zu prüfen: der Setz-Weg hat seine Tests (`scripts/test_asc_beta_setup.py`, Fall mit gesetzter
und fehlender Variable, seit 2a grün), und ob eine Seite auf henemm.com antwortet und Apple die URL annimmt, kann nur der echte
Aufruf zeigen (wie in 2b-1: die Belege sind echte Läufe). Ein Test, der `www.henemm.com` im Regelbetrieb abfragt, würde die
CI an eine fremde Seite und das Netz hängen und bei jedem Ausfall der Website rot werden. Stattdessen sind die Belege
(AC-4 bis AC-7) maschinell gelesene Antworten: `curl` mit Statuscode und `grep` auf Pflichtangaben, `hugo`-Build-Exit-Code,
`gh variable get`, Zeilen des Handlaufs. Zur Absicherung der Regression laufen die bestehenden Skripttests
(`python3 scripts/test_asc_beta_setup.py`, `test_asc_beta_probe.py`) unverändert grün.

## Implementation Details

### 1. Öffentliche Seite im Website-Repo

Arbeit in einem Wegwerf-Klon von `henemm/henemm-website`, Branch `docs/loose-ends-datenschutz` (kein Edit in `/var/www/henemm/`,
kein Direktpush auf `main`). Zwei neue Dateien:

- `content/legal/loose-ends/_index.md`: Front Matter `title: "Loose Ends — Rechtliches"`, `date: 2026-10-27`, `draft: false`,
  `showDate: false`, `showReadingTime: false`; Inhalt wie die Gregor-Zwanzig-Rubrikseite (Verweis auf die Datenschutzerklärung).
- `content/legal/loose-ends/privacy-policy/_index.md`: Front Matter `title: "Datenschutz — Loose Ends"`, gleiche Schalter,
  `*Stand: 27. Oktober 2026*`. Aufbau wie bei Gregor Zwanzig, nummerierte Abschnitte:
  1. **Wer ist verantwortlich?** HENEMM GmbH, Eichenaue 14, 48157 Münster, Deutschland; vertreten durch den Geschäftsführer
     Henning Emmrich; E-Mail henning@henemm.com; „Weitere Angaben findest du im [Impressum](/footer-information/imprint/).“
  2. **Kurzfassung und was erfasst wird:** Kurzfassung für Nutzer (kein eigener Server, kein Konto, keine Werbung, kein
     Tracking, Sprache wird auf dem Gerät in Text umgewandelt), Abschnitt „Was erfasst wird“ des Entwurfs.
  3. **Wo es liegt:** Gerät und private iCloud (CloudKit), Erinnerungszeit über den iCloud-Schlüsselwertspeicher, kein Backend.
  4. **Welche Rechte und warum:** die Tabelle des Entwurfs (Mikrofon, Spracherkennung, Kamera, Standort „beim Verwenden“,
     Kalender, Mitteilungen; Fotos und Dateien ohne Recht; kein Kontakte-Recht).
  5. **Was Apple dabei übernimmt:** die vier Punkte (Karten, Apple Intelligence, Siri und Kurzbefehle, Diktat auf der Watch),
     ohne Zusage über Apples Verhalten.
  6. **Deine Rechte und Löschung / Änderungen:** Fragen und Löschung an die E-Mail-Adresse, Aufgaben in der App löschen, iCloud-Bereich
     unter „Speicher verwalten“; Änderungen werden mit neuem Stand veröffentlicht.

  **Nicht übernommen** werden die Abschnitte „Beleg im Code“ und „Offen, nicht belegt“ des Entwurfs und alle Dateipfade,
  Ticketnummern und Code-Bezeichner (`project.yml`, `PrivacyInfo.xcprivacy`, `#311` usw.): das sind interne Belege, kein Text für
  Nutzer. Der Inhalt der Aussagen bleibt der freigegebene; es kommt keine neue Zusage hinzu. Der Löschhinweis zum iCloud-Bereich
  beschreibt eine Systemeinstellung und steht in der Veröffentlichung so, wie der Entwurf ihn freigab.
- Vor dem PR: `hugo --gc --minify --quiet` im Klon (Exit 0). PR in `henemm/henemm-website`, Merge durch mich nach grünem Build
  (technische Entscheidung, keine Rückfrage). Danach Auto-Deploy (bis ca. 5 min) abwarten.
- Live-Prüfung: `./scripts/verify-live.sh /legal/loose-ends/privacy-policy/` aus dem Website-Repo und unabhängig davon
  `curl -sS -o body.html -w '%{http_code}' https://www.henemm.com/legal/loose-ends/privacy-policy/` (Erwartung 200); der Rumpf
  enthält „HENEMM GmbH“, „Eichenaue 14“ und mindestens einen Kernsatz des Texts („kein eigenes Backend“ bzw. die Kurzfassung
  „Es gibt keinen eigenen Server“), dazu den Link `/footer-information/imprint/`.

### 2. Repo-Variable

`gh variable set ASC_PRIVACY_POLICY_URL --repo henemm/loose-ends --body "https://www.henemm.com/legal/loose-ends/privacy-policy/"`.
Eine Variable (`vars.`), kein Secret: die Adresse ist öffentlich und soll im Lauf-Log lesbar bleiben. Erst setzen, **nachdem**
die Live-Prüfung 200 meldet (Apple soll nie eine tote Adresse bekommen).

### 3. Handlauf bei Apple

- Erster Lauf: Actions → **ASC Beta Probe** → `aktion=einrichten` auf `main`. Erwartung: `lokalisierung locale=de-DE
  beschreibung=unverändert feedbackEmail=unverändert datenschutzUrl=gesetzt`, `reviewdetail kontakt=unverändert …`,
  `zusammenfassung geschrieben=1` (nur die URL wird geschrieben). Danach die Probe desselben Laufs: `lokalisierung locale=de-DE …
  datenschutzUrl=gesetzt`.
- Zweiter Lauf `aktion=einrichten`: `datenschutzUrl=unverändert`, `zusammenfassung geschrieben=0` (idempotent).
- Eine Abweichung von `geschrieben=1` im ersten Lauf (etwa weil Beschreibung oder Kontakt bei Apple nicht mehr zum Soll passen)
  wird im Abschlussbericht benannt und nicht schweigend akzeptiert.
- 403 („Schlüssel ohne Schreibrecht“) ist für `privacyPolicyUrl` nicht zu erwarten (Schreibrecht auf dieselbe Lokalisierung seit
  Lauf 40466472742 belegt); tritt es doch auf, ist der Rückfall die Oberfläche von App Store Connect, nicht das Umgehen.

### 4. Dokumentation im Loose-Ends-Repo

- `docs/reference/datenschutz-entwurf.md`: Kopfzeile „Status“ auf „veröffentlicht am 2026-10-27 unter
  https://www.henemm.com/legal/loose-ends/privacy-policy/ (Website-Repo `henemm/henemm-website`, ohne die Belegtabelle)“; Abschnitt
  „Verantwortlicher und Kontakt“ auf HENEMM GmbH, Eichenaue 14, 48157 Münster, vertreten durch den Geschäftsführer Henning
  Emmrich, E-Mail henning@henemm.com, Impressum (Henning, 2026-10-27); der Entwurf bleibt die Quelle mit Belegen, die öffentliche
  Seite die Kurzfassung ohne sie; Änderungen am Text gehen künftig in beide.
- `docs/reference/testflight.md`: Zeile „Datenschutz-URL“ in der Prüfliste → `erledigt: veröffentlicht 2026-10-27, bei Apple
  gesetzt` mit Beleg (Link zu den beiden Läufen, `datenschutzUrl=gesetzt`, `geschrieben=1`, `geschrieben=0`, die URL der Seite);
  im Absatz „Handlauf `einrichten`“ der Satz „(gehört zu #342)“ auf den gesetzten Stand (Variable besteht, Wert = die URL oben).

### Alternativen

- **A: Seite auf henemm.com (gewählt, Empfehlung):** bestehende Hugo-Site mit Auto-Deploy, dort liegt schon die Erklärung von
  Gregor Zwanzig, rechtlicher Rahmen (Impressum, Verantwortlicher HENEMM GmbH) schon vorhanden, Domain gehört Henning, Adresse
  ist für den App Store später dieselbe. Nachteil: Änderungen laufen über das private Website-Repo (PR, ca. 5 min bis live).
- **B: GitHub Pages aus `henemm/loose-ends`:** läge beim Code, ohne zweites Repo. Heute nicht eingerichtet (`GET repos/henemm/loose-ends/pages`
  → 404), müsste erst aktiviert werden, die Adresse `henemm.github.io/loose-ends` wäre ein anderer Auftritt als der Rest der
  Rechtstexte, und das Repo ist öffentlich (Entwürfe, Belege). Würde die Entscheidung „henemm.com, ich selbst“ (Henning,
  2026-10-27) kippen, keine ADR.
- **C: Ohne Datenschutz-URL einreichen (2b-2b vor 2b-2a):** spart diesen Schnitt, riskiert aber eine Ablehnung im Beta-Review
  (Richtlinie 5.1.1(i), Forenberichte) und damit Tage Wartezeit; die URL ist vor dem App Store ohnehin nötig. Würde die
  Reihenfolge „erst Datenschutzseite, dann einreichen“ (Henning, 2026-10-27) kippen, keine ADR.
- **D: Die URL einmal in der App-Store-Connect-Oberfläche eintragen statt per Handlauf:** eine Handarbeit weniger im CI-Muster,
  aber nicht belegt und nicht wiederholbar; der Setz-Weg per Skript existiert. Bleibt Notausgang bei 403.

Gekippt wird keine ADR.

## Test Plan

### Automated Tests

Kein neuer Test (Begründung unter „Kein neuer automatischer Test“). Die Belege sind maschinell gelesene Ergebnisse echter
Aufrufe; zusätzlich laufen unverändert:

- [ ] `python3 scripts/test_asc_beta_setup.py` grün (deckt: Variable gesetzt schreibt `privacyPolicyUrl`, Variable fehlt rührt sie nicht an).
- [ ] `python3 scripts/test_asc_beta_probe.py` grün (Probe-Ausgabe `datenschutzUrl=`).
- [ ] `python3 scripts/test_info_plist_sync.py` und die übrigen `scripts/test_*.py` unverändert grün (Regression; der Diff berührt keinen Code).

### Echte Aufrufe (Belege nach der Veröffentlichung)

1. `hugo --gc --minify --quiet` im Website-Klon: Exit 0, beide Seiten werden erzeugt (`public/legal/loose-ends/privacy-policy/index.html`).
2. Nach Merge und Deploy: `curl` auf die Seite, Statuscode 200 und `grep -c` auf „HENEMM GmbH“, „Eichenaue 14“, Kernsatz,
   Impressum-Link je ≥ 1; zusätzlich Kontrolle, dass kein Dateipfad aus dem Entwurf in der Seite steht
   (`grep -E "project.yml|xcprivacy|\.swift|#[0-9]{3}"` ohne Treffer).
3. `gh variable get ASC_PRIVACY_POLICY_URL --repo henemm/loose-ends` gibt genau die URL aus.
4. Handlauf `aktion=einrichten` (erster und zweiter Lauf) mit den Zeilen aus Abschnitt 3; Lauf-Links in #705 und in der Prüfliste.

## Acceptance Criteria

- **AC-1:** Im Website-Repo `henemm/henemm-website` liegen `content/legal/loose-ends/_index.md` und
  `content/legal/loose-ends/privacy-policy/_index.md` auf `main`, eingebracht per PR (kein Direktpush, kein Edit auf dem Server);
  `hugo --gc --minify --quiet` endet mit Exit 0. Belegt durch PR-Link, Build-Ausgabe und `git log` des Repos.
- **AC-2:** Die Seite nennt als Verantwortlichen HENEMM GmbH, Eichenaue 14, 48157 Münster, vertreten durch den Geschäftsführer
  Henning Emmrich, E-Mail henning@henemm.com, und verweist auf das Impressum (`/footer-information/imprint/`). Belegt durch `grep`
  auf diese Angaben in `content/legal/loose-ends/privacy-policy/_index.md` und im ausgelieferten HTML (AC-4).
- **AC-3:** Die Seite gibt den freigegebenen Inhalt von `docs/reference/datenschutz-entwurf.md` wieder (Kurzfassung, was erfasst
  wird, wo es liegt, Rechte-Tabelle mit allen sechs Rechten und dem Satz zu Fotos, Dateien und Kontakten, „Was Apple dabei übernimmt“
  mit den vier Punkten, Kontakt und Löschung) und enthält **keine** Code-Belege: kein Dateipfad, kein Ticket, keine Abschnitte
  „Beleg im Code“ und „Offen, nicht belegt“. Belegt durch `grep` der Abschnittsüberschriften und der Pflichtsätze ohne Treffer
  auf `project.yml|xcprivacy|\.swift|#[0-9]{3}` (Ausgabe im Abschlussbericht) und Gegenlesen gegen den Entwurf Absatz für Absatz
  (Liste der Abweichungen im Bericht, erwartet: keine inhaltliche).
- **AC-4:** Nach dem Deploy antwortet `https://www.henemm.com/legal/loose-ends/privacy-policy/` mit HTTP 200 und enthält
  „HENEMM GmbH“, „Eichenaue 14“ und einen Kernsatz des Texts. Belegt durch `curl`-Statuscode und `grep`-Zählungen im Bericht und
  durch `./scripts/verify-live.sh /legal/loose-ends/privacy-policy/` im Website-Repo.
- **AC-5:** Die Repo-Variable `ASC_PRIVACY_POLICY_URL` in `henemm/loose-ends` ist genau `https://www.henemm.com/legal/loose-ends/privacy-policy/`
  und wurde erst nach AC-4 gesetzt. Belegt durch `gh variable get`.
- **AC-6:** Der Handlauf `aktion=einrichten` auf `main` schreibt die URL bei Apple und sonst nichts: Zeile `lokalisierung locale=de-DE
  beschreibung=unverändert feedbackEmail=unverändert datenschutzUrl=gesetzt`, `zusammenfassung geschrieben=1`; die Probe desselben
  Laufs zeigt `lokalisierung locale=de-DE … datenschutzUrl=gesetzt`. Belegt durch den Lauf-Link und die zitierten Log-Zeilen.
- **AC-7:** Ein zweiter Lauf `aktion=einrichten` ist idempotent: `datenschutzUrl=unverändert`, `zusammenfassung geschrieben=0`.
  Belegt durch den Lauf-Link und die Log-Zeile.
- **AC-8:** `docs/reference/datenschutz-entwurf.md` nennt als Verantwortlichen die HENEMM GmbH (Anschrift, Geschäftsführer, E-Mail,
  Impressum) und den Status „veröffentlicht“ mit URL und Datum; `docs/reference/testflight.md` führt die Zeile „Datenschutz-URL“
  als `erledigt` mit den Lauf-Links und der Probe-Zeile und nennt die gesetzte Variable. Belegt durch Diff
  (`grep -n "legal/loose-ends" docs/reference/datenschutz-entwurf.md docs/reference/testflight.md` mindestens ein Treffer je Datei).
- **AC-9:** Im Loose-Ends-Repo ändert sich kein Code: kein `scripts/*.py`, kein `.github/`, kein `project.yml`, kein App-Code, kein
  Pfad der Geräteliste; Diff höchstens die beiden Dokumente (plus die Workflow-Artefakte unter `docs/`), ±250 LoC je Repo, im
  Website-Repo genau die zwei neuen Content-Dateien. Belegt durch `git diff --stat` beider Repos im Abschlussbericht mit dem Satz
  „Kein Pfad der Geräteliste berührt.“
- **AC-10:** Alle vorhandenen Skripttests (`python3 scripts/test_*.py`) sind grün. Belegt durch die Testausgabe im Abschlussbericht.
- **AC-11:** Nichts wird bei Apple eingereicht, kein öffentlicher Link eingeschaltet und nichts auf Hennings Geräten getan:
  die Probe nach dem Lauf zeigt `einreichung keine` und `link=aus` für `Tester`. Belegt durch die Probe-Zeilen des Laufs aus AC-6.

Kein Pfad der Geräteliste berührt (kein App-Code; `docs/` steht nicht auf der Liste, das Website-Repo ist ein anderes Projekt).
Abnahmestufe: Skripttests plus echte Aufrufe (Build, Live-Abfrage, Handlauf). Es gibt keine App-Änderung, also weder Simulator-
noch Geräteschritt; die Abnahme endet mit diesen Belegen.

## Out of Scope (Schnitte 2b-2b, 2b-2c und anderes)

- **Beta-Review einreichen** (`POST /v1/betaAppReviewSubmissions`, nicht rücknehmbar, nur nach Hennings ausdrücklicher Freigabe):
  Schnitt 2b-2b, eigener Workflow, eigene Spec.
- **Öffentlichen Link einschalten** (Limit 50, erst nach Apples Freigabe, Maskierung von `url=` in der Probe): Schnitt 2b-2c.
- **Änderungen an Skripten, Workflow oder Tests** im Loose-Ends-Repo.
- **Datenschutzhinweis in der App** (Einstellungen, Verlinkung) und **Datenschutzangaben im App Store** (#342).
- **Englische Fassung** der Seite; die App-Beschreibung bei Apple ist `de-DE`.
- **Änderungen an Layout, Navigation, Konfiguration oder Impressum der Website** und an der Seite von Gregor Zwanzig.
- **Gegenlesen des iCloud-Löschhinweises auf einem Gerät** (Hinweis im Entwurf): braucht Hennings Gerät und gehört zu #705 vor dem
  App Store; nichts auf seinen Geräten ohne sein Wort.

## Definition of Done

- [ ] Seite per PR im Website-Repo gemergt, Build-Check grün, nach Deploy live mit HTTP 200 und Pflichtangaben (AC-1 bis AC-4).
- [ ] Repo-Variable `ASC_PRIVACY_POLICY_URL` gesetzt (AC-5).
- [ ] Handlauf `einrichten`: erster Lauf `geschrieben=1` und Probe `datenschutzUrl=gesetzt`, zweiter Lauf `geschrieben=0` (AC-6, AC-7); Lauf-Links in #705.
- [ ] `datenschutz-entwurf.md` und `testflight.md` aktualisiert und gemergt (AC-8); Diff ohne Code (AC-9); alle Skripttests grün (AC-10).
- [ ] Kommentar in #705: Seite und Adresse, Lauf-Links, Hinweis, dass 2b-2b (Einreichen) und 2b-2c (Link) folgen. Ticket #705 bleibt
  offen (`Refs #705`, nicht `Closes`), #342 wird nicht angefasst.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: Veröffentlichung eines freigegebenen Textes auf der bestehenden Website und Eintrag einer URL über den vorhandenen Setz-Weg; kein Code, keine Produktarchitektur, keine Änderung an einer ADR.

## Changelog

- 2026-10-27: Initial spec created

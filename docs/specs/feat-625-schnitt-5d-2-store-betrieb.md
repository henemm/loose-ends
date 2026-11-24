---
entity_id: feat-625-schnitt-5d-2-store-betrieb
type: feature
created: 2026-11-24
updated: 2026-11-24
status: draft
workflow: feat-625-s5d2-store-betrieb
---

# Spec: Store-Betrieb 1.0.2 (Schnitt 5d-2, #625)

## Approval

- [ ] Approved

## GitHub Issue

#625 (Store-Schalter, Einreichung). Schnitt 5d-2; das Issue bleibt offen (`Refs #625`, nie `Closes #625`).
Analyse: `docs/context/feat-625-s5d2-store-betrieb.md` (Abschnitte „Ist-Stand“, „Analysis“, „Technical Approach“, „Alternativen“).
Vorgänger: `docs/specs/feat-625-schnitt-5d-1-store-werkzeug.md` (Werkzeug, PR #993), `docs/specs/feat-625-schnitt-5a-offene-tuer.md` (Tür im Code).

## Für den PO

Die Version 1.0.2 mit der Verbindung zu Claude geht in diesem Schnitt bis kurz vor Apples Prüfung: neuer Bau, Version bei Apple angelegt, Texte, Bilder, Hinweise für Apples Prüfer, offene Tür am Dienst. Du entscheidest drei Dinge: ein datiertes Ja zur Vorlage für das Datenschutz-Etikett, die Aufnahme auf deinem iPhone (du aktualisierst die App in TestFlight und nimmst den Ablauf auf; Claude rührt dein iPhone nie an) und am Ende dein Wort zum Einreichen. Bei der Anmeldung im App-Store-Portal tippst du nur den Passkey, den Rest trägt Claude ein. Ab dem Öffnen der Tür kann sich jeder mit Apple-Konto anmelden (höchstens 20 neue Konten pro Tag, so von dir am 2026-11-22 entschieden).

## Purpose

S5d-1 hat das Werkzeug geliefert, aber bei Apple nichts geschrieben. Dieser Schnitt führt die Handläufe aus: TestFlight-Bau 1.0.2 für iOS und Mac, Versionen anlegen, Texte mit Marketing-Adresse, englische Bilder, Bildschirmaufnahme als Anhang, Datenschutz-Etikett, Tür des Dienstes öffnen, Hinweise für Apples Prüfer schreiben, Vorprüfung `bereit` für beide Plattformen. Eingereicht wird erst nach Hennings ausdrücklichem Wort. Im Repo entstehen nur Belege und eine Betriebsnotiz; App-Code ändert sich nicht.

**Regeln vor Modell:** reine Liefer- und Betriebsarbeit, die Zeile „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue ADR
- **Rationale:** Ausführen vorhandener Handlauf-Werkzeuge (#842, #893, S5d-1) in fester Reihenfolge; kein neues Verfahren, keine neue Abhängigkeit. Die Tür öffnet nur den seit S5a im Code vorhandenen Zweig (`ALLOWED_APPLE_SUBS=*`, `NEW_ACCOUNTS_PER_DAY`); die Entscheidung dazu steht in #625 (PO 2026-11-22) und im Projekt-CLAUDE.md. Keine bestehende ADR fällt bei den Alternativen B bis D.

## Source

- **Betriebsdateien im Repo:** `docs/artifacts/feat-625-s5d2-store-betrieb/` (neu, Belege), `docs/reference/testflight.md` (Betriebsnotiz, ca. +30 Zeilen).
- **Aufgerufene Werkzeuge (unverändert):** Workflows `testflight.yml`, `asc-store-version.yml`, `asc-version-texts.yml`, `asc-store-images.yml`, `asc-review-notes.yml`, `asc-store-submit.yml` mit ihren Skripten `scripts/asc_*.py`.
- **Außerhalb des Repos:** Umgebungsdatei des Dienstes auf `rennwienix` (henemm-infra `loose-ends/`), Deploy mit `scripts/deploy-loose-ends.sh` bei festem Commit; ASC-Web (Datenschutz-Etikett, Anhang der Aufnahme).
- **Eingabedateien:** `docs/reference/app-store-texte.md`, `docs/reference/app-review-notizen.md`, `docs/reference/app-store-datenschutzangaben.md` (Vorlage Etikett).

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `.github/workflows/testflight.yml` | workflow | Bau 1.0.2, Eingabe `what_to_test` Pflicht |
| `scripts/asc_store_version.py` (`lesen`, `anlegen`) | skript | Versionen iOS, dann Mac, Bau-Zuordnung, Gegenprobe |
| `scripts/asc_version_texts.py` | skript | Texte de-DE/en-US mit `marketingUrl` |
| `scripts/asc_store_images.py` | skript | englische Bilder `hochladen`/`platzieren`, de-DE nur lesen |
| `scripts/asc_review_notes.py` | skript | Notizen je Plattform, Anhänge nur lesen |
| `scripts/asc_store_submit.py` | skript | `pruefen` (GET), `einreichen` mit `bestaetigung=1.0.2` |
| `scripts/deploy-loose-ends.sh` (henemm-infra) | skript | Tür öffnen, Dienst neu starten bei festem Commit |
| Henning | person | Aufnahme auf seinem iPhone, datiertes Ja zum Etikett, Passkey im ASC-Web, Wort zum Einreichen |
| S5d-1 (PR #993), S5a, S5c, #984, S1/S4 Datenschutztext | schnitt | gemergt bzw. live; Voraussetzungen |
| Marketing-Seite `https://www.henemm.com/loose-ends/` | seite | muss vor `texte` 200 liefern (2026-11-24 geprüft) |

## Reihenfolge (verbindlich)

Jeder schreibende Schritt: vorher `lesen`, schreibende Aktion nur bei Abweichung, Gegenprobe im selben Lauf, Beleg in `docs/artifacts/feat-625-s5d2-store-betrieb/`; nie löschen, kein POST wird wiederholt.

1. TestFlight-Lauf 1.0.2 (iOS und Mac) mit „Was testen“ (de/en), warten auf `VALID`.
2. `asc-store-version aktion=anlegen` (iOS, dann Mac, Bau-Zuordnung), Gegenprobe.
3. `asc-version-texts` (Marketing-URL erreichbar geprüft) und `asc-store-images` en (ios, mac); de-DE nur lesen.
4. Henning nimmt mit dem 1.0.2-Bau aus TestFlight auf seinem iPhone auf (Erfassen, Detail, Einstellungen › Claude, Anmelden mit Apple, Connector in claude.ai, Konto löschen) und gibt sein datiertes Ja zur Etikett-Vorlage.
5. ASC-Web in Hennings Chrome (er nur Anmeldung per Passkey): Aufnahme als Anhang der iOS- und der Mac-Version hochladen; Datenschutz-Etikett nach Vorlage eintragen, Vorschau gegen Vorlage prüfen.
6. Tür öffnen (`ALLOWED_APPLE_SUBS=*`, `NEW_ACCOUNTS_PER_DAY=20`), Deploy, Gegenprobe.
7. `asc-review-notes aktion=notizen`, danach `asc-store-submit aktion=pruefen`.
8. `asc-store-submit aktion=einreichen -f bestaetigung=1.0.2` nur nach Hennings ausdrücklichem Wort.

Das Etikett (Schritt 5) gilt sofort app-weit und kommt deshalb nicht vor Hennings Ja. Die Tür (Schritt 6) wirkt sofort öffentlich und liegt deshalb direkt vor Notizen und Einreichung, nicht früher.

## Acceptance Criteria

Alle ACs sind vor Phase 8 prüfbar: durch Läufe mit Beleg im Ordner `docs/artifacts/feat-625-s5d2-store-betrieb/` oder durch den Testlauf der Werkzeuge. Ein Beleg nennt Lauf-Link (oder Befehl), Zeit mit Zone, Zustand vorher und nachher.

- **AC-1:** GIVEN `origin/main` mit `MARKETING_VERSION: "1.0.2"` WHEN der TestFlight-Lauf mit nichtleerem `what_to_test` (de und en) gestartet wird THEN endet er grün, Apple meldet je Plattform (iOS, Mac) einen Bau der Vorabversion 1.0.2 als `VALID`, und die Archivprüfungen des Laufs (`LEAccountEnabled` als Bool `true`, `LEApsEnvironment` `production`) sind grün. Beleg: Lauf-Link und `asc-store-version aktion=lesen` mit beiden Bauten.
- **AC-2:** GIVEN `lesen` zeigt vor dem Lauf je Plattform keine Version 1.0.2 WHEN `asc-store-version aktion=anlegen` läuft THEN gibt es danach je Plattform genau eine bearbeitbare Version 1.0.2 (iOS und Mac), der gültige 1.0.2-Bau ist zugeordnet, die Ausgabe trägt `gegenprobe gleich=ja`, und ein späteres `lesen` bestätigt den Zustand. Beleg: Ausgaben von `lesen` vorher, `anlegen`, `lesen` nachher.
- **AC-3:** GIVEN die bearbeitbaren Versionen aus AC-2 und die Marketing-Adresse liefert HTTP 200 WHEN `asc-version-texts aktion=texte` läuft THEN stimmen für de-DE und en-US auf beiden Plattformen alle Felder aus `docs/reference/app-store-texte.md` einschließlich `marketingUrl` (`https://www.henemm.com/loose-ends/`) mit dem Gelesenen überein (Gegenprobe im selben Lauf), und ein zweiter `lesen`-Lauf zeigt keine Abweichung. Beleg: Ausgaben mit dem HTTP-Status der Marketing-Seite.
- **AC-4:** GIVEN die Versionen aus AC-2 WHEN `asc-store-images` für `en` auf `ios` und `mac` mit `hochladen` und danach `platzieren` läuft THEN belegt `lesen` für en-US je Plattform alle Bilder des Manifests in Manifest-Reihenfolge an der bearbeitbaren Version, nichts Fremdes wurde überschrieben, und de-DE wurde nur gelesen (kein Schreibaufruf auf de-DE im Aufrufprotokoll der Läufe). Beleg: `lesen`-Ausgaben vor und nach, Läufe mit Gegenprobe.
- **AC-5:** GIVEN Henning hat auf seinem iPhone mit dem 1.0.2-Bau aus TestFlight die Aufnahme gemacht (Claude hat sein iPhone nicht angerührt, keine Anweisung dazu gesendet außer der Bitte darum) WHEN die Aufnahme im ASC-Web in seinem Chrome (er nur Anmeldung) an iOS und Mac angehängt ist THEN zeigt `asc-review-notes aktion=lesen` je Plattform genau einen Anhang mit dem Dateinamen der Aufnahme; der Beleg hält fest, wer aufgenommen hat und wann, und dass die Aufnahme Erfassen, Einstellungen › Claude, Anmelden mit Apple, Connector in claude.ai und Konto löschen zeigt (Claude hat sie geöffnet und beschrieben, nicht nur gezählt).
- **AC-6:** GIVEN Hennings datiertes Ja zur Vorlage `docs/reference/app-store-datenschutzangaben.md` liegt im Beleg vor (Wortlaut und Datum) WHEN das Etikett im ASC-Web eingetragen wird THEN stimmen die Angaben der Vorschau Punkt für Punkt mit der Vorlage überein (Screenshots, geöffnet und beschrieben, Abweichungen einzeln benannt), und der Beleg zeigt, dass der Eintrag zeitlich nach dem Ja und nach AC-5 liegt; ohne datiertes Ja wird nichts eingetragen und der Schnitt bleibt in diesem Schritt stehen.
- **AC-7:** GIVEN die Umgebung auf `rennwienix` wurde vorher gelesen (nur Namen und die Werte `*` und `20`, nie Konto-Kennungen) und die Schritte AC-2 bis AC-6 sind belegt WHEN `ALLOWED_APPLE_SUBS=*` und `NEW_ACCOUNTS_PER_DAY=20` gesetzt und der Dienst bei festem Commit (`LE_COMMIT`) neu ausgerollt ist THEN antwortet `/health` mit 200, das Startlog enthält kein `door invalid` und kein `config invalid`, die Umgebung zeigt beide Werte, und der Beleg nennt den Commit und die Zeit. Der Schritt liegt zeitlich vor AC-8 und nach AC-6.
- **AC-8:** GIVEN `docs/reference/app-review-notizen.md` (Text aus S5d-1) und eine bearbeitbare Version je Plattform WHEN `asc-review-notes aktion=notizen` läuft THEN stimmt je Plattform das Review-Detail mit der Datei überein (`gegenprobe gleich=ja`, je höchstens ein PATCH, nie wiederholt), und ein folgendes `lesen` zeigt keinen Unterschied.
- **AC-9:** GIVEN AC-2 bis AC-8 erfüllt WHEN `asc-store-submit aktion=pruefen` läuft THEN meldet es für `IOS` und `MAC_OS` je `bereit` und endet mit Ausgang 0; keine belegende Einreichung existiert. Der Beleg ist die vollständige Ausgabe dieses Laufs.
- **AC-10:** GIVEN AC-9 erfüllt WHEN der Schnitt abgeschlossen wird THEN enthält der Beleg genau einen der beiden Zustände. (a) Hennings ausdrückliches Wort zum Einreichen liegt vor (Wortlaut, Datum): `asc-store-submit aktion=einreichen -f bestaetigung=1.0.2` lief genau einmal, die Gegenprobe im selben Lauf meldet für beide Plattformen `WAITING_FOR_REVIEW`, nichts wurde gelöscht oder storniert. (b) Es liegt kein Wort vor: keine Einreichung wurde angelegt (`pruefen` nach dem letzten Schritt meldet weiter `bereit` ohne belegende Einreichung), und der Beleg nennt, dass der Schritt bis zu seinem Wort offen ist. Ein Einreichen ohne Wort ist ausgeschlossen.
- **AC-11:** GIVEN alle Läufe des Schnitts WHEN der Beleg-Ordner geprüft wird THEN gibt es zu jedem schreibenden Lauf einen Beleg mit `lesen` vorher und Gegenprobe im selben Lauf; kein Aufrufprotokoll enthält `DELETE`; kein Schreibaufruf (POST) kommt in einem Lauf doppelt vor; die Zeitstempel der Belege halten die Reihenfolge AC-1, AC-2, AC-3 und AC-4, AC-5, AC-6, AC-7, AC-8, AC-9, AC-10 ein; kein Beleg enthält ein Token, einen Schlüssel oder eine Konto-Kennung.
- **AC-12:** GIVEN `docs/reference/testflight.md` WHEN sie gelesen wird THEN enthält sie eine Betriebsnotiz „Einreichung 1.0.2“ mit der Reihenfolge der acht Schritte, den Belegstellen, dem Satz, dass Etikett und Tür öffentlich wirken und deshalb erst spät kommen, und dem Hinweis, dass die Aufnahme von Henning selbst auf seinem iPhone stammt.
- **AC-13:** GIVEN die Gesamt-Diffliste WHEN sie geprüft wird THEN enthält sie keine Swift-Datei, kein `project.yml`, keine `Info.plist`, keine `.entitlements`, kein `PrivacyInfo.xcprivacy` und keine Workflow- oder Skriptdatei unter `.github/` und `scripts/`, und `python3 -m unittest discover -s scripts -p 'test_*.py'` ist grün (Werkzeug-Tests `test_asc_store_version.py`, `test_asc_version_texts.py`, `test_asc_store_images.py`, `test_asc_review_notes.py`, `test_asc_store_submit.py`).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/artifacts/feat-625-s5d2-store-betrieb/` | CREATE | Belege je Lauf (Ausgaben, Lauf-Links, Etikett-Vorschau, Tür-Gegenprobe, Hennings Worte mit Datum) |
| `docs/reference/testflight.md` | MODIFY | Betriebsnotiz „Einreichung 1.0.2“, ca. +30 Zeilen |
| Umgebungsdatei des Dienstes auf `rennwienix` (henemm-infra, nicht im Repo) | MODIFY | `ALLOWED_APPLE_SUBS=*`, `NEW_ACCOUNTS_PER_DAY=20` |

### Estimated Changes

- Files: 2 im Repo (Beleg-Ordner zählt als eine Stelle), dazu die Server-Umgebung außerhalb des Repos.
- LoC: **App-Code 0**; Doku und Belege ca. +30 Zeilen Notiz, dazu Beleg-Textdateien.
- **Berührte Berechtigungen und Schlüssel:** keine im Repo; kein AppStorage-Schlüssel, kein CloudKit-Schema, keine Audio-Dateien. Die API-Schlüssel der Workflows liegen als Secrets und werden nie ausgegeben.
- **Seiteneffekte (explizit):**
  1. Bei Apple entstehen Versionen 1.0.2 mit Texten, Bildern, Anhang und Hinweisen (nie gelöscht, im Zweifel stehen sie bis zum Einreichen offen).
  2. Das Datenschutz-Etikett gilt app-weit ab Eintrag.
  3. Die Tür öffnet für jeden Apple-Account, höchstens 20 neue Konten pro Tag; bestehende Konten werden nie abgewiesen.
  4. Das Einreichen (nur nach Wort) stößt Apples Prüfung an.
- **Parallele Arbeit:** vor dem Deploy `origin/main` und offene PRs prüfen; Server-Deploy und TestFlight-Läufe gehören zur Sitzung, die #625 hält.
- Kein Pfad der Geräteliste berührt; Stufe 3 entfällt. Hennings iPhone wird nur von ihm selbst benutzt.

## Implementation Details

Ablauf siehe „Reihenfolge (verbindlich)“. Einzelheiten je Schritt:

- **Bau:** `testflight.yml` per manuellem Lauf mit `what_to_test` auf Deutsch und Englisch (Zeilen `de:` und `en:`); nach `VALID` Beleg mit `lesen`.
- **Anlegen:** `anlegen` nimmt die Nummer aus `project.yml`; bei Fatal vor dem Schreiben wird die Ursache behoben, nicht umgangen. Ein Fehler im POST wird nicht wiederholt; ein halbes Ergebnis erkennt der nächste Lauf an der vorhandenen Version.
- **Texte und Bilder:** zuerst `lesen`, danach `texte` bzw. `hochladen` und `platzieren` (nur `en`); de-DE nur gelesen, weil Apple die deutschen Bilder beim Anlegen übernimmt (#842).
- **Aufnahme:** Claude bittet Henning in einer Nachricht, in der alles bereit ist (Bau 1.0.2 in TestFlight verfügbar, Ablauf der Aufnahme in Alltagssprache), um die Aufnahme; er aktualisiert die App selbst. Der Upload im ASC-Web geschieht in seinem Chrome, er meldet sich nur an.
- **Etikett:** nur nach seinem datierten Ja; Eintrag im ASC-Web nach der Vorlage, Vorschau als Screenshot gegen die Vorlage.
- **Tür:** `lesen` der Umgebung, Änderung der beiden Werte, `ssh rennwienix bash -s < …` für den Deploy bei festem Commit, Gegenprobe `/health` und Startlog. Der Monitor des Dienstes wird danach beobachtet (Dienst ist im Monitor als kritisch geführt).
- **Notizen und Vorprüfung:** `notizen`, `lesen`, dann `pruefen`; eine Abweichung wird behoben, bevor der nächste Schritt beginnt.
- **Einreichen:** Claude nennt Henning genau das Wort und den Stand; erst nach seinem getippten Wort läuft `einreichen`. Danach Gegenprobe `WAITING_FOR_REVIEW`.

## Test Plan

### Automated Tests (TDD RED)

Der Schnitt hat keinen Produktcode und keine neue Testdatei. Nachweis sind die bestehenden Werkzeug-Tests (sie schützen die Schreibwege der Läufe) und die Lauf-Belege.

- [ ] Test 1: GIVEN der Stand des Zweigs WHEN `python3 -m unittest discover -s scripts -p 'test_*.py'` läuft THEN grün (insbesondere `test_asc_store_version.py`, `test_asc_version_texts.py`, `test_asc_store_images.py`, `test_asc_review_notes.py`, `test_asc_store_submit.py`); belegt AC-13.
- [ ] Test 2: GIVEN die Beleg-Ordner-Dateien WHEN sie gelesen werden THEN enthält jeder schreibende Lauf `lesen` vorher und Gegenprobe, kein `DELETE`, keinen doppelten POST und keine Geheimnisse; belegt AC-11 (Textsuche über den Ordner, Ergebnis im Beleg).
- [ ] Test 3: GIVEN `asc-store-submit aktion=pruefen` WHEN beide Plattformen geprüft werden THEN `bereit`/`bereit`, Ausgang 0; belegt AC-9.
- [ ] Test 4: GIVEN die Tür nach dem Deploy WHEN `/health` und das Startlog gelesen werden THEN 200 und kein `door invalid`; belegt AC-7.

RED-Hinweis: Es gibt keinen Code, der vor der Änderung rot sein könnte; die Läufe sind der Schalter. Vor jedem Schreiblauf zeigt `lesen` den Ausgangszustand (Abweichung), danach die Gegenprobe (gleich).

Benannte Lücke: Ob Apples Prüfer die Version annimmt, belegt erst Apples Entscheidung und liegt außerhalb dieses Schnitts.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **Gewählt A: mit Aufnahme von Henning, Anhang im ASC-Web** | Henning nimmt auf, Claude lädt im Web hoch | Notizen stimmen (Punkt 1 verweist auf die Aufnahme), Apple fragt bei echtem Gerät nicht nach; kein neues Werkzeug | hängt an Hennings Aufnahme und Anmeldung | — |
| B: ohne Aufnahme einreichen, Notizpunkt 1 auf Schritte umschreiben | spart die Aufnahme jetzt | schneller | Apple verlangte sie bei 1.0 per „Guideline 2.1 – Information Needed“ von einem echten Gerät (#788); Verzug von ein bis zwei Tagen wahrscheinlich, die Aufnahme kommt dann doch | verworfen (PO: A); keine ADR |
| C: Anhang per API (`appStoreReviewAttachments`, neues Werkzeug ca. 150 Zeilen mit Tests) | wiederholbar ohne Web-Anmeldung | Forenbericht (developer.apple.com/forums/thread/776074): 500 beim Video-Upload über diesen Weg; sprengt den Schnitt ohne Nutzen für diese Version | verworfen; keine ADR |
| D: Aufnahme aus dem Simulator ohne Henning | kein Gerät nötig | bei 1.0 verlangte Apple ein echtes iPhone; Ablehnung wahrscheinlich | verworfen; keine ADR |

## Risiken

- **Aufnahme hängt an Henning:** ohne sie bleibt AC-5 offen und der Schnitt wartet; kein Ersatz durch Simulatoraufnahme.
- **Öffentlich wirkende Schritte** (Etikett, Tür, Einreichen): Reihenfolge in AC-6, AC-7, AC-10 festgelegt, jeweils mit Beleg und Gegenprobe; Tür unmittelbar vor Notizen, Monitor beobachtet.
- **Halbes Anlegen** (iOS ohne Mac): der nächste `anlegen`-Lauf legt nur Fehlendes an; nie löschen.
- **Apple lehnt das Anlegen oder ein Feld ab (403/409):** Lauf endet mit Grund, kein zweiter POST; Ursache klären, dann neuer Lauf.
- **Review-Detail fehlt bei der neuen iOS-Version:** `notizen` bricht ab, ohne anzulegen (S5d-1, AC-12 dort); dann eigene Folgearbeit nach Befund.
- **Dienst unter Last nach Öffnen der Tür:** Tagesgrenze 20 neue Konten; Monitor und `/health` beobachten.

## Definition of Done

- [ ] AC-1 bis AC-13 erfüllt; Werkzeug-Tests grün, CI grün
- [ ] PR mit `Refs #625` (nie `Closes #625`), gemergt
- [ ] Abschlussbericht mit dem Satz: „Kein Pfad der Geräteliste berührt.“ (App-Code unverändert; Hennings Aufnahme ist sein eigener Schritt, kein Test auf seinem Gerät durch Claude)
- [ ] Nach diesem Schnitt, nicht Teil der ACs: Apples Prüfung und Freigabe von 1.0.2 (iOS und Mac), danach Stand im Store beobachten
- [ ] Nach diesem Schnitt, nicht Teil der ACs: Gerätepunkte nach Freigabe (Henning mit der Store-Version) und Schließen von #625 erst, wenn die Verbindung zu Claude für Store-Nutzer erreichbar belegt ist
- [ ] #625 kommentiert (Stand S5d-2, offene Punkte), Board-Karte aktuell, Memory geschrieben; Wiedervorlage der Sicherungsfrist (ab 2026-12-07) bleibt in Memory

## Changelog

- 2026-11-24: Initial spec created (Schnitt 5d-2 von #625, Store-Betrieb 1.0.2; PO-Entscheidung Weg A mit Video)

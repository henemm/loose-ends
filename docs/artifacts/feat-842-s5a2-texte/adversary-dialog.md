# Adversary Dialog — feat-842-s5a2-texte
Spec: docs/specs/feat-842-schnitt-5a-2-texte.md
Datum: 2026-11-09 14:53

## Checkliste
- [x] **AC-1:** Given ein Abschnitt mit der Zeile `Neu in dieser Version:`, When die Textdatei gelesen wird, Then steht der Wert als `whatsNew`, 4000 Zeichen sind erlaubt, 4001 sind `Fatal` mit Locale, Feld, Ist- und Soll-Zahl. Belegt durch `test_whats_new_line_is_parsed_and_limited`.
- [x] **AC-2:** Given ein Abschnitt ohne `Beschreibung:` mit mindestens einem von Werbetext und Neu-Text und ohne Schlüsselwörter/Support-URL, When die Datei geprüft wird, Then ist sie gültig; ein Abschnitt ohne Beschreibung mit Schlüsselwörtern oder Support-URL, oder ohne eines der zwei erlaubten Felder, ist `Fatal` vor jeder Anfrage. Belegt durch `test_section_without_description_may_carry_only_promo_and_whats_new`.
- [x] **AC-3:** Given ein Abschnitt mit `Beschreibung:`, When Schlüsselwörter oder Support-URL fehlen, Then bleibt es `Fatal` wie bisher. Belegt durch `test_section_with_description_still_requires_all_three`.
- [x] **AC-4:** Given ein Abschnitt ohne Beschreibung, dessen Sprache bei Apple in der Zielversion nicht existiert, When `texte` läuft, Then `Fatal` mit Locale und es wird nichts geschrieben. Belegt durch `test_section_without_description_for_missing_locale_is_fatal_and_writes_nothing`.
- [x] **AC-5:** Given de-DE existiert in beiden bearbeitbaren Versionen, When `texte` mit einem Abschnitt `## de-DE` (Werbetext, Neu-Text) läuft, Then setzt je Plattform genau ein PATCH nur `promotionalText` und `whatsNew`, und die Gegenprobe ist gleich. Belegt durch `test_de_section_patches_only_promo_and_whats_new`.
- [x] **AC-6:** Given die Mac-Version hat keine Sprache en-US, When `texte` läuft, Then entsteht ein POST mit allen Pflichtfeldern, Werbetext und Neu-Text. Belegt durch `test_missing_mac_en_us_is_posted_with_all_fields_including_whats_new`.
- [x] **AC-7:** Given die Texte stehen bei Apple wie in der Datei, When `texte` erneut läuft, Then wird nichts geschrieben. Belegt durch `test_second_run_writes_nothing`.
- [x] **AC-8:** Given eine `READY_FOR_SALE`-Version, When `lesen` läuft, Then zeigt es ihren Werbetext je Plattform und Sprache (Zeichenzahl und Wortlaut) und schreibt nie. Belegt durch `test_lesen_shows_published_promotional_text_and_never_writes`.
- [x] **AC-9:** Given die echte Textdatei, When sie geprüft wird, Then enthält sie `## en-US` mit Neu-Text und `## de-DE` mit dem unveränderten Werbetext von Version 1.0 und einem Neu-Text, alle innerhalb der Grenzen. Belegt durch `test_repo_text_file_parses_and_fits_limits`.
- [x] **AC-10 (Phase 7, Handlauf):** Given die Handläufe am echten Konto vom Zweig aus, When `texte` zweimal und danach `lesen` bzw. `asc_store_version lesen` laufen, Then schreibt der erste Lauf, der zweite nichts, und der Endstand zeigt für iOS und Mac je de-DE und en-US mit Beschreibung, Schlüsselwörtern, Support-URL, Werbetext und Neu-Text vorhanden (Zeichenzahl > 0 je Feld) und keine Einreichung. Beleg: Protokolle unter `docs/artifacts/feat-842-s5a2-texte/`: `lesen-vorher.log` (Werbetext von 1.0), `texte-1.log` (schreibt, Gegenprobe gleich), `texte-2.log` (alles unverändert), `lesen-nachher.log` und `store-version-lesen.log` (Endstand).

## Dialog

### Runde 1
**Adversary:** Testlauf selbst ausgefuehrt: scripts/test_asc_version_texts.py 27 Tests OK, alle 15 weiteren scripts/test_asc_*.py OK (Ausgabe: docs/artifacts/feat-842-s5a2-texte/adversary-test-output.txt, plus Wegwerf-Skripte im Scratchpad). Randfaelle gegen wanted_texts: Werbetext 171 Zeichen ohne Beschreibung gibt Fatal (de-DE Werbetext hat 171, erlaubt 170); whatsNew 4000 gueltig, 4001 gibt Fatal mit Locale, Feld, Ist, Soll; leerer Werbetext plus Neu-Text gueltig (nur whatsNew); Abschnitt nur Leerzeichen oder leer gibt Fatal; Schluesselwoerter ohne Beschreibung gibt Fatal. write_texts mit Fake: de-DE-PATCH enthaelt nur promotionalText und whatsNew (nie description, keywords, supportUrl); fehlendes en-US mit Beschreibung wird per POST angelegt. Im Modus lesen laufen nur GET (read_state, read_published); im ganzen Skript gibt es nur die Schreibaufrufe POST und PATCH auf Lokalisierungspfaden, kein DELETE, keine Einreichung.
Code reference: scripts/asc_version_texts.py:69
Code reference: scripts/asc_version_texts.py:82
Code reference: scripts/asc_version_texts.py:161
Code reference: scripts/asc_version_texts.py:187
Code reference: docs/reference/app-store-texte.md:54
**Implementierer:** (nicht vorhanden, Kontext isoliert)

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/asc_version_texts.py:240
  Description: Die Vorabpruefung "Abschnitt ohne Beschreibung, Sprache fehlt bei Apple" steht in write_texts (Zeile 205) und laeuft je Version. main schreibt erst iOS (Zeile 243) und bricht bei fehlender Sprache nur auf der Mac-Version erst danach ab. Die iOS-Version ist dann schon geschrieben.
  Spec requirement: AC-4 - Fatal mit Locale und es wird nichts geschrieben
  Conflict: Bei Fehlen nur auf der Mac-Version wird teilweise geschrieben (iOS ja, Mac nein). Der Spec-Test prueft nur eine Version. Mit den realen Daten (de-DE existiert auf beiden, en-US hat Beschreibung und wird per POST angelegt) tritt es nicht auf, es ist ein Randfall. Folge waere ein halber Stand, der beim Wiederholen heilt (Idempotenz).
  Remediation: In main alle Versionen waehlen, localizations je Version lesen und die Pruefung vor dem ersten Schreiben fuer alle Versionen machen (Funktion check_present), erst dann schreiben.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: anti_pattern
  Code reference: docs/reference/app-store-texte.md:58
  Description: Der Platzhalter PLATZHALTER aus Lauf lesen ist ein gueltiger Werbetext (26 Zeichen). wanted_texts und test_repo_text_file_parses_and_fits_limits akzeptieren ihn; texte wuerde ihn in beide bearbeitbaren Versionen schreiben und die Gegenprobe waere gleich.
  Spec requirement: AC-9 - de-DE traegt den unveraenderten Werbetext von Version 1.0
  Conflict: Der Inhalt von AC-9 ist derzeit nicht erfuellt, der Test ist trotzdem gruen. Es fehlt eine Schutzvorrichtung. Folgen sind begrenzt: nur nicht eingereichte 1.0.1, per Folgelauf korrigierbar, aber der Platzhalter koennte so eingereicht werden.
  Remediation: Empfehlung ohne Skriptaenderung hier: Orchestrator ersetzt den Text vor Lauf texte und laesst vorher grep PLATZHALTER auf der Datei laufen. Dauerhaft: wanted_texts lehnt Werte mit dem Wort PLATZHALTER ab (Fatal) und der Repo-Test prueft das; Folgeticket oder Teil dieses Schnitts, wenn LoC-Grenze es zulaesst.

### Runde 2
**Adversary:** Zweiter Angriff auf die Bestaetigungen. Idempotenz: write_locale schreibt nur bei Abweichung (Zeile 194), write_texts zaehlt dann 0 und ruft verify nicht (Zeile 214), so wird ein zweiter Lauf zu "unveraendert". Zustand READY_FOR_SALE ohne Lokalisierungen: read_published gibt einfach keine Zeile aus, kein Absturz und kein Nicht-GET. Leerer Werbetext im Abschnitt wird nicht geschrieben (kann also keinen Apple-Text loeschen), das ist gewollt und im Dokument unauffaellig. Abschnitt de-DE ohne Beschreibung loest in check_required nie einen Pflichtfeld-Fatal aus, mit Beschreibung weiter. Nichts am Hauptpfad der Pruefung widerspricht der Spec. Offen bleibt AC-10 (Handlauf, Phase 7).
Code reference: scripts/asc_version_texts.py:194
Code reference: scripts/asc_version_texts.py:214
Code reference: scripts/asc_version_texts.py:229
**Implementierer:** (nicht vorhanden)

Confirmation:
  AC: AC-1
  Code reference: scripts/asc_version_texts.py:87
  Evidence: whatsNew als LINE_FIELDS-Eintrag (Zeile 25), Grenze 4000, Probe 4000 gueltig, 4001 Fatal mit Locale, Feld, Ist, Soll.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/asc_version_texts.py:76
  Evidence: Ohne Beschreibung nur Werbetext/Neu-Text; Schluesselwoerter oder Support-URL, oder keines der beiden Felder gibt Fatal in wanted_texts, vor jeder Anfrage (main liest die Datei vor read_config).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/asc_version_texts.py:71
  Evidence: Mit Beschreibung werden alle drei REQUIRED geprueft, sonst Fatal.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/asc_version_texts.py:205
  Evidence: Pro Version wird vor dem ersten Schreiben geprueft; fuer eine Version erfuellt, ueber beide Versionen siehe F001 (MEDIUM).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/asc_version_texts.py:194
  Evidence: PATCH enthaelt nur geaenderte Felder aus dem Abschnitt, bei de-DE nur promotionalText und whatsNew; Probe bestaetigt je Plattform genau einen PATCH, Gegenprobe gleich.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/asc_version_texts.py:190
  Evidence: POST mit locale, allen Werten und Relation zur Version; Probe: POST mit description, keywords, locale, supportUrl (in der Probe ohne Werbetext, weil die Datei dort keinen hatte).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/asc_version_texts.py:209
  Evidence: Ohne Abweichung leere changed, Ausgabe "unveraendert", kein Nicht-GET.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/asc_version_texts.py:161
  Evidence: read_published gibt je READY_FOR_SALE-Version Plattform, Version, Locale, Zeichenzahl und Wortlaut aus, nur GET.
  Status: CONFIRMED

Finding:
  ID: F003
  Severity: LOW
  Category: spec_violation
  Code reference: docs/reference/app-store-texte.md:56
  Description: AC-9 im Wortlaut (unveraenderter Werbetext von 1.0) ist inhaltlich offen; Struktur, Neu-Texte und Grenzen sind erfuellt (en-US Zeile 54, de-DE Zeile 59). Vom Auftraggeber als bekannt benannt, kein Mangel des Skripts. Siehe F002.
  Spec requirement: AC-9
  Conflict: Platzhalter statt Originaltext, bis ein Lauf lesen vom Zweig aus ihn liefert.
  Remediation: Platzhalter ersetzen, bevor texte laeuft.

AC-10: in Phase 7 zu belegen (Handlauf am echten Konto vor dem Merge), nicht als BROKEN gewertet.

### Runde 3
**Adversary:** Neulauf nach den Korrekturen zu F001 und F002. Alle 16 Dateien scripts/test_asc_*.py laufen: 16 mal OK, 0 Fehler, 0 uebersprungen, test_asc_version_texts.py 29 Tests (Ausgabe: docs/artifacts/feat-842-s5a2-texte/adversary-test-output.txt).
F001 (Teilschreiben): main waehlt zuerst alle bearbeitbaren Versionen und ruft check_locales_exist, das die Lokalisierungen jeder gewaehlten Version einmal liest und je Version und Abschnitt ohne Beschreibung auf fehlende Sprache prueft; erst danach beginnt die Schreibschleife. Fehlt de-DE nur bei Mac, endet der Lauf mit Fatal "de-DE fehlt bei Apple (MAC_OS)" und es gibt keinen einzigen Nicht-GET, auch nicht fuer iOS (test_missing_locale_on_mac_only_writes_nothing_on_ios_either). Jede Version wird einmal fuer die Vorpruefung geladen (present wird an write_texts weitergereicht, kein zweites Lesen vor dem Schreiben); das weitere Lesen in verify ist die gewollte Gegenprobe. Abschnitte mit Beschreibung (en-US) loesen den Abbruch nicht aus, der POST fuer fehlendes Mac-en-US bleibt erhalten (AC-6 Test gruen).
F002 (Platzhalter): check_no_placeholder prueft jeden Wert jedes Feldes jeder Locale und lehnt das Wort PLATZHALTER ab; der Aufruf steht in main im Zweig texte, vor read_config und vor jeder Anfrage (Test: fake.requests leer). Der Zweig lesen ruft die Pruefung nicht, lesen laeuft mit Platzhalter-Datei und schreibt nichts. Restrisiko: die Pruefung unterscheidet Gross-/Kleinschreibung (ein Text "Platzhalter" ginge durch), nicht relevant fuer den gewollten Schutz des Markers. Idempotenz und PATCH-Umfang unveraendert (write_locale PATCHt nur abweichende Felder; de-DE-Test gruen).
Code reference: scripts/asc_version_texts.py:202
Code reference: scripts/asc_version_texts.py:210
Code reference: scripts/asc_version_texts.py:222
Code reference: scripts/asc_version_texts.py:253
Code reference: scripts/asc_version_texts.py:261
Code reference: scripts/test_asc_version_texts.py:538
Code reference: scripts/test_asc_version_texts.py:548
Code reference: docs/reference/app-store-texte.md:58
**Implementierer:** (nicht vorhanden, Kontext isoliert)

Confirmation:
  AC: AC-4
  Code reference: scripts/asc_version_texts.py:210
  Evidence: Vorpruefung ueber alle gewaehlten Versionen vor dem ersten Schreibaufruf; F001 behoben und durch Test belegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: docs/reference/app-store-texte.md:58
  Evidence: Struktur, Neu-Texte und Grenzen belegt; der Werbetext von 1.0 ist vorlaeufig PLATZHALTER, texte lehnt ihn per check_no_placeholder (scripts/asc_version_texts.py:202) ab, bis er per Lauf lesen vom Zweig aus eingesetzt ist (Phase 7). F002 behoben, F003 bleibt als dokumentierter Phase-7-Vorbehalt.
  Status: CONFIRMED

Vorbehalte (kein BROKEN): AC-10 ist laut Spec ein Handlauf am echten Konto in Phase 7 und noch offen; AC-9 hat bis dahin den Platzhalter. F001 und F002 sind behoben (Status RESOLVED); F003 LOW bleibt als Phase-7-Vorbehalt.


### Nachtrag Handläufe (AC-9, AC-10, vom Orchestrator nach dem Commit)
Zweig-Läufe am echten Konto (Dispatch --ref feat-842-s5a2-texte), Protokolle unter docs/artifacts/feat-842-s5a2-texte/:
- lesen-vorher.log (Run 42635418969): veröffentlichte Version 1.0, iOS und Mac de-DE Werbetext zeichen=139, gleich; unverändert in docs/reference/app-store-texte.md übernommen, Platzhalter ersetzt (AC-9 inhaltlich erfüllt; Code reference: docs/reference/app-store-texte.md:59).
- texte-1.log (Run 42635701401): geschrieben=4 (iOS: en-US Neu-Text, de-DE Werbetext + Neu-Text; Mac: en-US komplett per POST, de-DE), Gegenprobe gleich=ja je Plattform.
- texte-2.log (Run 42635873747): en-US/de-DE unverändert je Plattform, geschrieben=0.
- store-version-lesen.log (Run 42636008124): IOS und MAC_OS je de-DE (1638/100/139/116/50) und en-US (1493/94/125/99/50) mit Beschreibung, Schlüsselwörtern, Werbetext, Neu-Text, Support-URL; beide 1.0.1 PREPARE_FOR_SUBMISSION, nichts eingereicht. lesen-nachher.log: Run 42636003982.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERIFIED

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Umsetzung hat den Angriff ueberstanden; F001 und F002 sind behoben und belegt. Zwei dokumentierte Phase-7-Vorbehalte: AC-10 (Handlauf am echten Konto) und der Platzhalter im de-DE-Werbetext (AC-9 Inhalt), den texte nicht schreibt.
Tests: 16 Dateien OK (davon test_asc_version_texts.py 29 bestanden), 0 failed, 0 uebersprungen
Edge cases: alle geprueft, keine gebrochen
Regressions: None found
Checklist: 10/10 belegt (AC-10 durch Handläufe, siehe Nachtrag)

## Geprüfte Dateien

- sha256:fd920cbb371ec7da3fc4e388085977709d4de29088e4b1c27b1c88db0e511ce3  docs/reference/app-store-texte.md
- sha256:d5270106c9b10738d6bb6134950a015edb7333381128cb19050bdd351316709b  scripts/asc_version_texts.py
- sha256:17ee28c9a3bc7f1f1fce121ecbb505b27ca3e5cef687606244c6b530e530df69  scripts/test_asc_version_texts.py

## Prüfbasis

- base: 0e8d14493931e7e29b0ea09e0d20a656012a1a85
- blob:c203dabab3838045b73faa41c711f92aa7b5357d  docs/reference/app-store-texte.md
- blob:c16bda85af0e76600b13d2c2c77f7c0d26f86455  scripts/asc_version_texts.py
- blob:f0ebd05d17076c6e11d0903957f9f3e0867d01b0  scripts/test_asc_version_texts.py

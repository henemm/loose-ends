# Eine dritte Sprache ausliefern (#762, Epic #750)

Stand: 2026-10-31. Entscheidung: ADR-10 in `docs/project/00-entscheidungen.md`. Eine Sprache ist ausgeliefert, wenn sie in
`LanguagePacks.shipped` (`Shared/Language/LanguagePack.swift`) steht, und dort steht sie erst, wenn alle acht Punkte erfüllt sind.
Die Liste ist die einzige Sprachliste; Skripte lesen sie mit `scripts/shipped_languages.py`.

## Die acht Punkte

1. **Sprachpaket.** Eine Datei im Ordner `Shared/Language/` mit `static let <name> = LanguagePack(code: "xx", …)` nach dem
   Muster von `Shared/Language/EnglishPack.swift` und `Shared/Language/GermanPack.swift`: Wochentage, Monate, Tageszeiten,
   Uhrzeit- und Dauerwörter, Wichtigkeit und Dringlichkeit, Ortsphrasen, Titel-Einleitungen, Etiketten-Wörter. Wörter stehen gefaltet,
   außer Wichtigkeit, Dringlichkeit, Etiketten und Titel-Datumswörter. Die Konformitätstests
   (`LooseEndsTests/Language/LanguagePackConformanceTests.swift`) laufen über alle Sprachen: kein Wort mit zwei Werten, keine leere
   Tabelle ohne Eintrag in der Ausnahmeliste, jedes Wort gefaltet. Das Testpaket `LooseEndsTests/Language/TestPack.swift` und der
   Testhaken `LanguagePacks.active` zeigen, dass ein Paket jedes Feld erreicht (`LooseEndsTests/Language/LanguagePackPluggingTests.swift`).
2. **Texte der Oberfläche.** Eine Spalte `xx` in allen fünf Katalogen: `LooseEnds/Resources/Localizable.xcstrings`,
   `LooseEnds/Resources/AppShortcuts.xcstrings` (mit den Siri-Namen der Kurzbefehle), `LooseEndsWidgets/Localizable.xcstrings`,
   `LooseEndsWatchWidgets/Localizable.xcstrings`, `LooseEndsShare/Localizable.xcstrings`; dazu eine InfoPlist-Datei im Ordner `xx.lproj` neben `LooseEnds/Resources/de.lproj/InfoPlist.strings`
   (Berechtigungstexte, App und Watch bündeln dieselbe Datei) und das Wort für das Knäuel (englisch „the Tangle“, #758). Der Wächter
   `scripts/test_catalog_languages.py` prüft Vollständigkeit je Sprache aus `shipped`.
3. **Korpus und Schwelle.** Mindestens 50 Datumssätze mit `"lang": "xx"` in `Measurement/date-title-corpus.json`. Die Regelspalte je
   Sprache steht im Bericht `docs/reference/date-title-fidelity.md`. Schwelle: Datum mindestens 99 % exakt, 0 % erfunden, Dringlichkeit
   und Etiketten nicht unter den englischen Werten (`docs/reference/textform-rules.md`). Darunter bleibt das Paket im Code, aber nicht
   in `shipped`. `LooseEndsTests/DateParserCorpusTests.swift` erzwingt die Marke je Sprache.
4. **Modell-Prompt. Stufe 3, einziger Gerätepunkt.** Der Prompt in `Shared/Enrichment/FoundationModelsEnricher.swift` nennt die Sprache
   mit ihrem Namen; `LooseEndsTests/Language/ModelPromptLanguagesTests.swift` erzwingt das. Ob Apple Intelligence die Sprache liefert,
   zeigt nur das Gerät (`docs/reference/modell-verfuegbarkeit.md`, Abschnitt Sprache); dieser Punkt braucht Hennings „jetzt ist ein Test
   möglich“.
5. **Spracherkennung.** Folgt der Gerätesprache (`LooseEnds/Speech/SpeechCapture.swift`, `SpeechTranscriber.supportedLocale(equivalentTo: .current)`).
   Nichts zu tun; prüfen, ob Apple die Sprache für die Diktierfunktion kennt.
6. **Vertrieb.** Die Locale in `scripts/asc_locales.py`; ein Abschnitt `## xx-XX` in `docs/reference/beta-beschreibung.md` und eine
   Sprachzeile `xx:` im Text „Was testen“ (`scripts/asc_what_to_test.py`); die Datenschutzseite in dieser Sprache auf der Website
   (Repo `henemm/henemm-website`, `content/legal/loose-ends/`), ihr Text in `docs/reference/datenschutz-entwurf.md` und ihre URL in
   `scripts/asc_beta_setup.py`.
7. **UI-Smoke.** Die Matrix `ui-smoke-lang` in `.github/workflows/ci.yml` nimmt die Sprache aus `shipped` von selbst. Die Wörter, die die
   zwei Klassen vom Bildschirm lesen, kommen in `LooseEndsUITests/LaunchLanguage.swift` (`phrases`); ohne sie scheitert der Lauf mit dem Namen der Sprache.
8. **Erst dann** der Eintrag in `shipped`. Ein Eintrag davor lässt die Wächter dieser Liste und die Matrix einen Zustand prüfen, der noch nicht gilt.

## Was keine Sprache braucht

Stellen mit `Locale.current` (Datumsformate, Zahlen, Sprachname in der Diagnose, Erkennungssprache) folgen dem Gerät und kennen die
Liste nicht. Die Wortregeln dagegen lesen alle ausgelieferten Sprachen zugleich (Denglisch im Korpus; es gibt kein Sprachfeld im Produkt).

## Ausnahme: Widget-Texte (#758)

Änderungen in `LooseEndsWidgets/`, die nur Katalogschlüssel oder Textliterale betreffen, enden nach Stufe 2 (Katalogwächter grün und
Screenshot der Widget-Galerie im Simulator). Layout, Logik, Intents und `Info.plist` bleiben Stufe 3 (`CLAUDE.md`).

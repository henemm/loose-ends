---
entity_id: feat-233-wortliste-lernt
type: feature
created: 2026-10-07
updated: 2026-10-22
status: in-progress
workflow: feat-233-wortliste-lernt
---

# Spec: #233 — Kontext-Wortliste lernt aus eigenen Zuordnungen

## Approval

- [x] Approved (Henning, 2026-10-22: N = 1 wie gemessen; Anzeige als Zeile unter dem Etikett)

Die Produktentscheidung steht im Issue (Henning, 2026-10-06): Die Wortliste aus #232 wächst aus
eigenen Zuordnungen; gelernte Wörter sind sichtbar und löschbar. Diese Spec legt nur die Technik fest.

**Ergebnis der Messung (Schnitt 1, gemerged):** Die vorab festgelegte Regel wählt **N = 1**
(`docs/reference/context-word-learning.md`: fest + gelernt 32 % statt 12 % exakte Treffer, Anteil fremder
Etiketten unter den gesetzten 36 % statt 42 %). Henning hat N = 1 am 2026-10-22 bestätigt; N = 2 erfüllte die
Regel ebenfalls, lernt aber erst aus zwei verschieden formulierten Aufgaben.

**Anzeige (Henning, 2026-10-22):** Auf der Seite „Etiketten“ steht unter jedem Etikett grau
„Erkennt: Hecke, Rasen …“. Tippen auf die Zeile öffnet die Wortliste; Wischen löscht ein Wort, und es wird
für dieses Etikett nie wieder gelernt.

## Purpose

Das Modell kann auf dem Gerät nicht nachtrainiert werden, und Prompt-Beispiele tragen nur bei fast
wortgleichem Text (#131). Fast wortgleichen Text deckt die Wiedererkennung ab (#136). Für **neu
formulierte** Aufgaben bleibt die Wortliste (#232) — und die soll aus Hennings eigenen Zuordnungen
wachsen statt nur aus den sechs handverlesenen Listen.

**Ohne Modell:** Es gibt keinen Modellanteil. Lernen ist Zählen.

## Regel

- Eingang: Rohtexte mit den Kontexten, die der Nutzer selbst gesetzt hat (Ursprung `user`).
- Wörter: `RawTextWords`, normalisiert, ab vier Zeichen (Schwelle aus #131), keine reinen Zahlen,
  keine Füllwörter (feste Liste: Funktionswörter, Wochentage, Zeitwörter, DE/EN).
- Gezählt wird über **verschiedene** Wortmengen je Kontext: Dieselbe Notiz zehnmal ist eine Zuordnung.
- Ein Wort kommt zu Kontext K, wenn es bei mindestens N Zuordnungen zu K vorkommt und bei keiner zu
  einem anderen Kontext. Eine Aufgabe mit zwei Kontexten macht ihre Wörter damit zum Konflikt.
- Vom Nutzer gelöschte Wörter werden für diesen Kontext nie wieder gelernt.
- Treffer: ganzes Wort, groß/klein und Umlaute egal; kein Präfix-Treffer wie bei den festen Listen
  („Rasen" gelernt trifft nicht „Rasenmäher"), weil ein gelerntes Wort kein geprüfter Wortstamm ist.

## N messen (DoD 1)

Auslass-Test auf dem FocusBlox-Korpus wie #131, aber je **verschiedenem Text** (50 Prüffälle): Gelernt
wird aus allen Aufgaben mit anderem Text. Spalten: Konstante, feste Wortliste #232 (Regelspalte),
gelernt allein, fest + gelernt, je N = 1 … 5; „fremd" zählt gesetzte Kontexte, die die Aufgabe nicht
trägt.

**Vorab festgelegte Regel:** Gewählt wird das kleinste N, bei dem „fest + gelernt" mehr Aufgaben exakt
trifft als die feste Liste allein **und** der Anteil fremder Kontexte unter den gesetzten Aufgaben nicht
steigt (leer schlägt geraten). Erfüllt kein N die Regel, geht die gelernte Liste nicht in den
Produktpfad; Schnitt 2 entfällt, und das Issue wird mit dem Bericht als Beleg geschlossen.

Bericht: `docs/reference/context-word-learning.md`, geschrieben von
`LooseEndsTests/ContextWordLearningReportTests.swift` (gegattert auf den gitignorierten Korpus, läuft
nur auf Hennings Mac).

## Schnitte

| Schnitt | Inhalt | Dateien |
|---|---|---|
| 1 (gemerged) | Reine Lernregel, Unit-Tests (Lernen, Konflikt, Löschen, Füllwörter, Treffer), Messbericht | `Shared/Enrichment/ContextWordLearning.swift`, `LooseEndsTests/ContextWordLearningTests.swift`, `LooseEndsTests/ContextWordLearningReportTests.swift` |
| 2a | Gelernte Wörter im Regelschritt: `EnrichmentCoordinator.learnedWords` lernt einmal je Durchlauf aus allen Aufgaben mit Etiketten vom Ursprung `user` (nie Regel- oder Modellwert, #244), fest + gelernt zusammen wie gemessen, auch für Zeilen unter einer Aufgabe (#565); Begründung „Aus „Wort“ in der Notiz, gelernt aus deinen Etiketten.“ | `EnrichmentCoordinator`, `ContextWordLearning` (N, Begründung), `LooseEndsTests/ContextWordLearningCoordinatorTests.swift` |
| 2b | Gestrichene Wörter je Etikett im Modell (`TaskContext.forgottenWordsRaw`, additiv, `cloudkit/schema.ckdb`), Zeile „Erkennt: …“ auf der Etiketten-Seite in der Schreibweise des Nutzers (`ContextWordLearning.spelled`), `LearnedWordsSheet` mit Wischen „Vergessen“ (`CatalogService.forget`) | `TaskContext`, `CatalogService`, `CatalogPage`, `LearnedWordsSheet`, `LooseEndsTests/ContextWordForgettingTests.swift` |
| offen | Markierung des gelernten Worts im Zitat des Feld-Editors (#101): der Editor kennt nur die eine Aufgabe, die gelernte Liste bräuchte alle — eigenes Ticket, falls Henning es vermisst | `RuleTrigger`, `FieldEditorView` |

Schnitt 2a berührt `EnrichmentCoordinator.swift`, Schnitt 2b `Shared/Models`: beide stehen auf der Geräteliste
(Stufe 3, über TestFlight). Henning hat am 2026-10-22 beide Schnitte freigegeben.

## Acceptance Criteria

- AC-1: Ein Wort, das bei N verschiedenen eigenen Zuordnungen zu K steht und bei keinem anderen
  Kontext, ist gelernt; bei N − 1 nicht.
- AC-2: Derselbe Rohtext mehrfach zählt einmal.
- AC-3: Ein Wort bei zwei Kontexten gehört keinem — auch wenn eine Aufgabe beide trägt.
- AC-4: Ein gelöschtes Wort wird für diesen Kontext nicht wieder gelernt, für andere Kontexte wirkt
  die Löschung nicht.
- AC-5: Füllwörter, Zahlen und Wörter unter vier Zeichen werden nie gelernt.
- AC-6: Der Bericht trägt die Regelspalte als Baseline und nennt das gewählte N nach der Regel oben.
- AC-7 (2a): Eine neu formulierte Aufgabe mit einem gelernten Wort bekommt das Etikett mit Ursprung Regel,
  Konfidenz 1.0, einer Regel-Revision und einer Begründung, die das Wort nennt; feste und gelernte Treffer
  ergänzen sich, die feste Liste begründet, wo sie trifft.
- AC-8 (2a): Gelernt wird nur aus Etiketten, die der Nutzer gesetzt hat; eine Zeile unter einer Aufgabe liest
  gelernte Wörter wie eine Aufgabe.
- AC-9 (2b): Unter jedem Etikett stehen die gelernten Wörter; ein gelöschtes Wort verschwindet sofort aus der
  Zeile und wird für dieses Etikett nie wieder gelernt, auf jedem Gerät.

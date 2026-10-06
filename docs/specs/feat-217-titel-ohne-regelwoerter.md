---
entity_id: feat-217-titel-ohne-regelwoerter
type: feature
created: 2026-10-06
updated: 2026-10-06
status: draft
workflow: feat-217-titel
---

# Spec: #217 — Erkannte Begriffe verlassen den Titel (mit #214: „wichtig“ setzt Wichtigkeit)

## Approval

- [ ] Approved

## Purpose

Henning (#217): Aus „Morgen wichtig Steuerbescheid prüfen“ wird heute der Titel „Morgen wichtig
Steuerbescheid prüfen“. Fälligkeit und Wichtigkeit stehen aber schon als Felder da. Erwartet wird
„Steuerbescheid prüfen“. Seit #202 setzt `TitleRule` den Titel beim Erfassen aus dem Rohtext, ohne
etwas zu entfernen.

#214 gehört dazu: Das Wort „wichtig“ setzte bisher keine Wichtigkeit. Ohne #214 bliebe es im Titel
stehen, weil nur Wörter verschwinden, deren Feld eine Regel setzt.

## Regel statt Modell

Kein Modell nötig: Die Regeln wissen, welche Wörter sie gelesen haben (`DateExpressionParser.span`,
`TimeExpressionParser.span`, `ImportanceUrgencyRule.importanceMarker/urgencyMarker`). Das Ergebnis ist
deterministisch und testbar.

## Entscheidungen (Henning, 2026-10-06)

- Kleine Wörter direkt vor Datum oder Uhrzeit gehen mit: „bis“, „am“, „um“, „ab“, „bis zum“;
  englisch „by“, „on“, „at“ (und „on the“/„by the“ vor „12th“).
- Bei Wichtigkeit und Dringlichkeit gehen nur die ausdrücklichen Wörter: „wichtig“, „sehr wichtig“,
  „important“, „dringend“, „sofort“, „jetzt“, „eilt“, „asap“, „urgent“ … Inhaltswörter wie
  „Rechnung“, „Finanzamt“ oder „Frist“ setzen das Feld weiter, bleiben aber im Titel.
- Die Uhrzeit geht mit, wenn die Fälligkeit sie trägt: „Morgen um 15 Uhr Zahnarzt anrufen“ →
  „Zahnarzt anrufen“. Eine Uhrzeit ohne Tag setzt keine Fälligkeit und bleibt.

## Verhalten

- Ein Wort geht nur, wenn seine Regel das Feld setzt: dieselben Regeln wie der Regelschritt, mit
  dem Erfassungszeitpunkt als Bezug.
- „und“/„and“ zwischen zwei gestrichenen Wörtern geht mit („Dringend und wichtig: …“).
- Satzzeichen direkt nach einem gestrichenen Wort gehen mit, Anführungszeichen und Klammern bleiben.
- Bleibt nichts übrig, behält der Titel alle Wörter.
- Die zwölf Wörter (#202) zählen nach dem Streichen.
- Der Rohtext bleibt unverändert und erscheint im Detail als „Du hast gesagt: …“, sobald er vom
  Titel abweicht.
- „Zurücksetzen“ eines Modelltitels führt auf den Regeltitel, jetzt ohne die Regelwörter.

## #214: „wichtig“

- Neues Signal mit höchster Priorität: „sehr wichtig“, „wichtig“, gebeugte Formen, „very
  important“, „important“. Begründung: „Aus dem Wort „wichtig“ in der Notiz.“
- Verneint zählt nicht: „nicht wichtig“, „nicht so wichtig“, „not very important“. „unwichtig“
  hält die Wortgrenze fern. Eine Verneinung zwei Wörter vorher ohne Verstärker zählt nicht
  („Nicht vergessen: wichtig …“).

## Beispieltabelle (Bezug: Mittwoch, 7. Okt. 2026, 12 Uhr)

| Rohtext | Titel |
|---|---|
| Morgen wichtig Steuerbescheid prüfen | Steuerbescheid prüfen |
| Geschenk für Anna bis Freitag besorgen | Geschenk für Anna besorgen |
| Bis zum 15. die Miete überweisen | Die Miete überweisen |
| Morgen um 15 Uhr Zahnarzt anrufen | Zahnarzt anrufen |
| Halb zwölf morgen Anna abholen | Anna abholen |
| Zahnarzt anrufen, dringend | Zahnarzt anrufen |
| Dringend und wichtig: Vertrag kündigen | Vertrag kündigen |
| Mit Anna am Samstag ins Kino gehen | Mit Anna ins Kino gehen |
| Steuererklärung nächsten Freitag abgeben | Steuererklärung abgeben |
| In 3 Tagen Reifen wechseln | Reifen wechseln |
| Am Wochenende Rasenmäher Ölwechsel | Rasenmäher Ölwechsel |
| Morgen: „Projekt X“ abgeben | „Projekt X“ abgeben |
| Call the bank tomorrow at 9am | Call the bank |
| Important: renew passport by Friday | Renew passport |
| Pay rent on the 12th | Pay rent |
| Urgent: call back the plumber | Call back the plumber |
| Rasen mähen | Rasen mähen (nichts erkannt) |
| Rechnung bezahlen | Rechnung bezahlen (Inhaltswort) |
| Kündigungsfrist prüfen | Kündigungsfrist prüfen (Inhaltswort) |
| Jeden Montag Blumen gießen | Jeden Montag Blumen gießen (Wiederholung, kein Datum) |
| Treffen um 15 Uhr | Treffen um 15 Uhr (Uhrzeit ohne Tag) |
| Nicht wichtig: Keller aufräumen | Nicht wichtig: Keller aufräumen (verneint) |
| Morgen wichtig | Morgen wichtig (nichts bliebe übrig) |

## Tests

- `LooseEndsTests/TitleRuleTests.swift`: Beispieltabelle, Grenzfälle, zwölf Wörter nach dem
  Streichen, Erfassung.
- `LooseEndsTests/ImportanceUrgencyRuleTests.swift`: „wichtig“, Vorrang, Verneinungen, Übersetzung.
- `LooseEndsTests/FieldOriginTests.swift`: „Morgen wichtig Steuerbescheid prüfen“ ergibt
  Wichtigkeit hoch, Ursprung Regel, „wichtig“ markiert.
- Angepasst: `CaptureServiceTests`, `RevisionServiceTests` (Titel ohne „am Wochenende“/„am Samstag“).

## Abnahme

Kein Pfad der Geräteliste berührt (`Shared/Services`, `Shared/Enrichment/ImportanceUrgencyRule.swift`).
Simulator: Die Design-Galerie erfasst „Steuerbescheid morgen prüfen“ und zeigt Liste und Detail;
der Titel muss dort „Steuerbescheid prüfen“ lauten.

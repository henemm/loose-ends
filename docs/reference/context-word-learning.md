# Lernende Wortliste: N gemessen (#233)

Auslass-Test ohne Modell auf `docs/reference/focusblox-corpus.json` (287 Aufgaben,
104 mit Kontext-Wahrheit, 50 verschiedene Texte). Je Prüffall lernt
`ContextWordLearning` aus allen Aufgaben mit **anderem** Text — Textdubletten erkennt schon die
Wiedererkennung (#136), gemessen wird nur, was neu formulierte Aufgaben gewinnen. Bewertet wird die
exakte Kontextmenge; „fremd" zählt Prüffälle, bei denen ein Kontext gesetzt wird, den die Aufgabe
nicht trägt.

## Baselines

| Arm | Treffer | gesetzt | fremd |
|---|---|---|---|
| Konstante (häufigste Menge) | 32.0 % | 50 | 34 |
| Feste Wortliste #232 (Regelspalte) | 12.0 % | 12 | 5 |

## Gelernt je N

| N | gelernt allein: Treffer | gesetzt | fremd | fest + gelernt: Treffer | gesetzt | fremd | b | c | p-Wert | Regel |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 28.0 % | 23 | 8 | 32.0 % | 28 | 10 | 10 | 0 | 0.0020 | erfüllt |
| 2 | 14.0 % | 8 | 1 | 18.0 % | 16 | 6 | 3 | 0 | 0.2500 | erfüllt |
| 3 | 8.0 % | 5 | 1 | 12.0 % | 13 | 6 | 0 | 0 | 1.0000 | nicht erfüllt |
| 4 | 0.0 % | 0 | 0 | 12.0 % | 12 | 5 | 0 | 0 | 1.0000 | nicht erfüllt |
| 5 | 0.0 % | 0 | 0 | 12.0 % | 12 | 5 | 0 | 0 | 1.0000 | nicht erfüllt |

b/c und p-Wert: zweiseitiger McNemar-Exakttest „fest + gelernt" gegen die feste Wortliste allein.

## Urteil nach der vorab festgelegten Regel

Erfüllt heißt: „fest + gelernt" trifft mehr Aufgaben als die feste Wortliste allein, und der Anteil
fremder Kontexte unter den gesetzten Aufgaben steigt nicht. Gewählt wird das kleinste erfüllende N.

**Gewähltes N: 1**

## Grenzen dieser Zahlen

- Der Korpus trägt gepflegte Titel als Rohtext, nicht diktierte Sätze.
- Alle Kontexte im Korpus hat Henning in FocusBlox von Hand gesetzt; sie gelten hier als
  Zuordnungen mit Ursprung `user`.
- Gelernt werden nur Wörter ab vier Zeichen; kurze Inhaltswörter („Tee", „Bad", „App") fehlen.
- Bei 50 Prüffällen kann ein realer Vorsprung an der Signifikanz scheitern; die Regel oben
  verlangt deshalb keinen p-Wert, sondern keinen Zuwachs an fremden Kontexten.

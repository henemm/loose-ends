# Antrieb: Recherche und Konzept (Entwurf)

> Erstellt: 2026-10-23, auf Hennings Wunsch nach „etwas Gamification, das beim Erledigen hilft“.
> Status: Entwurf, noch keine Entscheidung. Zwei Ideen von Henning (der eine Frosch, Gummipunkte
> mit Wochenfeier), geprüft gegen die Studienlage, dann als Konzept im Duktus der App.
> Rahmen aus `00-entscheidungen.md` und `03-design-briefing.md`: Farbbudget (Grün nur beim Erledigen),
> nur SF Symbols, keine Serien, kein Lob, nie ein Satz über Nichterledigtes, „Disziplin-Statistiken“
> und „Coach“ bewusst nicht in Version 1.

## Das Ergebnis in vier Sätzen

Beide Ideen tragen, aber in einer schmaleren Form als üblich: **genau eine** selbst gewählte schwere
Aufgabe pro Tag ist die am besten belegte Mechanik, und sie passt ohne Reibung in „Jetzt“. Punkte
funktionieren nur, wenn sie **knapp, selbst vergeben und sofort beim Erledigen** sichtbar sind, nie
pauschal für jede Aufgabe. Was in Gamification-Apps am meisten schadet (Serien, Ranglisten, Verlust-
Formulierungen, Belohnung für Menge), lässt die App weg; das deckt sich mit Regeln, die schon
gelten. Gefeiert wird mit Form, nicht mit Worten: der Faden, das Grün, ein Bild der Woche.

## 1. Was die Forschung sagt

### 1.1 Gamification allgemein: kleiner Effekt, stark kontextabhängig

- Hamari, Koivisto & Sarsa (2014) sichteten die empirischen Studien: positive Effekte, aber abhängig
  vom Kontext und den Nutzern, mit Neuheitseffekten als ständigem Vorbehalt. Koivisto & Hamari (2019,
  819 Studien) bestätigen das Bild.
- Li, Hew & Du (2023/24, Meta-Analyse, 35 Interventionen): kleiner, signifikanter Effekt auf die
  intrinsische Motivation (g ≈ 0,26). Er läuft über **Autonomie** und Verbundenheit, kaum über
  Kompetenz. Kurnaz (2025, K-12): Punkte, Abzeichen und Ranglisten fördern eher extrinsische als
  intrinsische Motivation.
- Folgerung: Der Hebel ist Autonomie (selbst wählen, selbst vergeben), nicht Vergleich oder Menge.

### 1.2 Belohnungen: Zeitpunkt und Art entscheiden

- Deci, Koestner & Ryan (1999, 128 Experimente): greifbare, an Erledigung oder Leistung gekoppelte
  Belohnungen untergraben die intrinsische Motivation; verbale, informierende Rückmeldung nicht.
  Cameron & Pierce widersprechen in der Größe, nicht in der Richtung bei kontrollierenden Belohnungen.
- Woolley & Fishbach (2018, JPSP): eine **sofortige** Belohnung stärkt die intrinsische Motivation,
  eine spätere nicht; nach Wegfall der Belohnung blieben fast 20 % mehr Teilnehmer bei der Sache.
  Mechanismus: Die Tätigkeit selbst wird mit dem guten Moment verknüpft.
- Milkman u. a. (2014, „temptation bundling“): eine konkrete, an die Tätigkeit gebundene Belohnung
  (Hörbuch nur im Fitnessstudio) hob die Teilnahme um rund 55 %.
- Folgerung: Der Punkt entsteht **im Erledigen-Moment**, nicht am Wochenende. Die Woche ist Rückblick,
  keine Auszahlung. Eine selbst benannte Belohnung ist als Option sinnvoll, aber nie Pflicht.

### 1.3 Das Negativbeispiel: Habitica

Diefenbach & Müssig (2019, IJHCS) haben die gamifizierte Aufgaben-App Habitica untersucht. Befund:
Belohnung für belanglose Aufgaben, Aufgabenlisten, die aufgebläht werden, damit Punkte fließen,
Punkte fürs Aufschieben; nur 49 % der Nutzer halten die Belohnungen für angemessen. Spätere Studien
zu Habitica im Unterricht fanden schlecht verinnerlichte extrinsische Motivation. Kirchner-Krath u. a.
(CHI 2024) sehen Potenzial gegen Aufschieben, aber nur mit Gestaltung, die Selbstwirksamkeit und
Selbstkontrolle stützt.

Folgerung: **Nie jede Aufgabe zählt.** Zählen darf nur, was der Nutzer vorher bewusst als zählend
markiert hat, und davon wenige.

### 1.4 Serien schaden, sobald sie reißen

Silverman & Barasch (2023, JCR, sieben Studien): eine sichtbar intakte Serie steigert die Fortsetzung,
eine sichtbar gerissene senkt sie, unabhängig vom tatsächlichen Verhalten; am stärksten, wenn der
Nutzer den Riss sich selbst zuschreibt. Amabile & Kramer (2011, 12 000 Tagebucheinträge): Rückschläge
wiegen mehr als doppelt so schwer wie Fortschritte.

Folgerung: **Keine Serien, kein Zähler für Verpasstes, kein Vergleich mit letzter Woche.** Das steht
seit #426 schon in der Überschriftenregel und bleibt.

### 1.5 Der eine Frosch: besser belegt als erwartet, aus anderen Gründen

- Steel (2007, Meta-Analyse, 691 Korrelationen): **Aufgaben-Aversivität** ist neben Impulsivität
  und geringer Selbstwirksamkeit der stärkste Prädiktor fürs Aufschieben. Der Frosch ist also
  richtig definiert: nicht die wichtigste, sondern die unangenehmste Aufgabe.
- Habbert & Schroeder (2020, JESP): Reihenfolge schwer→leicht stärkt die Selbstwirksamkeit, leicht→
  schwer senkt sie oder ändert nichts; die meisten wählen trotzdem leicht zuerst, weil sie die
  Anstrengung lebhafter vorstellen als die Erleichterung. Fast ein Drittel bevorzugt schwer zuerst.
- KC, Staats, Kouchaki & Gino (2020, Management Science, sechs Jahre Notaufnahme-Daten):
  „task completion preference“, unter Last zu den leichten Aufgaben zu greifen, sieht kurzfristig
  produktiv aus und ist langfristig schlechter.
- Zhu, Yang & Hsee (2018, JCR, „mere urgency effect“): Menschen wählen das Dringende vor dem
  Wichtigen, auch wenn Zeit genug ist; eine Erinnerung an den Wert **im Moment der Wahl** schwächt
  den Effekt. Eine Aufgabe ohne Datum, die etwas bedeutet, braucht deshalb einen eigenen Platz, sonst
  verliert sie jeden Tag gegen das Datierte.
- Masicampo & Baumeister (2011, JPSP): ein konkreter Plan für **ein** offenes Vorhaben beendet dessen
  Störgedanken so gut wie die Erledigung; Brainstorming reicht nicht. Die Wahl des Froschs am Morgen ist
  ein solcher Plan.
- Was nicht trägt: das „morgens ist die Willenskraft voll“ aus Tracys Buch beruht auf Ego-Depletion;
  eine Multi-Lab-Replikation (2021) fand einen Effekt nahe null. Die App schreibt daher keine Uhrzeit vor.
  Die Methode selbst ist nie als Ganzes getestet worden; belegt sind die Bausteine (eine, schwer, selbst
  gewählt, zuerst relativ zum Rest).

### 1.6 Fortschritt, kleine Ziele, frischer Start

- Amabile & Kramer: das stärkste positive Ereignis eines Arbeitstags ist ein kleiner, sichtbarer
  Fortschritt in sinnvoller Arbeit. Die Überschrift ab 16 Uhr (#426) tut das schon.
- Nunes & Drèze (2006, „endowed progress“) und die Zielgradienten-Literatur: ein **kleines, sichtbares
  Ziel** mit erkennbarem Fortschritt wird häufiger erreicht als ein offener Zähler.
- Dai, Milkman & Riis (2014, Management Science, „fresh start effect“): nach zeitlichen Marken, auch
  dem Montag, nehmen Menschen Ziele häufiger in Angriff. Die Woche ist die natürliche Einheit, der
  Montag ihr Anfang.

## 2. Das Konzept

Zwei Bausteine, beide optional, beide ohne Modell (Regelpfad, es gibt nichts zu verstehen):

### 2.1 Der eine: eine Aufgabe trägt die Last des Tages

**Was.** Genau eine offene Aufgabe trägt die Marke. Der Nutzer setzt sie selbst (Halten-Menü, Wisch,
„…“-Menü im Detail: „Heute dran“). Setzt er eine zweite, wandert die Marke, ohne Rückfrage. Jede
Änderung ist eine `Revision` mit `author == user`.

**Wo sie steht.** Ganz oben in „Jetzt“, vor dem Überfälligen, als einzige Zeile mit der Marke; in jeder
Liste trägt die Zeile die Marke als Glyphe am Anfang der Merkmalzeile, schwarz, ohne Farbe, wie Fahne
und Blitz. Morgens steht sie in der Überschrift: „Erst: Steuer anrufen.“ (vor „Heute: …“, die
Uhrzeiten des Tages gehen weiter vor). Kein Lob, keine Zahl.

**Wenn sie liegen bleibt.** Sie bleibt die Marke, auch morgen, still. Kein Satz darüber, kein Zähler,
kein Rot. Die Marke verfällt nur durch Erledigen, Parken oder Umsetzen. (Serienregel, 1.4.)

**Der Moment.** Erledigen ist der eine grüne Moment der App. Für diese Aufgabe darf er ein wenig
länger dauern: der Faden aus dem Logo zieht sich einmal glatt (Knoten → loser Faden, `ThreadShape`
hat beide Formen, die `trim`-Animation gibt es schon). Reduce Motion: stehendes Bild. Danach steht
in der Überschrift bis 16 Uhr nichts Besonderes mehr; ab 16 Uhr zählt der Rückblick sie wie jede
andere, aber zuerst.

**Vorschlag, kein Zwang (Schnitt 2).** Hat der Nutzer morgens keine Marke gesetzt, darf die App eine
Kandidatin nennen, regelbasiert: ohne Datum, Wichtigkeit hoch, am längsten getragen („Seit 11 Tagen“),
in „Alt“. Eine Zeile unter „Jetzt“: „Seit 11 Tagen offen: Steuer anrufen. Heute dran?“ mit einem
Tipp. Das ist Zhu et al.: der Wert im Moment der Wahl. Nie als Mitteilung, nie zweimal am Tag.

**Daten.** `heavyMarkedAt: Date?` auf `TaskItem` (manueller Zustand wie `nextRank`, additiv in
`cloudkit/schema.ckdb`). Eine Aufgabe kann zugleich „Als nächstes“ sein; die Marke sortiert vor.

### 2.2 Perlen: wenige Aufgaben zählen, die Woche zeigt sie

**Was.** Der Nutzer markiert einzelne Aufgaben als zählend („Zählt“). Eine Aufgabe zählt oder nicht,
keine Gewichte, keine Punktzahlen: Gewichte laden zum Rechnen ein, und Rechnen war Habiticas Fehler.
Es gibt ein kleines Budget: höchstens fünf offene zählende Aufgaben gleichzeitig. Die Knappheit macht
die Markierung zur Entscheidung („Das hier ist mir diese Woche etwas wert“), nicht zum Reflex.

**Der Moment.** Beim Erledigen einer zählenden Aufgabe erscheint die Perle auf dem Faden der Woche,
sofort (Woolley & Fishbach). Der Faden der Woche ist eine Zeile unter „Jetzt“: der lose Faden aus dem
Logo, darauf je erledigter zählender Aufgabe ein kleiner Kreis (`circle.fill`, grau, der frischeste
kurz grün). Leer bleibt die Zeile weg.

**Die Woche.** Montag bis Sonntag. Am Sonntag ab 16 Uhr und Montag bis zur ersten neuen Perle zeigt
die Überschrift die Woche: „Diese Woche: vier Perlen.“ mit der Fadenzeile und den Titeln beim Tipp
(öffnet „Erledigt“, nach Wochen gruppiert, die zählenden mit Perle). Kein Vergleich mit der Vorwoche,
kein „nur“, keine Null-Woche in der Überschrift: ohne Perle kein Satz. Der Faden beginnt Montag leer,
die alten Fäden bleiben in „Erledigt“ sichtbar.

**Ein Ziel, das der Nutzer setzt (Option).** In den Einstellungen eine Zahl „Perlen pro Woche“ (leer
oder 1–7). Ist sie gesetzt, zeigt der Faden die Lücken als leere Kreise (`circle`, grau): endowed
progress, Zielgradient. Erreicht heißt nur: die Kreise sind voll. Nicht erreicht heißt: nichts.

**Belohnung, die man sich selbst nennt (Option, später).** Eine Zeile am Faden der Woche: „Dafür:
Samstag Kino.“ Freitext, nichts wird geprüft. Das ist Milkmans Bündelung in ihrer einfachsten Form.
Erst bauen, wenn 2.1 und der Faden ein paar Wochen gelaufen sind.

**Daten.** `countsAt: Date?` auf `TaskItem`; die Perle liest `completedAt`. Bei Wiederholung zählt
jeder `CompletionRecord` einer zählenden Aufgabe einmal in seiner Woche. Keine weitere Tabelle, kein
Punktekonto: der Faden ist aus den Aufgaben berechnet (Regel 4 in `02-datenmodell-und-ansichten.md`).

### 2.3 Was bewusst nicht gebaut wird

| Nicht | Warum (Beleg) |
|---|---|
| Serien, „N Tage in Folge“ | Silverman & Barasch; Regel #426 |
| Punkte für jede Aufgabe, XP, Level | Deci et al.; Diefenbach & Müssig |
| Rangliste, Teilen des Wochenbilds | Vergleich untergräbt Autonomie (Li et al.) |
| Mitteilungen über Frosch oder Perlen | Nag ist eine Rückschlag-Erinnerung (Amabile) |
| Vorgeschriebene Uhrzeit für den Frosch | Ego-Depletion nicht repliziert |
| Lob-Wörter („Super!“) | Regel #426; Fogg’s „Celebration“ ohne Beleg |
| Wochen-Vergleich, Zähler fürs Verpasste | Rückschlag wiegt doppelt (Amabile) |

### 2.4 Namen und Zeichen (Produktfrage)

Henning nennt es „Frosch“ und „Gummipunkte“. Beides ist im Gespräch gut, in der App gibt es zwei Wege:

- **A, aus der Marke:** „Der Knoten“ (die eine verknotete Aufgabe, erledigen löst ihn) und „Perlen“
  auf dem Faden der Woche. Zeichen: der Faden selbst (Knoten-Form als kleine Glyphe, wie der Mac-
  Menüleisten-Faden `MenuBarThreadImage`). Passt zur Ausnahme in #350 (der Faden ist Marke), aber die
  Glyphe in der Zeile wäre ein Zeichen, das kein SF Symbol ist. Das wäre eine zweite Ausnahme.
- **B, aus SF Symbols:** „Heute dran“ mit `mountain.2` (der Berg vor einem) oder `tortoise`
  (das Langsame), „Zählt“ mit `star` und Sternen auf dem Faden. Hält #350 wörtlich; der Faden der
  Woche bliebe Marke, die Zeichen in der Zeile wären Symbole. Einen Frosch gibt es in SF Symbols nicht.

Empfehlung: **B für die Zeile, der Faden für die Woche.** Die Zeile bleibt in der Symbolsprache, das
Wochenbild trägt die Marke. Namen in der App: „Heute dran“ und „Zählt“; „Frosch“ und „Perlen“ bleiben
die Wörter im Gespräch.

## 3. Schnitte

Alles optional: ein Schalter „Antrieb“ in den Einstellungen, aus für neue Nutzer, zwei Zeilen darunter
(„Heute dran“, „Zählt“). Beide Felder laufen über `DetailFields`: aus heißt nicht angeboten, nie
versteckt.

| Schnitt | Inhalt | Größe |
|---|---|---|
| 1 | `heavyMarkedAt`, Schema, `TaskActions.markHeavy`, Halten-Menü und „…“, Glyphe in der Zeile, oben in „Jetzt“, Überschrift „Erst: …“ | S–M |
| 2 | Der Moment: Faden glatt ziehen beim Erledigen der Marke, Reduce Motion | S |
| 3 | `countsAt`, Schema, „Zählt“ mit Budget 5, Glyphe, Faden der Woche unter „Jetzt“ | M |
| 4 | Wochensatz Sonntag/Montag, „Erledigt“ nach Wochen mit Perlen | S |
| 5 | Vorschlag der Kandidatin (Regel: ohne Datum, hoch, am längsten getragen) | S |
| 6 | Wochenziel-Kreise, Belohnungszeile | S |

Schnitt 1 und 3 ändern `Shared/Models`: beide Felder gehören in **einen** Schema-Deploy (#448, Henning
klickt selten). Keine Modelländerung berührt die Geräteliste außer dem Schema; Widget und Watch
bekommen die Marke erst, wenn sie sich bewährt hat.

## 4. Messen, ob es hilft

Ohne Vergleichsgruppe, wie in `06-annahmen-und-experimente.md` (Vertrauen): nach vier Wochen zählt die
App lokal, an wie vielen Tagen eine Marke gesetzt und am selben Tag erledigt wurde, und wie viele
zählende Aufgaben erledigt wurden, gegen die Erledigungsquote aller Aufgaben. Keine Übertragung, nur
ein Satz in den Einstellungen. Fällt die Marke an mehr als der Hälfte der Tage liegen, ist die
Mechanik falsch gebaut, nicht der Nutzer.

## Quellen

- Hamari, Koivisto & Sarsa (2014): Does Gamification Work? HICSS. https://www.lescahiersdelinnovation.com/wp-content/uploads/2019/06/2014-hamari_et_al-does_gamification_work.pdf
- Koivisto & Hamari (2019): The rise of motivational information systems. IJIM. https://research.utu.fi/converis/portal/detail/Publication/39369087?lang=en_US
- Li, Hew & Du (2023/24): Gamification enhances student intrinsic motivation … Meta-analysis. ETR&D. https://link.springer.com/article/10.1007/s11423-023-10337-7
- Kurnaz (2025): Meta-Analysis of Gamification's Impact on Student Motivation. Psychology in the Schools. https://onlinelibrary.wiley.com/doi/10.1002/pits.70056
- Deci, Koestner & Ryan (1999): Extrinsic rewards and intrinsic motivation, meta-analysis. Psych. Bulletin. https://depts.washington.edu/techdocs/papers/deciExtrinsicRewardsAndIntrinsicMotivation99.pdf
- Woolley & Fishbach (2018): It's about time: Earlier rewards increase intrinsic motivation. JPSP. https://news.cornell.edu/node/300311
- Milkman, Minson & Volpp (2014): Holding the Hunger Games hostage at the gym (temptation bundling). Management Science. https://leadershipcenter.wharton.upenn.edu/research/fresh-starts-guilty-pleasures-and-other-pro-tips-for-sticking-to-good-habits/
- Diefenbach & Müssig (2019): Counterproductive effects of gamification: Habitica. IJHCS 127. https://www.sciencedirect.com/author/25723185400/sarah-diefenbach
- Kirchner-Krath u. a. (2024): Outplay Your Weaker Self. CHI. https://dl.acm.org/doi/full/10.1145/3613904.3642048
- Silverman & Barasch (2023): On or Off Track: How (Broken) Streaks Affect Consumer Decisions. JCR. https://www.colorado.edu/business/faculty-research/2023/04/19/or-track-how-broken-streaks-affect-consumer-decisions
- Amabile & Kramer (2011): The Progress Principle. https://edgeforscholars.vumc.org/go-go-go-read-the-progress-principle/
- Steel (2007): The nature of procrastination, meta-analysis. Psych. Bulletin. https://www.sciencedaily.com/releases/2007/01/070110090851.htm
- Habbert & Schroeder (2020): To build efficacy, eat the frog first. JESP. https://www.sciencedirect.com/science/article/abs/pii/S0022103120303723
- KC, Staats, Kouchaki & Gino (2020): Task Selection and Workload. Management Science. https://pubsonline.informs.org/doi/fpi/10.1287/mnsc.2019.3419
- Zhu, Yang & Hsee (2018): The Mere Urgency Effect. JCR. https://hub.jhu.edu/2018/05/31/meeting-deadlines-time-management-behaviors
- Masicampo & Baumeister (2011): Consider it done! JPSP. https://psychology.wfu.edu/e-j-masicampo/
- Nunes & Drèze (2006): The Endowed Progress Effect. JCR. https://ideas.repec.org/a/oup/jconrs/v32y2006i4p504-512.html
- Dai, Milkman & Riis (2014): The Fresh Start Effect. Management Science. https://faculty.wharton.upenn.edu/wp-content/uploads/2014/06/Dai_Fresh_Start_2014_Mgmt_Sci.pdf

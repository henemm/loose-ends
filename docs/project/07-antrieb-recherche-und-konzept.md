# Antrieb: Recherche und Konzept (Entwurf)

> Erstellt: 2026-10-23, auf Hennings Wunsch nach „etwas Gamification, das beim Erledigen hilft“.
> Status: Teil 1 (Recherche) Entwurf; Teil 2 (Konzept) entschieden mit Henning am 2026-10-23 anhand der Mockups,
> Leinwand https://claude.ai/artifact/91YJuzqSFibDQNfS22soYK. Zwei Ideen von Henning (die eine vermiedene Aufgabe, Gummipunkte
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

## 2. Das Konzept (entschieden 2026-10-23)

Zwei Bausteine, beide optional, beide ohne Modell (Regelpfad, es gibt nichts zu verstehen). Die Namen
und Zeichen sind am 23.10. mit Henning an den Mockups festgelegt worden; die Leinwand oben ist der
Stand, dieses Dokument die Begründung.

### 2.1 Das Knäuel: eine Aufgabe, vor der man sich drückt

**Was.** Genau eine offene Aufgabe ist „Das Knäuel“: nicht die schwerste, sondern die, vor der man sich
drückt (Steel, 1.5). Der Nutzer setzt sie selbst: Halten-Menü und „…“ im Detail, Eintrag „Das Knäuel“;
ist es schon diese Aufgabe, heißt der Eintrag „Kein Knäuel mehr“. Bekommt eine zweite Aufgabe das
Knäuel, **fragt die App erst**, ob es von der bisherigen wandern soll (Henning, 23.10.). Jede Änderung
ist eine `Revision` mit `author == user`.

**Wo es steht.** Im Kopf der Startseite, am Datum, wo sonst der Knoten des Logos steht: solange eine
Aufgabe das Knäuel ist, zeigt der Kopf statt des grauen Knotens das schwarze Knäuel, ein Fünftel größer.
Die Aufgabe steht als eigene Zeile direkt unter dem Datum, vor der Überschrift; die Überschrift bleibt
der Satz des Tages. Aus dem Knäuel läuft ein loser Faden in zwei lockeren Loops hinunter bis vor das
erste Wort der Zeile. In der Merkmalzeile steht „Seit 11 Tagen“. Das Datum beginnt bündig über dem
Aufgabentext.

**Die Zeichnung.** Das Knäuel ist eine Linie aus der Familie des Logo-Fadens: drei dichte Schlingen und
ein kurzes, flach nach rechts auslaufendes Ende (die Kurve steht in der Leinwand und in der Tafel „Die
Zeichen“; in der App als `Shape`, Strich wie der Knoten). Knäuel und Faden sind **zwei Elemente**: das
Knäuel steht für sich (Datum, Menü, Detail, Einstellungen, „Erledigt“), der Faden setzt tangential an
seinem Ende an, in derselben Strichstärke, ohne Lücke, und existiert nur im Kopf der Startseite. Der
Faden ist aus derselben Formel wie der Logo-Faden gerechnet (Trochoide, zwei Loops). Das Knäuel hat das
Gewicht (dicht), der Faden ist locker. Zweite Ausnahme von #350 (nur SF Symbols), wie der Faden selbst.

**Wenn es liegen bleibt.** Es bleibt das Knäuel, auch morgen, still. Kein Satz darüber, kein Zähler,
kein Rot. Die Marke verfällt nur durch Erledigen, Parken oder Umsetzen. (Serienregel, 1.4.)

**Der Moment.** Erledigen ist der eine grüne Moment der App. Das Knäuel lockert sich grün zum Knoten
(dieselbe Linie, die Schlingen gehen auf), der Faden zieht sich ein, die Zeile geht mit; danach steht
der Kopf wie an jedem Tag, der Knoten wieder grau. Reduce Motion zeigt nur das letzte Bild. Ab 16 Uhr
nennt die Überschrift das Entwirrte zuerst: „Heute entwirrt: Steuer anrufen.“

**Im Detail.** Unter dem Rohtext eine Zeile „Das Knäuel · seit heute Morgen“ mit „Lösen“ (nimmt die
Marke, ohne zu erledigen), nur solange die Aufgabe das Knäuel ist.

**Vorschlag, kein Zwang (später).** Hat der Nutzer morgens kein Knäuel gesetzt, darf die App eine
Kandidatin nennen, regelbasiert: ohne Datum, Wichtigkeit hoch, am längsten getragen, in „Alt“. Eine
Zeile unter „Jetzt“: „Seit 11 Tagen offen: Steuer anrufen. Das Knäuel?“ mit einem Tipp. Das ist Zhu et
al.: der Wert im Moment der Wahl. Nie als Mitteilung, nie zweimal am Tag.

**Daten.** `knaeuelAt: Date?` auf `TaskItem` (manueller Zustand wie `nextRank`, additiv in
`cloudkit/schema.ckdb`). Eine Aufgabe kann zugleich „Als nächstes“ sein; das Knäuel sortiert vor.

### 2.2 Perlen: wenige Aufgaben zählen, die Woche zeigt sie

**Was.** Der Nutzer markiert einzelne Aufgaben als zählend („Zählt“, Halten-Menü und „…“). Eine Aufgabe
zählt oder nicht, keine Gewichte, keine Punktzahlen: Gewichte laden zum Rechnen ein, und Rechnen war
Habiticas Fehler. Höchstens fünf offene zählende Aufgaben gleichzeitig; die Knappheit macht die
Markierung zur Entscheidung, nicht zum Reflex. Das Knäuel zählt immer. In der Merkmalzeile steht die
Perle: eine kurze Schnur mit einer hohlen Perle mit Glanzpunkt (Zeichnung in der Leinwand).

**Der Moment.** Beim Erledigen einer zählenden Aufgabe erscheint die Perle auf der Schnur der Woche,
sofort (Woolley & Fishbach), kurz grün. Die Schnur der Woche ist eine Zeile unter „Jetzt“: **eine
durchhängende Schnur (eine Mulde)**, die Perlen von links dicht aufgereiht, gleiche Abstände, keine
leeren Plätze (Fassung A, Henning 23.10.). Ohne Perle bleibt die Zeile weg.

**Die Woche.** Montag bis Sonntag. Ab Sonntag 16 Uhr bis zur ersten neuen Perle am Montag zeigt die
Überschrift die Woche: „Diese Woche: vier Perlen.“ mit der Schnur und den Titeln darunter; ein Tipp
öffnet „Erledigt“, dort nach Wochen gruppiert, jede Woche mit ihrer Schnur, die zählenden Aufgaben mit
Perle, die Knäuel-Aufgabe mit kleinem grauem Knäuel. Kein Vergleich mit der Vorwoche, kein „nur“,
keine Null-Woche in der Überschrift: ohne Perle kein Satz. Die Schnur beginnt Montag leer, die alten
bleiben in „Erledigt“.

**Kein Wochenziel** (Henning, 23.10.): keine Zahl „Perlen pro Woche“, keine leeren Ringe. Die
Zielgradienten-Idee (1.6) ist damit bewusst nicht gebaut; die Schnur zeigt nur, was da ist.

**Dafür.** Eine Zeile unter der Schnur: „Dafür: Samstag Kino.“ Freitext, nichts wird geprüft, der
Satz gehört zur Woche und bleibt stehen, bis er geändert wird. Ein Tipp auf die Zeile (Startseite) oder
auf das Feld in den Einstellungen setzt den Cursor hinein; leer heißt keine Zeile. Milkmans Bündelung in
ihrer einfachsten Form.

**Daten.** `countsAt: Date?` auf `TaskItem`; die Perle liest `completedAt`. Bei Wiederholung zählt
jeder `CompletionRecord` einer zählenden Aufgabe einmal in seiner Woche. „Dafür“ ein String im
iCloud-Schlüsselwertspeicher wie die Feld-Einstellungen. Keine weitere Tabelle, kein Punktekonto: die
Schnur ist aus den Aufgaben berechnet (Regel 4 in `02-datenmodell-und-ansichten.md`).

### 2.3 Einstellungen

Keine eigene Seite „Antrieb“ (Henning, 23.10.): „Das Knäuel“ und „Zählt“ sind Felder einer Aufgabe wie
Dauer oder Etiketten und stehen in derselben Liste „Felder“ (`DetailFieldSettings`, #538: aus heißt
nicht angeboten, nie versteckt), mit je einem Satz darunter. Beides aus für neue Nutzer. „Dafür“ steht
als Textfeld unter „Zählt“ und auf der Startseite.

### 2.4 Was bewusst nicht gebaut wird

| Nicht | Warum (Beleg) |
|---|---|
| Serien, „N Tage in Folge“ | Silverman & Barasch; Regel #426 |
| Punkte für jede Aufgabe, XP, Level | Deci et al.; Diefenbach & Müssig |
| Rangliste, Teilen des Wochenbilds | Vergleich untergräbt Autonomie (Li et al.) |
| Mitteilungen über Knäuel oder Perlen | Nag ist eine Rückschlag-Erinnerung (Amabile) |
| Vorgeschriebene Uhrzeit für das Knäuel | Ego-Depletion nicht repliziert |
| Lob-Wörter („Super!“) | Regel #426; Fogg’s „Celebration“ ohne Beleg |
| Wochen-Vergleich, Zähler fürs Verpasste, Wochenziel | Rückschlag wiegt doppelt (Amabile); Henning 23.10. |

### 2.5 Verworfene Namen und Bilder

Frosch (Bild gefiel nicht), Kröte, saurer Apfel, Stein im Schuh, bittere Pille, „Heute dran“, „Das
Eine“, „Jetzt“ (zu nüchtern oder zu erdrückend), „Hängt raus“ und „Augen zu und durch“ (Faden allein
zu unklar, Hennings Frau). Geblieben ist das Bild aus der Marke: lose Enden liegen ordentlich in der
Kiste, eines hat sich vom täglichen Zurückstopfen verheddert. Der Knoten des Logos bleibt das Zeichen
für „versorgt“, das Knäuel ist sein Gegenstück.

## 3. Schnitte

Alles optional über die Felder-Liste. Modelländerungen gebündelt in einem Schema-Deploy (#448).

| Schnitt | Inhalt | Größe |
|---|---|---|
| 1 | `knaeuelAt`, Schema, `TaskActions`, Halten-Menü und „…“ mit Rückfrage beim Wandern, Zeile unter dem Datum, Knäuel statt Knoten im Kopf (`ThreadShape`-Form), Datum bündig | M |
| 2 | Der Faden mit zwei Loops aus dem Knäuel zur Zeile; der Moment beim Erledigen (lockern, einziehen), Reduce Motion; Überschrift „Heute entwirrt“ | S |
| 3 | `countsAt`, Schema, „Zählt“ mit Budget 5, Perle in der Merkmalzeile, Schnur der Woche unter „Jetzt“, Knäuel zählt immer | M |
| 4 | Wochensatz Sonntag/Montag, „Erledigt“ nach Wochen mit Schnur, Perlen und Knäuel-Marke | S |
| 5 | „Dafür“ (Startseite und Einstellungen), Felder-Liste, Detail-Zeile „Das Knäuel“ mit „Lösen“ | S |
| 6 | Vorschlag der Kandidatin (Regel: ohne Datum, hoch, am längsten getragen) | S |

Schnitt 1 und 3 ändern `Shared/Models`: beide Felder gehören in **einen** Schema-Deploy. Keine
Modelländerung berührt die Geräteliste außer dem Schema; Widget und Watch bekommen das Knäuel erst,
wenn es sich bewährt hat.

## 4. Messen, ob es hilft

Ohne Vergleichsgruppe, wie in `06-annahmen-und-experimente.md` (Vertrauen): nach vier Wochen zählt die
App lokal, an wie vielen Tagen ein Knäuel gesetzt und am selben Tag erledigt wurde, und wie viele
zählende Aufgaben erledigt wurden, gegen die Erledigungsquote aller Aufgaben. Keine Übertragung, nur
ein Satz in den Einstellungen. Bleibt das Knäuel an mehr als der Hälfte der Tage liegen, ist die
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

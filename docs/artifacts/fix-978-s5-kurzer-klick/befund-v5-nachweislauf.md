# Befund v5 – Nachweislauf mit kurzem Klick (#978 S5, AC-7)

Lauf: `mac-panel-repeat.yml` 45642831767 auf `fix/978-s5-kurzer-klick` (22ae1d5), `iterationen=40`, `kontrollarm=false`,
2026-11-25 15:19–16:00 UTC (16:19–17:00 Uhr MEZ). Zusammenfassung: `repeat-45642831767/summary/mac-panel-repeat-summary.md`.
Parallel: Pflichtlauf „Mac Gallery (macOS)“ in CI 45642824480, Job 139305969241: **grün** (1/3).

## Ergebnis

| Arm | Nenner | Panel zu | Rate | Klickweg |
|---|---|---|---|---|
| return | 40 | 0 | 0,0 % | short-click 40 |
| open-app | 40 | **1** | **2,5 %** | short-click 40 |

AC-7 verlangt 0 Fälle je Nutzerarm → **nicht erfüllt**.

## Der Fall (open-app, zweiter Klick des Laufs, 1795620264.098)

- +0,000 s Klick (`click(forDuration: 0.1, thenDragTo:)`)
- +0,180 s App aktiv, +0,203 s Panel `key`
- +0,819 s globales Maus-hoch → Haltedauer **0,616 s** ab `key`
- +0,836 s `resign`, +0,847 s `hide` — Panel zu, 17 ms nach dem Maus-hoch (gleiches Muster wie v3/v4)

Alle anderen 79 Klicks: Haltedauer 0,033–0,138 s oder „kurz (kein Maus-hoch)“, Panel offen.

## Deutung

Die angeforderte Haltedauer von 0,1 s ist keine Garantie: unter Last (früh im Lauf, während XCTest die App aktiviert)
dehnt die Klicksynthese das Halten auf über 0,6 s, und das Loslassen schließt das Panel wie bisher. Die Ursache
(langes Halten schließt) bleibt bestätigt; der kurze Klick senkt die Rate (v3: 1/2, `click()` mehrfach ≥ 0,7 s), stellt
die Streuung aber nicht an der Quelle ab. Der Fall liegt zudem unter der bisher angenommenen Grenze von 0,7 s.

## Folge (Abbruchregel der Spec)

Stopp: keine Schwellen- oder Wiederholungs-Flickerei in diesem Schnitt, AC-8 (zwei weitere Galerie-Läufe) wird nicht
angegangen. Neue Analyse mit Alternative A (Haltedauer erkennen, über einer Schwelle genau einmal wiederholen) —
Messgrundlage jetzt: Fälle 0,616/0,71/0,90/0,93 s, Erfolge ≤ 0,36 s.

# Nachrechnung zur Analyse von #136

Zwei Wegwerf-Skripte, mit denen die Zahlen im Abschnitt `## Analysis` von
`docs/context/feat-136-wiedererkennung.md` entstanden sind. Sie liegen hier, damit die Herkunft jeder
Zahl nach einem `/clear` noch prüfbar ist — Risiko 1 der Kontextaufnahme war genau, dass eine Zahl ins
Produkt wandert, deren Herleitung niemand mehr nachvollziehen kann.

```bash
python3 docs/artifacts/feat-136-wiedererkennung/schwellen-nachrechnung.py
python3 docs/artifacts/feat-136-wiedererkennung/vergleichsvarianten.py
```

Beide lesen `docs/reference/focusblox-corpus.json`. Die Datei ist gitignoriert und liegt **nur im
Hauptordner** (`/Users/hem/Developer/loose-ends`), nicht in einem Worktree — ohne sie brechen die
Skripte ab, statt eine leere Auswertung zu liefern.

- `schwellen-nachrechnung.py` — Portierung von `Measurement/LeaveOneOut.swift` (`similarityWords`,
  `jaccard`, `neighbors(k: 1)`) mit einer Schwellen-Kurve je Merkmal: Fälle, Treffer, Quote im Band,
  Abdeckung. Zeigt, dass der gesamte Nutzen bei Jaccard 1,0 liegt und dass 0,34 genau über dem
  höchsten Fehlertreffer der Kontexte (0,333) sitzt.
- `vergleichsvarianten.py` — vergleicht drei Schlüsselvarianten (Wortmenge ab vier Zeichen, Wortmenge
  über alle Wörter, ganzer normalisierter Text). Alle drei ergeben auf diesem Korpus 124 Schlüssel und
  dieselben Trefferquoten; der Korpus kann sie also nicht unterscheiden.

**Bekannte Abweichung gegenüber dem Swift-Lauf: genau zwei Einträge** bei Dauer und Energie. Ursache
ist `ß`: Foundations `folding(options: [.caseInsensitive, .diacriticInsensitive], locale: de_DE)`
faltet `ß` zu `ss`, die Python-Nachbildung über NFD nicht, und der Korpus enthält genau zwei Einträge
mit `ß`. Der Befund ändert sich dadurch nicht. Der verbindliche Nachweis bleibt die Swift-Messung aus
der Definition of Done von #136, nicht diese Skripte.

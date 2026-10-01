# Upgrade-Durchlauf AC-5 (#157): Dubletten werden beim Start der neuen App zusammengeführt

Simulator iPhone 17 (iOS 27), Bundle-ID com.henning.looseends, persistenter Speicher (ohne --ui-testing),
Englisch. Eine Installation, nie deinstalliert/gelöscht: alter Stand (HEAD ohne Fix, per git archive in
ein Scratch-Verzeichnis) -> neuer Stand (Arbeitsstand, ./scripts/sim.sh build + launch).

1. 01: Alter Stand, Seitenleiste: zwei Zeilen "Garden" (gesät + über "New context" angelegt), je Zähler 0.
2. 02: Alter Stand, Aufgabe "Rasen mähen", Feld Contexts zeigt "Garden, Garden" (an beiden Dubletten).
3. 03: Alter Stand nach Neustart (sim.sh launch, neuer Prozess): weiterhin zwei "Garden", je Zähler 1 -> der Speicher überlebt.
4. 06: Neuer Stand, direkt nach sim.sh launch (Kopf der Seitenleiste; Contexts nur angeschnitten).
5. 04: Neuer Stand, Seitenleiste gescrollt: genau eine Zeile "Garden", Zähler 1 (Computer, Phone, Home, Garden, Errands, Out and about).
6. 05: Neuer Stand, Aufgabe "Rasen mähen" über die Garden-Zeile geöffnet: Contexts zeigt "Garden" (einmal), Aufgabe nicht verloren.

Zugänglichkeits-Beschriftung des Feldes: alt "Contexts, Garden, Garden, Set by AI", neu "Contexts, Garden, Set by AI".

Einschränkung: 04/05 stammen aus einem schreibgeschützten Ansichts-UI-Test, der in einer Kopie des
Arbeitsstands (Scratchpad, gleiche Quelle) gebaut und gestartet wurde, weil sim.sh nicht scrollen kann.
Die Zusammenführung selbst lief beim ersten Start über sim.sh launch aus dem Arbeitsstand (06).
Auffälligkeit: Die Aufgabe trägt den KI-Stern (Wiedererkennung/Erschließung hat Kontexte, Dauer 15 min
und Energie gesetzt), auch im alten Stand.

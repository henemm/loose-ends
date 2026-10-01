# Adversary-Dialog fix-157-kontext-dreifach

### Runde 1

- [x] Testlauf: `./scripts/sim.sh unit` selbst ausgefuehrt, "Test Succeeded", keine Fehlschlaege (docs/artifacts/fix-157-kontext-dreifach/adversary-unit-run.txt). Der Lauf hat docs/reference/date-title-fidelity.md ueberschrieben, per git checkout zurueckgesetzt.
- [x] AC-1: addContext wirft duplicateName ueber nameKey (getrimmt, case- und diakritik-unempfindlich); Garden/Garten bleiben verschieden.
  Code reference: Shared/Services/CatalogService.swift:22
- [x] AC-2: rename(among:) schliesst das eigene Objekt per id aus, eigenes Casing erlaubt, fremder Name abgelehnt.
  Code reference: Shared/Services/CatalogService.swift:34
- [x] AC-3: mergeDuplicateContexts haengt je Aufgabe einmal an den Ueberlebenden (Filter auf Dublette, contains-Pruefung gegen Doppelanhaengen), loescht Dublette. Aufgabe an beiden Dubletten: Dublette wird gefiltert, Ueberlebender nur einmal; Iteration laeuft ueber eine Wertkopie von duplicate.tasks, kein Loeschen waehrend der Iteration. Dublette ohne Aufgaben: nur geloescht. Drei Dubletten: dropFirst loest alle.
  Code reference: Shared/Services/CatalogService.swift:47
- [x] AC-4: Reihenfolge isSystemDefault, sortOrder, id.uuidString, deterministisch.
  Code reference: Shared/Services/CatalogService.swift:65
- [x] AC-5 (Code): startUp ruft nach dem Saeen merge auf und speichert direkt danach, vor enrichment.processPending.
  Code reference: LooseEnds/App/ContentView.swift:68
- [x] AC-6/Frage 6: commit faengt duplicateName, setzt duplicateRejected, Alert vorhanden; Rename uebergibt `among: contexts` (@Query aller Kontexte).
  Code reference: LooseEnds/Views/SidebarView.swift:128
- [x] Frage 5 Lokalisierung: Schluessel "A context with this name already exists." mit de "Einen Kontext mit diesem Namen gibt es schon." im Katalog (Diff geprueft). Der Alert nutzt den Literal-Schluessel, wird also lokalisiert.
  Code reference: LooseEnds/Views/SidebarView.swift:68
- [x] Frage 4 Watch/Widgets/Share: CatalogService importiert nur Foundation/SwiftData, `folding(options:locale:)` ist Foundation und auf watchOS verfuegbar; einziger Aufrufer sind LooseEnds/Views und LooseEnds/App, die Ziele mit Shared/ kompilieren es nur mit, ohne neue APIs. Kein Defekt per Quelltext.
  Code reference: Shared/Services/CatalogService.swift:1
- [x] Bilder geprueft: 03 (alt nach Neustart) zeigt zwei "Garden"-Zeilen mit je 1, 04 (neu) zeigt genau eine "Garden"-Zeile mit 1 (Computer, Phone, Home, Garden, Errands, Out and about), 05 zeigt Aufgabe "Rasen maehen" mit Contexts "Garden" einmal plus KI-Stern. Konsistent mit BESCHREIBUNG.md.

### Runde 2 (nachgebohrt)

- [x] AC-5 Beleg-Kette: echter Weg (alter Stand -> neuer Build, gleiche Installation, persistenter Speicher) zeigt Dublette weg. Von Hand gesetzt war nur der Ausgangszustand (alte App), das ist der reale Upgrade-Zustand. Schwaeche: Bilder 04/05 stammen aus einem Ansichts-Test in einer Scratch-Kopie, und "nur eine Zeile nach erneutem Start" unterscheidet nicht zwischen "gespeichert" und "bei jedem Start neu zusammengefuehrt" (Merge ist idempotent). Das Speichern ist nur per Quelltext belegt (try modelContext.save() unmittelbar nach dem Merge). Kein unit-test ruft startUp auf.
  Code reference: LooseEnds/App/ContentView.swift:70
- [x] Revisionen/Frage 3: Merge fasst Revisionen und *SourceRaw nicht an; Zuordnung laeuft ueber Namen, Revisionswerte tragen den Namen, der beim Ueberlebenden erhalten bleibt (gleicher nameKey). Keine Aufgabe bleibt ohne Kontext, weil der Ueberlebende immer angehaengt wird.
  Code reference: Shared/Services/CatalogService.swift:50
- [x] AC-7: UI-Test testSecondGardenIsRejected in docs/artifacts/.../ui-test-output.txt bestanden (Alert "A context with this name already exists.", Editor zaehlt genau einen "Garden"-Button). Tests pruefen Alert und Anzahl, nicht nur Existenz.
  Code reference: LooseEnds/Views/SidebarView.swift:123

Offene Zweifel (alle LOW, keine Spec-Verletzung): leere Namen, Rohname-Revision, spaete Sync-Dubletten, fehlender Test fuer startUp.

### Beobachtungen (LOW, keine Spec-Verletzung, vom Adversary nicht als Defekt gewertet)

- Randfall leere Namen: Kontexte mit leerem/Leerzeichen-Namen haben denselben nameKey "" und werden zusammengefuehrt (Aufgaben vereint, Rest geloescht). Ueber die UI nicht anlegbar (emptyName), nur durch Fremddaten; folgenlos, LOW.
  Code reference: Shared/Services/CatalogService.swift:79
- Randfall Revision-Wiederherstellung: Hat die Dublette "garden " (anderes Casing/Leerzeichen) getragen, haelt eine alte Revision diesen Rohnamen; FieldCodec.decode vergleicht exakt (`names.contains($0.name)`), der Ueberlebende heisst anders, ein Zuruecksetzen auf diese Revision ordnet dann nichts zu. Theoretisch, nicht belegt, LOW.
  Code reference: Shared/Services/CatalogService.swift:77
- Randfall CloudKit-Nachlieferung: Dubletten, die nach dem Start per Sync eintreffen, werden erst beim naechsten Start zusammengefuehrt (spec-konform, AC-5 sagt "bei jedem Start"). Waehrenddessen ist die Doppelanzeige moeglich. Nicht beweisbar im Simulator, AMBIGUOUS-Hinweis, kein Defekt gegen die Spec.
  Code reference: LooseEnds/App/ContentView.swift:62

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:34f046dc833e1ae0c08d61abd88c5f9538b4eecf3aecb8d5360981cc0dd3347c  LooseEnds/App/ContentView.swift
- sha256:bddb0e11c54c24144fc0e3d13e52cfdcbfb9dfdfa62ac0c262f4a15e1a9a9850  LooseEnds/Views/SidebarView.swift
- sha256:080fae7ae736d876241676eb3cce2ec6f0dcb6ba593bbdeecc082ac247061df0  Shared/Services/CatalogService.swift

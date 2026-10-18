# #442 Schnitt 2 – Stufe-2-Nachweis im Simulator (AC-7 bis AC-10)

Datum: 2026-10-18, 10:41–11:57. Stand: Worktree lovely-dancing-parnas, HEAD 11c9863 plus ungesicherte Arbeitsänderungen
(LooseEndsShare/*, Shared/Services/SharedAttachmentFile.swift, project.yml). Simulator iPhone 17, iOS 27.0
(3066F2CC-A9AD-40F9-A2E7-A29B1BEA6AD1), Sprache Deutsch. Kein Gerät berührt.

## Weg

- `./scripts/sim.sh generate`, `build`, `launch` (installiert diesen Stand; die Aktivierungsregel der installierten
  Erweiterung enthält `public.image` und `public.data` – vorher lag ein älterer Bau einer anderen Sitzung im Simulator,
  in dem Loose Ends bei Fotos fehlte, auch unter „Mehr“).
- Material: 13 PNG-Fotos (320×240, 776–868 Byte) per `simctl addmedia`; `Rechnung_Stadtwerke_Oktober.pdf` (607 Byte) und
  `Film.mov` (60 MB) in den Speicher „Auf meinem iPhone“ der Dateien-App (File Provider Storage) gelegt.
- Ein Wegwerf-XCUITest (danach gelöscht) steuert Fotos (`com.apple.mobileslideshow`) und Dateien
  (`com.apple.DocumentsApp`): Foto öffnen bzw. „Auswählen“ + elf Fotos bzw. Datei lange drücken → „Teilen“ → Zelle
  „Loose Ends“ in der App-Reihe des Teilen-Blatts → Maske. Lauf mit `./scripts/sim.sh test`, Bildschirmfotos per
  `XCUIScreen`. Alle fünf Teilen-Fälle grün (zweiter Gesamtlauf 11:38–11:48).
- Temp-Ordner: ein Beobachter auf dem Mac liest alle 0,5 s den `tmp`-Ordner im Datencontainer der Erweiterung
  (`com.henning.looseends.share`) und notiert jede Änderung (ohne die Systemordner `.LINKS`, `TemporaryItems`).
- Detail: Der unsignierte Simulatorbau hat keine App-Gruppe (bekannt, #377). Erweiterung und App schreiben deshalb in
  getrennte lokale Speicher. Gespeicherte Daten per `sqlite3` direkt im Speicher der Erweiterung geprüft; für die
  Detail-Bilder wurde dieser Speicher in den Rückfall-Speicher der App kopiert und die App ohne `--ui-testing` gestartet
  (ersetzt, was auf dem Gerät die App-Gruppe tut). Danach der alte App-Speicher zurückgelegt.

## AC-7 – ein Foto: belegt

- `sim-ac7-foto-maske.png`: Blatt „Erfassen“, links „Abbrechen“, rechts „Fertig“ ausgegraut. Textfeld leer mit
  Platzhalter „Was soll ich aufnehmen?“ und blinkender Einfügemarke, deutsche Tastatur offen. Darunter „Anhänge“ mit
  einer Zeile: blaues Bildsymbol, „foto13.PNG“, rechts grau „868 Byte“. Testereignis: `done-enabled-before-text=false`.
- `sim-ac7-foto-maske-mit-text.png`: Text „Foto vom Zählerstand ablegen“ getippt, „Fertig“ jetzt schwarz/aktiv,
  Anhangzeile unverändert.
- Speicher der Erweiterung: Aufgabe „Foto vom Zählerstand ablegen“, Kanal `share`, 1 Anhang `foto13.PNG`, `public.png`.
- `sim-ac7-foto-detail.png`: Detail „Foto vom Zählerstand ablegen“, unter „ANHÄNGE“ die Zeile Bildsymbol + „foto13.PNG“,
  darunter „Foto / Datei / Scan“.

## AC-8 – PDF aus Dateien: belegt

- `sim-ac8-pdf-maske.png`: Textfeld vorbelegt mit „Rechnung Stadtwerke Oktober“ (Unterstriche zu Leerzeichen, ohne
  „.pdf“), „Fertig“ sofort aktiv (schwarz). Unter „Anhänge“: Dokumentsymbol, „Rechnung_St…ke_Oktober.pdf“ (in der Mitte
  gekürzt), „607 Byte“. Keine Tastatur offen (Feld ist gefüllt, Fokus nur bei leerem Feld).
- Speicher: Aufgabe „Rechnung Stadtwerke Oktober“ mit 1 Anhang `Rechnung_Stadtwerke_Oktober.pdf`.
- `sim-ac8-pdf-detail.png`: Detail-Titel „Rechnung Stadtwerke“ (vom Modell umformuliert, „GESAGT Rechnung Stadtwerke
  Oktober“), unter „ANHÄNGE“ Dokumentsymbol + „Rechnung_Stadtwerke_Oktober.pdf“.

## AC-9 – elf Fotos und Datei über 50 MB: belegt

- `sim-ac9-elf-fotos-oben.png`: Maske mit leerem Feld, Tastatur, „Anhänge“ mit foto03 bis foto06, je „780 Byte“.
- `sim-ac9-elf-fotos-unten.png`: weitergescrollt: foto07 (780), foto08 (867), foto09–foto11 (776), foto12 (779 Byte),
  elfte Zeile „foto13.PNG“ mit grauem „Mehr als 10 – nicht angehängt“ statt Größe.
- Speicher: Aufgabe „Elf Fotos vom Umzug“ mit genau 10 Anhängen (foto03–foto12), foto13 fehlt.
- `sim-ac9-elf-fotos-detail-oben.png` / `-unten.png`: Detail „Elf Fotos vom Umzug“, unter „ANHÄNGE“ foto03.PNG bis
  foto12.PNG (zehn Zeilen), dann „Foto / Datei / Scan“.
- `sim-ac9-zu-gross.png`: Maske mit leerem Feld, Tastatur, „Fertig“ gesperrt; Zeile Dateisymbol, „Film.mov“, rechts
  grau zweizeilig „Zu groß (max. 50 MB) – nicht angehängt“.
- Speicher: Aufgabe „Großer Film“ mit 0 Anhängen. `sim-ac9-zu-gross-detail.png`: Detail „Großer Film“, „ANHÄNGE“ zeigt
  nur „Foto / Datei / Scan“, keine Anhangzeile.
- Englische und deutsche Texte stehen in `LooseEndsShare/Localizable.xcstrings` (Durchsicht; im Simulator sichtbar: Deutsch).

## AC-10 – Temp-Ordner nach Fertig und Abbrechen: belegt

Zeitleiste des zweiten Gesamtlaufs (Testereignis | Beobachter):

| Fall | Maske offen | Ordner `SharedAttachments-…` | Aktion | Ordner danach |
|---|---|---|---|---|
| Foto | 11:39:39 | 1 Datei (foto13.PNG, 868 B) | Fertig 11:39:53 | LEER 11:39:53 |
| Abbrechen | 11:40:45 | 1 Datei | Abbrechen 11:40:53 | LEER 11:40:53 |
| Elf Fotos | 11:41:46 | 11 Dateien | Fertig 11:41:58 | LEER 11:41:58 |
| PDF | 11:44:39 | 1 Datei (607 B) | Fertig 11:44:47 | LEER 11:44:47 |
| Film 60 MB | 11:47:32 | Ordner leer, 0 Dateien (nichts kopiert) | Fertig 11:47:42 | LEER 11:47:42 |

Der erste Gesamtlauf (11:01–11:07) zeigt dasselbe Muster. `sim-ac10-nach-abbrechen.png`: nach „Abbrechen“ wieder das
Teilen-Blatt von Fotos („1 Photo Selected“, App-Reihe Erinnerungen, Restock, Loose Ends, Vorschau); der Speicher
der Erweiterung enthält 9 Aufgaben aus 9 „Fertig“-Vorgängen, keine aus den zwei „Abbrechen“.

## Auffälligkeiten

- Beim Elf-Fotos-Fall wird auch das elfte Foto in den Temp-Ordner kopiert (11 Dateien), obwohl es nicht angehängt wird;
  es wird mit dem Ordner gelöscht. Kein Fehler gegen die Spec, nur unnötige Kopie.
- Bei der zu großen Datei bleibt das Textfeld leer (kein Vorschlag aus „Film“); Spec fordert dort nichts.
- Teilen-Blatt-Kopf „1 Photo Selected“ ist englisch (Systemtext von Fotos, nicht unsere App).
- `sim-app-start-nach-teilen.png` / `sim-app-liste-neu.png`: App-Start „9 zum Durchsehen“, Liste „Neu“ mit den neun
  geteilten Aufgaben (zwei Gesamtläufe).

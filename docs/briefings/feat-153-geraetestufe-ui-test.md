---
entity_id: feat-153-geraetestufe-ui-test
type: briefing
created: 2026-09-30
workflow: feat-153-geraetestufe-ui-test
spec_file: docs/specs/tooling/feat-153-geraetestufe-ui-test.md
spec_sha256: 55cd502ccf6dd41e4fd63be0a64e4b414432d6b40933d3f694b6c456ec895fb5
---

# PO-Briefing: #153 — Rückbau der Gerätestufe

## Was gebaut wird

Rückbau: Der Befehl, der Stufe 3 auf Hennings iPhone testen sollte, wird vollständig entfernt. Er
hatte die Installation überschrieben und das Gerät blockiert, ohne etwas zu beweisen. Stufe 3
bleibt: lesender Gerätestatus plus die Labor-App, die Henning selbst bedient.

## Definition of Done

Alle Bezeichner und der Prüfstand des entfernten Befehls sind weg, Dokumentation und
Entscheidungsgrundlage nachgezogen, kein Produktpfad angefasst, Tests bleiben grün.

## Wie geprüft wird

Datei- und Textsuchen belegen die Abwesenheit des Befehls, automatisierte Tests laufen grün. Ein
Rückbau beweist nur Abwesenheit — nie, dass Hennings Gerät unangetastet blieb.

## Kritische Anmerkungen

- Scoping gerissen (6 Dateien, 397 Zeilen) — Empfehlung Weg A ist nicht neutral, Freigabe entscheidet das mit.
- Issue-Titel verspricht „gezielte Sonden" — die Spec liefert keine.
- Nachweislücke: Apple Intelligence, Watch, Widgets, Teilen, Mikrofon, Mitteilungen bleiben auf dem Gerät unbelegt.
- Labor-App bleibt einziger Messweg, Henning tippt selbst — Spannung zur „keine manuellen Tests"-Regel offen.
- Folgearbeit (#156, #143, #160, #157, #158) ohne Termin, ohne Zuständigkeit.

## Was das Ticket verlangt hat und was die Spec liefert

| Verlangt | Spec liefert |
|---|---|
| Befehl fährt Ablauf auf dem Gerät | kehrt um — Befehl entfernt |
| Klarer Abbruch bei Sperre | kehrt um — Erkennung mit entfernt |
| Screenshots als Artefakt | kehrt um — Export mit entfernt |
| Ein Lauf zeigt Wiedererkennung grün, belegt | teils erfüllt — Beleg bleibt, nicht wiederholbar |
| `04-stand.md` neu beschrieben | liefert, aber als Rückbau statt Fortbestand |
| Prüfpunkt nimmt Lauf als Nachweis an | lässt fallen — kein Lauf mehr |
| Kommentar 30.9.: solide Teile als Grundlage für Sonden behalten | lässt fallen, weiter als verlangt |

## Empfehlung

**Freigeben mit einer Auflage:** Henning entscheidet zusätzlich ausdrücklich zwischen Weg A (sofort,
über die Grenzen hinaus) und Weg B (aufgeteilt) — nicht nur durch die Freigabe der ganzen Spec. Der
Rückbau selbst ist begründet: Der invasive Befehl hat im echten Lauf sein Versprechen nicht
eingelöst und dabei sein Gerät blockiert. Die Nachweislücke für Watch, Widgets, Teilen, Mikrofon und
Mitteilungen bleibt für unbestimmte Zeit bestehen — das sollte er mit dieser Freigabe bewusst in
Kauf nehmen.

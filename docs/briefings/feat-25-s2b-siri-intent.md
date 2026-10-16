---
spec_file: docs/specs/intents/feat-25-s2b1-siri-intent.md
spec_sha256: acf20dd76013727114c394a30ca3ef6c8c62b0e205353cad2939e05b99666a0d
spec_frozen_sha256: f998770aead55c76f9a1ac37ae1cc6290312d9295a83cea19173f4a9257352ca
---

# PO-Briefing: feat-25-s2b-siri-intent

- **Spec:** docs/specs/intents/feat-25-s2b1-siri-intent.md
- **Issue:** #25
- **Erstellt:** 2026-10-16

## Was gebaut wird

Siri legt über Apples Erinnerungs-Schema in Loose Ends eine Aufgabe mit Titel, Datum, Liste, Ort und weiteren Angaben an.

## Definition of Done

Im Simulator erscheint die per Kurzbefehle angelegte Aufgabe mit Titel und Datum in der Liste; am iPhone klappt Siri oder die Ablehnung ist dokumentiert.

## Wie geprüft wird

Automatische Tests prüfen Anlegen, Ablehnen und Adresssuche; ob Siri auf Deutsch diesen Weg nimmt, zeigt nur dein iPhone-Test.

## Kritische Anmerkungen

- Siri-Weg auf Deutsch ist unbelegt; Beleg erst nach Merge am iPhone, Ticket #25 bleibt bis dahin offen.
- Bei abgelehnten Angaben liest Siri nur einen allgemeinen Fehlersatz; verständliche Fehlertexte folgen erst im nächsten Schnitt.
- Bilder und Abschnitte werden abgelehnt statt gespeichert; solche Siri-Aufträge scheitern.

## Freigabe-Frage

Soll der Siri-Intent zuerst gebaut und am iPhone getestet werden, bevor verständliche Fehlertexte entstehen?

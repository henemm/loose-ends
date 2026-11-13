---
spec_file: docs/specs/feat-795-schnitt-5a1-geraet-anmelden.md
spec_sha256: 6f9e085b3688766d81b904d68f80807b0f24218318c875a03cbbcd38b0702e61
spec_frozen_sha256: bee077a337a1e17a1955867eaec67371d424bbf42c7b9a7f6c9703696a800f22
---

# PO-Briefing: feat-795-s5-weckruf

- **Spec:** docs/specs/feat-795-schnitt-5a1-geraet-anmelden.md
- **Issue:** #795
- **Erstellt:** 2026-11-13

## Was gebaut wird

Der Dienst kann sich merken, unter welcher Apple-Adresse jedes Gerät eines Kontos erreichbar ist; geweckt wird noch nichts.

## Definition of Done

Die Dienst-Prüfungen laufen grün, und der Dienst nimmt Geräteadressen an, ersetzt sie, begrenzt sie auf zehn je Konto und löscht sie mit dem Konto.

## Wie geprüft wird

Automatische Dienst-Tests mit Wegwerf-Datenbank belegen jede Regel; ein echtes Wecken oder die App-Seite wird noch nicht geprüft.

## Kritische Anmerkungen

- Der Datenschutztext nennt die Geräteadresse noch nicht; vor dem App-Schritt müssen Text und Website angepasst und von dir freigegeben sein.
- Nur Teilschnitt: Der Weckruf wirkt erst nach drei weiteren Schritten, darunter deine Anmeldung im Apple-Portal.
- Die Dateigrenze wird nur einmalig bei der Abschlussprüfung belegt, nicht durch einen Test.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen

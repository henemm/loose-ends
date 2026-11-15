# Protokoll B: Stufe 3 über TestFlight (#615 S4f)

- Bau: Version 1.0.2, TestFlight-Lauf 43604550720 mit `konto=true` (2026-11-14), Stand `main` nach PR #924.
  Vorlauf 43580196966 scheiterte am Upload, weil Apple den Zug 1.0.1 geschlossen hatte (Henning, 2026-11-14: 1.0.2).
- Ablauf laut „Was testen“: Einstellungen › „Claude“ › „Mit Apple anmelden“, „Angemeldet mit Apple“ mit „Dieses Gerät“,
  „Abmelden“ ohne Rückfrage, erneut anmelden. „Konto löschen“ nicht angetippt (PO-Entscheidung 2026-11-14: sein echtes
  Konto bleibt; Löschen ist in Protokoll A gegen den lokalen Dienst belegt).
- Rückmeldung Henning (2026-11-15): „funktioniert“.
- Gegenprobe am Live-Dienst (rennwienix, nur lesend, nur Zahlen, 2026-11-15): `accounts` 1, `sessions` 1, davon 1 in den
  letzten 24 h angelegt, `apple_tokens` 2 (App und Web-Anmeldung). Die beim Abmelden beendete Sitzung ist weg, die neue
  Anmeldung hält genau eine Sitzung; kein zweites Konto entstanden.

Folge zu #24: Teilen aus Apple Mail liefert auf iOS 27.0 nie eine `message:`-URL (Bericht: `docs/reference/mail-ruecksprung-messung.md`). Das Muss „Rücksprung zur Quell-Mail“ (User-Story, Entscheidung #6) hat deshalb keinen Weg mehr.

## Ziel
Ein belegter Weg, auf dem eine Aufgabe aus Mail einen echten Rücksprung zur Quell-Mail bekommt.

## Wege zu prüfen (Alternativen zu ADR-9 „Teilen-Menü“)
- A. Mail aus Mail in die App ziehen (iPad/Mac; iPhone mit zwei Händen). Auf iOS die einzige dokumentierte Stelle, an der Mail einen Mail-Link herausgibt (NSHipster, OmniFocus). Braucht ein Drop-Ziel in der App.
- B. Siri-Bildschirminhalt von Mail über #25 (App-Schema): prüfen, ob die Übergabe eine Mail-Referenz trägt.
- D (Boden): kein Rücksprung, Betreff und Absender als Text. Dann wird das Muss in der User-Story zum Kann, und Entscheidung #6 ändert sich.

## Definition of Done
- [ ] Je Weg gemessen oder ausdrücklich verworfen, mit Beleg im Bericht.
- [ ] Entscheidung über ADR-9 und das Muss „Rücksprung“ (User-Story, Entscheidung #6) getroffen und dokumentiert.
- [ ] Bei einem tragfähigen Weg: Umsetzung als eigenes Ticket mit Tests.

# Context: feat-625-weckruf-datenschutz

## Request Summary
Der öffentliche Datenschutztext (de + en) beschreibt den Weckruf noch nicht: Seit #795 S5c (gemergt, im TestFlight-Konto-Bau
aktiv) meldet die App nach jeder Anmeldung ein Apple-Gerätetoken an den Dienst, und der Dienst weckt damit die App per stiller
Push-Mitteilung, sobald Claude einen Auftrag hinterlegt. Ziel: Wortlaut für Entwurf und Website-Seite schreiben, Henning zur
Freigabe vorlegen, danach Entwurf, Prüfskript und beide Website-Seiten nachziehen (Muster #625 Schnitt 1).

## Related Files
| File | Relevance |
|------|-----------|
| `docs/reference/datenschutz-entwurf.md` | Quelle des Textes: Abschnitt „Wenn du die Verbindung zu Claude nutzt“ (de, Z. 72–124), „4. If you use the connection to Claude“ (en, Z. 269–316), „Beleg im Code“, „Offen, nicht belegt“ (Punkt „Weckruf (Push-Token)“ Z. 209–212 kündigt genau diesen Nachtrag an), Statuskopf |
| `scripts/test_datenschutz_text.py` | Prüfskript: `ANCHORS` (wörtliche Kernsätze, auch Live-Prüfung mit `DATENSCHUTZ_LIVE=1`), `STALE`, `CheckerTests` |
| henemm/henemm-website `content/legal/loose-ends/privacy-policy/_index.md`, `…/privacy-policy-en/_index.md` | Öffentliche Seiten, erst nach Freigabe ändern |
| `docs/reference/app-store-datenschutzangaben.md` | Fragebogen-Vorlage (#625 S3): nennt das APNs-Gerätetoken schon unter Device ID; kein Änderungsbedarf zu erwarten, nur Abgleich |
| `CLAUDE.md` (Datenschutz-Absatz unter „Build“) | Satz „der Weckruf-Absatz (Push-Token) folgt mit #795 S5c-2“ wird ersetzt |
| `docs/specs/feat-625-schnitt-1-datenschutztext.md` | Vorlage für Spec, ACs, Belege, Ablauf (Freigabe → Entwurf → Website-PR → Live-Prüfung) |

## Fakten aus dem Code (Belegquellen)
- **Wann gemeldet:** `LooseEnds/Claude/PushWakeUp.swift` fragt bei jeder Anmeldung (`signedIn` neu) `registerForRemoteNotifications` an; `DeviceRegistration.register(token:)` meldet nur mit Sitzung (`AccountState.withSession`), dasselbe Paar nur einmal.
- **Was gesendet wird:** `ServiceClient.putDevice` → `POST /app/device` mit `token` (Hex), `environment` (sandbox/production), Kopf `X-Device` (Kennung dieser Installation).
- **Was gespeichert wird:** `server/migrations/008_device_tokens.sql`: `account_id`, `device`, `token`, `environment`, `updated_at`; ein Token gehört genau einem Konto/Gerät; `server/src/devices.ts` höchstens 10 Geräte je Konto (älteste fallen weg), ein umgezogenes Token verlässt den alten Besitzer.
- **Wofür:** `server/src/mcp.ts` `storeOrder` weckt nach jedem neu gespeicherten Auftrag; `server/src/apns.ts` sendet an Apple Push Notification service (APNs) den festen Inhalt `{aps:{content-available:1}, looseends:{v:1}}` — kein Aufgabeninhalt, keine sichtbare Mitteilung; höchstens ein Push je Gerät je 15 min.
- **Wie lange:** Abmelden lässt die Zeile stehen (`/auth/logout` → nur `endSession`); „Konto löschen“ entfernt sie (Cascade); Apple meldet ein Token ungültig (410 `Unregistered`, 400 `BadDeviceToken`/`DeviceTokenNotForTopic`) → `dropToken` löscht es.
- **Protokolle:** Dienstlog nennt nie Token oder Konto (#960); nginx protokolliert wie für alle Pfade IP, Pfad, Zeit, Code.
- **Apple:** Zustellung über APNs = Apples System → passt in „Was Apple dabei übernimmt“ oder in den Weckruf-Absatz selbst.

## Existing Patterns
- Nachtrag je Absatz mit fettem Lead („**Kennung dieser Installation.**“), de zuerst, en wortgetreu; Belegtabelle je Aussage; Statuskopf nennt Freigabe und Website-PR.
- Rechtstext nur nach Hennings ausdrücklicher Freigabe live (Memory „Rechtstext erst nach Freigabe live“), keine Auto-Ampel.

## Dependencies
- Upstream: #795 S5c (Code gebaut), #960 (Drossel, Logform).
- Downstream: Website-Seiten, `ASC_PRIVACY_POLICY_URL` (bleibt), Store-Schalter `LEAccountEnabled` (bleibt aus, #625).

## Risks & Considerations
- Aussage „Abmelden“: Token bleibt nach Abmelden gespeichert und das Gerät kann weiter still geweckt werden, ohne dass die App etwas abholt — muss ehrlich im Text stehen oder als Folgearbeit (Token beim Abmelden löschen) angelegt werden. Alternative statt Textpflaster.
- Löschsatz und Kennungs-Absatz („mitgeschickt beim Abholen …“) werden durch `putDevice` mit `X-Device` unvollständig; beide anpassen.
- Kein Pfad der Geräteliste berührt (nur `docs/`, `scripts/`, `CLAUDE.md`, Website-Repo).

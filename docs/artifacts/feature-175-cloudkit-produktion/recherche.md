# #175 Recherche: CloudKit Development → Production (2026-10-08)

Stand der Quellen vor jeder Messung. Was hier steht, ist gelesen, nicht gemessen.

## Belegt

| # | Befund | Quelle |
|---|--------|--------|
| R1 | Development und Production sind getrennte Datenbestände. Xcode-Läufe: Development. TestFlight und App Store: immer Production. | [Forum 771966 (DTS)](https://developer.apple.com/forums/thread/771966), [Forum 795826 (DTS, 08/2025)](https://developer.apple.com/forums/thread/795826) |
| R2 | Production legt kein Schema per Just-in-Time an. Ohne „Deploy Schema Changes“ lehnt CloudKit Lesen und Schreiben ab, die Daten bleiben nur lokal. | [fatbobman](https://fatbobman.com/en/snippet/why-core-data-or-swiftdata-cloud-sync-stops-working-after-app-store-login/), [Forum 748719](https://developer.apple.com/forums/thread/748719) |
| R3 | Das Schema nach Production zu bringen geht nur über den Knopf in der CloudKit Console. `cktool` kann Production nur auslesen (`export-schema --environment production`); `import-schema` geht nur nach Development. Dafür braucht es einen Management-Token aus der Console. | [Apple: Using cktool](https://developer.apple.com/icloud/ck-tool/) |
| R4 | Nach dem Deploy sind nur additive Änderungen möglich: neue Felder, neue Typen. Nichts lässt sich löschen oder umbenennen. Empfehlung: ein Versionsfeld je Entität. Jede Modelländerung braucht vor dem nächsten TestFlight-Bau einen erneuten Deploy. | [Forum 748719](https://developer.apple.com/forums/thread/748719), [Apple: Designing a CloudKit database](https://developer.apple.com/documentation/cloudkit/designing-and-creating-a-cloudkit-database) |
| R5 | Unvollständig deployte Schemata zeigen sich in TestFlight als „Field 'recordName' is not marked queryable“. DTS empfiehlt, Development und Production per `cktool export-schema` zu vergleichen. | [Forum 814617 (DTS)](https://developer.apple.com/forums/thread/814617) |
| R6 | Für TestFlight-Exporte beachtet Xcode den Umgebungs-Eintrag `com.apple.developer.icloud-container-environment` nicht mehr; der Export setzt immer Production. Nur ein Ad-hoc-Export („Custom → Release Testing“) erlaubt die Wahl. | [Forum 842909 (DTS, 08/2026)](https://developer.apple.com/forums/thread/842909) |
| R7 | Ein Xcode-Lauf mit dem Eintrag `…-environment = Production` in der Debug-Berechtigung spricht mit Production. Belegt ist das nur für 2022 und nur durch einen Entwickler, nicht durch Apple. Ob es mit Xcode 27 noch gilt, ist offen. | [Forum 707098](https://developer.apple.com/forums/thread/707098) |
| R8 | Wird die TestFlight-Fassung über die Xcode-Fassung installiert, ohne die App zu löschen, „zeigen sich alle Daten“, aber beide Fassungen gleichen nicht miteinander ab. Wird die App gelöscht und aus TestFlight neu installiert, sind die Daten weg. | [Forum 763062](https://developer.apple.com/forums/thread/763062) |
| R9 | Der lokale Speicher überlebt den Wechsel der Fassung und wird von beiden gelesen. Das täuscht leicht einen funktionierenden Abgleich vor. | [Forum 771966](https://developer.apple.com/forums/thread/771966), [HWS-Forum 10714](https://www.hackingwithswift.com/forums/swiftui/swiftui-app-failing-to-sync-cloudkit-data-but-only-in-testflight-version/10714) |
| R10 | Apple hat für SwiftData keine Programmschnittstelle, um das Schema anzulegen. Der Umweg führt über `NSPersistentCloudKitContainer.initializeCloudKitSchema()`. Auch WWDC26 (SwiftData Group Lab) nennt keine. | [fatbobman: initializeCloudKitSchema](https://fatbobman.com/en/snippet/resolving-incomplete-icloud-data-sync-in-ios-development-using-initializecloudkitschema/), [WWDC26 8017](https://developer.apple.com/videos/play/wwdc2026/8017/) |
| R11 | Vorbild für eine Schutzschranke: ein Schema-Abbild im Repo, ein Test „Modell = Abbild“ und eine Prüfung vor jedem TestFlight-Bau, die ein abweichendes Production-Schema per `cktool` erkennt und den Bau anhält. Den Deploy-Knopf drückt trotzdem ein Mensch. | [wiggle-room #40](https://github.com/martinkearn/wiggle-room/issues/40) |

## Erklärung für Hennings Erfahrung (Hypothese, nicht gemessen)

„Bei meinen anderen Apps nie Probleme“ passt zu R8/R9: Nach dem Wechsel der Fassung sind die Daten auf
**demselben Gerät** weiter zu sehen, weil der lokale Speicher bleibt. Ob sie auch auf einem **zweiten Gerät**
ankommen, zeigt erst ein Abgleich. Den hat das Wechseln allein nie geprüft.

## Offen, nur durch Messung zu klären

- O1: Lädt die TestFlight-Fassung Aufgaben, die schon nach Development exportiert wurden, erneut nach Production hoch?
  Keine Quelle sagt es. R8 spricht eher dagegen: Die Daten sind lokal da, gleichen aber nicht ab.
- O2: Ist das Schema von `iCloud.com.henning.looseends` in Production schon ausgerollt? → `cktool export-schema`
  mit Management-Token, oder ein Blick in die Console.
- O3: Gilt R7 unter Xcode 27 noch? → Probe mit der Prüfkennung (`.probe`), nie mit Hennings Installation.

## Wege (Stand Recherche)

1. **Schema ausrollen, Henning steigt auf TestFlight um, Neustart in Production.** Development bleibt als Archiv.
2. **Schema ausrollen und Daten einmal umziehen.** Entweder O1 trägt (die TestFlight-Fassung lädt den lokalen
   Speicher hoch), oder eine einmalige Exportfunktion schreibt alle Felder, Revisionen und Kontexte neu.
3. **Xcode-Fassung auf Production stellen (R7).** Kein Umzug für künftige Daten; die Daten in Development bleiben
   trotzdem zurück. Risiko: Jeder Xcode-Lauf mit noch nicht ausgerolltem Modell schreibt gegen das echte Schema.

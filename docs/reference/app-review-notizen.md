# Notizen für App Review (Version 1.0.2, iOS und Mac)

Stand 2026-11-24 (#625 S5d-1). Eine Quelle für beide Plattformen: Der Text unten (erster Codeblock) kommt in das Feld „Notes“
der App-Review-Informationen der bearbeitbaren Version 1.0.2, iOS und Mac. Gesetzt wird er per Handlauf `asc-review-notes.yml`
mit `aktion=notizen` (höchstens 4000 Byte, ohne Platzhalter), je Plattform in die eine Version im Zustand
`PREPARE_FOR_SUBMISSION`. Die Bildschirmaufnahme, auf die Punkt 1 verweist, hängt S5d-2 an die Version; `notizen` läuft darum
erst unmittelbar vor diesem Schritt. Eingereicht wird erst nach Hennings Wort.

Vorgänger: der Text zu 1.0 (Antwort auf „Guideline 2.1 – Information Needed“, Stand 2026-11-01). Er sagte „kein Konto“ und
„kein eigener Server“; mit der Verbindung zu Claude (#615, #621, #795) stimmt das nicht mehr.

Jede Aussage unten ist am Repo geprüft (`LooseEnds/Info.plist`, `CLAUDE.md`, `LooseEnds/Views/AccountSection.swift`,
`docs/reference/datenschutz-entwurf.md`, `docs/reference/claude-abschrift-vertrag.md`).

```
1. SCREEN RECORDING
Screen recording of a physical iPhone 16 Pro, attached to this submission. The device runs the latest iOS.
It shows the typical flow: capture a task by voice (title, due date and tag are filled in from the spoken sentence), capture
one by typing, the "New" list, a task's detail view and the list of loose ends. It also shows the optional connection to
Claude: Sign in with Apple under Settings > Claude, adding Loose Ends as a connector in claude.ai, and deleting the account.
There is no user-generated content that is shared with other users (so no reporting or blocking), and no paid content or
in-app purchases.

2. PURPOSE AND AUDIENCE
Loose Ends is a task inbox for people who think of things faster than they can file them. You say or type one sentence; the
app turns it into a task with a title, a due date and tags. Audience: anyone who keeps a to-do list on iPhone, iPad, Mac and
Apple Watch and wants capturing to cost no effort. Value: nothing gets lost between "I should do that" and the list.

3. HOW TO USE IT
The app is fully usable without an account. Capturing and organizing tasks needs no sign-in and no sample files. Open the
app, tap the capture button, and say or type for example "Call the dentist tomorrow at 3 pm". The task appears under "New"
with its due date and appears in "Now" when it is due.
Connecting to Claude is optional: Settings > Claude. Sign-in is only through Sign in with Apple; please use your own Apple ID,
no demo credentials are needed. "Delete account" in the same place removes the account and everything the service keeps for
it, inside the app (Guideline 5.1.1(v)). Signing out or deleting leaves the tasks in the app as they are.
Microphone and speech recognition are asked on first use of voice capture; notifications when a task has a due date.
Calendar, camera and location are optional and asked only when the user switches the matching feature on (calendar mirror,
scanning a document into a task, reminder at a place).

4. EXTERNAL SERVICES
- Apple Intelligence (on-device Foundation Models) refines titles on the device. Without Apple Intelligence the app works
  fully: dates, times, tags and durations come from rules, not from the model.
- Apple speech recognition (on-device) for voice capture.
- iCloud (CloudKit, the user's private database) syncs tasks between the user's own devices.
- Our own service, run by us on a server in Germany, is used only after Sign in with Apple. It keeps a copy of the open
  tasks (title and fields such as due date and tags; never the raw text, notes or attachments) so that Claude can read
  them, and passes Claude's changes back to the app, which applies them on the device. Apple Push Notification service
  sends a silent notification so the app picks up a change.
- Claude: the user adds Loose Ends as a connector in claude.ai. This needs a Claude account; the screen recording shows
  the steps. Claude cannot delete tasks.
- Apple MapKit for choosing a place, Apple EventKit for the optional calendar mirror.
No third-party SDKs, analytics, advertising or payment services in the app.

5. REGIONS
The app behaves the same in all regions. The interface and the capture rules are available in German and English. The only
difference is Apple's own: Apple Intelligence is not offered on every device, language and region; where it is missing the
app uses its rules and says so in a short note.

6. REGULATED INDUSTRY
Not applicable. No regulated services, no protected third-party material.
```

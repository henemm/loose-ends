# Loose Ends

Say it, it's sorted.

A task app for iPhone, iPad, Mac and Apple Watch: one text field that takes anything, a quiet secretary
(on-device Apple Intelligence) that turns it into structure once, and views that fit the situation you are in.

Status: scaffold. The screens exist as a design canvas; the code is the data model, persistence, intents and
targets. See `docs/project/` for the decisions, user story, data model and design briefing.

## Build

```bash
brew install xcodegen xcbeautify
xcodegen generate
open LooseEnds.xcodeproj
```

Requires Xcode 26 and a device with Apple Intelligence (iPhone 15 Pro or later) for enrichment.

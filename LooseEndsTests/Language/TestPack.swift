@testable import LooseEnds

/// A language that does not exist (#755, Epic #750): `zz`, "Testish". Plugged in with `withPacks`, it proves that every
/// rule reads its words from the packs and that a third language needs no change in any rule file. All words are
/// folded, none is a word of a shipped language.
extension LanguagePack {
    static let test = LanguagePack(
        code: "zz",
        name: "Testish",
        numbers: ["uno": 1, "duo": 2, "trio": 3],
        weekdays: ["sundu": 1, "mondu": 2, "tuesdu": 3, "wednesdu": 4, "thursdu": 5, "fridu": 6, "saturdu": 7],
        months: [
            "janx": 1, "febx": 2, "marx": 3, "aprx": 4, "mayx": 5, "junx": 6,
            "julx": 7, "augx": 8, "sepx": 9, "octx": 10, "novx": 11, "decx": 12,
        ],
        relativeDays: ["blorp": 0, "snib": 1],
        nextWords: ["nexo"],
        dayUnits: ["dayo"],
        weekUnits: ["weeko"],
        dayPrepositions: ["ayo"],
        ordinalSuffixes: ["zth"],
        repetitions: ["everio"],
        timeCues: ["att"],
        clockWords: ["klok"],
        timeArticles: ["uno"],
        articleCues: ["att"],
        spelledHours: ["dekatrio": 13],
        hourUnits: ["quarnt"],
        abbreviatedHourUnits: ["qrn"],
        minuteUnits: ["minx"],
        spokenOffsets: [["halfo", "quarnt"]: 30],
        durationPhrases: ["halfquarnt": 30],
        pointInTime: ["inn"],
        importanceWords: ["explicit": ["zingo"]],
        urgencyWords: ["immediacy": ["zoom"]],
        negations: ["nix"],
        intensifiers: ["zuu"],
        placePhrases: [
            PlacePhrase(words: ["at", "florp"], slot: .home),
            PlacePhrase(words: ["at", "worx"], slot: .work),
        ],
        titleLeadIns: ["byy"],
        titleConnectors: ["unt"],
        titleDateWords: ["janx", "mondu"],
        contextWords: ["Garden": ["grassle"]]
    )
}

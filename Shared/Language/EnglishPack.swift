extension LanguagePack {
    static let english = LanguagePack(
        code: "en",
        name: "English",
        numbers: [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
            "nine": 9, "ten": 10, "eleven": 11, "twelve": 12,
        ],
        weekdays: [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7,
        ],
        months: [
            "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6, "july": 7,
            "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
        ],
        relativeDays: ["today": 0, "tomorrow": 1],
        nextWords: ["next"],
        dayUnits: ["day", "days"],
        weekUnits: ["week", "weeks"],
        offsetArticles: ["a", "an"],
        dayPrepositions: [],
        ordinalSuffixes: ["st", "nd", "rd", "th"],
        repetitions: ["every", "daily", "weekly", "monthly"],
        timeCues: ["at"],
        clockWords: [],
        timeArticles: [],
        articleCues: [],
        spelledHours: [:],
        hourUnits: ["hour", "hours", "h"],
        abbreviatedHourUnits: ["hrs", "hr"],
        minuteUnits: ["minutes", "min", "mins"],
        spokenOffsets: [["half", "an", "hour"]: 30, ["an", "hour"]: 60],
        durationPhrases: [
            "half an hour": 30, "half hour": 30, "quarter of an hour": 15, "an hour and a half": 90,
            "an hour": 60, "one hour": 60, "a few minutes": 5,
        ],
        pointInTime: ["in", "after"],
        importanceWords: [
            "explicit": ["very important", "important"],
            "money": ["invoice", "amount", "payment", "salary", "loan"],
            "official": ["tax", "official", "contract", "court", "lawyer"],
            "peopleWaiting": ["is waiting for", "are waiting for", "waiting for", "is expecting"],
        ],
        urgencyWords: [
            "deadline": ["deadline", "reminder", "cancellation"],
            "immediacy": ["asap", "urgent", "urgently", "immediately"],
        ],
        negations: ["not", "never", "isnt", "arent", "wasnt", "dont", "doesnt"],
        intensifiers: ["too", "very", "that"],
        placePhrases: [
            PlacePhrase(words: ["at", "home"], slot: .home),
            PlacePhrase(words: ["at", "work"], slot: .work),
            PlacePhrase(words: ["at", "the", "office"], slot: .work),
        ],
        titleLeadIns: ["by", "on", "at"],
        titleConnectors: ["and"],
        titleDateWords: [
            "january", "february", "march", "june", "july", "october", "december",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        ],
        contextWords: [
            "Computer": ["computer", "printer", "print out", "install", "spreadsheet"],
            "Phone": ["call", "phone", "ring back"],
            "Home": ["vacuum", "laundry", "dishes", "tidy up"],
            "Garden": ["lawn", "hedge", "weeds", "mow"],
            "Errands": ["buy", "pick up", "groceries", "pharmacy"],
            "Out and about": ["on the way", "gas station"],
        ]
    )
}

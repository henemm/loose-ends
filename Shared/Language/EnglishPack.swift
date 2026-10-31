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
        dayPrepositions: [],
        ordinalSuffixes: ["st", "nd", "rd", "th"],
        repetitions: ["every", "daily", "weekly", "monthly"]
    )
}

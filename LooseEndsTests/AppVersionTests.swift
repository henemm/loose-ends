import Testing
@testable import LooseEnds

@Suite struct AppVersionTests {
    @Test func versionAndBuildAreShownLikeTestFlight() {
        #expect(AppVersion.text(short: "0.1.0", build: "45") == "0.1.0 (45)")
    }

    @Test func missingPartsFallBack() {
        #expect(AppVersion.text(short: "0.1.0", build: nil) == "0.1.0")
        #expect(AppVersion.text(short: "", build: "45") == "(45)")
        #expect(AppVersion.text(short: nil, build: nil) == "–")
    }
}

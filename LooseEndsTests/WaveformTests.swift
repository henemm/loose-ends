import Foundation
import Testing
@testable import LooseEnds

@Suite("Waveform") struct WaveformTests {
    /// A constant-amplitude signal; its RMS equals the amplitude.
    private func signal(dBFS: Float) -> [Float] {
        let amplitude = pow(10, dBFS / 20)
        return [amplitude, -amplitude, amplitude, -amplitude]
    }

    @Test("Silence and an empty sample are zero")
    func silenceAndEmptyAreZero() {
        #expect(Waveform.level(of: []) == 0)
        #expect(Waveform.level(of: [0, 0, 0, 0]) == 0)
    }

    // #279: the bar scale is in decibels, −55 … −25 dBFS onto 0 … 1, so normal speech as measured on
    // the iPhone (Build 23, ≈ −40 dBFS under `.measurement`) fills half the height.
    @Test("−55 dBFS is the floor")
    func floorIsZero() {
        #expect(abs(Waveform.level(of: signal(dBFS: -55))) < 0.01)
    }

    @Test("−40 dBFS, measured speech, is half the height")
    func measuredSpeechIsHalf() {
        #expect(abs(Waveform.level(of: signal(dBFS: -40)) - 0.5) < 0.01)
    }

    @Test("−25 dBFS and a full-scale signal fill the bar")
    func ceilingIsOne() {
        #expect(abs(Waveform.level(of: signal(dBFS: -25)) - 1) < 0.01)
        #expect(Waveform.level(of: [1, -1, 1, -1]) == 1)
    }

    @Test("Below the floor clamps to zero")
    func belowFloorClampsToZero() {
        #expect(Waveform.level(of: signal(dBFS: -70)) == 0)
    }

    @Test("−36 dBFS, measured peaks, sits above half")
    func peaksAreAboveHalf() {
        #expect(abs(Waveform.level(of: signal(dBFS: -36)) - 0.63) < 0.02)
    }

    @Test("The ring grows with the level from the circle to 1.35 times it, clamped")
    func ringScale() {
        #expect(abs(Waveform.ringScale(for: 0) - 1) < 0.001)
        #expect(abs(Waveform.ringScale(for: 0.5) - 1.175) < 0.001)
        #expect(abs(Waveform.ringScale(for: 1) - 1.35) < 0.001)
        #expect(abs(Waveform.ringScale(for: -1) - 1) < 0.001)
        #expect(abs(Waveform.ringScale(for: 3) - 1.35) < 0.001)
    }

    @Test("The waveform keeps only the newest levels and clamps them to 0...1")
    func ringBuffer() {
        var waveform = Waveform()
        for index in 0..<(Waveform.capacity + 5) {
            waveform.append(Float(index) / Float(Waveform.capacity))
        }
        #expect(waveform.levels.count == Waveform.capacity)
        #expect(waveform.levels.first == Float(5) / Float(Waveform.capacity))
        #expect(waveform.levels.last == 1, "levels above one are clamped")

        waveform.append(-3)
        #expect(waveform.levels.last == 0, "levels below zero are clamped")
    }
}

/// #279/#297: "Listening …" stands where the recognized text will appear, until the first word.
@Suite("Listening hint") struct ListeningHintTests {
    @Test("Listening with an empty field shows the hint")
    func hintWhileListeningAndEmpty() {
        #expect(ListeningHint.state(isListening: true, text: "") == .hint)
    }

    @Test("Whitespace only counts as empty")
    func hintWhileListeningAndOnlyWhitespace() {
        #expect(ListeningHint.state(isListening: true, text: "  ") == .hint)
    }

    @Test("The first word replaces the hint")
    func noHintWhenTextPresent() {
        #expect(ListeningHint.state(isListening: true, text: "Milch") == .none)
    }

    @Test("Not listening with an empty field shows the usual placeholder")
    func placeholderWhenNotListening() {
        #expect(ListeningHint.state(isListening: false, text: "") == .placeholder)
    }

    @Test("Not listening with text shows neither")
    func noHintWhenNotListeningWithText() {
        #expect(ListeningHint.state(isListening: false, text: "Milch") == .none)
    }
}

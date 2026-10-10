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

    // #279: the bar scale is in decibels, −50 … −10 dBFS onto 0 … 1, so normal speech
    // without the system's gain control (`.measurement`) fills about half the height.
    @Test("−50 dBFS is the floor")
    func minusFiftyIsZero() {
        #expect(abs(Waveform.level(of: signal(dBFS: -50))) < 0.01)
    }

    @Test("−30 dBFS, normal speech, is half the height")
    func minusThirtyIsHalf() {
        #expect(abs(Waveform.level(of: signal(dBFS: -30)) - 0.5) < 0.01)
    }

    @Test("−10 dBFS and a full-scale signal fill the bar")
    func minusTenIsOne() {
        #expect(abs(Waveform.level(of: signal(dBFS: -10)) - 1) < 0.01)
        #expect(Waveform.level(of: [1, -1, 1, -1]) == 1)
    }

    @Test("Below the floor clamps to zero")
    func belowFloorClampsToZero() {
        #expect(Waveform.level(of: signal(dBFS: -70)) == 0)
    }

    @Test("Amplitude 0.05 (−26 dBFS) sits a little above half")
    func louderSpeech() {
        let speech = Waveform.level(of: [0.05, -0.05, 0.05, -0.05])
        #expect(abs(speech - 0.6) < 0.02)
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

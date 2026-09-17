import Foundation
import Testing
@testable import LooseEnds

@Suite("Waveform") struct WaveformTests {
    @Test("Silence is zero, a loud signal saturates at one, speech sits in between")
    func levels() {
        #expect(Waveform.level(of: []) == 0)
        #expect(Waveform.level(of: [0, 0, 0, 0]) == 0)
        #expect(Waveform.level(of: [1, -1, 1, -1]) == 1)
        let speech = Waveform.level(of: [0.05, -0.05, 0.05, -0.05])
        #expect(speech > 0.2 && speech < 0.5)
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

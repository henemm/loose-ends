import AVFoundation
import Foundation

/// The last few loudness levels, 0...1, for the bars that prove the microphone is listening
/// (design briefing, screen 1). Pure, so the level math is testable without a microphone.
struct Waveform: Equatable {
    static let capacity = 40

    private(set) var levels: [Float] = []

    mutating func append(_ level: Float) {
        levels.append(min(max(level, 0), 1))
        if levels.count > Self.capacity {
            levels.removeFirst(levels.count - Self.capacity)
        }
    }

    /// Bottom and top of the bar scale in dBFS (#279). Without the system's gain control (`.measurement`)
    /// normal speech sits near −30 dBFS, which lands at half the height.
    static let floorDecibel: Float = -50
    static let ceilingDecibel: Float = -10

    /// RMS of the samples in dBFS, mapped linearly from `floorDecibel … ceilingDecibel` onto 0 … 1.
    static func level(of samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let meanSquare = samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)
        let rms = meanSquare.squareRoot()
        guard rms > 0 else { return 0 }
        let decibel = 20 * log10(rms)
        return min(1, max(0, (decibel - floorDecibel) / (ceilingDecibel - floorDecibel)))
    }

    static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let samples = Array(UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength)))
        return level(of: samples)
    }
}

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

    /// RMS of the samples, scaled so normal speech fills most of the bar height.
    static func level(of samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let meanSquare = samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)
        return min(1, meanSquare.squareRoot() * 6)
    }

    static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let samples = Array(UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength)))
        return level(of: samples)
    }
}

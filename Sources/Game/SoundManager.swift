import AVFoundation
import Foundation

// MARK: - Retro bleeps, synthesized at runtime
//
// The BlackBerry original spoke in clicks and square-wave chirps. We
// generate tiny WAVs in memory so the game needs zero audio assets.

final class SoundManager {
    static let shared = SoundManager()

    enum Effect {
        case paddle, wall, brick, silver, capsule, shoot, gunFire, explosion,
             loseLife, levelClear, gameOver, launch, denied
    }

    private var players: [AVAudioPlayer] = []
    private var cache: [String: Data] = [:]
    var enabled = true

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    func play(_ effect: Effect) {
        guard enabled else { return }
        let data: Data
        switch effect {
        case .paddle: data = tone(freq: 520, ms: 40, type: .square, slideTo: 700)
        case .wall: data = tone(freq: 320, ms: 30, type: .square)
        case .brick: data = tone(freq: 880, ms: 60, type: .square, slideTo: 660)
        case .silver: data = tone(freq: 200, ms: 70, type: .square)
        case .capsule: data = arpeggio(freqs: [660, 880, 1320], msEach: 55)
        case .shoot: data = tone(freq: 1200, ms: 50, type: .saw, slideTo: 2400)
        case .gunFire: data = tone(freq: 180, ms: 120, type: .saw, slideTo: 90)
        case .explosion: data = noise(ms: 280)
        case .loseLife: data = arpeggio(freqs: [440, 330, 220, 150], msEach: 110)
        case .levelClear: data = arpeggio(freqs: [523, 659, 784, 1047, 1319], msEach: 90)
        case .gameOver: data = arpeggio(freqs: [400, 350, 300, 200, 140], msEach: 160)
        case .launch: data = tone(freq: 440, ms: 60, type: .square, slideTo: 880)
        case .denied: data = tone(freq: 160, ms: 120, type: .square)
        }
        do {
            let player = try AVAudioPlayer(data: data)
            player.volume = 0.5
            player.play()
            players.append(player)
            players = players.filter { $0.isPlaying }
        } catch {
            // Audio is garnish; never crash the game over a bleep.
        }
    }

    // MARK: Synthesis

    private enum Wave { case sine, square, saw }

    private func tone(freq: Double, ms: Int, type: Wave = .sine, slideTo: Double? = nil) -> Data {
        let rate = 22050.0
        let n = Int(rate * Double(ms) / 1000.0)
        var samples = [Int16]()
        samples.reserveCapacity(n)
        for i in 0..<n {
            let t = Double(i) / rate
            let f = slideTo.map { freq + ($0 - freq) * Double(i) / Double(max(n - 1, 1)) } ?? freq
            let phase = 2.0 * Double.pi * f * t
            let s: Double
            switch type {
            case .sine: s = sin(phase)
            case .square: s = sin(phase) >= 0 ? 0.7 : -0.7
            case .saw: s = 2.0 * (f * t - floor(f * t + 0.5))
            }
            let env = 1.0 - Double(i) / Double(n) // linear decay avoids clicks
            samples.append(Int16(max(-1.0, min(1.0, s * env * 0.6)) * Double(Int16.max)))
        }
        return wav(samples: samples, rate: Int(rate))
    }

    private func arpeggio(freqs: [Double], msEach: Int) -> Data {
        let rate = 22050.0
        var samples = [Int16]()
        for freq in freqs {
            let n = Int(rate * Double(msEach) / 1000.0)
            for i in 0..<n {
                let t = Double(i) / rate
                let s = sin(2.0 * Double.pi * freq * t) >= 0 ? 0.6 : -0.6
                let env = 1.0 - Double(i) / Double(n)
                samples.append(Int16(s * env * 0.6 * Double(Int16.max)))
            }
        }
        return wav(samples: samples, rate: Int(rate))
    }

    private func noise(ms: Int) -> Data {
        let rate = 22050.0
        let n = Int(rate * Double(ms) / 1000.0)
        var samples = [Int16]()
        samples.reserveCapacity(n)
        var last = 0.0
        for i in 0..<n {
            let white = Double.random(in: -1...1)
            last = last * 0.7 + white * 0.3 // low-passed rumble
            let env = 1.0 - Double(i) / Double(n)
            samples.append(Int16(last * env * 0.8 * Double(Int16.max)))
        }
        return wav(samples: samples, rate: Int(rate))
    }

    private func wav(samples: [Int16], rate: Int) -> Data {
        var data = Data()
        func append32(_ v: UInt32) {
            data.append(UInt8(v & 0xff)); data.append(UInt8((v >> 8) & 0xff))
            data.append(UInt8((v >> 16) & 0xff)); data.append(UInt8((v >> 24) & 0xff))
        }
        func append16(_ v: UInt16) {
            data.append(UInt8(v & 0xff)); data.append(UInt8((v >> 8) & 0xff))
        }
        data.append(contentsOf: "RIFF".utf8)
        append32(UInt32(36 + samples.count * 2))
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        append32(16); append16(1); append16(1)
        append32(UInt32(rate)); append32(UInt32(rate * 2)); append16(2); append16(16)
        data.append(contentsOf: "data".utf8)
        append32(UInt32(samples.count * 2))
        for s in samples {
            let u = UInt16(bitPattern: s)
            append16(u)
        }
        return data
    }
}

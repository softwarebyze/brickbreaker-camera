import Combine
import Foundation

// MARK: - HUD-observable game state
//
// The SpriteKit scene owns the simulation; it mirrors score/lives/level
// here so SwiftUI overlays stay in sync. Lives start at 3, like the original.

@MainActor
final class GameState: ObservableObject {
    /// One-time carry-over from the pre-rename high-score keys.
    static func migratedScore(newKey: String, oldKey: String) -> Int {
        let current = UserDefaults.standard.integer(forKey: newKey)
        if current != 0 { return current }
        let legacy = UserDefaults.standard.integer(forKey: oldKey)
        if legacy != 0 {
            UserDefaults.standard.set(legacy, forKey: newKey)
        }
        return legacy
    }

    @Published var score: Int = 0
    @Published var lives: Int = 3
    @Published var level: Int = 1
    @Published var highScore: Int = GameState.migratedScore(newKey: "CamBreakerHighScore", oldKey: "BrickBreakerHighScore")
    @Published var cameraBest: Int = GameState.migratedScore(newKey: "CamBreakerBest", oldKey: "BrickBreakerCameraBest")
    @Published var highScoreAtRunStart: Int = 0
    @Published var cameraBestAtRunStart: Int = 0
    /// True while the run still counts as camera-slider-only: camera steering
    /// selected and no touch-drag of the paddle yet. Taps (launch/fire) are
    /// fine — they don't steer.
    @Published var pureCameraRun = true
    @Published var cameraSteering = true
    @Published var ammo: Int = 0               // gun bullets remaining
    @Published var hasLaser = false
    @Published var hasCatch = false
    @Published var hasLong = false
    @Published var isFlipped = false
    @Published var isWrapped = false
    @Published var ballIsSlow = false
    @Published var bombArmed = false
    @Published var ballCount = 1
    @Published var phase: GamePhase = .menu
    @Published var message: String? = nil      // transient banner, e.g. "Multi!"
    // On by default: a visible camera feed is what keeps the Camera Control
    // overlay coming up, and it looks great dimmed behind the bricks.
    @Published var useCameraBackground = true

    func addScore(_ points: Int) {
        score += points
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(score, forKey: "CamBreakerHighScore")
        }
        // Bank the purist board live: only while the run still qualifies.
        if pureCameraRun && cameraSteering && score > cameraBest {
            cameraBest = score
            UserDefaults.standard.set(score, forKey: "CamBreakerBest")
        }
    }

    func flash(_ text: String) {
        message = text
    }

    func resetRun(startingLevel: Int = 1) {
        score = 0
        lives = 3
        level = startingLevel
        highScoreAtRunStart = highScore
        cameraBestAtRunStart = cameraBest
        pureCameraRun = true
        ammo = 0
        hasLaser = false
        hasCatch = false
        hasLong = false
        isFlipped = false
        isWrapped = false
        ballIsSlow = false
        bombArmed = false
        ballCount = 1
        message = nil
    }
}

enum GamePhase {
    case menu, serving, playing, paused, levelClear, gameOver
}

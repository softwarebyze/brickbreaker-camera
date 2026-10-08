import Combine
import Foundation

// MARK: - HUD-observable game state
//
// The SpriteKit scene owns the simulation; it mirrors score/lives/level
// here so SwiftUI overlays stay in sync. Lives start at 3, like the original.

@MainActor
final class GameState: ObservableObject {
    @Published var score: Int = 0
    @Published var lives: Int = 3
    @Published var level: Int = 1
    @Published var highScore: Int = UserDefaults.standard.integer(forKey: "BrickBreakerHighScore")
    @Published var cameraBest: Int = UserDefaults.standard.integer(forKey: "BrickBreakerCameraBest")
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
            UserDefaults.standard.set(score, forKey: "BrickBreakerHighScore")
        }
        // Bank the purist board live: only while the run still qualifies.
        if pureCameraRun && cameraSteering && score > cameraBest {
            cameraBest = score
            UserDefaults.standard.set(score, forKey: "BrickBreakerCameraBest")
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

import Foundation

// MARK: - Shared CamBreaker model
//
// Faithful to the BlackBerry original:
//  - 34 boards that loop; later loops descend faster.
//  - Bricks take 1–4 ball hits (10 pts per hit); silver bricks are
//    unbreakable except by the Gun (50 pts per gun hit).
//  - Capsules are worth 50 pts when caught; the *type* is random but the
//    bricks that hide them are fixed per board.

/// How many ball hits a brick can take. `.silver` is unbreakable by ball/laser/bomb.
enum BrickKind: Equatable {
    case hits(Int)   // 1...4
    case silver

    var isBreakableByBall: Bool {
        if case .hits = self { return true }
        return false
    }

    /// Points per ball hit (the original awards 10 per hit).
    var pointsPerHit: Int { 10 }
}

/// A single brick in a board layout.
struct BrickSpec: Equatable {
    var kind: BrickKind
    /// Bricks flagged as capsule holders hide a capsule (type randomized at runtime).
    var hidesCapsule: Bool = false
}

/// One row of a board: one character per column.
///  `.` empty, `1`–`4` hits, `S` silver, `*` = 1-hit brick hiding a capsule.
typealias BoardMap = [String]

/// Capsule power-ups from the original (9 + Wrap + Slow = 10 + Life).
enum CapsuleKind: CaseIterable {
    case bomb, catchBall, flip, gun, laser, life, long, multi, slow, wrap

    /// Single-glyph label drawn on the falling capsule.
    var glyph: String {
        switch self {
        case .bomb: return "B"
        case .catchBall: return "C"
        case .flip: return "F"
        case .gun: return "G"
        case .laser: return "L"
        case .life: return "+"
        case .long: return "="
        case .multi: return "M"
        case .slow: return "S"
        case .wrap: return "W"
        }
    }

    var title: String {
        switch self {
        case .bomb: return "Bomb"
        case .catchBall: return "Catch"
        case .flip: return "Flip"
        case .gun: return "Gun"
        case .laser: return "Laser"
        case .life: return "Life"
        case .long: return "Long"
        case .multi: return "Multi"
        case .slow: return "Slow"
        case .wrap: return "Wrap"
        }
    }

    var blurb: String {
        switch self {
        case .bomb: return "Ball becomes a bomb: next brick explodes, damaging neighbors."
        case .catchBall: return "Catch and hold the ball on the paddle. Tap to launch with an aimed angle."
        case .flip: return "Uh oh — paddle steering is reversed for a while!"
        case .gun: return "3 bullets. Tap to fire. Destroys ANY brick, even silver."
        case .laser: return "Unlimited lasers. Tap to fire. 2 hits = 1 damage. Can't hurt silver."
        case .life: return "Extra life!"
        case .long: return "Extra-long paddle until you lose it or grab another paddle bonus."
        case .multi: return "4 balls in play! Keep at least one alive."
        case .slow: return "Slows the ball and freezes the bricks' descent for a while."
        case .wrap: return "Paddle wraps around the screen edges for a while."
        }
    }

    /// Ball-side bonuses cancel each other; paddle-side bonuses cancel each other.
    /// Multi is the exception: it never removes paddle bonuses, but it removes Catch.
    var isBallBonus: Bool {
        switch self {
        case .bomb, .multi, .slow: return true
        default: return false
        }
    }
}

/// Scoring table (from the original manuals).
enum Scoring {
    static let brickHit = 10
    static let capsuleCatch = 50
    static let gunHit = 50
    static let laserHit = 5
    static let laserDamageStep = 5  // a damaging pair of laser hits totals 10
    static let bombBrick = 5
}

/// Paddle steering source.
enum ControlMode: String, CaseIterable, Identifiable {
    case cameraControl = "Camera Control"
    case touch = "Touch"

    var id: String { rawValue }
    var blurb: String {
        switch self {
        case .cameraControl:
            return "Slide your finger on the iPhone Camera Control button. Light-press to open the overlay, pick Paddle, then swipe."
        case .touch:
            return "Drag anywhere to slide the paddle. Tap to launch and fire."
        }
    }
}

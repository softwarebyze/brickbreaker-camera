import SpriteKit

// MARK: - BrickBreakerScene
//
// A faithful recreation of the BlackBerry original's rules:
//
//  * 3 lives, 10 pts per brick hit, 50 pts per caught capsule.
//  * Bricks take 1–4 hits; silver bricks only fall to the Gun.
//  * 9 (+wrap/slow/life) capsules with the original replacement rules:
//    a new ball bonus cancels the old ball bonus, a new paddle bonus cancels
//    the old paddle bonus — except Multi, which keeps paddle bonuses but
//    drops Catch. Life coexists with everything.
//  * The ball starts slow, turns fast after ~60 bounces, then settles slow
//    again; on the second loop it starts fast. Losing a life restarts the
//    fast portion. (Mirrors the original's famous speed quirks.)
//  * Bricks descend one row every N paddle hits (faster on later loops),
//    up to a max depth — then they stop, like the original.
//  * Paddle angle control: where the ball strikes the paddle sets the
//    rebound angle, up to 60° off vertical.
//
// Physics is hand-rolled (swept in small substeps) rather than SKPhysics:
// deterministic bounces and zero tunneling at high speed.

final class BrickBreakerScene: SKScene {

    // MARK: Tunables

    private enum Tune {
        static let cols = 10
        static let slowSpeed: CGFloat = 330
        static let fastSpeed: CGFloat = 540
        static let bouncesToFast = 60
        static let bouncesToSettle = 140
        static let descentEveryLoop1 = 30
        static let descentEveryLater = 15
        static let maxDescentRows = 5
        static let capsuleFall: CGFloat = 150
        static let laserSpeed: CGFloat = 720
        static let gunSpeed: CGFloat = 950
        static let paddleLerp: CGFloat = 18   // paddle tracking responsiveness
        static let maxReboundDeg: CGFloat = 60
        static let slowBounceBudget = 45
        static let flipWrapSeconds = 25.0
    }

    // MARK: Model

    private final class Brick {
        var col: Int; var row: Int
        var hp: Int
        let isSilver: Bool
        let hidesCapsule: Bool
        var laserCharge = 0
        var node: SKShapeNode
        init(col: Int, row: Int, hp: Int, isSilver: Bool, hidesCapsule: Bool, node: SKShapeNode) {
            self.col = col; self.row = row; self.hp = hp
            self.isSilver = isSilver; self.hidesCapsule = hidesCapsule; self.node = node
        }
    }

    private final class Ball {
        let node: SKShapeNode
        var vel: CGVector
        var stuck: Bool          // glued to paddle (serve or catch)
        var stuckOffset: CGFloat = 0
        init(node: SKShapeNode, vel: CGVector, stuck: Bool) {
            self.node = node; self.vel = vel; self.stuck = stuck
        }
        var speed: CGFloat { hypot(vel.dx, vel.dy) }
    }

    private final class Capsule {
        let node: SKNode
        let kind: CapsuleKind
        init(node: SKNode, kind: CapsuleKind) { self.node = node; self.kind = kind }
    }

    private final class Shot {
        let node: SKShapeNode
        let isGun: Bool
        init(node: SKShapeNode, isGun: Bool) { self.node = node; self.isGun = isGun }
    }

    // MARK: External wiring

    var gameState: GameState?
    /// Direct link to the camera session owner. The paddle reads the slider
    /// value straight from here every frame — no relay, nothing to go stale.
    weak var cameraLink: CameraManager?
    /// 0...1 paddle target from the Camera Control slider. Nil = no camera input.
    var cameraPaddle01: CGFloat?
    var controlMode: ControlMode = .cameraControl
    var useCameraBackground = false { didSet { updateBackground() } }

    // MARK: Layout

    private var playWidth: CGFloat = 400
    private var brickW: CGFloat = 36
    private var brickH: CGFloat = 20
    private var brickGap: CGFloat = 3
    private var gridOriginX: CGFloat = 0
    private var gridTopY: CGFloat = 0
    private var paddleY: CGFloat = 80
    private var paddleW: CGFloat = 70
    private var paddleH: CGFloat = 14
    private var ballR: CGFloat = 7
    private var laidOutWidth: CGFloat = 0
    private var laidOutHeight: CGFloat = 0

    // MARK: Run state

    private var paddle: SKShapeNode!
    private var paddleX: CGFloat = 200
    private var paddleTargetX: CGFloat = 200
    private var touchPaddleX: CGFloat?
    private var touchGrabOffset: CGFloat = 0
    private var touchMovedFar = false
    private var touchStart: CGPoint = .zero
    private var bricks: [Brick] = []
    private var balls: [Ball] = []
    private var capsules: [Capsule] = []
    private var shots: [Shot] = []
    private var descentRows = 0
    private var paddleHits = 0
    private var bounceCount = 0
    private var settledSlow = false
    private var fastPhase = false
    private var gunAmmo = 0
    private var hasLaser = false
    private var hasCatch = false
    private var hasLong = false
    private var flipUntil: Date?
    private var wrapUntil: Date?
    private var slowBudget = 0
    private var bombArmed = false
    private var breakablesLeft = 0
    private var lastUpdate: TimeInterval = 0
    private var running = false

    var isFlipped: Bool { flipUntil.map { $0 > Date() } ?? false }
    var isWrapped: Bool { wrapUntil.map { $0 > Date() } ?? false }

    // MARK: Setup

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = .black
        updateBackground()
        // NOTE: no layout here on purpose. At presentation time the view can
        // still have zero bounds (resizeFill corrects scene.size a beat later),
        // so laying out now would bake in a zero width. Layout happens in
        // startLevel + didChangeSize, both guarded by real sizes.
        running = true
    }

    /// resizeFill calls this whenever the view corrects our size. Recompute
    /// layout and rebuild nodes so a zero-size presentation can never stick
    /// (this exact bug once parked the paddle off-screen).
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 100, size.height > 100 else { return }
        guard abs(size.width - laidOutWidth) > 1 || abs(size.height - laidOutHeight) > 1 else { return }
        guard !bricks.isEmpty || paddle != nil else { return }
        relayout()
    }

    /// Recompute constants from the current size and rebuild laid-out nodes.
    /// Only runs on genuine size changes (launch-time correction, rotation).
    private func relayout() {
        let fraction = laidOutWidth > 0 ? (paddleTargetX / laidOutWidth) : 0.5
        layoutConstants()
        for brick in bricks {
            brick.node.removeFromParent()
            brick.node = makeBrickNode(hp: brick.hp, silver: brick.isSilver)
            brick.node.position = brickFrame(col: brick.col, row: brick.row).origin
            addChild(brick.node)
        }
        buildPaddle()
        paddleTargetX = fraction * playWidth
        paddleX = min(playWidth - effectivePaddleHalf(), max(effectivePaddleHalf(), paddleTargetX))
        paddle.position = CGPoint(x: paddleX, y: paddleY)
        glueStuckBalls()
    }

    private func updateBackground() {
        backgroundColor = useCameraBackground ? .clear : .black
    }

    private func layoutConstants() {
        // If we're somehow sized to zero (pre-layout presentation), fall back
        // to the screen so nodes never bake in a zero width.
        let w = size.width > 100 ? size.width : UIScreen.main.bounds.width
        let h = size.height > 100 ? size.height : UIScreen.main.bounds.height
        laidOutWidth = w
        laidOutHeight = h
        playWidth = w
        let side: CGFloat = 10
        brickGap = 3
        brickW = (playWidth - side * 2 - CGFloat(Tune.cols - 1) * brickGap) / CGFloat(Tune.cols)
        brickH = 20
        gridOriginX = side
        gridTopY = h - 150 // room for the SwiftUI HUD strip
        paddleY = max(90, h * 0.12)
        paddleW = max(64, playWidth / 5.6)
        paddleH = 14
        ballR = 7
        paddleX = playWidth / 2
        paddleTargetX = paddleX
    }

    // MARK: Level management

    func startLevel(_ level: Int, keepBonuses: Bool = false) {
        removeAllChildren()
        bricks.removeAll(); balls.removeAll(); capsules.removeAll(); shots.removeAll()
        layoutConstants()
        buildPaddle()
        paddleX = playWidth / 2; paddleTargetX = paddleX
        paddle.position = CGPoint(x: paddleX, y: paddleY)
        descentRows = 0; paddleHits = 0; bounceCount = 0
        settledSlow = false

        let loop = (level - 1) / Levels.count // 0-based loop
        fastPhase = (loop == 1) // second pass starts fast, like the original
        if loop >= 2 { settledSlow = true; fastPhase = false } // past "the Turn": always slow

        if !keepBonuses { clearAllBonuses(silent: true) }

        let spec = Levels.spec(forLevel: level)
        for entry in Levels.parse(spec.map) {
            addBrick(col: entry.col, row: entry.row, spec: entry.spec)
        }
        breakablesLeft = bricks.filter { !$0.isSilver }.count
        serveBall()
        gameState?.phase = .serving
    }

    private func brickFrame(col: Int, row: Int) -> CGRect {
        let x = gridOriginX + CGFloat(col) * (brickW + brickGap)
        let y = gridTopY - CGFloat(row + descentRows + 1) * (brickH + brickGap)
        return CGRect(x: x, y: y, width: brickW, height: brickH)
    }

    private func brickColor(hp: Int, silver: Bool) -> UIColor {
        if silver { return UIColor(red: 0.62, green: 0.64, blue: 0.68, alpha: 1) }
        switch hp {
        case 1: return UIColor(red: 0.30, green: 0.85, blue: 0.35, alpha: 1) // green
        case 2: return UIColor(red: 0.25, green: 0.55, blue: 1.0, alpha: 1)  // blue
        case 3: return UIColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 1)   // orange
        default: return UIColor(red: 1.0, green: 0.25, blue: 0.30, alpha: 1) // red
        }
    }

    /// Builds a brick node sized to the current layout constants.
    private func makeBrickNode(hp: Int, silver: Bool) -> SKShapeNode {
        let node = SKShapeNode(
            rect: CGRect(origin: .zero, size: CGSize(width: brickW, height: brickH)),
            cornerRadius: 4)
        node.fillColor = brickColor(hp: silver ? 4 : hp, silver: silver)
        node.strokeColor = UIColor(white: 1, alpha: 0.25)
        node.lineWidth = 1
        if silver {
            // rivets, so silver reads as metal at a glance
            for rx in [0.22, 0.78] {
                let rivet = SKShapeNode(circleOfRadius: 2)
                rivet.position = CGPoint(x: brickW * rx, y: brickH / 2)
                rivet.fillColor = UIColor(white: 0.35, alpha: 1)
                rivet.strokeColor = .clear
                node.addChild(rivet)
            }
        }
        return node
    }

    private func addBrick(col: Int, row: Int, spec: BrickSpec) {
        let hp: Int
        let silver: Bool
        switch spec.kind {
        case .hits(let n): hp = n; silver = false
        case .silver: hp = Int.max; silver = true
        }
        let node = makeBrickNode(hp: hp, silver: silver)
        node.position = brickFrame(col: col, row: row).origin
        addChild(node)
        bricks.append(Brick(col: col, row: row, hp: hp, isSilver: silver,
                            hidesCapsule: spec.hidesCapsule, node: node))
    }

    // MARK: Paddle & ball

    private func buildPaddle() {
        paddle?.removeFromParent()
        paddleW = max(64, playWidth / 5.6) * (hasLong ? 1.6 : 1.0)
        paddle = SKShapeNode(rect: CGRect(x: -paddleW / 2, y: -paddleH / 2, width: paddleW, height: paddleH),
                             cornerRadius: 7)
        paddle.fillColor = UIColor(white: 0.92, alpha: 1)
        paddle.strokeColor = UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1)
        paddle.lineWidth = 2
        paddle.position = CGPoint(x: paddleX, y: paddleY)
        addChild(paddle)
    }

    private func makeBallNode() -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: ballR)
        node.fillColor = .white
        node.strokeColor = UIColor(red: 0.6, green: 0.85, blue: 1.0, alpha: 1)
        node.lineWidth = 1.5
        return node
    }

    private func serveBall() {
        let node = makeBallNode()
        node.position = CGPoint(x: paddleX, y: paddleY + paddleH / 2 + ballR + 2)
        addChild(node)
        balls.append(Ball(node: node, vel: .zero, stuck: true))
        gameState?.ballCount = balls.count
    }

    private func launchStuckBalls(angleTweak: CGFloat = 0) {
        let speed = currentBallSpeed()
        for ball in balls where ball.stuck {
            ball.stuck = false
            let deg = max(-Tune.maxReboundDeg, min(Tune.maxReboundDeg, angleTweak * Tune.maxReboundDeg))
            let rad = CGFloat.pi / 2 + deg * CGFloat.pi / 180
            ball.vel = CGVector(dx: cos(rad) * speed, dy: abs(sin(rad)) * speed)
        }
        if balls.contains(where: { !$0.stuck }) {
            gameState?.phase = .playing
            SoundManager.shared.play(.launch)
        }
    }

    private func currentBallSpeed() -> CGFloat {
        if slowBudget > 0 { return Tune.slowSpeed * 0.75 }
        if settledSlow { return Tune.slowSpeed }
        return fastPhase ? Tune.fastSpeed : Tune.slowSpeed
    }

    private func retuneBallSpeeds() {
        let s = currentBallSpeed()
        for ball in balls where !ball.stuck {
            let v = ball.vel
            let m = max(hypot(v.dx, v.dy), 0.001)
            ball.vel = CGVector(dx: v.dx / m * s, dy: v.dy / m * s)
        }
    }

    // MARK: Input (touch + camera)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        touchStart = p
        touchMovedFar = false
        touchGrabOffset = paddleX - p.x
        touchPaddleX = paddleX
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        if hypot(p.x - touchStart.x, p.y - touchStart.y) > 12 { touchMovedFar = true }
        var x = p.x + touchGrabOffset
        x = applyFlipWrap(x, forTouch: true)
        touchPaddleX = x
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { touchPaddleX = nil }
        guard running else { return }
        if !touchMovedFar { handleTap() }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchPaddleX = nil
    }

    private func applyFlipWrap(_ x: CGFloat, forTouch: Bool) -> CGFloat {
        var v = x
        let half = effectivePaddleHalf()
        if isFlipped {
            // Flip mirrors steering around screen center (paddle bonus from the original).
            v = playWidth - v
        }
        if isWrapped {
            if v < -half { v += playWidth + half * 2 }
            if v > playWidth + half { v -= playWidth + half * 2 }
            return v
        }
        return min(playWidth - half, max(half, v))
    }

    private func effectivePaddleHalf() -> CGFloat {
        (paddle?.frame.width ?? paddleW) / 2
    }

    /// Tap = context action, like the BlackBerry SPACE key:
    /// launch a served/caught ball, else fire gun, else fire laser.
    private func handleTap() {
        guard let gs = gameState else { return }
        if gs.phase == .serving || balls.contains(where: { $0.stuck }) {
            var tweak: CGFloat = 0
            if let stuck = balls.first(where: { $0.stuck }) {
                tweak = max(-1, min(1, stuck.stuckOffset / max(effectivePaddleHalf(), 1)))
            }
            launchStuckBalls(angleTweak: tweak)
            return
        }
        guard gs.phase == .playing else { return }
        if gunAmmo > 0 && !shots.contains(where: { $0.isGun }) {
            fireGun()
        } else if hasLaser {
            fireLaser()
        }
    }

    private func fireGun() {
        guard gunAmmo > 0 else { return }
        gunAmmo -= 1
        gameState?.ammo = gunAmmo
        let node = SKShapeNode(rect: CGRect(x: -3, y: -8, width: 6, height: 16), cornerRadius: 3)
        node.fillColor = UIColor(red: 1, green: 0.6, blue: 0.1, alpha: 1)
        node.strokeColor = .white
        node.position = CGPoint(x: paddleX, y: paddleY + 20)
        addChild(node)
        shots.append(Shot(node: node, isGun: true))
        SoundManager.shared.play(.gunFire)
    }

    private func fireLaser() {
        let onScreen = shots.filter { !$0.isGun }.count
        guard onScreen < 4 else { return } // max 4 beams, like the original
        for dx in [-effectivePaddleHalf() + 4, effectivePaddleHalf() - 4] {
            let node = SKShapeNode(rect: CGRect(x: -1.5, y: -7, width: 3, height: 14), cornerRadius: 1.5)
            node.fillColor = UIColor(red: 1, green: 0.2, blue: 0.2, alpha: 1)
            node.strokeColor = .clear
            node.position = CGPoint(x: paddleX + dx, y: paddleY + 16)
            addChild(node)
            shots.append(Shot(node: node, isGun: false))
        }
        SoundManager.shared.play(.shoot)
    }

    // MARK: Simulation

    override func update(_ currentTime: TimeInterval) {
        guard running else { return }
        if lastUpdate == 0 { lastUpdate = currentTime }
        let dt = min(currentTime - lastUpdate, 1.0 / 30.0)
        lastUpdate = currentTime
        guard let gs = gameState, gs.phase == .playing || gs.phase == .serving else { return }

        movePaddle(dt: dt)
        if gs.phase == .playing {
            moveBalls(dt: dt)
            moveShots(dt: dt)
        } else {
            glueStuckBalls()
        }
        moveCapsules(dt: dt)
    }

    private func movePaddle(dt: CGFloat) {
        // Touch drag wins while touching; otherwise the Camera Control slider
        // (or the last known position in pure-touch mode).
        // NOTE: the live slider value is read directly from the CameraManager
        // every frame — an earlier design relayed it through SwiftUI onChange
        // and the paddle starved whenever that relay stalled.
        var source = "idle"
        if let tx = touchPaddleX {
            paddleTargetX = tx
            source = "touch"
        } else if controlMode == .cameraControl {
            let live: CGFloat? = cameraLink.map { CGFloat($0.paddlePosition) } ?? cameraPaddle01
            if let cam = live {
                source = String(format: "cam %.2f", cam)
                var x = cam * playWidth
                let half = effectivePaddleHalf()
                if isFlipped { x = playWidth - x }
                if isWrapped {
                    paddleTargetX = x // wrapping handled in clamp below
                } else {
                    paddleTargetX = min(playWidth - half, max(half, x))
                }
            } else {
                source = "cam(nil)"
            }
        } else {
            source = "mode=\(controlMode.rawValue)"
        }
        var x = paddleTargetX
        let half = effectivePaddleHalf()
        if isWrapped {
            if x < -half { x += playWidth + half * 2; paddleTargetX = x }
            if x > playWidth + half { x -= playWidth + half * 2; paddleTargetX = x }
        } else {
            x = min(playWidth - half, max(half, x))
        }
        // Fast exponential tracking: responsive, yet smooth.
        let t = min(1, Tune.paddleLerp * dt)
        paddleX += (x - paddleX) * t
        paddle.position.x = paddleX
        glueStuckBalls()
        reportPaddleDebug(source: source)
    }

    /// Temporary live diagnostics (removed before store submission).
    private var lastDebugSent = ""
    private func reportPaddleDebug(source: String) {
        let str = "\(source) tgt=\(Int(paddleTargetX)) x=\(Int(paddleX)) w=\(Int(playWidth))"
        guard str != lastDebugSent else { return }
        lastDebugSent = str
        gameState?.paddleDebug = str
    }

    private func glueStuckBalls() {
        for ball in balls where ball.stuck {
            ball.node.position = CGPoint(x: paddleX + ball.stuckOffset, y: paddleY + paddleH / 2 + ballR + 2)
        }
    }

    private func moveBalls(dt: CGFloat) {
        var deadIndexes: [Int] = []
        for (i, ball) in balls.enumerated() {
            if ball.stuck { continue }
            var remaining = hypot(ball.vel.dx, ball.vel.dy) * dt
            let step: CGFloat = 5
            while remaining > 0 {
                let d = min(step, remaining)
                remaining -= d
                let m = max(ball.speed, 0.001)
                ball.node.position.x += ball.vel.dx / m * d
                ball.node.position.y += ball.vel.dy / m * d
                collideBallWithWalls(ball)
                collideBallWithPaddle(ball)
                collideBallWithBricks(ball)
                if ball.node.position.y < -20 { break }
            }
            if ball.node.position.y < -20 { deadIndexes.append(i) }
        }
        for i in deadIndexes.reversed() {
            balls[i].node.removeFromParent()
            balls.remove(at: i)
        }
        if !deadIndexes.isEmpty {
            gameState?.ballCount = max(balls.count, 0)
            if balls.isEmpty { loseLife() }
        }
    }

    private func collideBallWithWalls(_ ball: Ball) {
        let p = ball.node.position
        if p.x < ballR && ball.vel.dx < 0 {
            ball.vel.dx = -ball.vel.dx
            ball.node.position.x = ballR
            registerBounce(sound: .wall)
        } else if p.x > playWidth - ballR && ball.vel.dx > 0 {
            ball.vel.dx = -ball.vel.dx
            ball.node.position.x = playWidth - ballR
            registerBounce(sound: .wall)
        }
        if p.y > size.height - ballR && ball.vel.dy > 0 {
            ball.vel.dy = -ball.vel.dy
            ball.node.position.y = size.height - ballR
            registerBounce(sound: .wall)
        }
        // Gentle anti-stall: never allow a near-horizontal loop.
        let s = max(ball.speed, 1)
        if abs(ball.vel.dy) < s * 0.18 {
            ball.vel.dy = (ball.vel.dy >= 0 ? 1 : -1) * s * 0.18
            let m = hypot(ball.vel.dx, ball.vel.dy)
            ball.vel.dx *= s / m; ball.vel.dy *= s / m
        }
    }

    private func paddleRect() -> CGRect {
        CGRect(x: paddleX - effectivePaddleHalf(), y: paddleY - paddleH / 2,
               width: effectivePaddleHalf() * 2, height: paddleH)
    }

    private func collideBallWithPaddle(_ ball: Ball) {
        guard ball.vel.dy < 0 else { return }
        let p = ball.node.position
        let r = paddleRect().insetBy(dx: -2, dy: 0)
        guard p.y - ballR <= r.maxY, p.y > r.minY - 14,
              p.x >= r.minX - ballR, p.x <= r.maxX + ballR else { return }
        let offset = max(-1, min(1, (p.x - paddleX) / max(effectivePaddleHalf(), 1)))
        if hasCatch {
            // Catch: hold the ball; the offset becomes the launch aim.
            ball.stuck = true
            ball.stuckOffset = (p.x - paddleX) * 0.9
            ball.vel = .zero
            SoundManager.shared.play(.paddle)
            return
        }
        let s = max(ball.speed, currentBallSpeed())
        let rad = CGFloat.pi / 2 + offset * Tune.maxReboundDeg * CGFloat.pi / 180
        ball.vel = CGVector(dx: cos(rad) * s, dy: abs(sin(rad)) * s)
        ball.node.position.y = r.maxY + ballR + 0.5
        paddleHits += 1
        registerBounce(sound: .paddle)
        maybeDescend()
    }

    private func collideBallWithBricks(_ ball: Ball) {
        let p = ball.node.position
        for brick in bricks where brick.hp > 0 || brick.isSilver {
            let f = brick.node.frame
            let expanded = f.insetBy(dx: -ballR + 1, dy: -ballR + 1)
            guard expanded.contains(p) else { continue }
            // Reflect on the axis of least penetration.
            let dxLeft = abs(p.x - (f.minX - ballR))
            let dxRight = abs(p.x - (f.maxX + ballR))
            let dyBot = abs(p.y - (f.minY - ballR))
            let dyTop = abs(p.y - (f.maxY + ballR))
            let m = min(min(dxLeft, dxRight), min(dyBot, dyTop))
            if m == dxLeft { ball.vel.dx = -abs(ball.vel.dx) }
            else if m == dxRight { ball.vel.dx = abs(ball.vel.dx) }
            else if m == dyBot { ball.vel.dy = -abs(ball.vel.dy) }
            else { ball.vel.dy = abs(ball.vel.dy) }
            hitBrick(brick, byBall: ball)
            registerBounce(sound: nil)
            break // one brick per substep keeps corners sane
        }
    }

    private func hitBrick(_ brick: Brick, byBall ball: Ball?) {
        if bombArmed, let _ = ball {
            explode(at: brick)
            return
        }
        if brick.isSilver {
            SoundManager.shared.play(.silver)
            return
        }
        brick.hp -= 1
        gameState?.addScore(Scoring.brickHit)
        if brick.hp <= 0 {
            destroyBrick(brick)
        } else {
            brick.node.fillColor = brickColor(hp: brick.hp, silver: false)
            SoundManager.shared.play(.brick)
        }
    }

    private func explode(at brick: Brick) {
        bombArmed = false
        gameState?.bombArmed = false
        SoundManager.shared.play(.explosion)
        let victims = bricks.filter {
            !$0.isSilver && abs($0.col - brick.col) <= 1 && abs($0.row - brick.row) <= 1
        }
        for v in victims {
            gameState?.addScore(Scoring.bombBrick)
            if v.hidesCapsule { dropCapsule(at: v.node.position) }
            v.hp = 0
            v.node.removeFromParent()
            breakablesLeft -= 1
        }
        bricks.removeAll { $0.hp <= 0 && !$0.isSilver }
        flash("Bomb!")
        checkLevelClear()
    }

    private func destroyBrick(_ brick: Brick) {
        if brick.hidesCapsule { dropCapsule(at: brick.node.position) }
        brick.hp = 0
        brick.node.removeFromParent()
        bricks.removeAll { $0 === brick }
        breakablesLeft -= 1
        SoundManager.shared.play(.brick)
        checkLevelClear()
    }

    private func registerBounce(sound: SoundManager.Effect?) {
        if let sound { SoundManager.shared.play(sound) }
        bounceCount += 1
        if slowBudget > 0 {
            slowBudget -= 1
            if slowBudget == 0 { retuneBallSpeeds() }
        }
        // The original's speed acts: slow → fast → slow again per level.
        if !settledSlow {
            if !fastPhase, bounceCount >= Tune.bouncesToFast {
                fastPhase = true
                retuneBallSpeeds()
            } else if fastPhase, bounceCount >= Tune.bouncesToSettle {
                fastPhase = false
                settledSlow = true
                retuneBallSpeeds()
            }
        }
    }

    // MARK: Descent

    private func descentThreshold() -> Int {
        guard let gs = gameState else { return Tune.descentEveryLoop1 }
        let loop = (gs.level - 1) / Levels.count
        return loop == 0 ? Tune.descentEveryLoop1 : Tune.descentEveryLater
    }

    private func maybeDescend() {
        guard paddleHits >= descentThreshold() else { return }
        paddleHits = 0
        guard slowBudget == 0 else { return } // Slow freezes the descent
        guard descentRows < Tune.maxDescentRows else { return }
        // Don't crush the player: stop if bricks near the paddle zone.
        let lowestY = bricks.map { brickFrame(col: $0.col, row: $0.row).minY }.min() ?? .greatestFiniteMagnitude
        guard lowestY > paddleY + (brickH + brickGap) * 3 else { return }
        descentRows += 1
        for brick in bricks {
            let f = brickFrame(col: brick.col, row: brick.row)
            brick.node.run(SKAction.move(to: f.origin, duration: 0.18))
        }
    }

    // MARK: Capsules

    private func dropCapsule(at pos: CGPoint) {
        guard let kind = CapsuleKind.allCases.randomElement() else { return }
        let node = SKNode()
        node.position = pos
        let pill = SKShapeNode(rect: CGRect(x: -13, y: -9, width: 26, height: 18), cornerRadius: 9)
        pill.fillColor = capsuleColor(kind)
        pill.strokeColor = .white
        pill.lineWidth = 1.5
        node.addChild(pill)
        let label = SKLabelNode(text: kind.glyph)
        label.fontSize = 12
        label.fontName = "Helvetica-Bold"
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 0.5)
        node.addChild(label)
        addChild(node)
        capsules.append(Capsule(node: node, kind: kind))
    }

    private func capsuleColor(_ kind: CapsuleKind) -> UIColor {
        switch kind {
        case .bomb: return UIColor(red: 1, green: 0.35, blue: 0.1, alpha: 1)
        case .catchBall: return UIColor(red: 0.2, green: 0.7, blue: 1, alpha: 1)
        case .flip: return UIColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1)
        case .gun: return UIColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1)
        case .laser: return UIColor(red: 1, green: 0.1, blue: 0.4, alpha: 1)
        case .life: return UIColor(red: 0.1, green: 0.85, blue: 0.3, alpha: 1)
        case .long: return UIColor(red: 0.1, green: 0.5, blue: 1, alpha: 1)
        case .multi: return UIColor(red: 1, green: 0.8, blue: 0.1, alpha: 1)
        case .slow: return UIColor(red: 0.3, green: 1, blue: 0.9, alpha: 1)
        case .wrap: return UIColor(red: 1, green: 0.5, blue: 0.9, alpha: 1)
        }
    }

    private func moveCapsules(dt: CGFloat) {
        let r = paddleRect()
        var caught: [Int] = []
        var missed: [Int] = []
        for (i, cap) in capsules.enumerated() {
            cap.node.position.y -= Tune.capsuleFall * dt
            let p = cap.node.position
            if p.y < -20 {
                missed.append(i)
            } else if p.y <= r.maxY + 10, p.y >= r.minY - 6,
                      p.x >= r.minX - 12, p.x <= r.maxX + 12,
                      gameState?.phase == .playing || gameState?.phase == .serving {
                caught.append(i)
            }
        }
        for i in caught.reversed() {
            let cap = capsules.remove(at: i)
            cap.node.removeFromParent()
            catchCapsule(cap.kind)
        }
        for i in missed.reversed() {
            capsules[missed[i]].node.removeFromParent()
            capsules.remove(at: missed[i])
        }
    }

    private func catchCapsule(_ kind: CapsuleKind) {
        gameState?.addScore(Scoring.capsuleCatch)
        SoundManager.shared.play(.capsule)
        switch kind {
        case .life:
            gameState?.lives += 1
            flash("+1 Life!")
        case .bomb, .multi, .slow:
            clearBallBonus()
            applyBallBonus(kind)
        case .catchBall, .gun, .laser, .long, .flip, .wrap:
            if kind == .multi { break } // unreachable; kept for clarity
            clearPaddleBonus()
            applyPaddleBonus(kind)
        }
        syncBonusHUD()
    }

    private func applyBallBonus(_ kind: CapsuleKind) {
        switch kind {
        case .bomb:
            bombArmed = true
            flash("Bomb armed!")
        case .multi:
            // Multi keeps paddle bonuses but drops Catch (original rule).
            if hasCatch {
                hasCatch = false
                for ball in balls where ball.stuck {
                    ball.stuck = false
                    ball.vel = CGVector(dx: 120, dy: currentBallSpeed())
                }
                gameState?.phase = .playing
            }
            while balls.count < 4 {
                let base = balls.first(where: { !$0.stuck }) ?? balls.first
                let node = makeBallNode()
                node.position = base?.node.position ?? CGPoint(x: paddleX, y: paddleY + 30)
                addChild(node)
                let s = currentBallSpeed()
                let ang = Double.random(in: 40...140) * Double.pi / 180
                balls.append(Ball(node: node, vel: CGVector(dx: cos(ang) * s, dy: abs(sin(ang)) * s), stuck: false))
            }
            gameState?.phase = .playing
            flash("Multi-ball!")
        case .slow:
            slowBudget = Tune.slowBounceBudget
            retuneBallSpeeds()
            flash("Slow!")
        default: break
        }
    }

    private func applyPaddleBonus(_ kind: CapsuleKind) {
        switch kind {
        case .catchBall:
            hasCatch = true
            flash("Catch!")
        case .gun:
            gunAmmo = 3
            flash("Gun — tap to fire!")
        case .laser:
            hasLaser = true
            flash("Laser — tap to fire!")
        case .long:
            hasLong = true
            buildPaddle()
            flash("Long paddle!")
        case .flip:
            flipUntil = Date().addingTimeInterval(Tune.flipWrapSeconds)
            flash("Flip! Steering reversed!")
        case .wrap:
            wrapUntil = Date().addingTimeInterval(Tune.flipWrapSeconds)
            flash("Wrap!")
        default: break
        }
    }

    private func clearBallBonus() {
        bombArmed = false
        slowBudget = 0
        if balls.count > 1 {
            // Collapse back to a single ball (keep the highest one).
            balls.sort { $0.node.position.y > $1.node.position.y }
            for extra in balls.dropFirst() { extra.node.removeFromParent() }
            balls = Array(balls.prefix(1))
        }
        retuneBallSpeeds()
    }

    private func clearPaddleBonus() {
        if hasCatch {
            for ball in balls where ball.stuck {
                ball.stuck = false
                ball.vel = CGVector(dx: 0, dy: currentBallSpeed())
            }
            if balls.contains(where: { !$0.stuck }) { gameState?.phase = .playing }
        }
        hasCatch = false
        hasLaser = false
        gunAmmo = 0
        if hasLong { hasLong = false; buildPaddle() }
        flipUntil = nil
        wrapUntil = nil
    }

    private func clearAllBonuses(silent: Bool) {
        clearBallBonus()
        clearPaddleBonus()
        if !silent { syncBonusHUD() }
    }

    private func syncBonusHUD() {
        gameState?.ammo = gunAmmo
        gameState?.hasLaser = hasLaser
        gameState?.hasCatch = hasCatch
        gameState?.hasLong = hasLong
        gameState?.isFlipped = isFlipped
        gameState?.isWrapped = isWrapped
        gameState?.ballIsSlow = slowBudget > 0
        gameState?.bombArmed = bombArmed
        gameState?.ballCount = balls.count
    }

    // MARK: Shots

    private func moveShots(dt: CGFloat) {
        var gone: [Int] = []
        for (i, shot) in shots.enumerated() {
            let v: CGFloat = shot.isGun ? Tune.gunSpeed : Tune.laserSpeed
            shot.node.position.y += v * dt
            var hit = false
            for brick in bricks {
                if brick.node.frame.insetBy(dx: -3, dy: -3).contains(shot.node.position) {
                    damageBrickByShot(brick, gun: shot.isGun)
                    hit = true
                    break
                }
            }
            if hit || shot.node.position.y > size.height + 20 { gone.append(i) }
        }
        for i in gone.reversed() {
            shots[i].node.removeFromParent()
            shots.remove(at: i)
        }
    }

    private func damageBrickByShot(_ brick: Brick, gun: Bool) {
        if gun {
            // The Gun destroys anything — the only way past silver.
            gameState?.addScore(Scoring.gunHit)
            if brick.isSilver {
                brick.node.removeFromParent()
                bricks.removeAll { $0 === brick }
                flash("Silver down! +50")
            } else {
                if brick.hidesCapsule { dropCapsule(at: brick.node.position) }
                brick.node.removeFromParent()
                bricks.removeAll { $0 === brick }
                breakablesLeft -= 1
            }
            SoundManager.shared.play(.explosion)
            checkLevelClear()
            return
        }
        // Laser: needs two hits per damage step, useless vs silver.
        if brick.isSilver {
            SoundManager.shared.play(.silver)
            return
        }
        gameState?.addScore(Scoring.laserHit)
        brick.laserCharge += 1
        if brick.laserCharge >= 2 {
            brick.laserCharge = 0
            gameState?.addScore(Scoring.laserDamageStep)
            brick.hp -= 1
            if brick.hp <= 0 {
                destroyBrick(brick)
            } else {
                brick.node.fillColor = brickColor(hp: brick.hp, silver: false)
            }
        }
        SoundManager.shared.play(.shoot)
    }

    // MARK: Life / level flow

    private func loseLife() {
        guard let gs = gameState else { return }
        SoundManager.shared.play(.loseLife)
        // Losing a ball drops paddle bonuses (long paddle, weapons...), like the original.
        let hadLong = hasLong
        clearPaddleBonus()
        bombArmed = false
        slowBudget = 0
        _ = hadLong
        syncBonusHUD()
        gs.lives -= 1
        bounceCount = 0 // the fast portion restarts after a lost life
        if gs.lives <= 0 {
            gs.phase = .gameOver
            SoundManager.shared.play(.gameOver)
            flash("Game Over")
        } else {
            flash("Ball lost — \(gs.lives) left")
            serveBall()
            gs.phase = .serving
        }
    }

    private func checkLevelClear() {
        guard breakablesLeft <= 0 else { return }
        guard let gs = gameState, gs.phase == .playing || gs.phase == .serving else { return }
        gs.phase = .levelClear
        SoundManager.shared.play(.levelClear)
        flash("Level \(gs.level) clear!")
        syncBonusHUD()
    }

    func resumeFromPause() {
        isPaused = false
        if balls.contains(where: { $0.stuck }) {
            gameState?.phase = .serving
        } else if breakablesLeft <= 0 {
            gameState?.phase = .levelClear
        } else if (gameState?.lives ?? 1) <= 0 {
            gameState?.phase = .gameOver
        } else {
            gameState?.phase = .playing
        }
    }

    func advanceToNextLevel() {        guard let gs = gameState else { return }
        gs.level += 1
        // Paddle bonuses expire between levels in the original; ball count resets.
        clearAllBonuses(silent: true)
        syncBonusHUD()
        startLevel(gs.level)
    }

    private func flash(_ text: String) {
        gameState?.flash(text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            if self?.gameState?.message == text { self?.gameState?.message = nil }
        }
    }
}

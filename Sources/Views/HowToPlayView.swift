import SwiftUI

// MARK: - How to play, with the Camera Control spotlight

struct HowToPlayView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Group {
                        Text("How to play")
                            .font(.largeTitle.bold())
                        Text("Clear all 34 boards. You get 3 lives. Green bricks fall in one hit; blue take two, orange three, red four. Silver bricks are unbreakable — except by the Gun.")
                    }

                    Group {
                        Text("📷 The special feature: steer with Camera Control")
                            .font(.headline)
                        Text("This game turns your iPhone's Camera Control button into a paddle controller, like the BlackBerry trackwheel back in the day:")
                        Bullet("Open the game and allow the camera (it runs a quiet preview so iOS keeps Camera Control routed here).")
                        Bullet("Light-press the Camera Control to open the overlay.")
                        Bullet("Double light-press to switch controls, then choose Paddle.")
                        Bullet("Swipe left/right on the Camera Control — the paddle follows!")
                        Bullet("Tap the screen to launch the ball and fire lasers or gun bullets, exactly like the old SPACE key.")
                        Text("Prefer fingers? Pick Touch steering in the menu or pause screen — drag anywhere to slide the paddle.")
                            .font(.caption)
                    }

                    Group {
                        Text("Capsules (50 pts each)")
                            .font(.headline)
                        ForEach(CapsuleKind.allCases, id: \.glyph) { kind in
                            HStack(alignment: .top, spacing: 8) {
                                Text(kind.glyph)
                                    .font(.headline.monospaced())
                                    .frame(width: 26, height: 26)
                                    .background(Color.cyan.opacity(0.85))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .foregroundStyle(.black)
                                VStack(alignment: .leading) {
                                    Text(kind.title).bold()
                                    Text(kind.blurb).font(.caption)
                                }
                            }
                        }
                        Text("Ball bonuses replace each other; paddle bonuses replace each other. Multi keeps your paddle gear but drops Catch. Life stacks with everything.")
                            .font(.caption)
                    }

                    Group {
                        Text("Scoring")
                            .font(.headline)
                        Bullet("Brick hit: 10 pts")
                        Bullet("Capsule caught: 50 pts")
                        Bullet("Gun hit: 50 pts (the only way to break silver!)")
                        Bullet("Laser hit: 5 pts, damaging pair totals 10")
                        Bullet("Bomb damage: 5 pts per brick")
                        Bullet("📷 Best: your top score steered with the Camera Control slider only — no touch-dragging. Show it off.")
                    }

                    Group {
                        Text("Survival tips (from the old masters)")
                            .font(.headline)
                        Bullet("The ball starts slow, turns fast after ~60 bounces, then settles slow. On your second loop it starts fast — survive until it calms down.")
                        Bullet("Bricks sink a row every few paddle hits (faster on later loops). Don't let them crowd you.")
                        Bullet("Hit with the paddle's center for safe returns; edges give wild angles.")
                        Bullet("Save Gun ammo for silver bricks — 150 free points per pill.")
                    }
                }
                .foregroundStyle(.white)
                .padding()
            }
        }
    }

    private func Bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
        .font(.subheadline)
    }
}

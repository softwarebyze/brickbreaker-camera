# CamBreaker — Camera Control Edition

The BlackBerry classic, reborn on iPhone — steered by the **Camera Control button**.

Slide your finger on the Camera Control to move the paddle, like the old
BlackBerry trackwheel. Light-press to open the overlay, pick **Paddle**, and
swipe. Tap the screen to launch the ball and fire lasers, exactly like the
old SPACE key.

## Features

- 🧱 **Faithful to the original**: 34 boards, 3 lives, 10 pts per brick hit,
  50 pts per capsule, silver unbreakables (Gun only!), bricks that descend as
  you play, and the famous slow → fast → slow ball.
- 💊 **All 10 capsules**: Bomb, Catch, Flip, Gun, Laser, Life, Long, Multi,
  Slow, Wrap — with the original replacement rules.
- 📷 **Camera Control steering** via a custom `AVCaptureSlider`, plus a
  touch-drag fallback and an optional **live camera background**.
- 🔊 Retro bleeps synthesized at runtime — zero audio assets.
- 🎯 60 fps hand-rolled physics (no tunneling, deterministic paddle angles).

## Project layout

```
Sources/
  CamBreakerApp.swift   App entry → MenuView
  ContentView.swift             Camera Control paddle test screen
  CameraManager.swift           AVCaptureSession + custom Paddle slider
  CameraPreviewView.swift       Live camera preview (game background)
  Game/
    CamBreakerTypes.swift     Bricks, capsules, scoring, control modes
    Levels.swift                All 34 boards (capsule slots fixed, types random)
    CamBreakerScene.swift     SpriteKit simulation + original game rules
    GameState.swift             HUD-observable score/lives/level
    SoundManager.swift          Synthesized retro sound effects
  Views/
    MenuView.swift  GameView.swift  HowToPlayView.swift
icon/make_icon.py               App icon generator (Pillow)
```

## Build it

Requirements: Xcode 26+, iPhone 16 or newer (for Camera Control), iOS 18+.

```sh
# Generate the Xcode project (checked in via project.yml + xcodegen)
xcodegen generate
# Open and Run on your device:
open CamBreaker.xcodeproj
```

Camera Control only exists on physical iPhone 16+ hardware — on the
simulator (or older phones) use Touch steering; everything else works.

## How the Camera Control works (for the curious)

`CameraManager` runs an `AVCaptureSession` (required: iOS only routes
Camera Control to apps actively using the camera) and adds a custom
`AVCaptureSlider("Paddle", in: 0...1)`. Swipes report values through
`setActionQueue`, which drives the paddle. The overlay/picker UI is drawn
entirely by the system.

## Credits

A loving homage to the 1999 BlackBerry original (Ali Asaria / Plazmic /
Digital Chocolate). Not affiliated with BlackBerry. Pure Swift + SpriteKit, zero dependencies.

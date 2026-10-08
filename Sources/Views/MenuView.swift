import SwiftUI

// MARK: - Main menu

enum Route: Hashable {
    case game, howTo, paddleTest
}

struct MenuView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var gameState = GameState()
    @State private var path = NavigationPath()
    @State private var controlMode: ControlMode = .cameraControl

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 14) {
                    Spacer(minLength: 40)

                    // Brand block: brick rows + paddle + ball, drawn in SwiftUI.
                    BrandArt()

                    Text("BRICKBREAKER")
                        .font(.system(size: 38, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("Camera Control Edition")
                        .font(.headline)
                        .foregroundStyle(.cyan)

                    Text("The BlackBerry classic — steered by your iPhone's Camera Control button.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    Text("BEST  \(gameState.highScore)")
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(.yellow)

                    Button("▶  Play") { path.append(Route.game) }
                        .buttonStyle(BigButton(color: .green))

                    Button("How to play") { path.append(Route.howTo) }
                        .buttonStyle(BigButton(color: .gray))

                    Button("Camera Control test") { path.append(Route.paddleTest) }
                        .buttonStyle(BigButton(color: .blue))

                    VStack(spacing: 8) {
                        Picker("Steering", selection: $controlMode) {
                            ForEach(ControlMode.allCases) { m in Text(m.rawValue).tag(m) }
                        }
                        .pickerStyle(.segmented)
                        Toggle("Camera view as game background", isOn: $gameState.useCameraBackground)
                            .foregroundStyle(.white)
                            .tint(.cyan)
                    }
                    .padding(.horizontal, 40)

                    Text("3 lives • 34 levels • gun beats silver")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .game:
                    GameView(camera: camera, gameState: gameState, path: $path, controlMode: controlMode)
                case .howTo:
                    HowToPlayView()
                case .paddleTest:
                    ContentView(camera: camera)
                }
            }
        }
    }
}

// MARK: - Little brick-art logo

struct BrandArt: View {
    private let rows: [[Color]] = [
        [.red, .orange, .yellow, .green, .cyan, .blue],
        [.green, .cyan, .blue, .red, .orange, .yellow],
        [.gray, .gray, .yellow, .yellow, .gray, .gray],
    ]

    var body: some View {
        VStack(spacing: 5) {
            ForEach(0..<rows.count, id: \.self) { r in
                HStack(spacing: 5) {
                    ForEach(0..<rows[r].count, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(rows[r][c])
                            .frame(width: 30, height: 14)
                    }
                }
            }
            // ball + paddle
            ZStack {
                Circle().fill(Color.white).frame(width: 12, height: 12)
                    .offset(x: 24, y: -16)
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white)
                    .frame(width: 90, height: 14)
            }
            .padding(.top, 10)
        }
    }
}

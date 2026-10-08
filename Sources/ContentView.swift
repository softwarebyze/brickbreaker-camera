import AVKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var camera: CameraManager
    @State private var lastPressMessage = "No press yet"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
            VStack(spacing: 12) {
            // Small live preview — proves the session is active and holding Camera Control.
            CameraPreviewView(session: camera.session)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.4)))

            VStack(spacing: 4) {
                Text("Paddle test — Camera Control slider")
                    .font(.headline)
                Text(camera.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    StatusPill(text: camera.supportsControls ? "supportsControls ✓" : "supportsControls ✗",
                               good: camera.supportsControls)
                    StatusPill(text: camera.controlsActive ? "overlay ACTIVE" : "overlay idle",
                               good: camera.controlsActive)
                }
                .font(.caption2)
            }

            // The paddle track.
            GeometryReader { geo in
                let trackWidth = geo.size.width
                let paddleWidth: CGFloat = 90
                let x = CGFloat(camera.paddlePosition) * (trackWidth - paddleWidth)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 44)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                        .frame(width: paddleWidth, height: 22)
                        .offset(x: x, y: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 60)

            Text("value: \(String(format: "%.3f", camera.paddlePosition))")
                .font(.system(.body, design: .monospaced))

            // Fallback / simulator control — drag this if you have no Camera Control hardware.
            VStack(spacing: 4) {
                Text("Touch fallback (simulator or finger test)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { Double(camera.paddlePosition) },
                    set: { camera.setPaddleFromTouchUI(Float($0)) }
                ), in: 0...1)
            }

            Text("Press test: \(lastPressMessage)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Event log
            VStack(alignment: .leading, spacing: 2) {
                Text("Event log")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(camera.eventLog.reversed().prefix(12)), id: \.self) { line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 110)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            }
            .padding()
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.white)
        .onCameraCaptureEvent { _ in
            lastPressMessage = "press began: \(Date().formatted(date: .omitted, time: .standard))"
            camera.logPress(phase: "began")
        }
    }
}

private struct StatusPill: View {
    let text: String
    let good: Bool
    var body: some View {
        Text(text)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((good ? Color.green : Color.gray).opacity(0.2))
            .clipShape(Capsule())
    }
}

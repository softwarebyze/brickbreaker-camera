import AVFoundation
import SwiftUI

/// Live camera preview so the session is visibly active (and proves Camera Control stayed in-app).
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.updateVideoOrientation()
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.updateVideoOrientation()
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(orientationChanged),
                name: UIDevice.orientationDidChangeNotification,
                object: nil)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) { fatalError() }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc private func orientationChanged() {
            updateVideoOrientation()
        }

        /// Keeps the feed upright as the phone rotates (the game supports
        /// portrait + landscape; the sensor doesn't rotate itself).
        func updateVideoOrientation() {
            guard let connection = previewLayer.connection,
                  connection.isVideoOrientationSupported else { return }
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                connection.videoOrientation = .landscapeRight
            case .landscapeRight:
                connection.videoOrientation = .landscapeLeft
            case .portraitUpsideDown:
                connection.videoOrientation = .portraitUpsideDown
            default:
                connection.videoOrientation = .portrait
            }
        }
    }
}

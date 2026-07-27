import SwiftUI
import AVFoundation

/// SwiftUI bridge to `AVCaptureVideoPreviewLayer` for the Live camera pane.
///
/// Keeps preview gravity at aspect-fill so composition overlays align with what operators see
/// on device; the pure guidance engine still analyzes the raw sample buffer separately.
struct CameraPreviewView: UIViewRepresentable {
    /// Running capture session owned by `CameraSessionModel`.
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer?.session = session
        view.videoPreviewLayer?.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer?.session = session
    }

    /// UIView whose backing layer is always a video preview layer.
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer? {
            layer as? AVCaptureVideoPreviewLayer
        }
    }
}

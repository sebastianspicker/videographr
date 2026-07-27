import AVFoundation
import Combine
import Foundation
import UIKit

final class CaptureObserverStorage {
    var cancellables: Set<AnyCancellable> = []
}

extension CameraSessionModel {
    internal func configureCaptureObservers() {
        observeMotion()
        observeCaptureEvents()
        observeOrientation()
        observeApplicationActivity()
        observeCaptureInterruptions()
        observeRuntimeStatusChanges()
        observeAudioRouteChanges()
    }

    private func observeMotion() {
        motion.$orientation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.recomputeGuidance() }
            .store(in: &observerStorage.cancellables)
    }

    private func observeCaptureEvents() {
        capture.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in self?.handleCaptureEvent(event) }
        }
    }

    private func observeOrientation() {
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.capture.updateVideoRotation(angle: Self.rotationAngle()) }
            .store(in: &observerStorage.cancellables)
    }

    private func observeApplicationActivity() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.appIsActive = false
                self?.privacyCoverIsVisible = true
                self?.suspend()
            }
            .store(in: &observerStorage.cancellables)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.appIsActive = true
                self?.resumeIfDesired()
            }
            .store(in: &observerStorage.cancellables)
    }

    private func observeCaptureInterruptions() {
        NotificationCenter.default.publisher(for: AVCaptureSession.wasInterruptedNotification, object: capture.session)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.captureIsInterrupted = true
                self?.privacyCoverIsVisible = true
                self?.recordStatusMessage = "Aufnahme unterbrochen - laufende Datei wird finalisiert."
                self?.persistOperationalObservation(
                    kind: .interruption,
                    note: "AVCaptureSession-Unterbrechung; Finalisierung angefordert."
                )
                self?.suspend()
            }
            .store(in: &observerStorage.cancellables)
        NotificationCenter.default.publisher(for: AVCaptureSession.interruptionEndedNotification, object: capture.session)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.captureIsInterrupted = false
                self?.resumeIfDesired()
            }
            .store(in: &observerStorage.cancellables)
        NotificationCenter.default.publisher(for: AVCaptureSession.runtimeErrorNotification, object: capture.session)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleRuntimeError(notification.userInfo?[AVCaptureSessionErrorKey] as? Error)
            }
            .store(in: &observerStorage.cancellables)
    }

    private func observeRuntimeStatusChanges() {
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshRuntimeStatus() }
            .store(in: &observerStorage.cancellables)
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshRuntimeStatus() }
            .store(in: &observerStorage.cancellables)
    }

    private func observeAudioRouteChanges() {
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                let previousRoute = self?.runtimeStatus.audioRoute
                self?.refreshRuntimeStatus()
                if previousRoute != self?.runtimeStatus.audioRoute { self?.invalidateSpokenAudioCheck() }
                self?.persistOperationalObservation(
                    kind: .audioRouteChange,
                    note: "Audioroute geändert: \(self?.runtimeStatus.audioRoute ?? "nicht verfügbar")"
                )
            }
            .store(in: &observerStorage.cancellables)
    }
}

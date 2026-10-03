import AVFoundation
import SessionCore
import SwiftUI
import XCTest

@testable import Unterrichtsvideographie

final class OperatorAuthenticationActivationTests: XCTestCase {
    func testCancellationOrFailureDoesNotRearmAutomaticAuthentication() {
        var gate = OperatorAuthenticationActivationGate()
        XCTAssertTrue(gate.consumeAttempt())
        // Native prompt dismissal returns inactive → active without a lock.
        XCTAssertFalse(gate.consumeAttempt())
        XCTAssertFalse(gate.consumeAttempt())
    }

    func testManualAttemptConsumesPendingAutomaticAttempt() {
        var gate = OperatorAuthenticationActivationGate()
        _ = gate.consumeAttempt() // The manual action ignores this return value.
        XCTAssertFalse(gate.consumeAttempt())
    }

    func testBackgroundLockRearmsExactlyOneAutomaticAttempt() {
        var gate = OperatorAuthenticationActivationGate()
        XCTAssertTrue(gate.consumeAttempt())
        gate.resetAfterLock()
        XCTAssertTrue(gate.consumeAttempt())
        XCTAssertFalse(gate.consumeAttempt())
        gate.resetAfterLock()
        XCTAssertTrue(gate.consumeAttempt())
        XCTAssertFalse(gate.consumeAttempt())
    }
}

final class ReflectionPresentationTests: XCTestCase {
    func testAnnotationIndexPreservesOrderAndCountsOnlyKnownPrompts() {
        let prompt = ReflectionPromptID.allCases[0]
        var values = EvidenceAnnotation.Values()
        values.promptIdentifier = prompt.rawValue
        values.createdAt = Date(timeIntervalSince1970: 20)
        let later = EvidenceAnnotation(values)
        values.id = UUID()
        values.createdAt = Date(timeIntervalSince1970: 10)
        let earlier = EvidenceAnnotation(values)
        values.id = UUID()
        values.promptIdentifier = "unrecognized-future-prompt"
        let index = ReflectionAnnotationIndex([later, EvidenceAnnotation(values), earlier])
        XCTAssertEqual(index.annotations(for: prompt).map(\.id), [earlier.id, later.id])
        XCTAssertEqual(index.linkedPromptCount, 1)
        XCTAssertTrue(index.annotations(for: ReflectionPromptID.allCases[1]).isEmpty)
    }

    @MainActor
    func testPlaybackTracksResolvedMediaAndTearsDownPreviousPlayer() {
        let playback = ReflectionPlaybackModel()
        let firstURL = FileManager.default.temporaryDirectory.appendingPathComponent("synthetic-first.mp4")
        let secondURL = FileManager.default.temporaryDirectory.appendingPathComponent("synthetic-second.mp4")
        playback.configure(url: nil)
        XCTAssertNil(playback.player)
        playback.configure(url: firstURL)
        let firstPlayer = playback.player
        XCTAssertNotNil(firstPlayer)
        playback.configure(url: firstURL)
        XCTAssertTrue(playback.player === firstPlayer)
        playback.seek(to: 9_000, durationMilliseconds: 1_000)
        XCTAssertEqual(playback.positionMilliseconds, 1_000)
        playback.configure(url: secondURL)
        XCTAssertFalse(playback.player === firstPlayer)
        XCTAssertEqual(playback.positionMilliseconds, 0)
        playback.configure(url: nil)
        XCTAssertNil(playback.player)
        XCTAssertNil(playback.mediaURL)
    }

    @MainActor
    func testFirstAttachedAssetConfiguresMountedReflectionPlayer() async throws {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let directory = support.appendingPathComponent("ReflectionTest-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SessionStore(rootDirectory: directory)
        let appStore = AppStore(store: store, bootstrapMode: .deferred)
        await appStore.bootstrap()
        let playback = ReflectionPlaybackModel()
        let host = UIHostingController(rootView: ReflectView(playback: playback).environmentObject(appStore))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            playback.stop()
            window.isHidden = true
            window.rootViewController = nil
        }
        host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(playback.player)
        attachRendering(of: host.view, name: "Reflection empty synthetic session")

        // File bytes are synthetic; this verifies attachment/selection routing, not decoding.
        try XCTContext.runActivity(named: "Persist empty synthetic session") { _ in
            try store.save(appStore.session)
        }
        let source = directory.appendingPathComponent("synthetic-source.mp4")
        try XCTContext.runActivity(named: "Write synthetic source bytes") { _ in
            try Data(repeating: 0, count: 32).write(to: source, options: .atomic)
        }
        let asset = try XCTContext.runActivity(named: "Copy synthetic attachment") { _ in
            try store.importMedia(from: source, into: appStore.session.id)
        }
        var attachedSession = appStore.session
        attachedSession.mediaAssets = [asset]
        try XCTContext.runActivity(named: "Commit synthetic attachment") { _ in
            try store.save(attachedSession)
            try store.commitImportedMedia(asset, toSession: attachedSession.id)
        }
        appStore.replaceSession(attachedSession)
        for _ in 0..<100 where playback.player == nil {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertNotNil(playback.player, "Newly attached media must configure playback without leaving the tab.")
        XCTAssertEqual(playback.mediaURL, try store.validatedMediaURL(for: asset, sessionID: appStore.session.id))
        attachRendering(of: host.view, name: "Reflection first synthetic attachment")
    }

    @MainActor
    private func attachRendering(of view: UIView, name: String) {
        view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: view.bounds).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

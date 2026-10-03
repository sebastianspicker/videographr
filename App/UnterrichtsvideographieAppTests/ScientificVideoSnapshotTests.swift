import AVFoundation
import CoreVideo
import ExperimentalResearch
import MetalKit
import SessionCore
import SwiftUI
import UIKit
import XCTest

@testable import Unterrichtsvideographie

/// Hardware-free rendering smoke coverage for the scientific-video redesign.
/// These are deliberately not pixel goldens: the attachments support visual
/// review while the assertions protect the persisted synthetic input and the
/// concrete hosting sizes used for that review.
final class ScientificVideoSnapshotTests: XCTestCase {
    /// Exercises the actual iOS pipeline without presenting content or depending on
    /// the host app's authentication dialog/scene activation. It proves no UI pixels.
    @MainActor
    func testGaussianProductionGeneratorProcessesSyntheticRecordingWithoutMediaMutation() async throws {
        let (appStore, playback, asset, url) = try await makeGaussianFixture()
        defer { playback.stop() }
        let request = try await prepareGaussianRequest(appStore, playback: playback, asset: asset, url: url)
        let modelURL = try XCTUnwrap(GaussianFrameGenerator.bundledModelURL)
        let baseline = appStore.session
        let isAuthorized: @MainActor @Sendable () -> Bool = {
            appStore.session.id == request.sessionID
                && appStore.session.mediaAssets.contains { $0.id == request.assetID }
                && request.authorization?.matches(appStore.session) == true
                && GaussianExplorationPolicy.permits(appStore.session)
                && playback.matchesPausedFrame(url: request.mediaURL, time: request.time)
        }
        XCTAssertTrue(isAuthorized())
        let result = try await withThrowingTaskGroup(of: GaussianFrameResult.self) { group in
            group.addTask {
                try await GaussianFrameGenerator.generate(request, modelURL: modelURL, isAuthorized: isAuthorized)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(120))
                throw GaussianHostedTestError.generationTimedOut
            }
            defer { group.cancelAll() }
            let first = try await group.next()
            return try XCTUnwrap(first)
        }
        // Cancellation remains cooperative across native Core ML work; the group
        // waits for native cleanup rather than leaving a worker using deleted fixtures.
        XCTAssertTrue(isAuthorized())
        XCTAssertEqual(result.sourceImage.width, 320)
        XCTAssertEqual(result.sourceImage.height, 180)
        XCTAssertEqual(result.actualTime.seconds, request.time.seconds, accuracy: 1.0 / 30 + 0.001)
        XCTAssertEqual(result.surface.aspectRatio, 320.0 / 180, accuracy: 0.0001)
        XCTAssertFalse(result.surface.points.isEmpty)
        XCTAssertLessThanOrEqual(result.surface.points.count, GaussianDepthSurface.maximumPointCount)
        XCTAssertTrue(result.surface.points.allSatisfy { point in
            [point.x, point.y, point.z, point.sigma, point.red, point.green, point.blue, point.opacity].allSatisfy(\.isFinite)
                && point.z > 0 && point.sigma > 0
                && [point.red, point.green, point.blue, point.opacity].allSatisfy { (0...1).contains($0) }
        })
        XCTAssertEqual(appStore.session.mediaAssets, baseline.mediaAssets)
        XCTAssertEqual(appStore.session.evidenceAnnotations, baseline.evidenceAnnotations)
        XCTAssertEqual(appStore.session.exportEvents, baseline.exportEvents)
        XCTAssertEqual(appStore.session.codingSnapshots, baseline.codingSnapshots)
        XCTAssertEqual(appStore.session.mediaAssets, [asset])
    }

    /// Real local-model generation, not an injected scene or an authentication bypass.
    /// Run on both phone and tablet destinations; each destination also renders Dynamic Type.
    @MainActor
    func testGaussianSheetRendersSyntheticRecordingAndDismissesOnConsentChange() async throws {
        try requireGaussianPresentationOptIn()
        let (appStore, playback, asset, url) = try await makeGaussianFixture()
        defer { playback.stop() }
        let presentation = GaussianHostedPresentation(playback: playback)
        presentation.request = try await prepareGaussianRequest(appStore, playback: playback, asset: asset, url: url)
        let (window, host) = try await mountGaussian(presentation, appStore: appStore)
        defer { window.isHidden = true; window.rootViewController = nil }
        try await waitForGaussian(presentation, host: host)

        let size = window.bounds.size
        attachGaussian(window, size: size, name: "gaussian-\(UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone")")
        let metal = try XCTUnwrap(descendants(in: host.view.window ?? host.view).compactMap { $0 as? MTKView }.first)
        XCTAssertNotNil(metal.device)
        XCTAssertGreaterThan(metal.drawableSize.width, 0)
        XCTAssertGreaterThan(metal.drawableSize.height, 0)
        let renderer = try XCTUnwrap(metal.delegate as? GaussianMetalRenderer)
        XCTAssertNil(renderer.failure, "The real hosted Metal renderer must initialize successfully.")
        XCTAssertFalse(metal.isHidden)
        XCTAssertTrue(metal.convert(metal.bounds, to: window).intersects(window.bounds))
        // Opt-in test-only hold for a compositor screenshot; never enabled in the app.
        if let raw = ProcessInfo.processInfo.environment["GAUSSIAN_SNAPSHOT_HOLD_SECONDS"],
           let seconds = Double(raw), seconds > 0 {
            print("GAUSSIAN_COMPOSITOR_READY: generated sheet visible; holding for \(min(seconds, 120)) seconds")
            try await Task.sleep(for: .seconds(min(seconds, 120)))
        }

        presentation.dynamicType = .accessibility3
        await Task.yield()
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(200))
        attachGaussian(window, size: size, name: "gaussian-accessibility3")
        XCTAssertEqual(presentation.generatedCount, 1, "Layout changes must not start another inference.")
        XCTAssertTrue(playback.matchesPausedFrame(url: url, time: try XCTUnwrap(presentation.request).time))

        // Replacing the grant also invalidates the frozen authorization identity.
        var regranted = appStore.session
        regranted.consentGrants = [documentedGrant(scopes: [.collection, .localReflection, .researchProcessing])]
        appStore.replaceSession(regranted)
        try await assertGaussianDismissed(presentation, host: host)
        XCTAssertEqual(appStore.session.mediaAssets, [asset], "No generated scene is added as media.")
    }

    @MainActor
    func testGaussianSheetDismissesOnPausedClockChangeAndMemoryWarning() async throws {
        try requireGaussianPresentationOptIn()
        let (appStore, playback, asset, url) = try await makeGaussianFixture()
        defer { playback.stop() }
        for memoryWarning in [false, true] {
            playback.seek(to: 400, durationMilliseconds: asset.durationMilliseconds)
            try await eventually("Synthetic seek must settle") { !playback.isSeeking }
            let presentation = GaussianHostedPresentation(playback: playback)
            presentation.request = try await prepareGaussianRequest(appStore, playback: playback, asset: asset, url: url)
            let (window, host) = try await mountGaussian(presentation, appStore: appStore)
            defer { window.isHidden = true; window.rootViewController = nil }
            try await waitForGaussian(presentation, host: host)
            if memoryWarning {
                NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
            } else {
                playback.seek(to: 700, durationMilliseconds: asset.durationMilliseconds)
            }
            try await assertGaussianDismissed(presentation, host: host)
            window.isHidden = true
            window.rootViewController = nil
        }
    }

    private func requireGaussianPresentationOptIn() throws {
        guard ProcessInfo.processInfo.environment["GAUSSIAN_PRESENTATION_TESTS"] == "1" else {
            throw XCTSkip("Manual foreground/LocalAuthentication prerequisite: set GAUSSIAN_PRESENTATION_TESTS=1 for real sheet checks.")
        }
    }

    @MainActor
    private func makeGaussianFixture() async throws -> (AppStore, ReflectionPlaybackModel, SessionMediaAsset, URL) {
        guard GaussianFrameGenerator.bundledModelURL != nil else {
            if ProcessInfo.processInfo.environment["GAUSSIAN_REQUIRE_MODEL"] == "1" {
                XCTFail("The required pinned local model is not bundled.")
                throw GaussianHostedTestError.modelMissing
            }
            throw XCTSkip("Optional local model absent; prepare it to run real Gaussian presentation coverage.")
        }
        let root = try makeFixtureRoot()
        let store = SessionStore(rootDirectory: root)
        var session = syntheticSession()
        session.operatingMode = .experimentalResearch
        session.experimentalProtocol = ResearchProtocolReference(
            protocolIdentifier: "synthetic-gaussian-rendering", oversightReference: "hardware-free-test",
            expiresAt: Date().addingTimeInterval(3_600), disclosureAcknowledgedAt: Date()
        )
        session.consentGrants = [documentedGrant(scopes: [.collection, .localReflection, .researchProcessing])]
        try store.save(session)
        let source = root.appendingPathComponent("synthetic-gaussian.mp4")
        try await Self.writeSyntheticVideo(to: source, gaussianPattern: true)
        var asset = try store.importMedia(from: source, into: session.id)
        let metadata = try await MediaInspector().inspect(url: source)
        asset.durationMilliseconds = metadata.durationMilliseconds
        asset.sha256 = metadata.sha256
        asset.codec = metadata.codec
        asset.resolution = metadata.resolution
        asset.frameRate = metadata.frameRate
        session.mediaAssets = [asset]
        try store.save(session)
        try store.commitImportedMedia(asset, toSession: session.id)
        let appStore = AppStore(store: store, bootstrapMode: .deferred)
        await appStore.bootstrap()
        XCTAssertEqual(appStore.session.id, session.id)
        XCTAssertTrue(appStore.session.hasUsableExperimentalProtocol)
        XCTAssertTrue(appStore.session.authorizes(.localReflection))
        // Persisted JSON timestamps can differ in precision from freshly imported
        // values. Reuse the exact bootstrapped asset, not a pre-persistence copy.
        let loadedAsset = try XCTUnwrap(appStore.session.mediaAssets.first { $0.id == asset.id })
        XCTAssertEqual(loadedAsset.id, asset.id)
        XCTAssertEqual(appStore.session.mediaAssets, [loadedAsset])
        // The source remains synthetic; use its decodable URL with the committed asset identity.
        let playback = ReflectionPlaybackModel()
        playback.configure(url: source)
        try await eventually("Synthetic playback must be ready") { playback.player?.currentItem?.status == .readyToPlay }
        playback.seek(to: 400, durationMilliseconds: loadedAsset.durationMilliseconds)
        try await eventually("Synthetic seek must settle") { !playback.isSeeking }
        return (appStore, playback, loadedAsset, source)
    }

    @MainActor
    private func prepareGaussianRequest(
        _ appStore: AppStore, playback: ReflectionPlaybackModel, asset: SessionMediaAsset, url: URL
    ) async throws -> GaussianFrameRequest {
        let selection = GaussianLaunchPreparation.Selection(session: appStore.session, assetID: asset.id, mediaURL: url)
        return try await GaussianLaunchPreparation.prepare(
            selection: selection, persist: { await appStore.flushPendingChanges() },
            currentSelection: { .init(session: appStore.session, assetID: asset.id, mediaURL: url) },
            freeze: { playback.pauseForGaussianExploration() }
        )
    }

    @MainActor
    private func mountGaussian(
        _ presentation: GaussianHostedPresentation, appStore: AppStore
    ) async throws -> (UIWindow, UIViewController) {
        let size = UIDevice.current.userInterfaceIdiom == .pad
            ? CGSize(width: 1_024, height: 768) : CGSize(width: 390, height: 844)
        let host = UIHostingController(rootView: GaussianHostedTestView(presentation: presentation).environmentObject(appStore))
        print("GAUSSIAN_HOST_SCENES: app state \(UIApplication.shared.applicationState.rawValue), scenes \(UIApplication.shared.connectedScenes.map { $0.activationState.rawValue })")
        // Opt-in manual presentation runs allow time to dismiss native device
        // authentication even when Simulator launch itself is delayed.
        try await eventually("Hosted checks require an actually foreground-active scene", timeout: 180) {
            UIApplication.shared.connectedScenes.contains { $0 is UIWindowScene && $0.activationState == .foregroundActive }
        }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }, "Hosted checks require a foreground Simulator scene.")
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = host
        window.makeKeyAndVisible()
        XCTAssertTrue(window.isKeyWindow)
        XCTAssertFalse(window.isHidden)
        XCTAssertEqual(scene.activationState, .foregroundActive)
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        return (window, host)
    }

    @MainActor
    private func waitForGaussian(_ presentation: GaussianHostedPresentation, host: UIViewController) async throws {
        try await eventually("Real-model sheet must publish a generated result", timeout: 120) {
            presentation.state == .generated || presentation.state == .unavailable || presentation.state == .discarded
        }
        XCTAssertEqual(presentation.state, .generated)
        guard presentation.state == .generated else { throw GaussianHostedTestError.notGenerated }
        try await eventually("Sheet must be genuinely presented and contain Metal") {
            host.presentedViewController != nil && descendants(in: host.view.window ?? host.view).contains { $0 is MTKView }
        }
        host.presentedViewController?.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(200))
    }

    @MainActor
    private func assertGaussianDismissed(_ presentation: GaussianHostedPresentation, host: UIViewController) async throws {
        try await eventually("Invalidation must discard the scene and actually dismiss the modal") {
            presentation.state == .discarded && presentation.didDismiss && host.presentedViewController == nil
        }
        XCTAssertNil(presentation.request)
        XCTAssertEqual(presentation.generatedCount, 1)
    }

    @MainActor
    private func eventually(_ description: String, timeout: TimeInterval = 15, condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline { try await Task.sleep(for: .milliseconds(25)) }
        XCTAssertTrue(condition(), description)
        if !condition() { throw GaussianHostedTestError.timedOut }
    }

    @MainActor
    private func descendants(in view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants(in: $0) } }

    @MainActor
    private func attachGaussian(_ window: UIWindow, size: CGSize, name: String) {
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
        XCTAssertEqual(image.size, size)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testScientificVideoRedesignRendersRepresentativeSurfaces() async throws {
        let root = try makeFixtureRoot()
        let store = SessionStore(rootDirectory: root)
        let fixture = syntheticSession()
        try store.save(fixture)
        let sourceVideo = root.appendingPathComponent("synthetic-checker.mp4")
        try await Self.writeSyntheticVideo(to: sourceVideo)
        var importedAsset = try store.importMedia(from: sourceVideo, into: fixture.id)
        let metadata = try await MediaInspector().inspect(url: sourceVideo)
        XCTAssertEqual(metadata.codec, "avc1")
        importedAsset.durationMilliseconds = metadata.durationMilliseconds
        importedAsset.sha256 = metadata.sha256
        importedAsset.codec = metadata.codec
        importedAsset.resolution = metadata.resolution
        importedAsset.frameRate = metadata.frameRate
        XCTAssertEqual(importedAsset.role, .otherImported)
        XCTAssertGreaterThan(importedAsset.durationMilliseconds ?? 0, 0)

        var persistedFixture = fixture
        persistedFixture.mediaAssets = [importedAsset]
        persistedFixture.evidenceAnnotations[0].mediaAssetID = importedAsset.id
        try store.save(persistedFixture)
        try store.commitImportedMedia(importedAsset, toSession: persistedFixture.id)
        let savedFixture = try XCTUnwrap(store.load(id: persistedFixture.id))

        let appStore = AppStore(store: store, bootstrapMode: .deferred)
        await appStore.bootstrap()
        XCTAssertNil(appStore.lastStoreError, "Linked imported video must reopen without an orphan-recording warning.")
        let durable = try XCTUnwrap(store.load(id: persistedFixture.id))
        XCTAssertEqual(durable.title, persistedFixture.title)
        XCTAssertEqual(durable.evidenceAnnotations, savedFixture.evidenceAnnotations)
        XCTAssertEqual(durable.exportEvents, savedFixture.exportEvents)
        XCTAssertEqual(durable.mediaAssets, savedFixture.mediaAssets)
        XCTAssertTrue(appStore.session.authorizes(.collection))
        XCTAssertTrue(appStore.session.authorizes(.localReflection))
        XCTAssertEqual(ReflectionAnnotationIndex(durable.evidenceAnnotations).linkedPromptCount, 1)
        XCTAssertEqual(durable.exportEvents.last?.status, .completed)

        let ipad = CGSize(width: 1_024, height: 768)
        let phone = CGSize(width: 390, height: 844)

        let setupLiveStore = LiveStore(appStore: appStore)
        await render(
            RootTabView(selection: .setup)
                .environmentObject(appStore)
                .environmentObject(setupLiveStore)
                .environment(\.horizontalSizeClass, .regular),
            size: ipad,
            name: "redesign-ipad-setup"
        )

        let liveStore = LiveStore(appStore: appStore)
        await render(
            RootTabView(selection: .live)
                .environmentObject(appStore)
                .environmentObject(liveStore)
                .environment(\.horizontalSizeClass, .regular),
            size: ipad,
            name: "redesign-ipad-live-unavailable"
        )
        XCTAssertFalse(liveStore.isRecording, "The rendering fixture never represents a real take.")
        liveStore.stop()

        let reflectionLiveStore = LiveStore(appStore: appStore)
        await render(
            RootTabView(selection: .reflect)
                .environmentObject(appStore)
                .environmentObject(reflectionLiveStore)
                .environment(\.horizontalSizeClass, .regular),
            size: ipad,
            name: "redesign-ipad-reflection"
        )
        await render(
            ReflectView(initialSection: .metadata)
                .environmentObject(appStore),
            size: ipad,
            name: "redesign-ipad-export"
        )
        await render(
            ReflectView(initialSection: .metadata).environmentObject(appStore),
            size: ipad, name: "redesign-ipad-export-outcome", scrollToBottom: true
        )

        let phoneSetupLiveStore = LiveStore(appStore: appStore)
        await render(
            RootTabView(selection: .setup)
                .environmentObject(appStore)
                .environmentObject(phoneSetupLiveStore)
                .environment(\.horizontalSizeClass, .compact),
            size: phone,
            name: "redesign-iphone-setup"
        )
        let phoneLiveStore = LiveStore(appStore: appStore)
        await render(
            RootTabView(selection: .live)
                .environmentObject(appStore)
                .environmentObject(phoneLiveStore)
                .environment(\.horizontalSizeClass, .compact),
            size: phone,
            name: "redesign-iphone-live"
        )
        XCTAssertFalse(phoneLiveStore.isRecording, "The rendering fixture never represents a real take.")
        phoneLiveStore.stop()
        let phoneReflectionLiveStore = LiveStore(appStore: appStore)
        await render(
            RootTabView(selection: .reflect)
                .environmentObject(appStore)
                .environmentObject(phoneReflectionLiveStore)
                .environment(\.horizontalSizeClass, .compact),
            size: phone,
            name: "redesign-iphone-reflection"
        )
        await render(
            ReflectView(initialSection: .metadata).environmentObject(appStore),
            size: phone, name: "redesign-iphone-export"
        )
        await render(
            RootTabView(selection: .reflect)
                .environmentObject(appStore).environmentObject(phoneReflectionLiveStore)
                .environment(\.horizontalSizeClass, .compact),
            size: phone, name: "redesign-iphone-notes", scrollToBottom: true
        )
        let accessibilityLiveStore = LiveStore(appStore: appStore)
        await render(
            RootTabView(selection: .setup)
                .environmentObject(appStore)
                .environmentObject(accessibilityLiveStore)
                .environment(\.horizontalSizeClass, .compact)
                .dynamicTypeSize(.accessibility3),
            size: phone,
            name: "redesign-accessibility-setup"
        )
        let emptyStore = AppStore(store: SessionStore(rootDirectory: try makeFixtureRoot()), bootstrapMode: .deferred)
        let accessibilityCapture = LiveStore(appStore: appStore)
        await render(
            RootTabView(selection: .live)
                .environmentObject(appStore).environmentObject(accessibilityCapture)
                .environment(\.horizontalSizeClass, .compact)
                .dynamicTypeSize(.accessibility3),
            size: phone, name: "redesign-accessibility-live"
        )
        accessibilityCapture.stop()
        await emptyStore.bootstrap()
        await render(
            ReflectView().environmentObject(emptyStore),
            size: phone, name: "redesign-iphone-empty"
        )
    }

    @MainActor
    private func render<Content: View>(
        _ content: Content, size: CGSize, name: String, scrollToBottom: Bool = false
    ) async {
        let host = UIHostingController(rootView: content)
        let requestedBounds = CGRect(origin: .zero, size: size)
        let window = UIWindow(frame: requestedBounds)
        let container = UIViewController()
        window.rootViewController = container
        container.addChild(host)
        container.view.addSubview(host.view)
        host.didMove(toParent: container)
        host.view.autoresizingMask = []
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        host.view.frame = requestedBounds
        host.view.bounds = requestedBounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        await Task.yield()
        try? await Task.sleep(nanoseconds: 600_000_000)
        host.view.frame = requestedBounds
        host.view.bounds = requestedBounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        XCTAssertEqual(host.view.bounds.size, size, "\(name) must render at its requested review size.")

        if scrollToBottom {
            let scrollViews = descendantScrollViews(in: host.view)
            let scrollView = scrollViews.max { $0.contentSize.height < $1.contentSize.height }
            if let scrollView {
                let bottom = max(-scrollView.adjustedContentInset.top,
                    scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
                scrollView.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
                host.view.layoutIfNeeded()
                try? await Task.sleep(nanoseconds: 100_000_000)
            } else {
                XCTFail("\(name) requires a scrollable surface")
            }
        }

        let image = UIGraphicsImageRenderer(size: size).image { _ in
            host.view.drawHierarchy(in: requestedBounds, afterScreenUpdates: true)
        }
        XCTAssertEqual(image.size, size, "\(name) attachment must retain the requested review size.")
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func descendantScrollViews(in view: UIView) -> [UIScrollView] {
        (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { descendantScrollViews(in: $0) }
    }

    private func makeFixtureRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScientificVideoSnapshotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    private func syntheticSession() -> CaptureSession {
        let grant = documentedGrant(scopes: [.collection, .localReflection, .secondaryUse, .externalSharing])
        let mediaID = UUID()
        var annotationValues = EvidenceAnnotation.Values()
        annotationValues.promptIdentifier = ReflectionPromptID.studentLearningEvidence.rawValue
        annotationValues.mediaAssetID = mediaID
        annotationValues.startMilliseconds = 100
        annotationValues.endMilliseconds = 700
        annotationValues.note = "Synthetische, menschlich verfasste Notiz zum Vergleichen von Brüchen."
        annotationValues.authorPseudonym = "R-01"

        var exportValues = ExportEvent.Values()
        exportValues.operatorPseudonym = "R-01"
        exportValues.operatorAuthenticationMethod = "deviceOwnerAuthentication"
        exportValues.includedScopes = [.collection, .localReflection, .secondaryUse, .externalSharing]
        exportValues.fileDigests = ["session.json": "synthetic"]
        exportValues.shareActivityIdentifier = "system-share"
        exportValues.status = .completed

        var context = SessionContext.Values()
        context.subject = "Mathematik"
        context.gradeLevel = "6"
        context.lessonGoal = "Brüche vergleichen"
        context.schoolOrSite = "Synthetischer Testort"

        var values = CaptureSession.Values()
        values.title = "Brüche vergleichen · Demo"
        values.plannedDurationMinutes = 20
        values.context = SessionContext(context)
        values.consentGrants = [grant]
        values.evidenceAnnotations = [EvidenceAnnotation(annotationValues)]
        values.reflection[.studentLearningEvidence] = annotationValues.note
        values.exportEvents = [ExportEvent(exportValues)]
        return CaptureSession(values)
    }

    private func documentedGrant(scopes: Set<ConsentScope>) -> ConsentGrant {
        var values = ConsentGrant.Values()
        values.scopes = scopes
        values.documentIdentifier = "synthetic-consent"
        values.documentVersion = "1"
        values.participantGroupPseudonym = "synthetic-group"
        values.grantedAt = Date().addingTimeInterval(-60)
        return ConsentGrant(values)
    }

    private static func writeSyntheticVideo(to url: URL, gaussianPattern: Bool = false) async throws {
        let size = CGSize(width: 320, height: 180)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: size.width,
                AVVideoHeightKey: size.height
            ]
        )
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: size.width,
                kCVPixelBufferHeightKey as String: size.height
            ]
        )
        XCTAssertTrue(writer.canAdd(input))
        writer.add(input)
        guard writer.startWriting() else {
            XCTFail(writer.error?.localizedDescription ?? "Synthetic writer could not start.")
            throw GaussianHostedTestError.videoWriterUnavailable
        }
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<30 {
            guard let buffer = makeSyntheticPixelBuffer(from: adaptor, size: size, frame: frame, gaussianPattern: gaussianPattern) else {
                writer.cancelWriting()
                XCTFail("Synthetic video frame could not allocate a pixel buffer")
                throw GaussianHostedTestError.videoWriterUnavailable
            }
            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            while !input.isReadyForMoreMediaData, ContinuousClock.now < deadline, writer.status == .writing {
                try await Task.sleep(for: .milliseconds(10))
            }
            guard writer.status == .writing, input.isReadyForMoreMediaData else {
                let failure = writer.error?.localizedDescription ?? "writer status \(writer.status.rawValue)"
                writer.cancelWriting()
                XCTFail("Synthetic video writer did not accept frame \(frame) within its bounded readiness deadline: \(failure).")
                throw GaussianHostedTestError.videoWriterUnavailable
            }
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)) else {
                let failure = writer.error?.localizedDescription ?? "unknown writer error"
                writer.cancelWriting()
                XCTFail("Synthetic test-pattern frame \(frame) could not be appended: \(failure)")
                throw GaussianHostedTestError.videoWriterUnavailable
            }
        }
        input.markAsFinished()
        await withCheckedContinuation { continuation in
            writer.finishWriting { continuation.resume() }
        }
        XCTAssertEqual(writer.status, .completed, writer.error?.localizedDescription ?? "Synthetic test video did not complete.")
        guard writer.status == .completed else { throw GaussianHostedTestError.videoWriterUnavailable }
    }

    private static func makeSyntheticPixelBuffer(
        from adaptor: AVAssetWriterInputPixelBufferAdaptor,
        size: CGSize,
        frame: Int,
        gaussianPattern: Bool
    ) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        guard let pool = adaptor.pixelBufferPool,
              CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
              let buffer
        else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        let width = Int(size.width)
        let height = Int(size.height)
        let pixels = baseAddress.assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            for x in 0..<width {
                let index = y * rowBytes + x * 4
                if gaussianPattern {
                    // Same spatial gradients/checker as the actual-model macOS smoke;
                    // two repeated colours alone can yield a correctly rejected flat depth map.
                    pixels[index] = (x / 20 + y / 20).isMultiple(of: 2) ? 220 : 30
                    pixels[index + 1] = UInt8(y * 255 / height)
                    pixels[index + 2] = UInt8(x * 255 / width)
                } else {
                    let light = ((x / 32) + (y / 30) + frame / 10).isMultiple(of: 2)
                    pixels[index] = light ? 72 : 36       // blue
                    pixels[index + 1] = light ? 116 : 64  // green
                    pixels[index + 2] = light ? 164 : 92  // red
                }
                pixels[index + 3] = 255
            }
        }
        return buffer
    }
}

private enum GaussianHostedTestError: Error { case timedOut, generationTimedOut, videoWriterUnavailable, modelMissing, notGenerated }

@MainActor
private final class GaussianHostedPresentation: ObservableObject {
    @Published var request: GaussianFrameRequest?
    @Published var dynamicType = DynamicTypeSize.large
    var state: GaussianPresentationState?
    var generatedCount = 0
    var didDismiss = false
    let playback: ReflectionPlaybackModel

    init(playback: ReflectionPlaybackModel) { self.playback = playback }

    func observe(_ next: GaussianPresentationState) {
        state = next
        if next == .generated { generatedCount += 1 }
    }
}

@MainActor
private struct GaussianHostedTestView: View {
    @ObservedObject var presentation: GaussianHostedPresentation

    var body: some View {
        Text("Synthetische Aufnahme · Hosted Test")
            .sheet(item: $presentation.request, onDismiss: { presentation.didDismiss = true }) { request in
                GaussianExplorationSheet(
                    request: request,
                    isCurrent: { presentation.playback.matchesPausedFrame(url: request.mediaURL, time: request.time) },
                    onPresentationState: presentation.observe
                )
                // A real foreground UIWindowScene is asserted by the host. A standalone
                // UIHostingController does not inherit the app's SwiftUI scene environment.
                .environment(\.scenePhase, .active)
                .dynamicTypeSize(presentation.dynamicType)
                .presentationDetents([.large])
                .presentationCompactAdaptation(.none)
            }
    }
}

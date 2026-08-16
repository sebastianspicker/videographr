import XCTest

/// End-to-end screenshot proof for the five-tab Videographr workflow.
///
/// Every screenshot is captured only after an accessibility-visible product state is asserted.
/// Evidence stays in the result bundle as retained XCTest attachments. The host-side runner
/// validates and publishes those attachments transactionally after the test succeeds.
@MainActor
final class VideographrE2EScreenshots: XCTestCase {
    static let expectedScreenshotNames: Set<String> = [
        "01-setup-scoped-consent",
        "02-live-preroll-guidance",
        "03-live-simulator-recording-rejection",
        "04-reflect-laf",
        "05-learn-catalogue",
        "06-learn-method-detail",
        "07-info-scope",
        "08-info-pipeline"
    ]

    var app: XCUIApplication!
    var capturedNames: Set<String> = []
    var capturedImageData: [String: Data] = [:]
    var capturedNotes: [String: String] = [:]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testE2E_coreFunctionsScreenshotTour() throws {
        prepareApp()
        defer {
            app.terminate()
            app = nil
        }

        try proveSetup()
        try proveLiveSimulatorPath()
        try proveReflection()
        try proveLearnCatalogue()
        try proveInfo()
        proveConsentRevocationSurvivesRelaunch()
        try verifyAttachments()
    }

    func testE2E_setupTraversalHandlesVirtualizedFields() throws {
        prepareApp()
        defer {
            app.terminate()
            app = nil
        }

        try proveSetup()
    }

    func testLiveCompactContract() {
        XCUIDevice.shared.orientation = .landscapeRight
        app = XCUIApplication()
        app.launchEnvironment["VIDEOGRAPHR_E2E_SESSION"] = UUID().uuidString
        app.launchEnvironment["VIDEOGRAPHR_E2E_START_TAB"] = "live"
        app.launch()
        defer {
            app.terminate()
            app = nil
        }

        expect(app.navigationBars["Live & Aufnahme"].waitForExistence(timeout: 12))
        let exposure = requireElement("live.observability.exposure", timeout: 12)
        expect(exposure.isHittable, "Direct exposure observation is not visible in compact Live")
    }

    private func prepareApp() {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(de)",
            "-AppleLocale", "de_DE",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryM"
        ]
        app.launchEnvironment["VIDEOGRAPHR_E2E_SESSION"] = UUID().uuidString

        app.launch()
        expect(
            app.buttons["tab.Setup"].waitForExistence(timeout: 12)
                || app.tabBars.firstMatch.waitForExistence(timeout: 2),
            "Main tab bar did not appear"
        )
    }

    private func proveSetup() throws {
        goToTab("Setup", navigationTitle: "Setup")
        let form = primaryScrollContainer()

        fillSetupFields(in: form)

        fillConsentFields(in: form)

        for identifier in [
            "setup.consent.scope.collection",
            "setup.consent.scope.localReflection"
        ] {
            var toggle = requireVisibleElement(identifier, in: form)
            var didPersist = (toggle.value as? String) == "1"
            for _ in 0..<2 where !didPersist {
                tapToggleControl(toggle)
                didPersist = waitForValue("1", on: toggle, timeout: 5)
                if !didPersist {
                    toggle = requireVisibleElement(identifier, in: form)
                    didPersist = (toggle.value as? String) == "1"
                }
            }
            expect(
                didPersist,
                "Consent toggle did not persist in UI: \(identifier)"
            )
        }

        if app.keyboards.firstMatch.exists { app.swipeDown() }
        let saveGrant = requireVisibleElement("setup.consent.save", in: form)
        expect(saveGrant.isEnabled, "Scoped grant must be saveable")
        saveGrant.tap()

        let experimentalButton = requireVisibleElement("setup.mode.experimental", in: form)
        expectFalse(
            experimentalButton.isEnabled,
            "Experimental mode must stay blocked without research-processing scope and protocol"
        )

        if app.keyboards.firstMatch.exists { app.swipeDown() }
        let save = requireElement("setup.save.toolbar")
        expect(save.isEnabled)
        save.tap()

        let complete = requireVisibleElement("setup.complete", in: form)
        expectEqual(
            complete.label,
            "Ja",
            "Setup did not become complete"
        )
        try capture(
            "01-setup-scoped-consent",
            note: "Setup: versioned collection/local-reflection grant is saved; experimental mode remains gated"
        )
    }

    private func proveLiveSimulatorPath() throws {
        goToTab("Live", navigationTitle: "Live & Aufnahme")
        expect(requireElement("live.preview", timeout: 12).exists)
        let captureMode = requireElement("live.captureMode", timeout: 12)
        expect(
            waitForValue("simulator", on: captureMode, timeout: 12),
            "Simulator fallback did not become ready"
        )
        let initialState = requireElement("live.recordingState")
        expectEqual(initialState.value as? String, "idle")
        expectLiveExposure()
        expectFalse(
            app.descendants(matching: .any).matching(identifier: "live.experimentalHypotheses").firstMatch.exists,
            "Evidence-safe mode must not expose experimental hypotheses"
        )
        try capture(
            "02-live-preroll-guidance",
            note: "Live pre-roll: preview, idle state, and direct technical observability are asserted"
        )

        let list = liveScrollContainer()
        _ = requireVisibleElementBelow("live.recordingControls", in: list)
        let forceToggle = requireVisibleElementBelow("live.forceOverride", in: list)
        if (forceToggle.value as? String) != "1" { tapToggleControl(forceToggle) }
        expect(
            waitForValue("1", on: forceToggle, timeout: 3),
            "Simulator override did not persist in UI"
        )
        let reason = requireVisibleElementBelow("live.overrideReason", in: list)
        reason.tap()
        reason.typeText("E2E simulator path")
        expectEqual(
            reason.value as? String,
            "E2E simulator path",
            "Simulator override reason did not persist"
        )
        dismissKeyboardIfPresent(in: list)
        // Keyboard dismissal can reposition SwiftUI's virtualized List in either direction.
        let pseudonym = requireVisibleElement("live.operatorPseudonym", in: list)
        expectEqual(
            pseudonym.value as? String,
            "group-e2e",
            "Live audit pseudonym does not match the scoped consent record"
        )
        let start = requireVisibleElementBelow("live.start", in: list)
        expect(start.isEnabled, "Start must be enabled after acknowledged override")
        start.tap()
        let rejection = requireVisibleElement("live.recordStatus", in: primaryScrollContainer())
        expect(rejection.label.contains("Demo-Modus"), "Simulator rejection was not surfaced")
        try capture(
            "03-live-simulator-recording-rejection",
            note: "Live: simulator recording attempt is explicitly rejected and remains idle"
        )
        let rejectedStart = requireVisibleElement("live.start", in: list)
        expect(rejectedStart.label.contains("Start"), "Simulator must remain ready to start")
        expect(rejectedStart.isEnabled, "Simulator rejection must leave Start enabled")
        let rejectedStop = requireVisibleElement("live.stop", in: list)
        expectFalse(rejectedStop.isEnabled, "Simulator rejection must leave Stop disabled")
    }

    private func proveReflection() throws {
        goToTab("Reflektieren", navigationTitle: "Reflektieren")
        let form = primaryScrollContainer()
        let importMedia = requireVisibleElement("reflect.importMedia", in: form)
        expect(importMedia.isEnabled, "Scoped local-reflection grant must enable import")
        let field = requireVisibleElementBelow("reflect.lessonGoals", in: form, maxSwipes: 12)
        let reflectionText = "E2E: Lernziel und Schüleräußerung am Tafelbild beobachtet."
        field.tap()
        field.typeText(reflectionText)
        dismissKeyboardIfPresent(in: form)
        let visibleField = requireVisibleElementBelow(
            "reflect.lessonGoals",
            in: form,
            maxSwipes: 12
        )
        expectEqual(
            visibleField.value as? String,
            reflectionText,
            "Reflect analysis text was not preserved after keyboard dismissal"
        )
        try capture(
            "04-reflect-laf",
            note: "Reflect: first LAF analysis field is visibly populated"
        )
        let save = requireVisibleElementBelow("reflect.save", in: form)
        expect(save.isEnabled, "Reflect draft save must remain available after entering analysis")
    }

    private func proveLearnCatalogue() throws {
        goToTab("Lernen", navigationTitle: "Lernen")
        let method = requireElement("learn.topic.method")
        expect(method.isHittable)
        try capture("05-learn-catalogue", note: "Learn: method topic is present in catalogue")
        method.tap()
        expect(
            app.navigationBars["Methode: Unterrichtsvideographie"].waitForExistence(timeout: 6),
            "Method detail navigation did not complete"
        )
        expect(requireElement("learn.topic.detail").exists)
        try capture("06-learn-method-detail", note: "Learn: method detail is open")
    }

    private func proveInfo() throws {
        goToTab("Info", navigationTitle: "Info")
        expect(requireElement("info.content").exists)
        expect(app.staticTexts["Videographr"].firstMatch.waitForExistence(timeout: 3))
        try capture("07-info-scope", note: "Info: product identity and scientific-alpha scope")

        let list = primaryScrollContainer()
        let platform = requireVisibleElementBelow("info.platform", in: list, maxSwipes: 12)
        expect(platform.isHittable, "Platform section did not become visible after scrolling")
        try capture("08-info-pipeline", note: "Info: lower platform section is visibly asserted")
    }

    private func proveConsentRevocationSurvivesRelaunch() {
        goToTab("Setup", navigationTitle: "Setup")
        let list = primaryScrollContainer()
        let localReflection = requireVisibleElement("setup.consent.scope.localReflection", in: list)
        expectEqual(localReflection.value as? String, "1")
        tapToggleControl(localReflection)
        expectEqual(
            localReflection.value as? String,
            "0",
            "Scoped grant change did not update in the form"
        )
        let saveGrant = requireVisibleElement("setup.consent.save", in: list)
        expect(saveGrant.isEnabled)
        saveGrant.tap()

        app.terminate()
        app.launch()
        expect(
            app.buttons["tab.Setup"].waitForExistence(timeout: 12)
                || app.tabBars.firstMatch.waitForExistence(timeout: 2)
        )
        goToTab("Setup", navigationTitle: "Setup")
        let reloaded = requireVisibleElement(
            "setup.consent.scope.localReflection",
            in: primaryScrollContainer()
        )
        expectEqual(
            reloaded.value as? String,
            "0",
            "Consent revocation did not survive relaunch"
        )
    }

    private func goToTab(_ name: String, navigationTitle: String) {
        let custom = app.buttons["tab.\(name)"]
        if custom.waitForExistence(timeout: 2) {
            custom.tap()
        } else {
            let tab = app.tabBars.buttons[name]
            expect(tab.waitForExistence(timeout: 6), "Tab \(name) missing")
            tab.tap()
        }
        expect(
            app.navigationBars[navigationTitle].waitForExistence(timeout: 6),
            "Navigation title \(navigationTitle) missing after opening \(name)"
        )
    }

    func requireElement(_ identifier: String, timeout: TimeInterval = 6) -> XCUIElement {
        let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        expect(
            element.waitForExistence(timeout: timeout),
            "Missing accessibility element: \(identifier)"
        )
        return element
    }

    func requireVisibleElement(_ identifier: String, in scroll: XCUIElement) -> XCUIElement {
        var element = matchingElement(identifier)
        for _ in 0..<4 {
            element = matchingElement(identifier)
            if isReadyForInteraction(element, in: scroll) { break }
            scroll.swipeUp()
        }
        for _ in 0..<8 {
            element = matchingElement(identifier)
            if isReadyForInteraction(element, in: scroll) { break }
            scroll.swipeDown()
        }
        for _ in 0..<4 {
            element = matchingElement(identifier)
            if isReadyForInteraction(element, in: scroll) { break }
            scroll.swipeUp()
        }
        element = matchingElement(identifier)
        let exists = element.waitForExistence(timeout: 2)
        expect(
            exists && element.isHittable,
            "Element never became visible: \(identifier)"
        )
        return element
    }

    /// Sequential forms are traversed in their top-to-bottom layout order; avoid oscillating
    /// around a tall List after keyboard dismissal.
    func requireVisibleElementBelow(
        _ identifier: String,
        in scroll: XCUIElement,
        maxSwipes: Int = 16
    ) -> XCUIElement {
        var element = matchingElement(identifier)
        for _ in 0..<maxSwipes {
            element = matchingElement(identifier)
            if isReadyForInteraction(element, in: scroll) { break }
            advanceTowardElementBelow(element, in: scroll)
        }
        element = matchingElement(identifier)
        let exists = element.waitForExistence(timeout: 2)
        expect(
            exists && element.isHittable,
            "Element never became visible while scrolling down: \(identifier)"
        )
        return element
    }

    func requireFrameVisibleElementBelow(
        _ identifier: String,
        in scroll: XCUIElement,
        maxSwipes: Int = 16
    ) -> XCUIElement {
        var element = matchingElement(identifier)
        for _ in 0..<maxSwipes {
            element = matchingElement(identifier)
            if isWithinScrollViewport(element, in: scroll) { break }
            advanceTowardElementBelow(element, in: scroll)
        }
        element = matchingElement(identifier)
        let exists = element.waitForExistence(timeout: 2)
        expect(
            exists && isWithinScrollViewport(element, in: scroll),
            "Element never entered the safe scroll viewport: \(identifier)"
        )
        return element
    }

    private func matchingElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func isReadyForInteraction(_ element: XCUIElement, in scroll: XCUIElement) -> Bool {
        guard isWithinScrollViewport(element, in: scroll) else { return false }
        return element.isHittable
    }

    private func isWithinScrollViewport(_ element: XCUIElement, in scroll: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let elementFrame = element.frame
        guard elementFrame.width > 0, elementFrame.height > 0 else { return false }
        let center = CGPoint(x: elementFrame.midX, y: elementFrame.midY)
        return scroll.frame.insetBy(dx: 1, dy: 80).contains(center)
    }

    private func advanceTowardElementBelow(_ element: XCUIElement, in scroll: XCUIElement) {
        let safeViewport = scroll.frame.insetBy(dx: 1, dy: 80)
        let elementIsAboveViewport = element.exists && element.frame.midY < safeViewport.minY
        let startY = elementIsAboveViewport ? 0.35 : 0.70
        let endY = elementIsAboveViewport ? 0.55 : 0.50
        scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
            .press(
                forDuration: 0.05,
                thenDragTo: scroll.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.5, dy: endY)
                )
            )
    }

    func primaryScrollContainer() -> XCUIElement {
        if app.scrollViews["setup.scroll"].exists { return app.scrollViews["setup.scroll"] }
        if app.scrollViews["reflect.scroll"].exists { return app.scrollViews["reflect.scroll"] }
        if app.collectionViews.firstMatch.exists { return app.collectionViews.firstMatch }
        if app.scrollViews.firstMatch.exists { return app.scrollViews.firstMatch }
        return app.tables.firstMatch
    }

    func dismissKeyboardIfPresent(in scroll: XCUIElement) {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        scroll.swipeDown()
        expectFalse(keyboard.exists, "Keyboard did not dismiss before form scrolling")
    }

    fileprivate func tapToggleControl(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    private func waitForValue(_ value: String, on element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

}

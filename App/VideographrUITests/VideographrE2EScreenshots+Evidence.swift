import XCTest

extension VideographrE2EScreenshots {
    func fillSetupFields(in form: XCUIElement) {
        fill("setup.title", with: "E2E Mathe 7b Frontal", in: form, visible: false)
        fill("setup.subject", with: "Mathematik", in: form)
        fill("setup.lessonGoal", with: "Lineare Funktionen vergleichen", in: form)
    }

    func fillConsentFields(in form: XCUIElement) {
        fillBelow("setup.consent.document", with: "e2e-consent", in: form)
        fillBelow("setup.consent.version", with: "2", in: form)
        fillBelow("setup.consent.pseudonym", with: "group-e2e", in: form)
    }

    func expectLiveExposure() {
        expect(requireElement("live.observability.exposure").isHittable, "Direct exposure observation is not visible at pre-roll")
    }

    private func fill(_ identifier: String, with text: String, in form: XCUIElement, visible: Bool = true) {
        let field = visible ? requireVisibleElement(identifier, in: form) : requireElement(identifier)
        field.tap()
        field.typeText(text)
        dismissKeyboardIfPresent(in: form)
    }

    private func fillBelow(_ identifier: String, with text: String, in form: XCUIElement) {
        let field = requireFrameVisibleElementBelow(identifier, in: form)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        field.typeText(text)
        expectEqual(field.value as? String, text, "Text entry did not persist: \(identifier)")
        dismissKeyboardIfPresent(in: form)
    }

    func liveScrollContainer() -> XCUIElement { primaryScrollContainer() }

    func capture(_ name: String, note: String) throws {
        expect(Self.expectedScreenshotNames.contains(name), "Unexpected screenshot name: \(name)")
        expectFalse(capturedNames.contains(name), "Duplicate screenshot capture: \(name)")
        let screenshot = app.screenshot()
        addAttachment(screenshot, name: name, note: note)
        capturedImageData[name] = screenshot.pngRepresentation
        capturedNotes[name] = note
        capturedNames.insert(name)
    }

    func verifyAttachments() throws {
        expectEqual(capturedNames, Self.expectedScreenshotNames)
        expectEqual(Set(capturedImageData.keys), Self.expectedScreenshotNames)
        expectEqual(Set(capturedNotes.keys), Self.expectedScreenshotNames)
        for name in Self.expectedScreenshotNames {
            expectGreaterThan(try unwrap(capturedImageData[name]).count, 1_024, "Screenshot is unexpectedly small: \(name)")
        }
        try assertImagesDiffer("05-learn-catalogue", "06-learn-method-detail")
        try assertImagesDiffer("07-info-scope", "08-info-pipeline")
    }

    private func addAttachment(_ screenshot: XCUIScreenshot, name: String, note: String) {
        let image = XCTAttachment(screenshot: screenshot)
        image.name = "\(name).png"
        image.lifetime = .keepAlways
        add(image)
        let text = XCTAttachment(data: Data(note.utf8), uniformTypeIdentifier: "public.plain-text")
        text.name = "\(name).txt"
        text.lifetime = .keepAlways
        add(text)
    }

    private func assertImagesDiffer(_ first: String, _ second: String) throws {
        expectNotEqual(try unwrap(capturedImageData[first]), try unwrap(capturedImageData[second]), "Semantically different screens produced identical images")
    }

    func expect(_ condition: Bool, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(condition, message, file: file, line: line)
    }

    func expectFalse(_ condition: Bool, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(condition, message, file: file, line: line)
    }

    func expectEqual<T: Equatable>(_ first: T, _ second: T, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(first, second, message, file: file, line: line)
    }

    func expectNotEqual<T: Equatable>(_ first: T, _ second: T, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotEqual(first, second, message, file: file, line: line)
    }

    func expectGreaterThan<T: Comparable>(_ first: T, _ second: T, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThan(first, second, message, file: file, line: line)
    }

    func unwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) throws -> T {
        try XCTUnwrap(value, file: file, line: line)
    }
}

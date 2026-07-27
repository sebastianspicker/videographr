import XCTest
@testable import LearnContent

/// Ensures the educational catalogue ships the three alpha topics with non-empty sections.
final class LearnContentTests: XCTestCase {
    func testCatalogContainsRequiredTopics() {
        let ids = Set(LearnCatalog.topicIDs)
        XCTAssertTrue(ids.contains("method"))
        XCTAssertTrue(ids.contains("technology"))
        XCTAssertTrue(ids.contains("devices"))
        XCTAssertTrue(ids.contains("coding"))
        XCTAssertGreaterThanOrEqual(LearnCatalog.allTopics.count, 4)
    }

    func testCodingTopicFramesIPNTIMSSGTIAsHumanObservationContext() {
        guard let coding = LearnCatalog.topic(id: "coding") else {
            return XCTFail("Expected coding topic")
        }
        let blob = topicText(coding).lowercased()
        XCTAssertTrue(blob.contains("ipn"))
        XCTAssertTrue(blob.contains("timss"))
        XCTAssertTrue(blob.contains("gti") || blob.contains("talis"))
        XCTAssertTrue(blob.contains("menschliche beobachtung"))
        XCTAssertTrue(blob.contains("nicht validiert"))
        XCTAssertTrue(blob.contains("evidenzsicheren modus"))
        XCTAssertGreaterThanOrEqual(coding.sections.count, 3)
    }

    func testCatalogRejectsUnsupportedScientificClaims() {
        let blob = LearnCatalog.allTopics.map(topicText).joined(separator: " ").lowercased()
        let prohibitedPhrases = [
            "forschungstauglich",
            "international vergleichbar",
            "domänen-mittelwerte für die live-anzeige",
            "verschiebt die priors",
            "automatische bewertung der unterrichtsqualität",
            "sprachverständlichkeit geprüft"
        ]

        for phrase in prohibitedPhrases {
            XCTAssertFalse(blob.contains(phrase), "Unsupported claim must not ship: \(phrase)")
        }
    }

    func testCatalogStatesEvidenceBoundaryForAudioAndPedagogy() {
        let blob = LearnCatalog.allTopics.map(topicText).joined(separator: " ").lowercased()
        XCTAssertTrue(blob.contains("pegelwerte allein belegen keine inhaltliche verständlichkeit"))
        XCTAssertTrue(blob.contains("bewerten weder unterrichtsqualität noch diskurs"))
        XCTAssertTrue(blob.contains("nicht automatisch"))
    }

    func testMethodExplainsUnterrichtsvideographie() {
        let method = LearnCatalog.topic(id: "method")
        guard let method else { return XCTFail("Expected method topic") }
        let blob = method.sections.map(\.body).joined(separator: " ").lowercased()
        XCTAssertTrue(containsAny(blob, ["unterrichtsvideographie", "videographie"]))
        XCTAssertTrue(containsAny(blob, ["lehr", "wahrnehmung", "analyse"]))
        XCTAssertFalse(method.sections.isEmpty)
        guard let firstSection = method.sections.first else { return XCTFail("Expected method sections") }
        XCTAssertFalse(firstSection.heading.isEmpty)
    }

    func testDevicesExplainsMicrophones() {
        guard let devices = LearnCatalog.topic(id: "devices") else {
            return XCTFail("Expected devices topic")
        }
        let blob = devices.sections.map { $0.heading + " " + $0.body }.joined().lowercased()
        XCTAssertTrue(containsAny(blob, ["mikrofon", "mikro"]))
        XCTAssertTrue(containsAny(blob, ["lavalier", "steck", "funk", "audio"]))
    }

    func testTechnologyCoversLightAndCamera() {
        guard let tech = LearnCatalog.topic(id: "technology") else {
            return XCTFail("Expected technology topic")
        }
        let blob = tech.sections.map(\.body).joined().lowercased()
        XCTAssertTrue(containsAny(blob, ["gegenlicht", "licht"]))
        XCTAssertTrue(containsAny(blob, ["kamera", "ipad", "stativ"]))
    }

    private func topicText(_ topic: LearnTopic) -> String {
        ([topic.title, topic.subtitle] + topic.sections.flatMap { section in
            [section.heading, section.body, section.researchNote ?? ""]
        }).joined(separator: " ")
    }

    private func containsAny(_ source: String, _ terms: [String]) -> Bool {
        terms.contains(where: source.contains)
    }
}

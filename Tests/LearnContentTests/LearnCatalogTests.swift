import XCTest
@testable import LearnContent

final class LearnCatalogTests: XCTestCase {
    func testTopicIDsAreUniqueStableAndResolvable() {
        let expectedIDs = ["method", "technology", "devices", "checklist", "coding"]

        XCTAssertEqual(LearnCatalog.topicIDs, expectedIDs)
        XCTAssertEqual(Set(LearnCatalog.topicIDs).count, LearnCatalog.topicIDs.count)
        XCTAssertEqual(LearnCatalog.allTopics.map(\.id), expectedIDs)

        for id in LearnCatalog.topicIDs {
            XCTAssertEqual(LearnCatalog.topic(id: id)?.id, id)
        }
        XCTAssertNil(LearnCatalog.topic(id: "missing-topic"))
    }

    func testTopicsContainNonemptyGermanUserFacingContent() {
        let topics = LearnCatalog.allTopics
        XCTAssertFalse(topics.isEmpty)

        for topic in topics {
            XCTAssertFalse(topic.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(topic.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(topic.sections.isEmpty)

            for section in topic.sections {
                XCTAssertFalse(section.heading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                XCTAssertFalse(section.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }

        let userFacingText = topics
            .flatMap { [$0.title, $0.subtitle] + $0.sections.flatMap { [$0.heading, $0.body] } }
            .joined(separator: " ")
            .lowercased()
        XCTAssertTrue(userFacingText.contains("unterricht"))
        XCTAssertTrue(userFacingText.contains("lehr"))
    }

    func testSectionIDsAreUniqueAcrossTheCatalogue() {
        let sectionIDs = LearnCatalog.allTopics.flatMap(\.sections).map(\.id)

        XCTAssertEqual(Set(sectionIDs).count, sectionIDs.count)
        XCTAssertFalse(sectionIDs.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }))
    }
}

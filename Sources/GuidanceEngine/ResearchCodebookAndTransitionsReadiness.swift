extension ResearchReadinessReport {
    static func hasPassingPlacementSceneAndStructure(_ status: ReadinessStatus) -> Bool {
        status.placementOK && status.sceneOK && status.structureOK
    }

    static func hasEligibleQualityAndRecordability(_ result: GuidanceResult) -> Bool {
        result.researchQuality.level != .unsuitable && result.isReadyToRecord
    }
}

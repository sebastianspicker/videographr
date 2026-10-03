import Foundation

/// Source of computer-vision features (production Vision vs pure fixtures/heuristics).
public enum CVFeatureSource: String, Equatable, Sendable {
    case heuristic
    case vision
    case fixture
}

/// Normalized axis-aligned rectangle in image coordinates (0...1, origin top-left).
public struct ImageNormalizedRect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = min(1, max(0, x))
        self.y = min(1, max(0, y))
        self.width = min(1, max(0, width))
        self.height = min(1, max(0, height))
    }

    public var centerX: Double { x + width / 2 }
    public var centerY: Double { y + height / 2 }
    public var area: Double { width * height }

    /// Aspect ratio width/height (safe for zero height).
    public var aspectRatio: Double {
        guard height > 1e-6 else { return 0 }
        return width / height
    }

    /// Intersection-over-union with another normalized rect.
    public func iou(with other: ImageNormalizedRect) -> Double {
        let x0 = max(x, other.x)
        let y0 = max(y, other.y)
        let x1 = min(x + width, other.x + other.width)
        let y1 = min(y + height, other.y + other.height)
        let iw = max(0, x1 - x0)
        let ih = max(0, y1 - y0)
        let inter = iw * ih
        let union = area + other.area - inter
        guard union > 1e-9 else { return 0 }
        return inter / union
    }

}

/// Structured classroom CV features consumed by pure guidance (Vision adapter or fixtures).
///
/// Literature-informed candidate signals used by unvalidated rules:
/// - **Board / writing surface:** multi-cue confidence (rectangle + aspect + geometry + edge support + text density)
/// - **Actors / people:** counts plus spatial usefulness (coverage, mid-band occupancy, centroid placement)
/// - **Interaction structure:** person–board co-presence for Lehr-Lern-Geschehen
/// - **Spatial geometry:** horizontal/vertical spread and clusteredness, without a scene label
/// - Stability: multi-observation temporal stability (fusion quality over short window)
public struct CVFeatures: Equatable, Sendable {
    public var source: CVFeatureSource
    /// Primary board / writing-surface detection confidence 0...1 (rectangle detector).
    public var boardConfidence: Double
    public var boardRect: ImageNormalizedRect?
    /// Aspect-ratio fitness for writing surfaces (wide horizontal boards score higher). 0...1
    public var boardAspectQuality: Double
    /// Geometry/size fitness (neither tiny nor full-frame; upper-mid preferred). 0...1
    public var boardGeometryQuality: Double
    /// Edge / document-like corroboration cue (from Vision or pure proxy). 0...1
    public var boardEdgeSupport: Double
    /// Number of detected people (human rectangles / bodies).
    public var personCount: Int
    /// Fraction of frame covered by person boxes (0...1).
    public var personCoverage: Double
    /// Number of faces (optional denser signal).
    public var faceCount: Int
    /// Fraction of person mass lying in the vertical mid-band (interaction zone ~0.25–0.75). 0...1
    public var personMidBandOccupancy: Double
    /// Vertical centroid of people mass (0 top … 1 bottom). nil if no people.
    public var personCentroidY: Double?
    /// Horizontal centroid of people mass. nil if no people.
    public var personCentroidX: Double?
    /// Person–board co-presence for teaching–learning capture (spatial usefulness). 0...1
    public var personBoardCoPresence: Double
    /// Temporal stability of recent CV observations (1 = stable; low = flickering). 0...1
    public var observationStability: Double
    /// Horizontal spread of actors (layout structure). 0...1
    public var personHorizontalSpread: Double
    /// Vertical spread of actors. 0...1
    public var personVerticalSpread: Double
    /// How tightly people cluster (1 = single tight cluster). 0...1
    public var personClusteredness: Double
    /// Estimated spatial cluster count (group structure).
    public var estimatedClusterCount: Int
    /// Face/person scale as proximity proxy (closer teaching shot). 0...1
    public var faceScaleScore: Double
    /// OCR/text density on writing surface (structure only). 0...1
    public var boardTextDensity: Double
    /// Temporal change in person coverage vs recent observation (0 stable … 1 large change).
    public var personCoverageDelta: Double
    /// Secondary writing surface / multi-board corroboration (side board, screen). 0...1
    public var secondaryWritingSurfaceSupport: Double
    /// Variance of actor box scales (0 = uniform sizes; high = mixed close/far actors). 0...1
    public var actorScaleVariance: Double
    /// Mean pose/joint confidence when pose used (0...1); 0 if unavailable.
    public var poseConfidenceMean: Double
    /// Whether CV pipeline ran successfully for this frame.
    public var analysisSucceeded: Bool

    public struct Values: Sendable {
        public var source: CVFeatureSource = .heuristic
        public var boardConfidence = 0.0
        public var boardRect: ImageNormalizedRect?
        public var boardAspectQuality = 0.0
        public var boardGeometryQuality = 0.0
        public var boardEdgeSupport = 0.0
        public var personCount = 0
        public var personCoverage = 0.0
        public var faceCount = 0
        public var personMidBandOccupancy = 0.0
        public var personCentroidY: Double?
        public var personCentroidX: Double?
        public var personBoardCoPresence = 0.0
        public var observationStability = 1.0
        public var personHorizontalSpread = 0.0
        public var personVerticalSpread = 0.0
        public var personClusteredness = 0.0
        public var estimatedClusterCount = 0
        public var faceScaleScore = 0.0
        public var boardTextDensity = 0.0
        public var personCoverageDelta = 0.0
        public var secondaryWritingSurfaceSupport = 0.0
        public var actorScaleVariance = 0.0
        public var poseConfidenceMean = 0.0
        public var analysisSucceeded = true

        public init() {}
    }

    public init(_ values: Values) {
        source = values.source
        boardConfidence = min(1, max(0, values.boardConfidence))
        boardRect = values.boardRect
        boardAspectQuality = min(1, max(0, values.boardAspectQuality))
        boardGeometryQuality = min(1, max(0, values.boardGeometryQuality))
        boardEdgeSupport = min(1, max(0, values.boardEdgeSupport))
        personCount = max(0, values.personCount)
        personCoverage = min(1, max(0, values.personCoverage))
        faceCount = max(0, values.faceCount)
        personMidBandOccupancy = min(1, max(0, values.personMidBandOccupancy))
        personCentroidY = values.personCentroidY.map { min(1, max(0, $0)) }
        personCentroidX = values.personCentroidX.map { min(1, max(0, $0)) }
        personBoardCoPresence = min(1, max(0, values.personBoardCoPresence))
        observationStability = min(1, max(0, values.observationStability))
        personHorizontalSpread = min(1, max(0, values.personHorizontalSpread))
        personVerticalSpread = min(1, max(0, values.personVerticalSpread))
        personClusteredness = min(1, max(0, values.personClusteredness))
        estimatedClusterCount = max(0, values.estimatedClusterCount)
        faceScaleScore = min(1, max(0, values.faceScaleScore))
        boardTextDensity = min(1, max(0, values.boardTextDensity))
        personCoverageDelta = min(1, max(0, values.personCoverageDelta))
        secondaryWritingSurfaceSupport = min(1, max(0, values.secondaryWritingSurfaceSupport))
        actorScaleVariance = min(1, max(0, values.actorScaleVariance))
        poseConfidenceMean = min(1, max(0, values.poseConfidenceMean))
        analysisSucceeded = values.analysisSucceeded
    }

    public static func make(_ configure: (inout Values) -> Void) -> CVFeatures {
        var values = Values()
        configure(&values)
        return CVFeatures(values)
    }

    public var hasPeople: Bool { personCount > 0 || faceCount > 0 }

    /// Multi-cue board quality combining rectangle confidence with aspect, geometry, and edge support.
    public var multiCueBoardQuality: Double {
        CVFeatureFusion.multiCueBoardQuality(from: self)
    }

    /// Spatial usefulness of people for Lehr-Lern capture (coverage scale + mid-band + not empty).
    public var peopleSpatialUsefulness: Double {
        CVFeatureFusion.peopleSpatialUsefulness(from: self)
    }

    public static let empty = CVFeatures.make {
        $0.observationStability = 0
        $0.analysisSucceeded = false
    }
}

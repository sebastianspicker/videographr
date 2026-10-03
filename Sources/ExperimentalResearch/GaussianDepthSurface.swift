import Foundation
import SessionCore

/// Inferred geometry is a reflection experiment, never an authorization/readiness input.
public enum GaussianExplorationPolicy {
    public static func permits(_ session: CaptureSession, at date: Date = Date()) -> Bool {
        session.operatingMode == .experimentalResearch
            && session.experimentalProtocol?.isUsable(at: date) == true
            && session.authorizes(.researchProcessing, at: date)
            && session.authorizes(.localReflection, at: date)
    }
}

/// Frozen after persistence. Replacing grants or protocol requires a fresh exploration.
public struct GaussianAuthorizationContext: Equatable, Sendable {
    private let mode: OperatingMode
    private let researchProtocol: ResearchProtocolReference?
    private let grants: [ConsentGrant]

    public init(session: CaptureSession) {
        mode = session.operatingMode
        researchProtocol = session.experimentalProtocol
        grants = session.consentGrants
    }

    public func matches(_ session: CaptureSession) -> Bool {
        self == Self(session: session)
    }
}

public struct GaussianPoint: Equatable, Sendable {
    public let x: Float
    public let y: Float
    public let z: Float
    /// Fronto-parallel standard deviation in scene units.
    public let sigma: Float
    public let red: Float
    public let green: Float
    public let blue: Float
    public let opacity: Float
    /// One-standard-deviation surface steps along the source columns and rows. They lie in
    /// the locally estimated depth surface, so a tilted floor or wall keeps covering its
    /// neighbours when the view changes. In the source view both project to `sigma`.
    public let tangentU: SIMD3<Float>
    public let tangentV: SIMD3<Float>
    /// Source-frame texture coordinate of the centre and its offset per standard deviation.
    public let textureCenter: SIMD2<Float>
    public let textureStep: SIMD2<Float>
    /// True beside a disparity jump, where the surface estimate stops at an occlusion edge.
    public let isOcclusionEdge: Bool
    /// Area |det(axisU, axisV)| of the source-view projected footprint in normalized
    /// device units². Independent of depth, because the footprint scales with `z`.
    public let sourceFootprintArea: Float
}

public struct GaussianDepthSurface: Equatable, Sendable {
    public enum InputError: Error, Equatable {
        case invalidDimensions
        case invalidSamples
        case unavailableDepth
    }

    public static let maximumPointCount = 20_000
    /// Estimated camera field of view; recordings do not contain calibrated intrinsics.
    public static let verticalFieldOfViewDegrees: Float = 55
    /// Arbitrary scene units of the robust depth range, not metres.
    public static let nearestDepth: Float = 0.8
    public static let farthestDepth: Float = 1.5
    /// Footprint standard deviation in grid steps. Colour comes from the source frame, so
    /// the overlap closes coverage gaps without blurring: at least 98% source-view coverage
    /// away from occlusion edges, where shrunken footprints keep holes open.
    public static let footprintSteps: Float = 0.7
    /// Normalized disparity difference that counts as an occlusion edge, not a surface.
    public static let disparityJump: Float = 0.2
    /// Largest depth change per fronto-parallel step: a surface tilted about 80 degrees
    /// from fronto-parallel.
    /// Steeper estimates are clamped so a grazing surfel cannot reach across the scene.
    public static let maximumSlope: Float = 6
    public let points: [GaussianPoint]
    public let aspectRatio: Float

    /// Both arrays sample the same oriented-frame UVs. Depth is relative inverse depth.
    /// The robust range maps to arbitrary scene units [0.8, 1.5], not metres.
    public static func make(
        width: Int, height: Int, rgba: [UInt8], inverseDepth: [Float], aspectRatio: Float
    ) throws -> Self {
        guard width >= 2, height >= 2, width <= maximumPointCount / height,
              aspectRatio.isFinite, (0.1...10).contains(aspectRatio)
        else { throw InputError.invalidDimensions }
        let count = width * height
        guard rgba.count == count * 4, inverseDepth.count == count,
              inverseDepth.allSatisfy({ $0.isFinite && $0 >= 0 })
        else { throw InputError.invalidSamples }
        let ordered = inverseDepth.sorted()
        let lower = ordered[Int(Float(count - 1) * 0.05)]
        let upper = ordered[Int(Float(count - 1) * 0.95)]
        guard upper - lower > max(0.000001, abs(upper) * 0.000001) else {
            throw InputError.unavailableDepth
        }
        let disparities = inverseDepth.map { value in
            min(1, max(0, (value - lower) / (upper - lower)))
        }
        // Relative inverse depth is only known up to scale and shift, so the map stays
        // affine in inverse depth. Parallax is then affine in the model output.
        let farInverse = 1 / farthestDepth
        let inverseSpan = 1 / nearestDepth - farInverse
        let depths = disparities.map { disparity in
            min(farthestDepth, max(nearestDepth, 1 / (farInverse + disparity * inverseSpan)))
        }
        let tangent = tan(verticalFieldOfViewDegrees * .pi / 360)
        // Fronto-parallel size of one grid step per unit depth.
        let stepX = tangent * aspectRatio * 2 / Float(width)
        let stepY = tangent * 2 / Float(height)
        // Depth change per grid step from the neighbours on the same surface. A neighbour
        // across a disparity jump is another object, so it is neither used nor bridged.
        func slope(_ index: Int, _ offset: Int, hasPrevious: Bool, hasNext: Bool) -> (depth: Float, edge: Bool) {
            let disparity = disparities[index]
            let previous = hasPrevious && abs(disparities[index - offset] - disparity) <= disparityJump
            let next = hasNext && abs(disparities[index + offset] - disparity) <= disparityJump
            let edge = (hasPrevious && !previous) || (hasNext && !next)
            switch (previous, next) {
            case (true, true): return ((depths[index + offset] - depths[index - offset]) / 2, edge)
            case (true, false): return (depths[index] - depths[index - offset], edge)
            case (false, true): return (depths[index + offset] - depths[index], edge)
            case (false, false): return (0, edge)
            }
        }
        var points: [GaussianPoint] = []
        points.reserveCapacity(count)
        for row in 0..<height {
            for column in 0..<width {
                let index = row * width + column
                let z = depths[index]
                let u = (Float(column) + 0.5) / Float(width)
                let v = (Float(row) + 0.5) / Float(height)
                let horizontal = slope(index, 1, hasPrevious: column > 0, hasNext: column < width - 1)
                let vertical = slope(index, width, hasPrevious: row > 0, hasNext: row < height - 1)
                // Smaller footprints on both sides of a disparity jump preserve holes
                // instead of bridging them.
                let steps = footprintSteps * (horizontal.edge || vertical.edge ? 0.65 : 1)
                // P(u, v) = z * ray(u, v), so a grid step moves z * dRay + dz * ray. The ray
                // term projects to nothing in the source view and only matters once it moves.
                let ray = SIMD3((2 * u - 1) * tangent * aspectRatio, (1 - 2 * v) * tangent, 1)
                let limitX = maximumSlope * z * stepX
                let limitY = maximumSlope * z * stepY
                points.append(GaussianPoint(
                    x: ray.x * z, y: ray.y * z, z: z, sigma: z * stepY * steps,
                    red: Float(rgba[index * 4]) / 255,
                    green: Float(rgba[index * 4 + 1]) / 255,
                    blue: Float(rgba[index * 4 + 2]) / 255,
                    opacity: Float(rgba[index * 4 + 3]) / 255 * 0.98,
                    tangentU: steps * (SIMD3(z * stepX, 0, 0) + min(limitX, max(-limitX, horizontal.depth)) * ray),
                    tangentV: steps * (SIMD3(0, -z * stepY, 0) + min(limitY, max(-limitY, vertical.depth)) * ray),
                    textureCenter: SIMD2(u, v),
                    textureStep: SIMD2(steps / Float(width), steps / Float(height)),
                    isOcclusionEdge: horizontal.edge || vertical.edge,
                    sourceFootprintArea: steps * steps * 4 / Float(width * height)
                ))
            }
        }
        return Self(points: points, aspectRatio: aspectRatio)
    }
}

/// Translation and a small orbit around an arbitrary display focus, not measured geometry.
public struct GaussianCamera: Equatable, Sendable {
    public static let lateralLimit: Float = 0.10
    public static let dollyLimit: Float = 0.08
    public static let yawLimitDegrees: Float = 5
    public static let pitchLimitDegrees: Float = 4
    /// Mid-disparity depth of the robust range, so orbiting pivots around the scene middle.
    public static let focusDepth: Float = 2 / (1 / GaussianDepthSurface.nearestDepth + 1 / GaussianDepthSurface.farthestDepth)
    public let horizontal: Float
    public let vertical: Float
    public let dolly: Float
    public let yawDegrees: Float
    public let pitchDegrees: Float

    public init(horizontal: Float = 0, vertical: Float = 0, dolly: Float = 0,
                yawDegrees: Float = 0, pitchDegrees: Float = 0) {
        self.horizontal = Self.bound(horizontal, limit: Self.lateralLimit)
        self.vertical = Self.bound(vertical, limit: Self.lateralLimit)
        self.dolly = Self.bound(dolly, limit: Self.dollyLimit)
        self.yawDegrees = Self.bound(yawDegrees, limit: Self.yawLimitDegrees)
        self.pitchDegrees = Self.bound(pitchDegrees, limit: Self.pitchLimitDegrees)
    }

    private static func bound(_ value: Float, limit: Float) -> Float {
        value.isFinite ? min(limit, max(-limit, value)) : 0
    }
}

/// Camera basis shared by the CPU reference projection and the GPU renderer.
public struct GaussianViewFrame: Equatable, Sendable {
    public let right: SIMD3<Float>
    public let up: SIMD3<Float>
    public let forward: SIMD3<Float>
    public let position: SIMD3<Float>

    public init(camera: GaussianCamera) {
        guard camera.yawDegrees != 0 || camera.pitchDegrees != 0 else {
            // An exact identity basis keeps the source camera bit-for-bit reproducible.
            right = SIMD3(1, 0, 0)
            up = SIMD3(0, 1, 0)
            forward = SIMD3(0, 0, 1)
            position = SIMD3(camera.horizontal, camera.vertical, camera.dolly)
            return
        }
        let yaw = camera.yawDegrees * .pi / 180
        let pitch = camera.pitchDegrees * .pi / 180
        right = SIMD3(cos(yaw), 0, sin(yaw))
        up = SIMD3(-sin(yaw) * sin(pitch), cos(pitch), cos(yaw) * sin(pitch))
        forward = SIMD3(-sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
        position = SIMD3<Float>(0, 0, GaussianCamera.focusDepth)
            - (GaussianCamera.focusDepth - camera.dolly) * forward
            + camera.horizontal * right + camera.vertical * up
    }
}

public struct GaussianProjectedPoint: Equatable, Sendable {
    public let x: Float
    public let y: Float
    /// Screen offsets of one standard deviation along `tangentU` and `tangentV`, so the
    /// projected covariance is `axisU * axisUᵀ + axisV * axisVᵀ`.
    public let axisU: SIMD2<Float>
    public let axisV: SIMD2<Float>
    /// Marginal standard deviations of that covariance along the screen axes.
    public let sigmaX: Float
    public let sigmaY: Float
    public let cameraDepth: Float
    /// Ratio of displayed to recorded footprint area, measured before the size clamp. About 1
    /// in the source view and above 1 where the view spreads one captured sample over more
    /// screen area.
    public let stretch: Float
    public let point: GaussianPoint
}

/// Direct display measure of how far a splat interpolates between recorded samples, in
/// [0, 1]. It is not a validated error estimate. A uniform dolly to the limit magnifies area
/// about 1.23 times, which is why the onset is 1.5.
public enum GaussianEvidence {
    public static let stretchOnset: Float = 1.5
    public static let stretchFull: Float = 3
    /// Floor for points beside an occlusion edge, where the depth estimate is least reliable.
    public static let occlusionEdgeUncertainty: Float = 0.5

    public static func uncertainty(stretch: Float, isOcclusionEdge: Bool) -> Float {
        guard stretch.isFinite else { return 1 }
        let t = min(1, max(0, (stretch - stretchOnset) / (stretchFull - stretchOnset)))
        return max(t * t * (3 - 2 * t), isOcclusionEdge ? occlusionEdgeUncertainty : 0)
    }
}

public enum GaussianProjection {
    public static let tangent = tan(GaussianDepthSurface.verticalFieldOfViewDegrees * .pi / 360)
    /// Points at or nearer than this camera depth are culled.
    public static let nearClip: Float = 0.05
    /// Largest footprint standard deviation in vertical normalized device units.
    public static let maximumSigma: Float = 0.04

    /// Perspective projection and far-to-near order for premultiplied alpha compositing.
    /// Reference for the GPU renderer, which evaluates the same math per vertex.
    public static func project(
        _ surface: GaussianDepthSurface, camera: GaussianCamera
    ) -> [GaussianProjectedPoint] {
        let frame = GaussianViewFrame(camera: camera)
        let scale = SIMD2(1 / (tangent * surface.aspectRatio), 1 / tangent)
        return surface.points.compactMap { point -> GaussianProjectedPoint? in
            let delta = SIMD3(point.x, point.y, point.z) - frame.position
            let depth = (delta * frame.forward).sum()
            guard depth.isFinite, depth > nearClip else { return nil }
            let lateral = SIMD2((delta * frame.right).sum(), (delta * frame.up).sum())
            let center = lateral * scale / depth
            // Surface-aligned footprint through the local perspective Jacobian. It is
            // inferred from one depth map, not a trained multi-view 3DGS covariance.
            func axis(_ step: SIMD3<Float>) -> SIMD2<Float> {
                let offset = SIMD2((step * frame.right).sum(), (step * frame.up).sum())
                return (offset - lateral / depth * (step * frame.forward).sum()) * scale / depth
            }
            var axisU = axis(point.tangentU)
            var axisV = axis(point.tangentV)
            let determinant = abs(axisU.x * axisV.y - axisU.y * axisV.x)
            let extent = max(
                (axisU.y * axisU.y + axisV.y * axisV.y).squareRoot(),
                (axisU.x * axisU.x + axisV.x * axisV.x).squareRoot() * surface.aspectRatio
            )
            guard extent.isFinite, extent > 0 else { return nil }
            if extent > maximumSigma {
                axisU *= maximumSigma / extent
                axisV *= maximumSigma / extent
            }
            let sigmaX = (axisU.x * axisU.x + axisV.x * axisV.x).squareRoot()
            let sigmaY = (axisU.y * axisU.y + axisV.y * axisV.y).squareRoot()
            // The rendered quad spans three standard deviations along each axis.
            guard center.x.isFinite, center.y.isFinite,
                  abs(center.x) <= 1 + 3 * (abs(axisU.x) + abs(axisV.x)),
                  abs(center.y) <= 1 + 3 * (abs(axisU.y) + abs(axisV.y))
            else { return nil }
            return GaussianProjectedPoint(
                x: center.x, y: center.y, axisU: axisU, axisV: axisV,
                sigmaX: sigmaX, sigmaY: sigmaY, cameraDepth: depth,
                stretch: determinant / max(point.sourceFootprintArea, 1e-12), point: point
            )
        }.sorted { $0.cameraDepth > $1.cameraDepth }
    }

    /// Far-to-near point indices for a view direction. Camera depth differs from
    /// `dot(point, forward)` only by a per-camera constant, so translation never
    /// changes the order. Ties fall back to the point index, which keeps the order
    /// unique; passing the previous order makes a small re-orientation cheaper to sort.
    /// `previous` must be an earlier result for this surface; other lengths are ignored.
    public static func drawOrder(
        _ surface: GaussianDepthSurface, forward: SIMD3<Float>, reusing previous: [UInt32] = []
    ) -> [UInt32] {
        // Each composite sorts by descending view depth, then ascending index. An integer
        // sort without a comparator closure is several times faster than comparing floats.
        let points = surface.points
        var composites: [UInt64]
        if previous.count == points.count {
            composites = previous.map { index in composite(points[Int(index)], index: index, forward: forward) }
        } else {
            composites = points.indices.map { index in composite(points[index], index: UInt32(index), forward: forward) }
        }
        composites.sort()
        return composites.map { UInt32(truncatingIfNeeded: $0) }
    }

    private static func composite(_ point: GaussianPoint, index: UInt32, forward: SIMD3<Float>) -> UInt64 {
        // Adding zero folds -0 into +0; points are finite, so the bit order matches value order.
        let bits = (point.x * forward.x + point.y * forward.y + point.z * forward.z + 0).bitPattern
        let ascending = bits & 0x8000_0000 == 0 ? bits | 0x8000_0000 : ~bits
        return UInt64(~ascending) << 32 | UInt64(index)
    }
}

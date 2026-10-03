import AVFoundation
import CoreVideo
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let width = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2])! : 320
let height = CommandLine.arguments.count > 3 ? Int(CommandLine.arguments[3])! : 240
let orientation = CommandLine.arguments.count > 4 ? CommandLine.arguments[4] : "rotated"
precondition((48...1920).contains(width) && (48...1920).contains(height))
precondition(width % 2 == 0 && height % 2 == 0)
precondition(orientation == "rotated" || orientation == "unrotated")
let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height
])
input.transform = orientation == "rotated" ? CGAffineTransform(rotationAngle: .pi / 2) : .identity
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
    sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                                 kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height])
writer.add(input)
precondition(writer.startWriting())
writer.startSession(atSourceTime: .zero)
for frame in 0..<30 {
    var optional: CVPixelBuffer?
    precondition(CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &optional) == kCVReturnSuccess)
    let pixel = optional!
    CVPixelBufferLockBaseAddress(pixel, [])
    let base = CVPixelBufferGetBaseAddress(pixel)!.assumingMemoryBound(to: UInt8.self)
    let stride = CVPixelBufferGetBytesPerRow(pixel)
    for y in 0..<height {
        for x in 0..<width {
            let offset = y * stride + x * 4
            base[offset] = UInt8((x / 20 + y / 20) % 2 == 0 ? 220 : 30)
            base[offset + 1] = UInt8(y * 255 / height)
            base[offset + 2] = UInt8(x * 255 / width)
            base[offset + 3] = 255
        }
    }
    CVPixelBufferUnlockBaseAddress(pixel, [])
    var retries = 0
    while !input.isReadyForMoreMediaData {
        usleep(1_000)
        retries += 1
        precondition(retries < 10_000 && writer.status == .writing)
    }
    precondition(adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)))
}
input.markAsFinished()
let semaphore = DispatchSemaphore(value: 0)
writer.finishWriting { semaphore.signal() }
precondition(semaphore.wait(timeout: .now() + 30) == .success)
precondition(writer.status == .completed, "Video encoding failed")
print("PASS: created synthetic \(orientation) \(width)×\(height) MP4")

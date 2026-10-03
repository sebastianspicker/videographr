import Foundation
import Metal

guard let device = MTLCreateSystemDefaultDevice() else { print("SKIP: No Metal device"); exit(2) }
let file = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
guard let start = file.range(of: "#include <metal_stdlib>"),
      let end = file.range(of: "\"\"\"", range: start.upperBound..<file.endIndex) else {
    fatalError("Embedded Metal shader not found")
}
let source = String(file[start.lowerBound..<end.lowerBound])
let library = try device.makeLibrary(source: source, options: nil)
print("PASS: Metal shader compiled on", device.name, library.functionNames)

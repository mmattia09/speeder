import AppKit

// Vector companion to the existing menu-bar spider, rendered at every ICNS size.
let directory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "dist/AppIcon.iconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

func render(pixels: Int) throws -> Data {
    let space = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                            bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let tile = CGPath(roundedRect: CGRect(x: 72, y: 72, width: 880, height: 880), cornerWidth: 196, cornerHeight: 196, transform: nil)
    context.saveGState()
    context.addPath(tile)
    context.clip()
    let colors = [CGColor(red: 0.025, green: 0.19, blue: 0.18, alpha: 1),
                  CGColor(red: 0.10, green: 0.60, blue: 0.48, alpha: 1)]
    let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 220, y: 80), end: CGPoint(x: 750, y: 940), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()
    context.addPath(tile)
    context.setStrokeColor(CGColor(gray: 1, alpha: 0.12))
    context.setLineWidth(3)
    context.strokePath()

    context.setStrokeColor(CGColor(red: 0.88, green: 1, blue: 0.96, alpha: 1))
    context.setFillColor(CGColor(red: 0.88, green: 1, blue: 0.96, alpha: 1))
    context.setLineWidth(32)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    let legs: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (568, 345, 675, 310, 754), (522, 297, 556, 236, 610),
        (464, 303, 431, 244, 380), (410, 354, 340, 327, 266)
    ]
    for side: CGFloat in [-1, 1] {
        for (rootY, kneeX, kneeY, footX, footY) in legs {
            context.move(to: CGPoint(x: 512 + side * 63, y: rootY))
            context.addLine(to: CGPoint(x: 512 + side * (512 - kneeX), y: kneeY))
            context.addLine(to: CGPoint(x: 512 + side * (512 - footX), y: footY))
            context.strokePath()
        }
    }
    context.fillEllipse(in: CGRect(x: 423, y: 320, width: 178, height: 245))
    context.fillEllipse(in: CGRect(x: 446, y: 550, width: 132, height: 139))
    context.setFillColor(CGColor(red: 0.045, green: 0.30, blue: 0.26, alpha: 1))
    for x: CGFloat in [485, 529] { context.fillEllipse(in: CGRect(x: x - 9, y: 634, width: 18, height: 18)) }
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    return bitmap.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        try render(pixels: size * scale).write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}

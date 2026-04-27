#!/usr/bin/env swift
import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "Resources/Insomnia/Insomnia.icns"
let fileManager = FileManager.default
let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("insomnia-app-icon-\(UUID().uuidString)", isDirectory: true)
let iconsetDirectory = temporaryDirectory.appendingPathComponent("Insomnia.iconset", isDirectory: true)

try fileManager.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: temporaryDirectory) }

func drawIcon(size: CGFloat, in context: CGContext) {
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let scale = size / 1024
    let background = NSBezierPath(roundedRect: rect, xRadius: 220 * scale, yRadius: 220 * scale)
    NSColor.white.setFill()
    background.fill()

    context.saveGState()
    context.translateBy(x: rect.midX, y: rect.midY)
    context.rotate(by: .pi / 6)
    context.scaleBy(x: scale, y: scale)

    context.setFillColor(NSColor.black.cgColor)
    let pill = CGPath(
        roundedRect: CGRect(x: -270, y: -105, width: 540, height: 210),
        cornerWidth: 105,
        cornerHeight: 105,
        transform: nil
    )
    context.addPath(pill)
    context.fillPath()

    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: -35, y: -125, width: 70, height: 250))
    context.restoreGState()
}

func writePNG(size: CGFloat, filename: String) throws {
    let pixelSize = Int(size)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "InsomniaIconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render \(filename)"])
    }

    bitmap.size = NSSize(width: pixelSize, height: pixelSize)

    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "InsomniaIconGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create graphics context for \(filename)"])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    defer { NSGraphicsContext.restoreGraphicsState() }

    guard let context = NSGraphicsContext.current?.cgContext else {
        throw NSError(domain: "InsomniaIconGenerator", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to access CGContext for \(filename)"])
    }

    drawIcon(size: size, in: context)

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "InsomniaIconGenerator", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to encode \(filename)"])
    }

    let outputURL = iconsetDirectory.appendingPathComponent(filename)
    try pngData.write(to: outputURL)

    guard let verificationBitmap = NSBitmapImageRep(data: pngData),
          verificationBitmap.pixelsWide == pixelSize,
          verificationBitmap.pixelsHigh == pixelSize else {
        throw NSError(domain: "InsomniaIconGenerator", code: 5, userInfo: [NSLocalizedDescriptionKey: "Generated \(filename) did not match requested \(pixelSize)x\(pixelSize) pixels"])
    }
}

let iconFiles: [(CGFloat, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for iconFile in iconFiles {
    try writePNG(size: iconFile.0, filename: iconFile.1)
}

try fileManager.createDirectory(at: URL(fileURLWithPath: outputPath).deletingLastPathComponent(), withIntermediateDirectories: true)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDirectory.path, "-o", outputPath]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "InsomniaIconGenerator", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}

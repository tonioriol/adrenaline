#!/usr/bin/env swift
import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "Resources/Cocaine/Cocaine.icns"
let fileManager = FileManager.default
let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("cocaine-app-icon-\(UUID().uuidString)", isDirectory: true)
let iconsetDirectory = temporaryDirectory.appendingPathComponent("Cocaine.iconset", isDirectory: true)

try fileManager.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: temporaryDirectory) }

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    guard let context = NSGraphicsContext.current?.cgContext else { return image }
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.225
    let background = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.055, dy: size * 0.055), xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.99, alpha: 1.0).setFill()
    background.fill()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = size * 0.035
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.018)
    shadow.set()

    context.saveGState()
    context.translateBy(x: rect.midX, y: rect.midY)
    context.rotate(by: .pi / 6)

    let pillWidth = size * 0.58
    let pillHeight = size * 0.285
    let pillRect = CGRect(x: -pillWidth / 2, y: -pillHeight / 2, width: pillWidth, height: pillHeight)
    let pillPath = CGPath(roundedRect: pillRect, cornerWidth: pillHeight / 2, cornerHeight: pillHeight / 2, transform: nil)

    context.addPath(pillPath)
    context.setFillColor(NSColor(calibratedRed: 0.07, green: 0.075, blue: 0.085, alpha: 1.0).cgColor)
    context.fillPath()

    context.setBlendMode(.clear)
    context.fill(CGRect(x: -size * 0.042, y: pillRect.minY - size * 0.05, width: size * 0.084, height: pillHeight + size * 0.10))
    context.restoreGState()

    return image
}

func writePNG(size: CGFloat, filename: String) throws {
    let image = drawIcon(size: size)
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "CocaineIconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render \(filename)"])
    }
    try pngData.write(to: iconsetDirectory.appendingPathComponent(filename))
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
    throw NSError(domain: "CocaineIconGenerator", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}

# Capsule App Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a macOS app bundle icon that uses the current diagonal capsule menu bar motif in a proper rounded-square app icon.

**Architecture:** Generate a checked-in `Resources/Cocaine/Cocaine.icns` from a small Swift/AppKit icon generator so the icon is reproducible without Xcode asset catalogs. Declare the icon in `Resources/Cocaine/Info.plist` and update `Makefile` to copy it into `build/Cocaine.app/Contents/Resources` before signing.

**Tech Stack:** Swift 5.9, AppKit/CoreGraphics image drawing, `iconutil`, `sips`, SwiftPM, Makefile, macOS app bundle `Info.plist` metadata.

---

## File Structure

- Create `Scripts/generate-app-icon.swift` — reproducible one-off Swift/AppKit generator for the capsule app icon `.icns`.
- Create `Resources/Cocaine/Cocaine.icns` — generated app bundle icon consumed by macOS.
- Modify `Resources/Cocaine/Info.plist` — add `CFBundleIconFile` pointing at the icon resource.
- Modify `Makefile` — create `Contents/Resources`, copy `Cocaine.icns`, and add a `generate-app-icon` helper target.
- Update `docs/feat/20260426163053-app-icon-capsule/context.md` — track implementation files and plan cursor.

## Task 1: Add reproducible capsule icon generator

**Files:**
- Create: `Scripts/generate-app-icon.swift`

- [x] **Step 1: Create the generator file**

Create `Scripts/generate-app-icon.swift` with this exact content:

```swift
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
```

- [x] **Step 2: Run the generator manually**

Run:

```bash
swift Scripts/generate-app-icon.swift Resources/Cocaine/Cocaine.icns
```

Expected: command exits 0 and creates `Resources/Cocaine/Cocaine.icns`.

- [x] **Step 3: Inspect generated icon metadata**

Run:

```bash
sips -g pixelWidth -g pixelHeight Resources/Cocaine/Cocaine.icns
```

Expected: command exits 0 and reports icon dimensions without an error.

- [x] **Step 4: Commit generator and icon**

Run:

```bash
git add Scripts/generate-app-icon.swift Resources/Cocaine/Cocaine.icns
git -c commit.gpgsign=false commit -m "build: add capsule app icon asset"
```

Expected: commit succeeds.

## Task 2: Wire icon into app bundle metadata and packaging

**Files:**
- Modify: `Resources/Cocaine/Info.plist`
- Modify: `Makefile`

- [ ] **Step 1: Add the bundle icon declaration**

In `Resources/Cocaine/Info.plist`, insert this key/value pair after `CFBundleExecutable`:

```xml
  <key>CFBundleIconFile</key>
  <string>Cocaine</string>
```

- [ ] **Step 2: Update Makefile resource packaging**

Change the directory variables and `app` target in `Makefile` so it contains these lines:

```makefile
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
```

and the `app` recipe creates/copies resources like this:

```makefile
app: build
	rm -rf $(APP_DIR)
	mkdir -p $(MACOS_DIR) $(LAUNCH_SERVICES_DIR) $(RESOURCES_DIR)
	cp Resources/Cocaine/Info.plist $(CONTENTS_DIR)/Info.plist
	cp Resources/Cocaine/Cocaine.icns $(RESOURCES_DIR)/Cocaine.icns
	cp $(SWIFT_BIN_DIR)/Cocaine $(MACOS_DIR)/Cocaine
	cp $(SWIFT_BIN_DIR)/CocaineHelper $(LAUNCH_SERVICES_DIR)/com.tr0n.Cocaine.Helper
	$(MAKE) sign
```

- [ ] **Step 3: Add a generator target**

Update `.PHONY` and add this target to `Makefile`:

```makefile
.PHONY: test build generate-app-icon app sign reinstall run clean verify-helper-sections

generate-app-icon:
	swift Scripts/generate-app-icon.swift Resources/Cocaine/Cocaine.icns
```

- [ ] **Step 4: Verify the generator target**

Run:

```bash
make generate-app-icon
```

Expected: command exits 0 and refreshes `Resources/Cocaine/Cocaine.icns`.

- [ ] **Step 5: Commit metadata and packaging**

Run:

```bash
git add Resources/Cocaine/Info.plist Makefile Resources/Cocaine/Cocaine.icns
git -c commit.gpgsign=false commit -m "build: package capsule app icon"
```

Expected: commit succeeds.

## Task 3: Verify bundle output

**Files:**
- Verify: `build/Cocaine.app/Contents/Info.plist`
- Verify: `build/Cocaine.app/Contents/Resources/Cocaine.icns`

- [ ] **Step 1: Run tests**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 2: Build the app bundle**

Run:

```bash
make app
```

Expected: PASS and `build/Cocaine.app` exists.

- [ ] **Step 3: Verify icon file is in the bundle**

Run:

```bash
test -f build/Cocaine.app/Contents/Resources/Cocaine.icns && echo "icon copied"
```

Expected: prints `icon copied`.

- [ ] **Step 4: Verify icon metadata is in the built plist**

Run:

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' build/Cocaine.app/Contents/Info.plist
```

Expected: prints `Cocaine`.

- [ ] **Step 5: Commit final verification updates if any**

Run:

```bash
git status --short
```

Expected: no uncommitted implementation changes except generated build outputs ignored by `.gitignore`.

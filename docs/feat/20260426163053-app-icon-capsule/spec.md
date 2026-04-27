# Capsule App Icon Spec

## Summary

Use the existing capsule/pill menu bar icon as the visual basis for the whole macOS app icon. The app should keep running as a menu-bar-only accessory app, but Finder, Launch Services, app metadata, and any system surfaces that display the app bundle icon should show a proper macOS-style icon derived from the same capsule shape.

## Goals

- Create a macOS app bundle icon that clearly matches the current capsule status-item icon.
- Package the icon in the SwiftPM-built `.app` bundle so macOS recognizes it as the app icon.
- Keep the status-item rendering behavior unchanged unless a small shared drawing helper is useful.
- Keep the build process simple and reproducible from the existing `Makefile` workflow.

## Non-Goals

- Do not introduce a full Xcode asset catalog unless the simple `.icns` path proves insufficient.
- Do not change the app from menu-bar-only/accessory behavior.
- Do not redesign the menu bar status states, click behavior, or preferences menu.

## Design

### Icon asset

Add a generated `Insomnia.icns` under `Resources/Insomnia/`. The icon composition should adapt the current diagonal split-capsule shape into a conventional macOS app icon:

- rounded-square background suitable for Finder/Launch Services surfaces;
- centered, enlarged capsule/pill mark using the same diagonal orientation and split motif as the status item;
- simple visual treatment only, avoiding detailed illustration or new branding concepts.

The generated `.icns` should include the standard macOS icon representations produced from a high-resolution source, so it remains crisp at common sizes.

### Bundle metadata

Update `Resources/Insomnia/Info.plist` to declare `CFBundleIconFile` for the app icon. The declared icon filename should match the resource copied into `Contents/Resources` during bundling.

### Packaging

Update `Makefile` so the `app` target creates `Contents/Resources` and copies the `.icns` file into the app bundle before signing. The existing code signing flow remains unchanged.

## Alternatives Considered

### Recommended: bundled `.icns`

This is the best fit for the current SwiftPM/Makefile app bundle. It is simple, works with `Info.plist`, and avoids adding Xcode-only asset catalog steps.

### Asset catalog

An asset catalog would be conventional in an Xcode app, but this project builds bundles manually from SwiftPM. Adding asset compilation would add tooling complexity without clear benefit for a single icon.

### Runtime-only app icon

Setting `NSApplication.shared.applicationIconImage` at runtime would not fully solve Finder/Launch Services bundle icon display, so it is insufficient for the requested whole-app icon.

## Testing

- Run the app bundle build path and verify `build/Insomnia.app/Contents/Resources/Insomnia.icns` exists.
- Verify `build/Insomnia.app/Contents/Info.plist` contains the icon declaration.
- Run the existing test/build commands used by the project (`swift test` and `make app`) to ensure no regressions.

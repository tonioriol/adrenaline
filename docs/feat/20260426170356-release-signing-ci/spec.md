# Release Signing CI Spec

## Goal

Prepare Cocaine for public GitHub release artifacts by removing personal-use wording and adding a minimal GitHub Actions workflow that builds, signs, notarizes, staples, and uploads a macOS app zip when a version tag is pushed.

## Scope

- Remove wording that frames the app as personal-only from user-facing docs and existing project docs.
- Add one tag-triggered GitHub Actions workflow for notarized macOS release artifacts.
- Keep packaging as a zip of `Cocaine.app`; do not add DMG generation.
- Keep the implementation small: no separate release script unless the workflow becomes unreadable.

## Release Trigger

The release workflow runs on tags matching `v*`, such as `v0.1.0`. Normal pushes and pull requests should not import signing credentials or run notarization.

## Signing and Notarization

The workflow will use GitHub Actions secrets for all sensitive material:

- `APPLE_DEVELOPER_ID_CERTIFICATE_BASE64`: base64-encoded Developer ID Application `.p12` certificate.
- `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD`: password for the `.p12` certificate.
- `APPLE_NOTARYTOOL_PROFILE`: keychain profile name used by `xcrun notarytool`.
- `APPLE_ID`: Apple ID used for notarization profile setup.
- `APPLE_TEAM_ID`: Apple Developer Team ID.
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for notarization profile setup.

The workflow will create a temporary keychain, import the certificate, configure `notarytool`, build `CONFIGURATION=release`, sign the helper first, sign the app, zip the app for notarization, submit and wait, staple the app, then create the final release zip.

## Code Signing Requirements

The app and privileged helper already use explicit signing requirement strings for the `SMJobBless` trust boundary. The implementation should update those strings from the current Apple Development certificate wording to Developer ID wording, and keep these locations consistent:

- `Sources/CocaineCore/CocaineHelperProtocol.swift`
- `Resources/Cocaine/Info.plist`
- `Resources/CocaineHelper/Info.plist`
- `Tests/CocaineCoreTests/CocaineHelperConstantsTests.swift`

The expected requirement shape should use the bundle identifier plus Developer ID Application certificate constraints for the configured Team ID. Tests should assert the source constants and plist values stay aligned.

## Documentation

`README.md` should describe the app without calling it personal-only and should include a short release section listing required GitHub secrets and the tag-based release trigger. `NOTICE.md` should retain attribution while removing personal-use wording. Archived project docs can be cleaned where they contain the requested wording.

## Testing

- Run text search to confirm personal-use wording was removed.
- Run `swift test`.
- Run `make app CONFIGURATION=release` locally with the available signing identity when possible.
- Validate workflow YAML syntax by inspection and by relying on GitHub Actions execution on tag push.

## Non-goals

- No DMG packaging.
- No Sparkle updates.
- No Homebrew cask.
- No App Store distribution.
- No broad release-management framework.

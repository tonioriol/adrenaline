# Cocaine macOS Keep-Awake App Spec

## Summary

Build `Cocaine`, a personal macOS menu bar app at `/Users/tr0n/Code/cocaine`. It should behave like the simplest useful version of Caffeine: one visible menu bar icon, one click to turn on, one click to turn off. When on, it prevents normal idle/display sleep and also prevents sleep when the MacBook lid is closed. When off, it restores all normal sleep behavior.

The app will be a clean Swift/SwiftUI reimplementation. Caffeine and Fermata are references for behavior and platform mechanisms, not bases to fork wholesale.

## Goals

- Provide one primary user interaction: click the menu bar icon to toggle off/on.
- In the on state, prevent ordinary idle/display sleep using public IOKit power assertions.
- In the on state, prevent lid-close sleep using a privileged helper/admin-authorized mechanism modeled after Fermata.
- In the off state, release all ordinary sleep assertions and restore normal lid-close sleep.
- Keep the visible product name `Cocaine` for personal use.
- Keep the codebase small and understandable, with focused services instead of a large app-delegate controller.
- Include attribution/license material for upstream behavioral references where code or patterns are reused.

## Non-goals

- No duration menu in the initial version.
- No app-specific rules in the initial version.
- No advanced lid-close automation in the initial version.
- No separate controls for ordinary sleep prevention versus lid-close prevention.
- No public distribution, App Store packaging, or notarization workflow in the initial version.
- No kernel extensions.

## User Experience

### Menu bar icon

The app runs as an accessory/menu bar app with no Dock icon. The menu bar icon has two states:

- Off: inactive icon, normal macOS sleep behavior.
- On: active icon, ordinary sleep and lid-close sleep are prevented.

A left click toggles the state immediately:

- Off to on: enable both ordinary sleep prevention and lid-close sleep prevention.
- On to off: disable both ordinary sleep prevention and lid-close sleep prevention.

### Minimal menu

The primary UI is the click toggle. A secondary menu may exist only for app lifecycle and recovery items:

- About Cocaine
- Repair/Install Helper, shown or enabled only when helper setup fails or needs reinstallation
- Quit

Feature controls do not live in the secondary menu for v1.

### First activation

On the first off-to-on toggle, if the privileged helper is not installed or not current, the app prompts for admin authorization to install or update it. If helper setup succeeds, the app continues enabling the on state. If helper setup fails or is cancelled, the app must not pretend lid-close prevention is active.

## Architecture

Use a small Swift/SwiftUI app target plus a privileged helper target.

### App target

The app target owns UI, state, normal IOKit assertions, and XPC communication with the helper.

Recommended components:

- `CocaineApp`: SwiftUI app entry point.
- `AppDelegate`: small bridge for menu bar app lifecycle and accessory activation policy.
- `MenuBarController`: owns `NSStatusItem`, click handling, icon updates, and minimal menu.
- `AppState`: observable state containing whether the app is off/on, helper status, and the most recent error.
- `AwakeController`: owns ordinary IOKit assertions for idle/display sleep prevention.
- `LidCloseController`: coordinates desired lid-close state and validates actual helper state.
- `PrivilegedHelperClient`: installs/verifies/connects to the helper and sends enable/disable/status commands.

The UI talks to `AppState`/coordinator-level methods only. UI code does not call IOKit or XPC directly.

### Privileged helper target

The helper is a small privileged XPC service installed through Apple’s blessed-helper mechanism. It exposes a minimal protocol:

- `enableLidClosePrevention(reply:)`
- `disableLidClosePrevention(reply:)`
- `readLidClosePreventionStatus(reply:)`
- `helperVersion(reply:)`

Internally, the helper performs the privileged power setting change needed for lid-close prevention and returns success/failure to the app.

## State Model

The app has one user-facing feature state:

- `off`
- `on`

It also tracks helper state separately because helper setup can fail independently of the UI request:

- `unknown`
- `notInstalled`
- `installing`
- `ready(version)`
- `failed(error)`

The app is considered truly on only after both ordinary assertions and helper lid-close prevention succeed. If ordinary assertions succeed but helper activation fails, the app should show an error state and either roll back to off or show a distinct failed icon. The default behavior should be rollback to off, because a simple toggle should not mislead the user.

## On/Off Flow

### Turn on

1. User clicks inactive icon.
2. Coordinator asks `PrivilegedHelperClient` to verify or install the helper.
3. If helper verification fails or authorization is cancelled, state remains off and the error is recorded.
4. `AwakeController` creates ordinary idle/display sleep assertions.
5. `LidCloseController` asks helper to enable lid-close prevention.
6. `LidCloseController` reads helper status back.
7. If both ordinary and lid-close prevention are active, state becomes on and icon changes active.
8. If any step fails after partial activation, the app releases ordinary assertions, asks the helper to disable lid-close prevention, records the error, and returns to off.

### Turn off

1. User clicks active icon.
2. `AwakeController` releases ordinary sleep assertions.
3. `LidCloseController` asks helper to disable lid-close prevention.
4. The app reads helper status back.
5. State becomes off even if cleanup reports an error, but the error is recorded and the helper repair item becomes available.

### Quit

On quit, the app must attempt the same cleanup as turning off before terminating. Normal sleep behavior should be restored even if the app was active.

## Error Handling and Safety

- Never show the active icon unless both ordinary sleep prevention and lid-close prevention are active.
- If admin authorization is cancelled, leave the app off.
- If helper install fails, leave the app off and expose a repair/install helper action.
- If helper communication fails while on, attempt cleanup and return to off.
- If disabling lid-close prevention fails, record the error and expose helper repair, because leaving lid-close sleep disabled is a safety risk.
- Include clear warning text in the helper authorization/recovery flow: preventing lid-close sleep can leave a closed MacBook running and may cause overheating if placed in a bag.
- Do not use kernel extensions.

## Implementation Notes from Upstreams

Caffeine reference findings:

- Small Swift/SwiftUI menu bar app.
- Uses public IOKit assertions for idle/display prevention.
- Simple status item click behavior is the desired UX reference.

Fermata reference findings:

- Lid-close prevention requires privileged behavior beyond normal user-level assertions.
- Uses a blessed helper and XPC communication.
- Sets the private `SleepDisabled` power setting through IOKit private SPI.
- Restores lid-close sleep on quit.

The new app should not copy either app’s high-level structure. It should only reuse narrow, necessary platform patterns with attribution where appropriate.

## Testing Strategy

### Unit-level tests where practical

- State transition tests for off-to-on success.
- State transition tests for helper install cancellation.
- State transition tests for helper activation failure rollback.
- State transition tests for cleanup on off and quit.

### Manual/system tests

- Build and launch app.
- Confirm no Dock icon appears.
- Confirm clicking icon toggles off/on.
- Confirm on state appears only after helper authorization/activation succeeds.
- Confirm off state releases ordinary assertions.
- Confirm off state restores normal lid-close behavior.
- Confirm quitting while on restores normal lid-close behavior.
- Confirm helper repair path appears after simulated helper failure.

## Risks

- The lid-close mechanism depends on private/unsupported power-management behavior and may break on macOS updates.
- Privileged helper signing and authorization are the most complex implementation area.
- Testing true lid-close sleep behavior may require manual validation on MacBook hardware.
- Because this is for personal use, public naming/distribution concerns are intentionally out of scope for v1.

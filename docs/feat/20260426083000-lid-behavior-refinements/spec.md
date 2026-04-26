# Lid Behavior Refinements Spec

## Summary

Refine Cocaine's right-click menu and lid/display behavior after real-use feedback on the first lid-behavior settings release.

The app's core feature remains unchanged: when Cocaine is ON, it prevents system sleep and keeps the computer awake. This work improves the preference menu UX, removes the confusing forced lock-screen feature, couples lid sounds to lid-close prevention, removes the helper repair item, skips disk-sleep controls, and adds a Launch at Login checkbox.

## Goals

- Keep Cocaine's main ON behavior as the global system-awake toggle.
- Keep **Prevent display sleep** as the visible label and behavior.
- Keep **Prevent sleep with lid closed** as an opt-in helper-backed setting with the existing first-enable safety warning.
- Make **Play lid event sounds** apply only when **Prevent sleep with lid closed** is enabled.
- Keep the right-click menu open while toggling checkbox preferences.
- Remove **Lock screen when lid closes** because macOS already locks when normal lid-close sleep is allowed and configured in system settings.
- Remove **Repair / Install Helper** from the menu.
- Add **Launch at login**, default OFF, backed by the actual macOS login-item state.
- Do not add a disk-sleep setting.

## Non-goals

- Do not remove or weaken Cocaine's core system-sleep prevention.
- Do not add a standalone lock-screen checkbox.
- Do not force-lock the screen via private APIs.
- Do not expose disk-sleep prevention.
- Do not replace the menu with a separate Preferences window.
- Do not replace the menu with a popover.

## User-Facing Behavior

### Main ON/OFF toggle

Left-clicking the menu bar icon still toggles Cocaine OFF/ON.

When ON, Cocaine always prevents system sleep. The computer stays awake unless the user explicitly allows a macOS path that still sleeps the system, such as closing the lid while **Prevent sleep with lid closed** is OFF.

### Right-click menu

The right-click menu keeps its menu shape but preference rows use custom checkbox views so simple preference toggles do not dismiss the menu.

Target order:

1. About Cocaine
2. separator
3. **Prevent display sleep** checkbox
4. **⚠ Prevent sleep with lid closed** checkbox
5. **Play lid event sounds** checkbox
6. **Launch at login** checkbox
7. separator
8. Quit

Removed rows:

- **Lock screen when lid closes**
- **Repair / Install Helper**

### Preference semantics

| Preference | Default | Meaning |
|---|---:|---|
| **Prevent display sleep** | ON | While Cocaine is ON, also hold a display-sleep assertion so the screen stays awake. If OFF, Cocaine still keeps the computer awake, but the display may sleep and macOS lock-screen settings may apply. |
| **⚠ Prevent sleep with lid closed** | OFF | While Cocaine is ON, use the privileged helper so the computer stays awake even after the lid closes. Existing first-enable warning remains. |
| **Play lid event sounds** | ON | While Cocaine is ON, play close/open sounds only if **Prevent sleep with lid closed** is also ON. The menu row is visible but disabled when lid-close prevention is OFF. |
| **Launch at login** | OFF | Register/unregister Cocaine as a macOS login item. The checkbox reflects `SMAppService.mainApp.status`, not only an internal preference. |

### Locking behavior

Cocaine no longer provides a separate lock-screen preference.

If **Prevent sleep with lid closed** is OFF, closing the lid follows normal macOS behavior. macOS may sleep and lock according to the user's system settings.

If **Prevent display sleep** is OFF, display sleep may occur while Cocaine keeps the computer awake. macOS may lock according to the user's system settings.

Cocaine does not force-lock via private API or AppleScript fallback.

### Disk sleep

No disk-sleep setting is added. Modern SSD Macs make disk-idle prevention effectively pointless for this app's intended behavior. Cocaine's core no-idle sleep assertion is sufficient to keep work running.

## Architecture

### PreferencesStore

Keep the existing display preference name and default:

- `preventDisplaySleep`: default `true`
- `preventLidCloseSleep`: default `false`
- `playLidEventSounds`: default `true`
- `lidClosePreventionConfirmed`: existing first-enable warning state

Remove the lock-screen preference from active behavior and menu UI:

- `lockScreenOnLidClose` should no longer appear in the menu.
- Implementation may remove this persisted preference entirely, or leave the old key unread as harmless migration residue. New code should not depend on it.

### AppCoordinator

The coordinator keeps current core behavior:

- Turning ON always enables no-idle/system awake prevention.
- Turning ON enables display-sleep prevention only when `preventDisplaySleep == true`.
- Turning ON enables the lid-close helper only when `preventLidCloseSleep == true`.
- Live display toggles still reconcile only the display assertion.
- Live lid-close toggles still reconcile only the helper.

Remove any coordinator dependency on lock-screen behavior.

### Lid event sounds

`LidEventSoundController` must gate sound playback on all of these conditions:

- Cocaine is active.
- Monitoring is started.
- The lid state is not a duplicate of the last handled state.
- `playLidEventSounds == true`.
- `preventLidCloseSleep == true`.

The duplicate-state suppression should remain ahead of sound playback so muted or disabled duplicate events do not replay later.

### Lock-screen components

Remove the active lock-screen feature:

- Unwire `LidCloseLockResponder` from `AppDelegate`.
- Remove `LoginFrameworkScreenLocker` / `ScreenLocker` usage.
- Prefer deleting `LidCloseLockResponder`, `ScreenLocker`, and their tests because no current feature uses them.

### Menu checkbox rows

Use custom `NSMenuItem.view` rows for preference checkboxes.

Requirements:

- Clicking a checkbox preference toggles it without dismissing the menu.
- Checkbox rows refresh their state after toggles.
- **Play lid event sounds** remains visible but disabled while `preventLidCloseSleep == false`.
- Normal menu items, such as About and Quit, keep normal menu behavior.
- The existing first-enable warning for **Prevent sleep with lid closed** remains. That alert may temporarily interrupt normal menu interaction.

### Launch at login

Add an app-target abstraction around `SMAppService.mainApp`.

Responsibilities:

- Report whether Launch at Login is enabled from actual system state.
- Register the app when the checkbox is turned ON.
- Unregister the app when the checkbox is turned OFF.
- Refresh visible checkbox state after register/unregister so the menu reflects the system truth.

Default is OFF because Cocaine should not add itself to login items without explicit user intent.

## Error Handling

### Lid-close helper errors

Helper setup or communication failures still use the existing app error state because they affect an active keep-awake behavior.

With **Repair / Install Helper** removed, the retry path is to toggle **Prevent sleep with lid closed** again, restart the app, or reinstall the app if needed.

### Launch-at-login errors

Launch-at-login failures should not put the main menu bar icon into a keep-awake error state. Login-item registration is ancillary and does not mean Cocaine's active sleep-prevention behavior failed.

Prefer showing the error locally in the menu, refreshing the checkbox from actual system state, or both.

### Checkbox menu behavior

Checkbox row failures should refresh from source-of-truth state instead of leaving a misleading checked state.

## Testing Strategy

### Unit tests

- `PreferencesStore` still defaults `preventDisplaySleep` to true and `preventLidCloseSleep` to false.
- `LidEventSoundController` plays sounds only when `playLidEventSounds == true` and `preventLidCloseSleep == true`.
- `LidEventSoundController` ignores lid events when lid-close prevention is OFF, even if sounds are enabled.
- Duplicate lid-state suppression still prevents replay after sound gating changes.
- `AppCoordinator` continues to enable no-idle sleep prevention whenever Cocaine turns ON.
- `AppCoordinator` continues to reconcile display-sleep prevention independently.
- `AppCoordinator` continues to reconcile lid-close helper state independently.
- Launch-at-login controller tests cover enabled/disabled status, register, unregister, and failure refresh semantics using a fake service.

### UI-adjacent tests

- Menu construction does not include **Lock screen when lid closes**.
- Menu construction does not include **Repair / Install Helper**.
- Menu construction includes **Launch at login**.
- **Play lid event sounds** row is disabled when lid-close prevention is OFF.
- Preference row actions update state without relying on normal `NSMenuItem` dismissal semantics.

### Verification

Run:

```bash
make test
make app
```

Manual checks:

1. Right-click menu opens.
2. Toggle multiple preference checkboxes; menu stays open.
3. **Play lid event sounds** is visible but disabled when **Prevent sleep with lid closed** is OFF.
4. **Lock screen when lid closes** is absent.
5. **Repair / Install Helper** is absent.
6. **Launch at login** reflects macOS login-item state.
7. Turning Cocaine ON still prevents system sleep.
8. Turning **Prevent display sleep** OFF allows display sleep while Cocaine stays ON.
9. Turning **Prevent sleep with lid closed** ON still shows the existing warning and keeps the computer awake when the lid closes.

## Risks

- Custom `NSMenuItem.view` rows need careful sizing and refreshing to feel native.
- `SMAppService` status can be affected outside the app through System Settings, so the menu must refresh from system truth when opened.
- Removing the forced lock-screen feature is correct for this design, but documentation should explain that macOS native lock settings own locking.
- The absence of **Repair / Install Helper** means helper failures need clear error text and a reasonable retry path.

## Rejected Alternatives

- **Separate Preferences window:** rejected because the user wants inline right-click settings.
- **Popover settings panel:** rejected as heavier than necessary and less menu-native.
- **Standalone lock-screen checkbox:** rejected because native macOS lock behavior already applies when display/lid sleep is allowed.
- **Disk sleep checkbox:** rejected because SSD Macs make it meaningless for the app's core purpose.
- **Keeping Repair / Install Helper:** rejected as confusing and not useful in normal operation.

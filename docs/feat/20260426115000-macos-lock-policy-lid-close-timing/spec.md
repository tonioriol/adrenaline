# Respect macOS Lock Policy for Lid-Close Timing

## Summary

Cocaine should stop treating lid-close locking as an immediate custom security action. When Cocaine keeps the Mac awake with the lid closed, it should mirror what macOS would have done if native display sleep were allowed to complete.

The behavior should be simple and predictable:

- If macOS **Require password** is **Never**, Cocaine does not lock on lid close.
- If macOS would require a password, Cocaine waits for the effective macOS timing before locking: the current power source's display-off timer plus the Require Password delay.
- If the lid opens before that delay completes, Cocaine cancels the pending lock.

This keeps Cocaine layered on top of macOS settings instead of creating a separate lock policy.

## Goals

- Respect **Require password = Never** by never force-locking on lid close in that configuration.
- Match macOS lock timing when Require Password is enabled.
- Use the display-off timer for the current power source: battery timer while on battery, AC timer while on power.
- Include the macOS Require Password delay, not only the display-off timer.
- Preserve the existing computed lock matrix: Cocaine only fills the lid-close lock gap when it is active, lid-close sleep prevention is enabled, and display sleep prevention is off.
- Keep the feature invisible in the menu. There should be no standalone lock checkbox.
- Keep lock failures best-effort and non-fatal.

## Non-Goals

- Do not add a new user-facing Cocaine lock setting.
- Do not change Cocaine's display-sleep or lid-close sleep-prevention preferences.
- Do not change the privileged helper's `SleepDisabled` responsibility unless implementation discovery proves it is necessary.
- Do not attempt to reproduce macOS screensaver visuals with the lid closed.
- Do not block app shutdown, Cocaine off, or lid reopening on a pending lock timer.

## User-Facing Behavior

When Cocaine is off, nothing changes. macOS owns all sleep, display, screensaver, and lock behavior.

When Cocaine is on but **Prevent system sleep with lid closed** is off, closing the lid follows native macOS behavior. Cocaine does not run a lid-close lock timer.

When Cocaine is on, **Prevent system sleep with lid closed** is on, and **Prevent display sleep** is on, Cocaine still does not lock on lid close. Display sleep is being intentionally suppressed, so the native idle display/screen saver trigger is also intentionally suppressed.

When Cocaine is on, **Prevent system sleep with lid closed** is on, and **Prevent display sleep** is off:

1. Closing the lid reads the current macOS lock/display policy.
2. If Require Password is Never, Cocaine leaves the session unlocked.
3. If Require Password is enabled, Cocaine schedules a lock for:

   ```text
   current-power-source display-off timer + Require Password delay
   ```

4. If the lid reopens before the scheduled time, the scheduled lock is cancelled.
5. If the scheduled time arrives while Cocaine is still active and the lid is still closed under the same gating conditions, Cocaine locks the screen.

Example using the settings from the prompt:

- Battery display-off timer: 1 minute
- AC display-off timer: 5 minutes
- Require Password: Immediately

Expected lid-close lock timing:

- On battery: lock after 1 minute.
- On AC power: lock after 5 minutes.
- If Require Password is changed to Never: do not lock.

If Require Password were set to 5 seconds instead of Immediately, Cocaine would lock after 1 minute 5 seconds on battery and 5 minutes 5 seconds on AC power.

## Architecture

### `MacOSLockPolicyReader`

Add a focused reader in `CocaineCore` that returns a snapshot of the macOS policy needed by lid-close locking.

Suggested public shape:

```swift
public struct MacOSLockPolicy: Equatable, Sendable {
    public var requiresPassword: Bool
    public var displaySleepDelay: TimeInterval
    public var passwordDelay: TimeInterval

    public var lockDelay: TimeInterval? {
        requiresPassword ? displaySleepDelay + passwordDelay : nil
    }
}

@MainActor
public protocol MacOSLockPolicyReading: AnyObject {
    func currentPolicy() throws -> MacOSLockPolicy
}
```

Implementation responsibilities:

- Read `askForPassword` from `com.apple.screensaver`.
- Treat missing, false, or zero `askForPassword` as Require Password disabled.
- Read `askForPasswordDelay` from `com.apple.screensaver` as seconds, defaulting to `0` if missing or invalid.
- Read the current power source.
- Read the matching display-off timer in minutes.
- Convert the display-off timer to seconds.

Power-setting source preference:

1. Prefer native Foundation / IOKit reads from system configuration, because this keeps the implementation testable and avoids parsing command output.
2. Do not shell out to `pmset` / `defaults` in production unless direct reads prove unavailable during implementation.
3. If implementation must fall back to shell commands, isolate that behind the same `MacOSLockPolicyReading` protocol so `LidCloseLockResponder` remains unchanged and tests remain deterministic.

### Current Power Source

The reader needs to decide between battery and AC display timers at the moment the lid closes. Use IOKit power-source APIs when possible. AC/charger/UPS-like external power should use the AC timer; internal battery should use the battery timer.

If the current source cannot be determined, fall back to the battery timer as the safer shorter delay when available. If only one display timer can be read, use that one.

### Display-Off Timer Semantics

Use the macOS **Display Sleep Timer** / `displaysleep` value for the active power source.

If the display-off timer is `0`, treat display sleep as disabled for this purpose and do not schedule a lock. This mirrors macOS: if there is no display sleep/screensaver trigger, Require Password does not fire from display sleep.

If the timer cannot be read, fail closed for surprise-minimization by not scheduling a Cocaine lock and log the policy-read failure. Do not lock immediately as a fallback.

### Password Delay Semantics

Use `askForPasswordDelay` as seconds.

- `0` means immediately after display sleep/screensaver begins, so the lid-close lock delay is just the display-off timer.
- Positive values are added to the display-off timer.
- Negative or non-numeric values are treated as `0`.

### `LidCloseLockResponder`

Refactor the responder from immediate lock to delayed lock scheduling.

The responder keeps the existing event-chaining behavior so lid sounds still receive the same events.

New behavior:

- On lid close:
  - Cancel any existing pending lock.
  - Check existing gates: `state.isActive`, `preferences.preventLidCloseSleep`, and `!preferences.preventDisplaySleep`.
  - Read the current macOS lock policy.
  - If `lockDelay == nil`, do nothing.
  - If `lockDelay` is present, create a cancellable `Task` that sleeps for that duration and then rechecks the gates before calling `ScreenLocking.lock()`.
- On lid open:
  - Cancel any pending lock.
- On deinit:
  - Cancel any pending lock.

The delayed task must recheck, at minimum:

- Cocaine is still active.
- The lid is still closed.
- Lid-close sleep prevention is still enabled.
- Display sleep prevention is still off.

If these checks fail, the task exits without locking.

Preference changes should not require a separate observer for this first version. Rechecking at fire time is enough for safety: turning display prevention on, turning lid-close prevention off, or turning Cocaine off prevents the delayed lock from firing. Lid reopen cancels promptly from the lid event.

### App Wiring

`AppDelegate` should construct the policy reader and inject it into `LidCloseLockResponder` alongside `ScreenLocker`.

Construction order still matters: the lid event sound controller should be attached before the lock responder so the responder preserves and forwards the existing lid callback.

### Logging and Errors

Policy-read failures and lock failures are best-effort operational details.

- Log policy-read failures via `os_log`.
- Log lock failures via the existing lock failure path.
- Do not show a menu-bar error for these failures.
- Do not change Cocaine active/inactive state when a lock cannot be scheduled or executed.

## Testing

### Unit Tests

Extend or replace `LidCloseLockResponderTests` to cover delayed behavior using fakes.

Required responder tests:

- Inactive state does not read policy or schedule a lock.
- Lid-close prevention off does not read policy or schedule a lock.
- Display sleep prevention on does not read policy or schedule a lock.
- Require Password disabled returns `lockDelay == nil` and does not lock.
- Require Password enabled schedules exactly one lock after the supplied delay.
- Lid open before the delay cancels the lock.
- Turning Cocaine inactive before the delay completes prevents locking.
- Turning display prevention on before the delay completes prevents locking.
- Turning lid-close prevention off before the delay completes prevents locking.
- Existing lid-state callback still runs before responder handling.
- Lock errors do not crash and do not mutate app state.

Required policy-reader tests:

- `askForPassword = 0` produces `lockDelay == nil`.
- Missing `askForPassword` produces `lockDelay == nil`.
- `askForPassword = 1`, display timer 1 minute, password delay 0 seconds produces 60 seconds.
- `askForPassword = 1`, display timer 5 minutes, password delay 5 seconds produces 305 seconds.
- Battery power uses the battery display timer.
- AC power uses the AC display timer.
- Display timer `0` produces `lockDelay == nil`.
- Invalid password delay is treated as `0`.
- Unreadable display timers produce no lock delay rather than immediate lock.

Tests should avoid waiting real minutes. Inject a sleep/timer abstraction or make the delayed task use a test scheduler/clock so tests can advance time deterministically.

### Manual Verification

Manual checks on a MacBook:

1. Set Require Password to Never, turn Cocaine on, enable lid-close prevention, allow display sleep, close and reopen after longer than the display-off timer: session is not locked by Cocaine.
2. Set Require Password to Immediately and display-off battery timer to 1 minute, run on battery, close lid, wait under 1 minute, reopen: not locked yet.
3. Same settings, close lid and wait over 1 minute, reopen: lock screen is shown.
4. Set Require Password delay to a positive value, confirm lock happens after display timer plus that delay.
5. On AC power, confirm the AC display-off timer is used instead of the battery timer.
6. Close lid with a pending lock, reopen before the delay: pending lock cancels.
7. Close lid with a pending lock, turn Cocaine off before the delay if possible through external display or remote interaction: pending lock does not fire.

## Documentation Updates

Update `README.md` to say:

- Cocaine does not expose its own lock setting.
- When lid-close sleep prevention keeps the Mac awake and display sleep is allowed, Cocaine mirrors macOS lock policy.
- Require Password = Never means Cocaine will not lock on lid close.
- Otherwise, Cocaine locks after the active display-off timer plus the Require Password delay.

## Risks and Mitigations

- **macOS settings storage may vary by OS version.** Keep settings access isolated behind `MacOSLockPolicyReading` and cover parsing/read behavior with tests.
- **Timer may fire after conditions changed.** Recheck active state, lid state, and preferences immediately before locking.
- **Power source may change while the lid is closed.** The initial version reads timing at lid close. This matches the user's mental model of "what did macOS say when I closed the lid" and avoids complexity. A future refinement could observe power-source changes while a lock is pending.
- **Private lock API remains best-effort.** This feature does not expand private API usage; it only changes when the existing `ScreenLocker` is called.

## Rejected Alternatives

- **Immediate lock plus Require Password = Never gate:** rejected because it still does not match macOS timing.
- **Display timer only:** rejected because non-immediate Require Password delays would still be ignored.
- **New Cocaine lock delay setting:** rejected because the goal is to make Cocaine self-explanatory by following macOS, not by creating another policy.
- **Shelling out to `pmset` and `defaults` as the primary production path:** rejected as less clean and harder to test than isolated native reads, though it remains an acceptable fallback if direct reads are not reliable.

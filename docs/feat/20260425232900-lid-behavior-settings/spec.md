# Configurable Lid-Close Behavior Settings Spec

## Summary

Replace Cocaine's bundled "on = idle + lid-close prevention" toggle with a smaller, opt-in model driven by user-visible checkboxes in the right-click menu. The left-click icon continues to mean "Cocaine on or off", but **on** now means only the safe baseline behavior (idle/CPU sleep prevention, plus optionally display sleep prevention). Lid-close sleep prevention becomes an explicit opt-in checkbox, off by default. A new "Lock screen when lid closes" preference protects unattended clamshelled Macs. Lid event sounds become a toggle.

The change preserves the existing one-click UX for the safe case, makes the dangerous lid-close behavior intentional, and gives the user a single right-click surface to see and adjust everything that matters.

## Goals

- Keep the one-click left-click toggle as the primary UX.
- Make lid-close sleep prevention an explicit opt-in preference (default OFF), not bundled into the click.
- Let the user choose whether display sleep is also prevented (default ON).
- Optionally lock the screen when the lid closes while lid-close prevention is engaged (default ON).
- Let the user mute lid event sounds (default ON, as today).
- Persist preferences across launches via `UserDefaults`.
- Keep all settings reachable through inline checkbox items in the existing right-click menu — no separate Preferences window.
- Reconcile actual behavior live when the user toggles a preference while Cocaine is on.
- Preserve all existing safety invariants (clean shutdown, helper repair path, no silent lid-close prevention).

## Non-goals

- No separate Preferences window. All settings are inline `NSMenuItem` checkboxes.
- No durations, schedules, or per-app rules.
- No automatic lid-close disable on low battery, time of day, or location.
- No syncing of preferences across machines.
- No telemetry or audit logging of preference changes.
- No migration code — this is the first version with persisted preferences.
- No changes to the privileged helper protocol or signing requirements.
- No replacement of the existing menu bar icon design.

## User Experience

### Menu bar icon (unchanged)

- Left-click toggles Cocaine off ↔ on. "On" now means "current preferences are being enforced".
- The icon's on/off rendering is unchanged from today.

### Right-click menu (extended)

```
About Cocaine
─────────────────
☐ Prevent display sleep            (default ON)
☐ Prevent sleep with lid closed ⚠  (default OFF)
    ☐ Lock screen when lid closes  (default ON)
☐ Play lid event sounds            (default ON)
─────────────────
Repair / Install Helper            (only when needed)
Quit
```

- Each `☐` is an `NSMenuItem` whose `.state` mirrors the persisted preference. Clicking flips the preference.
- A small ⚠ marker is appended to the "Prevent sleep with lid closed" title whenever that preference is checked, to keep the danger visible.
- "Lock screen when lid closes" is visually nested (indented) under "Prevent sleep with lid closed" and is disabled (greyed out) when lid-close prevention is unchecked, since it has no event to fire on.
- "Play lid event sounds" gates both the close (Hero) and open (Basso) sounds.

### Behavior matrix when Cocaine is ON and lid closes

| `Prevent lid-close sleep` | `Lock screen on lid close` | Result |
|---|---|---|
| OFF | — | Mac sleeps normally (macOS default). |
| ON | OFF | Mac stays awake, internal screen blanks per macOS, session remains unlocked. |
| ON | ON | Mac stays awake, screen blanks, session locked. |

### Behavior when Cocaine is OFF

All preferences are inert. No assertions are held, no helper calls are made, no lock action fires. Preferences are armed but not firing.

### First-time enable confirmation

Whenever the user checks "Prevent sleep with lid closed" while it was previously unchecked, a modal alert appears:

> Preventing lid-close sleep can leave a closed MacBook running. Don't put it in a bag while this is enabled — it may overheat. Continue?

Buttons: **Cancel** (preference stays off) / **Enable** (preference is set; if Cocaine is currently on, helper engagement begins immediately, otherwise it will engage on the next turn-on).

The alert appears regardless of whether Cocaine is on or off, since the meaningful event is the user opting in to the dangerous behavior, not the moment it physically engages. After acceptance, the alert is suppressed by a persisted "confirmed" flag (see Implementation Notes); the flag is cleared when the preference is unchecked, so unchecking and re-checking re-shows the alert.

## Architecture

### New components

- **`PreferencesStore`** — observable settings store backed by `UserDefaults`. Exposes the four preferences as `@Published` properties through a small protocol so it is fakeable in tests. Reads default values when keys are missing. Centralizes all settings access — no other component touches `UserDefaults` directly.

- **`ScreenLocker`** — protocol with one method, `func lock() throws`. Concrete implementation calls the private `SACLockScreenImmediate()` from the `login` framework (loaded via `dlopen`/`dlsym` to avoid a hard private-API link), with a fallback to invoking `loginwindow` AppleScript if the private symbol is unavailable.

- **`LidCloseLockResponder`** — small reactive component. Observes `LidStateMonitor` (existing). When `AppState.isActive == true` and `PreferencesStore.preventLidCloseSleep == true` and `PreferencesStore.lockScreenOnLidClose == true` and the lid transitions to closed, it calls `ScreenLocker.lock()`. Lid open never locks. All gating is checked at the time of the event, so live preference changes affect the very next lid event.

### Refactored components

- **`AwakeController`** — `enable()` becomes `enable(preventDisplaySleep: Bool)`. The no-idle assertion is always created when the controller is enabled. The display-sleep assertion is created only when the parameter is true. A new `setPreventDisplaySleep(_:)` method allows live reconciliation: if currently enabled, it adds or removes the display assertion to match the new flag.

- **`AppCoordinator`** — gains a `PreferencesStore` dependency. Activation reads a snapshot of the preferences and decides which controllers to engage. Adds `setPreventLidCloseSleep(_:)` and `setPreventDisplaySleep(_:)` reconciliation methods that run through the existing `runTransition` busy-guard. Failure to engage lid-close prevention live reverts the preference to its previous value, records the error, and leaves the awake controller unaffected.

- **`LidEventSoundController`** — gains a `PreferencesStore` dependency. Sound playback is gated by `playLidEventSounds`. The lid state monitor lifecycle is unchanged.

- **`MenuBarController`** — extended right-click menu builder includes the four checkbox items, observes `PreferencesStore` for live state changes, and routes user clicks to either `PreferencesStore` (for sound and lock toggles, which need no coordinator action) or `AppCoordinator.set…` reconciliation methods (for display and lid-close, which need controller side effects). Drives the first-time confirmation alert for lid-close enable.

### Wiring

```
PreferencesStore           ─┐
AwakeController            ─┤
LidCloseController         ─┼─►  AppCoordinator (reads prefs, reconciles)
AppState                   ─┘
                                
LidStateMonitor (existing) ─┬─►  LidEventSoundController (gated by prefs)
                            └─►  LidCloseLockResponder    (gated by prefs + AppState)

ScreenLocker               ────►  LidCloseLockResponder

MenuBarController ────► reads/writes PreferencesStore
                  └───► invokes AppCoordinator.toggle / setPrevent…
```

`AppDelegate` constructs `PreferencesStore` once and injects it into the coordinator, the sound controller, the lock responder, and the menu bar controller. There is one instance per app lifetime.

## State Model

### Preferences (`PreferencesStore`)

```swift
preventDisplaySleep:   Bool    // default true,  key "Cocaine.preventDisplaySleep"
preventLidCloseSleep:  Bool    // default false, key "Cocaine.preventLidCloseSleep"
lockScreenOnLidClose:  Bool    // default true,  key "Cocaine.lockScreenOnLidClose"
playLidEventSounds:    Bool    // default true,  key "Cocaine.playLidEventSounds"
```

All four are independent. They are stored under stable string keys in `UserDefaults.standard`. Missing keys read as defaults.

### App state (existing `AppState`, unchanged shape)

`isActive`, `isBusy`, `lastErrorMessage` continue to mean what they mean today. No new top-level fields. Whether the helper is currently engaged is deducible from `isActive && PreferencesStore.preventLidCloseSleep` snapshot at the time the coordinator turned on; the coordinator tracks the engaged scope internally.

### Internal coordinator state

The coordinator tracks, per active session, whether lid-close prevention was actually engaged this session (so that turn-off and shutdown call `LidCloseController.disable()` only when needed). This avoids unnecessary helper traffic when lid-close was never enabled.

## On / Off Flow

### Turn on

1. User left-clicks inactive icon.
2. `runTransition` guard acquires.
3. `state.setBusy(true)`, `state.clearError()`.
4. Coordinator reads a `PreferencesSnapshot` from `PreferencesStore`.
5. `AwakeController.enable(preventDisplaySleep: snapshot.preventDisplaySleep)` — always creates the no-idle assertion, conditionally the display assertion.
6. **If** `snapshot.preventLidCloseSleep`:
   1. `LidCloseController.enable()` — installs/blesses the helper if needed (admin auth prompt), then sets `SleepDisabled = true`.
   2. Verify `LidCloseController.status() == true`. If false, throw and roll back.
   3. Mark the session as having engaged lid-close prevention.
7. `state.setActive(true)`, `state.setBusy(false)`.
8. On any thrown error after partial activation: `awakeController.disable()`, attempt `lidCloseController.disable()`, `state.recordError(...)`, return to off. Existing rollback contract preserved.

### Turn off

1. User left-clicks active icon.
2. `runTransition` guard acquires.
3. `state.setBusy(true)`.
4. `awakeController.disable()` (idempotent).
5. **If** lid-close was engaged this session: `lidCloseController.disable()`. Verify `status() == false`; on failure, record error but still go off (safety: lid-close must not linger).
6. `state.setActive(false)`, `state.setBusy(false)`.

### Quit

`AppCoordinator.shutdownCleanup()` is unchanged in contract: serializes against in-flight transitions, releases all assertions, calls helper disable if engaged, and replies to the AppKit terminate handler.

## Live Reconciliation Flows

When the user toggles a preference checkbox while Cocaine is on, the coordinator reconciles actual state to match the new preference. All reconciliations run through the existing `runTransition` busy-guard.

| Toggled preference | Was → Now | Action |
|---|---|---|
| `preventDisplaySleep` | true → false | `AwakeController.setPreventDisplaySleep(false)` — releases the display assertion, keeps the no-idle assertion. |
| `preventDisplaySleep` | false → true | `AwakeController.setPreventDisplaySleep(true)` — creates the display assertion. On creation failure: revert preference, record error. |
| `preventLidCloseSleep` | false → true | First time only: present confirmation alert. On accept: `LidCloseController.enable()`, verify `status()`. On any failure: revert preference, attempt cleanup, record error. |
| `preventLidCloseSleep` | true → false | `LidCloseController.disable()`. On failure: still set preference to false (priority is safety), record error. |
| `lockScreenOnLidClose` | * | No live action. Affects only the next lid-close event. |
| `playLidEventSounds` | * | No live action. Affects only the next lid event. |

When Cocaine is OFF, toggling any preference simply persists it. No controllers are touched.

## Lid Event Flows (when ON and `preventLidCloseSleep == true`)

The Mac stays awake because the helper has set `SleepDisabled = true`. `LidStateMonitor` (existing) observes the IOPM root domain and emits open / closed transitions. Two consumers react:

1. **`LidEventSoundController`** — plays Hero on close, Basso on open, only if `playLidEventSounds == true`. Already exists; gains the preference gate.
2. **`LidCloseLockResponder`** — on close only, if `lockScreenOnLidClose == true`, calls `ScreenLocker.lock()`. On open: nothing.

Both consumers are best-effort. Failures (sound playback error, lock API unavailable) are silent and never affect sleep prevention or app state.

When `preventLidCloseSleep == false`, the helper is not engaged and the Mac sleeps on lid close as normal — there is no lid event to react to.

## Error Handling and Safety

### Invariants

1. `preventLidCloseSleep == false` (default) implies the helper-side `SleepDisabled` is `false`. Cocaine never silently engages lid-close prevention.
2. Cocaine OFF implies no power assertions held and `SleepDisabled == false`.
3. Quit always cleans up, regardless of which preferences were active.
4. Menu checkbox state always matches `PreferencesStore`. Reverts after failed reconciliation are reflected in the menu on the next render.

### Error responses

| Scenario | Response |
|---|---|
| Helper not installed when enabling lid-close live | First-time bless attempt with admin auth. On user cancel: revert preference, record error, "Repair / Install Helper" stays/becomes available. |
| Helper communication fails enabling lid-close (auth granted) | Revert preference, record error, ensure helper-side state is disabled, leave awake controller as-is. |
| Helper disable fails on turn-off | Cocaine still goes OFF (assertions released), `lastErrorMessage` records the helper failure, "Repair / Install Helper" appears. Safety: lid-close prevention must not linger. |
| Display assertion creation fails on live toggle | Revert preference, record error. No-idle assertion unaffected. |
| `ScreenLocker.lock()` fails | Best-effort; logged via `os_log`, no user-visible error, sleep prevention unaffected. |
| Sound playback fails | Silent, as today. |
| `UserDefaults` read fails / corrupted | Use built-in defaults, never crash. |
| Settings changed externally between snapshot and apply | Reconciliation reads its own snapshot at apply time; the busy-guard serializes transitions. |
| User changes `SleepDisabled` from outside Cocaine | Out of scope. Cocaine only manages what it set. |

### Safety regression vs. today

After upgrading, lid-close prevention defaults to OFF. Existing users who relied on lid-close behavior will need to check the new box once. This is intentionally safer and is documented in the README.

## Implementation Notes

- `PreferencesStore` should accept an injected `UserDefaults` instance so tests use a `UserDefaults(suiteName:)` namespace and never pollute the real one.
- The "first-time confirmation shown" flag is itself a `UserDefaults` key (`Cocaine.lidClosePreventionConfirmed`, default `false`), set to `true` after the user accepts the alert. It is reset to `false` whenever the preference is unchecked, so disabling and re-enabling triggers the alert again.
- `ScreenLocker` should not link the private `login` framework directly. Use `dlopen("/System/Library/PrivateFrameworks/login.framework/login", RTLD_LAZY)` and `dlsym` for `SACLockScreenImmediate`. If the symbol is unavailable, fall back to `osascript -e 'tell application "loginwindow" to «event aevtrlck»'` via `Process`.
- `MenuBarController` should rebuild the menu lazily (in `showMenu()`) so checkbox states reflect the latest preferences each time the menu opens. Live preference observation only needs to drive the icon and tooltip, not menu state (which is rebuilt on display).
- Keep coordinator concurrency invariants: all reconciliations go through `runTransition`, so concurrent menu clicks during a transition are dropped (matching the existing toggle behavior).

## Testing Strategy

### Unit tests (additive to existing 44)

**`PreferencesStoreTests`**
- Defaults match spec when `UserDefaults` is empty.
- Each preference round-trips through write → read.
- Setting a value publishes via Combine.
- Uses a suite-name-scoped `UserDefaults` to avoid polluting real defaults.

**`AwakeControllerTests` (extend)**
- `enable(preventDisplaySleep: false)` creates only the no-idle assertion (one create call, not two).
- `enable(preventDisplaySleep: true)` creates both — guard against regression.
- Live `setPreventDisplaySleep(false)` while enabled releases only the display assertion ID, keeps no-idle.
- Live `setPreventDisplaySleep(true)` while enabled creates the missing display assertion.

**`AppCoordinatorTests` (extend)**
- `turnOn()` with `preventLidCloseSleep == false`: awake controller called, lid-close controller NOT called, state goes active.
- `turnOn()` with `preventLidCloseSleep == true`: both controllers engaged (existing rollback paths still apply).
- Live `setPreventLidCloseSleep(true)` while on: helper engaged, fake helper state reflects it.
- Live `setPreventLidCloseSleep(true)` while on, helper enable fails: preference reverted, error recorded, awake stays enabled.
- Live `setPreventDisplaySleep(false)` while on: display assertion released, no-idle still held.
- `turnOff()` after a session that engaged lid-close: helper disable called.
- `turnOff()` after a session that did not engage lid-close: helper disable NOT called.

**`LidEventSoundControllerTests` (extend)**
- `playLidEventSounds == false` and `state.isActive == true`: no sound on either event.
- Toggling `playLidEventSounds` between events affects only the next event.

**`LidCloseLockResponderTests` (new)**
- `state.isActive == false`: no lock on lid close.
- `isActive && preventLidCloseSleep == false`: no lock (no point — Mac is sleeping anyway).
- `isActive && preventLidCloseSleep && lockScreenOnLidClose == false`: no lock.
- `isActive && preventLidCloseSleep && lockScreenOnLidClose == true`: lock called exactly once on close.
- Lid open never locks regardless of settings.
- `ScreenLocker.lock()` throwing: no crash, no state change.

### Manual / system tests (additive)

1. Fresh install → right-click menu shows checkboxes with expected defaults (display=on, lid-close=off, lock=on, sounds=on).
2. Toggle lid-close-prevention on → confirmation dialog appears once.
3. Toggle lid-close-prevention on, cancel dialog → preference stays off, no helper call.
4. Cocaine on, toggle display-sleep prevention off live → external monitor dims, Mac stays awake.
5. Cocaine on, lid-close on, lock-on-close on, close lid → reopen → finds lock screen.
6. Cocaine on, lid-close on, lock-on-close off, close lid → reopen → finds session unlocked.
7. Quit while lid-close on → relaunch → preference still on, but actual `SleepDisabled` is false until next turn-on.
8. Cocaine on with lid-close on → toggle Cocaine off via icon → `SleepDisabled` returns to false; menu checkbox stays checked (preference vs. actual state distinction).

### Tests deliberately skipped

- `ScreenLocker` concrete implementation — manual validation only (private API).
- `MenuBarController` AppKit binding details — manual validation, keep controller thin.
- First-run safety confirmation alert — manual validation.

## Risks

- The `SACLockScreenImmediate` symbol is private and may move or disappear in future macOS releases. The AppleScript fallback mitigates but is fragile and may be blocked by Automation permissions.
- Live reconciliation introduces more transition states than today. The existing `runTransition` busy-guard plus per-test coverage is the mitigation; complexity is bounded because each preference change is itself a small, finite state machine.
- The default change (lid-close prevention now OFF by default) is a behavior regression for existing users on upgrade. Documented in the README; acceptable because it makes the dangerous behavior explicit.
- Locking the screen on lid close while the user has automation in flight could surprise the user. The behavior is opt-out via the inline checkbox, and the default-on choice was made deliberately for safety.

## Rejected Alternatives

- **Separate Preferences window with a SwiftUI `Settings` scene.** Rejected for v1 in favor of inline menu checkboxes; revisit if the settings list grows past four to six items.
- **Three-state click cycle (Off / Idle-only / Idle + lid-close).** Rejected in favor of an opt-in preference, because cycling makes it easy to land on the dangerous state by accident.
- **Bundling lock-screen behavior into `LidEventSoundController`.** Rejected to keep that controller focused on audio. Lock and sound are sibling lid-event consumers.
- **Skipping live reconciliation (settings only apply on next off→on).** Rejected because users will expect a checkbox flip to take effect immediately while Cocaine is on, especially for the dangerous lid-close toggle.
- **Auto-revert versus persist on failed lid-close enable live.** Auto-revert chosen so the menu checkbox always matches actual behavior; persisting checked-but-failed risks the user thinking lid-close is engaged when it isn't.

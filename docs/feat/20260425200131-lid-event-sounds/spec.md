# Lid Event Sounds Spec

## Summary

Add audible feedback to Insomnia when lid-close sleep prevention is active. When the user closes the MacBook lid while Insomnia is on, the app plays the built-in macOS Hero sound. When the user opens the lid after the Mac remained awake, the app plays the built-in macOS Basso sound.

The feature is app-side user feedback only. It does not change how lid-close sleep prevention is enabled, disabled, or restored.

## Goals

- Play an audible close-lid warning so the user knows Insomnia was left enabled before leaving the Mac closed.
- Play an audible open-lid confirmation so the user knows the computer stayed awake while the lid was closed.
- Use built-in macOS sounds: Hero for lid close, Basso for lid open.
- Keep sound detection passive and low-power: no continuous polling in the default design.
- Keep the privileged helper focused on privileged power-setting work, not UI feedback.
- Keep the implementation small, testable, and consistent with the existing controller-oriented architecture.

## Non-goals

- No sound picker UI in this feature.
- No custom bundled audio assets in this feature.
- No volume control or mute setting in this feature.
- No helper-side lid event detection unless app-side passive observation proves impossible during implementation.
- No changes to the privileged helper protocol for sound playback.
- No behavior change for ordinary on/off toggling beyond starting and stopping lid sound monitoring.

## User Experience

### Active state

When Insomnia is fully active and lid-close prevention has been confirmed, the app listens for lid state changes:

- Lid closes: play Hero.
- Lid opens: play Basso.

The close sound communicates: “Insomnia is still enabled; this closed Mac may keep running.” The open sound communicates: “The Mac was awake while closed.”

### Inactive, busy, and failure states

When Insomnia is off, activation is still in progress, activation failed, shutdown cleanup is running, or the app is quitting, lid sounds do not play.

Sounds should only be associated with the state the menu bar icon already promises: active means ordinary sleep and lid-close sleep are prevented.

### Duplicate lid notifications

The app should remember the last known lid state and suppress duplicate sound playback for repeated identical notifications. A close-to-close sequence should not replay Hero unless an open event occurred in between; an open-to-open sequence should not replay Basso unless a close event occurred in between.

## Architecture

Add two small app-side services and keep the helper unchanged:

- `LidStateMonitor`: passively observes macOS lid state changes and emits normalized open/closed events.
- `LidEventSoundController`: coordinates app activity state, lid events, duplicate suppression, and sound playback.
- `SystemSoundPlayer`: tiny AppKit wrapper for loading and playing built-in macOS sound names.

The app delegate wires these services next to the existing `AppState`, `AwakeController`, `LidCloseController`, `AppCoordinator`, and `MenuBarController` setup.

## Component Responsibilities

### LidStateMonitor

`LidStateMonitor` owns platform-specific lid observation. It exposes a small testable interface that can start and stop monitoring and report lid events through a closure or publisher.

It should prefer passive macOS notifications or IOKit power-source/display notifications that fire on lid state changes. It should not run a repeating timer in the default design.

If passive observation cannot be registered, the monitor reports the failure to its caller and leaves the rest of the app usable.

### LidEventSoundController

`LidEventSoundController` owns policy:

- Start monitoring when `AppState.isActive` becomes true.
- Stop monitoring when `AppState.isActive` becomes false.
- Ignore lid events unless the app is active.
- Play Hero for a transition into closed state.
- Play Basso for a transition into open state.
- Suppress duplicate events with the same state as the previously handled lid state.

This keeps sound policy out of `AppCoordinator`, whose role remains activation, rollback, and cleanup.

### SystemSoundPlayer

`SystemSoundPlayer` wraps AppKit sound playback. It should support playing built-in sound names by name so tests can replace it with a fake recorder.

Playback failures must not throw into activation or cleanup paths. A missing sound is treated as a non-critical event: no sleep-prevention state changes, no rollback, and no user-visible failure state.

## Data Flow

### Activation

1. User toggles Insomnia on.
2. Existing coordinator enables ordinary sleep prevention and lid-close sleep prevention.
3. Existing coordinator marks `AppState.isActive = true` only after successful validation.
4. `LidEventSoundController` observes active state and starts `LidStateMonitor`.

No lid sound should play just because activation succeeded. Sounds are tied to actual lid state transitions.

### Lid closes while active

1. `LidStateMonitor` emits `closed`.
2. `LidEventSoundController` confirms the app is active and the previous handled state was not `closed`.
3. `SystemSoundPlayer` plays Hero.
4. Controller records `closed` as the last handled state.

### Lid opens while active

1. `LidStateMonitor` emits `open`.
2. `LidEventSoundController` confirms the app is active and the previous handled state was not `open`.
3. `SystemSoundPlayer` plays Basso.
4. Controller records `open` as the last handled state.

### Deactivation and quit

1. User toggles Insomnia off or quits the app.
2. Existing coordinator disables ordinary and lid-close prevention.
3. `AppState.isActive` becomes false.
4. `LidEventSoundController` stops monitoring and clears the last handled lid state for the next active session.

## Error Handling and Safety

- Lid-monitor setup failure must not prevent Insomnia from turning on, because sleep prevention is the primary behavior and sounds are auxiliary feedback.
- Sound playback failure must not affect sleep prevention state.
- Sound failures should not set the menu bar error icon; that error state remains reserved for sleep-prevention/helper failures.
- If monitoring cannot start, the app may log a diagnostic in debug builds, but it should not alarm the user.
- The existing safety warning remains valid: preventing lid-close sleep can leave a closed MacBook running and may cause overheating if placed in a bag.

## Testing

Add unit tests around policy with fake monitor and fake sound player:

- Active close event plays Hero.
- Active open event plays Basso.
- Off-state close/open events play no sounds.
- Busy or failed activation does not start monitoring or play sounds before `AppState.isActive` becomes true.
- Repeated close notifications play Hero only once until an open event occurs.
- Repeated open notifications play Basso only once until a close event occurs.
- Deactivation stops monitoring and clears the last lid state.
- Monitor startup failure does not change app active state or helper state.

Add build verification with the existing SwiftPM test and app bundle commands.

Manual validation should include running the app on MacBook hardware, activating Insomnia, closing the lid, hearing Hero, reopening the lid, and hearing Basso.

## Risks

- macOS lid state notifications can be hardware- and OS-version-specific. Manual validation on real MacBook hardware is required.
- A closed lid can physically muffle the close sound. Built-in Hero should still be audible enough for nearby feedback, but this is ultimately environment-dependent.
- System sound names are stable on the target machine, but if a future macOS version removes or renames a sound, playback should fail silently rather than affecting sleep prevention.

## Accepted Approach

Use the passive app-side observer approach. It is the least power-hungry option among the app-owned designs because it wakes only on lid state changes, avoids continuous polling, and keeps the privileged helper narrow.

Rejected alternatives:

- Polling-only app detection: simpler to reason about, but less power-efficient and potentially delayed.
- Helper-side detection: can also be passive, but unnecessarily couples a harmless UI feedback feature to privileged code and increases testing and maintenance risk.

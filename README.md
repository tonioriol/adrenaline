# Adrenaline

Keep your Mac awake from the menu bar — even with the lid closed.

**Left-click** the icon to toggle sleep prevention on/off. **Right-click** for options:

| Option | Default | |
|---|---|---|
| Prevent display sleep | ON | Also keeps the display awake |
| Prevent disk sleep | ON | Keeps mechanical drives spinning (only shown when HDD detected) |
| Prevent sleep with lid closed | OFF | Requires one-time admin authorization |
| Play lid event sounds | ON | Sound on lid open/close |
| Launch at login | OFF | Start with macOS |

## Keeping it awake from other apps

Other programs can keep Adrenaline on while they run, for example an agent harness during a long task. A request switches it on with your current settings, including lid-closed prevention if that option is enabled.

Adrenaline listens on a Unix socket at `~/Library/Application Support/Adrenaline/adrenaline.sock`, which only your user can access. The protocol is newline-delimited JSON:

| Request | Effect |
|---|---|
| `{"cmd":"hold","reason":"…"}` | Keep Adrenaline on while this connection stays open |
| `{"cmd":"release"}` | Drop this connection's hold |
| `{"cmd":"status"}` | Report `active`, `busy`, `holdDriven` and the current `holds` |

Each request gets one JSON reply with an `ok` field. A hold belongs to its connection, so if the client exits or crashes, the hold goes away with it. When the last hold is released, Adrenaline turns off again, but only if a hold was what turned it on. If you had it on already, it stays on. If you switch it off yourself while something is holding it, it stays off until the next hold request.

Node / Bun:

```js
import net from "node:net";
import os from "node:os";

const sock = net.connect(`${os.homedir()}/Library/Application Support/Adrenaline/adrenaline.sock`);
sock.on("error", () => {}); // Adrenaline not running: carry on without it
sock.write(JSON.stringify({ cmd: "hold", reason: "agent task" }) + "\n");
// ... work ...
sock.end(); // or just exit
```

From the shell, `adrenaline` wraps the same protocol. Homebrew puts it on your `PATH`; otherwise it's at `Adrenaline.app/Contents/Helpers/adrenaline`:

```bash
adrenaline hold -- npm run long-task   # awake while the command runs
adrenaline hold --pid 4242             # awake until that process exits
adrenaline status
```

## Install

### Homebrew

```bash
brew tap tonioriol/adrenaline https://github.com/tonioriol/adrenaline.git
brew install --cask tonioriol/adrenaline/adrenaline
```

After the official cask is accepted, you can install with `brew install --cask adrenaline`.

### Direct download

Grab the latest `.zip` from [Releases](https://github.com/tonioriol/adrenaline/releases/latest), unzip, drag to Applications.

### Uninstall

```bash
brew uninstall --zap --cask tonioriol/adrenaline/adrenaline
```

<details>
<summary>Also remove the privileged helper</summary>

```bash
sudo launchctl bootout system/com.tonioriol.adrenaline.helper 2>/dev/null
sudo rm -f /Library/PrivilegedHelperTools/com.tonioriol.adrenaline.helper
sudo rm -f /Library/LaunchDaemons/com.tonioriol.adrenaline.helper.plist
```

</details>

## Build

```bash
make app        # → build/Adrenaline.app
make test
make run
```

## License

[AGPL-3.0](LICENSE)

Inspired by Caffeine and Fermata; no third-party source is vendored in this repository.

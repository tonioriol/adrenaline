# Adrenaline

Keep your Mac awake from the menu bar — even with the lid closed.

**Click** the menu bar icon to choose a mode:

| Mode | Behavior | Icon |
|---|---|---|
| Off | Never prevent sleep; external holds are refused | Outlined pill |
| Auto | Prevent sleep only while at least one external hold is active | Outlined pill with a dot while waiting; filled pill with a dot while held |
| On | Always prevent sleep, regardless of external holds | Filled pill |

Adrenaline remembers your mode. On upgrade, the previous enabled setting becomes On; the previous disabled setting becomes Auto so existing integrations still work. The menu also has these options:

| Option | Default | |
|---|---|---|
| Prevent display sleep while lid is open | ON | Also keeps the display awake. With the lid closed the display always sleeps |
| Prevent disk sleep | ON | Keeps mechanical drives spinning (only shown when HDD detected) |
| Prevent sleep with lid closed | OFF | Requires one-time admin authorization |
| Stay unlocked when lid is closed | OFF | No lock screen when you reopen the lid. Asks once for your login password (kept in the Keychain), turns off the macOS "Require password" setting while Adrenaline is on and puts yours back when it turns off |
| Play lid event sounds | ON | Sound on lid open/close |
| Launch at login | OFF | Start with macOS |

## Keeping it awake from other apps

Other programs can keep Adrenaline on while they run, for example an agent harness during a long task. In Auto, a hold switches it on with your current settings, including lid-closed prevention if enabled. The tooltip names the holders; the menu also shows their PIDs when available.

Adrenaline listens on a Unix socket at `~/Library/Application Support/Adrenaline/adrenaline.sock`, which only your user can access. The protocol is newline-delimited JSON:

| Request | Effect |
|---|---|
| `{"cmd":"hold","reason":"…"}` | Request a hold while this connection stays open (refused in Off) |
| `{"cmd":"release"}` | Drop this connection's hold |
| `{"cmd":"status"}` | Report `mode`, `active`, `busy`, `holdDriven` and the current `holds` |

Each request gets one JSON reply with an `ok` field. A hold belongs to its connection, so if the client exits or crashes, the hold goes away with it. In Auto, the last release turns sleep prevention off. On stays active without holds. Switching to Off drops existing holds and refuses new ones; switch back to Auto and have the client request a new hold to let it keep the Mac awake again.

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

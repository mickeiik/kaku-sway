pragma Singleton
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io

// Brightness of each screen, shared by the bar, the display panel and the brightness
// keys (their Sway binding calls `qs ipc call brightness step 1` / `-1`, which also
// shows the on-screen indicator, see Osd.qml).
//   built-in screen (eDP...)  its backlight, through brightnessctl
//   monitors                  DDC/CI, through ddcutil (most monitors have it; some
//                             have it off in their own menu)
// The keys change the focused screen, scrolling on a bar's display icon that bar's.
// No polling: the level is shown right away (like the volume), written in the
// background (a monitor takes ~50 ms per change: at most one every 250 ms, ending on
// the latest value), re-read on startup, when screens come and go, and when the
// display panel opens.
// Monitors' levels are also kept in ~/.local/state/quickshell/brightness and set
// again when a monitor shows up (login, plugged in): some forget theirs when turned
// off. The built-in screen's backlight is restored by systemd.
//
// This laptop's brightness keys come from the firmware, which repeats a held key only
// every ~250 ms (the keyboard's volume keys: every 40 ms). So each key step glides
// over that gap instead of jumping, and held keys take bigger steps.
Singleton {
    id: root

    property var devices: ({}) // screen name -> { kind: "backlight" | "ddc", bus, max }
    property var levels: ({}) // screen name -> percent
    property string current: "" // the screen last changed (for the indicator)
    readonly property int percent: levels[current] ?? 0
    readonly property bool available: Object.keys(devices).length > 0

    property string gliding: "" // screen the keys are gliding (see glide)
    property int target: 0 // where the keys are taking its level
    property real lastKey: 0

    // Not bound to anything: write bookkeeping
    property var pending: ({}) // screen name -> percent waiting to be written
    property var lastWrite: ({}) // screen name -> time of its last write
    property var saved: ({}) // monitor name -> percent, as kept in stateFile

    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/quickshell/brightness"

    signal indicate() // show the on-screen indicator (keys, scrolling on the bar icon)

    function has(name) {
        return devices[name] !== undefined;
    }
    function level(name) {
        return levels[name] ?? 0;
    }
    // Never all the way to 0 on a backlight: on many laptops that turns it off
    function clamp(name, p) {
        return Math.max(devices[name]?.kind === "backlight" ? 1 : 0, Math.min(100, Math.round(p)));
    }

    // From a slider: straight to that level
    function set(name, p) {
        if (gliding === name)
            glide.stop();
        show(name, p);
    }
    // Steps of 5% (keys: see the IPC step below), gliding there
    function step(name, steps, size) {
        if (!has(name))
            return;
        if (gliding !== name || !glide.running) {
            gliding = name;
            target = level(name);
        }
        target = clamp(name, target + steps * (size || 5));
        current = name;
        glide.start();
        indicate();
    }

    // Shows the level, and writes it (see flush)
    function show(name, p) {
        if (!has(name))
            return;
        const value = clamp(name, p);
        levels = Object.assign({}, levels, { [name]: value });
        pending[name] = value;
        flush();
        if (devices[name].kind === "ddc") {
            saved[name] = value;
            saveTimer.restart();
        }
    }
    // "<monitor name> <percent>" per line
    function save() {
        const lines = Object.keys(saved).map(name => name + " " + saved[name]).join("\n");
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"', "save", stateFile, lines]);
    }
    // Writes the waiting levels whose screen can take one now; the others on the next tick
    function flush() {
        const now = Date.now();
        let waiting = false;
        for (const name of Object.keys(pending)) {
            const d = devices[name];
            if (!d) {
                delete pending[name];
            } else if (now - (lastWrite[name] ?? 0) >= (d.kind === "ddc" ? 250 : 50)) {
                write(d, pending[name]);
                lastWrite[name] = now;
                delete pending[name];
            } else {
                waiting = true;
            }
        }
        if (waiting && !flushTimer.running)
            flushTimer.start();
    }
    function write(d, p) {
        if (d.kind === "backlight") {
            Quickshell.execDetached(["brightnessctl", "-q", "set", p + "%"]);
            rereadAfter.restart();
        } else {
            Quickshell.execDetached(["ddcutil", "--bus", String(d.bus), "--noverify", "setvcp", "10", String(Math.round(p * d.max / 100))]);
        }
    }
    // A level read back is ignored while changes to it are still being written
    function busy(name) {
        return pending[name] !== undefined || Date.now() - (lastWrite[name] ?? 0) < 1000 || (glide.running && gliding === name);
    }

    function refresh() {
        readBacklight();
        if (!monitorReader.running)
            monitorReader.running = true;
    }
    function readBacklight() {
        if (!backlightReader.running)
            backlightReader.running = true;
        else
            rereadAfter.restart(); // a read is under way; read again once it's done
    }
    // Replaces the devices of one kind, and takes the levels read that aren't busy
    function update(kind, found) {
        const next = {};
        for (const name of Object.keys(devices)) {
            if (devices[name].kind !== kind)
                next[name] = devices[name];
        }
        const lv = Object.assign({}, levels);
        const restore = []; // monitors that just showed up with another level than saved
        let changed = false; // or changed on the monitor itself: kept as the new level
        for (const f of found) {
            if (kind === "ddc" && saved[f.name] !== f.percent) {
                if (devices[f.name] === undefined && saved[f.name] !== undefined) {
                    restore.push(f.name);
                } else if (!busy(f.name)) {
                    saved[f.name] = f.percent;
                    changed = true;
                }
            }
            next[f.name] = f.device;
            if (!busy(f.name))
                lv[f.name] = f.percent;
        }
        if (changed)
            saveTimer.restart();
        devices = next;
        levels = lv;
        for (const name of restore)
            show(name, saved[name]);
    }

    IpcHandler {
        target: "brightness"

        // 5% per press, 10% when held (presses less than 350 ms apart), on the focused
        // screen (or the first one that has brightness)
        function step(steps: int): void {
            const now = Date.now();
            const held = now - root.lastKey < 350;
            root.lastKey = now;
            const focused = I3.focusedMonitor?.name ?? "";
            const name = root.has(focused) ? focused : Quickshell.screens.map(s => s.name).find(n => root.has(n));
            if (name)
                root.step(name, steps, held ? 10 : 5);
        }
        function refresh(): void {
            root.refresh();
        }
    }

    // Monitors take a moment to answer after being plugged in or turned on
    Connections {
        target: Quickshell
        function onScreensChanged() { hotplug.restart(); }
    }
    Timer {
        id: hotplug
        interval: 2000
        onTriggered: root.refresh()
    }

    // Moves the level toward the target over ~250 ms, the gap between held-key repeats
    Timer {
        id: glide
        interval: 40
        repeat: true
        onTriggered: {
            const now = root.level(root.gliding);
            const diff = root.target - now;
            if (diff === 0 || !root.has(root.gliding)) {
                stop();
                return;
            }
            root.show(root.gliding, now + Math.sign(diff) * Math.max(1, Math.round(Math.abs(diff) * 0.35)));
        }
    }

    // Saved once the level stops changing
    Timer {
        id: saveTimer
        interval: 1000
        onTriggered: root.save()
    }

    Timer {
        id: flushTimer
        interval: 50
        onTriggered: root.flush()
    }

    Timer {
        id: rereadAfter
        interval: 150
        onTriggered: root.readBacklight()
    }

    // brightnessctl -m prints "device,class,current,percent%,max". The backlight is the
    // built-in screen's: eDP (or LVDS / DSI on older and ARM laptops).
    Process {
        id: backlightReader
        command: ["brightnessctl", "-m", "--class=backlight"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = parseInt(text.split(",")[3]);
                const name = Quickshell.screens.map(s => s.name).find(n => /^(eDP|LVDS|DSI)-/.test(n));
                root.update("backlight", isNaN(p) || !name ? [] : [{ name: name, device: { kind: "backlight" }, percent: p }]);
            }
        }
    }

    // The saved levels, then the monitors (which compares with them)
    Process {
        running: true
        command: ["cat", root.stateFile]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const [name, p] = line.trim().split(" ");
                    if (name && !isNaN(parseInt(p)))
                        root.saved[name] = parseInt(p);
                }
                monitorReader.running = true;
            }
        }
    }

    // Monitors that answer DDC/CI: "<bus> <screen name> <current> <max>" per line.
    // ddcutil detect --brief lists "Display N" (or "Invalid display": no DDC/CI) with
    // "I2C bus: /dev/i2c-5" and "DRM connector: card1-DP-2"; getvcp 10 --brief prints
    // "VCP 10 C <current> <max>".
    Process {
        id: monitorReader
        command: ["sh", "-c", `
            command -v ddcutil >/dev/null || exit 0
            ddcutil detect --brief 2>/dev/null | awk '
                /^Display/ { valid = 1; bus = ""; conn = "" }
                /^Invalid display/ { valid = 0 }
                valid && /I2C bus:/ { bus = $NF; sub(/.*i2c-/, "", bus) }
                valid && /DRM[_ ]connector:/ { conn = $NF; sub(/^card[0-9]+-/, "", conn) }
                valid && bus != "" && conn != "" { print bus, conn; valid = 0 }
            ' | while read -r bus conn; do
                set -- $(ddcutil --bus "$bus" getvcp 10 --brief 2>/dev/null)
                [ "$1" = VCP ] && [ "\${5:-0}" -gt 0 ] && echo "$bus $conn $4 $5"
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.trim().split("\n")) {
                    const [bus, name, cur, max] = line.split(" ");
                    if (name && parseInt(max) > 0)
                        found.push({ name: name, device: { kind: "ddc", bus: parseInt(bus), max: parseInt(max) }, percent: Math.round(parseInt(cur) * 100 / parseInt(max)) });
                }
                root.update("ddc", found);
            }
        }
    }
}

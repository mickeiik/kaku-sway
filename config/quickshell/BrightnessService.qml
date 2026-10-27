pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness through brightnessctl, shared by the bar, the display panel and
// the brightness keys (their Sway binding calls `qs ipc call brightness step 1` / `-1`,
// which also shows the on-screen indicator, see Osd.qml).
// No polling: the level is shown right away (like the volume), written in the
// background, then re-read once the changes stop.
//
// This laptop's brightness keys come from the firmware, which repeats a held key only
// every ~250 ms (the keyboard's volume keys: every 40 ms). So each key step glides
// over that gap instead of jumping, and held keys take bigger steps.
Singleton {
    id: root

    property int percent: 0
    property bool available: true // false when there's no backlight (e.g. a desktop monitor)
    property int pending: -1 // value waiting to be written
    property int target: 0 // where the keys are taking the level (see glide)
    property real lastKey: 0

    signal indicate() // show the on-screen indicator (keys, scrolling on the bar icon)

    // From the slider: straight to that level
    function set(p) {
        glide.stop();
        show(p);
    }
    // Steps of 5% (keys: see the IPC step below), gliding there
    function step(steps, size) {
        target = Math.max(1, Math.min(100, (glide.running ? target : percent) + steps * (size || 5)));
        glide.start();
        indicate();
    }

    // Shows the level, and writes it: at most once every 50 ms, ending on the latest value
    function show(p) {
        pending = Math.max(1, Math.min(100, Math.round(p)));
        percent = pending;
        if (!writeLimit.running) {
            write(pending + "%");
            pending = -1;
            writeLimit.start();
        }
    }
    function refresh() {
        if (!reader.running)
            reader.running = true;
        else
            rereadAfter.restart(); // a read is under way; read again once it's done
    }

    function write(value) {
        // Never all the way to 0: on many laptops that turns the backlight off
        Quickshell.execDetached(["brightnessctl", "-q", "-n1%", "set", value]);
        rereadAfter.restart();
    }

    IpcHandler {
        target: "brightness"

        // 5% per press, 10% when held (presses less than 350 ms apart)
        function step(steps: int): void {
            const now = Date.now();
            const held = now - root.lastKey < 350;
            root.lastKey = now;
            root.step(steps, held ? 10 : 5);
        }
        function refresh(): void {
            root.refresh();
        }
    }

    // Moves the level toward the target over ~250 ms, the gap between held-key repeats
    Timer {
        id: glide
        interval: 40
        repeat: true
        onTriggered: {
            const diff = root.target - root.percent;
            if (diff === 0) {
                stop();
                return;
            }
            root.show(root.percent + Math.sign(diff) * Math.max(1, Math.round(Math.abs(diff) * 0.35)));
        }
    }

    Timer {
        id: writeLimit
        interval: 50
        onTriggered: {
            if (root.pending >= 0) {
                root.write(root.pending + "%");
                root.pending = -1;
                restart();
            }
        }
    }

    Timer {
        id: rereadAfter
        interval: 150
        onTriggered: root.refresh()
    }

    // brightnessctl -m prints "device,class,current,percent%,max"
    Process {
        id: reader
        command: ["brightnessctl", "-m", "--class=backlight"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = parseInt(text.split(",")[3]);
                root.available = !isNaN(p);
                // Changes still being written: keep the level already shown
                if (isNaN(p) || root.pending >= 0 || writeLimit.running || rereadAfter.running || glide.running)
                    return;
                root.percent = p;
            }
        }
    }
}

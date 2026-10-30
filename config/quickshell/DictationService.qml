pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Speech to text with voxtype (hold Super+D, see sway/config.d/60-bindings-dictation.conf).
// Follows the state file the voxtype daemon rewrites on every change, and while
// listening, the microphone level (for DictationOsd.qml).
Singleton {
    id: root

    property bool installed: false // optional: install.sh asks
    property string state: "idle" // idle, recording, transcribing
    readonly property bool busy: state === "recording" || state === "transcribing"
    readonly property bool micMuted: VolumeService.micMuted

    // Recent microphone levels (0-1), oldest first, one per 60 ms
    readonly property int historyLength: 26
    property var levels: new Array(historyLength).fill(0)
    property real loudest: 0 // since the last sample
    property int seconds: 0 // listening for

    function cancel() {
        Quickshell.execDetached(["voxtype", "record", "cancel"]);
    }

    onStateChanged: {
        if (state === "recording") {
            levels = new Array(historyLength).fill(0);
            seconds = 0;
        }
        // Safety net: if voxtype stops without its "after typing" hook, Sway would stay
        // in a voxtype mode where the usual shortcuts do nothing
        if (state === "idle")
            Quickshell.execDetached(["sh", "-c",
                "swaymsg -t get_binding_state | grep -q '\"voxtype_' && swaymsg mode default"]);
    }

    Process {
        running: true
        command: ["rpm", "-q", "voxtype"]
        onExited: code => root.installed = code === 0
    }

    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/voxtype/state"
        watchChanges: true
        printErrors: false // missing until the daemon first runs
        onFileChanged: reload()
        onLoaded: root.state = text().trim() || "idle"
        onLoadFailed: root.state = "idle"
    }

    // voxtype's audio frames as JSON lines ({"peak": 0-1, "rms": ...}), only while listening
    Process {
        running: root.state === "recording"
        command: ["voxtype-audio-bridge"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const peak = JSON.parse(line).peak;
                    if (typeof peak === "number")
                        root.loudest = Math.max(root.loudest, peak);
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 60
        repeat: true
        running: root.state === "recording"
        onTriggered: {
            // dB scale from -50 dB (silence) to 0 dB, like a level meter
            const db = 20 * Math.log10(Math.max(root.loudest, 1e-5));
            root.levels = root.levels.slice(1).concat([Math.max(0, Math.min(1, (db + 50) / 50))]);
            root.loudest = 0;
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.state === "recording"
        onTriggered: root.seconds++
    }
}

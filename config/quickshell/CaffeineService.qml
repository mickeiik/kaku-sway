pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Caffeine on/off, shared by the bars of all screens.
// Kept in ~/.local/state/quickshell/caffeine, so it's still on after a restart.
Singleton {
    id: root

    property bool on: false

    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/quickshell/caffeine"

    function toggle() {
        on = !on;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"', "save", stateFile, on ? "on" : "off"]);
    }

    // Saved state, once at startup
    Process {
        running: true
        command: ["cat", root.stateFile]
        stdout: StdioCollector {
            onStreamFinished: root.on = text.trim() === "on"
        }
    }
}

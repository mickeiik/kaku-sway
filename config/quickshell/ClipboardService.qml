pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history, kept by cliphist (Fedora package; Sway starts
// `wl-paste --watch cliphist store`, see sway/config.d/80-clipboard.conf).
// Read when the launcher's Clipboard menu opens.
Singleton {
    id: root

    property var items: [] // [{ id, text }], newest first
    property bool available: true // false when cliphist isn't installed
    property bool confirmClear: false // "Clear history" was chosen once, waiting for the second time

    function refresh() {
        confirmClear = false;
        if (!lister.running)
            lister.running = true;
    }
    // Puts an entry back on the clipboard
    function copy(id) {
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "copy", id]);
    }
    // Removes one entry ("id<TAB>" is all cliphist needs to find it)
    function remove(id) {
        Quickshell.execDetached(["sh", "-c", 'printf "%s\t\n" "$1" | cliphist delete', "remove", id]);
        items = items.filter(c => c.id !== id);
    }
    function clear() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        items = [];
        confirmClear = false;
    }

    // "id<TAB>preview" lines
    Process {
        id: lister
        command: ["cliphist", "list"]
        onExited: code => root.available = code !== 127 && code !== -2
        onRunningChanged: if (!running && !root.available) root.items = []
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = true;
                root.items = text.split("\n").filter(l => l.includes("\t")).slice(0, 100).map(l => {
                    const i = l.indexOf("\t");
                    return { id: l.slice(0, i), text: l.slice(i + 1).trim() };
                });
            }
        }
    }
}

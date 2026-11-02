pragma Singleton
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io

// The screens as Sway sees them, turned-off ones included (swaymsg -t get_outputs):
// on/off and scale, set from the display panel. Both are also written to
// ~/.config/sway/config.d/20-outputs.conf (not synced: it's per machine), so they
// survive a restart.
// One screen always stays on: the last one can't be turned off, and if none is on
// (the screen left on was unplugged, or it's the only one at login) they're all
// turned back on. shell.qml creates this from the start for that.
Singleton {
    id: root

    property var outputs: [] // get_outputs objects: name, active, current_mode, scale...
    readonly property int activeCount: outputs.filter(o => o.active).length

    function setEnabled(name, on) {
        if (!on && activeCount <= 1)
            return;
        apply(name, on ? "enable" : "disable");
    }
    function setScale(name, scale) {
        apply(name, "scale", String(scale));
    }

    // swaymsg output <name> <setting...>, and saved (an output's line for that setting
    // replaced; "enable" just drops its "disable" line).
    // A screen is focused before being turned off: Sway deletes its workspace if it's
    // empty, and Quickshell 0.2.1 crashes on that unless the workspace has focus (fixed
    // upstream in d4c9297, after the version Fedora has).
    function apply(name, setting, value) {
        Quickshell.execDetached(["sh", "-c", `
            [ "$2" = disable ] && swaymsg -q focus output "$1"
            swaymsg output "$1" $2 $3
            f=~/.config/sway/config.d/20-outputs.conf
            touch "$f"
            case $2 in
                enable|disable) sed -i "/^output $1 disable$/d" "$f" ;;
                *) sed -i "/^output $1 $2 /d" "$f" ;;
            esac
            [ "$2" = enable ] || echo "output $1 $2\${3:+ $3}" >> "$f"
        `, "display", name, setting, value ?? ""]);
        rereadAfter.restart();
    }
    function refresh() {
        if (!reader.running)
            reader.running = true;
        else
            rereadAfter.restart();
    }

    // Plugged, unplugged, turned on or off
    Connections {
        target: Quickshell
        function onScreensChanged() { root.refresh(); }
    }
    Connections {
        target: I3
        function onRawEvent(event) {
            if (event.type === "output")
                root.refresh();
        }
    }

    // swaymsg runs in the background: re-read once it's applied
    Timer {
        id: rereadAfter
        interval: 300
        onTriggered: root.refresh()
    }

    Process {
        id: reader
        running: true
        command: ["swaymsg", "-r", "-t", "get_outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list;
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    return;
                }
                root.outputs = list;
                if (list.length > 0 && !list.some(o => o.active)) {
                    for (const o of list)
                        root.apply(o.name, "enable");
                }
                I3.refreshMonitors();
            }
        }
    }
}

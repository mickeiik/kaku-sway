pragma Singleton
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io

// The screens as Sway sees them, turned-off ones included (swaymsg -t get_outputs):
// on/off, scale, HDR and the main screen, set from the display panel. They're also
// written to ~/.config/sway/config.d/20-outputs.conf (not synced: it's per machine),
// so they survive a restart.
// One screen always stays on: the last one can't be turned off, and if none is on
// (the screen left on was unplugged, or it's the only one at login) they're all
// turned back on. shell.qml creates this from the start for that.
//
// The main screen is where workspace 1 is and what has focus at login (the launcher,
// notifications and indicators follow the focused screen). Sway has no "primary".
//
// HDR (Sway 1.12+) is offered for screens whose EDID says they take HDR10, and needs
// Sway's Vulkan renderer (WLR_RENDERER=vulkan at login): when Sway refuses it,
// hdrRefused names that screen, for the panel to say so.
Singleton {
    id: root

    property var outputs: [] // get_outputs objects: name, active, current_mode, scale, hdr...
    readonly property int activeCount: outputs.filter(o => o.active).length
    property var hdrCapable: [] // screen names
    property string hdrRefused: ""
    property string hdrAsked: "" // screen whose HDR was just turned on, checked by hdrCheck
    property string primary: "" // the main screen ("": none chosen)

    function setEnabled(name, on) {
        if (!on && activeCount <= 1)
            return;
        apply(name, on ? "enable" : "disable");
    }
    function setScale(name, scale) {
        apply(name, "scale", String(scale));
    }
    // Workspace 1 moves there now (and is shown); at login it's put there and focused
    function setPrimary(name) {
        primary = name;
        Quickshell.execDetached(["sh", "-c", `
            swaymsg -q "workspace 1 output $1"
            swaymsg -q "workspace number 1; move workspace to output $1"
            f=~/.config/sway/config.d/20-outputs.conf
            touch "$f"
            sed -i '/^workspace 1 output /d; /^exec swaymsg -q focus output /d' "$f"
            printf 'workspace 1 output %s\nexec swaymsg -q focus output %s\n' "$1" "$1" >> "$f"
        `, "main-screen", name]);
        rereadAfter.restart();
    }
    function setHdr(name, on) {
        hdrRefused = "";
        hdrAsked = on ? name : "";
        apply(name, "hdr", on ? "on" : "off");
        if (on)
            hdrCheck.restart();
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
        function onScreensChanged() {
            root.refresh();
            hdrReader.running = true;
        }
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

    // Turning HDR on changes the screen's mode: give it time, then see whether it took
    Timer {
        id: hdrCheck
        interval: 1500
        onTriggered: {
            const o = root.outputs.find(o => o.name === root.hdrAsked);
            if (o && !o.hdr)
                root.hdrRefused = root.hdrAsked;
            root.hdrAsked = "";
        }
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

    // The saved main screen
    Process {
        running: true
        command: ["sh", "-c", "sed -n 's/^workspace 1 output //p' ~/.config/sway/config.d/20-outputs.conf 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.primary = text.trim()
        }
    }

    // Screens that take HDR10: the HDR static metadata block of their EDID (CTA-861
    // extended tag 6) lists the PQ transfer function (bit 2)
    Process {
        id: hdrReader
        running: true
        command: ["python3", "-I", "-c", `
import glob, re
for f in glob.glob("/sys/class/drm/card*-*/edid"):
    d = open(f, "rb").read()
    for i in range(1, len(d) // 128):
        b = d[i * 128:(i + 1) * 128]
        if b[0] != 2:
            continue
        p = 4
        while p < b[2]:
            tag, n = b[p] >> 5, b[p] & 31
            if tag == 7 and n >= 2 and b[p + 1] == 6 and b[p + 2] & 4:
                print(re.sub(r"^card[0-9]+-", "", f.split("/")[4]))
            p += 1 + n
`]
        stdout: StdioCollector {
            onStreamFinished: root.hdrCapable = text.split("\n").filter(n => n)
        }
    }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Night light: a warm screen tint (wlsunset). Three modes, cycled by the bar button:
//   auto  warm from sunset to sunrise, fading in and out (sun times for the time
//         zone's city, from /usr/share/zoneinfo/zone1970.tab: close enough)
//   on    warm all the time
//   off
// The mode is kept in ~/.local/state/quickshell/night-light (auto by default).
Singleton {
    id: root

    property string mode: "auto"
    readonly property bool on: mode !== "off"
    readonly property int temperature: 4000 // Kelvin; lower is warmer
    readonly property string label: mode === "auto" ? "Automatic" : mode === "on" ? "On" : "Off"
    property var location: null // { lat, long } of the time zone

    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/quickshell/night-light"

    function cycle() {
        setMode(mode === "off" ? "auto" : mode === "auto" ? "on" : "off");
    }
    function setMode(m) {
        mode = m;
        restart();
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"', "save", stateFile, m]);
    }
    function restart() {
        sunset.running = false;
        Qt.callLater(() => sunset.running = root.mode === "on" || (root.mode === "auto" && root.location !== null));
    }

    // wlsunset only knows day/night temperatures: "on" makes both warm.
    // setpriv: it stops together with the shell (no tint left on after a restart).
    Process {
        id: sunset
        command: ["setpriv", "--pdeathsig", "TERM", "wlsunset", "-t", String(root.temperature)].concat(
            root.mode === "on" ? ["-T", String(root.temperature + 1)]
            : ["-l", String(root.location?.lat ?? 0), "-L", String(root.location?.long ?? 0)])
    }

    // Saved mode, and the time zone's coordinates ("+4852+00220" = 48°52' N, 2°20' E)
    Process {
        running: true
        command: ["sh", "-c", `
            cat "$1" 2>/dev/null; echo
            zone=$(readlink /etc/localtime | sed 's|.*zoneinfo/||')
            awk -v z="$zone" '$3 == z { print $2; exit }' /usr/share/zoneinfo/zone1970.tab
        `, "read", root.stateFile]
        stdout: StdioCollector {
            onStreamFinished: {
                const [saved, coords] = text.split("\n");
                if (["auto", "on", "off"].includes(saved))
                    root.mode = saved;
                const m = (coords ?? "").match(/^([+-])(\d{2})(\d{2})\d*([+-])(\d{3})(\d{2})/);
                if (m) {
                    const deg = (sign, d, min) => (sign === "-" ? -1 : 1) * (parseInt(d, 10) + parseInt(min, 10) / 60);
                    root.location = { lat: deg(m[1], m[2], m[3]).toFixed(2), long: deg(m[4], m[5], m[6]).toFixed(2) };
                }
                root.restart();
            }
        }
    }
}

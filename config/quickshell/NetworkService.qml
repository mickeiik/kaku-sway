pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Current network state, shared by the bar icon and the network panel
Singleton {
    id: root

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var activeWifi: wifi?.networks.values.find(n => n.connected) ?? null

    // Quickshell's network module only reports Wi-Fi devices, so wired ones come
    // from NetworkManager directly, re-read whenever it reports a change
    property var wired: [] // [{ name, connected }]
    readonly property bool wiredConnected: wired.some(d => d.connected)

    readonly property string icon: wiredConnected ? "" : ""
    readonly property bool online: wiredConnected || activeWifi !== null
    readonly property string label: wiredConnected ? "Ethernet" : activeWifi?.name ?? "Disconnected"

    Process {
        id: wiredReader
        running: true
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device"]
        stdout: StdioCollector {
            onStreamFinished: root.wired = text.split("\n")
                .map(line => line.split(":"))
                .filter(f => f[1] === "ethernet")
                .map(f => ({ name: f[0], connected: f[2].startsWith("connected") })) // incl. "connected (externally)"
        }
    }

    // `nmcli monitor` prints a line on every device/connection change.
    // setpriv: it stops together with the shell instead of lingering after a restart.
    Process {
        id: monitor
        running: true
        command: ["setpriv", "--pdeathsig", "TERM", "nmcli", "monitor"]
        stdout: SplitParser {
            onRead: settle.restart()
        }
        onExited: restartMonitor.start() // e.g. NetworkManager restarted
    }
    Timer {
        id: settle
        interval: 300
        onTriggered: if (!wiredReader.running) wiredReader.running = true
    }
    Timer {
        id: restartMonitor
        interval: 5000
        onTriggered: monitor.running = true
    }
}

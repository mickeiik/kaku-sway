pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth state shared by the bar icon and the panel, and pairing new devices:
// a device is only marked trusted once pairing has succeeded (not before, which would
// trust it even if you rejected the pairing). A service rather than the panel, so it
// still works if the panel is closed meanwhile.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property var devices: adapter?.devices.values ?? []
    readonly property int connectedCount: devices.filter(d => d.connected).length

    property var pending: [] // [{ device, since }] being paired from the panel

    function pair(device) {
        pending = pending.concat([{ device: device, since: Date.now() }]);
        device.pair();
    }

    // Follow pairings under way: trust on success, forget failed or rejected ones
    Timer {
        interval: 1000
        repeat: true
        running: root.pending.length > 0
        onTriggered: {
            root.pending = root.pending.filter(p => {
                if (p.device.paired) {
                    p.device.trusted = true;
                    return false;
                }
                // Not pairing anymore (failed / rejected), after a moment for it to start
                return p.device.pairing || Date.now() - p.since < 5000;
            });
        }
    }
}

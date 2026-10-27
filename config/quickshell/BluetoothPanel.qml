import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

// Paired devices, then devices found nearby (scanning while the panel is open)
Popout {
    id: root

    readonly property var adapter: BluetoothService.adapter
    readonly property bool on: BluetoothService.on
    readonly property var devices: BluetoothService.devices
    readonly property var paired: devices.filter(d => d.paired).sort((a, b) => b.connected - a.connected)
    readonly property var nearby: devices.filter(d => !d.paired && d.deviceName)

    function deviceIcon(d) {
        const i = d.icon || "";
        if (i.includes("audio") || i.includes("headset") || i.includes("headphone")) return "";
        if (i.includes("keyboard")) return "";
        if (i.includes("mouse")) return "";
        if (i.includes("phone")) return "";
        if (i.includes("computer")) return "";
        if (i.includes("gaming") || i.includes("joystick")) return "";
        return "";
    }

    function status(d) {
        const battery = d.batteryAvailable ? Math.round(d.battery * 100) + "%" : "";
        if (d.pairing) return "Pairing…";
        if (d.state === BluetoothDeviceState.Connecting) return "Connecting…";
        if (d.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…";
        if (d.connected) return "Connected" + (battery ? " · " + battery : "");
        return battery;
    }

    // A titled list of devices, with a grey line when it's empty
    component DeviceSection: ColumnLayout {
        id: section

        property string title
        property string emptyText
        property var devices: []
        property bool dim: false
        signal picked(var device)

        Layout.fillWidth: true
        spacing: 0

        SectionLabel { Layout.bottomMargin: 6; text: section.title }

        Label {
            visible: section.devices.length === 0
            text: section.emptyText
            color: Theme.muted
            font.pixelSize: Theme.fontSize - 2
        }

        Repeater {
            model: ScriptModel { values: section.devices }

            MenuRow {
                required property var modelData
                icon: root.deviceIcon(modelData)
                iconColor: section.dim ? Theme.muted : modelData.connected ? Theme.accent : Theme.fg
                text: modelData.name || modelData.deviceName
                status: root.status(modelData)
                checked: modelData.connected
                onClicked: section.picked(modelData)
            }
        }
    }

    cardWidth: 380

    // Look for new devices only while the panel is open
    Component.onCompleted: if (on) adapter.discovering = true
    Component.onDestruction: if (adapter) adapter.discovering = false

    // Turning Bluetooth on from the switch takes a moment: start looking once it's on
    Connections {
        target: root.adapter
        function onEnabledChanged() {
            if (root.adapter.enabled)
                root.adapter.discovering = true;
        }
    }

    PanelHeader {
        title: "Bluetooth"
        detail: "No adapter"
        hasToggle: root.adapter !== null
        checked: root.on
        onToggled: root.adapter.enabled = !root.adapter.enabled
    }

    DeviceSection {
        visible: root.on
        title: "My devices"
        emptyText: "No paired devices"
        devices: root.paired
        onPicked: d => d.connected ? d.disconnect() : d.connect()
    }

    Separator { visible: root.on }

    DeviceSection {
        visible: root.on
        title: "Nearby"
        emptyText: "Searching…"
        devices: root.nearby
        dim: true
        onPicked: d => BluetoothService.pair(d)
    }
}

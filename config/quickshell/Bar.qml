import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: bar

    // Name of the open popup panel ("" = none) and where to centre it
    property string openPanel: ""
    property real panelX: 0
    property var trayItem: null // the tray icon whose menu is open (TrayMenu.qml)

    function toggle(name, item) {
        if (openPanel === name) {
            openPanel = "";
            return;
        }
        panelX = item.mapToItem(null, item.width / 2, 0).x;
        openPanel = name;
    }

    // Same as clicking that panel's button (for qs ipc call bar toggle <name>)
    function toggleByName(name) {
        const button = [clockButton].concat(rightButtons.children).find(b => b.panel === name && b.visible); // hidden: e.g. no battery
        if (button)
            toggle(name, button);
    }

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: Theme.bg
    WlrLayershell.namespace: "qs-bar"

    // Clicking an empty part of the bar closes any open panel
    MouseArea {
        anchors.fill: parent
        onClicked: bar.openPanel = ""
    }

    Workspaces {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        screenName: bar.screen?.name ?? ""
    }

    ClockButton {
        id: clockButton
        anchors.centerIn: parent
        bar: bar
    }

    // Right of the clock: pending updates, screen recording, dictation
    Row {
        anchors.left: clockButton.right
        anchors.verticalCenter: parent.verticalCenter

        UpdatesButton {}
        RecordingButton {}
        DictationButton {}
    }

    // Left of the clock: night light, caffeine
    Row {
        anchors.right: clockButton.left
        anchors.verticalCenter: parent.verticalCenter

        NightLightButton {}
        CaffeineButton { bar: bar }
    }

    RowLayout {
        id: rightButtons

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Tray { bar: bar }
        BluetoothButton { bar: bar }
        NetworkButton { bar: bar }
        BatteryButton { bar: bar }
        VolumeButton { bar: bar }
        DisplayButton { bar: bar }
    }
}

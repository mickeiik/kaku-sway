import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// On-screen indicator for volume and brightness (keys, scrolling on the bar icons):
// icon and level bar near the bottom of the focused screen, updated in place, gone a
// second after the last change.
// Clicks go through it.
PanelWindow {
    id: root

    property string kind: "volume" // volume, mic, brightness, keyboard
    property bool shown: false

    readonly property real level: kind === "brightness" ? BrightnessService.percent / 100 : VolumeService.volume
    readonly property bool hasLevel: kind === "volume" || kind === "brightness"
    readonly property bool off: kind === "volume" ? VolumeService.muted : kind === "mic" ? VolumeService.micMuted : false

    function show(k) {
        kind = k;
        shown = true;
        hideTimer.restart();
    }

    Connections {
        target: VolumeService
        function onIndicate(kind) { root.show(kind); }
    }
    Connections {
        target: KeyboardService
        function onSwitched() { root.show("keyboard"); }
    }
    Connections {
        target: BrightnessService
        function onIndicate() { root.show("brightness"); }
    }
    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: root.shown = false
    }

    screen: Util.focusedScreen
    visible: shown || card.opacity > 0
    anchors.bottom: true
    margins.bottom: 96
    implicitWidth: card.width
    implicitHeight: card.height
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Card {
        id: card

        width: 300
        height: 52
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.shown ? 80 : 250 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 14

            Icon {
                text: root.kind === "brightness" ? ""
                    : root.kind === "mic" ? (root.off ? "\uf131" : "\uf130")
                    : root.kind === "keyboard" ? "\uf11c"
                    : VolumeService.icon
                color: root.off ? Theme.muted : root.kind === "brightness" ? Theme.yellow : Theme.accent
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 22
            }

            // No level for these: the microphone is on or off, the keyboard has a layout
            Label {
                visible: !root.hasLevel
                text: root.kind === "keyboard" ? KeyboardService.name
                    : root.off ? "Microphone off" : "Microphone on"
                color: root.off ? Theme.muted : Theme.fg
                Layout.fillWidth: true
            }

            Rectangle {
                visible: root.hasLevel
                Layout.fillWidth: true
                implicitHeight: 6
                color: Theme.bgAlt

                Rectangle {
                    height: parent.height
                    width: parent.width * Util.clamp01(root.level)
                    color: root.off ? Theme.muted : root.kind === "brightness" ? Theme.yellow : Theme.accent
                    Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}

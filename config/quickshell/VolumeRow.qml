import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

// Mute button + volume slider + value for one audio device
RowLayout {
    id: root

    required property PwNode node
    property string icon: ""
    property string mutedIcon: ""

    property bool showLevel: false

    readonly property bool muted: node?.audio?.muted ?? false
    // Peak amplitude on a -60..0 dB scale, so normal speech is clearly visible
    readonly property real level: peakMonitor.peak > 0 ? Util.clamp01(1 + Math.log10(peakMonitor.peak) / 3) : 0

    Layout.fillWidth: true
    spacing: 12

    Rectangle {
        implicitWidth: 34
        implicitHeight: 34
        color: root.muted ? Theme.bgAlt : Theme.accent

        Icon {
            anchors.centerIn: parent
            text: root.muted ? root.mutedIcon : root.icon
            color: root.muted ? Theme.muted : Theme.bg
            font.pixelSize: Theme.fontSize - 2
        }
        MouseArea {
            anchors.fill: parent
            onClicked: if (root.node) root.node.audio.muted = !root.muted
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        ValueSlider {
            Layout.fillWidth: true
            value: root.node?.audio?.volume ?? 0
            onMoved: v => { if (root.node) root.node.audio.volume = v; }
        }

        // Live level meter (e.g. "is the mic hearing me?")
        Rectangle {
            visible: root.showLevel
            Layout.fillWidth: true
            implicitHeight: 4
            color: Theme.bgAlt

            Rectangle {
                height: parent.height
                width: parent.width * root.level
                color: root.level > 0.9 ? Theme.red : root.level > 0.7 ? Theme.yellow : Theme.green
                Behavior on width { NumberAnimation { duration: 60 } }
            }
        }
    }

    PwNodePeakMonitor {
        id: peakMonitor
        node: root.node
        enabled: root.showLevel && !root.muted
    }

    Label {
        text: root.muted ? "muted" : Math.round((root.node?.audio?.volume ?? 0) * 100) + "%"
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 2
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 52
    }
}

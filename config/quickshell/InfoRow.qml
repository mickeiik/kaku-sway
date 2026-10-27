import QtQuick
import QtQuick.Layouts
import Quickshell

// "Label ........ value" table row for detail sections in panels.
// With copyable: true, clicking the value copies it to the clipboard.
RowLayout {
    id: root

    property string label
    property string value
    property color valueColor: Theme.fg
    property bool copyable: false
    property bool copied: false

    Layout.fillWidth: true
    spacing: 12

    Label {
        text: root.label
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 2
    }

    Label {
        text: root.copied ? "copied ✓" : root.value
        textFormat: Text.PlainText
        color: root.copied ? Theme.green : root.copyable && mouse.containsMouse ? Theme.accent : root.valueColor
        font.pixelSize: Theme.fontSize - 2
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideMiddle
        Layout.fillWidth: true

        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: root.copyable && root.value !== "—"
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Quickshell.execDetached(["wl-copy", root.value]);
                root.copied = true;
                copiedTimer.restart();
            }
        }
    }

    Timer {
        id: copiedTimer
        interval: 1500
        onTriggered: root.copied = false
    }
}

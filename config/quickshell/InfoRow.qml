import QtQuick
import QtQuick.Layouts
import Quickshell

// "Label ........ value" table row for detail sections in panels.
// Long values are cut at the end with "…" instead of widening the panel.
// With copyable: true, clicking the value copies it (in full) to the clipboard.
RowLayout {
    id: root

    property string label
    property string value
    property color valueColor: Theme.fg
    property bool copyable: false
    property int maxValueWidth: -1 // cut values longer than this (px), -1 = the row's space
    property bool copied: false

    Layout.fillWidth: true
    spacing: 12

    Label {
        text: root.label
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 2
    }

    // Pushes a width-limited value to the right edge
    Item {
        visible: root.maxValueWidth >= 0
        Layout.fillWidth: true
    }

    Label {
        text: root.copied ? "copied ✓" : root.value
        textFormat: Text.PlainText
        color: root.copied ? Theme.green : root.copyable && mouse.containsMouse ? Theme.accent : root.valueColor
        font.pixelSize: Theme.fontSize - 2
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        // Never asks for its full width: the space left in the row, or at most maxValueWidth
        Layout.fillWidth: root.maxValueWidth < 0
        Layout.preferredWidth: root.maxValueWidth < 0 ? 0 : Math.min(implicitWidth, root.maxValueWidth)

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

import QtQuick
import QtQuick.Layouts

// Clickable row inside a panel: icon, label, optional status or check mark
Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    property color iconColor: Theme.fg
    property string badge: "" // small extra icon before the check mark, e.g. a lock
    property color badgeColor: Theme.muted
    property bool checked: false
    property string status: "" // shown on the right, replaces the check mark

    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 36
    color: mouse.containsMouse ? Theme.bgAlt : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 12

        Icon {
            visible: root.icon !== ""
            text: root.icon
            color: root.iconColor
            horizontalAlignment: Text.AlignHCenter
            Layout.preferredWidth: 18
        }
        Label {
            text: root.text
            // Plain text: labels can come from outside (Wi-Fi names, Bluetooth devices...)
            textFormat: Text.PlainText
            color: root.checked ? Theme.accent : Theme.fg
            font.pixelSize: Theme.fontSize - 1
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Icon {
            visible: root.badge !== ""
            text: root.badge
            color: root.badgeColor
            font.pixelSize: Theme.fontSize - 4
        }
        Label {
            visible: root.status !== ""
            text: root.status
            textFormat: Text.PlainText
            color: root.checked ? Theme.accent : Theme.muted
            font.pixelSize: Theme.fontSize - 3
        }
        Icon {
            visible: root.checked && root.status === ""
            text: ""
            color: Theme.accent
            font.pixelSize: Theme.fontSize - 2
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}

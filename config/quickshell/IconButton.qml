import QtQuick

// Square icon-only button (reload, settings, close...), with an optional spin while busy
Rectangle {
    id: root

    property string icon
    property color iconColor: mouse.containsMouse ? Theme.fg : Theme.muted
    property bool active: false // highlighted, e.g. its view is open
    property bool spinning: false
    signal clicked()

    implicitWidth: Theme.fontSize + 14
    implicitHeight: implicitWidth
    color: mouse.containsMouse || active ? Theme.bgAlt : "transparent"

    Icon {
        anchors.centerIn: parent
        text: root.icon
        color: root.active ? Theme.accent : root.iconColor

        RotationAnimation on rotation {
            running: root.spinning
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            onStopped: parent.rotation = 0
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}

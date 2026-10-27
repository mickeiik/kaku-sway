import QtQuick

// On/off switch
Rectangle {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 40
    implicitHeight: 22
    color: checked ? Theme.accent : Theme.bgAlt
    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        width: root.height - 6
        height: width
        color: root.checked ? Theme.bg : Theme.fg
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.toggled()
    }
}

import QtQuick
import QtQuick.Layouts

// One option in a row of side-by-side choices: optional icon above a short label
Rectangle {
    id: root

    property string icon: ""
    property color iconColor: Theme.fg
    property string text
    property bool selected: false
    property int padding: 10
    signal clicked()

    Layout.fillWidth: true
    Layout.preferredWidth: 1 // equal widths in a row
    implicitHeight: column.implicitHeight + 2 * padding
    color: selected ? Theme.accent : mouse.containsMouse ? Theme.border : Theme.bgAlt
    Behavior on color { ColorAnimation { duration: 100 } }

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        width: parent.width - 16
        spacing: 5

        Icon {
            visible: root.icon !== ""
            text: root.icon
            color: root.selected ? Theme.bg : root.iconColor
            font.pixelSize: Theme.fontSize
            Layout.alignment: Qt.AlignHCenter
        }
        Label {
            text: root.text
            color: root.selected ? Theme.bg : Theme.fg
            font.pixelSize: Theme.fontSize - 3
            font.bold: root.selected
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}

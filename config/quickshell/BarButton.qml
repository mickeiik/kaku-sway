import QtQuick
import QtQuick.Layouts

// Icon + text item on the bar, with hover highlight, clicks and scrolling.
// With `panel` set, a click toggles that popup panel of the bar.
Rectangle {
    id: root

    property var bar
    property string panel: ""
    property string icon: ""
    property string text: ""
    property string iconFamily: Theme.iconFont
    property color iconColor: Theme.fg
    property color textColor: Theme.fg
    property bool bold: false
    property bool active: panel !== "" && bar?.openPanel === panel

    signal clicked()
    signal rightClicked()
    signal scrolled(int steps) // +1 per notch "up"

    implicitWidth: row.implicitWidth + 20
    implicitHeight: Theme.barHeight
    color: mouse.containsMouse || active ? Theme.bgAlt : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Icon {
            visible: root.icon !== ""
            text: root.icon
            color: root.iconColor
            font.family: root.iconFamily
            font.weight: root.iconFamily === Theme.iconFont ? Font.Black : Font.Normal
        }
        Label {
            visible: root.text !== ""
            text: root.text
            color: root.textColor
            font.bold: root.bold
        }
    }

    MouseArea {
        id: mouse
        property real wheelAcc: 0

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.RightButton)
                root.rightClicked();
            else if (root.panel !== "")
                root.bar.toggle(root.panel, root);
            else
                root.clicked();
        }
        onWheel: w => {
            wheelAcc += Util.wheelDelta(w);
            while (wheelAcc >= 120) { wheelAcc -= 120; root.scrolled(1); }
            while (wheelAcc <= -120) { wheelAcc += 120; root.scrolled(-1); }
        }
    }
}

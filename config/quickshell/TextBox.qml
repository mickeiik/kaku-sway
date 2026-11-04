import QtQuick
import QtQuick.Layouts

// One-line text field for panels, with a grey hint while empty
Rectangle {
    id: root

    property alias text: input.text
    property alias echoMode: input.echoMode
    property string placeholder: ""
    property bool error: false
    signal accepted()

    function clear() {
        input.text = "";
    }
    function takeFocus() {
        input.forceActiveFocus();
    }

    Layout.fillWidth: true
    implicitHeight: Theme.fontSize + 18
    color: Theme.bgAlt
    border.color: error ? Theme.red : input.activeFocus ? Theme.accent : Theme.border
    border.width: 1

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
        selectionColor: Theme.accent
        selectedTextColor: Theme.bg
        selectByMouse: true
        onAccepted: root.accepted()
        onTextChanged: root.error = false

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.placeholder
            color: Theme.muted
            font.pixelSize: Theme.fontSize - 1
        }
    }
}

import QtQuick
import QtQuick.Layouts

// Label with an on/off switch on the right
RowLayout {
    id: root

    property string text
    property bool checked
    signal toggled()

    Layout.fillWidth: true

    Label {
        text: root.text
        font.pixelSize: Theme.fontSize - 1
        Layout.fillWidth: true
    }
    Toggle {
        checked: root.checked
        onToggled: root.toggled()
    }
}

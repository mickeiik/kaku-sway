import QtQuick
import QtQuick.Layouts

// Panel title, with either a detail text or an on/off switch on the right
RowLayout {
    id: root

    property string title
    property string detail: ""
    property bool hasToggle: false
    property bool checked: false
    signal toggled()

    Layout.fillWidth: true

    Label {
        text: root.title
        font.pixelSize: Theme.fontSize + 1
        font.bold: true
        Layout.fillWidth: true
    }
    Label {
        visible: !root.hasToggle
        text: root.detail
        textFormat: Text.PlainText // e.g. the Wi-Fi name
        color: Theme.muted
    }
    Toggle {
        visible: root.hasToggle
        checked: root.checked
        onToggled: root.toggled()
    }
}

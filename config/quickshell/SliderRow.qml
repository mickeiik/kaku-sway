import QtQuick
import QtQuick.Layouts

// Icon, slider and value, e.g. brightness in the display panel
RowLayout {
    id: root

    property string icon
    property color iconColor: Theme.fg
    property real value: 0 // 0..1
    property string label
    signal moved(real value)

    Layout.fillWidth: true
    spacing: 12

    Icon {
        text: root.icon
        color: root.iconColor
        horizontalAlignment: Text.AlignHCenter
        Layout.preferredWidth: 18
    }
    ValueSlider {
        Layout.fillWidth: true
        value: root.value
        onMoved: v => root.moved(v)
    }
    Label {
        text: root.label
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 2
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 44
    }
}

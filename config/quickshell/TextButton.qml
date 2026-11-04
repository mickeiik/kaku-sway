import QtQuick
import QtQuick.Layouts

// Small button with a label (and an optional icon) for panels; enabled: false greys it out.
// With maxWidth, the label is cut with "…" to fit, but not its suffix.
Rectangle {
    id: root

    property string text
    property string icon: ""
    property string suffix: "" // after the label, never cut (e.g. a file's extension and size)
    property color fill: Theme.bgAlt // on a card: Theme.border, to stand out from it
    signal clicked()

    // At most this wide: the label is cut to fit (the icon and suffix never are)
    property real maxWidth: Infinity
    readonly property real fixedWidth: 20 + (icon !== "" ? iconItem.implicitWidth + 6 : 0) + (suffix !== "" ? suffixLabel.implicitWidth : 0)

    implicitWidth: Math.min(maxWidth, fixedWidth + label.implicitWidth)
    implicitHeight: Theme.fontSize + 18
    color: enabled && mouse.containsMouse ? Theme.accent : fill
    opacity: enabled ? 1 : 0.5
    Behavior on color { ColorAnimation { duration: 100 } }

    Row {
        anchors.centerIn: parent
        spacing: 6

        Icon {
            id: iconItem
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            color: mouse.containsMouse && root.enabled ? Theme.bg : Theme.fg
        }
        // The suffix right after the label's visible text (a cut label ends a bit short
        // of its width: whole characters)
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: label.contentWidth + (suffixLabel.visible ? suffixLabel.implicitWidth : 0)
            height: label.implicitHeight

            Label {
                id: label
                width: Math.max(0, Math.min(implicitWidth, root.width - root.fixedWidth))
                text: root.text
                textFormat: Text.PlainText
                color: mouse.containsMouse && root.enabled ? Theme.bg : Theme.fg
                font.pixelSize: Theme.fontSize - 2
                elide: Text.ElideRight
            }
            Label {
                id: suffixLabel
                x: label.contentWidth
                visible: root.suffix !== ""
                text: root.suffix
                textFormat: Text.PlainText
                color: mouse.containsMouse && root.enabled ? Theme.bg : Theme.fg
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}

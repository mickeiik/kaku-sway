import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// A card that drops down under the bar. It sits in a transparent layer covering
// the screen below the bar, so clicking anywhere outside the card (or pressing
// Escape) closes it, while the bar itself stays usable (clicks, scrolling).
PanelWindow {
    id: root

    required property var bar
    property int cardWidth: 340
    default property alias content: column.data

    function close() {
        bar.openPanel = "";
    }

    screen: bar.screen
    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: Theme.barHeight
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-popout"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Card {
        id: card

        width: root.cardWidth
        height: column.implicitHeight + 32
        x: Math.max(8, Math.min(root.bar.panelX - width / 2, root.width - width - 8))
        y: 8
        focus: true
        Keys.onEscapePressed: root.close()

        opacity: 0
        transform: Translate { id: slide; y: -10 }
        Component.onCompleted: enter.start()

        ParallelAnimation {
            id: enter
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { target: slide; property: "y"; to: 0; duration: 200; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10
        }
    }
}

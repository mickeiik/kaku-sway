import QtQuick

// Horizontal 0..1 slider: drag, click or scroll
Item {
    id: root

    property real value: 0
    signal moved(real value)

    implicitWidth: 200
    implicitHeight: 22

    readonly property real shown: Util.clamp01(value)

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        color: Theme.bgAlt

        Rectangle {
            width: parent.width * root.shown
            height: parent.height
            color: Theme.accent
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: (root.width - width) * root.shown
        width: mouse.pressed || mouse.containsMouse ? 16 : 14
        height: width
        color: Theme.fg
        Behavior on width { NumberAnimation { duration: 100 } }
    }

    MouseArea {
        id: mouse

        function set(mx) {
            root.moved(Util.clamp01(mx / width));
        }

        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        onPressed: m => set(m.x)
        onPositionChanged: m => { if (pressed) set(m.x); }
        // Touchpads send many small events: count whole notches (120 units), like the bar.
        // Sideways scrolling (no vertical part) is ignored.
        property real wheelAcc: 0
        onWheel: w => {
            wheelAcc += Util.wheelDelta(w);
            while (wheelAcc >= 120) { wheelAcc -= 120; root.moved(Util.scrollStep(root.value, 0.05)); }
            while (wheelAcc <= -120) { wheelAcc += 120; root.moved(Util.scrollStep(root.value, -0.05)); }
        }
    }
}

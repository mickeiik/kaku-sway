import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// On-screen indicator while dictating (Super+D): the microphone level as a row of
// squares that rise with your voice, then "Writing…" while voxtype turns it into text.
// Above the volume indicator (Osd.qml), so both can show. Clicks go through it.
PanelWindow {
    id: root

    readonly property bool shown: DictationService.busy
    readonly property bool listening: DictationService.state === "recording"
    readonly property bool muted: listening && DictationService.micMuted

    screen: Util.focusedScreen
    visible: shown || card.opacity > 0
    anchors.bottom: true
    margins.bottom: 160
    implicitWidth: card.width
    implicitHeight: card.height
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-dictation"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Card {
        id: card

        width: 300
        height: 52
        border.color: root.muted || root.listening ? Theme.red : Theme.yellow
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.shown ? 80 : 250 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 14

            Icon {
                text: root.muted ? "" : root.listening ? "" : ""
                color: root.muted || root.listening ? Theme.red : Theme.yellow
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 22
            }

            // Level history, newest on the right: each column is a stack of squares
            Row {
                id: meter

                readonly property int squares: 5
                readonly property int size: 4

                visible: root.listening && !root.muted
                spacing: 2
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: DictationService.levels

                    Column {
                        required property real modelData
                        required property int index
                        readonly property int lit: Math.max(1, Math.round(modelData * meter.squares))

                        spacing: 2
                        // Older columns fade out to the left
                        opacity: 0.35 + 0.65 * index / (DictationService.historyLength - 1)

                        Repeater {
                            model: meter.squares

                            Rectangle {
                                required property int index
                                // Squares light up from the bottom
                                readonly property bool on: meter.squares - 1 - index < parent.lit

                                width: meter.size
                                height: meter.size
                                color: on ? Theme.accent : Theme.bgAlt
                            }
                        }
                    }
                }
            }

            Label {
                visible: !meter.visible
                text: root.muted ? "Microphone is muted" : "Writing…"
                color: root.muted ? Theme.red : Theme.fg
                Layout.fillWidth: true
            }

            Label {
                visible: root.listening
                text: Util.duration(DictationService.seconds)
                color: Theme.muted
            }
        }
    }
}

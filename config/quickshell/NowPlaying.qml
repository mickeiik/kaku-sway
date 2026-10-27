import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

// What's playing (Spotify, a browser video...) with previous / play-pause / next.
// The player comes from MediaService; hidden when there's none.
ColumnLayout {
    id: root

    readonly property MprisPlayer player: MediaService.player

    visible: player !== null
    Layout.fillWidth: true
    spacing: 10

    SectionLabel { Layout.topMargin: 0; text: "Playing" }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        // Cover art, else a note
        Rectangle {
            implicitWidth: 48
            implicitHeight: 48
            color: Theme.bgAlt

            Icon {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                text: ""
                color: Theme.muted
            }
            Image {
                id: cover
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                sourceSize: Qt.size(96, 96)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            // Names come from the player: plain text
            Label {
                text: root.player?.trackTitle || root.player?.identity || ""
                textFormat: Text.PlainText
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Label {
                visible: text !== ""
                text: root.player?.trackArtist ?? ""
                textFormat: Text.PlainText
                color: Theme.muted
                font.pixelSize: Theme.fontSize - 2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Repeater {
            model: [
                { icon: "", enabled: root.player?.canGoPrevious ?? false, run: () => root.player.previous() },
                { icon: root.player?.isPlaying ? "" : "", enabled: root.player?.canTogglePlaying ?? false, run: () => root.player.togglePlaying() },
                { icon: "", enabled: root.player?.canGoNext ?? false, run: () => root.player.next() }
            ]

            Rectangle {
                required property var modelData

                implicitWidth: 34
                implicitHeight: 34
                color: controlMouse.containsMouse && modelData.enabled ? Theme.bgAlt : "transparent"
                opacity: modelData.enabled ? 1 : 0.35

                Icon {
                    anchors.centerIn: parent
                    text: parent.modelData.icon
                    font.pixelSize: Theme.fontSize - 2
                }
                MouseArea {
                    id: controlMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (parent.modelData.enabled) parent.modelData.run()
                }
            }
        }
    }
}

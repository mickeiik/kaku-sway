import QtQuick
import QtQuick.Layouts

Popout {
    id: root

    property real now: Date.now()

    // "in 1 h 05 min" within a day, else the day and time ("jeu. 5 nov., 09:00")
    function resetText(date) {
        const s = (date.getTime() - now) / 1000;
        if (s <= 60)
            return "Resets now";
        if (s < 24 * 3600) {
            const h = Math.floor(s / 3600);
            const m = Math.floor((s % 3600) / 60);
            return "Resets in " + (h > 0 ? h + " h " + String(m).padStart(2, "0") + " min" : m + " min");
        }
        return "Resets " + date.toLocaleString(Theme.locale, "ddd d MMM, HH:mm");
    }

    function ago(ms) {
        const m = Math.floor((now - ms) / 60000);
        return m < 1 ? "just now" : m < 60 ? m + " min ago" : Math.floor(m / 60) + " h ago";
    }

    cardWidth: 400

    Timer {
        interval: 30 * 1000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    RowLayout {
        Layout.fillWidth: true

        Label {
            text: "AI usage"
            font.pixelSize: Theme.fontSize + 1
            font.bold: true
            Layout.fillWidth: true
        }

        // Check again now (otherwise every 5 minutes)
        Rectangle {
            implicitWidth: Theme.fontSize + 14
            implicitHeight: implicitWidth
            color: reload.containsMouse ? Theme.bgAlt : "transparent"

            Icon {
                anchors.centerIn: parent
                text: "\uf2f9"
                color: AiUsageService.busy ? Theme.accent : reload.containsMouse ? Theme.fg : Theme.muted

                RotationAnimation on rotation {
                    running: AiUsageService.busy
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    onStopped: parent.rotation = 0
                }
            }
            MouseArea {
                id: reload
                anchors.fill: parent
                hoverEnabled: true
                onClicked: AiUsageService.refresh(true)
            }
        }
    }

    Repeater {
        model: AiUsageService.shown

        ColumnLayout {
            id: provider

            required property var modelData
            required property int index

            Layout.fillWidth: true
            spacing: 10

            Separator {}

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                PathIcon { path: provider.modelData.iconPath }
                Label {
                    text: provider.modelData.name
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                    Layout.fillWidth: true
                }
                Label {
                    text: provider.modelData.plan
                    color: Theme.muted
                }
            }

            Repeater {
                model: provider.modelData.limits

                ColumnLayout {
                    id: limit

                    required property var modelData
                    readonly property color levelColor: AiUsageService.levelColor(modelData.percent, Theme.accent)

                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        Label {
                            text: limit.modelData.name
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Label {
                            text: limit.modelData.percent + "%"
                            color: AiUsageService.levelColor(limit.modelData.percent, Theme.fg)
                            font.bold: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        color: Theme.bgAlt

                        Rectangle {
                            height: parent.height
                            width: parent.width * Math.min(limit.modelData.percent, 100) / 100
                            color: limit.levelColor
                        }
                    }

                    Label {
                        text: root.resetText(limit.modelData.resetsAt)
                        color: Theme.muted
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }

            // Limit resets one can use now, one line each, with when it expires
            Repeater {
                model: provider.modelData.resets

                RowLayout {
                    id: reset

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 8

                    Icon {
                        text: "\uf1da"
                        color: Theme.green
                    }
                    Label {
                        text: reset.modelData.name
                        color: Theme.green
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        visible: reset.modelData.until !== null
                        text: reset.modelData.until?.toLocaleString(Theme.locale, "d MMM, HH:mm") ?? ""
                        color: Theme.muted
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }

            Label {
                readonly property var p: provider.modelData

                visible: p.error !== "" || !p.updated
                Layout.fillWidth: true
                text: p.error !== "" ? p.error + (p.updated ? " · numbers from " + root.ago(p.updated) : "") : "Loading…"
                color: p.error !== "" ? Theme.yellow : Theme.muted
                font.pixelSize: Theme.fontSize - 2
                wrapMode: Text.Wrap
            }
        }
    }

    // All providers are checked together
    Separator { visible: AiUsageService.updated > 0 }

    Label {
        visible: AiUsageService.updated > 0
        text: "Updated " + root.ago(AiUsageService.updated)
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 2
    }
}

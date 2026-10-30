import QtQuick

// AI subscription usage: each provider's logo, colored by how far along its weekly
// limit is, and how much of its 5-hour session limit is used, colored the same
// way; click for all limits, when they reset and limit resets
BarButton {
    visible: AiUsageService.shown.length > 0
    panel: "ai"
    implicitWidth: providers.implicitWidth + 20

    Row {
        id: providers
        anchors.centerIn: parent
        spacing: 12

        Repeater {
            model: AiUsageService.shown

            Row {
                id: provider

                required property var modelData
                readonly property var session: modelData.session

                spacing: 6

                PathIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    path: provider.modelData.iconPath
                    color: provider.modelData.weekly ? AiUsageService.progressColor(provider.modelData.weekly.percent) : Theme.muted
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: provider.session ? provider.session.percent + "%" : "–"
                    color: provider.session ? AiUsageService.progressColor(provider.session.percent) : Theme.muted
                }
            }
        }
    }
}

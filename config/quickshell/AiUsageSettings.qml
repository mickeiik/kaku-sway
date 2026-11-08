import QtQuick
import QtQuick.Layouts

// Which AI subscriptions the bar and panel show (AiUsageService). A hidden one
// isn't checked at all: no request is made for its usage until it's shown again.
ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 10

    SectionLabel { text: "Subscriptions" }

    Repeater {
        model: AiUsageService.providers

        RowLayout {
            id: provider

            required property var modelData
            readonly property bool shown: AiUsageService.isProviderShown(modelData.providerId)

            Layout.fillWidth: true
            spacing: 10

            PathIcon {
                path: provider.modelData.iconPath
                color: provider.shown ? Theme.fg : Theme.muted
            }
            Label {
                text: provider.modelData.name
                color: provider.shown ? Theme.fg : Theme.muted
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Label {
                visible: !provider.modelData.signedIn
                text: "Not signed in"
                color: Theme.muted
                font.pixelSize: Theme.fontSize - 3
            }
            Toggle {
                checked: provider.shown
                onToggled: AiUsageService.setProviderShown(provider.modelData.providerId, !provider.shown)
            }
        }
    }

    Label {
        text: "Saved in ~/.config/kaku/ai-usage.json."
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 3
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }
}

import QtQuick
import QtQuick.Layouts
import Quickshell

Popout {
    id: root

    readonly property var scales: [1, 1.25, 1.5, 2]
    readonly property int textRange: TextSizeService.maxPx - TextSizeService.minPx

    cardWidth: 340

    // Monitors' brightness may have been changed on the monitor itself
    Component.onCompleted: {
        DisplayService.refresh();
        BrightnessService.refresh();
    }

    PanelHeader { title: "Display" }

    SliderRow {
        icon: "\uf031"
        iconColor: Theme.accent
        value: (TextSizeService.px - TextSizeService.minPx) / root.textRange
        label: TextSizeService.px + " px"
        onMoved: v => TextSizeService.set(TextSizeService.minPx + v * root.textRange)
    }

    // Per screen: on/off, brightness, scale
    Repeater {
        model: DisplayService.outputs

        ColumnLayout {
            id: screen
            required property var modelData
            readonly property string name: modelData.name
            readonly property bool active: modelData.active
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                SectionLabel {
                    text: [screen.name, screen.modelData.model,
                        screen.active ? screen.modelData.current_mode?.width + "×" + screen.modelData.current_mode?.height : "Off"]
                        .filter(s => s).join(" · ")
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                // The last screen on can't be turned off
                Toggle {
                    Layout.topMargin: 6
                    checked: screen.active
                    enabled: !screen.active || DisplayService.activeCount > 1
                    opacity: enabled ? 1 : 0.4
                    onToggled: DisplayService.setEnabled(screen.name, !screen.active)
                }
            }

            SliderRow {
                visible: screen.active && BrightnessService.has(screen.name)
                icon: "\uf185"
                iconColor: Theme.yellow
                value: BrightnessService.level(screen.name) / 100
                label: BrightnessService.level(screen.name) + "%"
                onMoved: v => BrightnessService.set(screen.name, v * 100)
            }

            RowLayout {
                visible: screen.active
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.scales

                    SegmentButton {
                        required property real modelData
                        text: Math.round(modelData * 100) + "%"
                        padding: 7
                        selected: Math.abs(screen.modelData.scale - modelData) < 0.01
                        onClicked: DisplayService.setScale(screen.name, modelData)
                    }
                }
            }
        }
    }
}

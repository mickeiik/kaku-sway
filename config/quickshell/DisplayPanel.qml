import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.I3

Popout {
    id: root

    readonly property var scales: [1, 1.25, 1.5, 2]
    readonly property int textRange: TextSizeService.maxPx - TextSizeService.minPx

    cardWidth: 340

    PanelHeader { title: "Display" }

    SliderRow {
        visible: BrightnessService.available // no backlight on external monitors
        icon: ""
        iconColor: Theme.yellow
        value: BrightnessService.percent / 100
        label: BrightnessService.percent + "%"
        onMoved: v => BrightnessService.set(v * 100)
    }

    SliderRow {
        icon: ""
        iconColor: Theme.accent
        value: (TextSizeService.px - TextSizeService.minPx) / root.textRange
        label: TextSizeService.px + " px"
        onMoved: v => TextSizeService.set(TextSizeService.minPx + v * root.textRange)
    }

    // Scale picker, per screen
    Repeater {
        model: I3.monitors

        ColumnLayout {
            id: screen
            required property var modelData
            Layout.fillWidth: true
            spacing: 6

            SectionLabel {
                text: screen.modelData.name + " · " + screen.modelData.lastIpcObject.current_mode?.width + "×" + screen.modelData.lastIpcObject.current_mode?.height
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.scales

                    SegmentButton {
                        required property real modelData
                        text: Math.round(modelData * 100) + "%"
                        padding: 7
                        selected: Math.abs(screen.modelData.scale - modelData) < 0.01
                        onClicked: {
                            // Apply now, and save it so it survives a restart
                            Quickshell.execDetached(["sh", "-c", `
                                swaymsg output "$1" scale "$2"
                                f=~/.config/sway/config.d/20-outputs.conf
                                touch "$f"
                                sed -i "/^output $1 scale /d" "$f"
                                echo "output $1 scale $2" >> "$f"
                            `, "set-scale", screen.modelData.name, String(modelData)]);
                            rereadMonitors.restart();
                        }
                    }
                }
            }
        }
    }

    // swaymsg runs in the background: re-read the screens once it's applied
    Timer {
        id: rereadMonitors
        interval: 300
        onTriggered: I3.refreshMonitors()
    }
}

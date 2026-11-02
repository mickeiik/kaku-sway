import QtQuick
import QtQuick.Layouts
import Quickshell

// One framed card per screen (on/off, brightness, scale, main screen, HDR), then the
// shell's text size
Popout {
    id: root

    readonly property var scales: [1, 1.25, 1.5, 2]
    readonly property int textRange: TextSizeService.maxPx - TextSizeService.minPx

    // Small on/off button with an icon, side by side with others under a screen
    component Chip: Rectangle {
        id: chip

        property string icon
        property string text
        property bool checked: false
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1 // equal widths in a row
        implicitHeight: row.implicitHeight + 14
        color: checked ? Theme.accent : mouse.containsMouse ? Theme.border : Theme.bgAlt
        Behavior on color { ColorAnimation { duration: 100 } }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 8

            Icon {
                text: chip.icon
                color: chip.checked ? Theme.bg : Theme.fg
                font.pixelSize: Theme.fontSize - 3
            }
            Label {
                text: chip.text
                color: chip.checked ? Theme.bg : Theme.fg
                font.pixelSize: Theme.fontSize - 2
                font.bold: chip.checked
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: chip.clicked()
        }
    }

    cardWidth: 380

    // Monitors' brightness may have been changed on the monitor itself
    Component.onCompleted: {
        DisplayService.refresh();
        BrightnessService.refresh();
    }

    PanelHeader { title: "Display" }

    Repeater {
        model: DisplayService.outputs

        Rectangle {
            id: screen
            required property var modelData
            readonly property string name: modelData.name
            readonly property bool active: modelData.active
            readonly property bool builtIn: /^eDP/.test(name)
            readonly property var mode: modelData.current_mode
            readonly property bool multi: DisplayService.activeCount > 1
            readonly property bool hdrCapable: DisplayService.hdrCapable.includes(name)

            Layout.fillWidth: true
            implicitHeight: body.implicitHeight + 24
            color: "transparent"
            border.color: Theme.bgAlt
            border.width: 1

            ColumnLayout {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 10

                // Screen icon, name and mode, on/off switch
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        implicitWidth: 34
                        implicitHeight: 34
                        color: screen.active ? Theme.accent : Theme.bgAlt
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Icon {
                            anchors.centerIn: parent
                            text: screen.builtIn ? "" : ""
                            color: screen.active ? Theme.bg : Theme.muted
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: screen.builtIn ? "Built-in screen"
                                : screen.modelData.model && screen.modelData.model !== "Unknown" ? screen.modelData.model
                                : screen.name
                            textFormat: Text.PlainText // from the screen's EDID
                            color: screen.active ? Theme.fg : Theme.muted
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: [screen.name,
                                screen.active && screen.mode ? screen.mode.width + "×" + screen.mode.height : "Off",
                                screen.active && screen.mode?.refresh ? Math.round(screen.mode.refresh / 1000) + " Hz" : ""]
                                .filter(s => s).join(" · ")
                            color: Theme.muted
                            font.pixelSize: Theme.fontSize - 3
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // The last screen on can't be turned off
                    Toggle {
                        checked: screen.active
                        enabled: !screen.active || screen.multi
                        opacity: enabled ? 1 : 0.4
                        onToggled: DisplayService.setEnabled(screen.name, !screen.active)
                    }
                }

                SliderRow {
                    visible: screen.active && BrightnessService.has(screen.name)
                    icon: ""
                    iconColor: Theme.yellow
                    value: BrightnessService.level(screen.name) / 100
                    label: BrightnessService.level(screen.name) + "%"
                    onMoved: v => BrightnessService.set(screen.name, v * 100)
                }

                RowLayout {
                    visible: screen.active
                    Layout.fillWidth: true
                    spacing: 6

                    Icon {
                        text: ""
                        color: Theme.cyan
                        horizontalAlignment: Text.AlignHCenter
                        Layout.preferredWidth: 18
                        Layout.rightMargin: 6 // lines the buttons up with the slider above
                    }
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

                RowLayout {
                    visible: screen.active && (screen.multi || screen.hdrCapable)
                    Layout.fillWidth: true
                    spacing: 6

                    // With several screens on: picking another one moves the main screen there
                    Chip {
                        visible: screen.multi
                        readonly property bool isMain: DisplayService.primary === screen.name
                        icon: ""
                        text: isMain ? "Main screen" : "Make main"
                        checked: isMain
                        enabled: !isMain
                        onClicked: DisplayService.setPrimary(screen.name)
                    }
                    // Only for screens that take HDR10
                    Chip {
                        visible: screen.hdrCapable
                        icon: ""
                        text: "HDR"
                        checked: screen.modelData.hdr ?? false
                        onClicked: DisplayService.setHdr(screen.name, !checked)
                    }
                }

                Label {
                    visible: screen.active && DisplayService.hdrRefused === screen.name
                    text: "Sway couldn't turn HDR on: it needs its Vulkan renderer (WLR_RENDERER=vulkan at login)."
                    color: Theme.yellow
                    font.pixelSize: Theme.fontSize - 2
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
        }
    }

    // For the whole shell, on every screen
    SectionLabel { text: "Text size" }

    SliderRow {
        icon: ""
        iconColor: Theme.accent
        value: (TextSizeService.px - TextSizeService.minPx) / root.textRange
        label: TextSizeService.px + " px"
        onMoved: v => TextSizeService.set(TextSizeService.minPx + v * root.textRange)
    }
}

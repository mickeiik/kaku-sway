import QtQuick

// Display icon: click for the display panel, scroll for this screen's brightness (if
// it has one: a backlight, or a monitor with DDC/CI)
BarButton {
    id: root

    panel: "display"
    icon: "\uf108"
    onScrolled: steps => BrightnessService.step(root.bar.screen?.name ?? "", steps)
}

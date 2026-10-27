import QtQuick

// Display icon: click for the display panel, scroll for brightness (if the screen has a backlight)
BarButton {
    panel: "display"
    icon: ""
    onScrolled: steps => {
        if (BrightnessService.available)
            BrightnessService.step(steps);
    }
}

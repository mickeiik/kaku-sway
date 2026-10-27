import QtQuick
import Quickshell.Wayland

// Caffeine: while on, the screen never dims, locks or sleeps on idle
BarButton {
    id: root

    icon: ""
    iconColor: CaffeineService.on ? Theme.yellow : Theme.muted
    onClicked: CaffeineService.on = !CaffeineService.on

    IdleInhibitor {
        window: root.bar
        enabled: CaffeineService.on
    }
}

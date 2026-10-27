import QtQuick

// Battery level; click for battery details and power mode
BarButton {
    visible: BatteryService.present
    panel: "battery"
    icon: BatteryService.icon
    iconColor: BatteryService.charging || BatteryService.full ? Theme.green
        : BatteryService.level < 0.2 ? BatteryService.levelColor : Theme.fg
    text: Math.round(BatteryService.level * 100) + "%"
}

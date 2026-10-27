import QtQuick

BarButton {
    panel: "network"
    icon: NetworkService.icon
    iconColor: NetworkService.online ? Theme.fg : Theme.muted
}

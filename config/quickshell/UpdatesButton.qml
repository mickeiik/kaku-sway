import QtQuick

// Shown next to the clock when updates are available; click to update
BarButton {
    visible: UpdatesService.count > 0
    icon: ""
    iconColor: Theme.yellow
    text: UpdatesService.count
    onClicked: UpdatesService.runUpdate()
}

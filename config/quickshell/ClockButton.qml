import QtQuick
import Quickshell

BarButton {
    SystemClock { id: clock; precision: SystemClock.Minutes }

    panel: "calendar"
    text: Theme.locale.toString(clock.date, "dddd d MMMM HH:mm")
    bold: true
}

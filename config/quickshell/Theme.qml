pragma Singleton
import QtQuick
import Quickshell

// Tokyo Night
Singleton {
    readonly property color bg: "#1a1b26"
    readonly property color bgAlt: "#292e42"
    readonly property color border: "#414868"
    readonly property color fg: "#c0caf5"
    readonly property color muted: "#565f89"
    readonly property color accent: "#7aa2f7"
    readonly property color green: "#9ece6a"
    readonly property color yellow: "#e0af68"
    readonly property color red: "#f7768e"
    readonly property color darkRed: "#db4b4b"
    readonly property color orange: "#ff9e64"
    readonly property color purple: "#bb9af7"
    readonly property color cyan: "#7dcfff"
    readonly property color teal: "#2ac3de"

    // Language for dates (day and month names, first day of the week)
    readonly property var locale: Qt.locale("fr_FR")

    readonly property string font: "JetBrains Mono"
    readonly property string iconFont: "Font Awesome 6 Free"
    readonly property int fontSize: TextSizeService.px
    readonly property int barHeight: fontSize + 17
}

import QtQuick

// The framed box used by the bar panels and the launcher. Clicks on it are
// swallowed, so they don't reach the "click outside to close" area behind it.
Rectangle {
    color: Theme.bg
    // Same as Sway's focused window border
    border.color: Theme.accent
    border.width: 2

    MouseArea { anchors.fill: parent }
}

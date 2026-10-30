import QtQuick

// Shown next to the clock while dictating (red: listening, yellow: writing it out);
// click to cancel
BarButton {
    visible: DictationService.busy
    icon: "\uf130"
    iconColor: DictationService.state === "recording" ? Theme.red : Theme.yellow
    text: DictationService.state === "recording" ? "Listening" : "Writing"
    onClicked: DictationService.cancel()
}

import QtQuick

// Shown next to the clock while recording the screen; click to stop
BarButton {
    visible: RecordingService.recording
    icon: ""
    iconColor: Theme.red
    text: Util.duration(RecordingService.seconds)
    onClicked: RecordingService.stop()
}

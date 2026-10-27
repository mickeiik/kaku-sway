import QtQuick

// Volume icon: click for the sound panel, scroll to change, right click to mute.
// Blue while something is playing (the panel then shows the player), grey when muted.
BarButton {
    panel: "volume"
    icon: VolumeService.icon
    iconColor: VolumeService.muted ? Theme.muted : MediaService.playing ? Theme.accent : Theme.fg
    text: VolumeService.muted ? "muted" : Math.round(VolumeService.volume * 100) + "%"
    textColor: VolumeService.muted ? Theme.muted : Theme.fg

    onRightClicked: VolumeService.toggleMute()
    onScrolled: steps => VolumeService.step(steps)
}

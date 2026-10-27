pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The media player to show (Spotify, a browser video...): the one playing, else the
// first one. Shared by the sound panel's Playing section and the bar's volume icon.
Singleton {
    // playerctld only mirrors the other players
    readonly property var players: Mpris.players.values.filter(p => !/playerctld/i.test(p.dbusName))
    readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool playing: player?.isPlaying ?? false
}

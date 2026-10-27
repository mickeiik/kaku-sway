pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Default speaker and microphone, shared by the bar and the volume keys (their Sway
// bindings call `qs ipc call volume hold 1` / `-1` on press and `release` on release,
// `mute`, `micMute`).
//
// Held keys are repeated here, not by Sway: Sway stops repeating a key at the next key
// event of any kind, so pressing Down before Up was fully released gave a single step.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property string icon: muted ? "" : volume < 0.34 ? "" : volume < 0.67 ? "" : ""

    signal indicate(string kind) // show the on-screen indicator: "volume" or "mic"

    property int holding: 0 // direction of the volume key being held, 0 = none

    PwObjectTracker { objects: [root.sink, root.source] }

    // Steps of 5% (keys and scrolling on the bar icon)
    function step(steps) {
        if (sink?.audio)
            sink.audio.volume = Util.scrollStep(volume, steps * 0.05);
        indicate("volume");
    }
    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !muted;
    }

    IpcHandler {
        target: "volume"

        // Key pressed: one step now, then repeats like a keyboard (600 ms, then 25 per second)
        function hold(steps: int): void {
            root.holding = steps;
            root.step(steps);
            repeatDelay.restart();
            repeat.stop();
        }
        // Key released: stops only if it's the key being held (not one released late)
        function release(steps: int): void {
            if (root.holding === steps) {
                root.holding = 0;
                repeatDelay.stop();
                repeat.stop();
            }
        }
        function mute(): void {
            root.toggleMute();
            root.indicate("volume");
        }
        function micMute(): void {
            if (root.source?.audio)
                root.source.audio.muted = !root.micMuted;
            root.indicate("mic");
        }
    }

    Timer {
        id: repeatDelay
        interval: 600
        onTriggered: repeat.start()
    }
    Timer {
        id: repeat
        interval: 40
        repeat: true
        // Also stops at the ends, so a lost key release can't keep going
        onTriggered: {
            if (root.holding === 0 || (root.holding > 0 ? root.volume >= 1 : root.volume <= 0))
                stop();
            else
                root.step(root.holding);
        }
    }
}

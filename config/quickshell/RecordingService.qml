pragma Singleton
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io

// Screen recording with wf-recorder, into ~/Videos/Recordings
Singleton {
    id: root

    readonly property bool recording: recorder.running
    property date started
    property string file: ""
    property int seconds: 0 // elapsed, for the bar

    // what: "area" (select with the mouse) or "screen" (the focused output)
    function start(what) {
        if (recorder.running)
            return;
        file = Quickshell.env("HOME") + "/Videos/Recordings/recording-"
            + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4";
        // setpriv: if the shell stops, the recording gets Ctrl+C and the file is still finished
        recorder.exec(["setpriv", "--pdeathsig", "INT", "sh", "-c", `
            trap 'exit 130' INT # "Stop" while still selecting: don't start recording
            mkdir -p "$(dirname "$1")"
            sleep 0.3 # let the launcher close first
            if [ "$2" = area ]; then
                geometry=$(slurp -d) || exit 1
                exec wf-recorder -g "$geometry" -f "$1"
            else
                exec wf-recorder -o "$3" -f "$1"
            fi
        `, "record", file, what, I3.focusedMonitor?.name ?? ""]);
        seconds = 0;
        started = new Date();
    }

    // wf-recorder finishes the file properly on Ctrl+C (SIGINT)
    function stop() {
        if (recorder.running)
            recorder.signal(2);
    }

    Process {
        id: recorder
        onExited: exitCode => {
            if (exitCode === 0)
                Quickshell.execDetached(["notify-send", "-a", "Recording", "-i", "video-x-generic",
                                         "Recording saved", root.file.replace(/^.*\//, "")]);
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.seconds = Math.round((Date.now() - root.started.getTime()) / 1000)
    }
}

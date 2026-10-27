pragma Singleton
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io

// Active keyboard layout (from Sway), and switching to the next one. Announces
// switches (Alt+Shift) for the on-screen indicator.
Singleton {
    id: root

    property string name: "" // e.g. "French", "English (US)"

    signal switched()

    // Sway sends one event per keyboard device: only a real change counts, and not
    // the first read at startup
    function update(layout) {
        if (layout === name)
            return;
        const first = name === "";
        name = layout;
        if (!first)
            switched();
    }

    function next() {
        Quickshell.execDetached(["swaymsg", "input", "type:keyboard", "xkb_switch_layout", "next"]);
    }

    Process {
        running: true
        command: ["swaymsg", "-r", "-t", "get_inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kb = JSON.parse(text).find(i => i.type === "keyboard" && i.xkb_active_layout_name);
                if (kb)
                    root.update(kb.xkb_active_layout_name);
            }
        }
    }

    I3IpcListener {
        subscriptions: ["input"]
        onIpcEvent: event => {
            const input = JSON.parse(event.data).input;
            if (input?.type === "keyboard" && input.xkb_active_layout_name)
                root.update(input.xkb_active_layout_name);
        }
    }
}

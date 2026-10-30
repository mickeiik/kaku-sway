pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Keyboard shortcuts read from the Sway config (same files and layering as Sway),
// with readable descriptions.
Singleton {
    id: root

    property var list: [] // [{ keys, description }]

    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    // Readable descriptions for Sway commands (first match wins)
    readonly property var commandNames: [
        [/launcher toggle/, "App launcher"],
        [/browser openPrivate/, "Private browser window"],
        [/browser open/, "Web browser"],
        [/^exec foot$/, "Terminal"],
        [/^kill$/, "Close window"],
        [/^fullscreen/, "Fullscreen"],
        [/^floating toggle/, "Float / tile window"],
        [/^focus parent/, "Select parent container"],
        [/^focus (left|right|up|down)/, "Focus window $1"],
        [/^move (left|right|up|down)/, "Move window $1"],
        [/^splith/, "Split horizontally"],
        [/^splitv/, "Split vertically"],
        [/^layout toggle split/, "Toggle split direction"],
        [/^move scratchpad/, "Move to scratchpad"],
        [/^scratchpad show/, "Show scratchpad"],
        [/^reload/, "Reload Sway config"],
        [/swaymsg exit|^exit/, "Log out"],
        [/^mode "?resize/, "Resize mode (arrows, Enter to finish)"],
        [/grimshot.*\boutput\b/, "Screenshot of the screen"],
        [/grimshot.*\bactive\b/, "Screenshot of the window"],
        [/grimshot.*\barea\b/, "Screenshot of an area"],
        [/voxtype record/, "Dictate (hold, speak, let go)"]
    ]

    // Media keys get their name from the key itself
    readonly property var keyNames: ({
        XF86AudioRaiseVolume: "Volume up", XF86AudioLowerVolume: "Volume down", XF86AudioMute: "Mute",
        XF86AudioMicMute: "Mute microphone", XF86MonBrightnessUp: "Brightness up", XF86MonBrightnessDown: "Brightness down",
        XF86AudioPlay: "Play / pause", XF86AudioPause: "Pause", XF86AudioNext: "Next track", XF86AudioPrev: "Previous track",
        XF86AudioStop: "Stop"
    })

    function prettyKeys(keys) {
        const names = { Mod4: "Super", Mod1: "Alt", Control: "Ctrl", Return: "Enter", space: "Space",
                        Left: "←", Right: "→", Up: "↑", Down: "↓", minus: "-" };
        return keys.split("+").map(k => names[k] ?? (k.length === 1 ? k.toUpperCase() : k)).join("+");
    }

    function describe(keys, command) {
        const media = keys.split("+").find(k => keyNames[k]);
        if (media)
            return keyNames[media];
        for (const [pattern, name] of commandNames) {
            const m = command.match(pattern);
            if (m)
                return name.replace("$1", m[1] ?? "");
        }
        return command.replace(/^exec\s+/, "").slice(0, 40);
    }

    function parse(text) {
        const vars = {};
        const found = []; // [keys, command]
        let block = null; // inside "bindsym {" / "bindcode {"
        let skipDepth = 0; // inside a mode "..." { } block
        // Lines ending in "\" continue on the next one
        for (let line of text.replace(/\\\n\s*/g, " ").split("\n")) {
            line = line.trim();
            if (!line || line.startsWith("#"))
                continue;
            if (skipDepth > 0) {
                if (line.endsWith("{")) skipDepth++;
                if (line === "}") skipDepth--;
                continue;
            }
            if (/^mode\s.*\{$/.test(line)) {
                skipDepth = 1;
                continue;
            }
            let m = line.match(/^set\s+(\$\S+)\s+(.+)$/);
            if (m) {
                vars[m[1]] = m[2];
                continue;
            }
            if (block) {
                if (line === "}") {
                    block = null;
                    continue;
                }
                m = line.match(/^(\S+)\s+(.+)$/);
                if (m)
                    found.push([block, m[1], m[2]]);
                continue;
            }
            m = line.match(/^(bindsym|bindcode)(?:\s+--\S+)*\s*\{$/);
            if (m) {
                block = m[1];
                continue;
            }
            m = line.match(/^(bindsym|bindcode)(?:\s+--\S+)*\s+(\S+)\s+(.+)$/);
            if (m)
                found.push([m[1], m[2], m[3]]);
        }

        // Expand $variables (longest names first, so $mod doesn't eat $mode)
        const names = Object.keys(vars).sort((a, b) => b.length - a.length);
        const expand = s => {
            for (let pass = 0; pass < 3; pass++)
                for (const n of names)
                    s = s.split(n).join(vars[n]);
            return s;
        };

        const byDescription = new Map();
        for (const [type, rawKeys, rawCommand] of found) {
            let keys = expand(rawKeys);
            const command = expand(rawCommand);
            // Workspace shortcuts are summarised in one line each
            const workspace = command.match(/^(move container to )?workspace number \d+/);
            if (workspace)
                keys = keys.replace(/\+\d+$/, "+1…0");
            else if (type === "bindcode")
                continue; // other raw key codes aren't readable
            const description = !workspace ? describe(keys, command)
                : workspace[1] ? "Move window to workspace 1–10" : "Go to workspace 1–10";
            const pretty = prettyKeys(keys);
            const entry = byDescription.get(description);
            if (!entry)
                byDescription.set(description, { description: description, keys: [pretty] });
            else if (!entry.keys.includes(pretty))
                entry.keys.push(pretty);
        }
        list = [...byDescription.values()].map(e => ({ description: e.description, keys: e.keys.join("  ") }));
    }

    Component.onCompleted: refresh()

    Process {
        id: reader
        // Fedora's helper that Sway's own config uses to layer the config.d folders
        command: ["sh", "-c", `
            cat ~/.config/sway/config
            # It writes a file of "include '<path>'" lines, in Sway's order
            list=$(/usr/libexec/sway/layered-include "/usr/share/sway/config.d/*.conf" "/etc/sway/config.d/*.conf" "$HOME/.config/sway/config.d/*.conf")
            sed -n "s/^include '\\(.*\\)'$/\\1/p" "$list" | while read -r f; do
                cat "$f"; echo
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }
}

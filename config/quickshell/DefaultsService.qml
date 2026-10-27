pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Default applications per category (stored by xdg-mime in ~/.config/mimeapps.list).
// The first type of each category is used to read the current app and the choices.
Singleton {
    id: root

    readonly property var categories: [
        { id: "browser", name: "Web browser", icon: "internet-web-browser",
          types: ["x-scheme-handler/https", "x-scheme-handler/http", "text/html", "application/xhtml+xml"] },
        { id: "files", name: "File manager", icon: "system-file-manager", types: ["inode/directory"] },
        { id: "text", name: "Text editor", icon: "accessories-text-editor",
          types: ["text/plain", "text/markdown", "application/x-shellscript", "text/x-log"] },
        // Firefox views PDFs well but doesn't declare it, so offer it anyway
        { id: "pdf", name: "PDF viewer", icon: "application-pdf", types: ["application/pdf"], extra: ["org.mozilla.firefox.desktop"] },
        { id: "image", name: "Image viewer", icon: "multimedia-photo-viewer",
          types: ["image/png", "image/jpeg", "image/gif", "image/webp", "image/svg+xml", "image/bmp", "image/tiff", "image/avif"] },
        { id: "video", name: "Video player", icon: "multimedia-video-player",
          types: ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo"] },
        { id: "audio", name: "Music player", icon: "multimedia-audio-player",
          types: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/mp4", "audio/x-opus+ogg"] },
        { id: "archive", name: "Archive manager", icon: "utilities-file-archiver",
          types: ["application/zip", "application/x-tar", "application/x-compressed-tar", "application/x-7z-compressed", "application/gzip", "application/vnd.rar"] },
        { id: "mail", name: "Email", icon: "internet-mail", types: ["x-scheme-handler/mailto"] }
    ]

    // category id -> { current: "app.desktop" or "", choices: ["app.desktop", ...] }
    property var apps: ({})

    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    // Each change runs on its own (two quick changes don't drop the second);
    // the list is re-read shortly after
    function set(categoryId, desktopFile) {
        const category = categories.find(c => c.id === categoryId);
        Quickshell.execDetached(["sh", "-c", `
            browser=$1; shift
            xdg-mime default "$@"
            # The browser also has its own setting, read by some apps
            [ "$browser" = yes ] && xdg-settings set default-web-browser "$1"
            true
        `, "set-default", categoryId === "browser" ? "yes" : "no", desktopFile].concat(category.types));
        rereadAfter.restart();
    }

    // Display name and icon for a .desktop file name
    function entry(desktopFile) {
        const id = desktopFile.replace(/\.desktop$/, "");
        return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
    }
    function appName(desktopFile) {
        return desktopFile ? (entry(desktopFile)?.name ?? desktopFile.replace(/\.desktop$/, "")) : "";
    }

    Component.onCompleted: refresh()

    Timer {
        id: rereadAfter
        interval: 300
        onTriggered: root.refresh()
    }

    // `gio mime <type>` prints the default app and every app registered for that type
    Process {
        id: reader
        command: ["sh", "-c", 'for t in "$@"; do echo "@@$t"; gio mime "$t" 2>/dev/null; done', "read-defaults"]
            .concat(root.categories.map(c => c.types[0]))
        stdout: StdioCollector {
            onStreamFinished: {
                const byType = {};
                for (const block of text.split("@@").slice(1)) {
                    const lines = block.split("\n");
                    const current = (lines.find(l => l.startsWith("Default application")) ?? "").match(/(\S+\.desktop)\s*$/)?.[1] ?? "";
                    const choices = lines.filter(l => l.startsWith("\t")).map(l => l.trim());
                    if (current)
                        choices.push(current);
                    byType[lines[0].trim()] = { current: current, choices: [...new Set(choices)] };
                }
                const result = {};
                for (const c of root.categories) {
                    const found = byType[c.types[0]] ?? { current: "", choices: [] };
                    const extra = (c.extra ?? []).filter(f => root.entry(f));
                    result[c.id] = { current: found.current, choices: [...new Set(found.choices.concat(extra))] };
                }
                root.apps = result;
            }
        }
    }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Number of pending updates (dnf + Flatpak).
// Run as the user, dnf reads its own metadata cache (~/.cache/libdnf5), not the
// system one that dnf-makecache.timer refreshes (and that timer is skipped on
// battery). So the check refreshes that user cache itself first: "dnf makecache"
// only downloads repos whose metadata has expired (6 h for updates), and keeps the
// old cache when offline. The dnf list is kept in ~/.cache and only recomputed when
// the repo metadata or the installed packages have changed since.
Singleton {
    id: root

    property int count: 0
    property real lastCheck: 0

    // At most every 30 minutes unless forced (the metadata refresh and a full dnf
    // check each cost ~0.75 s of CPU)
    function refresh(force) {
        if (checker.running || (!force && Date.now() - lastCheck < 30 * 60 * 1000))
            return;
        lastCheck = Date.now();
        checker.running = true;
    }

    // A launcher-pkg command in a floating terminal (see ~/.local/bin/launcher-pkg;
    // the "launcher-term" app id makes Sway float it). Here because both this service
    // (Update) and the launcher's Install/Remove/Update menus use it.
    function terminal(title, args) {
        return ["foot", "--app-id=launcher-term", "--title=" + title, "-e",
                Quickshell.env("HOME") + "/.local/bin/launcher-pkg"].concat(args);
    }

    // Opens the "Update system" terminal, and recounts once it's closed
    function runUpdate() {
        if (!updater.running)
            updater.running = true;
    }

    Component.onCompleted: refresh(true)

    Process {
        id: updater
        command: root.terminal("Update system", ["update"])
        onExited: root.refresh(true)
    }

    Process {
        id: checker
        command: ["sh", "-c", `
            cache="$HOME/.cache/quickshell-dnf-updates"
            # --assumeno and no stdin: never wait on a key import prompt (repos with
            # repo_gpgcheck, like Tailscale, have their key only in root's keyring)
            timeout 120 dnf makecache --assumeno </dev/null >/dev/null 2>&1
            # Metadata by content: a repo that fails its signature check rewrites its
            # repomd.xml on every refresh, even when nothing changed
            stamp=$({ cat "$HOME"/.cache/libdnf5/*/repodata/repomd.xml | cksum; stat -c %Y /var/lib/rpm/rpmdb.sqlite /var/lib/rpm/rpmdb.sqlite-wal; } 2>/dev/null | tr '\\n' ' ')
            if [ "$(head -1 "$cache" 2>/dev/null)" != "$stamp" ]; then
                { echo "$stamp"; dnf repoquery --upgrades --cacheonly --qf '%{name}\\n' 2>/dev/null | sort -u; } > "$cache.tmp" &&
                    mv "$cache.tmp" "$cache"
            fi
            tail -n +2 "$cache" 2>/dev/null
            flatpak remote-ls --updates --cached --columns=application 2>/dev/null
        `]
        stdout: StdioCollector {
            onStreamFinished: root.count = text.split("\n").filter(l => l.trim()).length
        }
    }

    Timer {
        interval: 60 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh(false)
    }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Messages from an ntfy server (ntfy.sh or a self-hosted one), for the bell on the
// bar and its panel. The bell shows once ~/.config/kaku/ntfy.json exists (the
// launcher's Tools > ntfy notifications creates it). That file holds the server and
// the topics, { server, topics: [{ name, popup }] }: nothing secret, fine to sync
// between machines. Signing in (username and password, like ntfy's web app) gets an
// access token for this machine, kept in ~/.config/kaku/ntfy-token (mode 600): the
// password itself isn't kept. The panel's settings write both. Credentials and token
// go to curl on stdin, never on a command line.
// The messages ntfy still keeps are loaded, then new ones stream in. A new one at or
// above its topic's pop-up level (1-5, 6 = never) also shows as a notification.
Singleton {
    id: root

    readonly property string configDir: Quickshell.env("HOME") + "/.config/kaku"
    readonly property string configFile: configDir + "/ntfy.json"
    readonly property string tokenFile: configDir + "/ntfy-token"
    // { read, shown }: time (s) of the newest message marked read / already popped up
    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/quickshell/ntfy.json"
    // Downloaded attachments, deleted after 7 days (ntfy keeps them as long)
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/kaku/ntfy"

    property bool enabled: false
    property string server: ""
    property var topics: [] // [{ name, popup }]
    property bool hasToken: false
    property bool tokenFileChanged: false
    property string account: "" // the signed-in user's name, once the server said it
    readonly property bool configured: server !== "" && hasToken && topics.length > 0

    property var messages: [] // newest first, cleared ones included
    property real readUntil: 0
    property real shownUntil: 0
    // Ids of the messages cleared from the list on this PC (ntfy can't delete them for
    // a subscriber, and its own apps also clear them on the device only)
    property var cleared: ({})
    readonly property var items: messages.filter(m => !cleared[m.id]) // what the panel lists
    property bool stateLoaded: false
    readonly property var unread: items.filter(m => m.time > readUntil)
    readonly property bool urgent: unread.some(m => m.priority >= 4)

    readonly property bool connected: stream.running && streamOpen
    property bool streamOpen: false
    property string error: ""
    property string lastId: ""
    property real lastLine: 0

    // ntfy's tag shortcodes that are emoji (shown before the title, as ntfy does);
    // other tags show as words
    readonly property var emoji: ({
        "+1": "👍", "-1": "👎", "white_check_mark": "✅", "heavy_check_mark": "✔️", "x": "❌",
        "warning": "⚠️", "rotating_light": "🚨", "no_entry": "⛔", "exclamation": "❗", "question": "❓",
        "bell": "🔔", "loudspeaker": "📢", "tada": "🎉", "partying_face": "🥳", "fire": "🔥",
        "skull": "💀", "bug": "🐛", "zap": "⚡", "rocket": "🚀", "hourglass": "⌛", "stopwatch": "⏱️",
        "floppy_disk": "💾", "cd": "💿", "computer": "💻", "desktop_computer": "🖥️", "file_folder": "📁",
        "card_file_box": "🗃️", "package": "📦", "inbox_tray": "📥", "outbox_tray": "📤", "envelope": "✉️",
        "lock": "🔒", "unlock": "🔓", "key": "🔑", "shield": "🛡️", "wrench": "🔧", "hammer": "🔨",
        "gear": "⚙️", "stethoscope": "🩺", "thermometer": "🌡️", "battery": "🔋", "electric_plug": "🔌",
        "globe_with_meridians": "🌐", "satellite": "📡", "chart_with_upwards_trend": "📈",
        "chart_with_downwards_trend": "📉", "calendar": "📅", "date": "📅", "clock": "🕐", "house": "🏠",
        "door": "🚪", "camera": "📷", "movie_camera": "🎥", "musical_note": "🎵", "speech_balloon": "💬",
        "information_source": "ℹ️", "mag": "🔍", "heart": "❤️", "star": "⭐", "sunny": "☀️", "cloud": "☁️",
        "umbrella": "☔", "snowflake": "❄️", "red_circle": "🔴", "green_circle": "🟢", "yellow_circle": "🟡",
        "large_blue_circle": "🔵", "stop_sign": "🛑", "construction": "🚧", "recycle": "♻️", "trophy": "🏆"
    })

    function emojiOf(m) {
        return m.tags.filter(t => emoji[t]).map(t => emoji[t]).join("");
    }
    function wordTags(m) {
        return m.tags.filter(t => !emoji[t]);
    }
    function heading(m) {
        return m.title || m.topic;
    }
    function topicPopup(name) {
        return topics.find(t => t.name === name)?.popup ?? 3;
    }
    function topicUrl(name) {
        return server + "/" + name;
    }

    // "https://ntfy.example.com" from what was typed ("ntfy.example.com/", ...)
    function normalizeServer(url) {
        url = url.trim().replace(/\/+$/, "");
        return url === "" || /^https?:\/\//i.test(url) ? url : "https://" + url;
    }
    function validTopic(name) {
        return /^[-_A-Za-z0-9]{1,64}$/.test(name);
    }

    // --- settings -------------------------------------------------------

    function applyConfig(text) {
        let c = {};
        try {
            c = JSON.parse(text || "{}");
        } catch (e) {
            error = "Can't read " + configFile;
        }
        enabled = true;
        const oldTopics = topics.map(t => t.name).join(",");
        server = normalizeServer(c.server ?? "");
        topics = (c.topics ?? []).filter(t => validTopic(t?.name ?? ""))
            .map(t => ({ name: t.name, popup: Math.max(1, Math.min(6, Number(t.popup) || 3)) }));
        if (topics.map(t => t.name).join(",") !== oldTopics) {
            // A new topic needs its history: load everything again (known ids are skipped)
            lastId = "";
            messages = messages.filter(m => topics.some(t => t.name === m.topic));
        }
        restart();
    }

    function saveConfig(newServer, newTopics) {
        const c = { server: normalizeServer(newServer), topics: newTopics };
        server = c.server;
        topics = newTopics;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1.tmp" && mv "$1.tmp" "$1"',
            "ntfy-config", configFile, JSON.stringify(c, null, 2)]);
        reloadConfig.restart();
    }

    // From the launcher: the bell shows, its panel opens on the settings
    function enable() {
        if (!enabled)
            saveConfig("", []);
        enabled = true;
    }

    function setServer(url) {
        saveConfig(url, topics);
    }
    function addTopic(name) {
        if (!topics.some(t => t.name === name))
            saveConfig(server, topics.concat([{ name: name, popup: 3 }]));
    }
    function removeTopic(name) {
        saveConfig(server, topics.filter(t => t.name !== name));
    }
    function setPopup(name, level) {
        saveConfig(server, topics.map(t => t.name === name ? { name: t.name, popup: level } : t));
    }

    // Written through stdin, so the token is never on a command line
    property string pendingToken: ""
    function saveToken(token) {
        pendingToken = token.trim();
        tokenWriter.running = true;
    }

    // --- account ----------------------------------------------------------

    // Signs in to the server: it gives a token for this machine (named after it, so it
    // can be told apart and revoked in ntfy's web app), and only that is kept.
    // callback(ok, text)
    property var signInCallback: null
    property string pendingLogin: ""
    function signIn(user, password, callback) {
        if (signInProc.running)
            return;
        signInCallback = callback;
        pendingLogin = user + "\n" + password + "\n";
        signInProc.output = "";
        signInProc.outputDone = false;
        signInProc.exitCode = -1;
        signInProc.command = ["sh", "-c", `
            IFS= read -r user; IFS= read -r pass
            auth=$(printf '%s:%s' "$user" "$pass" | base64 -w0)
            body=$(jq -nc --arg l "kaku-sway · $(uname -n)" '{label: $l}')
            out=$(printf 'Authorization: Basic %s\n' "$auth" | curl -sS -m 10 -H @- -H 'Content-Type: application/json' \
                -X POST -d "$body" -w '\n%{http_code}' "$2/v1/account/token") || { echo 000; exit 0; }
            status=$(printf '%s' "$out" | tail -n 1)
            if [ "$status" = 200 ]; then
                token=$(printf '%s' "$out" | sed '$d' | jq -r '.token // empty')
                [ -n "$token" ] || { echo 000; exit 0; }
                umask 077; mkdir -p "$(dirname "$1")"
                printf '%s\n' "$token" > "$1.tmp" && mv "$1.tmp" "$1"
            fi
            echo "$status"
        `, "ntfy-sign-in", tokenFile, server];
        signInProc.running = true;
    }
    function signInDone(status) {
        const callback = signInCallback;
        signInCallback = null;
        tokenCheck.running = true;
        if (status === "200") {
            error = "";
            restart();
            refreshAccount();
        }
        callback?.(status === "200", status === "200" ? ""
            : status === "401" ? "Wrong username or password"
            : status === "429" ? "Too many tries, wait a moment"
            : status === "000" ? "No answer from " + server
            : "Server answered HTTP " + status);
    }

    // Removes this machine's token, from the server too (when it answers)
    function signOut() {
        const p = requestComponent.createObject(root, { raw: true, callback: () => {
            account = "";
            tokenCheck.running = true;
        } });
        p.command = ["sh", "-c", `
            token=$(cat "$1" 2>/dev/null)
            [ -n "$token" ] && printf 'Authorization: Bearer %s\n' "$token" |
                curl -sS -m 10 -H @- -X DELETE -o /dev/null "$2/v1/account/token"
            rm -f "$1"
        `, "ntfy-sign-out", tokenFile, server];
        p.running = true;
    }

    // Who the token belongs to
    function refreshAccount() {
        if (server === "" || !hasToken) {
            account = "";
            return;
        }
        request(server + "/v1/account", (status, body) => {
            let user = "";
            try {
                user = status === "200" ? JSON.parse(body).username ?? "" : "";
            } catch (e) {}
            account = user === "*" ? "" : user;
        });
    }
    onServerChanged: refreshAccount()
    onHasTokenChanged: refreshAccount()

    // --- reading state --------------------------------------------------

    function saveState() {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"',
            "ntfy-state", stateFile, JSON.stringify({ read: readUntil, shown: shownUntil, cleared: Object.keys(cleared) })]);
    }
    // Removes these messages from the list
    function clear(ids) {
        const c = Object.assign({}, cleared);
        for (const id of ids)
            c[id] = true;
        // Only the newest are worth keeping: ntfy drops messages after a few days
        const keys = Object.keys(c);
        if (keys.length > 1000) {
            const keep = {};
            for (const id of keys.slice(-1000))
                keep[id] = true;
            cleared = keep;
        } else {
            cleared = c;
        }
        saveState();
    }

    function markRead() {
        if (messages.length > 0 && messages[0].time > readUntil) {
            readUntil = messages[0].time;
            saveState();
        }
    }

    // --- server requests -------------------------------------------------

    // Shell snippet: curl with the token (if there is one) as a header from stdin.
    // $1 = token file, the rest = curl's arguments.
    readonly property string curlWithToken: `
        token=$(cat "$1" 2>/dev/null); shift
        if [ -n "$token" ]; then
            printf 'Authorization: Bearer %s\\n' "$token" | curl -H @- "$@"
        else
            curl "$@"
        fi`

    // callback(status, body): status is the HTTP code, "000" without an answer
    function request(url, callback) {
        const p = requestComponent.createObject(root, { callback: callback });
        p.command = ["sh", "-c", curlWithToken, "ntfy-request", tokenFile, "-sS", "-m", "10", "-w", "\\n%{http_code}", url];
        p.running = true;
    }

    // Does the server answer, and as whom: callback(ok, text)
    function testServer(url, callback) {
        request(normalizeServer(url) + "/v1/account", (status, body) => {
            if (status === "200") {
                let user = "";
                try {
                    user = JSON.parse(body).username ?? "";
                } catch (e) {}
                callback(true, user && user !== "*" ? "Signed in as " + user : "Server answers (no token)");
            } else {
                callback(false, status === "401" ? "Token refused by the server"
                    : status === "000" ? "No answer from " + normalizeServer(url) : "Server answered HTTP " + status);
            }
        });
    }

    // Can this token read the topic: callback(ok, text)
    function checkTopic(name, callback) {
        if (!validTopic(name))
            return callback(false, "Letters, digits, - and _ only");
        request(server + "/" + name + "/json?poll=1&since=1s", status => {
            callback(status === "200", status === "200" ? ""
                : status === "401" || status === "403" ? "No read access to " + name + " with this token"
                : status === "000" ? "No answer from the server" : "Server answered HTTP " + status);
        });
    }

    // --- the stream -------------------------------------------------------

    property bool restartPending: false
    readonly property int retryMin: 15 * 1000
    readonly property int retryMax: 5 * 60 * 1000
    property int retryDelay: 0

    function restart() {
        reconnect.stop();
        retryDelay = 0;
        error = "";
        if (stream.running) {
            restartPending = true;
            stream.running = false;
        } else if (configured) {
            reconnect.interval = 200;
            reconnect.restart();
        }
    }

    function start() {
        if (!configured || !stateLoaded || stream.running)
            return;
        // What ntfy still has (7 days) the first time, then from the last message seen
        const since = lastId || "168h";
        stream.command = ["sh", "-c", curlWithToken, "ntfy-stream", tokenFile, "-sSN",
            "-w", "%{stderr}HTTP %{http_code}\\n",
            server + "/" + topics.map(t => t.name).join(",") + "/json?since=" + since];
        streamOpen = false;
        lastLine = Date.now();
        stream.running = true;
    }

    function handle(line) {
        let e;
        try {
            e = JSON.parse(line);
        } catch (err) {
            return;
        }
        lastLine = Date.now();
        if (e.event === "open") {
            streamOpen = true;
            error = "";
            retryDelay = 0;
            return;
        }
        if (e.event !== "message" || messages.some(m => m.id === e.id))
            return;
        const m = {
            id: e.id, time: e.time, topic: e.topic, title: e.title ?? "", text: e.message ?? "",
            priority: e.priority ?? 3, tags: e.tags ?? [], click: e.click ?? "", attachment: e.attachment ?? null
        };
        lastId = e.id;
        messages = [m].concat(messages).sort((a, b) => b.time - a.time).slice(0, 300);
        // Only recent ones pop up: none for what came in while this PC was off
        if (m.time > shownUntil && m.time * 1000 > Date.now() - 15 * 60 * 1000) {
            shownUntil = m.time;
            saveState();
            if (m.priority >= topicPopup(m.topic))
                popup(m);
        }
    }

    // --- pop-ups and opening --------------------------------------------

    function escapeMarkup(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // A notification (Toasts.qml) with buttons; notify-send prints the one clicked
    function popup(m) {
        const args = ["notify-send", "--app-name=ntfy · " + m.topic, "--icon=preferences-system-notifications",
            "--urgency=" + (m.priority >= 4 ? "critical" : m.priority <= 2 ? "low" : "normal"),
            "--action=default=Open"];
        if (m.attachment)
            args.push("--action=attachment=Open " + m.attachment.name);
        if (m.click)
            args.push("--action=link=Open link");
        const text = m.text.length > 300 ? m.text.slice(0, 300) + "…" : m.text;
        args.push(((emojiOf(m) ? emojiOf(m) + " " : "") + heading(m)), escapeMarkup(text).replace(/\n/g, "<br>"));
        const p = requestComponent.createObject(root, { callback: (status, action) => {
            const a = action.trim();
            if (a === "default")
                Quickshell.execDetached(["qs", "ipc", "call", "bar", "toggle", "ntfy"]);
            else if (a === "attachment")
                openAttachment(m);
            else if (a === "link")
                openLink(m.click);
        }, raw: true });
        p.command = args;
        p.running = true;
    }

    // Web and mail links only; other schemes could start local handlers
    function openLink(url) {
        if (/^(https?|mailto):/i.test(url))
            Qt.openUrlExternally(url);
    }

    function attachmentExpired(m) {
        return m.attachment?.expires > 0 && m.attachment.expires * 1000 < Date.now();
    }

    // Downloaded, then opened with this PC's default app for its type (in a floating
    // terminal for terminal apps, like micro); in the browser if there's no default
    // app, the download fails or the app doesn't start. Only files from this server
    // are downloaded.
    function openAttachment(m) {
        const a = m.attachment;
        if (!a?.url.startsWith(server + "/")) {
            openLink(a?.url ?? "");
            return;
        }
        const p = requestComponent.createObject(root, { raw: true, callback: (code, out) => {
            const [file, app] = out.trim().split("\n");
            const entry = app ? DefaultsService.entry(app) : null;
            if (code !== "0" || !file || !entry) {
                openLink(a.url);
                return;
            }
            if (entry.runInTerminal) {
                Quickshell.execDetached(["foot", "--app-id=launcher-term", "--title=" + a.name, "-e"]
                    .concat(Array.from(entry.command).filter(arg => !/^%[A-Za-z]$/.test(arg)), [file]));
                return;
            }
            launch(["gio", "open", file], () => openLink(a.url));
        } });
        p.command = ["sh", "-c", `
            dir=$1; mkdir -p "$dir" && find "$dir" -type f -mtime +7 -delete
            file="$dir/$2-$(printf %s "$3" | tr -c 'A-Za-z0-9._-' _)"
            if [ ! -s "$file" ]; then
                curl -fsS -m 60 -o "$file.part" "$4" && mv "$file.part" "$file" || { rm -f "$file.part"; exit 1; }
            fi
            echo "$file"
            xdg-mime query default "$(xdg-mime query filetype "$file")"
        `, "ntfy-attachment", cacheDir, m.id, a.name, a.url];
        p.running = true;
    }

    // Opens a file in its app; onFail() if that fails. In its own session and without
    // this process's output pipes, or the app would be closed with it.
    function launch(command, onFail) {
        const p = requestComponent.createObject(root, { raw: true, callback: code => {
            if (code !== "0")
                onFail();
        } });
        p.command = ["sh", "-c", 'setsid --wait "$@" </dev/null >/dev/null 2>&1', "ntfy-open"].concat(command);
        p.running = true;
    }

    // --- processes ---------------------------------------------------------

    // One-off command. Default: curl -w '\n%{http_code}', callback(status, body).
    // raw: callback(exit code, stdout).
    Component {
        id: requestComponent

        Process {
            id: proc

            property var callback
            property bool raw: false
            property string output: ""
            property bool outputDone: false
            property int exitCode: -1

            // The exit and the end of the output can come in either order
            function finish() {
                if (!outputDone || exitCode < 0)
                    return;
                if (raw) {
                    callback(String(exitCode), output);
                } else {
                    const lines = output.replace(/\n$/, "").split("\n");
                    const status = lines.pop() || "000";
                    callback(exitCode === 0 ? status : "000", lines.join("\n"));
                }
                destroy();
            }

            stdout: StdioCollector {
                onStreamFinished: {
                    proc.output = text;
                    proc.outputDone = true;
                    proc.finish();
                }
            }
            onExited: code => {
                exitCode = code;
                finish();
            }
        }
    }

    Process {
        id: stream

        stdout: SplitParser {
            onRead: line => root.handle(line)
        }
        // The exit and the end of the error output (with curl's HTTP status) can come
        // in either order: decide once both are there
        property bool exited: false
        property bool errDone: false
        property string errText: ""

        function ended() {
            if (!exited || !errDone)
                return;
            exited = errDone = false;
            root.streamEnded(errText);
        }

        stderr: StdioCollector {
            onStreamFinished: {
                stream.errText = text;
                stream.errDone = true;
                stream.ended();
            }
        }
        onExited: {
            root.streamOpen = false;
            exited = true;
            ended();
        }
    }

    function streamEnded(errText) {
        const codes = errText.match(/HTTP \d{3}/g) ?? []; // the last one: after redirects
        const status = codes.length > 0 ? codes[codes.length - 1].slice(5) : "000";
        if (restartPending) {
            restartPending = false;
            reconnect.interval = 200;
        } else if (status === "401" || status === "403") {
            error = status === "401" ? "Token refused by the server"
                : "This token can't read " + topics.map(t => t.name).join(", ");
            // Wait for a new token or the refresh button; the file may be gone
            tokenCheck.running = true;
            return;
        } else {
            error = status === "000" ? "Can't reach " + server + ", retrying"
                : status === "200" ? "Connection to " + server + " lost, retrying"
                : "Server answered HTTP " + status + ", retrying";
            retryDelay = retryDelay === 0 ? retryMin : Math.min(retryDelay * 2, retryMax);
            reconnect.interval = retryDelay;
        }
        if (configured)
            reconnect.restart();
    }

    Timer {
        id: reconnect
        onTriggered: root.start()
    }

    // ntfy sends a keepalive every 45 s: nothing for 2 minutes means the connection is
    // gone (after a sleep, a network change...), so start a new one
    Timer {
        interval: 30 * 1000
        repeat: true
        running: stream.running
        onTriggered: {
            if (Date.now() - root.lastLine > 120 * 1000)
                root.restart();
        }
    }

    Timer {
        id: reloadConfig
        interval: 300
        onTriggered: config.reload()
    }

    // Settings: also re-read when the file changes (a dotfiles sync, an edit)
    FileView {
        id: config
        path: root.configFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyConfig(text())
        onLoadFailed: root.enabled = false
    }

    Process {
        id: tokenCheck
        running: true
        command: ["test", "-s", root.tokenFile]
        onExited: code => {
            const had = root.hasToken;
            const changed = root.tokenFileChanged;
            root.tokenFileChanged = false;
            root.hasToken = code === 0;
            if (root.hasToken !== had || changed)
                root.restart();
        }
    }

    // Watch only: the token is read by curl, never here
    FileView {
        id: tokenWatch
        path: root.tokenFile
        preload: false
        watchChanges: true
        printErrors: false
        onFileChanged: {
            root.tokenFileChanged = true;
            tokenCheck.running = true;
        }
    }

    Process {
        id: signInProc

        property string output: ""
        property bool outputDone: false
        property int exitCode: -1

        function finish() {
            if (outputDone && exitCode >= 0)
                root.signInDone(output.trim() || "000");
        }

        stdinEnabled: true
        onStarted: {
            write(root.pendingLogin);
            root.pendingLogin = "";
            stdinEnabled = false;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                signInProc.output = text;
                signInProc.outputDone = true;
                signInProc.finish();
            }
        }
        onExited: code => {
            stdinEnabled = true;
            exitCode = code;
            finish();
        }
    }

    Process {
        id: tokenWriter
        stdinEnabled: true
        command: ["sh", "-c", 'umask 077; mkdir -p "$(dirname "$1")" && cat > "$1.tmp" && mv "$1.tmp" "$1"', "ntfy-token", root.tokenFile]
        onStarted: {
            write(root.pendingToken + "\n");
            root.pendingToken = "";
            stdinEnabled = false;
        }
        onExited: {
            stdinEnabled = true;
            tokenCheck.running = true;
            root.restart(); // the new token, even if one was saved before
            root.refreshAccount();
        }
    }

    Process {
        running: true
        command: ["cat", root.stateFile]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text);
                    root.readUntil = s.read ?? 0;
                    root.shownUntil = s.shown ?? 0;
                    const c = {};
                    for (const id of s.cleared ?? [])
                        c[id] = true;
                    root.cleared = c;
                } catch (e) {}
                root.stateLoaded = true;
                root.start();
            }
        }
    }
}

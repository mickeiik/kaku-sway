import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

// Lock screen, using Wayland's session lock protocol: if this shell crashed while
// locked, the session would stay locked (not open up).
// Lock: ~/.local/bin/lock-screen, which calls `qs ipc call lock lock` (or falls back
// to swaylock if the shell isn't running).
//
// Unlocks with the password, or a fingerprint when a reader with enrolled fingers is
// present: both are checked side by side (Fedora's password-auth and fingerprint-auth
// PAM profiles), since the usual login profile waits for the finger before the password.
//
// Small squares drift around like little creatures:
// - typing makes them curious (they come closer), and for each key one of them
//   flies over to take its place in the row under the clock;
// - while checking they hold their breath;
// - right password: everyone rushes to the center together (quickly);
// - wrong password: disappointment (they turn grey and fall), then worry
//   (they tremble and huddle), then they calm down. Their mood gets worse with each
//   wrong attempt (annoyed, then sulking at the edges);
// - Caps Lock makes the row stand on tiptoe.
// After a few seconds without input everything freezes (swayidle turns the screen off
// after a minute, see sway/config.d/90-swayidle.conf).
Scope {
    id: root

    // Fixed, like the login screen (~/.config/sddm-theme): not the bar's text size
    readonly property int fontSize: 15

    component ClockText: Label {
        font.pixelSize: root.fontSize * 7
        font.bold: true
    }

    property string password: ""
    property string state: "idle" // idle, checking, sad, worried, unlocking
    property string message: ""
    property bool redFlash: false
    property int failures: 0 // wrong attempts since locking
    readonly property string mood: failures >= 3 ? "sulk" : failures === 2 ? "annoyed" : "sad"
    property bool lockedOut: false // PAM said too many attempts
    property string pamNotice: "" // what PAM said about the last attempt (e.g. account locked)
    property bool capsLock: false
    property bool fingerprint: false // a reader with enrolled fingers
    // No input for a while (see the IdleMonitor below): animations freeze and the
    // fingerprint reader stops listening until a key or the mouse wakes things up
    property bool resting: false
    onRestingChanged: {
        if (resting)
            stopAuth(true);
        else
            fingerRetry.restart();
    }

    readonly property int maxSlots: 18
    readonly property var colors: [Theme.accent, Theme.purple, Theme.cyan, Theme.green, Theme.yellow, Theme.orange, Theme.teal]
    readonly property var moodMessages: ({
        sad: ["Oh no…", "Nope.", "That wasn't it…", "Hmm, no."],
        annoyed: ["Again?", "Really?", "Seriously?"],
        sulk: ["Hmph.", "We'll be over here.", "Fine. Not talking to you."]
    })
    function moodMessage() {
        const list = moodMessages[mood];
        return list[Math.floor(Math.random() * list.length)];
    }

    signal keyTyped()
    property int lastLength: 0

    onPasswordChanged: {
        if (password.length > lastLength)
            keyTyped();
        lastLength = password.length;
        if (password !== "") {
            message = "";
            if (state === "worried") // typing again calms them down
                state = "idle";
        }
    }

    // Stop listening for the fingerprint, and the password check unless told otherwise
    function stopAuth(keepPassword) {
        fingerRetry.stop();
        if (pamFinger.active)
            pamFinger.abort();
        if (!keepPassword && pamPassword.active)
            pamPassword.abort();
    }

    function flash(duration) {
        redFlash = true;
        flashTimer.interval = duration;
        flashTimer.restart();
    }

    function lock() {
        // Cancel anything from before: an unlock under way, checks in progress
        unlockDelay.stop();
        sadTimer.stop();
        worriedTimer.stop();
        stopAuth();
        reset();
        sessionLock.locked = true;
        capsReader.running = true;
        fingerCheck.running = true;
    }

    function submit() {
        if (password === "" || (state !== "idle" && state !== "worried"))
            return;
        state = "checking";
        message = "";
        lockedOut = false;
        pamNotice = "";
        if (!pamPassword.start()) {
            wrong("Authentication error.");
            return;
        }
        watchdog.restart();
    }

    function succeed() {
        watchdog.stop();
        stopAuth();
        state = "unlocking";
        unlockDelay.start();
    }

    // The row stays a moment (drooping) before falling apart, see sadTimer
    function wrong(text) {
        if (state === "sad") // e.g. an error and a failure for the same attempt
            return;
        watchdog.stop();
        failures++;
        state = "sad";
        message = text || moodMessage();
        flash(mood === "sad" ? 300 : 650);
        sadTimer.restart();
    }

    function reset() {
        password = "";
        state = "idle";
        message = "";
        redFlash = false;
        failures = 0;
        lockedOut = false;
        resting = false;
    }

    function finishUnlock() {
        stopAuth();
        sessionLock.locked = false;
        reset();
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }
        // No unlock(): only the password or a fingerprint opens the session
        function isLocked(): bool {
            return sessionLock.locked;
        }
        // The compositor has confirmed the lock is on screen (used before sleep)
        function isSecure(): bool {
            return sessionLock.secure;
        }
    }

    // Password (Fedora's password-only profile, same rules as logging in)
    PamContext {
        id: pamPassword

        config: "password-auth"
        onPamMessage: {
            if (responseRequired)
                respond(root.password);
            else if (messageIsError)
                root.pamNotice = message;
        }
        onCompleted: result => {
            if (root.state !== "checking") // aborted
                return;
            if (result === PamResult.Success) {
                root.succeed();
            } else {
                root.lockedOut = result === PamResult.MaxTries;
                root.wrong(root.pamNotice || (root.lockedOut ? "Too many attempts, wait a moment." : ""));
            }
        }
        onError: {
            if (root.state === "checking")
                root.wrong("Authentication error.");
        }
    }

    // Fingerprint (Fedora's fingerprint-only profile), listening while locked
    PamContext {
        id: pamFinger

        config: "fingerprint-auth"
        onPamMessage: {
            if (responseRequired)
                respond("");
            else if (/fail|no match|not match/i.test(message)) {
                root.message = "Fingerprint not recognized";
                root.flash(300);
            }
        }
        onCompleted: result => {
            if (!sessionLock.locked || root.state === "unlocking")
                return;
            if (result === PamResult.Success)
                root.succeed();
            else
                fingerRetry.restart(); // fprintd gives up after a while or a few misses: listen again
        }
        onError: {
            if (sessionLock.locked)
                fingerRetry.restart();
        }
    }
    Timer {
        id: fingerRetry
        interval: 1500
        onTriggered: {
            if (sessionLock.locked && root.fingerprint && !root.resting && root.state !== "unlocking" && !pamFinger.active)
                pamFinger.start();
        }
    }
    // Is there a reader with enrolled fingers? (checked each time the screen locks)
    Process {
        id: fingerCheck
        command: ["fprintd-list", Quickshell.env("USER")]
        stdout: StdioCollector {
            onStreamFinished: {
                root.fingerprint = /#\d+:/.test(text);
                if (root.fingerprint)
                    fingerRetry.restart();
            }
        }
    }

    // Timing of the reactions
    Timer {
        id: unlockDelay
        interval: 350
        onTriggered: {
            if (root.state === "unlocking")
                root.finishUnlock();
        }
    }
    Timer {
        id: watchdog // a check that never answers mustn't leave the screen stuck
        interval: 30000
        onTriggered: {
            if (root.state !== "checking")
                return;
            pamPassword.abort();
            root.wrong("No answer, try again.");
        }
    }
    Timer {
        id: flashTimer
        interval: 300
        onTriggered: root.redFlash = false
    }
    Timer {
        id: sadTimer
        interval: root.mood === "sulk" ? 1300 : 1000
        onTriggered: {
            if (root.state !== "sad")
                return;
            root.password = ""; // the row falls apart
            root.state = "worried";
            if (!root.lockedOut)
                root.message = root.mood === "sulk" ? "…try again, if you must." : "Try again?";
            worriedTimer.restart();
        }
    }
    Timer {
        id: worriedTimer
        interval: root.mood === "sulk" ? 4000 : 1600
        onTriggered: {
            if (root.state === "worried")
                root.state = "idle";
        }
    }

    // Caps Lock state, from the keyboard LED: read when locking and when the key is pressed
    Process {
        id: capsReader
        command: ["sh", "-c", "cat /sys/class/leds/*capslock/brightness 2>/dev/null | sort -r | head -1"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLock = text.trim() !== "" && text.trim() !== "0"
        }
    }
    Timer {
        id: capsDelay // the LED changes just after the key press
        interval: 80
        onTriggered: capsReader.running = true
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            id: surface

            color: Theme.bg

            // Created with the lock screen, so it counts from the moment of locking (not
            // from the idle time before). Inhibitors (caffeine) are ignored so it still rests.
            IdleMonitor {
                timeout: 20
                respectInhibitors: false
                onIsIdleChanged: root.resting = isIdle
            }

            Image {
                anchors.fill: parent
                // The wallpaper, already darkened (made from tokyo-night.png)
                source: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers/tokyo-night-lock.png"
                sourceSize: Qt.size(width, height)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
            }

            SystemClock {
                id: clock
                precision: SystemClock.Seconds
                enabled: !root.resting
            }

            // Keyboard input, invisible: the squares show what's typed
            TextInput {
                id: input

                width: 1
                height: 1
                opacity: 0
                echoMode: TextInput.Password
                enabled: root.state === "idle" || root.state === "worried"
                focus: true
                text: root.password // shared by all screens
                onTextChanged: root.password = text
                onAccepted: root.submit()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.password = "";
                        return;
                    }
                    if (event.key === Qt.Key_CapsLock)
                        capsDelay.restart();
                    event.accepted = false; // still type normally
                }
                Component.onCompleted: forceActiveFocus()
            }

            // The squares. Free ones drift; "slotted" ones sit in the password row.
            Item {
                id: field

                readonly property real cx: width / 2
                readonly property real cy: height / 2
                readonly property real slotSize: 22
                readonly property real slotGap: 8
                property real time: 0
                property var slots: [] // particle index for each typed character
                property var items: [] // the particles, by index

                // Direction and distance from the center (of a square's body)
                function fromCenter(b) {
                    const dx = b.px - cx, dy = b.py - cy;
                    const d = Math.max(1, Math.hypot(dx, dy));
                    return { x: dx / d, y: dy / d, d: d };
                }

                // One free square near the target slot flies over to fill it
                function takeSlot() {
                    const free = items.filter(p => p && p.slot === -1);
                    if (free.length === 0)
                        return false;
                    // Out of a few random candidates, pick the closest to the row
                    const y = rowY();
                    let best = null, bestDist = Infinity;
                    for (let k = 0; k < 6; k++) {
                        const p = free[Math.floor(Math.random() * free.length)];
                        const d = Math.hypot(p.body.px - cx, p.body.py - y);
                        if (d < bestDist) {
                            best = p;
                            bestDist = d;
                        }
                    }
                    best.slot = slots.length;
                    slots = slots.concat([best.index]);
                    return true;
                }

                function syncSlots() {
                    const wanted = Math.min(root.password.length, root.maxSlots);
                    while (slots.length > wanted) {
                        const p = items[slots[slots.length - 1]];
                        if (p)
                            p.slot = -1;
                        slots = slots.slice(0, -1);
                    }
                    while (slots.length < wanted && takeSlot()) {}
                }

                // Curious: everyone gets a small nudge toward the center
                function nudge() {
                    for (const p of items) {
                        if (!p || p.slot !== -1)
                            continue;
                        const c = fromCenter(p.body);
                        const pull = 25 + 25 * Math.random();
                        p.body.vx -= c.x * pull;
                        p.body.vy -= c.y * pull;
                    }
                }

                function rowY() {
                    return rowAnchor.mapToItem(field, 0, rowAnchor.height / 2).y;
                }

                anchors.fill: parent

                Connections {
                    target: root
                    function onKeyTyped() {
                        field.nudge();
                    }
                    function onPasswordChanged() {
                        field.syncSlots();
                    }
                }

                Repeater {
                    model: 90
                    onItemAdded: (index, item) => field.items[index] = item

                    Rectangle {
                        required property int index
                        property int slot: -1
                        // Position and speed: a plain JS object, so the 60 updates per second
                        // don't each go through property change notifications
                        property var body: ({ ready: false, px: 0, py: 0, vx: 0, vy: 0 })
                        // Each square's own slow drift
                        readonly property real angle: Math.random() * 2 * Math.PI
                        readonly property real speed: 6 + Math.random() * 16
                        readonly property real bx: Math.cos(angle) * speed
                        readonly property real by: Math.sin(angle) * speed
                        readonly property real phase: Math.random() * 2 * Math.PI
                        readonly property real base: 0.25 + Math.random() * 0.5
                        readonly property real baseSize: 4 + (index * 7) % 10
                        readonly property color tint: root.colors[index % root.colors.length]

                        property real size: slot >= 0 ? field.slotSize : baseSize
                        Behavior on size { NumberAnimation { duration: 350; easing.type: Easing.OutBack } }
                        property real fade: root.state === "unlocking" ? 0 : 1
                        Behavior on fade { NumberAnimation { duration: 320 } }
                        // Dimmer when disappointed or sulking
                        property real gloom: root.state === "sad" ? (root.mood === "sulk" ? 0.35 : 0.45)
                            : root.state === "worried" && root.mood === "sulk" ? 0.6 : 1
                        Behavior on gloom { NumberAnimation { duration: 400 } }

                        width: size
                        height: size
                        opacity: 0 // set by the update loop
                        color: root.redFlash ? Theme.red
                            : root.state === "sad" ? (root.mood === "annoyed" ? Theme.darkRed : Theme.muted)
                            : tint
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                }

                // Motion: ~60 updates per second while something happens, 30 when calm,
                // none at all while resting
                Timer {
                    property real last: 0

                    interval: root.state === "idle" && root.password === "" ? 33 : 16
                    repeat: true
                    running: !root.resting
                    onRunningChanged: last = 0
                    onTriggered: {
                        const now = Date.now();
                        const dt = last ? Math.min((now - last) / 1000, 0.05) : 0.016;
                        last = now;
                        field.time += dt;

                        const w = field.width, h = field.height;
                        const st = root.state;
                        const n = field.slots.length;
                        const rowY = field.rowY();
                        const interest = Math.min(root.password.length, 10); // more typed, more curious

                        for (const p of field.items) {
                            if (!p)
                                continue;
                            const b = p.body;
                            if (!b.ready) { // place randomly once the screen size is known
                                b.px = Math.random() * w;
                                b.py = Math.random() * h;
                                b.vx = p.bx;
                                b.vy = p.by;
                                b.ready = w > 0;
                                continue;
                            }

                            if (st === "unlocking") {
                                // Everyone together into the center
                                b.vx += ((field.cx - b.px) * 30 - b.vx * 3) * dt;
                                b.vy += ((field.cy - b.py) * 30 - b.vy * 3) * dt;
                            } else if (p.slot >= 0) {
                                // Spring into its place in the row: drooping when disappointed,
                                // shaking when annoyed, on tiptoe when Caps Lock is on
                                let tx = field.cx + (p.slot - (n - 1) / 2) * (field.slotSize + field.slotGap);
                                let ty = rowY - (root.capsLock ? 12 : 0);
                                if (st === "sad") {
                                    ty += 8;
                                    if (root.mood === "annoyed")
                                        tx += Math.sin(field.time * 55 + p.slot) * 4;
                                }
                                b.vx += ((tx - b.px) * 110 - b.vx * 21) * dt;
                                b.vy += ((ty - b.py) * 110 - b.vy * 21) * dt;
                            } else if (st === "sad" && root.mood === "sulk") {
                                // Sulking: everyone flees to the edges
                                const c = field.fromCenter(b);
                                b.vx += (c.x * 260 - b.vx * 1.5) * dt;
                                b.vy += (c.y * 260 - b.vy * 1.5) * dt;
                            } else if (st === "sad") {
                                // Disappointed: they sink (fast when annoyed)
                                b.vy += (root.mood === "annoyed" ? 420 : 240) * dt;
                                b.vx -= b.vx * 1.5 * dt;
                            } else if (st === "worried" && root.mood === "sulk") {
                                // Still sulking: they keep their distance, grumbling a little
                                const c = field.fromCenter(b);
                                const away = c.d < Math.min(w, h) * 0.42 ? 120 : 0;
                                b.vx += ((Math.random() - 0.5) * 250 + c.x * away - b.vx * 2) * dt;
                                b.vy += ((Math.random() - 0.5) * 250 + c.y * away - b.vy * 2) * dt;
                            } else if (st === "worried") {
                                // Worried: trembling, huddling a bit toward the center
                                b.vx += ((Math.random() - 0.5) * 900 + (field.cx - b.px) * 0.15 - b.vx * 3) * dt;
                                b.vy += ((Math.random() - 0.5) * 900 + (field.cy - b.py) * 0.15 - b.vy * 3) * dt;
                            } else if (st === "checking") {
                                // Holding their breath
                                b.vx -= b.vx * 4 * dt;
                                b.vy -= b.vy * 4 * dt;
                            } else {
                                // Back to the slow drift, slightly drawn to the center while typing
                                b.vx += ((p.bx - b.vx) * 1.2 + (field.cx - b.px) * 0.006 * interest) * dt;
                                b.vy += ((p.by - b.vy) * 1.2 + (field.cy - b.py) * 0.006 * interest) * dt;
                            }

                            // Personal space: free squares stay out of an oval around the clock and
                            // text, so curious ones gather around it instead of covering it
                            if (p.slot === -1 && st !== "unlocking" && st !== "sad") {
                                const ex = (b.px - field.cx) / 400, ey = (b.py - field.cy) / 240;
                                const e = ex * ex + ey * ey;
                                if (e < 1) {
                                    const d = Math.max(0.001, Math.sqrt(e));
                                    const push = (1 - e) * 900;
                                    b.vx += ex / d * push * dt;
                                    b.vy += ey / d * push * dt;
                                }
                            }

                            b.px += b.vx * dt;
                            b.py += b.vy * dt;

                            if (st !== "unlocking" && p.slot === -1) { // wrap around the edges
                                if (b.px < -12) b.px += w + 24;
                                else if (b.px > w + 12) b.px -= w + 24;
                                if (b.py < -12) b.py += h + 24;
                                else if (b.py > h + 12) b.py -= h + 24;
                            }

                            p.x = b.px - p.width / 2;
                            p.y = b.py - p.height / 2;
                            // Row squares pulse while checking; free ones twinkle
                            p.opacity = p.fade * (p.slot >= 0
                                ? (st === "checking" ? 0.35 + 0.65 * Math.abs(Math.sin(field.time * 4 + p.slot * 0.45)) : 1)
                                : p.base * p.gloom * (0.55 + 0.45 * Math.sin(field.time * 0.9 + p.phase)));
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                // Clock, with a blinking colon
                Row {
                    Layout.alignment: Qt.AlignHCenter

                    ClockText { text: String(clock.hours).padStart(2, "0") }
                    ClockText {
                        text: ":"
                        color: Theme.accent
                        opacity: clock.seconds % 2 ? 0.15 : 1
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                    }
                    ClockText { text: String(clock.minutes).padStart(2, "0") }
                }

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: Theme.locale.toString(clock.date, "dddd d MMMM")
                    font.pixelSize: root.fontSize + 4
                }

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    readonly property int hour: clock.hours
                    font.pixelSize: root.fontSize
                    text: (hour < 6 ? "Bonne nuit" : hour < 12 ? "Bonjour" : hour < 18 ? "Bon après-midi" : "Bonsoir") + ", " + Quickshell.env("USER")
                    color: Theme.muted
                }

                // Where the password row sits (the squares themselves live in the field)
                Item {
                    id: rowAnchor

                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 48
                    implicitWidth: 520
                    implicitHeight: 40

                    // Blinking block cursor while nothing is typed
                    Rectangle {
                        id: cursorBox

                        anchors.centerIn: parent
                        visible: root.password.length === 0 && (root.state === "idle" || root.state === "worried")
                        width: 22
                        height: 22
                        color: "transparent"
                        border.color: Theme.accent
                        border.width: 2

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: cursorBox.visible && !root.resting
                            NumberAnimation { to: 0.2; duration: 600; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: root.fontSize + 8
                    readonly property bool capsWarning: root.capsLock && root.message === "" && root.state === "idle"
                    text: root.state === "checking" ? "Checking…"
                        : root.message !== "" ? root.message
                        : capsWarning ? "Caps Lock is on"
                        : root.password.length > 0 ? "Enter to unlock"
                        : root.fingerprint ? "Type your password or use your fingerprint"
                        : "Type your password"
                    color: root.state === "sad" ? Theme.red : root.message !== "" || capsWarning ? Theme.yellow : Theme.muted
                    font.pixelSize: root.fontSize - 1
                }

                // Current keyboard layout, so a layout switch (Alt+Shift) doesn't
                // silently turn the right password into a wrong one
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    Icon {
                        text: ""
                        color: Theme.muted
                        font.pixelSize: root.fontSize - 4
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: KeyboardService.name
                        color: Theme.muted
                        font.pixelSize: root.fontSize - 3
                    }
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts

// SDDM login screen, made to look and behave like the Quickshell lock screen
// (~/.config/quickshell/LockScreen.qml): the same little squares drift around, one
// flies into the row for each typed character, they hold their breath while
// checking, sink when the password is wrong and rush to the center on success.
//
// Logs in the last user (SDDM remembers it; on a first boot, the first account).
// Clicking the name lets you type another one. Password only: see the README.
Rectangle {
    id: root

    readonly property color bg: "#1a1b26"
    readonly property color fg: "#c0caf5"
    readonly property color muted: "#565f89"
    readonly property color accent: "#7aa2f7"
    readonly property color yellow: "#e0af68"
    readonly property color red: "#f7768e"
    readonly property color darkRed: "#db4b4b"
    readonly property var colors: ["#7aa2f7", "#bb9af7", "#7dcfff", "#9ece6a", "#e0af68", "#ff9e64", "#2ac3de"]
    readonly property int fontSize: parseInt(config.fontSize) || 15
    readonly property string font: "JetBrains Mono"
    readonly property string iconFont: "Font Awesome 6 Free"
    readonly property var locale: Qt.locale("fr_FR")

    property string user: userModel.lastUser
    property string password: ""
    property string state: "idle" // idle, checking, sad, worried, unlocking
    property string message: ""
    property bool redFlash: false
    property int failures: 0
    readonly property string mood: failures >= 3 ? "sulk" : failures === 2 ? "annoyed" : "sad"
    readonly property int maxSlots: 18
    readonly property var moodMessages: ({
        sad: ["Oh no…", "Nope.", "That wasn't it…", "Hmm, no."],
        annoyed: ["Again?", "Really?", "Seriously?"],
        sulk: ["Hmph.", "We'll be over here.", "Fine. Not talking to you."]
    })

    signal keyTyped()
    property int lastLength: 0

    onPasswordChanged: {
        if (password.length > lastLength)
            keyTyped();
        lastLength = password.length;
        if (password !== "") {
            message = "";
            if (state === "worried")
                state = "idle";
        }
    }

    function submit() {
        if (password === "" || user === "" || (state !== "idle" && state !== "worried"))
            return;
        state = "checking";
        message = "";
        sddm.login(user, password, sessionModel.lastIndex);
    }

    function wrong(text) {
        if (state === "sad")
            return;
        failures++;
        state = "sad";
        const list = moodMessages[mood];
        message = text || list[Math.floor(Math.random() * list.length)];
        redFlash = true;
        flashTimer.interval = mood === "sad" ? 300 : 650;
        flashTimer.restart();
        sadTimer.restart();
    }

    color: bg

    Connections {
        target: sddm
        function onLoginSucceeded() {
            root.state = "unlocking";
        }
        function onLoginFailed() {
            root.wrong(root.pamNotice);
            root.pamNotice = "";
        }
        // PAM's own explanations, e.g. the account is locked after too many attempts
        function onInformationMessage(message) {
            root.pamNotice = message;
        }
    }
    property string pamNotice: ""

    // First boot: no last user yet, take the first account
    Repeater {
        model: userModel
        Item {
            required property int index
            required property string name
            Component.onCompleted: {
                if (index === 0 && root.user === "")
                    root.user = name;
            }
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
            root.password = "";
            root.state = "worried";
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

    // The wallpaper, already darkened
    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl(config.background)
        sourceSize: Qt.size(width, height)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
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
        text: root.password
        onTextChanged: root.password = text
        onAccepted: root.submit()
        Keys.onEscapePressed: root.password = ""
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
        property var slots: []
        property var items: []

        function fromCenter(b) {
            const dx = b.px - cx, dy = b.py - cy;
            const d = Math.max(1, Math.hypot(dx, dy));
            return { x: dx / d, y: dy / d, d: d };
        }

        function takeSlot() {
            const free = items.filter(p => p && p.slot === -1);
            if (free.length === 0)
                return false;
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
                property var body: ({ ready: false, px: 0, py: 0, vx: 0, vy: 0 })
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
                property real gloom: root.state === "sad" ? (root.mood === "sulk" ? 0.35 : 0.45)
                    : root.state === "worried" && root.mood === "sulk" ? 0.6 : 1
                Behavior on gloom { NumberAnimation { duration: 400 } }

                width: size
                height: size
                opacity: 0
                color: root.redFlash ? root.red
                    : root.state === "sad" ? (root.mood === "annoyed" ? root.darkRed : root.muted)
                    : tint
                Behavior on color { ColorAnimation { duration: 250 } }
            }
        }

        // Motion: 60 updates per second while something happens, 30 when calm
        Timer {
            property real last: 0

            interval: root.state === "idle" && root.password === "" ? 33 : 16
            repeat: true
            running: true
            onTriggered: {
                const now = Date.now();
                const dt = last ? Math.min((now - last) / 1000, 0.05) : 0.016;
                last = now;
                field.time += dt;

                const w = field.width, h = field.height;
                const st = root.state;
                const n = field.slots.length;
                const rowY = field.rowY();
                const interest = Math.min(root.password.length, 10);

                for (const p of field.items) {
                    if (!p)
                        continue;
                    const b = p.body;
                    if (!b.ready) {
                        b.px = Math.random() * w;
                        b.py = Math.random() * h;
                        b.vx = p.bx;
                        b.vy = p.by;
                        b.ready = w > 0;
                        continue;
                    }

                    if (st === "unlocking") {
                        b.vx += ((field.cx - b.px) * 30 - b.vx * 3) * dt;
                        b.vy += ((field.cy - b.py) * 30 - b.vy * 3) * dt;
                    } else if (p.slot >= 0) {
                        let tx = field.cx + (p.slot - (n - 1) / 2) * (field.slotSize + field.slotGap);
                        let ty = rowY - (keyboard.capsLock ? 12 : 0);
                        if (st === "sad") {
                            ty += 8;
                            if (root.mood === "annoyed")
                                tx += Math.sin(field.time * 55 + p.slot) * 4;
                        }
                        b.vx += ((tx - b.px) * 110 - b.vx * 21) * dt;
                        b.vy += ((ty - b.py) * 110 - b.vy * 21) * dt;
                    } else if (st === "sad" && root.mood === "sulk") {
                        const c = field.fromCenter(b);
                        b.vx += (c.x * 260 - b.vx * 1.5) * dt;
                        b.vy += (c.y * 260 - b.vy * 1.5) * dt;
                    } else if (st === "sad") {
                        b.vy += (root.mood === "annoyed" ? 420 : 240) * dt;
                        b.vx -= b.vx * 1.5 * dt;
                    } else if (st === "worried" && root.mood === "sulk") {
                        const c = field.fromCenter(b);
                        const away = c.d < Math.min(w, h) * 0.42 ? 120 : 0;
                        b.vx += ((Math.random() - 0.5) * 250 + c.x * away - b.vx * 2) * dt;
                        b.vy += ((Math.random() - 0.5) * 250 + c.y * away - b.vy * 2) * dt;
                    } else if (st === "worried") {
                        b.vx += ((Math.random() - 0.5) * 900 + (field.cx - b.px) * 0.15 - b.vx * 3) * dt;
                        b.vy += ((Math.random() - 0.5) * 900 + (field.cy - b.py) * 0.15 - b.vy * 3) * dt;
                    } else if (st === "checking") {
                        b.vx -= b.vx * 4 * dt;
                        b.vy -= b.vy * 4 * dt;
                    } else {
                        b.vx += ((p.bx - b.vx) * 1.2 + (field.cx - b.px) * 0.006 * interest) * dt;
                        b.vy += ((p.by - b.vy) * 1.2 + (field.cy - b.py) * 0.006 * interest) * dt;
                    }

                    // Personal space around the clock and text
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

                    if (st !== "unlocking" && p.slot === -1) {
                        if (b.px < -12) b.px += w + 24;
                        else if (b.px > w + 12) b.px -= w + 24;
                        if (b.py < -12) b.py += h + 24;
                        else if (b.py > h + 12) b.py -= h + 24;
                    }

                    p.x = b.px - p.width / 2;
                    p.y = b.py - p.height / 2;
                    p.opacity = p.fade * (p.slot >= 0
                        ? (st === "checking" ? 0.35 + 0.65 * Math.abs(Math.sin(field.time * 4 + p.slot * 0.45)) : 1)
                        : p.base * p.gloom * (0.55 + 0.45 * Math.sin(field.time * 0.9 + p.phase)));
                }
            }
        }
    }

    component Label: Text {
        color: root.fg
        font.family: root.font
        font.pixelSize: root.fontSize
    }
    component ClockText: Label {
        font.pixelSize: root.fontSize * 7
        font.bold: true
    }

    property var now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 8

        // Clock, with a blinking colon
        Row {
            Layout.alignment: Qt.AlignHCenter

            ClockText { text: String(root.now.getHours()).padStart(2, "0") }
            ClockText {
                text: ":"
                color: root.accent
                opacity: root.now.getSeconds() % 2 ? 0.15 : 1
                Behavior on opacity { NumberAnimation { duration: 250 } }
            }
            ClockText { text: String(root.now.getMinutes()).padStart(2, "0") }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: root.locale.toString(root.now, "dddd d MMMM")
            font.pixelSize: root.fontSize + 4
        }

        // Greeting; click the name to log in as someone else
        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4

            Label {
                readonly property int hour: root.now.getHours()
                text: (hour < 6 ? "Bonne nuit" : hour < 12 ? "Bonjour" : hour < 18 ? "Bon après-midi" : "Bonsoir") + ", "
                color: root.muted
            }
            Label {
                visible: !userInput.visible
                text: root.user
                textFormat: Text.PlainText
                color: nameMouse.containsMouse ? root.accent : root.muted

                MouseArea {
                    id: nameMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        userInput.text = root.user;
                        userInput.visible = true;
                        userInput.selectAll();
                        userInput.forceActiveFocus();
                    }
                }
            }
            TextInput {
                id: userInput

                visible: false
                width: Math.max(contentWidth, root.fontSize * 4)
                color: root.accent
                selectionColor: root.accent
                selectedTextColor: root.bg
                font.family: root.font
                font.pixelSize: root.fontSize

                function done(keep) {
                    if (keep && text.trim() !== "")
                        root.user = text.trim();
                    visible = false;
                    input.forceActiveFocus();
                }
                onAccepted: done(true)
                Keys.onEscapePressed: done(false)
                onActiveFocusChanged: if (!activeFocus && visible) done(true)

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.bottom
                    height: 2
                    color: root.accent
                }
            }
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
                border.color: root.accent
                border.width: 2

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: cursorBox.visible
                    NumberAnimation { to: 0.2; duration: 600; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutQuad }
                }
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: root.fontSize + 8
            readonly property bool capsWarning: keyboard.capsLock && root.message === "" && root.state === "idle"
            text: root.state === "checking" ? "Checking…"
                : root.message !== "" ? root.message
                : capsWarning ? "Caps Lock is on"
                : root.password.length > 0 ? "Enter to log in"
                : "Type your password"
            textFormat: Text.PlainText
            color: root.state === "sad" ? root.red : root.message !== "" || capsWarning ? root.yellow : root.muted
            font.pixelSize: root.fontSize - 1
        }

        // Keyboard layout. Fixed here: SDDM can't switch layouts on Wayland, so this
        // is the system one (localectl), set in theme.conf to match
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf11c"
                color: root.muted
                font.family: root.iconFont
                font.pixelSize: root.fontSize - 4
            }
            Label {
                text: config.keyboardLayout || "French"
                color: root.muted
                font.pixelSize: root.fontSize - 3
            }
        }
    }

    // Power buttons, bottom right
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 8

        Repeater {
            model: [
                { icon: "", allowed: sddm.canSuspend, run: () => sddm.suspend() },
                { icon: "", allowed: sddm.canReboot, run: () => sddm.reboot() },
                { icon: "", allowed: sddm.canPowerOff, run: () => sddm.powerOff() }
            ]

            Rectangle {
                required property var modelData

                visible: modelData.allowed
                width: 40
                height: 40
                color: powerMouse.containsMouse ? root.accent : "transparent"
                border.color: root.muted
                border.width: powerMouse.containsMouse ? 0 : 1

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.icon
                    color: powerMouse.containsMouse ? root.bg : root.fg
                    font.family: root.iconFont
                    font.styleName: "Solid"
                    font.pixelSize: root.fontSize
                }
                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: parent.modelData.run()
                }
            }
        }
    }
}

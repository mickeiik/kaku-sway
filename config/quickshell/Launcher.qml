import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// App launcher (Super+Space). An empty search shows the menus; typing searches
// everything. Inside a menu, typing filters that menu.
//
// Each entry is a plain object: name, icon, keywords, and what it does:
//   menu: "<id>"          opens that menu
//   run: () => ...        runs it, then closes the launcher (unless stay: true)
//   value / live: () =>   text shown at the end of the row (live: kept up to date)
//   checked: true         check mark at the end of the row
//   remove: () => ...     the entry can be removed: Delete key, or the × on the row
PanelWindow {
    id: root

    signal closeRequested()

    readonly property int rowHeight: 40
    readonly property int maxRows: 8
    readonly property int searchHeight: 44
    readonly property int spacing: 10
    readonly property int padding: 12

    function exec(command) {
        return () => Quickshell.execDetached(command);
    }

    // Screenshot with grimshot: saved to ~/Pictures/Screenshots and copied to the clipboard
    // (same command as the Print key bindings in sway/config.d/60-bindings-screenshot.conf)
    function screenshot(target) {
        return exec(["sh", "-c", 'sleep 0.3; exec grimshot --notify savecopy "$1" "$HOME/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png"', "screenshot", target]);
    }

    function terminal(title, args) {
        return exec(UpdatesService.terminal(title, args));
    }

    readonly property var appItems: DesktopEntries.applications.values
        .filter(a => !a.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))
        .map(a => ({
            key: "app:" + a.id, name: a.name, icon: a.icon, detail: a.genericName, keywords: [a.genericName, a.keywords].join(" "),
            // command is a Qt list: copy it into a JS array before joining
            run: () => a.runInTerminal ? Quickshell.execDetached(["foot", "-e"].concat(Array.from(a.command))) : a.execute()
        }))

    readonly property var captureItems: (RecordingService.recording
        ? [{ name: "Stop recording", icon: "simplescreenrecorder", keywords: "record video stop", run: () => RecordingService.stop(),
             live: () => Util.duration(RecordingService.seconds) }]
        : [
            { name: "Record an area", icon: "simplescreenrecorder", keywords: "record video screencast enregistrer", run: () => RecordingService.start("area") },
            { name: "Record the screen", icon: "io.github.seadve.Kooha", keywords: "record video screencast enregistrer", run: () => RecordingService.start("screen") }
        ]).concat([
        { name: "Screenshot of an area", icon: "applets-screenshooter", keywords: "screenshot capture region selection", run: screenshot("area") },
        { name: "Screenshot of a window", icon: "org.gnome.Screenshot", keywords: "screenshot capture window", run: screenshot("window") },
        { name: "Screenshot of the screen", icon: "video-display", keywords: "screenshot capture screen fullscreen", run: screenshot("output") },
        { name: "Screenshot and annotate", icon: "gnome-screenshot", keywords: "screenshot annotate draw edit swappy arrow blur",
          run: exec(["sh", "-c", "sleep 0.3; grimshot save area - | swappy -f -"]) }
    ])

    readonly property var toolsItems: [
        { name: "Night light", icon: "redshift", keywords: "warm screen blue light redshift wlsunset nuit",
          run: () => NightLightService.cycle(), stay: true, live: () => NightLightService.label },
        { name: "Keyboard shortcuts", icon: "preferences-desktop-keyboard-shortcuts", keywords: "keys bindings cheat sheet raccourcis", menu: "shortcuts" },
        { name: "Clipboard history", icon: "edit-paste", keywords: "clipboard copy paste history presse-papiers", menu: "clipboard" },
        { name: "Calculator: type math in the search", icon: "accessories-calculator", keywords: "calculator calculate math calculatrice" }
    ]

    readonly property var installItems: [
        { name: "Fedora package", icon: "distributor-logo-fedora", keywords: "install dnf rpm package paquet installer", run: terminal("Install Fedora package", ["install"]) },
        { name: "Flathub app", icon: "software-store", keywords: "install flatpak flathub app store installer", run: terminal("Install Flathub app", ["flatpak-install"]) }
    ]

    readonly property var removeItems: [
        { name: "Fedora package", icon: "distributor-logo-fedora", keywords: "remove uninstall dnf rpm package paquet desinstaller supprimer", run: terminal("Remove Fedora package", ["remove"]) },
        { name: "Flathub app", icon: "software-store", keywords: "remove uninstall flatpak flathub app desinstaller supprimer", run: terminal("Remove Flathub app", ["flatpak-remove"]) }
    ]

    readonly property var updateItems: [
        { name: "Update system", icon: "system-software-update", keywords: "upgrade dnf flatpak packages mise a jour", run: () => UpdatesService.runUpdate(),
          live: () => UpdatesService.count > 0 ? UpdatesService.count + (UpdatesService.count === 1 ? " update" : " updates") : "Up to date" },
        { name: "Update firmware", icon: "fwupd", keywords: "bios fwupd firmware upgrade mise a jour", run: terminal("Update firmware", ["firmware"]) }
    ]

    readonly property var settingsItems: [
        { name: "Defaults", icon: "preferences-desktop-default-applications", keywords: "default apps applications open with browser editor viewer player par defaut", menu: "defaults" },
        { name: "Keyboard layout", icon: "preferences-desktop-keyboard", keywords: "layout switch azerty qwerty clavier french english",
          run: () => KeyboardService.next(), stay: true, live: () => KeyboardService.name }
    ].concat(DictationService.installed ? [
        // voxtype's own settings screen, in its Parakeet build (bin/voxtype-onnx) so that
        // engine shows as available
        { name: "Speech to text", icon: "audio-input-microphone", keywords: "dictation voice voxtype parakeet whisper microphone dictee voix reconnaissance vocale",
          run: exec(["foot", "--app-id=launcher-term", "--title=Speech to text", "-e", Quickshell.env("HOME") + "/.local/bin/voxtype-onnx", "configure"]) }
    ] : [])

    readonly property var systemItems: [
        { name: "Lock", icon: "system-lock-screen", keywords: "screen verrouiller", run: exec([Quickshell.env("HOME") + "/.local/bin/lock-screen"]) },
        { name: "Sleep", icon: "system-suspend", keywords: "suspend veille", run: exec(["systemctl", "suspend"]) },
        { name: "Log out", icon: "system-log-out", keywords: "logout exit session quit deconnexion", run: exec(["swaymsg", "exit"]) },
        { name: "Restart", icon: "system-reboot", keywords: "reboot power redemarrer", run: exec(["systemctl", "reboot"]) },
        { name: "Shut down", icon: "system-shutdown", keywords: "shutdown power off poweroff halt eteindre", run: exec(["systemctl", "poweroff"]) }
    ]

    // A top-level menu: its entries get a unique key, and their menu's name as
    // description (shown in top-level search results)
    function section(id, name, icon, items) {
        return { name: name, icon: icon, items: items.map(i => Object.assign({ detail: name, key: id + ":" + i.name }, i)) };
    }

    readonly property var menus: ({
        apps: { name: "Apps", icon: "applications-all", items: appItems },
        capture: section("capture", "Capture", "accessories-screenshot", captureItems),
        tools: section("tools", "Tools", "applications-utilities", toolsItems),
        install: section("install", "Install", "system-software-install", installItems),
        remove: section("remove", "Remove", "user-trash", removeItems),
        update: section("update", "Update", "system-software-update", updateItems),
        settings: section("settings", "Settings", "preferences-system", settingsItems),
        system: section("system", "System", "system-shutdown", systemItems)
    })
    readonly property var menuOrder: ["apps", "capture", "tools", "install", "remove", "update", "settings", "system"]
    readonly property var menuItems: menuOrder.map(id => ({ key: "menu:" + id, menu: id, name: menus[id].name, icon: menus[id].icon, keywords: "" }))

    property var path: [] // menus entered, e.g. ["settings", "defaults", "defaults:browser"]
    readonly property string menu: path.length ? path[path.length - 1] : "" // "" = top level

    // Static menus, plus the keyboard shortcuts, Defaults (one row per category)
    // and each category's app choices; null for an unknown id
    function menuFor(id) {
        if (menus[id])
            return menus[id];
        if (id === "clipboard")
            return {
                name: "Clipboard history",
                items: ClipboardService.items.map(c => ({
                    key: "clip:" + c.id, name: c.text.replace(/\s+/g, " "), keywords: "",
                    icon: c.text.startsWith("[[ binary data") ? "image-x-generic" : "edit-paste",
                    run: () => ClipboardService.copy(c.id),
                    remove: () => ClipboardService.remove(c.id)
                })).concat(!ClipboardService.available
                    ? [{ key: "clip:missing", name: "Needs cliphist: sudo dnf install cliphist", icon: "dialog-information", keywords: "", stay: true }]
                    // Clearing everything takes a second Enter
                    : ClipboardService.items.length === 0 ? []
                    : [ClipboardService.confirmClear
                        ? { key: "clip:clear", name: "Clear everything? Enter again to confirm", icon: "edit-clear-all", keywords: "", run: () => ClipboardService.clear() }
                        : { key: "clip:clear", name: "Clear history", icon: "edit-clear-all", keywords: "", stay: true, run: () => ClipboardService.confirmClear = true }])
            };
        if (id === "shortcuts")
            return {
                name: "Keyboard shortcuts",
                items: ShortcutsService.list.map(s => ({ key: "shortcut:" + s.description, name: s.description, value: s.keys, icon: "", keywords: s.keys }))
            };
        if (id === "defaults")
            return {
                name: "Defaults",
                items: DefaultsService.categories.map(c => ({
                    key: "defaults:" + c.id, menu: "defaults:" + c.id, name: c.name, icon: c.icon, keywords: "default",
                    live: () => DefaultsService.appName(DefaultsService.apps[c.id]?.current) || "None"
                }))
            };
        const category = DefaultsService.categories.find(c => "defaults:" + c.id === id);
        if (!category)
            return null;
        const state = DefaultsService.apps[category.id] ?? { current: "", choices: [] };
        return {
            name: category.name,
            items: state.choices
                .map(f => ({
                    key: id + ":" + f, name: DefaultsService.appName(f), icon: DefaultsService.entry(f)?.icon ?? "application-x-executable",
                    keywords: "", checked: f === state.current, stay: true,
                    run: () => {
                        DefaultsService.set(category.id, f);
                        back(); // to Defaults, which shows the new value
                    }
                }))
                .sort((a, b) => a.name.localeCompare(b.name))
        };
    }

    readonly property var current: menu !== "" ? menuFor(menu) : null // the open menu

    property string query: ""

    readonly property var results: {
        const q = normalize(query.trim());
        const calc = (menu === "" || menu === "tools") ? calculate(query) : null;
        const found = menu !== ""
            ? (q === "" ? current?.items ?? [] : search(current?.items ?? [], q))
            : (q === "" ? menuItems : search(menuOrder.reduce((all, id) => all.concat(menus[id].items), menuItems), q));
        return calc ? [calc].concat(found) : found;
    }

    // "12*7+3", "1,5 x 4", "2^10", "(3+4)/2"... -> a result row; anything else -> null.
    // Only digits, operators and parentheses get through, so this can't run other code.
    function calculate(text) {
        const expr = text.trim().replace(/,/g, ".").replace(/[x×]/g, "*").replace(/÷/g, "/").replace(/\^/g, "**");
        if (!/^[\d\s.+\-*\/()%]+$/.test(expr) || !/\d/.test(expr) || !/[+\-*\/%]/.test(expr.replace(/^\s*-/, "")))
            return null;
        try {
            const value = Function('"use strict"; return (' + expr + ");")();
            if (typeof value !== "number" || !isFinite(value))
                return null;
            const result = String(parseFloat(value.toPrecision(12)));
            return { key: "calc:" + result, name: "= " + result, icon: "accessories-calculator", value: "Enter to copy",
                     run: exec(["wl-copy", result]) };
        } catch (e) {
            return null;
        }
    }

    function search(items, q) {
        const found = [];
        for (const item of items) {
            const s = Math.max(score(item.name, q), 0.7 * wordScore(item.keywords, q));
            if (s > 0)
                found.push(Object.assign({ score: s }, item));
        }
        return found.sort((a, b) => b.score - a.score || a.name.localeCompare(b.name));
    }

    // Lowercase without accents, so "eteindre" matches "éteindre"
    function normalize(text) {
        return (text || "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
    }

    function words(text) {
        return text.split(/[\s\-_.;,]+/);
    }

    // Secondary text (keywords, description) only matches at the start of a word
    function wordScore(text, q) {
        return words(normalize(text)).some(w => w.startsWith(q)) ? 80 : 0;
    }

    // How well a name matches the (normalized) query: start > word start > anywhere > letters in order
    function score(text, q) {
        const t = normalize(text);
        if (!t)
            return 0;
        if (t.startsWith(q))
            return 100;
        const ws = words(t);
        if (ws.some(w => w.startsWith(q)))
            return 80;
        if (t.includes(q))
            return 60;
        // Letters in order, within a single word (e.g. "ffx" -> Firefox)
        const inOrder = w => {
            let i = 0;
            for (const c of w)
                if (c === q[i])
                    i++;
            return i === q.length;
        };
        return ws.some(inOrder) ? 20 : 0;
    }

    function enterMenu(id) {
        path = path.concat([id]);
        if (id === "defaults")
            DefaultsService.refresh();
        if (id === "shortcuts")
            ShortcutsService.refresh();
        if (id === "clipboard")
            ClipboardService.refresh();
        input.text = "";
        list.currentIndex = 0;
    }

    // From the top level, straight into a menu (qs ipc call launcher menu <id>)
    function openMenu(id) {
        path = [];
        input.text = "";
        if (menuFor(id))
            enterMenu(id);
    }

    // Up one menu level, keeping the menu we just left highlighted
    function back() {
        const left = menu;
        path = path.slice(0, -1);
        input.text = "";
        list.currentIndex = Math.max(0, results.findIndex(r => r.menu === left));
    }

    function activate(item) {
        if (!item)
            return;
        if (item.menu) {
            enterMenu(item.menu);
        } else if (item.run) {
            item.run();
            if (!item.stay)
                root.closeRequested();
        }
    }

    Component.onCompleted: UpdatesService.refresh(false)

    screen: Util.focusedScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    Card {
        width: Math.min(400, root.width - 32)
        height: column.implicitHeight + 2 * root.padding
        x: (root.width - width) / 2
        // Centered as if the list were full, so the search bar doesn't jump
        // around while results get filtered
        y: (root.height - (root.searchHeight + root.spacing + root.maxRows * root.rowHeight + 2 * root.padding)) / 2
        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: root.padding
            spacing: root.spacing

            // Search field
            Rectangle {
                id: searchField

                Layout.fillWidth: true
                implicitHeight: root.searchHeight
                color: Theme.bgAlt

                // Where we are, e.g. "Defaults › Video player ›" (last two levels, and
                // at most half the field, to leave room for typing)
                Label {
                    id: crumb
                    visible: root.menu !== ""
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, searchField.width * 0.55)
                    text: root.path.slice(-2).map(id => root.menuFor(id)?.name ?? "").join(" › ") + "  ›"
                    elide: Text.ElideLeft
                    color: Theme.accent
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                }

                TextInput {
                    id: input

                    anchors.fill: parent
                    anchors.leftMargin: crumb.visible ? crumb.width + 26 : 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.bg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    focus: true

                    // Keep the selection if typing didn't change the list, otherwise go back to the top
                    onTextChanged: {
                        const keys = items => items.map(i => i.key).join("\n");
                        const before = keys(root.results);
                        const index = list.currentIndex;
                        root.query = text;
                        list.currentIndex = keys(root.results) === before ? index : 0;
                    }

                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Escape:
                            root.closeRequested();
                            break;
                        case Qt.Key_Backspace:
                        case Qt.Key_Left:
                            if (input.text !== "" || root.menu === "")
                                return; // normal text editing
                            root.back();
                            break;
                        case Qt.Key_Right:
                            if (!root.results[list.currentIndex]?.menu || input.cursorPosition < input.text.length)
                                return;
                            root.activate(root.results[list.currentIndex]);
                            break;
                        case Qt.Key_Down:
                        case Qt.Key_Tab:
                            list.incrementCurrentIndex();
                            break;
                        case Qt.Key_Up:
                        case Qt.Key_Backtab:
                            list.decrementCurrentIndex();
                            break;
                        case Qt.Key_PageDown:
                            list.currentIndex = Math.min(list.count - 1, list.currentIndex + root.maxRows);
                            break;
                        case Qt.Key_PageUp:
                            list.currentIndex = Math.max(0, list.currentIndex - root.maxRows);
                            break;
                        case Qt.Key_Delete:
                            // Removes the highlighted entry, unless there's text after the cursor to delete
                            if (!root.results[list.currentIndex]?.remove || input.cursorPosition < input.text.length)
                                return;
                            root.results[list.currentIndex].remove();
                            break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            root.activate(root.results[list.currentIndex]);
                            break;
                        default:
                            return;
                        }
                        event.accepted = true;
                    }

                    Text {
                        visible: input.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search..."
                        color: Theme.muted
                        font: input.font
                    }
                }
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(1, Math.min(count, root.maxRows)) * root.rowHeight
                // A plain array: entries hold functions (run, live), which a ScriptModel would drop
                model: root.results
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationWraps: true // Up on the first row goes to the last, Down on the last to the first
                highlightMoveDuration: 0

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool selected: ListView.isCurrentItem
                    readonly property bool hasValue: !!modelData.live || modelData.value !== undefined

                    width: ListView.view.width
                    height: root.rowHeight
                    color: selected ? Theme.accent : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 12
                        spacing: 12

                        IconImage {
                            visible: row.modelData.icon !== ""
                            implicitSize: 24
                            source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                        }
                        Label {
                            text: row.modelData.name
                            textFormat: Text.PlainText // app names come from .desktop files
                            color: row.selected ? Theme.bg : Theme.fg
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: row.modelData.live ? row.modelData.live()
                                : row.modelData.value !== undefined ? row.modelData.value
                                // Inside a menu its name is already shown above (apps keep their description)
                                : root.menu !== "" && !row.modelData.key.startsWith("app:") ? "" : row.modelData.detail || ""
                            textFormat: Text.PlainText
                            color: row.selected ? Theme.bg : row.hasValue ? Theme.accent : Theme.muted
                            font.pixelSize: row.hasValue ? Theme.fontSize - 1 : Theme.fontSize - 3
                            font.bold: row.hasValue
                        }
                        Icon {
                            visible: !!row.modelData.menu || !!row.modelData.checked
                            text: row.modelData.checked ? "" : ""
                            color: row.selected ? Theme.bg : row.modelData.checked ? Theme.accent : Theme.muted
                            font.pixelSize: Theme.fontSize - 4
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: list.currentIndex = row.index
                        onClicked: root.activate(row.modelData)
                    }

                    // Remove button on the highlighted row (above the row's own click area)
                    Rectangle {
                        visible: row.selected && !!row.modelData.remove
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 4
                        width: row.height - 8
                        height: row.height - 8
                        color: removeMouse.containsMouse ? Theme.bg : "transparent"

                        Icon {
                            anchors.centerIn: parent
                            text: "\uf00d"
                            color: removeMouse.containsMouse ? Theme.red : Theme.bg
                            font.pixelSize: Theme.fontSize - 2
                        }
                        MouseArea {
                            id: removeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: row.modelData.remove()
                        }
                    }
                }

                Label {
                    visible: list.count === 0
                    anchors.centerIn: parent
                    text: root.menu.startsWith("defaults:") && root.query === "" ? "No installed app handles this" : "No results"
                    color: Theme.muted
                    font.pixelSize: Theme.fontSize - 2
                }
            }
        }
    }
}

//@ pragma IconTheme Papirus-Dark
// Needed for the tray icons' right-click menus
//@ pragma UseQApplication
// Sway desktop shell: one bar per screen, popup panels opened from it, and the app launcher.
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    // Services are created on first use. The brightness and volume ones must exist from
    // the start for their IPC commands (the keys): the Osd below uses both, so they do.

    // Uses the browser's own desktop actions ("New Window", "New Private Window"),
    // so it works for any browser, Flatpak ones included.
    function launchBrowser(isPrivate) {
        const entry = DefaultsService.entry(DefaultsService.apps.browser?.current || "org.mozilla.firefox.desktop");
        if (!entry)
            return;
        const action = isPrivate
            ? entry.actions.find(a => /private|incognito/i.test(a.id + " " + a.name))
            : entry.actions.find(a => /^new-?window$/i.test(a.id));
        (action ?? entry).execute();
    }

    Variants {
        id: screens
        model: Quickshell.screens

        Scope {
            id: scope
            required property ShellScreen modelData
            readonly property var bar: barWindow

            Bar { id: barWindow; screen: scope.modelData }

            LazyLoader { active: barWindow.openPanel === "network"; NetworkPanel { bar: barWindow } }
            LazyLoader { active: barWindow.openPanel === "bluetooth"; BluetoothPanel { bar: barWindow } }
            LazyLoader { active: barWindow.openPanel === "volume"; VolumePanel { bar: barWindow } }
            LazyLoader { active: barWindow.openPanel === "display"; DisplayPanel { bar: barWindow } }
            LazyLoader { active: barWindow.openPanel === "battery"; BatteryPanel { bar: barWindow } }
            LazyLoader { active: barWindow.openPanel === "calendar"; CalendarPanel { bar: barWindow } }
            LazyLoader { active: barWindow.openPanel.startsWith("tray:"); TrayMenu { bar: barWindow } }
        }
    }

    // Open/close bar panels on the focused screen: qs ipc call bar toggle volume
    IpcHandler {
        target: "bar"

        function toggle(name: string): void {
            (screens.instances.find(s => s.modelData === Util.focusedScreen) ?? screens.instances[0])?.bar.toggleByName(name);
        }
        function close(): void {
            for (const s of screens.instances)
                s.bar.openPanel = "";
        }
    }

    // Notification pop-ups (replaces dunst)
    Toasts {}

    // Volume / brightness indicator for the media keys
    Osd {}

    // Microphone level while dictating (Super+D)
    DictationOsd {}

    // Password window when an app asks for admin rights (polkit agent)
    PolkitDialog {}

    // Lock screen (replaces swaylock): qs ipc call lock lock
    LockScreen {}

    // App launcher, opened by Super+Space: qs ipc call launcher toggle
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            launcher.active = !launcher.active;
        }
        function close(): void {
            launcher.active = false;
        }
        // Open directly in a menu: apps, capture, tools, install, remove, update, settings,
        // system, shortcuts, defaults
        function menu(name: string): void {
            launcher.active = true;
            launcher.item.openMenu(name);
        }
    }

    // Default browser (Super+Shift+B) and a private window in it (Super+Alt+B):
    // qs ipc call browser open / openPrivate
    IpcHandler {
        target: "browser"

        function open(): void {
            root.launchBrowser(false);
        }
        function openPrivate(): void {
            root.launchBrowser(true);
        }
    }

    LazyLoader {
        id: launcher
        Launcher { onCloseRequested: launcher.active = false }
    }
}

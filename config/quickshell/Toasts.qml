import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland

// Notification pop-ups, top right under the bar (no notification center).
// This shell is the notification server, replacing dunst.
Scope {
    id: root

    readonly property int maxShown: 4

    NotificationServer {
        id: server

        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            // Volume/brightness keys tag their notifications so a new one replaces the
            // previous one instead of stacking (x-canonical-private-synchronous)
            const tag = n.hints["x-canonical-private-synchronous"];
            if (tag)
                for (const old of trackedNotifications.values)
                    if (old !== n && old.hints["x-canonical-private-synchronous"] === tag)
                        old.dismiss();
            n.tracked = true;
        }
    }

    PanelWindow {
        id: popups

        // Newest first
        readonly property var shown: server.trackedNotifications.values.slice().reverse().slice(0, root.maxShown)

        visible: shown.length > 0
        screen: Util.focusedScreen
        anchors { top: true; right: true }
        margins { top: 8; right: 8 }
        implicitWidth: 380
        implicitHeight: column.implicitHeight
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-toasts"

        ColumnLayout {
            id: column
            width: parent.width
            spacing: 8

            Repeater {
                // ScriptModel keeps existing pop-ups (and their timers) when one is added or removed
                model: ScriptModel { values: popups.shown }

                Toast {
                    required property Notification modelData
                    notification: modelData
                    Layout.fillWidth: true
                }
            }
        }
    }
}

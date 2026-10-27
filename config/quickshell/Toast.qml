import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

// One notification pop-up. Click: default action (or close). Right click: close.
// Disappears after its timeout (5 s by default), paused while hovered.
// Critical notifications stay until dismissed.
Rectangle {
    id: root

    required property Notification notification

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property var buttons: notification.actions.filter(a => a.identifier !== "default")
    readonly property var defaultAction: notification.actions.find(a => a.identifier === "default")

    // Icon: the notification's image, else the app icon (a name or a path)
    function iconSource() {
        const n = notification;
        if (n.image)
            return n.image;
        if (n.appIcon.startsWith("/") || n.appIcon.startsWith("file:"))
            return n.appIcon;
        return Quickshell.iconPath(n.appIcon || n.desktopEntry, "dialog-information");
    }

    implicitHeight: content.implicitHeight + 24
    color: Theme.bg
    border.color: critical ? Theme.red : Theme.accent
    border.width: 2

    Timer {
        running: !root.critical && root.notification.expireTimeout !== 0 && !mouse.containsMouse
        interval: root.notification.expireTimeout > 0 ? root.notification.expireTimeout : 5000
        onTriggered: root.notification.expire()
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.LeftButton && root.defaultAction)
                root.defaultAction.invoke();
            else
                root.notification.dismiss();
        }
    }

    RowLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        IconImage {
            Layout.alignment: Qt.AlignTop
            implicitSize: 36
            source: root.iconSource()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    text: root.notification.summary || root.notification.appName
                    textFormat: Text.PlainText
                    font.pixelSize: Theme.fontSize - 1
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Label {
                    visible: root.notification.summary !== "" && root.notification.appName !== ""
                    text: root.notification.appName
                    textFormat: Text.PlainText
                    color: Theme.muted
                    font.pixelSize: Theme.fontSize - 4
                }
            }

            Label {
                visible: text !== ""
                // Only basic formatting gets through: any other "<" is shown as text,
                // so nothing (images in particular) can be loaded from elsewhere
                text: root.notification.body.replace(/<(?!\/?(b|i|u|a|br)\b)/gi, "&lt;")
                textFormat: Text.StyledText
                font.pixelSize: Theme.fontSize - 3
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                Layout.fillWidth: true
                // Only web and mail links; other schemes could start local handlers
                onLinkActivated: link => {
                    if (/^(https?|mailto):/i.test(link))
                        Qt.openUrlExternally(link);
                }
            }

            RowLayout {
                visible: root.buttons.length > 0
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6

                Repeater {
                    model: root.buttons

                    Rectangle {
                        required property NotificationAction modelData

                        Layout.fillWidth: true
                        implicitHeight: 28
                        color: buttonMouse.containsMouse ? Theme.accent : Theme.bgAlt

                        Label {
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            textFormat: Text.PlainText
                            color: buttonMouse.containsMouse ? Theme.bg : Theme.fg
                            font.pixelSize: Theme.fontSize - 3
                        }
                        MouseArea {
                            id: buttonMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: parent.modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}

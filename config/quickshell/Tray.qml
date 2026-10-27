import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets

RowLayout {
    id: root
    required property var bar

    spacing: 0

    Repeater {
        model: SystemTray.items

        Rectangle {
            id: item
            required property SystemTrayItem modelData

            // Network and Bluetooth have their own bar icons
            visible: !/nm-applet|nm_applet|blueman/i.test(modelData.id)
            implicitWidth: 34
            implicitHeight: Theme.barHeight
            color: mouse.containsMouse ? Theme.bgAlt : "transparent"

            IconImage {
                anchors.centerIn: parent
                implicitSize: 18
                source: item.modelData.icon
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                // Left click opens the app; right click, or apps with only a menu: our menu.
                // Electron apps (id "<App>_status_icon_<n>", e.g. Claude Desktop) often
                // ignore the left click, so they get the menu too.
                onClicked: m => {
                    const d = item.modelData;
                    const menuOnly = d.onlyMenu || /_status_icon_\d+$/.test(d.id);
                    if (m.button === Qt.LeftButton && !(menuOnly && d.hasMenu)) {
                        d.activate();
                    } else if (d.hasMenu) {
                        root.bar.trayItem = d;
                        root.bar.toggle("tray:" + d.id, item);
                    }
                }
            }
        }
    }
}

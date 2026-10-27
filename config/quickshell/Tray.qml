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
                onClicked: m => {
                    const d = item.modelData;
                    if (m.button === Qt.LeftButton && !d.onlyMenu) {
                        d.activate();
                    } else if (d.hasMenu) {
                        const p = item.mapToItem(null, 0, item.height);
                        d.display(root.bar, p.x, p.y);
                    }
                }
            }
        }
    }
}

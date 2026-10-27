import QtQuick
import QtQuick.Layouts
import Quickshell

// A tray icon's menu (right click, or left click on apps that only have a menu), drawn
// like the panels instead of the default Qt menu. Submenus open in place, with a row
// to go back. The item comes from bar.trayItem (set by Tray.qml).
Popout {
    id: root

    property var path: [] // submenus entered

    cardWidth: 280

    Connections {
        target: root.bar
        function onTrayItemChanged() {
            root.path = [];
        }
    }

    QsMenuOpener {
        id: opener
        menu: root.path.length > 0 ? root.path[root.path.length - 1] : root.bar.trayItem?.menu ?? null
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        MenuRow {
            visible: root.path.length > 0
            icon: ""
            iconColor: Theme.muted
            text: root.path.length > 0 ? root.path[root.path.length - 1].text : ""
            onClicked: root.path = root.path.slice(0, -1)
        }

        Repeater {
            model: opener.children

            Loader {
                required property QsMenuEntry modelData

                Layout.fillWidth: true
                sourceComponent: modelData.isSeparator ? separator : entry

                Component {
                    id: separator
                    Item {
                        implicitHeight: 9
                        Separator { anchors.verticalCenter: parent.verticalCenter; width: parent.width }
                    }
                }

                Component {
                    id: entry
                    MenuRow {
                        readonly property QsMenuEntry e: modelData
                        readonly property bool toggle: e.buttonType !== QsMenuButtonType.None

                        // Apps mark keyboard shortcuts with "_" (e.g. "_Quit")
                        text: e.text.replace(/_(.)/g, "$1")
                        enabled: e.enabled
                        opacity: e.enabled ? 1 : 0.4
                        icon: toggle ? (e.checkState === Qt.Checked ? "" : "") : ""
                        iconColor: e.checkState === Qt.Checked ? Theme.accent : Theme.muted
                        status: e.hasChildren ? "›" : ""
                        onClicked: {
                            if (!e.enabled)
                                return;
                            if (e.hasChildren) {
                                root.path = root.path.concat([e]);
                            } else {
                                e.triggered();
                                root.close();
                            }
                        }
                    }
                }
            }
        }
    }
}

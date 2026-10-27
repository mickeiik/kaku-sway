import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

// Details of the current connection (in two columns), then the Wi-Fi switch and networks
Popout {
    id: root

    readonly property var wifi: NetworkService.wifi
    // Connected first, then strongest signal
    readonly property var networks: (wifi?.networks.values ?? []).filter(n => n.name).sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))

    cardWidth: connection.visible ? 600 : 380

    // Scan only while the panel is open
    Component.onCompleted: if (wifi) wifi.scannerEnabled = true
    Component.onDestruction: if (wifi) wifi.scannerEnabled = false

    PanelHeader {
        title: "Network"
        detail: NetworkService.label
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 12

        ConnectionInfo { id: connection }

        Separator { visible: connection.visible }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: NetworkService.wired.filter(d => d.connected) // a cable in use

                MenuRow {
                    required property var modelData
                    icon: ""
                    iconColor: Theme.accent
                    text: "Ethernet · connected"
                    checked: true
                }
            }

            ToggleRow {
                visible: root.wifi !== null
                text: "Wi-Fi"
                checked: Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }

            SectionLabel {
                visible: Networking.wifiEnabled && root.networks.length > 0
                text: "Networks"
            }

            Flickable {
                visible: Networking.wifiEnabled
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(list.implicitHeight, 36 * 10)
                contentHeight: list.implicitHeight
                clip: true

                ColumnLayout {
                    id: list
                    width: parent.width
                    spacing: 0

                    Repeater {
                        // Keeps rows in place while signal strengths update
                        model: ScriptModel { values: root.networks }

                        MenuRow {
                            required property var modelData
                            readonly property bool open: modelData.security === WifiSecurityType.Open
                            readonly property bool busy: modelData.state === NetworkState.Connecting || modelData.state === NetworkState.Disconnecting

                            icon: ""
                            iconColor: modelData.signalStrength > 0.66 ? Theme.fg : modelData.signalStrength > 0.33 ? Theme.yellow : Theme.red
                            text: modelData.name + (busy ? "  …" : "")
                            // Open networks stand out (anyone nearby can read the traffic);
                            // the lock marks secured networks you haven't joined yet
                            badge: open ? "\uf3c1" : !modelData.known ? "\uf023" : ""
                            badgeColor: open ? Theme.yellow : Theme.muted
                            status: modelData.known && !modelData.connected ? "saved" : ""
                            checked: modelData.connected
                            onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                        }
                    }
                }
            }
        }
    }
}
